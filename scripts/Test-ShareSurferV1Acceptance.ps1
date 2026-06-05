[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $RunRoot,

    [string] $ExportPath = '',
    [string] $ReportPath = '',
    [string] $DashboardReviewPath = '',
    [string] $SupportBundlePath = '',
    [string] $PreflightPath = '',
    [string] $CriteriaPath = '',
    [string] $LiveEvidencePath = '',
    [string] $LiveEvidenceReviewPath = '',
    [string] $SummaryPath = '',

    [switch] $AllowMissingBundledAcceptance,
    [switch] $AllowMissingIssueComments,

    [switch] $RequireLiveEvidence
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$modulePath = Join-Path $repoRoot 'src\ShareSurfer\ShareSurfer.psd1'
Import-Module $modulePath -Force -ErrorAction Stop

if ($ExportPath -eq '') {
    $ExportPath = Join-Path $RunRoot 'export'
}
if ($ReportPath -eq '') {
    $ReportPath = Join-Path $RunRoot 'report.html'
}
if ($DashboardReviewPath -eq '') {
    $DashboardReviewPath = Join-Path $RunRoot 'dashboard-review.md'
}
if ($SupportBundlePath -eq '') {
    $SupportBundlePath = Join-Path $RunRoot 'support-bundle-redacted'
}
if ($PreflightPath -eq '') {
    $PreflightPath = Join-Path $RunRoot 'lab-preflight.csv'
}
if ($CriteriaPath -eq '') {
    $CriteriaPath = Join-Path $RunRoot 'lab-validation-criteria.csv'
}
if ($LiveEvidencePath -eq '') {
    $LiveEvidencePath = Join-Path $RunRoot 'live-evidence.json'
}
if ($LiveEvidenceReviewPath -eq '') {
    $LiveEvidenceReviewPath = Join-Path $RunRoot 'live-evidence-review.csv'
}
$IssueCommentPath = Join-Path $RunRoot 'issue-comments'
$IssueCommentPublishPreviewPath = Join-Path $RunRoot 'issue-comment-publish-preview.csv'
$CloseoutChecklistPath = Join-Path $RunRoot 'validation-closeout-checklist.md'

function New-ShareSurferAcceptanceCheck {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Name,

        [Parameter(Mandatory = $true)]
        [bool] $Passed,

        [Parameter(Mandatory = $true)]
        [string] $Detail
    )

    [pscustomobject]@{
        Name = $Name
        Passed = $Passed
        Detail = $Detail
    }
}

function New-ShareSurferAcceptanceSummary {
    param(
        [Parameter(Mandatory = $true)]
        [object] $AcceptanceResult
    )

    $passedChecks = @($AcceptanceResult.Checks | Where-Object { $_.Passed })
    $failedChecks = @($AcceptanceResult.Checks | Where-Object { -not $_.Passed })
    $checkSummary = @($AcceptanceResult.Checks | ForEach-Object {
            [pscustomobject]@{
                Name = [string]$_.Name
                Passed = [bool]$_.Passed
            }
        })

    [pscustomobject]@{
        SummaryType = 'ShareSurferV1AcceptanceSummary'
        GeneratedAt = (Get-Date).ToUniversalTime().ToString('o')
        IsValid = [bool]$AcceptanceResult.IsValid
        RequireLiveEvidence = [bool]$AcceptanceResult.RequireLiveEvidence
        CheckCount = @($AcceptanceResult.Checks).Count
        PassedCheckCount = $passedChecks.Count
        FailedCheckCount = $failedChecks.Count
        FailedChecks = @($failedChecks | ForEach-Object { [string]$_.Name })
        Checks = $checkSummary
        DetailPolicy = 'Detailed evidence remains in v1-acceptance.json; this summary intentionally omits raw check detail values.'
    }
}

$checks = New-Object System.Collections.ArrayList

if (-not (Test-Path -LiteralPath $RunRoot)) {
    [void]$checks.Add((New-ShareSurferAcceptanceCheck -Name 'RunRoot' -Passed $false -Detail ('Run root not found: {0}' -f $RunRoot)))
}
else {
    [void]$checks.Add((New-ShareSurferAcceptanceCheck -Name 'RunRoot' -Passed $true -Detail ('Run root found: {0}' -f $RunRoot)))
}

