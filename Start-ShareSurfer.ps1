[CmdletBinding()]
param(
    [string] $ConfigPath = '',

    [string] $SaveConfigPath = '',

    [string] $InputRoot = '',

    [string] $ExportPath = '',

    [string] $StandaloneDashboardPath = '',

    [string] $ObsAttribute = 'extensionAttribute10',

    [ValidateSet('Auto', 'ActiveDirectory', 'Ldap', 'DirectoryOnly')]
    [string] $AdLookupMode = 'Auto',

    [ValidateSet('MailTo', 'Mail', 'UserPrincipalName', 'SamAccountName', 'DistinguishedName')]
    [string] $ManagerIdentityFormat = 'MailTo',

    [ValidateSet('FullEffective', 'Compact')]
    [string] $AclExportMode = 'Compact',

    [ValidateSet('Auto', 'Enhanced', 'Plain')]
    [string] $ConsoleMode = 'Plain',

    [switch] $Interactive,

    [switch] $StartupOnly,

    [switch] $Force
)

$ErrorActionPreference = 'Stop'
$releaseRoot = $PSScriptRoot

function Invoke-ShareSurferLauncherUnblock {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Root
    )

    $unblockCommand = Get-Command -Name Unblock-File -ErrorAction SilentlyContinue
    if ($null -eq $unblockCommand) {
        Write-Host 'Unblock-File is not available in this PowerShell session; continuing.'
        return
    }

    Write-Host ('Checking ShareSurfer PowerShell files under {0} for downloaded-file blocks.' -f $Root)
    $files = @(Get-ChildItem -LiteralPath $Root -Recurse -File -ErrorAction SilentlyContinue | Where-Object {
        @('.ps1', '.psm1', '.psd1') -contains $_.Extension
    })

    $processed = 0
    $streamRemoved = 0
    $errors = 0
    foreach ($file in $files) {
        try {
            $streamStatus = Remove-ShareSurferLauncherZoneIdentifierStream -LiteralPath $file.FullName
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

    Write-Host ('Checked {0} ShareSurfer PowerShell file(s); explicitly cleared {1} downloaded-file marker(s).' -f $processed, $streamRemoved)
    if ($errors -gt 0) {
        Write-Warning ('{0} ShareSurfer PowerShell file(s) could not be unblocked before module import.' -f $errors)
    }
}

function Remove-ShareSurferLauncherZoneIdentifierStream {
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

Invoke-ShareSurferLauncherUnblock -Root $releaseRoot

$modulePath = Join-Path $releaseRoot 'src\ShareSurfer\ShareSurfer.psd1'
if (-not (Test-Path -LiteralPath $modulePath -PathType Leaf)) {
    throw "ShareSurfer module manifest was not found: $modulePath"
}

$shareSurferModule = @(Import-Module $modulePath -Force -PassThru)[0]
if ($null -eq $shareSurferModule) {
    throw "ShareSurfer module could not be imported from: $modulePath"
}

function Invoke-ShareSurferLauncherModuleCommand {
    param(
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.PSModuleInfo] $Module,

        [Parameter(Mandatory = $true)]
        [string] $Name,

        [hashtable] $Parameters = @{}
    )

    $command = @(Get-Command -Name $Name -Module $Module.Name -ErrorAction Stop | Where-Object {
        $null -ne $_.Module -and [string]::Equals([string]$_.Module.Path, [string]$Module.Path, [System.StringComparison]::OrdinalIgnoreCase)
    })[0]
    if ($null -eq $command) {
        throw "ShareSurfer command '$Name' was not exported from the imported module: $($Module.Path)"
    }

    & $command @Parameters
}

if ([string]::IsNullOrWhiteSpace($InputRoot)) {
    $InputRoot = Join-Path $releaseRoot 'inputs'
}

if ([string]::IsNullOrWhiteSpace($ExportPath)) {
    $ExportPath = Join-Path (Join-Path $releaseRoot 'exports') 'startup-scan'
}

if ([string]::IsNullOrWhiteSpace($StandaloneDashboardPath)) {
    $StandaloneDashboardPath = Join-Path $ExportPath 'standalone-dashboard'
}

if ([string]::IsNullOrWhiteSpace($ConfigPath) -and [string]::IsNullOrWhiteSpace($SaveConfigPath) -and -not $StartupOnly) {
    Invoke-ShareSurferLauncherModuleCommand -Module $shareSurferModule -Name 'Start-ShareSurfer' -Parameters @{
        ReleaseRoot = $releaseRoot
        InputRoot = $InputRoot
        ExportPath = $ExportPath
        StandaloneDashboardPath = $StandaloneDashboardPath
        ObsAttribute = $ObsAttribute
        AdLookupMode = $AdLookupMode
        ManagerIdentityFormat = $ManagerIdentityFormat
        AclExportMode = $AclExportMode
        ConsoleMode = $ConsoleMode
    }
    return
}

$startupParams = @{
    ReleaseRoot = $releaseRoot
    InputRoot = $InputRoot
    ExportPath = $ExportPath
    StandaloneDashboardPath = $StandaloneDashboardPath
    ObsAttribute = $ObsAttribute
    AdLookupMode = $AdLookupMode
    ManagerIdentityFormat = $ManagerIdentityFormat
    AclExportMode = $AclExportMode
    ConsoleMode = $ConsoleMode
}

if (-not [string]::IsNullOrWhiteSpace($ConfigPath)) {
    $startupParams.ConfigPath = $ConfigPath
}

if (-not [string]::IsNullOrWhiteSpace($SaveConfigPath)) {
    $startupParams.SaveConfigPath = $SaveConfigPath
}

if ($Interactive -or [string]::IsNullOrWhiteSpace($ConfigPath)) {
    $startupParams.Interactive = $true
}

if ($Force) {
    $startupParams.Force = $true
}

Invoke-ShareSurferLauncherModuleCommand -Module $shareSurferModule -Name 'Start-ShareSurferStartup' -Parameters $startupParams
