# Nonpermissive Collector to Dashboard Host Workflow

Use this workflow when the file-share environment is locked down, but reviewers need a richer dashboard experience on another workstation. The collector can stay simple and restricted. The dashboard host can be more permissive.

![Locked-down collector workflow](visuals/nonpermissive-collector-workflow.svg)

## When To Use This

Use this pattern when:

- The collector host has access to file servers, SMB shares, NTFS ACLs, and Active Directory, but has no internet access.
- The collector host cannot install Node, browser tooling, Power BI, or other review tools.
- Raw scan evidence must remain inside a trusted boundary until it is approved for transfer.
- A separate analyst or business-review workstation can open the dashboard package.

ShareSurfer does not change permissions. It reads evidence, writes normalized CSVs, and produces an offline report or dashboard package.

## Host Roles

| Host | What it needs | What it creates |
| --- | --- | --- |
| Collector host | Windows PowerShell 5.1, ShareSurfer module, read access to target shares and directory data | Raw CSV export set, `scan_manifest.csv`, `report.html`, optional transfer package |
| Dashboard host | Browser, optional Node/npm only when building the standalone dashboard assets | Offline dashboard review folder copied from the export dataset |

The collector host does not need npm, Vite, Playwright, internet access, or a local web server.

## 1. Prepare Inputs on the Collector

Create a dated export path:

```powershell
$scanId = 'scan-2026-06-08-finance'
$exportPath = "C:\ShareSurfer\exports\$scanId"
New-Item -ItemType Directory -Path $exportPath -Force
New-Item -ItemType Directory -Path 'C:\ShareSurfer\inputs' -Force
```

Create an owner mapping CSV when you know the expected business owner:

```powershell
@(
  [pscustomobject]@{
    Pattern = '\\files01\Finance*'
    Owner = 'Finance Operations'
    BusinessUnit = 'Finance'
    Source = 'operator'
  }
) | Export-Csv -LiteralPath 'C:\ShareSurfer\inputs\owner-mapping.csv' -NoTypeInformation -Encoding UTF8
```

Create a discounted principals CSV when broad HelpDesk, admin, scanner, backup, or platform groups should stay visible but should not drive Migration Discovery relatedness:

```powershell
@(
  [pscustomobject]@{
    Identity = 'CONTOSO\HelpDeskOps'
    Reason = 'Broad HelpDesk access'
    Scope = 'Global'
  }
) | Export-Csv -LiteralPath 'C:\ShareSurfer\inputs\discounted-principals.csv' -NoTypeInformation -Encoding UTF8
```

Discounted does not mean ignored, safe, approved, or remediated. ShareSurfer still shows the access in the CSVs and report.

## 2. Run Collection Read-Only

Import the module:

```powershell
Import-Module .\src\ShareSurfer\ShareSurfer.psd1 -Force
```

Run the scan:

```powershell
Invoke-ShareSurferScan `
  -TargetPath '\\files01\Finance' `
  -OutputPath $exportPath `
  -OwnerMappingPath 'C:\ShareSurfer\inputs\owner-mapping.csv' `
  -DiscountedPrincipalPath 'C:\ShareSurfer\inputs\discounted-principals.csv' `
  -OperationalPathLengthThreshold 256 `
  -ExplicitAceDepthThreshold 2 `
  -GroupExpansionMaxDepth 5 `
  -AdLookupMode Auto `
  -ObsAttribute 'extensionAttribute10'
```

Use the correct `-ObsAttribute` for your directory. `extensionAttribute10` is the default, but some environments use another attribute such as `info`.

Validate the export:

```powershell
$validation = Test-ShareSurferExport -ExportPath $exportPath
$validation
```

Generate the default offline report on the collector:

```powershell
ConvertTo-ShareSurferReport -ExportPath $exportPath -OutputPath "$exportPath\report.html"
```

At this point the export folder is the dataset. Keep it together.

## 3. Package the Dataset for Transfer

Create a zip package and hash:

```powershell
$packageRoot = 'C:\ShareSurfer\packages'
New-Item -ItemType Directory -Path $packageRoot -Force

