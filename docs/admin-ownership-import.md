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

## The Three-Step Workflow

1. **Test the source CSV.**
   ShareSurfer reads the headers and tells you which useful fields it can identify.

2. **Create a mapping profile.**
   The profile records which source header maps to each ShareSurfer field. You can reuse it when the same team gives you a refreshed CSV.

3. **Import a normalized ownership CSV.**
   ShareSurfer writes a consistent CSV with canonical headers, duplicate warnings, and potential service-account-like flags.

## Canonical Headers

ShareSurfer understands these normalized ownership fields:

| Header | Purpose |
| --- | --- |
| `EmployeeId` | Stable employee join key. |
| `EmployeeNumber` | Alternate employee join key. |
| `SamAccountName` | AD account join key. |
| `UserPrincipalName` | UPN or email-like identity join key. |
| `Mail` | User email address. |
| `DisplayName` | Human-readable name. |
| `Title` | Optional job title. |
| `Office` | Optional office, site, or location. |
| `Department` | Optional department name. |
| `Company` | Optional company or organization name. |
| `ManagerMail` | Manager level 1 email address. |
| `ManagerLevel2Mail` | Manager level 2 email address. |
| `ManagerLevel3Mail` | Manager level 3 email address. |
| `OBS` | OBS, OID, org path, or business hierarchy path. |
| `BusinessUnit` | Business-facing unit or division. |
| `DataOwner` | Explicit data owner when known. |
| `OwnerMail` | Explicit owner contact when known. |

At least one stable join key is strongly recommended:

- `EmployeeId`
- `EmployeeNumber`
- `SamAccountName`
- `UserPrincipalName`
- `Mail`

For the best owner and migration review experience, also provide `OBS` and `BusinessUnit` when you have them.

## Step 1: Test The CSV

```powershell
$releaseRoot = 'C:\ShareSurfer\ShareSurfer-0.1.0-pre.12'
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

## Reusable Outputs

The ownership import workflow can leave behind files that make the next refresh much easier:

| Output | Created By | What To Do With It |
| --- | --- | --- |
| `hr-obs.mapping.json` | `New-ShareSurferOwnershipMappingProfile` | Keep it beside the source CSV. Reuse it when the same team sends a refreshed file with the same headers. |
| `normalized-ownership.csv` | `Import-ShareSurferOwnershipSource` | Review the canonical ownership rows, duplicate warnings, and `PotentialServiceAccount` flags. |
| `ownership-import-rerun.ps1` | `-ReusableCommandPath` | Run it later to retest the source and regenerate `normalized-ownership.csv` without repeating the header interview. |

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

## What This Does Not Do Yet

The normalized ownership CSV is a preparation artifact. It does not automatically rewrite AD, modify permissions, or decide business ownership by itself.

Use it to:

- Review whether the source CSV has enough identity and OBS context.
- Create reusable mapping profiles.
- Flag likely service-account-like rows.
- Help build better `owner-mapping.csv` files.
- Improve future owner, OBS, and business-unit correlation workflows.
