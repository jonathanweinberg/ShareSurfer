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

        [string] $DiscountedPrincipalPath = '',

        [string] $HandoffPath = '',

        [string] $PlanPath = '',

        [string] $ReusableCommandPath = '',

        [switch] $IncludeFiles,

        [switch] $SkipIdentityEnrichment,

        [switch] $Interactive,

        [switch] $SkipUnblock,

        [switch] $NoCreateMissingFolders,

        [switch] $Force
    )

    $boundParameters = @{}
    foreach ($key in $PSBoundParameters.Keys) {
        $boundParameters[$key] = $true
    }

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
        if ($null -ne $definition.PSObject.Properties['skipIdentityEnrichment'] -and -not $boundParameters.ContainsKey('SkipIdentityEnrichment')) { $SkipIdentityEnrichment = [bool]$definition.skipIdentityEnrichment }
        if ($null -ne $definition.PSObject.Properties['skipUnblock'] -and -not $boundParameters.ContainsKey('SkipUnblock')) { $SkipUnblock = [bool]$definition.skipUnblock }
        if ($null -ne $definition.PSObject.Properties['optionalInputs']) {
            if ($null -ne $definition.optionalInputs.PSObject.Properties['ownerMappingPath'] -and -not $boundParameters.ContainsKey('OwnerMappingPath')) { $OwnerMappingPath = [string]$definition.optionalInputs.ownerMappingPath }
            if ($null -ne $definition.optionalInputs.PSObject.Properties['ownershipEnrichmentPath'] -and -not $boundParameters.ContainsKey('OwnershipEnrichmentPath')) { $OwnershipEnrichmentPath = [string]$definition.optionalInputs.ownershipEnrichmentPath }
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

    if ($Interactive) {
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
        $OwnerMappingPath = Read-ShareSurferAssistantText -Prompt 'Owner mapping CSV path (blank if absent)' -Value $OwnerMappingPath -AllowBlank
        $OwnershipEnrichmentPath = Read-ShareSurferAssistantText -Prompt 'Ownership enrichment CSV path (blank if absent)' -Value $OwnershipEnrichmentPath -AllowBlank
        $DiscountedPrincipalPath = Read-ShareSurferAssistantText -Prompt 'Discounted principals CSV path (blank if absent)' -Value $DiscountedPrincipalPath -AllowBlank
        if ($EnvironmentMode -eq 'Nonpermissive') {
            if ([string]::IsNullOrWhiteSpace($HandoffPath)) {
                $HandoffPath = Join-Path (Join-Path (Split-Path -Parent $InputRoot) 'handoff') 'scan-001.zip'
            }
            $HandoffPath = Read-ShareSurferAssistantText -Prompt 'Validated export handoff ZIP path' -Value $HandoffPath
        }
        $IncludeFiles = Read-ShareSurferStartupBoolean -Prompt 'Include file rows as well as folders?' -Value ([bool]$IncludeFiles)
        $SkipIdentityEnrichment = Read-ShareSurferStartupBoolean -Prompt 'Skip identity enrichment?' -Value ([bool]$SkipIdentityEnrichment)
        $SkipUnblock = Read-ShareSurferStartupBoolean -Prompt 'Skip recursive PowerShell file unblock?' -Value ([bool]$SkipUnblock)
        $SaveConfigPath = Read-ShareSurferAssistantText -Prompt 'Save startup JSON config path' -Value $SaveConfigPath
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
        -DiscountedPrincipalPath $DiscountedPrincipalPath `
        -PlanPath $PlanPath `
        -ReusableCommandPath $ReusableCommandPath `
        -IncludeFiles:$IncludeFiles `
        -SkipIdentityEnrichment:$SkipIdentityEnrichment `
        -NoCreateMissingFolders:$NoCreateMissingFolders `
        -Force:$Force

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
        skipIdentityEnrichment = [bool]$SkipIdentityEnrichment
        skipUnblock = [bool]$SkipUnblock
        optionalInputs = [ordered]@{
            ownerMappingPath = $OwnerMappingPath
            ownershipEnrichmentPath = $OwnershipEnrichmentPath
            discountedPrincipalPath = $DiscountedPrincipalPath
        }
        nonpermissive = [ordered]@{
            handoffPath = $HandoffPath
            note = 'Use this when the collector host must package the validated export for approved transfer to a dashboard/review host.'
        }
        generatedFiles = [ordered]@{
            startupConfigPath = $SaveConfigPath
            operatorPlanPath = $assistantSummary.PlanPath
            operatorReusableCommandPath = $assistantSummary.ReusableCommandPath
        }
        commands = [ordered]@{
            startupReplay = $startupReplayCommand
            startupScriptReplay = $scriptReplayCommand
            operatorRerun = $assistantSummary.ReusableCommandPath
        }
        stopGates = @(
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
        IncludeFiles = [bool]$IncludeFiles
        SkipIdentityEnrichment = [bool]$SkipIdentityEnrichment
        SkipUnblock = [bool]$SkipUnblock
        HandoffPath = $HandoffPath
        UnblockStatus = $unblockSummary.Status
        UnblockFileCount = $unblockSummary.FileCount
        UnblockZoneIdentifierRemovedCount = $unblockSummary.ZoneIdentifierRemovedCount
        OperatorPlanPath = $assistantSummary.PlanPath
        OperatorReusableCommandPath = $assistantSummary.ReusableCommandPath
        PostStartupReviewShown = [bool]$postStartupSummary.ReviewShown
        PostStartupRerunLaunched = [bool]$postStartupSummary.RerunLaunched
        StartupReplayCommand = $startupReplayCommand
        StartupScriptReplayCommand = $scriptReplayCommand
        StopGates = @($startupConfig.stopGates)
        NextSteps = @(
            'Review the startup JSON config and operator assistant rerun script.',
            'Run the operator rerun script on the collector host when ready.',
            'Validate the export before packaging or sharing the dashboard.',
            'Reuse the startup JSON config to regenerate the same startup pattern later.'
        )
    }
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
    Write-Host 'The rerun script runs collection, validates the export, and packages the standalone dashboard from the validated export folder.'
    $runNow = Read-ShareSurferStartupBoolean -Prompt 'Run the generated scan/validate/dashboard script now?' -Value $false
    if ($runNow) {
        Write-Host ('Running generated ShareSurfer script: {0}' -f $ReusableCommandPath)
        & $ReusableCommandPath
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
    while ($true) {
        $answer = Read-ShareSurferAssistantText -Prompt ('{0} ({1})' -f $Prompt, $choiceText) -Value $Value
        if ($Choices -contains $answer) {
            return $answer
        }
        Write-Host ('Please enter one of: {0}' -f $choiceText)
    }
}

function Read-ShareSurferStartupBoolean {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Prompt,

        [bool] $Value = $false
    )

    $default = if ($Value) { 'Y' } else { 'N' }
    while ($true) {
        $answer = Read-ShareSurferAssistantText -Prompt ('{0} (Y/N)' -f $Prompt) -Value $default
        if ($answer -match '(?i)^y(es)?$') {
            return $true
        }
        if ($answer -match '(?i)^n(o)?$') {
            return $false
        }
        Write-Host 'Please answer Y or N.'
    }
}