if (Test-Path -LiteralPath $ExportPath) {
    $validation = Test-ShareSurferExport -ExportPath $ExportPath
    $detail = 'ValidationIsValid={0}; MissingFiles={1}; SchemaErrors={2}' -f $validation.IsValid, @($validation.MissingFiles).Count, @($validation.SchemaErrors).Count
    [void]$checks.Add((New-ShareSurferAcceptanceCheck -Name 'NormalizedCsvExport' -Passed ([bool]$validation.IsValid) -Detail $detail))
}
else {
    [void]$checks.Add((New-ShareSurferAcceptanceCheck -Name 'NormalizedCsvExport' -Passed $false -Detail ('Export path not found: {0}' -f $ExportPath)))
}

$ownerReviewPacketsPath = Join-Path $ExportPath 'owner_review_packets.csv'
$ownerReviewPacketsPassed = $false
$ownerReviewPacketsDetail = 'owner_review_packets.csv not found.'
if (Test-Path -LiteralPath $ownerReviewPacketsPath) {
    $ownerReviewPackets = @(Import-Csv -LiteralPath $ownerReviewPacketsPath)
    $ownerReviewPacketsPassed = ($ownerReviewPackets.Count -gt 0)
    $ownerReviewPacketsDetail = 'OwnerReviewPacketRows={0}; Path={1}' -f $ownerReviewPackets.Count, $ownerReviewPacketsPath
}
[void]$checks.Add((New-ShareSurferAcceptanceCheck -Name 'OwnerReviewPackets' -Passed $ownerReviewPacketsPassed -Detail $ownerReviewPacketsDetail))

$rawEventLogPath = Join-Path $ExportPath 'scan_events.jsonl'
$rawEventLogPassed = (Test-Path -LiteralPath $rawEventLogPath) -and ((Get-Item -LiteralPath $rawEventLogPath).Length -gt 0)
[void]$checks.Add((New-ShareSurferAcceptanceCheck -Name 'RawEventLog' -Passed $rawEventLogPassed -Detail ('Raw event log: {0}' -f $rawEventLogPath)))

$reportMarkers = @(
    'ShareSurfer Business Review Dashboard',
    'Dashboard Filters',
    'sharesurfer-data',
    'owner-pivots',
    'Collection Error Drilldown'
)
$reportPassed = $false
$reportDetail = 'Report not found or empty.'
if ((Test-Path -LiteralPath $ReportPath) -and ((Get-Item -LiteralPath $ReportPath).Length -gt 0)) {
    $reportContent = Get-Content -LiteralPath $ReportPath -Raw
    $missingReportMarkers = @($reportMarkers | Where-Object { $reportContent -notlike ('*{0}*' -f $_) })
    $reportPassed = ($missingReportMarkers.Count -eq 0)
    $reportDetail = 'Report={0}; MissingMarkers={1}' -f $ReportPath, ($missingReportMarkers -join ', ')
}
[void]$checks.Add((New-ShareSurferAcceptanceCheck -Name 'OfflineReport' -Passed $reportPassed -Detail $reportDetail))

$dashboardReviewPassed = $false
$dashboardReviewDetail = 'Dashboard review not found.'
if ((Test-Path -LiteralPath $DashboardReviewPath) -and ((Get-Item -LiteralPath $DashboardReviewPath).Length -gt 0)) {
    $dashboardReviewContent = Get-Content -LiteralPath $DashboardReviewPath -Raw
    $dashboardReviewPassed = (
        $dashboardReviewContent -like '*# ShareSurfer Dashboard Review*' -and
        $dashboardReviewContent -like '*Dashboard review status: Pass*' -and
        $dashboardReviewContent -like '*Automated Dashboard Checks*' -and
        $dashboardReviewContent -like '*Operator Live Review*' -and
        $dashboardReviewContent -notlike "*$RunRoot*"
    )
    $dashboardReviewDetail = 'DashboardReview={0}; ContainsRunRoot={1}' -f $DashboardReviewPath, ($dashboardReviewContent -like "*$RunRoot*")
}
[void]$checks.Add((New-ShareSurferAcceptanceCheck -Name 'DashboardReviewEvidence' -Passed $dashboardReviewPassed -Detail $dashboardReviewDetail))

