# Normalized Ownership Enrichment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make normalized ownership import data a first-class ShareSurfer pre-scan enrichment source, export dataset, and standalone dashboard view.

**Architecture:** Add a PowerShell 5.1-friendly pre-scan enrichment command that can ingest one or more CSV files, resolve headers, merge partial ownership facts, optionally enrich matching AD accounts by employee identifier, skip forbidden OUs, and write reusable CSV/profile/command artifacts. Keep scan collection read-only, make enriched ownership data additive to the existing inventory/export model, and let the standalone dashboard load the new CSV as an optional evidence table.

**Tech Stack:** PowerShell 5.1 module code, ActiveDirectory module with .NET LDAP fallback where practical, CSV exports, React/Vite standalone dashboard schema, existing ShareSurfer test harness.

**Tracking Issue:** #227

**Implementation Status:** Completed and validated in branch `codex/normalized-ownership-enrichment`. The detailed checklist below is preserved as the execution record for the issue-first slice.

---

## File Structure

- Modify `src/ShareSurfer/Public/Import-ShareSurferOwnershipSource.ps1`
  - Add multi-source support, AD enrichment switches, forbidden OU parameters, and enriched output metadata.
- Create `src/ShareSurfer/Public/Join-ShareSurferOwnershipSources.ps1`
  - Operator-friendly command for multi-CSV interview/enrichment that can run before a scan.
- Create `src/ShareSurfer/Private/Get-ShareSurferDirectoryIdentityByEmployee.ps1`
  - EmployeeID/EmployeeNumber AD lookup with forbidden OU filtering and ActiveDirectory/LDAP modes.
- Create `src/ShareSurfer/Private/Get-ShareSurferDirectoryOrganizationalUnits.ps1`
  - OU listing helper used by interactive selection and tests.
- Modify `src/ShareSurfer/Private/Get-ShareSurferOwnershipSourceMap.ps1`
  - Add merge helpers, source-column provenance helpers, reusable command generation for the new workflow, and canonical enriched ownership field definitions.
- Modify `src/ShareSurfer/Public/Invoke-ShareSurferScan.ps1`
  - Add an optional `-OwnershipEnrichmentPath` parameter and attach rows to inventory.
- Modify `src/ShareSurfer/Private/Export-ShareSurferInventory.ps1`
  - Export `ownership_enrichment.csv`.
- Modify `src/ShareSurfer/Private/Get-ShareSurferExportSchema.ps1`
  - Add the new CSV schema.
- Modify `scripts/New-ShareSurferStandaloneDashboard.ps1`
  - Add optional schema support for `ownership_enrichment.csv`.
- Modify `interface/standalone-dashboard/src/data/schema.ts`
  - Add optional `ownership_enrichment` dataset and human label.
- Modify `interface/standalone-dashboard/src/data/deriveDashboard.ts`
  - Include the dataset in raw evidence and summary signals without making it required.
- Modify `interface/standalone-dashboard/src/data/fixtures.ts`
  - Add small realistic rows for dashboard smoke coverage.
- Modify `tests/Invoke-ShareSurferTests.ps1`
  - Add focused tests for merge, AD employee lookup, forbidden OU exclusion, export schema, reusable command output, and dashboard script schema.
- Modify `README.md`, `docs/admin-ownership-import.md`, and `docs/ownership-csv-ingest-quick-reference.md`
  - Explain the new pre-scan workflow, field meaning, forbidden OU behavior, reusable rerun files, and dashboard output.

---

## Task 1: Multi-Source Ownership Merge Core

**Files:**
- Modify `src/ShareSurfer/Private/Get-ShareSurferOwnershipSourceMap.ps1`
- Test in `tests/Invoke-ShareSurferTests.ps1`

