# ShareSurfer Workflow Guide

This guide explains the three main ShareSurfer operating flows shown in the README. It is written for first-time operators, business reviewers, and managers who need to understand what happens before they open the dashboard.

ShareSurfer is read-only. It collects evidence, validates the export set, and presents review views. It does not change permissions, approve access, migrate data, or fix broken ACLs.

## First Scan to Owner Review

![First scan to owner review workflow](visuals/readme-flow-guides/first-scan-owner-review.png)

Use this flow when you want one business owner or business unit to understand a share for the first time.

| Step | What happens | Operator action | Output to check |
| --- | --- | --- | --- |
| 1. Collect | ShareSurfer reads share permissions, NTFS ACLs, owner values, inheritance state, identities, groups, and org context. | Run `Invoke-ShareSurferScan` from Windows PowerShell 5.1. Use `-ObsAttribute` for the directory attribute that stores your OBS/OID path. | Timestamped console progress, `scan_manifest.csv`, `scan_events.csv`, and the normalized CSV set. |
| 2. Validate | The export folder is checked for required files, row counts, schema health, partial data, and critical collection blocks. | Run `Test-ShareSurferExport -ExportPath <path>`. | Validation pass/fail output and any warnings that need operator review. |
| 3. Report | The CSVs become a single offline HTML report and, optionally, a standalone dashboard folder. | Run `ConvertTo-ShareSurferReport`, then package the standalone dashboard if needed. | `report.html` and optional `standalone-dashboard\index.html`. |
| 4. Review | Owners review why their area was flagged, which paths matter, which groups grant access, and which findings block confidence. | Start with the dashboard review queue and `owner_review_packets.csv`. | Owner packets, related data areas, findings, conflicts, and group review views. |
| 5. Rerun | After cleanup, ShareSurfer is run again to prove the new state. | Rerun the same scan command and compare findings. | Lower risk counts, fewer partial-data rows, cleaner access conflicts, and updated owner packets. |

Fast starter command:

```powershell
$releaseRoot = 'C:\ShareSurfer\ShareSurfer-0.1.0-pre.9'
$exportPath = 'C:\ShareSurfer\exports\finance-001'

Import-Module "$releaseRoot\src\ShareSurfer\ShareSurfer.psd1" -Force

Invoke-ShareSurferScan `
  -TargetPath '\\files01\Finance' `
  -OutputPath $exportPath `
  -ObsAttribute 'extensionAttribute10' `
  -ManagerIdentityFormat MailTo

Test-ShareSurferExport -ExportPath $exportPath
ConvertTo-ShareSurferReport -ExportPath $exportPath -OutputPath "$exportPath\report.html"
```

Go gate:

- `Test-ShareSurferExport` passes or has warnings the operator understands.
- `report.html` opens from disk.
- Owner mappings are good enough for the first review, or the owner gaps are documented.
- Broken or missing SIDs, access denied errors, and critical scan information blocks have been reviewed before sending the report to a business owner.

Stop gate:

- The scan has many access-denied paths or collection errors that hide the business area being reviewed.
- The selected `-ObsAttribute` does not exist in the environment or does not populate the intended org path.
- The report has no owner/business-unit context and the reviewer cannot tell why they received it.

## Locked-Down Collector to Dashboard Host

![Locked-down collector to dashboard host workflow](visuals/readme-flow-guides/locked-down-collector-dashboard-host.png)

Use this flow when the collector host is locked down, has no internet access, cannot install npm/browser tooling, or is not the right place for business review.

| Stage | What to do | Why it matters |
| --- | --- | --- |
| Collector host | Import the release module, scan the target, validate the CSV export, and generate `report.html`. | Keeps raw evidence close to the file-share environment and avoids requiring a dashboard workstation to have share access. |
| Validated package | Compress the export folder and record a SHA256 hash. | Gives the receiving team a simple integrity check and a known evidence boundary. |
| Dashboard host | Verify the hash, open `report.html`, or package the standalone dashboard from the validated export folder. | Lets reviewers use the richer dashboard without rescanning shares or installing development tools. |
| Support path | Create a redacted support bundle when data must leave trusted handling. | Avoids sharing raw names, paths, and identities in bug reports. |

Collector-side handoff command:

