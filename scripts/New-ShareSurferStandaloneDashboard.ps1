[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $ExportPath,

    [Parameter(Mandatory = $true)]
    [string] $OutputPath,

    [string] $DashboardBuildPath = '',

    [switch] $Force,

    [switch] $PassThru
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function New-ShareSurferStandaloneSchema {
    [ordered]@{
        'shares.csv' = @('ShareId', 'Source', 'ComputerName', 'ShareName', 'UNCPath', 'LocalPath', 'Description', 'PartialData', 'PartialReason')
        'items.csv' = @('ItemId', 'ShareId', 'ItemType', 'FullPath', 'RelativePath', 'Depth', 'Owner', 'InheritanceEnabled', 'InheritanceBrokenAt')
        'share_permissions.csv' = @('ShareId', 'Identity', 'Rights', 'AccessControlType', 'Source')
        'acl_entries.csv' = @('ItemId', 'ShareId', 'FullPath', 'Identity', 'Rights', 'AccessControlType', 'IsInherited', 'InheritanceFlags', 'PropagationFlags', 'Depth')
        'identities.csv' = @('Identity', 'SamAccountName', 'DisplayName', 'ObjectClass', 'EmployeeId', 'EmployeeNumber', 'UserPrincipalName', 'Mail', 'Department', 'Title', 'Company', 'Office', 'AccountEnabled', 'Manager', 'ManagerLevel1', 'ManagerLevel2', 'ManagerLevel3', 'ObsPath', 'ObsAttribute', 'PotentialServiceAccount', 'DistinguishedName')
        'group_edges.csv' = @('ParentGroup', 'ChildIdentity', 'ChildObjectClass', 'Depth', 'IsCycle', 'IsTruncated')
        'discounted_principals.csv' = @('Identity', 'Reason', 'Scope', 'MatchType')
        'permissioned_groups.csv' = @('Group', 'DisplayName', 'ObjectClass', 'ObsPath', 'ManagerLevel1', 'ShareAssignments', 'NtfsAssignments', 'ExpandedMembers', 'MaxDepth', 'HasCycle', 'IsTruncated', 'Rights', 'ShareId', 'ShareIds', 'Sources', 'FullPath', 'ExamplePath', 'DiscountedPrincipal', 'DiscountReason', 'DiscountScope')
        'org_chains.csv' = @('Identity', 'EmployeeId', 'EmployeeNumber', 'Department', 'Title', 'Company', 'Office', 'ManagerLevel1', 'ManagerLevel2', 'ManagerLevel3', 'ObsPath', 'ObsAttribute', 'PotentialServiceAccount')
        'owner_mappings.csv' = @('Pattern', 'Owner', 'BusinessUnit', 'Source')
        'owner_risk_pivots.csv' = @('BusinessUnit', 'Owner', 'Pattern', 'Source', 'MatchingItems', 'Directories', 'Files', 'FindingCount', 'ConflictCount', 'PartialShareCount', 'DirectIdentityCount', 'DirectGroupCount', 'ExpandedMemberCount', 'RiskLevel', 'ReadinessSignals', 'DiscountedPrincipal', 'DiscountedPrincipalCount', 'DiscountedGroupCount', 'DiscountedPrincipals', 'DiscountReason')
        'related_data_areas.csv' = @('RelatedAreaId', 'RelatedDataArea', 'BusinessUnit', 'Owner', 'Pattern', 'Source', 'RelatednessStrength', 'RelationshipSignalCount', 'SupportingSignalCount', 'ReadinessSignalCount', 'RelationshipSignals', 'SupportingEvidence', 'ReadinessSignals', 'CoreFiveChips', 'EvidenceCompleteness', 'RiskLevel', 'MigrationReadiness', 'MatchingShares', 'MatchingItems', 'Directories', 'Files', 'FindingCount', 'ConflictCount', 'ReviewItemCount', 'PartialShareCount', 'DirectIdentityCount', 'DirectGroupCount', 'ExpandedMemberCount', 'RelatedBecauseShort', 'RelatedBecause', 'SuggestedNextAction', 'DiscountedPrincipal', 'DiscountedPrincipalCount', 'DiscountedGroupCount', 'DiscountedPrincipals', 'DiscountReason')
        'owner_review_packets.csv' = @('ReviewPacketId', 'BusinessUnit', 'Owner', 'Pattern', 'Source', 'RiskLevel', 'ReviewStatus', 'WhyReview', 'WhatToReviewFirst', 'SuggestedNextAction', 'MatchingItems', 'Directories', 'Files', 'FindingCount', 'ConflictCount', 'PartialShareCount', 'DirectIdentityCount', 'DirectGroupCount', 'ExpandedMemberCount', 'MigrationReadiness', 'RelatedDataAreaCount', 'RelatednessStrength', 'RelationshipSignalCount', 'ReadinessSignals', 'DiscountedPrincipal', 'DiscountedPrincipalCount', 'DiscountedGroupCount', 'DiscountedPrincipals', 'DiscountReason')
        'conflicts.csv' = @('ConflictId', 'ConflictType', 'ShareId', 'ItemId', 'Identity', 'ShareRights', 'NtfsRights', 'Severity', 'Message')
        'findings.csv' = @('FindingId', 'FindingType', 'Severity', 'ShareId', 'ItemId', 'FullPath', 'Identity', 'ObservedValue', 'PolicyValue', 'Message')
        'collection_errors.csv' = @('ErrorId', 'ShareId', 'ItemId', 'FullPath', 'ErrorType', 'Message', 'Detail')
        'scan_events.csv' = @('Timestamp', 'Level', 'EventType', 'Message', 'Detail')
        'scan_manifest.csv' = @('ScanId', 'GeneratedAt', 'ExportVersion', 'ObsAttribute', 'SourceMode', 'OperationalPathLengthThreshold', 'AzurePathComponentLimit', 'AzureFullPathLimit', 'ExplicitAceDepthThreshold', 'GroupExpansionMaxDepth', 'AdLookupMode', 'IncludeFiles')
    }
}

function Add-ShareSurferStandaloneWarning {
    param(
        [hashtable] $WarningMap,
        [string] $Warning
    )

    if (-not $WarningMap.ContainsKey($Warning)) {
        $WarningMap[$Warning] = $true
    }
}

function Test-ShareSurferStandalonePotentialServiceAccount {
    param($Row)

    $objectClass = if ($Row.PSObject.Properties['ObjectClass']) { [string]$Row.ObjectClass } else { '' }
    $obsPath = if ($Row.PSObject.Properties['ObsPath']) { [string]$Row.ObsPath } else { '' }
    $employeeId = if ($Row.PSObject.Properties['EmployeeId']) { [string]$Row.EmployeeId } else { '' }
    $employeeNumber = if ($Row.PSObject.Properties['EmployeeNumber']) { [string]$Row.EmployeeNumber } else { '' }

    $objectClass.ToLowerInvariant() -eq 'user' -and
        [string]::IsNullOrWhiteSpace($obsPath) -and
        [string]::IsNullOrWhiteSpace($employeeId) -and
        [string]::IsNullOrWhiteSpace($employeeNumber)
}

function Read-ShareSurferStandaloneCsv {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Path,

        [Parameter(Mandatory = $true)]
        [string] $FileName,

        [Parameter(Mandatory = $true)]
        [string[]] $Columns,

        [hashtable] $WarningMap
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        Add-ShareSurferStandaloneWarning -WarningMap $WarningMap -Warning ('{0} was not present in the export. The dashboard will show an empty dataset.' -f $FileName)
        return @()
    }

    $rows = @(Import-Csv -LiteralPath $Path)
    $normalizedRows = foreach ($row in $rows) {
        $record = [ordered]@{}
        foreach ($column in $Columns) {
            if ($row.PSObject.Properties[$column]) {
                $record[$column] = [string]$row.PSObject.Properties[$column].Value
            }
            elseif ($FileName -eq 'identities.csv' -and $column -eq 'PotentialServiceAccount') {
                $record[$column] = if (Test-ShareSurferStandalonePotentialServiceAccount -Row $row) { 'True' } else { 'False' }
                Add-ShareSurferStandaloneWarning -WarningMap $WarningMap -Warning ('{0} is missing column {1}; values were inferred for dashboard review.' -f $FileName, $column)
            }
            elseif ($FileName -eq 'org_chains.csv' -and $column -eq 'PotentialServiceAccount') {
                $record[$column] = 'False'
                Add-ShareSurferStandaloneWarning -WarningMap $WarningMap -Warning ('{0} is missing column {1}; values were defaulted for dashboard review.' -f $FileName, $column)
            }
            else {
                $record[$column] = ''
                Add-ShareSurferStandaloneWarning -WarningMap $WarningMap -Warning ('{0} is missing column {1}; values were defaulted for dashboard review.' -f $FileName, $column)
            }
        }

        foreach ($property in $row.PSObject.Properties) {
            $name = [string]$property.Name
            if (-not $record.Contains($name)) {
                $record[$name] = [string]$property.Value
            }
        }

        [pscustomobject]$record
    }

    @($normalizedRows)
}

