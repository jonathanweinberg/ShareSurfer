# Ownership CSV Ingest Quick Reference

Use this copy/paste-friendly guide when a team has an HR, employee, OBS, OID, cost-center, or owner CSV that should be normalized for ShareSurfer.

ShareSurfer can ingest the CSV even when the column names are not exactly what ShareSurfer expects. The first goal is to turn a messy source CSV into `normalized-ownership.csv` for review. When several CSVs need to be joined or AD should fill missing account details, run the enrichment workflow before the scan and pass the enriched file to `Invoke-ShareSurferScan -OwnershipEnrichmentPath`.

## 1. Put The Source CSV In The Inputs Folder

Example:

```powershell
C:\ShareSurfer\inputs\hr-obs.csv
```

## 2. Set Paths And Import ShareSurfer

If `v0.1.0-pre.20` is not visible yet on the [ShareSurfer Releases page](https://github.com/jonathanweinberg/ShareSurfer/releases), use the latest published prerelease and substitute that version in `$releaseRoot`.

```powershell
$releaseRoot = 'C:\ShareSurfer-0.1.0-pre.20'
$sourcePath = 'C:\ShareSurfer\inputs\hr-obs.csv'
$profilePath = 'C:\ShareSurfer\inputs\hr-obs.mapping.json'
$normalizedPath = 'C:\ShareSurfer\inputs\normalized-ownership.csv'
$enrichmentPath = 'C:\ShareSurfer\inputs\ownership-enrichment.csv'
$definitionPath = 'C:\ShareSurfer\inputs\ownership-import.definition.json'
$rerunPath = 'C:\ShareSurfer\inputs\ownership-import-rerun.ps1'
$enrichmentRerunPath = 'C:\ShareSurfer\inputs\ownership-enrichment-rerun.ps1'

Import-Module "$releaseRoot\src\ShareSurfer\ShareSurfer.psd1" -Force
```

## 3. Test The CSV Headers

```powershell
Test-ShareSurferOwnershipSource -Path $sourcePath
```

If the OBS, OID, or org column has a custom name, provide it:

```powershell
Test-ShareSurferOwnershipSource `
  -Path $sourcePath `
  -ObsHeader 'CostCenterPath'
```

This tells you whether ShareSurfer found useful identity, ownership, OBS, and business-unit fields.

## 4. Create A Reusable Mapping Profile

```powershell
New-ShareSurferOwnershipMappingProfile `
  -Path $sourcePath `
  -OutputPath $profilePath `
  -SourceName 'HR employee OBS export' `
  -ObsHeader 'CostCenterPath' `
  -ReusableCommandPath $rerunPath `
  -Force
```

If ShareSurfer needs help matching headers, use interactive mode:

```powershell
New-ShareSurferOwnershipMappingProfile `
  -Path $sourcePath `
  -OutputPath $profilePath `
  -SourceName 'HR employee OBS export' `
  -Interactive `
  -ReusableCommandPath $rerunPath `
  -Force
```

During interactive mode, ShareSurfer asks which source CSV header should map to each ShareSurfer field. Press Enter to accept a suggestion, type a different header, or type `S` to skip a field.

## 5. Normalize The CSV

```powershell
Import-ShareSurferOwnershipSource `
  -Path $sourcePath `
  -MappingProfilePath $profilePath `
  -OutputPath $normalizedPath `
  -ReusableCommandPath $rerunPath `
  -Force
```

This creates:

| File | Purpose |
| --- | --- |
| `hr-obs.mapping.json` | Saved header mapping so the admin does not repeat the header interview. |
| `normalized-ownership.csv` | Cleaned-up ShareSurfer-friendly ownership, employee, manager, OBS, and business-unit data. |
| `ownership-import-rerun.ps1` | Reusable commands to retest the source CSV and regenerate `normalized-ownership.csv` later. |

## 6. Enrich Ownership Before The Scan

Run enrichment before scanning when HR, OBS, project, and owner facts are split across files, or when the CSV has employee identifiers and you want AD to fill missing fields.

Example HR file with employee IDs and OBS:

```csv
EmployeeID,OBS,BusinessUnit
E1001,CORP.FIN.AP,Finance
E1002,CORP.FIN.TAX,Finance
```

Example project/OBS file without employee details beyond the join key:

```csv
EmployeeID,ProjectCode,Project,OBS,DataOwner,OwnerMail
E1001,FIN-AP,Accounts Payable Modernization,CORP.FIN.AP,Finance Operations,finops@example.com
E1003,FIN-ARCH,Finance Archive Review,CORP.FIN.ARCH,Records Management,records@example.com
```

AD enrichment can fill empty account fields such as `SamAccountName`, `UserPrincipalName`, `Mail`, `DisplayName`, `Title`, `Department`, manager values, enabled state, and distinguished name.

For a first run, let ShareSurfer show a text-only CSV picker:

```powershell
Join-ShareSurferOwnershipSources `
  -Interactive `
  -BrowseForCsv `
  -SourceFolder 'C:\ShareSurfer\inputs' `
  -DefinitionPath $definitionPath `
  -OutputPath $enrichmentPath `
  -ReusableCommandPath $enrichmentRerunPath `
  -Force
```

In the picker, you can browse folders, toggle CSV files, select all CSVs in the current folder, clear selected paths, show selected paths, go up, finish, or quit.

The definition JSON remembers the selected CSV paths and settings. It is useful for reruns, but it is not scan evidence by itself.

Pass the enriched file to the scan:

```powershell
Invoke-ShareSurferScan `
  -TargetPath '\\files01\Finance' `
  -OutputPath 'C:\ShareSurfer\exports\scan-001' `
  -ObsAttribute 'extensionAttribute10' `
  -OwnershipEnrichmentPath $enrichmentPath
```

The scan exports the rows as `ownership_enrichment.csv`. After you package the validated export folder, the standalone dashboard uses that exported dataset for ownership enrichment review.

To rerun the same join later without the picker:

```powershell
Join-ShareSurferOwnershipSources `
  -DefinitionPath $definitionPath `
  -OutputPath $enrichmentPath `
  -Force
```

## Fields ShareSurfer Understands

Useful fields include:

| Field | Meaning |
| --- | --- |
| `EmployeeId` | Stable employee join key. |
| `EmployeeNumber` | Alternate employee join key. |
| `SamAccountName` | AD account name. |
| `UserPrincipalName` | UPN or email-like identity. |
| `Mail` | User email address. |
| `DisplayName` | Human-readable name. |
| `Title` | Optional job title. |
| `Office` | Optional office, site, or location. |
| `Department` | Optional department name. |
| `Company` | Optional company or organization name. |
| `ManagerMail` | Manager level 1 email address. |
| `ManagerLevel2Mail` | Manager level 2 email address. |
| `ManagerLevel3Mail` | Manager level 3 email address. |
| `OBS` | OBS, OID, org path, cost-center path, or business hierarchy path. |
| `BusinessUnit` | Business-facing unit, division, or department. |
| `DataOwner` | Explicit data owner when known. |
| `OwnerMail` | Explicit owner contact email when known. |
| `Project` | Project, program, application, or initiative name. |
| `ProjectCode` | Short project, cost, application, or investment code. |

At least one stable join field is strongly recommended:

- `EmployeeId`
- `EmployeeNumber`
- `SamAccountName`
- `UserPrincipalName`
- `Mail`

Enriched output also includes review fields:

| Field | Meaning |
| --- | --- |
| `OwnershipKey` | Best join key ShareSurfer used for the row. |
| `MatchStatus` | Whether the row matched AD, was ambiguous, stayed source-only, or was skipped because of a forbidden OU. |
| `MatchMethod` | Which field was used to match, such as employee ID, employee number, account name, UPN, or mail. |
| `SourcePaths` | CSV files that contributed to the row. |
| `SourceRowNumbers` | Source row numbers used for troubleshooting. |
| `AdObsPath` | OBS value read from AD by using `-ObsAttribute`. |
| `AccountEnabled` | Whether the matched AD account is enabled. |
| `DistinguishedName` | Full AD location of the matched account. |
| `ForbiddenOuMatched` | Forbidden OU that caused the AD match to be skipped, when one applies. |
| `ImportWarnings` | Duplicate, ambiguous, missing-key, or service-account-like warnings. |

## Forbidden OUs

Forbidden OUs keep ShareSurfer from using AD matches that live in places admins do not want treated as normal business identities. Common examples:

- disabled-account archives
- service account OUs
- staging OUs
- test OUs
- migration holding areas

Example:

```powershell
Join-ShareSurferOwnershipSources `
  -SourceFolder 'C:\ShareSurfer\inputs\ownership-sources' `
  -BrowseForCsv `
  -DefinitionPath $definitionPath `
  -OutputPath $enrichmentPath `
  -ObsAttribute 'extensionAttribute10' `
  -AdLookupMode Auto `
  -ForbiddenOu @(
    'OU=Disabled Users,DC=example,DC=com',
    'OU=Service Accounts,DC=example,DC=com',
    'OU=Staging,DC=example,DC=com'
  ) `
  -Interactive `
  -ReusableCommandPath $enrichmentRerunPath `
  -Force
```

If a matching AD account is under a forbidden OU, ShareSurfer keeps the source row and records the OU in `ForbiddenOuMatched` instead of filling the row from that account.

## Potential Service Account Flag

Rows with no OBS and no employee ID or employee number are flagged as:

```text
PotentialServiceAccount=True
```

This is a review clue, not proof.

It may mean the row is:

- a real service account
- an automation account
- a shared account
- a stale or incomplete directory record
- a normal user with missing HR or OBS data

Review these rows before using the data for business-owner routing.

## Reusing The Import Later

After the first successful import, run:

```powershell
C:\ShareSurfer\inputs\ownership-import-rerun.ps1
```

That reuses the saved mapping profile and regenerates `normalized-ownership.csv` without repeating the header interview.

For the multi-CSV enrichment file, rerun from the saved definition:

```powershell
Join-ShareSurferOwnershipSources `
  -DefinitionPath 'C:\ShareSurfer\inputs\ownership-import.definition.json' `
  -OutputPath 'C:\ShareSurfer\inputs\ownership-enrichment.csv' `
  -Force
```

Then run `Invoke-ShareSurferScan -OwnershipEnrichmentPath 'C:\ShareSurfer\inputs\ownership-enrichment.csv'` so the scan exports fresh `ownership_enrichment.csv` evidence.
