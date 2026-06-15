function Get-ShareSurferDirectoryOrganizationalUnits {
    [CmdletBinding()]
    param(
        [ValidateSet('Auto', 'ActiveDirectory', 'Ldap', 'DirectoryOnly')]
        [string] $AdLookupMode = 'Auto'
    )

    if ($AdLookupMode -eq 'DirectoryOnly') {
        return @()
    }

    $getAdOrganizationalUnit = Get-Command Get-ADOrganizationalUnit -ErrorAction SilentlyContinue
    if ($AdLookupMode -ne 'Ldap' -and $null -ne $getAdOrganizationalUnit) {
        try {
            return @(Get-ADOrganizationalUnit -Filter * -Properties distinguishedName,canonicalName -ErrorAction Stop | ForEach-Object {
                $dn = [string]$_.DistinguishedName
                [pscustomobject]@{
                    Name = [string]$_.Name
                    DistinguishedName = $dn
                    CanonicalName = if ($_.PSObject.Properties['CanonicalName']) { [string]$_.CanonicalName } else { '' }
                    Depth = @($dn -split ',OU=').Count - 1
                }
            } | Sort-Object CanonicalName, DistinguishedName)
        }
        catch {
            if ($AdLookupMode -eq 'ActiveDirectory') {
                return @()
            }
        }
    }

    if ($AdLookupMode -eq 'ActiveDirectory') {
        return @()
    }

    try {
        $searcher = New-Object System.DirectoryServices.DirectorySearcher
        $searcher.Filter = '(objectClass=organizationalUnit)'
        [void]$searcher.PropertiesToLoad.Add('name')
        [void]$searcher.PropertiesToLoad.Add('distinguishedName')
        [void]$searcher.PropertiesToLoad.Add('canonicalName')
        $results = $searcher.FindAll()
        try {
            return @($results | ForEach-Object {
                $dn = Get-ShareSurferLdapPropertyValue -Properties $_.Properties -Name 'distinguishedName'
                [pscustomobject]@{
                    Name = Get-ShareSurferLdapPropertyValue -Properties $_.Properties -Name 'name'
                    DistinguishedName = $dn
                    CanonicalName = Get-ShareSurferLdapPropertyValue -Properties $_.Properties -Name 'canonicalName'
                    Depth = @($dn -split ',OU=').Count - 1
                }
            } | Sort-Object CanonicalName, DistinguishedName)
        }
        finally {
            if ($null -ne $results) {
                $results.Dispose()
            }
        }
    }
    catch {
        @()
    }
}
