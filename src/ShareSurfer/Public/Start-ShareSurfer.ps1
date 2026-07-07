function Get-ShareSurferMenuPathState {
    param(
        [string] $FolderPath = '',

        [string] $FileName = ''
    )

    if ([string]::IsNullOrWhiteSpace($FolderPath)) {
        return 'folder not set'
    }
    if ([string]::IsNullOrWhiteSpace($FileName)) {
        try {
            if (Test-Path -LiteralPath $FolderPath -PathType Container) { return 'found' }
        }
        catch {
        }
        return 'missing'
    }

    $candidate = Join-ShareSurferAssistantPathText -Root $FolderPath -Child $FileName
    try {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) { return 'found' }
    }
    catch {
    }
    'missing'
}

function Format-ShareSurferMenuLiteral {
    param(
        [string] $Value = '',

        [string] $Placeholder = ''
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $Placeholder
    }

    ConvertTo-ShareSurferPowerShellLiteral -Value $Value
}

function Join-ShareSurferMenuCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string] $CommandName,

        [hashtable] $Parameters = @{}
    )

    $parts = New-Object System.Collections.Generic.List[string]
    $parts.Add($CommandName)
    foreach ($name in @($Parameters.Keys | Sort-Object)) {
        $value = [string]$Parameters[$name]
        if (-not [string]::IsNullOrWhiteSpace($value)) {
            $parts.Add(('-{0} {1}' -f $name, $value))
        }
    }

    ($parts.ToArray() -join ' ')
}

