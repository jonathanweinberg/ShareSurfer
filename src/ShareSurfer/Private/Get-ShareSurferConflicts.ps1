function Get-ShareSurferConflicts {
    param(
        [Parameter(Mandatory = $true)]
        $SharePermissions,

        [Parameter(Mandatory = $true)]
        $AclEntries
    )

    $conflicts = New-Object System.Collections.ArrayList
    $sharePermissionsList = @(ConvertTo-ShareSurferArray $SharePermissions)
    $aclEntriesList = @(ConvertTo-ShareSurferArray $AclEntries)

    $sharePermissionsByShare = @{}
    foreach ($permission in $sharePermissionsList) {
        if (-not $sharePermissionsByShare.ContainsKey($permission.ShareId)) {
            $sharePermissionsByShare[$permission.ShareId] = @{}
        }
        $identityKey = ([string]$permission.Identity).ToUpperInvariant()
        if (-not $sharePermissionsByShare[$permission.ShareId].ContainsKey($identityKey)) {
            $sharePermissionsByShare[$permission.ShareId][$identityKey] = @()
        }
        $sharePermissionsByShare[$permission.ShareId][$identityKey] = @($sharePermissionsByShare[$permission.ShareId][$identityKey]) + $permission
    }

    $ntfsByShare = @{}
    $ntfsByShareItemIdentity = @{}
    foreach ($ace in $aclEntriesList) {
        if (-not $ntfsByShare.ContainsKey($ace.ShareId)) {
            $ntfsByShare[$ace.ShareId] = @{}
        }
        if (-not $ntfsByShareItemIdentity.ContainsKey($ace.ShareId)) {
            $ntfsByShareItemIdentity[$ace.ShareId] = @{}
        }

        $identityKey = ([string]$ace.Identity).ToUpperInvariant()
        if (-not $ntfsByShare[$ace.ShareId].ContainsKey($identityKey)) {
            $ntfsByShare[$ace.ShareId][$identityKey] = @()
        }
        $ntfsByShare[$ace.ShareId][$identityKey] = @($ntfsByShare[$ace.ShareId][$identityKey]) + $ace

        $itemKey = [string]$ace.ItemId
        if (-not $ntfsByShareItemIdentity[$ace.ShareId].ContainsKey($itemKey)) {
            $ntfsByShareItemIdentity[$ace.ShareId][$itemKey] = @{}
        }
        if (-not $ntfsByShareItemIdentity[$ace.ShareId][$itemKey].ContainsKey($identityKey)) {
            $ntfsByShareItemIdentity[$ace.ShareId][$itemKey][$identityKey] = @()
        }
        $ntfsByShareItemIdentity[$ace.ShareId][$itemKey][$identityKey] = @($ntfsByShareItemIdentity[$ace.ShareId][$itemKey][$identityKey]) + $ace
    }

    foreach ($ace in $aclEntriesList) {
        $identityKey = ([string]$ace.Identity).ToUpperInvariant()
        $shareMap = @{}
        if ($sharePermissionsByShare.ContainsKey($ace.ShareId)) {
            $shareMap = $sharePermissionsByShare[$ace.ShareId]
        }

        if ($shareMap.Count -gt 0 -and -not $shareMap.ContainsKey($identityKey)) {
            [void]$conflicts.Add((New-ShareSurferConflict -ConflictType 'NtfsIdentityMissingShareGate' -ShareId $ace.ShareId -ItemId $ace.ItemId -Identity $ace.Identity -ShareRights '' -NtfsRights $ace.Rights -Severity 'High' -Message 'NTFS grants rights to an identity that does not appear in the share-level permission gate.'))
        }

        if ($shareMap.ContainsKey($identityKey) -and (Get-ShareSurferAccessType $ace.AccessControlType) -eq 'Allow') {
            $shareAllowRank = Get-ShareSurferMaxRightsRank -Entries $shareMap[$identityKey] -AccessType 'Allow'
            $ntfsRank = Get-ShareSurferRightsRank -Rights $ace.Rights
            if ($shareAllowRank -gt 0 -and $ntfsRank -gt $shareAllowRank) {
                [void]$conflicts.Add((New-ShareSurferConflict -ConflictType 'ShareRightsRestrictNtfs' -ShareId $ace.ShareId -ItemId $ace.ItemId -Identity $ace.Identity -ShareRights (Get-ShareSurferRightsSummary -Entries $shareMap[$identityKey]) -NtfsRights $ace.Rights -Severity 'High' -Message 'Share-level rights are narrower than NTFS allow rights for the same identity, so the share gate may restrict access expected from NTFS ACLs.'))
            }
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

    foreach ($shareId in $ntfsByShareItemIdentity.Keys) {
        foreach ($itemId in $ntfsByShareItemIdentity[$shareId].Keys) {
            foreach ($identityKey in $ntfsByShareItemIdentity[$shareId][$itemId].Keys) {
                $entries = @($ntfsByShareItemIdentity[$shareId][$itemId][$identityKey])
                $allowEntries = @($entries | Where-Object { (Get-ShareSurferAccessType $_.AccessControlType) -eq 'Allow' })
                $denyEntries = @($entries | Where-Object { (Get-ShareSurferAccessType $_.AccessControlType) -eq 'Deny' })

                if ($allowEntries.Count -gt 0 -and $denyEntries.Count -gt 0) {
                    [void]$conflicts.Add((New-ShareSurferConflict -ConflictType 'NtfsDenyAllowCollision' -ShareId $shareId -ItemId $itemId -Identity $entries[0].Identity -ShareRights '' -NtfsRights (Get-ShareSurferRightsSummary -Entries $entries) -Severity 'High' -Message 'The same identity has both NTFS allow and deny entries on the same item. Review the deny entry before migration because it can override apparent allow access.'))
                }

                $shareMap = @{}
                if ($sharePermissionsByShare.ContainsKey($shareId)) {
                    $shareMap = $sharePermissionsByShare[$shareId]
                }
                if ($denyEntries.Count -gt 0 -and $shareMap.ContainsKey($identityKey) -and (Get-ShareSurferMaxRightsRank -Entries $shareMap[$identityKey] -AccessType 'Allow') -gt 0) {
                    [void]$conflicts.Add((New-ShareSurferConflict -ConflictType 'ShareAllowsNtfsDenies' -ShareId $shareId -ItemId $itemId -Identity $entries[0].Identity -ShareRights (Get-ShareSurferRightsSummary -Entries $shareMap[$identityKey]) -NtfsRights (Get-ShareSurferRightsSummary -Entries $denyEntries) -Severity 'High' -Message 'Share-level permissions allow an identity that has an NTFS deny entry on the item. The two-gate access view should call out this denial explicitly.'))
                }
            }
        }
    }

    @($conflicts)
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
