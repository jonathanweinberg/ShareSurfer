function Export-ShareSurferJsonLines {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Path,

        $Rows
    )

    $normalizedRows = @(ConvertTo-ShareSurferArray $Rows)
    $lines = foreach ($row in $normalizedRows) {
        $row | ConvertTo-Json -Depth 8 -Compress
    }

    if ($lines.Count -eq 0) {
        Set-Content -LiteralPath $Path -Value '' -Encoding UTF8
        return
    }

    Set-Content -LiteralPath $Path -Value $lines -Encoding UTF8
}
