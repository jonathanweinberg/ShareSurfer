# ShareSurfer UX/UI Next Steps

Date: 2026-06-19
Tracking issue: https://github.com/jonathanweinberg/ShareSurfer/issues/272
Baseline reviewed: `origin/main` after `v0.1.0-pre.18`

## Executive Take

ShareSurfer's next product phase should be **guided review for migration readiness, anchored in operator trust**.

That means the product should not simply add more views or tables. It should help a Windows file-share operator move from release ZIP to validated evidence, then help business owners and migration leads understand what needs review, why it matters, who should review it, and which data areas should move together.

The strongest next promise is:

> ShareSurfer gets a Windows file-share operator from scan to validated evidence to owner and migration decisions without guessing, internet access, npm, remediation automation, or hidden magic.

## Design Brief

The current design brief is already clear from the product and user direction:

- Desktop-first and admin-workstation-first.
- Read-only, evidence-first, and offline-capable.
- PowerShell-first collection with Windows PowerShell 5.1 compatibility.
- Static dashboard packaging remains the portable review path.
- Business-friendly language appears before raw schema names.
- Raw evidence remains available for operators, support, and proof.
- No AI/LLM calls, cloud workflow dependency, or live permission remediation in the near-term UX path.

## Current Strengths

ShareSurfer has moved beyond a collector prototype. The current product already includes several strong UX foundations.

### Product And Evidence Model

- `README.md` now gives first-run operators a short Start Here path.
- `docs/command-recipes.md` offers copy/paste workflows.
- `docs/first-run-guide.md` and `docs/nonpermissive-collection-dashboard-workflow.md` cover regular and locked-down environments.
- `docs/export-schema.md` explains durable CSV evidence and optional assessment packages.
- `evidence_confidence.csv`, `port_protocol_*.csv`, `owner_review_packets.csv`, `related_data_areas.csv`, `owner_review_decisions.csv`, and `migration_cluster_decisions.csv` now give the dashboard real product substance.

### Dashboard

The standalone dashboard already has the right broad information architecture:

- Overview.
- Findings.
- Migration Discovery.
- Groups.
- Identity.
- Diagnostics.
- Raw Evidence.
- Ports & Protocols.

It is also meaningfully usable today:

- Global filters and active context.
- Scoped row filtering.
- Detail panes.
- Evidence drills.
- Local review decisions.
- CSV export.
- Report generated date and read-only context.
- Collapsible sidebar and wide-scroll table panes.

### Operator Workflow

`Start-ShareSurferOperatorAssistant` is a good seed. It safely writes:

- `operator-assistant.plan.json`
- `operator-assistant-rerun.ps1`

It does not collect data or change permissions, and it previews the exact command path an operator can review before running.

### Documentation

The docs now explain important ShareSurfer vocabulary:

- Owner versus NTFS owner.
- Partial data.
- Broken/Missing SID.
- Potential service account.
- Discounted access principal.
- Share gate versus file/folder permissions.
- Evidence confidence.
- Protocol readiness.

This is a real advantage for amateur-admin friendliness.

## Re-Evaluation Of Existing Plans

Several existing plans are still useful, but their role has changed after `v0.1.0-pre.18`.

### `docs/next-level-roadmap.md`

This roadmap is directionally right, but parts of it are now stale as future-tense planning.

These items are no longer only future roadmap ideas:

- Evidence confidence.
- Protocol readiness.
- Decision CSVs.
- Migration Discovery quality harness.
- Dashboard package proof.
- Start Here docs.
- Operator assistant entry point.

Keep the roadmap as strategic context, but treat it as needing a refresh before it is used as the active backlog.

### `docs/reviews/project-quality-review-2026-06-15/`

The multi-standard quality review remains valuable as historical risk discovery. It should not be treated as the active product backlog now that loops 1-11 are complete.

Use it when asking, "Why did we invest in release correctness, schema parity, dashboard proof, and Start Here docs?"

### `docs/reviews/production-readiness-tui-usability-2026-06-17.md`

This is currently the better sequencing spine. It already frames the right next move:

- Pure PowerShell guided assistant first.
- Richer TUI or WebView2 later.
- Production readiness defined through install, validation, package, trust, support, and comprehension evidence.

### `docs/standalone-dashboard-interface-spec.md`

