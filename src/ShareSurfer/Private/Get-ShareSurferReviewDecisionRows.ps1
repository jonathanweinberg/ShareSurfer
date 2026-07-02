function Get-ShareSurferReviewDecisionAllowedValues {
    @(
        'ConfirmedOwner',
        'CleanupNeeded',
        'RerunNeeded',
        'MigrationCandidate',
        'WrongOwner'
    )
}

function Get-ShareSurferReviewDecisionAllowedText {
    (Get-ShareSurferReviewDecisionAllowedValues) -join '; '
}

function ConvertTo-ShareSurferReviewDecisionValue {
    param(
        [AllowNull()]
        [string] $Decision = ''
    )

    $text = ([string]$Decision).Trim()
    if ([string]::IsNullOrWhiteSpace($text)) {
        return [pscustomobject]@{
            Decision = ''
            IsValid = $true
            Warning = ''
        }
    }

    $normalized = ($text -replace '[^A-Za-z0-9]', '').ToLowerInvariant()
    $aliases = @{
        'confirmedowner' = 'ConfirmedOwner'
        'ownerconfirmed' = 'ConfirmedOwner'
        'confirmowner' = 'ConfirmedOwner'
        'cleanupneeded' = 'CleanupNeeded'
        'cleanup' = 'CleanupNeeded'
        'needscleanup' = 'CleanupNeeded'
        'rerunneeded' = 'RerunNeeded'
        'rerun' = 'RerunNeeded'
        'rescan' = 'RerunNeeded'
        'rescanneeded' = 'RerunNeeded'
        'migrationcandidate' = 'MigrationCandidate'
        'candidate' = 'MigrationCandidate'
        'readyformigration' = 'MigrationCandidate'
        'wrongowner' = 'WrongOwner'
        'incorrectowner' = 'WrongOwner'
        'notmydata' = 'WrongOwner'
    }

    if ($aliases.ContainsKey($normalized)) {
        return [pscustomobject]@{
            Decision = [string]$aliases[$normalized]
            IsValid = $true
            Warning = ''
        }
    }

    [pscustomobject]@{
        Decision = $text
        IsValid = $false
        Warning = ('Invalid decision "{0}". Allowed values: {1}.' -f $text, (Get-ShareSurferReviewDecisionAllowedText))
    }
}

function Get-ShareSurferReviewDecisionStatus {
    param(
        [string] $Decision = '',
        [bool] $DecisionIsValid = $true,
        [string] $InputStatus = ''
    )

    if (-not $DecisionIsValid) {
        return 'NeedsCorrection'
    }

    if ([string]::IsNullOrWhiteSpace($Decision)) {
        return 'Pending'
    }

    'Reviewed'
}

function Get-ShareSurferReviewDecisionNextAction {
    param(
        [string] $Decision = '',
        [bool] $DecisionIsValid = $true,
        [string] $InputNextAction = '',
        [string] $FallbackNextAction = ''
    )

    if (-not $DecisionIsValid) {
        return 'Correct the Decision value, then import the decision CSV again.'
    }

    if (-not [string]::IsNullOrWhiteSpace($InputNextAction)) {
        return [string]$InputNextAction
    }

    switch ($Decision) {
        'ConfirmedOwner' { return 'Keep the owner mapping and continue review with the confirmed business owner.' }
        'CleanupNeeded' { return 'Plan cleanup, rerun ShareSurfer after remediation, and keep this decision with the review record.' }
        'RerunNeeded' { return 'Rerun the scan after resolving collection gaps, stale owner data, or changed permissions.' }
        'MigrationCandidate' { return 'Move this area into migration wave planning after owner sign-off and blocker review.' }
        'WrongOwner' { return 'Update owner mappings, rerun the scan, and request review from the corrected owner.' }
    }

    if (-not [string]::IsNullOrWhiteSpace($FallbackNextAction)) {
        return [string]$FallbackNextAction
    }

    'Select a decision value after owner and migration review.'
}

