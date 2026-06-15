# ShareSurfer Next-Level Roadmap

ShareSurfer's next level is turning it from a scanner that exports evidence into a guided ownership and migration review system.

The current foundation is strong: collector commands, normalized CSV exports, offline reporting, standalone dashboard packaging, owner review packets, Migration Discovery, discounted principals, Native SMB/RPC diagnostics, first-run documentation, and pre-release packaging. The next leap is making ShareSurfer lead an operator or business owner through the review instead of asking them to interpret evidence tables alone.

## North Star

ShareSurfer should answer four questions clearly for every scan:

1. **Can we trust this scan?**
   Show collection completeness, unreachable paths, access denied areas, WinRM/CIM versus SMB/RPC fallback state, missing descriptors, missing SIDs, and partial-data warnings as a first-class confidence model.

2. **Who needs to review this?**
   Promote owner, business unit, manager, manager chain, and OBS routing above raw ACL detail. The report should be able to say: this appears to belong to a business area, these owners and managers are likely accountable, and these groups appear to grant access.

3. **What should they review first?**
   Rank review queues by critical blockers, unauthorized operation failures, missing owners, broken inheritance, long paths, deep explicit ACEs, broad or administrative access, and conflict clusters.

4. **What migration group does this belong with?**
   Migration Discovery should identify related shares and folders by owner, business unit, OBS, manager chain, naming pattern, path pattern, and permission-bearing group overlap, while explaining why the data areas were grouped.

## Recommended Theme

The recommended next major product theme is:

**ShareSurfer 0.2: Evidence Confidence and Guided Review**

This theme keeps ShareSurfer practical and offline. It does not require ShareSurfer to modify permissions, call an AI service, or depend on cloud services. The main goal is to turn the evidence already collected into trustworthy review guidance.

## Product Lanes

### 1. Evidence Confidence Layer

Evidence confidence should become a formal output model rather than an implied interpretation of scan events and collection errors.

Useful rollups include:

- WinRM/CIM available, failed, or skipped.
- Native SMB/RPC attempted, used, or failed.
- Share security descriptor read and parse status.
- File and folder owner read status.
- File and folder DACL read and parse status.
- Broken or missing SID count.
- Access denied count.
- Unauthorized operation count.
- Partial-data reason.
- Elevated or non-elevated PowerShell context.
- Collection provider used per share.

This can flow into a new CSV such as `evidence_confidence.csv`, or be added safely through additive columns in existing evidence outputs. The report and standalone dashboard should show this as "Can we trust this scan?" rather than making the user infer it from raw errors.

Example confidence categories:

| Category | Meaning |
| --- | --- |
| Complete | Required share and file/folder evidence was collected. |
| Partial | Some evidence was collected, but one or more expected evidence types could not be proven. |
| Blocked | The scan could reach a target but could not collect enough evidence for review confidence. |
| Unknown | The scan did not have enough context to classify completeness. |

### 2. Dashboard as the Primary Product Surface

The legacy offline HTML report can remain the sturdy fallback, but the standalone dashboard should become the flagship review experience.

Priority improvements:

- Full-width data panes where tables need horizontal scrolling.
- Hideable sidebar.
- Sort and filter on every table.
- Click any path and open a path detail view.
- Click any finding rollup and jump into the filtered finding rows.
- Add a global broken or missing SID filter.
- Add a collection-blocker panel for access denied and unauthorized operation events.
- Make scan dates and report generation dates visible in more places.
- Define "Owner", "no owner", "service-account-like identity", "discounted principal", and "partial data" in user-facing language.
- Keep the owner review packet workflow visible in the quickstart and dashboard.

The dashboard should feel like a guided review conversation:

- What needs review first.
- Who should review it.
- Why it was flagged.
- What evidence supports the finding.
- What data could not be proven.
- Which paths or shares appear related for migration planning.

### 3. Migration Discovery Engine

Migration Discovery is the differentiator. Many tools can dump ACLs. ShareSurfer should help explain which shares, folders, and files probably belong together before migration planning.

Initial relatedness signals should remain deterministic and explainable:

- Same owner mapping.
- Same business unit.
- Same OBS path.
- Same manager or manager chain.
- Same permission-bearing group.
- Similar share name.
- Similar folder name.
- Similar path prefix.
- Similar finding or conflict pattern.
- Shared long-path, inheritance, or partial-data risk.

Discounted principals, such as HelpDesk, backup, platform, or administrative groups, should remain visible in evidence but should not inflate relatedness scoring.

Each related data area should show why it exists:

| Relatedness Reason | Example User-Facing Text |
| --- | --- |
| Same owner | These paths map to the same owner. |
| Same business unit | These shares appear to belong to the same business unit. |
| Same OBS path | The matched identities roll up through the same OBS structure. |
| Shared group | The same permission-bearing group grants access across these areas. |
| Similar path pattern | The share or folder names follow a similar naming pattern. |
| Shared migration risk | These areas share long-path, inheritance, or conflict findings. |

## Admin Interview and Flexible Ownership Import