function Get-ShareSurferMenuEntries {
    param(
        [string] $InputRoot = '',

        [string] $ExportPath = '',

        [string] $StandaloneDashboardPath = '',

        [string] $ReleaseRoot = '',

        [string] $ObsAttribute = 'extensionAttribute10',

        [ValidateSet('Auto', 'ActiveDirectory', 'Ldap', 'DirectoryOnly')]
        [string] $AdLookupMode = 'Auto',

        [ValidateSet('MailTo', 'Mail', 'UserPrincipalName', 'SamAccountName', 'DistinguishedName')]
        [string] $ManagerIdentityFormat = 'MailTo',

        [ValidateSet('Auto', 'Enhanced', 'Plain')]
        [string] $ConsoleMode = 'Auto'
    )

    $entries = New-Object System.Collections.Generic.List[object]

    $preflightState = Get-ShareSurferMenuPathState -FolderPath $ExportPath -FileName 'port_protocol_checks.csv'
    $preflightReadiness = switch ($preflightState) {
        'found' { 'port/protocol evidence: found'; break }
        'missing' { 'port/protocol evidence: none yet'; break }
        default { 'export folder not set' }
    }
    [void]$entries.Add([pscustomobject]@{
        Key = 'preflight'
        Label = 'Preflight & connectivity'
        Readiness = $preflightReadiness
        CommandPreview = ('Invoke-ShareSurferPortProtocolAssessment -TargetPath <your scan targets> -OutputPath {0} -Force' -f (Format-ShareSurferMenuLiteral -Value $ExportPath -Placeholder '<export folder>'))
        Runnable = $false
        Guidance = 'Preflight needs your scan target paths. Copy the preview command and supply -TargetPath, or record targets by running scan setup first.'
    })

    $mappingState = Get-ShareSurferMenuPathState -FolderPath $InputRoot -FileName 'owner-mapping.csv'
    $enrichmentState = Get-ShareSurferMenuPathState -FolderPath $InputRoot -FileName 'ownership-enrichment.csv'
    [void]$entries.Add([pscustomobject]@{
        Key = 'ownership'
        Label = 'Ownership inputs'
        Readiness = ('owner mapping: {0} - enrichment: {1}' -f $mappingState, $enrichmentState)
        CommandPreview = (Join-ShareSurferMenuCommand -CommandName 'Invoke-ShareSurferStartupOwnershipSetup' -Parameters @{
            InputRoot = (Format-ShareSurferMenuLiteral -Value $InputRoot -Placeholder '<input folder>')
            ObsAttribute = (Format-ShareSurferMenuLiteral -Value $ObsAttribute -Placeholder '<OBS attribute>')
            AdLookupMode = (Format-ShareSurferMenuLiteral -Value $AdLookupMode -Placeholder '<AD lookup mode>')
        })
        Runnable = (-not [string]::IsNullOrWhiteSpace($InputRoot))
        Guidance = 'Set -InputRoot when starting the menu to run guided ownership setup from here.'
    })

    $configState = Get-ShareSurferMenuPathState -FolderPath $InputRoot -FileName 'sharesurfer-startup.config.json'
    $scanReadiness = if ($configState -eq 'found') {
        'saved setup: sharesurfer-startup.config.json'
    }
    elseif ($configState -eq 'missing') {
        'setup not recorded yet'
    }
    else {
        'input folder not set'
    }
    $scanPreview = if ($configState -eq 'found') {
        'Start-ShareSurferStartup -ConfigPath {0} -Force' -f (ConvertTo-ShareSurferPowerShellLiteral -Value (Join-ShareSurferAssistantPathText -Root $InputRoot -Child 'sharesurfer-startup.config.json'))
    }
    else {
        $scanPreviewParts = New-Object System.Collections.Generic.List[string]
        $scanPreviewParts.Add('Start-ShareSurferStartup')
        $scanPreviewParts.Add('-Interactive')
        foreach ($parameter in @(
            [pscustomobject]@{ Name = 'InputRoot'; Value = (Format-ShareSurferMenuLiteral -Value $InputRoot) },
            [pscustomobject]@{ Name = 'ExportPath'; Value = (Format-ShareSurferMenuLiteral -Value $ExportPath) },
            [pscustomobject]@{ Name = 'StandaloneDashboardPath'; Value = (Format-ShareSurferMenuLiteral -Value $StandaloneDashboardPath) },
            [pscustomobject]@{ Name = 'ReleaseRoot'; Value = (Format-ShareSurferMenuLiteral -Value $ReleaseRoot) },
            [pscustomobject]@{ Name = 'ObsAttribute'; Value = (Format-ShareSurferMenuLiteral -Value $ObsAttribute) },
            [pscustomobject]@{ Name = 'AdLookupMode'; Value = (Format-ShareSurferMenuLiteral -Value $AdLookupMode) },
            [pscustomobject]@{ Name = 'ManagerIdentityFormat'; Value = (Format-ShareSurferMenuLiteral -Value $ManagerIdentityFormat) },
            [pscustomobject]@{ Name = 'ConsoleMode'; Value = (Format-ShareSurferMenuLiteral -Value $ConsoleMode) }
        )) {
            if (-not [string]::IsNullOrWhiteSpace([string]$parameter.Value)) {
                $scanPreviewParts.Add(('-{0} {1}' -f [string]$parameter.Name, [string]$parameter.Value))
            }
        }
        $scanPreviewParts.ToArray() -join ' '
    }
    [void]$entries.Add([pscustomobject]@{
        Key = 'scan'
        Label = 'Scan (guided startup)'
        Readiness = $scanReadiness
        CommandPreview = $scanPreview
        Runnable = $true
        Guidance = ''
    })

    $exportState = Get-ShareSurferMenuPathState -FolderPath $ExportPath -FileName 'shares.csv'
    [void]$entries.Add([pscustomobject]@{
        Key = 'validate'
        Label = 'Validate export'
        Readiness = ('export: {0}' -f $exportState)
        CommandPreview = ('Test-ShareSurferExport -ExportPath {0}' -f (Format-ShareSurferMenuLiteral -Value $ExportPath -Placeholder '<export folder>'))
        Runnable = ($exportState -eq 'found')
        Guidance = 'Run a scan first; validation needs shares.csv in the export folder.'
    })

    $dashboardScriptPath = ''
    if (-not [string]::IsNullOrWhiteSpace($ReleaseRoot)) {
        $dashboardScriptPath = Join-ShareSurferAssistantPathText -Root $ReleaseRoot -Child 'scripts/New-ShareSurferStandaloneDashboard.ps1'
    }
    $dashboardState = Get-ShareSurferMenuPathState -FolderPath $StandaloneDashboardPath
    $dashboardScriptExists = $false
    if (-not [string]::IsNullOrWhiteSpace($dashboardScriptPath)) {
        try {
            $dashboardScriptExists = Test-Path -LiteralPath $dashboardScriptPath -PathType Leaf
        }
        catch {
            $dashboardScriptExists = $false
        }
    }
    [void]$entries.Add([pscustomobject]@{
        Key = 'dashboard'
        Label = 'Package standalone dashboard'
        Readiness = ('dashboard folder: {0}' -f $dashboardState)
        CommandPreview = ('& {0} -ExportPath {1} -OutputPath {2} -Force' -f (Format-ShareSurferMenuLiteral -Value $dashboardScriptPath -Placeholder '<release root>\scripts\New-ShareSurferStandaloneDashboard.ps1'), (Format-ShareSurferMenuLiteral -Value $ExportPath -Placeholder '<export folder>'), (Format-ShareSurferMenuLiteral -Value $StandaloneDashboardPath -Placeholder '<dashboard folder>'))
        Runnable = ($exportState -eq 'found' -and -not [string]::IsNullOrWhiteSpace($dashboardScriptPath) -and $dashboardScriptExists -and -not [string]::IsNullOrWhiteSpace($StandaloneDashboardPath))
        Guidance = 'Packaging needs a validated export, -ReleaseRoot (for the packaging script), and -StandaloneDashboardPath.'
    })

    $confidenceState = Get-ShareSurferMenuPathState -FolderPath $ExportPath -FileName 'evidence_confidence.csv'
    $errorState = Get-ShareSurferMenuPathState -FolderPath $ExportPath -FileName 'collection_errors.csv'
    [void]$entries.Add([pscustomobject]@{
        Key = 'stopgates'
        Label = 'Review stop gates & handoff'
        Readiness = ('evidence confidence: {0} - collection errors: {1}' -f $confidenceState, $errorState)
        CommandPreview = ('Review evidence_confidence.csv, collection_errors.csv, and scan_manifest.csv in {0} before owner signoff.' -f $(if ([string]::IsNullOrWhiteSpace($ExportPath)) { '<export folder>' } else { $ExportPath }))
        Runnable = $false
        Guidance = 'Stop gates are a human review step; open the listed CSVs and resolve unexplained gaps before handing evidence to owners.'
    })

    [void]$entries.Add([pscustomobject]@{
        Key = 'support'
        Label = 'Support bundle'
        Readiness = ''
        CommandPreview = ('New-ShareSurferSupportBundle -ExportPath {0} -OutputPath {1}' -f (Format-ShareSurferMenuLiteral -Value $ExportPath -Placeholder '<export folder>'), $(if ([string]::IsNullOrWhiteSpace($ExportPath)) { '<export folder>\support-bundle' } else { ConvertTo-ShareSurferPowerShellLiteral -Value (Join-ShareSurferAssistantPathText -Root $ExportPath -Child 'support-bundle') }))
        Runnable = $false
        Guidance = 'Copy the preview command when you need a redacted bundle for a bug report; it can take a while on large exports.'
    })

    @($entries.ToArray())
}

