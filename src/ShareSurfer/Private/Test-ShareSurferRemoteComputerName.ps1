function Test-ShareSurferRemoteComputerName {
    param(
        [string] $ComputerName = ''
    )

    if ([string]::IsNullOrWhiteSpace($ComputerName)) {
        return $false
    }

    $normalized = $ComputerName.Trim()
    $localNames = @(
        [System.Environment]::MachineName,
        $env:COMPUTERNAME,
        'localhost',
        '127.0.0.1',
        '::1'
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) }

    foreach ($localName in $localNames) {
        if ($normalized.Equals([string]$localName, [System.StringComparison]::OrdinalIgnoreCase)) {
            return $false
        }
    }

    $true
}
