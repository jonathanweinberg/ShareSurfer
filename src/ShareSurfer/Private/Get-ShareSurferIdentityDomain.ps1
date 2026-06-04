function Get-ShareSurferIdentityDomain {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Identity
    )

    if ($Identity -match '\\') {
        return ($Identity -split '\\')[0]
    }

    if ($env:USERDOMAIN) {
        return $env:USERDOMAIN
    }

    ''
}
