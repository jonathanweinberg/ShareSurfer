[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string] $LabRoot = 'C:\ShareSurferLab',
    [string] $OutputRoot = 'C:\ShareSurfer\lab-validation',
    [string] $DomainNetBiosName = $env:USERDOMAIN,
    [string] $ObsAttribute = 'extensionAttribute10',
    [ValidateSet('Focused', 'Enterprise')]
    [string] $Scale = 'Focused',
    [int] $EnterpriseUserCount = 2500,
    [int] $EnterpriseShareCount = 250,
    [int] $EnterpriseFilesPerShare = 8,
    [int] $EnterpriseTargetDepth = 5,
    [int64] $EnterpriseFileSizeBytes = 512,
    [int] $LongPathShareCount = 1,
    [int64] $MaxLabBytes = 2147483648,
    [int64] $AbsoluteMaxLabBytes = 8589934592,
    [switch] $CreateLab,
    [switch] $IncludeFiles,
    [switch] $RequireLiveEvidence,
    [switch] $PreflightOnly
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

function Add-ShareSurferLabRunEvent {
    param(
        [Parameter(Mandatory = $true)]
        [string] $EventPath,

        [Parameter(Mandatory = $true)]
        [string] $Phase,

        [ValidateSet('Info', 'Warning', 'Error')]
        [string] $Level = 'Info',

        [Parameter(Mandatory = $true)]
        [string] $Message,

        [string] $Detail = ''
    )

    $event = [ordered]@{
        Timestamp = (Get-Date).ToUniversalTime().ToString('o')
        Phase = $Phase
        Level = $Level
        Message = $Message
        Detail = $Detail
    }
    $event | ConvertTo-Json -Compress -Depth 4 | Add-Content -LiteralPath $EventPath -Encoding UTF8
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$modulePath = Join-Path $repoRoot 'src\ShareSurfer\ShareSurfer.psd1'
$helperPath = Join-Path $PSScriptRoot 'ShareSurferLabValidation.Helpers.ps1'
Import-Module $modulePath -Force -ErrorAction Stop
. $helperPath

if ([string]::IsNullOrWhiteSpace($DomainNetBiosName)) {
    $DomainNetBiosName = 'CONTOSO'
}

$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$runRoot = Join-Path $OutputRoot $timestamp
$exportPath = Join-Path $runRoot 'export'
$reportPath = Join-Path $runRoot 'report.html'
$dashboardReviewPath = Join-Path $runRoot 'dashboard-review.md'
$bundlePath = Join-Path $runRoot 'support-bundle-redacted'
$preflightPath = Join-Path $runRoot 'lab-preflight.csv'
$criteriaPath = Join-Path $runRoot 'lab-validation-criteria.csv'
$liveEvidencePath = Join-Path $runRoot 'live-evidence.json'
$liveEvidenceReviewPath = Join-Path $runRoot 'live-evidence-review.csv'
$acceptancePath = Join-Path $runRoot 'v1-acceptance.json'
$acceptanceSummaryPath = Join-Path $runRoot 'v1-acceptance-summary.json'
$issueSummaryPath = Join-Path $runRoot 'issue-summary.md'
$closeoutChecklistPath = Join-Path $runRoot 'validation-closeout-checklist.md'
$issueCommentDirectory = Join-Path $runRoot 'issue-comments'
$issueCommentPublishPreviewPath = Join-Path $runRoot 'issue-comment-publish-preview.csv'
$ownerMappingPath = Join-Path $runRoot 'owner-mapping.csv'
$labRunEventPath = Join-Path $runRoot 'lab-run-events.jsonl'

New-Item -ItemType Directory -Path $runRoot -Force | Out-Null
Add-ShareSurferLabRunEvent -EventPath $labRunEventPath -Phase 'Start' -Message 'ShareSurfer lab validation run started.' -Detail ('RunRoot={0}; Scale={1}; CreateLab={2}; IncludeFiles={3}; RequireLiveEvidence={4}; PreflightOnly={5}' -f $runRoot, $Scale, [bool]$CreateLab, [bool]$IncludeFiles, [bool]$RequireLiveEvidence, [bool]$PreflightOnly)

trap {
    Add-ShareSurferLabRunEvent -EventPath $labRunEventPath -Phase 'Failure' -Level Error -Message 'ShareSurfer lab validation run failed.' -Detail $_.Exception.Message
    throw
}

Add-ShareSurferLabRunEvent -EventPath $labRunEventPath -Phase 'Plan' -Message 'Generating deterministic lab plan.' -Detail ('LabRoot={0}; ObsAttribute={1}; UserCount={2}; ShareCount={3}; FilesPerShare={4}' -f $LabRoot, $ObsAttribute, $EnterpriseUserCount, $EnterpriseShareCount, $EnterpriseFilesPerShare)
$plan = New-ShareSurferLabFixture -OutputPlanOnly -RootPath $LabRoot -DomainNetBiosName $DomainNetBiosName -ObsAttribute $ObsAttribute -Scale $Scale -EnterpriseUserCount $EnterpriseUserCount -EnterpriseShareCount $EnterpriseShareCount -EnterpriseFilesPerShare $EnterpriseFilesPerShare -EnterpriseTargetDepth $EnterpriseTargetDepth -EnterpriseFileSizeBytes $EnterpriseFileSizeBytes -LongPathShareCount $LongPathShareCount -MaxLabBytes $MaxLabBytes -AbsoluteMaxLabBytes $AbsoluteMaxLabBytes
$plan | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $runRoot 'lab-plan.json') -Encoding UTF8
@($plan.OwnerMappings) | Export-Csv -LiteralPath $ownerMappingPath -NoTypeInformation -Encoding UTF8
Add-ShareSurferLabRunEvent -EventPath $labRunEventPath -Phase 'Plan' -Message 'Lab plan and owner mapping were written.' -Detail ('PlanPath={0}; OwnerMappingPath={1}; PlannedShares={2}; PlannedUsers={3}; EstimatedLabBytes={4}' -f (Join-Path $runRoot 'lab-plan.json'), $ownerMappingPath, @($plan.Shares).Count, @($plan.Users).Count, $plan.EstimatedLabBytes)

