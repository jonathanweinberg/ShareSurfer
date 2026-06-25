# Admin Ownership Import

Use this guide when you have an HR, identity, employee, OBS, OID, cost-center, or business-owner CSV that does not already match ShareSurfer's owner mapping format.

This workflow is offline and deterministic. ShareSurfer does not call an AI service, upload the CSV, or guess silently. It reads the headers, suggests mappings from known synonyms, tells you what is missing, and lets you save a reusable mapping profile.

For a shorter copy/paste version to send in team chat, use the [ownership CSV ingest quick reference](ownership-csv-ingest-quick-reference.md).

![Ownership import and reusable commands workflow](visuals/readme-flow-guides/ownership-import-reusable-commands.png)

## Why This Exists

Business ownership data often arrives with different column names:

- `EmployeeID`
- `employee_number`
- `WorkerId`
- `Personnel Number`
- `OBS`
- `OID`
- `OrgPath`
- `CostCenterPath`
- `Division`
- `DepartmentCode`

ShareSurfer needs consistent fields so it can correlate identity, manager, owner, business unit, and OBS context. The import commands help you convert unexpected CSVs into a normalized file that is easier to review and reuse.

## The Normal Workflow

1. **Test the source CSV.**
   ShareSurfer reads the headers and tells you which useful fields it can identify.

2. **Create a mapping profile.**
   The profile records which source header maps to each ShareSurfer field. You can reuse it when the same team gives you a refreshed CSV.

3. **Import a normalized ownership CSV when you are cleaning up one file.**
   ShareSurfer writes a consistent CSV with canonical headers, duplicate warnings, and potential service-account-like flags.

4. **Run ownership enrichment before the scan when you have more than one ownership source or want AD to fill gaps.**
   ShareSurfer joins HR, OBS, project, and owner files, optionally looks up matching AD accounts by employee identifier, skips any forbidden OUs you select, and writes an enriched CSV for the scan.

5. **Pass the enriched CSV to the scan.**
   `Invoke-ShareSurferScan -OwnershipEnrichmentPath` reads the enrichment file and exports the reviewed rows as `ownership_enrichment.csv`.

For a first multi-CSV run, the easiest path is the text-only CSV picker. It works in a normal PowerShell console and does not require Windows Explorer or a graphical file dialog.

Use the enrichment workflow before scanning when any of these are true:

- HR has employee identifiers, but the OBS, project, or owner information lives in another file.
- The source CSV has only employee IDs and business structure, and you want AD to fill display name, mail, account name, title, manager, enabled state, or distinguished name.
- You need to exclude disabled-account archives, service-account OUs, staging OUs, or test OUs from automatic AD matches.
- You want the dashboard to show the ownership context that was available at scan time.

If you only need to clean up one CSV for manual review, `normalized-ownership.csv` is enough. If the scan and dashboard should use the joined ownership facts, create an enriched CSV and pass it to the scan.

## Normalized CSV Versus Enriched Export

These two filenames are easy to mix up:

| File | Created When | What It Means |
| --- | --- | --- |
| `normalized-ownership.csv` | You run `Import-ShareSurferOwnershipSource` for one source CSV. | A cleaned-up copy of that source with ShareSurfer-friendly headers. Use it to check whether a single HR, OBS, OID, owner, or employee file has usable columns. |
| `C:\ShareSurfer\inputs\ownership-enrichment.csv` | You run the multi-source enrichment workflow before a scan. | A pre-scan input file that merges facts from multiple CSVs and optional AD lookup. Pass this file to `Invoke-ShareSurferScan -OwnershipEnrichmentPath`. |
| `C:\ShareSurfer\inputs\ownership-import.definition.json` | You run `Join-ShareSurferOwnershipSources -DefinitionPath` or save a definition during the interactive picker workflow. | A reusable definition that records selected CSV paths and join settings. It helps repeat the import later, but it is not scan evidence by itself. |
| `ownership_enrichment.csv` | The scan/export package is generated. | The exported evidence dataset copied into the scan output. The standalone dashboard reads this dataset after you package the validated export folder. |

