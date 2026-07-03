function Test-ShareSurferItemIsReparsePoint {
    param(
        $Item
    )

    if ($null -eq $Item -or $null -eq $Item.PSObject.Properties['Attributes']) {
        return $false
    }

    try {
        return ((([System.IO.FileAttributes]$Item.Attributes) -band [System.IO.FileAttributes]::ReparsePoint) -ne 0)
    }
    catch {
        return $false
    }
}

function ConvertTo-ShareSurferComparableLocalPath {
    param(
        [string] $Path = ''
    )

    $text = ConvertFrom-ShareSurferFilesystemPath -Path ([string]$Path)
    $text = $text.Trim().Replace('/', '\').TrimEnd('\')
    $text.ToUpperInvariant()
}

function Get-ShareSurferLocalInventory {
    param(
        [Parameter(Mandatory = $true)]
        [string[]] $TargetPath,

        [switch] $IncludeFiles,

        [ValidateSet('PowerShellGetAcl', 'NativeWin32Security')]
        [string] $AclProvider = 'PowerShellGetAcl',

        [switch] $SkipSharePermissionCollection,

        [switch] $Quiet
    )

    $shares = New-Object System.Collections.ArrayList
    $items = New-Object System.Collections.ArrayList
    $aclEntries = New-Object System.Collections.ArrayList
    $sharePermissions = New-Object System.Collections.ArrayList
    $scanErrors = New-Object System.Collections.ArrayList
    $scanEvents = New-Object System.Collections.ArrayList

    $getAcl = $null
    if ($AclProvider -eq 'PowerShellGetAcl') {
        $getAcl = Get-Command Get-Acl -ErrorAction SilentlyContinue
    }
    $index = 0
    foreach ($target in $TargetPath) {
        $index++
        $shareId = 'target-{0}' -f $index
        Write-ShareSurferStatus -Phase 'Collect' -Message ('Resolving target {0} of {1}: {2}' -f $index, @($TargetPath).Count, $target) -Quiet:$Quiet
        try {
            $targetItem = Get-Item -LiteralPath (ConvertTo-ShareSurferFilesystemPath -Path $target) -ErrorAction Stop
        }
        catch {
            [void]$shares.Add([pscustomobject]@{
                ShareId = $shareId
                Source = 'BestEffort'
                ComputerName = ''
                ShareName = Split-Path -Leaf $target
                UNCPath = $target
                LocalPath = $target
                Description = 'Best-effort target path scan'
                PartialData = $true
                PartialReason = 'Target path could not be resolved.'
            })
            [void]$scanErrors.Add([pscustomobject]@{
                ShareId = $shareId
                FullPath = $target
                ErrorType = 'TargetPathResolveError'
                Message = [string]$_.Exception.Message
            })
            [void]$scanEvents.Add((New-ShareSurferEvent -EventType 'TargetPathResolveError' -Source 'TargetPath' -ShareId $shareId -Message ('Unable to resolve target path {0}' -f $target) -Detail ([string]$_.Exception.Message)))
            continue
        }
        $targetDisplayPath = ConvertFrom-ShareSurferFilesystemPath -Path ([string]$targetItem.FullName)
        $shareInfo = Get-ShareSurferTargetShareInfo -TargetPath $target -TargetItem $targetItem
        [void]$scanEvents.Add((New-ShareSurferEvent -EventType 'TargetPathResolved' -Source 'TargetPath' -ShareId $shareId -Message ('Resolved target path {0}' -f $target) -Detail $targetDisplayPath))
        $permissionRows = @()
        $sharePermissionSource = ''
        $nativeSharePermissionAttempted = $false
        $permissionResult = $null
        $localShareVerificationMessage = ''
        if (-not $SkipSharePermissionCollection -and -not [bool]$shareInfo.IsUncTarget) {
            $getSmbShareCommand = Get-Command Get-SmbShare -ErrorAction SilentlyContinue
            if ($null -eq $getSmbShareCommand) {
                $localShareVerificationMessage = 'Share-level permissions were not collected because Get-SmbShare is unavailable to verify that this local folder is an SMB share root.'
            }
            else {
                try {
                    $targetComparisonPath = ConvertTo-ShareSurferComparableLocalPath -Path $targetDisplayPath
                    $candidateShareRows = @(Get-SmbShare -ErrorAction Stop)
                    $matchingShareRows = @($candidateShareRows | Where-Object {
                        $null -ne $_.PSObject.Properties['Path'] -and (ConvertTo-ShareSurferComparableLocalPath -Path ([string]$_.Path)) -eq $targetComparisonPath
                    } | Sort-Object Name)
                    if ($matchingShareRows.Count -eq 0) {
                        $localShareVerificationMessage = ('Share-level permissions were not collected because no local SMB share path matched scanned folder {0}.' -f $targetDisplayPath)
                    }
                    else {
                        $preferredShareRows = @($matchingShareRows | Where-Object {
                            $null -eq $_.PSObject.Properties['Special'] -or -not [bool]$_.Special
                        })
                        $matchedShare = if ($preferredShareRows.Count -gt 0) { $preferredShareRows[0] } else { $matchingShareRows[0] }
                        $matchedShareName = if ($matchedShare.PSObject.Properties['Name']) { [string]$matchedShare.Name } else { [string]$shareInfo.ShareName }
                        if (-not [string]::IsNullOrWhiteSpace($matchedShareName)) {
                            $shareInfo.ShareName = $matchedShareName
                            $shareInfo.UNCPath = '\\{0}\{1}' -f $shareInfo.ComputerName, $matchedShareName
                        }
                        $matchedShareIsSpecial = ($null -ne $matchedShare.PSObject.Properties['Special'] -and [bool]$matchedShare.Special)
                        if ($matchedShareIsSpecial) {
                            [void]$scanEvents.Add((New-ShareSurferEvent -Level 'Info' -EventType 'SpecialLocalShareSelected' -Source 'Get-SmbShare' -ShareId $shareId -Message ('Only a special/admin local SMB share matched scanned folder {0}; using {1} as best available share-gate evidence.' -f $targetDisplayPath, $matchedShareName) -Detail ('MatchedShares={0}' -f ((@($matchingShareRows | ForEach-Object { [string]$_.Name }) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) -join ', '))))
                        }
                        if ($matchingShareRows.Count -gt 1) {
                            $additionalNames = @($matchingShareRows | Where-Object {
                                $null -ne $_.PSObject.Properties['Name'] -and -not [string]::Equals([string]$_.Name, $matchedShareName, [System.StringComparison]::OrdinalIgnoreCase)
                            } | ForEach-Object { [string]$_.Name } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
                            if ($additionalNames.Count -gt 0) {
                                [void]$scanEvents.Add((New-ShareSurferEvent -Level 'Info' -EventType 'MultipleLocalSharesMatchedPath' -Source 'Get-SmbShare' -ShareId $shareId -Message ('Multiple local SMB shares matched scanned folder {0}; using {1} for share-permission collection.' -f $targetDisplayPath, $matchedShareName) -Detail ('AdditionalMatchingShares={0}' -f ($additionalNames -join ', '))))
                            }
                        }
                    }
                }
                catch {
                    $localShareVerificationMessage = ('Share-level permissions were not collected because local SMB shares could not be enumerated for scanned folder {0}: {1}' -f $targetDisplayPath, [string]$_.Exception.Message)
                }
            }

            if (-not [string]::IsNullOrWhiteSpace($localShareVerificationMessage)) {
                [void]$scanEvents.Add((New-ShareSurferEvent -Level 'Warning' -EventType 'SharePermissionVerificationSkipped' -Source 'Get-SmbShare' -ShareId $shareId -Message $localShareVerificationMessage -Detail 'Local folder scans only attach share-level permissions when a local SMB share path matches the scanned folder.'))
            }
        }
        if (-not $SkipSharePermissionCollection -and [string]::IsNullOrWhiteSpace($localShareVerificationMessage)) {
            Write-ShareSurferStatus -Phase 'Collect' -Message ('Collecting share-level permission evidence for {0}.' -f $targetDisplayPath) -Quiet:$Quiet
            $permissionResult = Get-ShareSurferSharePermissionRows -ShareId $shareId -ShareName $shareInfo.ShareName -ComputerName $shareInfo.ComputerName -PassThruResult
            $permissionRows = @($permissionResult.Rows)
            if (-not [string]::IsNullOrWhiteSpace([string]$permissionResult.ErrorType)) {
                $permissionEventLevel = if ([string]$permissionResult.Severity -eq 'Info') { 'Info' } else { 'Warning' }
                [void]$scanEvents.Add((New-ShareSurferEvent -Level $permissionEventLevel -EventType ([string]$permissionResult.ErrorType) -Source ([string]$permissionResult.Source) -ShareId $shareId -Message ([string]$permissionResult.Message) -Detail ([string]$permissionResult.Detail)))
            }
            if ($permissionRows.Count -gt 0) {
                $sharePermissionSource = 'Get-SmbShareAccess'
            }
            elseif ([string]$shareInfo.UNCPath -match '^\\\\' -and -not [string]::IsNullOrWhiteSpace([string]$shareInfo.ComputerName) -and -not [string]::IsNullOrWhiteSpace([string]$shareInfo.ShareName)) {
                $nativeSharePermissionAttempted = $true
                Write-ShareSurferStatus -Phase 'Collect' -Message ('Get-SmbShareAccess did not return share permissions for {0}; trying native SMB/RPC descriptor fallback.' -f $shareInfo.UNCPath) -Quiet:$Quiet
                $nativeEvidence = Get-ShareSurferNativeSharePermissionEvidence -ShareId $shareId -ComputerName $shareInfo.ComputerName -ShareName $shareInfo.ShareName
                if ([bool]$nativeEvidence.Success) {
                    $permissionRows = @($nativeEvidence.Rows)
                    $sharePermissionSource = 'NativeSmbRpc'
                    [void]$scanEvents.Add((New-ShareSurferEvent -EventType $nativeEvidence.EventType -Source 'NativeSmbRpc' -ShareId $shareId -Message $nativeEvidence.Message -Detail $nativeEvidence.Detail))
                    Write-ShareSurferStatus -Phase 'Collect' -Message ('Collected {0} share-level permission row(s) for {1} through native SMB/RPC fallback.' -f $permissionRows.Count, $shareInfo.UNCPath) -Quiet:$Quiet
                }
                else {
                    $nativeEventLevel = if ([string]$nativeEvidence.Severity -eq 'Info') { 'Info' } else { 'Warning' }
                    [void]$scanErrors.Add([pscustomobject]@{
                        ShareId = $shareId
                        FullPath = $shareInfo.UNCPath
                        ErrorType = $nativeEvidence.ErrorType
                        Severity = $nativeEvidence.Severity
                        Source = $nativeEvidence.Source
                        Message = $nativeEvidence.Message
                        Detail = $nativeEvidence.Detail
                    })
                    [void]$scanEvents.Add((New-ShareSurferEvent -Level $nativeEventLevel -EventType $nativeEvidence.EventType -Source $nativeEvidence.Source -ShareId $shareId -Message $nativeEvidence.Message -Detail $nativeEvidence.Detail))
                }
            }
            foreach ($permissionRow in $permissionRows) {
                [void]$sharePermissions.Add($permissionRow)
            }
        }
        if (-not $SkipSharePermissionCollection -and $permissionRows.Count -eq 0) {
            $permissionMessage = if ($nativeSharePermissionAttempted) {
                'Share-level permissions were not collected through Get-SmbShareAccess or NativeSmbRpc.'
            }
            elseif (-not [string]::IsNullOrWhiteSpace($localShareVerificationMessage)) {
                $localShareVerificationMessage
            }
            else {
                'Share-level permissions were not collected through Get-SmbShareAccess.'
            }
            $permissionErrorType = if (-not [string]::IsNullOrWhiteSpace($localShareVerificationMessage)) { 'SharePermissionVerificationSkipped' } else { 'SharePermissionCollectionUnavailable' }
            $permissionErrorSource = if (-not [string]::IsNullOrWhiteSpace($localShareVerificationMessage)) { 'Get-SmbShare' } else { 'Get-SmbShareAccess' }
            [void]$scanErrors.Add([pscustomobject]@{
                ShareId = $shareId
                FullPath = $targetDisplayPath
                ErrorType = $permissionErrorType
                Severity = 'Warning'
                Source = $permissionErrorSource
                Message = $permissionMessage
                Detail = 'Best-effort target path scan cannot prove the share-level access gate for this share.'
            })
            if ($null -ne $permissionResult -and -not [string]::IsNullOrWhiteSpace([string]$permissionResult.ErrorType) -and [string]$permissionResult.ErrorType -ne 'CimSessionRequired') {
                [void]$scanErrors.Add([pscustomobject]@{
                    ShareId = $shareId
                    FullPath = $targetDisplayPath
                    ErrorType = [string]$permissionResult.ErrorType
                    Severity = [string]$permissionResult.Severity
                    Source = [string]$permissionResult.Source
                    Message = [string]$permissionResult.Message
                    Detail = [string]$permissionResult.Detail
                })
            }
            [void]$scanEvents.Add((New-ShareSurferEvent -Level 'Warning' -EventType $permissionErrorType -Source $permissionErrorSource -ShareId $shareId -Message $permissionMessage -Detail $targetDisplayPath))
            Write-ShareSurferStatus -Phase 'Collect' -Message ('Share-level permissions were unavailable for {0}; continuing with file/folder ACL collection.' -f $targetDisplayPath) -Quiet:$Quiet
        }

        [void]$shares.Add([pscustomobject]@{
            ShareId = $shareId
            Source = if ($SkipSharePermissionCollection) { 'TargetPath' } elseif ($permissionRows.Count -gt 0) { $sharePermissionSource } else { 'BestEffort' }
            ComputerName = $shareInfo.ComputerName
            ShareName = $shareInfo.ShareName
            UNCPath = $shareInfo.UNCPath
            LocalPath = $targetDisplayPath
            Description = 'Best-effort target path scan'
            PartialData = (-not $SkipSharePermissionCollection -and $permissionRows.Count -eq 0)
            PartialReason = if (-not $SkipSharePermissionCollection -and $permissionRows.Count -eq 0) { $permissionMessage } else { '' }
        })

        $scanItems = New-Object System.Collections.ArrayList
        [void]$scanItems.Add($targetItem)
        $directoriesToEnumerate = New-Object -TypeName 'System.Collections.Generic.Queue[object]'
        $targetIsReparsePoint = Test-ShareSurferItemIsReparsePoint -Item $targetItem
        if ($targetItem.PSIsContainer) {
            $directoriesToEnumerate.Enqueue($targetItem)
            if ($targetIsReparsePoint) {
                [void]$scanEvents.Add((New-ShareSurferEvent -Level 'Info' -EventType 'ReparsePointTargetEnumerated' -Source 'Get-ChildItem' -ShareId $shareId -Message ('Enumerating explicit reparse-point target {0}.' -f $targetDisplayPath) -Detail 'The operator selected this target directly, so ShareSurfer treats it as scan intent while still skipping child reparse points.'))
            }
        }

        Write-ShareSurferStatus -Phase 'Collect' -Message ('Enumerating folders{0} under {1}.' -f $(if ($IncludeFiles) { ' and files' } else { '' }), $targetDisplayPath) -Quiet:$Quiet
        while ($directoriesToEnumerate.Count -gt 0) {
            $directoryItem = $directoriesToEnumerate.Dequeue()
            $directoryDisplayPath = ConvertFrom-ShareSurferFilesystemPath -Path ([string]$directoryItem.FullName)
            $childErrors = @()
            $children = @(Get-ChildItem -LiteralPath (ConvertTo-ShareSurferFilesystemPath -Path ([string]$directoryItem.FullName)) -Force -ErrorAction SilentlyContinue -ErrorVariable childErrors)
            foreach ($childError in $childErrors) {
                $errorPath = ConvertFrom-ShareSurferFilesystemPath -Path (Get-ShareSurferCollectionErrorPath -ErrorRecord $childError -FallbackPath $directoryDisplayPath)
                [void]$scanErrors.Add([pscustomobject]@{
                    ShareId = $shareId
                    FullPath = $errorPath
                    ErrorType = 'EnumerationError'
                    Severity = 'Warning'
                    Source = 'Get-ChildItem'
                    Message = [string]$childError.Exception.Message
                    Detail = ('FallbackPath={0}' -f $directoryDisplayPath)
                })
                [void]$scanEvents.Add((New-ShareSurferEvent -Level 'Warning' -EventType 'EnumerationError' -Source 'Get-ChildItem' -ShareId $shareId -Message ('Unable to enumerate child path {0}' -f $errorPath) -Detail ([string]$childError.Exception.Message)))
            }
            foreach ($child in $children) {
                $isReparsePoint = Test-ShareSurferItemIsReparsePoint -Item $child
                if ($child.PSIsContainer -or $IncludeFiles) {
                    [void]$scanItems.Add($child)
                }
                if ($child.PSIsContainer -and -not $isReparsePoint) {
                    $directoriesToEnumerate.Enqueue($child)
                }
                elseif ($child.PSIsContainer -and $isReparsePoint) {
                    $childDisplayPath = ConvertFrom-ShareSurferFilesystemPath -Path ([string]$child.FullName)
                    [void]$scanEvents.Add((New-ShareSurferEvent -Level 'Warning' -EventType 'ReparsePointSkipped' -Source 'Get-ChildItem' -ShareId $shareId -Message ('Skipped recursive traversal into reparse point {0}.' -f $childDisplayPath) -Detail 'The reparse-point directory is recorded as an item, but ShareSurfer does not descend into it.'))
                }
            }
        }

        Write-ShareSurferStatus -Phase 'Collect' -Message ('Reading ACLs for {0} item(s) under {1}.' -f @($scanItems).Count, $targetDisplayPath) -Quiet:$Quiet
        $processedItemCount = 0
        foreach ($scanItem in $scanItems) {
            $processedItemCount++
            if ($processedItemCount -gt 1 -and ($processedItemCount % 1000) -eq 0) {
                Write-ShareSurferStatus -Phase 'Collect' -Message ('Processed {0} of {1} item(s) under {2}.' -f $processedItemCount, @($scanItems).Count, $targetDisplayPath) -Quiet:$Quiet
            }
            $scanItemDisplayPath = ConvertFrom-ShareSurferFilesystemPath -Path ([string]$scanItem.FullName)
            $relative = $scanItemDisplayPath.Substring($targetDisplayPath.Length).TrimStart([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
            $depth = 0
            if ($relative -ne '') {
                $depth = @($relative -split '[\\/]' | Where-Object { $_ -ne '' }).Count
            }
            $itemId = [guid]::NewGuid().ToString('N')
            $owner = ''
            $inheritanceEnabled = $true
            $inheritanceBrokenAt = ''

            if ($AclProvider -eq 'NativeWin32Security') {
                try {
                    $nativeSecurity = Get-ShareSurferNativeSecurityInfo -Path ([string]$scanItem.FullName) -ShareId $shareId -ItemId $itemId -FullPath $scanItemDisplayPath -Depth $depth
                    $owner = [string]$nativeSecurity.Owner
                    $inheritanceEnabled = [bool]$nativeSecurity.InheritanceEnabled
                    if (-not $inheritanceEnabled) {
                        $inheritanceBrokenAt = [string]$nativeSecurity.InheritanceBrokenAt
                        if ($inheritanceBrokenAt -eq '') {
                            $inheritanceBrokenAt = $scanItemDisplayPath
                        }
                    }
                    foreach ($access in @(ConvertTo-ShareSurferArray $nativeSecurity.AclEntries)) {
                        [void]$aclEntries.Add($access)
                    }
                }
                catch {
                    $nativeError = Get-ShareSurferNativeSecurityErrorInfo -Exception $_.Exception -DefaultDetail 'GetNamedSecurityInfoW owner/DACL read failed.'
                    [void]$scanErrors.Add([pscustomobject]@{
                        ShareId = $shareId
                        ItemId = $itemId
                        FullPath = $scanItemDisplayPath
                        ErrorType = $nativeError.ErrorType
                        Severity = 'Warning'
                        Source = 'NativeWin32Security'
                        Message = $nativeError.Message
                        Detail = $nativeError.Detail
                    })
                    [void]$scanEvents.Add((New-ShareSurferEvent -Level 'Warning' -EventType $nativeError.ErrorType -Source 'NativeWin32Security' -ShareId $shareId -ItemId $itemId -Message ('Unable to read native owner/DACL security descriptor for {0}.' -f $scanItemDisplayPath) -Detail $nativeError.Message))
                    $inheritanceEnabled = $true
                }
            }
            elseif ($null -ne $getAcl) {
                try {
                    $acl = Get-Acl -LiteralPath (ConvertTo-ShareSurferFilesystemPath -Path ([string]$scanItem.FullName)) -ErrorAction Stop
                    $owner = $acl.Owner
                    $inheritanceEnabled = -not $acl.AreAccessRulesProtected
                    if ($acl.AreAccessRulesProtected) {
                        $inheritanceBrokenAt = $scanItemDisplayPath
                    }
                    foreach ($access in $acl.Access) {
                        [void]$aclEntries.Add([pscustomobject]@{
                            ItemId = $itemId
                            ShareId = $shareId
                            FullPath = $scanItemDisplayPath
                            Identity = [string]$access.IdentityReference
                            Rights = [string]$access.FileSystemRights
                            AccessMask = ''
                            AccessControlType = [string]$access.AccessControlType
                            IsInherited = [bool]$access.IsInherited
                            InheritanceFlags = [string]$access.InheritanceFlags
                            PropagationFlags = [string]$access.PropagationFlags
                            Depth = $depth
                        })
                    }
                }
                catch {
                    [void]$scanErrors.Add([pscustomobject]@{
                        ShareId = $shareId
                        FullPath = $scanItemDisplayPath
                        ErrorType = 'AclReadError'
                        Message = [string]$_.Exception.Message
                    })
                    $inheritanceEnabled = $true
                }
            }

            [void]$items.Add([pscustomobject]@{
                ItemId = $itemId
                ShareId = $shareId
                ItemType = if ($scanItem.PSIsContainer) { 'Directory' } else { 'File' }
                FullPath = $scanItemDisplayPath
                RelativePath = $relative
                Depth = $depth
                Owner = $owner
                InheritanceEnabled = $inheritanceEnabled
                InheritanceBrokenAt = $inheritanceBrokenAt
            })
        }
        Write-ShareSurferStatus -Phase 'Collect' -Message ('Finished target {0}. Items={1}; ACL entries={2}; CollectionErrors={3}' -f $targetDisplayPath, @($scanItems).Count, $aclEntries.Count, $scanErrors.Count) -Quiet:$Quiet
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
    }
}
