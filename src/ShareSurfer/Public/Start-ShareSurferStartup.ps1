function Start-ShareSurferStartup {
    [CmdletBinding()]
    param(
        [string] $ConfigPath = '',

        [string] $SaveConfigPath = '',

        [ValidateSet('Permissive', 'Nonpermissive')]
        [string] $EnvironmentMode = 'Permissive',

        [string] $ReleaseRoot = '',

        [string] $InputRoot = '',

        [string] $ExportPath = '',

        [string] $StandaloneDashboardPath = '',

        [string[]] $TargetPath = @(),

        [string] $ObsAttribute = 'extensionAttribute10',

        [ValidateSet('Auto', 'ActiveDirectory', 'Ldap', 'DirectoryOnly')]
        [string] $AdLookupMode = 'Auto',

        [ValidateSet('MailTo', 'Mail', 'UserPrincipalName', 'SamAccountName', 'DistinguishedName')]
        [string] $ManagerIdentityFormat = 'MailTo',

        [ValidateSet('FullEffective', 'Compact')]
        [string] $AclExportMode = 'Compact',

        [ValidateSet('Auto', 'Enhanced', 'Plain')]
        [string] $ConsoleMode = 'Plain',

        [string] $OwnerMappingPath = '',

        [string] $OwnershipEnrichmentPath = '',

        [string] $OwnershipContextPath = '',

        [string] $OwnershipRelationshipPath = '',

        [string] $OwnershipImportManifestPath = '',

        [string] $DiscountedPrincipalPath = '',

        [switch] $CreateOwnerMappingDraftAfterScan,

        [string] $OwnerMappingDraftPath = '',

        [string] $OwnerMappingDraftReusableCommandPath = '',

        [string] $HandoffPath = '',

        [string] $PlanPath = '',

        [string] $ReusableCommandPath = '',

        [switch] $IncludeFiles,

        [bool] $IncludeSharePermissionDiagnostics = $true,

        [switch] $SkipIdentityEnrichment,

        [switch] $Interactive,

        [switch] $SkipUnblock,

        [switch] $SkipOwnershipSetup,

        [switch] $DisableOptionalInputDiscovery,

        [switch] $NoCreateMissingFolders,

        [switch] $Force
    )

    $boundParameters = @{}
    foreach ($key in $PSBoundParameters.Keys) {
        $boundParameters[$key] = $true
    }
    $configOptionalInputsLoaded = $false

    if (-not [string]::IsNullOrWhiteSpace($ConfigPath)) {
        if (-not (Test-Path -LiteralPath $ConfigPath -PathType Leaf)) {
            throw "ShareSurfer startup config was not found: $ConfigPath"
        }

        $definition = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
        if ($null -ne $definition.PSObject.Properties['environmentMode'] -and -not $boundParameters.ContainsKey('EnvironmentMode')) { $EnvironmentMode = [string]$definition.environmentMode }
        if ($null -ne $definition.PSObject.Properties['releaseRoot'] -and -not $boundParameters.ContainsKey('ReleaseRoot')) { $ReleaseRoot = [string]$definition.releaseRoot }
        if ($null -ne $definition.PSObject.Properties['inputRoot'] -and -not $boundParameters.ContainsKey('InputRoot')) { $InputRoot = [string]$definition.inputRoot }
        if ($null -ne $definition.PSObject.Properties['exportPath'] -and -not $boundParameters.ContainsKey('ExportPath')) { $ExportPath = [string]$definition.exportPath }
        if ($null -ne $definition.PSObject.Properties['standaloneDashboardPath'] -and -not $boundParameters.ContainsKey('StandaloneDashboardPath')) { $StandaloneDashboardPath = [string]$definition.standaloneDashboardPath }
        if ($null -ne $definition.PSObject.Properties['targetPaths'] -and -not $boundParameters.ContainsKey('TargetPath')) { $TargetPath = @($definition.targetPaths | ForEach-Object { [string]$_ }) }
        if ($null -ne $definition.PSObject.Properties['obsAttribute'] -and -not $boundParameters.ContainsKey('ObsAttribute')) { $ObsAttribute = [string]$definition.obsAttribute }
        if ($null -ne $definition.PSObject.Properties['adLookupMode'] -and -not $boundParameters.ContainsKey('AdLookupMode')) { $AdLookupMode = [string]$definition.adLookupMode }
        if ($null -ne $definition.PSObject.Properties['managerIdentityFormat'] -and -not $boundParameters.ContainsKey('ManagerIdentityFormat')) { $ManagerIdentityFormat = [string]$definition.managerIdentityFormat }
        if ($null -ne $definition.PSObject.Properties['aclExportMode'] -and -not $boundParameters.ContainsKey('AclExportMode')) { $AclExportMode = [string]$definition.aclExportMode }
        if ($null -ne $definition.PSObject.Properties['consoleMode'] -and -not $boundParameters.ContainsKey('ConsoleMode')) { $ConsoleMode = [string]$definition.consoleMode }
        if ($null -ne $definition.PSObject.Properties['includeFiles'] -and -not $boundParameters.ContainsKey('IncludeFiles')) { $IncludeFiles = [bool]$definition.includeFiles }
        if ($null -ne $definition.PSObject.Properties['includeSharePermissionDiagnostics'] -and -not $boundParameters.ContainsKey('IncludeSharePermissionDiagnostics')) { $IncludeSharePermissionDiagnostics = [bool]$definition.includeSharePermissionDiagnostics }
        if ($null -ne $definition.PSObject.Properties['skipIdentityEnrichment'] -and -not $boundParameters.ContainsKey('SkipIdentityEnrichment')) { $SkipIdentityEnrichment = [bool]$definition.skipIdentityEnrichment }
        if ($null -ne $definition.PSObject.Properties['skipUnblock'] -and -not $boundParameters.ContainsKey('SkipUnblock')) { $SkipUnblock = [bool]$definition.skipUnblock }
        if ($null -ne $definition.PSObject.Properties['disableOptionalInputDiscovery'] -and -not $boundParameters.ContainsKey('DisableOptionalInputDiscovery')) { $DisableOptionalInputDiscovery = [bool]$definition.disableOptionalInputDiscovery }
        if ($null -ne $definition.PSObject.Properties['optionalInputs']) {
            $configOptionalInputsLoaded = $true
            if ($null -ne $definition.optionalInputs.PSObject.Properties['ownerMappingPath'] -and -not $boundParameters.ContainsKey('OwnerMappingPath')) { $OwnerMappingPath = [string]$definition.optionalInputs.ownerMappingPath }
            if ($null -ne $definition.optionalInputs.PSObject.Properties['ownershipEnrichmentPath'] -and -not $boundParameters.ContainsKey('OwnershipEnrichmentPath')) { $OwnershipEnrichmentPath = [string]$definition.optionalInputs.ownershipEnrichmentPath }
            if ($null -ne $definition.optionalInputs.PSObject.Properties['ownershipContextPath'] -and -not $boundParameters.ContainsKey('OwnershipContextPath')) { $OwnershipContextPath = [string]$definition.optionalInputs.ownershipContextPath }
            if ($null -ne $definition.optionalInputs.PSObject.Properties['ownershipRelationshipPath'] -and -not $boundParameters.ContainsKey('OwnershipRelationshipPath')) { $OwnershipRelationshipPath = [string]$definition.optionalInputs.ownershipRelationshipPath }
            if ($null -ne $definition.optionalInputs.PSObject.Properties['ownershipImportManifestPath'] -and -not $boundParameters.ContainsKey('OwnershipImportManifestPath')) { $OwnershipImportManifestPath = [string]$definition.optionalInputs.ownershipImportManifestPath }
            if ($null -ne $definition.optionalInputs.PSObject.Properties['discountedPrincipalPath'] -and -not $boundParameters.ContainsKey('DiscountedPrincipalPath')) { $DiscountedPrincipalPath = [string]$definition.optionalInputs.discountedPrincipalPath }
        }
        if ($null -ne $definition.PSObject.Properties['ownershipSetup']) {
            if ($null -ne $definition.ownershipSetup.PSObject.Properties['CreateOwnerMappingDraftAfterScan'] -and -not $boundParameters.ContainsKey('CreateOwnerMappingDraftAfterScan')) { $CreateOwnerMappingDraftAfterScan = [bool]$definition.ownershipSetup.CreateOwnerMappingDraftAfterScan }
            if ($null -ne $definition.ownershipSetup.PSObject.Properties['OwnerMappingDraftPath'] -and -not $boundParameters.ContainsKey('OwnerMappingDraftPath')) { $OwnerMappingDraftPath = [string]$definition.ownershipSetup.OwnerMappingDraftPath }
            if ($null -ne $definition.ownershipSetup.PSObject.Properties['OwnerMappingDraftReusableCommandPath'] -and -not $boundParameters.ContainsKey('OwnerMappingDraftReusableCommandPath')) { $OwnerMappingDraftReusableCommandPath = [string]$definition.ownershipSetup.OwnerMappingDraftReusableCommandPath }
        }
        if ($null -ne $definition.PSObject.Properties['nonpermissive'] -and $null -ne $definition.nonpermissive.PSObject.Properties['handoffPath'] -and -not $boundParameters.ContainsKey('HandoffPath')) {
            $HandoffPath = [string]$definition.nonpermissive.handoffPath
        }
        if ($null -ne $definition.PSObject.Properties['generatedFiles']) {
            if ($null -ne $definition.generatedFiles.PSObject.Properties['operatorPlanPath'] -and -not $boundParameters.ContainsKey('PlanPath')) { $PlanPath = [string]$definition.generatedFiles.operatorPlanPath }
            if ($null -ne $definition.generatedFiles.PSObject.Properties['operatorReusableCommandPath'] -and -not $boundParameters.ContainsKey('ReusableCommandPath')) { $ReusableCommandPath = [string]$definition.generatedFiles.operatorReusableCommandPath }
        }
        if ([string]::IsNullOrWhiteSpace($SaveConfigPath)) {
            $SaveConfigPath = $ConfigPath
        }
    }

    if ([string]::IsNullOrWhiteSpace($ReleaseRoot)) {
        $ReleaseRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    }

    if ([string]::IsNullOrWhiteSpace($InputRoot)) {
        $InputRoot = Join-Path (Get-Location).Path 'inputs'
    }

    if ([string]::IsNullOrWhiteSpace($ExportPath)) {
        $outputRoot = Join-Path (Split-Path -Parent $InputRoot) 'exports'
        $ExportPath = Join-Path $outputRoot 'startup-scan'
    }

    if ([string]::IsNullOrWhiteSpace($StandaloneDashboardPath)) {
        $StandaloneDashboardPath = Join-Path $ExportPath 'standalone-dashboard'
    }

    if ([string]::IsNullOrWhiteSpace($SaveConfigPath)) {
        $SaveConfigPath = Join-Path $InputRoot 'sharesurfer-startup.config.json'
    }

    if ([string]::IsNullOrWhiteSpace($PlanPath)) {
        $PlanPath = Join-Path $InputRoot 'operator-assistant.plan.json'
    }

    if ([string]::IsNullOrWhiteSpace($ReusableCommandPath)) {
        $ReusableCommandPath = Join-Path $InputRoot 'operator-assistant-rerun.ps1'
    }

    $ownershipSetupSummary = New-ShareSurferStartupOwnershipSetupSummary `
        -OwnerMappingPath $OwnerMappingPath `
        -OwnershipEnrichmentPath $OwnershipEnrichmentPath `
        -OwnershipContextPath $OwnershipContextPath `
        -OwnershipRelationshipPath $OwnershipRelationshipPath `
        -OwnershipImportManifestPath $OwnershipImportManifestPath `
        -Skipped:$SkipOwnershipSetup
    if ($CreateOwnerMappingDraftAfterScan) {
        $ownershipSetupSummary.CreateOwnerMappingDraftAfterScan = $true
        $ownershipSetupSummary.OwnerMappingDraftPath = if (-not [string]::IsNullOrWhiteSpace($OwnerMappingDraftPath)) { $OwnerMappingDraftPath } else { Join-Path $InputRoot 'owner-mapping-draft.csv' }
        $ownershipSetupSummary.OwnerMappingDraftReusableCommandPath = if (-not [string]::IsNullOrWhiteSpace($OwnerMappingDraftReusableCommandPath)) { $OwnerMappingDraftReusableCommandPath } else { Join-Path $InputRoot 'owner-mapping-draft-rerun.ps1' }
    }

    $interactiveRunNow = $false
    $interactiveReviewShown = $false
    $deferOwnershipInputs = $false

    if ($Interactive) {
        $interactiveState = [pscustomobject]@{
            EnvironmentMode = $EnvironmentMode
            ReleaseRoot = $ReleaseRoot
            InputRoot = $InputRoot
            ExportPath = $ExportPath
            StandaloneDashboardPath = $StandaloneDashboardPath
            TargetPath = @($TargetPath)
            ObsAttribute = $ObsAttribute
            AdLookupMode = $AdLookupMode
            ManagerIdentityFormat = $ManagerIdentityFormat
            AclExportMode = $AclExportMode
            ConsoleMode = $ConsoleMode
            IncludeFiles = [bool]$IncludeFiles
            IncludeSharePermissionDiagnostics = [bool]$IncludeSharePermissionDiagnostics
            SkipIdentityEnrichment = [bool]$SkipIdentityEnrichment
            SkipUnblock = [bool]$SkipUnblock
            SaveConfigPath = $SaveConfigPath
            HandoffPath = $HandoffPath
            OwnerMappingPath = $OwnerMappingPath
            OwnershipEnrichmentPath = $OwnershipEnrichmentPath
            OwnershipContextPath = $OwnershipContextPath
            OwnershipRelationshipPath = $OwnershipRelationshipPath
            OwnershipImportManifestPath = $OwnershipImportManifestPath
            DiscountedPrincipalPath = $DiscountedPrincipalPath
            OwnershipSetupSummary = $ownershipSetupSummary
            DeferOwnershipInputs = $true
            RunNow = $false
        }
        $newCancelledStartupSummary = {
            [pscustomobject]@{
                Cancelled = $true
                StartupConfigPath = [string]$interactiveState.SaveConfigPath
                EnvironmentMode = [string]$interactiveState.EnvironmentMode
                ReleaseRoot = [string]$interactiveState.ReleaseRoot
                InputRoot = [string]$interactiveState.InputRoot
                ExportPath = [string]$interactiveState.ExportPath
                StandaloneDashboardPath = [string]$interactiveState.StandaloneDashboardPath
                TargetPath = @($interactiveState.TargetPath)
                ObsAttribute = [string]$interactiveState.ObsAttribute
                AdLookupMode = [string]$interactiveState.AdLookupMode
                ManagerIdentityFormat = [string]$interactiveState.ManagerIdentityFormat
                AclExportMode = [string]$interactiveState.AclExportMode
            }
        }

        $interactiveResult = Read-ShareSurferFirstScanConfiguration `
            -State $interactiveState `
            -ConsoleMode $ConsoleMode `
            -NoCreateMissingFolders:$NoCreateMissingFolders `
            -Force:$Force
        if ($interactiveResult.Action -eq 'Cancel') {
            Write-ShareSurferConsoleLines -Lines @('First-scan setup cancelled before writing config, plan, or rerun files.')
            return (& $newCancelledStartupSummary)
        }

        $EnvironmentMode = [string]$interactiveState.EnvironmentMode
        $ReleaseRoot = [string]$interactiveState.ReleaseRoot
        $InputRoot = [string]$interactiveState.InputRoot
        $ExportPath = [string]$interactiveState.ExportPath
        $StandaloneDashboardPath = [string]$interactiveState.StandaloneDashboardPath
        $TargetPath = @($interactiveState.TargetPath)
        $ObsAttribute = [string]$interactiveState.ObsAttribute
        $AdLookupMode = [string]$interactiveState.AdLookupMode
        $ManagerIdentityFormat = [string]$interactiveState.ManagerIdentityFormat
        $AclExportMode = [string]$interactiveState.AclExportMode
        $IncludeFiles = [bool]$interactiveState.IncludeFiles
        $IncludeSharePermissionDiagnostics = [bool]$interactiveState.IncludeSharePermissionDiagnostics
        $SkipIdentityEnrichment = [bool]$interactiveState.SkipIdentityEnrichment
        $SkipUnblock = [bool]$interactiveState.SkipUnblock
        $SaveConfigPath = [string]$interactiveState.SaveConfigPath
        $HandoffPath = [string]$interactiveState.HandoffPath
        $OwnerMappingPath = [string]$interactiveState.OwnerMappingPath
        $OwnershipEnrichmentPath = [string]$interactiveState.OwnershipEnrichmentPath
        $OwnershipContextPath = [string]$interactiveState.OwnershipContextPath
        $OwnershipRelationshipPath = [string]$interactiveState.OwnershipRelationshipPath
        $OwnershipImportManifestPath = [string]$interactiveState.OwnershipImportManifestPath
        $DiscountedPrincipalPath = [string]$interactiveState.DiscountedPrincipalPath
        $ownershipSetupSummary = $interactiveState.OwnershipSetupSummary
        $deferOwnershipInputs = [bool]$interactiveState.DeferOwnershipInputs
        $interactiveRunNow = [bool]$interactiveState.RunNow
        $interactiveReviewShown = $true

        $existingStartupFiles = @(@($SaveConfigPath, $PlanPath, $ReusableCommandPath) | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) -and (Test-Path -LiteralPath ([string]$_) -PathType Leaf) })
        if ($existingStartupFiles.Count -gt 0 -and -not $Force) {
            Write-ShareSurferConsoleLines -Lines @(
                '',
                'A saved first-scan setup already exists.',
                'Replacing it updates the startup config, review plan, and rerun script only after you confirm below.'
            )
            $replace = Read-ShareSurferConsoleBoolean -Prompt 'Replace the existing saved first-scan setup?' -Default $false -AllowBack -AllowQuit -ConsoleMode $ConsoleMode
            if ($replace.Action -in @('Back', 'Cancel') -or -not [bool]$replace.Value) {
                Write-ShareSurferConsoleLines -Lines @('Existing startup files were kept. Returning home without writing changes.')
                return (& $newCancelledStartupSummary)
            }
            $Force = $true
        }
    }
    elseif (-not $configOptionalInputsLoaded -and -not $deferOwnershipInputs -and -not $DisableOptionalInputDiscovery) {
        if (-not $boundParameters.ContainsKey('OwnerMappingPath')) {
            $OwnerMappingPath = Resolve-ShareSurferOptionalInputPath -InputRoot $InputRoot -FileName 'owner-mapping.csv' -Value $OwnerMappingPath
        }
        if (-not $boundParameters.ContainsKey('OwnershipEnrichmentPath')) {
            $OwnershipEnrichmentPath = Resolve-ShareSurferOptionalInputPath -InputRoot $InputRoot -FileName 'ownership-enrichment.csv' -Value $OwnershipEnrichmentPath
        }
        if (-not $boundParameters.ContainsKey('OwnershipContextPath')) {
            $OwnershipContextPath = Resolve-ShareSurferOptionalInputPath -InputRoot $InputRoot -FileName 'ownership_context.csv' -Value $OwnershipContextPath
        }
        if (-not $boundParameters.ContainsKey('OwnershipRelationshipPath')) {
            $OwnershipRelationshipPath = Resolve-ShareSurferOptionalInputPath -InputRoot $InputRoot -FileName 'ownership_relationships.csv' -Value $OwnershipRelationshipPath
        }
        if (-not $boundParameters.ContainsKey('OwnershipImportManifestPath')) {
            $OwnershipImportManifestPath = Resolve-ShareSurferOptionalInputPath -InputRoot $InputRoot -FileName 'ownership_import_manifest.csv' -Value $OwnershipImportManifestPath
        }
        if (-not $boundParameters.ContainsKey('DiscountedPrincipalPath')) {
            $DiscountedPrincipalPath = Resolve-ShareSurferOptionalInputPath -InputRoot $InputRoot -FileName 'discounted-principals.csv' -Value $DiscountedPrincipalPath
        }
        $ownershipSetupSummary = New-ShareSurferStartupOwnershipSetupSummary `
            -OwnerMappingPath $OwnerMappingPath `
            -OwnershipEnrichmentPath $OwnershipEnrichmentPath `
            -OwnershipContextPath $OwnershipContextPath `
            -OwnershipRelationshipPath $OwnershipRelationshipPath `
            -OwnershipImportManifestPath $OwnershipImportManifestPath
    }

    if (@('Permissive', 'Nonpermissive') -notcontains $EnvironmentMode) {
        throw "Unsupported startup path: $EnvironmentMode"
    }

    if ($EnvironmentMode -eq 'Nonpermissive' -and [string]::IsNullOrWhiteSpace($HandoffPath)) {
        $HandoffPath = Join-Path (Join-Path (Split-Path -Parent $InputRoot) 'handoff') 'scan-001.zip'
    }

    $cleanTargetPaths = @($TargetPath | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { [string]$_ })
    if ($cleanTargetPaths.Count -eq 0) {
        throw 'Start-ShareSurferStartup needs at least one -TargetPath value or a startup config with targetPaths. Use -Interactive to be prompted for one.'
    }

    if ((Test-Path -LiteralPath $SaveConfigPath -PathType Leaf) -and -not $Force -and -not ([string]::Equals((ConvertTo-ShareSurferAssistantComparablePath -Path $SaveConfigPath), (ConvertTo-ShareSurferAssistantComparablePath -Path $ConfigPath), [System.StringComparison]::OrdinalIgnoreCase))) {
        throw "ShareSurfer startup config already exists: $SaveConfigPath. Use -Force to overwrite it."
    }

    $unblockSummary = Invoke-ShareSurferStartupUnblock -ReleaseRoot $ReleaseRoot -SkipUnblock:$SkipUnblock

    $assistantSummary = Start-ShareSurferOperatorAssistant `
        -ReleaseRoot $ReleaseRoot `
        -InputRoot $InputRoot `
        -ExportPath $ExportPath `
        -StandaloneDashboardPath $StandaloneDashboardPath `
        -TargetPath $cleanTargetPaths `
        -ObsAttribute $ObsAttribute `
        -AdLookupMode $AdLookupMode `
        -ManagerIdentityFormat $ManagerIdentityFormat `
        -AclExportMode $AclExportMode `
        -OwnerMappingPath $OwnerMappingPath `
        -OwnershipEnrichmentPath $OwnershipEnrichmentPath `
        -OwnershipContextPath $OwnershipContextPath `
        -OwnershipRelationshipPath $OwnershipRelationshipPath `
        -OwnershipImportManifestPath $OwnershipImportManifestPath `
        -DiscountedPrincipalPath $DiscountedPrincipalPath `
        -CreateOwnerMappingDraftAfterScan:([bool]$ownershipSetupSummary.CreateOwnerMappingDraftAfterScan) `
        -OwnerMappingDraftPath ([string]$ownershipSetupSummary.OwnerMappingDraftPath) `
        -OwnerMappingDraftReusableCommandPath ([string]$ownershipSetupSummary.OwnerMappingDraftReusableCommandPath) `
        -PlanPath $PlanPath `
        -ReusableCommandPath $ReusableCommandPath `
        -IncludeFiles:$IncludeFiles `
        -IncludeSharePermissionDiagnostics $IncludeSharePermissionDiagnostics `
        -SkipIdentityEnrichment:$SkipIdentityEnrichment `
        -DisableOptionalInputDiscovery:($configOptionalInputsLoaded -or $deferOwnershipInputs -or $DisableOptionalInputDiscovery) `
        -NoCreateMissingFolders:$NoCreateMissingFolders `
        -Force:$Force

    $optionalInputDiscovery = New-ShareSurferOptionalInputDiscoveryReport `
        -InputRoot $InputRoot `
        -OwnerMappingPath $OwnerMappingPath `
        -OwnershipEnrichmentPath $OwnershipEnrichmentPath `
        -OwnershipContextPath $OwnershipContextPath `
        -OwnershipRelationshipPath $OwnershipRelationshipPath `
        -OwnershipImportManifestPath $OwnershipImportManifestPath `
        -DiscountedPrincipalPath $DiscountedPrincipalPath

    $startupReplayCommand = 'Start-ShareSurferStartup -ConfigPath {0} -Force' -f (ConvertTo-ShareSurferPowerShellLiteral -Value $SaveConfigPath)
    $scriptReplayCommand = '& {0} -ConfigPath {1} -Force' -f (ConvertTo-ShareSurferPowerShellLiteral -Value (Join-ShareSurferAssistantPathText -Root $ReleaseRoot -Child 'Start-ShareSurfer.ps1')), (ConvertTo-ShareSurferPowerShellLiteral -Value $SaveConfigPath)

    $startupConfig = [ordered]@{
        version = 1
        createdAt = (Get-Date).ToUniversalTime().ToString('o')
        environmentMode = $EnvironmentMode
        releaseRoot = $ReleaseRoot
        inputRoot = $InputRoot
        exportPath = $ExportPath
        standaloneDashboardPath = $StandaloneDashboardPath
        targetPaths = @($cleanTargetPaths)
        obsAttribute = $ObsAttribute
        adLookupMode = $AdLookupMode
        managerIdentityFormat = $ManagerIdentityFormat
        aclExportMode = $AclExportMode
        consoleMode = $ConsoleMode
        includeFiles = [bool]$IncludeFiles
        includeSharePermissionDiagnostics = [bool]$IncludeSharePermissionDiagnostics
        skipIdentityEnrichment = [bool]$SkipIdentityEnrichment
        skipUnblock = [bool]$SkipUnblock
        disableOptionalInputDiscovery = [bool]($configOptionalInputsLoaded -or $deferOwnershipInputs -or $DisableOptionalInputDiscovery)
        optionalInputs = [ordered]@{
            ownerMappingPath = $OwnerMappingPath
            ownershipEnrichmentPath = $OwnershipEnrichmentPath
            ownershipContextPath = $OwnershipContextPath
            ownershipRelationshipPath = $OwnershipRelationshipPath
            ownershipImportManifestPath = $OwnershipImportManifestPath
            discountedPrincipalPath = $DiscountedPrincipalPath
        }
        ownershipSetup = $ownershipSetupSummary
        optionalInputDiscovery = $optionalInputDiscovery
        nonpermissive = [ordered]@{
            handoffPath = $HandoffPath
            note = 'Use this when the collector host must package the validated export for approved transfer to a dashboard/review host.'
        }
        generatedFiles = [ordered]@{
            startupConfigPath = $SaveConfigPath
            operatorPlanPath = $assistantSummary.PlanPath
            operatorReusableCommandPath = $assistantSummary.ReusableCommandPath
            ownershipImportDefinitionPath = [string]$ownershipSetupSummary.OwnershipImportDefinitionPath
            ownershipImportReusableCommandPath = [string]$ownershipSetupSummary.OwnershipImportReusableCommandPath
            ownerMappingDraftPath = [string]$ownershipSetupSummary.OwnerMappingDraftPath
            ownerMappingDraftReusableCommandPath = [string]$ownershipSetupSummary.OwnerMappingDraftReusableCommandPath
        }
        commands = [ordered]@{
            startupReplay = $startupReplayCommand
            startupScriptReplay = $scriptReplayCommand
            operatorRerun = $assistantSummary.ReusableCommandPath
        }
        stopGates = @(
            'If share-level permissions are missing or suspicious, open share-permission-diagnostics\share_permission_diagnostics.md before owner signoff.',
            'Run and review Test-ShareSurferExport before treating the export as complete.',
            'Review evidence_confidence.csv, collection_errors.csv, shares.csv PartialData, and scan_manifest.csv before owner signoff.',
            'Confirm the selected ObsAttribute is the intended directory OBS/OID source.',
            'Package the standalone dashboard from the validated export folder, not the release template folder.'
        )
    }

    Ensure-ShareSurferLocalFileParentDirectory -Path $SaveConfigPath -Purpose 'startup config' -NoCreateMissingFolders:$NoCreateMissingFolders | Out-Null
    Set-Content -LiteralPath $SaveConfigPath -Value ($startupConfig | ConvertTo-Json -Depth 8) -Encoding UTF8

    $postStartupSummary = [pscustomobject]@{
        ReviewShown = [bool]$interactiveReviewShown
        RerunLaunched = $false
    }
    if ($Interactive) {
        Write-ShareSurferConsoleLines -Lines @(
            '',
            'First-scan startup files are ready:',
            ('  Startup config: {0}' -f $SaveConfigPath),
            ('  Operator plan:  {0}' -f [string]$assistantSummary.PlanPath),
            ('  Rerun script:   {0}' -f [string]$assistantSummary.ReusableCommandPath)
        )
        if ($interactiveRunNow) {
            Write-ShareSurferConsoleLines -Lines @(('Running the reviewed first-scan workflow: {0}' -f [string]$assistantSummary.ReusableCommandPath))
            & ([string]$assistantSummary.ReusableCommandPath) | Out-Host
            $postStartupSummary.RerunLaunched = $true
        }
    }

    [pscustomobject]@{
        Cancelled = $false
        StartupConfigPath = $SaveConfigPath
        EnvironmentMode = $EnvironmentMode
        ReleaseRoot = $ReleaseRoot
        InputRoot = $InputRoot
        ExportPath = $ExportPath
        StandaloneDashboardPath = $StandaloneDashboardPath
        TargetPath = @($cleanTargetPaths)
        ObsAttribute = $ObsAttribute
        AdLookupMode = $AdLookupMode
        ManagerIdentityFormat = $ManagerIdentityFormat
        AclExportMode = $AclExportMode
        ConsoleMode = $ConsoleMode
        OwnerMappingPath = $OwnerMappingPath
        OwnershipEnrichmentPath = $OwnershipEnrichmentPath
        OwnershipContextPath = $OwnershipContextPath
        OwnershipRelationshipPath = $OwnershipRelationshipPath
        OwnershipImportManifestPath = $OwnershipImportManifestPath
        DiscountedPrincipalPath = $DiscountedPrincipalPath
        OwnershipSetup = $ownershipSetupSummary
        IncludeFiles = [bool]$IncludeFiles
        IncludeSharePermissionDiagnostics = [bool]$IncludeSharePermissionDiagnostics
        SkipIdentityEnrichment = [bool]$SkipIdentityEnrichment
        SkipUnblock = [bool]$SkipUnblock
        HandoffPath = $HandoffPath
        UnblockStatus = $unblockSummary.Status
        UnblockFileCount = $unblockSummary.FileCount
        UnblockZoneIdentifierRemovedCount = $unblockSummary.ZoneIdentifierRemovedCount
        OperatorPlanPath = $assistantSummary.PlanPath
        OperatorReusableCommandPath = $assistantSummary.ReusableCommandPath
        OptionalInputDiscovery = $optionalInputDiscovery
        PostStartupReviewShown = [bool]$postStartupSummary.ReviewShown
        PostStartupRerunLaunched = [bool]$postStartupSummary.RerunLaunched
        StartupReplayCommand = $startupReplayCommand
        StartupScriptReplayCommand = $scriptReplayCommand
        StopGates = @($startupConfig.stopGates)
        NextSteps = @(
            'Review the startup JSON config and operator assistant rerun script.',
            'If enabled, review share-permission-diagnostics\share_permission_diagnostics.md for collection method proof.',
            'Run the operator rerun script on the collector host when ready.',
            'Validate the export before packaging or sharing the dashboard.',
            'Reuse the startup JSON config to regenerate the same startup pattern later.'
        )
    }
}

