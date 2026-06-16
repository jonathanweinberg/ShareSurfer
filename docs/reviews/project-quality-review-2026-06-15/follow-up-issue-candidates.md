# Follow-Up Issue Candidates

This file turns the quality review into issue-ready follow-up candidates. These are not all immediate work. They are grouped by urgency and by the type of project risk they reduce.

## P0: Privacy And Current-Proof Integrity

### 1. Sanitize or relocate tracked raw lab evidence

Source Reviews: Critic, Quality Gatekeeper.

Problem:

Tracked `docs/lab-evidence/**` contains raw lab/run evidence. Release packaging excludes it, but repository/history exposure remains a separate risk.

Acceptance Criteria:

- Public repo keeps only sanitized summaries, synthetic evidence, redacted bundles, or public-safe attestations.
- Raw lab evidence is moved to controlled storage or removed from tracked docs.
- CI guard detects raw lab markers outside approved redacted/synthetic paths.
- Documentation explains where public proof lives and where controlled raw proof lives.

Validation:

- `git ls-files docs/lab-evidence` review after cleanup.
- New privacy guard test passes.
- Release package still excludes raw lab evidence.

### 2. Refresh current enterprise validation evidence or add schema migration proof

Source Reviews: Quality Gatekeeper, Strategist.

Problem:

Phase-1 enterprise proof was accepted historically, but a current validator rerun against archived evidence now fails normalized export validation after schema growth.

Acceptance Criteria:

- Current-tree enterprise validation produces schema-valid exports, or archived evidence is migrated through an explicit compatibility path.
- `scripts/Test-ShareSurferV1Acceptance.ps1` passes against the selected current proof pack.
- Acceptance docs distinguish historical proof from current proof.

Validation:

- `Test-ShareSurferExport` passes on enterprise export.
- `Test-ShareSurferV1Acceptance.ps1 -RequireLiveEvidence` passes on the proof pack.
- Updated audit docs link to current evidence.

### 3. Make manual release versioning fail closed before 1.0

Source Reviews: Critic, Quality Gatekeeper, Builder.

Problem:

Manual release dispatch can default to module version `0.1.0`, creating stable-looking artifacts while docs point to prereleases.

Acceptance Criteria:

- Manual release requires an explicit version or derives it from an intended tag.
- Pre-1.0 releases reject stable-looking versions unless an explicit override is present.
- Tests verify release metadata, docs, and package name are consistent.

Validation:

- Release workflow lint/test covers blank manual version.
- `New-ShareSurferRelease.ps1` behavior is tested for prerelease and stable version handling.

## P1: Evidence Contract Durability

### 4. Add single-source or parity checks for export schemas

Source Reviews: Builder, Critic, Quality Gatekeeper.

Problem:

PowerShell export schema, standalone packager schema, and React dashboard schema are duplicated and have drift.

Acceptance Criteria:

- CI detects schema drift across PowerShell, packager, and dashboard.
- `scan_manifest.CollectionProvider` is represented in dashboard schema and raw evidence.
- Documentation identifies the authoritative schema source.

Validation:

- New schema parity test fails before fix and passes after fix.
- Dashboard raw evidence shows `CollectionProvider`.

### 5. Extend export validation to optional assessment datasets

Source Reviews: Critic.

Problem:

`Test-ShareSurferExport` validates core exports and optional ownership enrichment, but not optional open-file or port/protocol assessment exports consumed by the dashboard.

Acceptance Criteria:

- Optional open-file exports validate when present.
- Optional port/protocol exports validate when present.
- Invalid optional assessment files produce clear row/column diagnostics.

Validation:

- New passing tests for valid optional assessment exports.
- New failing-case tests for missing optional columns.

### 6. Normalize native filesystem ACL rights masks

Source Reviews: Critic.

Problem:

Native filesystem ACE rights can render as numeric or negative masks instead of readable permission labels.

Acceptance Criteria:

- Generic/high-bit file access masks normalize to readable rights where possible.
- Raw masks are preserved separately if needed for diagnostics.
- Dashboard/report owner-facing rights are not opaque negative values.

Validation:

- Tests for generic read/write/execute/all masks.
- Tests for high-bit masks and inheritance-only ACEs.

### 7. Record requested and effective collection providers

Source Reviews: Critic, Strategist.

Problem:

Manifest currently records requested SMB provider, not the effective provider set used during Auto/fallback collection.

Acceptance Criteria:

- Manifest or scan events include requested provider and effective provider(s).
- Dashboard diagnostics can show whether CIM, native RPC, fallback, or mixed evidence was used.
- Support bundle preserves this evidence safely.

Validation:

- Tests for explicit provider and Auto fallback.
- Dashboard diagnostics test for provider display.

## P2: Release And Validation Gates

### 8. Add Windows PowerShell 5.1 CI validation

Source Reviews: Quality Gatekeeper.

Problem:

PowerShell 5.1 is the collector promise, but current CI uses `pwsh`.

Acceptance Criteria:

- CI runs module import and parser checks under `powershell.exe`.
- Critical collector/export tests run under Windows PowerShell 5.1.
- 5.1 failures block release branches.

Validation:

- New Windows 5.1 CI lane passes.
- At least one intentionally incompatible syntax sample is caught by a parser guard or equivalent test fixture.

### 9. Add dependency-age report validation to release-readiness CI

Source Reviews: Quality Gatekeeper.

Problem:

PR package smoke skips dependency-age checks, while real releases enforce them.

Acceptance Criteria:

- A non-publishing release-readiness job runs dependency-age checks.
- Dependency age report is uploaded as an artifact.
- Unknown or too-new dependencies fail release-readiness.

Validation:

- CI job proves dependency-age report generation.
- Release docs identify how to inspect the report.

### 10. Add packaged static dashboard e2e and performance gate

Source Reviews: Builder, Strategist, Quality Gatekeeper.

Problem:

Dashboard unit tests are strong, but packaged offline dashboard behavior against large exports is not a full gate.

Acceptance Criteria:

- Package a representative export into standalone dashboard output.
- Run browser smoke against static output.
- Assert key row counts, key views, no blank app, and basic performance thresholds.
- Store screenshots or summary artifacts for review.

Validation:

- Playwright or equivalent static-dashboard smoke passes in CI or release-readiness job.

### 11. Prove full enterprise redacted support bundle before 1.0

Source Reviews: Quality Gatekeeper.

Problem:

The archived enterprise support bundle was partial; baseline redaction tests pass, but enterprise-scale support output is not fully proven.

Acceptance Criteria:

- Full enterprise support bundle completes with manifest, summary, diagnostics, redaction audit, and zero leak count.
- Performance is acceptable for enterprise outputs.
- Docs explain when rich support bundles are required versus optional.

Validation:

- Enterprise support bundle generation completes.
- `RedactionLeakCount=0`.
- Bundle manifest and summary validate.

## P3: Builder Ergonomics

### 12. Split the monolithic PowerShell test runner

Source Reviews: Builder.

Problem:

`tests/Invoke-ShareSurferTests.ps1` is a large dependency-free runner that is valuable but hard to extend safely.

Acceptance Criteria:

- Shared assertion/fixture helpers are separated.
- Domain suites exist for lab, scan/export, ownership, SMB/RPC, dashboard/docs, release, and support bundle behavior.
- Existing single entrypoint can still run all tests.

Validation:

- Full suite count remains equivalent or grows.
- Targeted domain test commands are documented.

### 13. Refactor dashboard app into maintainable view/components/hooks

Source Reviews: Builder, Strategist.

Problem:

`interface/standalone-dashboard/src/App.tsx` has become the center for state, filters, CSV export, evidence drilldowns, views, and layout.

Acceptance Criteria:

- Extract filter/query state into hooks or modules.
- Extract major views into components.
- Keep derived data logic in pure data modules.
- Existing tests pass and new view-level tests cover extracted behavior.