This spec is still strong. It should now shift from broad "first standalone interface" language to the next implementation focus:

- Owner review packet.
- Migration candidate packet.
- Findings decision flow cleanup.
- Role-based start modes.
- Dashboard QA and performance gates.

## Primary UX Problem

ShareSurfer has enough evidence. The next friction is that users still have to connect too many pieces themselves.

An operator must mentally connect:

- Release ZIP setup.
- Recursive unblock.
- Target choice.
- OBS attribute choice.
- Ownership enrichment.
- Forbidden OUs.
- Discounted principals.
- Share collection provider.
- Validation.
- Dashboard packaging.
- Stop-gate review.
- Owner/migration decision import and export.

A business owner or migration lead must mentally connect:

- Evidence confidence.
- Owner routing.
- Groups granting access.
- Findings and conflicts.
- Related data areas.
- Migration readiness.
- Raw evidence.

The next UX move is to make those connections explicit through guided flows and packet views.

## Product Principles

Use these principles for the next UX implementation slices.

1. **Lead With A Decision**
   Every primary screen should answer what the user can decide next.

2. **Trust Before Review**
   Show scan confidence and stop gates before asking an owner to approve or clean up access.

3. **Packets Before Tables**
   Owners and migration leads should start with focused review packets. Tables remain available, but they should not be the first burden.

4. **Explain Why Rows Are Related**
   Migration Discovery must remain transparent. Relatedness should be explainable by signals, not opaque scoring.

5. **Local And Offline By Default**
   No remote services, telemetry, CDN dependency, or internet requirement for review.

6. **Show The Command**
   In CLI flows, every action should have a visible command preview and reusable output.

7. **Preserve Raw Evidence**
   Raw CSVs and raw evidence tables are proof surfaces. They should be secondary, not hidden.

8. **Defer Flash**
   Do not chase rich TUI frameworks, signed WebView2, or complex charting before the guided review flow is clear.

## Recommended Next Sequence

### Slice 1: Guided Operator Assistant V2

Make `Start-ShareSurferOperatorAssistant` feel like a real first-run interview instead of a flat prompt and rerun-script generator.

Key capabilities:

- Step labels and progress, such as `Step 3 of 9: Ownership inputs`.
- Current selections shown on every step.
- `next`, `back`, `skip`, `help`, `save`, and `quit` paths.
- Scan target chooser for UNC, computer/share, and NativeSmbRpc fallback.
- OBS attribute prompt with examples and reminder that `extensionAttribute10` may not exist in every schema.
- Ownership enrichment setup or skip.
- Forbidden OU selection or manual entry.
- Discounted principals setup or skip.
- Include-files and group-depth choices.
- Exact scan command preview before writing the rerun script.
- Stop-gate reminders in the generated plan.

Acceptance:

- Runs in Windows PowerShell 5.1.
- Requires no GUI file picker, npm, internet, or PowerShell 7.
- Writes a reusable JSON plan and `.ps1` rerun script.
- Does not collect data or change permissions unless the operator explicitly runs the generated command.
- Has no-color/plain-text fallback.
- Handles missing optional CSVs gracefully.

Validation:

- PowerShell test suite.
- Windows PowerShell 5.1 parser/import smoke.
- Transcript-style tests for happy path, missing CSVs, ambiguous headers, forbidden OU selection, quit/resume, and validation failure.

### Slice 2: First-Run Input Preparation Flow

Connect the existing ownership import, owner mapping, discounted principal, and forbidden OU work into one coherent preparation path.

Key capabilities:

- Browse/select candidate CSV files in pure text.
- Save selected files and mappings to `ownership-import.definition.json`.
- Regenerate `ownership-enrichment.csv` from the saved definition.
- Route users to `New-ShareSurferOwnerMappingDraft` when owner mapping is missing.
- Help create a starter `discounted-principals.csv`.
- Preserve all noninteractive command paths.

Acceptance:

- Users can combine multiple CSVs where one file has employee IDs and another has OBS/project/owner facts.
- The CLI explains what was matched, ambiguous, source-only, skipped by forbidden OU, or flagged as potential service-account-like.
- Generated commands are reusable without repeating the interview.
- Missing owner mapping is treated as a review routing gap, not as a scan failure.

Validation:

