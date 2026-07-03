function Add-ShareSurferOwnerMappings {
    param(
        [Parameter(Mandatory = $true)]
        $Inventory,

        [string] $OwnerMappingPath = ''
    )

    if ([string]::IsNullOrWhiteSpace($OwnerMappingPath)) {
        return $Inventory
    }

    $existingMappings = @()
    if ($null -ne $Inventory.PSObject.Properties['OwnerMappings']) {
        $existingMappings = @(ConvertTo-ShareSurferArray $Inventory.OwnerMappings)
    }

    $mappingCsv = Read-ShareSurferOwnerMappingCsv -Path $OwnerMappingPath
    $validation = Test-ShareSurferOwnerMappingData -MappingCsv $mappingCsv
    if (-not $validation.IsValid) {
        throw ("Owner mapping file is invalid: {0}. {1}" -f $OwnerMappingPath, ((@($validation.Errors) | Select-Object -First 5) -join ' '))
    }

    if (@($validation.Warnings).Count -gt 0) {
        $scanEvents = @()
        if ($null -ne $Inventory.PSObject.Properties['ScanEvents']) {
            $scanEvents = @(ConvertTo-ShareSurferArray $Inventory.ScanEvents)
        }

        $warningProblemRows = @($validation.ProblemRows | Where-Object { [string]$_.Severity -eq 'Warning' })
        if ($warningProblemRows.Count -gt 0) {
            foreach ($problemRow in $warningProblemRows) {
                $detail = 'Path={0}; RowNumber={1}; Column={2}; Problem={3}' -f $OwnerMappingPath, [string]$problemRow.RowNumber, [string]$problemRow.Column, [string]$problemRow.Problem
                $scanEvents += (New-ShareSurferEvent -Level 'Warning' -EventType 'OwnerMappingValidationWarning' -Source 'OwnerMappingPath' -Message ([string]$problemRow.Message) -Detail $detail)
            }
        }
        else {
            foreach ($warning in @($validation.Warnings)) {
                $scanEvents += (New-ShareSurferEvent -Level 'Warning' -EventType 'OwnerMappingValidationWarning' -Source 'OwnerMappingPath' -Message ([string]$warning) -Detail ('Path={0}' -f $OwnerMappingPath))
            }
        }

        if ($null -ne $Inventory.PSObject.Properties['ScanEvents']) {
            $Inventory.ScanEvents = $scanEvents
        }
        else {
            $Inventory | Add-Member -MemberType NoteProperty -Name ScanEvents -Value $scanEvents
        }
    }

    $fileMappings = @(ConvertTo-ShareSurferOwnerMappingRows -MappingCsv $mappingCsv)
    $mergedMappings = @($existingMappings + $fileMappings)
    if ($null -ne $Inventory.PSObject.Properties['OwnerMappings']) {
        $Inventory.OwnerMappings = $mergedMappings
    }
    else {
        $Inventory | Add-Member -MemberType NoteProperty -Name OwnerMappings -Value $mergedMappings
    }
    $Inventory
}
