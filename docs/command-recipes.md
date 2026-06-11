# ShareSurfer Command Recipes

This page collects the most common first-run commands in one place. Use it when you know what you want to do and need a copy/paste starting point.

The examples assume the current quickstart release is unpacked here:

```text
C:\ShareSurfer\ShareSurfer-0.1.0-pre.9\
```

They also assume Windows PowerShell 5.1 unless a command explicitly says otherwise.

## Recipe 1: Unpack and Import the Release

Use this on the Windows collector host after downloading `ShareSurfer-0.1.0-pre.9.zip` from the GitHub release on an approved connected workstation.

```powershell
$releaseZip = 'C:\ShareSurfer\downloads\ShareSurfer-0.1.0-pre.9.zip'
$releaseRoot = 'C:\ShareSurfer\ShareSurfer-0.1.0-pre.9'

Expand-Archive -LiteralPath $releaseZip -DestinationPath 'C:\ShareSurfer' -Force
Get-ChildItem -Path "$releaseRoot\*" -Recurse -File -Include *.ps1,*.psm1,*.psd1 | Unblock-File

Test-Path "$releaseRoot\src\ShareSurfer\ShareSurfer.psd1"
Test-Path "$releaseRoot\interface\standalone-dashboard\dist\index.html"

Import-Module "$releaseRoot\src\ShareSurfer\ShareSurfer.psd1" -Force
Get-Command -Module ShareSurfer
```

The `Unblock-File` line clears the Windows downloaded-file block from ShareSurfer PowerShell files. It is safe to run again after re-extracting the release ZIP.

Both `Test-Path` commands should return `True`. If either returns `False`, check for a doubled folder such as `C:\ShareSurfer\ShareSurfer-0.1.0-pre.9\ShareSurfer-0.1.0-pre.9`.

## Recipe 2: Create Optional Input CSVs

Use owner mappings when you know who should review a share or folder. Owner means the business/data reviewer, not the NTFS owner field.

```powershell
$inputRoot = 'C:\ShareSurfer\inputs'
$ownerMappingPath = Join-Path $inputRoot 'owner-mapping.csv'
$discountedPrincipalPath = Join-Path $inputRoot 'discounted-principals.csv'

New-Item -ItemType Directory -Force -Path $inputRoot | Out-Null

@(
  [pscustomobject]@{
    Pattern = '\\files01\Finance*'
    Owner = 'Finance Operations'
    BusinessUnit = 'Finance'
    Source = 'first-run'
  }
) | Export-Csv -LiteralPath $ownerMappingPath -NoTypeInformation -Encoding UTF8
```

Use discounted principals for broad HelpDesk, admin, backup, scanner, or platform access that should stay visible but should not make unrelated shares look related in Migration Discovery.

```powershell
@(
  [pscustomobject]@{
    Identity = 'CONTOSO\HelpDeskOps'
    Reason = 'Broad HelpDesk access'
    Scope = 'Global'
  }
  [pscustomobject]@{
    Identity = 'CONTOSO\FileServerAdmins'
    Reason = 'Administrative access'
    Scope = 'Global'
  }
) | Export-Csv -LiteralPath $discountedPrincipalPath -NoTypeInformation -Encoding UTF8
```

If you do not have either file yet, leave it absent. The scan recipes below only pass optional input paths when the files exist.

## Recipe 3: Quick UNC Path Scan

Use this when you already know the share path and want a first reviewable export.

```powershell
$releaseRoot = 'C:\ShareSurfer\ShareSurfer-0.1.0-pre.9'
$exportPath = 'C:\ShareSurfer\exports\finance-001'
$ownerMappingPath = 'C:\ShareSurfer\inputs\owner-mapping.csv'
$discountedPrincipalPath = 'C:\ShareSurfer\inputs\discounted-principals.csv'

Import-Module "$releaseRoot\src\ShareSurfer\ShareSurfer.psd1" -Force

$scanParams = @{
  TargetPath = '\\files01\Finance'
  OutputPath = $exportPath
  ObsAttribute = 'extensionAttribute10'
  ManagerIdentityFormat = 'MailTo'
  AdLookupMode = 'Auto'
  OperationalPathLengthThreshold = 256
  ExplicitAceDepthThreshold = 2
  GroupExpansionMaxDepth = 5
}

if (Test-Path -LiteralPath $ownerMappingPath) {
  $scanParams.OwnerMappingPath = $ownerMappingPath
}

if (Test-Path -LiteralPath $discountedPrincipalPath) {
  $scanParams.DiscountedPrincipalPath = $discountedPrincipalPath
}

Invoke-ShareSurferScan @scanParams
```

