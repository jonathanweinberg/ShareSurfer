function Export-ShareSurferInventory {
    param(
        [Parameter(Mandatory = $true)]
        $Inventory,

        [Parameter(Mandatory = $true)]
        [string] $OutputPath,

        [string] $ObsAttribute = 'extensionAttribute10',
        [int] $OperationalPathLengthThreshold = 256,
        [int] $AzurePathComponentLimit = 255,
        [int] $AzureFullPathLimit = 2048,
        [int] $ExplicitAceDepthThreshold = 2,
        [int] $GroupExpansionMaxDepth = 20,
        [ValidateSet('Auto', 'ActiveDirectory', 'Ldap', 'DirectoryOnly')]
        [string] $AdLookupMode = 'Auto',
        [string] $SourceMode = 'InputObject',
        [string] $DiscountedPrincipalPath = '',
        [switch] $SkipIdentityEnrichment,
        [switch] $IncludeFiles
    )

    if (-not (Test-Path -LiteralPath $OutputPath)) {
        New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
    }

    $schema = Get-ShareSurferExportSchema
    $shares = @(ConvertTo-ShareSurferArray $Inventory.Shares)
    $items = @(Normalize-ShareSurferItems -Items $Inventory.Items)
    $sharePermissions = @(ConvertTo-ShareSurferArray $Inventory.SharePermissions)
    $aclEntries = @(ConvertTo-ShareSurferArray $Inventory.AclEntries)
    $identities = @(ConvertTo-ShareSurferArray $Inventory.Identities)
    $groupEdges = @(ConvertTo-ShareSurferArray $Inventory.GroupEdges)
    $orgChains = @(ConvertTo-ShareSurferArray $Inventory.OrgChains)
    $ownerMappings = @(ConvertTo-ShareSurferArray $Inventory.OwnerMappings)
    $discountedPrincipals = @(Import-ShareSurferDiscountedPrincipals -Path $DiscountedPrincipalPath)
    $scanErrors = @()
    if ($null -ne $Inventory.PSObject.Properties['ScanErrors']) {
        $scanErrors = @(ConvertTo-ShareSurferArray $Inventory.ScanErrors)
    }
    $collectionErrors = New-Object System.Collections.ArrayList
    $scanErrorIndex = 0
    foreach ($scanError in $scanErrors) {
        $scanErrorIndex++
        $severity = 'High'
        if ($null -ne $scanError.PSObject.Properties['Severity'] -and -not [string]::IsNullOrWhiteSpace([string]$scanError.Severity)) {
            $severity = [string]$scanError.Severity
        }
        $source = $SourceMode
        if ($null -ne $scanError.PSObject.Properties['Source'] -and -not [string]::IsNullOrWhiteSpace([string]$scanError.Source)) {
            $source = [string]$scanError.Source
        }
        $detail = ''
        if ($null -ne $scanError.PSObject.Properties['Detail']) {
            $detail = [string]$scanError.Detail
        }

        [void]$collectionErrors.Add([pscustomobject]@{
            ErrorId = 'error-{0}' -f $scanErrorIndex
            ShareId = if ($null -ne $scanError.PSObject.Properties['ShareId']) { [string]$scanError.ShareId } else { '' }
            ItemId = if ($null -ne $scanError.PSObject.Properties['ItemId']) { [string]$scanError.ItemId } else { '' }
            FullPath = if ($null -ne $scanError.PSObject.Properties['FullPath']) { [string]$scanError.FullPath } else { '' }
            ErrorType = if ($null -ne $scanError.PSObject.Properties['ErrorType']) { [string]$scanError.ErrorType } else { 'CollectionError' }
            Severity = $severity
            Source = $source
            Message = if ($null -ne $scanError.PSObject.Properties['Message']) { [string]$scanError.Message } else { '' }
            Detail = $detail
        })
    }
    $scanEvents = New-Object System.Collections.ArrayList
    if ($null -ne $Inventory.PSObject.Properties['ScanEvents']) {
        foreach ($event in @(ConvertTo-ShareSurferArray $Inventory.ScanEvents)) {
            [void]$scanEvents.Add($event)
        }
    }
    [void]$scanEvents.Add((New-ShareSurferEvent -EventType 'ScanStarted' -Source $SourceMode -Message ('ShareSurfer scan export started for {0}' -f $SourceMode)))

    if (-not $SkipIdentityEnrichment) {
        $identityInventory = Resolve-ShareSurferIdentityInventory -Inventory $Inventory -ObsAttribute $ObsAttribute -GroupExpansionMaxDepth $GroupExpansionMaxDepth -AdLookupMode $AdLookupMode
        $identities = @(ConvertTo-ShareSurferArray $identityInventory.Identities)
        $groupEdges = @(ConvertTo-ShareSurferArray $identityInventory.GroupEdges)
        $orgChains = @(ConvertTo-ShareSurferArray $identityInventory.OrgChains)
    }

    if ($scanErrors.Count -gt 0) {
        foreach ($share in $shares) {
            $shareId = [string]$share.ShareId
            if ($shareId -eq '') {
                continue
            }

            $shareErrors = @($scanErrors | Where-Object { [string]$_.ShareId -eq $shareId })
            if ($shareErrors.Count -eq 0) {
                continue
            }

            $errorSummary = @($shareErrors |
                Group-Object -Property ErrorType |
                Sort-Object Name |
                ForEach-Object {
                    $errorType = if ([string]::IsNullOrWhiteSpace([string]$_.Name)) { 'UnknownError' } else { [string]$_.Name }
                    '{0}={1}' -f $errorType, $_.Count
                }) -join '; '

            $scanErrorReason = 'Scan errors recorded: {0}' -f $errorSummary
            $existingReason = ''
            if ($null -ne $share.PSObject.Properties['PartialReason']) {
                $existingReason = [string]$share.PartialReason
            }

            $share.PartialData = $true
            if ([string]::IsNullOrWhiteSpace($existingReason)) {
                $share.PartialReason = $scanErrorReason
            }
            elseif ($existingReason -notlike ('*{0}*' -f $scanErrorReason)) {
                $share.PartialReason = '{0}; {1}' -f $existingReason.TrimEnd('.', ';', ' '), $scanErrorReason
            }
        }
    }

    $conflicts = @(Get-ShareSurferConflicts -SharePermissions $sharePermissions -AclEntries $aclEntries)
    $findings = @(Get-ShareSurferFindings -Items $items -AclEntries $aclEntries -Shares $shares -GroupEdges $groupEdges -Identities $identities -ScanErrors $scanErrors -OperationalPathLengthThreshold $OperationalPathLengthThreshold -AzurePathComponentLimit $AzurePathComponentLimit -AzureFullPathLimit $AzureFullPathLimit -ExplicitAceDepthThreshold $ExplicitAceDepthThreshold)
    $permissionedGroups = @(Get-ShareSurferPermissionedGroups -SharePermissions $sharePermissions -AclEntries $aclEntries -Items $items -Identities $identities -GroupEdges $groupEdges -DiscountedPrincipals $discountedPrincipals)
    $ownerRiskPivots = @(Get-ShareSurferOwnerRiskPivots -OwnerMappings $ownerMappings -Items $items -Shares $shares -SharePermissions $sharePermissions -AclEntries $aclEntries -Identities $identities -GroupEdges $groupEdges -Findings $findings -Conflicts $conflicts -DiscountedPrincipals $discountedPrincipals)
    $relatedDataAreas = @(Get-ShareSurferRelatedDataAreas -OwnerRiskPivots $ownerRiskPivots -Items $items -Shares $shares)
    $ownerReviewPackets = @(Get-ShareSurferOwnerReviewPackets -OwnerRiskPivots $ownerRiskPivots -RelatedDataAreas $relatedDataAreas)
    $manifest = @(
        [pscustomobject]@{
            ScanId = [guid]::NewGuid().ToString('N')
            GeneratedAt = (Get-Date).ToUniversalTime().ToString('o')
            ExportVersion = '1'
            ObsAttribute = $ObsAttribute
            SourceMode = $SourceMode
            OperationalPathLengthThreshold = $OperationalPathLengthThreshold
            AzurePathComponentLimit = $AzurePathComponentLimit
            AzureFullPathLimit = $AzureFullPathLimit
            ExplicitAceDepthThreshold = $ExplicitAceDepthThreshold
            GroupExpansionMaxDepth = $GroupExpansionMaxDepth
            AdLookupMode = $AdLookupMode
            IncludeFiles = [bool]$IncludeFiles
        }
    )
    [void]$scanEvents.Add((New-ShareSurferEvent -EventType 'ExportCompleted' -Source 'Export' -Message ('Export completed at {0}' -f $OutputPath) -Detail ('Findings={0}; Conflicts={1}' -f $findings.Count, $conflicts.Count)))

    $data = @{
        'shares.csv' = $shares
        'items.csv' = $items
        'share_permissions.csv' = $sharePermissions
        'acl_entries.csv' = $aclEntries
        'identities.csv' = $identities
        'group_edges.csv' = $groupEdges
        'discounted_principals.csv' = $discountedPrincipals
        'permissioned_groups.csv' = $permissionedGroups
        'org_chains.csv' = $orgChains
        'owner_mappings.csv' = $ownerMappings
        'owner_risk_pivots.csv' = $ownerRiskPivots
        'related_data_areas.csv' = $relatedDataAreas
        'owner_review_packets.csv' = $ownerReviewPackets
        'conflicts.csv' = $conflicts
        'findings.csv' = $findings
        'collection_errors.csv' = @($collectionErrors)
        'scan_events.csv' = @($scanEvents)
        'scan_manifest.csv' = $manifest
    }

    foreach ($fileName in $schema.Keys) {
        Export-ShareSurferCsv -Path (Join-Path $OutputPath $fileName) -Columns $schema[$fileName] -Rows $data[$fileName]
    }

    $eventLogRows = foreach ($event in @($scanEvents)) {
        New-ShareSurferRecord -Columns $schema['scan_events.csv'] -InputObject $event
    }
    Export-ShareSurferJsonLines -Path (Join-Path $OutputPath 'scan_events.jsonl') -Rows $eventLogRows

    [pscustomobject]@{
        OutputPath = $OutputPath
        Shares = $shares.Count
        Items = $items.Count
        SharePermissions = $sharePermissions.Count
        AclEntries = $aclEntries.Count
        Findings = $findings.Count
        Conflicts = $conflicts.Count
        CollectionErrors = @($collectionErrors).Count
        DiscountedPrincipals = $discountedPrincipals.Count
        PermissionedGroups = $permissionedGroups.Count
        RelatedDataAreas = $relatedDataAreas.Count
        OwnerReviewPackets = $ownerReviewPackets.Count
    }
}
