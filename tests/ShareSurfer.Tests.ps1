Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Describe 'ShareSurfer fast acceptance suite' {
    It 'passes the dependency-free PowerShell test runner' {
        $runner = Join-Path $PSScriptRoot 'Invoke-ShareSurferTests.ps1'
        $output = & $runner
        $output | Should -Not -BeNullOrEmpty
        ($output -join "`n") | Should -Match 'tests passed'
    }
}
