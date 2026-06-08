function Get-ShareSurferOwnerRiskPivots {
    param(
        $OwnerMappings = @(),
        $Items = @(),
        $Shares = @(),
        $SharePermissions = @(),
        $AclEntries = @(),
        $Identities = @(),
        $GroupEdges = @(),
        $Findings = @(),
        $Conflicts = @(),
        $DiscountedPrincipals = @()
    )

    $discountedPrincipalLookup = New-ShareSurferDiscountedPrincipalLookup -DiscountedPrincipals $DiscountedPrincipals
    $identityClassByName = @{}
    foreach ($identity in @(ConvertTo-ShareSurferArray $Identities)) {
        $name = [string]$identity.Identity
        if ($name -ne '') {
            $identityClassByName[$name.ToUpperInvariant()] = [string]$identity.ObjectClass
        }
    }
    foreach ($edge in @(ConvertTo-ShareSurferArray $GroupEdges)) {
        $parent = [string]$edge.ParentGroup
        if ($parent -ne '' -and -not $identityClassByName.ContainsKey($parent.ToUpperInvariant())) {
            $identityClassByName[$parent.ToUpperInvariant()] = 'group'
        }
        $child = [string]$edge.ChildIdentity
        if ($child -ne '' -and -not $identityClassByName.ContainsKey($child.ToUpperInvariant())) {
            $identityClassByName[$child.ToUpperInvariant()] = [string]$edge.ChildObjectClass
        }
    }

    $pivots = New-Object System.Collections.ArrayList
    foreach ($mapping in @(ConvertTo-ShareSurferArray $OwnerMappings)) {
        $pattern = [string]$mapping.Pattern
        $matchedItems = @(ConvertTo-ShareSurferArray $Items | Where-Object {
            Test-ShareSurferWildcardMatch -Pattern $pattern -Value ([string]$_.FullPath)
        })

        $matchedItemIds = @{}
        $matchedShareIds = @{}
        foreach ($item in $matchedItems) {
            $itemId = [string]$item.ItemId
            $shareId = [string]$item.ShareId
            if ($itemId -ne '') {
                $matchedItemIds[$itemId] = $true
            }
            if ($shareId -ne '') {
                $matchedShareIds[$shareId] = $true
            }
        }

        foreach ($share in @(ConvertTo-ShareSurferArray $Shares)) {
            foreach ($path in @([string]$share.UNCPath, [string]$share.LocalPath)) {
                if ($path -ne '' -and (Test-ShareSurferWildcardMatch -Pattern $pattern -Value $path)) {
                    $shareId = [string]$share.ShareId
                    if ($shareId -ne '') {
                        $matchedShareIds[$shareId] = $true
                    }
                }
            }
        }

        $mappedFindings = @(ConvertTo-ShareSurferArray $Findings | Where-Object {
            $itemId = [string]$_.ItemId
            $shareId = [string]$_.ShareId
            $fullPath = [string]$_.FullPath
            ($itemId -ne '' -and $matchedItemIds.ContainsKey($itemId)) -or
                ($shareId -ne '' -and $matchedShareIds.ContainsKey($shareId)) -or
                ($fullPath -ne '' -and (Test-ShareSurferWildcardMatch -Pattern $pattern -Value $fullPath))
        })

        $mappedConflicts = @(ConvertTo-ShareSurferArray $Conflicts | Where-Object {
            $itemId = [string]$_.ItemId
            $shareId = [string]$_.ShareId
            ($itemId -ne '' -and $matchedItemIds.ContainsKey($itemId)) -or
                ($shareId -ne '' -and $matchedShareIds.ContainsKey($shareId))
        })

        $partialShares = @(ConvertTo-ShareSurferArray $Shares | Where-Object {
            $shareId = [string]$_.ShareId
            $partial = $false
            if ($null -ne $_.PSObject.Properties['PartialData']) {
                $partial = [System.Convert]::ToBoolean($_.PartialData)
            }
            $shareId -ne '' -and $matchedShareIds.ContainsKey($shareId) -and $partial
        })

        $directIdentityMap = @{}
        $discountedIdentityMap = @{}
        $discountedGroupMap = @{}
        $discountSummaries = New-Object System.Collections.ArrayList
        foreach ($permission in @(ConvertTo-ShareSurferArray $SharePermissions)) {
            $shareId = [string]$permission.ShareId
            $identity = [string]$permission.Identity
            if ($identity -ne '' -and $shareId -ne '' -and $matchedShareIds.ContainsKey($shareId)) {
                $identityKey = $identity.ToUpperInvariant()
                $discountedPrincipal = Get-ShareSurferDiscountedPrincipal -Identity $identity -DiscountedPrincipalLookup $discountedPrincipalLookup
                if ($null -ne $discountedPrincipal) {
                    $discountedIdentityMap[$identityKey] = $identity
                    Add-ShareSurferDiscountSummary -Values $discountSummaries -Principal $discountedPrincipal
                    if ($identityClassByName.ContainsKey($identityKey) -and ([string]$identityClassByName[$identityKey]).ToLowerInvariant() -eq 'group') {
                        $discountedGroupMap[$identityKey] = $identity
                    }
                }
                else {
                    $directIdentityMap[$identityKey] = $identity
                }
            }
        }
        foreach ($entry in @(ConvertTo-ShareSurferArray $AclEntries)) {
            $itemId = [string]$entry.ItemId
            $shareId = [string]$entry.ShareId
            $identity = [string]$entry.Identity
            if ($identity -eq '') {
                continue
            }
            if (($itemId -ne '' -and $matchedItemIds.ContainsKey($itemId)) -or ($shareId -ne '' -and $matchedShareIds.ContainsKey($shareId))) {
                $identityKey = $identity.ToUpperInvariant()
                $discountedPrincipal = Get-ShareSurferDiscountedPrincipal -Identity $identity -DiscountedPrincipalLookup $discountedPrincipalLookup
                if ($null -ne $discountedPrincipal) {
                    $discountedIdentityMap[$identityKey] = $identity
                    Add-ShareSurferDiscountSummary -Values $discountSummaries -Principal $discountedPrincipal
                    if ($identityClassByName.ContainsKey($identityKey) -and ([string]$identityClassByName[$identityKey]).ToLowerInvariant() -eq 'group') {
                        $discountedGroupMap[$identityKey] = $identity
                    }
                }
                else {
                    $directIdentityMap[$identityKey] = $identity
                }
            }
        }

        $directGroupKeys = @($directIdentityMap.Keys | Where-Object {
            $identityClassByName.ContainsKey($_) -and ([string]$identityClassByName[$_]).ToLowerInvariant() -eq 'group'
        })
        $expandedMemberCount = Get-ShareSurferExpandedMemberCount -GroupKeys $directGroupKeys -GroupEdges $GroupEdges
        $discountedPrincipalsText = (@($discountedIdentityMap.Values) | Sort-Object) -join '; '
        $discountReason = New-ShareSurferDiscountReason -Reason ((@($discountSummaries) | Sort-Object) -join '; ')

        $highRiskFindings = @($mappedFindings | Where-Object { Test-ShareSurferHighRiskSeverity -Severity ([string]$_.Severity) })
        $highRiskConflicts = @($mappedConflicts | Where-Object { Test-ShareSurferHighRiskSeverity -Severity ([string]$_.Severity) })
        $readinessSignals = New-Object System.Collections.ArrayList
        foreach ($findingType in @($mappedFindings | ForEach-Object { [string]$_.FindingType } | Sort-Object -Unique)) {
            switch ($findingType) {
                'LongPathOperationalPolicy' { Add-ShareSurferUniqueValue -Values $readinessSignals -Value 'long path'; break }
                'AzurePathComponentLimit' { Add-ShareSurferUniqueValue -Values $readinessSignals -Value 'long path'; break }
                'AzureFullPathLimit' { Add-ShareSurferUniqueValue -Values $readinessSignals -Value 'long path'; break }
                'BrokenInheritance' { Add-ShareSurferUniqueValue -Values $readinessSignals -Value 'broken inheritance'; break }
                'DeepExplicitAce' { Add-ShareSurferUniqueValue -Values $readinessSignals -Value 'deep explicit ACE'; break }
                default {
                    if (-not [string]::IsNullOrWhiteSpace($findingType)) {
                        Add-ShareSurferUniqueValue -Values $readinessSignals -Value ('finding: {0}' -f $findingType)
                    }
                    break
                }
            }
        }
        if ($mappedConflicts.Count -gt 0) {
            Add-ShareSurferUniqueValue -Values $readinessSignals -Value 'conflicts'
        }
        if ($partialShares.Count -gt 0) {
            Add-ShareSurferUniqueValue -Values $readinessSignals -Value 'partial data'
        }
        $riskLevel = 'Monitor'
        if (($highRiskFindings.Count + $highRiskConflicts.Count) -gt 0) {
            $riskLevel = 'High'
        }
        elseif (($mappedFindings.Count + $mappedConflicts.Count + $partialShares.Count) -gt 0) {
            $riskLevel = 'Review'
        }

        [void]$pivots.Add([pscustomobject]@{
            BusinessUnit = [string]$mapping.BusinessUnit
            Owner = [string]$mapping.Owner
            Pattern = $pattern
            Source = [string]$mapping.Source
            MatchingItems = $matchedItems.Count
            Directories = @($matchedItems | Where-Object { [string]$_.ItemType -eq 'Directory' }).Count
            Files = @($matchedItems | Where-Object { [string]$_.ItemType -eq 'File' }).Count
            FindingCount = $mappedFindings.Count
            ConflictCount = $mappedConflicts.Count
            PartialShareCount = $partialShares.Count
            DirectIdentityCount = $directIdentityMap.Count
            DirectGroupCount = @($directGroupKeys).Count
            ExpandedMemberCount = $expandedMemberCount
            RiskLevel = $riskLevel
            ReadinessSignals = (@($readinessSignals) | Sort-Object) -join '; '
            DiscountedPrincipal = [bool]($discountedIdentityMap.Count -gt 0)
            DiscountedPrincipalCount = $discountedIdentityMap.Count
            DiscountedGroupCount = $discountedGroupMap.Count
            DiscountedPrincipals = $discountedPrincipalsText
            DiscountReason = $discountReason
        })
    }

    @($pivots | Sort-Object @{ Expression = {
                switch ([string]$_.RiskLevel) {
                    'High' { 0; break }
                    'Review' { 1; break }
                    default { 2 }
                }
            }
        }, BusinessUnit, Owner)
}