Validation:

- `npm --prefix interface/standalone-dashboard run test`.
- `npm --prefix interface/standalone-dashboard run build`.

### 14. Add single release metadata source for docs/tests

Source Reviews: Builder, Critic.

Problem:

Current prerelease references are hard-coded across docs and tests.

Acceptance Criteria:

- One metadata file defines current quickstart release tag, package name, and release URL.
- Docs/tests consume or verify against that file.
- Version bump process becomes one-file or generated.

Validation:

- Metadata consistency test.
- Docs reference generated/current release values.

### 15. Exclude internal planning docs from release packages

Source Reviews: Builder.

Problem:

Release packaging includes tracked `docs/**`, which can include internal agent execution plans.

Acceptance Criteria:

- Release package excludes `docs/superpowers/**` or internal plans move outside public docs.
- Release test asserts internal planning paths are absent from package.
- Public docs remain complete for operators.

Validation:

- `New-ShareSurferRelease.ps1` package inspection.
- Test for absence of internal planning directory in release zip.

### 16. Refresh README command inventory

Source Reviews: Builder, Critic.

Problem:

README command list lags the 12 exported public functions.

Acceptance Criteria:

- README groups all public commands by workflow family.
- Tests verify README command inventory includes exported commands or intentionally documented families.

Validation:

- Module import command list compared to README anchors or generated command inventory.

## P4: Product Maturity

### 17. Add exported evidence confidence model

Source Reviews: Strategist, Quality Gatekeeper.

Problem:

The dashboard can infer confidence locally, but evidence confidence is not a first-class exported contract.

Acceptance Criteria:

- Export includes confidence rows by share/path/provider.
- Confidence covers partial data, collection errors, ACL/owner read status, share descriptor status, identity/group expansion status, and optional assessment readiness.
- Dashboard/report/business handoff consume the same confidence data.

Validation:

- Tests for clean, partial, blocked, and mixed-provider scans.
- Dashboard shows confidence from export data, not only local heuristics.

### 18. Add a release-root Start Here adoption path

Source Reviews: Strategist, Builder.

Problem:

Docs are deep and useful, but first-time operators face choice overload.

Acceptance Criteria:

- A short Start Here path covers Scan -> Validate -> Package -> Review -> Decide.
- Stop gates are visible for partial data, owner mapping gaps, wrong OBS attribute, and template dashboard confusion.
- Links route to deeper docs without duplicating everything.

Validation:

- Docs tests assert the Start Here path and stop gates exist.

### 19. Add owner packet and migration-cluster review decision export/import

Source Reviews: Strategist.

Problem:

ShareSurfer can produce review packets and related data areas, but review decisions still live outside the tool.

Acceptance Criteria:

- Operators can export a local CSV template for owner/migration decisions.
- Operators can import decisions to annotate dashboards/reports.
- No external service dependency is introduced.

Validation:

- Tests for owner confirmed, rerun needed, cleanup needed, migration candidate, and wrong owner states.

### 20. Add Migration Discovery quality harness

Source Reviews: Strategist.

Problem:

Migration Discovery is strategically important, but relatedness quality is not measured against expected clusters.

Acceptance Criteria:

- Lab generator emits expected related-data clusters.
- Tests measure false splits, false merges, and confidence labels.
- Dashboard/report explain relatedness signals for expected clusters.

Validation:

- Lab-backed tests for strong, possible, weak, and needs-evidence clusters.

### 21. Integrate port/protocol readiness into confidence and dashboard stop gates

Source Reviews: Strategist, Critic.

Problem:

Port/protocol assessment is useful but optional and somewhat separate from scan confidence.

Acceptance Criteria:

- When assessment exports exist, confidence model incorporates readiness and route limitations.
- Dashboard highlights pre-review readiness and blocked/warning routes.
- Docs explain reachability versus readable evidence.

Validation:

- Tests for WinRM blocked but SMB reachable, SMB blocked, directory lookup unavailable, and native provider fallback.
