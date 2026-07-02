function Test-ShareSurferReviewDecisionCsvColumns {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Path,

        [Parameter(Mandatory = $true)]
        [string[]] $RequiredColumns,

        [Parameter(Mandatory = $true)]
        [string] $Description
    )

    $rows = @(Read-ShareSurferCsv -Path $Path)
    $columns = @()
    if ($rows.Count -gt 0) {
        $columns = @($rows[0].PSObject.Properties | ForEach-Object { [string]$_.Name })
    }
    else {
        $firstLine = Get-Content -LiteralPath $Path -TotalCount 1 -ErrorAction Stop
        if (-not [string]::IsNullOrWhiteSpace($firstLine)) {
            $columns = @($firstLine -split ',' | ForEach-Object { ([string]$_).Trim().Trim('"') })
        }
    }

    $missingColumns = @($RequiredColumns | Where-Object { $columns -notcontains $_ })
    if ($missingColumns.Count -gt 0) {
        throw ('{0} is missing required column(s): {1}. Path: {2}' -f $Description, ($missingColumns -join ', '), $Path)
    }

    @($rows)
}

function Test-ShareSurferReviewDecisionIsDurable {
    param(
        $Row
    )

    if ($null -eq $Row) {
        return $false
    }

    $decision = if ($null -ne $Row.PSObject.Properties['Decision']) { [string]$Row.Decision } else { '' }
    $status = if ($null -ne $Row.PSObject.Properties['DecisionStatus']) { [string]$Row.DecisionStatus } else { '' }
    (-not [string]::IsNullOrWhiteSpace($decision) -and -not $status.Equals('NeedsCorrection', [System.StringComparison]::OrdinalIgnoreCase))
}

function Get-ShareSurferReviewDecisionReviewedAt {
    param(
        $Row
    )

    if ($null -eq $Row -or $null -eq $Row.PSObject.Properties['ReviewedAt'] -or [string]::IsNullOrWhiteSpace([string]$Row.ReviewedAt)) {
        return $null
    }

    $text = ([string]$Row.ReviewedAt).Trim()
    $parsed = [datetime]::MinValue
    $roundtripStyles = [System.Globalization.DateTimeStyles]::RoundtripKind -bor [System.Globalization.DateTimeStyles]::AllowWhiteSpaces
    if ([datetime]::TryParseExact($text, 'o', [System.Globalization.CultureInfo]::InvariantCulture, $roundtripStyles, [ref]$parsed)) {
        return $parsed
    }

    $fallbackStyles = [System.Globalization.DateTimeStyles]::AssumeLocal -bor [System.Globalization.DateTimeStyles]::AllowWhiteSpaces
    if ([datetime]::TryParse($text, [System.Globalization.CultureInfo]::InvariantCulture, $fallbackStyles, [ref]$parsed)) {
        return $parsed
    }

    $null
}

function Add-ShareSurferDecisionImportWarning {
    param(
        $Row,

        [string] $Warning = ''
    )

    if ($null -eq $Row -or [string]::IsNullOrWhiteSpace($Warning)) {
        return
    }

    $existing = if ($null -ne $Row.PSObject.Properties['ImportWarnings']) { [string]$Row.ImportWarnings } else { '' }
    $warnings = New-Object System.Collections.ArrayList
    foreach ($value in @($existing -split '; ')) {
        if (-not [string]::IsNullOrWhiteSpace($value) -and -not $warnings.Contains($value)) {
            [void]$warnings.Add($value)
        }
    }
    if (-not $warnings.Contains($Warning)) {
        [void]$warnings.Add($Warning)
    }
    if ($null -eq $Row.PSObject.Properties['ImportWarnings']) {
        $Row | Add-Member -NotePropertyName ImportWarnings -NotePropertyValue ''
    }
    $Row.ImportWarnings = @($warnings) -join '; '
}

