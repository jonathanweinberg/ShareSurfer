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
        $relationshipSignals = New-Object System.Collections.ArrayList
        $supportingEvidence = New-Object System.Collections.ArrayList
        if (-not [string]::IsNullOrWhiteSpace([string]$pivot.Owner)) {
            [void]$relationshipSignals.Add('same owner')
        }
        if (-not [string]::IsNullOrWhiteSpace([string]$pivot.BusinessUnit)) {
            [void]$relationshipSignals.Add('same business unit')
        }
        if ([int]$pivot.DirectGroupCount -gt 0) {
            [void]$relationshipSignals.Add('shared non-discounted business permission group')
        }
        if (-not [string]::IsNullOrWhiteSpace($pattern)) {
            [void]$supportingEvidence.Add('path/share/folder naming similarity')
        }
        $readinessSignals = @()
        if ($null -ne $pivot.PSObject.Properties['ReadinessSignals'] -and -not [string]::IsNullOrWhiteSpace([string]$pivot.ReadinessSignals)) {
            $readinessSignals = @([string]$pivot.ReadinessSignals -split '; ' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        }
        $relatednessStrength = Get-ShareSurferRelatednessStrength -RelationshipSignalCount $relationshipSignals.Count -SupportingSignalCount $supportingEvidence.Count
        $reasons = New-ShareSurferRelatedDataAreaReasons -RelatednessStrength $relatednessStrength -RelationshipSignals $relationshipSignals -SupportingEvidence $supportingEvidence
        $evidenceCompleteness = Get-ShareSurferEvidenceCompleteness -ReadinessSignalCount @($readinessSignals).Count -PartialShareCount $partialShareCount
        $discountedPrincipalCount = if ($null -ne $pivot.PSObject.Properties['DiscountedPrincipalCount']) { [int]$pivot.DiscountedPrincipalCount } else { 0 }
        $relationshipSummary = if ($relationshipSignals.Count -gt 0) { (@($relationshipSignals) | Select-Object -First 2) -join ' + ' } else { 'relationship needs evidence' }
        $coreFiveChips = 'Confidence: {0} | Relationship: {1} | Readiness: {2} | Discounted access: {3} | Evidence: {4}' -f $relatednessStrength, $relationshipSummary, $readiness, $discountedPrincipalCount, $evidenceCompleteness
        $relatedBecauseShort = 'This area appears together because {0}.' -f $reasons.ToLowerInvariant()

        [void]$rows.Add([pscustomobject]@{
            RelatedAreaId = 'related-area-{0:D4}' -f $index
            RelatedDataArea = (@([string]$pivot.BusinessUnit, [string]$pivot.Owner) | Where-Object { $_ -ne '' }) -join ' / '
            BusinessUnit = [string]$pivot.BusinessUnit
            Owner = [string]$pivot.Owner
            Pattern = $pattern
            Source = [string]$pivot.Source
            RelatednessStrength = $relatednessStrength
            RelationshipSignalCount = $relationshipSignals.Count
            SupportingSignalCount = $supportingEvidence.Count
            ReadinessSignalCount = @($readinessSignals).Count
            RelationshipSignals = (@($relationshipSignals) | Sort-Object) -join '; '
            SupportingEvidence = (@($supportingEvidence) | Sort-Object) -join '; '
            ReadinessSignals = (@($readinessSignals) | Sort-Object) -join '; '
            CoreFiveChips = $coreFiveChips
            EvidenceCompleteness = $evidenceCompleteness
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
            RelatedBecauseShort = $relatedBecauseShort
            RelatedBecause = $reasons
            SuggestedNextAction = Get-ShareSurferMigrationNextAction -MigrationReadiness $readiness
            DiscountedPrincipal = if ($null -ne $pivot.PSObject.Properties['DiscountedPrincipal']) { [bool]$pivot.DiscountedPrincipal } else { $false }
            DiscountedPrincipalCount = $discountedPrincipalCount
            DiscountedGroupCount = if ($null -ne $pivot.PSObject.Properties['DiscountedGroupCount']) { [int]$pivot.DiscountedGroupCount } else { 0 }
            DiscountedPrincipals = if ($null -ne $pivot.PSObject.Properties['DiscountedPrincipals']) { [string]$pivot.DiscountedPrincipals } else { '' }
            DiscountReason = if ($null -ne $pivot.PSObject.Properties['DiscountReason']) { [string]$pivot.DiscountReason } else { '' }
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
        'Blocked by scan gaps' { 'Review collection-error evidence before using this area for migration planning.'; break }
        'Review' { 'Review ownership, access groups, findings, and conflicts before migration planning.'; break }
        default { 'Review ownership and access evidence with the business owner before migration planning.' }
    }
}

function New-ShareSurferRelatedDataAreaReasons {
    param(
        [string] $RelatednessStrength = '',
        $RelationshipSignals = @(),
        $SupportingEvidence = @()
    )

    $reasons = New-Object System.Collections.ArrayList
    if (-not [string]::IsNullOrWhiteSpace($RelatednessStrength)) {
        [void]$reasons.Add(('{0} confidence' -f $RelatednessStrength))
    }
    foreach ($signal in @(ConvertTo-ShareSurferArray $RelationshipSignals)) {
        if (-not [string]::IsNullOrWhiteSpace([string]$signal)) {
            Add-ShareSurferUniqueValue -Values $reasons -Value ([string]$signal)
        }
    }
    foreach ($signal in @(ConvertTo-ShareSurferArray $SupportingEvidence)) {
        if (-not [string]::IsNullOrWhiteSpace([string]$signal)) {
            Add-ShareSurferUniqueValue -Values $reasons -Value ([string]$signal)
        }
    }

    @($reasons) -join '; '
}

function Get-ShareSurferRelatednessStrength {
    param(
        [int] $RelationshipSignalCount = 0,
        [int] $SupportingSignalCount = 0
    )

    if ($RelationshipSignalCount -ge 2) {
        return 'Strong'
    }
    if ($RelationshipSignalCount -eq 1 -and $SupportingSignalCount -gt 0) {
        return 'Possible'
    }
    'Needs Evidence'
}

function Get-ShareSurferEvidenceCompleteness {
    param(
        [int] $ReadinessSignalCount = 0,
        [int] $PartialShareCount = 0
    )

    if ($PartialShareCount -gt 0) {
        return 'Partial data'
    }
    if ($ReadinessSignalCount -gt 0) {
        return 'Complete with readiness review'
    }
    'Complete enough'
}
