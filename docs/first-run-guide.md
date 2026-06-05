# ShareSurfer First-Run Guide

This guide is for a first-time ShareSurfer operator. You do not need to be a senior Windows, Active Directory, or file-share engineer to get a useful first scan. Follow the steps in order and keep the raw export inside your trusted environment.

## What ShareSurfer Does

ShareSurfer reads Windows file-share information and turns it into CSV files and an offline report.

It helps answer plain questions:

- Which shares and folders did we scan?
- Who has access at the share level?
- Who has access at the folder or file level?
- Where was inheritance broken?
- Which permissions were added deep in a folder tree?
- Which paths may create migration work?
- Which data owner, manager chain, or business unit should review the access?
- Which support data can be shared safely after redaction?

ShareSurfer does not make access changes. It collects, normalizes, reports, and redacts evidence.

## Prerequisites

Use a Windows collector machine with:

- Windows PowerShell 5.1.
- The ShareSurfer repository copied to a local folder.
- Permission to read the target share, files, folders, owners, and ACLs.
- Permission to read share-level permissions when scanning Windows SMB shares.
- Directory read access if you want user, group, manager, employee, and OBS enrichment.
- A local output folder with enough free space for CSVs, logs, reports, and support bundles.

For AD enrichment, record the OBS attribute before scanning. The default is `extensionAttribute10`, but your environment may use another extension attribute. Some labs do not have Exchange-style extension attributes in the AD schema; in that case, choose an attribute that exists on both users and groups, such as `info`, and pass it with `-ObsAttribute`.

For lab validation, use the designated Windows/AD lab host directly.

## Step 1: Open PowerShell

Open Windows PowerShell 5.1 as the account that will run the scan.

Check the version:

```powershell
$PSVersionTable.PSVersion
```

The major version should be `5`.

Go to the repository folder:

```powershell
Set-Location C:\Path\To\ShareSurfer
```

Import the module:

```powershell
Import-Module .\src\ShareSurfer\ShareSurfer.psd1 -Force
```

Confirm the commands are available:

```powershell
Get-Command -Module ShareSurfer
```

## Step 2: Choose Scan Targets

Start with one small or medium share before scanning a large file server.

Good first targets:

- A known business share such as `\\files01\Finance`.
- A share with a known data owner.
- A share where you have read permission across most folders.
- A share that has a mix of normal and unusual permissions.

Avoid for the first run:

- A whole file server with hundreds of shares.
- A share where your account cannot read many folders.
- A production-critical path you do not understand yet.

Use a UNC path when you already know the share:

```powershell
$targetPath = '\\files01\Finance'
```

Use computer and share name when you want ShareSurfer to query SMB share metadata:

```powershell
$computerName = 'files01'
$shareName = 'Finance'
```

## Step 3: Prepare Output Folders

Use a new output folder for every scan. A dated folder keeps results easy to compare.

```powershell
$exportPath = 'C:\ShareSurfer\exports\scan-2026-06-04-finance'
New-Item -ItemType Directory -Path $exportPath -Force
```

Keep raw exports internal. They can contain real paths, server names, user names, group names, employee IDs, manager names, and OBS values.

## Step 4: Run the Collector

For a first scan by UNC path:

```powershell
Invoke-ShareSurferScan `
  -TargetPath $targetPath `
  -OutputPath $exportPath `
  -OperationalPathLengthThreshold 256 `
  -ExplicitAceDepthThreshold 2 `
  -GroupExpansionMaxDepth 5 `
  -AdLookupMode Auto `
  -ObsAttribute 'extensionAttribute10'
```

For a first scan by SMB computer and share name:

```powershell
Invoke-ShareSurferScan `
  -ComputerName $computerName `
  -ShareName $shareName `
  -OutputPath $exportPath `
  -IncludeFiles `
  -OperationalPathLengthThreshold 256 `
  -ExplicitAceDepthThreshold 2 `
  -GroupExpansionMaxDepth 5 `
  -AdLookupMode Auto `
  -ObsAttribute 'extensionAttribute10'
```

Use `-IncludeFiles` when you need file-level evidence, not only folder-level evidence. File-level scans can take longer on large shares.

