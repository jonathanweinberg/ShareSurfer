function Get-ShareSurferWin32ResultMessage {
    param(
        [uint32] $ResultCode
    )

    try {
        $message = [System.ComponentModel.Win32Exception]::new([int]$ResultCode).Message
        if (-not [string]::IsNullOrWhiteSpace($message)) {
            return $message
        }
    }
    catch {
    }

    'Unknown Win32 error'
}

function Get-ShareSurferNativeSecurityErrorInfo {
    param(
        [Parameter(Mandatory = $true)]
        $Exception,

        [string] $DefaultDetail = ''
    )

    $message = [string]$Exception.Message
    $errorType = 'AclReadError'
    $detail = $DefaultDetail

    if ($message -like 'NativeSecurityDescriptorReadFailed:*') {
        $errorType = 'NativeSecurityDescriptorReadFailed'
        $detail = 'SMB/RPC or UNC enumeration can be reachable while the account still cannot read owner/DACL security descriptor data. Check READ_CONTROL access, elevation/admin token, protected folders, and Samba/NT ACL compatibility.'
    }
    elseif ($message -like 'NativeSecurityDescriptorUnavailable:*') {
        $errorType = 'NativeSecurityDescriptorUnavailable'
        $detail = 'Windows returned no usable owner/DACL security descriptor for this object. Treat this item as partial evidence and confirm whether the target exposes Windows-compatible security descriptors.'
    }
    elseif ($message -like 'NativeSecurityDescriptorParseFailed:*') {
        $errorType = 'NativeSecurityDescriptorParseFailed'
        $detail = 'A security descriptor was returned, but ShareSurfer could not parse it into normalized ACL rows. This can happen with malformed or non-Windows-compatible descriptor data.'
    }

    if ([string]::IsNullOrWhiteSpace($detail)) {
        $detail = 'Native Win32 owner/DACL read failed.'
    }

    [pscustomobject]@{
        ErrorType = $errorType
        Message = $message
        Detail = $detail
    }
}
