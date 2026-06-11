# Business Review Handoff

Use this guide after a ShareSurfer scan validates and before you ask a data owner or business unit to review access. It is written for the operator who needs to turn technical evidence into a clear review request.

## What To Send

For most business reviewers, send one of these:

- `report.html` from the validated export folder.
- A packaged standalone dashboard folder, opened from `standalone-dashboard\index.html`.
- `owner_review_packets.csv` when the reviewer prefers Excel.
- A short note that names the scan date, target share or data area, owner mapping used, and any partial-data caveats.

Do not send raw CSVs by default. Raw exports can contain real paths, server names, users, groups, employee identifiers, manager chains, and OBS values. Keep raw CSVs for operators and analysts who need evidence detail.

## Do Not Hand Off Yet If

Pause before owner review when:

- `Test-ShareSurferExport` failed.
- `shares.csv` shows `PartialData=True` for the area the owner is being asked to approve and the caveat has not been reviewed.
- `collection_errors.csv` has high-severity access denied, unauthorized operation, target resolution, ACL read, owner read, or share-permission collection failures.
- `owner_review_packets.csv` has blank or incorrect owner/business-unit values.
- The wrong `-ObsAttribute`, manager format, discounted principals list, or owner mapping file was used.
- The report or standalone dashboard opens a template screen instead of the real scan dataset.

Use [First-run troubleshooting](first-run-troubleshooting.md) when any of those are true.

## Explain These Terms Up Front

| Term | Plain explanation |
| --- | --- |
| Owner | The mapped business or data-review owner. This is separate from the Windows/NTFS owner value on a file or folder. |
| Share gate | The share-level access layer. A user still needs folder or file permission after passing this gate. |
| File/folder permissions | Permissions inside the share that can allow, limit, or deny access. |
| Partial data | ShareSurfer could not prove every expected detail. Owners should not treat that area as fully verified until the caveat is understood. |
| Broken/Missing SID | A permission references an identity ShareSurfer could not resolve. It may be a deleted account, broken trust reference, stale ACE, or lookup gap. |
| No owner | ShareSurfer did not collect a usable NTFS owner value. It does not prove the file has no real Windows owner. |
| Potential service account | A user account with no OBS value and no employee identifier collected. It needs review; it is not automatically confirmed as a service account. |
| Discounted access principal | A broad admin, HelpDesk, scanner, backup, or platform identity that remains visible in evidence but does not drive Migration Discovery relatedness. |

## Suggested Owner Review Request

Copy and adapt this for the reviewer:

```text
Please review the attached ShareSurfer report for the data area below.

Data area:
Mapped owner/business unit:
Scan date:
Report generated:

Please confirm:
- Whether you are the right owner or who should be.
- Whether the listed groups and direct identities are expected.
- Whether any access conflicts, broken inheritance, deep explicit permissions, Broken/Missing SID rows, or potential service-account rows need cleanup.
- Whether the related data areas should be kept together for migration planning.

This report is read-only evidence. It does not change permissions and it is not an approval record by itself.
```

## What To Ask the Owner

Ask owners to answer practical questions:

- Are you the right reviewer for this data area?
- Are these shares, folders, or files part of the same business process?
- Which groups should keep access?
- Which groups or direct identities look unexpected?
- Are any potential service accounts real service accounts?
- Should any Broken/Missing SID rows be sent to the directory or file-share team for cleanup review?
- Should any related data areas move together during migration planning?
- Should the operator rerun the scan after cleanup or mapping changes?

## What To Keep With the Review Record

Archive these together internally:

- Raw export folder.
- `report.html`.
- Packaged standalone dashboard folder, if one was used.
- Owner response or ticket link.
- Any updated `owner-mapping.csv` or `discounted-principals.csv`.
- Notes about partial data, collection errors, or rerun decisions.

If the review needs outside support, create a redacted support bundle instead of attaching the raw export.