function Select-ShareSurferReviewDecisionSource {
    param(
        $Existing,

        $Incoming,

        [string] $Key = ''
    )

    if ($null -eq $Existing) {
        return $Incoming
    }
    if ($null -eq $Incoming) {
        return $Existing
    }

    $existingIsDurable = Test-ShareSurferReviewDecisionIsDurable -Row $Existing
    $incomingIsDurable = Test-ShareSurferReviewDecisionIsDurable -Row $Incoming
    if ($existingIsDurable -and -not $incomingIsDurable) {
        Add-ShareSurferDecisionImportWarning -Row $Existing -Warning ('Skipped older or pending incoming decision for {0}; existing reviewed decision was kept.' -f $Key)
        return $Existing
    }
    if (-not $existingIsDurable -and $incomingIsDurable) {
        return $Incoming
    }
    if ($existingIsDurable -and $incomingIsDurable) {
        $existingReviewedAt = Get-ShareSurferReviewDecisionReviewedAt -Row $Existing
        $incomingReviewedAt = Get-ShareSurferReviewDecisionReviewedAt -Row $Incoming
        if ($null -ne $existingReviewedAt -and $null -ne $incomingReviewedAt) {
            if ($incomingReviewedAt -lt $existingReviewedAt) {
                Add-ShareSurferDecisionImportWarning -Row $Existing -Warning ('Skipped older incoming decision for {0}; existing ReviewedAt {1:o} is newer than incoming ReviewedAt {2:o}.' -f $Key, $existingReviewedAt, $incomingReviewedAt)
                return $Existing
            }
            if ($incomingReviewedAt -gt $existingReviewedAt) {
                Add-ShareSurferDecisionImportWarning -Row $Incoming -Warning ('Replaced existing decision for {0}; incoming ReviewedAt {1:o} is newer than existing ReviewedAt {2:o}.' -f $Key, $incomingReviewedAt, $existingReviewedAt)
                return $Incoming
            }
        }
        Add-ShareSurferDecisionImportWarning -Row $Incoming -Warning ('Replaced existing reviewed decision for {0}; ReviewedAt values were equal or unavailable.' -f $Key)
    }

    $Incoming
}

