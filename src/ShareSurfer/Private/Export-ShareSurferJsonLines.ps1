function Export-ShareSurferJsonLines {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Path,

        $Rows
    )

    $normalizedRows = @(ConvertTo-ShareSurferArray $Rows)
    $lines = @(foreach ($row in $normalizedRows) {
        $row | ConvertTo-Json -Depth 8 -Compress
    })

    if ($lines.Count -eq 0) {
        $utf8NoBom = New-Object -TypeName System.Text.UTF8Encoding -ArgumentList $false
        [System.IO.File]::WriteAllText($Path, '', $utf8NoBom)
        return
    }

    Set-Content -LiteralPath $Path -Value $lines -Encoding UTF8
}
