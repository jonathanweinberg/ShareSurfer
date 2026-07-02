Set-StrictMode -Version 2.0

$privateScripts = Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'Private') -Filter '*.ps1' -ErrorAction SilentlyContinue
$publicScripts = Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'Public') -Filter '*.ps1' -ErrorAction SilentlyContinue

foreach ($script in @($privateScripts + $publicScripts)) {
    . $script.FullName
}

Export-ModuleMember -Function @(
    'ConvertTo-ShareSurferReport',
    'Import-ShareSurferReviewDecisions',
    'Import-ShareSurferOwnershipSource',
    'Invoke-ShareSurferFileShareConnectivityAssessment',
    'Invoke-ShareSurferOpenFileAssessment',
    'Invoke-ShareSurferPortProtocolAssessment',
    'Invoke-ShareSurferScan',
    'Invoke-ShareSurferSharePermissionDiagnostic',
    'Join-ShareSurferOwnershipSources',
    'New-ShareSurferOwnershipMappingProfile',
    'New-ShareSurferOwnerMappingDraft',
    'New-ShareSurferReviewDecisionDraft',
    'New-ShareSurferLabFixture',
    'New-ShareSurferSupportBundle',
    'Start-ShareSurferOperatorAssistant',
    'Start-ShareSurferStartup',
    'Test-ShareSurferExport',
    'Test-ShareSurferOwnerMapping',
    'Test-ShareSurferOwnershipSource'
)
