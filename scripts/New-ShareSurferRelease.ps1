[CmdletBinding()]
param(
    [string] $Version = '',

    [string] $OutputRoot = '',

    [string] $DashboardBuildPath = '',

    [switch] $SkipDashboardBuild,

    [switch] $SkipNpmInstall,

    [int] $MinimumDependencyAgeDays = -1,

    [string] $DependencyAgeReportPath = '',

    [switch] $SkipDependencyAgeCheck,

    [switch] $Force,

    [switch] $PassThru
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Invoke-ShareSurferReleaseCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string] $FilePath,

        [Parameter(Mandatory = $true)]
        [string[]] $ArgumentList,

        [string] $WorkingDirectory = ''
    )

    $previousLocation = Get-Location
    try {
        if (-not [string]::IsNullOrWhiteSpace($WorkingDirectory)) {
            Set-Location -LiteralPath $WorkingDirectory
        }

        $output = @(& $FilePath @ArgumentList 2>&1)
        $exitCode = $LASTEXITCODE
        foreach ($line in $output) {
            Write-Host $line
        }

        if ($exitCode -ne 0) {
            throw ('Command failed with exit code {0}: {1} {2}' -f $exitCode, $FilePath, ($ArgumentList -join ' '))
        }
    }
    finally {
        Set-Location -LiteralPath $previousLocation
    }
}

function Get-ShareSurferReleaseMetadataPath {
    param([string] $RepoRoot)

    Join-Path $RepoRoot 'release-metadata.json'
}

function Get-ShareSurferReleaseMetadata {
    param([string] $RepoRoot)

    $metadataPath = Get-ShareSurferReleaseMetadataPath -RepoRoot $RepoRoot
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
        'minimumDependencyAgeDays',
        'releaseNotesSummary',
        'docsReferencePaths',
        'internalPackageExcludePaths'
    )
    foreach ($field in $requiredFields) {
        if ($null -eq $metadata.PSObject.Properties[$field] -or [string]::IsNullOrWhiteSpace([string]$metadata.$field)) {
            throw ('Release metadata is missing required field {0}: {1}' -f $field, $metadataPath)
        }
    }

    $expectedTag = 'v{0}' -f [string]$metadata.packageVersion
    $expectedPackageName = 'ShareSurfer-{0}' -f [string]$metadata.packageVersion
    $expectedZipFileName = '{0}.zip' -f $expectedPackageName
    if ([string]$metadata.currentPrereleaseTag -ne $expectedTag) {
        throw ('Release metadata tag/version mismatch. Expected {0}; found {1}.' -f $expectedTag, [string]$metadata.currentPrereleaseTag)
    }
    if ([string]$metadata.packageName -ne $expectedPackageName) {
        throw ('Release metadata package/version mismatch. Expected {0}; found {1}.' -f $expectedPackageName, [string]$metadata.packageName)
    }
    if ([string]$metadata.zipAssetName -ne $expectedZipFileName) {
        throw ('Release metadata zip/version mismatch. Expected {0}; found {1}.' -f $expectedZipFileName, [string]$metadata.zipAssetName)
    }
    if ([int]$metadata.minimumDependencyAgeDays -lt 0) {
        throw ('Release metadata minimumDependencyAgeDays must be zero or greater: {0}' -f $metadataPath)
    }

    $metadata | Add-Member -MemberType NoteProperty -Name MetadataPath -Value $metadataPath -Force
    $metadata
}

function ConvertTo-ShareSurferReleaseVersion {
    param([string] $Value)

    $normalized = ([string]$Value).Trim()
    if ($normalized.StartsWith('v')) {
        $normalized = $normalized.Substring(1)
    }

    $normalized
}

