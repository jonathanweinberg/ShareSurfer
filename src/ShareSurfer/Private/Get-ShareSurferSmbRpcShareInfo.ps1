function Get-ShareSurferSmbRpcShareInfo {
    param(
        [Parameter(Mandatory = $true)]
        [string] $ComputerName,

        [Parameter(Mandatory = $true)]
        [string] $ShareName,

        [switch] $PreferSecurityDescriptor
    )

    $provider = Get-Variable -Name 'ShareSurferSmbRpcShareInfoProvider' -Scope Global -ErrorAction SilentlyContinue
    if ($null -ne $provider -and $provider.Value -is [scriptblock]) {
        return & $provider.Value -ComputerName $ComputerName -ShareName $ShareName
    }

    Initialize-ShareSurferNativeWin32

    $serverName = $null
    if (Test-ShareSurferRemoteComputerName -ComputerName $ComputerName) {
        $serverName = '\\{0}' -f $ComputerName
    }

    $buffer = [IntPtr]::Zero
    $result = [ShareSurfer.NativeWin32Methods]::NetShareGetInfo($serverName, $ShareName, 502, [ref]$buffer)
    try {
        if ($result -eq 0 -and $buffer -ne [IntPtr]::Zero) {
            $info502 = [System.Runtime.InteropServices.Marshal]::PtrToStructure($buffer, [type][ShareSurfer.NativeWin32Methods+SHARE_INFO_502])
            $securityDescriptorBytes = @()
            if ($info502.shi502_security_descriptor -ne [IntPtr]::Zero) {
                $securityDescriptorBytes = [byte[]](ConvertTo-ShareSurferSecurityDescriptorBytes -SecurityDescriptor $info502.shi502_security_descriptor)
            }

            return [pscustomobject]@{
                ShareName = [string]$info502.shi502_netname
                Path = [string]$info502.shi502_path
                Description = [string]$info502.shi502_remark
                Source = 'SmbRpcNetShareGetInfo'
                ResultCode = $result
                Level = 502
                SecurityDescriptorBytes = $securityDescriptorBytes
            }
        }
    }
    finally {
        if ($buffer -ne [IntPtr]::Zero) {
            [void][ShareSurfer.NativeWin32Methods]::NetApiBufferFree($buffer)
            $buffer = [IntPtr]::Zero
        }
    }

    $result = [ShareSurfer.NativeWin32Methods]::NetShareGetInfo($serverName, $ShareName, 2, [ref]$buffer)
    try {
        if ($result -ne 0 -or $buffer -eq [IntPtr]::Zero) {
            return $null
        }

        $info2 = [System.Runtime.InteropServices.Marshal]::PtrToStructure($buffer, [type][ShareSurfer.NativeWin32Methods+SHARE_INFO_2])
        [pscustomobject]@{
            ShareName = [string]$info2.shi2_netname
            Path = [string]$info2.shi2_path
            Description = [string]$info2.shi2_remark
            Source = 'SmbRpcNetShareGetInfo'
            ResultCode = $result
            Level = 2
            SecurityDescriptorBytes = @()
        }
    }
    finally {
        if ($buffer -ne [IntPtr]::Zero) {
            [void][ShareSurfer.NativeWin32Methods]::NetApiBufferFree($buffer)
        }
    }
}
