function Get-ShareSurferMenuPathState {
    param(
        [string] $FolderPath = '',

        [string] $FileName = ''
    )

    if ([string]::IsNullOrWhiteSpace($FolderPath)) {
        return 'not set'
    }
    if ([string]::IsNullOrWhiteSpace($FileName)) {
        try {
            if (Test-Path -LiteralPath $FolderPath -PathType Container) { return 'found' }
        }
        catch {
        }
        return 'not found'
    }

    $candidate = Join-ShareSurferAssistantPathText -Root $FolderPath -Child $FileName
    try {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) { return 'found' }
    }
    catch {
    }
    'not found'
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

function Get-ShareSurferMenuStartupConfigPath {
    param([string] $InputRoot = '')

    if ([string]::IsNullOrWhiteSpace($InputRoot)) {
        return ''
    }

    Join-ShareSurferAssistantPathText -Root $InputRoot -Child 'sharesurfer-startup.config.json'
}

function Get-ShareSurferMenuSavedWorkflowState {
    param([string] $InputRoot = '')

    $configPath = Get-ShareSurferMenuStartupConfigPath -InputRoot $InputRoot
    $fallbackRerunPath = if ([string]::IsNullOrWhiteSpace($InputRoot)) { '' } else { Join-ShareSurferAssistantPathText -Root $InputRoot -Child 'operator-assistant-rerun.ps1' }
    if ([string]::IsNullOrWhiteSpace($configPath) -or -not (Test-Path -LiteralPath $configPath -PathType Leaf)) {
        return [pscustomobject]@{
            State = 'Missing'
            Ready = $false
            Reason = 'Finish first-scan setup to create a saved workflow.'
            ConfigPath = $configPath
            RerunPath = $fallbackRerunPath
            TargetPath = @()
            ExportPath = ''
            StandaloneDashboardPath = ''
            ObsAttribute = ''
            AdLookupMode = ''
            ManagerIdentityFormat = ''
            AclExportMode = ''
            ConsoleMode = ''
        }
    }

    try {
        $definition = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
        $rerunPath = $fallbackRerunPath
        if ($null -ne $definition.PSObject.Properties['generatedFiles'] -and
            $null -ne $definition.generatedFiles.PSObject.Properties['operatorReusableCommandPath'] -and
            -not [string]::IsNullOrWhiteSpace([string]$definition.generatedFiles.operatorReusableCommandPath)) {
            $rerunPath = [string]$definition.generatedFiles.operatorReusableCommandPath
        }
        elseif ($null -ne $definition.PSObject.Properties['commands'] -and
            $null -ne $definition.commands.PSObject.Properties['operatorRerun'] -and
            -not [string]::IsNullOrWhiteSpace([string]$definition.commands.operatorRerun)) {
            $rerunPath = [string]$definition.commands.operatorRerun
        }

        $targets = @()
        if ($null -ne $definition.PSObject.Properties['targetPaths']) {
            $targets = @($definition.targetPaths | ForEach-Object { [string]$_ } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        }
        $savedExportPath = if ($null -ne $definition.PSObject.Properties['exportPath']) { [string]$definition.exportPath } else { '' }
        $savedDashboardPath = if ($null -ne $definition.PSObject.Properties['standaloneDashboardPath']) { [string]$definition.standaloneDashboardPath } else { '' }
        $savedObsAttribute = if ($null -ne $definition.PSObject.Properties['obsAttribute']) { [string]$definition.obsAttribute } else { '' }
        $savedAdLookupMode = if ($null -ne $definition.PSObject.Properties['adLookupMode']) { [string]$definition.adLookupMode } else { '' }
        $savedManagerIdentityFormat = if ($null -ne $definition.PSObject.Properties['managerIdentityFormat']) { [string]$definition.managerIdentityFormat } else { '' }
        $savedAclExportMode = if ($null -ne $definition.PSObject.Properties['aclExportMode']) { [string]$definition.aclExportMode } else { '' }
        $savedConsoleMode = if ($null -ne $definition.PSObject.Properties['consoleMode']) { [string]$definition.consoleMode } else { '' }

        if ([string]::IsNullOrWhiteSpace($rerunPath) -or -not (Test-Path -LiteralPath $rerunPath -PathType Leaf)) {
            return [pscustomobject]@{
                State = 'Incomplete'
                Ready = $false
                Reason = 'The saved setup exists, but its rerun script is missing. Start a first scan to repair it.'
                ConfigPath = $configPath
                RerunPath = $rerunPath
                TargetPath = @($targets)
                ExportPath = $savedExportPath
                StandaloneDashboardPath = $savedDashboardPath
                ObsAttribute = $savedObsAttribute
                AdLookupMode = $savedAdLookupMode
                ManagerIdentityFormat = $savedManagerIdentityFormat
                AclExportMode = $savedAclExportMode
                ConsoleMode = $savedConsoleMode
            }
        }

        return [pscustomobject]@{
            State = 'Ready'
            Ready = $true
            Reason = ''
            ConfigPath = $configPath
            RerunPath = $rerunPath
            TargetPath = @($targets)
            ExportPath = $savedExportPath
            StandaloneDashboardPath = $savedDashboardPath
            ObsAttribute = $savedObsAttribute
            AdLookupMode = $savedAdLookupMode
            ManagerIdentityFormat = $savedManagerIdentityFormat
            AclExportMode = $savedAclExportMode
            ConsoleMode = $savedConsoleMode
        }
    }
    catch {
        [pscustomobject]@{
            State = 'Invalid'
            Ready = $false
            Reason = 'The saved setup could not be read. Start a first scan to replace the invalid config.'
            ConfigPath = $configPath
            RerunPath = $fallbackRerunPath
            TargetPath = @()
            ExportPath = ''
            StandaloneDashboardPath = ''
            ObsAttribute = ''
            AdLookupMode = ''
            ManagerIdentityFormat = ''
            AclExportMode = ''
            ConsoleMode = ''
        }
    }
}

function Get-ShareSurferMenuInitialPaths {
    param(
        [string] $InputRoot = '',

        [string] $ExportPath = '',

        [string] $StandaloneDashboardPath = ''
    )

    $saved = Get-ShareSurferMenuSavedWorkflowState -InputRoot $InputRoot
    $defaultExportPath = if ([string]::IsNullOrWhiteSpace($InputRoot)) { '' } else { Join-ShareSurferAssistantPathText -Root (Join-ShareSurferAssistantPathText -Root (Split-Path -Parent $InputRoot) -Child 'exports') -Child 'startup-scan' }
    $defaultDashboardPath = if ([string]::IsNullOrWhiteSpace($ExportPath)) { '' } else { Join-ShareSurferAssistantPathText -Root $ExportPath -Child 'standalone-dashboard' }
    $exportUsesDefault = [string]::IsNullOrWhiteSpace($ExportPath)
    if (-not $exportUsesDefault -and -not [string]::IsNullOrWhiteSpace($defaultExportPath)) {
        $exportUsesDefault = [string]::Equals(
            (ConvertTo-ShareSurferAssistantComparablePath -Path $ExportPath),
            (ConvertTo-ShareSurferAssistantComparablePath -Path $defaultExportPath),
            [System.StringComparison]::OrdinalIgnoreCase)
    }
    $dashboardUsesDefault = [string]::IsNullOrWhiteSpace($StandaloneDashboardPath)
    if (-not $dashboardUsesDefault -and -not [string]::IsNullOrWhiteSpace($defaultDashboardPath)) {
        $dashboardUsesDefault = [string]::Equals(
            (ConvertTo-ShareSurferAssistantComparablePath -Path $StandaloneDashboardPath),
            (ConvertTo-ShareSurferAssistantComparablePath -Path $defaultDashboardPath),
            [System.StringComparison]::OrdinalIgnoreCase)
    }

    $resolvedExportPath = $ExportPath
    $resolvedDashboardPath = $StandaloneDashboardPath
    if ($exportUsesDefault -and -not [string]::IsNullOrWhiteSpace([string]$saved.ExportPath)) {
        $resolvedExportPath = [string]$saved.ExportPath
        if ($dashboardUsesDefault) {
            $resolvedDashboardPath = if (-not [string]::IsNullOrWhiteSpace([string]$saved.StandaloneDashboardPath)) {
                [string]$saved.StandaloneDashboardPath
            }
            else {
                Join-ShareSurferAssistantPathText -Root $resolvedExportPath -Child 'standalone-dashboard'
            }
        }
    }

    [pscustomobject]@{
        ExportPath = $resolvedExportPath
        StandaloneDashboardPath = $resolvedDashboardPath
        HydratedFromSavedConfig = ($resolvedExportPath -ne $ExportPath -or $resolvedDashboardPath -ne $StandaloneDashboardPath)
    }
}

function Get-ShareSurferMenuInitialSettings {
    param(
        [string] $InputRoot = '',
        [string] $ObsAttribute = 'extensionAttribute10',
        [string] $AdLookupMode = 'Auto',
        [string] $ManagerIdentityFormat = 'MailTo',
        [string] $AclExportMode = 'Compact',
        [string] $ConsoleMode = 'Plain',
        [switch] $PreserveObsAttribute,
        [switch] $PreserveAdLookupMode,
        [switch] $PreserveManagerIdentityFormat,
        [switch] $PreserveAclExportMode,
        [switch] $PreserveConsoleMode
    )

    $saved = Get-ShareSurferMenuSavedWorkflowState -InputRoot $InputRoot
    [pscustomobject]@{
        ObsAttribute = $(if (-not $PreserveObsAttribute -and -not [string]::IsNullOrWhiteSpace([string]$saved.ObsAttribute)) { [string]$saved.ObsAttribute } else { $ObsAttribute })
        AdLookupMode = $(if (-not $PreserveAdLookupMode -and [string]$saved.AdLookupMode -in @('Auto', 'ActiveDirectory', 'Ldap', 'DirectoryOnly')) { [string]$saved.AdLookupMode } else { $AdLookupMode })
        ManagerIdentityFormat = $(if (-not $PreserveManagerIdentityFormat -and [string]$saved.ManagerIdentityFormat -in @('MailTo', 'Mail', 'UserPrincipalName', 'SamAccountName', 'DistinguishedName')) { [string]$saved.ManagerIdentityFormat } else { $ManagerIdentityFormat })
        AclExportMode = $(if (-not $PreserveAclExportMode -and [string]$saved.AclExportMode -in @('FullEffective', 'Compact')) { [string]$saved.AclExportMode } else { $AclExportMode })
        ConsoleMode = $(if (-not $PreserveConsoleMode -and [string]$saved.ConsoleMode -in @('Auto', 'Enhanced', 'Plain')) { [string]$saved.ConsoleMode } else { $ConsoleMode })
    }
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

        [ValidateSet('FullEffective', 'Compact')]
        [string] $AclExportMode = 'Compact',

        [ValidateSet('Auto', 'Enhanced', 'Plain')]
        [string] $ConsoleMode = 'Plain',

        [bool] $SessionValidationPassed = $false
    )

    $saved = Get-ShareSurferMenuSavedWorkflowState -InputRoot $InputRoot
    $exportFound = (Get-ShareSurferMenuPathState -FolderPath $ExportPath -FileName 'shares.csv') -eq 'found'
    $resultsDescription = if ($exportFound) {
        if ($SessionValidationPassed) { 'A validated export is ready for review.' } else { 'An export was found; ShareSurfer will validate it before review.' }
    }
    else {
        'Open and validate results after a scan completes.'
    }

    @(
        [pscustomobject]@{
            Key = 'first_scan'
            Label = 'Start a first scan (recommended)'
            Description = 'Choose one share or folder, review safe defaults, then run now or save the plan.'
            Available = $true
            UnavailableReason = ''
            Recommended = $true
        },
        [pscustomobject]@{
            Key = 'saved_scan'
            Label = 'Run a saved scan'
            Description = 'Run the reviewed diagnostic, scan, validation, and dashboard workflow again.'
            Available = [bool]$saved.Ready
            UnavailableReason = [string]$saved.Reason
            Recommended = $false
            ConfigPath = [string]$saved.ConfigPath
            RerunPath = [string]$saved.RerunPath
            TargetPath = @($saved.TargetPath)
            ExportPath = [string]$saved.ExportPath
            StandaloneDashboardPath = [string]$saved.StandaloneDashboardPath
            ObsAttribute = [string]$saved.ObsAttribute
            AdLookupMode = [string]$saved.AdLookupMode
            ManagerIdentityFormat = [string]$saved.ManagerIdentityFormat
            AclExportMode = [string]$saved.AclExportMode
            ConsoleMode = [string]$saved.ConsoleMode
        },
        [pscustomobject]@{
            Key = 'review_results'
            Label = 'Review existing results'
            Description = $resultsDescription
            Available = [bool]$exportFound
            ValidationPassed = ([bool]$exportFound -and [bool]$SessionValidationPassed)
            UnavailableReason = 'No scan export was found yet.'
            Recommended = $false
        },
        [pscustomobject]@{
            Key = 'ownership'
            Label = 'Add ownership or HR data'
            Description = 'Optionally enrich identities and prepare owner mapping after the basic scan path works.'
            Available = (-not [string]::IsNullOrWhiteSpace($InputRoot))
            UnavailableReason = 'Set an input folder before adding ownership data.'
            Recommended = $false
        },
        [pscustomobject]@{
            Key = 'advanced'
            Label = 'Advanced tools'
            Description = 'Connectivity evidence, manual validation, dashboard packaging, stop gates, and support bundles.'
            Available = $true
            UnavailableReason = ''
            Recommended = $false
        },
        [pscustomobject]@{
            Key = 'exit'
            Label = 'Exit'
            Description = 'Leave the menu. Saved configs, plans, and rerun scripts keep your progress.'
            Available = $true
            UnavailableReason = ''
            Recommended = $false
        }
    )
}

