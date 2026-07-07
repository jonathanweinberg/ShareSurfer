[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $ExportPath,

    [Parameter(Mandatory = $true)]
    [string] $OutputPath,

    [string] $DashboardBuildPath = '',

    [Int64] $MaximumDataScriptBytes = 268435456,

    [switch] $Force,

    [switch] $ForceLargeDashboard,

    [switch] $NoCreateMissingFolders,

    [switch] $PassThru
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Ensure-ShareSurferStandaloneLocalDirectory {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Path,

        [string] $Purpose = 'local output',

        [switch] $NoCreateMissingFolders
    )

    if (Test-Path -LiteralPath $Path -PathType Container) {
        return
    }

    if (Test-Path -LiteralPath $Path -PathType Leaf) {
        throw ('Expected a directory for {0}, but a file already exists: {1}' -f $Purpose, $Path)
    }

    if ($NoCreateMissingFolders) {
        throw ('Required {0} folder does not exist and automatic folder creation was disabled: {1}' -f $Purpose, $Path)
    }

    Write-Host ('ShareSurfer Folders: Creating missing local {0} folder: {1}. Use -NoCreateMissingFolders to opt out and fail instead.' -f $Purpose, $Path)
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
}

function New-ShareSurferStandaloneSchema {
    [ordered]@{
        'shares.csv' = @('ShareId', 'Source', 'ComputerName', 'ShareName', 'UNCPath', 'LocalPath', 'Description', 'PartialData', 'PartialReason')
        'items.csv' = @('ItemId', 'ShareId', 'ItemType', 'FullPath', 'RelativePath', 'Depth', 'Owner', 'InheritanceEnabled', 'InheritanceBrokenAt', 'InheritanceBreakType')
        'share_permissions.csv' = @('ShareId', 'Identity', 'Rights', 'AccessMask', 'AccessControlType', 'Source')
        'acl_entries.csv' = @('ItemId', 'ShareId', 'FullPath', 'Identity', 'Rights', 'AccessMask', 'AccessControlType', 'IsInherited', 'InheritanceFlags', 'PropagationFlags', 'Depth')
        'identities.csv' = @('Identity', 'SamAccountName', 'DisplayName', 'ObjectClass', 'EmployeeId', 'EmployeeNumber', 'UserPrincipalName', 'Mail', 'Department', 'Title', 'Company', 'Office', 'AccountEnabled', 'Manager', 'ManagerLevel1', 'ManagerLevel2', 'ManagerLevel3', 'ManagerLevel1Raw', 'ManagerLevel2Raw', 'ManagerLevel3Raw', 'ObsPath', 'ObsAttribute', 'PotentialServiceAccount', 'DistinguishedName')
        'group_edges.csv' = @('ParentGroup', 'ChildIdentity', 'ChildObjectClass', 'Depth', 'IsCycle', 'IsTruncated')
        'discounted_principals.csv' = @('Identity', 'Reason', 'Scope', 'MatchType')
        'permissioned_groups.csv' = @('Group', 'DisplayName', 'ObjectClass', 'ObsPath', 'ManagerLevel1', 'ShareAssignments', 'NtfsAssignments', 'ExpandedMembers', 'MaxDepth', 'HasCycle', 'IsTruncated', 'Rights', 'ShareId', 'ShareIds', 'Sources', 'FullPath', 'ExamplePath', 'DiscountedPrincipal', 'DiscountReason', 'DiscountScope')
        'org_chains.csv' = @('Identity', 'EmployeeId', 'EmployeeNumber', 'Department', 'Title', 'Company', 'Office', 'ManagerLevel1', 'ManagerLevel2', 'ManagerLevel3', 'ManagerLevel1Raw', 'ManagerLevel2Raw', 'ManagerLevel3Raw', 'ObsPath', 'ObsAttribute', 'PotentialServiceAccount')
        'owner_mappings.csv' = @('Pattern', 'Owner', 'BusinessUnit', 'Source')
        'owner_risk_pivots.csv' = @('BusinessUnit', 'Owner', 'Pattern', 'Source', 'MatchingItems', 'Directories', 'Files', 'FindingCount', 'ConflictCount', 'PartialShareCount', 'DirectIdentityCount', 'DirectGroupCount', 'ExpandedMemberCount', 'RiskLevel', 'ReadinessSignals', 'DiscountedPrincipal', 'DiscountedPrincipalCount', 'DiscountedGroupCount', 'DiscountedPrincipals', 'DiscountReason')
        'related_data_areas.csv' = @('RelatedAreaId', 'RelatedDataArea', 'BusinessUnit', 'Owner', 'Pattern', 'Source', 'RelatednessStrength', 'RelationshipSignalCount', 'SupportingSignalCount', 'ReadinessSignalCount', 'RelationshipSignals', 'SupportingEvidence', 'ReadinessSignals', 'CoreFiveChips', 'EvidenceCompleteness', 'RiskLevel', 'MigrationReadiness', 'MatchingShares', 'MatchingItems', 'Directories', 'Files', 'FindingCount', 'ConflictCount', 'ReviewItemCount', 'PartialShareCount', 'DirectIdentityCount', 'DirectGroupCount', 'ExpandedMemberCount', 'RelatedBecauseShort', 'RelatedBecause', 'SuggestedNextAction', 'DiscountedPrincipal', 'DiscountedPrincipalCount', 'DiscountedGroupCount', 'DiscountedPrincipals', 'DiscountReason')
        'owner_review_packets.csv' = @('ReviewPacketId', 'BusinessUnit', 'Owner', 'Pattern', 'Source', 'RiskLevel', 'ReviewStatus', 'WhyReview', 'WhatToReviewFirst', 'SuggestedNextAction', 'MatchingItems', 'Directories', 'Files', 'FindingCount', 'ConflictCount', 'PartialShareCount', 'DirectIdentityCount', 'DirectGroupCount', 'ExpandedMemberCount', 'MigrationReadiness', 'RelatedDataAreaCount', 'RelatednessStrength', 'RelationshipSignalCount', 'ReadinessSignals', 'DiscountedPrincipal', 'DiscountedPrincipalCount', 'DiscountedGroupCount', 'DiscountedPrincipals', 'DiscountReason')
        'conflicts.csv' = @('ConflictId', 'ConflictType', 'ShareId', 'ItemId', 'Identity', 'ShareRights', 'NtfsRights', 'Severity', 'Message')
        'findings.csv' = @('FindingId', 'FindingType', 'Severity', 'ShareId', 'ItemId', 'FullPath', 'Identity', 'ObservedValue', 'PolicyValue', 'Message')
        'evidence_confidence.csv' = @('ConfidenceId', 'Scope', 'ScopeId', 'ScopeName', 'ConfidenceLabel', 'ConfidenceScore', 'StopGate', 'ReviewGate', 'SignalCount', 'Signals', 'PartialShareCount', 'CollectionErrorCount', 'HighSeverityErrorCount', 'TotalShares', 'TotalItems', 'RequestedProvider', 'EffectiveProvider', 'ProviderFallback', 'RecommendedAction', 'Detail')
        'collection_errors.csv' = @('ErrorId', 'ShareId', 'ItemId', 'FullPath', 'ErrorType', 'Severity', 'Source', 'Message', 'Detail')
        'scan_events.csv' = @('EventId', 'Timestamp', 'Level', 'EventType', 'Source', 'ShareId', 'ItemId', 'Message', 'Detail')
        'scan_manifest.csv' = @('ScanId', 'GeneratedAt', 'ExportVersion', 'ObsAttribute', 'SourceMode', 'CollectionProvider', 'RequestedSmbCollectionProvider', 'EffectiveSmbCollectionProvider', 'OperationalPathLengthThreshold', 'AzurePathComponentLimit', 'AzureFullPathLimit', 'ExplicitAceDepthThreshold', 'GroupExpansionMaxDepth', 'AdLookupMode', 'ManagerIdentityFormat', 'IncludeFiles')
    }
}