function Import-ShareSurferReviewDecisions {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $ExportPath,

        [string] $DecisionPath = '',

        [string] $OwnerDecisionPath = '',

        [string] $MigrationDecisionPath = '',

        [string] $OutputPath = '',

        [string] $ReusableCommandPath = '',

        [switch] $Force
    )

    if (-not (Test-Path -LiteralPath $ExportPath -PathType Container)) {
        throw "ShareSurfer export path was not found: $ExportPath"
    }

    if (-not [string]::IsNullOrWhiteSpace($DecisionPath)) {
        if (-not (Test-Path -LiteralPath $DecisionPath -PathType Container)) {
            throw "Review decision folder was not found: $DecisionPath"
        }
        if ([string]::IsNullOrWhiteSpace($OwnerDecisionPath)) {
            $candidateOwnerPath = Join-Path $DecisionPath 'owner_review_decisions.csv'
            if (Test-Path -LiteralPath $candidateOwnerPath -PathType Leaf) {
                $OwnerDecisionPath = $candidateOwnerPath
            }
        }
        if ([string]::IsNullOrWhiteSpace($MigrationDecisionPath)) {
            $candidateMigrationPath = Join-Path $DecisionPath 'migration_cluster_decisions.csv'
            if (Test-Path -LiteralPath $candidateMigrationPath -PathType Leaf) {
                $MigrationDecisionPath = $candidateMigrationPath
            }
        }
    }

    if ([string]::IsNullOrWhiteSpace($OwnerDecisionPath) -and [string]::IsNullOrWhiteSpace($MigrationDecisionPath)) {
        throw 'Provide -DecisionPath, -OwnerDecisionPath, -MigrationDecisionPath, or both specific decision CSV paths.'
    }

    if ([string]::IsNullOrWhiteSpace($OutputPath)) {
        $OutputPath = $ExportPath
    }
    if (-not (Test-Path -LiteralPath $OutputPath)) {
        New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
    }

    $schema = Get-ShareSurferExportSchema
    $outputOwnerDecisionPath = Join-Path $OutputPath 'owner_review_decisions.csv'
    $outputMigrationDecisionPath = Join-Path $OutputPath 'migration_cluster_decisions.csv'
    if (-not $Force) {
        foreach ($existingOutputPath in @($outputOwnerDecisionPath, $outputMigrationDecisionPath)) {
            if (Test-Path -LiteralPath $existingOutputPath -PathType Leaf) {
                throw "Review decision output already exists: $existingOutputPath. Use -Force to overwrite it."
            }
        }
    }

    $ownerInputs = @()
    if (Test-Path -LiteralPath $outputOwnerDecisionPath -PathType Leaf) {
        $ownerInputs += @(Test-ShareSurferReviewDecisionCsvColumns -Path $outputOwnerDecisionPath -RequiredColumns @('ReviewPacketId') -Description 'Existing owner review decision CSV')
    }
    if (-not [string]::IsNullOrWhiteSpace($OwnerDecisionPath)) {
        if (-not (Test-Path -LiteralPath $OwnerDecisionPath -PathType Leaf)) {
            throw "Owner review decision CSV was not found: $OwnerDecisionPath"
        }
        $ownerInputs += @(Test-ShareSurferReviewDecisionCsvColumns -Path $OwnerDecisionPath -RequiredColumns @('ReviewPacketId') -Description 'Owner review decision CSV' | ForEach-Object {
            $_ | Add-Member -NotePropertyName SourceDecisionPath -NotePropertyValue $OwnerDecisionPath -Force
            $_
        })
    }

    $migrationInputs = @()
    if (Test-Path -LiteralPath $outputMigrationDecisionPath -PathType Leaf) {
        $migrationInputs += @(Test-ShareSurferReviewDecisionCsvColumns -Path $outputMigrationDecisionPath -RequiredColumns @('RelatedAreaId') -Description 'Existing migration cluster decision CSV')
    }
    if (-not [string]::IsNullOrWhiteSpace($MigrationDecisionPath)) {
        if (-not (Test-Path -LiteralPath $MigrationDecisionPath -PathType Leaf)) {
            throw "Migration cluster decision CSV was not found: $MigrationDecisionPath"
        }
        $migrationInputs += @(Test-ShareSurferReviewDecisionCsvColumns -Path $MigrationDecisionPath -RequiredColumns @('RelatedAreaId') -Description 'Migration cluster decision CSV' | ForEach-Object {
            $_ | Add-Member -NotePropertyName SourceDecisionPath -NotePropertyValue $MigrationDecisionPath -Force
            $_
        })
    }

    $ownerInputByKey = @{}
    foreach ($row in $ownerInputs) {
        $key = [string]$row.ReviewPacketId
        if (-not [string]::IsNullOrWhiteSpace($key)) {
            $existingSource = if ($ownerInputByKey.ContainsKey($key)) { $ownerInputByKey[$key] } else { $null }
            $ownerInputByKey[$key] = Select-ShareSurferReviewDecisionSource -Existing $existingSource -Incoming $row -Key $key
        }
    }

    $ownerRows = New-Object System.Collections.ArrayList
    $ownerPackets = @(Read-ShareSurferCsv -Path (Join-Path $ExportPath 'owner_review_packets.csv'))
    $seenOwnerKeys = @{}
    foreach ($packet in $ownerPackets) {
        $key = [string]$packet.ReviewPacketId
        $source = if ($ownerInputByKey.ContainsKey($key)) { $ownerInputByKey[$key] } else { $null }
        $sourcePath = if ($null -ne $source -and $null -ne $source.PSObject.Properties['SourceDecisionPath']) { [string]$source.SourceDecisionPath } else { '' }
        [void]$ownerRows.Add((New-ShareSurferOwnerReviewDecisionRow -Packet $packet -DecisionSource $source -SourceDecisionPath $sourcePath))
        if (-not [string]::IsNullOrWhiteSpace($key)) {
            $seenOwnerKeys[$key] = $true
        }
    }
    foreach ($row in $ownerInputs) {
        $key = [string]$row.ReviewPacketId
        if ([string]::IsNullOrWhiteSpace($key) -or -not $seenOwnerKeys.ContainsKey($key)) {
            $sourcePath = if ($null -ne $row.PSObject.Properties['SourceDecisionPath']) { [string]$row.SourceDecisionPath } else { '' }
            [void]$ownerRows.Add((New-ShareSurferOwnerReviewDecisionRow -DecisionSource $row -SourceDecisionPath $sourcePath -ExtraWarning 'No matching current owner review packet was found in ExportPath.'))
        }
    }

    $migrationInputByKey = @{}
    foreach ($row in $migrationInputs) {
        $key = [string]$row.RelatedAreaId
        if (-not [string]::IsNullOrWhiteSpace($key)) {
            $existingSource = if ($migrationInputByKey.ContainsKey($key)) { $migrationInputByKey[$key] } else { $null }
            $migrationInputByKey[$key] = Select-ShareSurferReviewDecisionSource -Existing $existingSource -Incoming $row -Key $key
        }
    }

    $migrationRows = New-Object System.Collections.ArrayList
    $areas = @(Read-ShareSurferCsv -Path (Join-Path $ExportPath 'related_data_areas.csv'))
    $seenMigrationKeys = @{}
    foreach ($area in $areas) {
        $key = [string]$area.RelatedAreaId
        $source = if ($migrationInputByKey.ContainsKey($key)) { $migrationInputByKey[$key] } else { $null }
        $sourcePath = if ($null -ne $source -and $null -ne $source.PSObject.Properties['SourceDecisionPath']) { [string]$source.SourceDecisionPath } else { '' }
        [void]$migrationRows.Add((New-ShareSurferMigrationClusterDecisionRow -Area $area -DecisionSource $source -SourceDecisionPath $sourcePath))
        if (-not [string]::IsNullOrWhiteSpace($key)) {
            $seenMigrationKeys[$key] = $true
        }
    }
    foreach ($row in $migrationInputs) {
        $key = [string]$row.RelatedAreaId
        if ([string]::IsNullOrWhiteSpace($key) -or -not $seenMigrationKeys.ContainsKey($key)) {
            $sourcePath = if ($null -ne $row.PSObject.Properties['SourceDecisionPath']) { [string]$row.SourceDecisionPath } else { '' }
            [void]$migrationRows.Add((New-ShareSurferMigrationClusterDecisionRow -DecisionSource $row -SourceDecisionPath $sourcePath -ExtraWarning 'No matching current migration cluster was found in ExportPath.'))
        }
    }

    Export-ShareSurferCsv -Path $outputOwnerDecisionPath -Columns $schema['owner_review_decisions.csv'] -Rows $ownerRows
    Export-ShareSurferCsv -Path $outputMigrationDecisionPath -Columns $schema['migration_cluster_decisions.csv'] -Rows $migrationRows

    $allRows = @($ownerRows) + @($migrationRows)
    $invalidRows = @($allRows | Where-Object { [string]$_.DecisionStatus -eq 'NeedsCorrection' })
    $reviewedRows = @($allRows | Where-Object { [string]$_.DecisionStatus -eq 'Reviewed' })
    $pendingRows = @($allRows | Where-Object { [string]$_.DecisionStatus -eq 'Pending' })
    $reusableCommands = New-ShareSurferReviewDecisionReusableCommands -ExportPath $ExportPath -OutputPath $OutputPath -OwnerDecisionPath $outputOwnerDecisionPath -MigrationDecisionPath $outputMigrationDecisionPath -ImportOutputPath $OutputPath
    $writtenReusableCommandPath = Write-ShareSurferReusableCommandFile -Path $ReusableCommandPath -CommandText $reusableCommands

    [pscustomobject]@{
        ExportPath = $ExportPath
        OutputPath = $OutputPath
        OwnerDecisionPath = $outputOwnerDecisionPath
        MigrationDecisionPath = $outputMigrationDecisionPath
        OwnerDecisionCount = @($ownerRows).Count
        MigrationDecisionCount = @($migrationRows).Count
        OwnerReviewDecisionCount = @($ownerRows).Count
        MigrationClusterDecisionCount = @($migrationRows).Count
        ReviewedDecisionCount = @($reviewedRows).Count
        PendingDecisionCount = @($pendingRows).Count
        InvalidDecisionCount = @($invalidRows).Count
        IsValid = (@($invalidRows).Count -eq 0)
        AllowedDecisions = Get-ShareSurferReviewDecisionAllowedText
        ReusableCommandPath = $writtenReusableCommandPath
        ReusableCommands = $reusableCommands
    }
}