```powershell
$shareSurferRoot = 'C:\ShareSurfer\ShareSurfer-0.1.0-pre.9'
$exportPath = 'C:\ShareSurfer\exports\scan-001'
$handoffPath = 'C:\ShareSurfer\handoff\scan-001.zip'

Import-Module "$shareSurferRoot\src\ShareSurfer\ShareSurfer.psd1" -Force

Invoke-ShareSurferScan `
  -TargetPath '\\files01\Finance' `
  -OutputPath $exportPath `
  -ObsAttribute 'extensionAttribute10' `
  -ManagerIdentityFormat MailTo

Test-ShareSurferExport -ExportPath $exportPath
ConvertTo-ShareSurferReport -ExportPath $exportPath -OutputPath "$exportPath\report.html"
Compress-Archive -Path "$exportPath\*" -DestinationPath $handoffPath -Force
Get-FileHash -Algorithm SHA256 -Path $handoffPath
```

Dashboard-host command:

```powershell
$releaseRoot = 'C:\ShareSurfer\ShareSurfer-0.1.0-pre.9'
$exportPath = 'C:\ShareSurfer\received\scan-001'

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "$releaseRoot\scripts\New-ShareSurferStandaloneDashboard.ps1" `
  -ExportPath $exportPath `
  -OutputPath "$exportPath\standalone-dashboard" `
  -Force

Start-Process "$exportPath\standalone-dashboard\index.html"
```

Go gate:

- The dashboard host received the same ZIP hash the collector host recorded.
- The dashboard opens from local disk with no server, internet access, npm, Vite, or development workflow.
- Reviewers understand that the dashboard host is for reading evidence, not rescanning shares.

Stop gate:

- The transfer package was changed without a new hash.
- The dashboard host only has the release folder, not a real scan export folder.
- The report says collection was partial and the missing proof affects the review decision.

## Migration Discovery and Cleanup Planning

![Migration discovery and cleanup planning workflow](visuals/readme-flow-guides/migration-discovery-cleanup-planning.png)

Use this flow before planning a migration wave. The goal is to avoid moving one part of a business data area while leaving closely related shares or folders behind.

| Signal | What ShareSurfer uses | How to interpret it |
| --- | --- | --- |
| Owner and business unit | `owner_mappings.csv`, `owner_review_packets.csv`, and `owner_risk_pivots.csv`. | Areas with the same owner or business unit should usually be reviewed together. |
| OBS and manager chain | The runtime `-ObsAttribute`, manager levels, mail addresses, employee IDs, title, and office when available. | Areas that roll up to the same org path or managers may belong in the same migration discussion. |
| Path and naming patterns | Share names, folder names, path prefixes, and long-path warnings. | Similar path names can indicate related data, but they need owner confirmation. |
| Permission-bearing groups | Share permissions, ACL entries, group expansion, and discounted access principals. | Groups that grant access across several paths can reveal related areas, while discounted admin groups should not inflate relatedness. |
| Migration blockers | Share-vs-NTFS conflicts, broken inheritance, deep explicit ACEs, long paths, broken/missing SIDs, and access denied errors. | These findings do not always block migration, but they should be reviewed before a wave is approved. |

Review order:

1. Open the dashboard and start with **Migration Discovery**.
2. Pick a related data area by owner, business unit, OBS path, group overlap, or path pattern.
3. Review why the areas were grouped before treating the cluster as real.
4. Check conflicts, findings, partial-data warnings, and discounted access principals.
5. Confirm the owner and business unit before using the cluster for migration planning.

Go gate:

- The selected related data area has clear owner or business-unit evidence.
- Discounted principals have been used for broad HelpDesk/admin access groups so they stay visible without making unrelated shares appear related.
- Critical collection blocks have been reviewed and do not hide the relevant paths.

Stop gate:

- The cluster is only related by a broad admin group.
- The owner mapping is missing or obviously wrong.
- Access denied errors or missing share-level proof affect the paths being considered for migration.

## What To Send To Reviewers

For most first reviews, send:

- `report.html` or the packaged `standalone-dashboard` folder.
- `owner_review_packets.csv`.
- A short note naming the owner/business unit, the scan date, and whether the scan had partial-data warnings.
- The business review handoff wording from [business-review-handoff.md](business-review-handoff.md).

Do not send raw CSVs outside trusted handling unless your process allows it. Use [redacted support bundles](redacted-support-bundles.md) for support cases.
