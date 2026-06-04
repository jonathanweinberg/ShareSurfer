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
        [string] $OwnerMappingPath = '',
        [switch] $SkipIdentityEnrichment,
        [switch] $IncludeFiles
    )

    if ($PSCmdlet.ParameterSetName -eq 'InputObject') {
        $inventory = $InputObject
        $sourceMode = 'InputObject'
    }
    else {
        if ($PSCmdlet.ParameterSetName -eq 'SmbShare') {
            $inventory = Get-ShareSurferSmbShareInventory -ComputerName $ComputerName -ShareName $ShareName -IncludeFiles:$IncludeFiles
            $sourceMode = 'SmbShare'
        }
        else {
            $inventory = Get-ShareSurferLocalInventory -TargetPath $TargetPath -IncludeFiles:$IncludeFiles
            $sourceMode = 'TargetPath'
        }
    }

    $inventory = Add-ShareSurferOwnerMappings -Inventory $inventory -OwnerMappingPath $OwnerMappingPath

    Export-ShareSurferInventory -Inventory $inventory -OutputPath $OutputPath -ObsAttribute $ObsAttribute -OperationalPathLengthThreshold $OperationalPathLengthThreshold -AzurePathComponentLimit $AzurePathComponentLimit -AzureFullPathLimit $AzureFullPathLimit -ExplicitAceDepthThreshold $ExplicitAceDepthThreshold -GroupExpansionMaxDepth $GroupExpansionMaxDepth -SourceMode $sourceMode -SkipIdentityEnrichment:$SkipIdentityEnrichment
}
