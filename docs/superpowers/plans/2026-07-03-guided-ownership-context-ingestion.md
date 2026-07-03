# Guided Ownership Context Ingestion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add optional ownership context graph ingestion so ShareSurfer can preserve project/OBS/path/group context from messy multi-CSV inputs without breaking existing ownership enrichment behavior.

**Architecture:** Extend the existing ownership ingestion pipeline additively. `Join-ShareSurferOwnershipSources` remains the public orchestrator, `Get-ShareSurferOwnershipSourceMap.ps1` owns schema/helper logic, `Invoke-ShareSurferScan` copies optional context graph CSVs into exports, and dashboard schema/raw evidence learns the optional datasets.

**Tech Stack:** PowerShell 5.1-compatible module code, CSV exports, existing vanilla/React standalone dashboard TypeScript schema, existing PowerShell test harness.

---

### Task 1: Add Ownership Context Graph Schemas

**Files:**
- Modify: `src/ShareSurfer/Private/Get-ShareSurferOwnershipSourceMap.ps1`
- Modify: `src/ShareSurfer/Private/Get-ShareSurferExportSchema.ps1`
- Test: `tests/Invoke-ShareSurferTests.ps1`

- [ ] Add canonical fields to `Get-ShareSurferOwnershipFieldDefinitions` for `ProjectDescription`, `GroupName`, and `PathPattern`.
- [ ] Add helper functions:
  - `Get-ShareSurferOwnershipSourceTypes`
  - `Get-ShareSurferOwnershipAuthorityLevels`
  - `Get-ShareSurferOwnershipContextColumns`
  - `Get-ShareSurferOwnershipRelationshipColumns`
  - `Get-ShareSurferOwnershipImportManifestColumns`
- [ ] Add optional export schema entries for:
  - `ownership_context.csv`
  - `ownership_relationships.csv`
  - `ownership_import_manifest.csv`
- [ ] Add a PowerShell test that imports the module and verifies the three new schema entries exist with expected columns.

### Task 2: Generate Context And Relationship Rows

**Files:**
- Modify: `src/ShareSurfer/Private/Get-ShareSurferOwnershipSourceMap.ps1`
- Modify: `src/ShareSurfer/Public/Join-ShareSurferOwnershipSources.ps1`
- Test: `tests/Invoke-ShareSurferTests.ps1`

- [ ] Add `New-ShareSurferOwnershipSourceProfile` to represent `SourcePath`, `SourceType`, `AuthorityLevel`, `PrimaryAnchor`, and source warnings.
- [ ] Add `New-ShareSurferOwnershipContextRows` that accepts a source row, field map, source profile, source path, and row number, and returns one or more context rows.
- [ ] Add `New-ShareSurferOwnershipRelationshipRows` that emits explainable relationships:
  - `ProjectCode` or `Project` to `OBS` as `BelongsTo`.
  - `OBS` to `BusinessUnit` as `PartOf`.
  - `OBS` to `DataOwner` as `ReviewedBy`.
  - `ProjectCode` or `Project` to `DataOwner` as `ReviewedBy`.
  - `PathPattern` to `DataOwner` as `ReviewedBy`.
  - `GroupName` to `OBS` as `RelatedTo`.
- [ ] Add `-IncludeContextGraph`, `-ContextOutputPath`, `-RelationshipOutputPath`, and `-ManifestOutputPath` to `Join-ShareSurferOwnershipSources`.
- [ ] When `-IncludeContextGraph` is supplied and output paths are blank, write the three context graph CSVs beside `-OutputPath`.
- [ ] Add a test using a project/OBS CSV with no employee IDs and assert:
  - `ownership-enrichment.csv` still exists.
  - `ownership_context.csv` includes `ProjectContext` and OBS context rows.
  - `ownership_relationships.csv` includes `Project -> OBS`, `OBS -> BusinessUnit`, and `OBS -> DataOwner`.
  - `ownership_import_manifest.csv` records row counts and mapped fields.

### Task 3: Persist Source Profiles In Definition JSON

**Files:**
- Modify: `src/ShareSurfer/Private/Get-ShareSurferOwnershipSourceMap.ps1`
- Modify: `src/ShareSurfer/Public/Join-ShareSurferOwnershipSources.ps1`
- Test: `tests/Invoke-ShareSurferTests.ps1`