Add-ShareSurferLabRunEvent -EventPath $labRunEventPath -Phase 'Preflight' -Message 'Running lab validation preflight checks.' -Detail ('PreflightPath={0}' -f $preflightPath)
$preflightRows = @(New-ShareSurferLabValidationPreflight -Plan $plan -LabRoot $LabRoot -RunRoot $runRoot -CreateLab:$CreateLab -IncludeFiles:$IncludeFiles -RequireLiveEvidence:$RequireLiveEvidence)
$preflightRows | Export-Csv -LiteralPath $preflightPath -NoTypeInformation -Encoding UTF8
$failedPreflightRows = @($preflightRows | Where-Object { $_.Required -and -not $_.Passed })
Add-ShareSurferLabRunEvent -EventPath $labRunEventPath -Phase 'Preflight' -Level $(if ($failedPreflightRows.Count -eq 0) { 'Info' } else { 'Warning' }) -Message 'Lab validation preflight completed.' -Detail ('PreflightPath={0}; FailedRequiredCount={1}; TotalRows={2}' -f $preflightPath, $failedPreflightRows.Count, $preflightRows.Count)
if ($PreflightOnly) {
    Add-ShareSurferLabRunEvent -EventPath $labRunEventPath -Phase 'Complete' -Message 'Preflight-only lab validation run completed before creating or scanning the lab.' -Detail ('PreflightPassed={0}; PreflightFailedCount={1}' -f ($failedPreflightRows.Count -eq 0), $failedPreflightRows.Count)
    return [pscustomobject]@{
        RunRoot = $runRoot
        PreflightOnly = $true
        LabRunEventPath = $labRunEventPath
        PreflightPath = $preflightPath
        PreflightPassed = ($failedPreflightRows.Count -eq 0)
        PreflightFailedCount = $failedPreflightRows.Count
        PlanPath = Join-Path $runRoot 'lab-plan.json'
        OwnerMappingPath = $ownerMappingPath
        LabRoot = $LabRoot
        Scale = $Scale
        EstimatedLabBytes = $plan.EstimatedLabBytes
        MaxLabBytes = $plan.MaxLabBytes
        ShareCount = @($plan.Shares).Count
        UserCount = @($plan.Users).Count
        FileFixtureCount = @($plan.FileFixtures).Count
    }
}
if ($failedPreflightRows.Count -gt 0) {
    throw ('ShareSurfer lab validation preflight failed. See {0}' -f $preflightPath)
}

