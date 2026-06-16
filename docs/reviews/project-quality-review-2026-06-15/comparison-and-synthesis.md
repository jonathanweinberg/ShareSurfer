# Comparison And Synthesis

## Review Standards Used

This review used four independent standards:

- **Builder:** maintainability, extensibility, ergonomics, architecture, and how easy the project is to keep building.
- **Critic:** defects, regressions, privacy risk, confusing operator outcomes, release traps, and missing tests.
- **Strategist:** product coherence, business value, adoption journey, roadmap sequence, and migration-program usefulness.
- **Quality Gatekeeper:** release readiness, validation gates, CI coverage, lab proof, package quality, and acceptance evidence.

The four reviews are intentionally not the same. Builder asks "can we keep extending this cleanly?", Critic asks "what can hurt users?", Strategist asks "what should matter next?", and Quality Gatekeeper asks "what must be true before we call this shippable?"

## Shared Findings

### 1. Evidence and schema drift are now the highest maturity risk.

Seen By: Builder, Critic, Quality Gatekeeper, Strategist.

Agreement:

- Builder and Critic both found schema drift between PowerShell export schema, standalone dashboard packaging schema, and React dashboard schema.
- Critic specifically identified `scan_manifest.CollectionProvider` as present in PowerShell/package schema but missing from the dashboard schema path.
- Quality Gatekeeper found that archived enterprise phase-1 evidence no longer passes the current export schema validator.
- Strategist recommended formalizing an exported evidence-confidence model so trust signals become data, not just dashboard-local logic.

Synthesis:

ShareSurfer is past the "can it collect/export/report?" stage. The next maturity wall is making evidence contracts durable across PowerShell, dashboard, reports, release packages, and historical proof. Current proof can be historically accepted while still failing current-tree schema validation, and that distinction should be explicit.

Recommended Action:

1. Add schema parity checks across PowerShell, packager, and dashboard.
2. Regenerate or migrate enterprise evidence for current schema.
3. Add an exported `evidence_confidence.csv` or equivalent confidence contract.

Risk Rating: High.

### 2. Repository privacy boundaries need a stronger gate.

Seen By: Critic and Quality Gatekeeper.

Agreement:

- Both identified tracked raw lab evidence under `docs/lab-evidence/**` as a repository/history exposure risk.
- Both recognized that release packaging excludes lab evidence, but release exclusion does not protect repository readers, mirrors, generated docs, or history.
- Both recommended sanitizing or moving raw lab evidence and adding automated guards.

Synthesis:

The project has a good release-package boundary but not a complete repository-public boundary. That is a different class of risk. Even if release zips are clean, tracked raw evidence can still be visible through Git access or documentation publishing.

Recommended Action:

1. Decide whether raw lab evidence belongs in the public repo at all.
2. Replace raw tracked evidence with sanitized summaries where public proof is needed.
3. Add a CI guard for raw lab metadata markers outside explicitly redacted or synthetic evidence paths.

Risk Rating: High.

### 3. The release pipeline is useful but can still mislead maintainers.

Seen By: Builder, Critic, Quality Gatekeeper.

Agreement:

- Manual release dispatch can default to module version `0.1.0`, producing a stable-looking artifact while docs point to `v0.1.0-pre.14`.
- Current prerelease references are hard-coded across docs and tests.
- CI package smoke skips dependency-age checks, while real release packaging enforces them.
- Internal implementation-plan docs can be included in release packages unless explicitly excluded.

Synthesis:

The release story is good for pre-1.0, but its controls are distributed. Operators get an offline zip with hashes and prebuilt dashboard assets, but maintainers can still create confusing artifacts or ship internal planning docs.

Recommended Action:

1. Require explicit manual release versions or fail closed before 1.0.
2. Add a single release metadata source for current quickstart version.
3. Add dependency-age report validation to release-readiness CI.
4. Exclude internal planning docs from release packages.

Risk Rating: Medium-High.

### 4. PowerShell 5.1 is the promise, but current automated proof is incomplete.

Seen By: Quality Gatekeeper.

Related Signals: Builder praised the PowerShell-first collector design; Critic and Builder both relied on PowerShell 7/macOS-friendly local inspection rather than live Windows 5.1 proof.

Synthesis:

ShareSurfer is explicitly sold as PowerShell 5.1-friendly Windows collector tooling. CI currently runs on Windows, but the visible workflow uses `pwsh`, not `powershell.exe`. Passing PowerShell 7 does not prove Windows PowerShell 5.1 behavior for JSON, encoding, .NET types, parser differences, or platform APIs.

Recommended Action:

Add a Windows PowerShell 5.1 CI lane for module import, parser checks, and a critical test subset. Before 1.0, consider the full suite under `powershell.exe` a required gate.

Risk Rating: High for 1.0 claims, Medium for current pre-1.0 release.

### 5. The dashboard is becoming the primary product surface and needs engineering gates.

Seen By: Builder, Strategist, Quality Gatekeeper.

Agreement:

- Builder found `App.tsx` and dashboard data files large enough to slow safe extension.
- Strategist recommended dashboard performance and row-count review checks for enterprise evidence scale.
- Quality Gatekeeper recommended packaged dashboard smoke/e2e tests against real export data.

Synthesis:

The static dashboard is no longer a prototype sidecar; it is becoming the business-review product. The dashboard needs both maintainability work and release-quality gates, especially for offline packaged dashboards opened from transferred exports.

Recommended Action:

1. Add packaged static dashboard smoke/e2e tests with enterprise-scale row-count assertions.
2. Split dashboard app state, filters, views, and raw-evidence workbench into maintainable components/hooks.
3. Keep WebView2/signing later until the static package path is stable.

