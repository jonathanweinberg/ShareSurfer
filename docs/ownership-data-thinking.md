# Ownership Data Thinking Guide

Ownership data is almost never one-to-one. People have more than one account, sources disagree, paths nest, owners are often roles instead of rows, and everything changes over time.

Use this guide before you import HR, OBS, project, application, or owner CSVs. The commands tell ShareSurfer how to read files; this page helps you decide what the files really mean.

## Start With The Two Tracks

ShareSurfer has two related ownership tracks:

| Track | Main Question | Typical Files |
| --- | --- | --- |
| People | Who is this person or account? | HR CSV, OBS CSV, project CSV, AD lookup output, `ownership-enrichment.csv` |
| Paths | Who is accountable for this share or folder? | `owner-mapping.csv`, `owner-mapping-draft.csv`, scan `shares.csv` and `items.csv` |

`ownership-enrichment.csv` helps reviewers understand people, accounts, OBS, manager chains, projects, and service-account-like rows. `owner-mapping.csv` routes shares and folders to owners and business units. You usually need both, but they are not the same file.

## Define Owner Before Filling The CSV

For ShareSurfer, `Owner` should mean the business reviewer who can approve or reject access for the data area. It is not automatically the NTFS owner field, the server admin, HelpDesk, backup team, or scanner account.

Use `BusinessUnit` for the business area that should receive the review packet. Use notes or separate local tracking for technical contacts.

## People And Accounts Are Not One-to-One

Expect these cases:

- One employee may have a normal account, admin account, test account, and service account.
- A service account may have no employee ID, no employee number, and no OBS.
- Contractors may be in AD but not in HR.
- Disabled accounts and unresolved SIDs may still appear in ACLs.

Before importing, decide which account is the normal human account. Employee ID or employee number is usually the strongest join key.

Use `-ForbiddenOu` for OUs that should not become owner matches, such as disabled-account archives, service-account OUs, admin-account OUs, staging OUs, or test OUs.

## Sources Use Different Keys

One CSV might use `EmployeeId`, another might use email, and another might only have OBS or project code. Strong keys produce better joins:

1. `EmployeeId`
2. `EmployeeNumber`
3. `SamAccountName`
4. `UserPrincipalName`
5. `Mail`

If a source has only OBS/project/business-unit context, that can still be useful, but it is context, not a person match. Ask data providers to add employee ID whenever they can.

## Paths And Owners Are Not One-to-One

One owner can own many shares. One share can contain a project folder owned by another team. A broad pattern can accidentally catch sibling shares.

Good pattern habits:

- Start with share-level owner mapping.
- Refine to folders only when a reviewer says a subtree belongs somewhere else.
- Prefer boundary-safe patterns such as `\\files01\Finance\*`.
- Avoid sibling-prefix patterns such as `\\files01\Finance*`, which may also match `\\files01\FinanceArchive`.
- Run `Test-ShareSurferOwnerMapping` before scanning with a hand-edited mapping file.

`New-ShareSurferOwnerMappingDraft` creates boundary-safe draft patterns. Fill in `Owner` before using the draft as `-OwnerMappingPath`; fill `BusinessUnit` when you know it so the report can route review packets to the right business bucket. Blank `BusinessUnit` values are allowed but are shown as unmapped business-unit gaps.

## Treat Every File As A Snapshot

Record when each CSV was produced. HR may be current, the OBS extract may be old, and the scan may happen after a reorg.

Practical habits:

- Put dates in filenames, such as `hr-obs-2026-07-02.csv`.
- Keep `ownership-import.definition.json` with the input files.
- Rerun the saved import definition when HR or OBS refreshes.
- Treat old ownership data as a review clue, not proof.

## Groups Can Point To The Owner

ACLs often name groups, not people. Group names and membership can reveal the likely owner:

- `FS-Finance-AP-RW` probably belongs near Finance or Accounts Payable.
- A group whose members mostly share one department points to that business area.
- A group dominated by service accounts may point to an application owner instead of a people manager.

Use the dashboard group review and `permissioned_groups.csv` as evidence when filling `owner-mapping.csv`.

## Decide Coverage Targets Up Front

Do not wait until owner review to learn that the import was weak. Set expectations before the scan:

| Metric | Healthy First Pass |
| --- | --- |
| HR rows matched to AD | At least 85%, with the rest explainable |
| Ambiguous AD matches | Less than 1%, each one reviewed |
| Shares covered by owner mapping | 100% at share level before business signoff |
| Owner cells in `owner-mapping.csv` | 100% filled before using it in a scan |
| BusinessUnit cells in `owner-mapping.csv` | Fill when known; blanks are warning-level unmapped business-unit gaps |
| Potential service-account-like rows | Reviewed, not ignored |

If a number looks bad, fix it at the earliest step that can see it. A bad import fixed before scanning costs minutes. A bad owner packet discovered by a business reviewer costs trust.

## Quick Decision Table

| Situation | Best Next Step |
| --- | --- |
| One HR CSV with unusual headers | Run `Test-ShareSurferOwnershipSource`, then save a mapping profile. |
| HR file plus OBS or project context | Run `Join-ShareSurferOwnershipSources` and save the definition JSON. |
| CSV already says share to owner | Shape it as `Pattern,Owner,BusinessUnit`, then run `Test-ShareSurferOwnerMapping`. |
| No owner mapping exists yet | Scan once, run `New-ShareSurferOwnerMappingDraft`, fill the draft, validate it, then rerun with `-OwnerMappingPath`. |
| Service/admin OUs pollute AD matches | Use `-ForbiddenOu` during ownership enrichment. |
| Post-reorg or stale owners | Refresh CSVs, rerun the saved definition, and review changed owners before signoff. |