function Assert-ShareSurferReleaseVersionMatchesMetadata {
    param(
        [string] $RequestedVersion,
        [object] $ReleaseMetadata
    )

    if ([string]::IsNullOrWhiteSpace($RequestedVersion)) {
        return
    }

    $normalizedRequested = ConvertTo-ShareSurferReleaseVersion -Value $RequestedVersion
    $metadataVersion = [string]$ReleaseMetadata.packageVersion
    if ($normalizedRequested -ne $metadataVersion) {
        throw ('Release version "{0}" does not match release metadata version "{1}" in {2}. Update release-metadata.json first, or pass the metadata version.' -f $RequestedVersion, $metadataVersion, [string]$ReleaseMetadata.MetadataPath)
    }
}

function Copy-ShareSurferReleaseFile {
    param(
        [Parameter(Mandatory = $true)]
        [string] $RepoRoot,

        [Parameter(Mandatory = $true)]
        [string] $PackageRoot,

        [Parameter(Mandatory = $true)]
        [string] $RelativePath
    )

    $normalizedPath = $RelativePath.Replace('\', '/')
    $sourcePath = Join-Path $RepoRoot $normalizedPath
    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
        return
    }

    $destinationPath = Join-Path $PackageRoot $normalizedPath
    $destinationDirectory = Split-Path -Parent $destinationPath
    if (-not (Test-Path -LiteralPath $destinationDirectory)) {
        New-Item -ItemType Directory -Path $destinationDirectory -Force | Out-Null
    }

    Copy-Item -LiteralPath $sourcePath -Destination $destinationPath -Force
}

