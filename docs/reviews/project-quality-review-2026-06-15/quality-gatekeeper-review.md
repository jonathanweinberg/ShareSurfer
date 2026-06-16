# Quality Gatekeeper Review

## Scope And Method

Reviewed `/Users/jonathanweinberg/Documents/Codex_ShareSurfer` on branch `codex/project-quality-review-2026-06-15` in read-only mode. The quality gatekeeper reviewer did not edit files, stage, commit, use internal lab tooling, or include raw private lab values.

The reviewer inspected requested files plus package manifests, CI/release workflows, lab evidence READMEs, support-bundle/redaction docs, and current untracked review context as non-authoritative context.

Validation run locally:

- `git diff --check`: clean.
- `pwsh -NoLogo -NoProfile -File tests/Invoke-ShareSurferTests.ps1`: `54/54 tests passed`.
- `npm --prefix interface/standalone-dashboard run test`: `45/45 tests passed`.
- Local PowerShell runtime: PowerShell 7.6.1 on macOS, not Windows PowerShell 5.1.
- Current validator rerun against archived enterprise evidence: `IsValid=false`, one failed check: `NormalizedCsvExport`.
- `Test-ShareSurferExport` against archived enterprise export: missing `discounted_principals.csv` and 45 schema errors.

## Current Gates Observed

- CI exists on `windows-2022` and runs Node 22, `npm ci`, dashboard tests, dashboard build, PowerShell tests, and a package smoke artifact. CI package smoke skips dependency-age checking.
- Release workflow runs dashboard tests and PowerShell tests, then builds an unsigned release package with dependency-age checking enabled at 7 days.
- Module manifest declares `PowerShellVersion = '5.1'`, and README/operator docs tell collectors to use Windows PowerShell 5.1.
- Release script builds/copies static dashboard assets, replaces release dashboard data with a template snapshot, writes `release-manifest.json`, `RELEASE.md`, `SHA256SUMS.txt`, zip, and zip hash.
- Acceptance script checks normalized CSV export, report markers, dashboard review, support bundle, issue comments, preflight, collector environment, criteria, live evidence review, and live evidence gate.
- Archived V1 phase-1 docs say the refreshed proof was accepted: `IsValid=True`, `PassedCheckCount=19`, `FailedCheckCount=0`, and `FallbackCount=0`.
- The same archived export no longer validates against the current schema, so the accepted proof is historical, not current-tree clean.
- Baseline support-bundle redaction is covered by tests; the archived enterprise support bundle itself is documented as partial and optional for phase 1.
- Static dashboard unit coverage is strong, but the reviewer did not run a packaged browser/file-open smoke test or live enterprise dashboard performance check.

## Gate Passes

- Current local code/test gates are strong: dependency-free PowerShell suite passed `54/54`; dashboard Vitest suite passed `45/45`; whitespace diff check was clean.
- CI has a broad release-manager shape: Windows runner, dashboard install/test/build, PowerShell tests, and package smoke.
- Release package script has meaningful controls: dependency-age policy, package manifest, hashes, prebuilt dashboard template assets, lab-evidence exclusion, and offline dashboard packaging notes.
- Docs are unusually operator-ready: first-run, nonpermissive workflow, release quickstart, PowerShell 5.1 collector guidance, static dashboard packaging, and redacted support-bundle handling are all documented.
- Lab evidence exists for both enterprise-scale phase-1 proof and a bounded Native SMB/RPC provider proof.
- Support-bundle redaction baseline is tested for stable-token replacement, audit output, zero leak count, generated report redaction, and no salt disclosure.

## Gate Risks Or Weaknesses

### 1. Archived enterprise acceptance no longer passes the current export schema.

Severity: High

