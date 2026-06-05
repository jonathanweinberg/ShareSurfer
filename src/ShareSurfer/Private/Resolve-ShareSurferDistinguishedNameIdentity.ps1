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
        foreach ($property in @('sAMAccountName', 'displayName', 'objectClass', 'employeeID', 'employeeNumber', 'userPrincipalName', 'mail', 'department', 'title', 'company', 'physicalDeliveryOfficeName', 'userAccountControl', 'distinguishedName', 'manager', 'member', $ObsAttribute)) {
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

        $managerLevel1 = Get-ShareSurferLdapPropertyValue -Properties $props -Name 'manager'
        $managerLevel2 = Get-ShareSurferLdapManagerLevel2 -ManagerDistinguishedName $managerLevel1
        New-ShareSurferLdapIdentityRecord -Identity $identity -Properties $props -ObsAttribute $ObsAttribute -Members $members -ManagerLevel2 $managerLevel2 -DistinguishedName $DistinguishedName
    }
    catch {
        $null
    }
}