- [ ] Add canonical fields for enriched ownership rows:
  - `OwnershipKey`
  - `MatchStatus`
  - `MatchMethod`
  - `SourcePaths`
  - `SourceRowNumbers`
  - `EmployeeId`
  - `EmployeeNumber`
  - `SamAccountName`
  - `UserPrincipalName`
  - `Mail`
  - `DisplayName`
  - `Title`
  - `Office`
  - `Department`
  - `Company`
  - `Manager`
  - `ManagerLevel1`
  - `ManagerLevel2`
  - `ManagerLevel3`
  - `ManagerLevel1Raw`
  - `ManagerLevel2Raw`
  - `ManagerLevel3Raw`
  - `OBS`
  - `AdObsPath`
  - `ObsAttribute`
  - `BusinessUnit`
  - `DataOwner`
  - `OwnerMail`
  - `Project`
  - `ProjectCode`
  - `AccountEnabled`
  - `DistinguishedName`
  - `ForbiddenOuMatched`
  - `PotentialServiceAccount`
  - `ImportWarnings`
- [ ] Add `Project` and `ProjectCode` to ownership header definitions with common synonyms.
- [ ] Implement a helper that imports multiple CSVs using existing header-map logic and merges rows by the best available key:
  - EmployeeId first.
  - EmployeeNumber second.
  - SamAccountName, UPN, or Mail when employee identifiers are missing.
  - Source-only rows are kept with `MatchStatus=SourceOnly`.
- [ ] Preserve non-empty facts from later files only when the existing value is empty, except source provenance fields which should append.
- [ ] Add tests with two CSV fixtures:
  - one file containing `EmployeeID,OBS,ProjectCode`;
  - another containing `EmployeeID,DisplayName,Mail`;
  - expected merged row includes both OBS/project and person fields.

## Task 2: EmployeeID-to-AD Enrichment and Forbidden OUs

**Files:**
- Create `src/ShareSurfer/Private/Get-ShareSurferDirectoryIdentityByEmployee.ps1`
- Create `src/ShareSurfer/Private/Get-ShareSurferDirectoryOrganizationalUnits.ps1`
- Modify `src/ShareSurfer/Private/Get-ShareSurferOwnershipSourceMap.ps1`
- Test in `tests/Invoke-ShareSurferTests.ps1`

- [ ] Implement `Get-ShareSurferDirectoryIdentityByEmployee` with parameters:
  - `-EmployeeId`
  - `-EmployeeNumber`
  - `-ObsAttribute`
  - `-AdLookupMode`
  - `-ForbiddenOu`
- [ ] ActiveDirectory mode should use `Get-ADUser -LDAPFilter` against `employeeID` or `employeeNumber` and request existing identity properties.
- [ ] LDAP fallback should use `System.DirectoryServices.DirectorySearcher` with escaped filters.
- [ ] If a result DN is under any forbidden OU DN, skip it and return a clear skipped result state.
- [ ] If multiple non-forbidden AD accounts match, keep the row and set `MatchStatus=Ambiguous`.
- [ ] If exactly one account matches, fill empty fields from AD while preserving source OBS/project/business facts.
- [ ] Implement OU listing helper that returns DN, name, canonical-ish path, and depth.
- [ ] Add tests that mock `Get-ADUser` results under allowed and forbidden OUs.

## Task 3: Operator Command and Interactive Pickers

**Files:**
- Create `src/ShareSurfer/Public/Join-ShareSurferOwnershipSources.ps1`
- Modify `src/ShareSurfer/Public/Import-ShareSurferOwnershipSource.ps1`
- Modify `src/ShareSurfer/Private/Get-ShareSurferOwnershipSourceMap.ps1`
- Test in `tests/Invoke-ShareSurferTests.ps1`

- [ ] Add `Join-ShareSurferOwnershipSources` with parameters:
  - `-Path <string[]>`
  - `-SourceFolder`
  - `-OutputPath`
  - `-MappingProfilePath <string[]>`
  - `-ObsHeader`
  - `-ObsAttribute`
  - `-AdLookupMode`
  - `-ForbiddenOu <string[]>`
  - `-Interactive`
  - `-ReusableCommandPath`
  - `-Force`
- [ ] In interactive mode, show CSV candidates from `-SourceFolder`, let the operator choose one or more by number/comma/range/all, and explain what will be imported.
- [ ] In interactive mode, list OUs from AD/LDAP and let the operator choose forbidden OUs by number/comma/range/none.
- [ ] Reuse existing header interview behavior where profiles are missing or incomplete.
- [ ] Write `ownership-enrichment-rerun.ps1` with the selected CSVs, profiles, OBS attribute, forbidden OUs, and output path.
- [ ] Keep `Import-ShareSurferOwnershipSource` backward compatible for single-file normalization.