function Add-ShareSurferReviewDecisionWarning {
    param(
        [System.Collections.ArrayList] $Warnings,
        [string] $Warning = ''
    )

    if (-not [string]::IsNullOrWhiteSpace($Warning) -and -not $Warnings.Contains($Warning)) {
        [void]$Warnings.Add($Warning)
    }
}

function Copy-ShareSurferReviewDecisionFields {
    param(
        [Parameter(Mandatory = $true)]
        $Target,

        $Source
    )

    if ($null -eq $Source) {
        return $Target
    }

    foreach ($field in @('Decision', 'DecisionStatus', 'ConfirmedOwner', 'ConfirmedBusinessUnit', 'Reviewer', 'ReviewedAt', 'Notes', 'NextAction', 'ImportWarnings')) {
        if ($null -ne $Source.PSObject.Properties[$field]) {
            $Target.$field = [string]$Source.PSObject.Properties[$field].Value
        }
    }

    $Target
}

function Complete-ShareSurferReviewDecisionRow {
    param(
        [Parameter(Mandatory = $true)]
        $Row,

        [string] $FallbackNextAction = '',

        [string] $SourceDecisionPath = '',

        [string] $ExtraWarning = ''
    )

    $warnings = New-Object System.Collections.ArrayList
    if ($null -ne $Row.PSObject.Properties['ImportWarnings'] -and -not [string]::IsNullOrWhiteSpace([string]$Row.ImportWarnings)) {
        foreach ($warning in @([string]$Row.ImportWarnings -split '; ')) {
            if ($warning -match '^Invalid decision ".+"\.\s+Allowed values:') {
                continue
            }
            Add-ShareSurferReviewDecisionWarning -Warnings $warnings -Warning $warning
        }
    }
    Add-ShareSurferReviewDecisionWarning -Warnings $warnings -Warning $ExtraWarning

    $decisionResult = ConvertTo-ShareSurferReviewDecisionValue -Decision ([string]$Row.Decision)
    Add-ShareSurferReviewDecisionWarning -Warnings $warnings -Warning ([string]$decisionResult.Warning)

    $Row.Decision = [string]$decisionResult.Decision
    $Row.DecisionStatus = Get-ShareSurferReviewDecisionStatus -Decision ([string]$Row.Decision) -DecisionIsValid ([bool]$decisionResult.IsValid) -InputStatus ([string]$Row.DecisionStatus)
    $Row.NextAction = Get-ShareSurferReviewDecisionNextAction -Decision ([string]$Row.Decision) -DecisionIsValid ([bool]$decisionResult.IsValid) -InputNextAction ([string]$Row.NextAction) -FallbackNextAction $FallbackNextAction
    $Row.AllowedDecisions = Get-ShareSurferReviewDecisionAllowedText
    if (-not [string]::IsNullOrWhiteSpace($SourceDecisionPath)) {
        $Row.SourceDecisionPath = $SourceDecisionPath
    }
    $Row.ImportWarnings = @($warnings) -join '; '

    $Row
}