function New-ShareSurferStandaloneOptionalSchema {
    [ordered]@{
        'open_file_manifest.csv' = @('AssessmentId', 'GeneratedAt', 'ExportVersion', 'ComputerName', 'ShareNames', 'Provider', 'IntervalSeconds', 'SampleCount', 'DurationMinutes', 'StartedAt', 'CompletedAt', 'PackageKind')
        'open_file_samples.csv' = @('AssessmentId', 'SampleId', 'SampleTimestamp', 'ComputerName', 'ShareName', 'Provider', 'FileId', 'SessionId', 'ClientComputerName', 'ClientUserName', 'Path', 'FolderPath', 'ShareRelativePath', 'ShareRelativeFolder', 'Permissions', 'Locks', 'Source', 'CollectionStatus', 'ErrorMessage')
        'open_file_summary.csv' = @('AssessmentId', 'ComputerName', 'ShareName', 'FolderPath', 'ShareRelativeFolder', 'ObservationCount', 'SampleCount', 'FirstSeen', 'LastSeen', 'UniqueUsers', 'UniqueClients', 'TopUsers', 'TopClients', 'TotalLocks', 'MaxLocks', 'HeatScore', 'HotFolder', 'PathProximityKey')
        'open_file_errors.csv' = @('ErrorId', 'AssessmentId', 'SampleId', 'Timestamp', 'ComputerName', 'ShareName', 'Provider', 'ErrorType', 'Message', 'Detail')
        'port_protocol_manifest.csv' = @('AssessmentId', 'GeneratedAt', 'ExportVersion', 'CollectorComputerName', 'CollectorFqdn', 'CollectorUser', 'UserDomain', 'IsWindows', 'IsElevated', 'OSDescription', 'OSArchitecture', 'PowerShellVersion', 'PSEdition', 'ActiveDirectoryModuleAvailable', 'SmbShareModuleAvailable', 'TargetCount', 'CheckCount', 'PassedCount', 'WarningCount', 'FailedCount', 'SkippedCount', 'PackageKind')
        'port_protocol_targets.csv' = @('AssessmentId', 'TargetId', 'Target', 'TargetType', 'ComputerName', 'ShareName', 'UNCPath', 'CheckCount', 'PassedCount', 'WarningCount', 'FailedCount', 'SkippedCount', 'TargetStatus', 'ReadinessSummary', 'CollectionImpact', 'SuggestedNextAction')
        'port_protocol_checks.csv' = @('AssessmentId', 'CheckId', 'TargetId', 'Target', 'TargetType', 'ComputerName', 'ShareName', 'Protocol', 'Transport', 'Port', 'Requirement', 'Provider', 'Purpose', 'RequiredFor', 'Status', 'Severity', 'EnvironmentProfile', 'CollectionImpact', 'OperatorGuidance', 'RemediationHint', 'LatencyMs', 'RemoteAddress', 'Message', 'Detail')
        'ownership_enrichment.csv' = @('OwnershipKey', 'MatchStatus', 'MatchMethod', 'SourcePaths', 'SourceRowNumbers', 'EmployeeId', 'EmployeeNumber', 'SamAccountName', 'UserPrincipalName', 'Mail', 'DisplayName', 'Title', 'Office', 'Department', 'Company', 'Manager', 'ManagerLevel1', 'ManagerLevel2', 'ManagerLevel3', 'ManagerLevel1Raw', 'ManagerLevel2Raw', 'ManagerLevel3Raw', 'OBS', 'AdObsPath', 'ObsAttribute', 'BusinessUnit', 'DataOwner', 'OwnerMail', 'Project', 'ProjectCode', 'AccountEnabled', 'DistinguishedName', 'ForbiddenOuMatched', 'PotentialServiceAccount', 'ImportWarnings')
        'ownership_context.csv' = @('ContextId', 'SourceType', 'SourcePath', 'SourceRowNumber', 'EntityType', 'EntityKey', 'EntityLabel', 'OBS', 'BusinessUnit', 'DataOwner', 'OwnerMail', 'Project', 'ProjectCode', 'ProjectDescription', 'GroupName', 'PathPattern', 'AuthorityLevel', 'ConfidenceLabel', 'EvidenceReason', 'ImportWarnings')
        'ownership_relationships.csv' = @('RelationshipId', 'SourceType', 'SourcePath', 'SourceRowNumber', 'FromType', 'FromValue', 'RelationshipType', 'ToType', 'ToValue', 'AuthorityLevel', 'ConfidenceLabel', 'EvidenceReason')
        'ownership_import_manifest.csv' = @('SourcePath', 'SourceType', 'AuthorityLevel', 'PrimaryAnchor', 'MappedFields', 'RowCount', 'ContextRowCount', 'RelationshipRowCount', 'Warnings')
        'owner_review_decisions.csv' = @('DecisionId', 'ReviewPacketId', 'BusinessUnit', 'Owner', 'Pattern', 'Source', 'RiskLevel', 'ReviewStatus', 'MigrationReadiness', 'RelatednessStrength', 'MatchingItems', 'FindingCount', 'ConflictCount', 'PartialShareCount', 'DirectGroupCount', 'ExpandedMemberCount', 'Decision', 'DecisionStatus', 'ConfirmedOwner', 'ConfirmedBusinessUnit', 'Reviewer', 'ReviewedAt', 'Notes', 'NextAction', 'AllowedDecisions', 'SourceDecisionPath', 'ImportWarnings')
        'migration_cluster_decisions.csv' = @('DecisionId', 'RelatedAreaId', 'RelatedDataArea', 'BusinessUnit', 'Owner', 'Pattern', 'Source', 'RelatednessStrength', 'RiskLevel', 'MigrationReadiness', 'MatchingShares', 'MatchingItems', 'ReviewItemCount', 'FindingCount', 'ConflictCount', 'PartialShareCount', 'DirectGroupCount', 'ExpandedMemberCount', 'Decision', 'DecisionStatus', 'ConfirmedOwner', 'ConfirmedBusinessUnit', 'Reviewer', 'ReviewedAt', 'Notes', 'NextAction', 'AllowedDecisions', 'SourceDecisionPath', 'ImportWarnings')
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

function Format-ShareSurferStandaloneByteCount {
    param(
        [Int64] $Bytes = 0
    )

    if ($Bytes -ge 1GB) {
        return ('{0:N1} GB' -f ([double]$Bytes / 1GB))
    }

    if ($Bytes -ge 1MB) {
        return ('{0:N1} MB' -f ([double]$Bytes / 1MB))
    }

    if ($Bytes -ge 1KB) {
        return ('{0:N1} KB' -f ([double]$Bytes / 1KB))
    }

    return ('{0} bytes' -f $Bytes)
}

function Get-ShareSurferStandaloneSourceByteCount {
    param(
        [string] $Path = ''
    )

    if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return 0
    }

    [Int64](Get-Item -LiteralPath $Path).Length
}

function New-ShareSurferStandaloneSizeMessage {
    param(
        [Int64] $ProjectedBytes,
        [Int64] $MaximumBytes,
        $LargestDatasets
    )

    $datasetSummary = @(
        @($LargestDatasets | Select-Object -First 5) | ForEach-Object {
            '{0}: {1} row(s), {2}' -f [string]$_.DatasetKey, [string]$_.RowCount, (Format-ShareSurferStandaloneByteCount -Bytes ([Int64]$_.SourceBytes))
        }
    ) -join '; '

    if ([string]::IsNullOrWhiteSpace($datasetSummary)) {
        $datasetSummary = 'no dataset size contributors were available'
    }

    'Projected standalone dashboard data script is {0}, above the configured guardrail of {1}. Largest source datasets: {2}. This is a browser/runtime safety guardrail, not a scan failure. Re-run with -ForceLargeDashboard to package anyway, or reduce/package large evidence through the follow-up data-size work.' -f (Format-ShareSurferStandaloneByteCount -Bytes $ProjectedBytes), (Format-ShareSurferStandaloneByteCount -Bytes $MaximumBytes), $datasetSummary
}

function Write-ShareSurferStandaloneManifest {
    param(
        [Parameter(Mandatory = $true)]
        [string] $OutputPath,

        [Parameter(Mandatory = $true)]
        $Manifest
    )

    Set-Content -LiteralPath (Join-Path $OutputPath 'dashboard-manifest.json') -Value ($Manifest | ConvertTo-Json -Depth 10) -Encoding UTF8
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

        [hashtable] $WarningMap,

        [switch] $Optional
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        if (-not $Optional) {
            Add-ShareSurferStandaloneWarning -WarningMap $WarningMap -Warning ('{0} was not present in the export. The dashboard will show an empty dataset.' -f $FileName)
        }
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
            elseif ($FileName -eq 'scan_manifest.csv' -and $column -eq 'RequestedSmbCollectionProvider') {
                $record[$column] = if ($row.PSObject.Properties['CollectionProvider']) { [string]$row.CollectionProvider } else { '' }
                Add-ShareSurferStandaloneWarning -WarningMap $WarningMap -Warning ('{0} is missing column {1}; values were defaulted from CollectionProvider for dashboard review.' -f $FileName, $column)
            }
            elseif ($FileName -eq 'scan_manifest.csv' -and $column -eq 'EffectiveSmbCollectionProvider') {
                $record[$column] = if ($row.PSObject.Properties['CollectionProvider']) { [string]$row.CollectionProvider } else { '' }
                Add-ShareSurferStandaloneWarning -WarningMap $WarningMap -Warning ('{0} is missing column {1}; values were defaulted from CollectionProvider for dashboard review.' -f $FileName, $column)
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

Ensure-ShareSurferStandaloneLocalDirectory -Path $OutputPath -Purpose 'standalone dashboard output' -NoCreateMissingFolders:$NoCreateMissingFolders
foreach ($child in @(Get-ChildItem -LiteralPath $DashboardBuildPath -Force)) {
    Copy-Item -LiteralPath $child.FullName -Destination $OutputPath -Recurse -Force
}

$dataScriptPath = Join-Path $OutputPath 'sharesurfer-data.js'
if (Test-Path -LiteralPath $dataScriptPath -PathType Leaf) {
    Remove-Item -LiteralPath $dataScriptPath -Force
}

$schema = New-ShareSurferStandaloneSchema
$optionalSchema = New-ShareSurferStandaloneOptionalSchema
$warningMap = @{}
$datasets = [ordered]@{}
$rowCounts = [ordered]@{}
$datasetStats = New-Object System.Collections.ArrayList
foreach ($fileName in $schema.Keys) {
    $datasetKey = [System.IO.Path]::GetFileNameWithoutExtension($fileName)
    $filePath = Join-Path $ExportPath $fileName
    $rows = @(Read-ShareSurferStandaloneCsv -Path $filePath -FileName $fileName -Columns $schema[$fileName] -WarningMap $warningMap)
    $datasets[$datasetKey] = @($rows)
    $rowCounts[$datasetKey] = @($rows).Count
    [void]$datasetStats.Add([pscustomobject]@{
            DatasetKey = $datasetKey
            FileName = $fileName
            RowCount = @($rows).Count
            SourceBytes = Get-ShareSurferStandaloneSourceByteCount -Path $filePath
        })
}
foreach ($fileName in $optionalSchema.Keys) {
    $datasetKey = [System.IO.Path]::GetFileNameWithoutExtension($fileName)
    $filePath = Join-Path $ExportPath $fileName
    $rows = @(Read-ShareSurferStandaloneCsv -Path $filePath -FileName $fileName -Columns $optionalSchema[$fileName] -WarningMap $warningMap -Optional)
    $datasets[$datasetKey] = @($rows)
    $rowCounts[$datasetKey] = @($rows).Count
    [void]$datasetStats.Add([pscustomobject]@{
            DatasetKey = $datasetKey
            FileName = $fileName
            RowCount = @($rows).Count
            SourceBytes = Get-ShareSurferStandaloneSourceByteCount -Path $filePath
        })
}

$manifestRows = @($datasets['scan_manifest'])
$manifest = if ($manifestRows.Count -gt 0) { $manifestRows[0] } else { [pscustomobject]@{} }
$generatedAt = if ($manifest.PSObject.Properties['GeneratedAt'] -and [string]$manifest.GeneratedAt -ne '') { [string]$manifest.GeneratedAt } else { [DateTimeOffset]::UtcNow.ToString('o') }
$schemaWarnings = @($warningMap.Keys | Sort-Object)
$largestDatasets = @($datasetStats | Sort-Object -Property @{ Expression = { [Int64]$_.SourceBytes }; Descending = $true }, @{ Expression = { [Int64]$_.RowCount }; Descending = $true } | Select-Object -First 8)
$sourceDataBytes = [Int64]0
foreach ($datasetStat in @($datasetStats)) {
    $sourceDataBytes += [Int64]$datasetStat.SourceBytes
}

$projectedDataScriptBytes = [Int64][Math]::Ceiling(([double]$sourceDataBytes * 2.0) + 65536)
$actualDataScriptBytes = [Int64]0
$sizeGuardrailStatus = 'WithinLimit'
$sizeGuardrailMessage = 'Standalone dashboard data size is within the configured browser/runtime guardrail.'
if ($MaximumDataScriptBytes -le 0) {
    $sizeGuardrailStatus = 'Disabled'
    $sizeGuardrailMessage = 'Standalone dashboard data-size guardrail was disabled by MaximumDataScriptBytes <= 0.'
}

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
    sourceDataBytes = $sourceDataBytes
    projectedDataScriptBytes = $projectedDataScriptBytes
    actualDataScriptBytes = $actualDataScriptBytes
    maximumDataScriptBytes = [Int64]$MaximumDataScriptBytes
    sizeGuardrailStatus = $sizeGuardrailStatus
    sizeGuardrailMessage = $sizeGuardrailMessage
    largestDatasets = $largestDatasets
}

if ($MaximumDataScriptBytes -gt 0 -and $projectedDataScriptBytes -gt $MaximumDataScriptBytes) {
    $sizeGuardrailMessage = New-ShareSurferStandaloneSizeMessage -ProjectedBytes $projectedDataScriptBytes -MaximumBytes ([Int64]$MaximumDataScriptBytes) -LargestDatasets $largestDatasets
    if (-not $ForceLargeDashboard) {
        $sizeGuardrailStatus = 'RefusedProjectedOverLimit'
        $manifestOutput['sizeGuardrailStatus'] = $sizeGuardrailStatus
        $manifestOutput['sizeGuardrailMessage'] = $sizeGuardrailMessage
        Write-ShareSurferStandaloneManifest -OutputPath $OutputPath -Manifest $manifestOutput
        throw $sizeGuardrailMessage
    }

    $sizeGuardrailStatus = 'ProjectedOverLimitAllowed'
    $manifestOutput['sizeGuardrailStatus'] = $sizeGuardrailStatus
    $manifestOutput['sizeGuardrailMessage'] = $sizeGuardrailMessage
    Write-Warning ('{0} Packaging will continue because -ForceLargeDashboard was supplied.' -f $sizeGuardrailMessage)
}

$snapshotJson = $snapshot | ConvertTo-Json -Depth 30 -Compress
$snapshotScript = 'window.__SHARESURFER_SNAPSHOT__ = {0};' -f $snapshotJson
$actualDataScriptBytes = [Int64][System.Text.Encoding]::UTF8.GetByteCount($snapshotScript)
$manifestOutput['actualDataScriptBytes'] = $actualDataScriptBytes

if ($MaximumDataScriptBytes -gt 0 -and $actualDataScriptBytes -gt $MaximumDataScriptBytes) {
    $actualSizeMessage = 'Actual standalone dashboard data script is {0}, above the configured guardrail of {1}. This is a browser/runtime safety guardrail, not a scan failure. Re-run with -ForceLargeDashboard to package anyway, or reduce/package large evidence through the follow-up data-size work.' -f (Format-ShareSurferStandaloneByteCount -Bytes $actualDataScriptBytes), (Format-ShareSurferStandaloneByteCount -Bytes ([Int64]$MaximumDataScriptBytes))
    if (-not $ForceLargeDashboard) {
        $sizeGuardrailStatus = 'RefusedActualOverLimit'
        $manifestOutput['sizeGuardrailStatus'] = $sizeGuardrailStatus
        $manifestOutput['sizeGuardrailMessage'] = $actualSizeMessage
        Write-ShareSurferStandaloneManifest -OutputPath $OutputPath -Manifest $manifestOutput
        throw $actualSizeMessage
    }

    $sizeGuardrailStatus = 'ActualOverLimitAllowed'
    $manifestOutput['sizeGuardrailStatus'] = $sizeGuardrailStatus
    $manifestOutput['sizeGuardrailMessage'] = $actualSizeMessage
    Write-Warning ('{0} Packaging will continue because -ForceLargeDashboard was supplied.' -f $actualSizeMessage)
}

Set-Content -LiteralPath $dataScriptPath -Value $snapshotScript -Encoding UTF8
Write-ShareSurferStandaloneManifest -OutputPath $OutputPath -Manifest $manifestOutput

$result = [pscustomobject]@{
    DashboardPath = (Join-Path $OutputPath 'index.html')
    OutputPath = $OutputPath
    DataScriptPath = (Join-Path $OutputPath 'sharesurfer-data.js')
    ManifestPath = (Join-Path $OutputPath 'dashboard-manifest.json')
    RowCounts = $rowCounts
    SchemaWarningCount = $schemaWarnings.Count
    DashboardDataKind = 'export'
    SourceDataBytes = $sourceDataBytes
    ProjectedDataScriptBytes = $projectedDataScriptBytes
    ActualDataScriptBytes = $actualDataScriptBytes
    MaximumDataScriptBytes = [Int64]$MaximumDataScriptBytes
    SizeGuardrailStatus = $sizeGuardrailStatus
    LargestDatasets = $largestDatasets
    IsValid = (Test-Path -LiteralPath (Join-Path $OutputPath 'index.html')) -and (Test-Path -LiteralPath $dataScriptPath) -and ((Get-Item -LiteralPath $dataScriptPath).Length -gt 0)
}

if ($PassThru) {
    $result
}
