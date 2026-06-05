[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$pesterTestPath = Join-Path $repoRoot 'tests\ShareSurfer.Tests.ps1'

$pester = Get-Module -ListAvailable Pester | Sort-Object Version -Descending | Select-Object -First 1
if ($null -eq $pester) {
    throw 'Pester is not installed. Run tests\Invoke-ShareSurferTests.ps1 for the dependency-free suite, or install Pester and rerun this script.'
}

Import-Module Pester -ErrorAction Stop
Invoke-Pester -Path $pesterTestPath
