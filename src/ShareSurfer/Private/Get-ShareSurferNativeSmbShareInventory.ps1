function Get-ShareSurferNativeSmbShareInventory {
    param(
        [Parameter(Mandatory = $true)]
        [string] $ComputerName,

        [Parameter(Mandatory = $true)]
        [string[]] $ShareName,

        [switch] $IncludeFiles,

        [switch] $Quiet
    )

    $shares = New-Object System.Collections.ArrayList
    $items = New-Object System.Collections.ArrayList
    $aclEntries = New-Object System.Collections.ArrayList
    $sharePermissions = New-Object System.Collections.ArrayList
    $scanErrors = New-Object System.Collections.ArrayList
    $scanEvents = New-Object System.Collections.ArrayList

    [void]$scanEvents.Add((New-ShareSurferEvent -EventType 'CollectionProviderSelected' -Source 'NativeSmbRpc' -Message ('Using native SMB/RPC provider for {0} explicit share target(s) on {1}.' -f @($ShareName).Count, $ComputerName) -Detail 'Win32 NetShareGetInfo and GetNamedSecurityInfoW'))

    foreach ($name in $ShareName) {
        $shareId = 'share-{0}-{1}' -f ($ComputerName -replace '[^A-Za-z0-9]', '-'), ($name -replace '[^A-Za-z0-9]', '-')
        $uncPath = '\\{0}\{1}' -f $ComputerName, $name
        $localPath = ''
        $description = ''
        $scanPath = $uncPath
        $metadataResolved = $false

        Write-ShareSurferStatus -Phase 'Collect' -Message ('Resolving SMB share {0} with native SMB/RPC.' -f $uncPath) -Quiet:$Quiet
        try {
            $rpcShare = Get-ShareSurferSmbRpcShareInfo -ComputerName $ComputerName -ShareName $name -PreferSecurityDescriptor
            if ($null -ne $rpcShare) {
                $metadataResolved = $true
                $localPath = [string]$rpcShare.Path
                $description = [string]$rpcShare.Description
                if ($localPath -ne '' -and (Test-Path -LiteralPath (ConvertTo-ShareSurferFilesystemPath -Path $localPath))) {
                    $scanPath = $localPath
                }

                [void]$scanEvents.Add((New-ShareSurferEvent -EventType 'ShareTargetResolved' -Source 'NativeSmbRpc' -ShareId $shareId -Message ('Resolved share target {0} through native SMB/RPC.' -f $uncPath) -Detail $scanPath))

                $descriptorBytes = @()
                if ($null -ne $rpcShare.PSObject.Properties['SecurityDescriptorBytes']) {
                    $descriptorBytes = @($rpcShare.SecurityDescriptorBytes)
                }

                if ($descriptorBytes.Count -gt 0) {
                    try {
                        $permissionRows = @(ConvertTo-ShareSurferSharePermissionRowsFromSecurityDescriptor -ShareId $shareId -SecurityDescriptorBytes ([byte[]]$descriptorBytes))
                        foreach ($permission in $permissionRows) {
                            [void]$sharePermissions.Add($permission)
                        }
                        [void]$scanEvents.Add((New-ShareSurferEvent -EventType 'SharePermissionsCollected' -Source 'NativeSmbRpc' -ShareId $shareId -Message ('Collected {0} share-level permission row(s) for {1} through native SMB/RPC.' -f $permissionRows.Count, $uncPath) -Detail 'SHARE_INFO_502 security descriptor'))
                    }
                    catch {
                        [void]$scanErrors.Add([pscustomobject]@{
                            ShareId = $shareId
                            FullPath = $uncPath
                            ErrorType = 'NativeShareSecurityDescriptorParseFailed'
                            Severity = 'Warning'
                            Source = 'NativeSmbRpc'
                            Message = 'Native SMB/RPC returned a share security descriptor, but ShareSurfer could not parse it into share permission rows.'
                            Detail = ('SMB/RPC reachability was proven for this share, but the returned SHARE_INFO_502 security descriptor was unusable. Parser message: {0}' -f [string]$_.Exception.Message)
                        })
                        [void]$scanEvents.Add((New-ShareSurferEvent -Level 'Warning' -EventType 'NativeShareSecurityDescriptorParseFailed' -Source 'NativeSmbRpc' -ShareId $shareId -Message ('Unable to parse native share security descriptor for {0}.' -f $uncPath) -Detail ([string]$_.Exception.Message)))
                    }
                }
                elseif ($null -ne $rpcShare.PSObject.Properties['SharePermissions']) {
                    $permissionRows = @(ConvertTo-ShareSurferArray $rpcShare.SharePermissions)
                    foreach ($permission in $permissionRows) {
                        $permission | Add-Member -MemberType NoteProperty -Name ShareId -Value $shareId -Force
                        if ($null -eq $permission.PSObject.Properties['Source'] -or [string]::IsNullOrWhiteSpace([string]$permission.Source)) {
                            $permission | Add-Member -MemberType NoteProperty -Name Source -Value 'NativeSmbRpc' -Force
                        }
                        [void]$sharePermissions.Add($permission)
                    }
                    [void]$scanEvents.Add((New-ShareSurferEvent -EventType 'SharePermissionsCollected' -Source 'NativeSmbRpc' -ShareId $shareId -Message ('Collected {0} share-level permission row(s) for {1} through native SMB/RPC provider evidence.' -f $permissionRows.Count, $uncPath) -Detail 'Provider-supplied share permission rows'))
                }
                else {
                    [void]$scanErrors.Add([pscustomobject]@{
                        ShareId = $shareId
                        FullPath = $uncPath
                        ErrorType = 'NativeShareSecurityDescriptorUnavailable'
                        Severity = 'Warning'
                        Source = 'NativeSmbRpc'
                        Message = 'Native SMB/RPC reached the share, but no share security descriptor was returned.'
                        Detail = 'NetShareGetInfo level 502 did not return SHARE_INFO_502 security descriptor bytes, so share-level permissions remain partial even though SMB/RPC was reachable.'
                    })
                    [void]$scanEvents.Add((New-ShareSurferEvent -Level 'Warning' -EventType 'NativeShareSecurityDescriptorUnavailable' -Source 'NativeSmbRpc' -ShareId $shareId -Message ('Native SMB/RPC reached {0}, but no share security descriptor was returned.' -f $uncPath) -Detail 'Missing SHARE_INFO_502 security descriptor'))
                }
            }
            else {
                [void]$scanErrors.Add([pscustomobject]@{
                    ShareId = $shareId
                    FullPath = $uncPath
                    ErrorType = 'ShareLookupError'
                    Severity = 'High'
                    Source = 'NativeSmbRpc'
                    Message = 'Native SMB/RPC did not return share metadata.'
                    Detail = $uncPath
                })
                [void]$scanEvents.Add((New-ShareSurferEvent -Level 'Warning' -EventType 'ShareLookupError' -Source 'NativeSmbRpc' -ShareId $shareId -Message ('Native SMB/RPC did not return share metadata for {0}.' -f $uncPath) -Detail $uncPath))
            }
        }
        catch {
            [void]$scanErrors.Add([pscustomobject]@{
                ShareId = $shareId
                FullPath = $uncPath
                ErrorType = 'SmbRpcShareLookupError'
                Severity = 'High'
                Source = 'NativeSmbRpc'
                Message = [string]$_.Exception.Message
                Detail = $uncPath
            })
            [void]$scanEvents.Add((New-ShareSurferEvent -Level 'Warning' -EventType 'SmbRpcShareLookupError' -Source 'NativeSmbRpc' -ShareId $shareId -Message ('Native SMB/RPC share lookup failed for {0}.' -f $uncPath) -Detail ([string]$_.Exception.Message)))
        }

        Write-ShareSurferStatus -Phase 'Collect' -Message ('Enumerating {0} with native security reads.' -f $scanPath) -Quiet:$Quiet
        try {
            $inventory = Get-ShareSurferLocalInventory -TargetPath @($scanPath) -IncludeFiles:$IncludeFiles -Quiet:$Quiet -SkipSharePermissionCollection -AclProvider NativeWin32Security
            foreach ($row in @(ConvertTo-ShareSurferArray $inventory.Shares)) {
                $row.ShareId = $shareId
                $row.Source = 'NativeSmbRpc'
                $row.ComputerName = $ComputerName
                $row.ShareName = $name
                $row.UNCPath = $uncPath
                if ($localPath -ne '') {
                    $row.LocalPath = $localPath
                }
                $row.Description = $description
                if (-not $metadataResolved) {
                    $row.PartialData = $true
                    $row.PartialReason = 'Native SMB/RPC share metadata was not collected.'
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
                [void]$scanErrors.Add($row)
            }
            foreach ($row in @(ConvertTo-ShareSurferArray $inventory.ScanEvents)) {
                $row.ShareId = $shareId
                [void]$scanEvents.Add($row)
            }
        }
        catch {
            [void]$shares.Add([pscustomobject]@{
                ShareId = $shareId
                Source = 'NativeSmbRpc'
                ComputerName = $ComputerName
                ShareName = $name
                UNCPath = $uncPath
                LocalPath = $localPath
                Description = $description
                PartialData = $true
                PartialReason = 'Unable to enumerate share path with native provider.'
            })
            [void]$scanErrors.Add([pscustomobject]@{
                ShareId = $shareId
                FullPath = $uncPath
                ErrorType = 'ShareEnumerationError'
                Severity = 'High'
                Source = 'NativeSmbRpc'
                Message = [string]$_.Exception.Message
                Detail = $scanPath
            })
        }

        if (@($sharePermissions | Where-Object { [string]$_.ShareId -eq $shareId }).Count -eq 0) {
            $shareRow = @($shares | Where-Object { [string]$_.ShareId -eq $shareId } | Select-Object -First 1)
            if ($shareRow.Count -gt 0) {
                $shareRow[0].PartialData = $true
                $existingReason = ''
                if ($null -ne $shareRow[0].PSObject.Properties['PartialReason']) {
                    $existingReason = [string]$shareRow[0].PartialReason
                }
                $nativeReason = 'Share-level permissions were not collected through NativeSmbRpc.'
                if ([string]::IsNullOrWhiteSpace($existingReason)) {
                    $shareRow[0].PartialReason = $nativeReason
                }
                elseif ($existingReason -notlike ('*{0}*' -f $nativeReason)) {
                    $shareRow[0].PartialReason = '{0}; {1}' -f $existingReason.TrimEnd('.', ';', ' '), $nativeReason
                }
            }
        }

        Write-ShareSurferStatus -Phase 'Collect' -Message ('Finished native SMB share {0}.' -f $uncPath) -Quiet:$Quiet
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