- [ ] Extend `Export-ShareSurferOwnershipImportDefinition` to write `sourceProfiles`.
- [ ] Extend `Get-ShareSurferOwnershipImportDefinition` to read `sourceProfiles` while tolerating older definitions that do not have the property.
- [ ] On rerun from `-DefinitionPath`, reuse saved source profiles.
- [ ] Add a test that writes a definition with a `ProjectContext` source, reruns from `-DefinitionPath`, and verifies context/relationship output is reproduced without interactive prompts.

### Task 4: Add Guided Source-Type Interview

**Files:**
- Modify: `src/ShareSurfer/Public/Join-ShareSurferOwnershipSources.ps1`
- Test: `tests/Invoke-ShareSurferTests.ps1`

- [ ] Add a text prompt helper that asks for source type when `-Interactive` is used and no saved profile exists.
- [ ] Add a text prompt helper that asks for authority level with safe default `ReviewerHint` for `ProjectContext`, `ObsContext`, and `PathOwnership`, and `Unknown` otherwise.
- [ ] Add deterministic noninteractive defaults:
  - `Identity` when a strong join key is mapped.
  - `ProjectContext` when project fields and OBS exist.
  - `ObsContext` when OBS exists without a strong join key.
  - `PathOwnership` when `PathPattern` exists.
  - `GroupContext` when `GroupName` exists.
  - `Mixed` otherwise.
- [ ] Add tests for noninteractive source-type inference. Interactive prompt coverage can be limited to helper-level behavior.

### Task 5: Carry Optional Context Graph Files Through Scan Export

**Files:**
- Modify: `src/ShareSurfer/Public/Invoke-ShareSurferScan.ps1`
- Modify: `src/ShareSurfer/Private/Export-ShareSurferInventory.ps1`
- Modify: `src/ShareSurfer/Public/Test-ShareSurferExport.ps1`
- Test: `tests/Invoke-ShareSurferTests.ps1`

- [ ] Add optional scan parameters:
  - `OwnershipContextPath`
  - `OwnershipRelationshipPath`
  - `OwnershipImportManifestPath`
- [ ] Load those CSVs when supplied and attach them to inventory as:
  - `OwnershipContext`
  - `OwnershipRelationships`
  - `OwnershipImportManifest`
- [ ] Export those inventory properties as optional datasets.
- [ ] Add the three files to `Test-ShareSurferExport` optional file handling.
- [ ] Add a test that scans an `InputObject` with the three optional paths and validates the export includes the copied rows.

### Task 6: Update Dashboard Schema Raw Evidence

**Files:**
- Modify: `interface/standalone-dashboard/src/data/schema.ts`
- Modify: `interface/standalone-dashboard/src/data/fixtures.ts`
- Modify: `interface/standalone-dashboard/src/data/deriveDashboard.test.ts`

- [ ] Add dataset keys:
  - `ownership_context`
  - `ownership_relationships`
  - `ownership_import_manifest`
- [ ] Mark them optional.
- [ ] Add human labels and expected columns.
- [ ] Add fixture rows for a small project/OBS source.
- [ ] Add a dashboard data test that raw evidence catalog includes the new optional datasets when present.

### Task 7: Update Docs

**Files:**
- Modify: `README.md`
- Modify: `docs/admin-ownership-import.md`
- Modify: `docs/ownership-csv-ingest-quick-reference.md`
- Modify: `docs/export-schema.md`
- Modify: `docs/command-recipes.md`
- Test: `tests/Invoke-ShareSurferTests.ps1`

- [ ] Document the project-description-linked-to-OBS example.
- [ ] Explain the difference between:
  - `ownership-enrichment.csv`
  - `ownership_context.csv`
  - `ownership_relationships.csv`
  - `ownership_import_manifest.csv`
  - exported `ownership_enrichment.csv`
- [ ] Add a copy/paste command showing `Join-ShareSurferOwnershipSources -IncludeContextGraph`.
- [ ] Add docs assertions for `ownership_context.csv`, `ownership_relationships.csv`, and project/OBS wording.

### Task 8: Validate And Close

**Files:**
- No new source files expected.

- [ ] Run `git diff --check`.
- [ ] Run `pwsh -NoLogo -NoProfile -File tests/Invoke-ShareSurferTests.ps1`.
- [ ] Run `npm --prefix interface/standalone-dashboard run test`.
- [ ] Run `npm --prefix interface/standalone-dashboard run build`.
- [ ] Commit with issue reference `#346`.
- [ ] Push branch, open PR, and post an issue comment with commit SHA, changes, validation, and follow-up.
