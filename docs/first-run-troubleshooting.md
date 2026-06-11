# ShareSurfer First-Run Troubleshooting

Use this guide when a first scan finishes with warnings, looks sparse, or does not produce the dashboard/export result you expected. ShareSurfer is intentionally read-only. Most first-run problems are permission, target-selection, optional-input, or directory-lookup issues.

## Start Here

Open these files from the scan export folder first:

1. `scan_manifest.csv` to confirm the scan settings, OBS attribute, manager format, source mode, collection provider, and whether files were included.
2. `shares.csv` to see whether any share row has `PartialData=True` and what `PartialReason` says.
3. `collection_errors.csv` to see collection gaps such as access denied, share-permission collection unavailable, path resolution failure, ACL read failure, or folder enumeration failure.
4. `findings.csv` to see review signals such as `CollectionError`, `OwnerMetadataUnavailable`, `BrokenOrMissingSid`, `PotentialServiceAccount`, long paths, broken inheritance, and deep explicit ACEs.
5. `scan_events.csv` or `scan_events.jsonl` when you need the timeline of what the collector was doing.

Run this quick check from Windows PowerShell:

```powershell
$exportPath = 'C:\ShareSurfer\exports\scan-001'

Import-Csv "$exportPath\scan_manifest.csv" | Format-List
Import-Csv "$exportPath\shares.csv" | Where-Object { $_.PartialData -eq 'True' } | Format-Table ShareName,PartialReason -AutoSize
Import-Csv "$exportPath\collection_errors.csv" | Select-Object -First 20 | Format-Table ErrorType,Severity,Source,FullPath -AutoSize
Import-Csv "$exportPath\findings.csv" | Group-Object FindingType | Sort-Object Count -Descending | Format-Table Count,Name -AutoSize
```

Do not ask a business owner to approve a scan just because `Test-ShareSurferExport` says the CSV structure is valid. Validation proves the files and columns exist. It does not prove the collector reached every folder, file, share permission, owner value, or directory attribute.

## Common Problems