Evidence: `docs/v1-phase1-acceptance-audit.md` records accepted phase-1 proof with `IsValid=True`, `PassedCheckCount=19`, and `FailedCheckCount=0`. The lab evidence README says the refreshed proof was generated from archived CSVs and reports `FallbackCount=0`. Rerunning the current `scripts/Test-ShareSurferV1Acceptance.ps1` against that archived proof now returns `IsValid=false`, with `NormalizedCsvExport` failing. Direct `Test-ShareSurferExport` reports missing `discounted_principals.csv` and 45 missing-column schema errors.

What Could Go Wrong: A release could claim current 1.0-grade enterprise validation while the canonical archived export no longer satisfies the current validator. Operators may trust old evidence for newer schema fields such as discounted principals, manager raw fields, collection provider, and richer review packet fields.

Suggested Gate Improvement: Before 1.0, regenerate the enterprise lab/export evidence with the current tree or add an explicit schema migration/compatibility gate. The acceptance audit should only claim current readiness when the current validator passes.

### 2. PowerShell 5.1 compatibility is declared and documented, but not proven by this review or current CI shape.

Severity: High

Evidence: `src/ShareSurfer/ShareSurfer.psd1` declares `PowerShellVersion = '5.1'`, and README says the collector only needs Windows PowerShell 5.1. CI uses `shell: pwsh` and runs `pwsh -NoLogo -NoProfile`, while local validation ran PowerShell 7.6.1 on macOS.

What Could Go Wrong: A feature can pass PowerShell 7/Core and still fail on Windows PowerShell 5.1 due parser, encoding, .NET, JSON, class, or platform differences.

Suggested Gate Improvement: Add a Windows PowerShell 5.1 CI lane using `powershell.exe` for module import, parser checks, and a critical subset or full suite. Treat 5.1 failure as release-blocking.

### 3. Dependency-age policy exists, but the fastest CI package smoke explicitly skips it.

Severity: Medium

Evidence: CI package smoke runs `New-ShareSurferRelease.ps1` with `-SkipDependencyAgeCheck`. The release workflow runs packaging with `-MinimumDependencyAgeDays 7`. The release script treats unknown or too-new npm metadata as invalid when the check is enabled.

What Could Go Wrong: Normal PR CI can pass while the actual release fails on registry metadata, unknown dependency publish times, or too-new dependency versions.

Suggested Gate Improvement: Add a non-publishing release-readiness job that runs dependency-age checking and uploads the report, or require a checked/attached age report before tagging.

### 4. Manual release dispatch can produce a stable-looking `0.1.0` artifact.

Severity: Medium

Evidence: Release workflow input `version` is optional. If no input and no tag are present, the workflow reads the module manifest version. The manifest is `0.1.0`, while README points operators to `v0.1.0-pre.14`.

What Could Go Wrong: A maintainer can accidentally produce `ShareSurfer-0.1.0` artifacts that look more stable than the documented pre-release line.

Suggested Gate Improvement: Require manual release `version`, reject non-prerelease versions before 1.0 unless explicitly approved, or derive manual version from the intended tag.

### 5. Support-bundle readiness is partial at enterprise scale.

Severity: Medium-High

Evidence: The lab evidence README documents the enterprise support bundle as partial and missing `support_bundle_manifest.csv`, `support_bundle_redaction_audit.csv`, and `support_bundle_summary.json`. The acceptance script can pass with `-AllowMissingSupportBundle`. Unit tests prove the support-bundle baseline, but the archived enterprise artifact is not a full current bundle.

What Could Go Wrong: A support handoff could be claimed as proven at enterprise scale without the manifest, summary, redaction audit, and zero-leak evidence that support reviewers need.

Suggested Gate Improvement: Before 1.0, generate a full current enterprise redacted support bundle with manifest, file inventory, summary, diagnostics, redaction audit, and `RedactionLeakCount=0`.

### 6. Raw/private lab evidence is still a repository privacy gate.

Severity: High

Evidence: `docs/lab-evidence/.../README.md` includes a host/scope section with private lab metadata, and the tracked lab-evidence tree contains raw run/export/report evidence. The release script excludes `docs/lab-evidence/*`, which protects release zips but not repository/history exposure.

