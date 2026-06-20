# ShareSurfer File-Share Connectivity Diagnostics Plan

Tracking issue: https://github.com/jonathanweinberg/ShareSurfer/issues/274
Branch: `codex/fileshare-connectivity-diagnostics`
Date: 2026-06-19

## Main Goal Prompt

```text
/goal Implement ShareSurfer issue #274: build a PowerShell 5.1-compatible file-share connectivity and collection-capability diagnostic module. Keep it read-only, issue-first, branch-first, and compatible with non-WinRM SMB shares. Add extensive console status logging, durable raw outputs, and a separate redacted summary package suitable for support or LLM-assisted diagnostic review. Validate with focused tests and ShareSurfer's normal delivery flow.
```

## Subagent Goal Prompts

```text
/goal Review the ShareSurfer issue #274 implementation plan for SMB/RPC, WinRM/CIM, open-file, share-permission, and security-descriptor diagnostic coverage. Stay read-only. Identify gaps where TCP reachability might be mistaken for usable collection capability.
```

```text
/goal Review the ShareSurfer issue #274 implementation for logging, output schemas, redaction, and LLM-ready diagnostic summary quality. Confirm raw sensitive values are separated from redacted summaries and that support artifacts remain useful without leaking host/share/user/path details.
```

```text
/goal Review the ShareSurfer issue #274 implementation for PowerShell 5.1 compatibility, tests, public command exports, docs, and regression risk. Check that the module remains offline, read-only, and does not require WinRM, npm, browser tooling, or external services.
```

## Product Intent

Operators need a command that answers a narrower and more useful question than "are ports open?"

The command should answer:

- Can this collector reach the target?
- Can it prove SMB is reachable?
- Can it use WinRM/CIM, or should it plan for Native SMB/RPC?
- Can Native SMB/RPC read share metadata?
- Can it get a share security descriptor?
- If it gets a descriptor, can ShareSurfer parse it into share permission rows?
- Can it enumerate open file evidence through native NetFileEnum or CIM-backed tools?
- What scan provider is recommended?
- What is blocked, partial, or unknown?
- What should the operator do next?

This is intentionally similar to the diagnostic value an admin gets from Windows Computer Management, while staying PowerShell-first, read-only, and export-oriented.

## Proposed Public Command

```powershell
Invoke-ShareSurferFileShareConnectivityAssessment `
  -TargetPath '\\server01\FileShare' `
  -OutputPath 'C:\ShareSurfer\diagnostics\fileshare-001' `
  -IncludeOpenFiles `
  -Force
```

Alternate target shape:

```powershell
Invoke-ShareSurferFileShareConnectivityAssessment `
  -ComputerName 'server01' `
  -ShareName 'FileShare' `
  -OutputPath 'C:\ShareSurfer\diagnostics\fileshare-001' `
  -Force
```

## Outputs

Raw diagnostic package:

- `fileshare_connectivity_manifest.csv`
- `fileshare_connectivity_targets.csv`
- `fileshare_connectivity_checks.csv`
- `fileshare_connectivity_summary.json`
- `fileshare_connectivity_events.jsonl`

Redacted diagnostic package:

- `redacted/fileshare_connectivity_manifest.csv`
- `redacted/fileshare_connectivity_targets.csv`
- `redacted/fileshare_connectivity_checks.csv`
- `redacted/fileshare_connectivity_summary.json`
- `redacted/fileshare_connectivity_events.jsonl`
- `redacted/fileshare_connectivity_llm_summary.md`
- `redacted/fileshare_connectivity_redaction_manifest.csv`

## Check Layers

| Layer | Purpose | Example Status |
| --- | --- | --- |
| Target parsing | Prove ShareSurfer understood UNC/computer/share input | Pass, Fail |
| Name resolution | Record whether the collector can resolve the server | Pass, Fail, Skipped |
| SMB TCP 445 | Core SMB reachability | Pass, Fail |
| WinRM/CIM ports | Explain whether `Get-SmbShare*` through CIM is likely | Pass, Fail |
| RPC endpoint mapper | Explain classic RPC signal, without overclaiming | Pass, Fail |
| Native share metadata | `NetShareGetInfo` returned share metadata | Pass, Fail |
| Native share descriptor returned | `SHARE_INFO_502` had a descriptor pointer | Pass, Fail |
| Native share descriptor parse | Descriptor parsed into share permission rows | Pass, Fail |
| Open file enumeration | NetFileEnum or CIM open-file path returned usable evidence | Pass, Fail, Skipped |
| Provider recommendation | Recommend PowerShellCim, NativeSmbRpc, TargetPath, or blocked | Info |

## Implementation Notes

- Reuse `Invoke-ShareSurferPortProtocolAssessment` concepts, but do not just wrap it. This command must go beyond port checks into collection capability proof.
- Reuse `Get-ShareSurferSmbRpcShareInfo`, `ConvertTo-ShareSurferSharePermissionRowsFromSecurityDescriptor`, and `Get-ShareSurferNativeOpenFileRows` where practical.
- Add scriptblock injection hooks for tests, following the existing `$global:ShareSurferOpenFileProvider` style.
- Keep console logging visible by default and suppressible with `-Quiet`.
- Use `Write-ShareSurferStatus` for status lines.
- Use `Protect-ShareSurferRow` or a narrow diagnostic redaction helper so raw and redacted outputs stay separated.
- Preserve raw Win32 result codes/messages in raw outputs when available.
- Explain that SMB/RPC reachability does not prove readable or parseable security descriptors.
- Keep outputs additive and do not require dashboard changes in the first slice.

## Acceptance Criteria

- Public command exported in `ShareSurfer.psm1` and `ShareSurfer.psd1`.
- Tests verify:
  - UNC target parsing.
  - computer/share target parsing.
  - injected successful native share metadata and descriptor parse.
  - injected native descriptor unavailable/parse failed classification.
  - injected open-file capability success/failure/skip.
  - redacted outputs do not preserve raw host/share/path/user values.
  - summary JSON and LLM summary contain diagnostic categories and next actions.
- Docs explain:
  - when to use this command before scanning.
  - how it differs from `Invoke-ShareSurferPortProtocolAssessment`.
  - how to share the redacted output.
- Validation:
  - `git diff --check`
  - `pwsh -NoLogo -NoProfile -File tests/Invoke-ShareSurferTests.ps1`

## Non-Goals

- No permission remediation.
- No forced WinRM dependency.
- No external service or LLM call.
- No dashboard implementation in this slice.
- No release packaging unless the user asks for a release checkpoint.
- No live lab dependency for local unit validation.
