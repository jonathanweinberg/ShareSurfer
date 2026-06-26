# ShareSurfer Agent Guide

This repository uses issue-first, branch-first delivery. Start every non-trivial code, docs, dashboard, lab, or release slice by checking the current repo state, creating or identifying a GitHub issue, and keeping unrelated user work out of the branch.

## Default Operating Rules

- Work from `/Users/jonathanweinberg/Documents/Codex_ShareSurfer`.
- Preserve unrelated untracked files and user edits.
- Use `codex/` branch names.
- Use focused commits that reference the issue number.
- Post implementation and closeout comments with `gh issue comment --body-file`.
- Do not use `prlctl` for ShareSurfer work.
- Keep public docs amateur-admin friendly and free of internal tool/provenance labels.
- Keep proof classes explicit: local `pwsh` smoke, Windows PowerShell 5.1 CI, archived enterprise proof refresh, and fresh Windows/AD live-lab validation are different evidence classes.

## Skills To Use

- `$sharesurfer-delivery-flow`: normal issue-first ShareSurfer delivery.
- `$sharesurfer-release-orchestrator`: prerelease planning, PR/merge, package, publish, and release closeout.
- `$sharesurfer-release-worker`: bounded lower-cost/Spark release audits, notes, CI summaries, and asset checks.
- `$sharesurfer-validation-output-control`: long-running validation with log capture and concise summaries.
- `$gh-issue-comment-format`: clean GitHub issue comments using body files.

## Release Cost Control

The main thread owns judgment, credentials, merge, publish, and exception handling. Do not spend the most capable model babysitting every slow or verbose command when a bounded worker can gather evidence.

Good tasks for lower-cost subagents such as `5.3-Codex-Spark`:

- stale release version/path audits
- quickstart/docs consistency checks
- release-notes draft from issue/PR/diff
- ZIP, hash, manifest, and dependency-age report inspection
- CI status polling and summarization
- validation log summarization

Keep these main-thread only unless Jonathan explicitly delegates them:

- token prompting or credential handling
- deciding to skip or reinterpret a failed gate
- merging PRs
- creating, editing, or deleting GitHub releases
- mutating live Windows/AD lab state
- posting public closeout comments when the final wording matters

## Long Validation Output

Long gates should write logs under `/private/tmp/sharesurfer-validation-<timestamp>/` and report only command, exit code, duration, pass/fail summary, failure tail, and log path.

Do not stream full successful logs into chat. For ShareSurfer releases, run heavy gates sequentially unless the user explicitly chooses wall-clock speed over stability:

1. `git diff --check`
2. stale version/path `rg`
3. `pwsh -NoLogo -NoProfile -File tests/Invoke-ShareSurferTests.ps1`
4. `npm --prefix interface/standalone-dashboard run test`
5. `npm --prefix interface/standalone-dashboard run build`
6. `pwsh -NoLogo -NoProfile -File scripts/Test-ShareSurferReleaseReadiness.ps1 ...`
7. final `scripts/New-ShareSurferRelease.ps1` from merged `main`

Avoid running the full PowerShell suite and dashboard Vitest suite concurrently during release work. A prior release saw all Vitest tests pass but the process exit nonzero from a worker update timeout while the PowerShell suite was also running.

## Release Notes And Assets

Release notes must be complete enough for a first-time operator to understand:

- what changed
- package contents
- validation performed
- unsigned pre-1.0 status
- dashboard template versus packaged export behavior
- dependency-age policy result
- ZIP SHA256

The expected release assets are the versioned ZIP and `.zip.sha256` sidecar. The ZIP should contain `release-manifest.json`, `RELEASE.md`, `SHA256SUMS.txt`, `dependency-age-report.json`, module files, scripts, docs, and prebuilt standalone dashboard template assets.

## Subagent Prompt Shape

Use goal-shaped prompts for subagents. Keep them bounded and explicit:

```text
/goal Use $sharesurfer-release-worker at /Users/jonathanweinberg/.codex/skills/sharesurfer-release-worker to audit ShareSurfer release metadata and public docs for stale version/path references. Work read-only. Return a concise markdown report with files, line numbers, and suggested fixes. Do not commit, push, comment on GitHub, or publish anything.
```

For validation logs:

```text
/goal Use $sharesurfer-validation-output-control at /Users/jonathanweinberg/.codex/skills/sharesurfer-validation-output-control to run the ShareSurfer dashboard tests with output captured under /private/tmp. Return final pass/fail, duration, and the log path. Do not modify repo files.
```
