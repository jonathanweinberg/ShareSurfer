# ShareSurfer Issue 184 Native SMB/RPC Evidence

This folder contains a focused Windows/AD lab validation snapshot for issue #184, which added the `NativeSmbRpc` SMB collection provider.

## Run Summary

- Run stamp: `20260610-183619`
- Validated commit: `7fdc605340a45fee98134849e40c9558c2bc6415`
- Lab context: Windows Server / Active Directory test lab with existing ShareSurfer enterprise fixture data.
- Provider under test: `NativeSmbRpc`
- Comparison provider: `PowerShellCim`
- Native report output: `native-report.html`
- Overall result: passed

## Native Provider Counts

- Shares: `3`
- Items: `61`
- Share permission rows: `6`
- File/folder ACL rows: `427`
- Collection errors: `0`
- Scan events: `12`

## Comparison Counts

The same bounded share sample was scanned with the `PowerShellCim` provider for comparison:

- Shares: `3`
- Items: `61`
- Share permission rows: `6`
- File/folder ACL rows: `427`

## Checks

All validation checks passed:

- Native export schema validation succeeded with `0` schema errors.
- PowerShell CIM comparison export schema validation succeeded with `0` schema errors.
- `scan_manifest.csv` recorded `CollectionProvider=NativeSmbRpc`.
- Scan events recorded the selected native provider.
- No `RemoteCimSessionCreated` event was recorded for the native scan.
- Native share rows and share-permission rows were sourced from `NativeSmbRpc`.
- Native item rows contained owner evidence.
- Native ACL rows contained identity evidence.
- The offline static HTML report was generated.
- The comparison scan produced rows for shares, items, share permissions, and ACL entries.

## Contents

- `native-validation-summary.json` - machine-readable validation summary.
- `native-validation-checks.csv` - individual pass/fail checks.
- `native-report.html` - offline report generated from the native export.
- `native-export/` - complete normalized CSV export set from the `NativeSmbRpc` scan.
- `powershellcim-export/` - complete normalized CSV export set from the comparison `PowerShellCim` scan.

This is a bounded proof run, not a full enterprise-scale acceptance run. It is intended to prove the issue #184 collection path: native share metadata, native share permissions, native file/folder ownership, native DACL rows, export validation, report generation, and no remote-CIM provider event for the native scan.