function Get-ShareSurferFirstScanCommandPreview {
    param(
        [Parameter(Mandatory = $true)]
        $State
    )

    $parts = New-Object System.Collections.Generic.List[string]
    $parts.Add('Start-ShareSurferStartup')
    $parts.Add(('-EnvironmentMode {0}' -f (ConvertTo-ShareSurferPowerShellLiteral -Value ([string]$State.EnvironmentMode))))
    $parts.Add(('-ReleaseRoot {0}' -f (ConvertTo-ShareSurferPowerShellLiteral -Value ([string]$State.ReleaseRoot))))
    $parts.Add(('-InputRoot {0}' -f (ConvertTo-ShareSurferPowerShellLiteral -Value ([string]$State.InputRoot))))
    $parts.Add(('-ExportPath {0}' -f (ConvertTo-ShareSurferPowerShellLiteral -Value ([string]$State.ExportPath))))
    $parts.Add(('-StandaloneDashboardPath {0}' -f (ConvertTo-ShareSurferPowerShellLiteral -Value ([string]$State.StandaloneDashboardPath))))
    $parts.Add(('-TargetPath {0}' -f ((@($State.TargetPath) | ForEach-Object { ConvertTo-ShareSurferPowerShellLiteral -Value ([string]$_) }) -join ', ')))
    $parts.Add(('-ObsAttribute {0}' -f (ConvertTo-ShareSurferPowerShellLiteral -Value ([string]$State.ObsAttribute))))
    $parts.Add(('-AdLookupMode {0}' -f (ConvertTo-ShareSurferPowerShellLiteral -Value ([string]$State.AdLookupMode))))
    $parts.Add(('-ManagerIdentityFormat {0}' -f (ConvertTo-ShareSurferPowerShellLiteral -Value ([string]$State.ManagerIdentityFormat))))
    $parts.Add(('-AclExportMode {0}' -f (ConvertTo-ShareSurferPowerShellLiteral -Value ([string]$State.AclExportMode))))
    $parts.Add(('-ConsoleMode {0}' -f (ConvertTo-ShareSurferPowerShellLiteral -Value ([string]$State.ConsoleMode))))
    $parts.Add(('-SaveConfigPath {0}' -f (ConvertTo-ShareSurferPowerShellLiteral -Value ([string]$State.SaveConfigPath))))
    foreach ($optionalInput in @(
        [pscustomobject]@{ Name = 'OwnerMappingPath'; Value = [string]$State.OwnerMappingPath },
        [pscustomobject]@{ Name = 'OwnershipEnrichmentPath'; Value = [string]$State.OwnershipEnrichmentPath },
        [pscustomobject]@{ Name = 'OwnershipContextPath'; Value = [string]$State.OwnershipContextPath },
        [pscustomobject]@{ Name = 'OwnershipRelationshipPath'; Value = [string]$State.OwnershipRelationshipPath },
        [pscustomobject]@{ Name = 'OwnershipImportManifestPath'; Value = [string]$State.OwnershipImportManifestPath },
        [pscustomobject]@{ Name = 'DiscountedPrincipalPath'; Value = [string]$State.DiscountedPrincipalPath }
    )) {
        if (-not [string]::IsNullOrWhiteSpace([string]$optionalInput.Value)) {
            $parts.Add(('-{0} {1}' -f [string]$optionalInput.Name, (ConvertTo-ShareSurferPowerShellLiteral -Value ([string]$optionalInput.Value))))
        }
    }
    if (-not [string]::IsNullOrWhiteSpace([string]$State.HandoffPath)) {
        $parts.Add(('-HandoffPath {0}' -f (ConvertTo-ShareSurferPowerShellLiteral -Value ([string]$State.HandoffPath))))
    }
    if ([bool]$State.IncludeFiles) { $parts.Add('-IncludeFiles') }
    if (-not [bool]$State.IncludeSharePermissionDiagnostics) { $parts.Add('-IncludeSharePermissionDiagnostics:$false') }
    if ([bool]$State.SkipIdentityEnrichment) { $parts.Add('-SkipIdentityEnrichment') }
    if ([bool]$State.SkipUnblock) { $parts.Add('-SkipUnblock') }
    if ([bool]$State.DeferOwnershipInputs) { $parts.Add('-SkipOwnershipSetup') }
    $ownershipSetupSummary = $State.OwnershipSetupSummary
    if ($null -ne $ownershipSetupSummary -and [bool]$ownershipSetupSummary.CreateOwnerMappingDraftAfterScan) {
        $parts.Add('-CreateOwnerMappingDraftAfterScan')
        if (-not [string]::IsNullOrWhiteSpace([string]$ownershipSetupSummary.OwnerMappingDraftPath)) {
            $parts.Add(('-OwnerMappingDraftPath {0}' -f (ConvertTo-ShareSurferPowerShellLiteral -Value ([string]$ownershipSetupSummary.OwnerMappingDraftPath))))
        }
        if (-not [string]::IsNullOrWhiteSpace([string]$ownershipSetupSummary.OwnerMappingDraftReusableCommandPath)) {
            $parts.Add(('-OwnerMappingDraftReusableCommandPath {0}' -f (ConvertTo-ShareSurferPowerShellLiteral -Value ([string]$ownershipSetupSummary.OwnerMappingDraftReusableCommandPath))))
        }
    }
    $parts.Add('-DisableOptionalInputDiscovery')
    $parts.ToArray() -join ' '
}