if (-not (Test-Path -LiteralPath $ExportPath)) {
    throw ('ExportPath not found: {0}' -f $ExportPath)
}

if ([string]::IsNullOrWhiteSpace($DashboardBuildPath)) {
    $repoRoot = Split-Path -Parent $PSScriptRoot
    $DashboardBuildPath = Join-Path (Join-Path $repoRoot 'interface') (Join-Path 'standalone-dashboard' 'dist')
}

$indexPath = Join-Path $DashboardBuildPath 'index.html'
if (-not (Test-Path -LiteralPath $indexPath)) {
    throw ('Dashboard build output not found. Run npm --prefix interface/standalone-dashboard run build first: {0}' -f $indexPath)
}

if (Test-Path -LiteralPath $OutputPath) {
    if (-not $Force) {
        throw ('OutputPath already exists. Pass -Force to replace it: {0}' -f $OutputPath)
    }
    Remove-Item -LiteralPath $OutputPath -Recurse -Force
}

New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
foreach ($child in @(Get-ChildItem -LiteralPath $DashboardBuildPath -Force)) {
    Copy-Item -LiteralPath $child.FullName -Destination $OutputPath -Recurse -Force
}

$schema = New-ShareSurferStandaloneSchema
$warningMap = @{}
$datasets = [ordered]@{}
$rowCounts = [ordered]@{}
foreach ($fileName in $schema.Keys) {
    $datasetKey = [System.IO.Path]::GetFileNameWithoutExtension($fileName)
    $filePath = Join-Path $ExportPath $fileName
    $rows = @(Read-ShareSurferStandaloneCsv -Path $filePath -FileName $fileName -Columns $schema[$fileName] -WarningMap $warningMap)
    $datasets[$datasetKey] = @($rows)
    $rowCounts[$datasetKey] = @($rows).Count
}

