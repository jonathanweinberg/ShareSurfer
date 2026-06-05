# Scaled Lab Generator Spec

This spec defines the ShareSurfer enterprise-scale lab generator for validating the "multi-thousand users / hundreds of shares / realistic small files" proof point without wasting disk. The generator should remain PowerShell 5.1 friendly, deterministic, airgap-safe, and simple enough to inspect from `-OutputPlanOnly` before it mutates a Windows lab host.

## Goals

- Generate a realistic Windows/AD SMB lab with thousands of users, hundreds of SMB shares, nested security groups, owner/business-unit mappings, deep folder structures, long-path policy fixtures, broken inheritance, file-specific ACLs, deny collisions, and share-vs-NTFS conflicts.
- Keep real generated file content small by default. The default file-data budget is 2 GiB, not 8 GiB.
- Keep the plan deterministic so test assertions can check exact counts before live fixture creation.
- Make all generated data synthetic, named, and resettable under a dedicated `ShareSurferLab` OU and lab root.

## Default Profile

The public command may keep `Focused` as its safe default for quick demos. This spec defines the exact defaults that apply when the operator selects the scaled profile with `-Scale Enterprise`.

| Parameter | Default | Meaning |
| --- | ---: | --- |
| `Scale` | `Enterprise` | Selected profile for this spec. Enables generated enterprise users, groups, shares, ACL scenarios, owner mappings, and file fixtures. |
| `RootPath` | required | Root folder for local share paths, for example `C:\ShareSurferEnterpriseLab`. |
| `DomainNetBiosName` | `CONTOSO` | Prefix used for generated permission identities. |
| `ObsAttribute` | `extensionAttribute10` | Runtime-selected AD extension attribute used for OBS/OID paths. |
| `EnterpriseUserCount` | `2500` | Total user count, including seed users and generated synthetic users. |
| `EnterpriseShareCount` | `250` | Total SMB share count, including seed shares and generated enterprise shares. |
| `EnterpriseFilesPerShare` | `8` | Minimum real file fixtures per share. |
| `EnterpriseTargetDepth` | `5` | Normal enterprise permission path depth before file fixture subfolders. |
| `EnterpriseLongPathShareCount` | `1` | Number of shares with a path over the 256-character migration warning threshold. |
| `EnterpriseFileSizeBytes` | `512` | Default content size per file fixture. |
| `MaxLabBytes` | `2147483648` | Default generated file-data budget, 2 GiB. |
| `AbsoluteMaxLabBytes` | `8589934592` | Optional stress-run ceiling, 8 GiB. It should require an explicit override. |

The current implementation already plans the default enterprise profile as `2500` users, `250` shares, `500` groups, `256` ACL scenarios, `2000` file fixtures, and `1024000` estimated file bytes when using `512` byte files. The spec changes the intended default budget from 8 GiB to 2 GiB while leaving those generated counts valid.

## Runtime Parameters

These parameters should be exposed by the public generator command or accepted as compatible aliases when the implementation evolves.

| Parameter | Type | Validation | Notes |
| --- | --- | --- | --- |
| `-Scale` | enum | `Focused`, `Enterprise` | `Focused` keeps the small seed lab. `Enterprise` enables this spec. |
| `-EnterpriseUserCount` | int | `1000` to `100000` | Counts total users, not only generated users. Default `2500`. |
| `-EnterpriseShareCount` | int | `100` to `5000` | Counts total shares, not only generated enterprise shares. Default `250`. |
| `-EnterpriseFilesPerShare` | int | `1` to `128` | Minimum real files per share. Default `8`. |
| `-EnterpriseTargetDepth` | int | `3` to `12` | Normal generated directory depth for enterprise ACL paths. Default `5`. |
| `-EnterpriseFileSizeBytes` | int64 | `128` to `1048576` | File content size used for disk math and generated payloads. Default `512`. |
| `-MaxLabBytes` | int64 | `1` to `8589934592` | Default `2147483648`; values over 2 GiB should be deliberate. |
| `-LongPathShareCount` | int | `0` to `EnterpriseShareCount` | Default `1`; creates policy-warning paths without invalid path components. |
| `-Seed` | int | any 32-bit int | Optional future knob. Default deterministic sequence should be stable without a seed. |
| `-OutputPlanOnly` | switch | n/a | Must produce the full object graph without creating directories, files, shares, ACLs, or AD objects. |
| `-Force` | switch | n/a | Allows reuse of an existing lab root during live creation. |

