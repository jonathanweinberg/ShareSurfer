function Test-ShareSurferOwnerMapping {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $Path,

        [string] $ExportPath = ''
    )

    $mappingCsv = Read-ShareSurferOwnerMappingCsv -Path $Path
    Test-ShareSurferOwnerMappingData -MappingCsv $mappingCsv -ExportPath $ExportPath
}
