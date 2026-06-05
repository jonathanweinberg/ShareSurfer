function Get-ShareSurferRelatedDataAreas {
    param(
        $OwnerRiskPivots = @(),
        $Items = @(),
        $Shares = @()
    )

    $rows = New-Object System.Collections.ArrayList
    $index = 1
    foreach ($pivot in @(ConvertTo-ShareSurferArray $OwnerRiskPivots)) {
        $pattern = [string]$pivot.Pattern
        $matchedShareIds = @{}

        foreach ($share in @(ConvertTo-ShareSurferArray $Shares)) {
            foreach ($path in @([string]$share.UNCPath, [string]$share.LocalPath)) {
                if ($path -ne '' -and (Test-ShareSurferWildcardMatch -Pattern $pattern -Value $path)) {
                    $shareId = [string]$share.ShareId
                    if ($shareId -ne '') {
                        $matchedShareIds[$shareId] = $true
                    }
                }
            }
        }

        foreach ($item in @(ConvertTo-ShareSurferArray $Items)) {
            $fullPath = [string]$item.FullPath
            if ($fullPath -ne '' -and (Test-ShareSurferWildcardMatch -Pattern $pattern -Value $fullPath)) {
                $shareId = [string]$item.ShareId
                if ($shareId -ne '') {
                    $matchedShareIds[$shareId] = $true
                }
            }
        }

        $findingCount = [int]$pivot.FindingCount
        $conflictCount = [int]$pivot.ConflictCount
        $partialShareCount = [int]$pivot.PartialShareCount
        $reviewItems = $findingCount + $conflictCount
        $readiness = Get-ShareSurferMigrationReadiness -RiskLevel ([string]$pivot.RiskLevel) -FindingCount $findingCount -ConflictCount $conflictCount -PartialShareCount $partialShareCount
        $reasons = New-ShareSurferRelatedDataAreaReasons -PermissionedGroupCount ([int]$pivot.DirectGroupCount) -ReviewItemCount $reviewItems -PartialShareCount $partialShareCount

        [void]$rows.Add([pscustomobject]@{
            RelatedAreaId = 'related-area-{0:D4}' -f $index
            RelatedDataArea = (@([string]$pivot.BusinessUnit, [string]$pivot.Owner) | Where-Object { $_ -ne '' }) -join ' / '
            BusinessUnit = [string]$pivot.BusinessUnit
            Owner = [string]$pivot.Owner
            Pattern = $pattern
            Source = [string]$pivot.Source
            RiskLevel = [string]$pivot.RiskLevel
            MigrationReadiness = $readiness
            MatchingShares = [Math]::Max($matchedShareIds.Count, $partialShareCount)
            MatchingItems = [int]$pivot.MatchingItems
            Directories = [int]$pivot.Directories
            Files = [int]$pivot.Files
            FindingCount = $findingCount
            ConflictCount = $conflictCount
            ReviewItemCount = $reviewItems
            PartialShareCount = $partialShareCount
            DirectIdentityCount = [int]$pivot.DirectIdentityCount
            DirectGroupCount = [int]$pivot.DirectGroupCount
            ExpandedMemberCount = [int]$pivot.ExpandedMemberCount
            RelatedBecause = $reasons
            SuggestedNextAction = Get-ShareSurferMigrationNextAction -MigrationReadiness $readiness
        })
        $index++
    }

    @($rows | Sort-Object @{ Expression = {
                switch ([string]$_.MigrationReadiness) {
                    'Blocked by scan gaps' { 0; break }
                    'Review' { 1; break }
                    default { 2 }
                }
            }
        }, BusinessUnit, Owner)
}

function Get-ShareSurferMigrationReadiness {
    param(
        [string] $RiskLevel = '',
        [int] $FindingCount = 0,
        [int] $ConflictCount = 0,
        [int] $PartialShareCount = 0
    )

    if ($PartialShareCount -gt 0) {
        return 'Blocked by scan gaps'
    }

    if ($RiskLevel -eq 'High' -or $FindingCount -gt 0 -or $ConflictCount -gt 0) {
        return 'Review'
    }

    'Candidate'
}

function Get-ShareSurferMigrationNextAction {
    param(
        [string] $MigrationReadiness = ''
    )

    switch ($MigrationReadiness) {
        'Blocked by scan gaps' { 'Review collection errors and rerun the scan before final migration planning.'; break }
        'Review' { 'Confirm ownership, review access groups, and clean up findings or conflicts before migration.'; break }
        default { 'Confirm ownership and mark as migration-ready when the business owner agrees.' }
    }
}

function New-ShareSurferRelatedDataAreaReasons {
    param(
        [int] $PermissionedGroupCount = 0,
        [int] $ReviewItemCount = 0,
        [int] $PartialShareCount = 0
    )

    $reasons = New-Object System.Collections.ArrayList
    [void]$reasons.Add('same owner mapping')
    [void]$reasons.Add('same business unit')
    [void]$reasons.Add('matching path pattern')
    if ($PermissionedGroupCount -gt 0) {
        [void]$reasons.Add('shared permission group')
    }
    if ($ReviewItemCount -gt 0) {
        [void]$reasons.Add('shared review risk')
    }
    if ($PartialShareCount -gt 0) {
        [void]$reasons.Add('partial collection gap')
    }

    @($reasons) -join '; '
}
