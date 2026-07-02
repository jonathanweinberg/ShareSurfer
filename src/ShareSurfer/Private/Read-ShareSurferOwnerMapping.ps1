function Read-ShareSurferOwnerMapping {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Owner mapping file was not found: $Path"
    }

    $validation = Test-ShareSurferOwnerMapping -Path $Path
    if (-not $validation.IsValid) {
        throw ("Owner mapping file is invalid: {0}. {1}" -f $Path, ((@($validation.Errors) | Select-Object -First 5) -join ' '))
    }

    $headers = @(Get-ShareSurferCsvHeaders -Path $Path)
    $headerMap = Resolve-ShareSurferOwnerMappingHeaderMap -Headers $headers
    $rows = @(Import-Csv -LiteralPath $Path)
    foreach ($row in $rows) {
        [pscustomobject]@{
            Pattern = Get-ShareSurferMappedCsvValue -Row $row -HeaderMap $headerMap -Column 'Pattern'
            Owner = Get-ShareSurferMappedCsvValue -Row $row -HeaderMap $headerMap -Column 'Owner'
            BusinessUnit = Get-ShareSurferMappedCsvValue -Row $row -HeaderMap $headerMap -Column 'BusinessUnit'
            Source = if (-not [string]::IsNullOrWhiteSpace((Get-ShareSurferMappedCsvValue -Row $row -HeaderMap $headerMap -Column 'Source'))) { Get-ShareSurferMappedCsvValue -Row $row -HeaderMap $headerMap -Column 'Source' } else { 'OwnerMappingPath' }
        }
    }
}
