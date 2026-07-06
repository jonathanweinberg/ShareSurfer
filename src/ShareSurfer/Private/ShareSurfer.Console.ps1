# ShareSurfer internal console layer.
# Shared prompt state machines and rendering for guided text-mode flows.
# Nothing in this file is exported; flows use these helpers so every prompt
# shares one controls contract, renders through one sink, and can be tested
# headlessly by driving the state machines with scripted commands.
#
# Controls contract (docs/superpowers/specs/2026-07-06-staged-sharesurfer-tui-design.md):
#   Enter=accept | arrows/numbers=choose | S=skip | B=back | ?=help | Q=quit
#
# Cancellation contract: prompts and wizards return results whose Action is
# 'Cancelled'; they never throw. Flow entry points decide what cancel means.

function Get-ShareSurferConsoleControlsLine {
    'Controls: Enter=accept | arrows/numbers=choose | S=skip | B=back | ?=help | Q=quit'
}

function Test-ShareSurferConsoleRawKeyAvailable {
    if (-not [string]::IsNullOrWhiteSpace([string]$env:SHARESURFER_PLAIN_CONSOLE)) {
        return $false
    }

    try {
        return ($Host.Name -eq 'ConsoleHost' -and -not [Console]::IsInputRedirected -and -not [Console]::IsOutputRedirected -and $null -ne $Host.UI.RawUI)
    }
    catch {
        return $false
    }
}

function Get-ShareSurferConsoleCapabilities {
    $plainForced = -not [string]::IsNullOrWhiteSpace([string]$env:SHARESURFER_PLAIN_CONSOLE)
    $noColor = -not [string]::IsNullOrWhiteSpace([string]$env:NO_COLOR)

    $inputRedirected = $false
    try {
        $inputRedirected = [Console]::IsInputRedirected
    }
    catch {
        $inputRedirected = $true
    }

    $outputRedirected = $false
    try {
        $outputRedirected = [Console]::IsOutputRedirected
    }
    catch {
        $outputRedirected = $true
    }

    $width = 120
    try {
        if ($null -ne $Host.UI -and $null -ne $Host.UI.RawUI -and [int]$Host.UI.RawUI.WindowSize.Width -gt 0) {
            $width = [int]$Host.UI.RawUI.WindowSize.Width
        }
    }
    catch {
    }

    [pscustomobject]@{
        RawKeys = (Test-ShareSurferConsoleRawKeyAvailable)
        InputRedirected = [bool]$inputRedirected
        OutputRedirected = [bool]$outputRedirected
        WindowWidth = [int]$width
        SupportsColor = (-not $noColor -and -not $outputRedirected -and -not $plainForced)
        PlainMode = [bool]$plainForced
    }
}

function Write-ShareSurferConsoleLines {
    param(
        [AllowEmptyCollection()]
        [string[]] $Lines = @()
    )

    foreach ($line in @($Lines)) {
        Write-Host $line
    }
}

function New-ShareSurferConsoleChoiceOption {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Value,

        [string] $Label = '',

        [string] $Description = ''
    )

    if ([string]::IsNullOrWhiteSpace($Label)) {
        $Label = $Value
    }

    [pscustomobject]@{
        Value = $Value
        Label = $Label
        Description = $Description
    }
}

function New-ShareSurferConsoleChoiceState {
    param(
        [Parameter(Mandatory = $true)]
        [object[]] $Options,

        [string] $DefaultValue = ''
    )

    $normalizedOptions = @($Options | ForEach-Object {
        if ($null -ne $_.PSObject.Properties['Value']) {
            $_
        }
        else {
            New-ShareSurferConsoleChoiceOption -Value ([string]$_)
        }
    })
    $selectedIndex = 0
    if (-not [string]::IsNullOrWhiteSpace($DefaultValue)) {
        for ($index = 0; $index -lt $normalizedOptions.Count; $index++) {
            if ([string]$normalizedOptions[$index].Value -eq $DefaultValue -or [string]$normalizedOptions[$index].Label -eq $DefaultValue) {
                $selectedIndex = $index
                break
            }
        }
    }

    [pscustomobject]@{
        Options = $normalizedOptions
        SelectedIndex = $selectedIndex
        Done = $false
        Action = ''
        SelectedValue = ''
        CustomValue = ''
        Message = ''
    }
}

