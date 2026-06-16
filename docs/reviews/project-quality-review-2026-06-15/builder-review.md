# Builder Review

## Scope And Method

Reviewed the current tree on `codex/project-quality-review-2026-06-15` in read-only mode. Inspected `README.md`, `docs/`, `scripts/`, `src/ShareSurfer`, `tests/`, `interface/standalone-dashboard`, and `.github/workflows`.

Light validation/inventory commands run:

- `git status --short --branch`: confirmed requested branch; noted unrelated/untracked review/artifact files.
- `git diff --check`: no output.
- `pwsh -NoLogo -NoProfile -Command "Import-Module ./src/ShareSurfer/ShareSurfer.psd1 -Force; Get-Command -Module ShareSurfer ..."`: module imports and exposes 12 public functions.

The builder reviewer did not run the full PowerShell, Vitest, Playwright, release, or lab suites.

## Strengths

- The core product shape is coherent: PowerShell 5.1 collector, normalized CSV export, offline report/dashboard, redacted support bundle, and Windows/AD lab validation all line up around airgapped operator needs.
- The module entrypoint is simple and explicit: `src/ShareSurfer/ShareSurfer.psm1` dot-sources `Private/` and `Public/`, then exports a deliberate command set.
- `Get-ShareSurferExportSchema` gives the PowerShell side a central CSV contract, and `Test-ShareSurferExport` validates missing files/columns with structured diagnostics.
- Operator documentation is unusually strong: first-run, troubleshooting, export schema, nonpermissive two-host workflow, business handoff, command recipes, and visual guides are practical and copy/paste friendly.
- CI and release workflows cover dashboard install/test/build, PowerShell tests, package smoke artifacts, release packaging, SHA256 output, and dependency-age checks.

## Findings

### 1. Schema contracts are duplicated across PowerShell, packaging, and TypeScript, and drift already exists.

Priority: P1

Evidence with file paths/commands: `src/ShareSurfer/Private/Get-ShareSurferExportSchema.ps1:303` includes `CollectionProvider` in `scan_manifest.csv`; `scripts/New-ShareSurferStandaloneDashboard.ps1:38` also includes it; `interface/standalone-dashboard/src/data/schema.ts:332` omits it. `interface/standalone-dashboard/src/data/deriveDashboard.ts:748` uses `expectedColumns` to build raw evidence table columns.

Why It Matters: Builders adding a CSV column must update several disconnected schemas. The current drift means the dashboard can preserve `CollectionProvider` as row data but not treat it as an expected/displayed manifest column, so future schema additions can silently degrade.

Suggested Action: Make one schema source authoritative. Generate the dashboard schema and standalone packager schema from the PowerShell schema, or add a CI check that compares `Get-ShareSurferExportSchema`, `New-ShareSurferStandaloneSchema`, and `expectedColumns`.

### 2. Release packaging can include internal implementation-plan docs.

Priority: P1

Evidence with file paths/commands: `scripts/New-ShareSurferRelease.ps1:97` selects tracked `README.md LICENSE src scripts docs`; exclusions at `scripts/New-ShareSurferRelease.ps1:126` only cover `docs/lab-evidence`, `docs/.generated`, and dashboard `node_modules`. `git ls-files docs/superpowers` returns tracked plan files, and `docs/superpowers/plans/2026-06-15-normalized-ownership-enrichment.md:3` is explicitly for agentic workers.

Why It Matters: Release docs should be an operator product. Shipping internal execution plans adds noise, exposes process details, and makes the docs tree less clearly public-facing.

Suggested Action: Move internal plans outside packaged `docs`, or exclude `docs/superpowers/*` from release packaging. Add a release test that asserts internal planning paths are absent.

### 3. The PowerShell test suite is valuable but hard to extend safely.

Priority: P2

Evidence with file paths/commands: `tests/Invoke-ShareSurferTests.ps1` is 4,509 lines, defines custom assertions at `tests/Invoke-ShareSurferTests.ps1:7`, large fixture factories at `tests/Invoke-ShareSurferTests.ps1:50`, and broad doc/release assertions around `tests/Invoke-ShareSurferTests.ps1:4268`. `tests/ShareSurfer.Tests.ps1:4` is only a Pester wrapper around the monolith.