Short aliases may be added for ergonomics, but the verbose names above should stay supported because they are clear in logs and generated evidence.

Suggested aliases:

- `-UserCount` -> `-EnterpriseUserCount`
- `-ShareCount` -> `-EnterpriseShareCount`
- `-FilesPerShare` -> `-EnterpriseFilesPerShare`
- `-MaxDepth` -> `-EnterpriseTargetDepth`
- `-FileSizeBytes` -> `-EnterpriseFileSizeBytes`
- `-DiskBudgetGB` -> converted to `MaxLabBytes = DiskBudgetGB * 1024^3`

## Data Model

`New-ShareSurferLabFixture -OutputPlanOnly -Scale Enterprise` should return one plan object with these top-level fields:

| Field | Contents |
| --- | --- |
| `LabName` | Always `ShareSurferLab`. |
| `ScaleProfile` | `Focused` or `Enterprise`. |
| `RootPath` | Requested root path. |
| `DomainNetBiosName` | Domain prefix used by generated identities. |
| `ObsAttribute` | Runtime-selected OBS/OID attribute name. |
| `MaxLabBytes` | Configured generated file-data budget. |
| `EstimatedLabBytes` | Sum of planned file fixture sizes. |
| `OrganizationalUnit` | Dedicated generated OU, `OU=ShareSurferLab`. |
| `Users` | Generated user directory records. |
| `Groups` | Generated security group records and nested memberships. |
| `Shares` | SMB share records, local paths, descriptions, and share permissions. |
| `AclScenarios` | Directory/file ACL scenarios, inheritance state, rights, owners, and depth. |
| `FileFixtures` | Real file fixture rows with share, relative path, size, and content tag. |
| `OwnerMappings` | Business-owner and business-unit mapping rows for every share. |
| `ValidationCriteria` | Pre-live and live-evidence criteria for acceptance checks. |

### User Records

Each user record must include:

- `SamAccountName`
- `UserPrincipalName`
- `DisplayName`
- `EmployeeId`
- `EmployeeNumber`
- `Manager`
- `Enabled`
- the runtime OBS attribute, for example `extensionAttribute10`

Seed users preserve named scenarios such as `Ava.Accounting`, `Morgan.Manager`, and `Riley.Director`. Generated users use:

- `SamAccountName`: `SSUser00001`, `SSUser00002`, ...
- `UserPrincipalName`: `<SamAccountName>@example.test`
- `DisplayName`: `ShareSurfer User 00001`, ...
- `EmployeeId`: `E0000001`, ...
- `EmployeeNumber`: `0000001`, ...
- `Manager`: round-robin across seed managers
- OBS path: `CORP.<DEPT>.UNIT<NN>`

Department cycle:

`FIN`, `ENG`, `OPS`, `HR`, `LEGAL`, `SALES`, `MKT`, `RISK`

Manager cycle:

`Morgan.Manager`, `Parker.Manager`, `Quinn.Manager`

### Group Records

Each group record must include:

- `Name`
- `Members`
- `Description`
- the runtime OBS attribute

Seed groups preserve focused access and recursive expansion scenarios:

- `SS-Finance-Readers`
- `SS-Finance-Editors`
- `SS-Eng-Readers`
- `SS-Operations-Owners`
- `SS-Recursive-A`
- `SS-Recursive-B`

Generated enterprise groups use two groups per generated enterprise share:

- Reader group: `SS-ENT-0001-Readers`
- Editor group: `SS-ENT-0001-Editors`

All generated group names used as permission identities must be 20 characters or fewer so live Active Directory creation can use the same value as the group `sAMAccountName`.

