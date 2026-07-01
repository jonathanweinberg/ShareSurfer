function Add-ShareSurferPartialReason {
    param(
        [Parameter(Mandatory = $true)]
        $ShareRow,

        [string] $Reason = ''
    )

    if ($null -eq $ShareRow -or [string]::IsNullOrWhiteSpace($Reason)) {
        return
    }

    $ShareRow.PartialData = $true
    $existingReason = ''
    if ($null -ne $ShareRow.PSObject.Properties['PartialReason']) {
        $existingReason = [string]$ShareRow.PartialReason
    }

    if ([string]::IsNullOrWhiteSpace($existingReason)) {
        $ShareRow.PartialReason = $Reason
    }
    elseif ($existingReason -notlike ('*{0}*' -f $Reason)) {
        $ShareRow.PartialReason = '{0}; {1}' -f $existingReason.TrimEnd('.', ';', ' '), $Reason
    }
}
