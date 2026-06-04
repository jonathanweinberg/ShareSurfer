function ConvertFrom-ShareSurferDistinguishedName {
    param(
        [Parameter(Mandatory = $true)]
        [string] $DistinguishedName,

        [string] $FallbackDomain = ''
    )

    $commonName = ''
    if ($DistinguishedName -match 'CN=([^,]+)') {
        $commonName = $matches[1] -replace '\\,', ','
    }

    if ($commonName -eq '') {
        return $DistinguishedName
    }

    if ($FallbackDomain -ne '') {
        return ('{0}\{1}' -f $FallbackDomain, $commonName)
    }

    $commonName
}
