# PowerShell Testing And Lab Verification

Use this guide when you need to prove that ShareSurfer's PowerShell collector, lab tooling, and enterprise evidence checks are healthy. The important habit is to keep each evidence lane honest: a local PowerShell Core smoke is useful, but it is not the same thing as Windows PowerShell 5.1 CI or a fresh Windows/AD lab run.

## Verification Lanes

| Lane | Command | What it proves | What it does not prove |
| --- | --- | --- | --- |
| Local PowerShell Core smoke | `pwsh -NoLogo -NoProfile -Command '& { $result = & ./scripts/Test-ShareSurferWindowsPowerShell51.ps1 -AllowPowerShellCore -PassThru; $result | ConvertTo-Json -Depth 5 }'` | The module parses, imports, exports key commands, can perform a small synthetic scan/export, and can draft/import review decisions on the current host. | True Windows PowerShell 5.1 behavior, Windows-only APIs, AD, SMBShare, or live lab creation. |
| Windows PowerShell 5.1 CI smoke | GitHub Actions `Windows PowerShell 5.1 smoke` job in `.github/workflows/ci.yml` | The same parser/import/core smoke runs under `powershell.exe` on a Windows runner. | Live AD, SMB share creation, target server permissions, or enterprise lab scale. |
| Full CI build and test | GitHub Actions `Build and test` job | Dashboard tests/build, dependency-free PowerShell test suite, and release-readiness package checks pass on a Windows runner. | Fresh live Windows/AD lab proof. |
| Lab preflight only | `.\scripts\Invoke-ShareSurferLabValidation.ps1 -PreflightOnly -CreateLab ...` | The planned live lab run has the needed host, PowerShell, module, path, disk, schema, password policy, and collision readiness checks before mutation. | It does not create AD objects, SMB shares, files, scans, reports, or support bundles. |
| Enterprise plan only | `New-ShareSurferLabFixture -OutputPlanOnly -Scale Enterprise ...` | The deterministic enterprise fixture plan can be generated and the designed counts/budget are internally consistent. | It does not prove anything exists in AD, on disk, or over SMB. |
| Archived enterprise proof refresh | `pwsh -NoLogo -NoProfile -File scripts/Test-ShareSurferArchivedEnterpriseProof.ps1` | The tracked enterprise evidence snapshot still validates against the current verifier, export schema, acceptance rules, and live-evidence gate logic. | It is not a new live run and does not prove the current Windows lab host is still healthy. |
| Fresh live enterprise validation | `.\scripts\Invoke-ShareSurferLabValidation.ps1 -CreateLab -Scale Enterprise -IncludeFiles -RequireLiveEvidence ...` | The Windows/AD lab can be created or updated, scanned, exported, reported, and accepted using live evidence rather than plan-only counts. | Production readiness for a customer file server. Production scans still need their own target-specific validation. |

## Recommended Order

1. Run a local or CI smoke when changing docs, scripts, module exports, packaging, or release behavior.
2. Run `New-ShareSurferLabFixture -OutputPlanOnly` before any live lab mutation.
3. Run lab preflight with `-PreflightOnly -CreateLab` before creating or updating the lab.
4. Run archived enterprise proof refresh when verifier logic changes and you need to confirm the tracked evidence still agrees with the current schema.
5. Run fresh live enterprise validation when you need new proof from a Windows/AD host.

## Local PowerShell Capability Check

From the repository root:

```powershell
pwsh -NoLogo -NoProfile -Command '& {
  $result = & ./scripts/Test-ShareSurferWindowsPowerShell51.ps1 -AllowPowerShellCore -PassThru
  $result | ConvertTo-Json -Depth 5
}'
```

Expected shape:

```json
{
  "IsValid": true,
  "PSEdition": "Core",
  "ParsedFileCount": 3,
  "RequiredCommandCount": 8,
  "ModuleVersion": "0.1.0"
}
```

This is a good fast check, but label it as PowerShell Core evidence when it runs under `pwsh`. Do not describe it as Windows PowerShell 5.1 proof unless it ran under `powershell.exe` on Windows.

## Windows PowerShell 5.1 CI Check

The CI workflow has a separate job named `Windows PowerShell 5.1 smoke`. It runs:

```powershell
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass `
  -File scripts\Test-ShareSurferWindowsPowerShell51.ps1
