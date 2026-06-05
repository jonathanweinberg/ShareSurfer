function Protect-ShareSurferValue {
    param(
        $Value,

        [string] $ColumnName = '',

        [string] $FileName = '',

        [string] $RowType = '',

        [ValidateSet('StableToken', 'Strict')]
        [string] $RedactionMode = 'StableToken',

        [string] $RedactionSalt = 'ShareSurfer'
    )

    if ($null -eq $Value) {
        return ''
    }

    $text = [string]$Value
    if ($text -eq '') {
        return ''
    }

    $alwaysSensitiveColumns = @(
        'Identity',
        'SamAccountName',
        'DisplayName',
        'EmployeeId',
        'EmployeeNumber',
        'Manager',
        'ManagerLevel1',
        'ManagerLevel2',
        'ObsPath',
        'Pattern',
        'Owner',
        'BusinessUnit',
        'UNCPath',
        'LocalPath',
        'FullPath',
        'RelativePath',
        'InheritanceBrokenAt',
        'ParentGroup',
        'ChildIdentity',
        'ComputerName',
        'ShareName',
        'Description',
        'Message',
        'Detail'
    )

    $preserveColumns = @(
        'AccessControlType',
        'Rights',
        'Source',
        'ItemType',
        'Depth',
        'IsInherited',
        'InheritanceFlags',
        'PropagationFlags',
        'InheritanceEnabled',
        'PartialData',
        'PartialReason',
        'RelatedAreaId',
        'MigrationReadiness',
        'MatchingShares',
        'MatchingItems',
        'Directories',
        'Files',
        'FindingCount',
        'ConflictCount',
        'ReviewItemCount',
        'PartialShareCount',
        'DirectIdentityCount',
        'DirectGroupCount',
        'ExpandedMemberCount',
        'RelatedBecause',
        'SuggestedNextAction',
        'ReviewPacketId',
        'ReviewStatus',
        'WhyReview',
        'WhatToReviewFirst',
        'RelatedDataAreaCount',
        'RiskLevel',
        'ObjectClass',
        'ChildObjectClass',
        'IsCycle',
        'IsTruncated',
        'ConflictType',
        'FindingType',
        'Severity',
        'PolicyValue',
        'ExportVersion',
        'SourceMode',
        'OperationalPathLengthThreshold',
        'AzurePathComponentLimit',
        'AzureFullPathLimit',
        'ExplicitAceDepthThreshold',
        'GroupExpansionMaxDepth',
        'AdLookupMode',
        'ObsAttribute',
        'GeneratedAt'
    )

    $observedValueSafeRows = @(
        'LongPathOperationalPolicy',
        'AzureFullPathLimit',
        'AzurePathComponentLimit',
        'DeepExplicitAce',
        'GroupExpansionTruncated'
    )

    if ($RedactionMode -eq 'Strict') {
        if ($preserveColumns -contains $ColumnName -or ($ColumnName -eq 'ObservedValue' -and $observedValueSafeRows -contains $RowType)) {
            return $text
        }
        return '[redacted]'
    }

    if ($preserveColumns -contains $ColumnName) {
        return $text
    }

    if ($ColumnName -eq 'ObservedValue' -and $observedValueSafeRows -notcontains $RowType) {
        return Get-ShareSurferStableToken -Value $text -Salt $RedactionSalt
    }

    if ($alwaysSensitiveColumns -contains $ColumnName) {
        return Get-ShareSurferStableToken -Value $text -Salt $RedactionSalt
    }

    $safeLiterals = @(
        'Allow',
        'Deny',
        'Read',
        'Full',
        'FullControl',
        'Modify',
        'ReadAndExecute',
        'Directory',
        'File',
        'Warning',
        'High',
        'Review',
        'Monitor',
        'Info',
        'True',
        'False',
        'Fixture',
        'InputObject',
        'Get-SmbShareAccess',
        'BestEffort'
    )

    if ($safeLiterals -contains $text) {
        return $text
    }

    if ($text -match '^[0-9]+$') {
        return $text
    }

    if ($text -match '[\\/@]' -or $text -match '^[A-Z0-9.-]+\.' -or $text.Length -gt 12) {
        return Get-ShareSurferStableToken -Value $text -Salt $RedactionSalt
    }

    return $text
}
