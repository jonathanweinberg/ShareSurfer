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
    $generatedAt = (Get-Date).ToUniversalTime().ToString('o')
    $fileDiagnostics = New-Object System.Collections.ArrayList
    foreach ($fileName in $schema.Keys) {
        $sourcePath = Join-Path $ExportPath $fileName
        $destinationPath = Join-Path $OutputPath $fileName
        $rows = @(Read-ShareSurferCsv -Path $sourcePath)

        $redactedRows = foreach ($row in $rows) {
            Protect-ShareSurferRow -Row $row -FileName $fileName -Columns $schema[$fileName] -RedactionMode $RedactionMode -RedactionSalt $RedactionSalt
        }

        Export-ShareSurferCsv -Path $destinationPath -Columns $schema[$fileName] -Rows $redactedRows
        [void]$fileDiagnostics.Add([pscustomobject]@{
            FileName = $fileName
            RowCount = @($redactedRows).Count
            Sha256 = Get-ShareSurferFileSha256 -Path $destinationPath
        })
    }

    $validation = Test-ShareSurferExport -ExportPath $OutputPath
    $manifest = @(
        [pscustomobject]@{
            GeneratedAt = $generatedAt
            RedactionMode = $RedactionMode
            RelationshipPreserving = [bool]($RedactionMode -eq 'StableToken')
            ExportFileCount = @($schema.Keys).Count
            DiagnosticFileCount = @($fileDiagnostics).Count
            ValidationIsValid = [bool]$validation.IsValid
            MissingFileCount = @($validation.MissingFiles).Count
            SchemaErrorCount = @($validation.SchemaErrors).Count
        }
    )

    $manifest | Export-Csv -LiteralPath (Join-Path $OutputPath 'support_bundle_manifest.csv') -NoTypeInformation -Encoding UTF8
    @($fileDiagnostics) | Export-Csv -LiteralPath (Join-Path $OutputPath 'support_bundle_files.csv') -NoTypeInformation -Encoding UTF8

    Set-Content -LiteralPath (Join-Path $OutputPath 'README.txt') -Value @(
        'ShareSurfer redacted support bundle',
        ('GeneratedAt={0}' -f $generatedAt),
        ('RedactionMode={0}' -f $RedactionMode),
        ('ValidationIsValid={0}' -f [bool]$validation.IsValid),
        'Relationship-preserving StableToken mode uses salted synthetic IDs and does not include the salt in this bundle.',
        'support_bundle_manifest.csv records bundle-level diagnostics.',
        'support_bundle_files.csv records redacted file row counts and hashes.'
    ) -Encoding UTF8

    [pscustomobject]@{
        OutputPath = $OutputPath
        RedactionMode = $RedactionMode
        ValidationIsValid = [bool]$validation.IsValid
    }
}

function Get-ShareSurferFileSha256 {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Path
    )

    $sha = [System.Security.Cryptography.SHA256]::Create()
    $stream = [System.IO.File]::OpenRead($Path)
    try {
        $hash = $sha.ComputeHash($stream)
        ([System.BitConverter]::ToString($hash)).Replace('-', '')
    }
    finally {
        $stream.Dispose()
        $sha.Dispose()
    }
}
