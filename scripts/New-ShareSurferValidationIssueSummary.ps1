[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $RunRoot,

    [string] $OutputPath = '',

    [switch] $PassThru
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function ConvertTo-ShareSurferSummaryBool {
    param($Value)

    if ($null -eq $Value) {
        return $false
    }

    $text = [string]$Value
    return ($text -eq 'True' -or $text -eq 'true' -or $text -eq '1')
}

function Get-ShareSurferSummaryJson {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return $null
    }

    Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

function Get-ShareSurferSummaryCsv {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return @()
    }

    @(Import-Csv -LiteralPath $Path)
}

function Join-ShareSurferSummaryNames {
    param($Rows)

    $names = @($Rows | ForEach-Object {
            if ($null -ne $_.PSObject.Properties['Name']) {
                [string]$_.Name
            }
        } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique)

    if ($names.Count -eq 0) {
        return 'None'
    }

    $names -join ', '
}

function Add-ShareSurferMarkdownLine {
    param(
        [System.Collections.ArrayList] $Lines,

        [string] $Text = ''
    )

    [void]$Lines.Add($Text)
}

if (-not (Test-Path -LiteralPath $RunRoot)) {
    throw ('Run root not found: {0}' -f $RunRoot)
}

$acceptanceSummary = Get-ShareSurferSummaryJson -Path (Join-Path $RunRoot 'v1-acceptance-summary.json')
$liveEvidence = Get-ShareSurferSummaryJson -Path (Join-Path $RunRoot 'live-evidence.json')
$liveEvidenceReview = @(Get-ShareSurferSummaryCsv -Path (Join-Path $RunRoot 'live-evidence-review.csv'))
$criteriaRows = @(Get-ShareSurferSummaryCsv -Path (Join-Path $RunRoot 'lab-validation-criteria.csv'))
$supportBundlePath = Join-Path $RunRoot 'support-bundle-redacted'
$bundleManifestRows = @(Get-ShareSurferSummaryCsv -Path (Join-Path $supportBundlePath 'support_bundle_manifest.csv'))