function Get-ShareSurferFirstScanReviewScreen {
    param(
        [Parameter(Mandatory = $true)]
        $State
    )

    $reviewLocation = if ([string]$State.EnvironmentMode -eq 'Nonpermissive') { 'Separate review computer after an approved handoff' } else { 'This computer' }
    $identityText = if ([bool]$State.SkipIdentityEnrichment) { 'No' } else { 'Yes' }
    $diagnosticsText = if ([bool]$State.IncludeSharePermissionDiagnostics) { 'Yes' } else { 'No' }
    $fileText = if ([bool]$State.IncludeFiles) { 'Folders and files' } else { 'Folders only' }
    $ownershipText = if ([bool]$State.DeferOwnershipInputs) { 'Deferred until the basic scan succeeds' } else { 'Use selected or discovered ownership inputs' }

    @(
        '',
        'First-scan review',
        ('  Target: {0}' -f (@($State.TargetPath) -join '; ')),
        ('  Review results: {0}' -f $reviewLocation),
        ('  Collect: {0}' -f $fileText),
        ('  Permission detail: {0}' -f [string]$State.AclExportMode),
        ('  Collect identity details: {0}' -f $identityText),
        ('  Run permission diagnostics: {0}' -f $diagnosticsText),
        ('  Ownership or HR data: {0}' -f $ownershipText),
        ('  Export folder: {0}' -f [string]$State.ExportPath),
        ('  Dashboard folder: {0}' -f [string]$State.StandaloneDashboardPath),
        '',
        'Nothing changes share or file permissions. Save plan writes reviewable JSON and a rerun script; Run now writes them and then starts the saved workflow.',
        $(if ([string]$State.EnvironmentMode -eq 'Nonpermissive') { 'Collection still runs on this computer. After validation, package and transfer the evidence through your approved process.' } else { 'Validation and dashboard review stay on this computer unless you later prepare a handoff.' })
    )
}

