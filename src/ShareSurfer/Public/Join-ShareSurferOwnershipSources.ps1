function Join-ShareSurferOwnershipSources {
    [CmdletBinding()]
    param(
        [string[]] $Path = @(),

        [string] $SourceFolder = '',

        [switch] $BrowseForCsv,

        [Parameter(Mandatory = $true)]
        [string] $OutputPath,

        [switch] $IncludeContextGraph,

        [string] $ContextOutputPath = '',

        [string] $RelationshipOutputPath = '',

        [string] $ManifestOutputPath = '',

        [string] $DefinitionPath = '',

        [string[]] $MappingProfilePath = @(),

        [ValidateSet('Identity', 'ObsContext', 'ProjectContext', 'PathOwnership', 'GroupContext', 'Mixed')]
        [string[]] $SourceType = @(),

        [ValidateSet('Authoritative', 'ReviewerHint', 'ContextOnly', 'Unknown')]
        [string[]] $AuthorityLevel = @(),

        [string] $ObsHeader = '',

        [string] $ObsAttribute = 'extensionAttribute10',

        [ValidateSet('Auto', 'ActiveDirectory', 'Ldap', 'DirectoryOnly')]
        [string] $AdLookupMode = 'Auto',

        [string[]] $ForbiddenOu = @(),

        [switch] $Interactive,

        [string] $ReusableCommandPath = '',

        [ValidateRange(0, 2147483647)]
        [int] $ProgressRowInterval = 250,

        [ValidateRange(0, 2147483647)]
        [int] $ProgressIntervalSeconds = 10,

        [switch] $Quiet,

        [switch] $Force
    )

    if ((Test-Path -LiteralPath $OutputPath) -and -not $Force) {
        throw "Ownership enrichment output already exists: $OutputPath. Use -Force to overwrite it."
    }

    if ($BrowseForCsv -and -not $Interactive) {
        throw 'BrowseForCsv requires -Interactive because it uses a text-mode picker.'
    }

    $definition = $null
    $savedSourceProfiles = @()
    if (-not [string]::IsNullOrWhiteSpace($DefinitionPath) -and (Test-Path -LiteralPath $DefinitionPath -PathType Leaf)) {
        $definition = Get-ShareSurferOwnershipImportDefinition -Path $DefinitionPath
        if ([string]::IsNullOrWhiteSpace($SourceFolder) -and -not [string]::IsNullOrWhiteSpace([string]$definition.SourceFolder)) {
            $SourceFolder = [string]$definition.SourceFolder
        }
        if ($Path.Count -eq 0 -and -not $BrowseForCsv) {
            $Path = @($definition.SelectedCsvPaths)
        }
        if ($MappingProfilePath.Count -eq 0) {
            $MappingProfilePath = @($definition.MappingProfilePaths)
        }
        if (-not $PSBoundParameters.ContainsKey('ObsHeader') -and -not [string]::IsNullOrWhiteSpace([string]$definition.ObsHeader)) {
            $ObsHeader = [string]$definition.ObsHeader
        }
        if (-not $PSBoundParameters.ContainsKey('ObsAttribute') -and -not [string]::IsNullOrWhiteSpace([string]$definition.ObsAttribute)) {
            $ObsAttribute = [string]$definition.ObsAttribute
        }
        if (-not $PSBoundParameters.ContainsKey('AdLookupMode') -and -not [string]::IsNullOrWhiteSpace([string]$definition.AdLookupMode)) {
            $AdLookupMode = [string]$definition.AdLookupMode
        }
        if (-not $PSBoundParameters.ContainsKey('ForbiddenOu') -and $ForbiddenOu.Count -eq 0) {
            $ForbiddenOu = @($definition.ForbiddenOus)
        }
        if (-not $PSBoundParameters.ContainsKey('IncludeContextGraph') -and [bool]$definition.IncludeContextGraph) {
            $IncludeContextGraph = $true
        }
        if ([string]::IsNullOrWhiteSpace($ContextOutputPath) -and -not [string]::IsNullOrWhiteSpace([string]$definition.ContextOutputPath)) {
            $ContextOutputPath = [string]$definition.ContextOutputPath
        }
        if ([string]::IsNullOrWhiteSpace($RelationshipOutputPath) -and -not [string]::IsNullOrWhiteSpace([string]$definition.RelationshipOutputPath)) {
            $RelationshipOutputPath = [string]$definition.RelationshipOutputPath
        }
        if ([string]::IsNullOrWhiteSpace($ManifestOutputPath) -and -not [string]::IsNullOrWhiteSpace([string]$definition.ManifestOutputPath)) {
            $ManifestOutputPath = [string]$definition.ManifestOutputPath
        }
        $savedSourceProfiles = @($definition.SourceProfiles)
    }

    $selectedPaths = @(Resolve-ShareSurferOwnershipSourcePaths -Path $Path -SourceFolder $SourceFolder -Interactive:$Interactive -BrowseForCsv:$BrowseForCsv)
    if ($selectedPaths.Count -eq 0) {
        throw 'No ownership source CSV files were selected.'
    }

    $progressClock = [System.Diagnostics.Stopwatch]::StartNew()
    $lastProgressSecond = -1 * [Math]::Max(1, $ProgressIntervalSeconds)
    Write-ShareSurferOwnershipImportStatus -Message ('Selected {0} ownership source CSV file(s). AD lookup mode: {1}. Context graph: {2}.' -f $selectedPaths.Count, $AdLookupMode, $(if ($IncludeContextGraph) { 'enabled' } else { 'disabled' })) -Quiet:$Quiet

    $selectedForbiddenOus = @($ForbiddenOu | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($Interactive) {
        $selectedForbiddenOus = @(Select-ShareSurferForbiddenOus -ExistingForbiddenOu $selectedForbiddenOus -AdLookupMode $AdLookupMode)
    }
    if ($selectedForbiddenOus.Count -gt 0) {
        Write-ShareSurferOwnershipImportStatus -Message ('Using {0} forbidden OU filter(s) for AD enrichment.' -f $selectedForbiddenOus.Count) -Quiet:$Quiet
    }

    if ($IncludeContextGraph) {
        $outputParent = Split-Path -Parent $OutputPath
        if ([string]::IsNullOrWhiteSpace($outputParent)) {
            $outputParent = (Get-Location).Path
        }
        if ([string]::IsNullOrWhiteSpace($ContextOutputPath)) {
            $ContextOutputPath = Join-Path $outputParent 'ownership_context.csv'
        }
        if ([string]::IsNullOrWhiteSpace($RelationshipOutputPath)) {
            $RelationshipOutputPath = Join-Path $outputParent 'ownership_relationships.csv'
        }
        if ([string]::IsNullOrWhiteSpace($ManifestOutputPath)) {
            $ManifestOutputPath = Join-Path $outputParent 'ownership_import_manifest.csv'
        }
    }

    $writtenDefinitionPath = ''
    $mergedRows = [ordered]@{}
    $mergedKeysByObsKey = @{}
    $obsContextRows = @{}
    $contextRows = New-Object System.Collections.ArrayList
    $relationshipRows = New-Object System.Collections.ArrayList
    $manifestRows = New-Object System.Collections.ArrayList
    $sourceProfilesForDefinition = New-Object System.Collections.ArrayList
    $savedSourceProfileMap = ConvertTo-ShareSurferOwnershipSourceProfileMap -SourceProfiles $savedSourceProfiles
    $contextIndex = 0
    $relationshipIndex = 0
    $sourceIndex = 0
    $sourceWarnings = New-Object System.Collections.Generic.List[string]
    foreach ($sourcePath in $selectedPaths) {
        $sourceIndex++
        Write-ShareSurferOwnershipImportStatus -Message ('Reading source {0}/{1}: {2}' -f $sourceIndex, $selectedPaths.Count, $sourcePath) -Quiet:$Quiet
        $profilePath = ''
        if ($MappingProfilePath.Count -ge $sourceIndex) {
            $profilePath = [string]$MappingProfilePath[$sourceIndex - 1]
        }

        $headers = @(Get-ShareSurferCsvHeaders -Path $sourcePath)
        Write-ShareSurferOwnershipImportStatus -Message ('Source {0}/{1}: found {2} CSV header(s).' -f $sourceIndex, $selectedPaths.Count, $headers.Count) -Quiet:$Quiet
        $fieldMapOverride = @{}
        if (-not [string]::IsNullOrWhiteSpace($profilePath)) {
            if (-not (Test-Path -LiteralPath $profilePath)) {
                throw "Ownership mapping profile was not found: $profilePath"
            }
            $profile = Get-Content -LiteralPath $profilePath -Raw | ConvertFrom-Json
            if ($profile.PSObject.Properties['FieldMap']) {
                $fieldMapOverride = ConvertTo-ShareSurferOwnershipFieldMapHashtable -FieldMap $profile.FieldMap
            }
        }

        $resolved = Resolve-ShareSurferOwnershipHeaderMap -Headers $headers -ObsHeader $ObsHeader -FieldMap $fieldMapOverride
        $fieldMap = $resolved.FieldMap
        $headerWarnings = @($resolved.Warnings)
        if ($Interactive) {
            $interview = Read-ShareSurferOwnershipHeaderSelections -Headers $headers -InitialFieldMap $fieldMap -SourcePath $sourcePath -ObsHeader $ObsHeader
            if ([bool]$interview.Cancelled) {
                throw 'Ownership header interview cancelled by operator.'
            }
            $fieldMap = $interview.FieldMap
            $headerWarnings = @($interview.Warnings)
        }

        $savedSourceProfile = Get-ShareSurferOwnershipSavedSourceProfile -ProfileMap $savedSourceProfileMap -SourcePath $sourcePath
        $sourceTypeOverride = ''
        $authorityLevelOverride = ''
        if ($SourceType.Count -ge $sourceIndex) {
            $sourceTypeOverride = [string]$SourceType[$sourceIndex - 1]
        }
        elseif ($null -ne $savedSourceProfile -and $null -ne $savedSourceProfile.PSObject.Properties['SourceType']) {
            $sourceTypeOverride = [string]$savedSourceProfile.SourceType
        }
        if ($AuthorityLevel.Count -ge $sourceIndex) {
            $authorityLevelOverride = [string]$AuthorityLevel[$sourceIndex - 1]
        }
        elseif ($null -ne $savedSourceProfile -and $null -ne $savedSourceProfile.PSObject.Properties['AuthorityLevel']) {
            $authorityLevelOverride = [string]$savedSourceProfile.AuthorityLevel
        }

        $sourceProfile = New-ShareSurferOwnershipSourceProfile -SourcePath $sourcePath -FieldMap $fieldMap -SourceType $sourceTypeOverride -AuthorityLevel $authorityLevelOverride -Warnings @($headerWarnings)
        if ($Interactive -and $null -eq $savedSourceProfile) {
            $interactiveProfile = Read-ShareSurferOwnershipSourceProfile -SourcePath $sourcePath -FieldMap $fieldMap -InitialProfile $sourceProfile
            if ($null -ne $interactiveProfile.PSObject.Properties['Cancelled'] -and [bool]$interactiveProfile.Cancelled) {
                throw 'Ownership source classification cancelled by operator.'
            }
            $sourceProfile = $interactiveProfile
        }
        [void]$sourceProfilesForDefinition.Add($sourceProfile)

        foreach ($warning in @($headerWarnings)) {
            if (-not [string]::IsNullOrWhiteSpace([string]$warning)) {
                $sourceWarnings.Add(('{0}: {1}' -f $sourcePath, [string]$warning))
            }
        }

        $sourceRows = @(Import-Csv -LiteralPath $sourcePath)
        Write-ShareSurferOwnershipImportStatus -Message ('Source {0}/{1}: processing {2} row(s).' -f $sourceIndex, $selectedPaths.Count, $sourceRows.Count) -Quiet:$Quiet
        $sourceContextCount = 0
        $sourceRelationshipCount = 0
        $sourceStrongKeyCount = 0
        $sourceWeakObsOnlyCount = 0
        $rowNumber = 1
        $sourceProcessed = 0
        foreach ($sourceRow in $sourceRows) {
            $rowNumber++
            $sourceProcessed++
            $incoming = New-ShareSurferOwnershipEnrichmentRow -SourceRow $sourceRow -FieldMap $fieldMap -SourcePath $sourcePath -SourceRowNumber $rowNumber -ObsAttribute $ObsAttribute
            if ($IncludeContextGraph) {
                foreach ($contextRow in @(New-ShareSurferOwnershipContextRows -SourceRow $sourceRow -FieldMap $fieldMap -SourceProfile $sourceProfile -SourcePath $sourcePath -SourceRowNumber $rowNumber)) {
                    $contextIndex++
                    $contextRow.ContextId = 'context-{0:d6}' -f $contextIndex
                    [void]$contextRows.Add($contextRow)
                    $sourceContextCount++
                }
                foreach ($relationshipRow in @(New-ShareSurferOwnershipRelationshipRows -SourceRow $sourceRow -FieldMap $fieldMap -SourceProfile $sourceProfile -SourcePath $sourcePath -SourceRowNumber $rowNumber)) {
                    $relationshipIndex++
                    $relationshipRow.RelationshipId = 'relationship-{0:d6}' -f $relationshipIndex
                    [void]$relationshipRows.Add($relationshipRow)
                    $sourceRelationshipCount++
                }
            }

            $obsKey = Get-ShareSurferOwnershipObsMergeKey -Row $incoming
            $hasStrongJoinKey = Test-ShareSurferOwnershipStrongJoinKey -Row $incoming
            if ($hasStrongJoinKey) {
                $sourceStrongKeyCount++
            }
            elseif (-not [string]::IsNullOrWhiteSpace($obsKey)) {
                $sourceWeakObsOnlyCount++
            }

            if (-not $hasStrongJoinKey -and -not [string]::IsNullOrWhiteSpace($obsKey)) {
                if ($obsContextRows.ContainsKey($obsKey)) {
                    $obsContextRows[$obsKey] = Merge-ShareSurferOwnershipEnrichmentRow -Existing $obsContextRows[$obsKey] -Incoming $incoming
                }
                else {
                    $obsContextRows[$obsKey] = $incoming
                }

                $elapsedSeconds = [int][Math]::Floor($progressClock.Elapsed.TotalSeconds)
                $rowIntervalDue = ($ProgressRowInterval -gt 0 -and (($sourceProcessed % $ProgressRowInterval) -eq 0))
                $timeIntervalDue = ($ProgressIntervalSeconds -gt 0 -and (($elapsedSeconds - $lastProgressSecond) -ge $ProgressIntervalSeconds))
                if ($rowIntervalDue -or $timeIntervalDue -or $sourceProcessed -eq $sourceRows.Count) {
                    $lastProgressSecond = $elapsedSeconds
                    Write-ShareSurferOwnershipImportProgress -Activity 'ShareSurfer ownership import' -Status ('Source {0}/{1}: {2}/{3} rows' -f $sourceIndex, $selectedPaths.Count, $sourceProcessed, $sourceRows.Count) -CurrentOperation ('Merged rows: {0}; OBS-only context rows: {1}; context rows: {2}; relationship rows: {3}' -f $mergedRows.Count, $obsContextRows.Count, $contextRows.Count, $relationshipRows.Count) -Processed $sourceProcessed -Total $sourceRows.Count -Quiet:$Quiet
                    Write-ShareSurferOwnershipImportStatus -Message ('Source {0}/{1}: processed {2}/{3} row(s); merged rows {4}; OBS-only context rows {5}; context rows {6}; relationship rows {7}; elapsed {8}.' -f $sourceIndex, $selectedPaths.Count, $sourceProcessed, $sourceRows.Count, $mergedRows.Count, $obsContextRows.Count, $contextRows.Count, $relationshipRows.Count, (Get-ShareSurferOwnershipElapsedText -Stopwatch $progressClock)) -Quiet:$Quiet
                }
                continue
            }

            $key = Get-ShareSurferOwnershipMergeKey -Row $incoming
            if ($mergedRows.Contains($key)) {
                $mergedRows[$key] = Merge-ShareSurferOwnershipEnrichmentRow -Existing $mergedRows[$key] -Incoming $incoming
            }
            else {
                $mergedRows[$key] = $incoming
            }

            $indexedObsKey = Get-ShareSurferOwnershipObsMergeKey -Row $mergedRows[$key]
            Add-ShareSurferOwnershipObsMergeIndex -Index $mergedKeysByObsKey -ObsKey $indexedObsKey -MergeKey $key

            $elapsedSeconds = [int][Math]::Floor($progressClock.Elapsed.TotalSeconds)
            $rowIntervalDue = ($ProgressRowInterval -gt 0 -and (($sourceProcessed % $ProgressRowInterval) -eq 0))
            $timeIntervalDue = ($ProgressIntervalSeconds -gt 0 -and (($elapsedSeconds - $lastProgressSecond) -ge $ProgressIntervalSeconds))
            if ($rowIntervalDue -or $timeIntervalDue -or $sourceProcessed -eq $sourceRows.Count) {
                $lastProgressSecond = $elapsedSeconds
                Write-ShareSurferOwnershipImportProgress -Activity 'ShareSurfer ownership import' -Status ('Source {0}/{1}: {2}/{3} rows' -f $sourceIndex, $selectedPaths.Count, $sourceProcessed, $sourceRows.Count) -CurrentOperation ('Merged rows: {0}; context rows: {1}; relationship rows: {2}' -f $mergedRows.Count, $contextRows.Count, $relationshipRows.Count) -Processed $sourceProcessed -Total $sourceRows.Count -Quiet:$Quiet
                Write-ShareSurferOwnershipImportStatus -Message ('Source {0}/{1}: processed {2}/{3} row(s); merged rows {4}; context rows {5}; relationship rows {6}; elapsed {7}.' -f $sourceIndex, $selectedPaths.Count, $sourceProcessed, $sourceRows.Count, $mergedRows.Count, $contextRows.Count, $relationshipRows.Count, (Get-ShareSurferOwnershipElapsedText -Stopwatch $progressClock)) -Quiet:$Quiet
            }
        }

        Write-ShareSurferOwnershipImportStatus -Message ('Source {0}/{1} complete: {2} row(s), {3} strong-key row(s), {4} OBS-only context row(s), {5} context row(s), {6} relationship row(s).' -f $sourceIndex, $selectedPaths.Count, $sourceRows.Count, $sourceStrongKeyCount, $sourceWeakObsOnlyCount, $sourceContextCount, $sourceRelationshipCount) -Quiet:$Quiet
        if ($sourceRows.Count -gt 0 -and $sourceStrongKeyCount -eq 0 -and $sourceWeakObsOnlyCount -gt 0) {
            $weakWarning = 'Source has OBS-only rows but no mapped employee/account join keys. That can be valid for context files, but if this file should describe people, rerun the header interview or mapping profile and explicitly map EmployeeId, EmployeeNumber, SamAccountName, UserPrincipalName, or Mail.'
            $sourceWarnings.Add(('{0}: {1}' -f $sourcePath, $weakWarning))
            Write-ShareSurferOwnershipImportStatus -Message ('Review source {0}/{1}: {2}' -f $sourceIndex, $selectedPaths.Count, $weakWarning) -Quiet:$Quiet
        }
        elseif ($sourceRows.Count -gt 0 -and $sourceStrongKeyCount -eq 0 -and $sourceWeakObsOnlyCount -eq 0) {
            $noKeyWarning = 'Source has rows, but no rows mapped to an employee/account join key or OBS key. Rerun the header interview or mapping profile before relying on this file.'
            $sourceWarnings.Add(('{0}: {1}' -f $sourcePath, $noKeyWarning))
            Write-ShareSurferOwnershipImportStatus -Message ('Review source {0}/{1}: {2}' -f $sourceIndex, $selectedPaths.Count, $noKeyWarning) -Quiet:$Quiet
        }
        if ($IncludeContextGraph) {
            [void]$manifestRows.Add([pscustomobject]@{
                SourcePath = $sourcePath
                SourceType = [string]$sourceProfile.SourceType
                AuthorityLevel = [string]$sourceProfile.AuthorityLevel
                PrimaryAnchor = [string]$sourceProfile.PrimaryAnchor
                MappedFields = [string]$sourceProfile.MappedFields
                RowCount = [string]$sourceRows.Count
                ContextRowCount = [string]$sourceContextCount
                RelationshipRowCount = [string]$sourceRelationshipCount
                Warnings = [string]$sourceProfile.Warnings
            })
        }
    }

    Write-ShareSurferOwnershipImportProgress -Activity 'ShareSurfer ownership import' -Completed -Quiet:$Quiet
    Write-ShareSurferOwnershipImportStatus -Message ('CSV merge complete: {0} merged ownership row(s), {1} OBS-only context row(s).' -f $mergedRows.Count, $obsContextRows.Count) -Quiet:$Quiet

    $obsContextProcessed = 0
    $obsContextStrongRowMergeCount = 0
    $obsContextOrphanRowCount = 0
    foreach ($obsKey in @($obsContextRows.Keys)) {
        $obsContextProcessed++
        $hasMatchingStrongRow = ($mergedKeysByObsKey.ContainsKey($obsKey) -and @($mergedKeysByObsKey[$obsKey].Keys).Count -gt 0)

        if ($hasMatchingStrongRow) {
            $contextForStrongRow = Copy-ShareSurferOwnershipContextForStrongRow -ContextRow $obsContextRows[$obsKey]
            foreach ($existingKey in @($mergedKeysByObsKey[$obsKey].Keys)) {
                $mergedRows[$existingKey] = Merge-ShareSurferOwnershipEnrichmentRow -Existing $mergedRows[$existingKey] -Incoming $contextForStrongRow
                $obsContextStrongRowMergeCount++
            }
        }
        else {
            Complete-ShareSurferDelimitedProperties -Row $obsContextRows[$obsKey] | Out-Null
            $mergedRows[$obsKey] = $obsContextRows[$obsKey]
            Add-ShareSurferOwnershipObsMergeIndex -Index $mergedKeysByObsKey -ObsKey $obsKey -MergeKey $obsKey
            $obsContextOrphanRowCount++
        }

        $elapsedSeconds = [int][Math]::Floor($progressClock.Elapsed.TotalSeconds)
        $rowIntervalDue = ($ProgressRowInterval -gt 0 -and (($obsContextProcessed % $ProgressRowInterval) -eq 0))
        $timeIntervalDue = ($ProgressIntervalSeconds -gt 0 -and (($elapsedSeconds - $lastProgressSecond) -ge $ProgressIntervalSeconds))
        if ($rowIntervalDue -or $timeIntervalDue -or $obsContextProcessed -eq $obsContextRows.Count) {
            $lastProgressSecond = $elapsedSeconds
            Write-ShareSurferOwnershipImportProgress -Activity 'ShareSurfer ownership OBS context merge' -Status ('{0}/{1} OBS context row(s)' -f $obsContextProcessed, $obsContextRows.Count) -CurrentOperation ('Applied to strong rows: {0}; orphan OBS rows: {1}; merged rows: {2}' -f $obsContextStrongRowMergeCount, $obsContextOrphanRowCount, $mergedRows.Count) -Processed $obsContextProcessed -Total $obsContextRows.Count -Quiet:$Quiet
            Write-ShareSurferOwnershipImportStatus -Message ('OBS context merge: processed {0}/{1}; applied to {2} strong row(s); orphan OBS rows {3}; merged rows {4}; elapsed {5}.' -f $obsContextProcessed, $obsContextRows.Count, $obsContextStrongRowMergeCount, $obsContextOrphanRowCount, $mergedRows.Count, (Get-ShareSurferOwnershipElapsedText -Stopwatch $progressClock)) -Quiet:$Quiet
        }
    }
    Write-ShareSurferOwnershipImportProgress -Activity 'ShareSurfer ownership OBS context merge' -Completed -Quiet:$Quiet

    $enrichedRows = New-Object System.Collections.ArrayList
    $enrichmentTotal = @($mergedRows.Values).Count
    $enrichmentProcessed = 0
    $lookupAttemptCount = 0
    $lookupCacheHitCount = 0
    $lookupCache = @{}
    Write-ShareSurferOwnershipImportStatus -Message ('Starting directory enrichment for {0} row(s). AD lookup mode: {1}.' -f $enrichmentTotal, $AdLookupMode) -Quiet:$Quiet
    foreach ($row in @($mergedRows.Values)) {
        $enrichmentProcessed++
        if ($AdLookupMode -ne 'DirectoryOnly' -and (-not [string]::IsNullOrWhiteSpace([string]$row.EmployeeId) -or -not [string]::IsNullOrWhiteSpace([string]$row.EmployeeNumber))) {
            $lookupKey = New-ShareSurferOwnershipDirectoryLookupCacheKey -EmployeeId ([string]$row.EmployeeId) -EmployeeNumber ([string]$row.EmployeeNumber)
            if ($lookupCache.ContainsKey($lookupKey)) {
                $lookup = $lookupCache[$lookupKey]
                $lookupCacheHitCount++
            }
            else {
                $lookupAttemptCount++
                $lookup = Get-ShareSurferDirectoryIdentityByEmployee -EmployeeId ([string]$row.EmployeeId) -EmployeeNumber ([string]$row.EmployeeNumber) -ObsAttribute $ObsAttribute -AdLookupMode $AdLookupMode -ForbiddenOu $selectedForbiddenOus
                $lookupCache[$lookupKey] = $lookup
            }
            $row = Update-ShareSurferOwnershipRowFromDirectory -Row $row -LookupResult $lookup
        }
        elseif ($AdLookupMode -eq 'DirectoryOnly') {
            $row.MatchStatus = 'SourceOnly'
            $row.MatchMethod = ''
        }
        else {
            Add-ShareSurferDelimitedPropertyValue -Row $row -Column 'ImportWarnings' -Value 'NoEmployeeIdentifierForAdMatch'
        }

        $row.PotentialServiceAccount = [string]([string]::IsNullOrWhiteSpace([string]$row.OBS) -and [string]::IsNullOrWhiteSpace([string]$row.AdObsPath) -and [string]::IsNullOrWhiteSpace([string]$row.EmployeeId) -and [string]::IsNullOrWhiteSpace([string]$row.EmployeeNumber))
        Complete-ShareSurferDelimitedProperties -Row $row | Out-Null
        [void]$enrichedRows.Add($row)

        $elapsedSeconds = [int][Math]::Floor($progressClock.Elapsed.TotalSeconds)
        $rowIntervalDue = ($ProgressRowInterval -gt 0 -and (($enrichmentProcessed % $ProgressRowInterval) -eq 0))
        $timeIntervalDue = ($ProgressIntervalSeconds -gt 0 -and (($elapsedSeconds - $lastProgressSecond) -ge $ProgressIntervalSeconds))
        if ($rowIntervalDue -or $timeIntervalDue -or $enrichmentProcessed -eq $enrichmentTotal) {
            $lastProgressSecond = $elapsedSeconds
            Write-ShareSurferOwnershipImportProgress -Activity 'ShareSurfer ownership directory enrichment' -Status ('{0}/{1} rows enriched' -f $enrichmentProcessed, $enrichmentTotal) -CurrentOperation ('AD lookup attempts: {0}; cache hits: {1}; output rows: {2}' -f $lookupAttemptCount, $lookupCacheHitCount, $enrichedRows.Count) -Processed $enrichmentProcessed -Total $enrichmentTotal -Quiet:$Quiet
            Write-ShareSurferOwnershipImportStatus -Message ('Directory enrichment: processed {0}/{1} row(s); AD lookup attempts {2}; cache hits {3}; elapsed {4}.' -f $enrichmentProcessed, $enrichmentTotal, $lookupAttemptCount, $lookupCacheHitCount, (Get-ShareSurferOwnershipElapsedText -Stopwatch $progressClock)) -Quiet:$Quiet
        }
    }
    Write-ShareSurferOwnershipImportProgress -Activity 'ShareSurfer ownership directory enrichment' -Completed -Quiet:$Quiet

    $parent = Split-Path -Parent $OutputPath
    if (-not [string]::IsNullOrWhiteSpace($parent) -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    Write-ShareSurferOwnershipImportStatus -Message ('Writing ownership enrichment CSV: {0} ({1} row(s)).' -f $OutputPath, $enrichedRows.Count) -Quiet:$Quiet
    Export-ShareSurferCsv -Path $OutputPath -Columns (Get-ShareSurferOwnershipEnrichmentColumns) -Rows $enrichedRows
    if ($IncludeContextGraph) {
        Write-ShareSurferOwnershipImportStatus -Message ('Writing ownership context graph files: {0} context row(s), {1} relationship row(s), {2} manifest row(s).' -f $contextRows.Count, $relationshipRows.Count, $manifestRows.Count) -Quiet:$Quiet
        Export-ShareSurferCsv -Path $ContextOutputPath -Columns (Get-ShareSurferOwnershipContextColumns) -Rows $contextRows
        Export-ShareSurferCsv -Path $RelationshipOutputPath -Columns (Get-ShareSurferOwnershipRelationshipColumns) -Rows $relationshipRows
        Export-ShareSurferCsv -Path $ManifestOutputPath -Columns (Get-ShareSurferOwnershipImportManifestColumns) -Rows $manifestRows
    }

    if (-not [string]::IsNullOrWhiteSpace($DefinitionPath)) {
        Write-ShareSurferOwnershipImportStatus -Message ('Writing reusable ownership import definition: {0}' -f $DefinitionPath) -Quiet:$Quiet
        $writtenDefinitionPath = Export-ShareSurferOwnershipImportDefinition -Path $DefinitionPath -SelectedCsvPaths $selectedPaths -SourceFolder $SourceFolder -OutputPath $OutputPath -MappingProfilePaths $MappingProfilePath -ObsHeader $ObsHeader -ObsAttribute $ObsAttribute -AdLookupMode $AdLookupMode -ForbiddenOu $selectedForbiddenOus -IncludeContextGraph ([bool]$IncludeContextGraph) -ContextOutputPath $ContextOutputPath -RelationshipOutputPath $RelationshipOutputPath -ManifestOutputPath $ManifestOutputPath -SourceProfiles @($sourceProfilesForDefinition.ToArray()) -Force
    }

    $reusableCommands = New-ShareSurferOwnershipEnrichmentReusableCommands -SourcePaths $selectedPaths -OutputPath $OutputPath -MappingProfilePaths $MappingProfilePath -ObsHeader $ObsHeader -ObsAttribute $ObsAttribute -AdLookupMode $AdLookupMode -ForbiddenOu $selectedForbiddenOus -DefinitionPath $writtenDefinitionPath -IncludeContextGraph:$IncludeContextGraph -ContextOutputPath $ContextOutputPath -RelationshipOutputPath $RelationshipOutputPath -ManifestOutputPath $ManifestOutputPath
    $writtenReusableCommandPath = Write-ShareSurferReusableCommandFile -Path $ReusableCommandPath -CommandText $reusableCommands
    if (-not [string]::IsNullOrWhiteSpace($writtenReusableCommandPath)) {
        Write-ShareSurferOwnershipImportStatus -Message ('Writing reusable ownership import command: {0}' -f $writtenReusableCommandPath) -Quiet:$Quiet
    }

    $matchedCount = 0
    $ambiguousCount = 0
    $forbiddenOuSkippedCount = 0
    $sourceOnlyCount = 0
    $potentialServiceAccountCount = 0
    foreach ($row in @($enrichedRows)) {
        switch ([string]$row.MatchStatus) {
            'Matched' { $matchedCount++; break }
            'Ambiguous' { $ambiguousCount++; break }
            'ForbiddenOuSkipped' { $forbiddenOuSkippedCount++; break }
            'SourceOnly' { $sourceOnlyCount++; break }
        }
        if ([string]$row.PotentialServiceAccount -eq 'True') {
            $potentialServiceAccountCount++
        }
    }

    Write-ShareSurferOwnershipImportStatus -Message ('Ownership import complete: {0} row(s), {1} matched, {2} ambiguous, {3} forbidden-OU skipped, {4} source-only, {5} potential service-account-like row(s), {6} AD lookup attempt(s), {7} cache hit(s). Elapsed {8}.' -f $enrichedRows.Count, $matchedCount, $ambiguousCount, $forbiddenOuSkippedCount, $sourceOnlyCount, $potentialServiceAccountCount, $lookupAttemptCount, $lookupCacheHitCount, (Get-ShareSurferOwnershipElapsedText -Stopwatch $progressClock)) -Quiet:$Quiet

    [pscustomobject]@{
        OutputPath = $OutputPath
        ContextOutputPath = if ($IncludeContextGraph) { $ContextOutputPath } else { '' }
        RelationshipOutputPath = if ($IncludeContextGraph) { $RelationshipOutputPath } else { '' }
        ManifestOutputPath = if ($IncludeContextGraph) { $ManifestOutputPath } else { '' }
        DefinitionPath = $writtenDefinitionPath
        SourcePaths = (@($selectedPaths) -join '; ')
        SourceCount = $selectedPaths.Count
        RowCount = $enrichedRows.Count
        ContextRowCount = $contextRows.Count
        RelationshipRowCount = $relationshipRows.Count
        ManifestRowCount = $manifestRows.Count
        MatchedCount = $matchedCount
        AmbiguousCount = $ambiguousCount
        ForbiddenOuSkippedCount = $forbiddenOuSkippedCount
        SourceOnlyCount = $sourceOnlyCount
        PotentialServiceAccountCount = $potentialServiceAccountCount
        ForbiddenOu = (@($selectedForbiddenOus) -join '; ')
        ObsAttribute = $ObsAttribute
        ObsContextStrongRowMergeCount = $obsContextStrongRowMergeCount
        ObsContextOrphanRowCount = $obsContextOrphanRowCount
        AdLookupAttemptCount = $lookupAttemptCount
        DirectoryLookupCacheHitCount = $lookupCacheHitCount
        ElapsedSeconds = [Math]::Round($progressClock.Elapsed.TotalSeconds, 3)
        Warnings = @($sourceWarnings)
        ReusableCommandPath = $writtenReusableCommandPath
        ReusableCommands = $reusableCommands
    }
}

function Resolve-ShareSurferOwnershipSourcePaths {
    param(
        [string[]] $Path = @(),

        [string] $SourceFolder = '',

        [switch] $Interactive,

        [switch] $BrowseForCsv
    )

    $selected = New-Object System.Collections.Generic.List[string]
    foreach ($item in @($Path)) {
        if (-not [string]::IsNullOrWhiteSpace($item)) {
            if (-not (Test-Path -LiteralPath $item)) {
                throw "Ownership source CSV was not found: $item"
            }
            $selected.Add((Resolve-Path -LiteralPath $item).Path)
        }
    }

    if ($selected.Count -gt 0) {
        return @($selected)
    }

    if ([string]::IsNullOrWhiteSpace($SourceFolder) -and $Interactive) {
        $SourceFolder = Read-Host -Prompt 'Folder containing ownership CSV files'
    }

    if ([string]::IsNullOrWhiteSpace($SourceFolder)) {
        return @()
    }
    if (-not (Test-Path -LiteralPath $SourceFolder)) {
        throw "Ownership source folder was not found: $SourceFolder"
    }

    if ($BrowseForCsv) {
        return @(Read-ShareSurferCsvPickerSelection -StartFolder $SourceFolder)
    }

    $candidates = @(Get-ChildItem -LiteralPath $SourceFolder -Filter '*.csv' -File | Sort-Object Name)
    if ($candidates.Count -eq 0) {
        return @()
    }

    if (-not $Interactive) {
        return @($candidates | ForEach-Object { $_.FullName })
    }

    Write-Host ''
    Write-Host 'ShareSurfer found these importable CSV files:'
    for ($index = 0; $index -lt $candidates.Count; $index++) {
        Write-Host ('  [{0}] {1}' -f ($index + 1), $candidates[$index].Name)
    }
    Write-Host ''
    Write-Host 'Type numbers separated by commas, a range like 1-3, or A for all.'
    $answer = Read-Host -Prompt 'CSV files to import'
    $indexes = @(ConvertFrom-ShareSurferInteractiveSelection -Selection $answer -Maximum $candidates.Count)
    @($indexes | ForEach-Object { $candidates[$_ - 1].FullName })
}

function New-ShareSurferCsvPickerState {
    param(
        [string] $StartFolder = ''
    )

    $resolved = if ([string]::IsNullOrWhiteSpace($StartFolder)) {
        (Get-Location).Path
    }
    else {
        (Resolve-Path -LiteralPath $StartFolder).Path
    }

    [pscustomobject]@{
        CurrentFolder = $resolved
        SelectedCsvPaths = New-Object System.Collections.Generic.List[string]
        Done = $false
        Quit = $false
    }
}

function Get-ShareSurferCsvPickerView {
    param(
        [Parameter(Mandatory = $true)]
        $State
    )

    $directories = @(Get-ChildItem -LiteralPath $State.CurrentFolder -Directory | Sort-Object Name)
    $csvFiles = @(Get-ChildItem -LiteralPath $State.CurrentFolder -File -Filter '*.csv' | Sort-Object Name)
    $entries = New-Object System.Collections.ArrayList
    foreach ($directory in $directories) {
        [void]$entries.Add([pscustomobject]@{
            Kind = 'Directory'
            Name = [string]$directory.Name
            FullName = [string]$directory.FullName
            Selected = $false
        })
    }
    foreach ($file in $csvFiles) {
        $selected = @($State.SelectedCsvPaths | Where-Object { $_.ToLowerInvariant() -eq $file.FullName.ToLowerInvariant() }).Count -gt 0
        [void]$entries.Add([pscustomobject]@{
            Kind = 'Csv'
            Name = [string]$file.Name
            FullName = [string]$file.FullName
            Selected = $selected
        })
    }

    [pscustomobject]@{
        CurrentFolder = [string]$State.CurrentFolder
        Entries = @($entries)
    }
}

function Remove-ShareSurferCsvPickerSelectedPath {
    param(
        [Parameter(Mandatory = $true)]
        $State,

        [Parameter(Mandatory = $true)]
        [string] $Path
    )

    $remaining = @($State.SelectedCsvPaths | Where-Object { $_.ToLowerInvariant() -ne $Path.ToLowerInvariant() })
    $State.SelectedCsvPaths.Clear()
    foreach ($item in $remaining) {
        $State.SelectedCsvPaths.Add([string]$item)
    }
}

function Add-ShareSurferCsvPickerSelectedPath {
    param(
        [Parameter(Mandatory = $true)]
        $State,

        [Parameter(Mandatory = $true)]
        [string] $Path
    )

    if (-not (@($State.SelectedCsvPaths) | Where-Object { $_.ToLowerInvariant() -eq $Path.ToLowerInvariant() })) {
        $State.SelectedCsvPaths.Add($Path)
    }
}

function Invoke-ShareSurferCsvPickerCommand {
    param(
        [Parameter(Mandatory = $true)]
        $State,

        [string] $Command = ''
    )

    $text = $Command.Trim()
    if ([string]::IsNullOrWhiteSpace($text)) {
        return $State
    }

    $upper = $text.ToUpperInvariant()
    if ($upper -eq 'D') {
        $State.Done = $true
        return $State
    }
    if ($upper -eq 'Q') {
        $State.Quit = $true
        return $State
    }
    if ($upper -eq 'U') {
        $parent = Split-Path -Parent $State.CurrentFolder
        if (-not [string]::IsNullOrWhiteSpace($parent) -and (Test-Path -LiteralPath $parent -PathType Container)) {
            $State.CurrentFolder = (Resolve-Path -LiteralPath $parent).Path
        }
        return $State
    }
    if ($upper -eq 'C') {
        $State.SelectedCsvPaths.Clear()
        return $State
    }

    $view = Get-ShareSurferCsvPickerView -State $State
    if ($upper -eq 'A') {
        foreach ($entry in @($view.Entries | Where-Object { $_.Kind -eq 'Csv' })) {
            Add-ShareSurferCsvPickerSelectedPath -State $State -Path ([string]$entry.FullName)
        }
        return $State
    }
    if ($upper -eq 'P') {
        return $State
    }
    if ($text -match '^\d+$') {
        $index = [int]$text
        if ($index -lt 1 -or $index -gt @($view.Entries).Count) {
            return $State
        }

        $entry = @($view.Entries)[$index - 1]
        if ($entry.Kind -eq 'Directory') {
            $State.CurrentFolder = (Resolve-Path -LiteralPath ([string]$entry.FullName)).Path
        }
        elseif ($entry.Kind -eq 'Csv') {
            $path = [string]$entry.FullName
            $existing = @($State.SelectedCsvPaths | Where-Object { $_.ToLowerInvariant() -eq $path.ToLowerInvariant() })
            if ($existing.Count -gt 0) {
                Remove-ShareSurferCsvPickerSelectedPath -State $State -Path $path
            }
            else {
                Add-ShareSurferCsvPickerSelectedPath -State $State -Path $path
            }
        }
    }

    $State
}

function Get-ShareSurferCsvPickerScreen {
    param(
        [Parameter(Mandatory = $true)]
        $State
    )

    $view = Get-ShareSurferCsvPickerView -State $State
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('')
    $lines.Add(('Current folder: {0}' -f $view.CurrentFolder))
    $lines.Add('')
    if (@($view.Entries).Count -eq 0) {
        $lines.Add('  No subfolders or CSV files found here.')
    }
    else {
        for ($index = 0; $index -lt @($view.Entries).Count; $index++) {
            $entry = @($view.Entries)[$index]
            $marker = if ($entry.Kind -eq 'Directory') {
                '<DIR>'
            }
            elseif ($entry.Selected) {
                '[selected]'
            }
            else {
                '[ ]'
            }
            $lines.Add(('  [{0}] {1,-10} {2}' -f ($index + 1), $marker, $entry.Name))
        }
    }

    $lines.Add('')
    $lines.Add(('Selected CSVs: {0}' -f @($State.SelectedCsvPaths).Count))
    $lines.Add('Commands: number=open folder/toggle CSV, A=select all CSVs here, C=clear, U=up, P=show selected, D=done, Q=quit')

    @($lines.ToArray())
}

function Show-ShareSurferCsvPicker {
    param(
        [Parameter(Mandatory = $true)]
        $State
    )

    Write-ShareSurferConsoleLines -Lines (Get-ShareSurferCsvPickerScreen -State $State)
}

function Get-ShareSurferCsvPickerSelectedPathsScreen {
    param(
        [Parameter(Mandatory = $true)]
        $State
    )

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('')
    $lines.Add('Selected CSV files:')
    if (@($State.SelectedCsvPaths).Count -eq 0) {
        $lines.Add('  None yet.')
    }
    else {
        foreach ($path in @($State.SelectedCsvPaths)) {
            $lines.Add(('  {0}' -f $path))
        }
    }

    @($lines.ToArray())
}

function Show-ShareSurferCsvPickerSelectedPaths {
    param(
        [Parameter(Mandatory = $true)]
        $State
    )

    Write-ShareSurferConsoleLines -Lines (Get-ShareSurferCsvPickerSelectedPathsScreen -State $State)
}

function Read-ShareSurferCsvPickerSelection {
    param(
        [string] $StartFolder = ''
    )

    $state = New-ShareSurferCsvPickerState -StartFolder $StartFolder
    while (-not $state.Done -and -not $state.Quit) {
        Show-ShareSurferCsvPicker -State $state
        $answer = Read-Host -Prompt 'CSV picker command'
        if ($answer.Trim().ToUpperInvariant() -eq 'P') {
            Show-ShareSurferCsvPickerSelectedPaths -State $state
        }
        Invoke-ShareSurferCsvPickerCommand -State $state -Command $answer | Out-Null
    }

    if ($state.Quit) {
        return @()
    }

    @($state.SelectedCsvPaths)
}

function Select-ShareSurferForbiddenOus {
    param(
        [string[]] $ExistingForbiddenOu = @(),

        [ValidateSet('Auto', 'ActiveDirectory', 'Ldap', 'DirectoryOnly')]
        [string] $AdLookupMode = 'Auto'
    )

    $selected = New-Object System.Collections.Generic.List[string]
    foreach ($ou in @($ExistingForbiddenOu)) {
        if (-not [string]::IsNullOrWhiteSpace($ou)) {
            $selected.Add([string]$ou)
        }
    }

    if ($AdLookupMode -eq 'DirectoryOnly') {
        return @($selected)
    }

    $ous = @(Get-ShareSurferDirectoryOrganizationalUnits -AdLookupMode $AdLookupMode)
    if ($ous.Count -eq 0) {
        if ($selected.Count -gt 0) {
            return @($selected)
        }

        Write-Host 'ShareSurfer could not list OUs from AD/LDAP. You can still rerun with -ForbiddenOu later.'
        return @()
    }

    $ouOptions = @($ous | ForEach-Object {
        $display = if (-not [string]::IsNullOrWhiteSpace([string]$_.CanonicalName)) { [string]$_.CanonicalName } else { [string]$_.DistinguishedName }
        New-ShareSurferConsoleChoiceOption -Value ([string]$_.DistinguishedName) -Label $display
    })
    $listedValues = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($option in $ouOptions) {
        [void]$listedValues.Add([string]$option.Value)
    }
    $unlistedExisting = @($selected | Where-Object { -not $listedValues.Contains([string]$_) })

    $selection = Read-ShareSurferConsoleMultiSelect `
        -Title 'Forbidden OUs are skipped during EmployeeID-to-AD matching.' `
        -HelpText 'Use this for disabled-account archives, service-account containers, staging/test OUs, or areas that should not influence ownership.' `
        -Options $ouOptions `
        -SelectedValues @($selected) `
        -AllowQuit
    if ($selection.Action -eq 'Cancelled') {
        return @($selected)
    }

    @(@($unlistedExisting) + @(Get-ShareSurferConsoleMultiSelectValues -State $selection) | Select-Object -Unique)
}

function ConvertFrom-ShareSurferInteractiveSelection {
    param(
        [string] $Selection = '',

        [Parameter(Mandatory = $true)]
        [int] $Maximum
    )

    if ($Maximum -le 0) {
        return @()
    }

    if ([string]::IsNullOrWhiteSpace($Selection) -or $Selection.Trim().ToUpperInvariant() -eq 'A') {
        return 1..$Maximum
    }

    $values = New-Object System.Collections.Generic.List[int]
    foreach ($part in @($Selection -split ',')) {
        $text = $part.Trim()
        if ($text -match '^(\d+)\s*-\s*(\d+)$') {
            $start = [int]$Matches[1]
            $end = [int]$Matches[2]
            if ($end -lt $start) {
                $temp = $start
                $start = $end
                $end = $temp
            }
            foreach ($number in $start..$end) {
                if ($number -ge 1 -and $number -le $Maximum -and -not ($values -contains $number)) {
                    $values.Add($number)
                }
            }
        }
        elseif ($text -match '^\d+$') {
            $number = [int]$text
            if ($number -ge 1 -and $number -le $Maximum -and -not ($values -contains $number)) {
                $values.Add($number)
            }
        }
    }

    @($values)
}

function Get-ShareSurferOwnershipSourceTypePromptOptions {
    foreach ($sourceType in @(Get-ShareSurferOwnershipSourceTypes)) {
        $description = switch ($sourceType) {
            'Identity' { 'People or accounts, usually HR or directory-aligned employee data.'; break }
            'ObsContext' { 'Business structure, OBS/OID, owner, or business-unit clues.'; break }
            'ProjectContext' { 'Projects, programs, apps, or WBS codes linked to OBS or owners.'; break }
            'PathOwnership' { 'Share, folder, UNC, or path-prefix ownership clues.'; break }
            'GroupContext' { 'Security groups linked to owners, OBS, projects, or business units.'; break }
            default { 'Mixed or unclear source; keep this when the file has several kinds of clues.' }
        }
        New-ShareSurferConsoleChoiceOption -Value $sourceType -Description $description
    }
}

function Get-ShareSurferOwnershipAuthorityPromptOptions {
    foreach ($authority in @(Get-ShareSurferOwnershipAuthorityLevels)) {
        $description = switch ($authority) {
            'Authoritative' { 'Trusted source of record, such as HR or directory-backed employee data.'; break }
            'ReviewerHint' { 'Useful owner/business clue that should be reviewed before approval.'; break }
            'ContextOnly' { 'Context used for grouping; not direct ownership approval.'; break }
            default { 'Use when the file trust level is unclear.' }
        }
        New-ShareSurferConsoleChoiceOption -Value $authority -Description $description
    }
}

function Get-ShareSurferOwnershipFieldExplanation {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Field
    )

    switch ($Field) {
        'EmployeeId' { 'Usually the strongest join key for matching HR rows to AD accounts (employeeID attribute).'; break }
        'EmployeeNumber' { 'Alternate HR identifier; used with EmployeeId to match people to AD accounts (employeeNumber attribute).'; break }
        'SamAccountName' { 'Windows logon name; a direct account join key when HR identifiers are missing.'; break }
        'UserPrincipalName' { 'Sign-in name like user@domain; a direct account join key.'; break }
        'Mail' { 'Email address; a usable join key and how reviewers are contacted.'; break }
        'DisplayName' { 'Human-readable name shown in review packets and dashboards.'; break }
        'Title' { 'Job title; context that helps reviewers recognize the right owner.'; break }
        'Office' { 'Office or site location; light context for reviewers.'; break }
        'Department' { 'Department name; helps group people when OBS is missing.'; break }
        'Company' { 'Company or organization name for multi-entity environments.'; break }
        'ManagerMail' { 'Direct manager email; builds the escalation chain for owner review.'; break }
        'ManagerLevel2Mail' { 'Second-level manager email for escalation chains.'; break }
        'ManagerLevel3Mail' { 'Third-level manager email for escalation chains.'; break }
        'OBS' { 'Organizational breakdown structure (OBS/OID) path; the key that links people, projects, and paths to business structure.'; break }
        'BusinessUnit' { 'Business unit label used in owner and business-unit pivots.'; break }
        'DataOwner' { 'Named data owner; a direct reviewer hint for shares and paths.'; break }
        'OwnerMail' { 'Data owner email; how the owner is contacted for review.'; break }
        'Project' { 'Project, program, or application name that this row describes.'; break }
        'ProjectCode' { 'Project, WBS, or charge code; the strongest project join key.'; break }
        'ProjectDescription' { 'Project description; context shown to reviewers.'; break }
        'GroupName' { 'Security group name; links group-based access to business context.'; break }
        'PathPattern' { 'Share, folder, or UNC path prefix this row describes; links ownership context to scanned paths.'; break }
        default { 'Optional ownership context field.' }
    }
}

function New-ShareSurferOwnershipHeaderWizardState {
    param(
        [Parameter(Mandatory = $true)]
        [string[]] $Headers,

        [Parameter(Mandatory = $true)]
        $InitialFieldMap,

        [Parameter(Mandatory = $true)]
        [string] $SourcePath,

        [string] $ObsHeader = ''
    )

    $fieldMap = [ordered]@{}
    foreach ($property in $InitialFieldMap.PSObject.Properties) {
        $fieldMap[$property.Name] = [string]$property.Value
    }

    [pscustomobject]@{
        SourcePath = $SourcePath
        ObsHeader = $ObsHeader
        Headers = @($Headers)
        Definitions = @(Get-ShareSurferOwnershipFieldDefinitions)
        FieldIndex = 0
        FieldMap = $fieldMap
        Skipped = (New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase))
        Filter = ''
        Done = $false
        Cancelled = $false
        Message = ''
    }
}

function Get-ShareSurferOwnershipHeaderWizardVisibleHeaders {
    param(
        [Parameter(Mandatory = $true)]
        $State
    )

    $headers = @($State.Headers)
    $filter = ([string]$State.Filter).Trim()
    if (-not [string]::IsNullOrWhiteSpace($filter)) {
        $filterLower = $filter.ToLowerInvariant()
        $headers = @($headers | Where-Object { ([string]$_).ToLowerInvariant().Contains($filterLower) })
    }

    @($headers)
}

function Step-ShareSurferOwnershipHeaderWizard {
    param(
        [Parameter(Mandatory = $true)]
        $State
    )

    $State.Filter = ''
    $State.FieldIndex = [int]$State.FieldIndex + 1
    if ([int]$State.FieldIndex -ge @($State.Definitions).Count) {
        $State.Done = $true
    }

    $State
}

function Invoke-ShareSurferOwnershipHeaderWizardCommand {
    param(
        [Parameter(Mandatory = $true)]
        $State,

        [string] $Command = ''
    )

    $State.Message = ''
    $definitions = @($State.Definitions)
    if ([int]$State.FieldIndex -ge $definitions.Count) {
        $State.Done = $true
        return $State
    }

    $definition = $definitions[[int]$State.FieldIndex]
    $field = [string]$definition.Field
    $suggested = ''
    if ($State.FieldMap.Contains($field)) {
        $suggested = [string]$State.FieldMap[$field]
    }

    $text = ([string]$Command).Trim()
    $upper = $text.ToUpperInvariant()

    if ([string]::IsNullOrWhiteSpace($text)) {
        if ([string]::IsNullOrWhiteSpace($suggested)) {
            $visible = @(Get-ShareSurferOwnershipHeaderWizardVisibleHeaders -State $State)
            if ($visible.Count -gt 0 -and $visible.Count -le 10) {
                $State.Message = ('No suggestion exists for {0}. Choose one of the numbered headers above, type a header name, or press S to skip deliberately.' -f $field)
            }
            else {
                $State.Message = ('No suggestion exists for {0}. Type /text to filter, type a header name, or press S to skip deliberately.' -f $field)
            }
            return $State
        }
        return (Step-ShareSurferOwnershipHeaderWizard -State $State)
    }

    if ($upper -eq '?' -or $upper -eq 'HELP') {
        $State.Message = ('{0} Type a header name or its number to map {1}, Enter to accept an existing suggestion, /text to filter the header list, S to skip, B to go back, Q to cancel.' -f (Get-ShareSurferOwnershipFieldExplanation -Field $field), $field)
        return $State
    }

    if ($text.StartsWith('/')) {
        $State.Filter = $text.Substring(1).Trim()
        $State.Message = if ([string]::IsNullOrWhiteSpace([string]$State.Filter)) {
            'Header filter cleared.'
        }
        else {
            'Header filter set to "{0}".' -f [string]$State.Filter
        }
        return $State
    }

    if ($upper -in @('S', 'SKIP')) {
        $State.FieldMap[$field] = ''
        [void]$State.Skipped.Add($field)
        return (Step-ShareSurferOwnershipHeaderWizard -State $State)
    }

    if ($upper -in @('B', 'BACK')) {
        if ([int]$State.FieldIndex -gt 0) {
            $State.FieldIndex = [int]$State.FieldIndex - 1
            $State.Filter = ''
        }
        else {
            $State.Message = 'Already at the first field.'
        }
        return $State
    }

    if ($upper -in @('Q', 'QUIT')) {
        $State.Cancelled = $true
        $State.Done = $true
        return $State
    }

    if ($text -match '^\d+$') {
        $visible = @(Get-ShareSurferOwnershipHeaderWizardVisibleHeaders -State $State)
        $index = [int]$text
        if ($index -ge 1 -and $index -le $visible.Count) {
            $State.FieldMap[$field] = [string]$visible[$index - 1]
            [void]$State.Skipped.Remove($field)
            return (Step-ShareSurferOwnershipHeaderWizard -State $State)
        }
        $State.Message = ('Choose a number from 1 to {0}, or type a header name.' -f $visible.Count)
        return $State
    }

    $normalizedAnswer = Normalize-ShareSurferOwnershipHeaderName -Name $text
    $matched = ''
    foreach ($header in @($State.Headers)) {
        if ((Normalize-ShareSurferOwnershipHeaderName -Name ([string]$header)) -eq $normalizedAnswer) {
            $matched = [string]$header
            break
        }
    }

    if ($matched -ne '') {
        $State.FieldMap[$field] = $matched
    }
    else {
        $State.FieldMap[$field] = $text
        $State.Message = ('Header "{0}" was not found in this CSV. It stays recorded and will surface as an import warning unless a synonym match resolves it.' -f $text)
    }
    [void]$State.Skipped.Remove($field)
    Step-ShareSurferOwnershipHeaderWizard -State $State
}

function Get-ShareSurferOwnershipHeaderWizardScreen {
    param(
        [Parameter(Mandatory = $true)]
        $State,

        [int] $WindowWidth = 120,

        [int] $MaximumVisibleHeaders = 30
    )

    $lines = New-Object System.Collections.Generic.List[string]
    $definitions = @($State.Definitions)
    if ([int]$State.FieldIndex -ge $definitions.Count) {
        return @($lines.ToArray())
    }

    $definition = $definitions[[int]$State.FieldIndex]
    $field = [string]$definition.Field
    $recommended = if ([bool]$definition.Recommended) { 'recommended' } else { 'optional' }
    $suggested = ''
    if ($State.FieldMap.Contains($field)) {
        $suggested = [string]$State.FieldMap[$field]
    }

    $lines.Add('')
    $lines.Add('ShareSurfer Ownership Import')
    $lines.Add(('Source: {0}' -f [string]$State.SourcePath))
    $lines.Add(('Step {0}/{1} - {2} ({3})' -f ([int]$State.FieldIndex + 1), $definitions.Count, $field, $recommended))
    $lines.Add('')

    if (-not [string]::IsNullOrWhiteSpace($suggested)) {
        $lines.Add('Suggested header')
        $lines.Add(('> {0}' -f $suggested))
        $lines.Add('')
    }

    $visible = @(Get-ShareSurferOwnershipHeaderWizardVisibleHeaders -State $State)
    $lines.Add('Available headers')
    if ($visible.Count -eq 0) {
        $lines.Add('  (no headers match the current filter)')
    }
    else {
        $wrapWidth = [Math]::Max(40, [Math]::Min([int]$WindowWidth - 2, 100))
        $displayCount = [Math]::Min($visible.Count, [Math]::Max(1, [int]$MaximumVisibleHeaders))
        $currentLine = ''
        for ($index = 0; $index -lt $displayCount; $index++) {
            $item = '{0} {1}' -f ($index + 1), [string]$visible[$index]
            if ($currentLine -eq '') {
                $currentLine = '  ' + $item
            }
            elseif (($currentLine.Length + 4 + $item.Length) -le $wrapWidth) {
                $currentLine = $currentLine + '    ' + $item
            }
            else {
                $lines.Add($currentLine)
                $currentLine = '  ' + $item
            }
        }
        if ($currentLine -ne '') {
            $lines.Add($currentLine)
        }
        if ($visible.Count -gt $displayCount) {
            $lines.Add(('  (+{0} more - type a header name or /text to filter)' -f ($visible.Count - $displayCount)))
        }
    }
    if (-not [string]::IsNullOrWhiteSpace([string]$State.Filter)) {
        $lines.Add(('Filter: {0} (type / alone to clear)' -f [string]$State.Filter))
    }

    $lines.Add('')
    $lines.Add('Why this matters')
    $lines.Add((Get-ShareSurferOwnershipFieldExplanation -Field $field))
    $lines.Add('')

    $mappedCount = 0
    foreach ($mapDefinition in $definitions) {
        $mapField = [string]$mapDefinition.Field
        if ($State.FieldMap.Contains($mapField) -and -not [string]::IsNullOrWhiteSpace([string]$State.FieldMap[$mapField])) {
            $mappedCount++
        }
    }
    $lines.Add(('Mapped so far: {0} mapped, {1} skipped' -f $mappedCount, $State.Skipped.Count))
    $lines.Add('Controls: Enter=accept | numbers=choose | type a header name | /text=filter | S=skip | B=back | ?=help | Q=quit')
    if (-not [string]::IsNullOrWhiteSpace([string]$State.Message)) {
        $lines.Add('')
        $lines.Add([string]$State.Message)
    }

    @($lines.ToArray())
}

function Read-ShareSurferOwnershipHeaderSelections {
    param(
        [Parameter(Mandatory = $true)]
        [string[]] $Headers,

        [Parameter(Mandatory = $true)]
        $InitialFieldMap,

        [Parameter(Mandatory = $true)]
        [string] $SourcePath,

        [string] $ObsHeader = ''
    )

    $capabilities = Get-ShareSurferConsoleCapabilities
    $state = New-ShareSurferOwnershipHeaderWizardState -Headers $Headers -InitialFieldMap $InitialFieldMap -SourcePath $SourcePath -ObsHeader $ObsHeader
    while (-not $state.Done) {
        Write-ShareSurferConsoleLines -Lines (Get-ShareSurferOwnershipHeaderWizardScreen -State $state -WindowWidth ([int]$capabilities.WindowWidth))
        $definition = @($state.Definitions)[[int]$state.FieldIndex]
        $field = [string]$definition.Field
        $suggested = ''
        if ($state.FieldMap.Contains($field)) {
            $suggested = [string]$state.FieldMap[$field]
        }
        $prompt = if ([string]::IsNullOrWhiteSpace($suggested)) {
            'Column for {0}' -f $field
        }
        else {
            'Column for {0} [{1}]' -f $field, $suggested
        }

        $answer = Read-Host -Prompt $prompt
        Invoke-ShareSurferOwnershipHeaderWizardCommand -State $state -Command $answer | Out-Null
    }

    if ([bool]$state.Cancelled) {
        return [pscustomobject]@{
            FieldMap = $null
            Warnings = @()
            Cancelled = $true
        }
    }

    $resolved = Resolve-ShareSurferOwnershipHeaderMap -Headers $Headers -ObsHeader $ObsHeader -FieldMap (ConvertTo-ShareSurferOwnershipFieldMapHashtable -FieldMap ([pscustomobject]$state.FieldMap))
    foreach ($skippedField in @($state.Skipped)) {
        if ($null -ne $resolved.FieldMap.PSObject.Properties[$skippedField]) {
            $resolved.FieldMap.PSObject.Properties[$skippedField].Value = ''
        }
    }

    [pscustomobject]@{
        FieldMap = $resolved.FieldMap
        Warnings = @($resolved.Warnings)
        Cancelled = $false
    }
}

function Read-ShareSurferOwnershipSourceProfile {
    param(
        [Parameter(Mandatory = $true)]
        [string] $SourcePath,

        [Parameter(Mandatory = $true)]
        $FieldMap,

        [Parameter(Mandatory = $true)]
        $InitialProfile
    )

    Write-Host ''
    Write-Host ('Ownership source classification for {0}' -f $SourcePath)
    Write-Host ('Detected source type: {0}' -f $InitialProfile.SourceType)
    Write-Host ('Detected primary anchor: {0}' -f $InitialProfile.PrimaryAnchor)
    Write-Host ('Mapped fields: {0}' -f $InitialProfile.MappedFields)

    $selectedSourceType = [string]$InitialProfile.SourceType
    $selectedAuthority = Get-ShareSurferOwnershipDefaultAuthorityLevel -SourceType $selectedSourceType
    if (-not [string]::IsNullOrWhiteSpace([string]$InitialProfile.AuthorityLevel) -and [string]$InitialProfile.AuthorityLevel -ne 'Unknown') {
        $selectedAuthority = [string]$InitialProfile.AuthorityLevel
    }
    $selectedAnchor = Get-ShareSurferOwnershipDefaultPrimaryAnchor -FieldMap $FieldMap -SourceType $selectedSourceType
    if (-not [string]::IsNullOrWhiteSpace([string]$InitialProfile.PrimaryAnchor)) {
        $selectedAnchor = [string]$InitialProfile.PrimaryAnchor
    }

    $cancelledResult = [pscustomobject]@{
        Cancelled = $true
    }

    $profileStep = 0
    while ($profileStep -lt 3) {
        if ($profileStep -eq 0) {
            $sourceSelection = Read-ShareSurferConsoleChoice -Title 'Step 1/3 - What does this CSV mostly describe?' -Options @(Get-ShareSurferOwnershipSourceTypePromptOptions) -DefaultValue $selectedSourceType -HelpText 'Source type controls how ShareSurfer explains context rows and relationships from this file.' -AllowBack -AllowQuit
            if ($sourceSelection.Action -eq 'Select') {
                $selectedSourceType = [string]$sourceSelection.SelectedValue
                $selectedAuthority = Get-ShareSurferOwnershipDefaultAuthorityLevel -SourceType $selectedSourceType
                $selectedAnchor = Get-ShareSurferOwnershipDefaultPrimaryAnchor -FieldMap $FieldMap -SourceType $selectedSourceType
                $profileStep++
                continue
            }
            if ($sourceSelection.Action -eq 'Back') {
                Write-ShareSurferConsoleLines -Lines @('Already at the first source-classification prompt.')
                continue
            }
            if ($sourceSelection.Action -eq 'Cancelled') {
                return $cancelledResult
            }
        }
        elseif ($profileStep -eq 1) {
            $authoritySelection = Read-ShareSurferConsoleChoice -Title 'Step 2/3 - How authoritative is this file?' -Options @(Get-ShareSurferOwnershipAuthorityPromptOptions) -DefaultValue $selectedAuthority -HelpText 'This tells reviewers how much trust to place in ownership facts from this CSV.' -AllowBack -AllowQuit
            if ($authoritySelection.Action -eq 'Select') {
                $selectedAuthority = [string]$authoritySelection.SelectedValue
                $profileStep++
                continue
            }
            if ($authoritySelection.Action -eq 'Back') {
                $profileStep--
                continue
            }
            if ($authoritySelection.Action -eq 'Cancelled') {
                return $cancelledResult
            }
        }
        else {
            $mappedFields = @(Get-ShareSurferOwnershipMappedFieldNames -FieldMap $FieldMap)
            if ($mappedFields.Count -eq 0 -and -not [string]::IsNullOrWhiteSpace($selectedAnchor)) {
                $mappedFields = @($selectedAnchor)
            }
            $anchorOptions = @($mappedFields | ForEach-Object {
                New-ShareSurferConsoleChoiceOption -Value ([string]$_) -Description 'Use this field as the strongest clue for this source.'
            })
            if ($anchorOptions.Count -eq 0) {
                $anchorOptions = @(New-ShareSurferConsoleChoiceOption -Value '' -Label '(no mapped anchor)' -Description 'No mapped fields are available yet.')
            }
            $anchorSelection = Read-ShareSurferConsoleChoice -Title 'Step 3/3 - Which mapped field is the strongest anchor?' -Options $anchorOptions -DefaultValue $selectedAnchor -HelpText 'The anchor is the best field for explaining why this source links to identities, OBS, paths, projects, or groups.' -AllowBack -AllowQuit
            if ($anchorSelection.Action -eq 'Select') {
                $selectedAnchor = [string]$anchorSelection.SelectedValue
                $profileStep++
                continue
            }
            if ($anchorSelection.Action -eq 'Back') {
                $profileStep--
                continue
            }
            if ($anchorSelection.Action -eq 'Cancelled') {
                return $cancelledResult
            }
        }
    }

    New-ShareSurferOwnershipSourceProfile -SourcePath $SourcePath -FieldMap $FieldMap -SourceType $selectedSourceType -AuthorityLevel $selectedAuthority -PrimaryAnchor $selectedAnchor -Warnings @([string]$InitialProfile.Warnings)
}

function Write-ShareSurferOwnershipImportStatus {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Message,

        [switch] $Quiet
    )

    if ($Quiet) {
        return
    }

    if ($null -ne (Get-Command Write-ShareSurferStatus -ErrorAction SilentlyContinue)) {
        Write-ShareSurferStatus -Phase 'Ownership' -Message $Message
        return
    }

    $timestamp = Get-Date -Format 'HH:mm:ss'
    Write-Host ('[{0}] ShareSurfer Ownership: {1}' -f $timestamp, $Message)
}

function Write-ShareSurferOwnershipImportProgress {
    param(
        [string] $Activity = 'ShareSurfer ownership import',

        [string] $Status = '',

        [string] $CurrentOperation = '',

        [int] $Processed = 0,

        [int] $Total = 0,

        [switch] $Completed,

        [switch] $Quiet
    )

    if ($Quiet) {
        return
    }

    try {
        if ($Completed) {
            Write-Progress -Activity $Activity -Completed
            return
        }

        $progressParameters = @{
            Activity = $Activity
            Status = $Status
        }
        if (-not [string]::IsNullOrWhiteSpace($CurrentOperation)) {
            $progressParameters.CurrentOperation = $CurrentOperation
        }
        if ($Total -gt 0) {
            $percent = [int][Math]::Min(100, [Math]::Max(0, (($Processed / $Total) * 100)))
            $progressParameters.PercentComplete = $percent
        }

        Write-Progress @progressParameters
    }
    catch {
        # Console progress is helpful but should never stop ownership import work.
    }
}

function Get-ShareSurferOwnershipElapsedText {
    param(
        [Parameter(Mandatory = $true)]
        [System.Diagnostics.Stopwatch] $Stopwatch
    )

    $elapsed = $Stopwatch.Elapsed
    if ($elapsed.TotalHours -ge 1) {
        return ('{0:0.0}h' -f $elapsed.TotalHours)
    }
    if ($elapsed.TotalMinutes -ge 1) {
        return ('{0:0.0}m' -f $elapsed.TotalMinutes)
    }

    '{0:0.0}s' -f $elapsed.TotalSeconds
}

function Add-ShareSurferOwnershipObsMergeIndex {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable] $Index,

        [string] $ObsKey = '',

        [string] $MergeKey = ''
    )

    if ([string]::IsNullOrWhiteSpace($ObsKey) -or [string]::IsNullOrWhiteSpace($MergeKey)) {
        return
    }

    if (-not $Index.ContainsKey($ObsKey)) {
        $Index[$ObsKey] = @{}
    }

    $Index[$ObsKey][$MergeKey] = $true
}

function New-ShareSurferOwnershipDirectoryLookupCacheKey {
    param(
        [string] $EmployeeId = '',

        [string] $EmployeeNumber = ''
    )

    'employeeId={0}|employeeNumber={1}' -f ([string]$EmployeeId).Trim().ToLowerInvariant(), ([string]$EmployeeNumber).Trim().ToLowerInvariant()
}
