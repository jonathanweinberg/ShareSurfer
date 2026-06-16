# Critic Review

## Scope And Method

Reviewed `/Users/jonathanweinberg/Documents/Codex_ShareSurfer` on branch `codex/project-quality-review-2026-06-15` in read-only mode. The critic reviewer inspected tracked source, scripts, docs, tests, dashboard code, CI/release workflows, and selected lab evidence metadata using `git status`, `git ls-files`, `rg`, `sed`, and `nl`. The reviewer did not edit files, stage, commit, use internal lab tooling, or run the full test/release workflows.

## Highest-Risk Findings

### 1. Unredacted lab evidence is tracked in the repository

Severity: High

Evidence with file paths/commands: `git ls-files docs/lab-evidence | wc -l` returned `121`. `rg -n '"ComputerName"|"UserDomain"|"RunRoot"' docs/lab-evidence --glob '!**/support-bundle-redacted/**'` matched unredacted lab evidence outside the redacted support-bundle folders. Examples include `docs/lab-evidence/.../collector-environment.json`, `docs/lab-evidence/.../lab-run-events.jsonl`, and generated report HTML that embeds raw export data. Values are intentionally omitted here. Release packaging does exclude this tree in `scripts/New-ShareSurferRelease.ps1`, but that only protects release zips.

Impact: If this repo is public, mirrored, packaged by another route, or used as a reference implementation, raw lab host/domain/path/share evidence can leak from Git history and docs. This is the biggest privacy/supportability risk found by the critic review.

Reproduction Or Reasoning: The release script excludes `docs/lab-evidence/*`, but the files are still tracked by Git. A consumer does not need to run the release script to see them; they only need repository access.

Suggested Fix: Move raw lab evidence out of the tracked repo. Keep only synthetic fixtures, redacted support bundles, and sanitized summaries under tracked docs. Add a repo guard that fails if `docs/lab-evidence/**` contains raw environment/run-root/report markers outside explicitly redacted or synthetic paths. Review repository visibility and history exposure separately.

### 2. Native filesystem ACL rights can render as numeric or negative masks

Severity: Medium

Evidence with file paths/commands: `src/ShareSurfer/Private/ConvertTo-ShareSurferSecurityDescriptorRows.ps1` casts a long access mask through `[int]` into `FileSystemRights`. Filesystem ACEs use that path when converting descriptor ACL rows. Tracked redacted lab bundle ACL rows show operator-facing `Rights` values as raw numeric and negative masks; no identities are quoted here.

Impact: Reviewers can see opaque values instead of readable permissions such as Read, Modify, or FullControl. That weakens owner review, support triage, dashboard interpretation, and any automated grouping that assumes `Rights` is human-readable.

Reproduction Or Reasoning: Generic/high-bit access masks do not round-trip cleanly through `[int]` and `FileSystemRights`. The share-rights path has explicit generic-right mapping; filesystem rights do not.

Suggested Fix: Normalize filesystem generic bits before casting, similar to `ConvertTo-ShareSurferShareRights`. Preserve the raw mask in a separate diagnostic column if needed. Add tests for `GENERIC_READ`, `GENERIC_WRITE`, `GENERIC_EXECUTE`, `GENERIC_ALL`, inheritance-only ACEs, and high-bit masks.

### 3. Manual release packaging can default to a stable-looking `0.1.0` artifact

Severity: Medium

Evidence with file paths/commands: The manifest declares `ModuleVersion = '0.1.0'` in `src/ShareSurfer/ShareSurfer.psd1`. The release workflow says manual `version` input is optional and defaults to module version in `.github/workflows/release.yml`. The README points operators to current quickstart release `v0.1.0-pre.14`.

Impact: A manual workflow run without `version` can produce `ShareSurfer-0.1.0` artifacts, which look more stable/newer than the documented pre-release line. That is a release/package trap for operators and maintainers.

Reproduction Or Reasoning: On `workflow_dispatch`, no tag exists and the input is optional, so the workflow falls through to `Test-ModuleManifest`. The package name is then derived directly from `$Version` in `scripts/New-ShareSurferRelease.ps1`.

Suggested Fix: Require `version` for manual release dispatch or derive it from the latest intended pre-release tag. Add a release lint/test that fails when manual packaging would create a stable-looking `0.1.0` package while docs point at a `-pre.*` release.

## Medium And Low-Risk Findings

### 4. Dashboard schema hides `CollectionProvider`

Severity: Medium

Evidence with file paths/commands: PowerShell export schema includes `CollectionProvider` in `scan_manifest.csv` at `src/ShareSurfer/Private/Get-ShareSurferExportSchema.ps1`. The standalone packager also includes it in `scripts/New-ShareSurferStandaloneDashboard.ps1`. The React dashboard expected columns omit it in `interface/standalone-dashboard/src/data/schema.ts`, and curated raw-evidence columns omit it in `interface/standalone-dashboard/src/App.tsx`.

Impact: The UI can preserve the raw row but hide the provider from the raw evidence table/column selector path that operators use for triage. That is exactly the field needed to understand Native SMB/RPC vs CIM vs Auto behavior.

