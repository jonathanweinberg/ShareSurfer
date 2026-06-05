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
- `DiskBudget`
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
- `lab-preflight.csv`
- `lab-run-events.jsonl`
- `validation.json`
- `lab-validation-criteria.csv`
- `live-evidence.json`
- `live-evidence-review.csv`
- `v1-acceptance.json`
- `v1-acceptance-summary.json`
- `report.html`
- `export\*.csv`
- `export\scan_events.jsonl`

Use these files first:

- `lab-preflight.csv`: readiness checks before and during the run.
- `live-evidence-review.csv`: operator-friendly proof rows and next actions.
- `v1-acceptance-summary.json`: quick pass/fail summary.
- `v1-acceptance.json`: detailed acceptance evidence.
- `report.html`: offline business review dashboard.

Use the `support-bundle-redacted` folder for bug reports or external troubleshooting. Do not attach raw run folders outside the trusted lab environment.

## Go Gates

Treat the run as ready for phase-1 evidence review only when all of these are true:

- `v1-acceptance-summary.json` has `IsValid` set to `true`.
- `v1-acceptance-summary.json` has `FailedCheckCount` set to `0`.
- `live-evidence.json` has `IsValid` set to `true`.
- `live-evidence.json` has `FallbackCount` set to `0`.
- `lab-validation-criteria.csv` has no failed required criteria.
- `live-evidence-review.csv` has no required rows marked `PlanOnly`, `EvidenceUnavailable`, `MissingEvidenceSource`, or `Failed`.
- `support-bundle-redacted\support_bundle_manifest.csv` has `ValidationIsValid=True`.
- `support-bundle-redacted\support_bundle_manifest.csv` has `RedactionLeakCount=0`.
- `support-bundle-redacted\v1_acceptance_summary.json` exists.
- `report.html` opens locally and shows the ShareSurfer Business Review Dashboard.

## Stop Gates

Stop and review before sharing evidence if any of these happen:

- Preflight has a required blocker.
- The run stops before writing `v1-acceptance-summary.json`.
- V1 acceptance fails.
- Live evidence falls back to `LabPlan` for a required enterprise criterion.
- The redacted support bundle reports a redaction leak.
- The dashboard is blank, unreadable, or missing expected owner, group, findings, diagnostics, or migration discovery views.
- The run creates more lab data than the configured budget.

## What To Attach To Issues

For GitHub issue updates, prefer concise evidence:

- Commit SHA or PR link when a code change was needed.
- `v1-acceptance-summary.json` status fields.
- A short summary of `live-evidence-review.csv` blocking rows, if any.
- The redacted support bundle manifest status.
- Known follow-up, especially any failed live criteria or partial collection areas.

Do not paste raw paths, raw identities, employee identifiers, manager chains, or raw support-bundle contents into public comments. Use the redacted support bundle when external troubleshooting needs files.

## If The Run Fails

Start with these files:

- `lab-run-events.jsonl`
- `lab-preflight.csv`
- `live-evidence-review.csv`
- `v1-acceptance-summary.json`
- `v1-acceptance.json`
- `support-bundle-redacted\support_bundle_manifest.csv`

Fix one blocker at a time and rerun the same command. Keep each run folder so changes can be compared later.
