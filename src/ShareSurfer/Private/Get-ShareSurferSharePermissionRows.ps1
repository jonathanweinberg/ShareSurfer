function Get-ShareSurferSharePermissionRows {
    param(
        [Parameter(Mandatory = $true)]
        [string] $ShareId,

        [Parameter(Mandatory = $true)]
        [string] $ShareName,

        [string] $ComputerName = ''
    )

    $command = Get-Command Get-SmbShareAccess -ErrorAction SilentlyContinue
    if ($null -eq $command) {
        return @()
    }

    try {
        if ($ComputerName -ne '' -and $ComputerName -ne [System.Environment]::MachineName -and $ComputerName -ne $env:COMPUTERNAME) {
            $accessRows = @(Get-SmbShareAccess -Name $ShareName -CimSession $ComputerName)
        }
        else {
            $accessRows = @(Get-SmbShareAccess -Name $ShareName)
        }
        foreach ($access in $accessRows) {
            [pscustomobject]@{
                ShareId = $ShareId
                Identity = [string]$access.AccountName
                Rights = [string]$access.AccessRight
                AccessControlType = [string]$access.AccessControlType
                Source = 'Get-SmbShareAccess'
            }
        }
    }
    catch {
        @()
    }
}
