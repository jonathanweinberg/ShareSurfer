function Get-ShareSurferOwnerReviewPackets {
    param(
        $OwnerRiskPivots = @(),
        $RelatedDataAreas = @()
    )

    $relatedRows = @(ConvertTo-ShareSurferArray $RelatedDataAreas)
    $packets = New-Object System.Collections.ArrayList
    $index = 0
    foreach ($pivot in @(ConvertTo-ShareSurferArray $OwnerRiskPivots)) {
        $index++
        $businessUnit = [string]$pivot.BusinessUnit
        $owner = [string]$pivot.Owner
        $pattern = [string]$pivot.Pattern
        $riskLevel = [string]$pivot.RiskLevel
        $findingCount = [int]$pivot.FindingCount
        $conflictCount = [int]$pivot.ConflictCount
        $partialShareCount = [int]$pivot.PartialShareCount
        $directGroupCount = [int]$pivot.DirectGroupCount
        $expandedMemberCount = [int]$pivot.ExpandedMemberCount

        $relatedMatches = @($relatedRows | Where-Object {
            [string]$_.BusinessUnit -eq $businessUnit -and
                [string]$_.Owner -eq $owner -and
                ([string]$_.Pattern -eq $pattern -or [string]$_.Pattern -eq '')
        })
        $migrationReadiness = Get-ShareSurferOwnerPacketMigrationReadiness -RiskLevel $riskLevel -RelatedRows $relatedMatches
        $reviewStatus = Get-ShareSurferOwnerPacketReviewStatus -RiskLevel $riskLevel -PartialShareCount $partialShareCount
        $whyReview = Get-ShareSurferOwnerPacketWhyReview -RiskLevel $riskLevel -FindingCount $findingCount -ConflictCount $conflictCount -PartialShareCount $partialShareCount -DirectGroupCount $directGroupCount
        $whatToReviewFirst = Get-ShareSurferOwnerPacketReviewStart -FindingCount $findingCount -ConflictCount $conflictCount -PartialShareCount $partialShareCount -DirectGroupCount $directGroupCount -ExpandedMemberCount $expandedMemberCount
        $suggestedNextAction = Get-ShareSurferOwnerPacketNextAction -ReviewStatus $reviewStatus -PartialShareCount $partialShareCount -ConflictCount $conflictCount -FindingCount $findingCount

        [void]$packets.Add([pscustomobject]@{
            ReviewPacketId = 'owner-review-{0:D4}' -f $index
            BusinessUnit = $businessUnit
            Owner = $owner
            Pattern = $pattern
            Source = [string]$pivot.Source
            RiskLevel = $riskLevel
            ReviewStatus = $reviewStatus
            WhyReview = $whyReview
            WhatToReviewFirst = $whatToReviewFirst
            SuggestedNextAction = $suggestedNextAction
            MatchingItems = [int]$pivot.MatchingItems
            Directories = [int]$pivot.Directories
            Files = [int]$pivot.Files
            FindingCount = $findingCount
            ConflictCount = $conflictCount
            PartialShareCount = $partialShareCount
            DirectIdentityCount = [int]$pivot.DirectIdentityCount
            DirectGroupCount = $directGroupCount
            ExpandedMemberCount = $expandedMemberCount
            MigrationReadiness = $migrationReadiness
            RelatedDataAreaCount = $relatedMatches.Count
        })
    }

    @($packets)
}

function Get-ShareSurferOwnerPacketReviewStatus {
    param(
        [string] $RiskLevel,
        [int] $PartialShareCount
    )

    if ($PartialShareCount -gt 0) {
        return 'Blocked by scan gaps'
    }
    if ($RiskLevel -eq 'High') {
        return 'High priority review'
    }
    if ($RiskLevel -eq 'Review') {
        return 'Needs review'
    }
    'Monitor'
}

function Get-ShareSurferOwnerPacketWhyReview {
    param(
        [string] $RiskLevel,
        [int] $FindingCount,
        [int] $ConflictCount,
        [int] $PartialShareCount,
        [int] $DirectGroupCount
    )

    $reasons = New-Object System.Collections.ArrayList
    if ($RiskLevel -eq 'High') {
        [void]$reasons.Add('high-priority access or migration risk')
    }
    if ($ConflictCount -gt 0) {
        [void]$reasons.Add('share-vs-file permission mismatch')
    }
    if ($FindingCount -gt 0) {
        [void]$reasons.Add('migration or governance finding')
    }
    if ($PartialShareCount -gt 0) {
        [void]$reasons.Add('incomplete collection evidence')
    }
    if ($DirectGroupCount -gt 0) {
        [void]$reasons.Add('permission-bearing security groups')
    }
    if ($reasons.Count -eq 0) {
        [void]$reasons.Add('owner mapping should be confirmed before migration or audit work')
    }
    ($reasons -join '; ')
}

function Get-ShareSurferOwnerPacketReviewStart {
    param(
        [int] $FindingCount,
        [int] $ConflictCount,
        [int] $PartialShareCount,
        [int] $DirectGroupCount,
        [int] $ExpandedMemberCount
    )

    $starts = New-Object System.Collections.ArrayList
    if ($PartialShareCount -gt 0) {
        [void]$starts.Add('resolve scan gaps')
    }
    if ($ConflictCount -gt 0) {
        [void]$starts.Add('access conflicts')
    }
    if ($FindingCount -gt 0) {
        [void]$starts.Add('findings')
    }
    if ($DirectGroupCount -gt 0) {
        [void]$starts.Add('permissioned groups')
    }
    if ($ExpandedMemberCount -gt 0) {
        [void]$starts.Add('expanded members')
    }
    if ($starts.Count -eq 0) {
        [void]$starts.Add('owner mapping confirmation')
    }
    ($starts -join '; ')
}

function Get-ShareSurferOwnerPacketNextAction {
    param(
        [string] $ReviewStatus,
        [int] $PartialShareCount,
        [int] $ConflictCount,
        [int] $FindingCount
    )

    if ($PartialShareCount -gt 0) {
        return 'Review collection gaps and rerun the scan before requesting final owner approval.'
    }
    if ($ConflictCount -gt 0) {
        return 'Confirm intended access with the owner, then resolve share-vs-file permission mismatches.'
    }
    if ($FindingCount -gt 0) {
        return 'Review findings with the owner and decide whether cleanup or migration exceptions are needed.'
    }
    if ($ReviewStatus -eq 'Monitor') {
        return 'Confirm ownership and keep this area available for future review cycles.'
    }
    'Confirm ownership, review assigned groups, and document the remediation decision.'
}

function Get-ShareSurferOwnerPacketMigrationReadiness {
    param(
        [string] $RiskLevel,
        $RelatedRows = @()
    )

    $readinessValues = @($RelatedRows | ForEach-Object { [string]$_.MigrationReadiness } | Where-Object { $_ -ne '' })
    if (@($readinessValues | Where-Object { $_ -eq 'Blocked by scan gaps' }).Count -gt 0) {
        return 'Blocked by scan gaps'
    }
    if (@($readinessValues | Where-Object { $_ -eq 'Review' }).Count -gt 0 -or $RiskLevel -ne 'Monitor') {
        return 'Review'
    }
    if ($readinessValues.Count -gt 0) {
        return 'Candidate'
    }
    'Not assessed'
}
