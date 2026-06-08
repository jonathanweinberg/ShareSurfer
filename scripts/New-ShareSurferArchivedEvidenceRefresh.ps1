[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $RunRoot,

    [string] $OutputPath = '',

    [switch] $RequireLiveEvidence,
    [switch] $AllowMissingSupportBundle,
    [switch] $AllowMissingIssueComments
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$modulePath = Join-Path $repoRoot 'src\ShareSurfer\ShareSurfer.psd1'
$helperPath = Join-Path $PSScriptRoot 'ShareSurferLabValidation.Helpers.ps1'
$acceptanceScriptPath = Join-Path $PSScriptRoot 'Test-ShareSurferV1Acceptance.ps1'
$issueSummaryScriptPath = Join-Path $PSScriptRoot 'New-ShareSurferValidationIssueSummary.ps1'
$issueCommentScriptPath = Join-Path $PSScriptRoot 'New-ShareSurferValidationIssueComments.ps1'
$issueCommentPublisherScriptPath = Join-Path $PSScriptRoot 'Publish-ShareSurferValidationIssueComments.ps1'
$closeoutChecklistScriptPath = Join-Path $PSScriptRoot 'New-ShareSurferValidationCloseoutChecklist.ps1'

Import-Module $modulePath -Force -ErrorAction Stop
. $helperPath

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path $RunRoot 'refreshed-evidence'
}

$planPath = Join-Path $RunRoot 'lab-plan.json'
$exportPath = Join-Path $RunRoot 'export'
$criteriaPath = Join-Path $RunRoot 'lab-validation-criteria.csv'

foreach ($requiredPath in @($planPath, $exportPath, $criteriaPath)) {
    if (-not (Test-Path -LiteralPath $requiredPath)) {
        throw ('Required archived evidence path was not found: {0}' -f $requiredPath)
    }
}

New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null

function Convert-ShareSurferArchivedCsvToSchema {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Path,

        [Parameter(Mandatory = $true)]
        [string[]] $Columns
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return
    }

    $rows = @(Import-Csv -LiteralPath $Path)
    if ($rows.Count -eq 0) {
        return
    }

    $normalizedRows = foreach ($row in $rows) {
        $record = [ordered]@{}
        foreach ($column in $Columns) {
            if ($row.PSObject.Properties[$column]) {
                $record[$column] = [string]$row.PSObject.Properties[$column].Value
            }
            else {
                $record[$column] = ''
            }
        }
        [pscustomobject]$record
    }

    $normalizedRows | Export-Csv -LiteralPath $Path -NoTypeInformation -Encoding UTF8
}

