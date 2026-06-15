function Join-ShareSurferOwnershipSources {
    [CmdletBinding()]
    param(
        [string[]] $Path = @(),

        [string] $SourceFolder = '',

        [switch] $BrowseForCsv,

        [Parameter(Mandatory = $true)]
        [string] $OutputPath,

        [string] $DefinitionPath = '',

        [string[]] $MappingProfilePath = @(),

        [string] $ObsHeader = '',

        [string] $ObsAttribute = 'extensionAttribute10',

        [ValidateSet('Auto', 'ActiveDirectory', 'Ldap', 'DirectoryOnly')]
        [string] $AdLookupMode = 'Auto',

        [string[]] $ForbiddenOu = @(),

        [switch] $Interactive,

        [string] $ReusableCommandPath = '',

        [switch] $Force
    )

    if ((Test-Path -LiteralPath $OutputPath) -and -not $Force) {
        throw "Ownership enrichment output already exists: $OutputPath. Use -Force to overwrite it."
    }

    if ($BrowseForCsv -and -not $Interactive) {
        throw 'BrowseForCsv requires -Interactive because it uses a text-mode picker.'
    }

    $definition = $null
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
    }

    $selectedPaths = @(Resolve-ShareSurferOwnershipSourcePaths -Path $Path -SourceFolder $SourceFolder -Interactive:$Interactive -BrowseForCsv:$BrowseForCsv)
    if ($selectedPaths.Count -eq 0) {
        throw 'No ownership source CSV files were selected.'
    }

    $selectedForbiddenOus = @($ForbiddenOu | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($Interactive) {
        $selectedForbiddenOus = @(Select-ShareSurferForbiddenOus -ExistingForbiddenOu $selectedForbiddenOus -AdLookupMode $AdLookupMode)
    }

    $writtenDefinitionPath = ''
    if (-not [string]::IsNullOrWhiteSpace($DefinitionPath)) {
        $writtenDefinitionPath = Export-ShareSurferOwnershipImportDefinition -Path $DefinitionPath -SelectedCsvPaths $selectedPaths -SourceFolder $SourceFolder -OutputPath $OutputPath -MappingProfilePaths $MappingProfilePath -ObsHeader $ObsHeader -ObsAttribute $ObsAttribute -AdLookupMode $AdLookupMode -ForbiddenOu $selectedForbiddenOus -Force
    }

    $mergedRows = [ordered]@{}
    $obsContextRows = @{}
    $sourceIndex = 0
    $sourceWarnings = New-Object System.Collections.Generic.List[string]
    foreach ($sourcePath in $selectedPaths) {
        $sourceIndex++
        $profilePath = ''
        if ($MappingProfilePath.Count -ge $sourceIndex) {
            $profilePath = [string]$MappingProfilePath[$sourceIndex - 1]
        }

        $headers = @(Get-ShareSurferCsvHeaders -Path $sourcePath)
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

        foreach ($warning in @($resolved.Warnings)) {
            if (-not [string]::IsNullOrWhiteSpace([string]$warning)) {
                $sourceWarnings.Add(('{0}: {1}' -f $sourcePath, [string]$warning))
            }
        }

        $sourceRows = @(Import-Csv -LiteralPath $sourcePath)
        $rowNumber = 1
        foreach ($sourceRow in $sourceRows) {
            $rowNumber++
            $incoming = New-ShareSurferOwnershipEnrichmentRow -SourceRow $sourceRow -FieldMap $fieldMap -SourcePath $sourcePath -SourceRowNumber $rowNumber -ObsAttribute $ObsAttribute
            $obsKey = Get-ShareSurferOwnershipObsMergeKey -Row $incoming
            if (-not (Test-ShareSurferOwnershipStrongJoinKey -Row $incoming) -and -not [string]::IsNullOrWhiteSpace($obsKey)) {
                if ($obsContextRows.ContainsKey($obsKey)) {
                    $obsContextRows[$obsKey] = Merge-ShareSurferOwnershipEnrichmentRow -Existing $obsContextRows[$obsKey] -Incoming $incoming
                }
                else {
                    $obsContextRows[$obsKey] = $incoming
                }

                foreach ($existingKey in @($mergedRows.Keys)) {
                    $existingObsKey = Get-ShareSurferOwnershipObsMergeKey -Row $mergedRows[$existingKey]
                    if ($existingObsKey -eq $obsKey) {
                        $mergedRows[$existingKey] = Merge-ShareSurferOwnershipEnrichmentRow -Existing $mergedRows[$existingKey] -Incoming $incoming
                    }
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
        }
    }

    foreach ($obsKey in @($obsContextRows.Keys)) {
        $hasMatchingStrongRow = $false
        foreach ($existing in @($mergedRows.Values)) {
            if ((Get-ShareSurferOwnershipObsMergeKey -Row $existing) -eq $obsKey) {
                $hasMatchingStrongRow = $true
                break
            }
        }

        if (-not $hasMatchingStrongRow) {
            $mergedRows[$obsKey] = $obsContextRows[$obsKey]
        }
    }

    $enrichedRows = New-Object System.Collections.ArrayList
    foreach ($row in @($mergedRows.Values)) {
        if ($AdLookupMode -ne 'DirectoryOnly' -and (-not [string]::IsNullOrWhiteSpace([string]$row.EmployeeId) -or -not [string]::IsNullOrWhiteSpace([string]$row.EmployeeNumber))) {
            $lookup = Get-ShareSurferDirectoryIdentityByEmployee -EmployeeId ([string]$row.EmployeeId) -EmployeeNumber ([string]$row.EmployeeNumber) -ObsAttribute $ObsAttribute -AdLookupMode $AdLookupMode -ForbiddenOu $selectedForbiddenOus
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
    }

    $parent = Split-Path -Parent $OutputPath
    if (-not [string]::IsNullOrWhiteSpace($parent) -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    Export-ShareSurferCsv -Path $OutputPath -Columns (Get-ShareSurferOwnershipEnrichmentColumns) -Rows $enrichedRows
    $reusableCommands = New-ShareSurferOwnershipEnrichmentReusableCommands -SourcePaths $selectedPaths -OutputPath $OutputPath -MappingProfilePaths $MappingProfilePath -ObsHeader $ObsHeader -ObsAttribute $ObsAttribute -AdLookupMode $AdLookupMode -ForbiddenOu $selectedForbiddenOus -DefinitionPath $writtenDefinitionPath
    $writtenReusableCommandPath = Write-ShareSurferReusableCommandFile -Path $ReusableCommandPath -CommandText $reusableCommands

    [pscustomobject]@{
        OutputPath = $OutputPath
        DefinitionPath = $writtenDefinitionPath
        SourcePaths = (@($selectedPaths) -join '; ')
        SourceCount = $selectedPaths.Count
        RowCount = $enrichedRows.Count
        MatchedCount = @($enrichedRows | Where-Object { [string]$_.MatchStatus -eq 'Matched' }).Count
        AmbiguousCount = @($enrichedRows | Where-Object { [string]$_.MatchStatus -eq 'Ambiguous' }).Count
        ForbiddenOuSkippedCount = @($enrichedRows | Where-Object { [string]$_.MatchStatus -eq 'ForbiddenOuSkipped' }).Count
        SourceOnlyCount = @($enrichedRows | Where-Object { [string]$_.MatchStatus -eq 'SourceOnly' }).Count
        PotentialServiceAccountCount = @($enrichedRows | Where-Object { [string]$_.PotentialServiceAccount -eq 'True' }).Count
        ForbiddenOu = (@($selectedForbiddenOus) -join '; ')
        ObsAttribute = $ObsAttribute
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