function Read-ShareSurferFirstScanCustomization {
    param(
        [Parameter(Mandatory = $true)]
        $State,

        [ValidateSet('Auto', 'Enhanced', 'Plain')]
        [string] $ConsoleMode = 'Plain',

        [switch] $NoCreateMissingFolders,

        [switch] $Force
    )

    while ($true) {
        $menu = Read-ShareSurferConsoleChoice -Title 'Customize first-scan settings' -Options @(
            New-ShareSurferConsoleChoiceOption -Value 'Scan' -Label 'Scan and directory details' -Description 'Permission detail, folders/files, identity lookup, diagnostics, OBS attribute, and AD lookup.'
            New-ShareSurferConsoleChoiceOption -Value 'Paths' -Label 'Output paths' -Description 'Export and standalone dashboard folders.'
            New-ShareSurferConsoleChoiceOption -Value 'Ownership' -Label 'Ownership or HR data' -Description 'Defer it, use discovered files, or build enrichment now.'
            New-ShareSurferConsoleChoiceOption -Value 'Continue' -Label 'Continue to review' -Description 'Keep these custom settings and review the plan.'
        ) -DefaultValue 'Continue' -HelpText 'Only change settings your environment requires. B returns to the recommended/custom choice.' -AllowBack -AllowQuit -ConsoleMode $ConsoleMode

        if ($menu.Action -eq 'Cancel') { return [pscustomobject]@{ Action = 'Cancel' } }
        if ($menu.Action -eq 'Back') { return [pscustomobject]@{ Action = 'Back' } }
        if ($menu.Action -ne 'Select') { continue }
        if ([string]$menu.SelectedValue -eq 'Continue') { return [pscustomobject]@{ Action = 'Continue' } }

        if ([string]$menu.SelectedValue -eq 'Scan') {
            $acl = Read-ShareSurferConsoleChoice -Title 'Permission detail' -Options @(
                New-ShareSurferConsoleChoiceOption -Value 'Compact' -Label 'Recommended (compact)' -Description 'Keep explicit and boundary permissions while suppressing repeated inherited rows.'
                New-ShareSurferConsoleChoiceOption -Value 'FullEffective' -Label 'Full effective detail' -Description 'Write every effective permission row at every path; output can be much larger.'
            ) -DefaultValue ([string]$State.AclExportMode) -AllowBack -AllowQuit -ConsoleMode $ConsoleMode
            if ($acl.Action -eq 'Cancel') { return [pscustomobject]@{ Action = 'Cancel' } }
            if ($acl.Action -eq 'Back') { continue }
            $State.AclExportMode = [string]$acl.SelectedValue

            $files = Read-ShareSurferConsoleBoolean -Prompt 'Collect file rows as well as folders?' -Default ([bool]$State.IncludeFiles) -HelpText 'Folder-only collection is the faster recommended first scan.' -AllowBack -AllowQuit -ConsoleMode $ConsoleMode
            if ($files.Action -eq 'Cancel') { return [pscustomobject]@{ Action = 'Cancel' } }
            if ($files.Action -eq 'Back') { continue }
            $State.IncludeFiles = [bool]$files.Value

            $identity = Read-ShareSurferConsoleBoolean -Prompt 'Collect identity and manager details?' -Default (-not [bool]$State.SkipIdentityEnrichment) -HelpText 'Recommended when the collector can query directory data.' -AllowBack -AllowQuit -ConsoleMode $ConsoleMode
            if ($identity.Action -eq 'Cancel') { return [pscustomobject]@{ Action = 'Cancel' } }
            if ($identity.Action -eq 'Back') { continue }
            $State.SkipIdentityEnrichment = (-not [bool]$identity.Value)

            $diagnostics = Read-ShareSurferConsoleBoolean -Prompt 'Run share-permission diagnostics?' -Default ([bool]$State.IncludeSharePermissionDiagnostics) -HelpText 'Recommended. It adds collection-method evidence and may take longer on remote or restricted shares.' -AllowBack -AllowQuit -ConsoleMode $ConsoleMode
            if ($diagnostics.Action -eq 'Cancel') { return [pscustomobject]@{ Action = 'Cancel' } }
            if ($diagnostics.Action -eq 'Back') { continue }
            $State.IncludeSharePermissionDiagnostics = [bool]$diagnostics.Value

            $ad = Read-ShareSurferConsoleChoice -Title 'Directory lookup method' -Options @(
                New-ShareSurferConsoleChoiceOption -Value 'Auto' -Label 'Automatic (recommended)' -Description 'Try the AD module, then supported fallback lookup methods.'
                New-ShareSurferConsoleChoiceOption -Value 'ActiveDirectory' -Label 'Active Directory module only'
                New-ShareSurferConsoleChoiceOption -Value 'Ldap' -Label 'Built-in LDAP lookup'
                New-ShareSurferConsoleChoiceOption -Value 'DirectoryOnly' -Label 'Do not query AD' -Description 'Use only local or exported evidence.'
            ) -DefaultValue ([string]$State.AdLookupMode) -AllowBack -AllowQuit -ConsoleMode $ConsoleMode
            if ($ad.Action -eq 'Cancel') { return [pscustomobject]@{ Action = 'Cancel' } }
            if ($ad.Action -eq 'Back') { continue }
            $State.AdLookupMode = [string]$ad.SelectedValue

            $obs = Read-ShareSurferConsoleText -Prompt 'Directory attribute used for OBS or org context' -Default ([string]$State.ObsAttribute) -HelpText 'Press Enter to keep the current attribute. Use ? for help, B to return, or Q to cancel.' -AllowBack -AllowQuit
            if ($obs.Action -eq 'Cancel') { return [pscustomobject]@{ Action = 'Cancel' } }
            if ($obs.Action -eq 'Back') { continue }
            $State.ObsAttribute = [string]$obs.Value
            continue
        }

        if ([string]$menu.SelectedValue -eq 'Paths') {
            $export = Read-ShareSurferConsoleText -Prompt 'Export folder' -Default ([string]$State.ExportPath) -AllowBack -AllowQuit -Validate {
                param($value)
                if ([string]::IsNullOrWhiteSpace([string]$value)) { return 'Enter an export folder.' }
                ''
            }
            if ($export.Action -eq 'Cancel') { return [pscustomobject]@{ Action = 'Cancel' } }
            if ($export.Action -eq 'Back') { continue }
            $State.ExportPath = [string]$export.Value

            $dashboard = Read-ShareSurferConsoleText -Prompt 'Standalone dashboard folder' -Default ([string]$State.StandaloneDashboardPath) -AllowBack -AllowQuit -Validate {
                param($value)
                if ([string]::IsNullOrWhiteSpace([string]$value)) { return 'Enter a dashboard output folder.' }
                ''
            }
            if ($dashboard.Action -eq 'Cancel') { return [pscustomobject]@{ Action = 'Cancel' } }
            if ($dashboard.Action -eq 'Back') { continue }
            $State.StandaloneDashboardPath = [string]$dashboard.Value

            continue
        }

        if ([string]$menu.SelectedValue -eq 'Ownership') {
            $ownership = Read-ShareSurferConsoleChoice -Title 'Ownership or HR data for this first scan' -Options @(
                New-ShareSurferConsoleChoiceOption -Value 'Defer' -Label 'Defer until after the basic scan (recommended)' -Description 'The scan runs without optional ownership files.'
                New-ShareSurferConsoleChoiceOption -Value 'Discovered' -Label 'Use files already under the input folder' -Description 'Use recognized ownership files and skip any that are missing.'
                New-ShareSurferConsoleChoiceOption -Value 'Build' -Label 'Build ownership enrichment now' -Description 'Open the guided CSV ownership-import workflow.'
            ) -DefaultValue $(if ([bool]$State.DeferOwnershipInputs) { 'Defer' } else { 'Discovered' }) -AllowBack -AllowQuit -ConsoleMode $ConsoleMode
            if ($ownership.Action -eq 'Cancel') { return [pscustomobject]@{ Action = 'Cancel' } }
            if ($ownership.Action -eq 'Back') { continue }

            if ([string]$ownership.SelectedValue -eq 'Defer') {
                $State.DeferOwnershipInputs = $true
                $State.OwnerMappingPath = ''
                $State.OwnershipEnrichmentPath = ''
                $State.OwnershipContextPath = ''
                $State.OwnershipRelationshipPath = ''
                $State.OwnershipImportManifestPath = ''
                $State.DiscountedPrincipalPath = ''
                $State.OwnershipSetupSummary = New-ShareSurferStartupOwnershipSetupSummary -Skipped
                continue
            }

            $State.DeferOwnershipInputs = $false
            $State.OwnerMappingPath = Resolve-ShareSurferOptionalInputPath -InputRoot ([string]$State.InputRoot) -FileName 'owner-mapping.csv' -Value ([string]$State.OwnerMappingPath)
            $State.OwnershipEnrichmentPath = Resolve-ShareSurferOptionalInputPath -InputRoot ([string]$State.InputRoot) -FileName 'ownership-enrichment.csv' -Value ([string]$State.OwnershipEnrichmentPath)
            $State.OwnershipContextPath = Resolve-ShareSurferOptionalInputPath -InputRoot ([string]$State.InputRoot) -FileName 'ownership_context.csv' -Value ([string]$State.OwnershipContextPath)
            $State.OwnershipRelationshipPath = Resolve-ShareSurferOptionalInputPath -InputRoot ([string]$State.InputRoot) -FileName 'ownership_relationships.csv' -Value ([string]$State.OwnershipRelationshipPath)
            $State.OwnershipImportManifestPath = Resolve-ShareSurferOptionalInputPath -InputRoot ([string]$State.InputRoot) -FileName 'ownership_import_manifest.csv' -Value ([string]$State.OwnershipImportManifestPath)
            $State.DiscountedPrincipalPath = Resolve-ShareSurferOptionalInputPath -InputRoot ([string]$State.InputRoot) -FileName 'discounted-principals.csv' -Value ([string]$State.DiscountedPrincipalPath)
            if ([string]$ownership.SelectedValue -eq 'Build') {
                $summary = Invoke-ShareSurferStartupOwnershipSetup `
                    -InputRoot ([string]$State.InputRoot) `
                    -OwnerMappingPath ([string]$State.OwnerMappingPath) `
                    -OwnershipEnrichmentPath ([string]$State.OwnershipEnrichmentPath) `
                    -OwnershipContextPath ([string]$State.OwnershipContextPath) `
                    -OwnershipRelationshipPath ([string]$State.OwnershipRelationshipPath) `
                    -OwnershipImportManifestPath ([string]$State.OwnershipImportManifestPath) `
                    -ObsAttribute ([string]$State.ObsAttribute) `
                    -AdLookupMode ([string]$State.AdLookupMode) `
                    -BuildOwnershipEnrichmentNow `
                    -NoCreateMissingFolders:$NoCreateMissingFolders `
                    -Force:$Force `
                    -ConsoleMode $ConsoleMode
                if ($null -ne $summary.PSObject.Properties['Cancelled'] -and [bool]$summary.Cancelled) {
                    return [pscustomobject]@{ Action = 'Cancel' }
                }
                $State.OwnershipSetupSummary = $summary
                $State.OwnerMappingPath = [string]$summary.OwnerMappingPath
                $State.OwnershipEnrichmentPath = [string]$summary.OwnershipEnrichmentPath
                $State.OwnershipContextPath = [string]$summary.OwnershipContextPath
                $State.OwnershipRelationshipPath = [string]$summary.OwnershipRelationshipPath
                $State.OwnershipImportManifestPath = [string]$summary.OwnershipImportManifestPath
            }
            else {
                $State.OwnershipSetupSummary = New-ShareSurferStartupOwnershipSetupSummary `
                    -OwnerMappingPath ([string]$State.OwnerMappingPath) `
                    -OwnershipEnrichmentPath ([string]$State.OwnershipEnrichmentPath) `
                    -OwnershipContextPath ([string]$State.OwnershipContextPath) `
                    -OwnershipRelationshipPath ([string]$State.OwnershipRelationshipPath) `
                    -OwnershipImportManifestPath ([string]$State.OwnershipImportManifestPath)
            }
        }
    }
}

function Read-ShareSurferFirstScanConfiguration {
    param(
        [Parameter(Mandatory = $true)]
        $State,

        [ValidateSet('Auto', 'Enhanced', 'Plain')]
        [string] $ConsoleMode = 'Plain',

        [switch] $NoCreateMissingFolders,

        [switch] $Force
    )

    $stage = 0
    $settingsMode = 'Recommended'
    while ($stage -lt 4) {
        if ($stage -eq 0) {
            Write-ShareSurferStartupStepHeader -Step 1 -Total 4 -Title 'What should ShareSurfer scan?'
            $target = Read-ShareSurferConsoleText -Prompt 'UNC share or folder path' -Default (@($State.TargetPath) -join '; ') -HelpText 'Start with one known small or medium share, such as \\files01\Finance. Enter accepts the current target; B returns home; Q cancels.' -AllowBack -AllowQuit -Validate {
                param($value)
                if ([string]::IsNullOrWhiteSpace([string]$value)) { return 'Enter one share or folder path to scan.' }
                ''
            }
            if ($target.Action -in @('Back', 'Cancel')) { return [pscustomobject]@{ Action = 'Cancel'; State = $State } }
            $State.TargetPath = @(([string]$target.Value) -split ';' | ForEach-Object { ([string]$_).Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
            $stage++
            continue
        }

        if ($stage -eq 1) {
            Write-ShareSurferStartupStepHeader -Step 2 -Total 4 -Title 'Where will results be reviewed?'
            $location = Read-ShareSurferConsoleChoice -Title 'Review location' -Options @(
                New-ShareSurferConsoleChoiceOption -Value 'Permissive' -Label 'On this computer (recommended)' -Description 'Collect, validate, and package the dashboard on the collector computer.'
                New-ShareSurferConsoleChoiceOption -Value 'Nonpermissive' -Label 'On a separate review computer' -Description 'Collection still runs here; after validation, transfer the evidence through your approved process.'
            ) -DefaultValue ([string]$State.EnvironmentMode) -AllowBack -AllowQuit -ConsoleMode $ConsoleMode
            if ($location.Action -eq 'Cancel') { return [pscustomobject]@{ Action = 'Cancel'; State = $State } }
            if ($location.Action -eq 'Back') { $stage--; continue }
            $State.EnvironmentMode = [string]$location.SelectedValue
            if ([string]$State.EnvironmentMode -eq 'Nonpermissive' -and [string]::IsNullOrWhiteSpace([string]$State.HandoffPath)) {
                $State.HandoffPath = Join-Path (Join-Path (Split-Path -Parent ([string]$State.InputRoot)) 'handoff') 'scan-001.zip'
            }
            $stage++
            continue
        }

        if ($stage -eq 2) {
            Write-ShareSurferStartupStepHeader -Step 3 -Total 4 -Title 'Choose recommended or custom settings'
            $settings = Read-ShareSurferConsoleChoice -Title 'First-scan settings' -Options @(
                New-ShareSurferConsoleChoiceOption -Value 'Recommended' -Label 'Continue with recommended settings' -Description 'Folders only, compact permissions, identity details and diagnostics on, ownership data deferred.'
                New-ShareSurferConsoleChoiceOption -Value 'Customize' -Label 'Customize technical settings' -Description 'Change scan detail, lookup method, output paths, or optional ownership data.'
            ) -DefaultValue $settingsMode -AllowBack -AllowQuit -ConsoleMode $ConsoleMode
            if ($settings.Action -eq 'Cancel') { return [pscustomobject]@{ Action = 'Cancel'; State = $State } }
            if ($settings.Action -eq 'Back') { $stage--; continue }
            $settingsMode = [string]$settings.SelectedValue
            if ([string]$settings.SelectedValue -eq 'Recommended') {
                $State.AclExportMode = 'Compact'
                $State.IncludeFiles = $false
                $State.SkipIdentityEnrichment = $false
                $State.IncludeSharePermissionDiagnostics = $true
                $State.DeferOwnershipInputs = $true
                $State.OwnerMappingPath = ''
                $State.OwnershipEnrichmentPath = ''
                $State.OwnershipContextPath = ''
                $State.OwnershipRelationshipPath = ''
                $State.OwnershipImportManifestPath = ''
                $State.DiscountedPrincipalPath = ''
                $State.OwnershipSetupSummary = New-ShareSurferStartupOwnershipSetupSummary -Skipped
                $stage++
                continue
            }

            $custom = Read-ShareSurferFirstScanCustomization -State $State -ConsoleMode $ConsoleMode -NoCreateMissingFolders:$NoCreateMissingFolders -Force:$Force
            if ($custom.Action -eq 'Cancel') { return [pscustomobject]@{ Action = 'Cancel'; State = $State } }
            if ($custom.Action -eq 'Back') { continue }
            $stage++
            continue
        }

        Write-ShareSurferStartupStepHeader -Step 4 -Total 4 -Title 'Review and act'
        Write-ShareSurferConsoleLines -Lines (Get-ShareSurferFirstScanReviewScreen -State $State)
        $review = Read-ShareSurferConsoleChoice -Title 'What should ShareSurfer do?' -Options @(
            New-ShareSurferConsoleChoiceOption -Value 'Run' -Label 'Run now' -Description 'Write the saved plan and start its diagnostic, scan, validation, and dashboard workflow.'
            New-ShareSurferConsoleChoiceOption -Value 'Save' -Label 'Save plan and return home (recommended)' -Description 'Write the config, plan, and rerun script without starting collection.'
            New-ShareSurferConsoleChoiceOption -Value 'Details' -Label 'Show technical command' -Description 'Display the exact non-interactive startup command for review or copy/paste.'
        ) -DefaultValue 'Save' -AllowBack -AllowQuit -ConsoleMode $ConsoleMode
        if ($review.Action -eq 'Cancel') { return [pscustomobject]@{ Action = 'Cancel'; State = $State } }
        if ($review.Action -eq 'Back') { $stage--; continue }
        if ([string]$review.SelectedValue -eq 'Details') {
            Write-ShareSurferConsoleLines -Lines @('', 'Technical command', ('  {0}' -f (Get-ShareSurferFirstScanCommandPreview -State $State)))
            continue
        }
        $State.RunNow = ([string]$review.SelectedValue -eq 'Run')
        return [pscustomobject]@{ Action = 'Continue'; State = $State }
    }
}

function New-ShareSurferStartupOwnershipSetupSummary {
    param(
        [string] $OwnerMappingPath = '',

        [string] $OwnershipEnrichmentPath = '',

        [string] $OwnershipContextPath = '',

        [string] $OwnershipRelationshipPath = '',

        [string] $OwnershipImportManifestPath = '',

        [switch] $Skipped
    )

    [pscustomobject]@{
        Cancelled = $false
        Skipped = [bool]$Skipped
        OwnershipEnrichmentOffered = $false
        OwnershipEnrichmentBuilt = $false
        OwnerMappingDraftOffered = $false
        CreateOwnerMappingDraftAfterScan = $false
        OwnerMappingPath = $OwnerMappingPath
        OwnershipEnrichmentPath = $OwnershipEnrichmentPath
        OwnershipContextPath = $OwnershipContextPath
        OwnershipRelationshipPath = $OwnershipRelationshipPath
        OwnershipImportManifestPath = $OwnershipImportManifestPath
        OwnershipImportDefinitionPath = ''
        OwnershipImportReusableCommandPath = ''
        OwnerMappingDraftPath = ''
        OwnerMappingDraftReusableCommandPath = ''
        Message = ''
    }
}

function Invoke-ShareSurferStartupOwnershipSetup {
    param(
        [string] $InputRoot = '',

        [string] $OwnerMappingPath = '',

        [string] $OwnershipEnrichmentPath = '',

        [string] $OwnershipContextPath = '',

        [string] $OwnershipRelationshipPath = '',

        [string] $OwnershipImportManifestPath = '',

        [string] $ObsAttribute = 'extensionAttribute10',

        [ValidateSet('Auto', 'ActiveDirectory', 'Ldap', 'DirectoryOnly')]
        [string] $AdLookupMode = 'Auto',

        [switch] $BuildOwnershipEnrichmentNow,

        [switch] $SkipOwnershipEnrichmentOffer,

        [switch] $SkipOwnershipSetup,

        [switch] $NoCreateMissingFolders,

        [switch] $Force,

        [ValidateSet('Auto', 'Enhanced', 'Plain')]
        [string] $ConsoleMode = 'Plain'
    )

    $summary = New-ShareSurferStartupOwnershipSetupSummary `
        -OwnerMappingPath $OwnerMappingPath `
        -OwnershipEnrichmentPath $OwnershipEnrichmentPath `
        -OwnershipContextPath $OwnershipContextPath `
        -OwnershipRelationshipPath $OwnershipRelationshipPath `
        -OwnershipImportManifestPath $OwnershipImportManifestPath `
        -Skipped:$SkipOwnershipSetup

    if ($SkipOwnershipSetup) {
        $summary.Message = 'Ownership setup prompts were skipped.'
        return $summary
    }

    $expectedOwnerMappingPath = Get-ShareSurferOptionalInputExpectedPath -InputRoot $InputRoot -FileName 'owner-mapping.csv'
    $expectedOwnershipEnrichmentPath = Get-ShareSurferOptionalInputExpectedPath -InputRoot $InputRoot -FileName 'ownership-enrichment.csv'
    $expectedOwnershipContextPath = Get-ShareSurferOptionalInputExpectedPath -InputRoot $InputRoot -FileName 'ownership_context.csv'
    $expectedOwnershipRelationshipPath = Get-ShareSurferOptionalInputExpectedPath -InputRoot $InputRoot -FileName 'ownership_relationships.csv'
    $expectedOwnershipImportManifestPath = Get-ShareSurferOptionalInputExpectedPath -InputRoot $InputRoot -FileName 'ownership_import_manifest.csv'

    $enrichmentExists = (Test-ShareSurferOptionalInputFile -Path $OwnershipEnrichmentPath) -or (Test-ShareSurferOptionalInputFile -Path $expectedOwnershipEnrichmentPath)
    if (-not $enrichmentExists) {
        $summary.OwnershipEnrichmentOffered = $true
        $runOwnershipImport = [bool]$BuildOwnershipEnrichmentNow
        if ($SkipOwnershipEnrichmentOffer -and -not $BuildOwnershipEnrichmentNow) {
            $summary.Message = 'Ownership enrichment was not found and was skipped by startup optional-input discovery.'
        }
        elseif (-not $BuildOwnershipEnrichmentNow) {
            Write-Host ''
            Write-Host 'Ownership enrichment was not found. This optional setup can combine HR, OBS, project, or ownership CSVs before the scan.'
            Write-Host 'It can also save a reusable ownership import definition so the interview does not have to be repeated next time.'
            $runOwnershipChoice = Read-ShareSurferStartupBoolean -Prompt 'Build ownership enrichment now from CSV files?' -Value $false -AllowBack -AllowQuit -ConsoleMode $ConsoleMode
            if ($runOwnershipChoice.Action -in @('Back', 'Cancel')) {
                $summary.Cancelled = $true
                $summary.Message = 'Ownership setup was cancelled; no ownership import was started.'
                return $summary
            }
            $runOwnershipImport = [bool]$runOwnershipChoice.Value
        }
        else {
            Write-Host ''
            Write-Host 'Ownership enrichment build was selected from optional-input discovery.'
        }
        if ($runOwnershipImport) {
            $outputPath = if (-not [string]::IsNullOrWhiteSpace($OwnershipEnrichmentPath)) { $OwnershipEnrichmentPath } else { $expectedOwnershipEnrichmentPath }
            $contextOutputPath = if (-not [string]::IsNullOrWhiteSpace($OwnershipContextPath)) { $OwnershipContextPath } else { $expectedOwnershipContextPath }
            $relationshipOutputPath = if (-not [string]::IsNullOrWhiteSpace($OwnershipRelationshipPath)) { $OwnershipRelationshipPath } else { $expectedOwnershipRelationshipPath }
            $manifestOutputPath = if (-not [string]::IsNullOrWhiteSpace($OwnershipImportManifestPath)) { $OwnershipImportManifestPath } else { $expectedOwnershipImportManifestPath }
            $definitionPath = Join-Path $InputRoot 'ownership-import.definition.json'
            $reusableCommandPath = Join-Path $InputRoot 'ownership-import-rerun.ps1'

            try {
                Ensure-ShareSurferLocalDirectory -Path $InputRoot -Purpose 'ownership input' -NoCreateMissingFolders:$NoCreateMissingFolders | Out-Null
                $importSummary = Join-ShareSurferOwnershipSources `
                    -SourceFolder $InputRoot `
                    -BrowseForCsv `
                    -Interactive `
                    -OutputPath $outputPath `
                    -IncludeContextGraph `
                    -ContextOutputPath $contextOutputPath `
                    -RelationshipOutputPath $relationshipOutputPath `
                    -ManifestOutputPath $manifestOutputPath `
                    -DefinitionPath $definitionPath `
                    -ReusableCommandPath $reusableCommandPath `
                    -ObsAttribute $ObsAttribute `
                    -AdLookupMode $AdLookupMode `
                    -Force:$Force

                $summary.OwnershipEnrichmentBuilt = $true
                $summary.OwnershipEnrichmentPath = [string]$importSummary.OutputPath
                $summary.OwnershipContextPath = [string]$importSummary.ContextOutputPath
                $summary.OwnershipRelationshipPath = [string]$importSummary.RelationshipOutputPath
                $summary.OwnershipImportManifestPath = [string]$importSummary.ManifestOutputPath
                $summary.OwnershipImportDefinitionPath = [string]$importSummary.DefinitionPath
                $summary.OwnershipImportReusableCommandPath = [string]$importSummary.ReusableCommandPath
                $summary.Message = 'Ownership enrichment was built before startup continued.'
                Write-Host ('Ownership enrichment ready: {0}' -f $summary.OwnershipEnrichmentPath)
            }
            catch {
                $summary.Message = ('Ownership enrichment setup did not complete: {0}' -f $_.Exception.Message)
                Write-Warning $summary.Message
                foreach ($outputPropertyName in @('OwnershipEnrichmentPath', 'OwnershipContextPath', 'OwnershipRelationshipPath', 'OwnershipImportManifestPath', 'OwnershipImportDefinitionPath', 'OwnershipImportReusableCommandPath')) {
                    $outputProperty = $summary.PSObject.Properties[$outputPropertyName]
                    if ($null -ne $outputProperty -and -not (Test-ShareSurferOptionalInputFile -Path ([string]$outputProperty.Value))) {
                        $outputProperty.Value = ''
                    }
                }
                if ($_.Exception.Message -like '*cancelled by operator*') {
                    $summary.Cancelled = $true
                    return $summary
                }
            }
        }
    }

    $ownerMappingExists = (Test-ShareSurferOptionalInputFile -Path $OwnerMappingPath) -or (Test-ShareSurferOptionalInputFile -Path $expectedOwnerMappingPath)
    if (-not $ownerMappingExists) {
        $summary.OwnerMappingDraftOffered = $true
        Write-Host ''
        Write-Host 'Owner mapping was not found. A useful owner-mapping draft usually needs scan output, so ShareSurfer can create it after the scan finishes.'
        Write-Host 'The draft will still need a person to fill Owner and BusinessUnit before it is used for a final owner/business-unit report.'
        $createDraftChoice = Read-ShareSurferStartupBoolean -Prompt 'Add post-scan owner-mapping draft creation to the generated rerun script?' -Value $true -AllowBack -AllowQuit -ConsoleMode $ConsoleMode
        if ($createDraftChoice.Action -in @('Back', 'Cancel')) {
            $summary.Cancelled = $true
            $summary.Message = 'Ownership setup was cancelled before owner-mapping draft selection.'
            return $summary
        }
        $createDraft = [bool]$createDraftChoice.Value
        if ($createDraft) {
            $summary.CreateOwnerMappingDraftAfterScan = $true
            $summary.OwnerMappingDraftPath = Join-Path $InputRoot 'owner-mapping-draft.csv'
            $summary.OwnerMappingDraftReusableCommandPath = Join-Path $InputRoot 'owner-mapping-draft-rerun.ps1'
            if ([string]::IsNullOrWhiteSpace($summary.Message)) {
                $summary.Message = 'Owner-mapping draft creation will run after the first scan.'
            }
        }
    }

    $summary.OwnerMappingPath = $OwnerMappingPath
    $summary
}