Use `-AdLookupMode Auto` for normal collection. It tries the best available directory lookup path. Use `DirectoryOnly` only for imported test data.

## Step 5: Validate the Export

Run validation after every scan:

```powershell
$validation = Test-ShareSurferExport -ExportPath $exportPath
$validation
```

If `IsValid` is `True`, the expected CSV set exists and has the required columns.

If `IsValid` is `False`, look at:

- `MissingFiles`
- `SchemaErrors`
- `FileResults`

Validation does not prove that the scan reached every file. It proves the export structure is usable.

## Step 6: Understand Outputs

The most important CSVs for a first review are:

| File | First thing to look for |
| --- | --- |
| `scan_manifest.csv` | Scan settings, OBS attribute, thresholds, lookup mode, and whether file objects were included. |
| `shares.csv` | Which shares were scanned and whether data was partial. Partial rows may mean a target path could not be resolved, share-level permissions were unavailable, folder enumeration failed, or ACL reads failed for part of the tree. |
| `items.csv` | Folders and files found under each share. |
| `share_permissions.csv` | The share-level access gate. |
| `acl_entries.csv` | Folder and file permissions. |
| `findings.csv` | Long-path warnings, broken inheritance, and deep explicit ACEs. |
| `conflicts.csv` | Share-vs-NTFS access mismatches. |
| `identities.csv` | User and group details such as employee and OBS values. |
| `group_edges.csv` | Expanded group membership paths. |
| `org_chains.csv` | Manager and manager's manager context. |
| `owner_mappings.csv` | Business owner and business unit rules. |
| `owner_risk_pivots.csv` | Owner/business-unit review queue with mapped item counts, direct identities, direct groups, expanded members, findings, conflicts, partial shares, and risk level. |
| `related_data_areas.csv` | Migration discovery rows for like-owned shares, folders, and files that should be reviewed together before migration planning. |
| `owner_review_packets.csv` | Plain-language owner review packets showing why review is needed, where to start, and the suggested next action. |
| `identities.csv` | Users, groups, manager fields, OBS values, and extra directory clues such as mail, department, title, company, office, account status, and distinguished name. |
| `permissioned_groups.csv` | Groups that directly grant share or folder/file access, including assignment counts, rights, expanded members, and expansion health. |

Start with `owner_review_packets.csv`, `owner_risk_pivots.csv`, `related_data_areas.csv`, `permissioned_groups.csv`, `findings.csv`, and `conflicts.csv`, then use the report to pivot by business unit, owner, manager, OBS path, and group.

## Step 7: Generate the Offline Report

Create the report:

```powershell
ConvertTo-ShareSurferReport -ExportPath $exportPath -OutputPath "$exportPath\report.html"
```

Open `report.html` from the export folder. It does not need a server or internet access.

Example dashboard overview:

![ShareSurfer dashboard overview](visuals/report-dashboard-overview.png)

Example review workbench:

![ShareSurfer review workbench](visuals/report-dashboard-workbench.png)

Example findings drilldown:

![ShareSurfer findings drilldown](visuals/report-dashboard-findings.png)

Example migration discovery view:

![ShareSurfer migration discovery view](visuals/report-dashboard-migration.png)

Use the dashboard to review:

- Executive summary cards.
- What Needs Review First owner review queue for business-unit and data-owner review packets.
- Review Workbench snapshot for the selected business unit, data owner, or risk level.
- Access Model view showing share gate permissions beside file/folder permissions.
- Migration Discovery rows showing related data areas that should be kept together during migration planning.
- Direct Access Review table showing directly assigned identities, share-gate assignments, NTFS assignments, OBS context, and expanded group-member counts.
- Priority actions.
- Visual risk rollups. Click a bar to filter the dashboard to that finding type, conflict type, owner, or business unit.
- Dashboard-level search, business-unit filters, data-owner filters, review-risk filters, and view tabs.
- Business-unit and owner pivots, including mapped item counts, finding counts, conflict counts, partial-share counts, and a simple review risk level.
- Finding rollups.
- Conflict rollups.
- Permissioned Group Review rows showing assigned security groups, share and NTFS assignment counts, OBS context, rights, and expanded membership size. Select a group row to focus the Group Browser on that expanded membership path.
- Diagnostics view for partial shares, collection errors, and scan events.
- Org-chain rollups.
- Inheritance breaks.
- Explicit permissions deeper than level 2.
- Group expansion browsing.
- Raw Evidence Tables when an operator needs to browse the underlying CSV-shaped rows inside the offline report. This is secondary evidence browsing, not the first place to send a business owner.

