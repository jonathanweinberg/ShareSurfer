function Write-ShareSurferStatus {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Message,

        [string] $Phase = 'Scan',

        [switch] $Quiet
    )

    if ($Quiet) {
        return
    }

    $timestamp = Get-Date -Format 'HH:mm:ss'
    Write-Host ('[{0}] ShareSurfer {1}: {2}' -f $timestamp, $Phase, $Message)
}