function Get-ShareSurferConsoleChoiceSelectedOption {
    param(
        [Parameter(Mandatory = $true)]
        $State
    )

    if (@($State.Options).Count -eq 0) {
        return $null
    }

    $index = [Math]::Max(0, [Math]::Min([int]$State.SelectedIndex, @($State.Options).Count - 1))
    @($State.Options)[$index]
}

function Invoke-ShareSurferConsoleChoiceCommand {
    param(
        [Parameter(Mandatory = $true)]
        $State,

        [string] $Command = '',

        [switch] $AllowSkip,

        [switch] $AllowBack,

        [switch] $AllowQuit,

        [switch] $AllowCustom
    )

    $State.Action = ''
    $State.SelectedValue = ''
    $State.CustomValue = ''
    $State.Message = ''
    $text = ([string]$Command).Trim()
    $upper = $text.ToUpperInvariant()
    $optionCount = @($State.Options).Count

    if ([string]::IsNullOrWhiteSpace($text) -or $upper -in @('ENTER', 'SELECT')) {
        $selected = Get-ShareSurferConsoleChoiceSelectedOption -State $State
        $State.Done = $true
        $State.Action = 'Select'
        if ($null -ne $selected) {
            $State.SelectedValue = [string]$selected.Value
        }
        return $State
    }

    if ($upper -in @('UP', 'UPARROW')) {
        if ($optionCount -gt 0) {
            $State.SelectedIndex = if ([int]$State.SelectedIndex -le 0) { $optionCount - 1 } else { [int]$State.SelectedIndex - 1 }
        }
        return $State
    }

    if ($upper -in @('DOWN', 'DOWNARROW')) {
        if ($optionCount -gt 0) {
            $State.SelectedIndex = if ([int]$State.SelectedIndex -ge ($optionCount - 1)) { 0 } else { [int]$State.SelectedIndex + 1 }
        }
        return $State
    }

    if ($upper -eq '?' -or $upper -eq 'HELP') {
        $State.Action = 'Help'
        $State.Message = 'Use Up/Down or a number to choose. Enter selects. S skips when available. B goes back when available. Q cancels when available.'
        return $State
    }

    if ($upper -in @('S', 'SKIP') -and $AllowSkip) {
        $State.Done = $true
        $State.Action = 'Skip'
        return $State
    }

    if ($upper -in @('B', 'BACK', 'BACKSPACE') -and $AllowBack) {
        $State.Done = $true
        $State.Action = 'Back'
        return $State
    }

    if ($upper -in @('Q', 'QUIT', 'ESC', 'ESCAPE') -and $AllowQuit) {
        $State.Done = $true
        $State.Action = 'Cancelled'
        return $State
    }

    if ($text -match '^\d+$') {
        $index = [int]$text
        if ($index -ge 1 -and $index -le $optionCount) {
            $State.SelectedIndex = $index - 1
            $selected = Get-ShareSurferConsoleChoiceSelectedOption -State $State
            $State.Done = $true
            $State.Action = 'Select'
            $State.SelectedValue = [string]$selected.Value
        }
        else {
            $State.Message = ('Choose a number from 1 to {0}.' -f $optionCount)
        }
        return $State
    }

    if ($AllowCustom) {
        $State.Done = $true
        $State.Action = 'Custom'
        $State.CustomValue = $text
        return $State
    }

    $State.Message = 'Command not recognized. Type ? for controls.'
    $State
}

function ConvertFrom-ShareSurferConsoleKeyInfo {
    param(
        [Parameter(Mandatory = $true)]
        $KeyInfo
    )

    try {
        $consoleKey = [System.ConsoleKey]$KeyInfo.VirtualKeyCode
        switch ($consoleKey) {
            'UpArrow' { return 'Up' }
            'DownArrow' { return 'Down' }
            'Enter' { return 'Enter' }
            'Backspace' { return 'Back' }
            'Escape' { return 'Quit' }
        }
    }
    catch {
    }

    $character = [char]0
    try {
        if ($null -ne $KeyInfo.Character) {
            $character = [char]$KeyInfo.Character
        }
    }
    catch {
    }

    if ($character -ne [char]0) {
        return [string]$character
    }

    # Modifier, function, and other zero-character keys carry no command.
    # Returning empty tells the read loop to ignore the keypress instead of
    # surfacing a confusing "Choose a number" message.
    ''
}

