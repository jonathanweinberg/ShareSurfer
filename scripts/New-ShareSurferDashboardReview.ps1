[CmdletBinding()]
param(
    [string] $RunRoot = '',

    [string] $ExportPath = '',

    [string] $ReportPath = '',

    [string] $OutputPath = '',

    [switch] $PassThru
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($RunRoot)) {
    $RunRoot = (Get-Location).Path
}
if ([string]::IsNullOrWhiteSpace($ExportPath)) {
    $ExportPath = Join-Path $RunRoot 'export'
}
if ([string]::IsNullOrWhiteSpace($ReportPath)) {
    $ReportPath = Join-Path $RunRoot 'report.html'
}
if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path $RunRoot 'dashboard-review.md'
}

function Add-ShareSurferDashboardReviewLine {
    param(
        [System.Collections.ArrayList] $Lines,
        [string] $Text = ''
    )

    [void]$Lines.Add($Text)
}

function Get-ShareSurferDashboardReviewCsvCount {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return 0
    }

    @(Import-Csv -LiteralPath $Path).Count
}

$reportContent = ''
if (Test-Path -LiteralPath $ReportPath) {
    $reportContent = Get-Content -LiteralPath $ReportPath -Raw
}

$markers = @(
    [pscustomobject]@{ Name = 'Dashboard title'; Marker = 'ShareSurfer Business Review Dashboard' },
    [pscustomobject]@{ Name = 'Dashboard filters'; Marker = 'Dashboard Filters' },
    [pscustomobject]@{ Name = 'Embedded report data'; Marker = 'sharesurfer-data' },
    [pscustomobject]@{ Name = 'Owner review queue'; Marker = 'owner-review-queue' },
    [pscustomobject]@{ Name = 'Migration discovery'; Marker = 'migration-areas' },
    [pscustomobject]@{ Name = 'Access model'; Marker = 'access-model' },
    [pscustomobject]@{ Name = 'Group browser'; Marker = 'group-browser' },
    [pscustomobject]@{ Name = 'Diagnostics'; Marker = 'Collection Error Drilldown' },
    [pscustomobject]@{ Name = 'Raw evidence tables'; Marker = 'raw-dataset' }
)

$markerRows = foreach ($marker in @($markers)) {
    [pscustomobject]@{
        Name = [string]$marker.Name
        Present = ([string]$reportContent -like ('*{0}*' -f [string]$marker.Marker))
    }
}

$counts = [ordered]@{
    Shares = Get-ShareSurferDashboardReviewCsvCount -Path (Join-Path $ExportPath 'shares.csv')
    Items = Get-ShareSurferDashboardReviewCsvCount -Path (Join-Path $ExportPath 'items.csv')
    Findings = Get-ShareSurferDashboardReviewCsvCount -Path (Join-Path $ExportPath 'findings.csv')
    Conflicts = Get-ShareSurferDashboardReviewCsvCount -Path (Join-Path $ExportPath 'conflicts.csv')
    OwnerRiskPivots = Get-ShareSurferDashboardReviewCsvCount -Path (Join-Path $ExportPath 'owner_risk_pivots.csv')
    RelatedDataAreas = Get-ShareSurferDashboardReviewCsvCount -Path (Join-Path $ExportPath 'related_data_areas.csv')
    OwnerReviewPackets = Get-ShareSurferDashboardReviewCsvCount -Path (Join-Path $ExportPath 'owner_review_packets.csv')
    GroupEdges = Get-ShareSurferDashboardReviewCsvCount -Path (Join-Path $ExportPath 'group_edges.csv')
    CollectionErrors = Get-ShareSurferDashboardReviewCsvCount -Path (Join-Path $ExportPath 'collection_errors.csv')
}

$missingMarkers = @($markerRows | Where-Object { -not $_.Present })
$status = if (
    $missingMarkers.Count -eq 0 -and
    [int]$counts.Shares -gt 0 -and
    [int]$counts.Items -gt 0 -and
    [int]$counts.OwnerReviewPackets -gt 0 -and
    [int]$counts.RelatedDataAreas -gt 0
) { 'Pass' } else { 'Needs review' }

$lines = New-Object System.Collections.ArrayList
Add-ShareSurferDashboardReviewLine -Lines $lines -Text '# ShareSurfer Dashboard Review'
Add-ShareSurferDashboardReviewLine -Lines $lines
Add-ShareSurferDashboardReviewLine -Lines $lines -Text ('Generated at: `{0}`' -f (Get-Date).ToUniversalTime().ToString('o'))
Add-ShareSurferDashboardReviewLine -Lines $lines -Text 'Report file: `report.html`'
Add-ShareSurferDashboardReviewLine -Lines $lines -Text ('Dashboard review status: {0}' -f $status)
Add-ShareSurferDashboardReviewLine -Lines $lines
Add-ShareSurferDashboardReviewLine -Lines $lines -Text '## Automated Dashboard Checks'
Add-ShareSurferDashboardReviewLine -Lines $lines
Add-ShareSurferDashboardReviewLine -Lines $lines -Text '| Check | Status |'
Add-ShareSurferDashboardReviewLine -Lines $lines -Text '| --- | --- |'
foreach ($row in @($markerRows)) {
    $rowStatus = if ([bool]$row.Present) { 'Present' } else { 'Missing' }
    Add-ShareSurferDashboardReviewLine -Lines $lines -Text ('| {0} | `{1}` |' -f [string]$row.Name, $rowStatus)
}

Add-ShareSurferDashboardReviewLine -Lines $lines
Add-ShareSurferDashboardReviewLine -Lines $lines -Text '## Evidence Counts'
Add-ShareSurferDashboardReviewLine -Lines $lines
Add-ShareSurferDashboardReviewLine -Lines $lines -Text '| Evidence | Rows |'
Add-ShareSurferDashboardReviewLine -Lines $lines -Text '| --- | ---: |'
foreach ($key in @($counts.Keys)) {
    Add-ShareSurferDashboardReviewLine -Lines $lines -Text ('| {0} | `{1}` |' -f $key, [int]$counts[$key])
}

Add-ShareSurferDashboardReviewLine -Lines $lines
Add-ShareSurferDashboardReviewLine -Lines $lines -Text '## Operator Live Review'
Add-ShareSurferDashboardReviewLine -Lines $lines
Add-ShareSurferDashboardReviewLine -Lines $lines -Text '- Open `report.html` from the completed run folder on the lab workstation.'
Add-ShareSurferDashboardReviewLine -Lines $lines -Text '- Confirm the overview, review queue, owner workbench, migration discovery, access model, group browser, diagnostics, and raw evidence views render and respond to filters.'
Add-ShareSurferDashboardReviewLine -Lines $lines -Text '- Confirm the dashboard is readable with the enterprise-scale CSV output before posting issue #6 proof.'
Add-ShareSurferDashboardReviewLine -Lines $lines -Text '- This review file contains counts and marker status only; it intentionally avoids raw paths, identities, employee identifiers, and manager chains.'

$outputDirectory = Split-Path -Parent $OutputPath
if (-not [string]::IsNullOrWhiteSpace($outputDirectory)) {
    New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
}
Set-Content -LiteralPath $OutputPath -Value $lines -Encoding UTF8

$result = [pscustomobject]@{
    OutputPath = $OutputPath
    ReportFile = 'report.html'
    Status = $status
    MissingMarkerCount = $missingMarkers.Count
    Shares = [int]$counts.Shares
    Items = [int]$counts.Items
    OwnerReviewPackets = [int]$counts.OwnerReviewPackets
    RelatedDataAreas = [int]$counts.RelatedDataAreas
}

if ($PassThru) {
    $result
}
