function Add-ShareSurferUniqueValue {
    param(
        [System.Collections.ArrayList] $Values,

        [string] $Value = ''
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return
    }

    if ($Values -notcontains $Value) {
        [void]$Values.Add($Value)
    }
}

function Get-ShareSurferGroupExpansionSummary {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Group,

        [Parameter(Mandatory = $true)]
        [hashtable] $EdgesByParent
    )

    $start = $Group.ToUpperInvariant()
    $queue = New-Object System.Collections.Queue
    $visitedGroups = @{}
    $members = @{}
    $maxDepth = 0
    $hasCycle = $false
    $isTruncated = $false

    if (-not $EdgesByParent.ContainsKey($start)) {
        return [pscustomobject]@{
            ExpandedMembers = 0
            MaxDepth = 0
            HasCycle = $false
            IsTruncated = $false
        }
    }

    $queue.Enqueue($start)
    while ($queue.Count -gt 0) {
        $parent = [string]$queue.Dequeue()
        if ($visitedGroups.ContainsKey($parent)) {
            continue
        }
        $visitedGroups[$parent] = $true

        foreach ($edge in @($EdgesByParent[$parent])) {
            $child = [string]$edge.ChildIdentity
            if ($child -ne '') {
                $members[$child.ToUpperInvariant()] = $true
            }

            $depth = 0
            if ($null -ne $edge.PSObject.Properties['Depth'] -and [string]$edge.Depth -ne '') {
                $depth = [int]$edge.Depth
            }
            if ($depth -gt $maxDepth) {
                $maxDepth = $depth
            }

            if ($null -ne $edge.PSObject.Properties['IsCycle'] -and [System.Convert]::ToBoolean($edge.IsCycle)) {
                $hasCycle = $true
            }
            if ($null -ne $edge.PSObject.Properties['IsTruncated'] -and [System.Convert]::ToBoolean($edge.IsTruncated)) {
                $isTruncated = $true
            }

            $childKey = $child.ToUpperInvariant()
            if ($childKey -ne '' -and $EdgesByParent.ContainsKey($childKey)) {
                $queue.Enqueue($childKey)
            }
        }
    }

    [pscustomobject]@{
        ExpandedMembers = $members.Keys.Count
        MaxDepth = $maxDepth
        HasCycle = $hasCycle
        IsTruncated = $isTruncated
    }
}