Path note: Microsoft documents Azure Files limits of 255-character path components and 2,048-character full paths. ShareSurfer's default warning for full paths over 256 characters is an operational migration policy warning, not a claim that Azure Files cannot store the path.

## Step 8: Create a Redacted Support Bundle

Only create a support bundle after the raw export validates.

```powershell
New-ShareSurferSupportBundle `
  -ExportPath $exportPath `
  -OutputPath 'C:\ShareSurfer\support\scan-2026-06-04-finance-redacted' `
  -RedactionMode StableToken `
  -RedactionSalt 'case-2026-06-04-finance' `
  -IncludeReport
```

Validate the redacted bundle:

```powershell
Test-ShareSurferExport -ExportPath 'C:\ShareSurfer\support\scan-2026-06-04-finance-redacted'
```

Before sharing the bundle, search it for real domain names, server names, share names, user names, group names, and business unit names. The bundle should contain stable tokens such as `ID-000001`, not raw sensitive values.

## Step 9: What To Do Next

For a first business review:

1. Give the report to the expected data owner or business unit lead.
2. Ask them to confirm the owner mapping and business unit mapping.
3. Review high-severity conflicts first.
4. Review broken inheritance and deep explicit ACEs.
5. Review long-path operational warnings before migration planning.
6. Expand assigned security groups and confirm whether membership matches the owner's expectation.
7. Repeat the scan after access cleanup or owner mapping changes.

For a migration review:

1. Separate hard platform limits from operational migration policy warnings.
2. Treat share-level permissions and NTFS permissions as two gates that both matter.
3. Use owner/business-unit pivots to route remediation work.
4. Keep evidence from the same export folder together.

## Common First-Run Problems

| Symptom | What to check |
| --- | --- |
| The scan shows partial data | Open `shares.csv` and read `PartialReason`. Confirm the target path exists and that your account can read share metadata, folders, files, and ACLs, then check `findings.csv` for `CollectionError` rows. |
| Identity details are missing | Confirm directory read access and the selected `-AdLookupMode`. |
| OBS values are blank | Confirm the correct `-ObsAttribute`, such as `extensionAttribute10`. If that attribute does not exist in your AD schema, use an existing user/group attribute such as `info`. |
| Group expansion is incomplete | Increase `-GroupExpansionMaxDepth` or check for directory lookup errors. |
| The report is sparse | Confirm `Test-ShareSurferExport` passed and the scan target contained data. |
| A support bundle still shows real names | Do not share it. Regenerate with redaction and inspect again. |

## Quick Command Set

```powershell
Import-Module .\src\ShareSurfer\ShareSurfer.psd1 -Force

$exportPath = 'C:\ShareSurfer\exports\scan-2026-06-04-finance'

Invoke-ShareSurferScan `
  -TargetPath '\\files01\Finance' `
  -OutputPath $exportPath `
  -OperationalPathLengthThreshold 256 `
  -ExplicitAceDepthThreshold 2 `
  -GroupExpansionMaxDepth 5 `
  -AdLookupMode Auto `
  -ObsAttribute 'extensionAttribute10'

Test-ShareSurferExport -ExportPath $exportPath
ConvertTo-ShareSurferReport -ExportPath $exportPath -OutputPath "$exportPath\report.html"

New-ShareSurferSupportBundle `
  -ExportPath $exportPath `
  -OutputPath 'C:\ShareSurfer\support\scan-2026-06-04-finance-redacted' `
  -RedactionMode StableToken `
  -RedactionSalt 'case-2026-06-04-finance' `
  -IncludeReport
```
