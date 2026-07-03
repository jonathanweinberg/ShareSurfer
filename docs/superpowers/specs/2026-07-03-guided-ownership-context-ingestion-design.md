# Guided Ownership Context Ingestion Design

Issue: [#346](https://github.com/jonathanweinberg/ShareSurfer/issues/346)

## Goal

Build a more mature ownership ingestion workflow for imperfect multi-CSV inputs. ShareSurfer should be able to ingest files that describe people/accounts, OBS/business structure, projects/applications, path ownership, or security groups without pretending every row is a person record.

The selected direction is **B+C**:

- **B: Context graph CSVs.** Keep `ownership_enrichment.csv` compatible, and add optional CSV evidence for context entities, relationships, and import source decisions.
- **C: Guided source interview.** During interactive ingestion, ask the operator what each CSV describes and save those choices in the reusable JSON definition.

## Current State

Today `Join-ShareSurferOwnershipSources` can combine multiple CSVs, map flexible headers, save `ownership-import.definition.json`, enrich AD data by employee ID or employee number, skip forbidden OUs, and write `ownership-enrichment.csv`.

That works well when rows are identity-shaped. It is weaker when a CSV says something like:

```csv
OBS,ProjectCode,ProjectDescription,BusinessUnit,DataOwner
CORP.FIN.AP,FIN-AP,Accounts Payable modernization,Finance,Finance Operations
```

This row is valuable, but it is not an employee identity. It should become explainable context such as:

- Project `FIN-AP` belongs to OBS `CORP.FIN.AP`.
- OBS `CORP.FIN.AP` belongs to business unit `Finance`.
- OBS `CORP.FIN.AP` has reviewer hint `Finance Operations`.

## Data Contracts

### Existing File: `ownership_enrichment.csv`

Keep this file backward compatible. It remains the scan input/export evidence for person/account-shaped enrichment rows.

No existing column should be removed or renamed.

### New Optional File: `ownership_context.csv`

One row per imported context entity or context-bearing source row.

Columns:

| Column | Meaning |
| --- | --- |
| `ContextId` | Stable per-run context row id. |
| `SourceType` | `Identity`, `ObsContext`, `ProjectContext`, `PathOwnership`, `GroupContext`, or `Mixed`. |
| `SourcePath` | Source CSV path. |
| `SourceRowNumber` | Source row number. |
| `EntityType` | `Identity`, `OBS`, `Project`, `Path`, `Group`, `BusinessUnit`, or `Owner`. |
| `EntityKey` | Best stable key for the entity. |
| `EntityLabel` | Friendly label for review. |
| `OBS` | OBS/OID/org path when available. |
| `BusinessUnit` | Business-facing unit when available. |
| `DataOwner` | Owner/reviewer hint when available. |
| `OwnerMail` | Owner/reviewer email when available. |
| `Project` | Project/program/application name when available. |
| `ProjectCode` | Project/program/application code when available. |
| `ProjectDescription` | Plain description when available. |
| `GroupName` | Group name when available. |
| `PathPattern` | Path or path prefix when available. |
| `AuthorityLevel` | `Authoritative`, `ReviewerHint`, `ContextOnly`, or `Unknown`. |
| `ConfidenceLabel` | Plain label such as `DirectIdentityMatch`, `ObsContextMatch`, `ProjectContextMatch`, `PathMapping`, `GroupContextMatch`, or `NeedsReview`. |
| `EvidenceReason` | One-sentence explanation of why the row exists. |
| `ImportWarnings` | Row-level warnings. |

### New Optional File: `ownership_relationships.csv`

One row per explainable relationship inferred from source data.

Columns:

| Column | Meaning |
| --- | --- |
| `RelationshipId` | Stable per-run relationship id. |
| `SourceType` | Source classification. |
| `SourcePath` | Source CSV path. |
| `SourceRowNumber` | Source row number. |
| `FromType` | Entity type on the left side. |
| `FromValue` | Entity value on the left side. |
| `RelationshipType` | `BelongsTo`, `PartOf`, `ReviewedBy`, `Describes`, `GrantsContextTo`, or `RelatedTo`. |
| `ToType` | Entity type on the right side. |
| `ToValue` | Entity value on the right side. |
| `AuthorityLevel` | `Authoritative`, `ReviewerHint`, `ContextOnly`, or `Unknown`. |
| `ConfidenceLabel` | Plain confidence/source label. |
| `EvidenceReason` | Human explanation. |

Example:

```csv
SourceType,FromType,FromValue,RelationshipType,ToType,ToValue,ConfidenceLabel,EvidenceReason
ProjectContext,Project,FIN-AP,BelongsTo,OBS,CORP.FIN.AP,ProjectContextMatch,Project source linked ProjectCode to OBS.
ObsContext,OBS,CORP.FIN.AP,PartOf,BusinessUnit,Finance,ObsContextMatch,Source supplied BusinessUnit for OBS.
ObsContext,OBS,CORP.FIN.AP,ReviewedBy,DataOwner,Finance Operations,ReviewerHint,Source supplied DataOwner for OBS.
```

### New Optional File: `ownership_import_manifest.csv`

One row per selected source file.

Columns:

| Column | Meaning |
| --- | --- |
| `SourcePath` | Source CSV path. |
| `SourceType` | Selected or inferred source type. |
| `AuthorityLevel` | Selected authority level. |
| `PrimaryAnchor` | Primary anchor field, such as `EmployeeId`, `OBS`, `ProjectCode`, `PathPattern`, or `GroupName`. |
| `MappedFields` | Canonical ShareSurfer fields mapped from the source. |
| `RowCount` | Source row count. |
| `ContextRowCount` | Context rows emitted from this file. |
| `RelationshipRowCount` | Relationship rows emitted from this file. |
| `Warnings` | Source-level warnings. |

## Guided Operator Flow

When `Join-ShareSurferOwnershipSources -Interactive` is used, ShareSurfer should ask source-level questions after selecting CSV files and before row processing:

1. What does this CSV mostly describe?
   - `Identity`
   - `ObsContext`
   - `ProjectContext`
   - `PathOwnership`
   - `GroupContext`
   - `Mixed`
2. How authoritative is this file?
   - `Authoritative`
   - `ReviewerHint`
   - `ContextOnly`
   - `Unknown`
3. What is the strongest anchor?
   - suggested from mapped fields, such as `EmployeeId`, `OBS`, `ProjectCode`, `PathPattern`, or `GroupName`
4. Should owner-like fields be treated as reviewer hints?
   - default yes for `ProjectContext`, `ObsContext`, and `PathOwnership`

The answers must be saved in `ownership-import.definition.json` so a rerun does not need to repeat the interview.

## Public Interface

Extend `Join-ShareSurferOwnershipSources` additively:

```powershell
Join-ShareSurferOwnershipSources `
  -Path @('C:\ShareSurfer\inputs\hr.csv', 'C:\ShareSurfer\inputs\projects.csv') `
  -OutputPath 'C:\ShareSurfer\inputs\ownership-enrichment.csv' `
  -IncludeContextGraph `
  -ContextOutputPath 'C:\ShareSurfer\inputs\ownership_context.csv' `
  -RelationshipOutputPath 'C:\ShareSurfer\inputs\ownership_relationships.csv' `
  -ManifestOutputPath 'C:\ShareSurfer\inputs\ownership_import_manifest.csv' `
  -DefinitionPath 'C:\ShareSurfer\inputs\ownership-import.definition.json' `
  -Interactive `
  -Force
```

If `-IncludeContextGraph` is supplied and output paths are omitted, write default files beside `-OutputPath`.

Extend `Invoke-ShareSurferScan` additively:

```powershell
Invoke-ShareSurferScan `
  -TargetPath '\\files01\Finance' `
  -OutputPath 'C:\ShareSurfer\exports\scan-001' `
  -OwnershipEnrichmentPath 'C:\ShareSurfer\inputs\ownership-enrichment.csv' `
  -OwnershipContextPath 'C:\ShareSurfer\inputs\ownership_context.csv' `
  -OwnershipRelationshipPath 'C:\ShareSurfer\inputs\ownership_relationships.csv' `
  -OwnershipImportManifestPath 'C:\ShareSurfer\inputs\ownership_import_manifest.csv'
```

The scan should export these optional datasets unchanged into the scan export folder.

## Dashboard And Report Behavior

First slice dashboard behavior is intentionally modest:

- Add the new optional datasets to schema/raw evidence handling.
- Label them clearly:
  - Ownership context
  - Ownership relationships
  - Ownership import manifest
- Do not redesign the dashboard yet.

Later dashboard work can use these relationships in Migration Discovery and owner workbench explanations.

## Compatibility

- Existing `Join-ShareSurferOwnershipSources` calls continue to write only `ownership-enrichment.csv` unless the new context graph switch/paths are used.
- Existing `Invoke-ShareSurferScan -OwnershipEnrichmentPath` behavior remains valid.
- Existing dashboard packages and exports without the new optional files remain valid.
- New CSVs are optional in `Test-ShareSurferExport`.

## Validation

Add focused tests for:

- Project/OBS CSV generates context and relationship rows.
- Interactive/source profile choices can be represented in definition JSON and reused non-interactively.
- Existing multi-source ownership enrichment tests still pass.
- `Invoke-ShareSurferScan` copies optional ownership context graph files into the export.
- `Test-ShareSurferExport` treats the new files as optional but validates columns when present.
- Dashboard schema/raw evidence recognizes the new datasets.

## Non-Goals

- No AI or LLM inference.
- No graph database.
- No external service dependency.
- No permission or AD mutation.
- No dashboard visual redesign in this first slice.
