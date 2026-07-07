function Get-ShareSurferConflicts {
    param(
        [Parameter(Mandatory = $true)]
        $SharePermissions,

        [Parameter(Mandatory = $true)]
        $AclEntries,

        [int] $StatusIntervalSeconds = 15,

        [switch] $ShowProgress,

        [switch] $Quiet
    )

    $conflicts = New-Object System.Collections.ArrayList
    $sharePermissionsList = @(ConvertTo-ShareSurferArray $SharePermissions)
    $aclEntriesList = @(ConvertTo-ShareSurferArray $AclEntries)
    $statusClock = [System.Diagnostics.Stopwatch]::StartNew()
    $statusState = @{ LastSeconds = -999.0 }
    $showConflictProgress = [bool]$ShowProgress -and -not [bool]$Quiet

    function Write-ShareSurferConflictProgress {
        param(
            [string] $Message,

            [switch] $Force
        )

        if ($Quiet) {
            return
        }

        $elapsed = [double]$statusClock.Elapsed.TotalSeconds
        if ($Force -or $StatusIntervalSeconds -le 0 -or ($elapsed - $statusState.LastSeconds) -ge $StatusIntervalSeconds) {
            $statusState.LastSeconds = $elapsed
            Write-ShareSurferStatus -Phase 'Export' -Message $Message
        }
    }

    $sharePermissionsByShare = @{}
    $shareHasBroadAllowGate = @{}
    foreach ($permission in $sharePermissionsList) {
        if (-not $sharePermissionsByShare.ContainsKey($permission.ShareId)) {
            $sharePermissionsByShare[$permission.ShareId] = @{}
        }
        $identityKey = ([string]$permission.Identity).ToUpperInvariant()
        if (-not $sharePermissionsByShare[$permission.ShareId].ContainsKey($identityKey)) {
            $sharePermissionsByShare[$permission.ShareId][$identityKey] = New-Object System.Collections.ArrayList
        }
        [void]$sharePermissionsByShare[$permission.ShareId][$identityKey].Add($permission)
        if ((Get-ShareSurferAccessType $permission.AccessControlType) -eq 'Allow' -and (Test-ShareSurferBroadSharePrincipal -Identity $permission.Identity)) {
            $shareHasBroadAllowGate[$permission.ShareId] = $true
        }
    }

    $shareAllowRankByShareIdentity = @{}
    $shareRightsSummaryByShareIdentity = @{}
    foreach ($shareId in $sharePermissionsByShare.Keys) {
        foreach ($identityKey in $sharePermissionsByShare[$shareId].Keys) {
            $cacheKey = '{0}|{1}' -f [string]$shareId, [string]$identityKey
            $entries = $sharePermissionsByShare[$shareId][$identityKey]
            $shareAllowRankByShareIdentity[$cacheKey] = Get-ShareSurferMaxRightsRank -Entries $entries -AccessType 'Allow'
            $shareRightsSummaryByShareIdentity[$cacheKey] = Get-ShareSurferRightsSummary -Entries $entries
        }
    }

    $ntfsByShare = @{}
    $ntfsIdentityExamples = @{}
    $ntfsAllowPatterns = @{}
    $ntfsDenyItemIdentityKeys = @{}
    $aclIndex = 0
    $aclTotal = $aclEntriesList.Count
    foreach ($ace in $aclEntriesList) {
        $aclIndex++
        if (-not $ntfsByShare.ContainsKey($ace.ShareId)) {
            $ntfsByShare[$ace.ShareId] = @{}
        }

        $identityKey = ([string]$ace.Identity).ToUpperInvariant()
        $ntfsByShare[$ace.ShareId][$identityKey] = $true

        $shareIdentityKey = '{0}|{1}' -f [string]$ace.ShareId, $identityKey
        if (-not $ntfsIdentityExamples.ContainsKey($shareIdentityKey)) {
            $ntfsIdentityExamples[$shareIdentityKey] = @{
                ShareId = [string]$ace.ShareId
                IdentityKey = $identityKey
                Ace = $ace
            }
        }

        $accessType = Get-ShareSurferAccessType $ace.AccessControlType
        if ($accessType -eq 'Allow') {
            $allowPatternKey = '{0}|{1}|{2}' -f [string]$ace.ShareId, $identityKey, ([string]$ace.Rights).ToUpperInvariant()
            if (-not $ntfsAllowPatterns.ContainsKey($allowPatternKey)) {
                $ntfsAllowPatterns[$allowPatternKey] = @{
                    ShareId = [string]$ace.ShareId
                    IdentityKey = $identityKey
                    Ace = $ace
                    NtfsRank = Get-ShareSurferRightsRank -Rights $ace.Rights
                }
            }
        }
        elseif ($accessType -eq 'Deny') {
            $denyStateKey = '{0}|{1}|{2}' -f [string]$ace.ShareId, [string]$ace.ItemId, $identityKey
            $ntfsDenyItemIdentityKeys[$denyStateKey] = $true
        }

        if ($showConflictProgress) {
            Write-ShareSurferConflictProgress -Message ('Conflict classification progress: indexed {0}/{1} ACL row(s).' -f $aclIndex, $aclTotal)
        }
    }

    $identityPatternIndex = 0
    $identityPatternTotal = $ntfsIdentityExamples.Keys.Count
    foreach ($shareIdentityKey in $ntfsIdentityExamples.Keys) {
        $identityPatternIndex++
        $state = $ntfsIdentityExamples[$shareIdentityKey]
        $shareId = [string]$state['ShareId']
        $identityKey = [string]$state['IdentityKey']
        $ace = $state['Ace']
        $shareMap = @{}
        if ($sharePermissionsByShare.ContainsKey($shareId)) {
            $shareMap = $sharePermissionsByShare[$shareId]
        }

        $hasBroadAllowGate = ($shareHasBroadAllowGate.ContainsKey($shareId) -and [bool]$shareHasBroadAllowGate[$shareId])
        if ($shareMap.Count -gt 0 -and -not $shareMap.ContainsKey($identityKey) -and -not $hasBroadAllowGate) {
            [void]$conflicts.Add((New-ShareSurferConflict -ConflictType 'NtfsIdentityMissingShareGate' -ShareId $shareId -ItemId $ace.ItemId -Identity $ace.Identity -ShareRights '' -NtfsRights $ace.Rights -Severity 'High' -Message 'NTFS grants rights to an identity that does not appear in the share-level permission gate.'))
        }

        if ($showConflictProgress) {
            Write-ShareSurferConflictProgress -Message ('Conflict classification progress: checked {0}/{1} NTFS identity pattern(s); conflicts={2}.' -f $identityPatternIndex, $identityPatternTotal, $conflicts.Count)
        }
    }

    $allowPatternIndex = 0
    $allowPatternTotal = $ntfsAllowPatterns.Keys.Count
    foreach ($allowPatternKey in $ntfsAllowPatterns.Keys) {
        $allowPatternIndex++
        $state = $ntfsAllowPatterns[$allowPatternKey]
        $shareId = [string]$state['ShareId']
        $identityKey = [string]$state['IdentityKey']
        $ace = $state['Ace']
        $shareMap = @{}
        if ($sharePermissionsByShare.ContainsKey($shareId)) {
            $shareMap = $sharePermissionsByShare[$shareId]
        }

        if ($shareMap.ContainsKey($identityKey)) {
            $shareIdentityCacheKey = '{0}|{1}' -f $shareId, $identityKey
            $shareAllowRank = 0
            if ($shareAllowRankByShareIdentity.ContainsKey($shareIdentityCacheKey)) {
                $shareAllowRank = [int]$shareAllowRankByShareIdentity[$shareIdentityCacheKey]
            }
            $ntfsRank = [int]$state['NtfsRank']
            if ($shareAllowRank -gt 0 -and $ntfsRank -gt $shareAllowRank) {
                $shareRightsSummary = ''
                if ($shareRightsSummaryByShareIdentity.ContainsKey($shareIdentityCacheKey)) {
                    $shareRightsSummary = [string]$shareRightsSummaryByShareIdentity[$shareIdentityCacheKey]
                }
                [void]$conflicts.Add((New-ShareSurferConflict -ConflictType 'ShareRightsRestrictNtfs' -ShareId $shareId -ItemId $ace.ItemId -Identity $ace.Identity -ShareRights $shareRightsSummary -NtfsRights $ace.Rights -Severity 'High' -Message 'Share-level rights are narrower than NTFS allow rights for the same identity, so the share gate may restrict access expected from NTFS ACLs.'))
            }
        }
        if ($showConflictProgress) {
            Write-ShareSurferConflictProgress -Message ('Conflict classification progress: checked {0}/{1} NTFS allow pattern(s); conflicts={2}.' -f $allowPatternIndex, $allowPatternTotal, $conflicts.Count)
        }
    }

    foreach ($permission in $sharePermissionsList) {
        $identityKey = ([string]$permission.Identity).ToUpperInvariant()
        $ntfsMap = @{}
        if ($ntfsByShare.ContainsKey($permission.ShareId)) {
            $ntfsMap = $ntfsByShare[$permission.ShareId]
        }

        if ($ntfsMap.Count -gt 0 -and -not $ntfsMap.ContainsKey($identityKey)) {
            [void]$conflicts.Add((New-ShareSurferConflict -ConflictType 'ShareIdentityMissingNtfsEntry' -ShareId $permission.ShareId -Identity $permission.Identity -ShareRights $permission.Rights -NtfsRights '' -Severity 'Info' -Message 'Share-level rights exist for an identity that was not observed in NTFS ACL entries for this share.'))
        }
    }

    if ($ntfsDenyItemIdentityKeys.Count -gt 0) {
        $denyStates = @{}
        $aclIndex = 0
        foreach ($ace in $aclEntriesList) {
            $aclIndex++
            $identityKey = ([string]$ace.Identity).ToUpperInvariant()
            $denyStateKey = '{0}|{1}|{2}' -f [string]$ace.ShareId, [string]$ace.ItemId, $identityKey
            if (-not $ntfsDenyItemIdentityKeys.ContainsKey($denyStateKey)) {
                if ($showConflictProgress) {
                    Write-ShareSurferConflictProgress -Message ('Conflict classification progress: checked {0}/{1} ACL row(s) for deny/collision evidence; conflicts={2}.' -f $aclIndex, $aclTotal, $conflicts.Count)
                }
                continue
            }

            if (-not $denyStates.ContainsKey($denyStateKey)) {
                $denyStates[$denyStateKey] = @{
                    ShareId = [string]$ace.ShareId
                    ItemId = [string]$ace.ItemId
                    IdentityKey = $identityKey
                    Identity = [string]$ace.Identity
                    HasAllow = $false
                    HasDeny = $false
                    AllRightsParts = @{}
                    DenyRightsParts = @{}
                }
            }

            $state = $denyStates[$denyStateKey]
            $accessType = Get-ShareSurferAccessType $ace.AccessControlType
            $rightsPart = '{0}: {1}' -f $accessType, [string]$ace.Rights
            $state['AllRightsParts'][$rightsPart] = $true
            if ($accessType -eq 'Deny') {
                $state['HasDeny'] = $true
                $state['DenyRightsParts'][$rightsPart] = $true
            }
            else {
                $state['HasAllow'] = $true
            }

            if ($showConflictProgress) {
                Write-ShareSurferConflictProgress -Message ('Conflict classification progress: checked {0}/{1} ACL row(s) for deny/collision evidence; conflicts={2}.' -f $aclIndex, $aclTotal, $conflicts.Count)
            }
        }

        $denyStateIndex = 0
        $denyStateTotal = $denyStates.Keys.Count
        foreach ($denyStateKey in $denyStates.Keys) {
            $denyStateIndex++
            $state = $denyStates[$denyStateKey]
            $shareId = [string]$state['ShareId']
            $itemId = [string]$state['ItemId']
            $identityKey = [string]$state['IdentityKey']
            $identity = [string]$state['Identity']
            $allRightsSummary = (@($state['AllRightsParts'].Keys) | Sort-Object) -join '; '
            $denyRightsSummary = (@($state['DenyRightsParts'].Keys) | Sort-Object) -join '; '

            if ([bool]$state['HasAllow'] -and [bool]$state['HasDeny']) {
                [void]$conflicts.Add((New-ShareSurferConflict -ConflictType 'NtfsDenyAllowCollision' -ShareId $shareId -ItemId $itemId -Identity $identity -ShareRights '' -NtfsRights $allRightsSummary -Severity 'High' -Message 'The same identity has both NTFS allow and deny entries on the same item. Review the deny entry before migration because it can override apparent allow access.'))
            }

            $shareMap = @{}
            if ($sharePermissionsByShare.ContainsKey($shareId)) {
                $shareMap = $sharePermissionsByShare[$shareId]
            }
            $shareIdentityCacheKey = '{0}|{1}' -f $shareId, $identityKey
            $shareAllowRank = 0
            if ($shareAllowRankByShareIdentity.ContainsKey($shareIdentityCacheKey)) {
                $shareAllowRank = [int]$shareAllowRankByShareIdentity[$shareIdentityCacheKey]
            }
            if ([bool]$state['HasDeny'] -and $shareMap.ContainsKey($identityKey) -and $shareAllowRank -gt 0) {
                $shareRightsSummary = ''
                if ($shareRightsSummaryByShareIdentity.ContainsKey($shareIdentityCacheKey)) {
                    $shareRightsSummary = [string]$shareRightsSummaryByShareIdentity[$shareIdentityCacheKey]
                }
                [void]$conflicts.Add((New-ShareSurferConflict -ConflictType 'ShareAllowsNtfsDenies' -ShareId $shareId -ItemId $itemId -Identity $identity -ShareRights $shareRightsSummary -NtfsRights $denyRightsSummary -Severity 'High' -Message 'Share-level permissions allow an identity that has an NTFS deny entry on the item. The two-gate access view should call out this denial explicitly.'))
            }

            if ($showConflictProgress) {
                Write-ShareSurferConflictProgress -Message ('Conflict classification progress: checked {0}/{1} deny/collision group(s); conflicts={2}.' -f $denyStateIndex, $denyStateTotal, $conflicts.Count)
            }
        }
    }

    @($conflicts)
}

