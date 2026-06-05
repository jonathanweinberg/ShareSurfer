function Get-ShareSurferSmbShareInventory {
    param(
        [Parameter(Mandatory = $true)]
        [string] $ComputerName,

        [Parameter(Mandatory = $true)]
        [string[]] $ShareName,

        [switch] $IncludeFiles
    )

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

    if (Test-ShareSurferRemoteComputerName -ComputerName $ComputerName) {
        $remoteCimSessionAttempted = $true
        $newCimSession = Get-Command New-CimSession -ErrorAction SilentlyContinue
        if ($null -ne $newCimSession) {
            try {
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
            $localPath = ''
            $description = ''
            $scanPath = $uncPath
            $source = 'BestEffort'

            if ($null -ne $getSmbShare) {
                try {
                    if ($null -ne $cimSession) {
                        $share = Get-SmbShare -Name $name -CimSession $cimSession
                    }
                    elseif (-not (Test-ShareSurferRemoteComputerName -ComputerName $ComputerName)) {
                        $share = Get-SmbShare -Name $name
                    }
                    else {
                        $share = $null
                    }
                    if ($null -ne $share) {
                        $localPath = [string]$share.Path
                        $description = [string]$share.Description
                        if ($localPath -ne '' -and (Test-Path -LiteralPath $localPath)) {
                            $scanPath = $localPath
                        }
                        $source = 'Get-SmbShare'
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
            }

            [void]$scanEvents.Add((New-ShareSurferEvent -EventType 'ShareTargetResolved' -Source 'Get-SmbShare' -ShareId $shareId -Message ('Resolved share target {0}' -f $uncPath) -Detail $scanPath))

            try {
                $inventory = Get-ShareSurferLocalInventory -TargetPath @($scanPath) -IncludeFiles:$IncludeFiles
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

            $permissionRows = @(Get-ShareSurferSharePermissionRows -ShareId $shareId -ShareName $name -ComputerName $ComputerName -CimSession $cimSession -SkipRemoteCimSessionCreation:($remoteCimSessionAttempted -and -not $remoteCimSessionAvailable))
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
                    $shareRow[0].PartialData = $true
                    $shareRow[0].PartialReason = 'Share-level permissions were not collected through Get-SmbShareAccess.'
                }
            }
        }
    }
    finally {
        if ($null -ne $cimSession) {
            Remove-CimSession -CimSession $cimSession -ErrorAction SilentlyContinue
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