if ($CreateLab) {
    if ($PSCmdlet.ShouldProcess($LabRoot, 'Create or update ShareSurfer Windows/AD lab fixtures')) {
        Add-ShareSurferLabRunEvent -EventPath $labRunEventPath -Phase 'CreateLab' -Message 'Creating or updating live Windows/AD lab fixtures.' -Detail ('LabRoot={0}; ShareCount={1}; UserCount={2}; FileFixtureCount={3}' -f $LabRoot, @($plan.Shares).Count, @($plan.Users).Count, @($plan.FileFixtures).Count)
        New-ShareSurferLabFixture -RootPath $LabRoot -DomainNetBiosName $DomainNetBiosName -ObsAttribute $ObsAttribute -Scale $Scale -EnterpriseUserCount $EnterpriseUserCount -EnterpriseShareCount $EnterpriseShareCount -EnterpriseFilesPerShare $EnterpriseFilesPerShare -EnterpriseTargetDepth $EnterpriseTargetDepth -EnterpriseFileSizeBytes $EnterpriseFileSizeBytes -LongPathShareCount $LongPathShareCount -MaxLabBytes $MaxLabBytes -AbsoluteMaxLabBytes $AbsoluteMaxLabBytes -Force | Out-Null
        Add-ShareSurferLabRunEvent -EventPath $labRunEventPath -Phase 'CreateLab' -Message 'Live lab fixture creation completed.' -Detail ('LabRoot={0}' -f $LabRoot)
    }
}

$shareNames = @($plan.Shares | ForEach-Object { $_.ShareName })
Add-ShareSurferLabRunEvent -EventPath $labRunEventPath -Phase 'Scan' -Message 'Starting ShareSurfer scan for planned lab shares.' -Detail ('ComputerName={0}; ShareCount={1}; OutputPath={2}' -f $env:COMPUTERNAME, $shareNames.Count, $exportPath)
Invoke-ShareSurferScan -ComputerName $env:COMPUTERNAME -ShareName $shareNames -OutputPath $exportPath -ObsAttribute $ObsAttribute -OwnerMappingPath $ownerMappingPath -IncludeFiles:$IncludeFiles | Out-Null
Add-ShareSurferLabRunEvent -EventPath $labRunEventPath -Phase 'Scan' -Message 'ShareSurfer scan completed.' -Detail ('ExportPath={0}' -f $exportPath)

Add-ShareSurferLabRunEvent -EventPath $labRunEventPath -Phase 'ExportValidation' -Message 'Validating normalized CSV export set.' -Detail ('ExportPath={0}' -f $exportPath)
$validation = Test-ShareSurferExport -ExportPath $exportPath
$validation | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $runRoot 'validation.json') -Encoding UTF8
if (-not $validation.IsValid) {
    throw ('ShareSurfer export validation failed. See {0}' -f (Join-Path $runRoot 'validation.json'))
}
Add-ShareSurferLabRunEvent -EventPath $labRunEventPath -Phase 'ExportValidation' -Message 'Normalized CSV export validation passed.' -Detail ('ValidationPath={0}' -f (Join-Path $runRoot 'validation.json'))

