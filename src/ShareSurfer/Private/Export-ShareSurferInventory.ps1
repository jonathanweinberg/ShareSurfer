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
        [switch] $SkipIdentityEnrichment
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
    $scanErrors = @()
    if ($null -ne $Inventory.PSObject.Properties['ScanErrors']) {
        $scanErrors = @(ConvertTo-ShareSurferArray $Inventory.ScanErrors)
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

    $conflicts = @(Get-ShareSurferConflicts -SharePermissions $sharePermissions -AclEntries $aclEntries)
    $findings = @(Get-ShareSurferFindings -Items $items -AclEntries $aclEntries -Shares $shares -GroupEdges $groupEdges -ScanErrors $scanErrors -OperationalPathLengthThreshold $OperationalPathLengthThreshold -AzurePathComponentLimit $AzurePathComponentLimit -AzureFullPathLimit $AzureFullPathLimit -ExplicitAceDepthThreshold $ExplicitAceDepthThreshold)
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
        'org_chains.csv' = $orgChains
        'owner_mappings.csv' = $ownerMappings
        'conflicts.csv' = $conflicts
        'findings.csv' = $findings
        'scan_events.csv' = @($scanEvents)
        'scan_manifest.csv' = $manifest
    }

    foreach ($fileName in $schema.Keys) {
        Export-ShareSurferCsv -Path (Join-Path $OutputPath $fileName) -Columns $schema[$fileName] -Rows $data[$fileName]
    }

    [pscustomobject]@{
        OutputPath = $OutputPath
        Shares = $shares.Count
        Items = $items.Count
        SharePermissions = $sharePermissions.Count
        AclEntries = $aclEntries.Count
        Findings = $findings.Count
        Conflicts = $conflicts.Count
    }
}
