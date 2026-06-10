function Get-ShareSurferSmbRpcShareInfo {
    param(
        [Parameter(Mandatory = $true)]
        [string] $ComputerName,

        [Parameter(Mandatory = $true)]
        [string] $ShareName
    )

    $provider = Get-Variable -Name 'ShareSurferSmbRpcShareInfoProvider' -Scope Global -ErrorAction SilentlyContinue
    if ($null -ne $provider -and $provider.Value -is [scriptblock]) {
        return & $provider.Value -ComputerName $ComputerName -ShareName $ShareName
    }

    if (-not (Test-ShareSurferIsWindows)) {
        return $null
    }

    if ($null -eq ('ShareSurfer.NetApi32' -as [type])) {
        Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

namespace ShareSurfer
{
    public static class NetApi32
    {
        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        public struct SHARE_INFO_2
        {
            public string shi2_netname;
            public UInt32 shi2_type;
            public string shi2_remark;
            public UInt32 shi2_permissions;
            public UInt32 shi2_max_uses;
            public UInt32 shi2_current_uses;
            public string shi2_path;
            public string shi2_passwd;
        }

        [DllImport("Netapi32.dll", CharSet = CharSet.Unicode)]
        public static extern int NetShareGetInfo(string servername, string netname, int level, out IntPtr bufptr);

        [DllImport("Netapi32.dll")]
        public static extern int NetApiBufferFree(IntPtr Buffer);
    }
}
"@
    }

    $serverName = $null
    if (Test-ShareSurferRemoteComputerName -ComputerName $ComputerName) {
        $serverName = '\\{0}' -f $ComputerName
    }

    $buffer = [IntPtr]::Zero
    $result = [ShareSurfer.NetApi32]::NetShareGetInfo($serverName, $ShareName, 2, [ref]$buffer)
    try {
        if ($result -ne 0 -or $buffer -eq [IntPtr]::Zero) {
            return $null
        }

        $info = [System.Runtime.InteropServices.Marshal]::PtrToStructure($buffer, [type][ShareSurfer.NetApi32+SHARE_INFO_2])
        [pscustomobject]@{
            ShareName = [string]$info.shi2_netname
            Path = [string]$info.shi2_path
            Description = [string]$info.shi2_remark
            Source = 'SmbRpcNetShareGetInfo'
            ResultCode = $result
        }
    }
    finally {
        if ($buffer -ne [IntPtr]::Zero) {
            [void][ShareSurfer.NetApi32]::NetApiBufferFree($buffer)
        }
    }
}
