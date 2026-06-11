# ShareSurfer V1 Export Schema

ShareSurfer V1 writes a normalized CSV export set. Each scan should produce all files listed here, even when a file has only headers or a small number of rows. `Test-ShareSurferExport` validates that the expected set is present and reports structured file-level diagnostics.

## General Conventions

- CSV files are relational. Use IDs such as `ShareId` and `ItemId` to join files.
- Empty fields mean not collected, not applicable, or unknown.
- Boolean fields should use PowerShell-friendly values such as `True` and `False`.
- Identity values should keep a consistent display form, usually `DOMAIN\Name`, before redaction.
- Implementations may add columns, but should not remove or rename V1 columns without a schema version change.

Empty fields should be handled carefully. A blank `Owner`, OBS value, manager, title, office, employee ID, or share metadata field is not proof that the value does not exist in the source system. It usually means ShareSurfer did not collect a usable value, the source did not return one, the value was not populated, or the collector account could not read it.

## Reading Order By Question

| Question | Start with | Then open |
| --- | --- | --- |
| Did the scan run with the settings I expected? | `scan_manifest.csv` | `scan_events.csv`, `collection_errors.csv` |
| Which shares and paths were collected? | `shares.csv` | `items.csv` |
| Was the scan complete enough to review? | `shares.csv` partial fields | `collection_errors.csv`, `findings.csv`, Diagnostics in the report |
| Who should review this data? | `owner_review_packets.csv` | `owner_risk_pivots.csv`, `owner_mappings.csv`, `related_data_areas.csv` |
| Which groups grant access? | `permissioned_groups.csv` | `share_permissions.csv`, `acl_entries.csv`, `group_edges.csv`, `identities.csv` |
| Why is this path risky for migration? | `findings.csv` | `conflicts.csv`, `related_data_areas.csv`, `items.csv` |
| Which identities look like service accounts? | `identities.csv` | `findings.csv`, `org_chains.csv` |
| Which folders were active during the observation window? | `open_file_summary.csv` | `open_file_samples.csv`, `open_file_errors.csv` |
| What can I send to support? | Redacted support bundle output | Raw exports only inside trusted handling |

## Export Validation

`Test-ShareSurferExport` returns:

- `IsValid`, `MissingFiles`, and `SchemaErrors` for quick pass/fail automation.
- `FileResults` with one record per expected CSV.
- `FileResults.RowCount` for populated versus header-only CSVs.
- `FileResults.MissingColumns` and `FileResults.ExtraColumns` for schema triage.

Extra columns are reported for review but do not fail validation. Missing V1 columns fail validation.

## Files

| File | Grain | Purpose |
| --- | --- | --- |
| `shares.csv` | One row per share | Defines collected SMB shares and partial-data status. |
| `items.csv` | One row per file or folder | Defines filesystem items under each share. |
| `share_permissions.csv` | One row per share permission ACE | Captures the share-level access gate. |
| `acl_entries.csv` | One row per NTFS ACL ACE | Captures item-level filesystem permissions. |
| `identities.csv` | One row per enriched identity | Normalizes user, group, and service identity metadata, including extra directory fields that help correlate owners and business units. |
| `group_edges.csv` | One row per group membership edge | Represents nested group expansion. |
| `discounted_principals.csv` | One row per configured discounted principal | Preserves the operator-supplied broad-access identities that stay visible but do not drive migration relatedness. |
| `permissioned_groups.csv` | One row per permission-bearing group | Lists groups that directly grant share or NTFS access, with assignment counts, expansion health, rights, example path context, and discounted-principal labels. |
| `org_chains.csv` | One row per identity with org data | Captures manager chain and OBS ownership context. |
| `owner_mappings.csv` | One row per owner mapping rule | Maps paths or patterns to business owners. |
| `owner_risk_pivots.csv` | One row per owner mapping rule | Summarizes mapped item counts, direct access-review sizing, findings, conflicts, partial shares, and review risk. |
| `related_data_areas.csv` | One row per migration discovery area | Groups like-owned shares, folders, and files for migration planning with explainable relatedness and readiness. |
| `owner_review_packets.csv` | One row per owner review packet | Gives business owners a plain-language review queue with why review is needed, where to start, and suggested next action. |
| `conflicts.csv` | One row per share/NTFS mismatch | Highlights access model conflicts. |
| `findings.csv` | One row per policy or hygiene finding | Highlights migration and governance risks. |
| `collection_errors.csv` | One row per collection error | Preserves scanner error evidence for support, reruns, and partial-data review without forcing operators to infer errors from findings. |
| `scan_events.csv` | One row per scan event | Records collection, export, warning, and error events. |
| `scan_manifest.csv` | One row per scan | Records scan settings, versions, and collection health. |