ShareSurfer can improve owner and OBS discovery without adding AI or LLM calls. The right approach is a deterministic admin interview plus a flexible CSV header-mapping process.

The problem is that real environments rarely give us perfectly named files. One team may provide `EmployeeID`, another may provide `employee_number`, another may provide `WorkerId`, and another may provide `Personnel Number`. OBS information may be called `OBS`, `OID`, `OrgPath`, `CostCenterPath`, `Division`, `DepartmentCode`, or something stranger.

ShareSurfer can support both strict and guided modes.

### Mode A: Canonical Header Contract

This mode tells the user exactly what headers ShareSurfer understands.

Recommended canonical identity/OBS headers:

| Header | Required | Purpose |
| --- | --- | --- |
| `EmployeeId` | Recommended | Stable join key for HR or identity data. |
| `SamAccountName` | Optional | Join key for AD account data when employee ID is missing. |
| `UserPrincipalName` | Optional | Join key for Entra ID or email-like identity data. |
| `Mail` | Optional | Friendly reviewer/contact routing. |
| `DisplayName` | Optional | Human-readable identity name. |
| `Title` | Optional | Helpful reviewer context. |
| `Office` | Optional | Helpful reviewer context. |
| `ManagerMail` | Optional | Preferred manager level 1 value for reporting. |
| `ManagerLevel2Mail` | Optional | Preferred manager level 2 value for reporting. |
| `ManagerLevel3Mail` | Optional | Preferred manager level 3 value for reporting. |
| `OBS` | Recommended | Business or org structure path. |
| `BusinessUnit` | Recommended | Business-facing grouping label. |
| `DataOwner` | Optional | Explicit owner when known. |

Recommended owner/path mapping headers:

| Header | Required | Purpose |
| --- | --- | --- |
| `PathPrefix` | Required for path mapping | Share or folder prefix to match. |
| `DataOwner` | Recommended | Owner label shown in reports. |
| `BusinessUnit` | Recommended | Business unit shown in reports. |
| `OBS` | Optional | OBS path associated with the path. |
| `OwnerMail` | Optional | Contact or review routing address. |
| `Notes` | Optional | Admin explanation for the mapping. |

Strict mode is easy to support and easy to document. Its weakness is that it forces the admin to reshape files before ShareSurfer can help.

### Mode B: Guided Header Mapping

Guided mode lets the user provide an imperfect CSV and have ShareSurfer interview them.

The process can be fully offline and deterministic:

1. Read the CSV headers.
2. Show the headers and a small sample of non-sensitive-looking values.
3. Try safe synonym matching for common names.
4. Ask the admin to confirm or correct each important field.
5. Save the answers as a reusable mapping profile.
6. Normalize the source data into ShareSurfer's canonical model.
7. Produce warnings for missing, duplicate, or ambiguous keys.

Example prompt flow:

```text
ShareSurfer found these CSV headers:

employee_number, display_name, mail_address, cost_center_path, mgr_email, title, location

Which column contains the employee ID?
  [1] employee_number
  [2] display_name
  [3] mail_address
  [4] cost_center_path
  [S] Skip this field

Which column contains the OBS or org path?
  [1] cost_center_path
  [2] location
  [S] Skip this field
```

For repeatable use, ShareSurfer should save a mapping profile such as:

```json
{
  "SourceName": "HR employee OBS export",
  "EmployeeId": "employee_number",
  "DisplayName": "display_name",
  "Mail": "mail_address",
  "OBS": "cost_center_path",
  "ManagerMail": "mgr_email",
  "Title": "title",
  "Office": "location"
}
```

The profile can then be reused:

```powershell
Import-ShareSurferOwnershipSource `
  -Path C:\ShareSurfer\inputs\hr-obs.csv `
  -MappingProfilePath C:\ShareSurfer\inputs\hr-obs.mapping.json `
  -OutputPath C:\ShareSurfer\inputs\normalized-ownership.csv
```

### Mode C: Admin Interview for Missing Ownership Context

Some ownership information will not come from AD or HR exports. An admin may know that a path belongs to an application team, a regional office, or a legacy department even when the directory has no clean owner.

ShareSurfer can interview the admin and generate an owner mapping draft:

```text
ShareSurfer found 37 shares or top folders with no owner mapping.

