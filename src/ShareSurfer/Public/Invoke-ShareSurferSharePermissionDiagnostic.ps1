function Invoke-ShareSurferSharePermissionDiagnostic {
    [CmdletBinding()]
    param(
        [string[]] $TargetPath = @(),

        [string[]] $ComputerName = @(),

        [string[]] $ShareName = @(),

        [Parameter(Mandatory = $true)]
        [string] $OutputPath,

        [int] $TimeoutMilliseconds = 1500,

        [switch] $SkipNetworkTests,

        [switch] $SkipCimChecks,

        [switch] $SkipNativeChecks,

        [ValidateSet('StableToken', 'Strict')]
        [string] $RedactionMode = 'StableToken',

        [string] $RedactionSalt = '',

        [switch] $Force,

        [switch] $NoCreateMissingFolders,

        [switch] $Quiet,

        [switch] $PassThru
    )

    Write-ShareSurferStatus -Phase 'Diagnostics' -Message 'Starting intensive share-permission diagnostics. This checks collection capability, not only open ports.' -Quiet:$Quiet
    Write-ShareSurferStatus -Phase 'Diagnostics' -Message 'The run will record CIM, SMB/RPC, share descriptor, descriptor-parse, and filesystem owner/DACL attempts where applicable.' -Quiet:$Quiet

    $result = Invoke-ShareSurferFileShareConnectivityAssessment `
        -TargetPath $TargetPath `
        -ComputerName $ComputerName `
        -ShareName $ShareName `
        -OutputPath $OutputPath `
        -TimeoutMilliseconds $TimeoutMilliseconds `
        -SkipNetworkTests:$SkipNetworkTests `
        -SkipCimChecks:$SkipCimChecks `
        -SkipNativeChecks:$SkipNativeChecks `
        -RedactionMode $RedactionMode `
        -RedactionSalt $RedactionSalt `
        -Force:$Force `
        -NoCreateMissingFolders:$NoCreateMissingFolders `
        -Quiet:$Quiet `
        -PassThru

    Write-ShareSurferStatus -Phase 'Diagnostics' -Message ('Open this first: {0}' -f $result.SharePermissionDiagnosticSummaryPath) -Quiet:$Quiet
    Write-ShareSurferStatus -Phase 'Diagnostics' -Message ('Then inspect raw rows: {0}' -f $result.SharePermissionDiagnosticPath) -Quiet:$Quiet
    Write-ShareSurferStatus -Phase 'Diagnostics' -Message ('For support cases, share the redacted folder: {0}' -f $result.RedactedOutputPath) -Quiet:$Quiet

    if ($PassThru) {
        $result
    }
}
