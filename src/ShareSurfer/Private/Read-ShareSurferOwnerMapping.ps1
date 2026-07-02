function Read-ShareSurferOwnerMapping {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Path
    )

    $mappingCsv = Read-ShareSurferOwnerMappingCsv -Path $Path
    $validation = Test-ShareSurferOwnerMappingData -MappingCsv $mappingCsv
    if (-not $validation.IsValid) {
        throw ("Owner mapping file is invalid: {0}. {1}" -f $Path, ((@($validation.Errors) | Select-Object -First 5) -join ' '))
    }

    $headerMap = $mappingCsv.HeaderMap
    $rows = @($mappingCsv.Rows)
    foreach ($row in $rows) {
        [pscustomobject]@{
            Pattern = Get-ShareSurferMappedCsvValue -Row $row -HeaderMap $headerMap -Column 'Pattern'
            Owner = Get-ShareSurferMappedCsvValue -Row $row -HeaderMap $headerMap -Column 'Owner'
            BusinessUnit = Get-ShareSurferMappedCsvValue -Row $row -HeaderMap $headerMap -Column 'BusinessUnit'
            Source = if (-not [string]::IsNullOrWhiteSpace((Get-ShareSurferMappedCsvValue -Row $row -HeaderMap $headerMap -Column 'Source'))) { Get-ShareSurferMappedCsvValue -Row $row -HeaderMap $headerMap -Column 'Source' } else { 'OwnerMappingPath' }
        }
    }
}