$outputExportPath = Join-Path $OutputPath 'export'
if (Test-Path -LiteralPath $outputExportPath) {
    Remove-Item -LiteralPath $outputExportPath -Recurse -Force
}
Copy-Item -LiteralPath $exportPath -Destination $outputExportPath -Recurse -Force
Convert-ShareSurferArchivedCsvToSchema -Path (Join-Path $outputExportPath 'identities.csv') -Columns @(
    'Identity',
    'SamAccountName',
    'DisplayName',
    'ObjectClass',
    'EmployeeId',
    'EmployeeNumber',
    'UserPrincipalName',
    'Mail',
    'Department',
    'Title',
    'Company',
    'Office',
    'AccountEnabled',
    'Manager',
    'ManagerLevel1',
    'ManagerLevel2',
    'ManagerLevel3',
    'ObsPath',
    'ObsAttribute',
    'PotentialServiceAccount',
    'DistinguishedName'
)
Convert-ShareSurferArchivedCsvToSchema -Path (Join-Path $outputExportPath 'org_chains.csv') -Columns @(
    'Identity',
    'EmployeeId',
    'EmployeeNumber',
    'Department',
    'Title',
    'Company',
    'Office',
    'ManagerLevel1',
    'ManagerLevel2',
    'ManagerLevel3',
    'ObsPath',
    'ObsAttribute',
    'PotentialServiceAccount'
)
if (-not (Test-Path -LiteralPath (Join-Path $outputExportPath 'discounted_principals.csv'))) {
    Set-Content -LiteralPath (Join-Path $outputExportPath 'discounted_principals.csv') -Value '"Identity","Reason","Scope","MatchType"' -Encoding UTF8
}
Convert-ShareSurferArchivedCsvToSchema -Path (Join-Path $outputExportPath 'permissioned_groups.csv') -Columns @(
    'Group',
    'DisplayName',
    'ObjectClass',
    'ObsPath',
    'ManagerLevel1',
    'ShareAssignments',
    'NtfsAssignments',
    'ExpandedMembers',
    'MaxDepth',
    'HasCycle',
    'IsTruncated',
    'Rights',
    'ShareId',
    'ShareIds',
    'Sources',
    'FullPath',
    'ExamplePath',
    'DiscountedPrincipal',
    'DiscountReason',
    'DiscountScope'
)
Convert-ShareSurferArchivedCsvToSchema -Path (Join-Path $outputExportPath 'owner_risk_pivots.csv') -Columns @(
    'BusinessUnit',
    'Owner',
    'Pattern',
    'Source',
    'MatchingItems',
    'Directories',
    'Files',
    'FindingCount',
    'ConflictCount',
    'PartialShareCount',
    'DirectIdentityCount',
    'DirectGroupCount',
    'ExpandedMemberCount',
    'RiskLevel',
    'ReadinessSignals',
    'DiscountedPrincipal',
    'DiscountedPrincipalCount',
    'DiscountedGroupCount',
    'DiscountedPrincipals',
    'DiscountReason'
)
Convert-ShareSurferArchivedCsvToSchema -Path (Join-Path $outputExportPath 'related_data_areas.csv') -Columns @(
    'RelatedAreaId',
    'RelatedDataArea',
    'BusinessUnit',
    'Owner',
    'Pattern',
    'Source',
    'RelatednessStrength',
    'RelationshipSignalCount',
    'SupportingSignalCount',
    'ReadinessSignalCount',
    'RelationshipSignals',
    'SupportingEvidence',
    'ReadinessSignals',
    'CoreFiveChips',
    'EvidenceCompleteness',
    'RiskLevel',
    'MigrationReadiness',
    'MatchingShares',
    'MatchingItems',
    'Directories',
    'Files',
    'FindingCount',
    'ConflictCount',
    'ReviewItemCount',
    'PartialShareCount',
    'DirectIdentityCount',
    'DirectGroupCount',
    'ExpandedMemberCount',
    'RelatedBecauseShort',
    'RelatedBecause',
    'SuggestedNextAction',
    'DiscountedPrincipal',
    'DiscountedPrincipalCount',
    'DiscountedGroupCount',
    'DiscountedPrincipals',
    'DiscountReason'
)
Convert-ShareSurferArchivedCsvToSchema -Path (Join-Path $outputExportPath 'owner_review_packets.csv') -Columns @(
    'ReviewPacketId',
    'BusinessUnit',
    'Owner',
    'Pattern',
    'Source',
    'RiskLevel',
    'ReviewStatus',
    'WhyReview',
    'WhatToReviewFirst',
    'SuggestedNextAction',
    'MatchingItems',
    'Directories',
    'Files',
    'FindingCount',
    'ConflictCount',
    'PartialShareCount',
    'DirectIdentityCount',
    'DirectGroupCount',
    'ExpandedMemberCount',
    'MigrationReadiness',
    'RelatedDataAreaCount',
    'RelatednessStrength',
    'RelationshipSignalCount',
    'ReadinessSignals',
    'DiscountedPrincipal',
    'DiscountedPrincipalCount',
    'DiscountedGroupCount',
    'DiscountedPrincipals',
    'DiscountReason'
)

$plan = Get-Content -LiteralPath $planPath -Raw | ConvertFrom-Json
$existingCriteria = @(Import-Csv -LiteralPath $criteriaPath)
$refreshedCriteria = @(New-ShareSurferLabValidationCriteriaRows -Plan $plan -ExportPath $exportPath -LabRoot ([string]$plan.RootPath) -CreateLab -IncludeFiles)
$strengthenedRows = New-Object System.Collections.ArrayList