```

Use this lane to back the project promise that ShareSurfer remains friendly to Windows PowerShell 5.1. When reporting status, include the job name and link to the run when possible.

## Lab Preflight

Preflight should be your first Windows/AD lab command. Use `-CreateLab` together with `-PreflightOnly` so ShareSurfer checks creation blockers without creating anything:

```powershell
.\scripts\Invoke-ShareSurferLabValidation.ps1 `
  -PreflightOnly `
  -CreateLab `
  -LabRoot 'C:\ShareSurferLab' `
  -OutputRoot 'C:\ShareSurfer\lab-validation' `
  -DomainNetBiosName 'CONTOSO' `
  -ObsAttribute 'extensionAttribute10' `
  -Scale Enterprise `
  -EnterpriseUserCount 2500 `
  -EnterpriseShareCount 250 `
  -EnterpriseFilesPerShare 8 `
  -IncludeFiles `
  -RequireLiveEvidence
```

Open `lab-preflight.csv`. Required blocker rows must pass before a live proof run:

- `WindowsCollectorHost`
- `PowerShell51`
- `RunRootWritable`
- `ExistingLabRoot`, unless `-CreateLab` is intentionally creating a new lab
- `PlanDiskBudget`
- `PlanCriteria`
- `WindowsPathComponents`

On macOS or Linux, this preflight is expected to flag `WindowsCollectorHost` and `PowerShell51` as blockers. That is useful diagnostic evidence, not a failed product claim.

## Enterprise Plan-Only Check

Use plan-only mode to prove the generator can still design the large lab without mutating AD or SMB:

```powershell
Import-Module .\src\ShareSurfer\ShareSurfer.psd1 -Force

$plan = New-ShareSurferLabFixture `
  -OutputPlanOnly `
  -RootPath 'C:\ShareSurferEnterpriseLab' `
  -DomainNetBiosName 'CONTOSO' `
  -ObsAttribute 'extensionAttribute10' `
  -Scale Enterprise

[pscustomobject]@{
  UserCount = @($plan.Users).Count
  GroupCount = @($plan.Groups).Count
  ShareCount = @($plan.Shares).Count
  FileFixtureCount = @($plan.FileFixtures).Count
  AclScenarioCount = @($plan.AclScenarios).Count
  EstimatedLabBytes = $plan.EstimatedLabBytes
  MaxLabBytes = $plan.MaxLabBytes
}
```

Default enterprise counts should be:

- `2500` users
- `500` groups
- `250` shares
- `2000` file fixtures
- `256` ACL scenarios
- `2147483648` bytes as the default generated file-data budget

## Archived Enterprise Proof Refresh

Run this when current verifier logic changes or you want a quick confidence check against the tracked enterprise evidence snapshot:

```powershell
pwsh -NoLogo -NoProfile -File scripts\Test-ShareSurferArchivedEnterpriseProof.ps1
```

A valid result should show:

- `IsValid: True`
- `AcceptanceIsValid: True`
- `AcceptanceFailedCheckCount: 0`
- `LiveEvidenceIsValid: True`
- `LiveEvidenceFallbackCount: 0`
- `SchemaErrorCount: 0`

This is stronger than a plan-only check because it validates exported evidence, but weaker than a fresh live run because it does not create or scan the lab again.

## Fresh Live Enterprise Validation

Use this only on the disposable Windows/AD lab host:

```powershell
.\scripts\Invoke-ShareSurferLabValidation.ps1 `
  -CreateLab `
  -LabRoot 'C:\ShareSurferEnterpriseLab' `
  -OutputRoot 'C:\ShareSurfer\lab-validation' `
  -DomainNetBiosName 'CONTOSO' `
  -ObsAttribute 'extensionAttribute10' `
  -Scale Enterprise `
  -EnterpriseUserCount 2500 `
  -EnterpriseShareCount 250 `
  -EnterpriseFilesPerShare 8 `
  -IncludeFiles `
  -RequireLiveEvidence
```

Start review with these artifacts:

- `lab-preflight.csv`
- `collector-environment.json`
- `validation.json`
- `lab-validation-criteria.csv`
- `live-evidence.json`
- `live-evidence-review.csv`
- `v1-acceptance-summary.json`
- `v1-acceptance.json`
- `dashboard-review.md`
- `validation-closeout-checklist.md`

Treat the live proof as ready only when V1 acceptance is valid, failed check count is zero, live evidence is valid, fallback count is zero, and no required criteria are plan-only or unavailable.

## Reporting Language

Use precise wording:

- Say "PowerShell Core smoke passed" for local `pwsh` checks.
- Say "Windows PowerShell 5.1 smoke passed" only for the `powershell.exe` CI or Windows-host result.
- Say "enterprise plan-only generation passed" when no lab was created.
- Say "archived enterprise proof refresh passed" when validating tracked evidence with current verifier logic.
- Say "fresh live enterprise validation passed" only after a Windows/AD run with `-RequireLiveEvidence` produces a passing acceptance package.

That discipline prevents a small fast check from being mistaken for live enterprise proof.