function Get-ShareSurferMenuScreen {
    param(
        [Parameter(Mandatory = $true)]
        [object[]] $Entries,

        [string] $InputRoot = '',

        [string] $ExportPath = ''
    )

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('')
    $lines.Add('ShareSurfer Start Menu')
    $lines.Add(('Inputs: {0}' -f $(if ([string]::IsNullOrWhiteSpace($InputRoot)) { '(not set - pass -InputRoot for readiness checks)' } else { $InputRoot })))
    $lines.Add(('Export: {0}' -f $(if ([string]::IsNullOrWhiteSpace($ExportPath)) { '(not set - pass -ExportPath for readiness checks)' } else { $ExportPath })))
    $lines.Add('')
    for ($index = 0; $index -lt @($Entries).Count; $index++) {
        $entry = @($Entries)[$index]
        $readiness = if ([string]::IsNullOrWhiteSpace([string]$entry.Readiness)) { '' } else { '  ({0})' -f [string]$entry.Readiness }
        $lines.Add(('  {0}. {1}{2}' -f ($index + 1), [string]$entry.Label, $readiness))
    }
    $lines.Add('')
    $lines.Add('Every choice previews its exact command before anything runs. Nothing here changes share or file permissions.')

    @($lines.ToArray())
}

function Start-ShareSurfer {
    [CmdletBinding()]
    param(
        [string] $InputRoot = '',

        [string] $ExportPath = '',

        [string] $StandaloneDashboardPath = '',

        [string] $ReleaseRoot = '',

        [string] $ObsAttribute = 'extensionAttribute10',

        [ValidateSet('Auto', 'ActiveDirectory', 'Ldap', 'DirectoryOnly')]
        [string] $AdLookupMode = 'Auto',

        [ValidateSet('MailTo', 'Mail', 'UserPrincipalName', 'SamAccountName', 'DistinguishedName')]
        [string] $ManagerIdentityFormat = 'MailTo',

        [ValidateSet('Auto', 'Enhanced', 'Plain')]
        [string] $ConsoleMode = 'Auto'
    )

    while ($true) {
        $entries = Get-ShareSurferMenuEntries -InputRoot $InputRoot -ExportPath $ExportPath -StandaloneDashboardPath $StandaloneDashboardPath -ReleaseRoot $ReleaseRoot -ObsAttribute $ObsAttribute -AdLookupMode $AdLookupMode -ManagerIdentityFormat $ManagerIdentityFormat -ConsoleMode $ConsoleMode
        Write-ShareSurferConsoleLines -Lines (Get-ShareSurferMenuScreen -Entries $entries -InputRoot $InputRoot -ExportPath $ExportPath)

        $options = @($entries | ForEach-Object { New-ShareSurferConsoleChoiceOption -Value ([string]$_.Key) -Label ([string]$_.Label) })
        $selection = Read-ShareSurferConsoleChoice -Title 'Choose a task' -Options $options -HelpText 'Enter or a number picks a task; the exact command is shown before anything runs. Q leaves the menu.' -AllowQuit -ConsoleMode $ConsoleMode
        if ($selection.Action -eq 'Cancelled') {
            Write-ShareSurferConsoleLines -Lines @('Leaving the ShareSurfer start menu. Saved configs, plans, and rerun scripts keep your progress.')
            return
        }
        if ($selection.Action -ne 'Select') {
            continue
        }

        $entry = @($entries | Where-Object { [string]$_.Key -eq [string]$selection.SelectedValue })[0]
        Write-ShareSurferConsoleLines -Lines @('', 'Command preview', ('  {0}' -f [string]$entry.CommandPreview))

        if (-not [bool]$entry.Runnable) {
            Write-ShareSurferConsoleLines -Lines @([string]$entry.Guidance)
            Wait-ShareSurferConsolePause -Prompt 'Press Enter to return to the menu.'
            continue
        }

        $confirm = Read-ShareSurferConsoleBoolean -Prompt 'Run this now?' -Default $false -ConsoleMode $ConsoleMode
        if (-not [bool]$confirm.Value) {
            Wait-ShareSurferConsolePause -Prompt 'Run declined. Press Enter to return to the menu.'
            continue
        }

        switch ([string]$entry.Key) {
            'ownership' {
                Invoke-ShareSurferStartupOwnershipSetup -InputRoot $InputRoot -ObsAttribute $ObsAttribute -AdLookupMode $AdLookupMode -ConsoleMode $ConsoleMode | Out-Null
                break
            }
            'scan' {
                $configPath = if ([string]::IsNullOrWhiteSpace($InputRoot)) { '' } else { Join-Path $InputRoot 'sharesurfer-startup.config.json' }
                if (-not [string]::IsNullOrWhiteSpace($configPath) -and (Test-Path -LiteralPath $configPath -PathType Leaf)) {
                    Start-ShareSurferStartup -ConfigPath $configPath -Force -ConsoleMode $ConsoleMode | Out-Host
                }
                else {
                    $startupParameters = @{ Interactive = $true }
                    if (-not [string]::IsNullOrWhiteSpace($InputRoot)) { $startupParameters.InputRoot = $InputRoot }
                    if (-not [string]::IsNullOrWhiteSpace($ExportPath)) { $startupParameters.ExportPath = $ExportPath }
                    if (-not [string]::IsNullOrWhiteSpace($StandaloneDashboardPath)) { $startupParameters.StandaloneDashboardPath = $StandaloneDashboardPath }
                    if (-not [string]::IsNullOrWhiteSpace($ReleaseRoot)) { $startupParameters.ReleaseRoot = $ReleaseRoot }
                    if (-not [string]::IsNullOrWhiteSpace($ObsAttribute)) { $startupParameters.ObsAttribute = $ObsAttribute }
                    if (-not [string]::IsNullOrWhiteSpace($AdLookupMode)) { $startupParameters.AdLookupMode = $AdLookupMode }
                    if (-not [string]::IsNullOrWhiteSpace($ManagerIdentityFormat)) { $startupParameters.ManagerIdentityFormat = $ManagerIdentityFormat }
                    if (-not [string]::IsNullOrWhiteSpace($ConsoleMode)) { $startupParameters.ConsoleMode = $ConsoleMode }
                    Start-ShareSurferStartup @startupParameters | Out-Host
                }
                Write-Host ''
                Write-Host 'Guided startup is complete. ShareSurfer saved the startup config, operator plan, and rerun script shown above.'
                Write-Host 'Run the generated rerun script when ready, or run Start-ShareSurfer.ps1 again to reopen the menu.'
                return
            }
            'validate' {
                Test-ShareSurferExport -ExportPath $ExportPath | Out-Host
                break
            }
            'dashboard' {
                $dashboardScriptPath = Join-ShareSurferAssistantPathText -Root $ReleaseRoot -Child 'scripts/New-ShareSurferStandaloneDashboard.ps1'
                & $dashboardScriptPath -ExportPath $ExportPath -OutputPath $StandaloneDashboardPath -Force | Out-Host
                break
            }
            default {
                Write-ShareSurferConsoleLines -Lines @('This task is preview-only from the menu; copy the command above to run it.')
                Wait-ShareSurferConsolePause -Prompt 'Press Enter to return to the menu.'
            }
        }
    }
}