What Could Go Wrong: If the repo, mirror, or generated docs are shared more broadly than intended, raw lab metadata or embedded evidence can leak outside the trusted boundary.

Suggested Gate Improvement: Move raw lab evidence out of tracked product docs or sanitize it to public-safe summaries. Add a privacy guard that fails on raw lab metadata outside explicitly redacted/synthetic folders.

### 7. Static dashboard artifact quality is not yet a complete release gate.

Severity: Medium

Evidence: Dashboard unit tests passed, release packages include prebuilt template assets, and README explains packaging a real export into `standalone-dashboard/index.html`. Package manifest has an e2e script, but CI does not run it, and the reviewer did not run a browser/file-open smoke test against a current packaged enterprise dashboard.

What Could Go Wrong: Template assets can test well but still fail when opened from disk, copied between hosts, or loaded with enterprise-scale data.

Suggested Gate Improvement: Add release-gate Playwright smoke for a packaged dashboard from a current enterprise export, including `file://` or equivalent static open, row-count assertions, screenshot capture, and basic performance thresholds.

## Release Readiness Scorecard

| Area | Rating | Notes |
| --- | --- | --- |
| tests | Pass | `54/54` PowerShell tests and `45/45` dashboard tests passed locally; 5.1-specific proof remains separate. |
| CI | Partial | Broad Windows CI exists, but it uses `pwsh`, skips dependency-age in package smoke, and lacks dashboard e2e/static artifact smoke. |
| packaging | Partial | Strong release script and manifest/hash story; manual version trap and no current full package verification in this review. |
| docs | Partial | Strong operator docs; acceptance audit is now stale relative to current schema validation. |
| lab evidence | Partial | Archived proof accepted historically; current validator fails archived normalized export; no fresh live rerun. |
| security/privacy | Partial | Redaction baseline tests pass, but raw lab evidence remains tracked and enterprise bundle is partial. |
| dashboard artifact quality | Partial | Unit coverage is strong; packaged static enterprise dashboard smoke/perf gate is not yet proven. |

## Recommended Required Gates Before 1.0

1. Run a fresh current-tree Windows/AD enterprise validation with `-RequireLiveEvidence`, no plan-only required rows, and current schema-valid export.
2. Run the PowerShell suite under Windows PowerShell 5.1, not only PowerShell 7.
3. Generate a full enterprise redacted support bundle with manifest, summary, diagnostics, redaction audit, and zero leaks.
4. Run release packaging with dependency-age check enabled, then unzip/hash/import the package and package a real export dashboard from it.
5. Run static dashboard smoke/e2e against the packaged export dashboard, including row-count checks for enterprise-scale data.
6. Add privacy/public-artifact guardrails for `docs/lab-evidence/**` so raw lab metadata cannot accidentally become release or public evidence.
7. Make manual release versioning fail closed before 1.0.
8. Regenerate or clearly mark historical acceptance docs whenever schema/acceptance gates change.

## Top Follow-Up Issues To File

1. Refresh enterprise lab acceptance evidence against the current export schema.
2. Add Windows PowerShell 5.1 CI validation.
3. Produce and gate a full enterprise redacted support bundle with zero-leak audit.
4. Add privacy guardrails for raw lab evidence in tracked docs/history.
5. Fix manual release version resolution to prevent accidental `0.1.0` artifacts.
6. Add dependency-age report validation to release-readiness CI.
7. Add packaged static dashboard e2e/screenshot/performance gate.
8. Add schema parity/current-acceptance checks so docs cannot drift from the current validator.

## Confidence And Limits

Confidence is high for repo-evidenced gates and local validation results. Confidence is medium for Windows/live-lab readiness because the reviewer did not run Windows PowerShell 5.1 or mutate/use the live lab. The reviewer did not verify current GitHub release state or issue #233 remotely. Some untracked review artifacts appeared during this session and were treated as context, not authoritative evidence.