Membership pattern:

- reader group contains two generated users selected by deterministic modulo over the generated user population.
- editor group contains the reader group, creating a nested-group path for expansion.
- all permission-bearing groups must have a non-empty OBS value.

OBS pattern:

- base share OBS: `CORP.ENT.SHARE0001`
- reader group OBS: `CORP.ENT.SHARE0001.READ`
- editor group OBS: `CORP.ENT.SHARE0001.MODIFY`

### Share Records

Each share record must include:

- `ShareName`
- `LocalPath`
- `Description`
- `SharePermissions`

Seed shares:

- `SSFinance` -> `<RootPath>\Finance`
- `SSEngineering` -> `<RootPath>\Engineering`
- `SSOperations` -> `<RootPath>\Operations`

Generated enterprise shares:

- `ShareName`: `SSEnt0001`, `SSEnt0002`, ...
- `LocalPath`: `<RootPath>\Enterprise\Share0001`, ...
- `Description`: `Enterprise-scale complex share 0001`, ...
- default share permission: `DOMAIN\SS-ENT-0001-Readers` with `Read`

## Folder-Depth Patterns

The generator must create both realistic ordinary depth and policy-warning edge cases.

Normal enterprise ACL path:

```text
Division<DD>\Region<RR>\Program<PP>\Project<JJ>\Workstream<WW>
```

Default depth is `5` directories. Values are deterministic modulo cycles:

- `Division`: `01` to `12`
- `Region`: `01` to `18`
- `Program`: `01` to `30`
- `Project`: `01` to `40`
- `Workstream`: `01` to `50`

Default file fixture path under an enterprise share:

```text
Division<DD>\Region<RR>\Program<PP>\Project<JJ>\Workstream<WW>\Folder<FF>\File<FF>.txt
```

That gives a seven-segment relative path for normal enterprise files: five business hierarchy folders, one fixture folder, and one file.

Supplemental filler path for shares that do not yet have enough files:

```text
EnterpriseEvidence\Fixture<FF>.txt
```

Long-path fixture pattern:

```text
Division<DD>\Region<RR>\Program<PP>\Project<JJ>\Workstream<WW>\<120 x L>\<120 x M>
```

Long-path constraints:

- Full relative path length must exceed `256` characters to trigger ShareSurfer's operational migration policy warning.
- No single path component may exceed `255` characters, so the lab remains Windows-creatable.
- At least one long-path ACL scenario is required in the default Enterprise profile.

## File-Count Math

Definitions:

- `U = EnterpriseUserCount`
- `S = EnterpriseShareCount`
- `F = EnterpriseFilesPerShare`
- `B = EnterpriseFileSizeBytes`
- `SeedUsers = 8`
- `SeedShares = 3`
- `SeedGroups = 6`
- `SeedAclScenarios = 8`
- `SeedFileFixtures = 2`

Generated users:

```text
GeneratedUsers = max(U - SeedUsers, 0)
TotalUsers = SeedUsers + GeneratedUsers
```

Generated enterprise shares:

```text
GeneratedEnterpriseShares = max(S - SeedShares, 0)
TotalShares = SeedShares + GeneratedEnterpriseShares
```

Groups:

```text
GeneratedEnterpriseGroups = GeneratedEnterpriseShares * 2
TotalGroups = SeedGroups + GeneratedEnterpriseGroups
```

ACL scenarios:

```text
GeneratedEnterpriseAclScenarios = GeneratedEnterpriseShares
LongPathAclScenarios = min(LongPathShareCount, GeneratedEnterpriseShares)
TotalAclScenarios = SeedAclScenarios + GeneratedEnterpriseAclScenarios + LongPathAclScenarios
```

File fixtures:

```text
MinimumFileFixtures = TotalShares * F
TotalFileFixtures = max(SeedFileFixtures + (GeneratedEnterpriseShares * F), MinimumFileFixtures)
```

The implementation should fill any seed-share shortfall with supplemental fixtures until every share has at least `F` files.