Why It Matters: A single dependency-free runner is useful for collector hosts, but builders now pay high cognitive and merge-conflict costs for every feature. Failures will be harder to localize as ownership import, SMB/RPC, dashboard, release, docs, and lab validation keep growing.

Suggested Action: Keep the dependency-free entrypoint, but split tests into domain files plus shared fixture/assert helpers. Let the wrapper run all files by default and targeted groups during development.

### 4. The dashboard implementation is reaching a maintainability ceiling.

Priority: P2

Evidence with file paths/commands: `interface/standalone-dashboard/src/App.tsx` is 2,649 lines and contains storage, filter parsing, CSV export, evidence drilldowns, all views, and app state. `interface/standalone-dashboard/src/data/deriveDashboard.ts` is 793 lines, and `schema.ts` is 565 lines.

Why It Matters: The dashboard is becoming the primary review surface, but extension work will touch the same large file repeatedly. That raises regression risk for filters, navigation, review decisions, and raw evidence tables.

Suggested Action: Split `App.tsx` by view and shared hooks: filter/query model, review-decision storage/export, raw evidence workbench, connectivity view, and layout shell. Keep `deriveDashboard` as the pure model boundary.

### 5. Release/version ergonomics are brittle.

Priority: P2

Evidence with file paths/commands: `README.md:156`, `docs/first-run-guide.md:78`, `docs/nonpermissive-collection-dashboard-workflow.md:25`, and `docs/command-recipes.md:15` hard-code `v0.1.0-pre.14`; tests assert those exact strings at `tests/Invoke-ShareSurferTests.ps1:4309`. The release workflow defaults manual builds to the module manifest version at `.github/workflows/release.yml:45`, while `src/ShareSurfer/ShareSurfer.psd1:3` is `0.1.0`.

Why It Matters: Every prerelease requires coordinated edits across docs and tests, and a manual release without an input version can produce a package name that does not match the operator quickstart story.

Suggested Action: Introduce a single release metadata file or generated docs snippet for the current quickstart version. Make tests assert consistency with that metadata, not a scattered literal.

### 6. The README public command inventory lags the actual module surface.

Priority: P3

Evidence with file paths/commands: `README.md:57` lists 7 commands. `src/ShareSurfer/ShareSurfer.psm1:10` and `src/ShareSurfer/ShareSurfer.psd1:10` export 12 functions, including ownership import/profile/join/draft commands. The module import inventory command also returned 12 public functions.

Why It Matters: New contributors and operators will under-discover the ownership-enrichment workflow, which is now a major part of the product.

Suggested Action: Replace the flat README command list with grouped command families: scan/report, ownership import, activity/connectivity assessment, support, lab, and validation.

## Builder Quality Scorecard

| Area | Score | Notes |
| --- | ---: | --- |
| Architecture | 4 | Strong collector/export/report separation; schema duplication and large UI surface hold it back. |
| Maintainability | 3 | Clear naming and boundaries, but several large files and monolithic tests are becoming expensive. |
| Testability | 3 | Good breadth and CI coverage; test organization needs decomposition. |
| Documentation | 5 | Excellent operator docs, with minor public/internal doc boundary issues. |
| Release ergonomics | 3 | Good automation and offline package story; version metadata and package contents need tightening. |
| Contributor ergonomics | 3 | Easy to find major flows, harder to make small changes without touching broad files. |

## Top Follow-Up Issues To File

1. Create a single-source export schema contract and add a schema drift CI check.
2. Exclude internal `docs/superpowers` planning files from release packages or move them out of public docs.
3. Split `tests/Invoke-ShareSurferTests.ps1` into domain suites with shared fixtures.
4. Refactor `interface/standalone-dashboard/src/App.tsx` into view components and hooks.
5. Add release metadata generation for current prerelease docs/tests.
6. Update README command inventory to reflect all 12 exported public functions.

## Confidence And Limits

Confidence is high for builder-facing repo structure, docs, schema, release, and test ergonomics because findings are grounded in current files and read-only commands. The builder reviewer did not inspect every implementation branch in detail, run full test suites, verify GitHub issue #233 remotely, inspect live releases, or use lab/private evidence. No files were edited, staged, committed, or pushed by the reviewer.
