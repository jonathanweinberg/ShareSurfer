Set-StrictMode -Version 2.0

$privateScripts = Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'Private') -Filter '*.ps1' -ErrorAction SilentlyContinue
$publicScripts = Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'Public') -Filter '*.ps1' -ErrorAction SilentlyContinue

foreach ($script in @($privateScripts + $publicScripts)) {
    . $script.FullName
}

Export-ModuleMember -Function @(
    'ConvertTo-ShareSurferReport',
    'Invoke-ShareSurferScan',
    'New-ShareSurferLabFixture',
    'New-ShareSurferSupportBundle',
    'Test-ShareSurferExport'
)