| Symptom | What it usually means | What to do next |
| --- | --- | --- |
| `Owner mapping file was not found` | `-OwnerMappingPath` was passed, but the CSV does not exist at that path. | Remove `-OwnerMappingPath` for the first run, or create `owner-mapping.csv` with `Pattern`, `Owner`, and `BusinessUnit`. Prefer the splatted examples in the first-run guide because they only pass optional paths when files exist. |
| `Discounted principals file was not found` | `-DiscountedPrincipalPath` was passed, but the CSV does not exist. | Remove the parameter until the file exists, or create `discounted-principals.csv` with at least an `Identity` column. |
| `Test-Path "$releaseRoot\src\ShareSurfer\ShareSurfer.psd1"` returns `False` | The release ZIP may have been extracted into a doubled folder such as `C:\ShareSurfer\ShareSurfer-0.1.0-pre.8\ShareSurfer-0.1.0-pre.8`. | Move the inner release folder up one level, or extract the ZIP again to `C:\ShareSurfer` so `$releaseRoot` points at `C:\ShareSurfer\ShareSurfer-0.1.0-pre.8`. |
| WinRM or CIM cannot connect | The target does not allow the remote management route used for share metadata and share permissions. | If scanning a Windows SMB share by `-ComputerName` and `-ShareName`, try `-SmbCollectionProvider NativeSmbRpc`. If that still cannot prove share permissions, treat share-level data as partial and review `collection_errors.csv`. |
| Access denied, unauthorized operation, or path denied | The collector account cannot read part of the share, ACL, owner, security descriptor, or open-file provider. | Rerun from an elevated Windows PowerShell prompt when allowed. Confirm the account can read the path and security details with normal Windows tools. Review Diagnostics before treating the scan as complete. |
| `PartialData=True` in `shares.csv` | ShareSurfer collected something, but one or more proof layers were incomplete. | Read `PartialReason`, then open `collection_errors.csv`, `findings.csv`, and the Diagnostics dashboard. Decide whether to rerun with better permissions or accept the result as partial evidence. |
| OBS values are blank | The selected `-ObsAttribute` is empty, not readable, or missing from the directory schema. | Confirm the attribute used by your directory. If Exchange-style extension attributes are not present, choose an attribute that exists on both users and groups, such as `info`, and rerun with `-ObsAttribute info`. |
| Manager fields show unexpected values | The manager display format may not match the reviewer use case, or directory data may be sparse. | Use the default `-ManagerIdentityFormat MailTo` for business review. Raw directory references are preserved in `ManagerLevel1Raw`, `ManagerLevel2Raw`, and `ManagerLevel3Raw` when available. |
| `Owner` is blank in `items.csv` | ShareSurfer did not receive a usable NTFS owner value for that item. | Look for `OwnerMetadataUnavailable` in `findings.csv`. Blank owner does not prove the file has no real Windows owner. It can mean owner read denied, unresolved owner SID, partial collection, or missing source metadata. |
| `BrokenOrMissingSid` appears | A permission referenced a SID or account name ShareSurfer could not resolve. | Ask the directory or file-share team to review deleted accounts, broken trusts, stale ACEs, or lookup gaps. Use the Broken/Missing SID dashboard filter when available. |
| `PotentialServiceAccount=True` appears | A user account had no OBS value and no `employeeID` or `employeeNumber` in collected directory data. | Treat this as a review flag, not proof. Ask the owner or directory team whether it is a service account or a human account with incomplete directory attributes. |
| `owner_review_packets.csv` is generic or sparse | Owner mapping rules were missing or too broad. | Update `owner-mapping.csv`, rerun the scan, then reopen `owner_review_packets.csv`, `owner_risk_pivots.csv`, and the report owner queue. |
| The report opens but shows very little | The export may be valid but nearly empty, or the wrong folder was used. | Confirm `shares.csv`, `items.csv`, `findings.csv`, and `owner_review_packets.csv` have rows. Make sure `ConvertTo-ShareSurferReport` used the intended `$exportPath`. |
| Dashboard host folder contains release files but no `scan_manifest.csv` | The ShareSurfer release package was opened instead of a scan export dataset. | Keep the release folder and scan export folder separate. The release contains tools and dashboard template assets. The export folder contains `scan_manifest.csv`, CSV evidence, `report.html`, and packaged dashboard output. |
| The standalone dashboard opens a template/onboarding screen | The release dashboard assets were opened directly instead of packaging a scan export. | Run `scripts\New-ShareSurferStandaloneDashboard.ps1 -ExportPath <validated export> -OutputPath <dashboard folder>`, then open the generated `standalone-dashboard\index.html`. |
| Support bundle still shows real names | The wrong folder was opened, redaction was not requested, or the bundle needs review before sharing. | Do not share it. Recreate the support bundle, inspect the output for real server names, paths, users, groups, business units, employee IDs, and manager names, then share only after review. |

## When To Rerun

Rerun the scan when:

- `collection_errors.csv` has high-severity access denied, unauthorized operation, path resolution, ACL read, owner read, or share-permission collection failures that affect the review scope.
- `shares.csv` has `PartialData=True` for the share a business owner is being asked to approve.
- The scan ran without an elevated/admin token and the missing proof layer matters to your review.
- The wrong `-ObsAttribute`, owner mapping, discounted principals list, manager format, or file-inclusion setting was used.
- `owner_review_packets.csv` cannot route the review to a meaningful owner or business unit.

## When To Hand Off To Reviewers

It is reasonable to hand off the report or standalone dashboard for business review when:

- `Test-ShareSurferExport` passes.
- You reviewed `shares.csv`, `collection_errors.csv`, `findings.csv`, and Diagnostics for partial-data warnings.
- Owner/business-unit mappings are good enough for the review audience.
- You can explain any partial data in plain language.
- Raw CSVs stay inside the trusted boundary unless your organization approved the transfer.

Give business reviewers the report or packaged standalone dashboard first. Keep raw CSVs available for operators who need evidence detail.

## When To Create a Redacted Support Bundle

Create a support bundle when you need outside help with a scan, parser, report, or dashboard behavior. Do this after the raw export validates:

```powershell
New-ShareSurferSupportBundle `
  -ExportPath $exportPath `
  -OutputPath 'C:\ShareSurfer\support\scan-001-redacted' `
  -RedactionMode StableToken `
  -RedactionSalt 'case-scan-001' `
  -IncludeReport
```

Before sharing, inspect the bundle for real domain names, server names, share names, full paths, user names, group names, business-unit names, employee identifiers, manager values, and OBS values.