- Unit tests for saved definition loading.
- Tests for multiple CSV source merging.
- Tests for forbidden OU skip output.
- Tests for reusable command generation.
- Docs checks for quickstart references.

### Slice 3: Dashboard Owner Review Packet

Selecting an owner or business unit should open one focused packet instead of dropping the reviewer into broad tables.

The packet should answer:

- Why am I seeing this?
- Can I trust this scan enough to review it?
- What needs review first?
- Which groups grant access?
- Which paths are most important?
- Which findings or conflicts block signoff?
- What should I decide or send back?

Packet content:

- Owner and business unit.
- Scan generated date and confidence.
- Stop gates and review gates.
- Top findings and conflicts.
- Permissioned groups that grant access.
- Potential service-account-like identities.
- Broken/Missing SID rows.
- Top paths and example paths.
- Related migration areas.
- Local decision state and export shown evidence.

Acceptance:

- Owner selection from Overview opens the packet.
- Packet has business-language headings before raw schema details.
- Raw evidence is available through drills, not forced into the default view.
- Packet can export currently shown rows for handoff.
- Empty states explain missing owner mapping or missing evidence.

Validation:

- Dashboard unit tests for owner packet derivation.
- Packaged dashboard file-url smoke.
- Screenshot review at 1280x720 and 1440x1000.
- No raw evidence table becomes the default business-owner path.

### Slice 4: Dashboard Migration Candidate Packet

Migration Discovery should become a guided candidate packet, not only a cluster selector.

The packet should answer:

- Which shares, folders, and files appear related?
- Why are they grouped?
- Which owners/business units are involved?
- What blocks migration planning?
- Which groups grant access across the area?
- What should happen next?

Packet content:

- Related data area name.
- Owner and business unit.
- Migration readiness.
- Relatedness strength.
- Matching signals.
- Shares and top paths.
- Long-path, inheritance, deep explicit ACE, and conflict blockers.
- Partial-data and collection gaps.
- Permission-bearing groups and expanded member counts.
- Decision state: confirmed owner, cleanup needed, rerun needed, migration candidate, wrong owner.

Acceptance:

- Every related-data packet explains its grouping signals.
- Discounted principals remain visible but do not inflate relatedness.
- Packet export produces a local handoff CSV or shown-evidence CSV.
- Partial data cannot look like approval.

Validation:

- Migration fixture tests against `tests/fixtures/migration-discovery-quality/expected_related_data_areas.csv`.
- Dashboard tests for relatedness signals and readiness labels.
- Packaged dashboard smoke with representative export-shaped data.

### Slice 5: Findings Decision Flow Cleanup

The Findings view has useful detail, but it can feel operator-heavy before a reviewer understands the decision.

Reframe it around:

- Issue categories.
- Selected issue detail.
- Why it matters.
- Recommended next action.
- Review decision.
- Raw evidence drawer.

Move advanced analysis pivots behind an `Analysis tools` disclosure.

Acceptance:

- Default Findings view starts with business-readable issue categories and selected issue detail.
- Critical scan blocks are visible, but do not drown out the issue decision path.
- Finding rollups filter into the matching issue rows.
- Review decision controls remain local/offline and exportable.

Validation:

- Dashboard tests for category filters.
- E2E smoke for click-rollup-to-filter behavior.
- Screenshot review for readability and density.

### Slice 6: Role-Based Dashboard Start Modes

Add a lightweight role chooser or role-oriented first screen without changing the underlying data model.

Roles:

- Business Owner: start with owner packet and access review.
- Migration Lead: start with Migration Discovery and readiness.
- Operator: start with scan confidence, diagnostics, ports/protocols, and raw evidence.

Acceptance:

- Role mode changes the starting emphasis, not the evidence.
- Active role is visible in screenshots.
- Users can switch roles without losing filters.
- Raw evidence remains available in all roles.

Validation:

- Dashboard state tests.
- Keyboard navigation tests.
- Screenshot review across role modes.

### Slice 7: Dashboard QA Gate

Before deeper dashboard polish, add stronger dashboard quality gates.

Gates:

- Enterprise-shaped snapshot load.
- Filter latency budget.
- No blank app.
- No external network calls.
- Tooltip keyboard access.
- No text overlap in target desktop viewports.
- Raw evidence pagination/export proof.
- Packaged dashboard file-url smoke, not only Vite/dev mode.