$zipPath = Join-Path $packageRoot "$scanId.zip"
if (Test-Path -LiteralPath $zipPath) {
  Remove-Item -LiteralPath $zipPath -Force
}

Compress-Archive -LiteralPath (Join-Path $exportPath '*') -DestinationPath $zipPath
Get-FileHash -LiteralPath $zipPath -Algorithm SHA256 |
  Export-Csv -LiteralPath "$zipPath.sha256.csv" -NoTypeInformation -Encoding UTF8
```

Move the zip and hash file by your approved transfer process. Examples include an approved file-transfer service, a controlled jump host, removable media governed by policy, or another internal process your organization already trusts.

Do not send raw exports outside the trusted boundary unless your organization has approved that. Raw exports can contain real names, paths, server names, business-unit names, employee identifiers, manager chains, and OBS values.

## 4. Open on the Dashboard Host

![Dataset transfer to dashboard host](visuals/dataset-transfer-dashboard-workflow.svg)

Unpack the dataset:

```powershell
$reviewRoot = 'D:\ShareSurfer\reviews\scan-2026-06-08-finance'
New-Item -ItemType Directory -Path $reviewRoot -Force
Expand-Archive -LiteralPath 'D:\Intake\scan-2026-06-08-finance.zip' -DestinationPath $reviewRoot
```

Open the default report:

```powershell
Start-Process (Join-Path $reviewRoot 'report.html')
```

If the standalone dashboard assets are already built on the dashboard host, package the dataset into a self-contained dashboard folder:

```powershell
pwsh -NoLogo -NoProfile -File .\scripts\New-ShareSurferStandaloneDashboard.ps1 `
  -ExportPath $reviewRoot `
  -OutputPath "$reviewRoot\standalone-dashboard" `
  -Force
```

Open:

```powershell
Start-Process "$reviewRoot\standalone-dashboard\index.html"
```

The standalone dashboard folder is static. After packaging, it opens from disk and does not need npm, Vite, a server, or internet access.

## 5. What Reviewers Should Start With

Start with:

1. `owner_review_packets.csv` or the dashboard owner review queue.
2. `related_data_areas.csv` for migration discovery and like-owned shares/folders.
3. `permissioned_groups.csv` for groups that directly grant access.
4. `findings.csv` for long paths, broken inheritance, deep explicit ACEs, and service-account candidates.
5. `conflicts.csv` for share gate vs file/folder permission mismatches.
6. Raw evidence tables only when an operator needs the CSV-shaped detail.

For business users, frame the review around who owns the data, why it was flagged, which groups grant access, and what must be resolved before migration planning.

## 6. If You Need To Share a Support Case

Create a redacted support bundle instead of sending raw exports:

```powershell
New-ShareSurferSupportBundle `
  -ExportPath $exportPath `
  -OutputPath 'C:\ShareSurfer\support\scan-2026-06-08-finance-redacted' `
  -RedactionMode StableToken `
  -RedactionSalt 'case-2026-06-08-finance' `
  -IncludeReport
```

Validate and inspect the bundle before sharing it:

```powershell
Test-ShareSurferExport -ExportPath 'C:\ShareSurfer\support\scan-2026-06-08-finance-redacted'
```

Search for raw domain names, server names, share names, user names, group names, and business-unit names before attaching anything to a ticket.

## Quick Decision Guide

| Need | Use |
| --- | --- |
| Strict collector, no extra tooling | Run `Invoke-ShareSurferScan`, `Test-ShareSurferExport`, and `ConvertTo-ShareSurferReport` on the collector. |
| Rich review on another host | Transfer the validated export folder or zip to the dashboard host. |
| Dashboard host has built assets | Run `New-ShareSurferStandaloneDashboard.ps1` against the transferred export. |
| External bug report or support case | Generate a redacted support bundle and inspect it before sharing. |