function Get-ShareSurferReleaseSourceFiles {
    param([string] $RepoRoot)

    $trackedFiles = @()
    $gitOutput = & git -C $RepoRoot ls-files -- README.md LICENSE release-metadata.json src scripts docs 2>$null
    if ($LASTEXITCODE -eq 0) {
        $trackedFiles = @($gitOutput)
    }

    if ($trackedFiles.Count -eq 0) {
        $roots = @('README.md', 'LICENSE', 'release-metadata.json', 'src', 'scripts', 'docs')
        foreach ($root in $roots) {
            $path = Join-Path $RepoRoot $root
            if (Test-Path -LiteralPath $path -PathType Leaf) {
                $root
            }
            elseif (Test-Path -LiteralPath $path -PathType Container) {
                Get-ChildItem -LiteralPath $path -File -Recurse | ForEach-Object {
                    $_.FullName.Substring($RepoRoot.Length + 1).Replace('\', '/')
                }
            }
        }
        return
    }

    $releaseScript = 'scripts/New-ShareSurferRelease.ps1'
    if ($trackedFiles -notcontains $releaseScript) {
        $trackedFiles += $releaseScript
    }

    $releaseMetadata = 'release-metadata.json'
    if ($trackedFiles -notcontains $releaseMetadata -and (Test-Path -LiteralPath (Join-Path $RepoRoot $releaseMetadata) -PathType Leaf)) {
        $trackedFiles += $releaseMetadata
    }

    $trackedFiles
}

function Test-ShareSurferReleaseExcludedPath {
    param(
        [string] $RelativePath,
        [string[]] $MetadataExcludePatterns = @()
    )

    $normalizedPath = $RelativePath.Replace('\', '/')
    $excludePatterns = @(
        'docs/lab-evidence/*',
        'docs/.generated/*',
        'interface/standalone-dashboard/node_modules/*'
    ) + @($MetadataExcludePatterns)

    foreach ($pattern in $excludePatterns) {
        if ($normalizedPath -like $pattern) {
            return $true
        }
    }

    $false
}

function Copy-ShareSurferDashboardBuild {
    param(
        [Parameter(Mandatory = $true)]
        [string] $DashboardBuildPath,

        [Parameter(Mandatory = $true)]
        [string] $PackageRoot
    )

    $destinationPath = Join-Path (Join-Path (Join-Path $PackageRoot 'interface') 'standalone-dashboard') 'dist'
    if (Test-Path -LiteralPath $destinationPath) {
        Remove-Item -LiteralPath $destinationPath -Recurse -Force
    }

    New-Item -ItemType Directory -Path $destinationPath -Force | Out-Null
    foreach ($child in @(Get-ChildItem -LiteralPath $DashboardBuildPath -Force)) {
        Copy-Item -LiteralPath $child.FullName -Destination $destinationPath -Recurse -Force
    }
}

function Set-ShareSurferDashboardTemplateSnapshot {
    param(
        [Parameter(Mandatory = $true)]
        [string] $PackageRoot
    )

    $dataScriptPath = Join-Path (Join-Path (Join-Path (Join-Path $PackageRoot 'interface') 'standalone-dashboard') 'dist') 'sharesurfer-data.js'
    $templateSnapshot = [ordered]@{
        snapshotKind = 'template'
        generatedAt = [DateTimeOffset]::UtcNow.ToString('o')
        datasets = [ordered]@{}
    }
    $snapshotScript = 'window.__SHARESURFER_SNAPSHOT__ = {0};' -f ($templateSnapshot | ConvertTo-Json -Depth 8 -Compress)
    Set-Content -LiteralPath $dataScriptPath -Value $snapshotScript -Encoding UTF8
}

function Get-ShareSurferFileSha256 {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Path
    )

    $stream = [System.IO.File]::OpenRead($Path)
    try {
        $sha256 = [System.Security.Cryptography.SHA256]::Create()
        try {
            $hashBytes = $sha256.ComputeHash($stream)
            ([System.BitConverter]::ToString($hashBytes) -replace '-', '')
        }
        finally {
            if ($sha256 -is [System.IDisposable]) {
                $sha256.Dispose()
            }
        }
    }
    finally {
        $stream.Dispose()
    }
}

function New-ShareSurferReleaseHashFile {
    param(
        [Parameter(Mandatory = $true)]
        [string] $PackageRoot,

        [Parameter(Mandatory = $true)]
        [string] $OutputPath
    )

    $rootPath = (Resolve-Path -LiteralPath $PackageRoot).Path.TrimEnd('\', '/')
    $hashRows = foreach ($file in @(Get-ChildItem -LiteralPath $PackageRoot -File -Recurse | Sort-Object FullName)) {
        if ($file.FullName -eq $OutputPath) {
            continue
        }

        $relativePath = $file.FullName.Substring($rootPath.Length + 1).Replace('\', '/')
        $hash = Get-ShareSurferFileSha256 -Path $file.FullName
        '{0}  {1}' -f $hash, $relativePath
    }

    Set-Content -LiteralPath $OutputPath -Value $hashRows -Encoding UTF8
}

function New-ShareSurferReleaseZip {
    param(
        [Parameter(Mandatory = $true)]
        [string] $PackageRoot,

        [Parameter(Mandatory = $true)]
        [string] $ZipPath
    )

    Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction Stop
    $resolvedPackageRoot = (Resolve-Path -LiteralPath $PackageRoot).Path
    [System.IO.Compression.ZipFile]::CreateFromDirectory(
        $resolvedPackageRoot,
        $ZipPath,
        [System.IO.Compression.CompressionLevel]::Optimal,
        $true
    )
}

function Get-ShareSurferPackageLockDependencies {
    param(
        [Parameter(Mandatory = $true)]
        [string] $PackageLockPath
    )

    if (-not (Test-Path -LiteralPath $PackageLockPath -PathType Leaf)) {
        throw ('Package lock not found: {0}' -f $PackageLockPath)
    }

    $lock = Get-Content -LiteralPath $PackageLockPath -Raw | ConvertFrom-Json -AsHashtable
    if (-not $lock.ContainsKey('packages')) {
        throw ('Package lock does not include a packages map: {0}' -f $PackageLockPath)
    }

    $seen = @{}
    $packages = $lock['packages']
    foreach ($packagePath in @($packages.Keys)) {
        if ([string]::IsNullOrWhiteSpace($packagePath) -or $packagePath -notlike '*node_modules/*') {
            continue
        }

        $package = $packages[$packagePath]
        if (-not $package.ContainsKey('version') -or [string]::IsNullOrWhiteSpace([string]$package['version'])) {
            continue
        }

        $name = ($packagePath -split 'node_modules/')[-1].Trim('/')
        if ([string]::IsNullOrWhiteSpace($name)) {
            continue
        }

        $key = '{0}@{1}' -f $name, [string]$package['version']
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

function New-ShareSurferDependencyAgeReport {
    param(
        [Parameter(Mandatory = $true)]
        [string] $PackageLockPath,

        [int] $MinimumAgeDays = 7
    )

    $checkedAt = [DateTimeOffset]::UtcNow
    $cutoff = $checkedAt.AddDays(-1 * $MinimumAgeDays)
    $dependencies = @(Get-ShareSurferPackageLockDependencies -PackageLockPath $PackageLockPath | Sort-Object name, version)
    $rows = New-Object System.Collections.Generic.List[object]
    $violations = New-Object System.Collections.Generic.List[object]
    $unknown = New-Object System.Collections.Generic.List[object]

    foreach ($dependency in $dependencies) {
        $encodedName = [uri]::EscapeDataString([string]$dependency.name)
        $metadataUri = 'https://registry.npmjs.org/{0}' -f $encodedName
        $publishedAt = ''
        $ageDays = $null
        $status = 'Unknown'

        try {
            $metadata = Invoke-RestMethod -Uri $metadataUri -Method Get -ErrorAction Stop
            $timeProperty = $metadata.time.PSObject.Properties[[string]$dependency.version]
            if ($null -ne $timeProperty -and -not [string]::IsNullOrWhiteSpace([string]$timeProperty.Value)) {
                $published = [DateTimeOffset]::Parse([string]$timeProperty.Value).ToUniversalTime()
                $publishedAt = $published.ToString('o')
                $ageDays = [math]::Floor(($checkedAt - $published).TotalDays)
                $status = if ($published -gt $cutoff) { 'TooNew' } else { 'Allowed' }
            }
        }
        catch {
            $status = 'Unknown'
        }

        $row = [pscustomobject]@{
            name = [string]$dependency.name
            version = [string]$dependency.version
            publishedAt = $publishedAt
            ageDays = $ageDays
            status = $status
        }
        [void]$rows.Add($row)

        if ($status -eq 'TooNew') {
            [void]$violations.Add($row)
        }
        elseif ($status -eq 'Unknown') {
            [void]$unknown.Add($row)
        }
    }

    [pscustomobject]@{
        isValid = ($violations.Count -eq 0 -and $unknown.Count -eq 0)
        skipped = $false
        checkedAt = $checkedAt.ToString('o')
        packageLockPath = (Resolve-Path -LiteralPath $PackageLockPath).Path
        minimumAgeDays = $MinimumAgeDays
        cutoffUtc = $cutoff.ToString('o')
        dependencyCount = $dependencies.Count
        violationCount = $violations.Count
        unknownCount = $unknown.Count
        violations = @($violations.ToArray())
        unknown = @($unknown.ToArray())
        dependencies = @($rows.ToArray())
    }
}

function New-ShareSurferSkippedDependencyAgeReport {
    param([int] $MinimumAgeDays = 7)

    [pscustomobject]@{
        isValid = $true
        skipped = $true
        checkedAt = [DateTimeOffset]::UtcNow.ToString('o')
        packageLockPath = ''
        minimumAgeDays = $MinimumAgeDays
        cutoffUtc = ''
        dependencyCount = 0
        violationCount = 0
        unknownCount = 0
        violations = @()
        unknown = @()
        dependencies = @()
    }
}

function Get-ShareSurferDependencyAgeReport {
    param(
        [Parameter(Mandatory = $true)]
        [string] $DashboardRoot,

        [int] $MinimumAgeDays = 7,

        [string] $ReportPath = '',

        [switch] $Skip
    )

    if ($Skip) {
        return New-ShareSurferSkippedDependencyAgeReport -MinimumAgeDays $MinimumAgeDays
    }

    if (-not [string]::IsNullOrWhiteSpace($ReportPath)) {
        if (-not (Test-Path -LiteralPath $ReportPath -PathType Leaf)) {
            throw ('Dependency age report not found: {0}' -f $ReportPath)
        }

        $report = Get-Content -LiteralPath $ReportPath -Raw | ConvertFrom-Json
        if ($null -eq $report.PSObject.Properties['isValid']) {
            throw ('Dependency age report does not include isValid: {0}' -f $ReportPath)
        }

        return $report
    }

    $packageLockPath = Join-Path $DashboardRoot 'package-lock.json'
    New-ShareSurferDependencyAgeReport -PackageLockPath $packageLockPath -MinimumAgeDays $MinimumAgeDays
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$releaseMetadata = Get-ShareSurferReleaseMetadata -RepoRoot $repoRoot
Assert-ShareSurferReleaseVersionMatchesMetadata -RequestedVersion $Version -ReleaseMetadata $releaseMetadata
$Version = [string]$releaseMetadata.packageVersion

if ($MinimumDependencyAgeDays -lt 0) {
    $MinimumDependencyAgeDays = [int]$releaseMetadata.minimumDependencyAgeDays
}

if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
    $OutputRoot = Join-Path $repoRoot 'artifacts'
}

$dashboardRoot = Join-Path (Join-Path $repoRoot 'interface') 'standalone-dashboard'
if (-not $SkipDashboardBuild -and -not [string]::IsNullOrWhiteSpace($DashboardBuildPath)) {
    throw 'DashboardBuildPath points to an existing build. Use -SkipDashboardBuild when supplying DashboardBuildPath.'
}

if ([string]::IsNullOrWhiteSpace($DashboardBuildPath)) {
    $DashboardBuildPath = Join-Path $dashboardRoot 'dist'
}

if (-not $SkipDashboardBuild) {
    if (-not $SkipNpmInstall) {
        Invoke-ShareSurferReleaseCommand -FilePath 'npm' -ArgumentList @('--prefix', $dashboardRoot, 'ci') -WorkingDirectory $repoRoot
    }

    Invoke-ShareSurferReleaseCommand -FilePath 'npm' -ArgumentList @('--prefix', $dashboardRoot, 'run', 'build') -WorkingDirectory $repoRoot
}

$dashboardIndexPath = Join-Path $DashboardBuildPath 'index.html'
if (-not (Test-Path -LiteralPath $dashboardIndexPath -PathType Leaf)) {
    throw ('Dashboard build output not found: {0}' -f $dashboardIndexPath)
}

New-Item -ItemType Directory -Path $OutputRoot -Force | Out-Null
$dependencyAgeReport = Get-ShareSurferDependencyAgeReport -DashboardRoot $dashboardRoot -MinimumAgeDays $MinimumDependencyAgeDays -ReportPath $DependencyAgeReportPath -Skip:$SkipDependencyAgeCheck
if ($null -eq $dependencyAgeReport.PSObject.Properties['isValid'] -or -not [bool]$dependencyAgeReport.isValid) {
    $failedReportPath = Join-Path $OutputRoot 'dependency-age-report.failed.json'
    Set-Content -LiteralPath $failedReportPath -Value ($dependencyAgeReport | ConvertTo-Json -Depth 20) -Encoding UTF8
    $violationNames = @()
    if ($null -ne $dependencyAgeReport.PSObject.Properties['violations']) {
        $violationNames = @($dependencyAgeReport.violations | Select-Object -First 5 | ForEach-Object { '{0}@{1}' -f $_.name, $_.version })
    }
    $unknownNames = @()
    if ($null -ne $dependencyAgeReport.PSObject.Properties['unknown']) {
        $unknownNames = @($dependencyAgeReport.unknown | Select-Object -First 5 | ForEach-Object { '{0}@{1}' -f $_.name, $_.version })
    }
    throw ('NPM dependency age policy failed. Wrote {0}. Too new: {1}. Unknown: {2}.' -f $failedReportPath, (($violationNames -join ', ') -replace '^$', 'none'), (($unknownNames -join ', ') -replace '^$', 'none'))
}

$packageName = [string]$releaseMetadata.packageName
$packageRoot = Join-Path $OutputRoot $packageName
$zipPath = Join-Path $OutputRoot ([string]$releaseMetadata.zipAssetName)
$zipHashPath = '{0}.sha256' -f $zipPath

foreach ($path in @($packageRoot, $zipPath, $zipHashPath)) {
    if (Test-Path -LiteralPath $path) {
        if (-not $Force) {
            throw ('Release output already exists. Pass -Force to replace it: {0}' -f $path)
        }

        Remove-Item -LiteralPath $path -Recurse -Force
    }
}

New-Item -ItemType Directory -Path $packageRoot -Force | Out-Null
$sourceFiles = @(Get-ShareSurferReleaseSourceFiles -RepoRoot $repoRoot | Sort-Object -Unique)
foreach ($relativePath in $sourceFiles) {
    if (-not (Test-ShareSurferReleaseExcludedPath -RelativePath $relativePath -MetadataExcludePatterns @($releaseMetadata.internalPackageExcludePaths))) {
        Copy-ShareSurferReleaseFile -RepoRoot $repoRoot -PackageRoot $packageRoot -RelativePath $relativePath
    }
}

Copy-ShareSurferDashboardBuild -DashboardBuildPath $DashboardBuildPath -PackageRoot $packageRoot
Set-ShareSurferDashboardTemplateSnapshot -PackageRoot $packageRoot

$dependencyAgeReportOutputPath = Join-Path $packageRoot 'dependency-age-report.json'
Set-Content -LiteralPath $dependencyAgeReportOutputPath -Value ($dependencyAgeReport | ConvertTo-Json -Depth 20) -Encoding UTF8

$gitCommit = ''
$gitCommitOutput = & git -C $repoRoot rev-parse HEAD 2>$null
if ($LASTEXITCODE -eq 0) {
    $gitCommit = [string]$gitCommitOutput
}

$dashboardPackagePath = 'interface/standalone-dashboard/dist'
$manifest = [ordered]@{
    packageName = $packageName
    version = $Version
    currentPrereleaseTag = [string]$releaseMetadata.currentPrereleaseTag
    releaseUrl = [string]$releaseMetadata.releaseUrl
    releaseMetadata = 'release-metadata.json'
    generatedAt = [DateTimeOffset]::UtcNow.ToString('o')
    sourceCommit = $gitCommit
    signingStatus = 'UnsignedPre1.0'
    signed = $false
    includesPrebuiltStandaloneDashboard = $true
    dashboardAssetKind = 'Template'
    dashboardRequiresExportPackaging = $true
    dashboardPackagePath = $dashboardPackagePath
    dashboardEntryPoint = 'interface/standalone-dashboard/dist/index.html'
    dependencyAgePolicy = ('NPM dependency versions must be at least {0} days old unless the check is explicitly skipped for a local/offline dry run.' -f $MinimumDependencyAgeDays)
    minimumDependencyAgeDays = $MinimumDependencyAgeDays
    dependencyAgeReport = 'dependency-age-report.json'
    dependencyAgeCheckSkipped = [bool]$dependencyAgeReport.skipped
    dependencyAgeViolationCount = if ($null -ne $dependencyAgeReport.PSObject.Properties['violationCount']) { [int]$dependencyAgeReport.violationCount } else { 0 }
    dependencyAgeUnknownCount = if ($null -ne $dependencyAgeReport.PSObject.Properties['unknownCount']) { [int]$dependencyAgeReport.unknownCount } else { 0 }
    moduleManifest = 'src/ShareSurfer/ShareSurfer.psd1'
    packageNotes = [string]$releaseMetadata.releaseNotesSummary
}

$manifestPath = Join-Path $packageRoot 'release-manifest.json'
Set-Content -LiteralPath $manifestPath -Value ($manifest | ConvertTo-Json -Depth 8) -Encoding UTF8

$releaseNotes = @(
    '# ShareSurfer Release Package',
    '',
    ('Version: {0}' -f $Version),
    ('Release: {0}' -f [string]$releaseMetadata.currentPrereleaseTag),
    ('Release URL: {0}' -f [string]$releaseMetadata.releaseUrl),
    '',
    'This is an unsigned pre-1.0 package.',
    '',
    'The standalone dashboard assets are already built under `interface/standalone-dashboard/dist`.',
    'These are template dashboard assets, not scan evidence. Package a validated export before using the dashboard for review.',
    'No npm, Vite, development server, or internet access is required after this release package is unpacked.',
    ('NPM dependency versions were checked against a minimum age policy: package versions must be at least {0} days old. See `dependency-age-report.json`.' -f $MinimumDependencyAgeDays),
    '',
    'To package a validated export as a standalone dashboard:',
    '',
    '```powershell',
    'pwsh -NoLogo -NoProfile -File .\scripts\New-ShareSurferStandaloneDashboard.ps1 `',
    '  -ExportPath C:\ShareSurfer\exports\scan-001 `',
    '  -OutputPath C:\ShareSurfer\exports\scan-001\standalone-dashboard `',
    '  -Force',
    '```',
    '',
    'Open `standalone-dashboard\index.html` on the review workstation.'
)
Set-Content -LiteralPath (Join-Path $packageRoot 'RELEASE.md') -Value $releaseNotes -Encoding UTF8

$hashPath = Join-Path $packageRoot 'SHA256SUMS.txt'
New-ShareSurferReleaseHashFile -PackageRoot $packageRoot -OutputPath $hashPath

New-ShareSurferReleaseZip -PackageRoot $packageRoot -ZipPath $zipPath
$zipHash = Get-ShareSurferFileSha256 -Path $zipPath
Set-Content -LiteralPath $zipHashPath -Value ('{0}  {1}' -f $zipHash, (Split-Path -Leaf $zipPath)) -Encoding UTF8

$result = [pscustomobject]@{
    IsValid = (
        (Test-Path -LiteralPath $zipPath -PathType Leaf) -and
        (Test-Path -LiteralPath $zipHashPath -PathType Leaf) -and
        (Test-Path -LiteralPath (Join-Path $packageRoot 'interface/standalone-dashboard/dist/index.html') -PathType Leaf) -and
        (Test-Path -LiteralPath $manifestPath -PathType Leaf) -and
        (Test-Path -LiteralPath $hashPath -PathType Leaf)
    )
    Version = $Version
    SigningStatus = 'UnsignedPre1.0'
    IncludesPrebuiltStandaloneDashboard = $true
    PackageRoot = $packageRoot
    ZipPath = $zipPath
    ZipHashPath = $zipHashPath
    ManifestPath = $manifestPath
    HashPath = $hashPath
    DependencyAgeReportPath = $dependencyAgeReportOutputPath
    MinimumDependencyAgeDays = $MinimumDependencyAgeDays
    DependencyAgeCheckSkipped = [bool]$dependencyAgeReport.skipped
    DashboardBuildPath = $DashboardBuildPath
    FileCount = @(Get-ChildItem -LiteralPath $packageRoot -File -Recurse).Count
}

if ($PassThru) {
    $result
}
