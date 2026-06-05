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

## Lab Fixture

Plan the lab first:

```powershell
New-ShareSurferLabFixture -OutputPlanOnly -RootPath 'C:\ShareSurferLab' -DomainNetBiosName 'CONTOSO' -ObsAttribute 'extensionAttribute10'
```

On a disposable Windows/AD lab host, rerun without `-OutputPlanOnly` to create the filesystem/share fixtures and, when the ActiveDirectory module is available, demo users, groups, manager chains, employee fields, and OBS extension attributes. The lab plan includes directory ACLs, file-specific ACLs, ownership examples, broken inheritance, deep explicit ACEs, long-path fixtures, NTFS deny examples, and share-vs-NTFS conflict cases.

Enterprise validation should use the scaled profile:

```powershell
New-ShareSurferLabFixture -OutputPlanOnly -RootPath 'C:\ShareSurferEnterpriseLab' -Scale Enterprise -EnterpriseUserCount 2500 -EnterpriseShareCount 250 -EnterpriseFilesPerShare 8 -MaxLabBytes 8589934592
```

The enterprise profile is designed for a multi-thousand user population, hundreds of SMB shares, deep folder trees with real small files throughout, and an estimated lab data footprint under 8 GB. Final enterprise validation should run `scripts\Invoke-ShareSurferLabValidation.ps1` with `-RequireLiveEvidence` so required proof points cannot pass on plan-only rows.

## Azure Files Path Policy

ShareSurfer separates Azure Files hard limits from migration policy warnings. Microsoft documents 255-character path components and 2,048-character full paths for Azure Files. ShareSurfer defaults to flagging full paths over 256 characters as an operational migration warning, not as proof that Azure Files cannot store the path.

## Documentation

- [Operator workflow](docs/operator-workflow.md)
- [First-run guide](docs/first-run-guide.md)
- [Management overview](docs/management-overview.md)
- [Offline management overview slide](docs/management-overview.html)
- [Export schema](docs/export-schema.md)
- [Azure Files path policy](docs/azure-files-path-policy.md)
- [Redacted support bundles](docs/redacted-support-bundles.md)
- [Scaled lab generator spec](docs/scaled-lab-generator-spec.md)
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
