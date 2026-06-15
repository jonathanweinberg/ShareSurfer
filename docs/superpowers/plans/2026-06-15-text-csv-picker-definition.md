# Text CSV Picker Definition Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Add a pure text-mode filesystem CSV picker and reusable JSON definition file to ShareSurfer ownership enrichment.

**Architecture:** Extend `Join-ShareSurferOwnershipSources` without changing the existing noninteractive path flow. Add focused private helpers in the same public command file for path browsing and in `Get-ShareSurferOwnershipSourceMap.ps1` for reading/writing definition JSON. Definition JSON becomes the durable input when the operator wants to rerun the same multi-CSV enrichment later.

**Tech Stack:** PowerShell 5.1-compatible module code, JSON via `ConvertTo-Json` / `ConvertFrom-Json`, existing CSV/export helpers, existing single-file test harness.

**Tracking Issue:** #230

---

## File Structure

- Modify `src/ShareSurfer/Public/Join-ShareSurferOwnershipSources.ps1`
  - Add `-BrowseForCsv` and `-DefinitionPath`.
  - Load selected paths/settings from definition JSON when supplied and no explicit paths are supplied.
  - Use a pure text-mode filesystem picker when `-BrowseForCsv -Interactive` is supplied.
  - Save selected paths/settings to JSON when `-DefinitionPath` is supplied.
- Modify `src/ShareSurfer/Private/Get-ShareSurferOwnershipSourceMap.ps1`
  - Add `Get-ShareSurferOwnershipImportDefinition`.
  - Add `Export-ShareSurferOwnershipImportDefinition`.
  - Add small helpers to normalize definition values and produce reusable command text that prefers `-DefinitionPath`.
- Modify `tests/Invoke-ShareSurferTests.ps1`
  - Add focused tests for selection parsing, picker command behavior, definition write/read, and rerun behavior.
- Modify `README.md`, `docs/admin-ownership-import.md`, and `docs/ownership-csv-ingest-quick-reference.md`
  - Explain first-run browse mode and later definition rerun.

---

## Task 1: Definition JSON Read/Write Helpers

**Files:**
- Modify: `src/ShareSurfer/Private/Get-ShareSurferOwnershipSourceMap.ps1`
- Test: `tests/Invoke-ShareSurferTests.ps1`

- [x] **Step 1: Add a failing definition round-trip test**

Add a test near existing ownership enrichment tests:

```powershell
@{
    Name = 'Ownership import definition round-trips selected paths and settings'
    Script = {
        $definitionPath = Join-Path $script:TempRoot 'ownership-import.definition.json'
        $sourceOne = Join-Path $script:TempRoot 'hr.csv'
        $sourceTwo = Join-Path $script:TempRoot 'project.csv'

        Export-ShareSurferOwnershipImportDefinition `
            -Path $definitionPath `
            -SelectedCsvPaths @($sourceOne, $sourceTwo) `
            -SourceFolder $script:TempRoot `
            -OutputPath (Join-Path $script:TempRoot 'ownership-enrichment.csv') `
            -MappingProfilePaths @((Join-Path $script:TempRoot 'hr.mapping.json')) `
            -ObsHeader 'Org Path' `
            -ObsAttribute 'info' `
            -AdLookupMode 'DirectoryOnly' `
            -ForbiddenOu @('OU=Disabled,DC=example,DC=test') `
            -Force

        $definition = Get-ShareSurferOwnershipImportDefinition -Path $definitionPath
        Assert-Equal $definition.Version 1 'Definition version should be 1.'
        Assert-Equal @($definition.SelectedCsvPaths).Count 2 'Definition should preserve selected CSV paths.'
        Assert-Equal $definition.ObsAttribute 'info' 'Definition should preserve OBS attribute.'
        Assert-Equal $definition.AdLookupMode 'DirectoryOnly' 'Definition should preserve AD lookup mode.'
        Assert-Equal @($definition.ForbiddenOus).Count 1 'Definition should preserve forbidden OUs.'
    }
}
```

