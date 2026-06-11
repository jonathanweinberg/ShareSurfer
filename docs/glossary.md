# ShareSurfer Glossary

This glossary defines the terms operators and business reviewers see in ShareSurfer documentation, CSV exports, and dashboards.

ShareSurfer is read-only. These terms describe evidence and review signals, not automatic approval or remediation decisions.

## Access and Permission Terms

| Term | Plain-English meaning | Where you see it |
| --- | --- | --- |
| Share gate | The share-level permission layer on an SMB share. It is the front gate before file and folder permissions are considered. | `share_permissions.csv`, conflicts, dashboard Access Model. |
| File/folder permissions | The NTFS permissions on folders and files after a user gets through the share gate. | `acl_entries.csv`, dashboard path details. |
| Share-vs-NTFS conflict | A mismatch or collision between share-level access and file/folder permissions. | `conflicts.csv`, Findings and Conflicts views. |
| Explicit ACE | A permission entry placed directly on a folder or file instead of inherited from a parent. | `acl_entries.csv`, deep explicit permission findings. |
| Deep explicit permission | An explicit ACE found deeper than the configured depth threshold. ShareSurfer defaults to flagging explicit permissions deeper than level 2. | `findings.csv`, migration readiness warnings. |
| Inherited permission | A permission that flows down from a parent folder. | `acl_entries.csv`, dashboard path details. |
| Inheritance break | A folder or file where inherited permissions stop or are changed. | `items.csv`, `findings.csv`, dashboard inheritance views. |
| Deny/allow collision | Evidence that deny and allow permissions may produce confusing or unexpected effective access. | `conflicts.csv`, Findings and Conflicts views. |

## Owner and Identity Terms

| Term | Plain-English meaning | Where you see it |
| --- | --- | --- |
| Owner | The mapped business or data-review owner ShareSurfer should route a path to. This is not the same as the Windows NTFS owner. | `owner_mappings.csv`, `owner_review_packets.csv`, dashboard review queue. |
| NTFS owner | The Windows security owner recorded on a file or folder when ShareSurfer can read it. | `items.csv`. |
| No owner | Usually means ShareSurfer could not read, resolve, or enrich owner metadata. It does not prove the file has no real Windows owner. | Dashboard Key Terms, `OwnerMetadataUnavailable` findings. |
| Owner mapping | A CSV rule that maps a path pattern to a business owner and business unit. | `owner_mappings.csv`, README quickstart, command recipes. |
| Owner review packet | A CSV row set that groups findings, conflicts, paths, and access signals by likely owner/business unit. | `owner_review_packets.csv`, dashboard review queue. |
| Business unit | A business grouping used for review routing and pivots. It can come from owner mapping, org data, or enrichment. | `owner_mappings.csv`, `owner_risk_pivots.csv`, dashboard filters. |
| OBS attribute | The directory attribute used to store the organization or OBS/OID path. The default is `extensionAttribute10`, but the operator can choose another attribute at runtime. | `scan_manifest.csv`, `identities.csv`, command examples. |
| Employee ID / employee number | Directory attributes that help correlate users across exports and org data. Missing values can be normal, but accounts with no OBS and no employee identifier may deserve service-account review. | `identities.csv`, identity enrichment outputs. |
| Manager levels | Manager chain fields ShareSurfer follows up to three levels. The default report format is mail-style when available. | `identities.csv`, `org_chains.csv`, dashboard org views. |
| Broken/Missing SID | A permission entry references a SID that ShareSurfer cannot resolve to a current account or group. | `findings.csv`, dashboard filters and findings. |
| Potential service account | An identity with no OBS value and no employee identifier. This is a review signal, not proof that the account is safe or unsafe. | `findings.csv`, identity review. |

## Collection and Evidence Terms

| Term | Plain-English meaning | Where you see it |
| --- | --- | --- |
| Partial data | ShareSurfer completed the scan but could not prove every requested detail. Review the missing evidence before approval. | `shares.csv`, `collection_errors.csv`, dashboard Diagnostics. |
| Collection error | A recorded collection problem, such as access denied, unavailable share metadata, unreadable ACLs, or path enumeration failure. | `collection_errors.csv`, `scan_events.csv`, dashboard Diagnostics. |
| Critical scan information block | A collection problem serious enough that the report should call attention to it before business approval. | Findings tab, diagnostics views. |
| Access denied | The collector account could not read a path or security descriptor. The scan continues where it can. | `collection_errors.csv`, `findings.csv`. |
| WinRM/CIM gap | Remote Windows management could not prove SMB share metadata or share permissions. ShareSurfer can continue best-effort and may use native SMB/RPC when requested. | `collection_errors.csv`, `scan_events.csv`, troubleshooting docs. |
| NativeSmbRpc | A Windows SMB/RPC collection provider used when the normal WinRM/CIM route is blocked or unsuitable. | Command recipes, `scan_manifest.csv`, `scan_events.csv`. |
| Raw export | The validated CSV folder produced by a scan. It may contain sensitive paths, names, and identity details. | Output folder, handoff workflows. |
| Redacted support bundle | A support package that replaces sensitive values with stable tokens while preserving row shape and troubleshooting context. | `New-ShareSurferSupportBundle`, support docs. |

## Migration and Dashboard Terms

| Term | Plain-English meaning | Where you see it |
| --- | --- | --- |
| Operational path warning | ShareSurfer's default warning for full paths longer than 256 characters. This is a migration policy signal, not an Azure Files hard-limit claim. | `findings.csv`, dashboard migration warnings. |
| Azure Files hard limit | Microsoft currently documents 255-character path components and 2,048-character full paths for Azure Files. | Azure path policy docs, report language. |
| Migration Discovery | The dashboard view that groups related shares, folders, owners, OBS paths, path patterns, and access signals so migration teams can keep related data together. | Standalone dashboard, `related_data_areas.csv`. |
| Related data area | A transparent grouping of shares/folders that appear to belong together because of owner, business unit, OBS, path, manager, or group-overlap signals. | `related_data_areas.csv`, Migration Discovery. |
| Discounted access principal | A broad admin, HelpDesk, scanner, backup, or platform account/group that remains visible in evidence but does not inflate Migration Discovery relatedness. | `discounted_principals.csv`, `related_data_areas.csv`, dashboard filters. |
| Dashboard host | A workstation used to open `report.html` or a packaged standalone dashboard. It does not need rights to rescan file shares. | Two-host workflow docs. |
| Collector host | The Windows machine that runs `Invoke-ShareSurferScan` and writes the raw export folder. | README, first-run guide, workflow docs. |
| Standalone dashboard | A packaged offline dashboard folder created from a validated export. It opens from `index.html` without npm, Vite, a server, or internet access. | README, command recipes. |
| Raw Evidence Tables | Dashboard tables that show the CSV-shaped evidence after the business-friendly views. Use them when an admin needs details. | Dashboard Raw Evidence view. |

## Quick Rule of Thumb

- If a term says **finding**, treat it as something to review.
- If a term says **conflict**, compare the share gate and file/folder permissions.
- If a term says **partial** or **collection error**, decide whether the missing evidence affects approval.
- If a term says **owner**, ask whether it means business owner or NTFS owner before acting.
- If a term says **discounted**, remember it is still visible evidence. It is not ignored, approved, or remediated.
