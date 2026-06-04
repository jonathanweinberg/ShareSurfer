# ShareSurfer V1 Operator Workflow

ShareSurfer V1 is a Windows PowerShell 5.1-only collector for SMB share discovery, ACL collection, identity enrichment, normalized CSV export, and offline reporting. It is designed for Windows SMB shares and can make a best-effort pass over Samba-style SMB shares when the operator can enumerate paths and permissions from the Windows host.

If this is your first time using ShareSurfer, start with the [First-run guide](first-run-guide.md). It walks through prerequisites, choosing scan targets, running the collector, understanding outputs, generating reports, creating redacted support bundles, and next actions in beginner-friendly language.

## Scope

- Primary target: Windows file servers and Windows SMB shares.
- Secondary target: Samba-style SMB shares, best effort only. Expect partial owner, ACL, share-permission, or identity data when Windows APIs cannot read equivalent Samba metadata.
- Runtime: Windows PowerShell 5.1. Do not assume PowerShell 7 behavior.
- Output: a normalized CSV export set plus an optional static report and redacted support bundle.

## Prerequisites

- Run from an account that can enumerate target shares, files, folders, NTFS ACLs, and share permissions.
- Use an account with directory read access when identity, group, manager-chain, employee, or OBS enrichment is required.
- Pick a local output directory with enough free space for CSVs and any support bundle.
- Record the OBS extension attribute in use, for example `extensionAttribute10`, before scanning.

## Lab Setup

Use the lab fixture in a disposable lab before touching production shares.

```powershell
$labRoot = 'C:\ShareSurferLab'
New-ShareSurferLabFixture -OutputPlanOnly -RootPath $labRoot -DomainNetBiosName 'CONTOSO' -ObsAttribute 'extensionAttribute10'
```

Review the plan first. When the plan is acceptable and the lab is disposable, rerun without `-OutputPlanOnly`.

For enterprise-scale validation, plan the larger profile before creating anything:

```powershell
$labRoot = 'C:\ShareSurferEnterpriseLab'
New-ShareSurferLabFixture `
  -OutputPlanOnly `
  -RootPath $labRoot `
  -DomainNetBiosName 'CONTOSO' `
  -ObsAttribute 'extensionAttribute10' `
  -Scale Enterprise `
  -EnterpriseUserCount 2500 `
  -EnterpriseShareCount 250 `
  -EnterpriseFilesPerShare 8 `
  -MaxLabBytes 8589934592
```

The V1 fixture is expected to create:

- AD users, groups, nested group membership, manager chains, and OBS extension attributes.
- SMB shares, files, and folders.
- Directory ACLs, file-specific ACLs, and ownership examples.
- Inheritance breaks, deep explicit ACEs, and NTFS deny examples.
- Long path fixtures.
- Share-vs-NTFS permission conflicts.

The enterprise profile must additionally prove:

- A multi-thousand user population.
- Hundreds of SMB shares.
- Deep share trees and intricate folder paths.
- Real file objects throughout the trees, using small file contents.
- Estimated generated lab data under 8 GB.

For a repeatable Windows Server validation run, use the script from the repository root:

```powershell
.\scripts\Invoke-ShareSurferLabValidation.ps1 `
  -CreateLab `
  -LabRoot 'C:\ShareSurferLab' `
  -OutputRoot 'C:\ShareSurfer\lab-validation' `
  -DomainNetBiosName 'CONTOSO' `
  -ObsAttribute 'extensionAttribute10' `
  -IncludeFiles
```

For the enterprise profile, add:

```powershell
  -Scale Enterprise `
  -EnterpriseUserCount 2500 `
  -EnterpriseShareCount 250 `
  -EnterpriseFilesPerShare 8 `
  -MaxLabBytes 8589934592
```

The script writes `lab-plan.json`, `validation.json`, `lab-validation-criteria.csv`, normalized CSVs, `report.html`, and a redacted support bundle for the lab run. For enterprise validation, `lab-validation-criteria.csv` is the pass/fail evidence for user population, share population, real file fixtures, deep paths, long-path policy fixtures, and the 8 GB disk budget.

## Scan Workflow

Use a dated export path for each run.

```powershell
$exportPath = 'C:\ShareSurfer\exports\scan-2026-06-04'

Invoke-ShareSurferScan `
  -TargetPath '\\files01\Finance' `
  -OutputPath $exportPath `
  -OwnerMappingPath 'C:\ShareSurfer\inputs\owner-mapping.csv' `
  -OperationalPathLengthThreshold 256 `
  -ExplicitAceDepthThreshold 2 `
  -AdLookupMode Auto `
  -ObsAttribute 'extensionAttribute10'
```

When the Windows SMB cmdlets can resolve the share directly, scan by computer and share name:

```powershell
Invoke-ShareSurferScan `
  -ComputerName 'files01' `
  -ShareName 'Finance' `
  -OutputPath $exportPath `
  -IncludeFiles `
  -AdLookupMode Auto `
  -ObsAttribute 'extensionAttribute10'
```

If a pre-collected inventory object is being tested, pass it with `-InputObject`. For production collection, use the source-selection parameters supported by the implementation and keep the same export path discipline.

Use `-AdLookupMode Auto` for normal runs. Use `ActiveDirectory` to force the AD PowerShell module path, `Ldap` to force the built-in .NET directory searcher fallback, or `DirectoryOnly` for imported fixture data where no live directory lookup should occur.

After every scan, validate the export set:

```powershell
Test-ShareSurferExport -ExportPath $exportPath
```

Generate the offline report:

```powershell
ConvertTo-ShareSurferReport -ExportPath $exportPath -OutputPath "$exportPath\report.html"
```

Create a support bundle only after the export validates:

```powershell
New-ShareSurferSupportBundle `
  -ExportPath $exportPath `
  -OutputPath 'C:\ShareSurfer\support\scan-2026-06-04-redacted' `
  -RedactionMode StableToken
```

## Operator Checklist

1. Confirm the scan scope, account, OBS attribute, and output path.
2. Run the lab fixture in plan mode if validating a new build or demo flow.
3. Run `Invoke-ShareSurferScan`.
4. Run `Test-ShareSurferExport`.
5. Review `findings.csv`, `conflicts.csv`, and the generated report.
6. Create a redacted support bundle if external review is needed.
7. Archive the raw export internally. Share only the redacted bundle outside the trusted team.

## Report Interpretation

Use the report dashboard as a triage guide, not as the only source of truth.

- `shares` and `items` show the collected scope and whether data was partial.
- `share_permissions` and `acl_entries` show the two permission layers that determine effective access.
- `conflicts` highlight mismatches such as NTFS identities that are not granted through the share gate.
- `findings` highlight migration and governance risks such as broken inheritance, deep explicit ACEs, and long paths.
- `scan_events` records collection and export events, including partial-data and collection-error context.
- `identities`, `group_edges`, and `org_chains` explain who an identity is, how group access expands, and where the owner sits in the organization.
- Start with the executive summary, priority actions, and dashboard filters, then use finding, conflict, owner, and org-chain rollups to identify the business unit or manager area that needs attention.
- Use the group browser when a security group is assigned rights and the business unit needs to see the expanded membership path.

Owner mapping CSVs should include `Pattern`, `Owner`, `BusinessUnit`, and optional `Source` columns. Patterns support simple wildcards, for example `\\files01\Finance*`.

Path findings need careful wording. Microsoft documents Azure Files limits of 255-character path components and 2,048-character full paths. ShareSurfer's default warning for full paths over 256 characters is an operational migration policy, not the Azure Files hard full-path limit.
