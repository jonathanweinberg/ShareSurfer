function Get-ShareSurferSharePermissionRows {
    param(
        [Parameter(Mandatory = $true)]
        [string] $ShareId,

        [Parameter(Mandatory = $true)]
        [string] $ShareName,

        [string] $ComputerName = '',

        $CimSession = $null,

        [switch] $SkipRemoteCimSessionCreation,

        [switch] $PassThruResult
    )

    $result = [ordered]@{
        Rows = @()
        Attempted = $false
        Completed = $false
        ErrorType = ''
        Severity = ''
        Source = 'Get-SmbShareAccess'
        Message = ''
        Detail = ''
    }

    $command = Get-Command Get-SmbShareAccess -ErrorAction SilentlyContinue
    if ($null -eq $command) {
        $result.ErrorType = 'GetSmbShareAccessUnavailable'
        $result.Severity = 'Review'
        $result.Message = 'Get-SmbShareAccess command is unavailable.'
        $result.Detail = 'ShareSurfer could not attempt PowerShell SMB share-permission collection because Get-SmbShareAccess is not present on this collector.'
        if ($PassThruResult) {
            return [pscustomobject]$result
        }
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
                $result.ErrorType = 'CimSessionRequired'
                $result.Severity = 'Review'
                $result.Message = 'A remote CIM session is required before Get-SmbShareAccess can collect share permissions for this target.'
                $result.Detail = ('ComputerName={0}; ShareName={1}; SkipRemoteCimSessionCreation={2}' -f $ComputerName, $ShareName, [bool]$SkipRemoteCimSessionCreation)
                if ($PassThruResult) {
                    return [pscustomobject]$result
                }
                return @()
            }

            $result.Attempted = $true
            $accessRows = @(Get-SmbShareAccess -Name $ShareName -CimSession $CimSession)
        }
        else {
            $result.Attempted = $true
            $accessRows = @(Get-SmbShareAccess -Name $ShareName)
        }
        $rows = foreach ($access in $accessRows) {
            [pscustomobject]@{
                ShareId = $ShareId
                Identity = [string]$access.AccountName
                Rights = [string]$access.AccessRight
                AccessMask = ''
                AccessControlType = [string]$access.AccessControlType
                Source = 'Get-SmbShareAccess'
            }
        }
        $result.Rows = @($rows)
        $result.Completed = $true
    }
    catch {
        $result.ErrorType = 'GetSmbShareAccessError'
        $result.Severity = 'Warning'
        $result.Message = [string]$_.Exception.Message
        $result.Detail = ('ComputerName={0}; ShareName={1}' -f $ComputerName, $ShareName)
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
        if ($null -ne $createdCimSession) {
            Remove-CimSession -CimSession $createdCimSession -ErrorAction SilentlyContinue
        }
    }

    if ($PassThruResult) {
        return [pscustomobject]$result
    }

    @($result.Rows)
}