$requiredBundleFiles = @(
    'support_bundle_manifest.csv',
    'support_bundle_files.csv',
    'support_bundle_summary.json',
    'support_bundle_diagnostics.json',
    'support_bundle_redaction_audit.csv',
    'scan_events.jsonl',
    'report.html',
    'dashboard_review.md',
    'lab_run_diagnostics.json',
    'lab_run_events.jsonl',
    'lab_preflight.csv',
    'lab_validation_criteria.csv',
    'live_evidence_review.csv',
    'live_evidence.json',
    'v1_acceptance.json',
    'v1_acceptance_summary.json',
    'validation_closeout_checklist.md',
    'issue_comments/issue-1-lab-fixture-live-proof.md',
    'issue_comments/issue-3-scanner-live-proof.md',
    'issue_comments/issue-5-identity-group-live-proof.md',
    'issue_comments/issue-6-dashboard-live-proof.md',
    'issue_comments/issue_comment_manifest.csv',
    'issue_comments/post_commands.txt',
    'issue_comments/publish_preview.csv'
)
if ($AllowMissingBundledAcceptance) {
    $requiredBundleFiles = @($requiredBundleFiles | Where-Object { $_ -ne 'v1_acceptance.json' -and $_ -ne 'v1_acceptance_summary.json' })
}
if ($AllowMissingIssueComments) {
    $requiredBundleFiles = @($requiredBundleFiles | Where-Object { [string]$_ -notlike 'issue_comments/*' })
    $requiredBundleFiles = @($requiredBundleFiles | Where-Object { $_ -ne 'validation_closeout_checklist.md' })
}
$missingBundleFiles = @($requiredBundleFiles | Where-Object { -not (Test-Path -LiteralPath (Join-Path $SupportBundlePath $_)) })
$bundleManifestPath = Join-Path $SupportBundlePath 'support_bundle_manifest.csv'
$bundleManifestPassed = $false
$bundleManifestDetail = ''
if ($missingBundleFiles.Count -eq 0 -and (Test-Path -LiteralPath $bundleManifestPath)) {
    $bundleManifest = @(Import-Csv -LiteralPath $bundleManifestPath)
    if ($bundleManifest.Count -gt 0) {
        $validationIsValid = [string]$bundleManifest[0].ValidationIsValid
        $redactionLeakCount = 0
        [void][int]::TryParse([string]$bundleManifest[0].RedactionLeakCount, [ref]$redactionLeakCount)
        $bundleManifestPassed = ($validationIsValid -eq 'True' -and $redactionLeakCount -eq 0)
        $bundleManifestDetail = 'ValidationIsValid={0}; RedactionLeakCount={1}' -f $validationIsValid, $redactionLeakCount
    }
    else {
        $bundleManifestDetail = 'support_bundle_manifest.csv has no rows.'
    }
}
else {
    $bundleManifestDetail = 'Required bundle files missing.'
}
$redactedSupportPassed = ($missingBundleFiles.Count -eq 0 -and $bundleManifestPassed)
[void]$checks.Add((New-ShareSurferAcceptanceCheck -Name 'RedactedSupportBundle' -Passed $redactedSupportPassed -Detail ('Bundle={0}; Missing={1}; {2}' -f $SupportBundlePath, ($missingBundleFiles -join ', '), $bundleManifestDetail)))

$labRunDiagnosticsPath = Join-Path $SupportBundlePath 'lab_run_diagnostics.json'
if (Test-Path -LiteralPath $labRunDiagnosticsPath) {
    $labRunDiagnostics = Get-Content -LiteralPath $labRunDiagnosticsPath -Raw | ConvertFrom-Json
    $labRunEvidencePassed = ([string]$labRunDiagnostics.BundleType -eq 'ShareSurferRedactedLabRunDiagnostics' -and [int]$labRunDiagnostics.RunEvents.RowCount -gt 0 -and [int]$labRunDiagnostics.Preflight.RowCount -gt 0 -and [int]$labRunDiagnostics.Criteria.RowCount -gt 0)
    [void]$checks.Add((New-ShareSurferAcceptanceCheck -Name 'LabRunSupportBundleEvidence' -Passed $labRunEvidencePassed -Detail ('LabRunDiagnostics={0}; IncludedFiles={1}' -f $labRunDiagnosticsPath, @($labRunDiagnostics.IncludedFiles).Count)))
}
else {
    [void]$checks.Add((New-ShareSurferAcceptanceCheck -Name 'LabRunSupportBundleEvidence' -Passed $false -Detail ('Lab run diagnostics not found in support bundle: {0}' -f $labRunDiagnosticsPath)))
}

