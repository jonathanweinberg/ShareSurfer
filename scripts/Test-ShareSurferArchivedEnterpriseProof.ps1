[CmdletBinding()]
param(
    [string] $RunRoot = '',

    [string] $OutputPath = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$modulePath = Join-Path (Join-Path (Join-Path $repoRoot 'src') 'ShareSurfer') 'ShareSurfer.psd1'
$refreshScriptPath = Join-Path $PSScriptRoot 'New-ShareSurferArchivedEvidenceRefresh.ps1'

if ([string]::IsNullOrWhiteSpace($RunRoot)) {
    $RunRoot = Join-Path $repoRoot 'docs/lab-evidence/windows-ad-enterprise-20260605-101639/20260605-101639'
}
else {
    $RunRoot = [System.IO.Path]::GetFullPath($RunRoot)
}

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferArchivedEnterpriseProof-' + [guid]::NewGuid().ToString('N'))
}
else {
    $OutputPath = [System.IO.Path]::GetFullPath($OutputPath)
}

foreach ($requiredPath in @($modulePath, $refreshScriptPath, $RunRoot)) {
    if (-not (Test-Path -LiteralPath $requiredPath)) {
        throw ('Required path was not found: {0}' -f $requiredPath)
    }
}

Import-Module $modulePath -Force -ErrorAction Stop

$refreshResult = & $refreshScriptPath `
    -RunRoot $RunRoot `
    -OutputPath $OutputPath `
    -RequireLiveEvidence `
    -AllowMissingSupportBundle `
    -AllowMissingIssueComments

if ($null -eq $refreshResult) {
    throw 'Archived enterprise proof refresh did not return a result.'
}

$exportPath = Join-Path ([string]$refreshResult.OutputPath) 'export'
$exportValidation = Test-ShareSurferExport -ExportPath $exportPath
$missingFiles = @($exportValidation.MissingFiles | ForEach-Object { [string]$_ })
$schemaErrorCount = @($exportValidation.SchemaErrors).Count

$result = [pscustomobject][ordered]@{
    IsValid = ([bool]$exportValidation.IsValid -and [bool]$refreshResult.AcceptanceIsValid -and [bool]$refreshResult.LiveEvidenceIsValid)
    OutputPath = [string]$refreshResult.OutputPath
    ExportPath = [string]$exportValidation.ExportPath
    AcceptanceIsValid = [bool]$refreshResult.AcceptanceIsValid
    AcceptanceFailedCheckCount = [int]$refreshResult.AcceptanceFailedCheckCount
    LiveEvidenceIsValid = [bool]$refreshResult.LiveEvidenceIsValid
    LiveEvidenceFallbackCount = [int]$refreshResult.LiveEvidenceFallbackCount
    MissingFiles = @($missingFiles)
    SchemaErrorCount = [int]$schemaErrorCount
}

if (-not [bool]$result.IsValid) {
    $failureParts = @(
        ('AcceptanceIsValid={0}' -f [bool]$result.AcceptanceIsValid),
        ('AcceptanceFailedCheckCount={0}' -f [int]$result.AcceptanceFailedCheckCount),
        ('LiveEvidenceIsValid={0}' -f [bool]$result.LiveEvidenceIsValid),
        ('LiveEvidenceFallbackCount={0}' -f [int]$result.LiveEvidenceFallbackCount),
        ('MissingFiles={0}' -f (@($result.MissingFiles) -join ',')),
        ('SchemaErrorCount={0}' -f [int]$result.SchemaErrorCount),
        ('OutputPath={0}' -f [string]$result.OutputPath),
        ('ExportPath={0}' -f [string]$result.ExportPath)
    )
    throw ('Archived enterprise proof is invalid against the current verifier: {0}' -f ($failureParts -join '; '))
}

$result
