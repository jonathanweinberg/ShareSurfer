function Get-ShareSurferLocalInventory {
    param(
        [Parameter(Mandatory = $true)]
        [string[]] $TargetPath,

        [switch] $IncludeFiles
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
        $targetItem = Get-Item -LiteralPath $target -ErrorAction Stop
        $shareInfo = Get-ShareSurferTargetShareInfo -TargetPath $target -TargetItem $targetItem
        [void]$scanEvents.Add((New-ShareSurferEvent -EventType 'TargetPathResolved' -Source 'TargetPath' -ShareId $shareId -Message ('Resolved target path {0}' -f $target) -Detail $targetItem.FullName))
        $permissionRows = @(Get-ShareSurferSharePermissionRows -ShareId $shareId -ShareName $shareInfo.ShareName -ComputerName $shareInfo.ComputerName)
        foreach ($permissionRow in $permissionRows) {
            [void]$sharePermissions.Add($permissionRow)
        }

        [void]$shares.Add([pscustomobject]@{
            ShareId = $shareId
            Source = if ($permissionRows.Count -gt 0) { 'Get-SmbShareAccess' } else { 'BestEffort' }
            ComputerName = $shareInfo.ComputerName
            ShareName = $shareInfo.ShareName
            UNCPath = $shareInfo.UNCPath
            LocalPath = $targetItem.FullName
            Description = 'Best-effort target path scan'
            PartialData = ($permissionRows.Count -eq 0)
            PartialReason = if ($permissionRows.Count -eq 0) { 'Share-level permissions were not collected through Get-SmbShareAccess.' } else { '' }
        })

        $scanItems = @($targetItem)
        $childErrors = @()
        $children = Get-ChildItem -LiteralPath $targetItem.FullName -Recurse -Force -ErrorAction SilentlyContinue -ErrorVariable childErrors
        foreach ($childError in $childErrors) {
            [void]$scanErrors.Add([pscustomobject]@{
                ShareId = $shareId
                FullPath = $targetItem.FullName
                ErrorType = 'EnumerationError'
                Message = [string]$childError.Exception.Message
            })
        }
        foreach ($child in $children) {
            if ($child.PSIsContainer -or $IncludeFiles) {
                $scanItems += $child
            }
        }

        foreach ($scanItem in $scanItems) {
            $relative = $scanItem.FullName.Substring($targetItem.FullName.Length).TrimStart([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
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
                    $acl = Get-Acl -LiteralPath $scanItem.FullName -ErrorAction Stop
                    $owner = $acl.Owner
                    $inheritanceEnabled = -not $acl.AreAccessRulesProtected
                    if ($acl.AreAccessRulesProtected) {
                        $inheritanceBrokenAt = $scanItem.FullName
                    }
                    foreach ($access in $acl.Access) {
                        [void]$aclEntries.Add([pscustomobject]@{
                            ItemId = $itemId
                            ShareId = $shareId
                            FullPath = $scanItem.FullName
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
                        FullPath = $scanItem.FullName
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
                FullPath = $scanItem.FullName
                RelativePath = $relative
                Depth = $depth
                Owner = $owner
                InheritanceEnabled = $inheritanceEnabled
                InheritanceBrokenAt = $inheritanceBrokenAt
            })
        }
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
