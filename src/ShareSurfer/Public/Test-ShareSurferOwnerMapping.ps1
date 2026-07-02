function Test-ShareSurferOwnerMapping {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $Path,

        [string] $ExportPath = ''
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Owner mapping file was not found: $Path"
    }

    $headers = @(Get-ShareSurferCsvHeaders -Path $Path)
    $headerMap = Resolve-ShareSurferOwnerMappingHeaderMap -Headers $headers
    $rows = @(Import-Csv -LiteralPath $Path)
    $errors = New-Object System.Collections.Generic.List[string]
    $warnings = New-Object System.Collections.Generic.List[string]
    $problemRows = New-Object System.Collections.Generic.List[object]

    $missingRequired = New-Object System.Collections.Generic.List[string]
    foreach ($column in @(Get-ShareSurferOwnerMappingRequiredColumns)) {
        if (-not $headerMap.PSObject.Properties[$column] -or [string]::IsNullOrWhiteSpace([string]$headerMap.PSObject.Properties[$column].Value)) {
            $missingRequired.Add($column)
        }
    }

    if ($missingRequired.Count -gt 0) {
        $errors.Add(("Owner mapping CSV is missing required column(s): {0}. Required columns are Pattern, Owner, and BusinessUnit." -f (($missingRequired | Sort-Object) -join ', ')))
    }
    else {
        $rowNumber = 1
        foreach ($row in $rows) {
            $rowNumber++
            foreach ($column in @(Get-ShareSurferOwnerMappingRequiredColumns)) {
                $value = Get-ShareSurferMappedCsvValue -Row $row -HeaderMap $headerMap -Column $column
                if ([string]::IsNullOrWhiteSpace($value)) {
                    $message = ('Row {0} has a blank {1}. Fill Pattern, Owner, and BusinessUnit before using this file as -OwnerMappingPath.' -f $rowNumber, $column)
                    $errors.Add($message)
                    $problemRows.Add([pscustomobject]@{
                        RowNumber = $rowNumber
                        Column = $column
                        Severity = 'Error'
                        Problem = 'BlankRequiredValue'
                        Message = $message
                    })
                }
            }

            $pattern = Get-ShareSurferMappedCsvValue -Row $row -HeaderMap $headerMap -Column 'Pattern'
            if ($pattern -match '[^\\/]\*$') {
                $message = ('Row {0} pattern "{1}" may match sibling paths. Prefer a boundary-safe pattern such as "{2}".' -f $rowNumber, $pattern, (New-ShareSurferOwnerMappingPattern -Path ($pattern.Substring(0, $pattern.Length - 1))))
                $warnings.Add($message)
                $problemRows.Add([pscustomobject]@{
                    RowNumber = $rowNumber
                    Column = 'Pattern'
                    Severity = 'Warning'
                    Problem = 'SiblingPrefixPattern'
                    Message = $message
                })
            }
        }
    }

    $zeroMatchPatterns = New-Object System.Collections.Generic.List[string]
    if (-not [string]::IsNullOrWhiteSpace($ExportPath)) {
        if (-not (Test-Path -LiteralPath $ExportPath)) {
            throw "ShareSurfer export path was not found: $ExportPath"
        }

        $candidatePaths = New-Object System.Collections.Generic.List[string]
        $sharesPath = Join-Path $ExportPath 'shares.csv'
        if (Test-Path -LiteralPath $sharesPath) {
            foreach ($share in @(Read-ShareSurferCsv -Path $sharesPath)) {
                foreach ($candidate in @([string]$share.UNCPath, [string]$share.LocalPath)) {
                    if (-not [string]::IsNullOrWhiteSpace($candidate)) {
                        $candidatePaths.Add($candidate)
                    }
                }
            }
        }

        $itemsPath = Join-Path $ExportPath 'items.csv'
        if (Test-Path -LiteralPath $itemsPath) {
            foreach ($item in @(Read-ShareSurferCsv -Path $itemsPath)) {
                $candidate = [string]$item.FullPath
                if (-not [string]::IsNullOrWhiteSpace($candidate)) {
                    $candidatePaths.Add($candidate)
                }
            }
        }

        if ($missingRequired.Count -eq 0) {
            $rowNumber = 1
            foreach ($row in $rows) {
                $rowNumber++
                $pattern = Get-ShareSurferMappedCsvValue -Row $row -HeaderMap $headerMap -Column 'Pattern'
                if ([string]::IsNullOrWhiteSpace($pattern)) {
                    continue
                }

                $matches = @($candidatePaths | Where-Object { Test-ShareSurferWildcardMatch -Pattern $pattern -Value $_ })
                if ($matches.Count -eq 0) {
                    $zeroMatchPatterns.Add($pattern)
                    $message = ('Row {0} pattern "{1}" did not match any share or item path in {2}.' -f $rowNumber, $pattern, $ExportPath)
                    $warnings.Add($message)
                    $problemRows.Add([pscustomobject]@{
                        RowNumber = $rowNumber
                        Column = 'Pattern'
                        Severity = 'Warning'
                        Problem = 'PatternMatchedNoPaths'
                        Message = $message
                    })
                }
            }
        }
    }

    [pscustomobject]@{
        SourcePath = $Path
        ExportPath = $ExportPath
        RowCount = $rows.Count
        HeaderCount = $headers.Count
        Headers = ($headers -join ', ')
        RequiredColumns = ((Get-ShareSurferOwnerMappingRequiredColumns) -join ', ')
        MissingRequiredColumns = ((@($missingRequired.ToArray()) | Sort-Object) -join ', ')
        IsValid = ($errors.Count -eq 0)
        ErrorCount = $errors.Count
        WarningCount = $warnings.Count
        ZeroMatchPatternCount = $zeroMatchPatterns.Count
        Errors = [string[]]@($errors.ToArray())
        Warnings = [string[]]@($warnings.ToArray())
        ProblemRows = @($problemRows.ToArray())
    }
}
