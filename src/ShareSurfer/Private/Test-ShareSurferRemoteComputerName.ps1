function Test-ShareSurferRemoteComputerName {
    param(
        [string] $ComputerName = ''
    )

    if ([string]::IsNullOrWhiteSpace($ComputerName)) {
        return $false
    }

    $normalized = $ComputerName.Trim().TrimEnd('.')
    $localNames = @(
        [System.Environment]::MachineName,
        $env:COMPUTERNAME,
        'localhost',
        '127.0.0.1',
        '::1'
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) }

    try {
        $dnsHostName = [System.Net.Dns]::GetHostName()
        if (-not [string]::IsNullOrWhiteSpace($dnsHostName)) {
            $localNames += $dnsHostName
        }

        $hostEntry = [System.Net.Dns]::GetHostEntry($dnsHostName)
        if ($null -ne $hostEntry) {
            if (-not [string]::IsNullOrWhiteSpace([string]$hostEntry.HostName)) {
                $localNames += [string]$hostEntry.HostName
            }
            foreach ($alias in @($hostEntry.Aliases)) {
                if (-not [string]::IsNullOrWhiteSpace([string]$alias)) {
                    $localNames += [string]$alias
                }
            }
            foreach ($address in @($hostEntry.AddressList)) {
                if ($null -ne $address) {
                    $localNames += [string]$address.IPAddressToString
                }
            }
        }
    }
    catch {
        # DNS enumeration is a best-effort local alias hint. Basic local names above remain authoritative.
    }

    foreach ($localName in @($localNames | Select-Object -Unique)) {
        $candidate = ([string]$localName).Trim().TrimEnd('.')
        if ($normalized.Equals($candidate, [System.StringComparison]::OrdinalIgnoreCase)) {
            return $false
        }
    }

    $true
}