function Invoke-ShareSurferStartupPostPlanHandoff {
    param(
        [Parameter(Mandatory = $true)]
        [string] $StartupConfigPath,

        [Parameter(Mandatory = $true)]
        [string] $OperatorPlanPath,

        [Parameter(Mandatory = $true)]
        [string] $ReusableCommandPath,

        [ValidateSet('Auto', 'Enhanced', 'Plain')]
        [string] $ConsoleMode = 'Plain'
    )

    Write-Host ''
    Write-Host 'ShareSurfer startup files are ready:'
    Write-Host ('  Startup config: {0}' -f $StartupConfigPath)
    Write-Host ('  Operator plan:  {0}' -f $OperatorPlanPath)
    Write-Host ('  Rerun script:    {0}' -f $ReusableCommandPath)

    $reviewShown = $false
    $showGeneratedFilesChoice = Read-ShareSurferStartupBoolean -Prompt 'Show generated startup JSON, scan plan, and rerun script now?' -Value $false -AllowBack -AllowQuit -ConsoleMode $ConsoleMode
    if ($showGeneratedFilesChoice.Action -eq 'Cancel') {
        return [pscustomobject]@{ ReviewShown = $false; RerunLaunched = $false }
    }
    $showGeneratedFiles = [bool]$showGeneratedFilesChoice.Value
    if ($showGeneratedFiles) {
        foreach ($reviewFile in @(
            [pscustomobject]@{ Label = 'Startup JSON config'; Path = $StartupConfigPath },
            [pscustomobject]@{ Label = 'Operator scan plan'; Path = $OperatorPlanPath },
            [pscustomobject]@{ Label = 'Operator rerun script'; Path = $ReusableCommandPath }
        )) {
            Write-Host ''
            Write-Host ('--- {0}: {1} ---' -f $reviewFile.Label, $reviewFile.Path)
            if (Test-Path -LiteralPath $reviewFile.Path -PathType Leaf) {
                Get-Content -LiteralPath $reviewFile.Path | ForEach-Object { Write-Host $_ }
                $reviewShown = $true
            }
            else {
                Write-Warning ('Generated file was not found for review: {0}' -f $reviewFile.Path)
            }
        }
    }

    Write-Host ''
    Write-Host 'The rerun script runs share-permission diagnostics, collection, export validation, and standalone dashboard packaging from the validated export folder.'
    $runNowChoice = Read-ShareSurferStartupBoolean -Prompt 'Run the generated diagnostic/scan/validate/dashboard script now?' -Value $false -AllowBack -AllowQuit -ConsoleMode $ConsoleMode
    if ($runNowChoice.Action -eq 'Cancel') {
        return [pscustomobject]@{ ReviewShown = $reviewShown; RerunLaunched = $false }
    }
    $runNow = [bool]$runNowChoice.Value
    if ($runNow) {
        Write-Host ('Running generated ShareSurfer script: {0}' -f $ReusableCommandPath)
        & $ReusableCommandPath | Out-Host
    }

    [pscustomobject]@{
        ReviewShown = $reviewShown
        RerunLaunched = [bool]$runNow
    }
}