Each export also includes `scan_events.jsonl`, a raw JSON Lines event log with the same structured event records as `scan_events.csv`. Keep this file with the trusted raw export; use the redacted support bundle version for bug reports.

## Optional Open-File Assessment Package

`Invoke-ShareSurferOpenFileAssessment` can add a separate activity package to the same export folder. These files are optional. `Test-ShareSurferExport` validates the required scan export set even when the open-file files are absent, and the report/dashboard import the activity package when it is present.

| File | Grain | Purpose |
| --- | --- | --- |
| `open_file_manifest.csv` | One row per open-file assessment | Records the assessment provider, sample count, interval, target computer/share names, and start/end times. |
| `open_file_samples.csv` | One row per observed open file per sample | Keeps raw open-file observations, including client, user, path, share-relative path, permissions, locks, and collection status. |
| `open_file_summary.csv` | One row per observed folder | Summarizes activity by folder and marks hot folders based on repeated observations, unique users, unique clients, locks, and heat score. |
| `open_file_errors.csv` | One row per assessment collection error | Records provider or permission failures without invalidating the rest of the assessment package. |

## Column Reference

### `shares.csv`

Expected columns: `ShareId`, `Source`, `ComputerName`, `ShareName`, `UNCPath`, `LocalPath`, `Description`, `PartialData`, `PartialReason`.

Use `PartialData=True` when ShareSurfer could identify the share but could not fully collect metadata. This includes missing share-level permissions and recorded collection errors such as folder enumeration failures or ACL read failures. Put the practical reason in `PartialReason`; scan-error summaries use counts such as `AclReadError=1` so support reviewers can see the shape of the gap without opening raw logs first.

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

Expected columns: `Identity`, `SamAccountName`, `DisplayName`, `ObjectClass`, `EmployeeId`, `EmployeeNumber`, `UserPrincipalName`, `Mail`, `Department`, `Title`, `Company`, `Office`, `AccountEnabled`, `Manager`, `ManagerLevel1`, `ManagerLevel2`, `ManagerLevel3`, `ManagerLevel1Raw`, `ManagerLevel2Raw`, `ManagerLevel3Raw`, `ObsPath`, `ObsAttribute`, `PotentialServiceAccount`, `DistinguishedName`.

`ObsAttribute` records which directory attribute supplied the OBS value, for example `extensionAttribute10`.

`PotentialServiceAccount=True` means the identity is a user account with no OBS value and no `employeeID` or `employeeNumber` collected. Treat it as a review flag, not proof; some environments have incomplete directory data.

`ManagerLevel1`, `ManagerLevel2`, and `ManagerLevel3` use the configured manager display format. The default is `MailTo`, which produces `mailto:` values when mail or UPN data is available. `ManagerLevel1Raw`, `ManagerLevel2Raw`, and `ManagerLevel3Raw` preserve raw directory references when available for correlation and troubleshooting.

Use the extra directory fields as correlation clues, not as approval by themselves. They help identify likely data owners, business units, manager chains, and related groups when path naming alone is not enough.

### `group_edges.csv`

Expected columns: `ParentGroup`, `ChildIdentity`, `ChildObjectClass`, `Depth`, `IsCycle`, `IsTruncated`.

Use `IsCycle=True` for detected group loops. Use `IsTruncated=True` when expansion stops before the full graph is known.

### `discounted_principals.csv`

Expected columns: `Identity`, `Reason`, `Scope`, `MatchType`.

Create this file with `Identity` and optional `Reason` and `Scope`, then pass it to `Invoke-ShareSurferScan -DiscountedPrincipalPath`. V1 uses exact, case-insensitive identity matching. Discounted means visible access evidence that is not used for migration relatedness; it does not mean ignored, safe, approved, or remediated. Raw `share_permissions.csv`, `acl_entries.csv`, identity/group exports, and group review rows still show the access.

### `permissioned_groups.csv`

Expected columns: `Group`, `DisplayName`, `ObjectClass`, `ObsPath`, `ManagerLevel1`, `ShareAssignments`, `NtfsAssignments`, `ExpandedMembers`, `MaxDepth`, `HasCycle`, `IsTruncated`, `Rights`, `ShareId`, `ShareIds`, `Sources`, `FullPath`, `ExamplePath`, `DiscountedPrincipal`, `DiscountReason`, `DiscountScope`.