Add-ShareSurferLabRunEvent -EventPath $labRunEventPath -Phase 'LabCriteria' -Message 'Measuring lab validation criteria from live evidence where available.' -Detail ('CriteriaPath={0}' -f $criteriaPath)
$criteriaRows = @(New-ShareSurferLabValidationCriteriaRows -Plan $plan -ExportPath $exportPath -LabRoot $LabRoot -CreateLab:$CreateLab -IncludeFiles:$IncludeFiles)
@($criteriaRows) | Export-Csv -LiteralPath $criteriaPath -NoTypeInformation -Encoding UTF8
$liveEvidence = Test-ShareSurferLabValidationLiveEvidence -CriteriaRows $criteriaRows
$liveEvidence | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $liveEvidencePath -Encoding UTF8
$liveEvidenceReview = @(New-ShareSurferLabValidationEvidenceReview -CriteriaRows $criteriaRows)
$liveEvidenceReview | Export-Csv -LiteralPath $liveEvidenceReviewPath -NoTypeInformation -Encoding UTF8
$failedRequiredCriteria = @($criteriaRows | Where-Object { $_.Required -and -not $_.Passed })
if ($failedRequiredCriteria.Count -gt 0) {
    throw ('ShareSurfer lab validation criteria failed. See {0}' -f $criteriaPath)
}
if ($RequireLiveEvidence -and -not $liveEvidence.IsValid) {
    throw ('ShareSurfer live lab evidence validation failed. See {0}' -f $liveEvidencePath)
}
Add-ShareSurferLabRunEvent -EventPath $labRunEventPath -Phase 'LabCriteria' -Message 'Lab validation criteria and live-evidence gate completed.' -Detail ('CriteriaPath={0}; FailedRequiredCount={1}; LiveEvidenceIsValid={2}; FallbackCount={3}' -f $criteriaPath, $failedRequiredCriteria.Count, [bool]$liveEvidence.IsValid, [int]$liveEvidence.FallbackCount)

Add-ShareSurferLabRunEvent -EventPath $labRunEventPath -Phase 'Report' -Message 'Generating offline HTML report.' -Detail ('ReportPath={0}' -f $reportPath)
ConvertTo-ShareSurferReport -ExportPath $exportPath -OutputPath $reportPath | Out-Null
$dashboardReviewScriptPath = Join-Path $PSScriptRoot 'New-ShareSurferDashboardReview.ps1'
Add-ShareSurferLabRunEvent -EventPath $labRunEventPath -Phase 'Report' -Message 'Generating dashboard review evidence.' -Detail ('DashboardReviewPath={0}' -f $dashboardReviewPath)
& $dashboardReviewScriptPath -RunRoot $runRoot -ExportPath $exportPath -ReportPath $reportPath -OutputPath $dashboardReviewPath | Out-Null
Add-ShareSurferLabRunEvent -EventPath $labRunEventPath -Phase 'SupportBundle' -Message 'Generating redacted support bundle with lab-run evidence.' -Detail ('SupportBundlePath={0}' -f $bundlePath)
New-ShareSurferSupportBundle -ExportPath $exportPath -OutputPath $bundlePath -RedactionMode StableToken -IncludeReport -RunRoot $runRoot | Out-Null
$acceptanceScriptPath = Join-Path $PSScriptRoot 'Test-ShareSurferV1Acceptance.ps1'
Add-ShareSurferLabRunEvent -EventPath $labRunEventPath -Phase 'Acceptance' -Message 'Running V1 acceptance package check.' -Detail ('AcceptancePath={0}; AllowMissingBundledAcceptance=True' -f $acceptancePath)
$acceptance = & $acceptanceScriptPath -RunRoot $runRoot -RequireLiveEvidence:$RequireLiveEvidence -AllowMissingBundledAcceptance -AllowMissingIssueComments
$acceptance | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $acceptancePath -Encoding UTF8
if (-not $acceptance.IsValid) {
    throw ('ShareSurfer V1 acceptance validation failed. See {0}' -f $acceptancePath)
}