$manifestRows = @($datasets['scan_manifest'])
$manifest = if ($manifestRows.Count -gt 0) { $manifestRows[0] } else { [pscustomobject]@{} }
$generatedAt = if ($manifest.PSObject.Properties['GeneratedAt'] -and [string]$manifest.GeneratedAt -ne '') { [string]$manifest.GeneratedAt } else { [DateTimeOffset]::UtcNow.ToString('o') }
$schemaWarnings = @($warningMap.Keys | Sort-Object)

$snapshot = [ordered]@{
    snapshotKind = 'export'
    generatedAt = $generatedAt
    rowCounts = $rowCounts
    schemaWarnings = $schemaWarnings
    datasets = $datasets
}

$manifestOutput = [ordered]@{
    generatedAt = $generatedAt
    dashboardDataKind = 'export'
    exportPath = (Resolve-Path -LiteralPath $ExportPath).Path
    rowCounts = $rowCounts
    schemaWarningCount = $schemaWarnings.Count
    schemaWarnings = $schemaWarnings
}

$snapshotJson = $snapshot | ConvertTo-Json -Depth 30 -Compress
$snapshotScript = 'window.__SHARESURFER_SNAPSHOT__ = {0};' -f $snapshotJson
$dataScriptPath = Join-Path $OutputPath 'sharesurfer-data.js'
Set-Content -LiteralPath $dataScriptPath -Value $snapshotScript -Encoding UTF8
Set-Content -LiteralPath (Join-Path $OutputPath 'dashboard-manifest.json') -Value ($manifestOutput | ConvertTo-Json -Depth 8) -Encoding UTF8

$result = [pscustomobject]@{
    DashboardPath = (Join-Path $OutputPath 'index.html')
    OutputPath = $OutputPath
    DataScriptPath = (Join-Path $OutputPath 'sharesurfer-data.js')
    ManifestPath = (Join-Path $OutputPath 'dashboard-manifest.json')
    RowCounts = $rowCounts
    SchemaWarningCount = $schemaWarnings.Count
    DashboardDataKind = 'export'
    IsValid = (Test-Path -LiteralPath (Join-Path $OutputPath 'index.html')) -and (Test-Path -LiteralPath $dataScriptPath) -and ((Get-Item -LiteralPath $dataScriptPath).Length -gt 0)
}

if ($PassThru) {
    $result
}