Use this file to start group access review from groups that actually grant access. It summarizes where a group was assigned, whether the assignment was at the share gate or folder/file layer, which rights were observed, how many members were expanded, and whether expansion hit a cycle or truncation limit.

### `org_chains.csv`

Expected columns: `Identity`, `EmployeeId`, `EmployeeNumber`, `Department`, `Title`, `Company`, `Office`, `ManagerLevel1`, `ManagerLevel2`, `ManagerLevel3`, `ManagerLevel1Raw`, `ManagerLevel2Raw`, `ManagerLevel3Raw`, `ObsPath`, `ObsAttribute`, `PotentialServiceAccount`.

V1 follows the manager chain through three levels when the directory has the data. Blank manager, title, or office values are normal in many environments.

### `owner_mappings.csv`

Expected columns: `Pattern`, `Owner`, `BusinessUnit`, `Source`.

Use this file for business ownership rules such as path prefixes, share names, or imported mapping tables.

When passed through `Invoke-ShareSurferScan -OwnerMappingPath`, the mapping CSV must include `Pattern`, `Owner`, and `BusinessUnit`; `Source` is optional and defaults to `OwnerMappingPath`.

### `owner_risk_pivots.csv`

Expected columns: `BusinessUnit`, `Owner`, `Pattern`, `Source`, `MatchingItems`, `Directories`, `Files`, `FindingCount`, `ConflictCount`, `PartialShareCount`, `DirectIdentityCount`, `DirectGroupCount`, `ExpandedMemberCount`, `RiskLevel`, `ReadinessSignals`, `DiscountedPrincipal`, `DiscountedPrincipalCount`, `DiscountedGroupCount`, `DiscountedPrincipals`, `DiscountReason`.

Use this file when business reviewers need a CSV-first view of which owner or business unit should review a share area. The direct identity, direct group, and expanded member counts size the likely access-review queue before a reviewer opens the detailed identity and group exports. `RiskLevel` is `High` when mapped findings or conflicts include high-severity rows, `Review` when mapped findings, conflicts, or partial shares exist, and `Monitor` when the mapping has no current risk rows.

### `related_data_areas.csv`

Expected columns: `RelatedAreaId`, `RelatedDataArea`, `BusinessUnit`, `Owner`, `Pattern`, `Source`, `RelatednessStrength`, `RelationshipSignalCount`, `SupportingSignalCount`, `ReadinessSignalCount`, `RelationshipSignals`, `SupportingEvidence`, `ReadinessSignals`, `CoreFiveChips`, `EvidenceCompleteness`, `RiskLevel`, `MigrationReadiness`, `MatchingShares`, `MatchingItems`, `Directories`, `Files`, `FindingCount`, `ConflictCount`, `ReviewItemCount`, `PartialShareCount`, `DirectIdentityCount`, `DirectGroupCount`, `ExpandedMemberCount`, `RelatedBecauseShort`, `RelatedBecause`, `SuggestedNextAction`, `DiscountedPrincipal`, `DiscountedPrincipalCount`, `DiscountedGroupCount`, `DiscountedPrincipals`, `DiscountReason`.

Use this file before migration planning to find shares, folders, and files that appear to belong together. Balanced relatedness keeps relationship signals separate from readiness signals: `Strong` clusters have 2+ relationship signals, `Possible` clusters have 1 relationship signal plus supporting evidence, and `Needs Evidence` rows need more relationship proof. Readiness signals such as long path, conflicts, broken inheritance, deep explicit ACE, and partial data affect review priority and `MigrationReadiness`, but do not create relatedness by themselves. `CoreFiveChips` supports Adaptive Rows by summarizing confidence, relationship signal summary, migration readiness, discounted access count, and evidence completeness. Discounted principals are visible in the row and detail semantics but excluded from relatedness counts.

### `owner_review_packets.csv`

Expected columns: `ReviewPacketId`, `BusinessUnit`, `Owner`, `Pattern`, `Source`, `RiskLevel`, `ReviewStatus`, `WhyReview`, `WhatToReviewFirst`, `SuggestedNextAction`, `MatchingItems`, `Directories`, `Files`, `FindingCount`, `ConflictCount`, `PartialShareCount`, `DirectIdentityCount`, `DirectGroupCount`, `ExpandedMemberCount`, `MigrationReadiness`, `RelatedDataAreaCount`, `RelatednessStrength`, `RelationshipSignalCount`, `ReadinessSignals`, `DiscountedPrincipal`, `DiscountedPrincipalCount`, `DiscountedGroupCount`, `DiscountedPrincipals`, `DiscountReason`.

