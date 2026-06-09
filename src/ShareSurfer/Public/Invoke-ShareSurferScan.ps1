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
        [string] $DiscountedPrincipalPath = '',
        [switch] $SkipIdentityEnrichment,
        [switch] $IncludeFiles,
        [switch] $Quiet
    )

    Write-ShareSurferStatus -Phase 'Scan' -Message ('Starting scan using {0} mode. OutputPath={1}' -f $PSCmdlet.ParameterSetName, $OutputPath) -Quiet:$Quiet

    if ($PSCmdlet.ParameterSetName -eq 'InputObject') {
        Write-ShareSurferStatus -Phase 'Collect' -Message 'Using supplied inventory object.' -Quiet:$Quiet
        $inventory = $InputObject
        $sourceMode = 'InputObject'
    }
    else {
        if ($PSCmdlet.ParameterSetName -eq 'SmbShare') {
            Write-ShareSurferStatus -Phase 'Collect' -Message ('Scanning {0} SMB share target(s) on {1}.' -f @($ShareName).Count, $ComputerName) -Quiet:$Quiet
            $inventory = Get-ShareSurferSmbShareInventory -ComputerName $ComputerName -ShareName $ShareName -IncludeFiles:$IncludeFiles -Quiet:$Quiet
            $sourceMode = 'SmbShare'
        }
        else {
            Write-ShareSurferStatus -Phase 'Collect' -Message ('Scanning {0} target path(s).' -f @($TargetPath).Count) -Quiet:$Quiet
            $inventory = Get-ShareSurferLocalInventory -TargetPath $TargetPath -IncludeFiles:$IncludeFiles -Quiet:$Quiet
            $sourceMode = 'TargetPath'
        }
    }

    if ([string]::IsNullOrWhiteSpace($OwnerMappingPath)) {
        Write-ShareSurferStatus -Phase 'Owners' -Message 'No owner mapping file was supplied; owner/business-unit pivots will use unmapped evidence where needed.' -Quiet:$Quiet
    }
    else {
        Write-ShareSurferStatus -Phase 'Owners' -Message ('Loading owner mappings from {0}.' -f $OwnerMappingPath) -Quiet:$Quiet
    }
    $inventory = Add-ShareSurferOwnerMappings -Inventory $inventory -OwnerMappingPath $OwnerMappingPath

    Write-ShareSurferStatus -Phase 'Export' -Message 'Normalizing findings, conflicts, identity context, and CSV output.' -Quiet:$Quiet
    $result = Export-ShareSurferInventory -Inventory $inventory -OutputPath $OutputPath -ObsAttribute $ObsAttribute -OperationalPathLengthThreshold $OperationalPathLengthThreshold -AzurePathComponentLimit $AzurePathComponentLimit -AzureFullPathLimit $AzureFullPathLimit -ExplicitAceDepthThreshold $ExplicitAceDepthThreshold -GroupExpansionMaxDepth $GroupExpansionMaxDepth -AdLookupMode $AdLookupMode -ManagerIdentityFormat $ManagerIdentityFormat -SourceMode $sourceMode -DiscountedPrincipalPath $DiscountedPrincipalPath -SkipIdentityEnrichment:$SkipIdentityEnrichment -IncludeFiles:$IncludeFiles -Quiet:$Quiet
    Write-ShareSurferStatus -Phase 'Done' -Message ('Completed scan. Shares={0}; Items={1}; Findings={2}; Conflicts={3}; OutputPath={4}' -f $result.Shares, $result.Items, $result.Findings, $result.Conflicts, $OutputPath) -Quiet:$Quiet
    $result
}
