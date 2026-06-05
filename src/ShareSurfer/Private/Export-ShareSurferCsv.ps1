function Export-ShareSurferCsv {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Path,

        [Parameter(Mandatory = $true)]
        [string[]] $Columns,

        $Rows
    )

    $normalizedRows = @(ConvertTo-ShareSurferArray $Rows)
    if ($normalizedRows.Count -eq 0) {
        Set-Content -LiteralPath $Path -Value (($Columns | ForEach-Object { '"' + ($_ -replace '"', '""') + '"' }) -join ',') -Encoding UTF8
        return
    }

    $exportRows = foreach ($row in $normalizedRows) {
        New-ShareSurferRecord -Columns $Columns -InputObject $row
    }

    $exportRows | Export-Csv -LiteralPath $Path -NoTypeInformation -Encoding UTF8
}
