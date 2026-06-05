function Protect-ShareSurferRow {
    param(
        [Parameter(Mandatory = $true)]
        $Row,

        [Parameter(Mandatory = $true)]
        [string] $FileName,

        [Parameter(Mandatory = $true)]
        [string[]] $Columns,

        [ValidateSet('StableToken', 'Strict')]
        [string] $RedactionMode = 'StableToken',

        [string] $RedactionSalt = 'ShareSurfer'
    )

    $rowType = ''
    foreach ($typeColumn in @('FindingType', 'ConflictType')) {
        $property = $Row.PSObject.Properties[$typeColumn]
        if ($null -ne $property -and $null -ne $property.Value) {
            $rowType = [string]$property.Value
            break
        }
    }

    $record = [ordered]@{}
    foreach ($column in $Columns) {
        $value = ''
        $property = $Row.PSObject.Properties[$column]
        if ($null -ne $property) {
            $value = $property.Value
        }

        $record[$column] = Protect-ShareSurferValue -Value $value -ColumnName $column -FileName $FileName -RowType $rowType -RedactionMode $RedactionMode -RedactionSalt $RedactionSalt
    }

    [pscustomobject]$record
}