foreach ($row in $existingCriteria) {
    if ([string]$row.Name -ne 'FocusedAclScenarios') {
        continue
    }

    $freshRow = @($refreshedCriteria | Where-Object { [string]$_.Name -eq 'FocusedAclScenarios' }) | Select-Object -First 1
    if ($null -eq $freshRow -or [string]$freshRow.EvidenceSource -ne 'ScanExport:acl_entries.csv;findings.csv;conflicts.csv;items.csv') {
        continue
    }

    $row.ActualValue = [string]$freshRow.ActualValue
    $row.Passed = [string]$freshRow.Passed
    $row.EvidenceSource = [string]$freshRow.EvidenceSource
    $row.EvidenceDetail = [string]$freshRow.EvidenceDetail
    [void]$strengthenedRows.Add([pscustomobject]@{
            Name = [string]$row.Name
            EvidenceSource = [string]$row.EvidenceSource
            ActualValue = [string]$row.ActualValue
            EvidenceDetail = [string]$row.EvidenceDetail
        })
}

$outputCriteriaPath = Join-Path $OutputPath 'lab-validation-criteria.csv'
$outputLiveEvidencePath = Join-Path $OutputPath 'live-evidence.json'
$outputLiveEvidenceReviewPath = Join-Path $OutputPath 'live-evidence-review.csv'
$outputAcceptancePath = Join-Path $OutputPath 'v1-acceptance.json'
$outputAcceptanceSummaryPath = Join-Path $OutputPath 'v1-acceptance-summary.json'
$outputIssueSummaryPath = Join-Path $OutputPath 'issue-summary.md'
$outputIssueCommentDirectory = Join-Path $OutputPath 'issue-comments'
$outputIssueCommentPublishPreviewPath = Join-Path $OutputPath 'issue-comment-publish-preview.csv'
$outputCloseoutChecklistPath = Join-Path $OutputPath 'validation-closeout-checklist.md'
$outputSummaryPath = Join-Path $OutputPath 'evidence-refresh-summary.md'

$existingCriteria | Export-Csv -LiteralPath $outputCriteriaPath -NoTypeInformation -Encoding UTF8
$liveEvidence = Test-ShareSurferLabValidationLiveEvidence -CriteriaRows $existingCriteria
$liveEvidence | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $outputLiveEvidencePath -Encoding UTF8
$liveEvidenceReview = @(New-ShareSurferLabValidationEvidenceReview -CriteriaRows $existingCriteria)
$liveEvidenceReview | Export-Csv -LiteralPath $outputLiveEvidenceReviewPath -NoTypeInformation -Encoding UTF8

$acceptance = & $acceptanceScriptPath `
    -RunRoot $RunRoot `
    -ExportPath $outputExportPath `
    -CriteriaPath $outputCriteriaPath `
    -LiveEvidencePath $outputLiveEvidencePath `
    -LiveEvidenceReviewPath $outputLiveEvidenceReviewPath `
    -SummaryPath $outputAcceptanceSummaryPath `
    -RequireLiveEvidence:$RequireLiveEvidence `
    -AllowMissingSupportBundle:$AllowMissingSupportBundle `
    -AllowMissingIssueComments:$AllowMissingIssueComments
$acceptance | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $outputAcceptancePath -Encoding UTF8

& $issueSummaryScriptPath `
    -RunRoot $RunRoot `
    -AcceptanceSummaryPath $outputAcceptanceSummaryPath `
    -LiveEvidencePath $outputLiveEvidencePath `
    -LiveEvidenceReviewPath $outputLiveEvidenceReviewPath `
    -CriteriaPath $outputCriteriaPath `
    -OutputPath $outputIssueSummaryPath `
    -AllowMissingSupportBundle:$AllowMissingSupportBundle | Out-Null

& $issueCommentScriptPath `
    -RunRoot $RunRoot `
    -AcceptanceSummaryPath $outputAcceptanceSummaryPath `
    -AcceptancePath $outputAcceptancePath `
    -LiveEvidencePath $outputLiveEvidencePath `
    -LiveEvidenceReviewPath $outputLiveEvidenceReviewPath `
    -CriteriaPath $outputCriteriaPath `
    -OutputDirectory $outputIssueCommentDirectory `
    -AllowMissingSupportBundle:$AllowMissingSupportBundle | Out-Null

