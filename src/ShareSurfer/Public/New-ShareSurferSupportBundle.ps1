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

    $redactedEventLogPath = Join-Path $OutputPath 'scan_events.jsonl'
    $redactedEventRows = @(Read-ShareSurferCsv -Path (Join-Path $OutputPath 'scan_events.csv'))
    Export-ShareSurferJsonLines -Path $redactedEventLogPath -Rows $redactedEventRows
    [void]$fileDiagnostics.Add([pscustomobject]@{
        FileName = 'scan_events.jsonl'
        RowCount = @($redactedEventRows).Count
        Sha256 = Get-ShareSurferFileSha256 -Path $redactedEventLogPath
    })

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

    $diagnosticsPath = Join-Path $OutputPath 'support_bundle_diagnostics.json'
    $diagnostics = New-ShareSurferSupportBundleDiagnostics -BundlePath $OutputPath -GeneratedAt $generatedAt -RedactionMode $RedactionMode -ReportIncluded:$reportIncluded -Validation $validation -RedactionLeakCount $redactionLeakCount -FileDiagnostics $fileDiagnostics
    $diagnostics | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $diagnosticsPath -Encoding UTF8
    [void]$fileDiagnostics.Add([pscustomobject]@{
        FileName = 'support_bundle_diagnostics.json'
        RowCount = 1
        Sha256 = Get-ShareSurferFileSha256 -Path $diagnosticsPath
    })

    $summaryPath = Join-Path $OutputPath 'support_bundle_summary.json'
    $summary = [ordered]@{
        BundleType = 'ShareSurferRedactedSupportBundle'
        GeneratedAt = $generatedAt
        RedactionMode = $RedactionMode
        RelationshipPreserving = [bool]($RedactionMode -eq 'StableToken')
        ReportIncluded = [bool]$reportIncluded
        Validation = [ordered]@{
            IsValid = [bool]$validation.IsValid
            MissingFileCount = @($validation.MissingFiles).Count
            SchemaErrorCount = @($validation.SchemaErrors).Count
        }
        Redaction = [ordered]@{
            AuditCount = @($redactionAudit).Count
            LeakCount = [int]$redactionLeakCount
            LeakDetected = ([int]$redactionLeakCount -gt 0)
        }
        Diagnostics = [ordered]@{
            FileName = 'support_bundle_diagnostics.json'
            FindingCount = [int]$diagnostics.Inventory.FindingCount
            ConflictCount = [int]$diagnostics.Inventory.ConflictCount
            PartialShareCount = [int]$diagnostics.Inventory.PartialShareCount
            CollectionErrorCount = [int]$diagnostics.Inventory.CollectionErrorCount
        }
        Files = @($fileDiagnostics | ForEach-Object {
            [ordered]@{
                FileName = [string]$_.FileName
                RowCount = [int]$_.RowCount
                Sha256 = [string]$_.Sha256
            }
        })
        Notes = @(
            'This summary is safe to share with the redacted bundle.',
            'The redaction salt and any reversal map are not included.',
            'Use support_bundle_diagnostics.json for redacted scan settings, counts, and collection-health context.',
            'Use support_bundle_redaction_audit.csv to review checked value tokens and leak status.'
        )
    }
    $summary | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $summaryPath -Encoding UTF8
    [void]$fileDiagnostics.Add([pscustomobject]@{
        FileName = 'support_bundle_summary.json'
        RowCount = 1
        Sha256 = Get-ShareSurferFileSha256 -Path $summaryPath
    })

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
        'support_bundle_summary.json provides a quick redacted bundle health summary for support triage.',
        'support_bundle_diagnostics.json summarizes redacted scan settings, export counts, findings, conflicts, partial shares, and collection errors.',
        'support_bundle_redaction_audit.csv records checked source-value tokens and leak status without storing raw source values.',
        'scan_events.jsonl is a redacted JSON Lines event log for support tools that prefer append-friendly logs.'
    ) -Encoding UTF8

    [pscustomobject]@{
        OutputPath = $OutputPath
        RedactionMode = $RedactionMode
        ValidationIsValid = [bool]$validation.IsValid
        ReportIncluded = [bool]$reportIncluded
        RedactionLeakCount = [int]$redactionLeakCount
    }
}

