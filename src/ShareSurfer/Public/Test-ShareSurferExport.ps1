function Test-ShareSurferExport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $ExportPath
    )

    $schema = [ordered]@{}
    $baseSchema = Get-ShareSurferExportSchema
    foreach ($fileName in $baseSchema.Keys) {
        $schema[$fileName] = $baseSchema[$fileName]
    }

    $optionalFiles = New-Object System.Collections.ArrayList
    [void]$optionalFiles.Add('ownership_enrichment.csv')
    $requiredOptionalFiles = New-Object System.Collections.ArrayList
    $optionalPackages = @(
        (Get-ShareSurferOpenFileExportSchema),
        (Get-ShareSurferPortProtocolExportSchema)
    )
    foreach ($packageSchema in $optionalPackages) {
        $packageFiles = @($packageSchema.Keys)
        $packagePresent = @($packageFiles | Where-Object {
            Test-Path -LiteralPath (Join-Path $ExportPath $_)
        }).Count -gt 0

        if (-not $packagePresent) {
            continue
        }

        foreach ($fileName in $packageFiles) {
            $schema[$fileName] = $packageSchema[$fileName]
            if (-not $optionalFiles.Contains($fileName)) {
                [void]$optionalFiles.Add($fileName)
            }
            if (-not $requiredOptionalFiles.Contains($fileName)) {
                [void]$requiredOptionalFiles.Add($fileName)
            }
        }
    }

    $missingFiles = New-Object System.Collections.ArrayList
    $schemaErrors = New-Object System.Collections.ArrayList
    $fileResults = New-Object System.Collections.ArrayList

    foreach ($fileName in $schema.Keys) {
        $isOptionalFile = $optionalFiles.Contains($fileName)
        $path = Join-Path $ExportPath $fileName
        if (-not (Test-Path -LiteralPath $path)) {
            if (-not $isOptionalFile) {
                [void]$missingFiles.Add($fileName)
            }
            elseif ($requiredOptionalFiles.Contains($fileName)) {
                [void]$schemaErrors.Add("$fileName is missing from an optional assessment package that is present.")
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
                Optional = $isOptionalFile
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
            Optional = $isOptionalFile
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
