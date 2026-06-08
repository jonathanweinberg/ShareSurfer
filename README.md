# ShareSurfer

ShareSurfer helps business units understand complex Windows file-share access by collecting share permissions, filesystem ACLs, ownership, inheritance state, identity enrichment, group expansion, org context, and migration-readiness findings.

V1 is PowerShell-first and designed for airgapped or tightly controlled environments:

- PowerShell 5.1 module layout under `src/ShareSurfer`
- Normalized CSV export set for Excel, Power BI, and downstream analysis
- Dynamic offline HTML report with no server or internet dependency
- Windows/AD lab fixture planning and live fixture creation on Windows hosts
- Raw export validation plus redacted support bundle generation

## Commands

- `New-ShareSurferLabFixture`
- `Invoke-ShareSurferScan`
- `ConvertTo-ShareSurferReport`
- `New-ShareSurferSupportBundle`
- `Test-ShareSurferExport`

## Basic Use Cases

ShareSurfer is useful when access data is too complex for business owners to review directly from Windows tools.

| Use case | Start here | Output to review |
| --- | --- | --- |
| First business-owner review | Scan one known share with owner mapping | `owner_review_packets.csv`, `owner_risk_pivots.csv`, and `report.html` |
| Migration discovery | Scan related shares with file/folder evidence and owner mappings | `related_data_areas.csv`, long-path findings, inheritance breaks, and share-vs-NTFS conflicts |
| Nonpermissive collector workflow | Collect on a locked-down Windows host, then transfer the validated dataset to a dashboard host | Validated CSV export folder, `report.html`, optional standalone dashboard folder |
| Broad admin or HelpDesk access cleanup | Provide a discounted principals CSV | Visible access evidence that does not inflate Migration Discovery relatedness |
| Support or bug report | Create a redacted support bundle after export validation | Stable-token CSVs, manifests, and optional redacted report |

The most common production pattern is two-host review:

![Dataset transfer to dashboard host](docs/visuals/dataset-transfer-dashboard-workflow.png)

1. Run the collector inside the restricted file-share environment.
2. Validate the raw CSV export set.
3. Package the export folder and move it by an approved transfer process.
4. Open `report.html` or package the standalone dashboard on a more permissive review workstation.

See the [nonpermissive collector to dashboard host workflow](docs/nonpermissive-collection-dashboard-workflow.md) for a full walkthrough.

## Quick Start

For a first-time walkthrough, start with the [First-run guide](docs/first-run-guide.md). It explains prerequisites, target selection, collector commands, CSV outputs, reports, and redacted support bundles for operators who are new to ShareSurfer or new to Windows file-share auditing.

```powershell
Import-Module .\src\ShareSurfer\ShareSurfer.psd1 -Force

$exportPath = 'C:\ShareSurfer\exports\scan-001'

Invoke-ShareSurferScan -TargetPath '\\files01\Finance' -OutputPath $exportPath
Test-ShareSurferExport -ExportPath $exportPath
ConvertTo-ShareSurferReport -ExportPath $exportPath -OutputPath "$exportPath\report.html"
New-ShareSurferSupportBundle -ExportPath $exportPath -OutputPath 'C:\ShareSurfer\support\scan-001-redacted'
```

To keep broad operational access visible without letting it drive Migration Discovery, pass a discounted principal CSV:

```powershell
Invoke-ShareSurferScan -TargetPath '\\files01\Finance' -OutputPath $exportPath -DiscountedPrincipalPath 'C:\ShareSurfer\inputs\discounted-principals.csv'
```

The CSV must include `Identity` and can include `Reason` and `Scope`. Discounted means visible access evidence that is not used for migration relatedness; it does not mean ignored, safe, approved, or remediated.

## Standalone Dashboard Prototype

ShareSurfer also includes a React/Vite standalone dashboard prototype for richer local review. It is build-time tooling only; packaged dashboard output is static, offline, and opens from `index.html` on Windows or macOS without npm, Vite, a server, or internet access.

Run the dashboard during development:

```powershell
npm --prefix interface/standalone-dashboard run dev
```

Build the static dashboard assets:

```powershell
npm --prefix interface/standalone-dashboard run build
```

Package a validated export folder as a standalone dashboard:

```powershell
pwsh -NoLogo -NoProfile -File scripts/New-ShareSurferStandaloneDashboard.ps1 `
  -ExportPath $exportPath `
  -OutputPath "$exportPath\standalone-dashboard" `
  -Force
```

Open `standalone-dashboard\index.html` on Windows or `standalone-dashboard/index.html` on macOS. The package uses relative assets and `sharesurfer-data.js`, so it can be copied, zipped, or opened directly from disk.

## Lab Fixture

Plan the lab first:

```powershell
New-ShareSurferLabFixture -OutputPlanOnly -RootPath 'C:\ShareSurferLab' -DomainNetBiosName 'CONTOSO' -ObsAttribute 'extensionAttribute10'
```

On a disposable Windows/AD lab host, rerun without `-OutputPlanOnly` to create the filesystem/share fixtures and, when the ActiveDirectory module is available, demo users, groups, manager chains, employee fields, and OBS extension attributes. The lab plan includes directory ACLs, file-specific ACLs, ownership examples, broken inheritance, deep explicit ACEs, long-path fixtures, NTFS deny examples, and share-vs-NTFS conflict cases.

Enterprise validation should use the scaled profile:

```powershell
New-ShareSurferLabFixture -OutputPlanOnly -RootPath 'C:\ShareSurferEnterpriseLab' -Scale Enterprise -EnterpriseUserCount 2500 -EnterpriseShareCount 250 -EnterpriseFilesPerShare 8
```

The enterprise profile is designed for a multi-thousand user population, hundreds of SMB shares, deep folder trees with real small files throughout, and an estimated lab data footprint under the default 2 GiB generated file-data budget. An 8 GiB budget is reserved for explicit stress runs. Final enterprise validation should run `scripts\Invoke-ShareSurferLabValidation.ps1` with `-RequireLiveEvidence` so required proof points cannot pass on plan-only rows.

## Azure Files Path Policy

ShareSurfer separates Azure Files hard limits from migration policy warnings. Microsoft documents 255-character path components and 2,048-character full paths for Azure Files. ShareSurfer defaults to flagging full paths over 256 characters as an operational migration warning, not as proof that Azure Files cannot store the path.

## Documentation

- [Operator workflow](docs/operator-workflow.md)
- [First-run guide](docs/first-run-guide.md)
- [Management overview](docs/management-overview.md)
- [Offline management overview slide](docs/management-overview.html)
- [Nonpermissive collector to dashboard host workflow](docs/nonpermissive-collection-dashboard-workflow.md)
- [Standalone dashboard interface spec](docs/standalone-dashboard-interface-spec.md)
- [V1 phase-1 acceptance audit](docs/v1-phase1-acceptance-audit.md)
- [Export schema](docs/export-schema.md)
- [Azure Files path policy](docs/azure-files-path-policy.md)
- [Redacted support bundles](docs/redacted-support-bundles.md)
- [Scaled lab generator spec](docs/scaled-lab-generator-spec.md)
- [Windows lab readiness checklist](docs/windows-lab-readiness-checklist.md)
- [Workflow visuals](docs/workflow-visuals.md)

## Tests

The default test runner avoids external dependencies so it can run on a fresh collector workstation:

```powershell
pwsh -NoLogo -NoProfile -File tests/Invoke-ShareSurferTests.ps1
```

If Pester is installed, you can use the Pester-compatible wrapper:

```powershell
pwsh -NoLogo -NoProfile -File scripts/Invoke-ShareSurferPester.ps1
```
