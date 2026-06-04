function Get-ShareSurferIdentityName {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Identity
    )

    if ($Identity -match '\\') {
        return ($Identity -split '\\')[-1]
    }

    $Identity
}