$acceptanceValid = $false
$acceptanceFailedCount = 0
$acceptanceFailedNames = @()
if ($null -ne $acceptanceSummary) {
    $acceptanceValid = ConvertTo-ShareSurferSummaryBool $acceptanceSummary.IsValid
    if ($null -ne $acceptanceSummary.PSObject.Properties['FailedCheckCount']) {
        $acceptanceFailedCount = [int]$acceptanceSummary.FailedCheckCount
    }
    $acceptanceFailedNames = @($acceptanceSummary.FailedChecks | ForEach-Object { [string]$_ } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
}

$liveEvidenceValid = $false
$fallbackCount = 0
if ($null -ne $liveEvidence) {
    $liveEvidenceValid = ConvertTo-ShareSurferSummaryBool $liveEvidence.IsValid
    if ($null -ne $liveEvidence.PSObject.Properties['FallbackCount']) {
        $fallbackCount = [int]$liveEvidence.FallbackCount
    }
}

$blockingStatuses = @('Failed', 'MissingEvidenceSource', 'PlanOnly', 'EvidenceUnavailable')
$blockingReviewRows = @($liveEvidenceReview | Where-Object { [string]$_.Required -eq 'True' -and $blockingStatuses -contains [string]$_.EvidenceStatus })
$failedCriteriaRows = @($criteriaRows | Where-Object { [string]$_.Required -eq 'True' -and [string]$_.Passed -ne 'True' })

$bundleValidation = 'Missing'
$bundleLeakCount = 'Unknown'
if ($bundleManifestRows.Count -gt 0) {
    $bundleValidation = [string]$bundleManifestRows[0].ValidationIsValid
    $bundleLeakCount = [string]$bundleManifestRows[0].RedactionLeakCount
}

$lines = New-Object System.Collections.ArrayList
$failedCheckLabel = if ($acceptanceFailedNames.Count -eq 0) { 'None' } else { $acceptanceFailedNames -join ', ' }
Add-ShareSurferMarkdownLine -Lines $lines -Text 'ShareSurfer live validation evidence summary.'
Add-ShareSurferMarkdownLine -Lines $lines
Add-ShareSurferMarkdownLine -Lines $lines -Text '**Acceptance Status**'
Add-ShareSurferMarkdownLine -Lines $lines -Text ('- V1 acceptance valid: `{0}`' -f $acceptanceValid)
Add-ShareSurferMarkdownLine -Lines $lines -Text ('- Failed acceptance checks: `{0}`' -f $acceptanceFailedCount)
Add-ShareSurferMarkdownLine -Lines $lines -Text ('- Failed check names: `{0}`' -f $failedCheckLabel)
Add-ShareSurferMarkdownLine -Lines $lines
Add-ShareSurferMarkdownLine -Lines $lines -Text '**Live Evidence Gate**'
Add-ShareSurferMarkdownLine -Lines $lines -Text ('- Live evidence valid: `{0}`' -f $liveEvidenceValid)
Add-ShareSurferMarkdownLine -Lines $lines -Text ('- Fallback criteria count: `{0}`' -f $fallbackCount)
Add-ShareSurferMarkdownLine -Lines $lines -Text ('- Blocking review rows: `{0}`' -f $blockingReviewRows.Count)
Add-ShareSurferMarkdownLine -Lines $lines -Text ('- Blocking review criteria: `{0}`' -f (Join-ShareSurferSummaryNames -Rows $blockingReviewRows))
Add-ShareSurferMarkdownLine -Lines $lines
Add-ShareSurferMarkdownLine -Lines $lines -Text '**Validation Criteria**'
Add-ShareSurferMarkdownLine -Lines $lines -Text ('- Failed required criteria: `{0}`' -f $failedCriteriaRows.Count)
Add-ShareSurferMarkdownLine -Lines $lines -Text ('- Failed criteria names: `{0}`' -f (Join-ShareSurferSummaryNames -Rows $failedCriteriaRows))
Add-ShareSurferMarkdownLine -Lines $lines
Add-ShareSurferMarkdownLine -Lines $lines -Text '**Redacted Support Bundle**'
Add-ShareSurferMarkdownLine -Lines $lines -Text ('- Bundle validation status: `{0}`' -f $bundleValidation)
Add-ShareSurferMarkdownLine -Lines $lines -Text ('- Redaction leak count: `{0}`' -f $bundleLeakCount)
Add-ShareSurferMarkdownLine -Lines $lines
Add-ShareSurferMarkdownLine -Lines $lines -Text '**Issue Targets**'
Add-ShareSurferMarkdownLine -Lines $lines -Text '- Update issue #1 with lab creation and enterprise fixture proof.'
Add-ShareSurferMarkdownLine -Lines $lines -Text '- Update issue #3 with scanner/share/ACL/inheritance proof.'
Add-ShareSurferMarkdownLine -Lines $lines -Text '- Update issue #5 with identity enrichment and group expansion proof.'
Add-ShareSurferMarkdownLine -Lines $lines -Text '- Update issue #6 with dashboard usability proof at enterprise scale.'
Add-ShareSurferMarkdownLine -Lines $lines
Add-ShareSurferMarkdownLine -Lines $lines -Text '**Safe Sharing Note**'
Add-ShareSurferMarkdownLine -Lines $lines -Text '- This summary intentionally omits raw run paths, raw identities, employee identifiers, manager chains, and evidence detail values.'

$markdown = $lines -join [Environment]::NewLine

if (-not [string]::IsNullOrWhiteSpace($OutputPath)) {
    $outputDirectory = Split-Path -Parent $OutputPath
    if (-not [string]::IsNullOrWhiteSpace($outputDirectory)) {
        New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
    }
    Set-Content -LiteralPath $OutputPath -Value $markdown -Encoding UTF8
}

if ($PassThru -or [string]::IsNullOrWhiteSpace($OutputPath)) {
    $markdown
}