function New-ShareSurferMenuChoiceOptions {
    param(
        [Parameter(Mandatory = $true)]
        [object[]] $Entries
    )

    @($Entries | ForEach-Object {
        New-ShareSurferConsoleChoiceOption `
            -Value ([string]$_.Key) `
            -Label ([string]$_.Label) `
            -Description ([string]$_.Description) `
            -Enabled ([bool]$_.Available) `
            -UnavailableReason ([string]$_.UnavailableReason)
    })
}

function Get-ShareSurferMenuHelpText {
    param(
        [Parameter(Mandatory = $true)]
        [object[]] $Entries
    )

    $saved = @($Entries | Where-Object { [string]$_.Key -eq 'saved_scan' })[0]
    $results = @($Entries | Where-Object { [string]$_.Key -eq 'review_results' })[0]
    $savedText = if ([bool]$saved.Available) { 'Saved scan: ready.' } else { 'Saved scan: not ready.' }
    $resultsValidated = ($null -ne $results.PSObject.Properties['ValidationPassed'] -and [bool]$results.ValidationPassed)
    $resultsText = if ($resultsValidated) { 'Results: validated in this session.' } elseif ([bool]$results.Available) { 'Results: found; validation is required in this session.' } else { 'Results: none found.' }
    '{0} {1} Press Enter for the recommended first-scan path.' -f $savedText, $resultsText
}

function Get-ShareSurferMenuScreen {
    param(
        [Parameter(Mandatory = $true)]
        [object[]] $Entries,

        [string] $InputRoot = '',

        [string] $ExportPath = '',

        [int] $Width = 120
    )

    $options = @(New-ShareSurferMenuChoiceOptions -Entries $Entries)
    $state = New-ShareSurferConsoleChoiceState -Options $options -DefaultValue 'first_scan'
    Get-ShareSurferConsoleChoiceScreen `
        -State $state `
        -Title 'ShareSurfer' `
        -HelpText (Get-ShareSurferMenuHelpText -Entries $Entries) `
        -AllowQuit `
        -Width $Width
}

function Show-ShareSurferMenuTechnicalCommand {
    param([string] $Command = '')

    if ([string]::IsNullOrWhiteSpace($Command)) {
        return
    }
    Write-ShareSurferConsoleLines -Lines @('', 'Technical command', ('  {0}' -f $Command))
}

function Set-ShareSurferMenuSessionValidationState {
    param(
        [Parameter(Mandatory = $true)]
        $SessionState,

        [bool] $Passed = $false,

        [string] $ExportPath = ''
    )

    if ($null -eq $SessionState.PSObject.Properties['ValidatedExportPath']) {
        $SessionState | Add-Member -MemberType NoteProperty -Name ValidatedExportPath -Value ''
    }
    $SessionState.ValidationPassed = [bool]$Passed
    $SessionState.ValidatedExportPath = if ($Passed) { $ExportPath } else { '' }
}

function Test-ShareSurferMenuSessionValidation {
    param(
        [Parameter(Mandatory = $true)]
        $SessionState,

        [string] $ExportPath = ''
    )

    if (-not [bool]$SessionState.ValidationPassed -or
        [string]::IsNullOrWhiteSpace($ExportPath) -or
        $null -eq $SessionState.PSObject.Properties['ValidatedExportPath'] -or
        [string]::IsNullOrWhiteSpace([string]$SessionState.ValidatedExportPath)) {
        return $false
    }

    [string]::Equals(
        (ConvertTo-ShareSurferAssistantComparablePath -Path ([string]$SessionState.ValidatedExportPath)),
        (ConvertTo-ShareSurferAssistantComparablePath -Path $ExportPath),
        [System.StringComparison]::OrdinalIgnoreCase)
}

function Invoke-ShareSurferMenuExportValidation {
    param(
        [Parameter(Mandatory = $true)]
        [string] $ExportPath,

        [Parameter(Mandatory = $true)]
        $SessionState
    )

    Set-ShareSurferMenuSessionValidationState -SessionState $SessionState
    $validation = Test-ShareSurferExport -ExportPath $ExportPath
    Set-ShareSurferMenuSessionValidationState -SessionState $SessionState -Passed ([bool]$validation.IsValid) -ExportPath $ExportPath
    if ([bool]$validation.IsValid) {
        Write-ShareSurferConsoleLines -Lines @('', 'Export validation passed.', ('  Export: {0}' -f $ExportPath))
    }
    else {
        $missing = @($validation.MissingFiles)
        $schemaErrors = @($validation.SchemaErrors)
        $lines = New-Object System.Collections.Generic.List[string]
        $lines.Add('')
        $lines.Add('Export validation failed. Dashboard packaging remains unavailable.')
        if ($missing.Count -gt 0) { $lines.Add(('  Missing files: {0}' -f ($missing -join ', '))) }
        if ($schemaErrors.Count -gt 0) { $lines.Add(('  Schema errors: {0}' -f ($schemaErrors -join ' | '))) }
        $lines.Add('  Correct the export or run the scan again, then validate once more.')
        Write-ShareSurferConsoleLines -Lines @($lines.ToArray())
    }

    $validation
}

function Invoke-ShareSurferMenuOwnerMappingDraftOffer {
    param(
        [string] $InputRoot = '',

        [Parameter(Mandatory = $true)]
        [string] $ExportPath,

        [ValidateSet('Auto', 'Enhanced', 'Plain')]
        [string] $ConsoleMode = 'Plain'
    )

    if ([string]::IsNullOrWhiteSpace($InputRoot)) {
        Write-ShareSurferConsoleLines -Lines @(
            'Owner mapping is optional. Set an input folder or choose Add ownership or HR data when you are ready to prepare it.'
        )
        return
    }

    $ownerMappingPath = Join-ShareSurferAssistantPathText -Root $InputRoot -Child 'owner-mapping.csv'
    if (Test-Path -LiteralPath $ownerMappingPath -PathType Leaf) {
        Write-ShareSurferConsoleLines -Lines @(
            ('Owner mapping is available: {0}' -f $ownerMappingPath),
            'Rerun the saved scan with that mapping when you are ready to refresh owner review packets.'
        )
        return
    }

    $draftPath = Join-ShareSurferAssistantPathText -Root $InputRoot -Child 'owner-mapping-draft.csv'
    $rerunPath = Join-ShareSurferAssistantPathText -Root $InputRoot -Child 'owner-mapping-draft-rerun.ps1'
    if (Test-Path -LiteralPath $draftPath -PathType Leaf) {
        Write-ShareSurferConsoleLines -Lines @(
            ('An owner-mapping draft already exists: {0}' -f $draftPath),
            'Fill Owner and BusinessUnit, save the completed file as owner-mapping.csv, then rerun the saved scan.'
        )
        return
    }

    $options = @(
        (New-ShareSurferConsoleChoiceOption -Value 'create' -Label 'Create an owner-mapping draft' -Description 'Build path patterns from this validated export; no share permissions are changed.'),
        (New-ShareSurferConsoleChoiceOption -Value 'home' -Label 'Return home' -Description 'Skip ownership work for now; the validated results remain available.')
    )
    $selection = Read-ShareSurferConsoleChoice `
        -Title 'Optional next step' `
        -Options $options `
        -DefaultValue 'home' `
        -HelpText 'Ownership is optional for a first scan. The draft needs a person to fill Owner and BusinessUnit.' `
        -AllowBack `
        -AllowQuit `
        -ConsoleMode $ConsoleMode

    if ($selection.Action -ne 'Select' -or [string]$selection.SelectedValue -ne 'create') {
        return
    }

    Show-ShareSurferMenuTechnicalCommand -Command ('New-ShareSurferOwnerMappingDraft -ExportPath {0} -OutputPath {1} -ReusableCommandPath {2}' -f (ConvertTo-ShareSurferPowerShellLiteral -Value $ExportPath), (ConvertTo-ShareSurferPowerShellLiteral -Value $draftPath), (ConvertTo-ShareSurferPowerShellLiteral -Value $rerunPath))
    $summary = New-ShareSurferOwnerMappingDraft `
        -ExportPath $ExportPath `
        -OutputPath $draftPath `
        -ReusableCommandPath $rerunPath
    Write-ShareSurferConsoleLines -Lines @(
        '',
        'Owner-mapping draft created.',
        ('  Draft: {0}' -f [string]$summary.OutputPath),
        ('  Regenerate: {0}' -f [string]$summary.ReusableCommandPath),
        'Fill Owner and BusinessUnit, save the completed file as owner-mapping.csv, then rerun the saved scan.'
    )
}

function Get-ShareSurferAdvancedMenuEntries {
    param(
        [string] $InputRoot = '',

        [string] $ExportPath = '',

        [string] $StandaloneDashboardPath = '',

        [string] $ReleaseRoot = '',

        [Parameter(Mandatory = $true)]
        $SessionState
    )

    $saved = Get-ShareSurferMenuSavedWorkflowState -InputRoot $InputRoot
    $exportFound = (Get-ShareSurferMenuPathState -FolderPath $ExportPath -FileName 'shares.csv') -eq 'found'
    $validationReady = Test-ShareSurferMenuSessionValidation -SessionState $SessionState -ExportPath $ExportPath
    $dashboardScriptPath = if ([string]::IsNullOrWhiteSpace($ReleaseRoot)) { '' } else { Join-ShareSurferAssistantPathText -Root $ReleaseRoot -Child 'scripts/New-ShareSurferStandaloneDashboard.ps1' }
    $dashboardScriptFound = (-not [string]::IsNullOrWhiteSpace($dashboardScriptPath) -and (Test-Path -LiteralPath $dashboardScriptPath -PathType Leaf))
    $supportPath = if ([string]::IsNullOrWhiteSpace($ExportPath)) { '' } else { Join-ShareSurferAssistantPathText -Root $ExportPath -Child 'support-bundle' }

    @(
        [pscustomobject]@{
            Key = 'preflight'
            Label = 'Run connectivity preflight'
            Description = 'Write port and protocol readiness evidence for the saved scan targets.'
            Available = ([bool]$saved.Ready -and @($saved.TargetPath).Count -gt 0)
            UnavailableReason = 'Save a first-scan target before running connectivity preflight.'
            CommandPreview = ('Invoke-ShareSurferPortProtocolAssessment -TargetPath {0} -OutputPath {1} -Force' -f ((@($saved.TargetPath) | ForEach-Object { ConvertTo-ShareSurferPowerShellLiteral -Value ([string]$_) }) -join ', '), (Format-ShareSurferMenuLiteral -Value $ExportPath -Placeholder '<export folder>'))
            TargetPath = @($saved.TargetPath)
        },
        [pscustomobject]@{
            Key = 'validate'
            Label = 'Validate the current export'
            Description = 'Check required files and schemas before review or packaging.'
            Available = [bool]$exportFound
            UnavailableReason = 'No export was found to validate.'
            CommandPreview = ('Test-ShareSurferExport -ExportPath {0}' -f (Format-ShareSurferMenuLiteral -Value $ExportPath -Placeholder '<export folder>'))
        },
        [pscustomobject]@{
            Key = 'dashboard'
            Label = 'Package the standalone dashboard'
            Description = 'Build the portable offline dashboard from the export validated in this session.'
            Available = ([bool]$exportFound -and $validationReady -and $dashboardScriptFound -and -not [string]::IsNullOrWhiteSpace($StandaloneDashboardPath))
            UnavailableReason = $(if (-not [bool]$exportFound -or -not $validationReady) { 'Validate this export successfully in this session first.' } elseif (-not $dashboardScriptFound) { 'The dashboard packaging script was not found.' } else { 'Set a dashboard output folder.' })
            CommandPreview = ('& {0} -ExportPath {1} -OutputPath {2} -Force' -f (Format-ShareSurferMenuLiteral -Value $dashboardScriptPath -Placeholder '<dashboard script>'), (Format-ShareSurferMenuLiteral -Value $ExportPath -Placeholder '<export folder>'), (Format-ShareSurferMenuLiteral -Value $StandaloneDashboardPath -Placeholder '<dashboard folder>'))
            ScriptPath = $dashboardScriptPath
        },
        [pscustomobject]@{
            Key = 'stopgates'
            Label = 'Review stop gates and handoff evidence'
            Description = 'Locate confidence, collection-error, and scan-manifest evidence before owner signoff.'
            Available = [bool]$exportFound
            UnavailableReason = 'Run a scan before reviewing stop-gate evidence.'
            CommandPreview = ''
        },
        [pscustomobject]@{
            Key = 'support'
            Label = 'Create a redacted support bundle'
            Description = 'Copy and redact the export into a troubleshooting bundle.'
            Available = [bool]$exportFound
            UnavailableReason = 'Run a scan before creating a support bundle.'
            CommandPreview = ('New-ShareSurferSupportBundle -ExportPath {0} -OutputPath {1}' -f (Format-ShareSurferMenuLiteral -Value $ExportPath -Placeholder '<export folder>'), (Format-ShareSurferMenuLiteral -Value $supportPath -Placeholder '<support folder>'))
            OutputPath = $supportPath
        },
        [pscustomobject]@{
            Key = 'back'
            Label = 'Back to home'
            Description = 'Return to the goal-based home screen.'
            Available = $true
            UnavailableReason = ''
            CommandPreview = ''
        }
    )
}

function Invoke-ShareSurferAdvancedMenu {
    param(
        [string] $InputRoot = '',
        [string] $ExportPath = '',
        [string] $StandaloneDashboardPath = '',
        [string] $ReleaseRoot = '',
        [ValidateSet('Auto', 'Enhanced', 'Plain')]
        [string] $ConsoleMode = 'Plain',
        [Parameter(Mandatory = $true)]
        $SessionState
    )

    while ($true) {
        $entries = @(Get-ShareSurferAdvancedMenuEntries -InputRoot $InputRoot -ExportPath $ExportPath -StandaloneDashboardPath $StandaloneDashboardPath -ReleaseRoot $ReleaseRoot -SessionState $SessionState)
        $options = @(New-ShareSurferMenuChoiceOptions -Entries $entries)
        $selection = Read-ShareSurferConsoleChoice -Title 'Advanced tools' -Options $options -HelpText 'These tools support an existing setup or export. Unavailable tools show the prerequisite they need.' -AllowBack -AllowQuit -ConsoleMode $ConsoleMode
        if ($selection.Action -in @('Back', 'Cancel') -or [string]$selection.SelectedValue -eq 'back') {
            return
        }
        if ($selection.Action -ne 'Select') {
            continue
        }

        $entry = @($entries | Where-Object { [string]$_.Key -eq [string]$selection.SelectedValue })[0]
        try {
            switch ([string]$entry.Key) {
                'preflight' {
                    Show-ShareSurferMenuTechnicalCommand -Command ([string]$entry.CommandPreview)
                    $confirm = Read-ShareSurferConsoleBoolean -Prompt 'Write connectivity readiness evidence now?' -Default $false -AllowBack -AllowQuit -ConsoleMode $ConsoleMode
                    if ($confirm.Action -eq 'Cancel') { return }
                    if ($confirm.Action -eq 'Back' -or -not [bool]$confirm.Value) { continue }
                    Invoke-ShareSurferPortProtocolAssessment -TargetPath @($entry.TargetPath) -OutputPath $ExportPath -Force | Out-Host
                    Write-ShareSurferConsoleLines -Lines @('Connectivity readiness evidence is ready. Returning to Advanced tools.')
                }
                'validate' {
                    Show-ShareSurferMenuTechnicalCommand -Command ([string]$entry.CommandPreview)
                    Invoke-ShareSurferMenuExportValidation -ExportPath $ExportPath -SessionState $SessionState | Out-Null
                }
                'dashboard' {
                    Show-ShareSurferMenuTechnicalCommand -Command ([string]$entry.CommandPreview)
                    $confirm = Read-ShareSurferConsoleBoolean -Prompt 'Package the validated export now?' -Default $false -AllowBack -AllowQuit -ConsoleMode $ConsoleMode
                    if ($confirm.Action -eq 'Cancel') { return }
                    if ($confirm.Action -eq 'Back' -or -not [bool]$confirm.Value) { continue }
                    Write-ShareSurferConsoleLines -Lines @('Revalidating the export immediately before packaging...')
                    Invoke-ShareSurferMenuExportValidation -ExportPath $ExportPath -SessionState $SessionState | Out-Null
                    if (-not (Test-ShareSurferMenuSessionValidation -SessionState $SessionState -ExportPath $ExportPath)) {
                        Write-ShareSurferConsoleLines -Lines @('Packaging stopped because the export no longer passes validation.')
                        continue
                    }
                    & ([string]$entry.ScriptPath) -ExportPath $ExportPath -OutputPath $StandaloneDashboardPath -Force | Out-Host
                    Write-ShareSurferConsoleLines -Lines @('Standalone dashboard packaging completed. Returning to Advanced tools.')
                }
                'stopgates' {
                    $lines = New-Object System.Collections.Generic.List[string]
                    $lines.Add('')
                    $lines.Add('Stop-gate evidence')
                    foreach ($fileName in @('evidence_confidence.csv', 'collection_errors.csv', 'scan_manifest.csv')) {
                        $path = Join-ShareSurferAssistantPathText -Root $ExportPath -Child $fileName
                        $state = if (Test-Path -LiteralPath $path -PathType Leaf) { 'found' } else { 'missing' }
                        $lines.Add(('  {0}: {1}' -f $fileName, $state))
                    }
                    $lines.Add('Resolve or document unexplained gaps before owner signoff or handoff.')
                    Write-ShareSurferConsoleLines -Lines @($lines.ToArray())
                }
                'support' {
                    Show-ShareSurferMenuTechnicalCommand -Command ([string]$entry.CommandPreview)
                    $confirm = Read-ShareSurferConsoleBoolean -Prompt 'Create the redacted support bundle now?' -Default $false -AllowBack -AllowQuit -ConsoleMode $ConsoleMode
                    if ($confirm.Action -eq 'Cancel') { return }
                    if ($confirm.Action -eq 'Back' -or -not [bool]$confirm.Value) { continue }
                    New-ShareSurferSupportBundle -ExportPath $ExportPath -OutputPath ([string]$entry.OutputPath) | Out-Host
                    Write-ShareSurferConsoleLines -Lines @(('Support bundle ready: {0}' -f [string]$entry.OutputPath))
                }
            }
        }
        catch {
            Write-ShareSurferConsoleLines -Lines @('', ('Advanced action failed: {0}' -f $_.Exception.Message), 'Correct the issue and choose the action again, or return home. Your saved setup is unchanged.')
        }
    }
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
        [ValidateSet('FullEffective', 'Compact')]
        [string] $AclExportMode = 'Compact',
        [ValidateSet('Auto', 'Enhanced', 'Plain')]
        [string] $ConsoleMode = 'Plain'
    )

    $initialPaths = Get-ShareSurferMenuInitialPaths -InputRoot $InputRoot -ExportPath $ExportPath -StandaloneDashboardPath $StandaloneDashboardPath
    $ExportPath = [string]$initialPaths.ExportPath
    $StandaloneDashboardPath = [string]$initialPaths.StandaloneDashboardPath
    $initialSettings = Get-ShareSurferMenuInitialSettings `
        -InputRoot $InputRoot `
        -ObsAttribute $ObsAttribute `
        -AdLookupMode $AdLookupMode `
        -ManagerIdentityFormat $ManagerIdentityFormat `
        -AclExportMode $AclExportMode `
        -ConsoleMode $ConsoleMode `
        -PreserveObsAttribute:$($PSBoundParameters.ContainsKey('ObsAttribute')) `
        -PreserveAdLookupMode:$($PSBoundParameters.ContainsKey('AdLookupMode')) `
        -PreserveManagerIdentityFormat:$($PSBoundParameters.ContainsKey('ManagerIdentityFormat')) `
        -PreserveAclExportMode:$($PSBoundParameters.ContainsKey('AclExportMode')) `
        -PreserveConsoleMode:$($PSBoundParameters.ContainsKey('ConsoleMode'))
    $ObsAttribute = [string]$initialSettings.ObsAttribute
    $AdLookupMode = [string]$initialSettings.AdLookupMode
    $ManagerIdentityFormat = [string]$initialSettings.ManagerIdentityFormat
    $AclExportMode = [string]$initialSettings.AclExportMode
    $ConsoleMode = [string]$initialSettings.ConsoleMode

    $sessionState = [pscustomobject]@{
        ValidationPassed = $false
        ValidatedExportPath = ''
    }

    while ($true) {
        $sessionValidationPassed = Test-ShareSurferMenuSessionValidation -SessionState $sessionState -ExportPath $ExportPath
        $entries = @(Get-ShareSurferMenuEntries -InputRoot $InputRoot -ExportPath $ExportPath -StandaloneDashboardPath $StandaloneDashboardPath -ReleaseRoot $ReleaseRoot -ObsAttribute $ObsAttribute -AdLookupMode $AdLookupMode -ManagerIdentityFormat $ManagerIdentityFormat -AclExportMode $AclExportMode -ConsoleMode $ConsoleMode -SessionValidationPassed $sessionValidationPassed)
        $options = @(New-ShareSurferMenuChoiceOptions -Entries $entries)
        $selection = Read-ShareSurferConsoleChoice -Title 'ShareSurfer' -Options $options -DefaultValue 'first_scan' -HelpText (Get-ShareSurferMenuHelpText -Entries $entries) -AllowQuit -ConsoleMode $ConsoleMode
        if ($selection.Action -eq 'Cancel' -or [string]$selection.SelectedValue -eq 'exit') {
            Write-ShareSurferConsoleLines -Lines @('Leaving ShareSurfer. Saved configs, plans, and rerun scripts keep your progress.')
            return
        }
        if ($selection.Action -ne 'Select') {
            continue
        }

        $entry = @($entries | Where-Object { [string]$_.Key -eq [string]$selection.SelectedValue })[0]
        try {
            switch ([string]$entry.Key) {
                'first_scan' {
                    $startupParameters = @{ Interactive = $true; ConsoleMode = $ConsoleMode }
                    if (-not [string]::IsNullOrWhiteSpace($InputRoot)) { $startupParameters.InputRoot = $InputRoot }
                    if (-not [string]::IsNullOrWhiteSpace($ExportPath)) { $startupParameters.ExportPath = $ExportPath }
                    if (-not [string]::IsNullOrWhiteSpace($StandaloneDashboardPath)) { $startupParameters.StandaloneDashboardPath = $StandaloneDashboardPath }
                    if (-not [string]::IsNullOrWhiteSpace($ReleaseRoot)) { $startupParameters.ReleaseRoot = $ReleaseRoot }
                    if (-not [string]::IsNullOrWhiteSpace($ObsAttribute)) { $startupParameters.ObsAttribute = $ObsAttribute }
                    if (-not [string]::IsNullOrWhiteSpace($AdLookupMode)) { $startupParameters.AdLookupMode = $AdLookupMode }
                    if (-not [string]::IsNullOrWhiteSpace($ManagerIdentityFormat)) { $startupParameters.ManagerIdentityFormat = $ManagerIdentityFormat }
                    if (-not [string]::IsNullOrWhiteSpace($AclExportMode)) { $startupParameters.AclExportMode = $AclExportMode }
                    $summary = Start-ShareSurferStartup @startupParameters
                    if ($null -ne $summary.PSObject.Properties['Cancelled'] -and [bool]$summary.Cancelled) {
                        Write-ShareSurferConsoleLines -Lines @('First-scan setup cancelled. No startup files were written; returning home.')
                        continue
                    }
                    $InputRoot = [string]$summary.InputRoot
                    $ExportPath = [string]$summary.ExportPath
                    $StandaloneDashboardPath = [string]$summary.StandaloneDashboardPath
                    Write-ShareSurferConsoleLines -Lines @('', 'First-scan setup is ready.', ('  Config: {0}' -f [string]$summary.StartupConfigPath), ('  Plan:   {0}' -f [string]$summary.OperatorPlanPath), ('  Rerun:  {0}' -f [string]$summary.OperatorReusableCommandPath), 'Returning to the refreshed home screen.')
                    if (Test-Path -LiteralPath (Join-ShareSurferAssistantPathText -Root $ExportPath -Child 'shares.csv') -PathType Leaf) {
                        Invoke-ShareSurferMenuExportValidation -ExportPath $ExportPath -SessionState $sessionState | Out-Null
                    }
                }
                'saved_scan' {
                    if (-not [string]::IsNullOrWhiteSpace([string]$entry.ExportPath)) {
                        if (-not [string]::Equals((ConvertTo-ShareSurferAssistantComparablePath -Path $ExportPath), (ConvertTo-ShareSurferAssistantComparablePath -Path ([string]$entry.ExportPath)), [System.StringComparison]::OrdinalIgnoreCase)) {
                            Write-ShareSurferConsoleLines -Lines @('', ('Switching to the saved workflow export: {0}' -f [string]$entry.ExportPath))
                        }
                        $ExportPath = [string]$entry.ExportPath
                        $StandaloneDashboardPath = if (-not [string]::IsNullOrWhiteSpace([string]$entry.StandaloneDashboardPath)) { [string]$entry.StandaloneDashboardPath } else { Join-ShareSurferAssistantPathText -Root $ExportPath -Child 'standalone-dashboard' }
                    }
                    if (-not [string]::IsNullOrWhiteSpace([string]$entry.ObsAttribute)) { $ObsAttribute = [string]$entry.ObsAttribute }
                    if ([string]$entry.AdLookupMode -in @('Auto', 'ActiveDirectory', 'Ldap', 'DirectoryOnly')) { $AdLookupMode = [string]$entry.AdLookupMode }
                    if ([string]$entry.ManagerIdentityFormat -in @('MailTo', 'Mail', 'UserPrincipalName', 'SamAccountName', 'DistinguishedName')) { $ManagerIdentityFormat = [string]$entry.ManagerIdentityFormat }
                    if ([string]$entry.AclExportMode -in @('FullEffective', 'Compact')) { $AclExportMode = [string]$entry.AclExportMode }
                    $rerunPath = [string]$entry.RerunPath
                    Show-ShareSurferMenuTechnicalCommand -Command ('& {0}' -f (ConvertTo-ShareSurferPowerShellLiteral -Value $rerunPath))
                    $confirm = Read-ShareSurferConsoleBoolean -Prompt 'Run the saved scan workflow now?' -Default $false -AllowBack -AllowQuit -ConsoleMode $ConsoleMode
                    if ($confirm.Action -eq 'Cancel') { continue }
                    if ($confirm.Action -eq 'Back' -or -not [bool]$confirm.Value) { continue }
                    Write-ShareSurferConsoleLines -Lines @(('Running saved ShareSurfer workflow: {0}' -f $rerunPath))
                    Set-ShareSurferMenuSessionValidationState -SessionState $sessionState
                    & $rerunPath | Out-Host
                    if (Test-Path -LiteralPath (Join-ShareSurferAssistantPathText -Root $ExportPath -Child 'shares.csv') -PathType Leaf) {
                        Invoke-ShareSurferMenuExportValidation -ExportPath $ExportPath -SessionState $sessionState | Out-Null
                    }
                    Write-ShareSurferConsoleLines -Lines @('Saved workflow completed. Returning to the refreshed home screen.')
                }
                'review_results' {
                    Invoke-ShareSurferMenuExportValidation -ExportPath $ExportPath -SessionState $sessionState | Out-Null
                    if ([bool]$sessionState.ValidationPassed) {
                        Write-ShareSurferConsoleLines -Lines @('Use the standalone dashboard or exported CSVs for review. Open stop-gate evidence before owner signoff.')
                        Invoke-ShareSurferMenuOwnerMappingDraftOffer -InputRoot $InputRoot -ExportPath $ExportPath -ConsoleMode $ConsoleMode
                    }
                }
                'ownership' {
                    Write-ShareSurferConsoleLines -Lines @('', 'Ownership and HR data are optional for a first scan. This guided branch can discover or build enrichment inputs without changing share permissions.')
                    $ownershipSummary = Invoke-ShareSurferStartupOwnershipSetup -InputRoot $InputRoot -ObsAttribute $ObsAttribute -AdLookupMode $AdLookupMode -ConsoleMode $ConsoleMode
                    if ($null -ne $ownershipSummary.PSObject.Properties['Cancelled'] -and [bool]$ownershipSummary.Cancelled) {
                        Write-ShareSurferConsoleLines -Lines @('Ownership setup stopped. Returning to the refreshed home screen.')
                    }
                    else {
                        Write-ShareSurferConsoleLines -Lines @('Ownership setup finished. Returning to the refreshed home screen.')
                    }
                }
                'advanced' {
                    Invoke-ShareSurferAdvancedMenu -InputRoot $InputRoot -ExportPath $ExportPath -StandaloneDashboardPath $StandaloneDashboardPath -ReleaseRoot $ReleaseRoot -ConsoleMode $ConsoleMode -SessionState $sessionState
                }
            }
        }
        catch {
            Set-ShareSurferMenuSessionValidationState -SessionState $sessionState
            Write-ShareSurferConsoleLines -Lines @('', ('ShareSurfer could not complete that action: {0}' -f $_.Exception.Message), 'Startup files may already have been saved and scan output may be partial. Review the reported paths, correct the issue, and retry from home.')
        }
    }
}