- [x] **Step 2: Implement definition helpers**

Add these functions to `Get-ShareSurferOwnershipSourceMap.ps1`:

```powershell
function Get-ShareSurferOwnershipImportDefinition {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Ownership import definition was not found: $Path"
    }

    $definition = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
    if ($null -eq $definition.PSObject.Properties['version'] -or [int]$definition.version -ne 1) {
        throw "Unsupported ownership import definition version in $Path"
    }

    [pscustomobject]@{
        Version = [int]$definition.version
        SelectedCsvPaths = @($definition.selectedCsvPaths | ForEach-Object { [string]$_ })
        SourceFolder = [string]$definition.sourceFolder
        OutputPath = [string]$definition.outputPath
        MappingProfilePaths = @($definition.mappingProfilePaths | ForEach-Object { [string]$_ })
        ObsHeader = [string]$definition.obsHeader
        ObsAttribute = [string]$definition.obsAttribute
        AdLookupMode = [string]$definition.adLookupMode
        ForbiddenOus = @($definition.forbiddenOus | ForEach-Object { [string]$_ })
        CreatedBy = [string]$definition.createdBy
        CreatedAt = [string]$definition.createdAt
        UpdatedAt = [string]$definition.updatedAt
    }
}

function Export-ShareSurferOwnershipImportDefinition {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $Path,
        [string[]] $SelectedCsvPaths = @(),
        [string] $SourceFolder = '',
        [string] $OutputPath = '',
        [string[]] $MappingProfilePaths = @(),
        [string] $ObsHeader = '',
        [string] $ObsAttribute = 'extensionAttribute10',
        [string] $AdLookupMode = 'Auto',
        [string[]] $ForbiddenOu = @(),
        [switch] $Force
    )

    if ((Test-Path -LiteralPath $Path) -and -not $Force) {
        throw "Ownership import definition already exists: $Path. Use -Force to overwrite it."
    }

    $parent = Split-Path -Parent $Path
    if (-not [string]::IsNullOrWhiteSpace($parent) -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    $now = [DateTimeOffset]::UtcNow.ToString('o')
    $createdBy = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    $definition = [ordered]@{
        version = 1
        selectedCsvPaths = @($SelectedCsvPaths | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { [string]$_ })
        sourceFolder = $SourceFolder
        outputPath = $OutputPath
        mappingProfilePaths = @($MappingProfilePaths | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { [string]$_ })
        obsHeader = $ObsHeader
        obsAttribute = $ObsAttribute
        adLookupMode = $AdLookupMode
        forbiddenOus = @($ForbiddenOu | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { [string]$_ })
        createdBy = $createdBy
        createdAt = $now
        updatedAt = $now
    }

    Set-Content -LiteralPath $Path -Value ($definition | ConvertTo-Json -Depth 8) -Encoding UTF8
    $Path
}
```

- [x] **Step 3: Run focused tests**

Run:

```bash
pwsh -NoLogo -NoProfile -File tests/Invoke-ShareSurferTests.ps1
```

Expected: the new test passes and existing tests remain green.

---

## Task 2: Pure Text Filesystem CSV Picker

**Files:**
- Modify: `src/ShareSurfer/Public/Join-ShareSurferOwnershipSources.ps1`
- Test: `tests/Invoke-ShareSurferTests.ps1`

- [x] **Step 1: Add focused tests for picker command parsing**

Add tests that call helper functions directly:

```powershell
@{
    Name = 'CSV picker state toggles files and navigates folders'
    Script = {
        $root = Join-Path $script:TempRoot 'PickerRoot'
        $child = Join-Path $root 'Child'
        New-Item -ItemType Directory -Path $child -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $root 'a.csv') -Value 'EmployeeID,OBS'
        Set-Content -LiteralPath (Join-Path $child 'b.csv') -Value 'EmployeeID,OBS'

        $state = New-ShareSurferCsvPickerState -StartFolder $root
        $view = Get-ShareSurferCsvPickerView -State $state
        Assert-True (@($view.Entries | Where-Object { $_.Name -eq 'a.csv' }).Count -eq 1) 'Picker should show CSV files.'

        Invoke-ShareSurferCsvPickerCommand -State $state -Command '2' | Out-Null
        Assert-Equal @($state.SelectedCsvPaths).Count 1 'Numeric CSV command should toggle selection.'

        Invoke-ShareSurferCsvPickerCommand -State $state -Command '1' | Out-Null
        Assert-True ($state.CurrentFolder -like '*Child') 'Numeric folder command should navigate into folder.'

        Invoke-ShareSurferCsvPickerCommand -State $state -Command 'A' | Out-Null
        Assert-Equal @($state.SelectedCsvPaths).Count 2 'A should select all CSVs in the current folder.'
    }
}
```

- [x] **Step 2: Implement picker helpers**

Add helpers to `Join-ShareSurferOwnershipSources.ps1`:

```powershell
function New-ShareSurferCsvPickerState {
    param([string] $StartFolder)
    $resolved = if ([string]::IsNullOrWhiteSpace($StartFolder)) { (Get-Location).Path } else { (Resolve-Path -LiteralPath $StartFolder).Path }
    [pscustomobject]@{
        CurrentFolder = $resolved
        SelectedCsvPaths = New-Object System.Collections.Generic.List[string]
        Done = $false
        Quit = $false
    }
}

function Get-ShareSurferCsvPickerView {
    param([Parameter(Mandatory = $true)] $State)
    $directories = @(Get-ChildItem -LiteralPath $State.CurrentFolder -Directory | Sort-Object Name)
    $csvFiles = @(Get-ChildItem -LiteralPath $State.CurrentFolder -File -Filter '*.csv' | Sort-Object Name)
    $entries = New-Object System.Collections.ArrayList
    foreach ($directory in $directories) {
        [void]$entries.Add([pscustomobject]@{ Kind = 'Directory'; Name = $directory.Name; FullName = $directory.FullName; Selected = $false })
    }
    foreach ($file in $csvFiles) {
        $selected = @($State.SelectedCsvPaths | Where-Object { $_.ToLowerInvariant() -eq $file.FullName.ToLowerInvariant() }).Count -gt 0
        [void]$entries.Add([pscustomobject]@{ Kind = 'Csv'; Name = $file.Name; FullName = $file.FullName; Selected = $selected })
    }
    [pscustomobject]@{ CurrentFolder = $State.CurrentFolder; Entries = @($entries) }
}

function Invoke-ShareSurferCsvPickerCommand {
    param(
        [Parameter(Mandatory = $true)] $State,
        [string] $Command = ''
    )
    $text = $Command.Trim()
    if ([string]::IsNullOrWhiteSpace($text)) { return $State }
    if ($text.ToUpperInvariant() -eq 'D') { $State.Done = $true; return $State }
    if ($text.ToUpperInvariant() -eq 'Q') { $State.Quit = $true; return $State }
    if ($text.ToUpperInvariant() -eq 'U') { $State.CurrentFolder = (Split-Path -Parent $State.CurrentFolder); return $State }
    if ($text.ToUpperInvariant() -eq 'C') { $State.SelectedCsvPaths.Clear(); return $State }

    $view = Get-ShareSurferCsvPickerView -State $State
    if ($text.ToUpperInvariant() -eq 'A') {
        foreach ($entry in @($view.Entries | Where-Object { $_.Kind -eq 'Csv' })) {
            if (-not (@($State.SelectedCsvPaths) | Where-Object { $_.ToLowerInvariant() -eq $entry.FullName.ToLowerInvariant() })) {
                $State.SelectedCsvPaths.Add([string]$entry.FullName)
            }
        }
        return $State
    }
    if ($text.ToUpperInvariant() -eq 'P') {
        return $State
    }
    if ($text -match '^\d+$') {
        $index = [int]$text
        if ($index -lt 1 -or $index -gt @($view.Entries).Count) { return $State }
        $entry = @($view.Entries)[$index - 1]
        if ($entry.Kind -eq 'Directory') {
            $State.CurrentFolder = [string]$entry.FullName
        }
        elseif ($entry.Kind -eq 'Csv') {
            $existing = @($State.SelectedCsvPaths | Where-Object { $_.ToLowerInvariant() -eq ([string]$entry.FullName).ToLowerInvariant() })
            if ($existing.Count -gt 0) {
                $remaining = @($State.SelectedCsvPaths | Where-Object { $_.ToLowerInvariant() -ne ([string]$entry.FullName).ToLowerInvariant() })
                $State.SelectedCsvPaths.Clear()
                foreach ($item in $remaining) { $State.SelectedCsvPaths.Add([string]$item) }
            }
            else {
                $State.SelectedCsvPaths.Add([string]$entry.FullName)
            }
        }
    }
    $State
}
```