Acceptance:

- A representative export-shaped fixture drives automated checks.
- The package path is tested through `scripts/New-ShareSurferStandaloneDashboard.ps1`.
- Failures produce useful operator/developer messages.

Validation:

- `npm --prefix interface/standalone-dashboard run test`
- `npm --prefix interface/standalone-dashboard run build`
- `npm --prefix interface/standalone-dashboard run test:e2e`
- PowerShell package script smoke when dashboard packaging changes.

### Slice 8: Release And Trust UX

After packet flows and assistant flow improve, make release trust easier for operators.

Key capabilities:

- `Test-ShareSurferReleasePackage` or equivalent.
- Offline hash and manifest verification.
- Clear source commit, dependency-age report, and signing status.
- Explicit unsigned pre-1.0 wording until signing exists.
- Internal planning docs excluded from packages.

Acceptance:

- Operators can verify a release ZIP offline.
- The docs explain what the release package proves and does not prove.
- Signing/WebView2 remains later unless explicitly scoped.

Validation:

- Release-readiness tests.
- Package manifest tests.
- Hash verification tests.

## UX Issue Backlog Candidates

Use these as follow-up issue titles.

1. `UX: build guided operator assistant v2`
2. `UX: connect ownership, forbidden OU, and discounted-principal input preparation`
3. `Dashboard: add owner review packet view`
4. `Dashboard: add migration candidate packet view`
5. `Dashboard: simplify findings decision flow`
6. `Dashboard: add role-based start modes`
7. `Dashboard: add enterprise UX QA gate`
8. `Release: add offline package verification UX`
9. `Docs: refresh next-level roadmap after v0.1.0-pre.18`
10. `Docs: refresh dashboard screenshots after packet views land`

## Validation Matrix

| Workstream | Required gates |
| --- | --- |
| PowerShell assistant | `pwsh -NoLogo -NoProfile -File tests/Invoke-ShareSurferTests.ps1`; Windows PowerShell 5.1 smoke; transcript tests |
| Ownership input UX | multi-CSV merge tests; definition/rerun tests; forbidden OU tests; docs checks |
| Dashboard packet views | dashboard unit tests; packaged file-url smoke; screenshot review; no-network check |
| Migration Discovery UX | migration harness tests; relatedness signal tests; discounted principal behavior checks |
| Findings flow | rollup-to-filter tests; review decision tests; screenshot density review |
| Release trust UX | release-readiness tests; package hash/manifest verification; dependency-age evidence |

## Explicit Deferrals

These are useful, but they should not block the next UX phase:

- Permission-changing remediation.
- Cloud workflow automation.
- AI/LLM-generated summaries or ownership guesses.
- Required WebView2 viewer.
- Required Terminal.Gui, Spectre.Console, or other rich TUI framework.
- Release signing as a precondition for packet-flow work.
- Multi-user collaboration or shared state service.
- Redacted support-bundle expansion beyond preserving current baseline behavior.
- Mobile-first dashboard optimization.
- Complex charting before packet flows are clear.

## Source Surfaces Reviewed

MainThread reviewed:

- `README.md`
- `docs/standalone-dashboard-interface-spec.md`
- `docs/reviews/production-readiness-tui-usability-2026-06-17.md`
- `docs/next-level-roadmap.md`
- `docs/business-review-handoff.md`
- `docs/command-recipes.md`
- `docs/visuals/dashboard-screenshots/2026-06-09-current/README.md`
- `src/ShareSurfer/Public/Start-ShareSurferOperatorAssistant.ps1`
- `interface/standalone-dashboard/src/App.tsx`
- `interface/standalone-dashboard/src/styles.css`
- `interface/standalone-dashboard/src/data/deriveDashboard.ts`
- `interface/standalone-dashboard/package.json`

Subagent reviews covered:

- Dashboard UX and information architecture.
- Operator/admin first-run UX.
- Product strategy and roadmap prioritization.

## Bottom Line

The next step is not a broad rewrite. ShareSurfer should make the current evidence model feel guided.

Start with the operator assistant because it prevents bad first runs. Then make the dashboard packet-based because it prevents bad reviews. After that, strengthen QA and release trust so each prerelease feels easier to adopt in controlled Windows environments.
