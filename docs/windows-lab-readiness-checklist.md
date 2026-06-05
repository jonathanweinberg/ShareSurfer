# Windows Lab Readiness Checklist

Use this checklist before the live ShareSurfer enterprise validation run. It is written for an operator who may be running ShareSurfer for the first time.

The goal is simple: prove ShareSurfer can create the lab, scan it, export the evidence, generate the dashboard, and produce a redacted support bundle without relying on plan-only counts.

## Before You Start

Use a disposable Windows Server lab host joined to the test Active Directory domain. Do not run the enterprise lab fixture on a production file server.

You need:

- Windows PowerShell 5.1.
- The ActiveDirectory PowerShell module.
- The SMBShare PowerShell module.
- Permission to create or update objects under the `ShareSurferLab` OU.
- Permission to create local folders and SMB shares under the selected lab root.
- Permission to read the created SMB shares, file and folder ACLs, owners, and share permissions.
- At least 2 GiB available for the default generated file-data budget, plus room for CSVs, logs, report HTML, and support bundles.
- A trusted output folder for raw evidence, for example `C:\ShareSurfer\lab-validation`.

The default enterprise profile uses small files and should stay far below the 2 GiB generated file-data budget. The 8 GiB value is only for an explicit stress run.

## Choose Paths

Use short paths so Windows path components remain valid and the long-path warning scenario stays intentional.

Suggested defaults:

```powershell
$labRoot = 'C:\ShareSurferLab'
$outputRoot = 'C:\ShareSurfer\lab-validation'
$domain = 'CONTOSO'
```

Change `$domain` to the NetBIOS name of the test domain.

## Run Preflight First

Run preflight before creating users, groups, shares, files, reports, or support bundles.

```powershell
.\scripts\Invoke-ShareSurferLabValidation.ps1 `
  -PreflightOnly `
  -LabRoot $labRoot `
  -OutputRoot $outputRoot `
  -DomainNetBiosName $domain `
  -Scale Enterprise `
  -EnterpriseUserCount 2500 `
  -EnterpriseShareCount 250 `
  -EnterpriseFilesPerShare 8 `
  -IncludeFiles `
  -RequireLiveEvidence
```

Open the returned `lab-preflight.csv`.

Stop and fix the issue before continuing if any required row is not passing, especially:

- `WindowsCollectorHost`
- `PowerShell51`
- `ActiveDirectoryModule`
- `SmbShareCommands`
- `EnterpriseIncludeFiles`
- `WindowsPathComponents`
- `PlanDiskBudget`
- `TargetVolumeFreeSpace`
- `PlanCriteria`

Preflight is safe to rerun. It should not create the lab.

## Run The Full Enterprise Validation

After preflight passes, run the full validation:

```powershell
.\scripts\Invoke-ShareSurferLabValidation.ps1 `
  -CreateLab `
  -LabRoot $labRoot `
  -OutputRoot $outputRoot `
  -DomainNetBiosName $domain `
  -Scale Enterprise `
  -EnterpriseUserCount 2500 `
  -EnterpriseShareCount 250 `
  -EnterpriseFilesPerShare 8 `
  -IncludeFiles `
  -RequireLiveEvidence
```

The command should create or update the lab, scan the planned shares, validate the CSV export set, generate the offline report, create a redacted support bundle, and run V1 acceptance.

## Expected Artifacts

Each run creates a timestamped folder under `-OutputRoot`.

Keep these raw files inside the trusted lab environment:

- `lab-plan.json`
- `owner-mapping.csv`
- `collector-environment.json`
- `lab-preflight.csv`
- `lab-run-events.jsonl`
- `validation.json`
- `lab-validation-criteria.csv`
- `live-evidence.json`
- `live-evidence-review.csv`
- `v1-acceptance.json`
- `v1-acceptance-summary.json`
- `dashboard-review.md`
- `issue-summary.md`
- `issue-comments\issue-1-lab-fixture-live-proof.md`
- `issue-comments\issue-3-scanner-live-proof.md`
- `issue-comments\issue-5-identity-group-live-proof.md`
- `issue-comments\issue-6-dashboard-live-proof.md`
- `issue-comments\issue-comment-manifest.csv`
- `issue-comments\post-commands.txt`
- `report.html`
- `export\*.csv`
- `export\scan_events.jsonl`

Use these files first:

- `lab-preflight.csv`: readiness checks before and during the run.
- `collector-environment.json`: collector host, PowerShell, module, and command availability evidence for troubleshooting failed live runs.
- `live-evidence-review.csv`: operator-friendly proof rows and next actions.
- `v1-acceptance-summary.json`: quick pass/fail summary.
- `v1-acceptance.json`: detailed acceptance evidence.
- `validation-closeout-checklist.md`: safe go/no-go checklist for proof review and issue-comment posting.
- `dashboard-review.md`: dashboard marker checks, row counts, and the operator live-review checklist for issue #6.
- `issue-summary.md`: public-safe Markdown starting point for GitHub issue updates.
- `issue-comments\*.md`: public-safe targeted body-file comments for the remaining proof issues.
- `issue-comments\post-commands.txt`: exact `gh issue comment --body-file` commands for posting those targeted comments after review.
- `issue-comment-publish-preview.csv`: dry-run preview proving which issue comments would be posted and that no comment was posted during validation.
- `scripts\Publish-ShareSurferValidationIssueComments.ps1`: preview or post the generated issue comments after you review them. Posting from a run folder requires `validation-closeout-checklist.md` to say `Ready for proof review: True` unless you deliberately use `-SkipReadyCheck`.
- `report.html`: offline business review dashboard.

