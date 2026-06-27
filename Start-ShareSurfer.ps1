[CmdletBinding()]
param(
    [string] $ConfigPath = '',

    [string] $SaveConfigPath = '',

    [switch] $Interactive,

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
    Get-ChildItem -Path (Join-Path $Root '*') -Recurse -File -Include '*.ps1', '*.psm1', '*.psd1' -ErrorAction SilentlyContinue | ForEach-Object {
        try {
            Unblock-File -LiteralPath $_.FullName -ErrorAction Stop
        }
        catch {
            Write-Warning ('Unable to unblock {0}: {1}' -f $_.FullName, $_.Exception.Message)
        }
    }
}

Invoke-ShareSurferLauncherUnblock -Root $releaseRoot

$modulePath = Join-Path $releaseRoot 'src\ShareSurfer\ShareSurfer.psd1'
if (-not (Test-Path -LiteralPath $modulePath -PathType Leaf)) {
    throw "ShareSurfer module manifest was not found: $modulePath"
}

Import-Module $modulePath -Force

$startupParams = @{
    ReleaseRoot = $releaseRoot
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

Start-ShareSurferStartup @startupParams
