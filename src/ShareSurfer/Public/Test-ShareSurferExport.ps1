function Test-ShareSurferExport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $ExportPath
    )

    $schema = Get-ShareSurferExportSchema
    $optionalFiles = @('ownership_enrichment.csv')
    $missingFiles = New-Object System.Collections.ArrayList
    $schemaErrors = New-Object System.Collections.ArrayList
    $fileResults = New-Object System.Collections.ArrayList

    foreach ($fileName in $schema.Keys) {
        $path = Join-Path $ExportPath $fileName
        if (-not (Test-Path -LiteralPath $path)) {
            $isOptionalFile = @($optionalFiles | Where-Object { $_ -eq $fileName }).Count -gt 0
            if (-not $isOptionalFile) {
                [void]$missingFiles.Add($fileName)
            }
            [void]$fileResults.Add([pscustomobject]@{
                FileName = $fileName
                Exists = $false
                Optional = $isOptionalFile
                RowCount = 0
                ExpectedColumns = @($schema[$fileName])
                ActualColumns = @()
                MissingColumns = @($schema[$fileName])
                ExtraColumns = @()
            })
            continue
        }

        $header = (Get-Content -LiteralPath $path -First 1)
        if ($null -eq $header) {
            [void]$schemaErrors.Add("$fileName is empty.")
            [void]$fileResults.Add([pscustomobject]@{
                FileName = $fileName
                Exists = $true
                Optional = $false
                RowCount = 0
                ExpectedColumns = @($schema[$fileName])
                ActualColumns = @()
                MissingColumns = @($schema[$fileName])
                ExtraColumns = @()
            })
            continue
        }

        $actualColumns = @($header -split ',' | ForEach-Object { $_.Trim('"') })
        $expectedColumns = $schema[$fileName]
        $missingColumns = New-Object System.Collections.ArrayList
        foreach ($column in $expectedColumns) {
            if ($actualColumns -notcontains $column) {
                [void]$schemaErrors.Add("$fileName is missing column $column.")
                [void]$missingColumns.Add($column)
            }
        }

        $extraColumns = New-Object System.Collections.ArrayList
        foreach ($column in $actualColumns) {
            if ($expectedColumns -notcontains $column) {
                [void]$extraColumns.Add($column)
            }
        }

        $rowCount = 0
        $rows = @(Read-ShareSurferCsv -Path $path)
        $rowCount = $rows.Count

        [void]$fileResults.Add([pscustomobject]@{
            FileName = $fileName
            Exists = $true
            Optional = $false
            RowCount = $rowCount
            ExpectedColumns = @($expectedColumns)
            ActualColumns = @($actualColumns)
            MissingColumns = @($missingColumns)
            ExtraColumns = @($extraColumns)
        })
    }

    [pscustomobject]@{
        ExportPath = $ExportPath
        IsValid = ($missingFiles.Count -eq 0 -and $schemaErrors.Count -eq 0)
        MissingFiles = @($missingFiles)
        SchemaErrors = @($schemaErrors)
        FileResults = @($fileResults)
    }
}
