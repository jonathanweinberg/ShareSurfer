# ShareSurfer Standalone Dashboard Interface Spec

Status: review draft  
Date: 2026-06-05  
Scope: standalone interface direction for ShareSurfer review dashboards

## Purpose

ShareSurfer already has a strong collector and export story. The next interface should make the review experience feel less like reading ACL tables and more like walking through a guided business review.

The standalone dashboard should help a non-specialist answer:

- What needs my attention first?
- How confident is this scan?
- Which owner, business unit, group, or migration area should review this?
- What happened, why does it matter, and what should we do next?
- Where is the raw evidence if an operator needs to prove or troubleshoot it?

## Current Truth Surfaces

The new interface must stay grounded in the current V1 surfaces:

- `src/ShareSurfer/Public/ConvertTo-ShareSurferReport.ps1`
- `docs/export-schema.md`
- `docs/first-run-guide.md`
- `docs/management-overview.md`
- `docs/visuals/report-dashboard-*.png`
- `docs/visuals/concepts/ux-ui-vision-art/*.png`
- `docs/lab-evidence/windows-ad-enterprise-20260605-101639/20260605-101639/export`
- `docs/lab-evidence/windows-ad-enterprise-20260605-101639/20260605-101639/report.html`

The concept images are design references, not proof artifacts. The generated report and normalized CSV exports remain the product source of truth.

Current mainline identity review signals include three-level manager context and potential service-account candidates. The standalone dashboard should treat these as first-class review signals because the current offline report already surfaces them.

## Current Constraints

The existing offline report is valuable because it works in controlled environments with no server and no internet dependency. It should remain supported.

The current enterprise evidence pack also shows the scale pressure:

| Evidence | Current enterprise rows |
| --- | ---: |
| Shares | 250 |
| Items | 5,728 |
| ACL entries | 41,278 |
| Conflicts | 32,309 |
| Findings | 263 |
| Permissioned groups | 500 |
| Group edges | 1,253 |
| Owner review packets | 250 |

The archived enterprise `report.html` is about 32 MB because it embeds all data. A richer dashboard must not re-render all large tables on every filter interaction.

## Product Recommendation

Build a static standalone web interface as the primary future dashboard path, while keeping the existing generated single-file report as the airgap-safe fallback.

Recommended product split:

| Option | Recommendation | Why |
| --- | --- | --- |
| Static React-style interface | Primary path | Best match for concept art, tooltips, drawers, virtual tables, guided flows, and future dashboard polish. |
| Existing offline HTML report | Keep as fallback | It is already validated, dependency-free, and works in highly controlled environments. |
| Standalone Python UI | Secondary/internal | Useful for analyst profiling or local diagnostics, but less natural for business-review dashboard UX. |

Runtime principle: no production data leaves the local environment. Any static app must open local exports or bundled report data without calling external services.

## Users

### Business Owner

Needs plain review packets, fewer technical terms, and a clear next action. Should start in the review queue or a focused owner workbench.

### Migration Lead

Needs related data areas, readiness states, path and scan-gap warnings, and exportable migration packets.

### Windows/File Share Operator

Needs scan confidence, diagnostics, raw evidence, settings, and collection-error detail.

### Support/Maintainer

Needs redacted bundle health, row counts, schema validation, and enough raw table access to debug issues without raw customer values.

## Design Principles

1. Lead with business meaning, not schema names.
2. Keep raw evidence available, but secondary.
3. Explain technical terms at the point of use with hover and keyboard-focus tooltips.
4. Never hide scan gaps. Partial data should be visually obvious.
5. Use evidence labels: observed, inferred, calculated, partial, redacted.
6. Keep all views read-only unless a future remediation workflow is explicitly approved.
7. Prefer fast, bounded views over huge always-live tables.
8. Make filters visible as context chips so screenshots are self-explaining.

## Information Architecture

