function Start-ShareSurferOperatorAssistant {
    [CmdletBinding()]
    param(
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

        [string] $PlanPath = '',

        [string] $ReusableCommandPath = '',

        [switch] $IncludeFiles,

        [switch] $SkipIdentityEnrichment,

        [switch] $Interactive,

        [switch] $NoCreateMissingFolders,

        [switch] $Force
    )

    if ([string]::IsNullOrWhiteSpace($ReleaseRoot)) {
        $ReleaseRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    }

    if ([string]::IsNullOrWhiteSpace($InputRoot)) {
        $InputRoot = Join-Path (Get-Location).Path 'inputs'
    }

    if ($Interactive) {
        $ReleaseRoot = Read-ShareSurferAssistantText -Prompt 'ShareSurfer release root' -Value $ReleaseRoot
        $InputRoot = Read-ShareSurferAssistantText -Prompt 'Input folder for optional CSVs and assistant files' -Value $InputRoot
        if ($TargetPath.Count -eq 0) {
            $targetAnswer = Read-ShareSurferAssistantText -Prompt 'Share or folder path to scan' -Value ''
            if (-not [string]::IsNullOrWhiteSpace($targetAnswer)) {
                $TargetPath = @($targetAnswer)
            }
        }
        $ObsAttribute = Read-ShareSurferAssistantText -Prompt 'OBS attribute' -Value $ObsAttribute
        $AdLookupMode = Read-ShareSurferAssistantText -Prompt 'AD lookup mode' -Value $AdLookupMode
        $ManagerIdentityFormat = Read-ShareSurferAssistantText -Prompt 'Manager identity format' -Value $ManagerIdentityFormat
        $OwnerMappingPath = Read-ShareSurferAssistantText -Prompt 'Owner mapping CSV path (blank if absent)' -Value $OwnerMappingPath -AllowBlank
        $OwnershipEnrichmentPath = Read-ShareSurferAssistantText -Prompt 'Ownership enrichment CSV path (blank if absent)' -Value $OwnershipEnrichmentPath -AllowBlank
        $DiscountedPrincipalPath = Read-ShareSurferAssistantText -Prompt 'Discounted principals CSV path (blank if absent)' -Value $DiscountedPrincipalPath -AllowBlank
    }

    if ($TargetPath.Count -eq 0 -or @($TargetPath | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }).Count -eq 0) {
        throw 'Start-ShareSurferOperatorAssistant needs at least one -TargetPath value. Use -Interactive to be prompted for one.'
    }
    if (@('Auto', 'ActiveDirectory', 'Ldap', 'DirectoryOnly') -notcontains $AdLookupMode) {
        throw "Unsupported AD lookup mode: $AdLookupMode"
    }
    if (@('MailTo', 'Mail', 'UserPrincipalName', 'SamAccountName', 'DistinguishedName') -notcontains $ManagerIdentityFormat) {
        throw "Unsupported manager identity format: $ManagerIdentityFormat"
    }

    if ([string]::IsNullOrWhiteSpace($ExportPath)) {
        $outputRoot = Join-Path (Split-Path -Parent $InputRoot) 'exports'
        $ExportPath = Join-Path $outputRoot 'assistant-scan'
    }

    if ([string]::IsNullOrWhiteSpace($StandaloneDashboardPath)) {
        $StandaloneDashboardPath = Join-Path $ExportPath 'standalone-dashboard'
    }

    if ([string]::IsNullOrWhiteSpace($PlanPath)) {
        $PlanPath = Join-Path $InputRoot 'operator-assistant.plan.json'
    }

    if ([string]::IsNullOrWhiteSpace($ReusableCommandPath)) {
        $ReusableCommandPath = Join-Path $InputRoot 'operator-assistant-rerun.ps1'
    }

    $normalizedPlanPath = ConvertTo-ShareSurferAssistantComparablePath -Path $PlanPath
    $normalizedReusableCommandPath = ConvertTo-ShareSurferAssistantComparablePath -Path $ReusableCommandPath
    if ([string]::Equals($normalizedPlanPath, $normalizedReusableCommandPath, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw 'Operator assistant plan and rerun script paths must be different files.'
    }

    foreach ($path in @($PlanPath, $ReusableCommandPath)) {
        if ((Test-Path -LiteralPath $path) -and -not $Force) {
            throw "Operator assistant output already exists: $path. Use -Force to overwrite it."
        }
    }

    $cleanTargetPaths = @($TargetPath | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { [string]$_ })
    $commands = New-ShareSurferOperatorAssistantCommandSet `
        -ReleaseRoot $ReleaseRoot `
        -ExportPath $ExportPath `
        -StandaloneDashboardPath $StandaloneDashboardPath `
        -TargetPath $cleanTargetPaths `
        -ObsAttribute $ObsAttribute `
        -AdLookupMode $AdLookupMode `
        -ManagerIdentityFormat $ManagerIdentityFormat `
        -OwnerMappingPath $OwnerMappingPath `
        -OwnershipEnrichmentPath $OwnershipEnrichmentPath `
        -DiscountedPrincipalPath $DiscountedPrincipalPath `
        -IncludeFiles:$IncludeFiles `
        -SkipIdentityEnrichment:$SkipIdentityEnrichment

    $plan = [ordered]@{
        version = 1
        createdAt = (Get-Date).ToUniversalTime().ToString('o')
        mode = if ($Interactive) { 'Interactive' } else { 'NonInteractive' }
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
        optionalInputs = [ordered]@{
            ownerMappingPath = $OwnerMappingPath
            ownershipEnrichmentPath = $OwnershipEnrichmentPath
            discountedPrincipalPath = $DiscountedPrincipalPath
        }
        generatedFiles = [ordered]@{
            planPath = $PlanPath
            reusableCommandPath = $ReusableCommandPath
        }
        commands = [ordered]@{
            importModule = [string]$commands.ImportModule
            scan = [string]$commands.Scan
            validate = [string]$commands.Validate
            packageStandaloneDashboard = [string]$commands.PackageStandaloneDashboard
            optionalInputBehavior = [string]$commands.OptionalInputBehavior
        }
        stopGates = @(
            'Review evidence_confidence.csv before owner signoff.',
            'Resolve or document collection_errors.csv and partial shares.',
            'Confirm scan_manifest.csv uses the intended ObsAttribute.',
            'Open the generated standalone dashboard under the export folder, not the release template dashboard.'
        )
        nextSteps = @(
            'Review the generated rerun script before running it.',
            'Run the scan command on the collector host.',
            'Run Test-ShareSurferExport after collection finishes.',
            'Package the standalone dashboard only from a validated export.'
        )
    }

    Ensure-ShareSurferLocalFileParentDirectory -Path $PlanPath -Purpose 'operator assistant plan' -NoCreateMissingFolders:$NoCreateMissingFolders | Out-Null

    Set-Content -LiteralPath $PlanPath -Value ($plan | ConvertTo-Json -Depth 8) -Encoding UTF8
    $writtenReusableCommandPath = Write-ShareSurferReusableCommandFile -Path $ReusableCommandPath -CommandText ([string]$commands.Script) -NoCreateMissingFolders:$NoCreateMissingFolders

    [pscustomobject]@{
        PlanPath = $PlanPath
        ReusableCommandPath = $writtenReusableCommandPath
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
        Commands = $plan.commands
        StopGates = $plan.stopGates
        NextSteps = $plan.nextSteps
    }
}

