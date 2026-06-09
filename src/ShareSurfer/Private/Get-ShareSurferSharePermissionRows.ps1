function Get-ShareSurferSharePermissionRows {
    param(
        [Parameter(Mandatory = $true)]
        [string] $ShareId,

        [Parameter(Mandatory = $true)]
        [string] $ShareName,

        [string] $ComputerName = '',

        $CimSession = $null,

        [switch] $SkipRemoteCimSessionCreation
    )

    $command = Get-Command Get-SmbShareAccess -ErrorAction SilentlyContinue
    if ($null -eq $command) {
        return @()
    }

    $createdCimSession = $null
    $previousErrorActionPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Stop'
        if (Test-ShareSurferRemoteComputerName -ComputerName $ComputerName) {
            if ($null -eq $CimSession -and -not $SkipRemoteCimSessionCreation) {
                $newCimSession = Get-Command New-CimSession -ErrorAction SilentlyContinue
                if ($null -ne $newCimSession) {
                    $createdCimSession = New-CimSession -ComputerName $ComputerName
                    $CimSession = $createdCimSession
                }
            }

            if ($null -eq $CimSession) {
                return @()
            }

            $accessRows = @(Get-SmbShareAccess -Name $ShareName -CimSession $CimSession)
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
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
        if ($null -ne $createdCimSession) {
            Remove-CimSession -CimSession $createdCimSession -ErrorAction SilentlyContinue
        }
    }
}
