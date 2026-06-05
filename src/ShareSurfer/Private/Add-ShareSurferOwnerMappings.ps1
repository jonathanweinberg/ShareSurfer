function Add-ShareSurferOwnerMappings {
    param(
        [Parameter(Mandatory = $true)]
        $Inventory,

        [string] $OwnerMappingPath = ''
    )

    if ([string]::IsNullOrWhiteSpace($OwnerMappingPath)) {
        return $Inventory
    }

    $existingMappings = @()
    if ($null -ne $Inventory.PSObject.Properties['OwnerMappings']) {
        $existingMappings = @(ConvertTo-ShareSurferArray $Inventory.OwnerMappings)
    }

    $fileMappings = @(Read-ShareSurferOwnerMapping -Path $OwnerMappingPath)
    $mergedMappings = @($existingMappings + $fileMappings)
    if ($null -ne $Inventory.PSObject.Properties['OwnerMappings']) {
        $Inventory.OwnerMappings = $mergedMappings
    }
    else {
        $Inventory | Add-Member -MemberType NoteProperty -Name OwnerMappings -Value $mergedMappings
    }
    $Inventory
}
