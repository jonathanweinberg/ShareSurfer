function Export-ShareSurferCsv {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Path,

        [Parameter(Mandatory = $true)]
        [string[]] $Columns,

        $Rows
    )

    $normalizedRows = @(ConvertTo-ShareSurferArray $Rows)
    $utf8Bom = New-Object -TypeName System.Text.UTF8Encoding -ArgumentList $true
    if ($normalizedRows.Count -eq 0) {
        [System.IO.File]::WriteAllLines($Path, @((($Columns | ForEach-Object { '"' + ($_ -replace '"', '""') + '"' }) -join ',')), $utf8Bom)
        return
    }

    $exportRows = foreach ($row in $normalizedRows) {
        New-ShareSurferRecord -Columns $Columns -InputObject $row
    }

    $csvLines = @($exportRows | ConvertTo-Csv -NoTypeInformation)
    [System.IO.File]::WriteAllLines($Path, [string[]]$csvLines, $utf8Bom)
}
