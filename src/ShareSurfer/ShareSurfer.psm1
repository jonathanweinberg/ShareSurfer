Set-StrictMode -Version 2.0

$privateScripts = Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'Private') -Filter '*.ps1' -ErrorAction SilentlyContinue
$publicScripts = Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'Public') -Filter '*.ps1' -ErrorAction SilentlyContinue

foreach ($script in @($privateScripts + $publicScripts)) {
    . $script.FullName
}

Export-ModuleMember -Function @(
    'ConvertTo-ShareSurferReport',
    'Import-ShareSurferOwnershipSource',
    'Invoke-ShareSurferOpenFileAssessment',
    'Invoke-ShareSurferPortProtocolAssessment',
    'Invoke-ShareSurferScan',
    'Join-ShareSurferOwnershipSources',
    'New-ShareSurferOwnershipMappingProfile',
    'New-ShareSurferOwnerMappingDraft',
    'New-ShareSurferLabFixture',
    'New-ShareSurferSupportBundle',
    'Test-ShareSurferExport',
    'Test-ShareSurferOwnershipSource'
)