$requiredIssueCommentFiles = @(
    'issue-1-lab-fixture-live-proof.md',
    'issue-3-scanner-live-proof.md',
    'issue-5-identity-group-live-proof.md',
    'issue-6-dashboard-live-proof.md',
    'issue-comment-manifest.csv',
    'post-commands.txt'
)
$missingIssueCommentFiles = @($requiredIssueCommentFiles | Where-Object { -not (Test-Path -LiteralPath (Join-Path $IssueCommentPath $_)) })
$issueCommentManifestPath = Join-Path $IssueCommentPath 'issue-comment-manifest.csv'
$issueCommentPassed = $false
$issueCommentDetail = ''
if ($missingIssueCommentFiles.Count -eq 0 -and (Test-Path -LiteralPath $issueCommentManifestPath)) {
    $issueCommentManifest = @(Import-Csv -LiteralPath $issueCommentManifestPath)
    $issueNumbers = @($issueCommentManifest | ForEach-Object { [string]$_.IssueNumber } | Sort-Object -Unique)
    $missingIssueNumbers = @(@('1', '3', '5', '6') | Where-Object { $issueNumbers -notcontains $_ })
    $issueCommentBodies = @(Get-ChildItem -LiteralPath $IssueCommentPath -Filter 'issue-*.md' -File -ErrorAction SilentlyContinue)
    $issueCommentPassed = ($issueCommentManifest.Count -ge 4 -and $missingIssueNumbers.Count -eq 0 -and $issueCommentBodies.Count -ge 4)
    $issueCommentDetail = 'IssueCommentPath={0}; ManifestRows={1}; BodyFiles={2}; MissingIssues={3}' -f $IssueCommentPath, $issueCommentManifest.Count, $issueCommentBodies.Count, ($missingIssueNumbers -join ', ')
}
else {
    $issueCommentDetail = 'IssueCommentPath={0}; Missing={1}' -f $IssueCommentPath, ($missingIssueCommentFiles -join ', ')
}
if ($AllowMissingIssueComments -and $missingIssueCommentFiles.Count -gt 0) {
    [void]$checks.Add((New-ShareSurferAcceptanceCheck -Name 'ValidationIssueComments' -Passed $true -Detail ('Issue comments pending for staged acceptance: {0}' -f $issueCommentDetail)))
}
else {
    [void]$checks.Add((New-ShareSurferAcceptanceCheck -Name 'ValidationIssueComments' -Passed $issueCommentPassed -Detail $issueCommentDetail))
}

