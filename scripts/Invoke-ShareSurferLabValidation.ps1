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
    [int64] $MaxLabBytes = 8589934592,
    [switch] $CreateLab,
    [switch] $IncludeFiles,
    [switch] $RequireLiveEvidence
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

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
$bundlePath = Join-Path $runRoot 'support-bundle-redacted'
$criteriaPath = Join-Path $runRoot 'lab-validation-criteria.csv'
$liveEvidencePath = Join-Path $runRoot 'live-evidence.json'
$acceptancePath = Join-Path $runRoot 'v1-acceptance.json'

New-Item -ItemType Directory -Path $runRoot -Force | Out-Null

$plan = New-ShareSurferLabFixture -OutputPlanOnly -RootPath $LabRoot -DomainNetBiosName $DomainNetBiosName -ObsAttribute $ObsAttribute -Scale $Scale -EnterpriseUserCount $EnterpriseUserCount -EnterpriseShareCount $EnterpriseShareCount -EnterpriseFilesPerShare $EnterpriseFilesPerShare -MaxLabBytes $MaxLabBytes
$plan | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $runRoot 'lab-plan.json') -Encoding UTF8

if ($CreateLab) {
    if ($PSCmdlet.ShouldProcess($LabRoot, 'Create or update ShareSurfer Windows/AD lab fixtures')) {
        New-ShareSurferLabFixture -RootPath $LabRoot -DomainNetBiosName $DomainNetBiosName -ObsAttribute $ObsAttribute -Scale $Scale -EnterpriseUserCount $EnterpriseUserCount -EnterpriseShareCount $EnterpriseShareCount -EnterpriseFilesPerShare $EnterpriseFilesPerShare -MaxLabBytes $MaxLabBytes -Force | Out-Null
    }
}

$shareNames = @($plan.Shares | ForEach-Object { $_.ShareName })
Invoke-ShareSurferScan -ComputerName $env:COMPUTERNAME -ShareName $shareNames -OutputPath $exportPath -ObsAttribute $ObsAttribute -IncludeFiles:$IncludeFiles | Out-Null

$validation = Test-ShareSurferExport -ExportPath $exportPath
$validation | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $runRoot 'validation.json') -Encoding UTF8
if (-not $validation.IsValid) {
    throw ('ShareSurfer export validation failed. See {0}' -f (Join-Path $runRoot 'validation.json'))
}

$criteriaRows = @(New-ShareSurferLabValidationCriteriaRows -Plan $plan -ExportPath $exportPath -LabRoot $LabRoot -CreateLab:$CreateLab -IncludeFiles:$IncludeFiles)
@($criteriaRows) | Export-Csv -LiteralPath $criteriaPath -NoTypeInformation -Encoding UTF8
$liveEvidence = Test-ShareSurferLabValidationLiveEvidence -CriteriaRows $criteriaRows
$liveEvidence | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $liveEvidencePath -Encoding UTF8
$failedRequiredCriteria = @($criteriaRows | Where-Object { $_.Required -and -not $_.Passed })
if ($failedRequiredCriteria.Count -gt 0) {
    throw ('ShareSurfer lab validation criteria failed. See {0}' -f $criteriaPath)
}
if ($RequireLiveEvidence -and -not $liveEvidence.IsValid) {
    throw ('ShareSurfer live lab evidence validation failed. See {0}' -f $liveEvidencePath)
}

ConvertTo-ShareSurferReport -ExportPath $exportPath -OutputPath $reportPath | Out-Null
New-ShareSurferSupportBundle -ExportPath $exportPath -OutputPath $bundlePath -RedactionMode StableToken -IncludeReport | Out-Null
$acceptanceScriptPath = Join-Path $PSScriptRoot 'Test-ShareSurferV1Acceptance.ps1'
$acceptance = & $acceptanceScriptPath -RunRoot $runRoot -RequireLiveEvidence:$RequireLiveEvidence
$acceptance | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $acceptancePath -Encoding UTF8
if (-not $acceptance.IsValid) {
    throw ('ShareSurfer V1 acceptance validation failed. See {0}' -f $acceptancePath)
}

[pscustomobject]@{
    RunRoot = $runRoot
    ExportPath = $exportPath
    ReportPath = $reportPath
    SupportBundlePath = $bundlePath
    ValidationPath = Join-Path $runRoot 'validation.json'
    CriteriaPath = $criteriaPath
    LiveEvidencePath = $liveEvidencePath
    AcceptancePath = $acceptancePath
    AcceptanceIsValid = [bool]$acceptance.IsValid
    AcceptanceFailedCheckCount = [int]$acceptance.FailedCheckCount
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
