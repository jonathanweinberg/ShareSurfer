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