function Get-ShareSurferConsoleChoiceScreen {
    param(
        [Parameter(Mandatory = $true)]
        $State,

        [Parameter(Mandatory = $true)]
        [string] $Title,

        [string] $HelpText = ''
    )

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('')
    $lines.Add($Title)
    if (-not [string]::IsNullOrWhiteSpace($HelpText)) {
        $lines.Add($HelpText)
    }
    $lines.Add((Get-ShareSurferConsoleControlsLine))
    $lines.Add('')
    for ($index = 0; $index -lt @($State.Options).Count; $index++) {
        $option = @($State.Options)[$index]
        $marker = if ($index -eq [int]$State.SelectedIndex) { '>' } else { ' ' }
        $description = if ([string]::IsNullOrWhiteSpace([string]$option.Description)) { '' } else { ' - {0}' -f [string]$option.Description }
        $lines.Add((' {0} {1}. {2}{3}' -f $marker, ($index + 1), [string]$option.Label, $description))
    }
    if (-not [string]::IsNullOrWhiteSpace([string]$State.Message)) {
        $lines.Add('')
        $lines.Add([string]$State.Message)
    }

    @($lines.ToArray())
}

function Show-ShareSurferConsoleChoice {
    param(
        [Parameter(Mandatory = $true)]
        $State,

        [Parameter(Mandatory = $true)]
        [string] $Title,

        [string] $HelpText = ''
    )

    Write-ShareSurferConsoleLines -Lines (Get-ShareSurferConsoleChoiceScreen -State $State -Title $Title -HelpText $HelpText)
}

function Read-ShareSurferConsoleChoice {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Title,

        [Parameter(Mandatory = $true)]
        [object[]] $Options,

        [string] $DefaultValue = '',

        [string] $HelpText = '',

        [switch] $AllowSkip,

        [switch] $AllowBack,

        [switch] $AllowQuit,

        [switch] $AllowCustom,

        $Capabilities = $null
    )

    if ($null -eq $Capabilities) {
        $Capabilities = Get-ShareSurferConsoleCapabilities
    }

    $state = New-ShareSurferConsoleChoiceState -Options $Options -DefaultValue $DefaultValue
    $useRawKeys = [bool]$Capabilities.RawKeys
    $needsRender = $true
    while (-not $state.Done) {
        if ($needsRender) {
            Show-ShareSurferConsoleChoice -State $state -Title $Title -HelpText $HelpText
            $needsRender = $false
        }

        $fromRawKey = $false
        if ($useRawKeys) {
            try {
                $keyInfo = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
                $command = ConvertFrom-ShareSurferConsoleKeyInfo -KeyInfo $keyInfo
                $fromRawKey = $true
            }
            catch {
                $useRawKeys = $false
                $command = Read-Host -Prompt 'Selection'
            }
        }
        else {
            $command = Read-Host -Prompt 'Selection'
        }

        if ($fromRawKey -and [string]::IsNullOrEmpty($command)) {
            continue
        }

        Invoke-ShareSurferConsoleChoiceCommand -State $state -Command $command -AllowSkip:$AllowSkip -AllowBack:$AllowBack -AllowQuit:$AllowQuit -AllowCustom:$AllowCustom | Out-Null
        $needsRender = $true
        if ($state.Action -eq 'Help') {
            Write-ShareSurferConsoleLines -Lines @([string]$state.Message)
            $state.Message = ''
        }
    }

    $state
}

function New-ShareSurferConsoleTextState {
    param(
        [string] $Default = '',

        [string] $HelpText = ''
    )

    [pscustomobject]@{
        Default = $Default
        HelpText = $HelpText
        Done = $false
        Action = ''
        Value = ''
        Message = ''
    }
}

