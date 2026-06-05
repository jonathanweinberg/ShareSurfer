function Get-ShareSurferLdapPropertyValues {
    param(
        [Parameter(Mandatory = $true)]
        $Properties,

        [Parameter(Mandatory = $true)]
        [string] $Name
    )

    $values = New-Object System.Collections.ArrayList
    foreach ($key in @($Name, $Name.ToLowerInvariant(), $Name.ToUpperInvariant())) {
        $rawValue = $null
        if ($Properties -is [hashtable]) {
            if (-not $Properties.ContainsKey($key)) {
                continue
            }
            $rawValue = $Properties[$key]
        }
        else {
            try {
                $rawValue = $Properties[$key]
            }
            catch {
                $rawValue = $null
            }
        }

        foreach ($value in @(ConvertTo-ShareSurferArray $rawValue)) {
            $text = [string]$value
            if ($text -ne '') {
                [void]$values.Add($text)
            }
        }

        if ($values.Count -gt 0) {
            break
        }
    }

    @($values)
}

function Get-ShareSurferLdapPropertyValue {
    param(
        [Parameter(Mandatory = $true)]
        $Properties,

        [Parameter(Mandatory = $true)]
        [string] $Name
    )

    $values = @(Get-ShareSurferLdapPropertyValues -Properties $Properties -Name $Name)
    if ($values.Count -eq 0) {
        return ''
    }

    [string]$values[0]
}

function Get-ShareSurferLdapManagerLevel2 {
    param(
        [string] $ManagerDistinguishedName = ''
    )

    if ([string]::IsNullOrWhiteSpace($ManagerDistinguishedName)) {
        return ''
    }

    try {
        $searcher = New-Object System.DirectoryServices.DirectorySearcher
        $escapedDn = $ManagerDistinguishedName.Replace('\', '\5c').Replace('(', '\28').Replace(')', '\29')
        $searcher.Filter = "(distinguishedName=$escapedDn)"
        [void]$searcher.PropertiesToLoad.Add('manager')
        $result = $searcher.FindOne()
        if ($null -eq $result) {
            return ''
        }

        Get-ShareSurferLdapPropertyValue -Properties $result.Properties -Name 'manager'
    }
    catch {
        ''
    }
}

function New-ShareSurferLdapIdentityRecord {
    param(
        [string] $Identity = '',

        [Parameter(Mandatory = $true)]
        $Properties,

        [string] $FallbackDomain = '',

        [string] $ObsAttribute = 'extensionAttribute10',

        [string[]] $Members = @(),

        [string] $ManagerLevel2 = '',

        [string] $DistinguishedName = ''
    )

    $sam = Get-ShareSurferLdapPropertyValue -Properties $Properties -Name 'sAMAccountName'
    if ($sam -eq '') {
        return $null
    }

    if ($Identity -eq '') {
        $Identity = if ($FallbackDomain -ne '') { '{0}\{1}' -f $FallbackDomain, $sam } else { $sam }
    }

    $objectClasses = @(Get-ShareSurferLdapPropertyValues -Properties $Properties -Name 'objectClass')
    $objectClass = if ($objectClasses -contains 'group') { 'group' } else { 'user' }
    $managerLevel1 = Get-ShareSurferLdapPropertyValue -Properties $Properties -Name 'manager'

    [pscustomobject]@{
        Identity = $Identity
        SamAccountName = $sam
        DisplayName = Get-ShareSurferLdapPropertyValue -Properties $Properties -Name 'displayName'
        ObjectClass = $objectClass
        EmployeeId = Get-ShareSurferLdapPropertyValue -Properties $Properties -Name 'employeeID'
        EmployeeNumber = Get-ShareSurferLdapPropertyValue -Properties $Properties -Name 'employeeNumber'
        Manager = $managerLevel1
        ManagerLevel1 = $managerLevel1
        ManagerLevel2 = $ManagerLevel2
        ObsPath = Get-ShareSurferLdapPropertyValue -Properties $Properties -Name $ObsAttribute
        ObsAttribute = $ObsAttribute
        Members = @($Members)
        DistinguishedName = $DistinguishedName
    }
}
