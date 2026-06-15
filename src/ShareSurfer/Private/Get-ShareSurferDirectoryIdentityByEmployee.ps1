function Get-ShareSurferDirectoryIdentityByEmployee {
    [CmdletBinding()]
    param(
        [string] $EmployeeId = '',

        [string] $EmployeeNumber = '',

        [string] $ObsAttribute = 'extensionAttribute10',

        [ValidateSet('Auto', 'ActiveDirectory', 'Ldap', 'DirectoryOnly')]
        [string] $AdLookupMode = 'Auto',

        [string[]] $ForbiddenOu = @()
    )

    if ($AdLookupMode -eq 'DirectoryOnly') {
        return New-ShareSurferEmployeeLookupResult -Status 'NotSearched' -MatchMethod '' -Message 'AD lookup mode was DirectoryOnly.'
    }

    $filter = New-ShareSurferEmployeeLookupFilter -EmployeeId $EmployeeId -EmployeeNumber $EmployeeNumber
    if ([string]::IsNullOrWhiteSpace($filter)) {
        return New-ShareSurferEmployeeLookupResult -Status 'SourceOnly' -MatchMethod '' -Message 'No employeeID or employeeNumber value was available for directory matching.'
    }

    $records = @()
    $getAdUser = Get-Command Get-ADUser -ErrorAction SilentlyContinue
    if ($AdLookupMode -ne 'Ldap' -and $null -ne $getAdUser) {
        try {
            $records = @(Find-ShareSurferAdUsersByEmployeeFilter -LDAPFilter $filter -ObsAttribute $ObsAttribute)
        }
        catch {
            if ($AdLookupMode -eq 'ActiveDirectory') {
                return New-ShareSurferEmployeeLookupResult -Status 'LookupFailed' -MatchMethod 'EmployeeId' -Message $_.Exception.Message
            }
        }
    }

    if ($records.Count -eq 0 -and $AdLookupMode -ne 'ActiveDirectory') {
        try {
            $records = @(Find-ShareSurferLdapUsersByEmployeeFilter -LDAPFilter $filter -ObsAttribute $ObsAttribute)
        }
        catch {
            return New-ShareSurferEmployeeLookupResult -Status 'LookupFailed' -MatchMethod 'EmployeeId' -Message $_.Exception.Message
        }
    }

    if ($records.Count -eq 0) {
        return New-ShareSurferEmployeeLookupResult -Status 'NotFound' -MatchMethod 'EmployeeId' -Message 'No AD account matched the supplied employee identifier.'
    }

    $allowedRecords = New-Object System.Collections.ArrayList
    $forbiddenMatches = New-Object System.Collections.ArrayList
    foreach ($record in $records) {
        $dn = ''
        if ($null -ne $record.PSObject.Properties['DistinguishedName']) {
            $dn = [string]$record.DistinguishedName
        }

        $matchedForbiddenOu = Get-ShareSurferMatchedForbiddenOu -DistinguishedName $dn -ForbiddenOu $ForbiddenOu
        if (-not [string]::IsNullOrWhiteSpace($matchedForbiddenOu)) {
            [void]$forbiddenMatches.Add($matchedForbiddenOu)
            continue
        }

        [void]$allowedRecords.Add($record)
    }

    if ($allowedRecords.Count -eq 0) {
        return New-ShareSurferEmployeeLookupResult -Status 'ForbiddenOuSkipped' -MatchMethod 'EmployeeId' -ForbiddenOuMatched ((@($forbiddenMatches) | Select-Object -Unique) -join '; ') -Message 'All matching AD accounts were under a forbidden OU.'
    }

    if ($allowedRecords.Count -gt 1) {
        return New-ShareSurferEmployeeLookupResult -Status 'Ambiguous' -MatchMethod 'EmployeeId' -IdentityRecord $null -ForbiddenOuMatched ((@($forbiddenMatches) | Select-Object -Unique) -join '; ') -Message ('Multiple non-forbidden AD accounts matched the supplied employee identifier: {0}' -f $allowedRecords.Count)
    }

    New-ShareSurferEmployeeLookupResult -Status 'Matched' -MatchMethod 'EmployeeId' -IdentityRecord $allowedRecords[0] -ForbiddenOuMatched ((@($forbiddenMatches) | Select-Object -Unique) -join '; ') -Message ''
}

function New-ShareSurferEmployeeLookupResult {
    param(
        [string] $Status = '',

        [string] $MatchMethod = '',

        $IdentityRecord = $null,

        [string] $ForbiddenOuMatched = '',

        [string] $Message = ''
    )

    [pscustomobject]@{
        Status = $Status
        MatchMethod = $MatchMethod
        IdentityRecord = $IdentityRecord
        ForbiddenOuMatched = $ForbiddenOuMatched
        Message = $Message
    }
}

function New-ShareSurferEmployeeLookupFilter {
    param(
        [string] $EmployeeId = '',

        [string] $EmployeeNumber = ''
    )

    $parts = New-Object System.Collections.Generic.List[string]
    if (-not [string]::IsNullOrWhiteSpace($EmployeeId)) {
        $parts.Add(('(employeeID={0})' -f (Escape-ShareSurferLdapFilterValue -Value $EmployeeId)))
    }
    if (-not [string]::IsNullOrWhiteSpace($EmployeeNumber)) {
        $parts.Add(('(employeeNumber={0})' -f (Escape-ShareSurferLdapFilterValue -Value $EmployeeNumber)))
    }

    if ($parts.Count -eq 0) {
        return ''
    }
    if ($parts.Count -eq 1) {
        return [string]$parts[0]
    }

    '(|{0})' -f (@($parts) -join '')
}

