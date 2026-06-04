function Read-ShareSurferCsv {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return @()
    }

    $content = Get-Content -LiteralPath $Path -Raw
    if ([string]::IsNullOrWhiteSpace($content)) {
        return @()
    }

    $rows = @(Import-Csv -LiteralPath $Path)
    if ($rows.Count -eq 1) {
        $hasData = $false
        foreach ($property in $rows[0].PSObject.Properties) {
            if ([string]$property.Value -ne '') {
                $hasData = $true
                break
            }
        }
        if (-not $hasData) {
            return @()
        }
    }

    $rows
}