function Get-ShareSurferPermissionedGroups {
    param(
        $SharePermissions = @(),
        $AclEntries = @(),
        $Items = @(),
        $Identities = @(),
        $GroupEdges = @(),
        $DiscountedPrincipals = @()
    )

    $discountedPrincipalLookup = New-ShareSurferDiscountedPrincipalLookup -DiscountedPrincipals $DiscountedPrincipals
    $identityByKey = @{}
    foreach ($identity in @(ConvertTo-ShareSurferArray $Identities)) {
        $identityValue = ''
        if ($null -ne $identity.PSObject.Properties['Identity']) {
            $identityValue = [string]$identity.Identity
        }
        if ($identityValue -ne '') {
            $identityByKey[$identityValue.ToUpperInvariant()] = $identity
        }
    }

    $itemById = @{}
    foreach ($item in @(ConvertTo-ShareSurferArray $Items)) {
        if ($null -ne $item.PSObject.Properties['ItemId'] -and [string]$item.ItemId -ne '') {
            $itemById[([string]$item.ItemId)] = $item
        }
    }

    $edgesByParent = @{}
    foreach ($edge in @(ConvertTo-ShareSurferArray $GroupEdges)) {
        $parent = ''
        if ($null -ne $edge.PSObject.Properties['ParentGroup']) {
            $parent = [string]$edge.ParentGroup
        }
        if ($parent -eq '') {
            continue
        }
        $parentKey = $parent.ToUpperInvariant()
        if (-not $edgesByParent.ContainsKey($parentKey)) {
            $edgesByParent[$parentKey] = New-Object System.Collections.ArrayList
        }
        [void]$edgesByParent[$parentKey].Add($edge)
    }

    $groups = @{}

    function Get-OrAddPermissionedGroup {
        param(
            [Parameter(Mandatory = $true)]
            [string] $Identity
        )

        $key = $Identity.ToUpperInvariant()
        if (-not $groups.ContainsKey($key)) {
            $details = $null
            if ($identityByKey.ContainsKey($key)) {
                $details = $identityByKey[$key]
            }
            $groups[$key] = [pscustomobject]@{
                Group = $Identity
                DisplayName = if ($null -ne $details -and $null -ne $details.PSObject.Properties['DisplayName']) { [string]$details.DisplayName } else { '' }
                ObjectClass = if ($null -ne $details -and $null -ne $details.PSObject.Properties['ObjectClass']) { [string]$details.ObjectClass } else { '' }
                ObsPath = if ($null -ne $details -and $null -ne $details.PSObject.Properties['ObsPath']) { [string]$details.ObsPath } else { '' }
                ManagerLevel1 = if ($null -ne $details -and $null -ne $details.PSObject.Properties['ManagerLevel1']) { [string]$details.ManagerLevel1 } else { '' }
                ShareAssignments = 0
                NtfsAssignments = 0
                RightsValues = New-Object System.Collections.ArrayList
                ShareIds = New-Object System.Collections.ArrayList
                Sources = New-Object System.Collections.ArrayList
                ExamplePath = ''
            }
        }

        $groups[$key]
    }

    function Add-PermissionedGroupAssignment {
        param(
            [string] $Identity = '',
            [string] $Source = '',
            [string] $ShareId = '',
            [string] $Rights = '',
            [string] $FullPath = ''
        )

        if ([string]::IsNullOrWhiteSpace($Identity)) {
            return
        }

        $key = $Identity.ToUpperInvariant()
        $objectClass = ''
        if ($identityByKey.ContainsKey($key) -and $null -ne $identityByKey[$key].PSObject.Properties['ObjectClass']) {
            $objectClass = [string]$identityByKey[$key].ObjectClass
        }

        if ($objectClass.ToLowerInvariant() -ne 'group' -and -not $edgesByParent.ContainsKey($key)) {
            return
        }

        $group = Get-OrAddPermissionedGroup -Identity $Identity
        if ($Source -eq 'Share') {
            $group.ShareAssignments++
        }
        else {
            $group.NtfsAssignments++
        }
        Add-ShareSurferUniqueValue -Values $group.RightsValues -Value $Rights
        Add-ShareSurferUniqueValue -Values $group.ShareIds -Value $ShareId
        Add-ShareSurferUniqueValue -Values $group.Sources -Value $Source
        if ($group.ExamplePath -eq '' -and $FullPath -ne '') {
            $group.ExamplePath = $FullPath
        }
    }

    foreach ($permission in @(ConvertTo-ShareSurferArray $SharePermissions)) {
        Add-PermissionedGroupAssignment -Identity ([string]$permission.Identity) -Source 'Share' -ShareId ([string]$permission.ShareId) -Rights ([string]$permission.Rights)
    }

    foreach ($ace in @(ConvertTo-ShareSurferArray $AclEntries)) {
        $fullPath = ''
        if ($null -ne $ace.PSObject.Properties['FullPath'] -and [string]$ace.FullPath -ne '') {
            $fullPath = [string]$ace.FullPath
        }
        elseif ($null -ne $ace.PSObject.Properties['ItemId'] -and $itemById.ContainsKey([string]$ace.ItemId)) {
            $item = $itemById[[string]$ace.ItemId]
            if ($null -ne $item.PSObject.Properties['FullPath']) {
                $fullPath = [string]$item.FullPath
            }
        }
        Add-PermissionedGroupAssignment -Identity ([string]$ace.Identity) -Source 'NTFS' -ShareId ([string]$ace.ShareId) -Rights ([string]$ace.Rights) -FullPath $fullPath
    }

    @($groups.Values | ForEach-Object {
        $summary = Get-ShareSurferGroupExpansionSummary -Group ([string]$_.Group) -EdgesByParent $edgesByParent
        $discountedPrincipal = Get-ShareSurferDiscountedPrincipal -Identity ([string]$_.Group) -DiscountedPrincipalLookup $discountedPrincipalLookup
        [pscustomobject]@{
            Group = [string]$_.Group
            DisplayName = [string]$_.DisplayName
            ObjectClass = if ([string]::IsNullOrWhiteSpace([string]$_.ObjectClass)) { 'group' } else { [string]$_.ObjectClass }
            ObsPath = [string]$_.ObsPath
            ManagerLevel1 = [string]$_.ManagerLevel1
            ShareAssignments = [int]$_.ShareAssignments
            NtfsAssignments = [int]$_.NtfsAssignments
            ExpandedMembers = [int]$summary.ExpandedMembers
            MaxDepth = [int]$summary.MaxDepth
            HasCycle = [bool]$summary.HasCycle
            IsTruncated = [bool]$summary.IsTruncated
            Rights = (@($_.RightsValues) | Sort-Object) -join '; '
            ShareId = if ($_.ShareIds.Count -gt 0) { [string]$_.ShareIds[0] } else { '' }
            ShareIds = (@($_.ShareIds) | Sort-Object) -join '; '
            Sources = (@($_.Sources) | Sort-Object) -join '; '
            FullPath = [string]$_.ExamplePath
            ExamplePath = [string]$_.ExamplePath
            DiscountedPrincipal = [bool]($null -ne $discountedPrincipal)
            DiscountReason = if ($null -ne $discountedPrincipal -and $null -ne $discountedPrincipal.PSObject.Properties['Reason']) { [string]$discountedPrincipal.Reason } else { '' }
            DiscountScope = if ($null -ne $discountedPrincipal -and $null -ne $discountedPrincipal.PSObject.Properties['Scope']) { [string]$discountedPrincipal.Scope } else { '' }
        }
    } | Sort-Object @{ Expression = 'ExpandedMembers'; Descending = $true }, Group)
}