Use the `support-bundle-redacted` folder for bug reports or external troubleshooting. When the full validation script completes, that redacted folder also includes `issue_summary.md`, `validation_closeout_checklist.md`, and a sanitized `issue_comments` folder as shareable copies of the public-safe issue update artifacts. Do not attach raw run folders outside the trusted lab environment.

## Go Gates

Treat the run as ready for phase-1 evidence review only when all of these are true:

- `v1-acceptance-summary.json` has `IsValid` set to `true`.
- `v1-acceptance-summary.json` has `FailedCheckCount` set to `0`.
- `live-evidence.json` has `IsValid` set to `true`.
- `live-evidence.json` has `FallbackCount` set to `0`.
- `lab-validation-criteria.csv` has no failed required criteria.
- `live-evidence-review.csv` has no required rows marked `PlanOnly`, `EvidenceUnavailable`, `MissingEvidenceSource`, or `Failed`.
- `lab-validation-criteria.csv` shows passing lab population criteria for enterprise users, security groups, and SMB shares.
- `lab-validation-criteria.csv` shows passing lab fixture criteria for real files, deep paths, long-path policy fixtures, and the configured disk budget.
- `export\scan_manifest.csv` has `IncludeFiles=True` for enterprise runs, and the real-file criteria detail agrees with that setting.
- `lab-validation-criteria.csv` shows passing scanner permission criteria for share permissions, folder ACL entries, and file ACL entries.
- `lab-validation-criteria.csv` shows passing scanner finding criteria for ownership evidence, deep explicit ACE findings, and inheritance-break findings.
- `lab-validation-criteria.csv` shows passing scanner conflict criteria for share-vs-NTFS conflicts and collection-error evidence.
- `lab-validation-criteria.csv` shows passing identity criteria for employee identifiers, two-level manager chains, and the runtime OBS/OID attribute.
- `lab-validation-criteria.csv` shows passing security group criteria for recursive group expansion and OBS/OID coverage on permission-bearing groups.
- `collector-environment.json` exists so reviewers can confirm the collector host, PowerShell version, module availability, and command availability used for the run.
- `support-bundle-redacted\support_bundle_manifest.csv` has `ValidationIsValid=True`.
- `support-bundle-redacted\support_bundle_manifest.csv` has `RedactionLeakCount=0`.
- `support-bundle-redacted\v1_acceptance_summary.json` exists.
- `support-bundle-redacted\collector_environment.json` exists and contains only redacted host/user/path values.
- `report.html` opens locally and shows the ShareSurfer Business Review Dashboard.
- `dashboard-review.md` has `Dashboard review status: Pass`, then the operator confirms the live dashboard views render and respond to filters.

## Stop Gates

Stop and review before sharing evidence if any of these happen:

- Preflight has a required blocker.
- The run stops before writing `v1-acceptance-summary.json`.
- `collector-environment.json` is missing from the raw run folder or redacted support bundle.
- V1 acceptance fails.
- Live evidence falls back to `LabPlan` for a required enterprise criterion.
- The redacted support bundle reports a redaction leak.
- The dashboard is blank, unreadable, or missing expected owner, group, findings, diagnostics, or migration discovery views.
- `dashboard-review.md` is missing or says the dashboard needs review.
- The run creates more lab data than the configured budget.

If a `-RequireLiveEvidence` run fails after scanning, still check the generated `validation-closeout-checklist.md`, `live-evidence-review.csv`, and `support-bundle-redacted` folder. ShareSurfer attempts to finish those diagnostics before returning the final not-ready error so you can see what to fix before rerunning.

## What To Attach To Issues

For GitHub issue updates, prefer concise evidence:

- Commit SHA or PR link when a code change was needed.
- `v1-acceptance-summary.json` status fields.
- A short summary of `live-evidence-review.csv` blocking rows, if any.
- The redacted support bundle manifest status.
- Known follow-up, especially any failed live criteria or partial collection areas.

Do not paste raw paths, raw identities, employee identifiers, manager chains, or raw support-bundle contents into public comments. Use the redacted support bundle when external troubleshooting needs files.

To generate a public-safe Markdown summary from a completed run folder, use:

```powershell
.\scripts\New-ShareSurferValidationIssueSummary.ps1 `
  -RunRoot 'C:\ShareSurfer\lab-validation\20260605-120000' `
  -OutputPath 'C:\ShareSurfer\lab-validation\20260605-120000\issue-summary.md'
```

Review `issue-summary.md` before posting. It summarizes acceptance, live evidence, failed criteria, and redacted support bundle status while intentionally omitting raw paths, identities, employee identifiers, manager chains, and evidence detail values.

The full validation script also writes `issue-summary.md` automatically after final acceptance passes. Use the command above when you need to regenerate the summary for an archived run folder.

## If The Run Fails

Start with these files:

- `lab-run-events.jsonl`
- `lab-preflight.csv`
- `live-evidence-review.csv`
- `v1-acceptance-summary.json`
- `v1-acceptance.json`
- `support-bundle-redacted\support_bundle_manifest.csv`

Fix one blocker at a time and rerun the same command. Keep each run folder so changes can be compared later.
