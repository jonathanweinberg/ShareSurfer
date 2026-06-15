function Test-ShareSurferOwnershipSource {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $Path,

        [string] $ObsHeader = '',

        [string] $MappingProfilePath = ''
    )

    $headers = @(Get-ShareSurferCsvHeaders -Path $Path)
    $rows = @(Import-Csv -LiteralPath $Path)
    $profileFieldMap = @{}
    $profileWarnings = @()

    if (-not [string]::IsNullOrWhiteSpace($MappingProfilePath)) {
        if (-not (Test-Path -LiteralPath $MappingProfilePath)) {
            throw "Ownership mapping profile was not found: $MappingProfilePath"
        }

        $profile = Get-Content -LiteralPath $MappingProfilePath -Raw | ConvertFrom-Json
        if ($profile.PSObject.Properties['FieldMap']) {
            $profileFieldMap = ConvertTo-ShareSurferOwnershipFieldMapHashtable -FieldMap $profile.FieldMap
        }
        else {
            $profileWarnings += 'Mapping profile does not contain a FieldMap object.'
        }
    }

    $resolved = Resolve-ShareSurferOwnershipHeaderMap -Headers $headers -ObsHeader $ObsHeader -FieldMap $profileFieldMap
    $fieldMap = $resolved.FieldMap
    $warnings = New-Object System.Collections.Generic.List[string]
    foreach ($warning in @($profileWarnings + $resolved.Warnings)) {
        if (-not [string]::IsNullOrWhiteSpace([string]$warning)) {
            $warnings.Add([string]$warning)
        }
    }

    $joinKeyFields = @(Get-ShareSurferOwnershipJoinKeyFields | Where-Object {
        $fieldMap.PSObject.Properties[$_] -and -not [string]::IsNullOrWhiteSpace([string]$fieldMap.PSObject.Properties[$_].Value)
    })

    $missingRecommended = New-Object System.Collections.Generic.List[string]
    foreach ($definition in @(Get-ShareSurferOwnershipFieldDefinitions | Where-Object { $_.Recommended })) {
        $field = [string]$definition.Field
        if (-not $fieldMap.PSObject.Properties[$field] -or [string]::IsNullOrWhiteSpace([string]$fieldMap.PSObject.Properties[$field].Value)) {
            $missingRecommended.Add($field)
        }
    }

    if ($joinKeyFields.Count -eq 0) {
        $warnings.Add('No stable join key was mapped. Provide at least one of EmployeeId, EmployeeNumber, SamAccountName, UserPrincipalName, or Mail.')
    }

    if ($missingRecommended -contains 'OBS') {
        $warnings.Add('No OBS column was mapped. Use -ObsHeader or a mapping profile if the source has an OBS/OID/org-path column with an unexpected name.')
    }

    [pscustomobject]@{
        SourcePath = $Path
        RowCount = $rows.Count
        HeaderCount = $headers.Count
        Headers = ($headers -join ', ')
        IsUsable = ($joinKeyFields.Count -gt 0)
        JoinKeyFields = ($joinKeyFields -join ', ')
        ObsHeader = if ($fieldMap.PSObject.Properties['OBS']) { [string]$fieldMap.OBS } else { '' }
        MissingRecommendedFields = ($missingRecommended -join ', ')
        FieldMap = $fieldMap
        Warnings = @($warnings)
        CanonicalHeaders = ((Get-ShareSurferOwnershipFieldDefinitions | ForEach-Object { $_.Field }) -join ', ')
    }
}
