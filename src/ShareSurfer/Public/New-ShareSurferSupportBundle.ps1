function New-ShareSurferSupportBundle {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $ExportPath,

        [Parameter(Mandatory = $true)]
        [string] $OutputPath,

        [ValidateSet('StableToken', 'Strict')]
        [string] $RedactionMode = 'StableToken',

        [string] $RedactionSalt = ''
    )

    if ($RedactionSalt -eq '') {
        $RedactionSalt = [guid]::NewGuid().ToString('N')
    }

    if (-not (Test-Path -LiteralPath $OutputPath)) {
        New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
    }

    $schema = Get-ShareSurferExportSchema
    foreach ($fileName in $schema.Keys) {
        $sourcePath = Join-Path $ExportPath $fileName
        $destinationPath = Join-Path $OutputPath $fileName
        $rows = @(Read-ShareSurferCsv -Path $sourcePath)

        $redactedRows = foreach ($row in $rows) {
            Protect-ShareSurferRow -Row $row -FileName $fileName -Columns $schema[$fileName] -RedactionMode $RedactionMode -RedactionSalt $RedactionSalt
        }

        Export-ShareSurferCsv -Path $destinationPath -Columns $schema[$fileName] -Rows $redactedRows
    }

    Set-Content -LiteralPath (Join-Path $OutputPath 'README.txt') -Value @(
        'ShareSurfer redacted support bundle',
        ('GeneratedAt={0}' -f (Get-Date).ToUniversalTime().ToString('o')),
        ('RedactionMode={0}' -f $RedactionMode),
        'Relationship-preserving StableToken mode uses salted synthetic IDs and does not include the salt in this bundle.'
    ) -Encoding UTF8

    [pscustomobject]@{
        OutputPath = $OutputPath
        RedactionMode = $RedactionMode
    }
}
