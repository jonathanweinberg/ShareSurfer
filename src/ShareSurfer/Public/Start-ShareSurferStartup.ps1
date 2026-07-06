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

        [string] $OwnerMappingPath = '',

        [string] $OwnershipEnrichmentPath = '',

        [string] $OwnershipContextPath = '',

        [string] $OwnershipRelationshipPath = '',

        [string] $OwnershipImportManifestPath = '',

        [string] $DiscountedPrincipalPath = '',

        [string] $HandoffPath = '',

        [string] $PlanPath = '',

        [string] $ReusableCommandPath = '',

        [switch] $IncludeFiles,

        [bool] $IncludeSharePermissionDiagnostics = $true,

        [switch] $SkipIdentityEnrichment,

        [switch] $Interactive,

        [switch] $SkipUnblock,

        [switch] $SkipOwnershipSetup,

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
        if ($null -ne $definition.PSObject.Properties['includeFiles'] -and -not $boundParameters.ContainsKey('IncludeFiles')) { $IncludeFiles = [bool]$definition.includeFiles }
        if ($null -ne $definition.PSObject.Properties['includeSharePermissionDiagnostics'] -and -not $boundParameters.ContainsKey('IncludeSharePermissionDiagnostics')) { $IncludeSharePermissionDiagnostics = [bool]$definition.includeSharePermissionDiagnostics }
        if ($null -ne $definition.PSObject.Properties['skipIdentityEnrichment'] -and -not $boundParameters.ContainsKey('SkipIdentityEnrichment')) { $SkipIdentityEnrichment = [bool]$definition.skipIdentityEnrichment }
        if ($null -ne $definition.PSObject.Properties['skipUnblock'] -and -not $boundParameters.ContainsKey('SkipUnblock')) { $SkipUnblock = [bool]$definition.skipUnblock }
        if ($null -ne $definition.PSObject.Properties['optionalInputs']) {
            $configOptionalInputsLoaded = $true
            if ($null -ne $definition.optionalInputs.PSObject.Properties['ownerMappingPath'] -and -not $boundParameters.ContainsKey('OwnerMappingPath')) { $OwnerMappingPath = [string]$definition.optionalInputs.ownerMappingPath }
            if ($null -ne $definition.optionalInputs.PSObject.Properties['ownershipEnrichmentPath'] -and -not $boundParameters.ContainsKey('OwnershipEnrichmentPath')) { $OwnershipEnrichmentPath = [string]$definition.optionalInputs.ownershipEnrichmentPath }
            if ($null -ne $definition.optionalInputs.PSObject.Properties['ownershipContextPath'] -and -not $boundParameters.ContainsKey('OwnershipContextPath')) { $OwnershipContextPath = [string]$definition.optionalInputs.ownershipContextPath }
            if ($null -ne $definition.optionalInputs.PSObject.Properties['ownershipRelationshipPath'] -and -not $boundParameters.ContainsKey('OwnershipRelationshipPath')) { $OwnershipRelationshipPath = [string]$definition.optionalInputs.ownershipRelationshipPath }
            if ($null -ne $definition.optionalInputs.PSObject.Properties['ownershipImportManifestPath'] -and -not $boundParameters.ContainsKey('OwnershipImportManifestPath')) { $OwnershipImportManifestPath = [string]$definition.optionalInputs.ownershipImportManifestPath }
            if ($null -ne $definition.optionalInputs.PSObject.Properties['discountedPrincipalPath'] -and -not $boundParameters.ContainsKey('DiscountedPrincipalPath')) { $DiscountedPrincipalPath = [string]$definition.optionalInputs.discountedPrincipalPath }
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

    if ($Interactive) {
        Write-ShareSurferStartupStepHeader -Step 1 -Total 4 -Title 'Core scan settings'
        $EnvironmentMode = Read-ShareSurferStartupChoice -Prompt 'Startup path' -Value $EnvironmentMode -Choices @('Permissive', 'Nonpermissive')
        $ReleaseRoot = Read-ShareSurferAssistantText -Prompt 'ShareSurfer release root' -Value $ReleaseRoot
        $InputRoot = Read-ShareSurferAssistantText -Prompt 'Input folder for optional CSVs and startup files' -Value $InputRoot
        $ExportPath = Read-ShareSurferAssistantText -Prompt 'Export folder for this scan' -Value $ExportPath
        $StandaloneDashboardPath = Read-ShareSurferAssistantText -Prompt 'Standalone dashboard output folder' -Value $StandaloneDashboardPath
        if ($TargetPath.Count -eq 0) {
            $targetAnswer = Read-ShareSurferAssistantText -Prompt 'Share or folder path to scan' -Value ''
            if (-not [string]::IsNullOrWhiteSpace($targetAnswer)) {
                $TargetPath = @($targetAnswer)
            }
        }
        $ObsAttribute = Read-ShareSurferAssistantText -Prompt 'OBS attribute' -Value $ObsAttribute
        $AdLookupMode = Read-ShareSurferStartupChoice -Prompt 'AD lookup mode' -Value $AdLookupMode -Choices @('Auto', 'ActiveDirectory', 'Ldap', 'DirectoryOnly')
        $ManagerIdentityFormat = Read-ShareSurferStartupChoice -Prompt 'Manager identity format' -Value $ManagerIdentityFormat -Choices @('MailTo', 'Mail', 'UserPrincipalName', 'SamAccountName', 'DistinguishedName')
        Write-ShareSurferStartupStepHeader -Step 2 -Total 4 -Title 'Optional ownership inputs'
        Write-ShareSurferOptionalInputDiscoverySummary -InputRoot $InputRoot
        $OwnerMappingPath = Read-ShareSurferOptionalInputPath -Prompt 'Owner mapping CSV path' -InputRoot $InputRoot -FileName 'owner-mapping.csv' -Value $OwnerMappingPath
        $OwnershipEnrichmentPath = Read-ShareSurferOptionalInputPath -Prompt 'Ownership enrichment CSV path' -InputRoot $InputRoot -FileName 'ownership-enrichment.csv' -Value $OwnershipEnrichmentPath
        $DiscountedPrincipalPath = Read-ShareSurferOptionalInputPath -Prompt 'Discounted principals CSV path' -InputRoot $InputRoot -FileName 'discounted-principals.csv' -Value $DiscountedPrincipalPath
        Write-ShareSurferStartupStepHeader -Step 3 -Total 4 -Title 'Guided ownership setup'
        $ownershipSetupSummary = Invoke-ShareSurferStartupOwnershipSetup `
            -InputRoot $InputRoot `
            -OwnerMappingPath $OwnerMappingPath `
            -OwnershipEnrichmentPath $OwnershipEnrichmentPath `
            -OwnershipContextPath $OwnershipContextPath `
            -OwnershipRelationshipPath $OwnershipRelationshipPath `
            -OwnershipImportManifestPath $OwnershipImportManifestPath `
            -ObsAttribute $ObsAttribute `
            -AdLookupMode $AdLookupMode `
            -SkipOwnershipSetup:$SkipOwnershipSetup `
            -NoCreateMissingFolders:$NoCreateMissingFolders `
            -Force:$Force
        $OwnerMappingPath = [string]$ownershipSetupSummary.OwnerMappingPath
        $OwnershipEnrichmentPath = [string]$ownershipSetupSummary.OwnershipEnrichmentPath
        $OwnershipContextPath = [string]$ownershipSetupSummary.OwnershipContextPath
        $OwnershipRelationshipPath = [string]$ownershipSetupSummary.OwnershipRelationshipPath
        $OwnershipImportManifestPath = [string]$ownershipSetupSummary.OwnershipImportManifestPath
        if ($EnvironmentMode -eq 'Nonpermissive') {
            if ([string]::IsNullOrWhiteSpace($HandoffPath)) {
                $HandoffPath = Join-Path (Join-Path (Split-Path -Parent $InputRoot) 'handoff') 'scan-001.zip'
            }
            $HandoffPath = Read-ShareSurferAssistantText -Prompt 'Validated export handoff ZIP path' -Value $HandoffPath
        }
        Write-ShareSurferStartupStepHeader -Step 4 -Total 4 -Title 'Scan options and config save'
        $IncludeFiles = Read-ShareSurferStartupBoolean -Prompt 'Include file rows as well as folders?' -Value ([bool]$IncludeFiles)
        $IncludeSharePermissionDiagnostics = Read-ShareSurferStartupBoolean -Prompt 'Run intensive share-permission diagnostics before the scan?' -Value ([bool]$IncludeSharePermissionDiagnostics)
        $SkipIdentityEnrichment = Read-ShareSurferStartupBoolean -Prompt 'Skip identity enrichment?' -Value ([bool]$SkipIdentityEnrichment)
        $SkipUnblock = Read-ShareSurferStartupBoolean -Prompt 'Skip recursive PowerShell file unblock?' -Value ([bool]$SkipUnblock)
        $SaveConfigPath = Read-ShareSurferAssistantText -Prompt 'Save startup JSON config path' -Value $SaveConfigPath
        Write-ShareSurferConsoleLines -Lines (Get-ShareSurferStartupSelectionsScreen `
            -EnvironmentMode $EnvironmentMode `
            -TargetPath @($TargetPath) `
            -ExportPath $ExportPath `
            -StandaloneDashboardPath $StandaloneDashboardPath `
            -ObsAttribute $ObsAttribute `
            -AdLookupMode $AdLookupMode `
            -ManagerIdentityFormat $ManagerIdentityFormat `
            -OwnerMappingPath $OwnerMappingPath `
            -OwnershipEnrichmentPath $OwnershipEnrichmentPath `
            -DiscountedPrincipalPath $DiscountedPrincipalPath `
            -HandoffPath $HandoffPath `
            -SaveConfigPath $SaveConfigPath)
    }
    elseif (-not $configOptionalInputsLoaded) {
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
        -DisableOptionalInputDiscovery:$configOptionalInputsLoaded `
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
        includeFiles = [bool]$IncludeFiles
        includeSharePermissionDiagnostics = [bool]$IncludeSharePermissionDiagnostics
        skipIdentityEnrichment = [bool]$SkipIdentityEnrichment
        skipUnblock = [bool]$SkipUnblock
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
        ReviewShown = $false
        RerunLaunched = $false
    }
    if ($Interactive) {
        $postStartupSummary = Invoke-ShareSurferStartupPostPlanHandoff `
            -StartupConfigPath $SaveConfigPath `
            -OperatorPlanPath $assistantSummary.PlanPath `
            -ReusableCommandPath $assistantSummary.ReusableCommandPath
    }

    [pscustomobject]@{
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

        [switch] $SkipOwnershipSetup,

        [switch] $NoCreateMissingFolders,

        [switch] $Force
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
        Write-Host ''
        Write-Host 'Ownership enrichment was not found. This optional setup can combine HR, OBS, project, or ownership CSVs before the scan.'
        Write-Host 'It can also save a reusable ownership import definition so the interview does not have to be repeated next time.'
        $runOwnershipImport = Read-ShareSurferStartupBoolean -Prompt 'Build ownership enrichment now from CSV files?' -Value $false
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
            }
        }
    }

    $ownerMappingExists = (Test-ShareSurferOptionalInputFile -Path $OwnerMappingPath) -or (Test-ShareSurferOptionalInputFile -Path $expectedOwnerMappingPath)
    if (-not $ownerMappingExists) {
        $summary.OwnerMappingDraftOffered = $true
        Write-Host ''
        Write-Host 'Owner mapping was not found. A useful owner-mapping draft usually needs scan output, so ShareSurfer can create it after the scan finishes.'
        Write-Host 'The draft will still need a person to fill Owner and BusinessUnit before it is used for a final owner/business-unit report.'
        $createDraft = Read-ShareSurferStartupBoolean -Prompt 'Add post-scan owner-mapping draft creation to the generated rerun script?' -Value $true
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
        [string] $ReusableCommandPath
    )

    Write-Host ''
    Write-Host 'ShareSurfer startup files are ready:'
    Write-Host ('  Startup config: {0}' -f $StartupConfigPath)
    Write-Host ('  Operator plan:  {0}' -f $OperatorPlanPath)
    Write-Host ('  Rerun script:    {0}' -f $ReusableCommandPath)

    $reviewShown = $false
    $showGeneratedFiles = Read-ShareSurferStartupBoolean -Prompt 'Show generated startup JSON, scan plan, and rerun script now?' -Value $true
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
    $runNow = Read-ShareSurferStartupBoolean -Prompt 'Run the generated diagnostic/scan/validate/dashboard script now?' -Value $false
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

        [Parameter(Mandatory = $true)]
        [string[]] $Choices
    )

    $choiceText = $Choices -join '/'
    $validate = {
        param($text)
        if ($Choices -contains $text) { '' } else { 'Please enter one of: {0}' -f $choiceText }
    }.GetNewClosure()
    $result = Read-ShareSurferConsoleText -Prompt ('{0} ({1})' -f $Prompt, $choiceText) -Default $Value -Validate $validate
    [string]$result.Value
}

function Read-ShareSurferStartupBoolean {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Prompt,

        [bool] $Value = $false
    )

    $result = Read-ShareSurferConsoleBoolean -Prompt $Prompt -Default $Value
    [bool]$result.Value
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
