function Invoke-ShareSurferScan {
    [CmdletBinding(DefaultParameterSetName = 'TargetPath')]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'InputObject')]
        $InputObject,

        [Parameter(Mandatory = $true, ParameterSetName = 'TargetPath')]
        [string[]] $TargetPath,

        [Parameter(Mandatory = $true, ParameterSetName = 'SmbShare')]
        [string] $ComputerName,

        [Parameter(Mandatory = $true, ParameterSetName = 'SmbShare')]
        [string[]] $ShareName,

        [Parameter(Mandatory = $true)]
        [string] $OutputPath,

        [Parameter(ParameterSetName = 'SmbShare')]
        [ValidateSet('Auto', 'PowerShellCim', 'NativeSmbRpc')]
        [string] $SmbCollectionProvider = 'Auto',

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
        [string] $OwnerMappingPath = '',
        [string] $OwnershipEnrichmentPath = '',
        [string] $OwnershipContextPath = '',
        [string] $OwnershipRelationshipPath = '',
        [string] $OwnershipImportManifestPath = '',
        [string] $DiscountedPrincipalPath = '',
        [ValidateSet('FullEffective', 'Compact')]
        [string] $AclExportMode = 'FullEffective',
        [switch] $SkipIdentityEnrichment,
        [switch] $IncludeFiles,
        [switch] $ParallelTargetCollection,
        [ValidateRange(1, 64)]
        [int] $TargetCollectionThrottle = 4,
        [switch] $NoCreateMissingFolders,
        [int] $StatusIntervalSeconds = 15,
        [switch] $Quiet
    )

    Write-ShareSurferStatus -Phase 'Scan' -Message ('Starting scan using {0} mode. OutputPath={1}' -f $PSCmdlet.ParameterSetName, $OutputPath) -Quiet:$Quiet
    Ensure-ShareSurferLocalDirectory -Path $OutputPath -Purpose 'scan export' -NoCreateMissingFolders:$NoCreateMissingFolders -Quiet:$Quiet | Out-Null

    $requestedSmbCollectionProvider = ''
    $effectiveSmbCollectionProvider = ''

    if ($PSCmdlet.ParameterSetName -eq 'InputObject') {
        Write-ShareSurferStatus -Phase 'Collect' -Message 'Using supplied inventory object.' -Quiet:$Quiet
        $inventory = $InputObject
        $sourceMode = 'InputObject'
    }
    else {
        if ($PSCmdlet.ParameterSetName -eq 'SmbShare') {
            Write-ShareSurferStatus -Phase 'Collect' -Message ('Scanning {0} SMB share target(s) on {1} with {2} provider.' -f @($ShareName).Count, $ComputerName, $SmbCollectionProvider) -Quiet:$Quiet
            $inventory = Get-ShareSurferSmbShareInventory -ComputerName $ComputerName -ShareName $ShareName -SmbCollectionProvider $SmbCollectionProvider -IncludeFiles:$IncludeFiles -Quiet:$Quiet
            $sourceMode = 'SmbShare'
            $collectionProvider = $SmbCollectionProvider
            $requestedSmbCollectionProvider = $SmbCollectionProvider
            if ($null -ne $inventory.PSObject.Properties['EffectiveSmbCollectionProvider']) {
                $effectiveSmbCollectionProvider = [string]$inventory.EffectiveSmbCollectionProvider
            }
            if ([string]::IsNullOrWhiteSpace($effectiveSmbCollectionProvider)) {
                $effectiveSmbCollectionProvider = $SmbCollectionProvider
            }
        }
        else {
            $targetPathList = @($TargetPath | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | ForEach-Object { [string]$_ })
            Write-ShareSurferStatus -Phase 'Collect' -Message ('Scanning {0} target path(s).' -f $targetPathList.Count) -Quiet:$Quiet
            if ($ParallelTargetCollection -and $targetPathList.Count -gt 1 -and $TargetCollectionThrottle -gt 1) {
                $inventory = Get-ShareSurferParallelLocalInventory -TargetPath $targetPathList -IncludeFiles:$IncludeFiles -ThrottleLimit $TargetCollectionThrottle -StatusIntervalSeconds $StatusIntervalSeconds -Quiet:$Quiet
            }
            else {
                if ($ParallelTargetCollection -and -not $Quiet) {
                    Write-ShareSurferStatus -Phase 'Collect' -Message 'Parallel target collection was requested but not used because fewer than two targets or a throttle of 1 was supplied.'
                }
                $inventory = Get-ShareSurferLocalInventory -TargetPath $targetPathList -IncludeFiles:$IncludeFiles -Quiet:$Quiet
            }
            $sourceMode = 'TargetPath'
            $collectionProvider = 'TargetPath'
        }
    }
    if ($PSCmdlet.ParameterSetName -eq 'InputObject') {
        $collectionProvider = 'InputObject'
    }

    if ([string]::IsNullOrWhiteSpace($OwnerMappingPath)) {
        Write-ShareSurferStatus -Phase 'Owners' -Message 'No owner mapping file was supplied; owner/business-unit pivots will use unmapped evidence where needed.' -Quiet:$Quiet
    }
    else {
        Write-ShareSurferStatus -Phase 'Owners' -Message ('Loading owner mappings from {0}.' -f $OwnerMappingPath) -Quiet:$Quiet
    }
    $inventory = Add-ShareSurferOwnerMappings -Inventory $inventory -OwnerMappingPath $OwnerMappingPath

    if (-not [string]::IsNullOrWhiteSpace($OwnershipEnrichmentPath)) {
        Test-ShareSurferOwnershipEnrichmentShape -Path $OwnershipEnrichmentPath | Out-Null

        Write-ShareSurferStatus -Phase 'Owners' -Message ('Loading ownership enrichment rows from {0}.' -f $OwnershipEnrichmentPath) -Quiet:$Quiet
        $ownershipEnrichmentRows = @(Import-Csv -LiteralPath $OwnershipEnrichmentPath)
        if ($null -ne $inventory.PSObject.Properties['OwnershipEnrichment']) {
            $inventory.OwnershipEnrichment = $ownershipEnrichmentRows
        }
        else {
            $inventory | Add-Member -MemberType NoteProperty -Name OwnershipEnrichment -Value $ownershipEnrichmentRows
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($OwnershipContextPath)) {
        Test-ShareSurferOwnershipContextGraphShape -Path $OwnershipContextPath -FileName 'ownership_context.csv' | Out-Null
        Write-ShareSurferStatus -Phase 'Owners' -Message ('Loading ownership context rows from {0}.' -f $OwnershipContextPath) -Quiet:$Quiet
        $ownershipContextRows = @(Import-Csv -LiteralPath $OwnershipContextPath)
        if ($null -ne $inventory.PSObject.Properties['OwnershipContext']) {
            $inventory.OwnershipContext = $ownershipContextRows
        }
        else {
            $inventory | Add-Member -MemberType NoteProperty -Name OwnershipContext -Value $ownershipContextRows
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($OwnershipRelationshipPath)) {
        Test-ShareSurferOwnershipContextGraphShape -Path $OwnershipRelationshipPath -FileName 'ownership_relationships.csv' | Out-Null
        Write-ShareSurferStatus -Phase 'Owners' -Message ('Loading ownership relationship rows from {0}.' -f $OwnershipRelationshipPath) -Quiet:$Quiet
        $ownershipRelationshipRows = @(Import-Csv -LiteralPath $OwnershipRelationshipPath)
        if ($null -ne $inventory.PSObject.Properties['OwnershipRelationships']) {
            $inventory.OwnershipRelationships = $ownershipRelationshipRows
        }
        else {
            $inventory | Add-Member -MemberType NoteProperty -Name OwnershipRelationships -Value $ownershipRelationshipRows
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($OwnershipImportManifestPath)) {
        Test-ShareSurferOwnershipContextGraphShape -Path $OwnershipImportManifestPath -FileName 'ownership_import_manifest.csv' | Out-Null
        Write-ShareSurferStatus -Phase 'Owners' -Message ('Loading ownership import manifest rows from {0}.' -f $OwnershipImportManifestPath) -Quiet:$Quiet
        $ownershipImportManifestRows = @(Import-Csv -LiteralPath $OwnershipImportManifestPath)
        if ($null -ne $inventory.PSObject.Properties['OwnershipImportManifest']) {
            $inventory.OwnershipImportManifest = $ownershipImportManifestRows
        }
        else {
            $inventory | Add-Member -MemberType NoteProperty -Name OwnershipImportManifest -Value $ownershipImportManifestRows
        }
    }

    Write-ShareSurferStatus -Phase 'Export' -Message 'Normalizing findings, conflicts, identity context, and CSV output.' -Quiet:$Quiet
    $result = Export-ShareSurferInventory -Inventory $inventory -OutputPath $OutputPath -ObsAttribute $ObsAttribute -OperationalPathLengthThreshold $OperationalPathLengthThreshold -AzurePathComponentLimit $AzurePathComponentLimit -AzureFullPathLimit $AzureFullPathLimit -ExplicitAceDepthThreshold $ExplicitAceDepthThreshold -GroupExpansionMaxDepth $GroupExpansionMaxDepth -AdLookupMode $AdLookupMode -ManagerIdentityFormat $ManagerIdentityFormat -SourceMode $sourceMode -CollectionProvider $collectionProvider -RequestedSmbCollectionProvider $requestedSmbCollectionProvider -EffectiveSmbCollectionProvider $effectiveSmbCollectionProvider -AclExportMode $AclExportMode -DiscountedPrincipalPath $DiscountedPrincipalPath -SkipIdentityEnrichment:$SkipIdentityEnrichment -IncludeFiles:$IncludeFiles -NoCreateMissingFolders:$NoCreateMissingFolders -StatusIntervalSeconds $StatusIntervalSeconds -Quiet:$Quiet
    Write-ShareSurferStatus -Phase 'Summary' -Message 'Scan complete.' -Quiet:$Quiet
    Write-ShareSurferStatus -Phase 'Summary' -Message ('Shares={0}; Items={1}; Findings={2}; Conflicts={3}; CollectionErrors={4}; PartialShares={5}' -f $result.Shares, $result.Items, $result.Findings, $result.Conflicts, $result.CollectionErrors, $result.PartialShares) -Quiet:$Quiet
    Write-ShareSurferStatus -Phase 'Summary' -Message ('OutputPath={0}' -f $OutputPath) -Quiet:$Quiet
    if ($result.CollectionErrors -gt 0 -or $result.PartialShares -gt 0) {
        Write-ShareSurferStatus -Phase 'Summary' -Message 'Review collection_errors.csv and partial-share evidence before owner approval.' -Quiet:$Quiet
    }
    Write-ShareSurferStatus -Phase 'Summary' -Message ('Next: Test-ShareSurferExport -ExportPath ''{0}''' -f $OutputPath) -Quiet:$Quiet
    $result
}
