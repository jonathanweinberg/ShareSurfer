# Staged ShareSurfer TUI Design

## Decision

ShareSurfer will take a staged TUI path:

1. **C now:** build a dependency-free internal console layer and use it to make ownership import feel like a real guided wizard.
2. **B later:** consider a richer/full-screen TUI or companion only after the stable console layer exists, the collector prompts are consistent, and the team can evaluate the cost of richer terminal behavior with real operator feedback.

This replaces the current prompt-control experience, which technically supports back/skip/help but still feels like a stack of `Read-Host` prompts instead of a guided tool.

## Why Not A Framework TUI First

ShareSurfer's collector runs in Windows PowerShell 5.1, in offline and nonpermissive environments, from an unsigned pre-1.0 ZIP. Operators need transcripts, scrollback, command previews, copy/pasteable rerun scripts, and readable troubleshooting evidence.

A third-party framework or full-screen alternate-buffer TUI would add risk before the workflow is stable:

- extra assemblies or runtime dependencies to explain to security teams;
- more signing and packaging work before the base experience is proven;
- possible breakage in older Windows consoles;
- weaker transcript and scrollback behavior;
- harder snapshot testing;
- less predictable accessibility behavior.

The near-term goal is not visual spectacle. It is to make the console feel calm, guided, reversible, and understandable.

## Near-Term Architecture

Add an internal console layer, tentatively `src/ShareSurfer/Private/ShareSurfer.Console.ps1`.

This layer should not export public commands. It should provide internal helpers used by startup, ownership import, CSV picking, OU picking, and future guided flows.

Core helpers:

- `Get-ShareSurferConsoleCapabilities`: detect raw-key support, redirected input/output, width, color support, and `NO_COLOR`.
- `New-ShareSurferConsoleChoiceState`: deterministic choice state for tests.
- `Invoke-ShareSurferConsoleChoiceCommand`: apply commands such as up, down, select, skip, back, help, quit, and typed number.
- `Read-ShareSurferConsoleChoice`: interactive choice reader with raw-key support where available and numbered fallback everywhere else.
- `Read-ShareSurferConsoleText`: text prompt with default, help, validation, back, quit, and clear error messages.
- `Read-ShareSurferConsoleBoolean`: yes/no prompt using the same control model.
- `Read-ShareSurferConsoleMultiSelect`: reusable multi-select engine for CSV and OU pickers.
- `Write-ShareSurferConsoleLines`: one output sink for rendered screens.

Every visible screen should be generated as `[string[]]` first, then written by the sink. This makes transcript snapshot tests practical and prevents every prompt from inventing its own formatting.

## Ownership Import Wizard First

The first implementation slice should focus on ownership import because that is where the current experience hurt most.

The ownership wizard should show:

- title and source file;
- step number and total fields;
- current field name;
- whether the field is recommended or optional;
- suggested source header, when one exists;
- available headers, compactly displayed;
- short explanation of why the field matters;
- current controls line;
- current mapped/skipped state summary.

Example shape:

```text
ShareSurfer Ownership Import
Source: hr-export.csv
Step 3/22 - EmployeeId (recommended)

Suggested header
> EmployeeID

Available headers
1 EmployeeID     2 Name     3 Mail     4 OBSPath     5 ProjectCode

Why this matters
EmployeeId is usually the strongest join key for matching HR data to AD accounts.

Controls
Enter=accept | arrows/numbers=choose | S=skip | B=back | ?=help | Q=quit
```

For source classification, the same layer should show source type, authority level, and primary anchor choices with short plain-English descriptions.

## Behavior Contract

The console layer should use one controls contract everywhere:

```text
Enter=accept | arrows/numbers=choose | S=skip | B=back | ?=help | Q=quit
```

Behavior rules:

- `Enter` accepts the default or selected item.
- Arrow keys move selection only when raw-key input is safe.
- Numbers always work as fallback selection.
- `S` skips only when the current prompt permits skip.
- `B` returns to the previous wizard field without losing current state.
- `?` shows contextual help.
- `Q` cancels the current guided flow with a clear message.
- Cancel should not partially overwrite mapping profiles, definition JSON, or rerun scripts.

Where the console cannot safely read raw keys, the same screens should still work with typed numbers and typed commands.

