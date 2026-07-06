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
        if ($Interactive) {
            $fieldMap = Read-ShareSurferOwnershipHeaderSelections -Headers $headers -InitialFieldMap $fieldMap -SourcePath $sourcePath -ObsHeader $ObsHeader
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

        $sourceProfile = New-ShareSurferOwnershipSourceProfile -SourcePath $sourcePath -FieldMap $fieldMap -SourceType $sourceTypeOverride -AuthorityLevel $authorityLevelOverride -Warnings @($resolved.Warnings)
        if ($Interactive -and $null -eq $savedSourceProfile) {
            $sourceProfile = Read-ShareSurferOwnershipSourceProfile -SourcePath $sourcePath -FieldMap $fieldMap -InitialProfile $sourceProfile
        }
        [void]$sourceProfilesForDefinition.Add($sourceProfile)

        foreach ($warning in @($resolved.Warnings)) {
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

            if (-not [string]::IsNullOrWhiteSpace($obsKey) -and $obsContextRows.ContainsKey($obsKey)) {
                $incoming = Merge-ShareSurferOwnershipEnrichmentRow -Existing $incoming -Incoming $obsContextRows[$obsKey]
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
            foreach ($existingKey in @($mergedKeysByObsKey[$obsKey].Keys)) {
                $mergedRows[$existingKey] = Merge-ShareSurferOwnershipEnrichmentRow -Existing $mergedRows[$existingKey] -Incoming $obsContextRows[$obsKey]
                $obsContextStrongRowMergeCount++
            }
        }
        else {
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
        elseif ([string]::IsNullOrWhiteSpace([string]$row.ImportWarnings)) {
            $row.ImportWarnings = 'NoEmployeeIdentifierForAdMatch'
        }
        else {
            $row.ImportWarnings = Add-ShareSurferDelimitedValue -Existing ([string]$row.ImportWarnings) -Value 'NoEmployeeIdentifierForAdMatch'
        }

        $row.PotentialServiceAccount = [string]([string]::IsNullOrWhiteSpace([string]$row.OBS) -and [string]::IsNullOrWhiteSpace([string]$row.AdObsPath) -and [string]::IsNullOrWhiteSpace([string]$row.EmployeeId) -and [string]::IsNullOrWhiteSpace([string]$row.EmployeeNumber))
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

    Write-ShareSurferOwnershipImportStatus -Message ('Ownership import complete: {0} row(s), {1} matched, {2} ambiguous, {3} forbidden-OU skipped, {4} source-only, {5} potential service-account-like row(s), {6} AD lookup attempt(s), {7} cache hit(s). Elapsed {8}.' -f $enrichedRows.Count, @($enrichedRows | Where-Object { [string]$_.MatchStatus -eq 'Matched' }).Count, @($enrichedRows | Where-Object { [string]$_.MatchStatus -eq 'Ambiguous' }).Count, @($enrichedRows | Where-Object { [string]$_.MatchStatus -eq 'ForbiddenOuSkipped' }).Count, @($enrichedRows | Where-Object { [string]$_.MatchStatus -eq 'SourceOnly' }).Count, @($enrichedRows | Where-Object { [string]$_.PotentialServiceAccount -eq 'True' }).Count, $lookupAttemptCount, $lookupCacheHitCount, (Get-ShareSurferOwnershipElapsedText -Stopwatch $progressClock)) -Quiet:$Quiet

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
        MatchedCount = @($enrichedRows | Where-Object { [string]$_.MatchStatus -eq 'Matched' }).Count
        AmbiguousCount = @($enrichedRows | Where-Object { [string]$_.MatchStatus -eq 'Ambiguous' }).Count
        ForbiddenOuSkippedCount = @($enrichedRows | Where-Object { [string]$_.MatchStatus -eq 'ForbiddenOuSkipped' }).Count
        SourceOnlyCount = @($enrichedRows | Where-Object { [string]$_.MatchStatus -eq 'SourceOnly' }).Count
        PotentialServiceAccountCount = @($enrichedRows | Where-Object { [string]$_.PotentialServiceAccount -eq 'True' }).Count
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

function Show-ShareSurferCsvPicker {
    param(
        [Parameter(Mandatory = $true)]
        $State
    )

    $view = Get-ShareSurferCsvPickerView -State $State
    Write-Host ''
    Write-Host ('Current folder: {0}' -f $view.CurrentFolder)
    Write-Host ''
    if (@($view.Entries).Count -eq 0) {
        Write-Host '  No subfolders or CSV files found here.'
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
            Write-Host ('  [{0}] {1,-10} {2}' -f ($index + 1), $marker, $entry.Name)
        }
    }

    Write-Host ''
    Write-Host ('Selected CSVs: {0}' -f @($State.SelectedCsvPaths).Count)
    Write-Host 'Commands: number=open folder/toggle CSV, A=select all CSVs here, C=clear, U=up, P=show selected, D=done, Q=quit'
}

function Show-ShareSurferCsvPickerSelectedPaths {
    param(
        [Parameter(Mandatory = $true)]
        $State
    )

    Write-Host ''
    Write-Host 'Selected CSV files:'
    if (@($State.SelectedCsvPaths).Count -eq 0) {
        Write-Host '  None yet.'
        return
    }

    foreach ($path in @($State.SelectedCsvPaths)) {
        Write-Host ('  {0}' -f $path)
    }
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

    Write-Host ''
    Write-Host 'Forbidden OUs are skipped during EmployeeID-to-AD matching.'
    Write-Host 'Use this for disabled-account archives, service-account containers, staging/test OUs, or areas that should not influence ownership.'
    Write-Host ''
    for ($index = 0; $index -lt $ous.Count; $index++) {
        $display = if (-not [string]::IsNullOrWhiteSpace([string]$ous[$index].CanonicalName)) { [string]$ous[$index].CanonicalName } else { [string]$ous[$index].DistinguishedName }
        Write-Host ('  [{0}] {1}' -f ($index + 1), $display)
    }
    Write-Host ''
    Write-Host 'Type numbers separated by commas, a range like 2-4, N for none, or press Enter to keep existing selections.'
    $answer = Read-Host -Prompt 'OUs to ignore'
    if ([string]::IsNullOrWhiteSpace($answer)) {
        return @($selected)
    }
    if ($answer.Trim().ToUpperInvariant() -eq 'N') {
        return @()
    }

    $indexes = @(ConvertFrom-ShareSurferInteractiveSelection -Selection $answer -Maximum $ous.Count)
    foreach ($index in $indexes) {
        $selected.Add([string]$ous[$index - 1].DistinguishedName)
    }

    @($selected | Select-Object -Unique)
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

    $fieldMap = [ordered]@{}
    foreach ($property in $InitialFieldMap.PSObject.Properties) {
        $fieldMap[$property.Name] = [string]$property.Value
    }

    Write-Host ''
    Write-Host ('Header interview for {0}' -f $SourcePath)
    Write-Host ('Available headers: {0}' -f ($Headers -join ', '))
    Write-Host 'Press Enter to accept a suggestion, type a different header, or type S to skip a field.'
    foreach ($definition in @(Get-ShareSurferOwnershipFieldDefinitions)) {
        $field = [string]$definition.Field
        $suggested = ''
        if ($fieldMap.Contains($field)) {
            $suggested = [string]$fieldMap[$field]
        }

        $prompt = if ([string]::IsNullOrWhiteSpace($suggested)) {
            'Column for {0}' -f $field
        }
        else {
            'Column for {0} [{1}]' -f $field, $suggested
        }

        $answer = Read-Host -Prompt $prompt
        if ([string]::IsNullOrWhiteSpace($answer)) {
            continue
        }
        if ($answer.Trim().ToUpperInvariant() -eq 'S') {
            $fieldMap[$field] = ''
            continue
        }

        $fieldMap[$field] = $answer.Trim()
    }

    $resolved = Resolve-ShareSurferOwnershipHeaderMap -Headers $Headers -ObsHeader $ObsHeader -FieldMap (ConvertTo-ShareSurferOwnershipFieldMapHashtable -FieldMap ([pscustomobject]$fieldMap))
    $resolved.FieldMap
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

    $sourceTypes = @(Get-ShareSurferOwnershipSourceTypes)
    for ($index = 0; $index -lt $sourceTypes.Count; $index++) {
        Write-Host ('  {0}. {1}' -f ($index + 1), $sourceTypes[$index])
    }

    $selectedSourceType = [string]$InitialProfile.SourceType
    $sourceTypeAnswer = Read-Host -Prompt ('What does this CSV mostly describe? [{0}]' -f $selectedSourceType)
    if (-not [string]::IsNullOrWhiteSpace($sourceTypeAnswer)) {
        $trimmed = $sourceTypeAnswer.Trim()
        $numericChoice = 0
        if ([int]::TryParse($trimmed, [ref]$numericChoice) -and $numericChoice -ge 1 -and $numericChoice -le $sourceTypes.Count) {
            $selectedSourceType = [string]$sourceTypes[$numericChoice - 1]
        }
        elseif ($sourceTypes -contains $trimmed) {
            $selectedSourceType = $trimmed
        }
        else {
            Write-Host ('Unrecognized source type "{0}"; keeping {1}.' -f $trimmed, $selectedSourceType)
        }
    }

    $authorityLevels = @(Get-ShareSurferOwnershipAuthorityLevels)
    $selectedAuthority = Get-ShareSurferOwnershipDefaultAuthorityLevel -SourceType $selectedSourceType
    if (-not [string]::IsNullOrWhiteSpace([string]$InitialProfile.AuthorityLevel) -and [string]$InitialProfile.AuthorityLevel -ne 'Unknown') {
        $selectedAuthority = [string]$InitialProfile.AuthorityLevel
    }

    Write-Host ''
    for ($index = 0; $index -lt $authorityLevels.Count; $index++) {
        Write-Host ('  {0}. {1}' -f ($index + 1), $authorityLevels[$index])
    }

    $authorityAnswer = Read-Host -Prompt ('How authoritative is this file? [{0}]' -f $selectedAuthority)
    if (-not [string]::IsNullOrWhiteSpace($authorityAnswer)) {
        $trimmed = $authorityAnswer.Trim()
        $numericChoice = 0
        if ([int]::TryParse($trimmed, [ref]$numericChoice) -and $numericChoice -ge 1 -and $numericChoice -le $authorityLevels.Count) {
            $selectedAuthority = [string]$authorityLevels[$numericChoice - 1]
        }
        elseif ($authorityLevels -contains $trimmed) {
            $selectedAuthority = $trimmed
        }
        else {
            Write-Host ('Unrecognized authority "{0}"; keeping {1}.' -f $trimmed, $selectedAuthority)
        }
    }

    $selectedAnchor = Get-ShareSurferOwnershipDefaultPrimaryAnchor -FieldMap $FieldMap -SourceType $selectedSourceType
    if (-not [string]::IsNullOrWhiteSpace([string]$InitialProfile.PrimaryAnchor)) {
        $selectedAnchor = [string]$InitialProfile.PrimaryAnchor
    }

    $anchorAnswer = Read-Host -Prompt ('Strongest anchor field [{0}]' -f $selectedAnchor)
    if (-not [string]::IsNullOrWhiteSpace($anchorAnswer)) {
        $selectedAnchor = $anchorAnswer.Trim()
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
