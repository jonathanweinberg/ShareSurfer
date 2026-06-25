function New-ShareSurferReviewDecisionDraft {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $ExportPath,

        [string] $OutputPath = '',

        [ValidateSet('All', 'OwnerReview', 'MigrationCluster')]
        [string] $DecisionScope = 'All',

        [string] $ReusableCommandPath = '',

        [switch] $NoCreateMissingFolders,

        [switch] $Force
    )

    if (-not (Test-Path -LiteralPath $ExportPath -PathType Container)) {
        throw "ShareSurfer export path was not found: $ExportPath"
    }

    if ([string]::IsNullOrWhiteSpace($OutputPath)) {
        $OutputPath = $ExportPath
    }

    Ensure-ShareSurferLocalDirectory -Path $OutputPath -Purpose 'review decision output' -NoCreateMissingFolders:$NoCreateMissingFolders | Out-Null

    $schema = Get-ShareSurferExportSchema
    $ownerDecisionPath = Join-Path $OutputPath 'owner_review_decisions.csv'
    $migrationDecisionPath = Join-Path $OutputPath 'migration_cluster_decisions.csv'
    $pathsToWrite = @()
    if ($DecisionScope -in @('All', 'OwnerReview')) {
        $pathsToWrite += $ownerDecisionPath
    }
    if ($DecisionScope -in @('All', 'MigrationCluster')) {
        $pathsToWrite += $migrationDecisionPath
    }
    foreach ($path in $pathsToWrite) {
        if ((Test-Path -LiteralPath $path) -and -not $Force) {
            throw "Review decision draft already exists: $path. Use -Force to overwrite it."
        }
    }

    $ownerRows = @()
    if ($DecisionScope -in @('All', 'OwnerReview')) {
        $packets = @(Read-ShareSurferCsv -Path (Join-Path $ExportPath 'owner_review_packets.csv'))
        $ownerRows = @($packets | ForEach-Object {
            New-ShareSurferOwnerReviewDecisionRow -Packet $_
        })
        Export-ShareSurferCsv -Path $ownerDecisionPath -Columns $schema['owner_review_decisions.csv'] -Rows $ownerRows
    }

    $migrationRows = @()
    if ($DecisionScope -in @('All', 'MigrationCluster')) {
        $areas = @(Read-ShareSurferCsv -Path (Join-Path $ExportPath 'related_data_areas.csv'))
        $migrationRows = @($areas | ForEach-Object {
            New-ShareSurferMigrationClusterDecisionRow -Area $_
        })
        Export-ShareSurferCsv -Path $migrationDecisionPath -Columns $schema['migration_cluster_decisions.csv'] -Rows $migrationRows
    }

    $reusableCommands = New-ShareSurferReviewDecisionReusableCommands -ExportPath $ExportPath -OutputPath $OutputPath -DecisionScope $DecisionScope
    $writtenReusableCommandPath = Write-ShareSurferReusableCommandFile -Path $ReusableCommandPath -CommandText $reusableCommands -NoCreateMissingFolders:$NoCreateMissingFolders

    [pscustomobject]@{
        ExportPath = $ExportPath
        OutputPath = $OutputPath
        DecisionScope = $DecisionScope
        OwnerDecisionPath = if ($DecisionScope -in @('All', 'OwnerReview')) { $ownerDecisionPath } else { '' }
        MigrationDecisionPath = if ($DecisionScope -in @('All', 'MigrationCluster')) { $migrationDecisionPath } else { '' }
        OwnerDecisionCount = @($ownerRows).Count
        MigrationDecisionCount = @($migrationRows).Count
        OwnerReviewDecisionCount = @($ownerRows).Count
        MigrationClusterDecisionCount = @($migrationRows).Count
        AllowedDecisions = Get-ShareSurferReviewDecisionAllowedText
        ReusableCommandPath = $writtenReusableCommandPath
        ReusableCommands = $reusableCommands
    }
}
