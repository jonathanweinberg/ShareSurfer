# ShareSurfer Production Readiness And TUI Usability Plan

Date: 2026-06-17
Tracking issue: https://github.com/jonathanweinberg/ShareSurfer/issues/262
Current baseline reviewed: `origin/main` after `v0.1.0-pre.18`

## Executive Judgment

ShareSurfer has crossed the line from prototype to useful pre-1.0 tool. The next step is not "more features everywhere." The next step is a production-readiness program that proves the tool can be installed, run, trusted, supported, and understood by ordinary Windows and file-share operators in locked-down environments.

The strongest near-term product move is a guided, pure-PowerShell operator assistant. ShareSurfer already has text-mode pieces: ownership CSV picking, header mapping, AD/OBS enrichment, scan progress, validation, release packaging, and stop-gate docs. These should become a coherent "Start Here" flow before we introduce a heavy full-screen TUI framework.

Recommended direction:

1. Keep the production collector path PowerShell 5.1-compatible, offline, and dependency-light.
2. Build a first-class guided console assistant using PowerShell host APIs and plain text fallbacks.
3. Use current export validators, release-readiness scripts, and dashboard proof as gates, not as documentation-only claims.
4. Treat richer .NET TUI frameworks or a signed WebView2 viewer as later companions, not requirements for the collector.
5. Define production readiness through evidence: live lab proof, package verification, install/uninstall clarity, security review, supportability, and operator comprehension.

## Current Product Surface

Current production-facing strengths:

- PowerShell 5.1-oriented collector module.
- Normalized CSV export set.
- Offline HTML report and packaged standalone dashboard.
- Static dashboard packaging with file-url smoke proof.
- Release metadata and dependency-age release checks.
- Windows PowerShell 5.1 smoke lane.
- Evidence confidence and protocol readiness outputs.
- Owner review packet and migration decision import/export.
- Migration Discovery quality harness.
- Admin ownership import and text-mode CSV picker.
- Nonpermissive two-host workflow documentation.

Current TUI-like surfaces:

- `Join-ShareSurferOwnershipSources -Interactive -BrowseForCsv`
- `New-ShareSurferOwnershipMappingProfile -Interactive`
- forbidden OU selection in ownership enrichment
- scan progress/status lines
- validation summaries and next-command output

There is not currently a separate full-screen TUI application. That is a good thing for now. The existing surface is scriptable, testable, and compatible with the project's Windows collector promise.

## External Research Summary

### Usability Principles

Nielsen Norman Group's 10 heuristics are directly useful for ShareSurfer's console flows: visibility of system status, plain-language concepts, clear exits, consistency, error prevention, recognition over recall, efficient shortcuts, minimalist design, useful errors, and task-focused help.

Source:
- https://www.nngroup.com/articles/ten-usability-heuristics/

Command Line Interface Guidelines emphasize several rules that fit ShareSurfer:

- show current state clearly
- suggest next commands
- keep human messages separate from machine-readable output
- use explicit confirmation for boundary-crossing actions
- make escape paths visible
- make failures recoverable
- do not phone home without consent
- make distribution easy

Source:
- https://clig.dev/

### PowerShell Console Interaction

PowerShell's host UI model supports structured finite choices through `PromptForChoice`, where choices have labels/descriptions and a default index. This is better than raw `Read-Host` for decisions like "scan now, validate only, package dashboard, quit."

Source:
- https://learn.microsoft.com/en-us/dotnet/api/system.management.automation.host.pshostuserinterface.promptforchoice

`Read-Host` remains appropriate for free-form strings such as a path, owner label, OBS attribute, or filter text. ShareSurfer should wrap it so prompts always show current state, examples, defaults, validation errors, and how to quit or go back.

### Windows Terminal And Console Capabilities

Windows console virtual terminal sequences can control cursor movement, color, and formatting, but the Microsoft docs explicitly describe mode configuration through `GetConsoleMode` and `SetConsoleMode`. ShareSurfer should not require advanced VT behavior for the collector path. It can use color and simple layout when available, but every assistant screen must degrade to plain text.

Source:
- https://learn.microsoft.com/en-us/windows/console/console-virtual-terminal-sequences

### .NET And Third-Party TUI Frameworks

