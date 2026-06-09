function Get-ShareSurferLocalInventory {
    param(
        [Parameter(Mandatory = $true)]
        [string[]] $TargetPath,

        [switch] $IncludeFiles,

        [switch] $Quiet
    )

    $shares = New-Object System.Collections.ArrayList
    $items = New-Object System.Collections.ArrayList
    $aclEntries = New-Object System.Collections.ArrayList
    $sharePermissions = New-Object System.Collections.ArrayList
    $scanErrors = New-Object System.Collections.ArrayList
    $scanEvents = New-Object System.Collections.ArrayList

    $getAcl = Get-Command Get-Acl -ErrorAction SilentlyContinue
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
        Write-ShareSurferStatus -Phase 'Collect' -Message ('Collecting share-level permission evidence for {0}.' -f $targetDisplayPath) -Quiet:$Quiet
        $permissionRows = @(Get-ShareSurferSharePermissionRows -ShareId $shareId -ShareName $shareInfo.ShareName -ComputerName $shareInfo.ComputerName)
        foreach ($permissionRow in $permissionRows) {
            [void]$sharePermissions.Add($permissionRow)
        }
        if ($permissionRows.Count -eq 0) {
            $permissionMessage = 'Share-level permissions were not collected through Get-SmbShareAccess.'
            [void]$scanErrors.Add([pscustomobject]@{
                ShareId = $shareId
                FullPath = $targetDisplayPath
                ErrorType = 'SharePermissionCollectionUnavailable'
                Severity = 'Warning'
                Source = 'Get-SmbShareAccess'
                Message = $permissionMessage
                Detail = 'Best-effort target path scan cannot prove the share-level access gate for this share.'
            })
            [void]$scanEvents.Add((New-ShareSurferEvent -Level 'Warning' -EventType 'SharePermissionCollectionUnavailable' -Source 'Get-SmbShareAccess' -ShareId $shareId -Message $permissionMessage -Detail $targetDisplayPath))
            Write-ShareSurferStatus -Phase 'Collect' -Message ('Share-level permissions were unavailable for {0}; continuing with file/folder ACL collection.' -f $targetDisplayPath) -Quiet:$Quiet
        }

        [void]$shares.Add([pscustomobject]@{
            ShareId = $shareId
            Source = if ($permissionRows.Count -gt 0) { 'Get-SmbShareAccess' } else { 'BestEffort' }
            ComputerName = $shareInfo.ComputerName
            ShareName = $shareInfo.ShareName
            UNCPath = $shareInfo.UNCPath
            LocalPath = $targetDisplayPath
            Description = 'Best-effort target path scan'
            PartialData = ($permissionRows.Count -eq 0)
            PartialReason = if ($permissionRows.Count -eq 0) { 'Share-level permissions were not collected through Get-SmbShareAccess.' } else { '' }
        })

        $scanItems = @($targetItem)
        $childErrors = @()
        Write-ShareSurferStatus -Phase 'Collect' -Message ('Enumerating folders{0} under {1}.' -f $(if ($IncludeFiles) { ' and files' } else { '' }), $targetDisplayPath) -Quiet:$Quiet
        $children = Get-ChildItem -LiteralPath (ConvertTo-ShareSurferFilesystemPath -Path ([string]$targetItem.FullName)) -Recurse -Force -ErrorAction SilentlyContinue -ErrorVariable childErrors
        foreach ($childError in $childErrors) {
            $errorPath = ConvertFrom-ShareSurferFilesystemPath -Path (Get-ShareSurferCollectionErrorPath -ErrorRecord $childError -FallbackPath $targetDisplayPath)
            [void]$scanErrors.Add([pscustomobject]@{
                ShareId = $shareId
                FullPath = $errorPath
                ErrorType = 'EnumerationError'
                Severity = 'Warning'
                Source = 'Get-ChildItem'
                Message = [string]$childError.Exception.Message
                Detail = ('FallbackPath={0}' -f $targetDisplayPath)
            })
            [void]$scanEvents.Add((New-ShareSurferEvent -Level 'Warning' -EventType 'EnumerationError' -Source 'Get-ChildItem' -ShareId $shareId -Message ('Unable to enumerate child path {0}' -f $errorPath) -Detail ([string]$childError.Exception.Message)))
        }
        foreach ($child in $children) {
            if ($child.PSIsContainer -or $IncludeFiles) {
                $scanItems += $child
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

            if ($null -ne $getAcl) {
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
