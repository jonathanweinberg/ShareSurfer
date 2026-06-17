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
        $ownerInputs += @(Read-ShareSurferCsv -Path $outputOwnerDecisionPath)
    }
    if (-not [string]::IsNullOrWhiteSpace($OwnerDecisionPath)) {
        if (-not (Test-Path -LiteralPath $OwnerDecisionPath -PathType Leaf)) {
            throw "Owner review decision CSV was not found: $OwnerDecisionPath"
        }
        $ownerInputs += @(Read-ShareSurferCsv -Path $OwnerDecisionPath | ForEach-Object {
            $_ | Add-Member -NotePropertyName SourceDecisionPath -NotePropertyValue $OwnerDecisionPath -Force
            $_
        })
    }

    $migrationInputs = @()
    if (Test-Path -LiteralPath $outputMigrationDecisionPath -PathType Leaf) {
        $migrationInputs += @(Read-ShareSurferCsv -Path $outputMigrationDecisionPath)
    }
    if (-not [string]::IsNullOrWhiteSpace($MigrationDecisionPath)) {
        if (-not (Test-Path -LiteralPath $MigrationDecisionPath -PathType Leaf)) {
            throw "Migration cluster decision CSV was not found: $MigrationDecisionPath"
        }
        $migrationInputs += @(Read-ShareSurferCsv -Path $MigrationDecisionPath | ForEach-Object {
            $_ | Add-Member -NotePropertyName SourceDecisionPath -NotePropertyValue $MigrationDecisionPath -Force
            $_
        })
    }

    $ownerInputByKey = @{}
    foreach ($row in $ownerInputs) {
        $key = [string]$row.ReviewPacketId
        if (-not [string]::IsNullOrWhiteSpace($key)) {
            $ownerInputByKey[$key] = $row
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
            $migrationInputByKey[$key] = $row
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