Default exact counts:

```text
U = 2500
S = 250
F = 8
B = 512
GeneratedUsers = 2492
GeneratedEnterpriseShares = 247
TotalUsers = 2500
TotalShares = 250
TotalGroups = 6 + (247 * 2) = 500
TotalAclScenarios = 8 + 247 + 1 = 256
TotalFileFixtures = 250 * 8 = 2000
EstimatedLabBytes = 2000 * 512 = 1024000 bytes
```

## Disk-Budget Formula

The lab budget applies to generated file content, not NTFS metadata, AD metadata, or SMB share objects.

Core formula:

```text
EstimatedLabBytes = TotalFileFixtures * EnterpriseFileSizeBytes
EstimatedLabGiB = EstimatedLabBytes / 1024^3
BudgetPass = EstimatedLabBytes <= MaxLabBytes
```

Default budget:

```text
MaxLabBytes = 2 * 1024^3 = 2147483648 bytes
```

Default generated file data:

```text
EstimatedLabBytes = 2000 * 512 = 1024000 bytes
EstimatedLabMiB = 1024000 / 1024^2 = 0.9765625 MiB
```

Maximum file size allowed under the default 2 GiB budget for default counts:

```text
MaxFileSizeBytes = floor(2147483648 / 2000) = 1073741 bytes
```

Maximum files allowed under the default 2 GiB budget at 512 bytes each:

```text
MaxFileFixtures = floor(2147483648 / 512) = 4194304 files
```

Stress runs may set `MaxLabBytes` up to `8589934592` bytes only through an explicit override. The default should not create or require more than 2 GiB of file content.

## Acceptance Criteria

Plan-only acceptance must pass without a Windows host:

- `ScaleProfile` is `Enterprise`.
- `Users.Count >= EnterpriseUserCount`.
- `Shares.Count >= EnterpriseShareCount`.
- `FileFixtures.Count >= EnterpriseShareCount * EnterpriseFilesPerShare`.
- `EstimatedLabBytes <= MaxLabBytes`.
- every share has at least `EnterpriseFilesPerShare` planned files.
- at least one file fixture has a relative path with six or more path segments.
- at least one ACL scenario has a relative path longer than `256` characters.
- no generated path component exceeds `255` characters.
- every permission-bearing group has a non-empty runtime OBS attribute.
- `ValidationCriteria` includes user population, share population, real files, deep paths, long-path policy, share permissions, ACL entries, file ACL entries, deep explicit ACE findings, broken inheritance, conflict findings, collection-error evidence, group expansion, permission-group OBS coverage, owner-risk pivots, related data areas, owner review packets, and disk budget.

Live acceptance on a disposable Windows/AD lab host must additionally prove:

- the dedicated OU exists or is created under the current domain.
- generated users and groups exist with expected manager and OBS attributes.
- SMB shares exist at the planned local paths.
- share permissions are applied.
- NTFS ACL scenarios are applied, including broken inheritance, deny collision, deep explicit ACE, owner examples, and file-specific ACLs.
- scanning the generated shares produces CSV exports, report data, owner/business-unit pivots, related data area rows, group expansion rows, long-path findings, deep explicit ACE findings, share-vs-NTFS conflict evidence, and collection-error evidence. A clean Windows run may show `0` collection error rows; partial-data or best-effort paths should show the count in `lab-validation-criteria.csv`.
- redacted support bundle generation succeeds against the enterprise export.

## Implementation Notes

- `-OutputPlanOnly` is the contract surface for future implementation planning. It must stay fast enough to run repeatedly in tests and rich enough to verify counts without touching the machine.
- Live creation should fail before mutation when `EstimatedLabBytes > MaxLabBytes`.
- Generated names should be deterministic and stable across runs for the same parameters.
- Reset/cleanup should be possible by removing the lab root, generated SMB shares, and `OU=ShareSurferLab`.
- The generator should not require Python or network access.
- The generated content should be plain text and synthetic. No real names, customer paths, or private org details should be embedded.
