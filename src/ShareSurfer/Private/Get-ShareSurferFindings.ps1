function Get-ShareSurferFindings {
    param(
        [Parameter(Mandatory = $true)]
        $Items,

        [Parameter(Mandatory = $true)]
        $AclEntries,

        $SharePermissions = @(),

        [Parameter(Mandatory = $true)]
        $Shares,

        [Parameter(Mandatory = $true)]
        $GroupEdges,

        $Identities = @(),

        $ScanErrors = @(),

        [int] $OperationalPathLengthThreshold = 256,
        [int] $AzurePathComponentLimit = 255,
        [int] $AzureFullPathLimit = 2048,
        [int] $ExplicitAceDepthThreshold = 2
    )

    $findings = New-Object System.Collections.ArrayList
    $brokenSidKeys = @{}

    function Test-ShareSurferBrokenOrMissingSid {
        param(
            [string] $Identity = ''
        )

        $trimmed = $Identity.Trim()
        if ($trimmed -eq '') {
            return $false
        }

        $trimmed -match '^S-\d-\d+(-\d+)+$' -or
            $trimmed -match '(?i)\baccount\s+unknown\b' -or
            $trimmed -match '(?i)\bunknown\s+(account|sid)\b'
    }

    function Add-ShareSurferBrokenSidFinding {
        param(
            [string] $ShareId = '',
            [string] $ItemId = '',
            [string] $FullPath = '',
            [string] $Identity = '',
            [string] $Source = ''
        )

        if (-not (Test-ShareSurferBrokenOrMissingSid -Identity $Identity)) {
            return
        }

        $key = @($ShareId, $ItemId, $FullPath, $Identity, $Source) -join '|'
        if ($brokenSidKeys.ContainsKey($key)) {
            return
        }
        $brokenSidKeys[$key] = $true

        $message = 'Permission references a SID or account name that could not be resolved. Review whether this is a deleted account, broken trust reference, or directory lookup gap.'
        if ($Source -ne '') {
            $message = '{0} Source: {1}.' -f $message, $Source
        }

        [void]$findings.Add((New-ShareSurferFinding -FindingType 'BrokenOrMissingSid' -Severity 'High' -ShareId $ShareId -ItemId $ItemId -FullPath $FullPath -Identity $Identity -ObservedValue $Identity -PolicyValue 'Resolvable identity' -Message $message))
    }

    foreach ($item in @(ConvertTo-ShareSurferArray $Items)) {
        $fullPath = [string]$item.FullPath
        if ($fullPath.Length -gt $OperationalPathLengthThreshold) {
            [void]$findings.Add((New-ShareSurferFinding -FindingType 'LongPathOperationalPolicy' -Severity 'Warning' -ShareId $item.ShareId -ItemId $item.ItemId -FullPath $fullPath -ObservedValue $fullPath.Length -PolicyValue $OperationalPathLengthThreshold -Message 'Full path exceeds the configured ShareSurfer operational migration policy threshold. This is separate from Azure Files hard limits.'))
        }

        if ($fullPath.Length -gt $AzureFullPathLimit) {
            [void]$findings.Add((New-ShareSurferFinding -FindingType 'AzureFullPathLimit' -Severity 'High' -ShareId $item.ShareId -ItemId $item.ItemId -FullPath $fullPath -ObservedValue $fullPath.Length -PolicyValue $AzureFullPathLimit -Message 'Full path exceeds the Azure Files documented full path limit.'))
        }

        $segments = @($fullPath -split '[\\/]' | Where-Object { $_ -ne '' })
        foreach ($segment in $segments) {
            if ($segment.Length -gt $AzurePathComponentLimit) {
                [void]$findings.Add((New-ShareSurferFinding -FindingType 'AzurePathComponentLimit' -Severity 'High' -ShareId $item.ShareId -ItemId $item.ItemId -FullPath $fullPath -ObservedValue $segment.Length -PolicyValue $AzurePathComponentLimit -Message 'A path component exceeds the Azure Files documented component limit.'))
                break
            }
        }

        $inheritanceEnabled = $true
        if ($null -ne $item.PSObject.Properties['InheritanceEnabled']) {
            $inheritanceEnabled = [System.Convert]::ToBoolean($item.InheritanceEnabled)
        }
        $inheritanceBrokenAt = ''
        if ($null -ne $item.PSObject.Properties['InheritanceBrokenAt']) {
            $inheritanceBrokenAt = [string]$item.InheritanceBrokenAt
        }

        if (-not $inheritanceEnabled -or $inheritanceBrokenAt -ne '') {
            [void]$findings.Add((New-ShareSurferFinding -FindingType 'BrokenInheritance' -Severity 'Warning' -ShareId $item.ShareId -ItemId $item.ItemId -FullPath $fullPath -ObservedValue $inheritanceBrokenAt -PolicyValue 'Inheritance enabled' -Message 'Inheritance is disabled or was recorded as broken for this item.'))
        }
    }

    foreach ($ace in @(ConvertTo-ShareSurferArray $AclEntries)) {
        $isInherited = $false
        if ($null -ne $ace.PSObject.Properties['IsInherited']) {
            $isInherited = [System.Convert]::ToBoolean($ace.IsInherited)
        }
        $depth = 0
        if ($null -ne $ace.PSObject.Properties['Depth'] -and [string]$ace.Depth -ne '') {
            $depth = [int]$ace.Depth
        }

        if (-not $isInherited -and $depth -gt $ExplicitAceDepthThreshold) {
            [void]$findings.Add((New-ShareSurferFinding -FindingType 'DeepExplicitAce' -Severity 'High' -ShareId $ace.ShareId -ItemId $ace.ItemId -FullPath $ace.FullPath -Identity $ace.Identity -ObservedValue $depth -PolicyValue $ExplicitAceDepthThreshold -Message 'Explicit permissions were introduced deeper than the configured Azure Files migration review threshold.'))
        }

        Add-ShareSurferBrokenSidFinding -ShareId $ace.ShareId -ItemId $ace.ItemId -FullPath $ace.FullPath -Identity $ace.Identity -Source 'Folder/file ACL'
    }

    foreach ($sharePermission in @(ConvertTo-ShareSurferArray $SharePermissions)) {
        Add-ShareSurferBrokenSidFinding -ShareId $sharePermission.ShareId -Identity $sharePermission.Identity -Source 'Share-level permission'
    }

    foreach ($share in @(ConvertTo-ShareSurferArray $Shares)) {
        $partial = $false
        if ($null -ne $share.PSObject.Properties['PartialData']) {
            $partial = [System.Convert]::ToBoolean($share.PartialData)
        }
        if ($partial) {
            [void]$findings.Add((New-ShareSurferFinding -FindingType 'PartialSharePermissionData' -Severity 'Info' -ShareId $share.ShareId -ObservedValue $share.PartialReason -PolicyValue 'Complete share permission inventory' -Message 'Share-level permission data is partial. This commonly occurs for best-effort Samba or UNC scans.'))
        }
    }

    foreach ($edge in @(ConvertTo-ShareSurferArray $GroupEdges)) {
        $isCycle = $false
        $isTruncated = $false
        if ($null -ne $edge.PSObject.Properties['IsCycle']) {
            $isCycle = [System.Convert]::ToBoolean($edge.IsCycle)
        }
        if ($null -ne $edge.PSObject.Properties['IsTruncated']) {
            $isTruncated = [System.Convert]::ToBoolean($edge.IsTruncated)
        }
        if ($isCycle) {
            [void]$findings.Add((New-ShareSurferFinding -FindingType 'GroupExpansionCycle' -Severity 'Warning' -Identity $edge.ParentGroup -ObservedValue $edge.ChildIdentity -PolicyValue 'Acyclic group graph' -Message 'Group expansion detected a membership cycle.'))
        }
        if ($isTruncated) {
            [void]$findings.Add((New-ShareSurferFinding -FindingType 'GroupExpansionTruncated' -Severity 'Warning' -Identity $edge.ParentGroup -ObservedValue $edge.Depth -PolicyValue 'Configured max depth' -Message 'Group expansion stopped at the configured maximum depth.'))
        }
    }

    foreach ($identity in @(ConvertTo-ShareSurferArray $Identities)) {
        $objectClass = ''
        if ($null -ne $identity.PSObject.Properties['ObjectClass']) {
            $objectClass = [string]$identity.ObjectClass
        }
        if ($objectClass.ToLowerInvariant() -ne 'user') {
            continue
        }

        $obsPath = if ($null -ne $identity.PSObject.Properties['ObsPath']) { [string]$identity.ObsPath } else { '' }
        $employeeId = if ($null -ne $identity.PSObject.Properties['EmployeeId']) { [string]$identity.EmployeeId } else { '' }
        $employeeNumber = if ($null -ne $identity.PSObject.Properties['EmployeeNumber']) { [string]$identity.EmployeeNumber } else { '' }
        $isPotentialServiceAccount = [string]::IsNullOrWhiteSpace($obsPath) -and [string]::IsNullOrWhiteSpace($employeeId) -and [string]::IsNullOrWhiteSpace($employeeNumber)
        if (-not $isPotentialServiceAccount) {
            continue
        }

        $identityText = if ($null -ne $identity.PSObject.Properties['Identity']) { [string]$identity.Identity } else { '' }
        [void]$findings.Add((New-ShareSurferFinding -FindingType 'PotentialServiceAccount' -Severity 'Warning' -Identity $identityText -ObservedValue 'Missing OBS path and employee identifiers' -PolicyValue 'User account should have OBS, employeeID, or employeeNumber unless it is a service account' -Message 'User account has no OBS value and no employee identifier. Review whether this is a service account or an incomplete directory record.'))
    }

    foreach ($scanError in @(ConvertTo-ShareSurferArray $ScanErrors)) {
        [void]$findings.Add((New-ShareSurferFinding -FindingType 'CollectionError' -Severity 'High' -ShareId $scanError.ShareId -FullPath $scanError.FullPath -ObservedValue $scanError.ErrorType -PolicyValue 'Complete inventory' -Message $scanError.Message))
    }

    @($findings)
}