Use this file when business owners need a CSV-first review packet instead of raw ACL evidence. `WhyReview`, `WhatToReviewFirst`, and `SuggestedNextAction` are plain-language fields generated from owner pivots, findings, conflicts, partial-share counts, non-discounted group counts, and related-data-area readiness. The packet is view-only current-state evidence, not approval or planning state. Per-cluster review packet export and interactive planning states are later roadmap features.

### `conflicts.csv`

Expected columns: `ConflictId`, `ConflictType`, `ShareId`, `ItemId`, `Identity`, `ShareRights`, `NtfsRights`, `Severity`, `Message`.

Common V1 conflict types include:

- `NtfsIdentityMissingShareGate` for identities that appear in NTFS ACLs but are not represented at the share-permission layer.
- `ShareIdentityMissingNtfsEntry` for share-level identities with no observed NTFS ACL entry in the scanned share.
- `ShareRightsRestrictNtfs` when share-level rights are narrower than NTFS allow rights for the same identity.
- `NtfsDenyAllowCollision` when the same identity has NTFS allow and deny entries on the same item.
- `ShareAllowsNtfsDenies` when share-level permissions allow an identity that is denied by NTFS on an item.

### `findings.csv`

Expected columns: `FindingId`, `FindingType`, `Severity`, `ShareId`, `ItemId`, `FullPath`, `Identity`, `ObservedValue`, `PolicyValue`, `Message`.

Common V1 finding types include:

- `LongPathOperationalPolicy`
- `DeepExplicitAce`
- `BrokenInheritance`
- `BrokenOrMissingSid`
- `OwnerMetadataUnavailable`
- `CollectionError`

`BrokenOrMissingSid` means a share or folder/file permission references a SID or account name ShareSurfer could not resolve. Treat it as a directory/file-share cleanup signal, not as proof of malicious access.

`OwnerMetadataUnavailable` means `items.csv` did not contain a usable NTFS owner value for the item. This can happen when owner reads are denied, the owner SID is unresolved, a path was partially collected, or the source did not return owner metadata.

### `collection_errors.csv`

Expected columns: `ErrorId`, `ShareId`, `ItemId`, `FullPath`, `ErrorType`, `Severity`, `Source`, `Message`, `Detail`.

Use this file when a scan has partial data, failed folder enumeration, ACL read failures, unresolved target paths, or best-effort SMB/Samba gaps. For folder enumeration failures, `FullPath` should identify the skipped child path when PowerShell exposes it, with the scanned target root used as a fallback. `SharePermissionCollectionUnavailable` means ShareSurfer could enumerate a target path but could not prove the share-level access gate through `Get-SmbShareAccess`. `ErrorType` is preserved as a troubleshooting category, while paths, messages, and details are redacted in support bundles.

### `scan_events.csv`

Expected columns: `EventId`, `Timestamp`, `Level`, `EventType`, `Source`, `ShareId`, `ItemId`, `Message`, `Detail`.

Use this file to troubleshoot collection behavior without scraping console output. Redacted support bundles should preserve event types and levels while anonymizing paths, hostnames, identities, and detailed messages.

### `scan_manifest.csv`

Expected columns: `ScanId`, `GeneratedAt`, `ExportVersion`, `ObsAttribute`, `SourceMode`, `CollectionProvider`, `OperationalPathLengthThreshold`, `AzurePathComponentLimit`, `AzureFullPathLimit`, `ExplicitAceDepthThreshold`, `GroupExpansionMaxDepth`, `AdLookupMode`, `ManagerIdentityFormat`, `IncludeFiles`.

Use the manifest to reproduce scan settings and explain incomplete data. `CollectionProvider` records the collector route, such as `Auto`, `PowerShellCim`, `NativeSmbRpc`, `TargetPath`, or `InputObject`. `ManagerIdentityFormat` records how manager fields were presented in identity and org exports. `IncludeFiles` records whether file objects were included in addition to folders, which matters for enterprise validation and migration-readiness evidence.

### `open_file_manifest.csv`

Expected columns: `AssessmentId`, `GeneratedAt`, `ExportVersion`, `ComputerName`, `ShareNames`, `Provider`, `IntervalSeconds`, `SampleCount`, `DurationMinutes`, `StartedAt`, `CompletedAt`, `PackageKind`.

Use this file to explain how the activity package was collected. `Provider` records the route, such as `NativeRpc` or `PowerShellCim`. `SampleCount` and `IntervalSeconds` explain whether the package was a quick ad hoc sample or a longer observation window.