function New-ShareSurferOwnerReviewDecisionRow {
    param(
        $Packet,

        $DecisionSource,

        [string] $SourceDecisionPath = '',

        [string] $ExtraWarning = ''
    )

    $reviewPacketId = if ($null -ne $Packet -and $null -ne $Packet.PSObject.Properties['ReviewPacketId']) { [string]$Packet.ReviewPacketId } elseif ($null -ne $DecisionSource -and $null -ne $DecisionSource.PSObject.Properties['ReviewPacketId']) { [string]$DecisionSource.ReviewPacketId } else { '' }
    $row = [pscustomobject]@{
        DecisionId = if (-not [string]::IsNullOrWhiteSpace($reviewPacketId)) { 'owner-decision-{0}' -f $reviewPacketId } elseif ($null -ne $DecisionSource -and $null -ne $DecisionSource.PSObject.Properties['DecisionId']) { [string]$DecisionSource.DecisionId } else { 'owner-decision-unmatched' }
        ReviewPacketId = $reviewPacketId
        BusinessUnit = if ($null -ne $Packet -and $null -ne $Packet.PSObject.Properties['BusinessUnit']) { [string]$Packet.BusinessUnit } elseif ($null -ne $DecisionSource -and $null -ne $DecisionSource.PSObject.Properties['BusinessUnit']) { [string]$DecisionSource.BusinessUnit } else { '' }
        Owner = if ($null -ne $Packet -and $null -ne $Packet.PSObject.Properties['Owner']) { [string]$Packet.Owner } elseif ($null -ne $DecisionSource -and $null -ne $DecisionSource.PSObject.Properties['Owner']) { [string]$DecisionSource.Owner } else { '' }
        Pattern = if ($null -ne $Packet -and $null -ne $Packet.PSObject.Properties['Pattern']) { [string]$Packet.Pattern } elseif ($null -ne $DecisionSource -and $null -ne $DecisionSource.PSObject.Properties['Pattern']) { [string]$DecisionSource.Pattern } else { '' }
        Source = if ($null -ne $Packet -and $null -ne $Packet.PSObject.Properties['Source']) { [string]$Packet.Source } elseif ($null -ne $DecisionSource -and $null -ne $DecisionSource.PSObject.Properties['Source']) { [string]$DecisionSource.Source } else { '' }
        RiskLevel = if ($null -ne $Packet -and $null -ne $Packet.PSObject.Properties['RiskLevel']) { [string]$Packet.RiskLevel } elseif ($null -ne $DecisionSource -and $null -ne $DecisionSource.PSObject.Properties['RiskLevel']) { [string]$DecisionSource.RiskLevel } else { '' }
        ReviewStatus = if ($null -ne $Packet -and $null -ne $Packet.PSObject.Properties['ReviewStatus']) { [string]$Packet.ReviewStatus } elseif ($null -ne $DecisionSource -and $null -ne $DecisionSource.PSObject.Properties['ReviewStatus']) { [string]$DecisionSource.ReviewStatus } else { '' }
        MigrationReadiness = if ($null -ne $Packet -and $null -ne $Packet.PSObject.Properties['MigrationReadiness']) { [string]$Packet.MigrationReadiness } elseif ($null -ne $DecisionSource -and $null -ne $DecisionSource.PSObject.Properties['MigrationReadiness']) { [string]$DecisionSource.MigrationReadiness } else { '' }
        RelatednessStrength = if ($null -ne $Packet -and $null -ne $Packet.PSObject.Properties['RelatednessStrength']) { [string]$Packet.RelatednessStrength } elseif ($null -ne $DecisionSource -and $null -ne $DecisionSource.PSObject.Properties['RelatednessStrength']) { [string]$DecisionSource.RelatednessStrength } else { '' }
        MatchingItems = if ($null -ne $Packet -and $null -ne $Packet.PSObject.Properties['MatchingItems']) { [string]$Packet.MatchingItems } elseif ($null -ne $DecisionSource -and $null -ne $DecisionSource.PSObject.Properties['MatchingItems']) { [string]$DecisionSource.MatchingItems } else { '' }
        FindingCount = if ($null -ne $Packet -and $null -ne $Packet.PSObject.Properties['FindingCount']) { [string]$Packet.FindingCount } elseif ($null -ne $DecisionSource -and $null -ne $DecisionSource.PSObject.Properties['FindingCount']) { [string]$DecisionSource.FindingCount } else { '' }
        ConflictCount = if ($null -ne $Packet -and $null -ne $Packet.PSObject.Properties['ConflictCount']) { [string]$Packet.ConflictCount } elseif ($null -ne $DecisionSource -and $null -ne $DecisionSource.PSObject.Properties['ConflictCount']) { [string]$DecisionSource.ConflictCount } else { '' }
        PartialShareCount = if ($null -ne $Packet -and $null -ne $Packet.PSObject.Properties['PartialShareCount']) { [string]$Packet.PartialShareCount } elseif ($null -ne $DecisionSource -and $null -ne $DecisionSource.PSObject.Properties['PartialShareCount']) { [string]$DecisionSource.PartialShareCount } else { '' }
        DirectGroupCount = if ($null -ne $Packet -and $null -ne $Packet.PSObject.Properties['DirectGroupCount']) { [string]$Packet.DirectGroupCount } elseif ($null -ne $DecisionSource -and $null -ne $DecisionSource.PSObject.Properties['DirectGroupCount']) { [string]$DecisionSource.DirectGroupCount } else { '' }
        ExpandedMemberCount = if ($null -ne $Packet -and $null -ne $Packet.PSObject.Properties['ExpandedMemberCount']) { [string]$Packet.ExpandedMemberCount } elseif ($null -ne $DecisionSource -and $null -ne $DecisionSource.PSObject.Properties['ExpandedMemberCount']) { [string]$DecisionSource.ExpandedMemberCount } else { '' }
        Decision = ''
        DecisionStatus = 'Pending'
        ConfirmedOwner = ''
        ConfirmedBusinessUnit = ''
        Reviewer = ''
        ReviewedAt = ''
        Notes = ''
        NextAction = ''
        AllowedDecisions = Get-ShareSurferReviewDecisionAllowedText
        SourceDecisionPath = ''
        ImportWarnings = ''
    }

    $row = Copy-ShareSurferReviewDecisionFields -Target $row -Source $DecisionSource
    $fallbackNextAction = if ($null -ne $Packet -and $null -ne $Packet.PSObject.Properties['SuggestedNextAction']) { [string]$Packet.SuggestedNextAction } else { '' }
    Complete-ShareSurferReviewDecisionRow -Row $row -FallbackNextAction $fallbackNextAction -SourceDecisionPath $SourceDecisionPath -ExtraWarning $ExtraWarning
}