- [x] **Step 3: Add interactive renderer**

Add `Read-ShareSurferCsvPickerSelection` that loops until done/quit, prints current folder, numbered directories/CSV files, selected state, and commands.

Expected command labels:

```text
number = open folder or toggle CSV
A      = select all CSVs in this folder
C      = clear all selected CSVs
U      = go up one folder
P      = show selected paths
D      = done
Q      = quit without importing
```

- [x] **Step 4: Wire `-BrowseForCsv` into source path resolution**

Add `[switch] $BrowseForCsv` to `Join-ShareSurferOwnershipSources`.

Change source path selection so:

- explicit `-Path` still wins
- `-DefinitionPath` supplies paths when no explicit `-Path` is supplied
- `-BrowseForCsv -Interactive` launches the navigator
- existing `-SourceFolder -Interactive` flat folder selection remains as fallback

- [x] **Step 5: Run focused tests**

Run:

```bash
pwsh -NoLogo -NoProfile -File tests/Invoke-ShareSurferTests.ps1
```

Expected: all tests pass.

---

## Task 3: Definition-Driven Join Workflow

**Files:**
- Modify: `src/ShareSurfer/Public/Join-ShareSurferOwnershipSources.ps1`
- Modify: `src/ShareSurfer/Private/Get-ShareSurferOwnershipSourceMap.ps1`
- Test: `tests/Invoke-ShareSurferTests.ps1`

- [x] **Step 1: Add rerun test**

Add a test:

```powershell
@{
    Name = 'Join-ShareSurferOwnershipSources reruns from ownership import definition'
    Script = {
        $sourcePath = Join-Path $script:TempRoot 'hr.csv'
        Set-Content -LiteralPath $sourcePath -Value @(
            'EmployeeID,OBS,BusinessUnit',
            'E1001,CORP.FIN.AP,Finance'
        )
        $definitionPath = Join-Path $script:TempRoot 'ownership-import.definition.json'
        Export-ShareSurferOwnershipImportDefinition `
            -Path $definitionPath `
            -SelectedCsvPaths @($sourcePath) `
            -SourceFolder $script:TempRoot `
            -OutputPath (Join-Path $script:TempRoot 'ownership-enrichment.csv') `
            -ObsAttribute 'extensionAttribute10' `
            -AdLookupMode 'DirectoryOnly' `
            -Force

        $outputPath = Join-Path $script:TempRoot 'rerun-output.csv'
        $summary = Join-ShareSurferOwnershipSources -DefinitionPath $definitionPath -OutputPath $outputPath -Force
        $rows = @(Import-Csv -LiteralPath $outputPath)
        Assert-Equal $summary.SourceCount 1 'Definition rerun should use one source path.'
        Assert-Equal $rows[0].EmployeeId 'E1001' 'Definition rerun should import selected CSV rows.'
    }
}
```

- [x] **Step 2: Implement definition precedence**

Inside `Join-ShareSurferOwnershipSources`:

- Load definition early when `-DefinitionPath` exists.
- If `-Path` is empty, use `definition.SelectedCsvPaths`.
- If `-MappingProfilePath` is empty, use `definition.MappingProfilePaths`.
- If caller did not explicitly provide non-default settings, use `definition.ObsHeader`, `definition.ObsAttribute`, `definition.AdLookupMode`, and `definition.ForbiddenOus`.
- If caller supplies explicit parameters, caller values win.

- [x] **Step 3: Save definition after picker/source resolution**

When `-DefinitionPath` is supplied and selected paths are known, write/update JSON with:

- selected CSV paths
- source folder
- output path
- mapping profile paths
- OBS header
- OBS attribute
- AD lookup mode
- forbidden OUs
- created/updated metadata

- [x] **Step 4: Prefer definition in reusable command text**

Update `New-ShareSurferOwnershipEnrichmentReusableCommands` so when `-DefinitionPath` is known, the generated rerun command calls:

```powershell
Join-ShareSurferOwnershipSources -DefinitionPath $definitionPath -OutputPath $outputPath -Force
```

- [x] **Step 5: Run focused tests**

Run:

```bash
pwsh -NoLogo -NoProfile -File tests/Invoke-ShareSurferTests.ps1
```

Expected: all tests pass.

---

## Task 4: Novice-Admin Documentation

**Files:**
- Modify: `README.md`
- Modify: `docs/admin-ownership-import.md`
- Modify: `docs/ownership-csv-ingest-quick-reference.md`

- [x] **Step 1: Update quickstart wording**

Add a short section explaining:

- first run uses `-Interactive -BrowseForCsv -DefinitionPath`
- later runs use only `-DefinitionPath`
- selected CSVs and settings are preserved in JSON
- the JSON is not scan evidence by itself; the scan export writes `ownership_enrichment.csv`

- [x] **Step 2: Add copy/paste examples**

Add examples:

```powershell
Join-ShareSurferOwnershipSources `
  -Interactive `
  -BrowseForCsv `
  -SourceFolder 'C:\ShareSurfer\inputs' `
  -DefinitionPath 'C:\ShareSurfer\inputs\ownership-import.definition.json' `
  -OutputPath 'C:\ShareSurfer\inputs\ownership-enrichment.csv' `
  -ReusableCommandPath 'C:\ShareSurfer\inputs\ownership-enrichment-rerun.ps1' `
  -Force
```

```powershell
Join-ShareSurferOwnershipSources `
  -DefinitionPath 'C:\ShareSurfer\inputs\ownership-import.definition.json' `
  -OutputPath 'C:\ShareSurfer\inputs\ownership-enrichment.csv' `
  -Force
```

- [x] **Step 3: Run docs-related checks**

Run:

```bash
rg -n "BrowseForCsv|ownership-import.definition.json|DefinitionPath" README.md docs/admin-ownership-import.md docs/ownership-csv-ingest-quick-reference.md
git diff --check
```

Expected: docs mention the new workflow and diff check is clean.

---

## Task 5: Final Validation and Closeout

**Files:**
- All changed files

- [x] **Step 1: Run validation**

Run:

```bash
git diff --check
pwsh -NoLogo -NoProfile -File tests/Invoke-ShareSurferTests.ps1
```

Expected: diff check clean and PowerShell suite passes.

- [x] **Step 2: Commit and push**

Commit message:

```bash
git commit -m "feat: add text CSV picker definition workflow (#230)"
```

- [x] **Step 3: Comment on issue #230**

Use a Markdown body file with:

- commit SHA
- what changed
- validation
- follow-up

- [x] **Step 4: Open PR to main**

Open a ready PR. Merge only after checks pass.

- [x] **Step 5: Decide prerelease**

If merged, publish a fresh prerelease because this changes the operator-facing ownership import workflow.

---

## Self-Review

- Spec coverage: The plan covers pure text navigation, selected CSVs, reusable JSON definition, rerun behavior, docs, tests, and issue closeout.
- Placeholder scan: No TBD/TODO placeholders remain.
- Type consistency: Public parameters use `BrowseForCsv` and `DefinitionPath`; JSON file uses lower camel-case persisted properties; returned definition object uses PowerShell-friendly PascalCase properties.
