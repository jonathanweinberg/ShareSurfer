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
        [ValidateSet('MailTo', 'Mail', 'UserPrincipalName', 'SamAccountName', 'DistinguishedName')]
        [string] $ManagerIdentityFormat = 'MailTo',
        [string] $SourceMode = 'InputObject',
        [string] $CollectionProvider = '',
        [string] $RequestedSmbCollectionProvider = '',
        [string] $EffectiveSmbCollectionProvider = '',
        [string] $DiscountedPrincipalPath = '',
        [switch] $SkipIdentityEnrichment,
        [switch] $IncludeFiles,
        [switch] $NoCreateMissingFolders,
        [int] $StatusIntervalSeconds = 15,
        [switch] $Quiet
    )

    Ensure-ShareSurferLocalDirectory -Path $OutputPath -Purpose 'scan export' -NoCreateMissingFolders:$NoCreateMissingFolders -Quiet:$Quiet | Out-Null

    $schema = Get-ShareSurferExportSchema
    $shares = @(ConvertTo-ShareSurferArray $Inventory.Shares)
    $items = @(Normalize-ShareSurferItems -Items $Inventory.Items)
    $sharePermissions = @(ConvertTo-ShareSurferArray $Inventory.SharePermissions)
    $aclEntries = @(ConvertTo-ShareSurferArray $Inventory.AclEntries)
    $identities = @(ConvertTo-ShareSurferArray $Inventory.Identities)
    $groupEdges = @(ConvertTo-ShareSurferArray $Inventory.GroupEdges)
    $orgChains = @(ConvertTo-ShareSurferArray $Inventory.OrgChains)
    $ownerMappings = @(ConvertTo-ShareSurferArray $Inventory.OwnerMappings)
    $ownershipEnrichment = @()
    if ($null -ne $Inventory.PSObject.Properties['OwnershipEnrichment']) {
        $ownershipEnrichment = @(ConvertTo-ShareSurferArray $Inventory.OwnershipEnrichment)
    }
    $ownershipContext = @()
    if ($null -ne $Inventory.PSObject.Properties['OwnershipContext']) {
        $ownershipContext = @(ConvertTo-ShareSurferArray $Inventory.OwnershipContext)
    }
    $ownershipRelationships = @()
    if ($null -ne $Inventory.PSObject.Properties['OwnershipRelationships']) {
        $ownershipRelationships = @(ConvertTo-ShareSurferArray $Inventory.OwnershipRelationships)
    }
    $ownershipImportManifest = @()
    if ($null -ne $Inventory.PSObject.Properties['OwnershipImportManifest']) {
        $ownershipImportManifest = @(ConvertTo-ShareSurferArray $Inventory.OwnershipImportManifest)
    }
    if ([string]::IsNullOrWhiteSpace($RequestedSmbCollectionProvider) -and $null -ne $Inventory.PSObject.Properties['RequestedSmbCollectionProvider']) {
        $RequestedSmbCollectionProvider = [string]$Inventory.RequestedSmbCollectionProvider
    }
    if ([string]::IsNullOrWhiteSpace($EffectiveSmbCollectionProvider) -and $null -ne $Inventory.PSObject.Properties['EffectiveSmbCollectionProvider']) {
        $EffectiveSmbCollectionProvider = [string]$Inventory.EffectiveSmbCollectionProvider
    }
    if ($SourceMode -eq 'SmbShare') {
        if ([string]::IsNullOrWhiteSpace($RequestedSmbCollectionProvider)) {
            $RequestedSmbCollectionProvider = $CollectionProvider
        }
        if ([string]::IsNullOrWhiteSpace($EffectiveSmbCollectionProvider)) {
            $EffectiveSmbCollectionProvider = $CollectionProvider
        }
    }
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
        [void]$scanEvents.Add((New-ShareSurferEvent -EventType 'IdentityEnrichmentStarted' -Source 'IdentityEnrichment' -Message 'Identity enrichment started.'))
        Write-ShareSurferStatus -Phase 'Identity' -Message ('Resolving identity context with OBS attribute {0}, AD lookup mode {1}, and manager format {2}.' -f $ObsAttribute, $AdLookupMode, $ManagerIdentityFormat) -Quiet:$Quiet
        $identityInventory = Resolve-ShareSurferIdentityInventory -Inventory $Inventory -ObsAttribute $ObsAttribute -GroupExpansionMaxDepth $GroupExpansionMaxDepth -AdLookupMode $AdLookupMode -ManagerIdentityFormat $ManagerIdentityFormat -StatusIntervalSeconds $StatusIntervalSeconds -Quiet:$Quiet
        $identities = @(ConvertTo-ShareSurferArray $identityInventory.Identities)
        $groupEdges = @(ConvertTo-ShareSurferArray $identityInventory.GroupEdges)
        $orgChains = @(ConvertTo-ShareSurferArray $identityInventory.OrgChains)
        if ($null -ne $identityInventory.PSObject.Properties['ScanEvents']) {
            foreach ($event in @(ConvertTo-ShareSurferArray $identityInventory.ScanEvents)) {
                [void]$scanEvents.Add($event)
            }
        }
        Write-ShareSurferStatus -Phase 'Identity' -Message ('Identity context ready: identities={0}; group edges={1}; org-chain rows={2}.' -f $identities.Count, $groupEdges.Count, $orgChains.Count) -Quiet:$Quiet
        [void]$scanEvents.Add((New-ShareSurferEvent -EventType 'IdentityEnrichmentCompleted' -Source 'IdentityEnrichment' -Message 'Identity enrichment completed.' -Detail ('Identities={0}; GroupEdges={1}; OrgChains={2}' -f $identities.Count, $groupEdges.Count, $orgChains.Count)))
    }
    else {
        Write-ShareSurferStatus -Phase 'Identity' -Message 'Skipping identity enrichment because -SkipIdentityEnrichment was supplied.' -Quiet:$Quiet
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

    [void]$scanEvents.Add((New-ShareSurferEvent -EventType 'ExportClassificationStarted' -Source 'Export' -Message 'Export classification started.'))
    Write-ShareSurferStatus -Phase 'Export' -Message ('Classifying conflicts from {0} share permission row(s) and {1} ACL row(s).' -f $sharePermissions.Count, $aclEntries.Count) -Quiet:$Quiet
    $conflicts = @(Get-ShareSurferConflicts -SharePermissions $sharePermissions -AclEntries $aclEntries -StatusIntervalSeconds $StatusIntervalSeconds -ShowProgress:(-not [bool]$Quiet) -Quiet:$Quiet)
    Write-ShareSurferStatus -Phase 'Export' -Message ('Conflicts classified: {0} row(s).' -f $conflicts.Count) -Quiet:$Quiet

    Write-ShareSurferStatus -Phase 'Export' -Message ('Classifying findings from {0} item(s), {1} ACL row(s), {2} share permission row(s), and {3} scan error(s).' -f $items.Count, $aclEntries.Count, $sharePermissions.Count, $scanErrors.Count) -Quiet:$Quiet
    $findings = @(Get-ShareSurferFindings -Items $items -AclEntries $aclEntries -SharePermissions $sharePermissions -Shares $shares -GroupEdges $groupEdges -Identities $identities -ScanErrors $scanErrors -OperationalPathLengthThreshold $OperationalPathLengthThreshold -AzurePathComponentLimit $AzurePathComponentLimit -AzureFullPathLimit $AzureFullPathLimit -ExplicitAceDepthThreshold $ExplicitAceDepthThreshold -StatusIntervalSeconds $StatusIntervalSeconds -ShowProgress:(-not [bool]$Quiet) -Quiet:$Quiet)
    Write-ShareSurferStatus -Phase 'Export' -Message ('Findings classified: {0} row(s).' -f $findings.Count) -Quiet:$Quiet

    Write-ShareSurferStatus -Phase 'Export' -Message ('Building permissioned group review rows from {0} share permission row(s), {1} ACL row(s), and {2} group edge row(s).' -f $sharePermissions.Count, $aclEntries.Count, $groupEdges.Count) -Quiet:$Quiet
    $permissionedGroups = @(Get-ShareSurferPermissionedGroups -SharePermissions $sharePermissions -AclEntries $aclEntries -Items $items -Identities $identities -GroupEdges $groupEdges -DiscountedPrincipals $discountedPrincipals)
    Write-ShareSurferStatus -Phase 'Export' -Message ('Permissioned group review rows ready: {0} row(s).' -f $permissionedGroups.Count) -Quiet:$Quiet

    Write-ShareSurferStatus -Phase 'Export' -Message ('Building owner/business-unit pivots from {0} owner mapping row(s), {1} item(s), {2} finding(s), and {3} conflict(s).' -f $ownerMappings.Count, $items.Count, $findings.Count, $conflicts.Count) -Quiet:$Quiet
    $ownerRiskPivots = @(Get-ShareSurferOwnerRiskPivots -OwnerMappings $ownerMappings -Items $items -Shares $shares -SharePermissions $sharePermissions -AclEntries $aclEntries -Identities $identities -GroupEdges $groupEdges -Findings $findings -Conflicts $conflicts -DiscountedPrincipals $discountedPrincipals)
    Write-ShareSurferStatus -Phase 'Export' -Message ('Owner/business-unit pivots ready: {0} row(s).' -f $ownerRiskPivots.Count) -Quiet:$Quiet

    Write-ShareSurferStatus -Phase 'Export' -Message ('Building migration discovery rows from {0} owner pivot row(s), {1} item(s), and {2} share(s).' -f $ownerRiskPivots.Count, $items.Count, $shares.Count) -Quiet:$Quiet
    $relatedDataAreas = @(Get-ShareSurferRelatedDataAreas -OwnerRiskPivots $ownerRiskPivots -Items $items -Shares $shares)
    Write-ShareSurferStatus -Phase 'Export' -Message ('Migration discovery rows ready: {0} related data area(s).' -f $relatedDataAreas.Count) -Quiet:$Quiet

    Write-ShareSurferStatus -Phase 'Export' -Message ('Building owner review packets from {0} owner pivot row(s) and {1} related data area row(s).' -f $ownerRiskPivots.Count, $relatedDataAreas.Count) -Quiet:$Quiet
    $ownerReviewPackets = @(Get-ShareSurferOwnerReviewPackets -OwnerRiskPivots $ownerRiskPivots -RelatedDataAreas $relatedDataAreas)
    Write-ShareSurferStatus -Phase 'Export' -Message ('Owner review packets ready: {0} row(s).' -f $ownerReviewPackets.Count) -Quiet:$Quiet
    $manifest = @(
        [pscustomobject]@{
            ScanId = [guid]::NewGuid().ToString('N')
            GeneratedAt = (Get-Date).ToUniversalTime().ToString('o')
            ExportVersion = '1'
            ObsAttribute = $ObsAttribute
            SourceMode = $SourceMode
            CollectionProvider = $CollectionProvider
            RequestedSmbCollectionProvider = $RequestedSmbCollectionProvider
            EffectiveSmbCollectionProvider = $EffectiveSmbCollectionProvider
            OperationalPathLengthThreshold = $OperationalPathLengthThreshold
            AzurePathComponentLimit = $AzurePathComponentLimit
            AzureFullPathLimit = $AzureFullPathLimit
            ExplicitAceDepthThreshold = $ExplicitAceDepthThreshold
            GroupExpansionMaxDepth = $GroupExpansionMaxDepth
            AdLookupMode = $AdLookupMode
            ManagerIdentityFormat = $ManagerIdentityFormat
            IncludeFiles = [bool]$IncludeFiles
        }
    )
    Write-ShareSurferStatus -Phase 'Export' -Message ('Building evidence confidence rows from {0} share(s), {1} item(s), and {2} collection error(s).' -f $shares.Count, $items.Count, @($collectionErrors).Count) -Quiet:$Quiet
    $evidenceConfidence = @(Get-ShareSurferEvidenceConfidenceRows -Shares $shares -Items $items -CollectionErrors @($collectionErrors) -RequestedProvider $RequestedSmbCollectionProvider -EffectiveProvider $EffectiveSmbCollectionProvider)
    Write-ShareSurferStatus -Phase 'Export' -Message ('Evidence confidence rows ready: {0} row(s).' -f $evidenceConfidence.Count) -Quiet:$Quiet
    [void]$scanEvents.Add((New-ShareSurferEvent -EventType 'ExportClassificationCompleted' -Source 'Export' -Message 'Export classification completed.' -Detail ('Findings={0}; Conflicts={1}; PermissionedGroups={2}; OwnerPivots={3}; RelatedDataAreas={4}; OwnerReviewPackets={5}; EvidenceConfidence={6}' -f $findings.Count, $conflicts.Count, $permissionedGroups.Count, $ownerRiskPivots.Count, $relatedDataAreas.Count, $ownerReviewPackets.Count, $evidenceConfidence.Count)))
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
        'ownership_enrichment.csv' = $ownershipEnrichment
        'ownership_context.csv' = $ownershipContext
        'ownership_relationships.csv' = $ownershipRelationships
        'ownership_import_manifest.csv' = $ownershipImportManifest
        'owner_risk_pivots.csv' = $ownerRiskPivots
        'related_data_areas.csv' = $relatedDataAreas
        'owner_review_packets.csv' = $ownerReviewPackets
        'owner_review_decisions.csv' = @()
        'migration_cluster_decisions.csv' = @()
        'conflicts.csv' = $conflicts
        'findings.csv' = $findings
        'evidence_confidence.csv' = $evidenceConfidence
        'collection_errors.csv' = @($collectionErrors)
        'scan_events.csv' = @($scanEvents)
        'scan_manifest.csv' = $manifest
    }

    $csvIndex = 0
    $csvTotal = @($schema.Keys).Count
    foreach ($fileName in $schema.Keys) {
        $csvIndex++
        $rowCount = @(ConvertTo-ShareSurferArray $data[$fileName]).Count
        Write-ShareSurferStatus -Phase 'Export' -Message ('Writing CSV {0}/{1}: {2} ({3} row(s)).' -f $csvIndex, $csvTotal, $fileName, $rowCount) -Quiet:$Quiet
        Export-ShareSurferCsv -Path (Join-Path $OutputPath $fileName) -Columns $schema[$fileName] -Rows $data[$fileName]
    }
    Write-ShareSurferStatus -Phase 'Export' -Message ('Wrote {0} normalized CSV export(s) to {1}.' -f @($schema.Keys).Count, $OutputPath) -Quiet:$Quiet

    $eventLogRows = foreach ($event in @($scanEvents)) {
        New-ShareSurferRecord -Columns $schema['scan_events.csv'] -InputObject $event
    }
    Export-ShareSurferJsonLines -Path (Join-Path $OutputPath 'scan_events.jsonl') -Rows $eventLogRows
    $partialShares = @($shares | Where-Object {
        $null -ne $_.PSObject.Properties['PartialData'] -and [string]$_.PartialData -eq 'True'
    })

    [pscustomobject]@{
        OutputPath = $OutputPath
        Shares = $shares.Count
        Items = $items.Count
        SharePermissions = $sharePermissions.Count
        AclEntries = $aclEntries.Count
        Findings = $findings.Count
        Conflicts = $conflicts.Count
        CollectionErrors = @($collectionErrors).Count
        PartialShares = @($partialShares).Count
        DiscountedPrincipals = $discountedPrincipals.Count
        OwnershipEnrichment = $ownershipEnrichment.Count
        PermissionedGroups = $permissionedGroups.Count
        RelatedDataAreas = $relatedDataAreas.Count
        OwnerReviewPackets = $ownerReviewPackets.Count
    }
}
