function Get-ShareSurferDirectoryIdentity {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Identity,

        [string] $ObsAttribute = 'extensionAttribute10'
    )

    $sam = Get-ShareSurferIdentityName -Identity $Identity
    $domain = Get-ShareSurferIdentityDomain -Identity $Identity

    $getAdUser = Get-Command Get-ADUser -ErrorAction SilentlyContinue
    $getAdGroup = Get-Command Get-ADGroup -ErrorAction SilentlyContinue
    $getAdGroupMember = Get-Command Get-ADGroupMember -ErrorAction SilentlyContinue

    if ($null -ne $getAdUser -and $null -ne $getAdGroup) {
        try {
            $properties = @('employeeID', 'employeeNumber', 'manager', 'displayName', $ObsAttribute)
            $user = Get-ADUser -Identity $sam -Properties $properties -ErrorAction Stop
            $managerLevel1 = ''
            $managerLevel2 = ''
            if ($user.Manager) {
                $managerLevel1 = [string]$user.Manager
                try {
                    $manager = Get-ADUser -Identity $user.Manager -Properties manager -ErrorAction Stop
                    if ($manager.Manager) {
                        $managerLevel2 = [string]$manager.Manager
                    }
                }
                catch {
                    $managerLevel2 = ''
                }
            }

            return [pscustomobject]@{
                Identity = $Identity
                SamAccountName = [string]$user.SamAccountName
                DisplayName = [string]$user.DisplayName
                ObjectClass = 'user'
                EmployeeId = [string]$user.EmployeeID
                EmployeeNumber = [string]$user.employeeNumber
                Manager = [string]$user.Manager
                ManagerLevel1 = $managerLevel1
                ManagerLevel2 = $managerLevel2
                ObsPath = [string]$user.$ObsAttribute
                ObsAttribute = $ObsAttribute
                Members = @()
            }
        }
        catch {
            try {
                $group = Get-ADGroup -Identity $sam -Properties displayName, $ObsAttribute -ErrorAction Stop
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
                    Manager = ''
                    ManagerLevel1 = ''
                    ManagerLevel2 = ''
                    ObsPath = [string]$group.$ObsAttribute
                    ObsAttribute = $ObsAttribute
                    Members = @($members)
                }
            }
            catch {
                return $null
            }
        }
    }

    try {
        $searcher = New-Object System.DirectoryServices.DirectorySearcher
        $escapedSam = $sam.Replace('\', '\5c').Replace('(', '\28').Replace(')', '\29')
        $searcher.Filter = "(sAMAccountName=$escapedSam)"
        foreach ($property in @('sAMAccountName', 'displayName', 'objectClass', 'employeeID', 'employeeNumber', 'manager', 'member', $ObsAttribute)) {
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

        [pscustomobject]@{
            Identity = $Identity
            SamAccountName = [string]$props['samaccountname'][0]
            DisplayName = [string]$props['displayname'][0]
            ObjectClass = $objectClass
            EmployeeId = [string]$props['employeeid'][0]
            EmployeeNumber = [string]$props['employeenumber'][0]
            Manager = [string]$props['manager'][0]
            ManagerLevel1 = [string]$props['manager'][0]
            ManagerLevel2 = ''
            ObsPath = [string]$props[$ObsAttribute.ToLowerInvariant()][0]
            ObsAttribute = $ObsAttribute
            Members = @($members)
        }
    }
    catch {
        $null
    }
}
