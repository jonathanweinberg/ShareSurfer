[CmdletBinding()]
param(
    [switch] $AllowPowerShellCore,

    [switch] $PassThru
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$moduleManifest = Join-Path $repoRoot 'src/ShareSurfer/ShareSurfer.psd1'

function Assert-True {
    param(
        [Parameter(Mandatory = $true)]
        [bool] $Condition,

        [Parameter(Mandatory = $true)]
        [string] $Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

if (-not $AllowPowerShellCore -and ($PSVersionTable.PSVersion.Major -ne 5 -or $PSVersionTable.PSVersion.Minor -ne 1)) {
    throw ('Windows PowerShell validation must run on PowerShell 5.1. Actual: {0} ({1})' -f $PSVersionTable.PSVersion, $PSVersionTable.PSEdition)
}

$parseTargets = @(
    $moduleManifest,
    (Join-Path $repoRoot 'src/ShareSurfer/ShareSurfer.psm1'),
    (Join-Path $repoRoot 'scripts/New-ShareSurferStandaloneDashboard.ps1')
)

foreach ($parseTarget in $parseTargets) {
    $tokens = $null
    $parseErrors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($parseTarget, [ref]$tokens, [ref]$parseErrors) | Out-Null
    Assert-True (@($parseErrors).Count -eq 0) ('PowerShell 5.1 parser errors in {0}: {1}' -f $parseTarget, (@($parseErrors | ForEach-Object { $_.Message }) -join '; '))
}

Import-Module $moduleManifest -Force
$module = Get-Module ShareSurfer
$exportedCommands = @(Get-Command -Module ShareSurfer | Select-Object -ExpandProperty Name)
$requiredCommands = @(
    'Invoke-ShareSurferScan',
    'ConvertTo-ShareSurferReport',
    'Import-ShareSurferReviewDecisions',
    'New-ShareSurferLabFixture',
    'New-ShareSurferReviewDecisionDraft',
    'New-ShareSurferSupportBundle',
    'Start-ShareSurferOperatorAssistant',
    'Start-ShareSurferStartup',
    'Test-ShareSurferExport'
)
foreach ($commandName in $requiredCommands) {
    Assert-True ($exportedCommands -contains $commandName) ('Expected exported command under Windows PowerShell 5.1: {0}' -f $commandName)
}

$consoleSmoke = & $module {
    $state = New-ShareSurferConsoleChoiceState -Options @('One', 'Two') -DefaultValue 'One'
    Invoke-ShareSurferConsoleChoiceCommand -State $state -Command 'Down' | Out-Null
    $plainCapabilities = Get-ShareSurferConsoleCapabilities -ConsoleMode Plain
    [pscustomobject]@{
        SelectedIndex = [int]$state.SelectedIndex
        EffectiveConsoleMode = [string]$plainCapabilities.EffectiveConsoleMode
        RawKeys = [bool]$plainCapabilities.RawKeys
    }
}
Assert-True ($consoleSmoke.SelectedIndex -eq 1) 'Windows PowerShell 5.1 console choice state should support deterministic Down navigation.'
Assert-True ($consoleSmoke.EffectiveConsoleMode -eq 'Plain') 'Windows PowerShell 5.1 console capabilities should support forced plain mode.'
Assert-True (-not [bool]$consoleSmoke.RawKeys) 'Forced plain mode should not require raw key input.'

$menuSmoke = & $module {
    Get-ShareSurferMenuEntries -InputRoot 'C:\ShareSurfer-0.1.0-pre.example\inputs' -ExportPath 'C:\ShareSurfer-0.1.0-pre.example\exports\startup-scan' -ObsAttribute 'info' -AdLookupMode DirectoryOnly -ManagerIdentityFormat Mail -ConsoleMode Plain
}
$firstScanMenuEntries = @($menuSmoke | Where-Object { $_.Key -eq 'first_scan' })
Assert-True (@($menuSmoke).Count -eq 6) 'Windows PowerShell 5.1 goal-based home should expose six operator choices.'
Assert-True ($firstScanMenuEntries.Count -eq 1) 'Windows PowerShell 5.1 goal-based home should expose exactly one first-scan goal.'
$firstScanMenuEntry = $firstScanMenuEntries[0]
Assert-True ([bool]$firstScanMenuEntry.Available) 'Windows PowerShell 5.1 goal-based home should keep the recommended first scan available.'

$technicalCommandSmoke = & $module {
    $state = [pscustomobject]@{
        EnvironmentMode = 'Permissive'
        ReleaseRoot = 'C:\ShareSurfer-0.1.0-pre.example'
        InputRoot = 'C:\ShareSurfer-0.1.0-pre.example\inputs'
        ExportPath = 'C:\ShareSurfer-0.1.0-pre.example\exports\startup-scan'
        StandaloneDashboardPath = 'C:\ShareSurfer-0.1.0-pre.example\exports\startup-scan\standalone-dashboard'
        TargetPath = @('\\files01\Finance')
        ObsAttribute = 'info'
        AdLookupMode = 'DirectoryOnly'
        ManagerIdentityFormat = 'Mail'
        AclExportMode = 'Compact'
        ConsoleMode = 'Plain'
        SaveConfigPath = 'C:\ShareSurfer-0.1.0-pre.example\inputs\sharesurfer-startup.config.json'
        OwnerMappingPath = ''
        OwnershipEnrichmentPath = ''
        OwnershipContextPath = ''
        OwnershipRelationshipPath = ''
        OwnershipImportManifestPath = ''
        DiscountedPrincipalPath = ''
        HandoffPath = ''
        IncludeFiles = $false
        IncludeSharePermissionDiagnostics = $true
        SkipIdentityEnrichment = $false
        SkipUnblock = $false
        DeferOwnershipInputs = $true
        OwnershipSetupSummary = $null
    }
    Get-ShareSurferFirstScanCommandPreview -State $state
}
Assert-True ([string]$technicalCommandSmoke -like '*-ObsAttribute ''info''*') 'Windows PowerShell 5.1 technical preview should preserve the OBS attribute.'
Assert-True ([string]$technicalCommandSmoke -like '*-AdLookupMode ''DirectoryOnly''*') 'Windows PowerShell 5.1 technical preview should preserve AD lookup mode.'
Assert-True ([string]$technicalCommandSmoke -like '*-ManagerIdentityFormat ''Mail''*') 'Windows PowerShell 5.1 technical preview should preserve manager format.'
Assert-True ([string]$technicalCommandSmoke -like '*-DisableOptionalInputDiscovery*') 'Windows PowerShell 5.1 technical preview should preserve deferred optional-input behavior.'

$inventory = [pscustomobject]@{
    Shares = @(
        [pscustomobject]@{
            ShareId = 'share-finance'
            Source = 'Fixture'
            ComputerName = 'files01'
            ShareName = 'Finance'
            UNCPath = '\\files01\Finance'
            LocalPath = 'C:\ShareSurferLab\Finance'
            Description = 'Finance test share'
            PartialData = $false
            PartialReason = ''
        }
    )
    Items = @(
        [pscustomobject]@{
            ItemId = 'item-root'
            ShareId = 'share-finance'
            ItemType = 'Directory'
            FullPath = '\\files01\Finance'
            RelativePath = ''
            Depth = 0
            Owner = 'CONTOSO\FinanceOwner'
            InheritanceEnabled = $true
            InheritanceBrokenAt = ''
        }
    )
    SharePermissions = @()
    AclEntries = @(
        [pscustomobject]@{
            ItemId = 'item-root'
            ShareId = 'share-finance'
            FullPath = '\\files01\Finance'
            Identity = 'CONTOSO\FinanceReaders'
            Rights = 'Read'
            AccessControlType = 'Allow'
            IsInherited = $false
            InheritanceFlags = 'ContainerInherit,ObjectInherit'
            PropagationFlags = 'None'
            Depth = 1
        }
    )
    Identities = @()
    GroupEdges = @()
    OrgChains = @()
    OwnerMappings = @()
    IdentityDirectory = @()
    ScanErrors = @()
}

$outputPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferWindowsPowerShell-' + [guid]::NewGuid().ToString('N'))
Invoke-ShareSurferScan -InputObject $inventory -OutputPath $outputPath -SkipIdentityEnrichment -Quiet | Out-Null
$validation = Test-ShareSurferExport -ExportPath $outputPath

Assert-True ([bool]$validation.IsValid) 'Windows PowerShell 5.1 core scan/export validation should pass.'
Assert-True (Test-Path -LiteralPath (Join-Path $outputPath 'shares.csv') -PathType Leaf) 'Windows PowerShell 5.1 scan should write shares.csv.'
Assert-True (Test-Path -LiteralPath (Join-Path $outputPath 'acl_entries.csv') -PathType Leaf) 'Windows PowerShell 5.1 scan should write acl_entries.csv.'

$reviewDecisionPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferWindowsPowerShellReview-' + [guid]::NewGuid().ToString('N'))
New-ShareSurferReviewDecisionDraft -ExportPath $outputPath -OutputPath $reviewDecisionPath -Force | Out-Null
$ownerDecisionPath = Join-Path $reviewDecisionPath 'owner_review_decisions.csv'
$ownerDecisionRows = @(Import-Csv -LiteralPath $ownerDecisionPath)
if ($ownerDecisionRows.Count -gt 0) {
    $ownerDecisionRows[0].Decision = 'ConfirmedOwner'
    $ownerDecisionRows[0].Reviewer = 'Windows PowerShell 5.1 smoke'
    $ownerDecisionRows | Export-Csv -LiteralPath $ownerDecisionPath -NoTypeInformation -Encoding UTF8
}
$decisionImport = Import-ShareSurferReviewDecisions -ExportPath $outputPath -DecisionPath $reviewDecisionPath -Force
Assert-True ([bool]$decisionImport.IsValid) 'Windows PowerShell 5.1 review-decision import should pass.'
Assert-True (Test-Path -LiteralPath (Join-Path $outputPath 'owner_review_decisions.csv') -PathType Leaf) 'Windows PowerShell 5.1 decision import should write owner_review_decisions.csv.'

$manifestData = Import-PowerShellDataFile -LiteralPath $moduleManifest
$result = [pscustomobject]@{
    IsValid = $true
    PSVersion = [string]$PSVersionTable.PSVersion
    PSEdition = [string]$PSVersionTable.PSEdition
    ParsedFileCount = @($parseTargets).Count
    RequiredCommandCount = @($requiredCommands).Count
    ModuleVersion = [string]$manifestData.ModuleVersion
    ExportPath = $outputPath
}

if ($PassThru) {
    $result
}
else {
    Write-Host ('Windows PowerShell 5.1 validation passed. PSVersion={0}; ExportPath={1}' -f $PSVersionTable.PSVersion, $outputPath)
}
