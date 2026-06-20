function Get-ShareSurferNativeSessionRows {
    param(
        [Parameter(Mandatory = $true)]
        [string] $ComputerName,

        [int] $MaxRows = 100
    )

    $provider = Get-Variable -Name 'ShareSurferNativeSessionProvider' -Scope Global -ErrorAction SilentlyContinue
    if ($null -ne $provider -and $provider.Value -is [scriptblock]) {
        return & $provider.Value -ComputerName $ComputerName -MaxRows $MaxRows
    }

    Initialize-ShareSurferNativeWin32

    $serverName = $null
    if (Test-ShareSurferRemoteComputerName -ComputerName $ComputerName) {
        $serverName = '\\{0}' -f $ComputerName
    }

    $rows = New-Object System.Collections.ArrayList
    $buffer = [IntPtr]::Zero
    $resumeHandle = [UInt32]0
    $entriesRead = [UInt32]0
    $totalEntries = [UInt32]0
    $result = [ShareSurfer.NativeWin32Methods]::NetSessionEnum(
        $serverName,
        $null,
        $null,
        10,
        [ref]$buffer,
        [ShareSurfer.NativeWin32Methods]::MAX_PREFERRED_LENGTH,
        [ref]$entriesRead,
        [ref]$totalEntries,
        [ref]$resumeHandle)

    try {
        if ($result -ne 0) {
            $win32Message = Get-ShareSurferWin32ResultMessage -ResultCode $result
            throw ('NativeSessionEnumerationFailed: NetSessionEnum failed for {0} with Win32 result {1} ({2}). SMB/RPC reachability does not guarantee session enumeration rights.' -f $ComputerName, $result, $win32Message)
        }

        if ($buffer -eq [IntPtr]::Zero -or $entriesRead -eq 0) {
            return @()
        }

        $entrySize = [System.Runtime.InteropServices.Marshal]::SizeOf([type][ShareSurfer.NativeWin32Methods+SESSION_INFO_10])
        for ($index = 0; $index -lt [int]$entriesRead; $index++) {
            if ($rows.Count -ge $MaxRows) {
                break
            }

            $entryPointer = [IntPtr]::Add($buffer, ($index * $entrySize))
            $session = [System.Runtime.InteropServices.Marshal]::PtrToStructure($entryPointer, [type][ShareSurfer.NativeWin32Methods+SESSION_INFO_10])
            [void]$rows.Add([pscustomobject]@{
                ComputerName = $ComputerName
                ClientComputerName = [string]$session.sesi10_cname
                ClientUserName = [string]$session.sesi10_username
                ConnectedSeconds = [int]$session.sesi10_time
                IdleSeconds = [int]$session.sesi10_idle_time
                Source = 'NativeNetSessionEnum'
            })
        }

        @($rows)
    }
    finally {
        if ($buffer -ne [IntPtr]::Zero) {
            [void][ShareSurfer.NativeWin32Methods]::NetApiBufferFree($buffer)
        }
    }
}