function Test-ShareSurferWildcardMatch {
    param(
        [string] $Pattern,
        [string] $Value
    )

    if ([string]::IsNullOrWhiteSpace($Pattern)) {
        return $false
    }

    $escaped = [System.Text.RegularExpressions.Regex]::Escape($Pattern)
    $regex = '^' + $escaped.Replace('\*', '.*').Replace('\?', '.') + '$'
    [System.Text.RegularExpressions.Regex]::IsMatch([string]$Value, $regex, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
}

function Test-ShareSurferHighRiskSeverity {
    param(
        [string] $Severity
    )

    @('Critical', 'High') -contains $Severity
}

function Get-ShareSurferExpandedMemberCount {
    param(
        [string[]] $GroupKeys = @(),

        $GroupEdges = @()
    )

    $edgesByParent = @{}
    foreach ($edge in @(ConvertTo-ShareSurferArray $GroupEdges)) {
        $parent = ([string]$edge.ParentGroup).ToUpperInvariant()
        if ($parent -eq '') {
            continue
        }
        if (-not $edgesByParent.ContainsKey($parent)) {
            $edgesByParent[$parent] = @()
        }
        $edgesByParent[$parent] = @($edgesByParent[$parent]) + $edge
    }

    $queue = New-Object System.Collections.Queue
    $visitedGroups = @{}
    foreach ($groupKey in @($GroupKeys)) {
        if ($groupKey -ne '') {
            $queue.Enqueue($groupKey)
        }
    }

    $members = @{}
    while ($queue.Count -gt 0) {
        $groupKey = [string]$queue.Dequeue()
        if ($visitedGroups.ContainsKey($groupKey)) {
            continue
        }
        $visitedGroups[$groupKey] = $true
        if (-not $edgesByParent.ContainsKey($groupKey)) {
            continue
        }

        foreach ($edge in @($edgesByParent[$groupKey])) {
            $child = [string]$edge.ChildIdentity
            $childKey = $child.ToUpperInvariant()
            if ($childKey -eq '') {
                continue
            }
            $members[$childKey] = $true
            if (([string]$edge.ChildObjectClass).ToLowerInvariant() -eq 'group') {
                $queue.Enqueue($childKey)
            }
        }
    }

    $members.Count
}
