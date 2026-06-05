function Get-ShareSurferDirectoryIdentity {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Identity,

        [string] $ObsAttribute = 'extensionAttribute10',

        [ValidateSet('Auto', 'ActiveDirectory', 'Ldap', 'DirectoryOnly')]
        [string] $AdLookupMode = 'Auto'
    )

    if ($AdLookupMode -eq 'DirectoryOnly') {
        return $null
    }

    $sam = Get-ShareSurferIdentityName -Identity $Identity
    $domain = Get-ShareSurferIdentityDomain -Identity $Identity

    $getAdUser = Get-Command Get-ADUser -ErrorAction SilentlyContinue
    $getAdGroup = Get-Command Get-ADGroup -ErrorAction SilentlyContinue
    $getAdGroupMember = Get-Command Get-ADGroupMember -ErrorAction SilentlyContinue

    if ($AdLookupMode -ne 'Ldap' -and $null -ne $getAdUser -and $null -ne $getAdGroup) {
        try {
            $properties = @('employeeID', 'employeeNumber', 'manager', 'displayName', 'userPrincipalName', 'mail', 'department', 'title', 'company', 'physicalDeliveryOfficeName', 'distinguishedName', $ObsAttribute)
            $user = Get-ShareSurferAdUserWithOptionalProperties -SamAccountName $sam -Properties $properties -OptionalProperties @('employeeNumber', $ObsAttribute)
            $managerLevel1 = ''
            $managerLevel2 = ''
            $managerLevel3 = ''
            if ($user.Manager) {
                $managerLevel1 = [string]$user.Manager
                try {
                    $manager = Get-ADUser -Identity $user.Manager -Properties manager -ErrorAction Stop
                    if ($manager.Manager) {
                        $managerLevel2 = [string]$manager.Manager
                        try {
                            $manager2 = Get-ADUser -Identity $manager.Manager -Properties manager -ErrorAction Stop
                            if ($manager2.Manager) {
                                $managerLevel3 = [string]$manager2.Manager
                            }
                        }
                        catch {
                            $managerLevel3 = ''
                        }
                    }
                }
                catch {
                    $managerLevel2 = ''
                    $managerLevel3 = ''
                }
            }

            return [pscustomobject]@{
                Identity = $Identity
                SamAccountName = [string]$user.SamAccountName
                DisplayName = [string]$user.DisplayName
                ObjectClass = 'user'
                EmployeeId = Get-ShareSurferAdObjectPropertyValue -Object $user -Name 'EmployeeID'
                EmployeeNumber = Get-ShareSurferAdObjectPropertyValue -Object $user -Name 'employeeNumber'
                UserPrincipalName = [string]$user.UserPrincipalName
                Mail = [string]$user.Mail
                Department = [string]$user.Department
                Title = [string]$user.Title
                Company = [string]$user.Company
                Office = [string]$user.physicalDeliveryOfficeName
                AccountEnabled = if ($null -ne $user.PSObject.Properties['Enabled'] -and $null -ne $user.Enabled) { [string]$user.Enabled } else { '' }
                Manager = [string]$user.Manager
                ManagerLevel1 = $managerLevel1
                ManagerLevel2 = $managerLevel2
                ManagerLevel3 = $managerLevel3
                ObsPath = Get-ShareSurferAdObjectPropertyValue -Object $user -Name $ObsAttribute
                ObsAttribute = $ObsAttribute
                Members = @()
                DistinguishedName = [string]$user.DistinguishedName
            }
        }
        catch {
            try {
                $group = Get-ShareSurferAdGroupWithOptionalProperties -SamAccountName $sam -Properties @('displayName', 'mail', 'managedBy', 'description', 'distinguishedName', $ObsAttribute) -OptionalProperties @($ObsAttribute)
                $members = @()
                if ($null -ne $getAdGroupMember) {
                    $members = @(Get-ADGroupMember -Identity $group.SamAccountName -ErrorAction SilentlyContinue | ForEach-Object {
                        if ($domain -ne '') {
                            '{0}\{1}' -f $domain, $_.SamAccountName
                        }
                        else {
                            [string]$_.SamAccountName
                        }
                    })
                }

                return [pscustomobject]@{
                    Identity = $Identity
                    SamAccountName = [string]$group.SamAccountName
                    DisplayName = if ($group.DisplayName) { [string]$group.DisplayName } else { [string]$group.Name }
                    ObjectClass = 'group'
                    EmployeeId = ''
                    EmployeeNumber = ''
                    UserPrincipalName = ''
                    Mail = [string]$group.Mail
                    Department = ''
                    Title = ''
                    Company = ''
                    Office = ''
                    AccountEnabled = ''
                    Manager = [string]$group.ManagedBy
                    ManagerLevel1 = [string]$group.ManagedBy
                    ManagerLevel2 = ''
                    ManagerLevel3 = ''
                    ObsPath = Get-ShareSurferAdObjectPropertyValue -Object $group -Name $ObsAttribute
                    ObsAttribute = $ObsAttribute
                    Members = @($members)
                    DistinguishedName = [string]$group.DistinguishedName
                }
            }
            catch {
                return $null
            }
        }
    }

    if ($AdLookupMode -eq 'ActiveDirectory') {
        return $null
    }

    try {
        $searcher = New-Object System.DirectoryServices.DirectorySearcher
        $escapedSam = $sam.Replace('\', '\5c').Replace('(', '\28').Replace(')', '\29')
        $searcher.Filter = "(sAMAccountName=$escapedSam)"
        foreach ($property in @('sAMAccountName', 'displayName', 'objectClass', 'employeeID', 'employeeNumber', 'userPrincipalName', 'mail', 'department', 'title', 'company', 'physicalDeliveryOfficeName', 'userAccountControl', 'distinguishedName', 'manager', 'member', $ObsAttribute)) {
            [void]$searcher.PropertiesToLoad.Add($property)
        }
        $result = $searcher.FindOne()
        if ($null -eq $result) {
            return $null
        }

        $props = $result.Properties
        $objectClasses = @($props['objectclass'] | ForEach-Object { [string]$_ })
        $objectClass = if ($objectClasses -contains 'group') { 'group' } else { 'user' }
        $members = @()
        if ($objectClass -eq 'group') {
            $members = @($props['member'] | ForEach-Object {
                $resolvedMember = Resolve-ShareSurferDistinguishedNameIdentity -DistinguishedName ([string]$_) -FallbackDomain $domain -ObsAttribute $ObsAttribute
                if ($null -ne $resolvedMember) {
                    $resolvedMember.Identity
                }
                else {
                    ConvertFrom-ShareSurferDistinguishedName -DistinguishedName ([string]$_) -FallbackDomain $domain
                }
            })
        }

        $managerLevel1 = Get-ShareSurferLdapPropertyValue -Properties $props -Name 'manager'
        $managerLevel2 = Get-ShareSurferLdapManagerLevel2 -ManagerDistinguishedName $managerLevel1
        $managerLevel3 = Get-ShareSurferLdapManagerLevel2 -ManagerDistinguishedName $managerLevel2
        New-ShareSurferLdapIdentityRecord -Identity $Identity -Properties $props -ObsAttribute $ObsAttribute -Members $members -ManagerLevel2 $managerLevel2 -ManagerLevel3 $managerLevel3
    }
    catch {
        $null
    }
}