function Escape-ShareSurferLdapFilterValue {
    param(
        [AllowNull()]
        [string] $Value
    )

    if ($null -eq $Value) {
        return ''
    }

    ([string]$Value).Replace('\', '\5c').Replace('*', '\2a').Replace('(', '\28').Replace(')', '\29').Replace([string][char]0, '\00')
}

function Find-ShareSurferAdUsersByEmployeeFilter {
    param(
        [Parameter(Mandatory = $true)]
        [string] $LDAPFilter,

        [string] $ObsAttribute = 'extensionAttribute10'
    )

    $properties = @('employeeID', 'employeeNumber', 'manager', 'displayName', 'userPrincipalName', 'mail', 'department', 'title', 'company', 'physicalDeliveryOfficeName', 'distinguishedName', 'samAccountName', 'enabled', $ObsAttribute)
    $optionalProperties = @('employeeNumber', $ObsAttribute)
    $users = @(Invoke-ShareSurferAdUserSearchWithOptionalProperties -LDAPFilter $LDAPFilter -Properties $properties -OptionalProperties $optionalProperties)
    foreach ($user in $users) {
        $managerChain = @(Get-ShareSurferAdManagerChain -ManagerReference ([string]$user.Manager) -MaxDepth 3)
        [pscustomobject]@{
            Identity = [string]$user.SamAccountName
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
            ManagerLevel1 = if ($managerChain.Count -ge 1) { [string]$managerChain[0] } else { '' }
            ManagerLevel2 = if ($managerChain.Count -ge 2) { [string]$managerChain[1] } else { '' }
            ManagerLevel3 = if ($managerChain.Count -ge 3) { [string]$managerChain[2] } else { '' }
            ObsPath = Get-ShareSurferAdObjectPropertyValue -Object $user -Name $ObsAttribute
            ObsAttribute = $ObsAttribute
            Members = @()
            DistinguishedName = [string]$user.DistinguishedName
        }
    }
}

function Invoke-ShareSurferAdUserSearchWithOptionalProperties {
    param(
        [Parameter(Mandatory = $true)]
        [string] $LDAPFilter,

        [string[]] $Properties = @(),

        [string[]] $OptionalProperties = @()
    )

    $remainingProperties = @($Properties | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    $remainingOptional = @($OptionalProperties | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    while ($true) {
        try {
            if ($remainingProperties.Count -gt 0) {
                return @(Get-ADUser -LDAPFilter $LDAPFilter -Properties $remainingProperties -ErrorAction Stop)
            }

            return @(Get-ADUser -LDAPFilter $LDAPFilter -ErrorAction Stop)
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

function Find-ShareSurferLdapUsersByEmployeeFilter {
    param(
        [Parameter(Mandatory = $true)]
        [string] $LDAPFilter,

        [string] $ObsAttribute = 'extensionAttribute10'
    )

    $searcher = New-Object System.DirectoryServices.DirectorySearcher
    $searcher.Filter = "(&(objectClass=user)$LDAPFilter)"
    foreach ($property in @('sAMAccountName', 'displayName', 'objectClass', 'employeeID', 'employeeNumber', 'userPrincipalName', 'mail', 'department', 'title', 'company', 'physicalDeliveryOfficeName', 'userAccountControl', 'distinguishedName', 'manager', $ObsAttribute)) {
        [void]$searcher.PropertiesToLoad.Add($property)
    }
    $results = $searcher.FindAll()
    try {
        foreach ($result in $results) {
            $props = $result.Properties
            $managerChain = @(Get-ShareSurferLdapManagerChain -ManagerDistinguishedName (Get-ShareSurferLdapPropertyValue -Properties $props -Name 'manager') -MaxDepth 3)
            $managerLevel2 = if ($managerChain.Count -ge 2) { [string]$managerChain[1] } else { '' }
            $managerLevel3 = if ($managerChain.Count -ge 3) { [string]$managerChain[2] } else { '' }
            New-ShareSurferLdapIdentityRecord -Properties $props -ObsAttribute $ObsAttribute -ManagerLevel2 $managerLevel2 -ManagerLevel3 $managerLevel3
        }
    }
    finally {
        if ($null -ne $results) {
            $results.Dispose()
        }
    }
}

function Get-ShareSurferMatchedForbiddenOu {
    param(
        [string] $DistinguishedName = '',

        [string[]] $ForbiddenOu = @()
    )

    if ([string]::IsNullOrWhiteSpace($DistinguishedName)) {
        return ''
    }

    $normalizedDn = Normalize-ShareSurferDistinguishedNameForCompare -DistinguishedName $DistinguishedName
    foreach ($ou in @($ForbiddenOu)) {
        if ([string]::IsNullOrWhiteSpace($ou)) {
            continue
        }

        $normalizedOu = Normalize-ShareSurferDistinguishedNameForCompare -DistinguishedName $ou
        if ($normalizedDn -eq $normalizedOu -or $normalizedDn.EndsWith(',' + $normalizedOu)) {
            return [string]$ou
        }
    }

    ''
}

function Normalize-ShareSurferDistinguishedNameForCompare {
    param(
        [string] $DistinguishedName = ''
    )

    ([string]$DistinguishedName).Trim().ToUpperInvariant()
}
