[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $RunRoot,

    [string] $ExportPath = '',
    [string] $ReportPath = '',
    [string] $SupportBundlePath = '',
    [string] $CriteriaPath = '',
    [string] $LiveEvidencePath = '',

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
if ($CriteriaPath -eq '') {
    $CriteriaPath = Join-Path $RunRoot 'lab-validation-criteria.csv'
}
if ($LiveEvidencePath -eq '') {
    $LiveEvidencePath = Join-Path $RunRoot 'live-evidence.json'
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

$rawEventLogPath = Join-Path $ExportPath 'scan_events.jsonl'
$rawEventLogPassed = (Test-Path -LiteralPath $rawEventLogPath) -and ((Get-Item -LiteralPath $rawEventLogPath).Length -gt 0)
[void]$checks.Add((New-ShareSurferAcceptanceCheck -Name 'RawEventLog' -Passed $rawEventLogPassed -Detail ('Raw event log: {0}' -f $rawEventLogPath)))

$reportPassed = (Test-Path -LiteralPath $ReportPath) -and ((Get-Item -LiteralPath $ReportPath).Length -gt 0)
[void]$checks.Add((New-ShareSurferAcceptanceCheck -Name 'OfflineReport' -Passed $reportPassed -Detail ('Report: {0}' -f $ReportPath)))

$requiredBundleFiles = @(
    'support_bundle_manifest.csv',
    'support_bundle_files.csv',
    'support_bundle_redaction_audit.csv',
    'scan_events.jsonl',
    'report.html'
)
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

if (Test-Path -LiteralPath $CriteriaPath) {
    $criteriaRows = @(Import-Csv -LiteralPath $CriteriaPath)
    $failedRequiredCriteria = @($criteriaRows | Where-Object { [string]$_.Required -eq 'True' -and [string]$_.Passed -ne 'True' })
    [void]$checks.Add((New-ShareSurferAcceptanceCheck -Name 'LabValidationCriteria' -Passed ($failedRequiredCriteria.Count -eq 0 -and $criteriaRows.Count -gt 0) -Detail ('CriteriaRows={0}; FailedRequired={1}' -f $criteriaRows.Count, $failedRequiredCriteria.Count)))
}
else {
    [void]$checks.Add((New-ShareSurferAcceptanceCheck -Name 'LabValidationCriteria' -Passed $false -Detail ('Criteria file not found: {0}' -f $CriteriaPath)))
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
[pscustomobject]@{
    IsValid = ($failedChecks.Count -eq 0)
    RunRoot = $RunRoot
    ExportPath = $ExportPath
    ReportPath = $ReportPath
    SupportBundlePath = $SupportBundlePath
    CriteriaPath = $CriteriaPath
    LiveEvidencePath = $LiveEvidencePath
    RequireLiveEvidence = [bool]$RequireLiveEvidence
    FailedCheckCount = $failedChecks.Count
    Checks = @($checks)
}