$publishPreviewPassed = $false
$publishPreviewDetail = ''
if (Test-Path -LiteralPath $IssueCommentPublishPreviewPath) {
    $publishPreviewRows = @(Import-Csv -LiteralPath $IssueCommentPublishPreviewPath)
    $publishIssueNumbers = @($publishPreviewRows | ForEach-Object { [string]$_.IssueNumber } | Sort-Object -Unique)
    $missingPublishIssueNumbers = @(@('1', '3', '5', '6') | Where-Object { $publishIssueNumbers -notcontains $_ })
    $nonDryRunRows = @($publishPreviewRows | Where-Object { [string]$_.Status -ne 'DryRun' })
    $postedRows = @($publishPreviewRows | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_.PostedUrl) })
    $bodyFileRows = @($publishPreviewRows | Where-Object { [string]$_.Command -like '*--body-file*' })
    $publishPreviewPassed = ($publishPreviewRows.Count -ge 4 -and $missingPublishIssueNumbers.Count -eq 0 -and $nonDryRunRows.Count -eq 0 -and $postedRows.Count -eq 0 -and $bodyFileRows.Count -eq $publishPreviewRows.Count)
    $publishPreviewDetail = 'PublishPreviewPath={0}; Rows={1}; MissingIssues={2}; NonDryRunRows={3}; PostedRows={4}' -f $IssueCommentPublishPreviewPath, $publishPreviewRows.Count, ($missingPublishIssueNumbers -join ', '), $nonDryRunRows.Count, $postedRows.Count
}
else {
    $publishPreviewDetail = 'Publish preview not found: {0}' -f $IssueCommentPublishPreviewPath
}
if ($AllowMissingIssueComments -and -not (Test-Path -LiteralPath $IssueCommentPublishPreviewPath)) {
    [void]$checks.Add((New-ShareSurferAcceptanceCheck -Name 'ValidationIssueCommentPublishPreview' -Passed $true -Detail ('Issue comment publish preview pending for staged acceptance: {0}' -f $publishPreviewDetail)))
}
else {
    [void]$checks.Add((New-ShareSurferAcceptanceCheck -Name 'ValidationIssueCommentPublishPreview' -Passed $publishPreviewPassed -Detail $publishPreviewDetail))
}