Terminal.Gui is a strong .NET TUI toolkit with rich widgets, tables, trees, file dialogs, wizards, keyboard and mouse support. Current NuGet metadata for `Terminal.Gui 2.4.6` shows `net10.0` as the included target framework. That is attractive for a future companion executable, but it is not a clean fit for the immediate PowerShell 5.1 collector path.

Sources:
- https://github.com/gui-cs/Terminal.Gui
- https://www.nuget.org/packages/Terminal.Gui

Spectre.Console provides rich formatted console output, tables, charts, progress, prompts, status/spinners, and targets .NET Standard 2.0 through .NET 10. It is more plausible as a future packaged helper than Terminal.Gui v2, but it still introduces dependency, packaging, and PowerShell 5.1 compatibility questions.

Source:
- https://spectreconsole.net/

Microsoft's .NET Standard guidance says .NET Standard 2.0 is the common choice for sharing code with .NET Framework, but it also warns that .NET Framework consumers should preferably target 4.7.2 or higher for .NET Standard library consumption. Windows PowerShell 5.1 is .NET Framework-based, so any assembly-based TUI route needs explicit Windows PowerShell validation before it can become a production promise.

Source:
- https://learn.microsoft.com/en-us/dotnet/standard/net-standard

## TUI Strategy

### Near Term: Pure PowerShell Guided Assistant

Build a dependency-light guided assistant around the existing commands instead of a new full-screen app.

Candidate command:

```powershell
Start-ShareSurferOperatorAssistant
```

Primary goals:

- help an amateur admin get from release ZIP to validated export and dashboard
- avoid requiring command memorization
- preserve copy/paste and automation paths
- write a reusable JSON run plan and a rerun `.ps1`
- never hide what command will run
- never require npm, internet, or PowerShell 7 on collector hosts

Assistant sections:

1. Environment preflight
2. Release folder and unblock check
3. Target selection
4. OBS attribute and AD lookup settings
5. ownership CSV selection and enrichment
6. forbidden OU selection
7. discounted principals selection
8. scan command preview
9. export validation
10. standalone dashboard packaging
11. stop-gate review
12. support bundle generation

Each screen should show:

- current step and total steps
- current selections
- required/missing values
- recommended default
- commands available: next, back, skip, save, quit, help
- exact command preview before execution

State files:

```text
C:\ShareSurfer\inputs\operator-assistant.plan.json
C:\ShareSurfer\inputs\operator-assistant-rerun.ps1
C:\ShareSurfer\inputs\ownership-import.definition.json
C:\ShareSurfer\inputs\ownership-enrichment.csv
C:\ShareSurfer\inputs\discounted-principals.csv
```

Design rule: every interactive choice must have a noninteractive equivalent parameter path.

### Mid Term: Console Rendering Layer

Add small internal helpers so all text-mode flows feel consistent:

```powershell
Get-ShareSurferConsoleCapabilities
Write-ShareSurferConsoleHeading
Write-ShareSurferConsolePanel
Write-ShareSurferConsoleTable
Read-ShareSurferConsoleChoice
Read-ShareSurferConsoleText
Read-ShareSurferConsoleMultiSelect
Write-ShareSurferNextCommand
```

These helpers should be plain PowerShell, covered by tests, and able to render to strings for snapshot tests. They should support a no-color mode and avoid hard-coded console widths.

### Later: Rich TUI Companion

Only consider a richer TUI after the pure PowerShell assistant proves the workflow.

Options:

- a signed .NET console companion using Spectre.Console
- a signed .NET full-screen TUI using Terminal.Gui if runtime/dependency choices become acceptable
- a signed WebView2 dashboard viewer that opens packaged dashboard folders

Recommendation: do not make Terminal.Gui, Spectre.Console, ConsoleGuiTools, or WebView2 required for collection before 1.0.

## Production Readiness Workstreams

### P0: Trustworthy Installation And First Run

Goal: a first-time operator can install, unblock, preflight, scan, validate, and package without guessing.

Candidate issues:

