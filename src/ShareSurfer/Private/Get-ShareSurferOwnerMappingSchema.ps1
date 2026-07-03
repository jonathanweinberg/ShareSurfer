function Get-ShareSurferOwnerMappingRequiredColumns {
    @('Pattern', 'Owner', 'BusinessUnit')
}

function Get-ShareSurferOwnerMappingColumns {
    @(
        'Pattern',
        'Owner',
        'BusinessUnit',
        'Source',
        'PathPrefix',
        'OwnerMail',
        'OBS',
        'Confidence',
        'MappingScope',
        'ShareId',
        'Notes'
    )
}

function Read-ShareSurferOwnerMappingCsv {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Owner mapping file was not found: $Path"
    }

    $headers = @(Get-ShareSurferCsvHeaders -Path $Path)
    [pscustomobject]@{
        Path = $Path
        Headers = [string[]]$headers
        HeaderMap = Resolve-ShareSurferOwnerMappingHeaderMap -Headers $headers
        Rows = @(Import-Csv -LiteralPath $Path)
    }
}

function Resolve-ShareSurferOwnerMappingHeaderMap {
    param(
        [Parameter(Mandatory = $true)]
        [string[]] $Headers
    )

    $headersByNormalizedName = @{}
    foreach ($header in @($Headers)) {
        $normalized = Normalize-ShareSurferOwnershipHeaderName -Name $header
        if ($normalized -ne '' -and -not $headersByNormalizedName.ContainsKey($normalized)) {
            $headersByNormalizedName[$normalized] = [string]$header
        }
    }

    $map = [ordered]@{}
    foreach ($column in @(Get-ShareSurferOwnerMappingColumns)) {
        $normalized = Normalize-ShareSurferOwnershipHeaderName -Name $column
        $map[$column] = if ($headersByNormalizedName.ContainsKey($normalized)) { [string]$headersByNormalizedName[$normalized] } else { '' }
    }

    [pscustomobject]$map
}

function Get-ShareSurferMappedCsvValue {
    param(
        [Parameter(Mandatory = $true)]
        [psobject] $Row,

        [Parameter(Mandatory = $true)]
        [psobject] $HeaderMap,

        [Parameter(Mandatory = $true)]
        [string] $Column
    )

    if (-not $HeaderMap.PSObject.Properties[$Column]) {
        return ''
    }

    $header = [string]$HeaderMap.PSObject.Properties[$Column].Value
    if ([string]::IsNullOrWhiteSpace($header) -or -not $Row.PSObject.Properties[$header]) {
        return ''
    }

    ([string]$Row.PSObject.Properties[$header].Value).Trim()
}

