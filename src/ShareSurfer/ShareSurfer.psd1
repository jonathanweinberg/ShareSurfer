@{
    RootModule = 'ShareSurfer.psm1'
    ModuleVersion = '0.1.0'
    GUID = 'd1b74a5d-6fd0-45a7-9da4-5ab63f8e6f3d'
    Author = 'Jonathan Weinberg'
    CompanyName = 'ShareSurfer'
    Copyright = '(c) 2026 Jonathan Weinberg. All rights reserved.'
    Description = 'PowerShell tooling for SMB share, NTFS ACL, identity, org, and migration-readiness reporting.'
    PowerShellVersion = '5.1'
    FunctionsToExport = @(
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
        'Test-ShareSurferOwnershipSource'
    )
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
    PrivateData = @{
        PSData = @{
            Tags = @('SMB', 'ACL', 'NTFS', 'AzureFiles', 'ActiveDirectory')
            LicenseUri = 'https://opensource.org/license/mit/'
            ProjectUri = 'https://github.com/jonathanweinberg/ShareSurfer'
        }
    }
}