function New-ShareSurferSupportBundleDiagnostics {
    param(
        [Parameter(Mandatory = $true)]
        [string] $BundlePath,

        [Parameter(Mandatory = $true)]
        [string] $GeneratedAt,

        [Parameter(Mandatory = $true)]
        [string] $RedactionMode,

        [switch] $ReportIncluded,

        [Parameter(Mandatory = $true)]
        $Validation,

        [Parameter(Mandatory = $true)]
        [int] $RedactionLeakCount,

        [Parameter(Mandatory = $true)]
        $FileDiagnostics
    )

    $shares = @(Read-ShareSurferCsv -Path (Join-Path $BundlePath 'shares.csv'))
    $items = @(Read-ShareSurferCsv -Path (Join-Path $BundlePath 'items.csv'))
    $sharePermissions = @(Read-ShareSurferCsv -Path (Join-Path $BundlePath 'share_permissions.csv'))
    $aclEntries = @(Read-ShareSurferCsv -Path (Join-Path $BundlePath 'acl_entries.csv'))
    $identities = @(Read-ShareSurferCsv -Path (Join-Path $BundlePath 'identities.csv'))
    $groupEdges = @(Read-ShareSurferCsv -Path (Join-Path $BundlePath 'group_edges.csv'))
    $ownerPivots = @(Read-ShareSurferCsv -Path (Join-Path $BundlePath 'owner_risk_pivots.csv'))
    $findings = @(Read-ShareSurferCsv -Path (Join-Path $BundlePath 'findings.csv'))
    $conflicts = @(Read-ShareSurferCsv -Path (Join-Path $BundlePath 'conflicts.csv'))
    $events = @(Read-ShareSurferCsv -Path (Join-Path $BundlePath 'scan_events.csv'))
    $manifestRows = @(Read-ShareSurferCsv -Path (Join-Path $BundlePath 'scan_manifest.csv'))
    $manifest = $null
    if ($manifestRows.Count -gt 0) {
        $manifest = $manifestRows[0]
    }

    $scanSettings = [ordered]@{}
    foreach ($column in @('ExportVersion', 'ObsAttribute', 'SourceMode', 'OperationalPathLengthThreshold', 'AzurePathComponentLimit', 'AzureFullPathLimit', 'ExplicitAceDepthThreshold', 'GroupExpansionMaxDepth', 'AdLookupMode')) {
        if ($null -ne $manifest -and $null -ne $manifest.PSObject.Properties[$column]) {
            $scanSettings[$column] = [string]$manifest.$column
        }
    }

    $partialShares = @($shares | Where-Object { [string]$_.PartialData -eq 'True' })
    $collectionErrors = @($findings | Where-Object { [string]$_.FindingType -eq 'CollectionError' })
    $highFindings = @($findings | Where-Object { @('Critical', 'High') -contains [string]$_.Severity })
    $highConflicts = @($conflicts | Where-Object { @('Critical', 'High') -contains [string]$_.Severity })

    [ordered]@{
        BundleType = 'ShareSurferRedactedSupportBundleDiagnostics'
        GeneratedAt = $GeneratedAt
        RedactionMode = $RedactionMode
        RelationshipPreserving = [bool]($RedactionMode -eq 'StableToken')
        ReportIncluded = [bool]$ReportIncluded
        Validation = [ordered]@{
            IsValid = [bool]$Validation.IsValid
            MissingFileCount = @($Validation.MissingFiles).Count
            SchemaErrorCount = @($Validation.SchemaErrors).Count
        }
        Redaction = [ordered]@{
            LeakCount = [int]$RedactionLeakCount
            LeakDetected = ([int]$RedactionLeakCount -gt 0)
        }
        ScanSettings = $scanSettings
        Inventory = [ordered]@{
            ShareCount = $shares.Count
            PartialShareCount = $partialShares.Count
            ItemCount = $items.Count
            FileCount = @($items | Where-Object { [string]$_.ItemType -eq 'File' }).Count
            DirectoryCount = @($items | Where-Object { [string]$_.ItemType -eq 'Directory' }).Count
            SharePermissionCount = $sharePermissions.Count
            AclEntryCount = $aclEntries.Count
            IdentityCount = $identities.Count
            GroupEdgeCount = $groupEdges.Count
            OwnerRiskPivotCount = $ownerPivots.Count
            FindingCount = $findings.Count
            HighFindingCount = $highFindings.Count
            ConflictCount = $conflicts.Count
            HighConflictCount = $highConflicts.Count
            ScanEventCount = $events.Count
            CollectionErrorCount = $collectionErrors.Count
        }
        Rollups = [ordered]@{
            FindingsByType = @(Group-ShareSurferSupportBundleRows -Rows $findings -Field 'FindingType')
            FindingsBySeverity = @(Group-ShareSurferSupportBundleRows -Rows $findings -Field 'Severity')
            ConflictsByType = @(Group-ShareSurferSupportBundleRows -Rows $conflicts -Field 'ConflictType')
            ConflictsBySeverity = @(Group-ShareSurferSupportBundleRows -Rows $conflicts -Field 'Severity')
            CollectionErrorsByType = @(Group-ShareSurferSupportBundleRows -Rows $collectionErrors -Field 'ObservedValue')
            ScanEventsByType = @(Group-ShareSurferSupportBundleRows -Rows $events -Field 'EventType')
        }
        Files = @($FileDiagnostics | ForEach-Object {
            [ordered]@{
                FileName = [string]$_.FileName
                RowCount = [int]$_.RowCount
                Sha256 = [string]$_.Sha256
            }
        })
        Notes = @(
            'This diagnostics file is generated from redacted bundle data only.',
            'It is intended for support triage without opening every CSV file.',
            'It does not include the redaction salt or any reversal map.'
        )
    }
}

function Group-ShareSurferSupportBundleRows {
    param(
        $Rows = @(),
        [string] $Field
    )

    @($Rows |
        Group-Object -Property $Field |
        Sort-Object @{ Expression = 'Count'; Descending = $true }, Name |
        ForEach-Object {
            [ordered]@{
                Name = if ([string]::IsNullOrWhiteSpace([string]$_.Name)) { 'Unspecified' } else { [string]$_.Name }
                Count = [int]$_.Count
            }
        })
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
        'MatchingItems',
        'Directories',
        'Files',
        'FindingCount',
        'ConflictCount',
        'PartialShareCount',
        'RiskLevel',
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
