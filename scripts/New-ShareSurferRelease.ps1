[CmdletBinding()]
param(
    [string] $Version = '',

    [string] $OutputRoot = '',

    [string] $DashboardBuildPath = '',

    [switch] $SkipDashboardBuild,

    [switch] $SkipNpmInstall,

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

function Get-ShareSurferReleaseVersion {
    param([string] $ManifestPath)

    $manifest = Test-ModuleManifest -Path $ManifestPath
    [string]$manifest.Version
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
    $gitOutput = & git -C $RepoRoot ls-files -- README.md LICENSE src scripts docs 2>$null
    if ($LASTEXITCODE -eq 0) {
        $trackedFiles = @($gitOutput)
    }

    if ($trackedFiles.Count -eq 0) {
        $roots = @('README.md', 'LICENSE', 'src', 'scripts', 'docs')
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

    $trackedFiles
}

function Test-ShareSurferReleaseExcludedPath {
    param([string] $RelativePath)

    $normalizedPath = $RelativePath.Replace('\', '/')
    $normalizedPath -like 'docs/lab-evidence/*' -or
        $normalizedPath -like 'docs/.generated/*' -or
        $normalizedPath -like 'interface/standalone-dashboard/node_modules/*'
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
        $hash = Get-FileHash -Algorithm SHA256 -LiteralPath $file.FullName
        '{0}  {1}' -f $hash.Hash, $relativePath
    }

    Set-Content -LiteralPath $OutputPath -Value $hashRows -Encoding UTF8
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$moduleManifestPath = Join-Path (Join-Path $repoRoot 'src') (Join-Path 'ShareSurfer' 'ShareSurfer.psd1')
if ([string]::IsNullOrWhiteSpace($Version)) {
    $Version = Get-ShareSurferReleaseVersion -ManifestPath $moduleManifestPath
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
$packageName = 'ShareSurfer-{0}' -f $Version
$packageRoot = Join-Path $OutputRoot $packageName
$zipPath = Join-Path $OutputRoot ('{0}.zip' -f $packageName)
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
    if (-not (Test-ShareSurferReleaseExcludedPath -RelativePath $relativePath)) {
        Copy-ShareSurferReleaseFile -RepoRoot $repoRoot -PackageRoot $packageRoot -RelativePath $relativePath
    }
}

Copy-ShareSurferDashboardBuild -DashboardBuildPath $DashboardBuildPath -PackageRoot $packageRoot

$gitCommit = ''
$gitCommitOutput = & git -C $repoRoot rev-parse HEAD 2>$null
if ($LASTEXITCODE -eq 0) {
    $gitCommit = [string]$gitCommitOutput
}

$dashboardPackagePath = 'interface/standalone-dashboard/dist'
$manifest = [ordered]@{
    packageName = $packageName
    version = $Version
    generatedAt = [DateTimeOffset]::UtcNow.ToString('o')
    sourceCommit = $gitCommit
    signingStatus = 'UnsignedPre1.0'
    signed = $false
    includesPrebuiltStandaloneDashboard = $true
    dashboardPackagePath = $dashboardPackagePath
    dashboardEntryPoint = 'interface/standalone-dashboard/dist/index.html'
    moduleManifest = 'src/ShareSurfer/ShareSurfer.psd1'
    packageNotes = 'Unsigned pre-1.0 package. Dashboard assets are prebuilt so release users do not need npm, Vite, a server, or internet access to package a standalone dashboard from an export.'
}

$manifestPath = Join-Path $packageRoot 'release-manifest.json'
Set-Content -LiteralPath $manifestPath -Value ($manifest | ConvertTo-Json -Depth 8) -Encoding UTF8

$releaseNotes = @(
    '# ShareSurfer Release Package',
    '',
    ('Version: {0}' -f $Version),
    '',
    'This is an unsigned pre-1.0 package.',
    '',
    'The standalone dashboard assets are already built under `interface/standalone-dashboard/dist`.',
    'No npm, Vite, development server, or internet access is required after this release package is unpacked.',
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

Compress-Archive -Path $packageRoot -DestinationPath $zipPath -Force
$zipHash = Get-FileHash -Algorithm SHA256 -LiteralPath $zipPath
Set-Content -LiteralPath $zipHashPath -Value ('{0}  {1}' -f $zipHash.Hash, (Split-Path -Leaf $zipPath)) -Encoding UTF8

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
    DashboardBuildPath = $DashboardBuildPath
    FileCount = @(Get-ChildItem -LiteralPath $packageRoot -File -Recurse).Count
}

if ($PassThru) {
    $result
}