For \\server01\FinanceArchive:
Who is the most likely business owner?
Who is the business unit?
Does this path belong under an OBS path?
Should this mapping apply only to this share, or to child folders as well?
Should this owner mapping override identity-derived hints?
```

The output should be a normal CSV the admin can review, edit, and version:

```csv
PathPrefix,DataOwner,BusinessUnit,OBS,OwnerMail,Confidence,MappingSource,Notes
\\server01\FinanceArchive,Finance Operations,Finance,/Corporate/Finance,finance-ops@example.com,AdminConfirmed,Interview,"Confirmed by storage admin during review"
```

### Handling Unexpected Information

The ingestion process should be forgiving, but not magical. It should avoid hidden guessing.

Recommended behavior:

- Use synonym matching to suggest field mappings.
- Ask before accepting uncertain mappings.
- Show a preview of normalized rows.
- Emit validation findings for missing join keys.
- Emit warnings for duplicate employee IDs or duplicate account names.
- Flag accounts with no OBS and no employee number or employee ID as potential service-account-like identities.
- Preserve original source columns in a sidecar or source reference when useful.
- Record the mapping profile in the scan manifest or ownership import manifest.

Example synonym groups:

| Canonical Field | Acceptable Input Hints |
| --- | --- |
| `EmployeeId` | `employeeid`, `employee_id`, `employeeNumber`, `employee_number`, `workerid`, `personnelnumber`, `personnel_number` |
| `OBS` | `obs`, `oid`, `orgpath`, `org_path`, `costcenterpath`, `departmentpath`, `divisionpath`, `extensionattribute10` |
| `Mail` | `mail`, `email`, `emailaddress`, `mail_address`, `userprincipalname` |
| `ManagerMail` | `manager`, `manageremail`, `manager_mail`, `managerupn`, `supervisor` |
| `Title` | `title`, `jobtitle`, `job_title`, `position` |
| `Office` | `office`, `physicaldeliveryofficename`, `location`, `site` |

When the file is too ambiguous, ShareSurfer should stop and tell the user what it needs:

```text
ShareSurfer could not identify a stable join key.

Please provide at least one of these columns:
- EmployeeId
- SamAccountName
- UserPrincipalName
- Mail

For best owner and OBS routing, also provide:
- OBS
- BusinessUnit
- ManagerMail
```

### Proposed Commands

The exact names can change, but the workflow should feel like this:

```powershell
# Inspect a CSV and tell the user whether ShareSurfer can understand it.
Test-ShareSurferOwnershipSource -Path C:\ShareSurfer\inputs\hr-obs.csv

# Interview the admin and create a reusable header mapping profile.
New-ShareSurferOwnershipMappingProfile `
  -Path C:\ShareSurfer\inputs\hr-obs.csv `
  -OutputPath C:\ShareSurfer\inputs\hr-obs.mapping.json

# Normalize the source into ShareSurfer's canonical ownership model.
Import-ShareSurferOwnershipSource `
  -Path C:\ShareSurfer\inputs\hr-obs.csv `
  -MappingProfilePath C:\ShareSurfer\inputs\hr-obs.mapping.json `
  -OutputPath C:\ShareSurfer\inputs\normalized-ownership.csv

# Build or refine owner mappings from admin interview answers.
New-ShareSurferOwnerMappingDraft `
  -ExportPath C:\ShareSurfer\outputs\scan-001 `
  -OutputPath C:\ShareSurfer\inputs\owner-mapping-draft.csv
```

This keeps the workflow transparent. ShareSurfer can help the admin fit unexpected CSVs into the model, but the operator always sees the mapping and can correct it before it affects reporting.

## Collector Hardening and Operator Ergonomics

The collector should keep improving in locked-down environments:

- Stronger protocol decision tree: CIM first, Native SMB/RPC fallback, UNC path walk, and partial evidence states.
- Better console progress while scanning.
- Resume or checkpoint behavior for large scans.
- More obvious "running, not hung" logging.
- Preflight command that tells the operator what will and will not work before a full scan.
- Better explanation of non-admin and non-elevated PowerShell limits.
- Clearer Samba and non-Windows SMB expectation setting.
- Optional sampling mode for first-pass discovery.

The main goal is to reduce field confusion. Operators should understand whether ShareSurfer is blocked, partially successful, or still collecting.

## Release Trust and Distribution

Once the dashboard package path stabilizes, release trust becomes more important:

- Signed PowerShell scripts.
- Signed release packages or signed checksums.
- Optional signed WebView2 dashboard viewer.
- Release manifest verification.
- Clear separation between developer package and operator package if needed.
- Preserve the no-internet, no-npm, no-server review path for release users.

This should not outrun the product experience. Signing and a viewer make the most sense after the static dashboard package is stable.

## What Not To Do Yet

ShareSurfer should not jump directly into permissions-changing remediation, AI-generated summaries, or cloud-dependent review features.

Those may be useful later, but they add risk and complexity. The near-term advantage is trustworthy evidence, owner routing, explainable migration grouping, and a dashboard that helps people make decisions.

## Best Next Slice

The highest-impact next implementation slice is:

**Add Evidence Confidence and Collection Completeness Rollups**

Recommended deliverables:

- Add confidence rows or fields from existing scan errors, scan events, collection provider state, and manifest data.
- Show "Can we trust this scan?" in the dashboard overview.
- Add per-share and per-path confidence badges.
- Surface access denied, unauthorized operation, missing or broken SID, descriptor unavailable, descriptor parse failure, and partial-data reasons.
- Update quickstart and troubleshooting documentation.
- Publish a new prerelease after validation.

This unlocks safer owner review and safer Migration Discovery. Once ShareSurfer can clearly say what it proved and what it could not prove, every other view becomes more credible.

