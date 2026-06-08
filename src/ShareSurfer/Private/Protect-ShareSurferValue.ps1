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
        'Group',
        'SamAccountName',
        'DisplayName',
        'EmployeeId',
        'EmployeeNumber',
        'UserPrincipalName',
        'Mail',
        'Department',
        'Title',
        'Company',
        'Office',
        'Manager',
        'ManagerLevel1',
        'ManagerLevel2',
        'ManagerLevel3',
        'ObsPath',
        'Pattern',
        'Owner',
        'BusinessUnit',
        'UNCPath',
        'LocalPath',
        'FullPath',
        'ExamplePath',
        'RelativePath',
        'InheritanceBrokenAt',
        'ParentGroup',
        'ChildIdentity',
        'ComputerName',
        'ShareName',
        'Description',
        'DistinguishedName',
        'Reason',
        'Scope',
        'DiscountReason',
        'DiscountScope',
        'DiscountedPrincipals',
        'Message',
        'Detail'
    )

    $preserveColumns = @(
        'AccessControlType',
        'Rights',
        'Source',
        'Sources',
        'ItemType',
        'Depth',
        'IsInherited',
        'InheritanceFlags',
        'PropagationFlags',
        'InheritanceEnabled',
        'PartialData',
        'PartialReason',
        'AccountEnabled',
        'RelatedAreaId',
        'ErrorId',
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
        'RelatednessStrength',
        'RelationshipSignalCount',
        'SupportingSignalCount',
        'ReadinessSignalCount',
        'RelationshipSignals',
        'SupportingEvidence',
        'ReadinessSignals',
        'CoreFiveChips',
        'EvidenceCompleteness',
        'RelatedBecauseShort',
        'RelatedBecause',
        'SuggestedNextAction',
        'DiscountedPrincipal',
        'DiscountedPrincipalCount',
        'DiscountedGroupCount',
        'MatchType',
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
        'ErrorType',
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
        'PotentialServiceAccount',
        'GeneratedAt'
    )

    $observedValueSafeRows = @(
        'LongPathOperationalPolicy',
        'AzureFullPathLimit',
        'AzurePathComponentLimit',
        'DeepExplicitAce',
        'GroupExpansionTruncated',
        'PartialSharePermissionData',
        'PotentialServiceAccount',
        'CollectionError'
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
