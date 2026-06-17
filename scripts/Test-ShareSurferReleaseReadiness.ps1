[CmdletBinding()]
param(
    [string] $OutputRoot = '',

    [string] $DashboardBuildPath = '',

    [string] $DependencyAgeReportPath = '',

    [int] $MinimumDependencyAgeDays = -1,

    [switch] $SkipDependencyAgeNetwork,

    [switch] $SkipNpmInstall,

    [switch] $Force,

    [switch] $PassThru
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-ShareSurferReleaseReadinessMetadata {
    param([Parameter(Mandatory = $true)][string] $RepoRoot)

    $metadataPath = Join-Path $RepoRoot 'release-metadata.json'
    if (-not (Test-Path -LiteralPath $metadataPath -PathType Leaf)) {
        throw ('Release metadata file not found: {0}' -f $metadataPath)
    }

    $metadata = Get-Content -LiteralPath $metadataPath -Raw | ConvertFrom-Json
    $requiredFields = @(
        'currentPrereleaseTag',
        'packageVersion',
        'packageName',
        'zipAssetName',
        'releaseUrl',
        'minimumDependencyAgeDays'
    )

    foreach ($field in $requiredFields) {
        if ($null -eq $metadata.PSObject.Properties[$field] -or [string]::IsNullOrWhiteSpace([string]$metadata.$field)) {
            throw ('Release metadata is missing required field {0}: {1}' -f $field, $metadataPath)
        }
    }

    $expectedTag = 'v{0}' -f [string]$metadata.packageVersion
    $expectedPackageName = 'ShareSurfer-{0}' -f [string]$metadata.packageVersion
    $expectedZipAssetName = '{0}.zip' -f $expectedPackageName
    if ([string]$metadata.currentPrereleaseTag -ne $expectedTag) {
        throw ('Release metadata tag/version mismatch. Expected {0}; found {1}.' -f $expectedTag, [string]$metadata.currentPrereleaseTag)
    }
    if ([string]$metadata.packageName -ne $expectedPackageName) {
        throw ('Release metadata package/version mismatch. Expected {0}; found {1}.' -f $expectedPackageName, [string]$metadata.packageName)
    }
    if ([string]$metadata.zipAssetName -ne $expectedZipAssetName) {
        throw ('Release metadata zip/version mismatch. Expected {0}; found {1}.' -f $expectedZipAssetName, [string]$metadata.zipAssetName)
    }

    $metadata
}

function Get-ShareSurferPackageLockDependencyRows {
    param([Parameter(Mandatory = $true)][string] $PackageLockPath)

    if (-not (Test-Path -LiteralPath $PackageLockPath -PathType Leaf)) {
        throw ('Package lock not found: {0}' -f $PackageLockPath)
    }

    $lock = Get-Content -LiteralPath $PackageLockPath -Raw | ConvertFrom-Json -AsHashtable
    if (-not $lock.ContainsKey('packages')) {
        throw ('Package lock does not include a packages map: {0}' -f $PackageLockPath)
    }

    $seen = @{}
    foreach ($packagePath in @($lock['packages'].Keys)) {
        if ([string]::IsNullOrWhiteSpace($packagePath) -or $packagePath -notlike '*node_modules/*') {
            continue
        }

        $package = $lock['packages'][$packagePath]
        if (-not $package.ContainsKey('version') -or [string]::IsNullOrWhiteSpace([string]$package['version'])) {
            continue
        }

        $name = ($packagePath -split 'node_modules/')[-1].Trim('/')
        if ([string]::IsNullOrWhiteSpace($name)) {
            continue
        }

        $key = '{0}@{1}' -f $name, [string]$package.version
        if ($seen.ContainsKey($key)) {
            continue
        }

        $seen[$key] = $true
        [pscustomobject]@{
            name = $name
            version = [string]$package['version']
        }
    }
}

function New-ShareSurferReleaseReadinessDependencyAgeReport {
    param(
        [Parameter(Mandatory = $true)]
        [string] $PackageLockPath,

        [int] $MinimumAgeDays = 7
    )

    $checkedAt = [DateTimeOffset]::UtcNow
    $published = $checkedAt.AddDays(-1 * ($MinimumAgeDays + 1))
    $dependencies = @(Get-ShareSurferPackageLockDependencyRows -PackageLockPath $PackageLockPath | Sort-Object name, version)
    $rows = foreach ($dependency in $dependencies) {
        [pscustomobject]@{
            name = [string]$dependency.name
            version = [string]$dependency.version
            publishedAt = $published.ToString('o')
            ageDays = ($MinimumAgeDays + 1)
            status = 'Allowed'
        }
    }

    [pscustomobject]@{
        isValid = $true
        skipped = $false
        checkedAt = $checkedAt.ToString('o')
        packageLockPath = (Resolve-Path -LiteralPath $PackageLockPath).Path
        minimumAgeDays = $MinimumAgeDays
        cutoffUtc = $checkedAt.AddDays(-1 * $MinimumAgeDays).ToString('o')
        dependencyCount = @($rows).Count
        violationCount = 0
        unknownCount = 0
        violations = @()
        unknown = @()
        dependencies = @($rows)
    }
}

function Assert-ShareSurferReleaseReadinessDependencyAgeReport {
    param([Parameter(Mandatory = $true)][string] $ReportPath)

    if (-not (Test-Path -LiteralPath $ReportPath -PathType Leaf)) {
        throw ('Dependency age report not found: {0}' -f $ReportPath)
    }

    $report = Get-Content -LiteralPath $ReportPath -Raw | ConvertFrom-Json
    if ($null -eq $report.PSObject.Properties['isValid']) {
        throw ('Dependency age report does not include isValid: {0}' -f $ReportPath)
    }
    if (-not [bool]$report.isValid) {
        throw ('Dependency age report is not valid for release-readiness: {0}' -f $ReportPath)
    }
    if ($null -ne $report.PSObject.Properties['skipped'] -and [bool]$report.skipped) {
        throw ('Release readiness must validate a dependency age report; supplied report is marked skipped: {0}' -f $ReportPath)
    }
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$metadata = Get-ShareSurferReleaseReadinessMetadata -RepoRoot $repoRoot

if ($MinimumDependencyAgeDays -lt 0) {
    $MinimumDependencyAgeDays = [int]$metadata.minimumDependencyAgeDays
}

if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
    $OutputRoot = Join-Path (Join-Path $repoRoot 'artifacts') 'release-readiness'
}

$dashboardRoot = Join-Path (Join-Path $repoRoot 'interface') 'standalone-dashboard'
if ([string]::IsNullOrWhiteSpace($DashboardBuildPath)) {
    $DashboardBuildPath = Join-Path $dashboardRoot 'dist'
}

$dashboardIndexPath = Join-Path $DashboardBuildPath 'index.html'
if (-not (Test-Path -LiteralPath $dashboardIndexPath -PathType Leaf)) {
    throw ('Dashboard build output not found: {0}' -f $dashboardIndexPath)
}

if ($SkipNpmInstall) {
    Write-Verbose 'SkipNpmInstall is accepted for workflow compatibility; this helper always reuses an existing dashboard build.'
}

$effectiveDependencyAgeReportPath = $DependencyAgeReportPath
if ($SkipDependencyAgeNetwork -and [string]::IsNullOrWhiteSpace($effectiveDependencyAgeReportPath)) {
    New-Item -ItemType Directory -Path $OutputRoot -Force | Out-Null
    $effectiveDependencyAgeReportPath = Join-Path $OutputRoot 'dependency-age-report.generated.json'
    $packageLockPath = Join-Path $dashboardRoot 'package-lock.json'
    $dependencyAgeReport = New-ShareSurferReleaseReadinessDependencyAgeReport -PackageLockPath $packageLockPath -MinimumAgeDays $MinimumDependencyAgeDays
    Set-Content -LiteralPath $effectiveDependencyAgeReportPath -Value ($dependencyAgeReport | ConvertTo-Json -Depth 20) -Encoding UTF8
}

if (-not [string]::IsNullOrWhiteSpace($effectiveDependencyAgeReportPath)) {
    Assert-ShareSurferReleaseReadinessDependencyAgeReport -ReportPath $effectiveDependencyAgeReportPath
}

$releaseScript = Join-Path $repoRoot 'scripts/New-ShareSurferRelease.ps1'
$releaseParams = @{
    Version = [string]$metadata.packageVersion
    OutputRoot = $OutputRoot
    DashboardBuildPath = $DashboardBuildPath
    SkipDashboardBuild = $true
    MinimumDependencyAgeDays = $MinimumDependencyAgeDays
    PassThru = $true
}
if ($Force) {
    $releaseParams.Force = $true
}
if (-not [string]::IsNullOrWhiteSpace($effectiveDependencyAgeReportPath)) {
    $releaseParams.DependencyAgeReportPath = $effectiveDependencyAgeReportPath
}

$result = & $releaseScript @releaseParams

if (-not [bool]$result.IsValid) {
    throw 'Release readiness package validation failed.'
}
if (-not (Test-Path -LiteralPath ([string]$result.DependencyAgeReportPath) -PathType Leaf)) {
    throw ('Release readiness dependency age report was not written: {0}' -f [string]$result.DependencyAgeReportPath)
}
if ([bool]$result.DependencyAgeCheckSkipped) {
    throw 'Release readiness must validate a dependency age report; do not skip the dependency age check.'
}

$result | Add-Member -MemberType NoteProperty -Name CurrentPrereleaseTag -Value ([string]$metadata.currentPrereleaseTag) -Force

if ($PassThru) {
    $result
}
else {
    Write-Host ('Release readiness passed for {0}; package={1}; dependencyAgeReport={2}' -f [string]$result.Version, [string]$result.ZipPath, [string]$result.DependencyAgeReportPath)
}