function Get-ShareSurferAdUserWithOptionalProperties {
    param(
        [Parameter(Mandatory = $true)]
        [string] $SamAccountName,

        [string[]] $Properties = @(),

        [string[]] $OptionalProperties = @()
    )

    Invoke-ShareSurferAdLookupWithOptionalProperties -CommandName 'Get-ADUser' -Identity $SamAccountName -Properties $Properties -OptionalProperties $OptionalProperties
}

function Get-ShareSurferAdGroupWithOptionalProperties {
    param(
        [Parameter(Mandatory = $true)]
        [string] $SamAccountName,

        [string[]] $Properties = @(),

        [string[]] $OptionalProperties = @()
    )

    Invoke-ShareSurferAdLookupWithOptionalProperties -CommandName 'Get-ADGroup' -Identity $SamAccountName -Properties $Properties -OptionalProperties $OptionalProperties
}

function Invoke-ShareSurferAdLookupWithOptionalProperties {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Get-ADUser', 'Get-ADGroup')]
        [string] $CommandName,

        [Parameter(Mandatory = $true)]
        [string] $Identity,

        [string[]] $Properties = @(),

        [string[]] $OptionalProperties = @()
    )

    $remainingProperties = @($Properties | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    $remainingOptional = @($OptionalProperties | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    while ($true) {
        try {
            if ($remainingProperties.Count -gt 0) {
                return & $CommandName -Identity $Identity -Properties $remainingProperties -ErrorAction Stop
            }

            return & $CommandName -Identity $Identity -ErrorAction Stop
        }
        catch {
            if ($remainingOptional.Count -eq 0) {
                throw
            }

            $propertyToRemove = [string]$remainingOptional[0]
            $remainingOptional = @($remainingOptional | Select-Object -Skip 1)
            $remainingProperties = @($remainingProperties | Where-Object { $_ -ne $propertyToRemove })
        }
    }
}

function Get-ShareSurferAdObjectPropertyValue {
    param(
        $Object,

        [string] $Name = ''
    )

    if ($null -eq $Object -or [string]::IsNullOrWhiteSpace($Name)) {
        return ''
    }

    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property -or $null -eq $property.Value) {
        return ''
    }

    [string]$property.Value
}