$bundledIssueCommentPath = Join-Path $SupportBundlePath 'issue_comments'
$bundledIssueCommentManifestPath = Join-Path $bundledIssueCommentPath 'issue_comment_manifest.csv'
$bundledIssueCommentPostCommandsPath = Join-Path $bundledIssueCommentPath 'post_commands.txt'
$bundledIssueCommentPublishPreviewPath = Join-Path $bundledIssueCommentPath 'publish_preview.csv'
$requiredBundledIssueCommentFiles = @(
    'issue-1-lab-fixture-live-proof.md',
    'issue-3-scanner-live-proof.md',
    'issue-5-identity-group-live-proof.md',
    'issue-6-dashboard-live-proof.md',
    'issue_comment_manifest.csv',
    'post_commands.txt',
    'publish_preview.csv'
)
$missingBundledIssueCommentFiles = @($requiredBundledIssueCommentFiles | Where-Object { -not (Test-Path -LiteralPath (Join-Path $bundledIssueCommentPath $_)) })
$bundledIssueCommentsPassed = $false
$bundledIssueCommentDetail = ''
if ($missingBundledIssueCommentFiles.Count -eq 0 -and (Test-Path -LiteralPath $bundledIssueCommentManifestPath) -and (Test-Path -LiteralPath $bundledIssueCommentPostCommandsPath) -and (Test-Path -LiteralPath $bundledIssueCommentPublishPreviewPath)) {
    $bundledIssueCommentManifest = @(Import-Csv -LiteralPath $bundledIssueCommentManifestPath)
    $bundledManifestText = Get-Content -LiteralPath $bundledIssueCommentManifestPath -Raw
    $bundledPostCommandText = Get-Content -LiteralPath $bundledIssueCommentPostCommandsPath -Raw
    $bundledPublishPreviewRows = @(Import-Csv -LiteralPath $bundledIssueCommentPublishPreviewPath)
    $bundledPublishPreviewText = Get-Content -LiteralPath $bundledIssueCommentPublishPreviewPath -Raw
    $hasRawPathColumn = ($bundledManifestText -like '*OutputPath*')
    $hasRunRootLeak = ($bundledManifestText -like "*$RunRoot*" -or $bundledPostCommandText -like "*$RunRoot*" -or $bundledPublishPreviewText -like "*$RunRoot*")
    $hasRelativeBodyFiles = ($bundledPostCommandText -like '*--body-file "issue_comments/issue-1-lab-fixture-live-proof.md"*' -and $bundledPostCommandText -like '*--body-file "issue_comments/issue-6-dashboard-live-proof.md"*')
    $previewBodyFiles = @($bundledPublishPreviewRows | ForEach-Object { [string]$_.BodyFile })
    $hasRelativePublishBodyFiles = ($previewBodyFiles -contains 'issue_comments/issue-1-lab-fixture-live-proof.md' -and $previewBodyFiles -contains 'issue_comments/issue-6-dashboard-live-proof.md')
    $nonDryRunBundledPreviewRows = @($bundledPublishPreviewRows | Where-Object { [string]$_.Status -ne 'DryRun' })
    $diagnosticsIssueCommentCount = 0
    $diagnosticsIssueCommentsIncluded = $false
    $diagnosticsPublishPreviewIncluded = $false
    $diagnosticsPublishPreviewRowCount = 0
    if (Test-Path -LiteralPath $labRunDiagnosticsPath) {
        try {
            $diagnosticsForIssueComments = Get-Content -LiteralPath $labRunDiagnosticsPath -Raw | ConvertFrom-Json
            if ($diagnosticsForIssueComments.PSObject.Properties['IssueComments']) {
                $diagnosticsIssueCommentCount = [int]$diagnosticsForIssueComments.IssueComments.CommentCount
                $diagnosticsIssueCommentsIncluded = ([string]$diagnosticsForIssueComments.IssueComments.Included -eq 'True')
                $diagnosticsPublishPreviewIncluded = ([string]$diagnosticsForIssueComments.IssueComments.PublishPreviewIncluded -eq 'True')
                $diagnosticsPublishPreviewRowCount = [int]$diagnosticsForIssueComments.IssueComments.PublishPreviewRowCount
            }
        }
        catch {
            $diagnosticsIssueCommentCount = 0
            $diagnosticsIssueCommentsIncluded = $false
            $diagnosticsPublishPreviewIncluded = $false
            $diagnosticsPublishPreviewRowCount = 0
        }
    }
    $bundledIssueCommentsPassed = ($bundledIssueCommentManifest.Count -ge 4 -and $bundledPublishPreviewRows.Count -ge 4 -and $nonDryRunBundledPreviewRows.Count -eq 0 -and -not $hasRawPathColumn -and -not $hasRunRootLeak -and $hasRelativeBodyFiles -and $hasRelativePublishBodyFiles -and $diagnosticsIssueCommentsIncluded -and $diagnosticsIssueCommentCount -ge 4 -and $diagnosticsPublishPreviewIncluded -and $diagnosticsPublishPreviewRowCount -ge 4)
    $bundledIssueCommentDetail = 'BundledIssueCommentPath={0}; ManifestRows={1}; PublishPreviewRows={2}; Missing={3}; HasRawPathColumn={4}; HasRunRootLeak={5}; DiagnosticsCount={6}; DiagnosticsPublishPreviewRows={7}' -f $bundledIssueCommentPath, $bundledIssueCommentManifest.Count, $bundledPublishPreviewRows.Count, ($missingBundledIssueCommentFiles -join ', '), $hasRawPathColumn, $hasRunRootLeak, $diagnosticsIssueCommentCount, $diagnosticsPublishPreviewRowCount
}
else {
    $bundledIssueCommentDetail = 'BundledIssueCommentPath={0}; Missing={1}' -f $bundledIssueCommentPath, ($missingBundledIssueCommentFiles -join ', ')
}
if ($AllowMissingIssueComments -and $missingBundledIssueCommentFiles.Count -gt 0) {
    [void]$checks.Add((New-ShareSurferAcceptanceCheck -Name 'BundledValidationIssueComments' -Passed $true -Detail ('Bundled issue comments pending for staged acceptance: {0}' -f $bundledIssueCommentDetail)))
}
else {
    [void]$checks.Add((New-ShareSurferAcceptanceCheck -Name 'BundledValidationIssueComments' -Passed $bundledIssueCommentsPassed -Detail $bundledIssueCommentDetail))
}