function Invoke-ShareSurferStartupUnblock {
    param(
        [Parameter(Mandatory = $true)]
        [string] $ReleaseRoot,

        [switch] $SkipUnblock
    )

    if ($SkipUnblock) {
        return [pscustomobject]@{
            Status = 'Skipped'
            FileCount = 0
            ZoneIdentifierRemovedCount = 0
            ErrorCount = 0
        }
    }

    $unblockCommand = Get-Command -Name Unblock-File -ErrorAction SilentlyContinue
    if ($null -eq $unblockCommand) {
        return [pscustomobject]@{
            Status = 'Unavailable'
            FileCount = 0
            ZoneIdentifierRemovedCount = 0
            ErrorCount = 0
        }
    }

    if (-not (Test-Path -LiteralPath $ReleaseRoot -PathType Container)) {
        throw "ShareSurfer release root was not found for recursive unblock: $ReleaseRoot"
    }

    $files = @(Get-ChildItem -LiteralPath $ReleaseRoot -Recurse -File -ErrorAction SilentlyContinue | Where-Object {
        @('.ps1', '.psm1', '.psd1') -contains $_.Extension
    })
    $processed = 0
    $streamRemoved = 0
    $errors = 0
    foreach ($file in $files) {
        try {
            $streamStatus = Remove-ShareSurferStartupZoneIdentifierStream -LiteralPath $file.FullName
            if ($streamStatus -eq 'Removed') {
                $streamRemoved++
            }

            Unblock-File -LiteralPath $file.FullName -ErrorAction Stop
            $processed++
        }
        catch {
            $errors++
            Write-Warning ('Unable to unblock {0}: {1}' -f $file.FullName, $_.Exception.Message)
        }
    }

    [pscustomobject]@{
        Status = if ($errors -gt 0) { 'CompletedWithWarnings' } else { 'Completed' }
        FileCount = $processed
        ZoneIdentifierRemovedCount = $streamRemoved
        ErrorCount = $errors
    }
}

