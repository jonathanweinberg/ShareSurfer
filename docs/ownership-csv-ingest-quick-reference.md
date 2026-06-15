# Ownership CSV Ingest Quick Reference

Use this copy/paste-friendly guide when a team has an HR, employee, OBS, OID, cost-center, or owner CSV that should be normalized for ShareSurfer.

ShareSurfer can ingest the CSV even when the column names are not exactly what ShareSurfer expects. The goal is to turn a messy source CSV into a normalized ownership file that can be reused for owner, OBS, business-unit, manager, and service-account review.

## 1. Put The Source CSV In The Inputs Folder

Example:

```powershell
C:\ShareSurfer\inputs\hr-obs.csv
```

## 2. Set Paths And Import ShareSurfer

```powershell
$releaseRoot = 'C:\ShareSurfer\ShareSurfer-0.1.0-pre.12'
$sourcePath = 'C:\ShareSurfer\inputs\hr-obs.csv'
$profilePath = 'C:\ShareSurfer\inputs\hr-obs.mapping.json'
$normalizedPath = 'C:\ShareSurfer\inputs\normalized-ownership.csv'
$rerunPath = 'C:\ShareSurfer\inputs\ownership-import-rerun.ps1'

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

At least one stable join field is strongly recommended:

- `EmployeeId`
- `EmployeeNumber`
- `SamAccountName`
- `UserPrincipalName`
- `Mail`

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
