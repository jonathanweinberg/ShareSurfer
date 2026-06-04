# ShareSurfer V1 Export Schema

ShareSurfer V1 writes a normalized CSV export set. Each scan should produce all files listed here, even when a file has only headers or a small number of rows. `Test-ShareSurferExport` validates that the expected set is present.

## General Conventions

- CSV files are relational. Use IDs such as `ShareId` and `ItemId` to join files.
- Empty fields mean not collected, not applicable, or unknown.
- Boolean fields should use PowerShell-friendly values such as `True` and `False`.
- Identity values should keep a consistent display form, usually `DOMAIN\Name`, before redaction.
- Implementations may add columns, but should not remove or rename V1 columns without a schema version change.

## Files

| File | Grain | Purpose |
| --- | --- | --- |
| `shares.csv` | One row per share | Defines collected SMB shares and partial-data status. |
| `items.csv` | One row per file or folder | Defines filesystem items under each share. |
| `share_permissions.csv` | One row per share permission ACE | Captures the share-level access gate. |
| `acl_entries.csv` | One row per NTFS ACL ACE | Captures item-level filesystem permissions. |
| `identities.csv` | One row per enriched identity | Normalizes user, group, and service identity metadata. |
| `group_edges.csv` | One row per group membership edge | Represents nested group expansion. |
| `org_chains.csv` | One row per identity with org data | Captures manager chain and OBS ownership context. |
| `owner_mappings.csv` | One row per owner mapping rule | Maps paths or patterns to business owners. |
| `conflicts.csv` | One row per share/NTFS mismatch | Highlights access model conflicts. |
| `findings.csv` | One row per policy or hygiene finding | Highlights migration and governance risks. |
| `scan_events.csv` | One row per scan event | Records collection, export, warning, and error events. |
| `scan_manifest.csv` | One row per scan | Records scan settings, versions, and collection health. |

## Column Reference

### `shares.csv`

Expected columns: `ShareId`, `Source`, `ComputerName`, `ShareName`, `UNCPath`, `LocalPath`, `Description`, `PartialData`, `PartialReason`.

Use `PartialData=True` when ShareSurfer could identify the share but could not fully collect metadata. Put the practical reason in `PartialReason`.

### `items.csv`

Expected columns: `ItemId`, `ShareId`, `ItemType`, `FullPath`, `RelativePath`, `Depth`, `Owner`, `InheritanceEnabled`, `InheritanceBrokenAt`.

`Depth` is relative to the share root. `InheritanceBrokenAt` should identify the nearest path where inheritance was broken when known.

### `share_permissions.csv`

Expected columns: `ShareId`, `Identity`, `Rights`, `AccessControlType`, `Source`.

Use this file to evaluate the share gate. A permissive NTFS ACL does not grant access when the identity is blocked or absent at the share layer.

### `acl_entries.csv`

Expected columns: `ItemId`, `ShareId`, `FullPath`, `Identity`, `Rights`, `AccessControlType`, `IsInherited`, `InheritanceFlags`, `PropagationFlags`, `Depth`.

Use `IsInherited=False` plus a high `Depth` to identify explicit ACEs buried deep in the tree.

### `identities.csv`

Expected columns: `Identity`, `SamAccountName`, `DisplayName`, `ObjectClass`, `EmployeeId`, `EmployeeNumber`, `Manager`, `ManagerLevel1`, `ManagerLevel2`, `ObsPath`, `ObsAttribute`.

`ObsAttribute` records which directory attribute supplied the OBS value, for example `extensionAttribute10`.

### `group_edges.csv`

Expected columns: `ParentGroup`, `ChildIdentity`, `ChildObjectClass`, `Depth`, `IsCycle`, `IsTruncated`.

Use `IsCycle=True` for detected group loops. Use `IsTruncated=True` when expansion stops before the full graph is known.

### `org_chains.csv`

Expected columns: `Identity`, `EmployeeId`, `ManagerLevel1`, `ManagerLevel2`, `ObsPath`, `ObsAttribute`.

Implementations may add more manager-level columns, but V1 reports should handle at least the first two levels.

### `owner_mappings.csv`

Expected columns: `Pattern`, `Owner`, `BusinessUnit`, `Source`.

Use this file for business ownership rules such as path prefixes, share names, or imported mapping tables.

When passed through `Invoke-ShareSurferScan -OwnerMappingPath`, the mapping CSV must include `Pattern`, `Owner`, and `BusinessUnit`; `Source` is optional and defaults to `OwnerMappingPath`.

### `conflicts.csv`

Expected columns: `ConflictId`, `ConflictType`, `ShareId`, `ItemId`, `Identity`, `ShareRights`, `NtfsRights`, `Severity`, `Message`.

Common V1 conflict types include `NtfsIdentityMissingShareGate` for identities that appear in NTFS ACLs but are not represented at the share-permission layer.

### `findings.csv`

Expected columns: `FindingId`, `FindingType`, `Severity`, `ShareId`, `ItemId`, `FullPath`, `Identity`, `ObservedValue`, `PolicyValue`, `Message`.

Common V1 finding types include:

- `LongPathOperationalPolicy`
- `DeepExplicitAce`
- `BrokenInheritance`

### `scan_manifest.csv`

### `scan_events.csv`

Expected columns: `EventId`, `Timestamp`, `Level`, `EventType`, `Source`, `ShareId`, `ItemId`, `Message`, `Detail`.

Use this file to troubleshoot collection behavior without scraping console output. Redacted support bundles should preserve event types and levels while anonymizing paths, hostnames, identities, and detailed messages.

### `scan_manifest.csv`

Expected columns: `ScanId`, `GeneratedAt`, `ExportVersion`, `ObsAttribute`, `SourceMode`, `OperationalPathLengthThreshold`, `AzurePathComponentLimit`, `AzureFullPathLimit`, `ExplicitAceDepthThreshold`, `GroupExpansionMaxDepth`.

Use the manifest to reproduce scan settings and explain incomplete data.

## Relationship Map

- `shares.ShareId` joins to `items.ShareId`, `share_permissions.ShareId`, `acl_entries.ShareId`, `conflicts.ShareId`, and `findings.ShareId`.
- `items.ItemId` joins to `acl_entries.ItemId`, `conflicts.ItemId`, and `findings.ItemId`.
- `identities.Identity` joins to identity fields in permissions, ACL entries, group edges, org chains, conflicts, and findings.
- `group_edges` expands access from groups to child identities.
- `owner_mappings` adds business context to paths and shares.