## Task 4: Scan/Export/Dashboard Wiring

**Files:**
- Modify `src/ShareSurfer/Public/Invoke-ShareSurferScan.ps1`
- Modify `src/ShareSurfer/Private/Export-ShareSurferInventory.ps1`
- Modify `src/ShareSurfer/Private/Get-ShareSurferExportSchema.ps1`
- Modify `scripts/New-ShareSurferStandaloneDashboard.ps1`
- Modify `interface/standalone-dashboard/src/data/schema.ts`
- Modify `interface/standalone-dashboard/src/data/deriveDashboard.ts`
- Modify `interface/standalone-dashboard/src/data/fixtures.ts`
- Test in `tests/Invoke-ShareSurferTests.ps1` and dashboard tests

- [ ] Add `-OwnershipEnrichmentPath` to `Invoke-ShareSurferScan`.
- [ ] Load the enriched CSV into inventory without making it mandatory.
- [ ] Export it as `ownership_enrichment.csv`.
- [ ] Add the CSV to export schema and standalone dashboard schema as optional evidence.
- [ ] Dashboard raw evidence should show the dataset with label `Ownership enrichment`.
- [ ] Dashboard summary should surface counts for matched, ambiguous, skipped-forbidden-OU, source-only, and potential service account rows when present.
- [ ] Existing exports without the file must keep working.

## Task 5: Documentation and Examples

**Files:**
- Modify `README.md`
- Modify `docs/admin-ownership-import.md`
- Modify `docs/ownership-csv-ingest-quick-reference.md`

- [ ] Explain `normalized-ownership.csv` versus `ownership_enrichment.csv`.
- [ ] Document when to run the enrichment before scanning.
- [ ] Explain each important field in friendly language.
- [ ] Show multi-CSV examples:
  - HR file with employee IDs and OBS.
  - Project file with project codes and OBS.
  - directory enrichment filling AD attributes.
- [ ] Document forbidden OUs with examples such as disabled-account archives, service account OUs, and staging/test OUs.
- [ ] Show how to use the enriched CSV in `Invoke-ShareSurferScan`.
- [ ] Show how the standalone dashboard uses the exported dataset.

## Task 6: Validation, Issue Comments, and Release

**Files:**
- No source file ownership; closeout only.

- [ ] Run parser/import checks for touched PowerShell.
- [ ] Run `pwsh -NoLogo -NoProfile -File tests/Invoke-ShareSurferTests.ps1`.
- [ ] Run dashboard tests/build if dashboard files changed.
- [ ] Commit with `(#227)` in the message.
- [ ] Post issue #227 comment using a Markdown body file with commit SHA, changed behavior, validation, and follow-up.
- [ ] Push branch and open/update PR.
- [ ] Prepare a fresh prerelease after validation.

---

## Subagent Goals

### Subagent A: Dashboard Schema Sidecar

Goal: Update the standalone dashboard data schema and raw evidence handling so `ownership_enrichment.csv` is optional, labeled, fixture-backed, and does not break older export packages.

Owned files:
- `interface/standalone-dashboard/src/data/schema.ts`
- `interface/standalone-dashboard/src/data/deriveDashboard.ts`
- `interface/standalone-dashboard/src/data/fixtures.ts`
- dashboard tests if needed

### Subagent B: Documentation Sidecar

Goal: Update owner-import documentation so a first-time admin understands when to run the new enrichment workflow, what each field means, how forbidden OUs work, and how the output feeds scan/dashboard review.

Owned files:
- `README.md`
- `docs/admin-ownership-import.md`
- `docs/ownership-csv-ingest-quick-reference.md`

### Subagent C: Review/Validation Sidecar

Goal: After implementation, review issue #227 requirements against the branch, look for missing acceptance criteria, and run/inspect the fastest relevant validation gates that do not require the Windows lab.

Owned files:
- No source ownership unless explicitly asked to patch small validation fixes.
