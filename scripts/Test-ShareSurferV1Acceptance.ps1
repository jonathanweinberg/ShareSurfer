[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $RunRoot,

    [string] $ExportPath = '',
    [string] $ReportPath = '',
    [string] $SupportBundlePath = '',
    [string] $PreflightPath = '',
    [string] $CriteriaPath = '',
    [string] $LiveEvidencePath = '',
    [string] $LiveEvidenceReviewPath = '',
    [string] $SummaryPath = '',

    [switch] $AllowMissingBundledAcceptance,

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

$requiredBundleFiles = @(
    'support_bundle_manifest.csv',
    'support_bundle_files.csv',
    'support_bundle_summary.json',
    'support_bundle_diagnostics.json',
    'support_bundle_redaction_audit.csv',
    'scan_events.jsonl',
    'report.html',
    'lab_run_diagnostics.json',
    'lab_run_events.jsonl',
    'lab_preflight.csv',
    'lab_validation_criteria.csv',
    'live_evidence_review.csv',
    'live_evidence.json',
    'v1_acceptance.json'
)
if ($AllowMissingBundledAcceptance) {
    $requiredBundleFiles = @($requiredBundleFiles | Where-Object { $_ -ne 'v1_acceptance.json' })
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
