function Get-ShareSurferSmbShareInventory {
    param(
        [Parameter(Mandatory = $true)]
        [string] $ComputerName,

        [Parameter(Mandatory = $true)]
        [string[]] $ShareName,

        [ValidateSet('Auto', 'PowerShellCim', 'NativeSmbRpc')]
        [string] $SmbCollectionProvider = 'Auto',

        [switch] $IncludeFiles,

        [switch] $Quiet
    )

    if ($SmbCollectionProvider -eq 'NativeSmbRpc') {
        $nativeInventory = Get-ShareSurferNativeSmbShareInventory -ComputerName $ComputerName -ShareName $ShareName -IncludeFiles:$IncludeFiles -Quiet:$Quiet
        $nativeInventory | Add-Member -MemberType NoteProperty -Name RequestedSmbCollectionProvider -Value $SmbCollectionProvider -Force
        $nativeInventory | Add-Member -MemberType NoteProperty -Name EffectiveSmbCollectionProvider -Value 'NativeSmbRpc' -Force
        return $nativeInventory
    }

    $shares = New-Object System.Collections.ArrayList
    $items = New-Object System.Collections.ArrayList
    $aclEntries = New-Object System.Collections.ArrayList
    $sharePermissions = New-Object System.Collections.ArrayList
    $scanErrors = New-Object System.Collections.ArrayList
    $scanEvents = New-Object System.Collections.ArrayList
    $getSmbShare = Get-Command Get-SmbShare -ErrorAction SilentlyContinue
    $cimSession = $null
    $remoteCimSessionAttempted = $false
    $remoteCimSessionAvailable = $false
    $effectiveProviders = New-Object System.Collections.ArrayList

    [void]$scanEvents.Add((New-ShareSurferEvent -EventType 'CollectionProviderSelected' -Source $SmbCollectionProvider -Message ('Using {0} SMB collection provider for {1} explicit share target(s) on {2}.' -f $SmbCollectionProvider, @($ShareName).Count, $ComputerName) -Detail 'PowerShell SMB/CIM collector path'))

    $targetIsRemote = Test-ShareSurferRemoteComputerName -ComputerName $ComputerName

    if ($targetIsRemote) {
        $remoteCimSessionAttempted = $true
        $newCimSession = Get-Command New-CimSession -ErrorAction SilentlyContinue
        if ($null -ne $newCimSession) {
            $previousErrorActionPreference = $ErrorActionPreference
            try {
                $ErrorActionPreference = 'Stop'
                Write-ShareSurferStatus -Phase 'Collect' -Message ('Attempting remote CIM session to {0} for SMB share metadata.' -f $ComputerName) -Quiet:$Quiet
                $cimSession = New-CimSession -ComputerName $ComputerName
                $remoteCimSessionAvailable = ($null -ne $cimSession)
                [void]$scanEvents.Add((New-ShareSurferEvent -EventType 'RemoteCimSessionCreated' -Source 'New-CimSession' -Message ('Created remote CIM session for {0}' -f $ComputerName) -Detail $ComputerName))
            }
            catch {
                [void]$scanErrors.Add([pscustomobject]@{
                    ShareId = ''
                    FullPath = ('\\{0}' -f $ComputerName)
                    ErrorType = 'RemoteCimSessionError'
                    Message = [string]$_.Exception.Message
                })
                [void]$scanEvents.Add((New-ShareSurferEvent -EventType 'RemoteCimSessionError' -Source 'New-CimSession' -Level 'Warning' -Message ('Unable to create remote CIM session for {0}' -f $ComputerName) -Detail ([string]$_.Exception.Message)))
                Write-ShareSurferStatus -Phase 'Collect' -Message ('Remote CIM session to {0} was unavailable; continuing with best-effort share/path evidence.' -f $ComputerName) -Quiet:$Quiet
            }
            finally {
                $ErrorActionPreference = $previousErrorActionPreference
            }
        }
        else {
            [void]$scanErrors.Add([pscustomobject]@{
                ShareId = ''
                FullPath = ('\\{0}' -f $ComputerName)
                ErrorType = 'RemoteCimSessionUnavailable'
                Message = 'New-CimSession command is unavailable.'
            })
            [void]$scanEvents.Add((New-ShareSurferEvent -EventType 'RemoteCimSessionUnavailable' -Source 'New-CimSession' -Level 'Warning' -Message ('Unable to create remote CIM session for {0}' -f $ComputerName) -Detail 'New-CimSession command is unavailable.'))
        }
    }

    try {
        foreach ($name in $ShareName) {
            $shareId = 'share-{0}-{1}' -f ($ComputerName -replace '[^A-Za-z0-9]', '-'), ($name -replace '[^A-Za-z0-9]', '-')
            $uncPath = '\\{0}\{1}' -f $ComputerName, $name
            Write-ShareSurferStatus -Phase 'Collect' -Message ('Resolving SMB share {0}.' -f $uncPath) -Quiet:$Quiet
            $localPath = ''
            $description = ''
            $scanPath = $uncPath
            $pathSelection = 'TargetUNC'
            $source = 'BestEffort'
            $rpcShare = $null

            if ($null -ne $getSmbShare) {
                $previousErrorActionPreference = $ErrorActionPreference
                try {
                    $ErrorActionPreference = 'Stop'
                    if ($null -ne $cimSession) {
                        $share = Get-SmbShare -Name $name -CimSession $cimSession
                    }
                    elseif (-not $targetIsRemote) {
                        $share = Get-SmbShare -Name $name
                    }
                    else {
                        $share = $null
                    }
                    if ($null -ne $share) {
                        $localPath = [string]$share.Path
                        $description = [string]$share.Description
                        if ($localPath -ne '' -and -not $targetIsRemote -and (Test-Path -LiteralPath (ConvertTo-ShareSurferFilesystemPath -Path $localPath))) {
                            $scanPath = $localPath
                            $pathSelection = 'ReturnedLocalPathUsedForLocalTarget'
                        }
                        elseif ($localPath -ne '' -and $targetIsRemote) {
                            $pathSelection = 'ReturnedLocalPathIgnoredForRemoteTarget'
                        }
                        elseif ($localPath -ne '') {
                            $pathSelection = 'ReturnedLocalPathUnavailableOnCollector'
                        }
                        $source = 'Get-SmbShare'
                        [void]$effectiveProviders.Add('PowerShellCim')
                    }
                }
                catch {
                    [void]$scanErrors.Add([pscustomobject]@{
                        ShareId = $shareId
                        FullPath = $uncPath
                        ErrorType = 'ShareLookupError'
                        Message = [string]$_.Exception.Message
                    })
                }
                finally {
                    $ErrorActionPreference = $previousErrorActionPreference
                }
            }

            if ($source -eq 'BestEffort') {
                try {
                    Write-ShareSurferStatus -Phase 'Collect' -Message ('Attempting SMB/RPC share metadata fallback for {0}.' -f $uncPath) -Quiet:$Quiet
                    $rpcShare = Get-ShareSurferSmbRpcShareInfo -ComputerName $ComputerName -ShareName $name -PreferSecurityDescriptor
                    if ($null -ne $rpcShare) {
                        $localPath = [string]$rpcShare.Path
                        $description = [string]$rpcShare.Description
                        if ($localPath -ne '' -and -not $targetIsRemote -and (Test-Path -LiteralPath (ConvertTo-ShareSurferFilesystemPath -Path $localPath))) {
                            $scanPath = $localPath
                            $pathSelection = 'ReturnedLocalPathUsedForLocalTarget'
                        }
                        elseif ($localPath -ne '' -and $targetIsRemote) {
                            $pathSelection = 'ReturnedLocalPathIgnoredForRemoteTarget'
                        }
                        elseif ($localPath -ne '') {
                            $pathSelection = 'ReturnedLocalPathUnavailableOnCollector'
                        }
                        $source = [string]$rpcShare.Source
                        if ($source -eq '') {
                            $source = 'SmbRpcNetShareGetInfo'
                        }
                        [void]$effectiveProviders.Add('NativeSmbRpc')
                        [void]$scanEvents.Add((New-ShareSurferEvent -EventType 'SmbRpcShareInfoResolved' -Source $source -ShareId $shareId -Message ('Resolved share metadata for {0} through SMB/RPC fallback.' -f $uncPath) -Detail $localPath))
                    }
                    else {
                        [void]$scanEvents.Add((New-ShareSurferEvent -EventType 'SmbRpcShareInfoUnavailable' -Source 'SmbRpcNetShareGetInfo' -Level 'Warning' -ShareId $shareId -Message ('SMB/RPC fallback did not return share metadata for {0}.' -f $uncPath) -Detail $uncPath))
                    }
                }
                catch {
                    [void]$scanErrors.Add([pscustomobject]@{
                        ShareId = $shareId
                        FullPath = $uncPath
                        ErrorType = 'SmbRpcShareLookupError'
                        Message = [string]$_.Exception.Message
                    })
                    [void]$scanEvents.Add((New-ShareSurferEvent -EventType 'SmbRpcShareLookupError' -Source 'SmbRpcNetShareGetInfo' -Level 'Warning' -ShareId $shareId -Message ('SMB/RPC fallback failed for {0}.' -f $uncPath) -Detail ([string]$_.Exception.Message)))
                }
            }

            if ($source -eq 'BestEffort') {
                [void]$effectiveProviders.Add('BestEffort')
            }

            $pathSelectionDetail = 'SelectedPath={0}; ReturnedLocalPath={1}; TargetIsRemote={2}; PathSelection={3}' -f $scanPath, $localPath, $targetIsRemote, $pathSelection
            [void]$scanEvents.Add((New-ShareSurferEvent -EventType 'ShareTargetResolved' -Source $source -ShareId $shareId -Message ('Resolved share target {0}' -f $uncPath) -Detail $pathSelectionDetail))
            Write-ShareSurferStatus -Phase 'Collect' -Message ('Enumerating {0}.' -f $scanPath) -Quiet:$Quiet

            try {
                $inventory = Get-ShareSurferLocalInventory -TargetPath @($scanPath) -IncludeFiles:$IncludeFiles -Quiet:$Quiet -SkipSharePermissionCollection
                foreach ($row in @(ConvertTo-ShareSurferArray $inventory.Shares)) {
                    $row.ShareId = $shareId
                    $row.Source = $source
                    $row.ComputerName = $ComputerName
                    $row.ShareName = $name
                    $row.UNCPath = $uncPath
                    if ($localPath -ne '') {
                        $row.LocalPath = $localPath
                    }
                    $row.Description = $description
                    if ([string]$row.PartialReason -eq 'Target path could not be resolved.') {
                        $row.PartialReason = 'Unable to enumerate share path.'
                    }
                    [void]$shares.Add($row)
                }
                foreach ($row in @(ConvertTo-ShareSurferArray $inventory.Items)) {
                    $row.ShareId = $shareId
                    [void]$items.Add($row)
                }
                foreach ($row in @(ConvertTo-ShareSurferArray $inventory.AclEntries)) {
                    $row.ShareId = $shareId
                    [void]$aclEntries.Add($row)
                }
                foreach ($row in @(ConvertTo-ShareSurferArray $inventory.ScanErrors)) {
                    $row.ShareId = $shareId
                    if ([string]$row.ErrorType -eq 'TargetPathResolveError') {
                        $row.ErrorType = 'ShareEnumerationError'
                        $row.FullPath = $uncPath
                    }
                    [void]$scanErrors.Add($row)
                }
                foreach ($row in @(ConvertTo-ShareSurferArray $inventory.ScanEvents)) {
                    $row.ShareId = $shareId
                    if ([string]$row.EventType -eq 'TargetPathResolveError') {
                        $row.EventType = 'ShareEnumerationError'
                        $row.Source = 'SmbShare'
                        $row.Message = ('Unable to enumerate share path {0}' -f $uncPath)
                    }
                    [void]$scanEvents.Add($row)
                }
            }
            catch {
                [void]$shares.Add([pscustomobject]@{
                    ShareId = $shareId
                    Source = $source
                    ComputerName = $ComputerName
                    ShareName = $name
                    UNCPath = $uncPath
                    LocalPath = $localPath
                    Description = $description
                    PartialData = $true
                    PartialReason = 'Unable to enumerate share path.'
                })
                [void]$scanErrors.Add([pscustomobject]@{
                    ShareId = $shareId
                    FullPath = $uncPath
                    ErrorType = 'ShareEnumerationError'
                    Message = [string]$_.Exception.Message
                })
            }

            $permissionResult = Get-ShareSurferSharePermissionRows -ShareId $shareId -ShareName $name -ComputerName $ComputerName -CimSession $cimSession -SkipRemoteCimSessionCreation:($remoteCimSessionAttempted -and -not $remoteCimSessionAvailable) -PassThruResult
            $permissionRows = @($permissionResult.Rows)
            if (-not [string]::IsNullOrWhiteSpace([string]$permissionResult.ErrorType)) {
                $permissionEventLevel = if ([string]$permissionResult.Severity -eq 'Info') { 'Info' } else { 'Warning' }
                [void]$scanEvents.Add((New-ShareSurferEvent -Level $permissionEventLevel -EventType ([string]$permissionResult.ErrorType) -Source ([string]$permissionResult.Source) -ShareId $shareId -Message ([string]$permissionResult.Message) -Detail ([string]$permissionResult.Detail)))
            }
            if ($permissionRows.Count -eq 0) {
                Write-ShareSurferStatus -Phase 'Collect' -Message ('Get-SmbShareAccess did not return share permissions for {0}; trying native SMB/RPC descriptor fallback.' -f $uncPath) -Quiet:$Quiet
                $nativeEvidence = Get-ShareSurferNativeSharePermissionEvidence -ShareId $shareId -ComputerName $ComputerName -ShareName $name -RpcShare $rpcShare
                if ([bool]$nativeEvidence.Success) {
                    $permissionRows = @($nativeEvidence.Rows)
                    [void]$effectiveProviders.Add('NativeSmbRpc')
                    [void]$scanEvents.Add((New-ShareSurferEvent -EventType $nativeEvidence.EventType -Source 'NativeSmbRpc' -ShareId $shareId -Message $nativeEvidence.Message -Detail $nativeEvidence.Detail))
                }
                else {
                    $nativeEventLevel = if ([string]$nativeEvidence.Severity -eq 'Info') { 'Info' } else { 'Warning' }
                    [void]$scanErrors.Add([pscustomobject]@{
                        ShareId = $shareId
                        FullPath = $uncPath
                        ErrorType = $nativeEvidence.ErrorType
                        Severity = $nativeEvidence.Severity
                        Source = $nativeEvidence.Source
                        Message = $nativeEvidence.Message
                        Detail = $nativeEvidence.Detail
                    })
                    [void]$scanEvents.Add((New-ShareSurferEvent -Level $nativeEventLevel -EventType $nativeEvidence.EventType -Source $nativeEvidence.Source -ShareId $shareId -Message $nativeEvidence.Message -Detail $nativeEvidence.Detail))
                }
            }
            foreach ($permission in $permissionRows) {
                [void]$sharePermissions.Add($permission)
            }
            if ($permissionRows.Count -gt 0) {
                $shareRow = @($shares | Where-Object { $_.ShareId -eq $shareId } | Select-Object -First 1)
                if ($shareRow.Count -gt 0 -and [string]$shareRow[0].PartialReason -eq 'Share-level permissions were not collected through Get-SmbShareAccess.') {
                    $shareRow[0].PartialData = $false
                    $shareRow[0].PartialReason = ''
                }
                for ($scanErrorIndex = $scanErrors.Count - 1; $scanErrorIndex -ge 0; $scanErrorIndex--) {
                    $scanError = $scanErrors[$scanErrorIndex]
                    if ([string]$scanError.ShareId -eq $shareId -and [string]$scanError.ErrorType -eq 'SharePermissionCollectionUnavailable') {
                        $scanErrors.RemoveAt($scanErrorIndex)
                    }
                }
                for ($scanEventIndex = $scanEvents.Count - 1; $scanEventIndex -ge 0; $scanEventIndex--) {
                    $scanEvent = $scanEvents[$scanEventIndex]
                    if ([string]$scanEvent.ShareId -eq $shareId -and [string]$scanEvent.EventType -eq 'SharePermissionCollectionUnavailable') {
                        $scanEvents.RemoveAt($scanEventIndex)
                    }
                }
            }
            if ($permissionRows.Count -eq 0) {
                $shareRow = @($shares | Where-Object { $_.ShareId -eq $shareId } | Select-Object -First 1)
                if ($shareRow.Count -gt 0) {
                    Add-ShareSurferPartialReason -ShareRow $shareRow[0] -Reason 'Share-level permissions were not collected through Get-SmbShareAccess or NativeSmbRpc.'
                }
                if (-not [string]::IsNullOrWhiteSpace([string]$permissionResult.ErrorType) -and [string]$permissionResult.ErrorType -ne 'CimSessionRequired') {
                    [void]$scanErrors.Add([pscustomobject]@{
                        ShareId = $shareId
                        FullPath = $uncPath
                        ErrorType = [string]$permissionResult.ErrorType
                        Severity = [string]$permissionResult.Severity
                        Source = [string]$permissionResult.Source
                        Message = [string]$permissionResult.Message
                        Detail = [string]$permissionResult.Detail
                    })
                }
                Write-ShareSurferStatus -Phase 'Collect' -Message ('Share-level permissions were unavailable for {0}; continuing with partial share-permission evidence.' -f $uncPath) -Quiet:$Quiet
            }
            Write-ShareSurferStatus -Phase 'Collect' -Message ('Finished SMB share {0}.' -f $uncPath) -Quiet:$Quiet
        }
    }
    finally {
        if ($null -ne $cimSession) {
            Remove-CimSession -CimSession $cimSession -ErrorAction SilentlyContinue
        }
    }

    $effectiveProviderNames = @($effectiveProviders | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | Select-Object -Unique)
    $effectiveSmbCollectionProvider = if ($effectiveProviderNames.Count -eq 0) {
        $SmbCollectionProvider
    }
    elseif ($effectiveProviderNames.Count -eq 1) {
        [string]$effectiveProviderNames[0]
    }
    else {
        'Mixed'
    }

    [pscustomobject]@{
        Shares = @($shares)
        Items = @($items)
        SharePermissions = @($sharePermissions)
        AclEntries = @($aclEntries)
        Identities = @()
        GroupEdges = @()
        OrgChains = @()
        OwnerMappings = @()
        ScanErrors = @($scanErrors)
        ScanEvents = @($scanEvents)
        RequestedSmbCollectionProvider = $SmbCollectionProvider
        EffectiveSmbCollectionProvider = $effectiveSmbCollectionProvider
    }
}