Use this recipe first if you are new to the tool. It can still record partial-data findings when share-level permission proof is unavailable.

## Recipe 4: SMB Computer and Share Scan

Use this when you know the Windows file server and share name and want ShareSurfer to collect share metadata.

```powershell
$releaseRoot = 'C:\ShareSurfer\ShareSurfer-0.1.0-pre.9'
$exportPath = 'C:\ShareSurfer\exports\finance-001'

Import-Module "$releaseRoot\src\ShareSurfer\ShareSurfer.psd1" -Force

Invoke-ShareSurferScan `
  -ComputerName 'files01' `
  -ShareName 'Finance' `
  -OutputPath $exportPath `
  -ObsAttribute 'extensionAttribute10' `
  -ManagerIdentityFormat MailTo `
  -AdLookupMode Auto `
  -IncludeFiles
```

Use `-IncludeFiles` only when file-level rows matter for the review. Large shares take longer when file rows are included.

## Recipe 5: SMB Scan When WinRM or CIM Is Blocked

Use this when a Windows SMB target is reachable but default remote CIM or SMB cmdlets cannot prove share metadata cleanly.

```powershell
$releaseRoot = 'C:\ShareSurfer\ShareSurfer-0.1.0-pre.9'
$exportPath = 'C:\ShareSurfer\exports\finance-native-001'

Import-Module "$releaseRoot\src\ShareSurfer\ShareSurfer.psd1" -Force

Invoke-ShareSurferScan `
  -ComputerName 'files01' `
  -ShareName 'Finance' `
  -SmbCollectionProvider NativeSmbRpc `
  -OutputPath $exportPath `
  -ObsAttribute 'extensionAttribute10' `
  -ManagerIdentityFormat MailTo `
  -AdLookupMode Auto `
  -IncludeFiles
```

`NativeSmbRpc` avoids the normal WinRM/CIM route for core SMB evidence. It is still permission-dependent, so access denied results should be reviewed in `collection_errors.csv`, `findings.csv`, and the dashboard diagnostics. A green SMB/RPC port check means the route is reachable; it does not prove that the collector can read or parse share security descriptors, owner values, or folder/file DACLs. If the scan reports `NativeShareSecurityDescriptorUnavailable`, `NativeShareSecurityDescriptorParseFailed`, `NativeSecurityDescriptorReadFailed`, or `NativeSecurityDescriptorParseFailed`, treat the share as reachable but incomplete and review collector rights or SMB server compatibility.

## Recipe 6: Validate, Build the Report, and Open the Dashboard

Run this after the collector finishes.

```powershell
$releaseRoot = 'C:\ShareSurfer\ShareSurfer-0.1.0-pre.9'
$exportPath = 'C:\ShareSurfer\exports\finance-001'

Test-ShareSurferExport -ExportPath $exportPath

ConvertTo-ShareSurferReport `
  -ExportPath $exportPath `
  -OutputPath "$exportPath\report.html"

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "$releaseRoot\scripts\New-ShareSurferStandaloneDashboard.ps1" `
  -ExportPath $exportPath `
  -OutputPath "$exportPath\standalone-dashboard" `
  -Force

Start-Process "$exportPath\report.html"
Start-Process "$exportPath\standalone-dashboard\index.html"
```

Release users do not need Node, npm, Vite, a development server, or internet access to package and open the standalone dashboard from a validated export folder.

## Recipe 7: Locked-Down Collector Handoff

Use this when collection happens on a restricted host but review happens on a dashboard host.

