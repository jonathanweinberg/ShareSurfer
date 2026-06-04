function Test-ShareSurferExport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $ExportPath
    )

    $schema = Get-ShareSurferExportSchema
    $missingFiles = New-Object System.Collections.ArrayList
    $schemaErrors = New-Object System.Collections.ArrayList

    foreach ($fileName in $schema.Keys) {
        $path = Join-Path $ExportPath $fileName
        if (-not (Test-Path -LiteralPath $path)) {
            [void]$missingFiles.Add($fileName)
            continue
        }

        $header = (Get-Content -LiteralPath $path -First 1)
        if ($null -eq $header) {
            [void]$schemaErrors.Add("$fileName is empty.")
            continue
        }

        $actualColumns = @($header -split ',' | ForEach-Object { $_.Trim('"') })
        $expectedColumns = $schema[$fileName]
        foreach ($column in $expectedColumns) {
            if ($actualColumns -notcontains $column) {
                [void]$schemaErrors.Add("$fileName is missing column $column.")
            }
        }
    }

    [pscustomobject]@{
        ExportPath = $ExportPath
        IsValid = ($missingFiles.Count -eq 0 -and $schemaErrors.Count -eq 0)
        MissingFiles = @($missingFiles)
        SchemaErrors = @($schemaErrors)
    }
}
