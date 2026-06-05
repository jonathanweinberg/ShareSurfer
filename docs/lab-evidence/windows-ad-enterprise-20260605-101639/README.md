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

## Support Bundle Status

`20260605-101639/support-bundle-redacted/` was retrieved as a partial redacted support bundle with `27` files. Bundle generation was stopped before these expected completion artifacts were produced:

- `support_bundle_manifest.csv`
- `support_bundle_redaction_audit.csv`
- `support_bundle_summary.json`

Because the support bundle did not complete, these final acceptance artifacts are not present:

- `20260605-101639/v1-acceptance.json`
- `20260605-101639/v1-acceptance-summary.json`
- `20260605-101639/validation-closeout-checklist.md`
- `20260605-101639/issue-comments/`

## Recommended Follow-Up

Preserve the live lab while the remaining acceptance blockers are fixed:

1. Make `FocusedAclScenarios` prove itself from live scan/export evidence under `-RequireLiveEvidence`.
2. Make redacted support-bundle generation scale on enterprise output.
3. Rerun validation against the existing lab with `-ObsAttribute info`.
