function Get-ShareSurferConflicts {
    param(
        [Parameter(Mandatory = $true)]
        $SharePermissions,

        [Parameter(Mandatory = $true)]
        $AclEntries
    )

    $conflicts = New-Object System.Collections.ArrayList
    $sharePermissionsByShare = @{}
    foreach ($permission in @(ConvertTo-ShareSurferArray $SharePermissions)) {
        if (-not $sharePermissionsByShare.ContainsKey($permission.ShareId)) {
            $sharePermissionsByShare[$permission.ShareId] = @{}
        }
        $sharePermissionsByShare[$permission.ShareId][([string]$permission.Identity).ToUpperInvariant()] = $permission
    }

    $ntfsByShare = @{}
    foreach ($ace in @(ConvertTo-ShareSurferArray $AclEntries)) {
        if (-not $ntfsByShare.ContainsKey($ace.ShareId)) {
            $ntfsByShare[$ace.ShareId] = @{}
        }
        $ntfsByShare[$ace.ShareId][([string]$ace.Identity).ToUpperInvariant()] = $ace
    }

    foreach ($ace in @(ConvertTo-ShareSurferArray $AclEntries)) {
        $identityKey = ([string]$ace.Identity).ToUpperInvariant()
        $shareMap = @{}
        if ($sharePermissionsByShare.ContainsKey($ace.ShareId)) {
            $shareMap = $sharePermissionsByShare[$ace.ShareId]
        }

        if ($shareMap.Count -gt 0 -and -not $shareMap.ContainsKey($identityKey)) {
            [void]$conflicts.Add((New-ShareSurferConflict -ConflictType 'NtfsIdentityMissingShareGate' -ShareId $ace.ShareId -ItemId $ace.ItemId -Identity $ace.Identity -ShareRights '' -NtfsRights $ace.Rights -Severity 'High' -Message 'NTFS grants rights to an identity that does not appear in the share-level permission gate.'))
        }
    }

    foreach ($permission in @(ConvertTo-ShareSurferArray $SharePermissions)) {
        $identityKey = ([string]$permission.Identity).ToUpperInvariant()
        $ntfsMap = @{}
        if ($ntfsByShare.ContainsKey($permission.ShareId)) {
            $ntfsMap = $ntfsByShare[$permission.ShareId]
        }

        if ($ntfsMap.Count -gt 0 -and -not $ntfsMap.ContainsKey($identityKey)) {
            [void]$conflicts.Add((New-ShareSurferConflict -ConflictType 'ShareIdentityMissingNtfsEntry' -ShareId $permission.ShareId -Identity $permission.Identity -ShareRights $permission.Rights -NtfsRights '' -Severity 'Info' -Message 'Share-level rights exist for an identity that was not observed in NTFS ACL entries for this share.'))
        }
    }

    @($conflicts)
}