function New-ShareSurferOwnerMappingPattern {
    param(
        [AllowNull()]
        [string] $Path
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return ''
    }

    $trimmedPath = ([string]$Path).Trim()
    if ($trimmedPath.EndsWith('\') -or $trimmedPath.EndsWith('/')) {
        return ($trimmedPath + '*')
    }

    $separator = if ($trimmedPath -like '*/*' -and $trimmedPath -notlike '*\*') { '/' } else { '\' }
    '{0}{1}*' -f $trimmedPath, $separator
}

function Test-ShareSurferOwnerMappingData {
    param(
        [Parameter(Mandatory = $true)]
        [psobject] $MappingCsv,

        [string] $ExportPath = ''
    )

    $headers = @($MappingCsv.Headers)
    $headerMap = $MappingCsv.HeaderMap
    $rows = @($MappingCsv.Rows)
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
        if ($rows.Count -eq 0) {
            $message = 'Owner mapping CSV contains headers but no data rows. The scan can continue, but no owner/business-unit mappings will be added from this file.'
            $warnings.Add($message)
            $problemRows.Add([pscustomobject]@{
                RowNumber = 0
                Column = ''
                Severity = 'Warning'
                Problem = 'HeadersOnlyOwnerMapping'
                Message = $message
            })
        }

        $rowNumber = 1
        foreach ($row in $rows) {
            $rowNumber++
            foreach ($column in @('Pattern', 'Owner')) {
                $value = Get-ShareSurferMappedCsvValue -Row $row -HeaderMap $headerMap -Column $column
                if ([string]::IsNullOrWhiteSpace($value)) {
                    $message = ('Row {0} has a blank {1}. Fill Pattern and Owner before using this file as -OwnerMappingPath.' -f $rowNumber, $column)
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

            $businessUnit = Get-ShareSurferMappedCsvValue -Row $row -HeaderMap $headerMap -Column 'BusinessUnit'
            if ([string]::IsNullOrWhiteSpace($businessUnit)) {
                $message = ('Row {0} has a blank BusinessUnit. The scan can continue, but this mapping will appear as an unmapped business-unit gap in reports.' -f $rowNumber)
                $warnings.Add($message)
                $problemRows.Add([pscustomobject]@{
                    RowNumber = $rowNumber
                    Column = 'BusinessUnit'
                    Severity = 'Warning'
                    Problem = 'BlankBusinessUnit'
                    Message = $message
                })
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

        $shareCandidatePaths = New-Object System.Collections.Generic.HashSet[string]([System.StringComparer]::OrdinalIgnoreCase)
        $sharesPath = Join-Path $ExportPath 'shares.csv'
        if (Test-Path -LiteralPath $sharesPath) {
            foreach ($share in @(Read-ShareSurferCsv -Path $sharesPath)) {
                foreach ($candidate in @([string]$share.UNCPath, [string]$share.LocalPath)) {
                    if (-not [string]::IsNullOrWhiteSpace($candidate)) {
                        [void]$shareCandidatePaths.Add($candidate)
                    }
                }
            }
        }

        $itemsPath = Join-Path $ExportPath 'items.csv'
        $itemCandidatePaths = $null

        if ($missingRequired.Count -eq 0) {
            $rowNumber = 1
            foreach ($row in $rows) {
                $rowNumber++
                $pattern = Get-ShareSurferMappedCsvValue -Row $row -HeaderMap $headerMap -Column 'Pattern'
                if ([string]::IsNullOrWhiteSpace($pattern)) {
                    continue
                }

                $matched = $false
                foreach ($candidatePath in @($shareCandidatePaths)) {
                    if (Test-ShareSurferWildcardMatch -Pattern $pattern -Value $candidatePath) {
                        $matched = $true
                        break
                    }
                }

                if (-not $matched) {
                    if ($null -eq $itemCandidatePaths) {
                        $itemCandidatePaths = New-Object System.Collections.Generic.HashSet[string]([System.StringComparer]::OrdinalIgnoreCase)
                        if (Test-Path -LiteralPath $itemsPath) {
                            foreach ($item in @(Read-ShareSurferCsv -Path $itemsPath)) {
                                $candidate = [string]$item.FullPath
                                if (-not [string]::IsNullOrWhiteSpace($candidate)) {
                                    [void]$itemCandidatePaths.Add($candidate)
                                }
                            }
                        }
                    }

                    foreach ($candidatePath in @($itemCandidatePaths)) {
                        if (Test-ShareSurferWildcardMatch -Pattern $pattern -Value $candidatePath) {
                            $matched = $true
                            break
                        }
                    }
                }

                if (-not $matched) {
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
        SourcePath = [string]$MappingCsv.Path
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

function Test-ShareSurferOwnershipEnrichmentShape {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Ownership enrichment file was not found: $Path"
    }

    $headers = @(Get-ShareSurferCsvHeaders -Path $Path)
    $headersByNormalizedName = @{}
    foreach ($header in $headers) {
        $normalized = Normalize-ShareSurferOwnershipHeaderName -Name $header
        if ($normalized -ne '') {
            $headersByNormalizedName[$normalized] = $true
        }
    }

    $requiredAnchors = @('OwnershipKey', 'MatchStatus', 'SourcePaths', 'EmployeeId', 'OBS', 'ImportWarnings')
    $missing = New-Object System.Collections.Generic.List[string]
    foreach ($column in $requiredAnchors) {
        $normalized = Normalize-ShareSurferOwnershipHeaderName -Name $column
        if (-not $headersByNormalizedName.ContainsKey($normalized)) {
            $missing.Add($column)
        }
    }

    if ($missing.Count -gt 0) {
        $normalizedImportColumns = @('EmployeeId', 'EmployeeNumber', 'SamAccountName', 'UserPrincipalName', 'Mail', 'DisplayName', 'ManagerMail', 'SourceRowNumber', 'SourcePath')
        $looksLikeNormalizedImport = $true
        foreach ($column in $normalizedImportColumns) {
            $normalized = Normalize-ShareSurferOwnershipHeaderName -Name $column
            if (-not $headersByNormalizedName.ContainsKey($normalized)) {
                $looksLikeNormalizedImport = $false
                break
            }
        }

        $hint = if ($looksLikeNormalizedImport) {
            ' This looks like normalized-ownership.csv from Import-ShareSurferOwnershipSource. Run Join-ShareSurferOwnershipSources and pass that ownership-enrichment.csv file to -OwnershipEnrichmentPath.'
        }
        else {
            ' Build this file with Join-ShareSurferOwnershipSources before passing it to -OwnershipEnrichmentPath.'
        }
        throw ("Ownership enrichment file does not look like Join-ShareSurferOwnershipSources output. Missing column(s): {0}.{1}" -f (($missing | Sort-Object) -join ', '), $hint)
    }

    [pscustomobject]@{
        Path = $Path
        IsValid = $true
        HeaderCount = $headers.Count
        RequiredColumns = ($requiredAnchors -join ', ')
    }
}

function Test-ShareSurferOwnershipContextGraphShape {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Path,

        [Parameter(Mandatory = $true)]
        [ValidateSet('ownership_context.csv', 'ownership_relationships.csv', 'ownership_import_manifest.csv')]
        [string] $FileName
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Ownership context graph file was not found: $Path"
    }

    $schema = Get-ShareSurferExportSchema
    $expectedColumns = @($schema[$FileName])
    if ($expectedColumns.Count -eq 0) {
        throw "ShareSurfer does not have an ownership context graph schema for $FileName."
    }

    $headers = @(Get-ShareSurferCsvHeaders -Path $Path)
    $headersByNormalizedName = @{}
    foreach ($header in $headers) {
        $normalized = Normalize-ShareSurferOwnershipHeaderName -Name $header
        if ($normalized -ne '') {
            $headersByNormalizedName[$normalized] = $true
        }
    }

    $missing = New-Object System.Collections.Generic.List[string]
    foreach ($column in $expectedColumns) {
        $normalized = Normalize-ShareSurferOwnershipHeaderName -Name $column
        if (-not $headersByNormalizedName.ContainsKey($normalized)) {
            $missing.Add($column)
        }
    }

    if ($missing.Count -gt 0) {
        throw ("Ownership context graph file {0} does not match the expected ShareSurfer schema. Missing column(s): {1}. Rebuild this file with Join-ShareSurferOwnershipSources -IncludeContextGraph." -f $FileName, (($missing | Sort-Object) -join ', '))
    }

    [pscustomobject]@{
        Path = $Path
        FileName = $FileName
        IsValid = $true
        HeaderCount = $headers.Count
        ExpectedColumns = ($expectedColumns -join ', ')
    }
}
