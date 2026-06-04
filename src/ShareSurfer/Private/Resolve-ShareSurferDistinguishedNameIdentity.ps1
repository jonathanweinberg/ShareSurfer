function Resolve-ShareSurferDistinguishedNameIdentity {
    param(
        [Parameter(Mandatory = $true)]
        [string] $DistinguishedName,

        [string] $FallbackDomain = '',

        [string] $ObsAttribute = 'extensionAttribute10'
    )

    try {
        $searcher = New-Object System.DirectoryServices.DirectorySearcher
        $escapedDn = $DistinguishedName.Replace('\', '\5c').Replace('(', '\28').Replace(')', '\29')
        $searcher.Filter = "(distinguishedName=$escapedDn)"
        foreach ($property in @('sAMAccountName', 'displayName', 'objectClass', 'employeeID', 'employeeNumber', 'manager', 'member', $ObsAttribute)) {
            [void]$searcher.PropertiesToLoad.Add($property)
        }

        $result = $searcher.FindOne()
        if ($null -eq $result) {
            return $null
        }

        $props = $result.Properties
        $sam = [string]$props['samaccountname'][0]
        if ($sam -eq '') {
            return $null
        }

        $identity = if ($FallbackDomain -ne '') { '{0}\{1}' -f $FallbackDomain, $sam } else { $sam }
        $objectClasses = @($props['objectclass'] | ForEach-Object { [string]$_ })
        $objectClass = if ($objectClasses -contains 'group') { 'group' } else { 'user' }
        $members = @()
        if ($objectClass -eq 'group') {
            $members = @($props['member'] | ForEach-Object { [string]$_ })
        }

        [pscustomobject]@{
            Identity = $identity
            SamAccountName = $sam
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
            DistinguishedName = $DistinguishedName
        }
    }
    catch {
        $null
    }
}
