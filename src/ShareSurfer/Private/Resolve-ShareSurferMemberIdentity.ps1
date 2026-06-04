function Resolve-ShareSurferMemberIdentity {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Member,

        [Parameter(Mandatory = $true)]
        [hashtable] $DirectoryByDistinguishedName,

        [string] $FallbackDomain = '',

        [string] $ObsAttribute = 'extensionAttribute10'
    )

    if ($Member -notmatch '^CN=') {
        return $Member
    }

    $dnKey = $Member.ToUpperInvariant()
    if ($DirectoryByDistinguishedName.ContainsKey($dnKey)) {
        $entry = $DirectoryByDistinguishedName[$dnKey]
        $identityProp = $entry.PSObject.Properties['Identity']
        if ($null -ne $identityProp -and [string]$identityProp.Value -ne '') {
            return [string]$identityProp.Value
        }

        $samProp = $entry.PSObject.Properties['SamAccountName']
        if ($null -ne $samProp -and [string]$samProp.Value -ne '') {
            if ($FallbackDomain -ne '') {
                return ('{0}\{1}' -f $FallbackDomain, [string]$samProp.Value)
            }
            return [string]$samProp.Value
        }
    }

    $resolved = Resolve-ShareSurferDistinguishedNameIdentity -DistinguishedName $Member -FallbackDomain $FallbackDomain -ObsAttribute $ObsAttribute
    if ($null -ne $resolved) {
        $DirectoryByDistinguishedName[$dnKey] = $resolved
        return [string]$resolved.Identity
    }

    ConvertFrom-ShareSurferDistinguishedName -DistinguishedName $Member -FallbackDomain $FallbackDomain
}
