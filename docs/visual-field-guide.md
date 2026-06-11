# ShareSurfer Visual Field Guide

This field guide explains the major ShareSurfer workflows with diagrams and plain-English review notes. Use it when introducing ShareSurfer to a new operator, business owner, manager, or migration team.

ShareSurfer is read-only. These visuals explain how evidence moves from file shares into review outputs; they do not imply that ShareSurfer changes permissions, approves access, or migrates data.

## Evidence Pipeline

![ShareSurfer evidence pipeline](visuals/field-guide/evidence-pipeline.png)

The evidence pipeline starts with source data from SMB shares, NTFS ACLs, owners, AD users, and groups. ShareSurfer normalizes that evidence into CSV exports, findings, conflicts, and a manifest. The operator validates the export, reviews partial-data warnings, then opens `report.html` or packages the standalone dashboard.

Review questions:

- Did `Test-ShareSurferExport` pass?
- Are partial-data warnings understood before owner review?
- Does the owner packet explain who should review the area?
- After cleanup, will the same scan be rerun to prove improvement?

Primary outputs:

- `scan_manifest.csv`
- `findings.csv`
- `conflicts.csv`
- `owner_review_packets.csv`
- `report.html`
- optional `standalone-dashboard\index.html`

## Share Gate vs File and Folder Permissions

![Share gate vs file and folder permissions](visuals/field-guide/share-gate-ntfs-model.png)

Windows file-share access has two important permission layers. The share-level permission is the front gate. File and folder ACLs decide what happens after a user passes that gate. ShareSurfer compares both layers so reviewers can see where access is restricted, allowed, denied, inherited, customized, or broken.

Review questions:

- Does the share gate allow access that NTFS later denies?
- Does the share gate restrict access that NTFS appears to allow?
- Where has inheritance stopped?
- Which explicit permissions appear deep in the folder tree?
- Are any broken or missing SIDs part of the access story?

Primary outputs:

- `share_permissions.csv`
- `acl_entries.csv`
- `items.csv`
- `conflicts.csv`
- dashboard Access Model and Findings views

## Identity and Org Enrichment

![Identity and org enrichment](visuals/field-guide/identity-org-enrichment.png)

Identity enrichment expands permission-bearing users and groups into reviewable context. ShareSurfer follows nested security groups with cycle protection, enriches known directory attributes, follows manager chains up to three levels, and records the runtime OBS attribute selected by the operator.

Review questions:

- Which groups grant access to this area?
- Were any group expansions truncated by max depth?
- Do users roll up to the expected manager chain?
- Does the chosen `-ObsAttribute` contain the intended OBS/OID path?
- Which accounts have no OBS and no employee identifier and may need service-account review?

Primary outputs:

- `identities.csv`
- `group_edges.csv`
- `org_chains.csv`
- `permissioned_groups.csv`
- `findings.csv`

## Migration Discovery Signals

![Migration discovery signals](visuals/field-guide/migration-discovery-signals.png)

Migration Discovery helps teams find shares, folders, and files that appear to belong together before migration planning. It uses transparent signals: same owner, same business unit, OBS path, manager chain, path pattern, and permission group overlap. Discounted principals remain visible, but they do not inflate relatedness.

Review questions:

- Why did ShareSurfer group these shares or folders together?
- Is the relationship based on ownership, org context, path pattern, group overlap, or several signals?
- Are broad admin or HelpDesk groups discounted so they do not create false clusters?
- Which findings and conflicts should be reviewed before a migration wave?
- Are partial-data gaps blocking confidence?

Primary outputs:

- `related_data_areas.csv`
- `owner_risk_pivots.csv`
- `owner_review_packets.csv`
- `discounted_principals.csv`
- dashboard Migration Discovery view

## Diagnostics and Trust Review

![Diagnostics and trust review](visuals/field-guide/diagnostics-trust-review.png)

Diagnostics answer a simple question: can reviewers trust this scan enough to act on it? Warnings do not automatically mean the scan failed. They show what the operator should review before approval, such as partial data, access denied paths, WinRM/CIM gaps, broken or missing SIDs, long path warnings, and critical scan blocks.

Review questions:

- Which warnings affect the paths being reviewed?
- Can the scan be rerun elevated or with a different provider?
- Do access denied rows hide important folders?
- Are broken or missing SIDs expected cleanup work?
- Should the result be handed off now, or rerun first?

Primary outputs:

- `collection_errors.csv`
- `scan_events.csv`
- `findings.csv`
- `scan_manifest.csv`
- dashboard Diagnostics view

## Redacted Support Handoff

![Redacted support handoff](visuals/field-guide/redacted-support-handoff.png)

Raw exports can contain real paths, identities, employee details, manager context, and business structure. When support evidence must leave trusted handling, use a redacted support bundle. The bundle preserves troubleshooting shape with stable tokens, row counts, hashes, and manifests while keeping raw data internal.

Review questions:

- Is this for internal review or external support?
- Do raw CSVs need to stay inside the trusted environment?
- Does the support bundle include the row counts and manifest needed for troubleshooting?
- Is a redacted report enough, or does the operator need to rerun the scan first?

Primary outputs:

- redacted CSV files
- support bundle manifest
- audit summary
- optional redacted report

## How To Use This Guide

- Use **Evidence Pipeline** when explaining what ShareSurfer does end to end.
- Use **Share Gate vs File and Folder Permissions** when business owners ask why share permissions and folder permissions both matter.
- Use **Identity and Org Enrichment** when explaining group expansion, manager chains, OBS attributes, and service-account signals.
- Use **Migration Discovery Signals** before migration planning.
- Use **Diagnostics and Trust Review** before asking an owner to approve a report.
- Use **Redacted Support Handoff** before sending evidence outside trusted handling.
