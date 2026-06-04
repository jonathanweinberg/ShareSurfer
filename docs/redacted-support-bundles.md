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
  -RedactionSalt 'internal-case-1234'
```

Validate the bundle before sharing:

```powershell
Test-ShareSurferExport -ExportPath 'C:\ShareSurfer\support\scan-2026-06-04-redacted'
```

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
- `support_bundle_manifest.csv` with redaction mode, validation status, and bundle-level file counts.
- `support_bundle_files.csv` with redacted CSV row counts and SHA256 hashes for support-case integrity checks.
- Any validation result from `Test-ShareSurferExport`.
- A redacted report, if generated.

Do not include a reversal map in the shared bundle. If an implementation produces a map for internal troubleshooting, store it separately with the raw export and treat it as sensitive.

## Review Before Sharing

Before sending a support bundle outside the trusted team:

1. Search the bundle for obvious source domains, server names, user names, and share names.
2. Confirm paths and identities use synthetic tokens.
3. Confirm relationships still work across CSV files.
4. Confirm the Azure path policy threshold and explicit ACE depth threshold are still visible.
5. Share the smallest bundle that answers the support question.
