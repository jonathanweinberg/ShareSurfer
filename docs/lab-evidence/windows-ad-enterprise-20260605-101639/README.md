# Windows/AD Enterprise Lab Evidence - 2026-06-05

This folder preserves evidence retrieved from the designated ShareSurfer Windows/AD lab host after the enterprise-scale live lab run.

## Host and Scope

- Host: `WINSERVER`
- Address: `192.168.1.218`
- Domain: `lab.contoso.com`
- User context: `lab\administrator`
- Lab root: `C:\ShareSurferEnterpriseLab`
- Repository staging path on host: `C:\ShareSurferRepo`
- Scale profile: `Enterprise`
- Observation attribute used: `info`

## Retrieved Evidence

| Local path | Source on lab host | Purpose |
| --- | --- | --- |
| `plan-only-20260605-101133/` | `C:\ShareSurfer\lab-validation\plan-only-20260605-101133` | Plan-only enterprise generation output. |
| `20260605-101159/` | `C:\ShareSurfer\lab-validation\20260605-101159` | Official preflight-only validation run. |
| `20260605-101639/` | `C:\ShareSurfer\lab-validation\20260605-101639` | Live lab creation, scan/export, evidence review, dashboard review, report, and partial support bundle output. |

## Enterprise Plan Counts

From `plan-only-20260605-101133/lab-plan-summary.json`:

- Users: `2500`
- Groups: `500`
- Shares: `250`
- File fixtures: `2000`
- ACL scenarios: `256`
- Owner mappings: `250`
- Validation criteria: `24`
- Estimated lab bytes: `1024000`
- Max lab bytes: `2147483648`
- Absolute max lab bytes: `8589934592`

## Live Run Results

The live lab was established under `C:\ShareSurferEnterpriseLab`.

- AD users created: `2500`
- AD groups created: `500`
- SMB shares created: `250`
- Files observed under the lab root: `2251`
- Actual lab bytes observed: `1152512`
- Export CSV files retrieved: `17`
- Offline report retrieved: `20260605-101639/report.html`
- Dashboard review retrieved: `20260605-101639/dashboard-review.md`

## Live Evidence Gate

`20260605-101639/live-evidence.json` reports:

- `IsValid`: `false`
- `FallbackCount`: `1`
- `FallbackCriteria`: `FocusedAclScenarios`
- `FallbackEvidenceSources`: `LabPlan`

The blocking row is in `20260605-101639/live-evidence-review.csv`:

```text
FocusedAclScenarios, Required=True, Passed=True, EvidenceStatus=PlanOnly, EvidenceSource=LabPlan, ActualValue=256, MinimumValue=1
```

All other required criteria in the live evidence review were backed by live evidence.

## Current Verifier Refresh

After the archived evidence was retrieved, ShareSurfer's validation helper was updated to prove `FocusedAclScenarios` from scan/export evidence instead of leaving it plan-only. The historical raw files above are preserved as captured.

The derived review under `20260605-101639/refreshed-evidence/` was generated from the archived CSV export with:

```powershell
.\scripts\New-ShareSurferArchivedEvidenceRefresh.ps1 `
  -RunRoot 'docs\lab-evidence\windows-ad-enterprise-20260605-101639\20260605-101639' `
  -OutputPath 'docs\lab-evidence\windows-ad-enterprise-20260605-101639\20260605-101639\refreshed-evidence' `
  -RequireLiveEvidence `
  -AllowMissingSupportBundle `
  -AllowMissingIssueComments
```

That refresh preserves the original AD, filesystem, and scan evidence rows, strengthens only the stale `FocusedAclScenarios` row when the archived CSV export proves it, then writes refreshed criteria, live-evidence, live-evidence-review, and V1 acceptance artifacts.

`20260605-101639/refreshed-evidence/v1-acceptance-summary.json` reports:

- `IsValid`: `true`
- `RequireLiveEvidence`: `true`
- `FailedCheckCount`: `0`

`20260605-101639/refreshed-evidence/live-evidence.json` reports:

- `IsValid`: `true`
- `FallbackCount`: `0`

The strengthened `FocusedAclScenarios` row is backed by `ScanExport:acl_entries.csv;findings.csv;conflicts.csv;items.csv` with `41,278` ACL rows, `11,244` file ACL rows, `251` deep explicit ACE findings, `4` broken inheritance findings, `2` long-path findings, and `32,309` conflict rows.

## Support Bundle Status

`20260605-101639/support-bundle-redacted/` was retrieved as a partial redacted support bundle with `27` files. Bundle generation was stopped before these expected completion artifacts were produced:

- `support_bundle_manifest.csv`
- `support_bundle_redaction_audit.csv`
- `support_bundle_summary.json`

The richer redacted lab-run support bundle is now optional phase-1 troubleshooting output, not a live-evidence proof blocker. Because the original support bundle did not complete, these historical raw-run acceptance artifacts are not present in the captured run root:

- `20260605-101639/v1-acceptance.json`
- `20260605-101639/v1-acceptance-summary.json`
- `20260605-101639/validation-closeout-checklist.md`
- `20260605-101639/issue-comments/`

## Recommended Follow-Up

Preserve the live lab while the remaining acceptance blockers are fixed:

1. Rerun validation against the existing lab with `-ObsAttribute info`, `-IncludeFiles`, and `-RequireLiveEvidence`.
2. Leave `-IncludeRedactedSupportBundle` off unless troubleshooting specifically needs the richer redacted lab-run bundle.
3. Use the refreshed evidence folder as the current archived-export proof, and use a fresh live rerun when reviewers need new host-side AD, filesystem, or collector evidence.
