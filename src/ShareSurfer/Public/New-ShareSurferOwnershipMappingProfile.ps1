function New-ShareSurferOwnershipMappingProfile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $Path,

        [Parameter(Mandatory = $true)]
        [string] $OutputPath,

        [string] $SourceName = '',

        [string] $ObsHeader = '',

        [switch] $Interactive,

        [string] $ReusableCommandPath = '',

        [switch] $Force
    )

    if ((Test-Path -LiteralPath $OutputPath) -and -not $Force) {
        throw "Ownership mapping profile already exists: $OutputPath. Use -Force to overwrite it."
    }

    $assessment = Test-ShareSurferOwnershipSource -Path $Path -ObsHeader $ObsHeader
    $headers = @(Get-ShareSurferCsvHeaders -Path $Path)
    $fieldMap = [ordered]@{}

    foreach ($property in $assessment.FieldMap.PSObject.Properties) {
        $fieldMap[$property.Name] = [string]$property.Value
    }

    if ($Interactive) {
        Write-Host 'ShareSurfer found these CSV headers:'
        Write-Host ('  {0}' -f ($headers -join ', '))
        Write-Host ''
        Write-Host 'Press Enter to accept a suggested header, type a different header, or type S to skip that field.'

        foreach ($definition in @(Get-ShareSurferOwnershipFieldDefinitions)) {
            $field = [string]$definition.Field
            $suggested = ''
            if ($fieldMap.Contains($field)) {
                $suggested = [string]$fieldMap[$field]
            }

            $prompt = if ([string]::IsNullOrWhiteSpace($suggested)) {
                ("Column for {0}" -f $field)
            }
            else {
                ("Column for {0} [{1}]" -f $field, $suggested)
            }

            $answer = Read-Host -Prompt $prompt
            if ([string]::IsNullOrWhiteSpace($answer)) {
                continue
            }
            elseif ($answer.Trim().ToUpperInvariant() -eq 'S') {
                $fieldMap[$field] = ''
            }
            else {
                $fieldMap[$field] = $answer.Trim()
            }
        }

        $interactiveResolved = Resolve-ShareSurferOwnershipHeaderMap -Headers $headers -ObsHeader $ObsHeader -FieldMap (ConvertTo-ShareSurferOwnershipFieldMapHashtable -FieldMap ([pscustomobject]$fieldMap))
        $fieldMap = [ordered]@{}
        foreach ($property in $interactiveResolved.FieldMap.PSObject.Properties) {
            $fieldMap[$property.Name] = [string]$property.Value
        }
        $assessment = [pscustomobject]@{
            IsUsable = (@(Get-ShareSurferOwnershipJoinKeyFields | Where-Object { $fieldMap.Contains($_) -and -not [string]::IsNullOrWhiteSpace([string]$fieldMap[$_]) }).Count -gt 0)
            JoinKeyFields = (@(Get-ShareSurferOwnershipJoinKeyFields | Where-Object { $fieldMap.Contains($_) -and -not [string]::IsNullOrWhiteSpace([string]$fieldMap[$_]) }) -join ', ')
            ObsHeader = if ($fieldMap.Contains('OBS')) { [string]$fieldMap['OBS'] } else { '' }
            Warnings = @($interactiveResolved.Warnings)
        }
    }

    $ignoredHeaders = New-Object System.Collections.Generic.List[string]
    foreach ($header in $headers) {
        $isMapped = $false
        foreach ($key in $fieldMap.Keys) {
            if ((Normalize-ShareSurferOwnershipHeaderName -Name ([string]$fieldMap[$key])) -eq (Normalize-ShareSurferOwnershipHeaderName -Name $header)) {
                $isMapped = $true
                break
            }
        }
        if (-not $isMapped) {
            $ignoredHeaders.Add([string]$header)
        }
    }

    if ([string]::IsNullOrWhiteSpace($SourceName)) {
        $SourceName = [System.IO.Path]::GetFileNameWithoutExtension($Path)
    }

    $profile = [ordered]@{
        ProfileVersion = 1
        SourceName = $SourceName
        CreatedAt = (Get-Date).ToUniversalTime().ToString('o')
        SourcePath = $Path
        FieldMap = [pscustomobject]$fieldMap
        IgnoredHeaders = @($ignoredHeaders)
        Warnings = @($assessment.Warnings)
    }

    $parent = Split-Path -Parent $OutputPath
    if (-not [string]::IsNullOrWhiteSpace($parent) -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    $profile | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $OutputPath -Encoding UTF8
    $reusableCommands = New-ShareSurferOwnershipProfileReusableCommands -SourcePath $Path -ProfilePath $OutputPath
    $writtenReusableCommandPath = Write-ShareSurferReusableCommandFile -Path $ReusableCommandPath -CommandText $reusableCommands

    [pscustomobject]@{
        ProfilePath = $OutputPath
        SourcePath = $Path
        SourceName = $SourceName
        IsUsable = $assessment.IsUsable
        JoinKeyFields = $assessment.JoinKeyFields
        ObsHeader = $assessment.ObsHeader
        IgnoredHeaders = @($ignoredHeaders)
        Warnings = @($assessment.Warnings)
        ReusableCommandPath = $writtenReusableCommandPath
        ReusableCommands = $reusableCommands
    }
}
