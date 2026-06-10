function ConvertTo-ShareSurferSecurityDescriptorBytes {
    param(
        [Parameter(Mandatory = $true)]
        [IntPtr] $SecurityDescriptor
    )

    if ($SecurityDescriptor -eq [IntPtr]::Zero) {
        return @()
    }

    $length = [ShareSurfer.NativeWin32Methods]::GetSecurityDescriptorLength($SecurityDescriptor)
    if ($length -le 0) {
        return @()
    }

    $bytes = New-Object byte[] $length
    [System.Runtime.InteropServices.Marshal]::Copy($SecurityDescriptor, $bytes, 0, [int]$length)
    $bytes
}

function ConvertTo-ShareSurferIdentityReference {
    param(
        $SecurityIdentifier
    )

    if ($null -eq $SecurityIdentifier) {
        return ''
    }

    $sid = $null
    try {
        if ($SecurityIdentifier -is [System.Security.Principal.SecurityIdentifier]) {
            $sid = $SecurityIdentifier
        }
        else {
            $sid = New-Object System.Security.Principal.SecurityIdentifier ([string]$SecurityIdentifier)
        }
    }
    catch {
        return [string]$SecurityIdentifier
    }

    try {
        return [string]$sid.Translate([System.Security.Principal.NTAccount]).Value
    }
    catch {
        return [string]$sid.Value
    }
}

function ConvertTo-ShareSurferAccessControlType {
    param(
        [string] $AceQualifier = ''
    )

    if ($AceQualifier -like '*Denied*') {
        return 'Deny'
    }

    if ($AceQualifier -like '*Allowed*') {
        return 'Allow'
    }

    ''
}

function ConvertTo-ShareSurferShareRights {
    param(
        [long] $AccessMask
    )

    $genericAll = 0x10000000
    $genericWrite = 0x40000000
    $genericRead = 0x80000000
    $fileAllAccess = 0x001F01FF
    $fileGenericWrite = 0x00120116
    $delete = 0x00010000
    $writeDac = 0x00040000
    $writeOwner = 0x00080000

    if ((($AccessMask -band $genericAll) -ne 0) -or (($AccessMask -band $fileAllAccess) -eq $fileAllAccess)) {
        return 'Full'
    }

    if ((($AccessMask -band $genericWrite) -ne 0) -or (($AccessMask -band $fileGenericWrite) -ne 0) -or (($AccessMask -band $delete) -ne 0) -or (($AccessMask -band $writeDac) -ne 0) -or (($AccessMask -band $writeOwner) -ne 0)) {
        return 'Change'
    }

    if (($AccessMask -band $genericRead) -ne 0) {
        return 'Read'
    }

    'Read'
}

function ConvertTo-ShareSurferFileSystemRights {
    param(
        [long] $AccessMask
    )

    try {
        return [string]([System.Security.AccessControl.FileSystemRights]([int]$AccessMask))
    }
    catch {
        return ('0x{0:X8}' -f $AccessMask)
    }
}

function ConvertTo-ShareSurferAceFlagText {
    param(
        [System.Security.AccessControl.AceFlags] $AceFlags,

        [ValidateSet('Inheritance', 'Propagation')]
        [string] $FlagType
    )

    $values = New-Object System.Collections.ArrayList
    if ($FlagType -eq 'Inheritance') {
        if (($AceFlags -band [System.Security.AccessControl.AceFlags]::ContainerInherit) -ne 0) {
            [void]$values.Add('ContainerInherit')
        }
        if (($AceFlags -band [System.Security.AccessControl.AceFlags]::ObjectInherit) -ne 0) {
            [void]$values.Add('ObjectInherit')
        }
    }
    else {
        if (($AceFlags -band [System.Security.AccessControl.AceFlags]::NoPropagateInherit) -ne 0) {
            [void]$values.Add('NoPropagateInherit')
        }
        if (($AceFlags -band [System.Security.AccessControl.AceFlags]::InheritOnly) -ne 0) {
            [void]$values.Add('InheritOnly')
        }
    }

    if ($values.Count -eq 0) {
        return 'None'
    }

    @($values) -join ','
}

function ConvertTo-ShareSurferRawSecurityDescriptor {
    param(
        [Parameter(Mandatory = $true)]
        [byte[]] $SecurityDescriptorBytes
    )

    if ($SecurityDescriptorBytes.Count -eq 0) {
        return $null
    }

    [System.Security.AccessControl.RawSecurityDescriptor]::new($SecurityDescriptorBytes, 0)
}

function ConvertTo-ShareSurferSecurityDescriptorAclRows {
    param(
        [Parameter(Mandatory = $true)]
        [System.Security.AccessControl.RawSecurityDescriptor] $RawSecurityDescriptor,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Share', 'FileSystem')]
        [string] $PermissionKind,

        [string] $ShareId = '',
        [string] $ItemId = '',
        [string] $FullPath = '',
        [int] $Depth = 0
    )

    $rows = New-Object System.Collections.ArrayList
    if ($null -eq $RawSecurityDescriptor.DiscretionaryAcl) {
        return @($rows)
    }

    foreach ($ace in $RawSecurityDescriptor.DiscretionaryAcl) {
        if (-not ($ace -is [System.Security.AccessControl.KnownAce])) {
            continue
        }

        $aceQualifier = ''
        try {
            $aceQualifier = [string]$ace.AceQualifier
        }
        catch {
            $aceQualifier = ''
        }

        $accessControlType = ConvertTo-ShareSurferAccessControlType -AceQualifier $aceQualifier
        if ($accessControlType -eq '') {
            continue
        }

        $identity = ConvertTo-ShareSurferIdentityReference -SecurityIdentifier $ace.SecurityIdentifier
        $rights = if ($PermissionKind -eq 'Share') {
            ConvertTo-ShareSurferShareRights -AccessMask ([long]$ace.AccessMask)
        }
        else {
            ConvertTo-ShareSurferFileSystemRights -AccessMask ([long]$ace.AccessMask)
        }

        if ($PermissionKind -eq 'Share') {
            [void]$rows.Add([pscustomobject]@{
                ShareId = $ShareId
                Identity = $identity
                Rights = $rights
                AccessControlType = $accessControlType
                Source = 'NativeSmbRpc'
            })
        }
        else {
            $aceFlags = [System.Security.AccessControl.AceFlags]$ace.AceFlags
            [void]$rows.Add([pscustomobject]@{
                ItemId = $ItemId
                ShareId = $ShareId
                FullPath = $FullPath
                Identity = $identity
                Rights = $rights
                AccessControlType = $accessControlType
                IsInherited = (($aceFlags -band [System.Security.AccessControl.AceFlags]::Inherited) -ne 0)
                InheritanceFlags = ConvertTo-ShareSurferAceFlagText -AceFlags $aceFlags -FlagType 'Inheritance'
                PropagationFlags = ConvertTo-ShareSurferAceFlagText -AceFlags $aceFlags -FlagType 'Propagation'
                Depth = $Depth
            })
        }
    }

    @($rows)
}

function ConvertTo-ShareSurferSharePermissionRowsFromSecurityDescriptor {
    param(
        [Parameter(Mandatory = $true)]
        [string] $ShareId,

        [Parameter(Mandatory = $true)]
        [byte[]] $SecurityDescriptorBytes
    )

    $descriptor = ConvertTo-ShareSurferRawSecurityDescriptor -SecurityDescriptorBytes $SecurityDescriptorBytes
    if ($null -eq $descriptor) {
        return @()
    }

    ConvertTo-ShareSurferSecurityDescriptorAclRows -RawSecurityDescriptor $descriptor -PermissionKind Share -ShareId $ShareId
}