Add-ShareSurferLabRunEvent -EventPath $labRunEventPath -Phase 'SupportBundle' -Message 'Refreshing redacted support bundle with acceptance evidence.' -Detail ('SupportBundlePath={0}' -f $bundlePath)
New-ShareSurferSupportBundle -ExportPath $exportPath -OutputPath $bundlePath -RedactionMode StableToken -IncludeReport -RunRoot $runRoot | Out-Null
Add-ShareSurferLabRunEvent -EventPath $labRunEventPath -Phase 'Acceptance' -Message 'Running V1 acceptance package check with bundled acceptance evidence.' -Detail ('AcceptancePath={0}' -f $acceptancePath)
$acceptance = & $acceptanceScriptPath -RunRoot $runRoot -RequireLiveEvidence:$RequireLiveEvidence -SummaryPath $acceptanceSummaryPath -AllowMissingIssueComments
$acceptance | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $acceptancePath -Encoding UTF8
if (-not $acceptance.IsValid) {
    throw ('ShareSurfer V1 acceptance validation failed. See {0}' -f $acceptancePath)
}

$issueSummaryScriptPath = Join-Path $PSScriptRoot 'New-ShareSurferValidationIssueSummary.ps1'
Add-ShareSurferLabRunEvent -EventPath $labRunEventPath -Phase 'IssueSummary' -Message 'Generating public-safe validation issue summary.' -Detail ('IssueSummaryPath={0}' -f $issueSummaryPath)
& $issueSummaryScriptPath -RunRoot $runRoot -OutputPath $issueSummaryPath | Out-Null
Add-ShareSurferLabRunEvent -EventPath $labRunEventPath -Phase 'IssueSummary' -Message 'Public-safe validation issue summary generated.' -Detail ('IssueSummaryPath={0}' -f $issueSummaryPath)
$issueCommentScriptPath = Join-Path $PSScriptRoot 'New-ShareSurferValidationIssueComments.ps1'
Add-ShareSurferLabRunEvent -EventPath $labRunEventPath -Phase 'IssueComments' -Message 'Generating public-safe validation issue comment bodies.' -Detail ('IssueCommentDirectory={0}' -f $issueCommentDirectory)
& $issueCommentScriptPath -RunRoot $runRoot -OutputDirectory $issueCommentDirectory | Out-Null
Add-ShareSurferLabRunEvent -EventPath $labRunEventPath -Phase 'IssueComments' -Message 'Public-safe validation issue comment bodies generated.' -Detail ('IssueCommentDirectory={0}' -f $issueCommentDirectory)
$issueCommentPublisherScriptPath = Join-Path $PSScriptRoot 'Publish-ShareSurferValidationIssueComments.ps1'
Add-ShareSurferLabRunEvent -EventPath $labRunEventPath -Phase 'IssueComments' -Message 'Generating validation issue comment publish preview.' -Detail ('PublishPreviewPath={0}' -f $issueCommentPublishPreviewPath)
$issueCommentPublishPreview = @(& $issueCommentPublisherScriptPath -RunRoot $runRoot)
$issueCommentPublishPreview | Export-Csv -LiteralPath $issueCommentPublishPreviewPath -NoTypeInformation -Encoding UTF8
Add-ShareSurferLabRunEvent -EventPath $labRunEventPath -Phase 'IssueComments' -Message 'Validation issue comment publish preview generated.' -Detail ('PublishPreviewPath={0}; PreviewRows={1}' -f $issueCommentPublishPreviewPath, @($issueCommentPublishPreview).Count)
$closeoutChecklistScriptPath = Join-Path $PSScriptRoot 'New-ShareSurferValidationCloseoutChecklist.ps1'
Add-ShareSurferLabRunEvent -EventPath $labRunEventPath -Phase 'CloseoutChecklist' -Message 'Generating validation closeout checklist.' -Detail ('CloseoutChecklistPath={0}' -f $closeoutChecklistPath)
& $closeoutChecklistScriptPath -RunRoot $runRoot -OutputPath $closeoutChecklistPath | Out-Null
Add-ShareSurferLabRunEvent -EventPath $labRunEventPath -Phase 'CloseoutChecklist' -Message 'Validation closeout checklist generated.' -Detail ('CloseoutChecklistPath={0}' -f $closeoutChecklistPath)
Add-ShareSurferLabRunEvent -EventPath $labRunEventPath -Phase 'Complete' -Message 'ShareSurfer lab validation evidence completed; refreshing final redacted support bundle with issue summary.' -Detail ('RunRoot={0}; AcceptanceIsValid={1}; LiveEvidenceIsValid={2}; SupportBundlePath={3}; IssueSummaryPath={4}' -f $runRoot, [bool]$acceptance.IsValid, [bool]$liveEvidence.IsValid, $bundlePath, $issueSummaryPath)
New-ShareSurferSupportBundle -ExportPath $exportPath -OutputPath $bundlePath -RedactionMode StableToken -IncludeReport -RunRoot $runRoot | Out-Null
Add-ShareSurferLabRunEvent -EventPath $labRunEventPath -Phase 'Acceptance' -Message 'Running final V1 acceptance package check with issue-comment evidence.' -Detail ('AcceptancePath={0}; IssueCommentDirectory={1}' -f $acceptancePath, $issueCommentDirectory)
$finishedPackageAcceptance = & $acceptanceScriptPath -RunRoot $runRoot -RequireLiveEvidence:$RequireLiveEvidence -SummaryPath $acceptanceSummaryPath
$finishedPackageAcceptance | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $acceptancePath -Encoding UTF8
if (-not $finishedPackageAcceptance.IsValid) {
    throw ('ShareSurfer finished support bundle validation failed. See {0}' -f $acceptancePath)
}
Add-ShareSurferLabRunEvent -EventPath $labRunEventPath -Phase 'SupportBundle' -Message 'Refreshing redacted support bundle with final acceptance evidence.' -Detail ('SupportBundlePath={0}' -f $bundlePath)
New-ShareSurferSupportBundle -ExportPath $exportPath -OutputPath $bundlePath -RedactionMode StableToken -IncludeReport -RunRoot $runRoot | Out-Null
$finishedPackageAcceptance = & $acceptanceScriptPath -RunRoot $runRoot -RequireLiveEvidence:$RequireLiveEvidence
if (-not $finishedPackageAcceptance.IsValid) {
    throw ('ShareSurfer final refreshed support bundle validation failed. See {0}' -f $acceptancePath)
}