```powershell
$exportPath = 'C:\ShareSurfer\exports\finance-001'
$handoffPath = 'C:\ShareSurfer\handoff\finance-001.zip'

Test-ShareSurferExport -ExportPath $exportPath
ConvertTo-ShareSurferReport -ExportPath $exportPath -OutputPath "$exportPath\report.html"

New-Item -ItemType Directory -Force -Path (Split-Path -Path $handoffPath) | Out-Null
Compress-Archive -Path "$exportPath\*" -DestinationPath $handoffPath -Force
Get-FileHash -Algorithm SHA256 -Path $handoffPath
```

On the dashboard host, verify the received hash before review:

```powershell
$handoffPath = 'C:\ShareSurfer\received\finance-001.zip'
$expectedHash = '<paste expected SHA256 here>'
$actualHash = (Get-FileHash -Algorithm SHA256 -Path $handoffPath).Hash

$actualHash -eq $expectedHash
```

The result should be `True`.

## Recipe 8: Open-File Activity Assessment

Use this after or near a scan when you need a quick look at active use.

```powershell
$exportPath = 'C:\ShareSurfer\exports\finance-001'

Invoke-ShareSurferOpenFileAssessment `
  -ComputerName 'files01' `
  -ShareName 'Finance' `
  -OutputPath $exportPath `
  -SampleCount 3 `
  -IntervalSeconds 10
```

This writes `open_file_manifest.csv`, `open_file_samples.csv`, `open_file_summary.csv`, and `open_file_errors.csv`. Treat it as activity evidence, not as a replacement for permission evidence.

## Recipe 9: Ports and Protocols Assessment

Use this before or after a scan when you need to prove which collector routes are reachable. The command is read-only.

```powershell
$exportPath = 'C:\ShareSurfer\exports\finance-001'

Invoke-ShareSurferPortProtocolAssessment `
  -ComputerName 'files01' `
  -ShareName 'Finance' `
  -DirectoryServer 'dc01.contoso.com' `
  -OutputPath $exportPath
```

This writes `port_protocol_manifest.csv`, `port_protocol_targets.csv`, and `port_protocol_checks.csv`. Package the standalone dashboard after these files are present to see the **Ports & Protocols** view below Raw Evidence. The output includes plain guidance fields such as `ReadinessSummary`, `CollectionImpact`, `OperatorGuidance`, and `RemediationHint`, which are useful for firewall tickets, server-team handoffs, and deciding whether to rerun with `-SmbCollectionProvider NativeSmbRpc`.

If you are only rehearsing the workflow and are not allowed to open network sockets, add `-SkipNetworkTests`; the CSVs will show skipped checks instead of pass/fail reachability.

## Recipe 10: Redacted Support Bundle

Use this when you need to share bug-report evidence outside trusted handling.

```powershell
$exportPath = 'C:\ShareSurfer\exports\finance-001'
$supportPath = 'C:\ShareSurfer\support\finance-001-redacted'

New-ShareSurferSupportBundle `
  -ExportPath $exportPath `
  -OutputPath $supportPath
```

Keep raw CSVs internal unless your process allows sharing them. The support bundle uses stable tokens so support can compare rows without seeing raw identities and paths.

## Recipe 11: Rerun After Mapping or Cleanup

Use a new export folder for each rerun so you can compare results.

```powershell
$exportPath = 'C:\ShareSurfer\exports\finance-002-after-cleanup'

Invoke-ShareSurferScan `
  -TargetPath '\\files01\Finance' `
  -OutputPath $exportPath `
  -OwnerMappingPath 'C:\ShareSurfer\inputs\owner-mapping.csv' `
  -DiscountedPrincipalPath 'C:\ShareSurfer\inputs\discounted-principals.csv' `
  -ObsAttribute 'extensionAttribute10' `
  -ManagerIdentityFormat MailTo `
  -AdLookupMode Auto

Test-ShareSurferExport -ExportPath $exportPath
ConvertTo-ShareSurferReport -ExportPath $exportPath -OutputPath "$exportPath\report.html"
```

Compare the old and new reports for fewer critical scan information blocks, fewer collection errors, clearer owner routing, and fewer migration readiness findings.
