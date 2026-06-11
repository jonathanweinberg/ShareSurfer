function Get-ShareSurferOpenFileParentPath {
    param([string] $Path)

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return ''
    }

    $trimmed = $Path.TrimEnd('\', '/')
    $slashIndex = $trimmed.LastIndexOf('/')
    $backslashIndex = $trimmed.LastIndexOf('\')
    $index = [Math]::Max($slashIndex, $backslashIndex)
    if ($index -lt 0) {
        return ''
    }

    $trimmed.Substring(0, $index)
}

function ConvertTo-ShareSurferOpenFilePermissionText {
    param([int] $PermissionMask)

    $values = New-Object System.Collections.ArrayList
    if (($PermissionMask -band 1) -ne 0) {
        [void]$values.Add('Read')
    }
    if (($PermissionMask -band 2) -ne 0) {
        [void]$values.Add('Write')
    }
    if (($PermissionMask -band 4) -ne 0) {
        [void]$values.Add('Create')
    }

    if ($values.Count -eq 0) {
        return ('0x{0:X}' -f $PermissionMask)
    }

    $values -join ','
}

function New-ShareSurferOpenFileSampleRow {
    param(
        [Parameter(Mandatory = $true)]
        [string] $AssessmentId,

        [Parameter(Mandatory = $true)]
        [string] $SampleId,

        [Parameter(Mandatory = $true)]
        [string] $SampleTimestamp,

        [Parameter(Mandatory = $true)]
        [string] $ComputerName,

        [string] $ShareName = '',
        [string] $Provider = '',
        [string] $FileId = '',
        [string] $SessionId = '',
        [string] $ClientComputerName = '',
        [string] $ClientUserName = '',
        [string] $Path = '',
        [string] $ShareRelativePath = '',
        [string] $Permissions = '',
        [int] $Locks = 0,
        [string] $Source = '',
        [string] $CollectionStatus = 'Open',
        [string] $ErrorMessage = ''
    )

    [pscustomobject]@{
        AssessmentId = $AssessmentId
        SampleId = $SampleId
        SampleTimestamp = $SampleTimestamp
        ComputerName = $ComputerName
        ShareName = $ShareName
        Provider = $Provider
        FileId = $FileId
        SessionId = $SessionId
        ClientComputerName = $ClientComputerName
        ClientUserName = $ClientUserName
        Path = $Path
        FolderPath = Get-ShareSurferOpenFileParentPath -Path $Path
        ShareRelativePath = $ShareRelativePath
        ShareRelativeFolder = Get-ShareSurferOpenFileParentPath -Path $ShareRelativePath
        Permissions = $Permissions
        Locks = $Locks
        Source = $Source
        CollectionStatus = $CollectionStatus
        ErrorMessage = $ErrorMessage
    }
}

function Get-ShareSurferNativeOpenFileRows {
    param(
        [Parameter(Mandatory = $true)]
        [string] $ComputerName,

        [string[]] $ShareName = @(),

        [Parameter(Mandatory = $true)]
        [string] $AssessmentId,

        [Parameter(Mandatory = $true)]
        [string] $SampleId,

        [Parameter(Mandatory = $true)]
        [string] $SampleTimestamp
    )

    $provider = Get-Variable -Name 'ShareSurferOpenFileProvider' -Scope Global -ErrorAction SilentlyContinue
    if ($null -ne $provider -and $provider.Value -is [scriptblock]) {
        return & $provider.Value -ComputerName $ComputerName -ShareName $ShareName -AssessmentId $AssessmentId -SampleId $SampleId -SampleTimestamp $SampleTimestamp -Provider 'NativeRpc'
    }

    Initialize-ShareSurferNativeWin32

    $serverName = $null
    if (Test-ShareSurferRemoteComputerName -ComputerName $ComputerName) {
        $serverName = '\\{0}' -f $ComputerName
    }

    $targets = @()
    if ($null -ne $ShareName -and @($ShareName).Count -gt 0) {
        foreach ($share in @($ShareName)) {
            $shareInfo = Get-ShareSurferSmbRpcShareInfo -ComputerName $ComputerName -ShareName $share
            $basePath = ''
            if ($null -ne $shareInfo -and $shareInfo.PSObject.Properties['Path']) {
                $basePath = [string]$shareInfo.Path
            }
            $targets += [pscustomobject]@{
                ShareName = $share
                BasePath = $basePath
            }
        }
    }
    else {
        $targets += [pscustomobject]@{
            ShareName = ''
            BasePath = ''
        }
    }

    $rows = New-Object System.Collections.ArrayList
    foreach ($target in $targets) {
        $buffer = [IntPtr]::Zero
        $entriesRead = [UInt32]0
        $totalEntries = [UInt32]0
        $resumeHandle = [UInt32]0
        do {
            $basePathFilter = $null
            if (-not [string]::IsNullOrWhiteSpace([string]$target.BasePath)) {
                $basePathFilter = [string]$target.BasePath
            }

            $result = [ShareSurfer.NativeWin32Methods]::NetFileEnum(
                $serverName,
                $basePathFilter,
                $null,
                3,
                [ref]$buffer,
                [ShareSurfer.NativeWin32Methods]::MAX_PREFERRED_LENGTH,
                [ref]$entriesRead,
                [ref]$totalEntries,
                [ref]$resumeHandle)

            try {
                if ($result -ne 0 -and $result -ne 234) {
                    throw ('NetFileEnum failed for {0}\{1} with result code {2}.' -f $ComputerName, [string]$target.ShareName, $result)
                }

                $structSize = [System.Runtime.InteropServices.Marshal]::SizeOf([type][ShareSurfer.NativeWin32Methods+FILE_INFO_3])
                for ($index = 0; $index -lt [int]$entriesRead; $index++) {
                    $entryPointer = [IntPtr]::Add($buffer, ($index * $structSize))
                    $info = [System.Runtime.InteropServices.Marshal]::PtrToStructure($entryPointer, [type][ShareSurfer.NativeWin32Methods+FILE_INFO_3])
                    $path = [string]$info.fi3_pathname
                    $relativePath = ''
                    if (-not [string]::IsNullOrWhiteSpace([string]$target.BasePath) -and $path.StartsWith([string]$target.BasePath, [StringComparison]::OrdinalIgnoreCase)) {
                        $relativePath = $path.Substring(([string]$target.BasePath).Length).TrimStart('\', '/')
                    }

                    [void]$rows.Add((New-ShareSurferOpenFileSampleRow -AssessmentId $AssessmentId -SampleId $SampleId -SampleTimestamp $SampleTimestamp -ComputerName $ComputerName -ShareName ([string]$target.ShareName) -Provider 'NativeRpc' -FileId ([string]$info.fi3_id) -ClientUserName ([string]$info.fi3_username) -Path $path -ShareRelativePath $relativePath -Permissions (ConvertTo-ShareSurferOpenFilePermissionText -PermissionMask ([int]$info.fi3_permissions)) -Locks ([int]$info.fi3_num_locks) -Source 'NativeNetFileEnum'))
                }
            }
            finally {
                if ($buffer -ne [IntPtr]::Zero) {
                    [void][ShareSurfer.NativeWin32Methods]::NetApiBufferFree($buffer)
                    $buffer = [IntPtr]::Zero
                }
            }
        } while ($result -eq 234 -and $resumeHandle -ne 0)
    }

    @($rows)
}

function Get-ShareSurferPowerShellOpenFileRows {
    param(
        [Parameter(Mandatory = $true)]
        [string] $ComputerName,

        [string[]] $ShareName = @(),

        [Parameter(Mandatory = $true)]
        [string] $AssessmentId,

        [Parameter(Mandatory = $true)]
        [string] $SampleId,

        [Parameter(Mandatory = $true)]
        [string] $SampleTimestamp
    )

    $provider = Get-Variable -Name 'ShareSurferOpenFileProvider' -Scope Global -ErrorAction SilentlyContinue
    if ($null -ne $provider -and $provider.Value -is [scriptblock]) {
        return & $provider.Value -ComputerName $ComputerName -ShareName $ShareName -AssessmentId $AssessmentId -SampleId $SampleId -SampleTimestamp $SampleTimestamp -Provider 'PowerShellCim'
    }

    $session = $null
    try {
        $arguments = @{}
        if (Test-ShareSurferRemoteComputerName -ComputerName $ComputerName) {
            $session = New-CimSession -ComputerName $ComputerName -ErrorAction Stop
            $arguments['CimSession'] = $session
        }

        $openFiles = @(Get-SmbOpenFile @arguments -ErrorAction Stop)
        if ($null -ne $ShareName -and @($ShareName).Count -gt 0) {
            $shareSet = @{}
            foreach ($share in @($ShareName)) {
                $shareSet[[string]$share] = $true
            }
            $openFiles = @($openFiles | Where-Object {
                $rowShare = if ($_.PSObject.Properties['ShareName']) { [string]$_.ShareName } else { '' }
                $shareSet.ContainsKey($rowShare) -or [string]::IsNullOrWhiteSpace($rowShare)
            })
        }

        foreach ($openFile in $openFiles) {
            $share = if ($openFile.PSObject.Properties['ShareName']) { [string]$openFile.ShareName } elseif (@($ShareName).Count -eq 1) { [string]$ShareName[0] } else { '' }
            $path = if ($openFile.PSObject.Properties['Path']) { [string]$openFile.Path } else { '' }
            $relative = if ($openFile.PSObject.Properties['ShareRelativePath']) { [string]$openFile.ShareRelativePath } else { '' }
            $fileId = if ($openFile.PSObject.Properties['FileId']) { [string]$openFile.FileId } else { '' }
            $sessionId = if ($openFile.PSObject.Properties['SessionId']) { [string]$openFile.SessionId } else { '' }
            $clientComputerName = if ($openFile.PSObject.Properties['ClientComputerName']) { [string]$openFile.ClientComputerName } else { '' }
            $clientUserName = if ($openFile.PSObject.Properties['ClientUserName']) { [string]$openFile.ClientUserName } else { '' }
            $permissions = if ($openFile.PSObject.Properties['Permissions']) { [string]$openFile.Permissions } else { '' }
            $locks = if ($openFile.PSObject.Properties['Locks']) { [int]$openFile.Locks } else { 0 }

            New-ShareSurferOpenFileSampleRow -AssessmentId $AssessmentId -SampleId $SampleId -SampleTimestamp $SampleTimestamp -ComputerName $ComputerName -ShareName $share -Provider 'PowerShellCim' -FileId $fileId -SessionId $sessionId -ClientComputerName $clientComputerName -ClientUserName $clientUserName -Path $path -ShareRelativePath $relative -Permissions $permissions -Locks $locks -Source 'Get-SmbOpenFile'
        }
    }
    finally {
        if ($null -ne $session) {
            Remove-CimSession -CimSession $session -ErrorAction SilentlyContinue
        }
    }
}
