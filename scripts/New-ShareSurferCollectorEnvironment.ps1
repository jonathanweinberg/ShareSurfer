[CmdletBinding()]
param(
    [string] $OutputPath = '',

    [switch] $PassThru
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Test-ShareSurferCollectorCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Name
    )

    $command = Get-Command $Name -ErrorAction SilentlyContinue
    [pscustomobject]@{
        Name = $Name
        Available = ($null -ne $command)
        Source = if ($null -ne $command -and $command.PSObject.Properties['Source']) { [string]$command.Source } else { '' }
    }
}

function Test-ShareSurferCollectorModule {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Name
    )

    $module = Get-Module -ListAvailable $Name | Select-Object -First 1
    [pscustomobject]@{
        Name = $Name
        Available = ($null -ne $module)
        Version = if ($null -ne $module -and $module.PSObject.Properties['Version']) { [string]$module.Version } else { '' }
        Path = if ($null -ne $module -and $module.PSObject.Properties['Path']) { [string]$module.Path } else { '' }
    }
}

$collectorIsWindows = $false
try {
    $collectorIsWindows = [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Windows)
}
catch {
    $collectorIsWindows = ($env:OS -eq 'Windows_NT')
}

$osDescription = ''
$osArchitecture = ''
try {
    $osDescription = [System.Runtime.InteropServices.RuntimeInformation]::OSDescription
    $osArchitecture = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString()
}
catch {
    $osDescription = [string]$env:OS
    $osArchitecture = ''
}

$snapshot = [ordered]@{
    ArtifactType = 'ShareSurferCollectorEnvironment'
    GeneratedAt = (Get-Date).ToUniversalTime().ToString('o')
    IsWindows = [bool]$collectorIsWindows
    OSDescription = [string]$osDescription
    OSArchitecture = [string]$osArchitecture
    ComputerName = [string]$env:COMPUTERNAME
    UserDomain = [string]$env:USERDOMAIN
    UserName = [string]$env:USERNAME
    PowerShell = [ordered]@{
        Version = [string]$PSVersionTable.PSVersion
        PSEdition = [string]$PSVersionTable.PSEdition
        HostName = [string]$Host.Name
        ClrVersion = if ($PSVersionTable.ContainsKey('CLRVersion')) { [string]$PSVersionTable.CLRVersion } else { '' }
    }
    Modules = @(
        Test-ShareSurferCollectorModule -Name 'ActiveDirectory'
        Test-ShareSurferCollectorModule -Name 'SmbShare'
    )
    Commands = @(
        Test-ShareSurferCollectorCommand -Name 'Get-SmbShare'
        Test-ShareSurferCollectorCommand -Name 'Get-SmbShareAccess'
        Test-ShareSurferCollectorCommand -Name 'New-SmbShare'
        Test-ShareSurferCollectorCommand -Name 'Grant-SmbShareAccess'
        Test-ShareSurferCollectorCommand -Name 'Get-Acl'
        Test-ShareSurferCollectorCommand -Name 'Get-ADUser'
        Test-ShareSurferCollectorCommand -Name 'Get-ADGroup'
        Test-ShareSurferCollectorCommand -Name 'Get-ADDomain'
    )
}

if (-not [string]::IsNullOrWhiteSpace($OutputPath)) {
    $outputDirectory = Split-Path -Parent $OutputPath
    if (-not [string]::IsNullOrWhiteSpace($outputDirectory)) {
        New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
    }
    $snapshot | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $OutputPath -Encoding UTF8
}

if ($PassThru -or [string]::IsNullOrWhiteSpace($OutputPath)) {
    [pscustomobject]$snapshot
}