function Invoke-ShareSurferConsoleTextCommand {
    param(
        [Parameter(Mandatory = $true)]
        $State,

        [string] $Command = '',

        [switch] $AllowSkip,

        [switch] $AllowBack,

        [switch] $AllowQuit,

        [scriptblock] $Validate = $null
    )

    $State.Action = ''
    $State.Value = ''
    $State.Message = ''
    $text = ([string]$Command).Trim()
    $upper = $text.ToUpperInvariant()

    if ([string]::IsNullOrWhiteSpace($text)) {
        $State.Done = $true
        $State.Action = 'Accept'
        $State.Value = [string]$State.Default
        return $State
    }

    if ($upper -eq '?' -or $upper -eq 'HELP') {
        $State.Action = 'Help'
        $State.Message = if (-not [string]::IsNullOrWhiteSpace([string]$State.HelpText)) {
            [string]$State.HelpText
        }
        else {
            'Type a value and press Enter, or press Enter alone to accept the default. S skips when available. B goes back when available. Q cancels when available.'
        }
        return $State
    }

    if ($upper -in @('S', 'SKIP') -and $AllowSkip) {
        $State.Done = $true
        $State.Action = 'Skip'
        return $State
    }

    if ($upper -in @('B', 'BACK') -and $AllowBack) {
        $State.Done = $true
        $State.Action = 'Back'
        return $State
    }

    if ($upper -in @('Q', 'QUIT') -and $AllowQuit) {
        $State.Done = $true
        $State.Action = 'Cancelled'
        return $State
    }

    if ($null -ne $Validate) {
        $validationMessage = [string](& $Validate $text)
        if (-not [string]::IsNullOrWhiteSpace($validationMessage)) {
            $State.Message = $validationMessage
            return $State
        }
    }

    $State.Done = $true
    $State.Action = 'Accept'
    $State.Value = $text
    $State
}

function Read-ShareSurferConsoleText {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Prompt,

        [string] $Default = '',

        [string] $HelpText = '',

        [switch] $AllowSkip,

        [switch] $AllowBack,

        [switch] $AllowQuit,

        [scriptblock] $Validate = $null
    )

    $state = New-ShareSurferConsoleTextState -Default $Default -HelpText $HelpText
    $promptText = if ([string]::IsNullOrWhiteSpace($Default)) { $Prompt } else { '{0} [{1}]' -f $Prompt, $Default }
    while (-not $state.Done) {
        $answer = Read-Host -Prompt $promptText
        Invoke-ShareSurferConsoleTextCommand -State $state -Command $answer -AllowSkip:$AllowSkip -AllowBack:$AllowBack -AllowQuit:$AllowQuit -Validate $Validate | Out-Null
        if (-not [string]::IsNullOrWhiteSpace([string]$state.Message)) {
            Write-ShareSurferConsoleLines -Lines @([string]$state.Message)
            $state.Message = ''
        }
    }

    $state
}

function Read-ShareSurferConsoleBoolean {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Prompt,

        [bool] $Default = $false,

        [string] $HelpText = '',

        [switch] $AllowBack,

        [switch] $AllowQuit
    )

    $defaultText = if ($Default) { 'Y' } else { 'N' }
    $validate = {
        param($text)
        if (([string]$text).Trim().ToUpperInvariant() -in @('Y', 'YES', 'N', 'NO')) { '' } else { 'Answer Y or N.' }
    }
    $result = Read-ShareSurferConsoleText -Prompt ('{0} (Y/N)' -f $Prompt) -Default $defaultText -HelpText $HelpText -AllowBack:$AllowBack -AllowQuit:$AllowQuit -Validate $validate

    $value = $Default
    if ($result.Action -eq 'Accept') {
        $value = (([string]$result.Value).Trim().ToUpperInvariant() -in @('Y', 'YES'))
    }

    [pscustomobject]@{
        Action = [string]$result.Action
        Value = [bool]$value
    }
}