function Remove-ShareSurferStartupZoneIdentifierStream {
    param(
        [Parameter(Mandatory = $true)]
        [string] $LiteralPath
    )

    try {
        $zoneStream = Get-Item -LiteralPath $LiteralPath -Stream Zone.Identifier -ErrorAction SilentlyContinue
    }
    catch [System.Management.Automation.ParameterBindingException] {
        return 'Unsupported'
    }
    catch {
        return 'Unavailable'
    }

    if ($null -eq $zoneStream) {
        return 'Absent'
    }

    try {
        Remove-Item -LiteralPath $LiteralPath -Stream Zone.Identifier -ErrorAction Stop
        return 'Removed'
    }
    catch {
        return 'Failed'
    }
}

function Read-ShareSurferStartupChoice {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Prompt,

        [Parameter(Mandatory = $true)]
        [string] $Value,

        [string[]] $Choices = @(),

        [object[]] $Options = @(),

        [ValidateSet('Auto', 'Enhanced', 'Plain')]
        [string] $ConsoleMode = 'Plain',

        [switch] $AllowBack,

        [switch] $AllowQuit
    )

    $choiceOptions = @($Options)
    if ($choiceOptions.Count -eq 0) {
        $choiceOptions = @($Choices | ForEach-Object { New-ShareSurferConsoleChoiceOption -Value ([string]$_) })
    }
    if ($choiceOptions.Count -eq 0) {
        throw "No choices were supplied for prompt: $Prompt"
    }

    Read-ShareSurferConsoleChoice -Title $Prompt -Options $choiceOptions -DefaultValue $Value -ConsoleMode $ConsoleMode -AllowBack:$AllowBack -AllowQuit:$AllowQuit
}

