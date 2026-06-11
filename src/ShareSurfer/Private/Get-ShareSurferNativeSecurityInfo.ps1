function Get-ShareSurferNativeSecurityInfo {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Path,

        [string] $ShareId = '',
        [string] $ItemId = '',
        [string] $FullPath = '',
        [int] $Depth = 0
    )

    $provider = Get-Variable -Name 'ShareSurferNativeSecurityInfoProvider' -Scope Global -ErrorAction SilentlyContinue
    if ($null -ne $provider -and $provider.Value -is [scriptblock]) {
        return & $provider.Value -Path $Path -ShareId $ShareId -ItemId $ItemId -FullPath $FullPath -Depth $Depth
    }

    Initialize-ShareSurferNativeWin32

    $ownerSid = [IntPtr]::Zero
    $groupSid = [IntPtr]::Zero
    $dacl = [IntPtr]::Zero
    $sacl = [IntPtr]::Zero
    $securityDescriptor = [IntPtr]::Zero
    $securityInfo = [ShareSurfer.NativeWin32Methods]::OWNER_SECURITY_INFORMATION -bor [ShareSurfer.NativeWin32Methods]::DACL_SECURITY_INFORMATION
    $nativePath = ConvertTo-ShareSurferFilesystemPath -Path $Path

    $result = [ShareSurfer.NativeWin32Methods]::GetNamedSecurityInfo(
        $nativePath,
        [ShareSurfer.NativeWin32Methods+SE_OBJECT_TYPE]::SE_FILE_OBJECT,
        $securityInfo,
        [ref]$ownerSid,
        [ref]$groupSid,
        [ref]$dacl,
        [ref]$sacl,
        [ref]$securityDescriptor)

    try {
        if ($result -ne 0) {
            $win32Message = Get-ShareSurferWin32ResultMessage -ResultCode $result
            throw ('NativeSecurityDescriptorReadFailed: GetNamedSecurityInfoW failed for {0} with Win32 result {1} ({2}). SMB/RPC reachability does not guarantee readable owner/DACL security descriptor evidence.' -f $nativePath, $result, $win32Message)
        }

        if ($securityDescriptor -eq [IntPtr]::Zero) {
            throw ('NativeSecurityDescriptorUnavailable: GetNamedSecurityInfoW returned an empty security descriptor for {0}.' -f $nativePath)
        }

        $bytes = [byte[]](ConvertTo-ShareSurferSecurityDescriptorBytes -SecurityDescriptor $securityDescriptor)
        try {
            $rawDescriptor = ConvertTo-ShareSurferRawSecurityDescriptor -SecurityDescriptorBytes $bytes
        }
        catch {
            throw ('NativeSecurityDescriptorParseFailed: GetNamedSecurityInfoW returned security descriptor bytes for {0}, but they could not be parsed. {1}' -f $nativePath, [string]$_.Exception.Message)
        }
        if ($null -eq $rawDescriptor) {
            throw ('NativeSecurityDescriptorUnavailable: GetNamedSecurityInfoW returned empty security descriptor bytes for {0}.' -f $nativePath)
        }

        $owner = ConvertTo-ShareSurferIdentityReference -SecurityIdentifier $rawDescriptor.Owner
        $inheritanceEnabled = (($rawDescriptor.ControlFlags -band [System.Security.AccessControl.ControlFlags]::DiscretionaryAclProtected) -eq 0)
        $displayPath = if ([string]::IsNullOrWhiteSpace($FullPath)) { ConvertFrom-ShareSurferFilesystemPath -Path $Path } else { $FullPath }
        $aclRows = @(ConvertTo-ShareSurferSecurityDescriptorAclRows -RawSecurityDescriptor $rawDescriptor -PermissionKind FileSystem -ShareId $ShareId -ItemId $ItemId -FullPath $displayPath -Depth $Depth)

        [pscustomobject]@{
            Owner = $owner
            InheritanceEnabled = [bool]$inheritanceEnabled
            InheritanceBrokenAt = if ($inheritanceEnabled) { '' } else { $displayPath }
            AclEntries = $aclRows
            Source = 'NativeWin32Security'
        }
    }
    finally {
        if ($securityDescriptor -ne [IntPtr]::Zero) {
            [void][ShareSurfer.NativeWin32Methods]::LocalFree($securityDescriptor)
        }
    }
}
