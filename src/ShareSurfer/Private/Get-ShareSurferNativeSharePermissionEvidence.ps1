function Get-ShareSurferNativeSharePermissionEvidence {
    param(
        [Parameter(Mandatory = $true)]
        [string] $ShareId,

        [Parameter(Mandatory = $true)]
        [string] $ComputerName,

        [Parameter(Mandatory = $true)]
        [string] $ShareName,

        $RpcShare = $null
    )

    $uncPath = '\\{0}\{1}' -f $ComputerName, $ShareName
    try {
        if ($null -eq $RpcShare) {
            $RpcShare = Get-ShareSurferSmbRpcShareInfo -ComputerName $ComputerName -ShareName $ShareName -PreferSecurityDescriptor
        }

        if ($null -eq $RpcShare) {
            return [pscustomobject]@{
                Success = $false
                Available = $false
                Rows = @()
                Source = 'NativeSmbRpc'
                ErrorType = 'NativeShareSecurityDescriptorUnavailable'
                Severity = 'Warning'
                Message = 'Native SMB/RPC did not return share metadata or a share security descriptor.'
                Detail = ('NetShareGetInfo returned no usable metadata for {0}.' -f $uncPath)
                EventType = 'NativeShareSecurityDescriptorUnavailable'
            }
        }

        $descriptorBytes = @()
        if ($null -ne $RpcShare.PSObject.Properties['SecurityDescriptorBytes'] -and $null -ne $RpcShare.SecurityDescriptorBytes) {
            $descriptorBytes = @($RpcShare.SecurityDescriptorBytes)
        }

        if ($descriptorBytes.Count -gt 0) {
            try {
                $rows = @(ConvertTo-ShareSurferSharePermissionRowsFromSecurityDescriptor -ShareId $ShareId -SecurityDescriptorBytes ([byte[]]$descriptorBytes))
                return [pscustomobject]@{
                    Success = ($rows.Count -gt 0)
                    Available = ($rows.Count -gt 0)
                    Rows = @($rows)
                    Source = 'NativeSmbRpc'
                    ErrorType = if ($rows.Count -gt 0) { '' } else { 'NativeShareSecurityDescriptorEmpty' }
                    Severity = if ($rows.Count -gt 0) { 'Info' } else { 'Warning' }
                    Message = if ($rows.Count -gt 0) { ('Collected {0} share-level permission row(s) through native SMB/RPC.' -f $rows.Count) } else { 'Native SMB/RPC returned a share security descriptor with no readable DACL ACE rows.' }
                    Detail = ('SHARE_INFO_502 security descriptor for {0}; descriptor byte count {1}.' -f $uncPath, $descriptorBytes.Count)
                    EventType = if ($rows.Count -gt 0) { 'SharePermissionsCollected' } else { 'NativeShareSecurityDescriptorEmpty' }
                }
            }
            catch {
                return [pscustomobject]@{
                    Success = $false
                    Available = $false
                    Rows = @()
                    Source = 'NativeSmbRpc'
                    ErrorType = 'NativeShareSecurityDescriptorParseFailed'
                    Severity = 'Warning'
                    Message = 'Native SMB/RPC returned a share security descriptor, but ShareSurfer could not parse it into share permission rows.'
                    Detail = ('SMB/RPC reachability was proven for {0}, but the returned SHARE_INFO_502 security descriptor was unusable. Parser message: {1}' -f $uncPath, [string]$_.Exception.Message)
                    EventType = 'NativeShareSecurityDescriptorParseFailed'
                }
            }
        }

        if ($null -ne $RpcShare.PSObject.Properties['SharePermissions']) {
            $rows = New-Object System.Collections.ArrayList
            foreach ($permission in @(ConvertTo-ShareSurferArray $RpcShare.SharePermissions)) {
                $permission | Add-Member -MemberType NoteProperty -Name ShareId -Value $ShareId -Force
                if ($null -eq $permission.PSObject.Properties['Source'] -or [string]::IsNullOrWhiteSpace([string]$permission.Source)) {
                    $permission | Add-Member -MemberType NoteProperty -Name Source -Value 'NativeSmbRpc' -Force
                }
                [void]$rows.Add($permission)
            }

            $rowArray = @(ConvertTo-ShareSurferArray $rows)
            return [pscustomobject]@{
                Success = ($rowArray.Count -gt 0)
                Available = ($rowArray.Count -gt 0)
                Rows = @($rowArray)
                Source = 'NativeSmbRpc'
                ErrorType = if ($rowArray.Count -gt 0) { '' } else { 'NativeShareSecurityDescriptorEmpty' }
                Severity = if ($rowArray.Count -gt 0) { 'Info' } else { 'Warning' }
                Message = if ($rowArray.Count -gt 0) { ('Collected {0} provider-supplied share-level permission row(s) through native SMB/RPC.' -f $rowArray.Count) } else { 'Native SMB/RPC returned provider share permission evidence with no rows.' }
                Detail = ('Provider-supplied share permission rows for {0}.' -f $uncPath)
                EventType = if ($rowArray.Count -gt 0) { 'SharePermissionsCollected' } else { 'NativeShareSecurityDescriptorEmpty' }
            }
        }

        [pscustomobject]@{
            Success = $false
            Available = $false
            Rows = @()
            Source = 'NativeSmbRpc'
            ErrorType = 'NativeShareSecurityDescriptorUnavailable'
            Severity = 'Warning'
            Message = 'Native SMB/RPC reached the share, but no share security descriptor was returned.'
            Detail = ('NetShareGetInfo did not return SHARE_INFO_502 security descriptor bytes for {0}, so share-level permissions remain partial even though SMB/RPC was reachable.' -f $uncPath)
            EventType = 'NativeShareSecurityDescriptorUnavailable'
        }
    }
    catch {
        [pscustomobject]@{
            Success = $false
            Available = $false
            Rows = @()
            Source = 'NativeSmbRpc'
            ErrorType = 'SmbRpcShareLookupError'
            Severity = 'High'
            Message = [string]$_.Exception.Message
            Detail = $uncPath
            EventType = 'SmbRpcShareLookupError'
        }
    }
}