function New-ShareSurferConsoleMultiSelectState {
    param(
        [Parameter(Mandatory = $true)]
        [object[]] $Options,

        [string[]] $SelectedValues = @()
    )

    $normalizedOptions = @($Options | ForEach-Object {
        if ($null -ne $_.PSObject.Properties['Value']) {
            $_
        }
        else {
            New-ShareSurferConsoleChoiceOption -Value ([string]$_)
        }
    })

    $selected = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($value in @($SelectedValues)) {
        if (-not [string]::IsNullOrWhiteSpace([string]$value)) {
            [void]$selected.Add(([string]$value).Trim())
        }
    }

    [pscustomobject]@{
        Options = $normalizedOptions
        Selected = $selected
        Done = $false
        Action = ''
        Message = ''
    }
}

function Get-ShareSurferConsoleMultiSelectValues {
    param(
        [Parameter(Mandatory = $true)]
        $State
    )

    @(@($State.Options) | Where-Object { $State.Selected.Contains([string]$_.Value) } | ForEach-Object { [string]$_.Value })
}

function Invoke-ShareSurferConsoleMultiSelectCommand {
    param(
        [Parameter(Mandatory = $true)]
        $State,

        [string] $Command = '',

        [switch] $AllowQuit
    )

    $State.Action = ''
    $State.Message = ''
    $text = ([string]$Command).Trim()
    $upper = $text.ToUpperInvariant()
    $optionCount = @($State.Options).Count

    if ([string]::IsNullOrWhiteSpace($text) -or $upper -in @('D', 'DONE', 'ENTER')) {
        $State.Done = $true
        $State.Action = 'Done'
        return $State
    }

    if ($upper -eq '?' -or $upper -eq 'HELP') {
        $State.Action = 'Help'
        $State.Message = 'Type numbers to toggle (ranges like 2-4 and lists like 1,3 work). A selects all. C clears. Enter or D finishes. Q cancels when available.'
        return $State
    }

    if ($upper -eq 'A') {
        foreach ($option in @($State.Options)) {
            [void]$State.Selected.Add([string]$option.Value)
        }
        return $State
    }

    if ($upper -eq 'C') {
        $State.Selected.Clear()
        return $State
    }

    if ($upper -in @('Q', 'QUIT') -and $AllowQuit) {
        $State.Done = $true
        $State.Action = 'Cancelled'
        return $State
    }

    if ($text -match '^[\d,\s-]+$') {
        $indexes = @(ConvertFrom-ShareSurferInteractiveSelection -Selection $text -Maximum $optionCount)
        if ($indexes.Count -eq 0) {
            $State.Message = ('Choose numbers from 1 to {0}.' -f $optionCount)
            return $State
        }
        foreach ($index in $indexes) {
            $value = [string](@($State.Options)[$index - 1].Value)
            if ($State.Selected.Contains($value)) {
                [void]$State.Selected.Remove($value)
            }
            else {
                [void]$State.Selected.Add($value)
            }
        }
        return $State
    }

    $State.Message = 'Command not recognized. Type ? for controls.'
    $State
}

function Get-ShareSurferConsoleMultiSelectScreen {
    param(
        [Parameter(Mandatory = $true)]
        $State,

        [Parameter(Mandatory = $true)]
        [string] $Title,

        [string] $HelpText = ''
    )

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('')
    $lines.Add($Title)
    if (-not [string]::IsNullOrWhiteSpace($HelpText)) {
        $lines.Add($HelpText)
    }
    $lines.Add('Controls: numbers/ranges=toggle | A=all | C=clear | Enter/D=done | ?=help | Q=quit')
    $lines.Add('')
    for ($index = 0; $index -lt @($State.Options).Count; $index++) {
        $option = @($State.Options)[$index]
        $marker = if ($State.Selected.Contains([string]$option.Value)) { '[x]' } else { '[ ]' }
        $description = if ([string]::IsNullOrWhiteSpace([string]$option.Description)) { '' } else { ' - {0}' -f [string]$option.Description }
        $lines.Add((' {0} {1}. {2}{3}' -f $marker, ($index + 1), [string]$option.Label, $description))
    }
    $lines.Add('')
    $lines.Add(('Selected: {0}' -f @(Get-ShareSurferConsoleMultiSelectValues -State $State).Count))
    if (-not [string]::IsNullOrWhiteSpace([string]$State.Message)) {
        $lines.Add('')
        $lines.Add([string]$State.Message)
    }

    @($lines.ToArray())
}