| View | Primary user | Purpose | Technical detail posture |
| --- | --- | --- | --- |
| Overview | Business owner, leader | Scan confidence, KPI cards, quick insights, review queue | Hide raw fields behind tooltips and drawers |
| Start Here / Review Queue | Business owner | Prioritized owner packets and next actions | Show why-review language first |
| Owners & Workbench | Business owner, operator | One owner/business-unit focused review workspace | Show direct identity and group sizing with explainers |
| Findings & Conflicts | Business owner, operator | Issue cards, detail panel, raw evidence for selected issue | Translate finding/conflict types to plain names |
| Migration Discovery | Migration lead | Related data clusters and migration packet | Show readiness, relatedness, and scan gaps first |
| Groups | Operator, owner delegate | Permissioned groups, expansion tree, assignments | Explain expanded members, truncation, and cycles |
| Identity & Org Context | Business owner, operator | OBS path, manager chain, office/title clues, and potential service-account candidates | Plain labels first, directory fields on demand |
| Diagnostics | Operator, support | Partial data, collection errors, scan events, export health | Technical by design, but labeled clearly |
| Raw Evidence | Operator, support | CSV-like explorer for all exported datasets | Keep exact schema names and raw rows |
| About This Report | Everyone | Scan settings, thresholds, redaction state, source files | Plain descriptions plus raw settings table |

## Concept Art Translation

The concept images should influence layout and hierarchy, not force exact pixel matching.

Adopt from `dashboard-overview-concept.png`:

- Left navigation for stable mental model.
- Top scan metadata: generated time, source, read-only report status.
- KPI cards with icons and short labels.
- Scan confidence card with partial-data reasons.
- Quick insights panel.
- Owner/business-unit review queue near the top.

Adopt from `migration-discovery-concept.png`:

- Cluster list on the left.
- Selected cluster packet on the right.
- "Why these are related" cards.
- Recommended next actions with checkboxes or review status markers.

Adopt from `group-expansion-concept.png`:

- Permissioned group list.
- Membership tree with cycle and truncation warnings.
- Access assignment panel.
- Ownership and org context for the selected group.

Adopt from `findings-conflicts-concept.png`:

- Plain issue categories.
- List/detail layout.
- "What happened", "Why it matters", "Recommended next action", and "Raw evidence" sections.
- Clear distinction between share gate and folder/file permissions.

## Data Contract

The interface should consume the existing V1 export schema without requiring scanner changes for the first prototype.

Required input files:

- `shares.csv`
- `items.csv`
- `share_permissions.csv`
- `acl_entries.csv`
- `identities.csv`
- `group_edges.csv`
- `permissioned_groups.csv`
- `org_chains.csv`
- `owner_mappings.csv`
- `owner_risk_pivots.csv`
- `related_data_areas.csv`
- `owner_review_packets.csv`
- `conflicts.csv`
- `findings.csv`
- `collection_errors.csv`
- `scan_events.csv`
- `scan_manifest.csv`

Identity fields should follow the current V1 schema. In particular, `identities.csv` and `org_chains.csv` now include `ManagerLevel3` and `PotentialServiceAccount`. The standalone dashboard should not assume manager context stops at two levels, and it should present potential service-account rows as review candidates rather than confirmed service accounts.

Derived view models:

| View model | Built from | Purpose |
| --- | --- | --- |
| `scanSummary` | manifest, shares, findings, conflicts, errors | KPI cards and scan confidence |
| `reviewQueue` | owner review packets, pivots, findings, conflicts | Start-here review queue |
| `issueSummaries` | findings, conflicts, items, shares | Business-readable findings/conflicts |
| `migrationClusters` | related data areas, pivots, items, shares | Migration discovery packets |
| `permissionedGroupTree` | permissioned groups, group edges, identities | Group browser and expansion view |
| `identityReviewSignals` | identities, org chains, findings | Potential service-account candidates and manager-chain context |
| `diagnosticSummary` | collection errors, scan events, shares | Scan confidence and diagnostics |
| `rawEvidenceCatalog` | all CSVs | Raw evidence explorer |

The display layer should not rename export columns. Instead, maintain a separate label and tooltip registry so raw exports remain stable.

## Tooltip And Hover System

Tooltips must work with both hover and keyboard focus. Tooltips should explain the concept in plain language and, where useful, offer a "show raw evidence" affordance.

Initial tooltip registry:

| Term | Plain label | Tooltip text |
| --- | --- | --- |
| Share gate | Share-level access | The front door to the share. A user still needs folder or file permission after passing this gate. |
| File/folder permissions | Folder and file access | Permissions on folders or files inside the share. These can allow, limit, or deny access after the share gate. |
| Partial data | Incomplete scan evidence | ShareSurfer found the target but could not prove all expected metadata. Open Diagnostics before using this area for approval. |
| Review risk | Review priority | A simple routing label based on high-severity findings, conflicts, or scan gaps. It is not final approval. |
| Migration readiness | Migration planning state | A planning signal that shows whether scan gaps, conflicts, or findings should be reviewed before migration. |
| Owner mapping | Business ownership rule | A rule that maps paths or shares to an owner and business unit. Owners should confirm it before cleanup. |
| Related data area | Migration cluster | Shares, folders, or files that appear related by owner, business unit, path pattern, group overlap, or shared risk. |
| Permissioned group | Group granting access | A security group observed directly on the share gate or folder/file permissions. |
| Expanded members | Members found through groups | Users or nested groups found during group expansion. This may be incomplete if expansion was truncated. |
| Group truncation | Expansion limit reached | Group expansion stopped at the configured depth or size limit. Increase the limit or review directory access if needed. |
| OBS path | Org/business structure path | A directory attribute used to connect identities and groups to business structure. The attribute name is scan-specific. |
| Manager level 3 | Third-level manager | The next manager above a manager's manager when directory data is available. It helps route escalation, not approval. |
| Potential service account | Account purpose needs review | A user account with no OBS value and no employee identifier collected. It may be automation, or it may be incomplete directory data. |
| Collection error | Scan gap | A recorded problem while resolving, enumerating, or reading share, folder, file, ACL, or directory metadata. |
| Long path warning | Path migration warning | The path exceeded ShareSurfer's operational migration threshold. This is separate from Azure Files hard limits. |
| Deep explicit permission | Custom permission deep in tree | A non-inherited permission was found below the configured depth threshold. It may need owner review. |
| Broken inheritance | Inheritance stopped | A folder or file stopped inheriting permissions from its parent. Review whether that was intentional. |

## Performance Requirements

Initial targets for enterprise-sized exports:

- Load shell and metadata before rendering large tables.
- Do not render more than one major table view at a time.
- Cap first paint tables to a visible page, then virtualize or paginate.
- Keep filter interactions under 250 ms for owner, risk, and search filters on the current enterprise evidence pack.
- Keep a selected issue detail drawer responsive even when raw evidence contains tens of thousands of rows.
- Keep raw evidence exploration paginated, searchable, and dataset-scoped.
- Add a dashboard review check that records file size, input row counts, first-render timing, and filter timing.

## Accessibility And Usability

Minimum bar:

- Tooltips are reachable by keyboard focus.
- Icon buttons have visible labels or accessible names.
- Tables have sticky headers or equivalent context.
- Filter chips are removable with keyboard controls.
- Color is not the only risk signal.
- Long paths wrap or truncate with copy/open affordances.
- No text overlaps in 1280x720 and 1440x1000 viewports.

## Security And Privacy

The interface must preserve current raw-vs-redacted boundaries.

- Raw exports are trusted-environment artifacts.
- Redacted support bundles must continue using stable token redaction.
- Tooltips, examples, and screenshots must use synthetic data.
- No telemetry, CDN, SaaS upload, or remote font dependency.
- A read-only badge must be visible on every primary view.
- Raw evidence access should be obvious but not the default business-owner path.

## Open Review Questions

1. Should the first standalone interface load a folder of CSV files, a generated JSON snapshot, or both?
2. Should the interface be packaged as a static React app for maintainers, while `ConvertTo-ShareSurferReport` continues to generate single-file HTML for airgapped operators?
3. Should raw evidence be available in all builds, or should a business-owner packet mode hide raw tables by default?
4. Should per-owner and per-migration-cluster export packets be in scope for the first implementation slice?
5. Which terms need tooltips before any others: access model, migration readiness, OBS, partial data, or group expansion?
6. Should phase 1 prioritize performance on the archived enterprise export before adding all concept-art views?

## Acceptance Criteria

A first reviewable standalone interface is successful when:

- It loads the current enterprise export without freezing the browser.
- It presents a business-first overview with scan confidence, quick insights, and review queue.
- It has working filters with visible context chips.
- It explains at least the initial tooltip registry terms on hover and keyboard focus.
- It renders Findings & Conflicts as issue summaries with detail panels.
- It renders Migration Discovery as cluster packets.
- It renders Groups as a permissioned group list plus expansion detail.
- It renders identity review signals, including potential service-account candidates and three-level manager context when present.
- It keeps Raw Evidence available as a secondary operator view.
- It passes the existing PowerShell test suite and a new browser/dashboard performance smoke test.