### `open_file_samples.csv`

Expected columns: `AssessmentId`, `SampleId`, `SampleTimestamp`, `ComputerName`, `ShareName`, `Provider`, `FileId`, `SessionId`, `ClientComputerName`, `ClientUserName`, `Path`, `FolderPath`, `ShareRelativePath`, `ShareRelativeFolder`, `Permissions`, `Locks`, `Source`, `CollectionStatus`, `ErrorMessage`.

Use this file as raw activity evidence. One open file can appear in multiple samples if it remains open across the observation window. `ShareRelativePath` and `ShareRelativeFolder` make it easier to compare activity to the scanned share tree without relying on local server paths.

### `open_file_summary.csv`

Expected columns: `AssessmentId`, `ComputerName`, `ShareName`, `FolderPath`, `ShareRelativeFolder`, `ObservationCount`, `SampleCount`, `FirstSeen`, `LastSeen`, `UniqueUsers`, `UniqueClients`, `TopUsers`, `TopClients`, `TotalLocks`, `MaxLocks`, `HeatScore`, `HotFolder`, `PathProximityKey`.

Use this file to identify active or hot folders for migration planning. `HotFolder=True` means the folder had repeated observations, multiple users or clients, locks, or enough combined activity to deserve review. It is not an approval state and it does not prove exclusive ownership.

### `open_file_errors.csv`

Expected columns: `ErrorId`, `AssessmentId`, `SampleId`, `Timestamp`, `ComputerName`, `ShareName`, `Provider`, `ErrorType`, `Message`, `Detail`.

Use this file to troubleshoot missing or partial open-file activity evidence. Common causes include insufficient rights, an unavailable provider, remote-management restrictions, or a target that does not expose equivalent open-file data.

## Relationship Map

- `shares.ShareId` joins to `items.ShareId`, `share_permissions.ShareId`, `acl_entries.ShareId`, `conflicts.ShareId`, and `findings.ShareId`.
- `items.ItemId` joins to `acl_entries.ItemId`, `conflicts.ItemId`, and `findings.ItemId`.
- `identities.Identity` joins to identity fields in permissions, ACL entries, group edges, org chains, conflicts, and findings.
- `group_edges` expands access from groups to child identities.
- `permissioned_groups.Group` joins to `identities.Identity`, `group_edges.ParentGroup`, `share_permissions.Identity`, and `acl_entries.Identity` for group access review.
- `owner_mappings` adds business context to paths and shares.
- `owner_risk_pivots` joins owner mappings to collected items, shares, access identities, group expansion, findings, and conflicts for owner/business-unit review queues.
- `related_data_areas` builds on owner risk pivots to provide migration discovery rows that are easy to export, filter, and discuss outside the HTML report.
- `owner_review_packets` builds on owner risk pivots and related data areas to produce business-owner review packets with plain next steps.
- `open_file_summary` and `open_file_samples` can be compared to `shares`, `items`, and owner mapping outputs by share name, folder path, and share-relative path when planning hot-folder migration windows.

## Common Join Recipes

| Need | Join path |
| --- | --- |
| Show all ACL entries for one share | `shares.ShareId` to `acl_entries.ShareId`, then filter by `shares.ShareName` or `shares.UNCPath`. |
| Explain why a business owner got a review packet | Start with `owner_review_packets.Pattern`, then compare to `owner_mappings.Pattern`, `owner_risk_pivots.Pattern`, and matching `items.FullPath` or `shares.UNCPath`. |
| Expand a permissioned group | `permissioned_groups.Group` to `group_edges.ParentGroup`, then join `group_edges.ChildIdentity` to `identities.Identity`. |
| Investigate Broken/Missing SID rows | Filter `findings.FindingType=BrokenOrMissingSid`, then use `ShareId`, `ItemId`, `FullPath`, and `Identity` to compare with `share_permissions.csv` and `acl_entries.csv`. |
| Investigate blank file owners | Filter `findings.FindingType=OwnerMetadataUnavailable`, then join `findings.ItemId` to `items.ItemId`. |
| Check whether broad admin access influenced migration relatedness | Open `discounted_principals.csv`, then compare `DiscountedPrincipal*` fields in `permissioned_groups.csv`, `owner_risk_pivots.csv`, and `related_data_areas.csv`. |
| Compare hot folders to access evidence | Use `open_file_summary.ShareRelativeFolder` or `FolderPath`, then compare with `items.RelativePath`, `items.FullPath`, owner mappings, and related data areas. |