function Read-ShareSurferStartupBoolean {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Prompt,

        [bool] $Value = $false,

        [ValidateSet('Auto', 'Enhanced', 'Plain')]
        [string] $ConsoleMode = 'Plain',

        [switch] $AllowBack,

        [switch] $AllowQuit
    )

    Read-ShareSurferConsoleBoolean -Prompt $Prompt -Default $Value -AllowBack:$AllowBack -AllowQuit:$AllowQuit -ConsoleMode $ConsoleMode
}

function Write-ShareSurferStartupStepHeader {
    param(
        [Parameter(Mandatory = $true)]
        [int] $Step,

        [Parameter(Mandatory = $true)]
        [int] $Total,

        [Parameter(Mandatory = $true)]
        [string] $Title
    )

    Write-ShareSurferConsoleLines -Lines @('', ('--- Step {0}/{1}: {2} ---' -f $Step, $Total, $Title))
}

function Get-ShareSurferStartupSelectionsScreen {
    param(
        [string] $EnvironmentMode = '',

        [string[]] $TargetPath = @(),

        [string] $ExportPath = '',

        [string] $StandaloneDashboardPath = '',

        [string] $ObsAttribute = '',

        [string] $AdLookupMode = '',

        [string] $ManagerIdentityFormat = '',

        [string] $AclExportMode = '',

        [string] $OwnerMappingPath = '',

        [string] $OwnershipEnrichmentPath = '',

        [string] $DiscountedPrincipalPath = '',

        [string] $HandoffPath = '',

        [string] $SaveConfigPath = ''
    )

    $optionalLabel = {
        param($path)
        if ([string]::IsNullOrWhiteSpace([string]$path)) {
            '(none - the scan runs without it)'
        }
        elseif (Test-ShareSurferOptionalInputFile -Path ([string]$path)) {
            [string]$path
        }
        else {
            '{0} (not found yet)' -f [string]$path
        }
    }

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('')
    $lines.Add('Startup selections')
    $lines.Add(('  Startup path: {0}' -f $EnvironmentMode))
    $lines.Add(('  Scan targets: {0}' -f $(if (@($TargetPath).Count -gt 0) { @($TargetPath) -join '; ' } else { '(none yet)' })))
    $lines.Add(('  Export folder: {0}' -f $ExportPath))
    $lines.Add(('  Dashboard folder: {0}' -f $StandaloneDashboardPath))
    $lines.Add(('  OBS attribute: {0}; AD lookup: {1}; manager format: {2}' -f $ObsAttribute, $AdLookupMode, $ManagerIdentityFormat))
    $lines.Add(('  ACL export mode: {0}' -f $(if ([string]::IsNullOrWhiteSpace($AclExportMode)) { '(default)' } else { $AclExportMode })))
    $lines.Add(('  Owner mapping CSV: {0}' -f (& $optionalLabel $OwnerMappingPath)))
    $lines.Add(('  Ownership enrichment CSV: {0}' -f (& $optionalLabel $OwnershipEnrichmentPath)))
    $lines.Add(('  Discounted principals CSV: {0}' -f (& $optionalLabel $DiscountedPrincipalPath)))
    if (-not [string]::IsNullOrWhiteSpace($HandoffPath)) {
        $lines.Add(('  Handoff ZIP: {0}' -f $HandoffPath))
    }
    $lines.Add(('  Startup config will be saved to: {0}' -f $SaveConfigPath))
    $lines.Add('The generated rerun script previews the exact scan command before anything runs.')

    @($lines.ToArray())
}
