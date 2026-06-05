# Redacted Support Bundles

`New-ShareSurferSupportBundle` creates a shareable copy of a ShareSurfer export with sensitive values replaced by redacted tokens. Use it when asking for support, sending samples to another team, or attaching evidence to an issue where raw names and paths should not leave the trusted environment.

## Workflow

Validate the raw export first:

```powershell
Test-ShareSurferExport -ExportPath $exportPath
```

Create a redacted bundle:

```powershell
New-ShareSurferSupportBundle `
  -ExportPath $exportPath `
  -OutputPath 'C:\ShareSurfer\support\scan-2026-06-04-redacted' `
  -RedactionMode StableToken `
  -RedactionSalt 'internal-case-1234' `
  -IncludeReport
```

When the bundle is for a ShareSurfer lab validation run, include the run folder too. The lab validation script does this automatically.

```powershell
New-ShareSurferSupportBundle `
  -ExportPath 'C:\ShareSurfer\lab-validation\20260604-193000\export' `
  -OutputPath 'C:\ShareSurfer\lab-validation\20260604-193000\support-bundle-redacted' `
  -RedactionMode StableToken `
  -IncludeReport `
  -RunRoot 'C:\ShareSurfer\lab-validation\20260604-193000'
```

Validate the bundle before sharing:

```powershell
Test-ShareSurferExport -ExportPath 'C:\ShareSurfer\support\scan-2026-06-04-redacted'
```

Review the redaction audit before sharing:

```powershell
Import-Csv 'C:\ShareSurfer\support\scan-2026-06-04-redacted\support_bundle_redaction_audit.csv' |
  Where-Object { $_.LeakDetected -eq 'True' }
```

This should return no rows. The audit stores source-value tokens and lengths, not raw source values.

## Stable Token Redaction

Stable token redaction replaces repeated sensitive values with the same synthetic value. This preserves joins and relationships while hiding the original value.

Example behavior:

- `CONTOSO\FinanceEditors` becomes a stable token such as `ID-000001`.
- The same source identity gets the same token in `acl_entries.csv`, `identities.csv`, `group_edges.csv`, `conflicts.csv`, and `findings.csv`.
- Different identities, servers, shares, and paths get different tokens.

Use a case-specific salt when you need stable tokens within one support case. Reusing the same salt across unrelated bundles can make cross-bundle correlation easier.

## Data To Redact

The support bundle should redact or tokenize:

- Domain names, computer names, share names, UNC paths, local paths, full paths, and relative paths.
- User, group, service account, display, employee, and manager names.
- Employee IDs and employee numbers.
- OBS paths, business unit names, owner names, and owner mapping patterns.
- Free-text descriptions or evidence fields that can contain names or paths.

The support bundle should preserve:

- IDs needed for joins, or replace them with stable synthetic IDs.
- Rights, access-control types, inheritance flags, propagation flags, item types, depths, booleans, and timestamps.
- Finding types, conflict types, severities, policy names, and policy values.
- Scan settings such as `OperationalPathLengthThreshold` and `ExplicitAceDepthThreshold`.

## What To Include

A useful support bundle includes:

- The full redacted CSV export set.
- `scan_manifest.csv` with sensitive values redacted but scan settings preserved.
- `owner_risk_pivots.csv` with owner/business-unit tokens but preserved counts, access-review sizing, and risk levels for support triage.
- `related_data_areas.csv` with owner/business-unit/path tokens but preserved migration readiness, relatedness reasons, counts, and suggested next actions.
- `owner_review_packets.csv` with owner/business-unit/path tokens but preserved review status, why-review guidance, where-to-start guidance, counts, and suggested next actions.
- `scan_events.jsonl` with redacted structured scan events for support tools that prefer JSON Lines logs.
- `support_bundle_manifest.csv` with redaction mode, validation status, and bundle-level file counts.
- `support_bundle_files.csv` with redacted CSV row counts and SHA256 hashes for support-case integrity checks.
- `support_bundle_summary.json` with a quick redacted bundle health summary, validation result, redaction status, and file inventory.
- `support_bundle_diagnostics.json` with redacted scan settings, export counts, finding/conflict rollups, partial-share counts, and collection-error counts for support triage.
- `support_bundle_redaction_audit.csv` with checked source-value tokens, leak status, and leak file names when any are found.
- `lab_run_diagnostics.json`, `lab_run_events.jsonl`, `lab_preflight.csv`, `lab_validation_criteria.csv`, `live_evidence_review.csv`, `live_evidence.json`, and `v1_acceptance.json` when `-RunRoot` is used after a lab validation run has produced acceptance evidence.
- Any validation result from `Test-ShareSurferExport`.
- A regenerated redacted `report.html`, when `-IncludeReport` is used.

Do not include a reversal map in the shared bundle. If an implementation produces a map for internal troubleshooting, store it separately with the raw export and treat it as sensitive.

## Review Before Sharing

Before sending a support bundle outside the trusted team:

1. Search the bundle for obvious source domains, server names, user names, and share names.
2. Confirm paths and identities use synthetic tokens.
3. Confirm relationships still work across CSV files.
4. Confirm `support_bundle_manifest.csv` shows `RedactionLeakCount` as `0`.
5. Confirm `support_bundle_summary.json` shows `Validation.IsValid=True` and `Redaction.LeakCount=0`.
6. Review `support_bundle_diagnostics.json` for safe scan settings, counts, and collection-health context.
7. For lab validation bundles, review `lab_run_diagnostics.json`, `lab_run_events.jsonl`, and the redacted lab evidence CSVs for pass/fail context.
8. Confirm `support_bundle_redaction_audit.csv` has no rows with `LeakDetected=True`.
9. Confirm the Azure path policy threshold and explicit ACE depth threshold are still visible.
10. Share the smallest bundle that answers the support question.
