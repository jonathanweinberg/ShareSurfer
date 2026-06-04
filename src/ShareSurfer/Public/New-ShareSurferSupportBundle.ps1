function New-ShareSurferSupportBundle {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $ExportPath,

        [Parameter(Mandatory = $true)]
        [string] $OutputPath,

        [ValidateSet('StableToken', 'Strict')]
        [string] $RedactionMode = 'StableToken',

        [string] $RedactionSalt = '',

        [switch] $IncludeReport
    )

    if ($RedactionSalt -eq '') {
        $RedactionSalt = [guid]::NewGuid().ToString('N')
    }

    if (-not (Test-Path -LiteralPath $OutputPath)) {
        New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
    }

    $schema = Get-ShareSurferExportSchema
    $generatedAt = (Get-Date).ToUniversalTime().ToString('o')
    $fileDiagnostics = New-Object System.Collections.ArrayList
    foreach ($fileName in $schema.Keys) {
        $sourcePath = Join-Path $ExportPath $fileName
        $destinationPath = Join-Path $OutputPath $fileName
        $rows = @(Read-ShareSurferCsv -Path $sourcePath)

        $redactedRows = foreach ($row in $rows) {
            Protect-ShareSurferRow -Row $row -FileName $fileName -Columns $schema[$fileName] -RedactionMode $RedactionMode -RedactionSalt $RedactionSalt
        }

        Export-ShareSurferCsv -Path $destinationPath -Columns $schema[$fileName] -Rows $redactedRows
        [void]$fileDiagnostics.Add([pscustomobject]@{
            FileName = $fileName
            RowCount = @($redactedRows).Count
            Sha256 = Get-ShareSurferFileSha256 -Path $destinationPath
        })
    }

    $validation = Test-ShareSurferExport -ExportPath $OutputPath
    $reportIncluded = $false
    if ($IncludeReport) {
        $reportPath = Join-Path $OutputPath 'report.html'
        ConvertTo-ShareSurferReport -ExportPath $OutputPath -OutputPath $reportPath | Out-Null
        $reportIncluded = $true
        [void]$fileDiagnostics.Add([pscustomobject]@{
            FileName = 'report.html'
            RowCount = 1
            Sha256 = Get-ShareSurferFileSha256 -Path $reportPath
        })
    }

    $redactionAuditPath = Join-Path $OutputPath 'support_bundle_redaction_audit.csv'
    $redactionAudit = @(New-ShareSurferRedactionAudit -ExportPath $ExportPath -BundlePath $OutputPath -Schema $schema -RedactionSalt $RedactionSalt)
    $redactionAudit | Export-Csv -LiteralPath $redactionAuditPath -NoTypeInformation -Encoding UTF8
    [void]$fileDiagnostics.Add([pscustomobject]@{
        FileName = 'support_bundle_redaction_audit.csv'
        RowCount = @($redactionAudit).Count
        Sha256 = Get-ShareSurferFileSha256 -Path $redactionAuditPath
    })
    $redactionLeakCount = @($redactionAudit | Where-Object { $_.LeakDetected }).Count

    $manifest = @(
        [pscustomobject]@{
            GeneratedAt = $generatedAt
            RedactionMode = $RedactionMode
            RelationshipPreserving = [bool]($RedactionMode -eq 'StableToken')
            ExportFileCount = @($schema.Keys).Count
            DiagnosticFileCount = @($fileDiagnostics).Count
            ReportIncluded = [bool]$reportIncluded
            RedactionAuditCount = @($redactionAudit).Count
            RedactionLeakCount = [int]$redactionLeakCount
            ValidationIsValid = [bool]$validation.IsValid
            MissingFileCount = @($validation.MissingFiles).Count
            SchemaErrorCount = @($validation.SchemaErrors).Count
        }
    )

    $manifest | Export-Csv -LiteralPath (Join-Path $OutputPath 'support_bundle_manifest.csv') -NoTypeInformation -Encoding UTF8
    @($fileDiagnostics) | Export-Csv -LiteralPath (Join-Path $OutputPath 'support_bundle_files.csv') -NoTypeInformation -Encoding UTF8

    Set-Content -LiteralPath (Join-Path $OutputPath 'README.txt') -Value @(
        'ShareSurfer redacted support bundle',
        ('GeneratedAt={0}' -f $generatedAt),
        ('RedactionMode={0}' -f $RedactionMode),
        ('ValidationIsValid={0}' -f [bool]$validation.IsValid),
        ('ReportIncluded={0}' -f [bool]$reportIncluded),
        ('RedactionLeakCount={0}' -f [int]$redactionLeakCount),
        'Relationship-preserving StableToken mode uses salted synthetic IDs and does not include the salt in this bundle.',
        'support_bundle_manifest.csv records bundle-level diagnostics.',
        'support_bundle_files.csv records redacted file row counts and hashes.',
        'support_bundle_redaction_audit.csv records checked source-value tokens and leak status without storing raw source values.'
    ) -Encoding UTF8

    [pscustomobject]@{
        OutputPath = $OutputPath
        RedactionMode = $RedactionMode
        ValidationIsValid = [bool]$validation.IsValid
        ReportIncluded = [bool]$reportIncluded
        RedactionLeakCount = [int]$redactionLeakCount
    }
}