Risk Rating: Medium.

### 6. Operator documentation is a major strength, but choice overload is now real.

Seen By: Builder, Strategist, Quality Gatekeeper, Critic.

Agreement:

- Builder scored docs 5/5 for operator usefulness.
- Strategist said adoption friction is now more about choice overload than missing instructions.
- Quality Gatekeeper marked docs partial only because acceptance docs are stale relative to current schema proof.
- Critic found the README command inventory is stale relative to actual exported commands.

Synthesis:

The docs are unusually thorough, but the project now needs a tighter "Start Here" path and some metadata-driven consistency. Documentation depth should remain, but first-time operators need fewer forks in the first ten minutes.

Recommended Action:

1. Add a release-root or README "Start Here: Scan -> Validate -> Package -> Review -> Decide" path.
2. Update command inventory to reflect all exported commands, grouped by workflow.
3. Keep deep docs, but make stop gates and role-based next actions easier to see.

Risk Rating: Medium.

## Unique Findings

### Builder-unique emphasis

- Tests are too monolithic for continued feature velocity.
- Dashboard code size is a maintainability ceiling.
- Internal execution plans can ship in release packages.

These are not immediate operator hazards, but they predict future regression and contributor drag.

### Critic-unique emphasis

- Native filesystem ACL rights can render as numeric or negative masks.
- `Test-ShareSurferExport` does not validate optional open-file and port/protocol assessment exports.
- Manifest records requested provider instead of effective provider.

These are concrete correctness/supportability issues and should become focused implementation issues.

### Strategist-unique emphasis

- Evidence confidence should become an exported model.
- Owner packet and migration-cluster decisions need a lightweight export/import loop.
- Migration Discovery needs quality metrics against expected clusters.

These define product maturity after the immediate gate fixes.

### Quality Gatekeeper-unique emphasis

- Historical enterprise proof is accepted but no longer current-schema clean.
- Windows PowerShell 5.1 CI should be a first-class gate.
- Full enterprise redacted support bundle remains partial and should be proven before 1.0.

These are release-readiness standards, especially for 1.0.

## Disagreements And Tensions

### Documentation: excellent or partial?

Builder rated documentation 5/5. Quality Gatekeeper rated docs partial.

Resolution:

Both are right. Operator docs are excellent as instructions, but acceptance documentation is stale relative to current schema validation. Treat docs as a strength with one specific release-gate weakness: proof documents must clearly distinguish historical accepted proof from current-tree validation.

### Release signing and WebView2: now or later?

Strategist recommends waiting on signing/WebView2 until confidence/dashboard stability lands. Quality Gatekeeper wants stronger release gates before 1.0.

Resolution:

Do not prioritize WebView2 or signing immediately. Do prioritize release correctness now: fail-closed versioning, dependency-age readiness, static dashboard smoke, hashes, and package verification. Signing can remain later.

### Raw lab evidence: proof asset or privacy liability?

The project has treated lab evidence as proof. Critic and Gatekeeper treat tracked raw lab evidence as risk.

Resolution:

Keep proof, but change its public form. Public repo artifacts should be sanitized summaries, redacted bundles, or synthetic evidence. Raw host-side proof can live in controlled storage with hashes or public-safe attestations in the repo.

### Product polish versus hard gates

Strategist wants evidence confidence, owner decisions, and Migration Discovery quality. Critic/Gatekeeper want privacy, schema, release, and 5.1 gates.

Resolution:

Do the hard gates first where they could mislead operators or leak evidence. Then build evidence confidence as the bridge between product polish and release trust.

## Recommended Priority Order

### P0: Stop Potentially Misleading Or Sensitive Claims

1. Decide and fix the tracked raw lab evidence boundary.
2. Reconcile historical enterprise proof with current schema validation.
3. Make manual release versioning fail closed before 1.0.

### P1: Make Evidence Contracts Durable

1. Add schema parity checks across PowerShell, dashboard, and packager.
2. Add `CollectionProvider` to dashboard schema/raw evidence.
3. Extend export validation to optional assessment datasets.
4. Normalize native filesystem ACL rights masks.

### P2: Strengthen Release And Runtime Gates

1. Add Windows PowerShell 5.1 CI lane.
2. Add dependency-age report validation to release-readiness CI.
3. Add packaged static dashboard smoke/e2e gate.
4. Prove full enterprise redacted support bundle before 1.0.

### P3: Improve Builder Velocity

1. Split the monolithic PowerShell test runner into domain suites.
2. Refactor dashboard `App.tsx` into view components and hooks.
3. Add release metadata source instead of scattered prerelease literals.
4. Exclude internal planning docs from release packages.

### P4: Product Maturity

1. Export evidence confidence as data.
2. Add release-root "Start Here" role-based adoption path.
3. Add review decision export/import for owner packets and migration clusters.
4. Add Migration Discovery quality harness.
5. Integrate port/protocol readiness into confidence and dashboard stop gates.

## Suggested Next Three Issues

1. **Security/Privacy:** Sanitize or relocate raw lab evidence and add privacy guardrails.
2. **Validation:** Add schema parity/current acceptance checks and refresh current enterprise proof.
3. **Release:** Fix manual prerelease versioning and add release metadata consistency checks.

These three give the highest confidence lift without derailing the product roadmap.

## Confidence

Confidence is high that the themes above represent the real project quality posture because multiple independent lenses converged on the same risks. Runtime confidence is lower for Windows PowerShell 5.1 and live enterprise evidence because this review did not run a fresh live Windows/AD lab or a Windows PowerShell 5.1 CI lane.