$closeoutChecklistPassed = $false
$closeoutChecklistDetail = ''
if (Test-Path -LiteralPath $CloseoutChecklistPath) {
    $closeoutChecklistText = Get-Content -LiteralPath $CloseoutChecklistPath -Raw
    $hasTitle = ($closeoutChecklistText -like '*ShareSurfer live validation closeout checklist*')
    $hasReadyStatus = ($closeoutChecklistText -like '*Ready for proof review:*')
    $hasRunRootLeak = ($closeoutChecklistText -like "*$RunRoot*")
    $closeoutChecklistPassed = ($hasTitle -and $hasReadyStatus -and -not $hasRunRootLeak)
    $closeoutChecklistDetail = 'CloseoutChecklist={0}; HasTitle={1}; HasReadyStatus={2}; HasRunRootLeak={3}' -f $CloseoutChecklistPath, $hasTitle, $hasReadyStatus, $hasRunRootLeak
}
else {
    $closeoutChecklistDetail = 'Closeout checklist not found: {0}' -f $CloseoutChecklistPath
}
if ($AllowMissingIssueComments -and -not (Test-Path -LiteralPath $CloseoutChecklistPath)) {
    [void]$checks.Add((New-ShareSurferAcceptanceCheck -Name 'ValidationCloseoutChecklist' -Passed $true -Detail ('Closeout checklist pending for staged acceptance: {0}' -f $closeoutChecklistDetail)))
}
else {
    [void]$checks.Add((New-ShareSurferAcceptanceCheck -Name 'ValidationCloseoutChecklist' -Passed $closeoutChecklistPassed -Detail $closeoutChecklistDetail))
}

$bundledCloseoutChecklistPath = Join-Path $SupportBundlePath 'validation_closeout_checklist.md'
$bundledCloseoutChecklistPassed = $false
$bundledCloseoutChecklistDetail = ''
if (Test-Path -LiteralPath $bundledCloseoutChecklistPath) {
    $bundledCloseoutChecklistText = Get-Content -LiteralPath $bundledCloseoutChecklistPath -Raw
    $hasBundledTitle = ($bundledCloseoutChecklistText -like '*ShareSurfer live validation closeout checklist*')
    $hasBundledRunRootLeak = ($bundledCloseoutChecklistText -like "*$RunRoot*")
    $bundledCloseoutChecklistPassed = ($hasBundledTitle -and -not $hasBundledRunRootLeak)
    $bundledCloseoutChecklistDetail = 'BundledCloseoutChecklist={0}; HasTitle={1}; HasRunRootLeak={2}' -f $bundledCloseoutChecklistPath, $hasBundledTitle, $hasBundledRunRootLeak
}
else {
    $bundledCloseoutChecklistDetail = 'Bundled closeout checklist not found: {0}' -f $bundledCloseoutChecklistPath
}
if ($AllowMissingIssueComments -and -not (Test-Path -LiteralPath $bundledCloseoutChecklistPath)) {
    [void]$checks.Add((New-ShareSurferAcceptanceCheck -Name 'BundledValidationCloseoutChecklist' -Passed $true -Detail ('Bundled closeout checklist pending for staged acceptance: {0}' -f $bundledCloseoutChecklistDetail)))
}
else {
    [void]$checks.Add((New-ShareSurferAcceptanceCheck -Name 'BundledValidationCloseoutChecklist' -Passed $bundledCloseoutChecklistPassed -Detail $bundledCloseoutChecklistDetail))
}

if (Test-Path -LiteralPath $PreflightPath) {
    $preflightRows = @(Import-Csv -LiteralPath $PreflightPath)
    $failedRequiredPreflightRows = @($preflightRows | Where-Object { [string]$_.Required -eq 'True' -and [string]$_.Passed -ne 'True' })
    [void]$checks.Add((New-ShareSurferAcceptanceCheck -Name 'LabPreflight' -Passed ($preflightRows.Count -gt 0 -and $failedRequiredPreflightRows.Count -eq 0) -Detail ('PreflightRows={0}; FailedRequired={1}; Preflight={2}' -f $preflightRows.Count, $failedRequiredPreflightRows.Count, $PreflightPath)))
}
else {
    [void]$checks.Add((New-ShareSurferAcceptanceCheck -Name 'LabPreflight' -Passed $false -Detail ('Preflight file not found: {0}' -f $PreflightPath)))
}