function Test-ShareSurferBroadSharePrincipal {
    param(
        [string] $Identity = ''
    )

    $text = ([string]$Identity).Trim()
    if ($text -eq '') {
        return $false
    }

    $upper = $text.ToUpperInvariant()
    $leaf = $upper
    if ($leaf.Contains('\')) {
        $leaf = $leaf.Substring($leaf.LastIndexOf('\') + 1)
    }

    if ($upper -in @('S-1-1-0', 'S-1-5-11', 'S-1-5-32-545') -or $upper -match '^S-1-5-21-.+-513$') {
        return $true
    }

    $broadNames = @(
        'EVERYONE',
        'AUTHENTICATED USERS',
        'DOMAIN USERS',
        'USERS',
        'INTERACTIVE'
    )

    ($broadNames -contains $upper -or $broadNames -contains $leaf)
}

function Get-ShareSurferAccessType {
    param(
        $AccessControlType
    )

    $value = ([string]$AccessControlType).Trim()
    if ($value -eq '') {
        return 'Allow'
    }

    if ($value.Equals('Deny', [System.StringComparison]::OrdinalIgnoreCase)) {
        return 'Deny'
    }

    return 'Allow'
}

function Get-ShareSurferRightsRank {
    param(
        $Rights
    )

    $text = ([string]$Rights).ToLowerInvariant()
    if ($text.Contains('genericall')) {
        return 3
    }
    if ($text.Contains('full')) {
        return 3
    }
    if ($text.Contains('modify') -or $text.Contains('change') -or $text.Contains('write') -or $text.Contains('delete')) {
        return 2
    }
    if ($text.Contains('read') -or $text.Contains('list') -or $text.Contains('execute')) {
        return 1
    }

    return 0
}

function Get-ShareSurferMaxRightsRank {
    param(
        $Entries,

        [string] $AccessType = ''
    )

    $maxRank = 0
    foreach ($entry in @(ConvertTo-ShareSurferArray $Entries)) {
        if ($AccessType -ne '' -and (Get-ShareSurferAccessType $entry.AccessControlType) -ne $AccessType) {
            continue
        }

        $rank = Get-ShareSurferRightsRank -Rights $entry.Rights
        if ($rank -gt $maxRank) {
            $maxRank = $rank
        }
    }

    $maxRank
}

function Get-ShareSurferRightsSummary {
    param(
        $Entries
    )

    $parts = New-Object System.Collections.ArrayList
    foreach ($entry in @(ConvertTo-ShareSurferArray $Entries)) {
        $accessType = Get-ShareSurferAccessType $entry.AccessControlType
        [void]$parts.Add(('{0}: {1}' -f $accessType, $entry.Rights))
    }

    ($parts | Select-Object -Unique) -join '; '
}