function Get-ShareSurferFileSha256 {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Path
    )

    $sha = [System.Security.Cryptography.SHA256]::Create()
    $stream = [System.IO.File]::OpenRead($Path)
    try {
        $hash = $sha.ComputeHash($stream)
        ([System.BitConverter]::ToString($hash)).Replace('-', '')
    }
    finally {
        $stream.Dispose()
        $sha.Dispose()
    }
}

function New-ShareSurferRedactionAudit {
    param(
        [Parameter(Mandatory = $true)]
        [string] $ExportPath,

        [Parameter(Mandatory = $true)]
        [string] $BundlePath,

        [Parameter(Mandatory = $true)]
        [hashtable] $Schema,

        [Parameter(Mandatory = $true)]
        [string] $RedactionSalt
    )

    $bundleFiles = @(Get-ChildItem -LiteralPath $BundlePath -File -ErrorAction SilentlyContinue | Where-Object {
        $_.Name -ne 'support_bundle_redaction_audit.csv'
    })
    $bundleContents = @{}
    foreach ($file in $bundleFiles) {
        try {
            $bundleContents[$file.Name] = Get-Content -LiteralPath $file.FullName -Raw -ErrorAction Stop
        }
        catch {
            $bundleContents[$file.Name] = ''
        }
    }

    $seen = @{}
    foreach ($fileName in $Schema.Keys) {
        $rows = @(Read-ShareSurferCsv -Path (Join-Path $ExportPath $fileName))
        foreach ($row in $rows) {
            $rowType = ''
            foreach ($typeColumn in @('FindingType', 'ConflictType')) {
                $typeProperty = $row.PSObject.Properties[$typeColumn]
                if ($null -ne $typeProperty -and $null -ne $typeProperty.Value) {
                    $rowType = [string]$typeProperty.Value
                    break
                }
            }

            foreach ($column in $Schema[$fileName]) {
                $property = $row.PSObject.Properties[$column]
                if ($null -eq $property) {
                    continue
                }
                $value = [string]$property.Value
                if (-not (Test-ShareSurferRedactionAuditValue -Value $value -ColumnName $column -RowType $rowType)) {
                    continue
                }

                $key = '{0}|{1}|{2}' -f $fileName, $column, $value
                if ($seen.ContainsKey($key)) {
                    continue
                }
                $seen[$key] = $true

                $leakFiles = New-Object System.Collections.ArrayList
                foreach ($bundleFile in $bundleFiles) {
                    $content = [string]$bundleContents[$bundleFile.Name]
                    if ($content -ne '' -and $content.IndexOf($value, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
                        [void]$leakFiles.Add($bundleFile.Name)
                    }
                }

                [pscustomobject]@{
                    SourceFile = $fileName
                    ColumnName = $column
                    ValueToken = Get-ShareSurferStableToken -Value $value -Salt $RedactionSalt
                    ValueLength = $value.Length
                    CheckedFileCount = $bundleFiles.Count
                    LeakDetected = ($leakFiles.Count -gt 0)
                    LeakFiles = (@($leakFiles) -join ';')
                }
            }
        }
    }
}

function Test-ShareSurferRedactionAuditValue {
    param(
        [string] $Value,
        [string] $ColumnName = '',
        [string] $RowType = ''
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $false
    }

    $preserveColumns = @(
        'AccessControlType',
        'Rights',
        'Source',
        'ItemType',
        'Depth',
        'IsInherited',
        'InheritanceFlags',
        'PropagationFlags',
        'InheritanceEnabled',
        'PartialData',
        'PartialReason',
        'ObjectClass',
        'ChildObjectClass',
        'IsCycle',
        'IsTruncated',
        'ConflictType',
        'FindingType',
        'Severity',
        'PolicyValue',
        'ExportVersion',
        'SourceMode',
        'OperationalPathLengthThreshold',
        'AzurePathComponentLimit',
        'AzureFullPathLimit',
        'ExplicitAceDepthThreshold',
        'GroupExpansionMaxDepth',
        'AdLookupMode',
        'ObsAttribute',
        'GeneratedAt'
    )
    $structuralColumns = @(
        'ShareId',
        'ItemId',
        'FindingId',
        'ConflictId',
        'EventId',
        'Level',
        'EventType'
    )
    $observedValueSafeRows = @(
        'LongPathOperationalPolicy',
        'AzureFullPathLimit',
        'AzurePathComponentLimit',
        'DeepExplicitAce',
        'GroupExpansionTruncated'
    )

    if ($preserveColumns -contains $ColumnName -or $structuralColumns -contains $ColumnName) {
        return $false
    }
    if ($ColumnName -eq 'ObservedValue' -and $observedValueSafeRows -contains $RowType) {
        return $false
    }
    if ($Value -match '^[0-9]+$') {
        return $false
    }
    if (@('True', 'False', 'Allow', 'Deny', 'Read', 'Modify', 'Full') -contains $Value) {
        return $false
    }

    $true
}
