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
| Dashboard host | Browser and the unpacked ShareSurfer release package | Offline dashboard review folder copied from the export dataset |

The collector host does not need npm, Vite, Playwright, internet access, or a local web server. Starting with [v0.1.0-pre.5](https://github.com/jonathanweinberg/ShareSurfer/releases/tag/v0.1.0-pre.5), release users also do not need Node, npm, Vite, a development server, or internet access on the dashboard host to package and open the standalone dashboard. Download `ShareSurfer-0.1.0-pre.5.zip` and `ShareSurfer-0.1.0-pre.5.zip.sha256` on an approved connected workstation, verify or record the hash, and move the release package by your approved process.

When the release ZIP is extracted to `C:\ShareSurfer\`, the ShareSurfer folder is:

```text
C:\ShareSurfer\ShareSurfer-0.1.0-pre.5\
```

If Windows Explorer suggests extracting to `C:\ShareSurfer\ShareSurfer-0.1.0-pre.5`, change the destination to `C:\ShareSurfer` to avoid a doubled nested folder. The dashboard host can use the same release folder path, or another local path such as `D:\Tools\ShareSurfer-0.1.0-pre.5`.

During collection, `Invoke-ShareSurferScan` prints timestamped phase updates so the operator can tell the scan is still active. Use `-Quiet` only for scheduled automation. If WinRM/CIM is unavailable, ShareSurfer records the gap as partial share-permission evidence and continues with file/folder evidence where possible.

## 1. Prepare Inputs on the Collector

Create a dated export path:

```powershell
$scanId = 'scan-2026-06-08-finance'
$shareSurferRoot = 'C:\ShareSurfer\ShareSurfer-0.1.0-pre.5'
$exportPath = "C:\ShareSurfer\exports\$scanId"
$inputRoot = 'C:\ShareSurfer\inputs'
$ownerMappingPath = Join-Path $inputRoot 'owner-mapping.csv'
$discountedPrincipalPath = Join-Path $inputRoot 'discounted-principals.csv'

Test-Path "$shareSurferRoot\src\ShareSurfer\ShareSurfer.psd1"
Test-Path "$shareSurferRoot\interface\standalone-dashboard\dist\index.html"

New-Item -ItemType Directory -Path $exportPath -Force
New-Item -ItemType Directory -Path $inputRoot -Force
```

Both `Test-Path` commands should return `True`. If either returns `False`, confirm the ZIP was extracted to the expected folder before scanning.

Create an owner mapping CSV when you know the expected business owner:

```powershell
@(
  [pscustomobject]@{
    Pattern = '\\files01\Finance*'
    Owner = 'Finance Operations'
    BusinessUnit = 'Finance'
    Source = 'operator'
  }
) | Export-Csv -LiteralPath $ownerMappingPath -NoTypeInformation -Encoding UTF8
```

Create a discounted principals CSV when broad HelpDesk, admin, scanner, backup, or platform groups should stay visible but should not drive Migration Discovery relatedness:

```powershell
@(
  [pscustomobject]@{
    Identity = 'CONTOSO\HelpDeskOps'
    Reason = 'Broad HelpDesk access'
    Scope = 'Global'
  }
) | Export-Csv -LiteralPath $discountedPrincipalPath -NoTypeInformation -Encoding UTF8
```

Discounted does not mean ignored, safe, approved, or remediated. ShareSurfer still shows the access in the CSVs and report.

## 2. Run Collection Read-Only

Import the module:

```powershell
Import-Module "$shareSurferRoot\src\ShareSurfer\ShareSurfer.psd1" -Force
```

Run the scan:

```powershell
$scanParams = @{
  TargetPath = '\\files01\Finance'
  OutputPath = $exportPath
  OperationalPathLengthThreshold = 256
  ExplicitAceDepthThreshold = 2
  GroupExpansionMaxDepth = 5
  ManagerIdentityFormat = 'MailTo'
  AdLookupMode = 'Auto'
  ObsAttribute = 'extensionAttribute10'
}

if (Test-Path -LiteralPath $ownerMappingPath) {
  $scanParams.OwnerMappingPath = $ownerMappingPath
}

if (Test-Path -LiteralPath $discountedPrincipalPath) {
  $scanParams.DiscountedPrincipalPath = $discountedPrincipalPath
}

Invoke-ShareSurferScan @scanParams
```

Use the correct `-ObsAttribute` for your directory. `extensionAttribute10` is the default, but some environments use another attribute such as `info`.

Do not pass optional input paths unless the files exist. The splatted command above checks for the owner mapping and discounted principals CSVs before adding those parameters, so a first scan can still run without optional inputs.

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

If you are using the `v0.1.0-pre.5` release package, the standalone dashboard assets are already built. Package the dataset into a self-contained dashboard folder:

```powershell
$shareSurferRoot = 'D:\Tools\ShareSurfer-0.1.0-pre.5'

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "$shareSurferRoot\scripts\New-ShareSurferStandaloneDashboard.ps1" `
  -ExportPath $reviewRoot `
  -OutputPath "$reviewRoot\standalone-dashboard" `
  -Force
```

Open:

```powershell
Start-Process "$reviewRoot\standalone-dashboard\index.html"
```

The standalone dashboard folder is static. After packaging, it opens from disk and does not need npm, Vite, a server, or internet access. The release's `interface\standalone-dashboard\dist\index.html` is only a template shell until you run `New-ShareSurferStandaloneDashboard.ps1` against a validated export.

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
| Dashboard host uses `v0.1.0-pre.5` or later release zip | Run `New-ShareSurferStandaloneDashboard.ps1` against the transferred export; no npm or Vite is required. |
| External bug report or support case | Generate a redacted support bundle and inspect it before sharing. |
