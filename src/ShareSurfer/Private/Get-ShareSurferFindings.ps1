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
        [int] $ExplicitAceDepthThreshold = 2,
        [int] $StatusIntervalSeconds = 15,
        [switch] $ShowProgress,
        [switch] $Quiet
    )

    $findings = New-Object System.Collections.ArrayList
    $brokenSidKeys = @{}
    $brokenSidIdentityCache = @{}
    $itemsList = @(ConvertTo-ShareSurferArray $Items)
    $aclEntriesList = @(ConvertTo-ShareSurferArray $AclEntries)
    $sharePermissionsList = @(ConvertTo-ShareSurferArray $SharePermissions)
    $sharesList = @(ConvertTo-ShareSurferArray $Shares)
    $groupEdgesList = @(ConvertTo-ShareSurferArray $GroupEdges)
    $identitiesList = @(ConvertTo-ShareSurferArray $Identities)
    $scanErrorsList = @(ConvertTo-ShareSurferArray $ScanErrors)
    $statusClock = [System.Diagnostics.Stopwatch]::StartNew()
    $statusState = @{ LastSeconds = -999.0 }
    $showFindingProgress = [bool]$ShowProgress -and -not [bool]$Quiet
    $findingCounts = @{
        OwnerMetadataUnavailable = 0
        LongPathOperationalPolicy = 0
        AzureFullPathLimit = 0
        AzurePathComponentLimit = 0
        BrokenInheritance = 0
        DeepExplicitAce = 0
        BrokenOrMissingSid = 0
        PartialSharePermissionData = 0
        GroupExpansionCycle = 0
        GroupExpansionTruncated = 0
        PotentialServiceAccount = 0
        CollectionError = 0
    }

    function Write-ShareSurferFindingProgress {
        param(
            [string] $Message,

            [switch] $Force
        )

        if (-not $showFindingProgress) {
            return
        }

        $elapsed = [double]$statusClock.Elapsed.TotalSeconds
        if ($Force -or $StatusIntervalSeconds -le 0 -or ($elapsed - $statusState.LastSeconds) -ge $StatusIntervalSeconds) {
            $statusState.LastSeconds = $elapsed
            Write-ShareSurferStatus -Phase 'Export' -Message $Message
        }
    }

    function Get-ShareSurferMaxPathComponentLength {
        param(
            [string] $Path = ''
        )

        if ([string]::IsNullOrEmpty($Path)) {
            return 0
        }

        $currentLength = 0
        $maxLength = 0
        for ($index = 0; $index -lt $Path.Length; $index++) {
            $character = $Path[$index]
            if ($character -eq '\' -or $character -eq '/') {
                if ($currentLength -gt $maxLength) {
                    $maxLength = $currentLength
                }
                $currentLength = 0
                continue
            }

            $currentLength++
        }

        if ($currentLength -gt $maxLength) {
            $maxLength = $currentLength
        }

        $maxLength
    }

    function Test-ShareSurferBrokenOrMissingSid {
        param(
            [string] $Identity = ''
        )

        $trimmed = $Identity.Trim()
        if ($trimmed -eq '') {
            return $false
        }

        $cacheKey = $trimmed.ToUpperInvariant()
        if ($brokenSidIdentityCache.ContainsKey($cacheKey)) {
            return [bool]$brokenSidIdentityCache[$cacheKey]
        }

        $isBroken = $trimmed -match '^S-\d-\d+(-\d+)+$' -or
            $trimmed -match '(?i)\baccount\s+unknown\b' -or
            $trimmed -match '(?i)\bunknown\s+(account|sid)\b'
        $brokenSidIdentityCache[$cacheKey] = [bool]$isBroken
        $isBroken
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
        $findingCounts['BrokenOrMissingSid']++
    }

    Write-ShareSurferFindingProgress -Message ('Finding classification progress: checking {0} item row(s).' -f $itemsList.Count) -Force

    $itemIndex = 0
    foreach ($item in $itemsList) {
        $itemIndex++
        $fullPath = [string]$item.FullPath
        $owner = ''
        if ($null -ne $item.PSObject.Properties['Owner']) {
            $owner = [string]$item.Owner
        }

        if ([string]::IsNullOrWhiteSpace($owner)) {
            [void]$findings.Add((New-ShareSurferFinding -FindingType 'OwnerMetadataUnavailable' -Severity 'Warning' -ShareId $item.ShareId -ItemId $item.ItemId -FullPath $fullPath -ObservedValue 'Blank owner metadata' -PolicyValue 'Usable NTFS owner value' -Message 'ShareSurfer could not collect a usable NTFS owner value for this item. This can mean the owner read was denied, the owner SID was unresolved, the path was partially collected, or the source did not return owner metadata; it does not prove the Windows object lacks an owner.'))
            $findingCounts['OwnerMetadataUnavailable']++
        }

        if ($fullPath.Length -gt $OperationalPathLengthThreshold) {
            [void]$findings.Add((New-ShareSurferFinding -FindingType 'LongPathOperationalPolicy' -Severity 'Warning' -ShareId $item.ShareId -ItemId $item.ItemId -FullPath $fullPath -ObservedValue $fullPath.Length -PolicyValue $OperationalPathLengthThreshold -Message 'Full path exceeds the configured ShareSurfer operational migration policy threshold. This is separate from Azure Files hard limits.'))
            $findingCounts['LongPathOperationalPolicy']++
        }

        if ($fullPath.Length -gt $AzureFullPathLimit) {
            [void]$findings.Add((New-ShareSurferFinding -FindingType 'AzureFullPathLimit' -Severity 'High' -ShareId $item.ShareId -ItemId $item.ItemId -FullPath $fullPath -ObservedValue $fullPath.Length -PolicyValue $AzureFullPathLimit -Message 'Full path exceeds the Azure Files documented full path limit.'))
            $findingCounts['AzureFullPathLimit']++
        }

        if ($fullPath.Length -gt $AzurePathComponentLimit) {
            $maxComponentLength = Get-ShareSurferMaxPathComponentLength -Path $fullPath
            if ($maxComponentLength -gt $AzurePathComponentLimit) {
                [void]$findings.Add((New-ShareSurferFinding -FindingType 'AzurePathComponentLimit' -Severity 'High' -ShareId $item.ShareId -ItemId $item.ItemId -FullPath $fullPath -ObservedValue $maxComponentLength -PolicyValue $AzurePathComponentLimit -Message 'A path component exceeds the Azure Files documented component limit.'))
                $findingCounts['AzurePathComponentLimit']++
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
        $inheritanceBreakType = 'None'
        if ($null -ne $item.PSObject.Properties['InheritanceBreakType'] -and [string]$item.InheritanceBreakType -ne '') {
            $inheritanceBreakType = [string]$item.InheritanceBreakType
        } elseif (-not $inheritanceEnabled) {
            $inheritanceBreakType = 'Direct'
        } elseif ($inheritanceBrokenAt -ne '') {
            $inheritanceBreakType = 'InheritedAncestor'
        }

        if (-not $inheritanceEnabled -or $inheritanceBreakType -eq 'Direct') {
            if ($inheritanceBrokenAt -eq '') {
                $inheritanceBrokenAt = $fullPath
            }

            [void]$findings.Add((New-ShareSurferFinding -FindingType 'BrokenInheritance' -Severity 'Warning' -ShareId $item.ShareId -ItemId $item.ItemId -FullPath $fullPath -ObservedValue $inheritanceBrokenAt -PolicyValue 'Inheritance enabled' -Message 'Inheritance is disabled directly on this item. If this is the top of a hosted share or delegated data area, confirm whether the local NTFS boundary is intentional before treating it as cleanup risk.'))
            $findingCounts['BrokenInheritance']++
        }

        Write-ShareSurferFindingProgress -Message ('Finding classification progress: checked {0}/{1} item row(s); findings={2}; missing owners={3}; long paths={4}; broken inheritance={5}.' -f $itemIndex, $itemsList.Count, $findings.Count, $findingCounts['OwnerMetadataUnavailable'], $findingCounts['LongPathOperationalPolicy'], $findingCounts['BrokenInheritance'])
    }

    Write-ShareSurferFindingProgress -Message ('Finding classification progress: item pass complete. Findings={0}; missing owners={1}; long paths={2}; Azure component warnings={3}; broken inheritance={4}.' -f $findings.Count, $findingCounts['OwnerMetadataUnavailable'], $findingCounts['LongPathOperationalPolicy'], $findingCounts['AzurePathComponentLimit'], $findingCounts['BrokenInheritance']) -Force

    $aclIndex = 0
    foreach ($ace in $aclEntriesList) {
        $aclIndex++
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
            $findingCounts['DeepExplicitAce']++
        }

        Add-ShareSurferBrokenSidFinding -ShareId $ace.ShareId -ItemId $ace.ItemId -FullPath $ace.FullPath -Identity $ace.Identity -Source 'Folder/file ACL'
        Write-ShareSurferFindingProgress -Message ('Finding classification progress: checked {0}/{1} ACL row(s); findings={2}; deep explicit ACEs={3}; broken/missing SIDs={4}; SID cache={5}.' -f $aclIndex, $aclEntriesList.Count, $findings.Count, $findingCounts['DeepExplicitAce'], $findingCounts['BrokenOrMissingSid'], $brokenSidIdentityCache.Count)
    }

    Write-ShareSurferFindingProgress -Message ('Finding classification progress: ACL pass complete. Findings={0}; deep explicit ACEs={1}; broken/missing SIDs={2}; SID cache={3}.' -f $findings.Count, $findingCounts['DeepExplicitAce'], $findingCounts['BrokenOrMissingSid'], $brokenSidIdentityCache.Count) -Force

    $sharePermissionIndex = 0
    foreach ($sharePermission in $sharePermissionsList) {
        $sharePermissionIndex++
        Add-ShareSurferBrokenSidFinding -ShareId $sharePermission.ShareId -Identity $sharePermission.Identity -Source 'Share-level permission'
        Write-ShareSurferFindingProgress -Message ('Finding classification progress: checked {0}/{1} share permission row(s); findings={2}; broken/missing SIDs={3}.' -f $sharePermissionIndex, $sharePermissionsList.Count, $findings.Count, $findingCounts['BrokenOrMissingSid'])
    }

    foreach ($share in $sharesList) {
        $partial = $false
        if ($null -ne $share.PSObject.Properties['PartialData']) {
            $partial = [System.Convert]::ToBoolean($share.PartialData)
        }
        if ($partial) {
            [void]$findings.Add((New-ShareSurferFinding -FindingType 'PartialSharePermissionData' -Severity 'Info' -ShareId $share.ShareId -ObservedValue $share.PartialReason -PolicyValue 'Complete share permission inventory' -Message 'Share-level permission data is partial. This commonly occurs for best-effort Samba or UNC scans.'))
            $findingCounts['PartialSharePermissionData']++
        }
    }

    $groupEdgeIndex = 0
    foreach ($edge in $groupEdgesList) {
        $groupEdgeIndex++
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
            $findingCounts['GroupExpansionCycle']++
        }
        if ($isTruncated) {
            [void]$findings.Add((New-ShareSurferFinding -FindingType 'GroupExpansionTruncated' -Severity 'Warning' -Identity $edge.ParentGroup -ObservedValue $edge.Depth -PolicyValue 'Configured max depth' -Message 'Group expansion stopped at the configured maximum depth.'))
            $findingCounts['GroupExpansionTruncated']++
        }
        Write-ShareSurferFindingProgress -Message ('Finding classification progress: checked {0}/{1} group edge row(s); group cycles={2}; truncated groups={3}.' -f $groupEdgeIndex, $groupEdgesList.Count, $findingCounts['GroupExpansionCycle'], $findingCounts['GroupExpansionTruncated'])
    }

    $identityIndex = 0
    foreach ($identity in $identitiesList) {
        $identityIndex++
        $objectClass = ''
        if ($null -ne $identity.PSObject.Properties['ObjectClass']) {
            $objectClass = [string]$identity.ObjectClass
        }
        if ($objectClass.ToLowerInvariant() -ne 'user') {
            Write-ShareSurferFindingProgress -Message ('Finding classification progress: checked {0}/{1} identity row(s); potential service accounts={2}.' -f $identityIndex, $identitiesList.Count, $findingCounts['PotentialServiceAccount'])
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
        $findingCounts['PotentialServiceAccount']++
        Write-ShareSurferFindingProgress -Message ('Finding classification progress: checked {0}/{1} identity row(s); potential service accounts={2}.' -f $identityIndex, $identitiesList.Count, $findingCounts['PotentialServiceAccount'])
    }

    foreach ($scanError in $scanErrorsList) {
        [void]$findings.Add((New-ShareSurferFinding -FindingType 'CollectionError' -Severity 'High' -ShareId $scanError.ShareId -FullPath $scanError.FullPath -ObservedValue $scanError.ErrorType -PolicyValue 'Complete inventory' -Message $scanError.Message))
        $findingCounts['CollectionError']++
    }

    Write-ShareSurferFindingProgress -Message ('Finding classification complete: findings={0}; owner gaps={1}; long paths={2}; deep explicit ACEs={3}; broken/missing SIDs={4}; partial shares={5}; service-account candidates={6}; collection errors={7}.' -f $findings.Count, $findingCounts['OwnerMetadataUnavailable'], $findingCounts['LongPathOperationalPolicy'], $findingCounts['DeepExplicitAce'], $findingCounts['BrokenOrMissingSid'], $findingCounts['PartialSharePermissionData'], $findingCounts['PotentialServiceAccount'], $findingCounts['CollectionError']) -Force

    @($findings)
}
