function Import-ShareSurferOwnershipSource {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $Path,

        [Parameter(Mandatory = $true)]
        [string] $OutputPath,

        [string] $MappingProfilePath = '',

        [string] $ObsHeader = '',

        [string] $ReusableCommandPath = '',

        [switch] $Force
    )

    if ((Test-Path -LiteralPath $OutputPath) -and -not $Force) {
        throw "Normalized ownership output already exists: $OutputPath. Use -Force to overwrite it."
    }

    $fieldMapOverride = @{}
    if (-not [string]::IsNullOrWhiteSpace($MappingProfilePath)) {
        if (-not (Test-Path -LiteralPath $MappingProfilePath)) {
            throw "Ownership mapping profile was not found: $MappingProfilePath"
        }

        $profile = Get-Content -LiteralPath $MappingProfilePath -Raw | ConvertFrom-Json
        if ($profile.PSObject.Properties['FieldMap']) {
            $fieldMapOverride = ConvertTo-ShareSurferOwnershipFieldMapHashtable -FieldMap $profile.FieldMap
        }
    }

    $headers = @(Get-ShareSurferCsvHeaders -Path $Path)
    $resolved = Resolve-ShareSurferOwnershipHeaderMap -Headers $headers -ObsHeader $ObsHeader -FieldMap $fieldMapOverride
    $fieldMap = $resolved.FieldMap
    $sourceRows = @(Import-Csv -LiteralPath $Path)
    $normalizedRows = New-Object System.Collections.Generic.List[object]
    $warnings = New-Object System.Collections.Generic.List[string]
    foreach ($warning in @($resolved.Warnings)) {
        if (-not [string]::IsNullOrWhiteSpace([string]$warning)) {
            $warnings.Add([string]$warning)
        }
    }

    $joinKeyFields = @(Get-ShareSurferOwnershipJoinKeyFields | Where-Object {
        $fieldMap.PSObject.Properties[$_] -and -not [string]::IsNullOrWhiteSpace([string]$fieldMap.PSObject.Properties[$_].Value)
    })
    if ($joinKeyFields.Count -eq 0) {
        $warnings.Add('No stable join key was mapped. Normalized rows were written, but matching to directory identities may be weak.')
    }

    $duplicateTrackers = @{
        EmployeeId = @{}
        EmployeeNumber = @{}
        SamAccountName = @{}
        UserPrincipalName = @{}
        Mail = @{}
    }

    $rowNumber = 1
    foreach ($sourceRow in $sourceRows) {
        $rowNumber++

        $employeeId = Get-ShareSurferOwnershipMappedValue -Row $sourceRow -FieldMap $fieldMap -Field 'EmployeeId'
        $employeeNumber = Get-ShareSurferOwnershipMappedValue -Row $sourceRow -FieldMap $fieldMap -Field 'EmployeeNumber'
        $samAccountName = Get-ShareSurferOwnershipMappedValue -Row $sourceRow -FieldMap $fieldMap -Field 'SamAccountName'
        $userPrincipalName = Get-ShareSurferOwnershipMappedValue -Row $sourceRow -FieldMap $fieldMap -Field 'UserPrincipalName'
        $mail = Get-ShareSurferOwnershipMappedValue -Row $sourceRow -FieldMap $fieldMap -Field 'Mail'
        $displayName = Get-ShareSurferOwnershipMappedValue -Row $sourceRow -FieldMap $fieldMap -Field 'DisplayName'
        $title = Get-ShareSurferOwnershipMappedValue -Row $sourceRow -FieldMap $fieldMap -Field 'Title'
        $office = Get-ShareSurferOwnershipMappedValue -Row $sourceRow -FieldMap $fieldMap -Field 'Office'
        $department = Get-ShareSurferOwnershipMappedValue -Row $sourceRow -FieldMap $fieldMap -Field 'Department'
        $company = Get-ShareSurferOwnershipMappedValue -Row $sourceRow -FieldMap $fieldMap -Field 'Company'
        $managerMail = Get-ShareSurferOwnershipMappedValue -Row $sourceRow -FieldMap $fieldMap -Field 'ManagerMail'
        $managerLevel2Mail = Get-ShareSurferOwnershipMappedValue -Row $sourceRow -FieldMap $fieldMap -Field 'ManagerLevel2Mail'
        $managerLevel3Mail = Get-ShareSurferOwnershipMappedValue -Row $sourceRow -FieldMap $fieldMap -Field 'ManagerLevel3Mail'
        $obs = Get-ShareSurferOwnershipMappedValue -Row $sourceRow -FieldMap $fieldMap -Field 'OBS'
        $businessUnit = Get-ShareSurferOwnershipMappedValue -Row $sourceRow -FieldMap $fieldMap -Field 'BusinessUnit'
        $dataOwner = Get-ShareSurferOwnershipMappedValue -Row $sourceRow -FieldMap $fieldMap -Field 'DataOwner'
        $ownerMail = Get-ShareSurferOwnershipMappedValue -Row $sourceRow -FieldMap $fieldMap -Field 'OwnerMail'

        $rowWarnings = New-Object System.Collections.Generic.List[string]
        if ([string]::IsNullOrWhiteSpace($employeeId) -and [string]::IsNullOrWhiteSpace($employeeNumber) -and [string]::IsNullOrWhiteSpace($samAccountName) -and [string]::IsNullOrWhiteSpace($userPrincipalName) -and [string]::IsNullOrWhiteSpace($mail)) {
            $rowWarnings.Add('NoJoinKey')
        }

        $potentialServiceAccount = $false
        if ([string]::IsNullOrWhiteSpace($obs) -and [string]::IsNullOrWhiteSpace($employeeId) -and [string]::IsNullOrWhiteSpace($employeeNumber)) {
            $potentialServiceAccount = $true
            $rowWarnings.Add('PotentialServiceAccount')
        }

        foreach ($field in @('EmployeeId', 'EmployeeNumber', 'SamAccountName', 'UserPrincipalName', 'Mail')) {
            $value = ''
            switch ($field) {
                'EmployeeId' { $value = $employeeId }
                'EmployeeNumber' { $value = $employeeNumber }
                'SamAccountName' { $value = $samAccountName }
                'UserPrincipalName' { $value = $userPrincipalName }
                'Mail' { $value = $mail }
            }

            if (-not [string]::IsNullOrWhiteSpace($value)) {
                $normalizedValue = $value.ToLowerInvariant()
                if ($duplicateTrackers[$field].ContainsKey($normalizedValue)) {
                    $rowWarnings.Add(('Duplicate{0}' -f $field))
                }
                else {
                    $duplicateTrackers[$field][$normalizedValue] = $true
                }
            }
        }

        $normalizedRows.Add([pscustomobject]@{
            EmployeeId = $employeeId
            EmployeeNumber = $employeeNumber
            SamAccountName = $samAccountName
            UserPrincipalName = $userPrincipalName
            Mail = $mail
            DisplayName = $displayName
            Title = $title
            Office = $office
            Department = $department
            Company = $company
            ManagerMail = $managerMail
            ManagerLevel2Mail = $managerLevel2Mail
            ManagerLevel3Mail = $managerLevel3Mail
            OBS = $obs
            BusinessUnit = $businessUnit
            DataOwner = $dataOwner
            OwnerMail = $ownerMail
            PotentialServiceAccount = $potentialServiceAccount
            SourceRowNumber = $rowNumber
            SourcePath = $Path
            ImportWarnings = (@($rowWarnings) -join '; ')
        })
    }

    $parent = Split-Path -Parent $OutputPath
    if (-not [string]::IsNullOrWhiteSpace($parent) -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    $normalizedRows | Export-Csv -LiteralPath $OutputPath -NoTypeInformation -Encoding UTF8

    $warningRows = @($normalizedRows | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_.ImportWarnings) })
    $reusableCommands = New-ShareSurferOwnershipImportReusableCommands -SourcePath $Path -OutputPath $OutputPath -MappingProfilePath $MappingProfilePath -ObsHeader $ObsHeader
    $writtenReusableCommandPath = Write-ShareSurferReusableCommandFile -Path $ReusableCommandPath -CommandText $reusableCommands

    [pscustomobject]@{
        SourcePath = $Path
        OutputPath = $OutputPath
        MappingProfilePath = $MappingProfilePath
        RowCount = $normalizedRows.Count
        WarningRowCount = $warningRows.Count
        PotentialServiceAccountCount = @($normalizedRows | Where-Object { [bool]$_.PotentialServiceAccount }).Count
        JoinKeyFields = ($joinKeyFields -join ', ')
        ObsHeader = if ($fieldMap.PSObject.Properties['OBS']) { [string]$fieldMap.OBS } else { '' }
        Warnings = @($warnings)
        ReusableCommandPath = $writtenReusableCommandPath
        ReusableCommands = $reusableCommands
    }
}
