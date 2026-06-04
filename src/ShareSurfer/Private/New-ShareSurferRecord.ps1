function New-ShareSurferRecord {
    param(
        [Parameter(Mandatory = $true)]
        [string[]] $Columns,

        [Parameter(Mandatory = $true)]
        $InputObject
    )

    $record = [ordered]@{}
    foreach ($column in $Columns) {
        $value = ''
        if ($null -ne $InputObject) {
            $property = $InputObject.PSObject.Properties[$column]
            if ($null -ne $property -and $null -ne $property.Value) {
                $value = $property.Value
            }
        }
        $record[$column] = $value
    }

    [pscustomobject]$record
}
