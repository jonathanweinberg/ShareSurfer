function Resolve-ShareSurferIdentityInventory {
    param(
        [Parameter(Mandatory = $true)]
        $Inventory,

        [string] $ObsAttribute = 'extensionAttribute10',
        [int] $GroupExpansionMaxDepth = 20,

        [ValidateSet('Auto', 'ActiveDirectory', 'Ldap', 'DirectoryOnly')]
        [string] $AdLookupMode = 'Auto'
    )

    $directoryByIdentity = @{}
    $directoryByDistinguishedName = @{}
    $identityDirectorySource = @()
    if ($null -ne $Inventory.PSObject.Properties['IdentityDirectory']) {
        $identityDirectorySource = $Inventory.PSObject.Properties['IdentityDirectory'].Value
    }
    foreach ($entry in @(ConvertTo-ShareSurferArray $identityDirectorySource)) {
        if ($null -ne $entry.PSObject.Properties['Identity']) {
            $directoryByIdentity[([string]$entry.Identity).ToUpperInvariant()] = $entry
        }
        if ($null -ne $entry.PSObject.Properties['DistinguishedName'] -and [string]$entry.DistinguishedName -ne '') {
            $directoryByDistinguishedName[([string]$entry.DistinguishedName).ToUpperInvariant()] = $entry
        }
    }
    foreach ($entry in @(ConvertTo-ShareSurferArray $Inventory.Identities)) {
        if ($null -ne $entry.PSObject.Properties['Identity'] -and -not $directoryByIdentity.ContainsKey(([string]$entry.Identity).ToUpperInvariant())) {
            $directoryByIdentity[([string]$entry.Identity).ToUpperInvariant()] = $entry
        }
        if ($null -ne $entry.PSObject.Properties['DistinguishedName'] -and [string]$entry.DistinguishedName -ne '') {
            $directoryByDistinguishedName[([string]$entry.DistinguishedName).ToUpperInvariant()] = $entry
        }
    }

    $identityRows = [ordered]@{}
    $groupEdges = New-Object System.Collections.ArrayList
    $orgRows = [ordered]@{}

    function Test-ShareSurferPotentialServiceAccount {
        param(
            [string] $ObjectClass = '',
            [string] $ObsPath = '',
            [string] $EmployeeId = '',
            [string] $EmployeeNumber = ''
        )

        $ObjectClass.ToLowerInvariant() -eq 'user' -and
            [string]::IsNullOrWhiteSpace($ObsPath) -and
            [string]::IsNullOrWhiteSpace($EmployeeId) -and
            [string]::IsNullOrWhiteSpace($EmployeeNumber)
    }

    foreach ($existing in @(ConvertTo-ShareSurferArray $Inventory.GroupEdges)) {
        [void]$groupEdges.Add($existing)
    }

    function Add-IdentityRow {
        param(
            [Parameter(Mandatory = $true)]
            [string] $Identity
        )

        $key = $Identity.ToUpperInvariant()
        if ($identityRows.Contains($key)) {
            return
        }

        $entry = $null
        if ($directoryByIdentity.ContainsKey($key)) {
            $entry = $directoryByIdentity[$key]
        }
        elseif ($AdLookupMode -ne 'DirectoryOnly') {
            $entry = Get-ShareSurferDirectoryIdentity -Identity $Identity -ObsAttribute $ObsAttribute -AdLookupMode $AdLookupMode
            if ($null -ne $entry) {
                $directoryByIdentity[$key] = $entry
            }
        }

        $sam = Get-ShareSurferIdentityName -Identity $Identity
        $display = $sam
        $objectClass = 'unknown'
        $employeeId = ''
        $employeeNumber = ''
        $userPrincipalName = ''
        $mail = ''
        $department = ''
        $title = ''
        $company = ''
        $office = ''
        $accountEnabled = ''
        $manager = ''
        $managerLevel1 = ''
        $managerLevel2 = ''
        $managerLevel3 = ''
        $obsPath = ''
        $distinguishedName = ''
        if ($null -ne $entry) {
            foreach ($pair in @(
                @('SamAccountName', 'sam'),
                @('DisplayName', 'display'),
                @('ObjectClass', 'objectClass'),
                @('EmployeeId', 'employeeId'),
                @('EmployeeNumber', 'employeeNumber'),
                @('UserPrincipalName', 'userPrincipalName'),
                @('Mail', 'mail'),
                @('Department', 'department'),
                @('Title', 'title'),
                @('Company', 'company'),
                @('Office', 'office'),
                @('AccountEnabled', 'accountEnabled'),
                @('Manager', 'manager'),
                @('ManagerLevel1', 'managerLevel1'),
                @('ManagerLevel2', 'managerLevel2'),
                @('ManagerLevel3', 'managerLevel3'),
                @('ObsPath', 'obsPath'),
                @('DistinguishedName', 'distinguishedName')
            )) {
                $prop = $entry.PSObject.Properties[$pair[0]]
                if ($null -ne $prop -and $null -ne $prop.Value) {
                    Set-Variable -Name $pair[1] -Value ([string]$prop.Value) -Scope Local
                }
            }
        }

        $row = [pscustomobject]@{
            Identity = $Identity
            SamAccountName = $sam
            DisplayName = $display
            ObjectClass = $objectClass
            EmployeeId = $employeeId
            EmployeeNumber = $employeeNumber
            UserPrincipalName = $userPrincipalName
            Mail = $mail
            Department = $department
            Title = $title
            Company = $company
            Office = $office
            AccountEnabled = $accountEnabled
            Manager = $manager
            ManagerLevel1 = $managerLevel1
            ManagerLevel2 = $managerLevel2
            ManagerLevel3 = $managerLevel3
            ObsPath = $obsPath
            ObsAttribute = $ObsAttribute
            PotentialServiceAccount = Test-ShareSurferPotentialServiceAccount -ObjectClass $objectClass -ObsPath $obsPath -EmployeeId $employeeId -EmployeeNumber $employeeNumber
            DistinguishedName = $distinguishedName
        }
        $identityRows[$key] = $row

        if ($managerLevel1 -ne '' -or $managerLevel2 -ne '' -or $managerLevel3 -ne '' -or $obsPath -ne '' -or $employeeId -ne '' -or $employeeNumber -ne '' -or [bool]$row.PotentialServiceAccount) {
            $orgRows[$key] = [pscustomobject]@{
                Identity = $Identity
                EmployeeId = $employeeId
                EmployeeNumber = $employeeNumber
                Department = $department
                Title = $title
                Company = $company
                Office = $office
                ManagerLevel1 = $managerLevel1
                ManagerLevel2 = $managerLevel2
                ManagerLevel3 = $managerLevel3
                ObsPath = $obsPath
                ObsAttribute = $ObsAttribute
                PotentialServiceAccount = $row.PotentialServiceAccount
            }
        }
    }

    function Expand-Group {
        param(
            [Parameter(Mandatory = $true)]
            [string] $ParentGroup,

            [int] $Depth = 1,

            [string[]] $Seen = @()
        )

        Add-IdentityRow -Identity $ParentGroup
        $key = $ParentGroup.ToUpperInvariant()
        if (-not $directoryByIdentity.ContainsKey($key)) {
            return
        }

        $entry = $directoryByIdentity[$key]
        $membersProperty = $entry.PSObject.Properties['Members']
        if ($null -eq $membersProperty -or $null -eq $membersProperty.Value) {
            return
        }

        foreach ($member in @(ConvertTo-ShareSurferArray $membersProperty.Value)) {
            $memberText = Resolve-ShareSurferMemberIdentity -Member ([string]$member) -DirectoryByDistinguishedName $directoryByDistinguishedName -FallbackDomain (Get-ShareSurferIdentityDomain -Identity $ParentGroup) -ObsAttribute $ObsAttribute
            $memberKey = $memberText.ToUpperInvariant()
            $isCycle = @($Seen | ForEach-Object { $_.ToUpperInvariant() }) -contains $memberKey
            $isTruncated = $Depth -ge $GroupExpansionMaxDepth
            Add-IdentityRow -Identity $memberText

            $childClass = 'unknown'
            if ($directoryByIdentity.ContainsKey($memberKey)) {
                $classProp = $directoryByIdentity[$memberKey].PSObject.Properties['ObjectClass']
                if ($null -ne $classProp -and $null -ne $classProp.Value) {
                    $childClass = [string]$classProp.Value
                }
            }

            [void]$groupEdges.Add([pscustomobject]@{
                ParentGroup = $ParentGroup
                ChildIdentity = $memberText
                ChildObjectClass = $childClass
                Depth = $Depth
                IsCycle = $isCycle
                IsTruncated = $isTruncated
            })

            if (-not $isCycle -and -not $isTruncated -and $childClass -eq 'group') {
                Expand-Group -ParentGroup $memberText -Depth ($Depth + 1) -Seen @($Seen + $ParentGroup)
            }
        }
    }

    $rootIdentities = New-Object System.Collections.ArrayList
    foreach ($permission in @(ConvertTo-ShareSurferArray $Inventory.SharePermissions)) {
        if ($null -ne $permission.PSObject.Properties['Identity'] -and [string]$permission.Identity -ne '') {
            [void]$rootIdentities.Add([string]$permission.Identity)
        }
    }
    foreach ($ace in @(ConvertTo-ShareSurferArray $Inventory.AclEntries)) {
        if ($null -ne $ace.PSObject.Properties['Identity'] -and [string]$ace.Identity -ne '') {
            [void]$rootIdentities.Add([string]$ace.Identity)
        }
    }
    foreach ($identity in @(ConvertTo-ShareSurferArray $Inventory.Identities)) {
        if ($null -ne $identity.PSObject.Properties['Identity'] -and [string]$identity.Identity -ne '') {
            [void]$rootIdentities.Add([string]$identity.Identity)
        }
    }

    foreach ($identity in @($rootIdentities | Select-Object -Unique)) {
        Add-IdentityRow -Identity $identity
        $key = $identity.ToUpperInvariant()
        $class = ''
        if ($directoryByIdentity.ContainsKey($key) -and $null -ne $directoryByIdentity[$key].PSObject.Properties['ObjectClass']) {
            $class = [string]$directoryByIdentity[$key].ObjectClass
        }
        if ($class -eq 'group') {
            Expand-Group -ParentGroup $identity -Seen @()
        }
    }

    [pscustomobject]@{
        Identities = @($identityRows.Values)
        GroupEdges = @($groupEdges)
        OrgChains = @($orgRows.Values)
    }
}
