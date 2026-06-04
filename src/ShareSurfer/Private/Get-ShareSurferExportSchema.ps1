function Get-ShareSurferExportSchema {
    [ordered]@{
        'shares.csv' = @(
            'ShareId',
            'Source',
            'ComputerName',
            'ShareName',
            'UNCPath',
            'LocalPath',
            'Description',
            'PartialData',
            'PartialReason'
        )
        'items.csv' = @(
            'ItemId',
            'ShareId',
            'ItemType',
            'FullPath',
            'RelativePath',
            'Depth',
            'Owner',
            'InheritanceEnabled',
            'InheritanceBrokenAt'
        )
        'share_permissions.csv' = @(
            'ShareId',
            'Identity',
            'Rights',
            'AccessControlType',
            'Source'
        )
        'acl_entries.csv' = @(
            'ItemId',
            'ShareId',
            'FullPath',
            'Identity',
            'Rights',
            'AccessControlType',
            'IsInherited',
            'InheritanceFlags',
            'PropagationFlags',
            'Depth'
        )
        'identities.csv' = @(
            'Identity',
            'SamAccountName',
            'DisplayName',
            'ObjectClass',
            'EmployeeId',
            'EmployeeNumber',
            'Manager',
            'ManagerLevel1',
            'ManagerLevel2',
            'ObsPath',
            'ObsAttribute'
        )
        'group_edges.csv' = @(
            'ParentGroup',
            'ChildIdentity',
            'ChildObjectClass',
            'Depth',
            'IsCycle',
            'IsTruncated'
        )
        'org_chains.csv' = @(
            'Identity',
            'EmployeeId',
            'ManagerLevel1',
            'ManagerLevel2',
            'ObsPath',
            'ObsAttribute'
        )
        'owner_mappings.csv' = @(
            'Pattern',
            'Owner',
            'BusinessUnit',
            'Source'
        )
        'conflicts.csv' = @(
            'ConflictId',
            'ConflictType',
            'ShareId',
            'ItemId',
            'Identity',
            'ShareRights',
            'NtfsRights',
            'Severity',
            'Message'
        )
        'findings.csv' = @(
            'FindingId',
            'FindingType',
            'Severity',
            'ShareId',
            'ItemId',
            'FullPath',
            'Identity',
            'ObservedValue',
            'PolicyValue',
            'Message'
        )
        'scan_events.csv' = @(
            'EventId',
            'Timestamp',
            'Level',
            'EventType',
            'Source',
            'ShareId',
            'ItemId',
            'Message',
            'Detail'
        )
        'scan_manifest.csv' = @(
            'ScanId',
            'GeneratedAt',
            'ExportVersion',
            'ObsAttribute',
            'SourceMode',
            'OperationalPathLengthThreshold',
            'AzurePathComponentLimit',
            'AzureFullPathLimit',
            'ExplicitAceDepthThreshold',
            'GroupExpansionMaxDepth',
            'AdLookupMode'
        )
    }
}