$publishPreview = @(& $issueCommentPublisherScriptPath -RunRoot $OutputPath -IssueCommentPath $outputIssueCommentDirectory)
$publishPreview | Export-Csv -LiteralPath $outputIssueCommentPublishPreviewPath -NoTypeInformation -Encoding UTF8

& $closeoutChecklistScriptPath `
    -RunRoot $RunRoot `
    -AcceptanceSummaryPath $outputAcceptanceSummaryPath `
    -LiveEvidencePath $outputLiveEvidencePath `
    -LiveEvidenceReviewPath $outputLiveEvidenceReviewPath `
    -CriteriaPath $outputCriteriaPath `
    -PreflightPath (Join-Path $RunRoot 'lab-preflight.csv') `
    -IssueCommentDirectory $outputIssueCommentDirectory `
    -IssueCommentPublishPreviewPath $outputIssueCommentPublishPreviewPath `
    -OutputPath $outputCloseoutChecklistPath `
    -AllowMissingSupportBundle:$AllowMissingSupportBundle | Out-Null

$failedChecks = @($acceptance.Checks | Where-Object { -not $_.Passed } | ForEach-Object { [string]$_.Name })
$fallbackCriteria = @($liveEvidence.FallbackCriteria | ForEach-Object { [string]$_ })
$summaryLines = New-Object System.Collections.Generic.List[string]
$summaryLines.Add('# ShareSurfer Archived Evidence Refresh')
$summaryLines.Add('')
$summaryLines.Add('This folder contains a derived review of an existing lab run. It preserves the historical run folder and writes refreshed validation artifacts separately.')
$summaryLines.Add('')
$summaryLines.Add(('Generated at: `{0}`' -f (Get-Date).ToUniversalTime().ToString('o')))
$summaryLines.Add(('Strengthened criteria: `{0}`' -f (@($strengthenedRows | ForEach-Object { $_.Name }) -join ', ')))
$summaryLines.Add(('Live evidence valid: `{0}`' -f [bool]$liveEvidence.IsValid))
$summaryLines.Add(('Live evidence fallback count: `{0}`' -f [int]$liveEvidence.FallbackCount))
$summaryLines.Add(('Live evidence fallback criteria: `{0}`' -f ($fallbackCriteria -join ', ')))
$summaryLines.Add(('Acceptance valid: `{0}`' -f [bool]$acceptance.IsValid))
$summaryLines.Add(('Acceptance failed check count: `{0}`' -f [int]$acceptance.FailedCheckCount))
$summaryLines.Add(('Acceptance failed checks: `{0}`' -f ($failedChecks -join ', ')))
$summaryLines.Add('')
$summaryLines.Add('Use this refresh only when the archived CSV export already proves a criterion but older validation metadata did not capture it. Rerun the live Windows/AD validation when directory, filesystem, or collector evidence itself is missing.')
$summaryLines | Set-Content -LiteralPath $outputSummaryPath -Encoding UTF8

[pscustomobject]@{
    RunRoot = $RunRoot
    OutputPath = $OutputPath
    CriteriaPath = $outputCriteriaPath
    LiveEvidencePath = $outputLiveEvidencePath
    LiveEvidenceReviewPath = $outputLiveEvidenceReviewPath
    AcceptancePath = $outputAcceptancePath
    AcceptanceSummaryPath = $outputAcceptanceSummaryPath
    IssueSummaryPath = $outputIssueSummaryPath
    IssueCommentDirectory = $outputIssueCommentDirectory
    IssueCommentPublishPreviewPath = $outputIssueCommentPublishPreviewPath
    CloseoutChecklistPath = $outputCloseoutChecklistPath
    SummaryPath = $outputSummaryPath
    StrengthenedCriteria = @($strengthenedRows)
    LiveEvidenceIsValid = [bool]$liveEvidence.IsValid
    LiveEvidenceFallbackCount = [int]$liveEvidence.FallbackCount
    AcceptanceIsValid = [bool]$acceptance.IsValid
    AcceptanceFailedCheckCount = [int]$acceptance.FailedCheckCount
}
