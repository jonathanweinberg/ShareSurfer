function Initialize-ShareSurferNativeWin32 {
    if (-not (Test-ShareSurferIsWindows)) {
        throw 'The native SMB/RPC provider requires Windows.'
    }

    if ($null -ne ('ShareSurfer.NativeWin32Methods' -as [type])) {
        return
    }

    Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

namespace ShareSurfer
{
    public static class NativeWin32Methods
    {
        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        public struct SHARE_INFO_2
        {
            [MarshalAs(UnmanagedType.LPWStr)]
            public string shi2_netname;
            public UInt32 shi2_type;
            [MarshalAs(UnmanagedType.LPWStr)]
            public string shi2_remark;
            public UInt32 shi2_permissions;
            public UInt32 shi2_max_uses;
            public UInt32 shi2_current_uses;
            [MarshalAs(UnmanagedType.LPWStr)]
            public string shi2_path;
            [MarshalAs(UnmanagedType.LPWStr)]
            public string shi2_passwd;
        }

        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        public struct SHARE_INFO_502
        {
            [MarshalAs(UnmanagedType.LPWStr)]
            public string shi502_netname;
            public UInt32 shi502_type;
            [MarshalAs(UnmanagedType.LPWStr)]
            public string shi502_remark;
            public UInt32 shi502_permissions;
            public UInt32 shi502_max_uses;
            public UInt32 shi502_current_uses;
            [MarshalAs(UnmanagedType.LPWStr)]
            public string shi502_path;
            [MarshalAs(UnmanagedType.LPWStr)]
            public string shi502_passwd;
            public UInt32 shi502_reserved;
            public IntPtr shi502_security_descriptor;
        }

        public enum SE_OBJECT_TYPE
        {
            SE_UNKNOWN_OBJECT_TYPE = 0,
            SE_FILE_OBJECT = 1
        }

        public const UInt32 OWNER_SECURITY_INFORMATION = 0x00000001;
        public const UInt32 DACL_SECURITY_INFORMATION = 0x00000004;

        [DllImport("Netapi32.dll", CharSet = CharSet.Unicode)]
        public static extern Int32 NetShareGetInfo(string servername, string netname, Int32 level, out IntPtr bufptr);

        [DllImport("Netapi32.dll")]
        public static extern Int32 NetApiBufferFree(IntPtr Buffer);

        [DllImport("Advapi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        public static extern UInt32 GetNamedSecurityInfo(
            string pObjectName,
            SE_OBJECT_TYPE ObjectType,
            UInt32 SecurityInfo,
            out IntPtr ppsidOwner,
            out IntPtr ppsidGroup,
            out IntPtr ppDacl,
            out IntPtr ppSacl,
            out IntPtr ppSecurityDescriptor);

        [DllImport("Advapi32.dll", SetLastError = true)]
        public static extern UInt32 GetSecurityDescriptorLength(IntPtr pSecurityDescriptor);

        [DllImport("Kernel32.dll")]
        public static extern IntPtr LocalFree(IntPtr hMem);
    }
}
"@
}