function Read-ShareSurferConsoleMultiSelect {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Title,

        [Parameter(Mandatory = $true)]
        [object[]] $Options,

        [string[]] $SelectedValues = @(),

        [string] $HelpText = '',

        [switch] $AllowQuit
    )

    $state = New-ShareSurferConsoleMultiSelectState -Options $Options -SelectedValues $SelectedValues
    while (-not $state.Done) {
        Write-ShareSurferConsoleLines -Lines (Get-ShareSurferConsoleMultiSelectScreen -State $state -Title $Title -HelpText $HelpText)
        $answer = Read-Host -Prompt 'Selection'
        Invoke-ShareSurferConsoleMultiSelectCommand -State $state -Command $answer -AllowQuit:$AllowQuit | Out-Null
        if ($state.Action -eq 'Help') {
            Write-ShareSurferConsoleLines -Lines @([string]$state.Message)
            $state.Message = ''
        }
    }

    $state
}

# --- Compatibility shims -----------------------------------------------------
# The prompt-choice machine shipped in #364 under *-ShareSurferPromptChoice*
# names inside Join-ShareSurferOwnershipSources.ps1. These shims keep those
# names working while callers and tests migrate to the console layer names.
# Note: Q now reports Action 'Cancelled' (previously 'Quit') per the
# cancellation contract in the staged TUI spec.

function New-ShareSurferPromptChoiceOption {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Value,

        [string] $Label = '',

        [string] $Description = ''
    )

    New-ShareSurferConsoleChoiceOption -Value $Value -Label $Label -Description $Description
}

function New-ShareSurferPromptChoiceState {
    param(
        [Parameter(Mandatory = $true)]
        [object[]] $Options,

        [string] $DefaultValue = ''
    )

    New-ShareSurferConsoleChoiceState -Options $Options -DefaultValue $DefaultValue
}

function Get-ShareSurferPromptChoiceSelectedOption {
    param(
        [Parameter(Mandatory = $true)]
        $State
    )

    Get-ShareSurferConsoleChoiceSelectedOption -State $State
}

function Invoke-ShareSurferPromptChoiceCommand {
    param(
        [Parameter(Mandatory = $true)]
        $State,

        [string] $Command = '',

        [switch] $AllowSkip,

        [switch] $AllowBack,

        [switch] $AllowQuit,

        [switch] $AllowCustom
    )

    Invoke-ShareSurferConsoleChoiceCommand -State $State -Command $Command -AllowSkip:$AllowSkip -AllowBack:$AllowBack -AllowQuit:$AllowQuit -AllowCustom:$AllowCustom
}

function ConvertFrom-ShareSurferPromptKeyInfo {
    param(
        [Parameter(Mandatory = $true)]
        $KeyInfo
    )

    ConvertFrom-ShareSurferConsoleKeyInfo -KeyInfo $KeyInfo
}

function Test-ShareSurferPromptRawKeyAvailable {
    Test-ShareSurferConsoleRawKeyAvailable
}

function Show-ShareSurferPromptChoice {
    param(
        [Parameter(Mandatory = $true)]
        $State,

        [Parameter(Mandatory = $true)]
        [string] $Title,

        [string] $HelpText = '',

        [switch] $AllowSkip,

        [switch] $AllowBack,

        [switch] $AllowQuit
    )

    Show-ShareSurferConsoleChoice -State $State -Title $Title -HelpText $HelpText
}

function Read-ShareSurferPromptChoice {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Title,

        [Parameter(Mandatory = $true)]
        [object[]] $Options,

        [string] $DefaultValue = '',

        [string] $HelpText = '',

        [switch] $AllowSkip,

        [switch] $AllowBack,

        [switch] $AllowQuit,

        [switch] $AllowCustom
    )

    Read-ShareSurferConsoleChoice -Title $Title -Options $Options -DefaultValue $DefaultValue -HelpText $HelpText -AllowSkip:$AllowSkip -AllowBack:$AllowBack -AllowQuit:$AllowQuit -AllowCustom:$AllowCustom
}