Reproduction Or Reasoning: Dashboard raw evidence uses `expectedColumns[key]` for dataset columns in `deriveDashboard.ts`, so omitted schema fields are not treated as first-class raw evidence columns.

Suggested Fix: Add `CollectionProvider` to dashboard schema and curated manifest columns. Add a schema parity test for `scan_manifest.csv`.

### 5. `Test-ShareSurferExport` does not validate optional assessment exports

Severity: Medium

Evidence with file paths/commands: `src/ShareSurfer/Public/Test-ShareSurferExport.ps1` validates only `Get-ShareSurferExportSchema` plus optional `ownership_enrichment.csv`. Separate schemas exist for open-file and port/protocol exports in `src/ShareSurfer/Private/Get-ShareSurferOpenFileExportSchema.ps1` and `src/ShareSurfer/Private/Get-ShareSurferPortProtocolExportSchema.ps1`. The standalone dashboard packager accepts those optional datasets in `scripts/New-ShareSurferStandaloneDashboard.ps1`.

Impact: Malformed optional assessment CSVs can pass the main export validation gate, then show up later as dashboard warnings, blank fields, or misleading tables.

Reproduction Or Reasoning: The CLI validator never consults the optional open-file or port/protocol schema functions, while the packaging/dashboard path consumes those files.

Suggested Fix: Extend `Test-ShareSurferExport` with optional assessment schema validation when those files are present, or add an explicit `Test-ShareSurferAssessmentExport` gate used by docs and packaging.

### 6. README command inventory is stale

Severity: Low

Evidence with file paths/commands: The module exports twelve functions in `src/ShareSurfer/ShareSurfer.psd1`. The README command list shows only seven, omitting the ownership import/mapping commands.

Impact: New operators may miss the ownership-source workflow from the first command inventory, even though later docs cover it.

Reproduction Or Reasoning: The exported command list and README list are visibly out of sync.

Suggested Fix: Update the README command list or split it into "collection/reporting" and "ownership import" groups.

### 7. Manifest records requested SMB provider, not effective provider

Severity: Low

Evidence with file paths/commands: `Invoke-ShareSurferScan` sets `$collectionProvider = $SmbCollectionProvider` after collection in `src/ShareSurfer/Public/Invoke-ShareSurferScan.ps1`, then exports it into manifest data. Tests assert explicit `NativeSmbRpc` is recorded.

Impact: For `Auto`, the manifest alone cannot tell support whether collection actually used CIM, native RPC fallback, or mixed sources. Operators must inspect share rows and scan events.

Reproduction Or Reasoning: The manifest records the parameter selection, not the effective provider set.

Suggested Fix: Record both `CollectionProviderRequested` and `CollectionProvidersUsed`, or summarize effective providers from inventory/share events.

## Missing Tests Or Validation Gaps

- Add a privacy/public-artifact guard for tracked `docs/lab-evidence/**` raw environment, run-root, and embedded-report markers.
- Add native filesystem ACL rights tests for generic/high-bit masks and readable normalized labels.
- Add release workflow/package tests that prevent accidental stable-looking `0.1.0` artifacts from manual pre-release packaging.
- Add dashboard schema parity tests against PowerShell export schemas, especially `scan_manifest.csv`.
- Add optional open-file and port/protocol schema validation to the export validation gate.
- The critic reviewer did not run `tests/Invoke-ShareSurferTests.ps1`, npm tests, dashboard build, or release packaging because this was a read-only risk review.

## False Positives Considered

- Release zip leaking lab evidence: not currently a release-package bug; `scripts/New-ShareSurferRelease.ps1` excludes `docs/lab-evidence/*`. The risk is repo/history exposure.
- Template dashboard showing demo data by accident: the runtime logic and dashboard tests appear designed to treat template snapshots as missing until the user explicitly chooses demo data.
- Support bundle markdown copy: generated review/summary markdown appears designed to be public-safe. It should stay covered by redaction tests, but the critic reviewer did not rank it as a current high-risk leak.
- Tracked `node_modules`, `dist`, or `artifacts`: local copies exist, but the release script and tracked-file checks do not indicate they are part of the tracked release source set.
- XSS in report/dashboard rendering: the critic reviewer did not find an obvious unsafe HTML-rendering path in the reviewed dashboard/report surfaces.

## Top Follow-Up Issues To File

1. Remove or sanitize tracked raw lab evidence and add a repository privacy guard.
2. Normalize native filesystem ACL rights masks and test generic/high-bit ACEs.
3. Fix pre-release version resolution so manual release artifacts cannot default to stable-looking `0.1.0`.
4. Add dashboard/export schema parity coverage for `scan_manifest.CollectionProvider`.
5. Extend export validation to optional open-file and port/protocol assessment datasets.
6. Refresh the README command inventory from exported module commands.

## Confidence And Limits

Confidence is medium-high for repo-grounded risks and medium for runtime behavior that would require live Windows collection to fully prove. The highest-risk item is clear from tracked files and release packaging boundaries. Raw private evidence values were intentionally omitted from this report.
