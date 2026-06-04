[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string] $LabRoot = 'C:\ShareSurferLab',
    [string] $OutputRoot = 'C:\ShareSurfer\lab-validation',
    [string] $DomainNetBiosName = $env:USERDOMAIN,
    [string] $ObsAttribute = 'extensionAttribute10',
    [switch] $CreateLab,
    [switch] $IncludeFiles
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$modulePath = Join-Path $repoRoot 'src\ShareSurfer\ShareSurfer.psd1'
Import-Module $modulePath -Force -ErrorAction Stop

if ([string]::IsNullOrWhiteSpace($DomainNetBiosName)) {
    $DomainNetBiosName = 'CONTOSO'
}

$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$runRoot = Join-Path $OutputRoot $timestamp
$exportPath = Join-Path $runRoot 'export'
$reportPath = Join-Path $runRoot 'report.html'
$bundlePath = Join-Path $runRoot 'support-bundle-redacted'

New-Item -ItemType Directory -Path $runRoot -Force | Out-Null

$plan = New-ShareSurferLabFixture -OutputPlanOnly -RootPath $LabRoot -DomainNetBiosName $DomainNetBiosName -ObsAttribute $ObsAttribute
$plan | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $runRoot 'lab-plan.json') -Encoding UTF8

if ($CreateLab) {
    if ($PSCmdlet.ShouldProcess($LabRoot, 'Create or update ShareSurfer Windows/AD lab fixtures')) {
        New-ShareSurferLabFixture -RootPath $LabRoot -DomainNetBiosName $DomainNetBiosName -ObsAttribute $ObsAttribute -Force | Out-Null
    }
}

$shareNames = @($plan.Shares | ForEach-Object { $_.ShareName })
Invoke-ShareSurferScan -ComputerName $env:COMPUTERNAME -ShareName $shareNames -OutputPath $exportPath -ObsAttribute $ObsAttribute -IncludeFiles:$IncludeFiles | Out-Null

$validation = Test-ShareSurferExport -ExportPath $exportPath
$validation | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $runRoot 'validation.json') -Encoding UTF8
if (-not $validation.IsValid) {
    throw ('ShareSurfer export validation failed. See {0}' -f (Join-Path $runRoot 'validation.json'))
}

ConvertTo-ShareSurferReport -ExportPath $exportPath -OutputPath $reportPath | Out-Null
New-ShareSurferSupportBundle -ExportPath $exportPath -OutputPath $bundlePath -RedactionMode StableToken | Out-Null

[pscustomobject]@{
    RunRoot = $runRoot
    ExportPath = $exportPath
    ReportPath = $reportPath
    SupportBundlePath = $bundlePath
    ValidationPath = Join-Path $runRoot 'validation.json'
    LabCreated = [bool]$CreateLab
    ShareCount = @($plan.Shares).Count
}