In short: `normalized-ownership.csv` helps you prepare and review source data. `ownership-import.definition.json` remembers how to rebuild the joined input. `ownership_enrichment.csv` is scan evidence that shows what enriched ownership context ShareSurfer used for review.

## Canonical Headers

ShareSurfer understands these normalized ownership fields:

| Header | Purpose |
| --- | --- |
| `EmployeeId` | The main employee identifier from HR or AD. This is usually the best way to join an HR row to a directory account. |
| `EmployeeNumber` | A second employee identifier used by some directories or HR exports. |
| `SamAccountName` | The short Windows logon name, such as `jsmith`. |
| `UserPrincipalName` | The sign-in name that often looks like an email address, such as `jsmith@example.com`. |
| `Mail` | The user's email address. |
| `DisplayName` | The readable person or account name shown to reviewers. |
| `Title` | Job title from HR or AD. |
| `Office` | Office, site, region, or location. |
| `Department` | Department name from HR or AD. |
| `Company` | Company, subsidiary, or organization name. |
| `ManagerMail` | Direct manager email address from the source CSV. |
| `ManagerLevel2Mail` | Second-level manager email address when the source already provides it. |
| `ManagerLevel3Mail` | Third-level manager email address when the source already provides it. |
| `OBS` | OBS, OID, org path, cost-center path, or business hierarchy path. This is the business structure that helps group related data. |
| `BusinessUnit` | Business-facing unit, division, department, or cost-center name. |
| `DataOwner` | Named data owner when the source file already knows who should review the data. |
| `OwnerMail` | Email address for the explicit data owner. |
| `Project` | Project, program, application, or initiative name tied to the account or data area. |
| `ProjectCode` | Short project, cost, application, or investment code tied to the account or data area. |

At least one stable join key is strongly recommended:

- `EmployeeId`
- `EmployeeNumber`
- `SamAccountName`
- `UserPrincipalName`
- `Mail`

For the best owner and migration review experience, also provide `OBS` and `BusinessUnit` when you have them.

Enriched rows can add these review fields:

| Header | Meaning |
| --- | --- |
| `OwnershipKey` | ShareSurfer's best join key for the merged row. It is usually an employee ID, employee number, account name, UPN, or mail value. |
| `MatchStatus` | How confident the enrichment was. Common values include matched, ambiguous, source-only, and skipped because a forbidden OU matched. |
| `MatchMethod` | The field used to match the row, such as employee ID, employee number, account name, UPN, mail, or source-only. |
| `SourcePaths` | CSV source files that contributed facts to the row. |
| `SourceRowNumbers` | Source row numbers that contributed facts to the row. |
| `Manager`, `ManagerLevel1`, `ManagerLevel2`, `ManagerLevel3` | Directory manager values filled from AD when available. |
| `ManagerLevel1Raw`, `ManagerLevel2Raw`, `ManagerLevel3Raw` | Raw directory manager values before display formatting. |
| `AdObsPath` | OBS or org path read from AD by using the selected `-ObsAttribute`. |
| `ObsAttribute` | The AD attribute used for OBS lookup, such as `extensionAttribute10`. |
| `AccountEnabled` | Whether the matched AD account is enabled. |
| `DistinguishedName` | Full AD location for the matched account. This is useful for OU review. |
| `ForbiddenOuMatched` | The forbidden OU that caused an AD match to be skipped, when one applies. |
| `PotentialServiceAccount` | `True` when the row looks service-account-like because it lacks normal employee and OBS clues. Treat this as a review clue, not proof. |
| `ImportWarnings` | Row-specific warnings, such as duplicate source keys, ambiguous matches, or missing join fields. |

## Step 1: Test The CSV