## Reusable Output Contract

The improved TUI must preserve existing durable outputs:

- mapping profile JSON;
- ownership import definition JSON;
- ownership enrichment CSV;
- reusable rerun scripts;
- startup JSON config;
- operator assistant plan JSON.

The TUI can improve how choices are made, but non-interactive replay must stay compatible. A saved definition should not require re-answering interactive questions.

## Testing Strategy

Tests should favor deterministic state and render output over trying to automate a real terminal.

Required test lanes:

- choice state machine: up/down/select/number/back/skip/help/quit;
- key translation: arrow keys, enter, escape, backspace, zero-character modifier keys, and unsupported function keys;
- render snapshots: ownership field screen, source type screen, authority screen, primary anchor screen, validation error screen;
- header interview: back edits a prior field, skip stays blank, quit does not write partial output;
- fallback mode: typed-number selection works when raw keys are unavailable;
- compatibility: existing `-DefinitionPath`, mapping profile, and rerun tests still pass.

The existing PowerShell suite remains the main local gate:

```powershell
pwsh -NoLogo -NoProfile -File tests/Invoke-ShareSurferTests.ps1
```

Dashboard tests are not required unless dashboard files change.

## Implementation Sequence

### Slice 1: Console Layer Foundation

- Create `ShareSurfer.Console.ps1`.
- Move the existing prompt-choice state machine out of `Join-ShareSurferOwnershipSources.ps1`.
- Add capability detection and render-to-string helpers.
- Add tests for state, key translation, and plain rendering.
- Preserve current behavior through compatibility shims.

### Slice 2: Ownership Import Wizard

- Rework `Read-ShareSurferOwnershipHeaderSelections` to render full wizard screens through the console layer.
- Add field explanations for canonical ownership fields.
- Preserve mapping profile and definition replay behavior.
- Add snapshot tests and cancellation tests.

### Slice 3: Source Classification Wizard

- Rework source type, authority level, and primary anchor prompts through the console layer.
- Improve explanations for `Identity`, `ObsContext`, `ProjectContext`, `PathOwnership`, `GroupContext`, and `Mixed`.
- Add tests for defaults, alternate selections, back, and quit.

### Slice 4: Broader Prompt Convergence

- Convert startup prompts, operator assistant prompts, CSV picker, and forbidden-OU picker to the same layer.
- Add breadcrumbs and selection summaries.
- Add a test that blocks new ad hoc `Read-Host` loops outside approved prompt-layer code.

### Slice 5: Start-ShareSurfer Home Menu

- Add a start menu shell over existing flows.
- Show readiness states for preflight, ownership inputs, scan, validate, package dashboard, handoff, and support bundle.
- Every menu action previews the exact command before running.
- State is saved through existing JSON files.

## Later Rich TUI Direction

After the internal console layer is stable, evaluate a richer TUI as a separate project.

The later richer TUI could include:

- in-place redraw;
- color accents;
- searchable pickers;
- side-by-side panels;
- a fuller menu shell;
- possibly a signed companion application or richer dashboard-adjacent experience.

That later work must not become a collector dependency until it clears these gates:

- works on target Windows admin workstations;
- does not break transcripts or evidence capture;
- is packageable and eventually signable;
- has a plain console fallback;
- does not require internet access at runtime.

## Acceptance Criteria For The First Build

The first build should be considered successful when:

- ownership import feels like a guided wizard rather than repeated raw prompts;
- back, skip, help, quit, and number fallback behave consistently;
- raw-key support improves normal consoles without being required;
- saved JSON and rerun outputs remain compatible;
- render snapshots prove the visible screens;
- the full PowerShell suite passes;
- docs show the new wizard behavior plainly for first-time admins.

## Explicit Non-Goals

- No third-party TUI framework in the near-term collector path.
- No full-screen alternate-buffer application in the first slice.
- No dependency on PowerShell 7, npm, internet access, or a GUI.
- No changes to ownership merge semantics beyond what is needed to preserve prompt choices.
- No dashboard redesign as part of this TUI slice.

## Open Follow-Up

The later richer TUI should be tracked as a long-term goal after the console layer proves itself in the field. The immediate release path should focus on the internal console layer and ownership import wizard first.