function New-ShareSurferMigrationClusterDecisionRow {
    param(
        $Area,

        $DecisionSource,

        [string] $SourceDecisionPath = '',

        [string] $ExtraWarning = ''
    )

    $relatedAreaId = if ($null -ne $Area -and $null -ne $Area.PSObject.Properties['RelatedAreaId']) { [string]$Area.RelatedAreaId } elseif ($null -ne $DecisionSource -and $null -ne $DecisionSource.PSObject.Properties['RelatedAreaId']) { [string]$DecisionSource.RelatedAreaId } else { '' }
    $row = [pscustomobject]@{
        DecisionId = if (-not [string]::IsNullOrWhiteSpace($relatedAreaId)) { 'migration-decision-{0}' -f $relatedAreaId } elseif ($null -ne $DecisionSource -and $null -ne $DecisionSource.PSObject.Properties['DecisionId']) { [string]$DecisionSource.DecisionId } else { 'migration-decision-unmatched' }
        RelatedAreaId = $relatedAreaId
        RelatedDataArea = if ($null -ne $Area -and $null -ne $Area.PSObject.Properties['RelatedDataArea']) { [string]$Area.RelatedDataArea } elseif ($null -ne $DecisionSource -and $null -ne $DecisionSource.PSObject.Properties['RelatedDataArea']) { [string]$DecisionSource.RelatedDataArea } else { '' }
        BusinessUnit = if ($null -ne $Area -and $null -ne $Area.PSObject.Properties['BusinessUnit']) { [string]$Area.BusinessUnit } elseif ($null -ne $DecisionSource -and $null -ne $DecisionSource.PSObject.Properties['BusinessUnit']) { [string]$DecisionSource.BusinessUnit } else { '' }
        Owner = if ($null -ne $Area -and $null -ne $Area.PSObject.Properties['Owner']) { [string]$Area.Owner } elseif ($null -ne $DecisionSource -and $null -ne $DecisionSource.PSObject.Properties['Owner']) { [string]$DecisionSource.Owner } else { '' }
        Pattern = if ($null -ne $Area -and $null -ne $Area.PSObject.Properties['Pattern']) { [string]$Area.Pattern } elseif ($null -ne $DecisionSource -and $null -ne $DecisionSource.PSObject.Properties['Pattern']) { [string]$DecisionSource.Pattern } else { '' }
        Source = if ($null -ne $Area -and $null -ne $Area.PSObject.Properties['Source']) { [string]$Area.Source } elseif ($null -ne $DecisionSource -and $null -ne $DecisionSource.PSObject.Properties['Source']) { [string]$DecisionSource.Source } else { '' }
        RelatednessStrength = if ($null -ne $Area -and $null -ne $Area.PSObject.Properties['RelatednessStrength']) { [string]$Area.RelatednessStrength } elseif ($null -ne $DecisionSource -and $null -ne $DecisionSource.PSObject.Properties['RelatednessStrength']) { [string]$DecisionSource.RelatednessStrength } else { '' }
        RiskLevel = if ($null -ne $Area -and $null -ne $Area.PSObject.Properties['RiskLevel']) { [string]$Area.RiskLevel } elseif ($null -ne $DecisionSource -and $null -ne $DecisionSource.PSObject.Properties['RiskLevel']) { [string]$DecisionSource.RiskLevel } else { '' }
        MigrationReadiness = if ($null -ne $Area -and $null -ne $Area.PSObject.Properties['MigrationReadiness']) { [string]$Area.MigrationReadiness } elseif ($null -ne $DecisionSource -and $null -ne $DecisionSource.PSObject.Properties['MigrationReadiness']) { [string]$DecisionSource.MigrationReadiness } else { '' }
        MatchingShares = if ($null -ne $Area -and $null -ne $Area.PSObject.Properties['MatchingShares']) { [string]$Area.MatchingShares } elseif ($null -ne $DecisionSource -and $null -ne $DecisionSource.PSObject.Properties['MatchingShares']) { [string]$DecisionSource.MatchingShares } else { '' }
        MatchingItems = if ($null -ne $Area -and $null -ne $Area.PSObject.Properties['MatchingItems']) { [string]$Area.MatchingItems } elseif ($null -ne $DecisionSource -and $null -ne $DecisionSource.PSObject.Properties['MatchingItems']) { [string]$DecisionSource.MatchingItems } else { '' }
        ReviewItemCount = if ($null -ne $Area -and $null -ne $Area.PSObject.Properties['ReviewItemCount']) { [string]$Area.ReviewItemCount } elseif ($null -ne $DecisionSource -and $null -ne $DecisionSource.PSObject.Properties['ReviewItemCount']) { [string]$DecisionSource.ReviewItemCount } else { '' }
        FindingCount = if ($null -ne $Area -and $null -ne $Area.PSObject.Properties['FindingCount']) { [string]$Area.FindingCount } elseif ($null -ne $DecisionSource -and $null -ne $DecisionSource.PSObject.Properties['FindingCount']) { [string]$DecisionSource.FindingCount } else { '' }
        ConflictCount = if ($null -ne $Area -and $null -ne $Area.PSObject.Properties['ConflictCount']) { [string]$Area.ConflictCount } elseif ($null -ne $DecisionSource -and $null -ne $DecisionSource.PSObject.Properties['ConflictCount']) { [string]$DecisionSource.ConflictCount } else { '' }
        PartialShareCount = if ($null -ne $Area -and $null -ne $Area.PSObject.Properties['PartialShareCount']) { [string]$Area.PartialShareCount } elseif ($null -ne $DecisionSource -and $null -ne $DecisionSource.PSObject.Properties['PartialShareCount']) { [string]$DecisionSource.PartialShareCount } else { '' }
        DirectGroupCount = if ($null -ne $Area -and $null -ne $Area.PSObject.Properties['DirectGroupCount']) { [string]$Area.DirectGroupCount } elseif ($null -ne $DecisionSource -and $null -ne $DecisionSource.PSObject.Properties['DirectGroupCount']) { [string]$DecisionSource.DirectGroupCount } else { '' }
        ExpandedMemberCount = if ($null -ne $Area -and $null -ne $Area.PSObject.Properties['ExpandedMemberCount']) { [string]$Area.ExpandedMemberCount } elseif ($null -ne $DecisionSource -and $null -ne $DecisionSource.PSObject.Properties['ExpandedMemberCount']) { [string]$DecisionSource.ExpandedMemberCount } else { '' }
        Decision = ''
        DecisionStatus = 'Pending'
        ConfirmedOwner = ''
        ConfirmedBusinessUnit = ''
        Reviewer = ''
        ReviewedAt = ''
        Notes = ''
        NextAction = ''
        AllowedDecisions = Get-ShareSurferReviewDecisionAllowedText
        SourceDecisionPath = ''
        ImportWarnings = ''
    }

    $row = Copy-ShareSurferReviewDecisionFields -Target $row -Source $DecisionSource
    $fallbackNextAction = if ($null -ne $Area -and $null -ne $Area.PSObject.Properties['SuggestedNextAction']) { [string]$Area.SuggestedNextAction } else { '' }
    Complete-ShareSurferReviewDecisionRow -Row $row -FallbackNextAction $fallbackNextAction -SourceDecisionPath $SourceDecisionPath -ExtraWarning $ExtraWarning
}

