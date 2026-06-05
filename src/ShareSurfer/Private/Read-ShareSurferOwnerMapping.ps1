function Read-ShareSurferOwnerMapping {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Owner mapping file was not found: $Path"
    }

    $rows = @(Import-Csv -LiteralPath $Path)
    foreach ($row in $rows) {
        [pscustomobject]@{
            Pattern = [string]$row.Pattern
            Owner = [string]$row.Owner
            BusinessUnit = [string]$row.BusinessUnit
            Source = if ($row.PSObject.Properties['Source'] -and [string]$row.Source -ne '') { [string]$row.Source } else { 'OwnerMappingPath' }
        }
    }
}