function Read-ShareSurferAssistantText {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Prompt,

        [string] $Value = '',

        [switch] $AllowBlank
    )

    $displayPrompt = if ([string]::IsNullOrWhiteSpace($Value)) {
        $Prompt
    }
    else {
        '{0} [{1}]' -f $Prompt, $Value
    }

    $answer = Read-Host -Prompt $displayPrompt
    if ([string]::IsNullOrWhiteSpace($answer)) {
        if ($AllowBlank -and [string]::IsNullOrWhiteSpace($Value)) {
            return ''
        }
        return $Value
    }

    $answer
}

function New-ShareSurferOperatorAssistantCommandSet {
    param(
        [Parameter(Mandatory = $true)]
        [string] $ReleaseRoot,

        [Parameter(Mandatory = $true)]
        [string] $ExportPath,

        [Parameter(Mandatory = $true)]
        [string] $StandaloneDashboardPath,

        [Parameter(Mandatory = $true)]
        [string[]] $TargetPath,

        [Parameter(Mandatory = $true)]
        [string] $ObsAttribute,

        [Parameter(Mandatory = $true)]
        [string] $AdLookupMode,

        [Parameter(Mandatory = $true)]
        [string] $ManagerIdentityFormat,

        [string] $OwnerMappingPath = '',

        [string] $OwnershipEnrichmentPath = '',

        [string] $DiscountedPrincipalPath = '',

        [switch] $IncludeFiles,

        [switch] $SkipIdentityEnrichment
    )

    $moduleRelativePath = 'src\ShareSurfer\ShareSurfer.psd1'
    $dashboardRelativePath = 'scripts\New-ShareSurferStandaloneDashboard.ps1'
    $modulePathPreview = Join-ShareSurferAssistantPathText -Root $ReleaseRoot -Child $moduleRelativePath
    $dashboardScriptPreview = Join-ShareSurferAssistantPathText -Root $ReleaseRoot -Child $dashboardRelativePath

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('# Reusable ShareSurfer operator assistant commands')
    $lines.Add('# Review these commands before running them. ShareSurfer does not change permissions.')
    $lines.Add(('$releaseRoot = {0}' -f (ConvertTo-ShareSurferPowerShellLiteral -Value $ReleaseRoot)))
    $lines.Add(('$exportPath = {0}' -f (ConvertTo-ShareSurferPowerShellLiteral -Value $ExportPath)))
    $lines.Add(('$standaloneDashboardPath = {0}' -f (ConvertTo-ShareSurferPowerShellLiteral -Value $StandaloneDashboardPath)))
    $lines.Add(('$targetPaths = {0}' -f (ConvertTo-ShareSurferPowerShellArrayLiteral -Values $TargetPath)))
    $lines.Add(('$obsAttribute = {0}' -f (ConvertTo-ShareSurferPowerShellLiteral -Value $ObsAttribute)))
    $lines.Add(('$adLookupMode = {0}' -f (ConvertTo-ShareSurferPowerShellLiteral -Value $AdLookupMode)))
    $lines.Add(('$managerIdentityFormat = {0}' -f (ConvertTo-ShareSurferPowerShellLiteral -Value $ManagerIdentityFormat)))
    $lines.Add(('$ownerMappingPath = {0}' -f (ConvertTo-ShareSurferPowerShellLiteral -Value $OwnerMappingPath)))
    $lines.Add(('$ownershipEnrichmentPath = {0}' -f (ConvertTo-ShareSurferPowerShellLiteral -Value $OwnershipEnrichmentPath)))
    $lines.Add(('$discountedPrincipalPath = {0}' -f (ConvertTo-ShareSurferPowerShellLiteral -Value $DiscountedPrincipalPath)))
    $lines.Add('')
    $lines.Add(('$modulePath = Join-Path $releaseRoot {0}' -f (ConvertTo-ShareSurferPowerShellLiteral -Value $moduleRelativePath)))
    $lines.Add(('$standaloneDashboardScript = Join-Path $releaseRoot {0}' -f (ConvertTo-ShareSurferPowerShellLiteral -Value $dashboardRelativePath)))
    $lines.Add('Import-Module $modulePath -Force')
    $lines.Add('')
    $lines.Add('$scanParams = @{')
    $lines.Add('  TargetPath = $targetPaths')
    $lines.Add('  OutputPath = $exportPath')
    $lines.Add('  ObsAttribute = $obsAttribute')
    $lines.Add('  AdLookupMode = $adLookupMode')
    $lines.Add('  ManagerIdentityFormat = $managerIdentityFormat')
    $lines.Add('}')
    if ($IncludeFiles) {
        $lines.Add('$scanParams.IncludeFiles = $true')
    }
    if ($SkipIdentityEnrichment) {
        $lines.Add('$scanParams.SkipIdentityEnrichment = $true')
    }
    $lines.Add('if (-not [string]::IsNullOrWhiteSpace($ownerMappingPath) -and (Test-Path -LiteralPath $ownerMappingPath)) {')
    $lines.Add('  $scanParams.OwnerMappingPath = $ownerMappingPath')
    $lines.Add('}')
    $lines.Add('if (-not [string]::IsNullOrWhiteSpace($ownershipEnrichmentPath) -and (Test-Path -LiteralPath $ownershipEnrichmentPath)) {')
    $lines.Add('  $scanParams.OwnershipEnrichmentPath = $ownershipEnrichmentPath')
    $lines.Add('}')
    $lines.Add('if (-not [string]::IsNullOrWhiteSpace($discountedPrincipalPath) -and (Test-Path -LiteralPath $discountedPrincipalPath)) {')
    $lines.Add('  $scanParams.DiscountedPrincipalPath = $discountedPrincipalPath')
    $lines.Add('}')
    $lines.Add('')
    $lines.Add('Invoke-ShareSurferScan @scanParams')
    $lines.Add('$validation = Test-ShareSurferExport -ExportPath $exportPath')
    $lines.Add('if (-not $validation.IsValid) {')
    $lines.Add('  $validationDetails = @()')
    $lines.Add('  if (@($validation.MissingFiles).Count -gt 0) {')
    $lines.Add('    $validationDetails += ("Missing files: {0}" -f (@($validation.MissingFiles) -join '', ''))')
    $lines.Add('  }')
    $lines.Add('  if (@($validation.SchemaErrors).Count -gt 0) {')
    $lines.Add('    $validationDetails += ("Schema errors: {0}" -f (@($validation.SchemaErrors) -join '', ''))')
    $lines.Add('  }')
    $lines.Add('  throw ("ShareSurfer export validation failed. {0}" -f ($validationDetails -join '' ''))')
    $lines.Add('}')
    $lines.Add('& $standaloneDashboardScript -ExportPath $exportPath -OutputPath $standaloneDashboardPath -Force')
    $lines.Add('')
    $lines.Add('# Stop before owner signoff if evidence_confidence.csv, collection_errors.csv, or scan_manifest.csv show unresolved gaps.')

    $scanPreviewParts = New-Object System.Collections.Generic.List[string]
    $scanPreviewParts.Add('Invoke-ShareSurferScan')
    $scanPreviewParts.Add(('-TargetPath {0}' -f (ConvertTo-ShareSurferPowerShellArrayLiteral -Values $TargetPath)))
    $scanPreviewParts.Add(('-OutputPath {0}' -f (ConvertTo-ShareSurferPowerShellLiteral -Value $ExportPath)))
    $scanPreviewParts.Add(('-ObsAttribute {0}' -f (ConvertTo-ShareSurferPowerShellLiteral -Value $ObsAttribute)))
    $scanPreviewParts.Add(('-AdLookupMode {0}' -f (ConvertTo-ShareSurferPowerShellLiteral -Value $AdLookupMode)))
    $scanPreviewParts.Add(('-ManagerIdentityFormat {0}' -f (ConvertTo-ShareSurferPowerShellLiteral -Value $ManagerIdentityFormat)))
    if ($IncludeFiles) {
        $scanPreviewParts.Add('-IncludeFiles')
    }
    if ($SkipIdentityEnrichment) {
        $scanPreviewParts.Add('-SkipIdentityEnrichment')
    }
    if (-not [string]::IsNullOrWhiteSpace($OwnerMappingPath)) {
        $scanPreviewParts.Add(('-OwnerMappingPath {0}' -f (ConvertTo-ShareSurferPowerShellLiteral -Value $OwnerMappingPath)))
    }
    if (-not [string]::IsNullOrWhiteSpace($OwnershipEnrichmentPath)) {
        $scanPreviewParts.Add(('-OwnershipEnrichmentPath {0}' -f (ConvertTo-ShareSurferPowerShellLiteral -Value $OwnershipEnrichmentPath)))
    }
    if (-not [string]::IsNullOrWhiteSpace($DiscountedPrincipalPath)) {
        $scanPreviewParts.Add(('-DiscountedPrincipalPath {0}' -f (ConvertTo-ShareSurferPowerShellLiteral -Value $DiscountedPrincipalPath)))
    }

    [pscustomobject]@{
        ImportModule = ('Import-Module {0} -Force' -f (ConvertTo-ShareSurferPowerShellLiteral -Value $modulePathPreview))
        Scan = ($scanPreviewParts -join ' ')
        Validate = ('Test-ShareSurferExport -ExportPath {0}' -f (ConvertTo-ShareSurferPowerShellLiteral -Value $ExportPath))
        PackageStandaloneDashboard = ('& {0} -ExportPath {1} -OutputPath {2} -Force' -f (ConvertTo-ShareSurferPowerShellLiteral -Value $dashboardScriptPreview), (ConvertTo-ShareSurferPowerShellLiteral -Value $ExportPath), (ConvertTo-ShareSurferPowerShellLiteral -Value $StandaloneDashboardPath))
        OptionalInputBehavior = 'Scan preview lists requested optional CSV paths. The generated rerun script is authoritative and passes optional CSV paths only when Test-Path confirms those files exist.'
        Script = ($lines -join [Environment]::NewLine)
    }
}

function ConvertTo-ShareSurferAssistantComparablePath {
    param(
        [string] $Path = ''
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return ''
    }

    $trimmed = $Path.Trim()
    if ($trimmed -match '^[A-Za-z]:[\\/]' -or $trimmed -like '\\*') {
        return ($trimmed -replace '/', '\')
    }

    try {
        return [System.IO.Path]::GetFullPath($trimmed)
    }
    catch {
        return $trimmed
    }
}

function Join-ShareSurferAssistantPathText {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Root,

        [Parameter(Mandatory = $true)]
        [string] $Child
    )

    $separator = if ($Root -match '^[A-Za-z]:\\' -or $Root -like '\\*') { '\' } else { [System.IO.Path]::DirectorySeparatorChar }
    '{0}{1}{2}' -f $Root.TrimEnd('\', '/'), $separator, $Child.TrimStart('\', '/')
}