function New-ShareSurferReviewDecisionReusableCommands {
    param(
        [Parameter(Mandatory = $true)]
        [string] $ExportPath,

        [Parameter(Mandatory = $true)]
        [string] $OutputPath,

        [string] $OwnerDecisionPath = '',

        [string] $MigrationDecisionPath = '',

        [string] $ImportOutputPath = '',

        [ValidateSet('All', 'OwnerReview', 'MigrationCluster')]
        [string] $DecisionScope = 'All'
    )

    $includeOwner = $DecisionScope -in @('All', 'OwnerReview')
    $includeMigration = $DecisionScope -in @('All', 'MigrationCluster')
    $ownerPath = if ($includeOwner) { if ([string]::IsNullOrWhiteSpace($OwnerDecisionPath)) { Join-Path $OutputPath 'owner_review_decisions.csv' } else { $OwnerDecisionPath } } else { '' }
    $migrationPath = if ($includeMigration) { if ([string]::IsNullOrWhiteSpace($MigrationDecisionPath)) { Join-Path $OutputPath 'migration_cluster_decisions.csv' } else { $MigrationDecisionPath } } else { '' }
    $normalizedOutputPath = if ([string]::IsNullOrWhiteSpace($ImportOutputPath)) { $ExportPath } else { $ImportOutputPath }

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('# Reusable ShareSurfer review decision commands')
    $lines.Add('# First regenerate blank/review-ready decision drafts when the scan export changes.')
    $lines.Add(('$exportPath = {0}' -f (ConvertTo-ShareSurferPowerShellLiteral -Value $ExportPath)))
    $lines.Add(('$decisionPath = {0}' -f (ConvertTo-ShareSurferPowerShellLiteral -Value $OutputPath)))
    $lines.Add(('$importOutputPath = {0}' -f (ConvertTo-ShareSurferPowerShellLiteral -Value $normalizedOutputPath)))
    if ($includeOwner) {
        $lines.Add(('$ownerDecisionPath = {0}' -f (ConvertTo-ShareSurferPowerShellLiteral -Value $ownerPath)))
    }
    if ($includeMigration) {
        $lines.Add(('$migrationDecisionPath = {0}' -f (ConvertTo-ShareSurferPowerShellLiteral -Value $migrationPath)))
    }
    $lines.Add('')
    $lines.Add('# Regenerate blank drafts only before reviewers edit CSVs. This overwrites existing review CSVs.')
    $lines.Add(('# New-ShareSurferReviewDecisionDraft -ExportPath $exportPath -OutputPath $decisionPath -DecisionScope {0} -Force' -f $DecisionScope))
    $lines.Add('')
    $lines.Add('# After reviewers fill Decision, ConfirmedOwner, Reviewer, ReviewedAt, and Notes, normalize them back into the export evidence set.')
    $importCommand = New-Object System.Collections.Generic.List[string]
    $importCommand.Add('Import-ShareSurferReviewDecisions')
    $importCommand.Add('-ExportPath $exportPath')
    if ($includeOwner) {
        $importCommand.Add('-OwnerDecisionPath $ownerDecisionPath')
    }
    if ($includeMigration) {
        $importCommand.Add('-MigrationDecisionPath $migrationDecisionPath')
    }
    $importCommand.Add('-OutputPath $importOutputPath')
    $importCommand.Add('-Force')
    $lines.Add(($importCommand -join ' '))

    $lines -join [Environment]::NewLine
}