[pscustomobject]@{
    RunRoot = $runRoot
    ExportPath = $exportPath
    ReportPath = $reportPath
    DashboardReviewPath = $dashboardReviewPath
    SupportBundlePath = $bundlePath
    ValidationPath = Join-Path $runRoot 'validation.json'
    PreflightPath = $preflightPath
    CriteriaPath = $criteriaPath
    LabRunEventPath = $labRunEventPath
    LiveEvidencePath = $liveEvidencePath
    LiveEvidenceReviewPath = $liveEvidenceReviewPath
    AcceptancePath = $acceptancePath
    AcceptanceSummaryPath = $acceptanceSummaryPath
    IssueSummaryPath = $issueSummaryPath
    CloseoutChecklistPath = $closeoutChecklistPath
    IssueCommentDirectory = $issueCommentDirectory
    IssueCommentPublishPreviewPath = $issueCommentPublishPreviewPath
    OwnerMappingPath = $ownerMappingPath
    AcceptanceIsValid = [bool]$finishedPackageAcceptance.IsValid
    AcceptanceFailedCheckCount = [int]$finishedPackageAcceptance.FailedCheckCount
    LiveEvidenceRequired = [bool]$RequireLiveEvidence
    LiveEvidenceIsValid = [bool]$liveEvidence.IsValid
    LiveEvidenceFallbackCount = [int]$liveEvidence.FallbackCount
    LabCreated = [bool]$CreateLab
    Scale = $Scale
    EstimatedLabBytes = $plan.EstimatedLabBytes
    MaxLabBytes = $plan.MaxLabBytes
    ShareCount = @($plan.Shares).Count
    UserCount = @($plan.Users).Count
    FileFixtureCount = @($plan.FileFixtures).Count
}