If `v0.1.0-pre.19` is not visible yet on the [ShareSurfer Releases page](https://github.com/jonathanweinberg/ShareSurfer/releases), use the latest published prerelease and substitute that version in `$releaseRoot`.

```powershell
$releaseRoot = 'C:\ShareSurfer-0.1.0-pre.19'
$sourcePath = 'C:\ShareSurfer\inputs\hr-obs.csv'

Import-Module "$releaseRoot\src\ShareSurfer\ShareSurfer.psd1" -Force

Test-ShareSurferOwnershipSource -Path $sourcePath
```

If your OBS column has a custom name, tell ShareSurfer:

```powershell
Test-ShareSurferOwnershipSource `
  -Path $sourcePath `
  -ObsHeader 'CostCenterPath'
```

The result includes:

- `IsUsable`: whether ShareSurfer found at least one stable join key.
- `JoinKeyFields`: which join fields were mapped.
- `ObsHeader`: which source column maps to `OBS`.
- `FieldMap`: the proposed source-header mapping.
- `Warnings`: what the operator should fix before trusting the import.
- `CanonicalHeaders`: the header names ShareSurfer understands.

If ShareSurfer cannot find a stable join key, it tells you which headers to provide. It does not stop you from importing, but the normalized output may be harder to correlate to directory identities.

## Step 2: Create A Mapping Profile

```powershell
$profilePath = 'C:\ShareSurfer\inputs\hr-obs.mapping.json'
$rerunPath = 'C:\ShareSurfer\inputs\ownership-import-rerun.ps1'

New-ShareSurferOwnershipMappingProfile `
  -Path $sourcePath `
  -OutputPath $profilePath `
  -SourceName 'HR employee OBS export' `
  -ObsHeader 'CostCenterPath' `
  -ReusableCommandPath $rerunPath `
  -Force
```

The profile is a JSON file. It records the selected source headers so the next import does not need to rediscover them.

You can also ask ShareSurfer to interview you in the console:

```powershell
New-ShareSurferOwnershipMappingProfile `
  -Path $sourcePath `
  -OutputPath $profilePath `
  -SourceName 'HR employee OBS export' `
  -Interactive `
  -ReusableCommandPath $rerunPath `
  -Force
```

During interactive mode, press Enter to accept a suggested header, type another header, or type `S` to skip a field.

## Step 3: Import A Normalized Ownership CSV

```powershell
$normalizedPath = 'C:\ShareSurfer\inputs\normalized-ownership.csv'

Import-ShareSurferOwnershipSource `
  -Path $sourcePath `
  -MappingProfilePath $profilePath `
  -OutputPath $normalizedPath `
  -ReusableCommandPath $rerunPath `
  -Force
```

The normalized CSV uses the canonical headers listed above and adds review fields:

| Header | Meaning |
| --- | --- |
| `PotentialServiceAccount` | `True` when the row has no OBS, no employee ID, and no employee number. Treat this as a review clue, not proof. |
| `SourceRowNumber` | Source CSV row number for troubleshooting. |
| `SourcePath` | Source CSV path used for the import. |
| `ImportWarnings` | Row-specific warnings such as duplicate keys or potential service-account-like identity. |

Rows with `PotentialServiceAccount=True` may be service accounts, automation accounts, shared accounts, or incomplete directory records. Review them before using the data for business-owner routing.

## Multi-CSV Ownership Enrichment Before A Scan

Use enrichment when several simple files need to become one scan input. A common pattern is:

- HR file: employee ID plus OBS or department structure.
- Project or OBS file: project code, project name, OBS path, business unit, or data owner, but no employee details.
- AD lookup: fills missing account name, UPN, mail, display name, title, manager, enabled state, and distinguished name.

Example source files:

```csv
EmployeeID,OBS,BusinessUnit
E1001,CORP.FIN.AP,Finance
E1002,CORP.FIN.TAX,Finance
```

```csv
EmployeeID,ProjectCode,Project,OBS,DataOwner,OwnerMail
E1001,FIN-AP,Accounts Payable Modernization,CORP.FIN.AP,Finance Operations,finops@example.com
E1003,FIN-ARCH,Finance Archive Review,CORP.FIN.ARCH,Records Management,records@example.com
```

The first file tells ShareSurfer who is in which part of the business. The second file adds project and owner context. AD enrichment can then fill missing account fields for rows such as `E1001` and `E1002`.

Create the enriched file before running the scan. This first-run command opens the text picker, saves the selected CSV paths and settings, writes the enriched CSV, and writes a rerun script:

```powershell
Join-ShareSurferOwnershipSources `
  -Interactive `
  -BrowseForCsv `
  -SourceFolder 'C:\ShareSurfer\inputs' `
  -DefinitionPath 'C:\ShareSurfer\inputs\ownership-import.definition.json' `
  -OutputPath 'C:\ShareSurfer\inputs\ownership-enrichment.csv' `
  -ReusableCommandPath 'C:\ShareSurfer\inputs\ownership-enrichment-rerun.ps1' `
  -Force
```

In the picker, use the numbered folder and file choices to move around and toggle CSVs. The menu also lets you select all CSVs in the current folder, clear selected paths, show selected paths, go up to the parent folder, finish, or quit.

If you already know the exact files, you can still pass them directly:

```powershell
$inputRoot = 'C:\ShareSurfer\inputs'
$enrichmentPath = Join-Path $inputRoot 'ownership-enrichment.csv'
$enrichmentRerunPath = Join-Path $inputRoot 'ownership-enrichment-rerun.ps1'

Join-ShareSurferOwnershipSources `
  -Path @(
    (Join-Path $inputRoot 'hr-employee-obs.csv'),
    (Join-Path $inputRoot 'project-obs.csv')
  ) `
  -DefinitionPath (Join-Path $inputRoot 'ownership-import.definition.json') `
  -OutputPath $enrichmentPath `
  -ObsAttribute 'extensionAttribute10' `
  -AdLookupMode Auto `
  -ReusableCommandPath $enrichmentRerunPath `
  -Force
```

If you already saved mapping profiles for the same files, pass them with `-MappingProfilePath`.

Later, rerun the same join from the saved definition without repeating the picker choices:

```powershell
Join-ShareSurferOwnershipSources `
  -DefinitionPath 'C:\ShareSurfer\inputs\ownership-import.definition.json' `
  -OutputPath 'C:\ShareSurfer\inputs\ownership-enrichment.csv' `
  -Force
```

Pass the enriched file to the scan:

```powershell
Invoke-ShareSurferScan `
  -TargetPath '\\files01\Finance' `
  -OutputPath 'C:\ShareSurfer\exports\scan-001' `
  -ObsAttribute 'extensionAttribute10' `
  -OwnershipEnrichmentPath 'C:\ShareSurfer\inputs\ownership-enrichment.csv'
```

After the scan/export package is generated, ShareSurfer writes the enriched rows into the export set as `ownership_enrichment.csv`. Package the validated export folder with `scripts\New-ShareSurferStandaloneDashboard.ps1`; the standalone dashboard uses the exported `ownership_enrichment.csv` dataset, not the input file sitting in `C:\ShareSurfer\inputs`.

## Forbidden OUs

Forbidden OUs tell ShareSurfer which AD account locations should not be used for automatic enrichment matches. They do not delete accounts, disable accounts, or change AD. They only prevent those directory results from filling a row in the enriched CSV.

Use forbidden OUs when matching by employee ID could find accounts that are technically present in AD but should not be used as the normal business identity:

- disabled-account archives, such as `OU=Disabled Users,DC=example,DC=com`
- service account OUs, such as `OU=Service Accounts,DC=example,DC=com`
- staging or test OUs, such as `OU=Staging,DC=example,DC=com` or `OU=Test Users,DC=example,DC=com`
- migration holding areas where accounts are not ready for owner review

Example:

```powershell
Join-ShareSurferOwnershipSources `
  -SourceFolder 'C:\ShareSurfer\inputs\ownership-sources' `
  -BrowseForCsv `
  -OutputPath 'C:\ShareSurfer\inputs\ownership-enrichment.csv' `
  -ObsAttribute 'extensionAttribute10' `
  -AdLookupMode Auto `
  -ForbiddenOu @(
    'OU=Disabled Users,DC=example,DC=com',
    'OU=Service Accounts,DC=example,DC=com',
    'OU=Staging,DC=example,DC=com'
  ) `
  -Interactive `
  -ReusableCommandPath 'C:\ShareSurfer\inputs\ownership-enrichment-rerun.ps1' `
  -Force
```

If an AD account match is found under a forbidden OU, ShareSurfer keeps the source row for review and records the skipped OU in `ForbiddenOuMatched`. This helps an admin see why a row did not receive AD values.

## Reusable Outputs

The ownership import workflow can leave behind files that make the next refresh much easier:

| Output | Created By | What To Do With It |
| --- | --- | --- |
| `hr-obs.mapping.json` | `New-ShareSurferOwnershipMappingProfile` | Keep it beside the source CSV. Reuse it when the same team sends a refreshed file with the same headers. |
| `normalized-ownership.csv` | `Import-ShareSurferOwnershipSource` | Review the canonical ownership rows, duplicate warnings, and `PotentialServiceAccount` flags. |
| `ownership-import-rerun.ps1` | `-ReusableCommandPath` | Run it later to retest the source and regenerate `normalized-ownership.csv` without repeating the header interview. |
| `ownership-import.definition.json` | `Join-ShareSurferOwnershipSources -DefinitionPath` | Keep it with the input files. It records selected CSV paths and settings so the next admin can rebuild `ownership-enrichment.csv`; it is not scan evidence by itself. |
| `ownership-enrichment.csv` | `Join-ShareSurferOwnershipSources` | Pass this pre-scan input to `Invoke-ShareSurferScan -OwnershipEnrichmentPath` when the scan should carry merged ownership context. |
| `ownership-enrichment-rerun.ps1` | `Join-ShareSurferOwnershipSources -ReusableCommandPath` | Run it later to repeat the same multi-CSV join, AD enrichment, OBS attribute, and forbidden-OU choices. |
| `ownership_enrichment.csv` | `Invoke-ShareSurferScan` export | Review it in the scan export folder and standalone dashboard after the export package is generated. |

Each command also returns a `ReusableCommands` property. If you do not write a `.ps1` file, you can still copy that text from the command output.

## Draft Owner Mappings From A Scan

If a scan has no owner mapping yet, create a draft CSV for an admin to fill in:

```powershell
$exportPath = 'C:\ShareSurfer\exports\scan-001'
$draftPath = 'C:\ShareSurfer\inputs\owner-mapping-draft.csv'
$draftRerunPath = 'C:\ShareSurfer\inputs\owner-mapping-rerun.ps1'

New-ShareSurferOwnerMappingDraft `
  -ExportPath $exportPath `
  -OutputPath $draftPath `
  -Scope Share `
  -ReusableCommandPath $draftRerunPath `
  -Force
```

Open `owner-mapping-draft.csv`, fill in `Owner` and `BusinessUnit`, then save it as your owner mapping input:

```powershell
Copy-Item -LiteralPath $draftPath -Destination 'C:\ShareSurfer\inputs\owner-mapping.csv' -Force
```

The draft includes extra columns such as `PathPrefix`, `OwnerMail`, `OBS`, `Confidence`, and `Notes` to help the admin review the rows. `Invoke-ShareSurferScan -OwnerMappingPath` only needs `Pattern`, `Owner`, `BusinessUnit`, and optional `Source`.

`owner-mapping-rerun.ps1` records the draft regeneration command plus the copy/use pattern for `owner-mapping.csv`. Keep it with the draft so another admin can repeat the same owner-routing preparation later.

## What This Does Not Do

The normalized or enriched ownership CSV is review evidence. It does not rewrite AD, modify permissions, enable or disable accounts, or decide business ownership by itself.

Use it to:

- Review whether the source CSV has enough identity and OBS context.
- Create reusable mapping profiles.
- Flag likely service-account-like rows.
- Help build better `owner-mapping.csv` files.
- Feed scan and dashboard review with owner, OBS, project, and business-unit context.