if (Test-Path -LiteralPath $CriteriaPath) {
    $criteriaRows = @(Import-Csv -LiteralPath $CriteriaPath)
    $failedRequiredCriteria = @($criteriaRows | Where-Object { [string]$_.Required -eq 'True' -and [string]$_.Passed -ne 'True' })
    [void]$checks.Add((New-ShareSurferAcceptanceCheck -Name 'LabValidationCriteria' -Passed ($failedRequiredCriteria.Count -eq 0 -and $criteriaRows.Count -gt 0) -Detail ('CriteriaRows={0}; FailedRequired={1}' -f $criteriaRows.Count, $failedRequiredCriteria.Count)))
}
else {
    [void]$checks.Add((New-ShareSurferAcceptanceCheck -Name 'LabValidationCriteria' -Passed $false -Detail ('Criteria file not found: {0}' -f $CriteriaPath)))
}

if (Test-Path -LiteralPath $LiveEvidenceReviewPath) {
    $reviewRows = @(Import-Csv -LiteralPath $LiveEvidenceReviewPath)
    $blockingStatuses = @('Failed', 'MissingEvidenceSource', 'PlanOnly', 'EvidenceUnavailable')
    $blockingRows = @($reviewRows | Where-Object { [string]$_.Required -eq 'True' -and $blockingStatuses -contains [string]$_.EvidenceStatus })
    $reviewPassed = ($reviewRows.Count -gt 0 -and ((-not $RequireLiveEvidence) -or $blockingRows.Count -eq 0))
    [void]$checks.Add((New-ShareSurferAcceptanceCheck -Name 'LiveEvidenceReview' -Passed $reviewPassed -Detail ('ReviewRows={0}; BlockingRows={1}; Review={2}' -f $reviewRows.Count, $blockingRows.Count, $LiveEvidenceReviewPath)))
}
else {
    [void]$checks.Add((New-ShareSurferAcceptanceCheck -Name 'LiveEvidenceReview' -Passed $false -Detail ('Live evidence review file not found: {0}' -f $LiveEvidenceReviewPath)))
}

if ($RequireLiveEvidence) {
    if (Test-Path -LiteralPath $LiveEvidencePath) {
        $liveEvidence = Get-Content -LiteralPath $LiveEvidencePath -Raw | ConvertFrom-Json
        $fallbackCount = 0
        if ($null -ne $liveEvidence.PSObject.Properties['FallbackCount']) {
            $fallbackCount = [int]$liveEvidence.FallbackCount
        }
        $liveEvidencePassed = ([string]$liveEvidence.IsValid -eq 'True' -and $fallbackCount -eq 0)
        [void]$checks.Add((New-ShareSurferAcceptanceCheck -Name 'LiveEvidenceGate' -Passed $liveEvidencePassed -Detail ('LiveEvidenceIsValid={0}; FallbackCount={1}' -f $liveEvidence.IsValid, $fallbackCount)))
    }
    else {
        [void]$checks.Add((New-ShareSurferAcceptanceCheck -Name 'LiveEvidenceGate' -Passed $false -Detail ('Live evidence file not found: {0}' -f $LiveEvidencePath)))
    }
}
else {
    [void]$checks.Add((New-ShareSurferAcceptanceCheck -Name 'LiveEvidenceGate' -Passed $true -Detail 'Live evidence was not required for this acceptance run.'))
}

$failedChecks = @($checks | Where-Object { -not $_.Passed })
$result = [pscustomobject]@{
    IsValid = ($failedChecks.Count -eq 0)
    RunRoot = $RunRoot
    ExportPath = $ExportPath
    ReportPath = $ReportPath
    DashboardReviewPath = $DashboardReviewPath
    SupportBundlePath = $SupportBundlePath
    PreflightPath = $PreflightPath
    CriteriaPath = $CriteriaPath
    LiveEvidencePath = $LiveEvidencePath
    LiveEvidenceReviewPath = $LiveEvidenceReviewPath
    RequireLiveEvidence = [bool]$RequireLiveEvidence
    FailedCheckCount = $failedChecks.Count
    Checks = @($checks)
}

if (-not [string]::IsNullOrWhiteSpace($SummaryPath)) {
    $summaryDirectory = Split-Path -Parent $SummaryPath
    if (-not [string]::IsNullOrWhiteSpace($summaryDirectory)) {
        New-Item -ItemType Directory -Path $summaryDirectory -Force | Out-Null
    }
    New-ShareSurferAcceptanceSummary -AcceptanceResult $result | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $SummaryPath -Encoding UTF8
}

$result
