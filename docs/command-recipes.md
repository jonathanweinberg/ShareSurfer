# ShareSurfer Command Recipes

This page collects the most common first-run commands in one place. Use it when you know what you want to do and need a copy/paste starting point.

The examples assume the current quickstart release is unpacked here:

```text
C:\ShareSurfer\ShareSurfer-0.1.0-pre.18\
```

If `v0.1.0-pre.18` is not visible yet on the [ShareSurfer Releases page](https://github.com/jonathanweinberg/ShareSurfer/releases), use the latest published prerelease and substitute that version in every `ShareSurfer-0.1.0-pre.18` path and ZIP name below. The commands also assume Windows PowerShell 5.1 unless a command explicitly says otherwise.

## Start Here

1. Unpack and unblock the release.
2. Optional: generate an operator assistant plan and rerun script before scanning.
3. Create optional input CSVs only when you have the data.
4. Run one scan shape: quick UNC path, Windows SMB computer/share, or NativeSmbRpc fallback.
5. Validate the export and build `report.html`.
6. Package the standalone dashboard from the validated export folder when reviewers need the richer local dashboard.
7. Check stop gates before owner signoff.

## Command Inventory by Workflow

| Workflow | Copy/paste recipe | Commands and scripts |
| --- | --- | --- |
| Release setup | Recipe 1 | `Expand-Archive`, `Unblock-File`, `Import-Module` |
| Guided first-run planning | Recipe 1A | `Start-ShareSurferOperatorAssistant` |
| Lab and fixture planning | README Lab Fixture section | `New-ShareSurferLabFixture` |
| Optional owner/admin inputs | Recipe 2 | `owner-mapping.csv`, `discounted-principals.csv` |
| Flexible ownership import | Recipe 2A | `Test-ShareSurferOwnershipSource`, `New-ShareSurferOwnershipMappingProfile`, `Import-ShareSurferOwnershipSource`, `Join-ShareSurferOwnershipSources`, `New-ShareSurferOwnerMappingDraft` |
| Core scan | Recipes 3-5 | `Invoke-ShareSurferScan`, optional `-SmbCollectionProvider NativeSmbRpc` |
| Validation and dashboards | Recipe 6 | `Test-ShareSurferExport`, `ConvertTo-ShareSurferReport`, `New-ShareSurferStandaloneDashboard.ps1` |
| Review decisions | Recipe 7 | `New-ShareSurferReviewDecisionDraft`, `Import-ShareSurferReviewDecisions` |
| Locked-down handoff | Recipe 8 | `Compress-Archive`, `Get-FileHash` |
| Optional assessments | Recipes 9-10 | `Invoke-ShareSurferOpenFileAssessment`, `Invoke-ShareSurferPortProtocolAssessment` |
| Support and rerun | Recipes 11-12 | `New-ShareSurferSupportBundle`, rerun scan commands |

## Stop Gates Before Owner Signoff

`Test-ShareSurferExport` proves the files and columns are usable. It does not prove the scan reached every path or collected every security detail. Pause before owner review when:

- `evidence_confidence.csv` has a stop gate, review gate, provider fallback, or low confidence label that affects the review scope.
- `shares.csv` has `PartialData=True` or `collection_errors.csv` has access denied, unauthorized operation, native security descriptor, path resolution, ACL read, or owner read failures.
- `scan_manifest.csv` shows the wrong `ObsAttribute`, or `identities.csv`/`org_chains.csv` show blank OBS values where reviewer routing depends on OBS.
- The dashboard opened from the release template folder instead of a generated `$exportPath\standalone-dashboard` folder.
- `owner_review_packets.csv` and `owner_risk_pivots.csv` are blank, generic, or missing expected owner/business-unit mappings.
- `port_protocol_targets.csv` or `port_protocol_checks.csv` shows protocol readiness blockers for the collection route you intended to trust.

## Recipe 1: Unpack and Import the Release

Use this on the Windows collector host after downloading `ShareSurfer-0.1.0-pre.18.zip` from the GitHub release on an approved connected workstation. If that checkpoint ZIP is not published yet, download the latest published prerelease ZIP and update `$releaseZip` and `$releaseRoot` to match it.

```powershell
$releaseZip = 'C:\ShareSurfer\downloads\ShareSurfer-0.1.0-pre.18.zip'
$releaseRoot = 'C:\ShareSurfer\ShareSurfer-0.1.0-pre.18'

Expand-Archive -LiteralPath $releaseZip -DestinationPath 'C:\ShareSurfer' -Force
Get-ChildItem -Path "$releaseRoot\*" -Recurse -File -Include *.ps1,*.psm1,*.psd1 | Unblock-File

Test-Path "$releaseRoot\src\ShareSurfer\ShareSurfer.psd1"
Test-Path "$releaseRoot\interface\standalone-dashboard\dist\index.html"

Import-Module "$releaseRoot\src\ShareSurfer\ShareSurfer.psd1" -Force
Get-Command -Module ShareSurfer
```

The `Unblock-File` line clears the Windows downloaded-file block from ShareSurfer PowerShell files. It is safe to run again after re-extracting the release ZIP.

Both `Test-Path` commands should return `True`. If either returns `False`, check for a doubled folder such as `C:\ShareSurfer\ShareSurfer-0.1.0-pre.18\ShareSurfer-0.1.0-pre.18`.

## Recipe 1A: Generate a Guided Operator Plan

Use this when you want ShareSurfer to write the first-run plan and rerun script before you collect data. The assistant does not scan shares or change permissions. It writes `operator-assistant.plan.json` and `operator-assistant-rerun.ps1` so you can review the requested command preview and the authoritative rerun script first. Optional CSV paths are only used by the rerun script when those files exist.

```powershell
$releaseRoot = 'C:\ShareSurfer\ShareSurfer-0.1.0-pre.18'
$inputRoot = 'C:\ShareSurfer\inputs'
$exportPath = 'C:\ShareSurfer\exports\finance-001'

Import-Module "$releaseRoot\src\ShareSurfer\ShareSurfer.psd1" -Force
New-Item -ItemType Directory -Force -Path $inputRoot | Out-Null

Start-ShareSurferOperatorAssistant `
  -ReleaseRoot $releaseRoot `
  -InputRoot $inputRoot `
  -ExportPath $exportPath `
  -TargetPath '\\files01\Finance' `
  -ObsAttribute 'extensionAttribute10' `
  -AdLookupMode Auto `
  -PlanPath (Join-Path $inputRoot 'operator-assistant.plan.json') `
  -ReusableCommandPath (Join-Path $inputRoot 'operator-assistant-rerun.ps1') `
  -Force
```

Open `operator-assistant-rerun.ps1` and review it before running. The script imports the module, builds the scan parameters, only passes optional CSV paths when those files exist, runs `Invoke-ShareSurferScan`, validates with `Test-ShareSurferExport`, and packages the standalone dashboard from the validated export folder.

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

## Recipe 2A: Normalize HR, Employee, OBS, or Owner CSVs

Use this when another team gives you a CSV with useful owner or OBS data but the headers do not match ShareSurfer's expected owner mapping format.

```powershell
$releaseRoot = 'C:\ShareSurfer\ShareSurfer-0.1.0-pre.18'
$sourcePath = 'C:\ShareSurfer\inputs\hr-obs.csv'
$profilePath = 'C:\ShareSurfer\inputs\hr-obs.mapping.json'
$normalizedPath = 'C:\ShareSurfer\inputs\normalized-ownership.csv'
$rerunPath = 'C:\ShareSurfer\inputs\ownership-import-rerun.ps1'

Import-Module "$releaseRoot\src\ShareSurfer\ShareSurfer.psd1" -Force

Test-ShareSurferOwnershipSource -Path $sourcePath

New-ShareSurferOwnershipMappingProfile `
  -Path $sourcePath `
  -OutputPath $profilePath `
  -SourceName 'HR employee OBS export' `
  -ObsHeader 'CostCenterPath' `
  -ReusableCommandPath $rerunPath `
  -Force

Import-ShareSurferOwnershipSource `
  -Path $sourcePath `
  -MappingProfilePath $profilePath `
  -OutputPath $normalizedPath `
  -ReusableCommandPath $rerunPath `
  -Force
```

The normalized CSV keeps fields such as employee ID, employee number, account name, mail, title, office, manager mail levels, OBS, business unit, data owner, and owner mail in consistent columns. Rows with no OBS and no employee ID or employee number are flagged as potential service-account-like identities for review.

This recipe creates three reusable files:

- `hr-obs.mapping.json`: saved header mapping profile.
- `normalized-ownership.csv`: canonical ownership rows for review.
- `ownership-import-rerun.ps1`: reusable commands to retest the source and regenerate the normalized CSV without repeating the header interview.

If you need ShareSurfer to ask you about each header in the console, add `-Interactive` to `New-ShareSurferOwnershipMappingProfile`. The saved rerun file still uses the profile afterward.

To gather AD data from an HR or OBS file before scanning, create an enrichment CSV. ShareSurfer uses employee ID or employee number values from the source CSV to look up matching AD accounts when `-AdLookupMode Auto` or `ActiveDirectory` can read the directory. It fills available account, mail, title, office, manager, and OBS fields, then writes a local CSV that travels with the scan evidence.

```powershell
$releaseRoot = 'C:\ShareSurfer\ShareSurfer-0.1.0-pre.18'
$inputRoot = 'C:\ShareSurfer\inputs'
$ownershipEnrichmentPath = Join-Path $inputRoot 'ownership-enrichment.csv'
$ownershipDefinitionPath = Join-Path $inputRoot 'ownership-import.definition.json'
$ownershipRerunPath = Join-Path $inputRoot 'ownership-enrichment-rerun.ps1'

Import-Module "$releaseRoot\src\ShareSurfer\ShareSurfer.psd1" -Force

Join-ShareSurferOwnershipSources `
  -Interactive `
  -BrowseForCsv `
  -SourceFolder $inputRoot `
  -OutputPath $ownershipEnrichmentPath `
  -DefinitionPath $ownershipDefinitionPath `
  -ObsAttribute 'extensionAttribute10' `
  -AdLookupMode Auto `
  -ForbiddenOu @('OU=Service Accounts,DC=contoso,DC=com', 'OU=Admins,DC=contoso,DC=com') `
  -ReusableCommandPath $ownershipRerunPath `
  -Force
```

Use `-ObsAttribute` for the AD attribute that stores OBS/OID in your directory. The text picker can select one or more CSVs, including one file that only has OBS/project data and another that has employee IDs. The definition JSON saves the selected CSV paths, OBS attribute, AD lookup mode, and forbidden OU choices. Later, rerun the same import without the picker:

```powershell
Join-ShareSurferOwnershipSources `
  -DefinitionPath $ownershipDefinitionPath `
  -OutputPath $ownershipEnrichmentPath `
  -ReusableCommandPath $ownershipRerunPath `
  -Force
```

Pass `ownership-enrichment.csv` to the scan with `-OwnershipEnrichmentPath`. The scan exports it as `ownership_enrichment.csv`, and the report/dashboard can show matched, ambiguous, source-only, forbidden-OU-skipped, and potential service-account rows beside the permission evidence.

After a scan, create a draft owner mapping for paths that do not have owner routing yet:

```powershell
$exportPath = 'C:\ShareSurfer\exports\finance-001'
$draftPath = 'C:\ShareSurfer\inputs\owner-mapping-draft.csv'
$draftRerunPath = 'C:\ShareSurfer\inputs\owner-mapping-rerun.ps1'

New-ShareSurferOwnerMappingDraft `
  -ExportPath $exportPath `
  -OutputPath $draftPath `
  -ReusableCommandPath $draftRerunPath `
  -Force
```

Open the draft CSV, fill in `Owner` and `BusinessUnit`, save it as `owner-mapping.csv`, and rerun the scan with `-OwnerMappingPath`. The `owner-mapping-rerun.ps1` file shows the draft regeneration command and the copy/use pattern for the completed owner mapping.

For more detail, see the [admin ownership import guide](admin-ownership-import.md).

## Recipe 3: Quick UNC Path Scan

Use this when you already know the share path and want a first reviewable export.

```powershell
$releaseRoot = 'C:\ShareSurfer\ShareSurfer-0.1.0-pre.18'
$exportPath = 'C:\ShareSurfer\exports\finance-001'
$ownerMappingPath = 'C:\ShareSurfer\inputs\owner-mapping.csv'
$ownershipEnrichmentPath = 'C:\ShareSurfer\inputs\ownership-enrichment.csv'
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

if (Test-Path -LiteralPath $ownershipEnrichmentPath) {
  $scanParams.OwnershipEnrichmentPath = $ownershipEnrichmentPath
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
$releaseRoot = 'C:\ShareSurfer\ShareSurfer-0.1.0-pre.18'
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
$releaseRoot = 'C:\ShareSurfer\ShareSurfer-0.1.0-pre.18'
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
$releaseRoot = 'C:\ShareSurfer\ShareSurfer-0.1.0-pre.18'
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

Before owner signoff, open `evidence_confidence.csv` or the dashboard Scan Confidence panel. The score and label summarize evidence completeness only. Stop gates, partial data, collection errors, and provider fallback should be resolved, rerun, supplemented, or explicitly documented before approval.

## Recipe 7: Record Owner and Migration Review Decisions

Use this after a scan has produced `owner_review_packets.csv` and `related_data_areas.csv`. The draft files are plain CSVs that can be edited in Excel, reviewed in a meeting, and imported back into the export folder before rebuilding the report or standalone dashboard.

```powershell
$releaseRoot = 'C:\ShareSurfer\ShareSurfer-0.1.0-pre.18'
$exportPath = 'C:\ShareSurfer\exports\finance-001'
$decisionPath = 'C:\ShareSurfer\reviews\finance-001'
$decisionRerunPath = Join-Path $decisionPath 'review-decisions-rerun.ps1'

Import-Module "$releaseRoot\src\ShareSurfer\ShareSurfer.psd1" -Force

New-ShareSurferReviewDecisionDraft `
  -ExportPath $exportPath `
  -OutputPath $decisionPath `
  -ReusableCommandPath $decisionRerunPath `
  -Force
```

Open these files and fill in the reviewer columns:

```text
C:\ShareSurfer\reviews\finance-001\owner_review_decisions.csv
C:\ShareSurfer\reviews\finance-001\migration_cluster_decisions.csv
```

Allowed `Decision` values are:

```text
ConfirmedOwner
CleanupNeeded
RerunNeeded
MigrationCandidate
WrongOwner
```

Then import the edited decisions back into the export and rebuild review artifacts:

```powershell
Import-ShareSurferReviewDecisions `
  -ExportPath $exportPath `
  -DecisionPath $decisionPath `
  -ReusableCommandPath $decisionRerunPath `
  -Force

Test-ShareSurferExport -ExportPath $exportPath

ConvertTo-ShareSurferReport `
  -ExportPath $exportPath `
  -OutputPath "$exportPath\report.html"

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "$releaseRoot\scripts\New-ShareSurferStandaloneDashboard.ps1" `
  -ExportPath $exportPath `
  -OutputPath "$exportPath\standalone-dashboard" `
  -Force
```

`New-ShareSurferReviewDecisionDraft` and `Import-ShareSurferReviewDecisions` both write reusable command text when `-ReusableCommandPath` is supplied. Keep that `.ps1` file beside the review CSVs so a later scan can regenerate the same decision workflow without retyping commands.

## Recipe 8: Locked-Down Collector Handoff

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

## Recipe 9: Open-File Activity Assessment

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

## Recipe 10: Ports and Protocols Assessment

Use this before or after a scan when you need to prove which collector routes are reachable. The command is read-only.

```powershell
$exportPath = 'C:\ShareSurfer\exports\finance-001'

Invoke-ShareSurferPortProtocolAssessment `
  -ComputerName 'files01' `
  -ShareName 'Finance' `
  -DirectoryServer 'dc01.contoso.com' `
  -OutputPath $exportPath
```

This writes `port_protocol_manifest.csv`, `port_protocol_targets.csv`, and `port_protocol_checks.csv`. Package the standalone dashboard after these files are present to see the **Ports & Protocols** view below Raw Evidence. The output includes plain guidance fields such as `ReadinessSummary`, `CollectionImpact`, `OperatorGuidance`, and `RemediationHint`, which are useful for firewall tickets, server-team handoffs, and deciding whether to rerun with `-SmbCollectionProvider NativeSmbRpc`. Failed required SMB checks are stop gates. Failed or warning WinRM/CIM checks explain fallback or partial metadata risk. Passing SMB/RPC reachability does not prove ACL or security descriptor readability.

If you are only rehearsing the workflow and are not allowed to open network sockets, add `-SkipNetworkTests`; the CSVs will show skipped checks instead of pass/fail reachability.

## Recipe 11: Redacted Support Bundle

Use this when you need to share bug-report evidence outside trusted handling.

```powershell
$exportPath = 'C:\ShareSurfer\exports\finance-001'
$supportPath = 'C:\ShareSurfer\support\finance-001-redacted'

New-ShareSurferSupportBundle `
  -ExportPath $exportPath `
  -OutputPath $supportPath
```

Keep raw CSVs internal unless your process allows sharing them. The support bundle uses stable tokens so support can compare rows without seeing raw identities and paths.

## Recipe 12: Rerun After Mapping or Cleanup

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