1. Add `Start-ShareSurferOperatorAssistant` as a guided pure-PowerShell first-run assistant.
2. Add `Test-ShareSurferCollectorReadiness` as a more explicit preflight command for environment, elevation, AD module, SMB/CIM readiness, write paths, and dashboard packaging prerequisites.
3. Add release-root `START-HERE.md` generated into the ZIP with exact commands for the extracted version folder.
4. Add an install/uninstall/upgrade doc that explains ZIP extraction, `Unblock-File`, module import, and safe removal.

Validation gates:

- Windows PowerShell 5.1 parser/import.
- PowerShell Core parser/import.
- assistant no-color/plain transcript snapshot tests.
- nonpermissive quickstart dry-run test using fake paths.

### P0: Current Live Enterprise Proof

Goal: make the current prerelease credible against a realistic Windows/AD lab, not only historical proof.

Candidate issues:

1. Run current `v0.1.0-pre.18` or later through the enterprise lab validation.
2. Confirm enterprise users/groups/shares/files/ACL scenarios under the default 2 GiB generated-data budget.
3. Validate current exports, report, standalone dashboard package, and support bundle baseline.
4. Capture current-schema proof summary without publishing sensitive raw evidence.

Validation gates:

- `Invoke-ShareSurferLabValidation.ps1 -RequireLiveEvidence`
- `Test-ShareSurferExport`
- packaged dashboard smoke
- Windows PowerShell 5.1 smoke
- evidence confidence has no unexplained stop gates for the proof scope

### P0: Release Trust And Supply Chain

Goal: make release artifacts verifiable and enterprise-friendly.

Candidate issues:

1. Add release package verification command, for example `Test-ShareSurferReleasePackage`.
2. Generate a release SBOM or dependency inventory for packaged assets.
3. Add GitHub artifact attestations when feasible.
4. Add Authenticode signing for PowerShell files and a signed checksum path.
5. Defer signed WebView2 viewer until static package verification is stable.

Validation gates:

- package hash verification
- dependency-age report present and valid
- internal planning docs excluded from release package
- release manifest points at exact source commit
- signing status is explicit, never implied

### P1: TUI Usability And Operator Delight

Goal: make the console flow feel guided, forgiving, and transparent.

Candidate issues:

1. Extract reusable console rendering/prompt helpers.
2. Replace ad hoc CSV picker output with a consistent assistant layout.
3. Add searchable/filterable text picker behavior for CSVs and OUs.
4. Add visible breadcrumbs, current selections, and clear finish/quit/back commands.
5. Save partial progress automatically so a long setup can resume.
6. Add transcript-based tests for beginner and locked-down workflows.

Validation gates:

- transcript snapshots for happy path, missing AD module, no CSV files, ambiguous CSV headers, forbidden OU selection, quit/resume
- no terminal color dependency
- no hard dependency on Windows Terminal
- Ctrl-C and quit behavior leave reusable files in a coherent state

### P1: Dashboard Production Experience

Goal: prove the dashboard works for enterprise-shaped exports and business review sessions.

Candidate issues:

1. Add larger representative dashboard fixture for performance testing.
2. Add row-count and render-time budgets.
3. Add table virtualization coverage for raw evidence views.
4. Improve keyboard navigation and visible focus in the standalone dashboard.
5. Add exportable per-owner review packet from dashboard filters.

Validation gates:

- `npm --prefix interface/standalone-dashboard run test`
- `npm --prefix interface/standalone-dashboard run build`
- packaged file-url e2e
- no external network requests
- no blank app state
- large table scrolling remains responsive

### P1: Supportability And Privacy

Goal: make bug reports useful without increasing data exposure.

Candidate issues:

1. Keep baseline support bundle behavior working.
2. Improve support bundle performance on enterprise-sized exports.
3. Add support-bundle manifest with included files, row counts, and redaction state.
4. Add a public/private evidence policy for lab proof and customer submissions.
5. Add a `New-ShareSurferBugReportPacket` wrapper that produces a GitHub-ready summary plus a local bundle path.

Validation gates:

- redacted bundle generated for representative enterprise export within a defined time budget
- no raw SID/path/identity leakage in redacted bundle tests
- support manifest includes tool version, schema version, and confidence summary

### P2: Security And Hardening

Goal: before 1.0, prove ShareSurfer's read-only boundaries and release trust story.

Candidate issues:

1. Threat model collector, dashboard, release ZIP, support bundle, and lab evidence.
2. Add script signing or signed-release workflow.
3. Add static analysis/security scan workflow where practical.
4. Add least-privilege collection guidance and a permission matrix.
5. Add malicious CSV and dashboard data hardening tests.

Validation gates:

- documented trust boundaries
- no external calls in collector/dashboard by default
- CSV injection mitigations for generated CSVs where opened in Excel
- dashboard escapes untrusted evidence values
- release package verification passes offline

### P2: Maintainability

Goal: keep the project buildable as it grows.

Candidate issues:

1. Split the monolithic PowerShell test runner into domain suites while keeping one-command validation.
2. Split dashboard `App.tsx` into view/workbench components and hooks.
3. Create schema contract tests that fail with actionable messages.
4. Add performance tests for export validation and support bundle generation.
5. Add contributor docs for adding a new CSV dataset.

Validation gates:

- one-command all-tests still works
- domain-specific tests can run independently
- dashboard schema parity remains green
- no release package drift

## Proposed Issue Sequence

1. `TUI: add pure PowerShell operator assistant skeleton`
2. `TUI: extract console rendering and prompt helpers`
3. `TUI: add resumable run plan and rerun script generation`
4. `Validation: rerun current enterprise lab proof for latest prerelease`
5. `Release: add offline release package verifier`
6. `Support: make enterprise support bundle generation bounded and manifest-driven`
7. `Security: threat model collector, dashboard, release, and support bundle`
8. `Dashboard: add enterprise-scale performance and keyboard-accessibility gates`
9. `Release: add signing/attestation design and first unsigned-to-signed transition plan`
10. `Docs: publish production readiness checklist for 1.0`

## TUI Acceptance Criteria

A ShareSurfer text-mode assistant is production-useful when:

- it runs in Windows PowerShell 5.1
- it runs without internet access
- it requires no GUI file dialogs
- it requires no npm, Vite, or PowerShell 7 on collector hosts
- every action has a visible command preview
- every decision has a back/quit path
- every generated file path is shown
- state can be saved and rerun
- it handles no AD module, missing CSVs, wrong OBS attribute, blocked WinRM/CIM, SMB/RPC fallback, and non-admin mode in plain language
- it produces the same files a scripted operator would produce
- it never changes share/file permissions

## Production Readiness Definition

ShareSurfer is production ready when all of these are true:

- latest release package verifies offline from hash/manifest/signature evidence
- collector has current Windows PowerShell 5.1 validation
- current live enterprise lab proof exists for the current schema
- dashboard packaging is proven from representative export data
- first-run assistant or docs reliably guide a new operator through scan, validate, package, review, and stop gates
- support bundle baseline is performant and safe enough for bug reports
- security/threat model is documented
- release notes, quickstarts, and release metadata agree
- known deferred work is clearly labeled as deferred rather than implied complete

## Explicit Non-Goals For The Immediate Production Path

- Do not require Terminal.Gui or Spectre.Console for the collector.
- Do not require Windows Terminal specifically.
- Do not require a browser companion for collection.
- Do not require npm/Vite on operator machines.
- Do not add AI/LLM calls to ownership mapping or TUI guidance.
- Do not add live permission remediation.
- Do not expand redacted support-output scope beyond what is required to keep baseline supportability credible.

## Source Links

- Nielsen Norman Group, 10 usability heuristics: https://www.nngroup.com/articles/ten-usability-heuristics/
- Command Line Interface Guidelines: https://clig.dev/
- Microsoft, PowerShell host `PromptForChoice`: https://learn.microsoft.com/en-us/dotnet/api/system.management.automation.host.pshostuserinterface.promptforchoice
- Microsoft, Windows console virtual terminal sequences: https://learn.microsoft.com/en-us/windows/console/console-virtual-terminal-sequences
- Microsoft, .NET Standard compatibility: https://learn.microsoft.com/en-us/dotnet/standard/net-standard
- Terminal.Gui repository: https://github.com/gui-cs/Terminal.Gui
- Terminal.Gui NuGet package: https://www.nuget.org/packages/Terminal.Gui
- Spectre.Console documentation: https://spectreconsole.net/
- PowerShell ConsoleGuiTools repository: https://github.com/PowerShell/ConsoleGuiTools
