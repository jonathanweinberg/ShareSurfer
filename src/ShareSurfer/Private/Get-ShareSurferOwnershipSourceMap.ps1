function Get-ShareSurferOwnershipFieldDefinitions {
    @(
        [pscustomobject]@{ Field = 'EmployeeId'; Required = $false; Recommended = $true; Synonyms = @('employeeid', 'employee_id', 'employee id', 'employeeID', 'workerid', 'worker_id', 'worker id') },
        [pscustomobject]@{ Field = 'EmployeeNumber'; Required = $false; Recommended = $true; Synonyms = @('employeenumber', 'employee_number', 'employee number', 'employeeNo', 'employee_no', 'personnelnumber', 'personnel_number', 'personnel number') },
        [pscustomobject]@{ Field = 'SamAccountName'; Required = $false; Recommended = $false; Synonyms = @('samaccountname', 'sam_account_name', 'sam', 'account', 'accountname', 'account_name', 'username', 'login') },
        [pscustomobject]@{ Field = 'UserPrincipalName'; Required = $false; Recommended = $false; Synonyms = @('userprincipalname', 'user_principal_name', 'upn', 'principalname', 'principal_name') },
        [pscustomobject]@{ Field = 'Mail'; Required = $false; Recommended = $false; Synonyms = @('mail', 'email', 'emailaddress', 'email_address', 'mailaddress', 'mail_address', 'e-mail') },
        [pscustomobject]@{ Field = 'DisplayName'; Required = $false; Recommended = $false; Synonyms = @('displayname', 'display_name', 'display name', 'name', 'fullname', 'full_name', 'full name') },
        [pscustomobject]@{ Field = 'Title'; Required = $false; Recommended = $false; Synonyms = @('title', 'jobtitle', 'job_title', 'job title', 'position') },
        [pscustomobject]@{ Field = 'Office'; Required = $false; Recommended = $false; Synonyms = @('office', 'physicaldeliveryofficename', 'physical_delivery_office_name', 'location', 'site') },
        [pscustomobject]@{ Field = 'Department'; Required = $false; Recommended = $false; Synonyms = @('department', 'dept', 'departmentname', 'department_name') },
        [pscustomobject]@{ Field = 'Company'; Required = $false; Recommended = $false; Synonyms = @('company', 'companyname', 'company_name', 'organization') },
        [pscustomobject]@{ Field = 'ManagerMail'; Required = $false; Recommended = $false; Synonyms = @('managermail', 'manager_mail', 'manageremail', 'manager_email', 'mgrmail', 'mgr_email', 'supervisor', 'supervisoremail', 'supervisor_email') },
        [pscustomobject]@{ Field = 'ManagerLevel2Mail'; Required = $false; Recommended = $false; Synonyms = @('managerlevel2mail', 'manager_level_2_mail', 'manager2mail', 'manager_2_mail', 'managersmanager', 'managers_manager') },
        [pscustomobject]@{ Field = 'ManagerLevel3Mail'; Required = $false; Recommended = $false; Synonyms = @('managerlevel3mail', 'manager_level_3_mail', 'manager3mail', 'manager_3_mail', 'level3manager', 'level_3_manager') },
        [pscustomobject]@{ Field = 'OBS'; Required = $false; Recommended = $true; Synonyms = @('obs', 'oid', 'orgpath', 'org_path', 'org path', 'organizationpath', 'organization_path', 'costcenterpath', 'cost_center_path', 'cost center path', 'departmentpath', 'department_path', 'divisionpath', 'division_path', 'extensionattribute10') },
        [pscustomobject]@{ Field = 'BusinessUnit'; Required = $false; Recommended = $true; Synonyms = @('businessunit', 'business_unit', 'business unit', 'bu', 'division', 'lineofbusiness', 'line_of_business', 'lob') },
        [pscustomobject]@{ Field = 'DataOwner'; Required = $false; Recommended = $false; Synonyms = @('dataowner', 'data_owner', 'data owner', 'owner', 'businessowner', 'business_owner', 'business owner') },
        [pscustomobject]@{ Field = 'OwnerMail'; Required = $false; Recommended = $false; Synonyms = @('ownermail', 'owner_mail', 'owneremail', 'owner_email', 'dataowneremail', 'data_owner_email') }
    )
}

function Normalize-ShareSurferOwnershipHeaderName {
    param(
        [AllowNull()]
        [string] $Name
    )

    if ([string]::IsNullOrWhiteSpace($Name)) {
        return ''
    }

    ([string]$Name).Trim().ToLowerInvariant() -replace '[^a-z0-9]', ''
}

function Get-ShareSurferCsvHeaders {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Ownership source CSV was not found: $Path"
    }

    $headerLine = Get-Content -LiteralPath $Path -TotalCount 1
    if ([string]::IsNullOrWhiteSpace($headerLine)) {
        throw "Ownership source CSV has no header row: $Path"
    }

    $delimiterCount = 0
    $inQuotes = $false
    for ($index = 0; $index -lt $headerLine.Length; $index++) {
        $character = $headerLine[$index]
        if ($character -eq '"') {
            if ($inQuotes -and ($index + 1) -lt $headerLine.Length -and $headerLine[$index + 1] -eq '"') {
                $index++
                continue
            }
            $inQuotes = -not $inQuotes
        }
        elseif ($character -eq ',' -and -not $inQuotes) {
            $delimiterCount++
        }
    }

    $dummyValues = New-Object string[] ($delimiterCount + 1)
    for ($index = 0; $index -lt $dummyValues.Length; $index++) {
        $dummyValues[$index] = 'x'
    }
    $dummyRow = $dummyValues -join ','
    $probe = @(@($headerLine, $dummyRow) | ConvertFrom-Csv)
    if ($probe.Count -eq 0) {
        throw "Ownership source CSV headers could not be parsed: $Path"
    }

    @($probe[0].PSObject.Properties | ForEach-Object { [string]$_.Name })
}

function Resolve-ShareSurferOwnershipHeaderMap {
    param(
        [Parameter(Mandatory = $true)]
        [string[]] $Headers,

        [string] $ObsHeader = '',

        [hashtable] $FieldMap = @{}
    )

    $headerByNormalizedName = @{}
    foreach ($header in @($Headers)) {
        $normalized = Normalize-ShareSurferOwnershipHeaderName -Name $header
        if ($normalized -ne '' -and -not $headerByNormalizedName.ContainsKey($normalized)) {
            $headerByNormalizedName[$normalized] = [string]$header
        }
    }

    $warnings = New-Object System.Collections.Generic.List[string]
    $map = [ordered]@{}
    foreach ($definition in @(Get-ShareSurferOwnershipFieldDefinitions)) {
        $field = [string]$definition.Field
        $selected = ''

        if ($FieldMap.ContainsKey($field) -and -not [string]::IsNullOrWhiteSpace([string]$FieldMap[$field])) {
            $configuredHeader = [string]$FieldMap[$field]
            $normalizedConfiguredHeader = Normalize-ShareSurferOwnershipHeaderName -Name $configuredHeader
            if ($headerByNormalizedName.ContainsKey($normalizedConfiguredHeader)) {
                $selected = [string]$headerByNormalizedName[$normalizedConfiguredHeader]
            }
            else {
                $warnings.Add(("Configured header for {0} was not found: {1}" -f $field, $configuredHeader))
            }
        }

        if ($field -eq 'OBS' -and $selected -eq '' -and -not [string]::IsNullOrWhiteSpace($ObsHeader)) {
            $normalizedObsHeader = Normalize-ShareSurferOwnershipHeaderName -Name $ObsHeader
            if ($headerByNormalizedName.ContainsKey($normalizedObsHeader)) {
                $selected = [string]$headerByNormalizedName[$normalizedObsHeader]
            }
            else {
                $warnings.Add(("OBS header was not found: {0}" -f $ObsHeader))
            }
        }

        if ($selected -eq '') {
            $normalizedField = Normalize-ShareSurferOwnershipHeaderName -Name $field
            if ($headerByNormalizedName.ContainsKey($normalizedField)) {
                $selected = [string]$headerByNormalizedName[$normalizedField]
            }
        }

        if ($selected -eq '') {
            foreach ($synonym in @($definition.Synonyms)) {
                $normalizedSynonym = Normalize-ShareSurferOwnershipHeaderName -Name ([string]$synonym)
                if ($headerByNormalizedName.ContainsKey($normalizedSynonym)) {
                    $selected = [string]$headerByNormalizedName[$normalizedSynonym]
                    break
                }
            }
        }

        $map[$field] = $selected
    }

    [pscustomobject]@{
        FieldMap = [pscustomobject]$map
        Warnings = @($warnings)
    }
}

function Get-ShareSurferOwnershipMappedValue {
    param(
        [Parameter(Mandatory = $true)]
        [psobject] $Row,

        [Parameter(Mandatory = $true)]
        [psobject] $FieldMap,

        [Parameter(Mandatory = $true)]
        [string] $Field
    )

    $header = ''
    if ($FieldMap.PSObject.Properties[$Field]) {
        $header = [string]$FieldMap.PSObject.Properties[$Field].Value
    }

    if ([string]::IsNullOrWhiteSpace($header)) {
        return ''
    }

    if (-not $Row.PSObject.Properties[$header]) {
        return ''
    }

    ([string]$Row.PSObject.Properties[$header].Value).Trim()
}

function ConvertTo-ShareSurferOwnershipFieldMapHashtable {
    param(
        [AllowNull()]
        [object] $FieldMap
    )

    $map = @{}
    if ($null -eq $FieldMap) {
        return $map
    }

    if ($FieldMap -is [hashtable]) {
        foreach ($key in $FieldMap.Keys) {
            $map[[string]$key] = [string]$FieldMap[$key]
        }
        return $map
    }

    foreach ($property in $FieldMap.PSObject.Properties) {
        $map[[string]$property.Name] = [string]$property.Value
    }

    $map
}

function Get-ShareSurferOwnershipJoinKeyFields {
    @('EmployeeId', 'EmployeeNumber', 'SamAccountName', 'UserPrincipalName', 'Mail')
}

function ConvertTo-ShareSurferPowerShellLiteral {
    param(
        [AllowNull()]
        [string] $Value
    )

    if ($null -eq $Value) {
        return "''"
    }

    "'{0}'" -f ([string]$Value).Replace("'", "''")
}

function Write-ShareSurferReusableCommandFile {
    param(
        [string] $Path = '',

        [Parameter(Mandatory = $true)]
        [string] $CommandText
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return ''
    }

    $parent = Split-Path -Parent $Path
    if (-not [string]::IsNullOrWhiteSpace($parent) -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    Set-Content -LiteralPath $Path -Value $CommandText -Encoding UTF8
    $Path
}

function New-ShareSurferOwnershipImportReusableCommands {
    param(
        [Parameter(Mandatory = $true)]
        [string] $SourcePath,

        [Parameter(Mandatory = $true)]
        [string] $OutputPath,

        [string] $MappingProfilePath = '',

        [string] $ObsHeader = ''
    )

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('# Reusable ShareSurfer ownership import commands')
    $lines.Add('# Run this after replacing paths only when your input or output location changes.')
    $lines.Add(('$sourcePath = {0}' -f (ConvertTo-ShareSurferPowerShellLiteral -Value $SourcePath)))
    $lines.Add(('$normalizedPath = {0}' -f (ConvertTo-ShareSurferPowerShellLiteral -Value $OutputPath)))

    if (-not [string]::IsNullOrWhiteSpace($MappingProfilePath)) {
        $lines.Add(('$profilePath = {0}' -f (ConvertTo-ShareSurferPowerShellLiteral -Value $MappingProfilePath)))
        $lines.Add('')
        $lines.Add('Test-ShareSurferOwnershipSource -Path $sourcePath -MappingProfilePath $profilePath')
        $lines.Add('Import-ShareSurferOwnershipSource -Path $sourcePath -MappingProfilePath $profilePath -OutputPath $normalizedPath -Force')
    }
    else {
        if (-not [string]::IsNullOrWhiteSpace($ObsHeader)) {
            $lines.Add(('$obsHeader = {0}' -f (ConvertTo-ShareSurferPowerShellLiteral -Value $ObsHeader)))
            $lines.Add('')
            $lines.Add('Test-ShareSurferOwnershipSource -Path $sourcePath -ObsHeader $obsHeader')
            $lines.Add('Import-ShareSurferOwnershipSource -Path $sourcePath -ObsHeader $obsHeader -OutputPath $normalizedPath -Force')
        }
        else {
            $lines.Add('')
            $lines.Add('Test-ShareSurferOwnershipSource -Path $sourcePath')
            $lines.Add('Import-ShareSurferOwnershipSource -Path $sourcePath -OutputPath $normalizedPath -Force')
        }
    }

    $lines -join [Environment]::NewLine
}

function New-ShareSurferOwnershipProfileReusableCommands {
    param(
        [Parameter(Mandatory = $true)]
        [string] $SourcePath,

        [Parameter(Mandatory = $true)]
        [string] $ProfilePath,

        [string] $NormalizedOutputPath = ''
    )

    if ([string]::IsNullOrWhiteSpace($NormalizedOutputPath)) {
        $parent = Split-Path -Parent $ProfilePath
        if ([string]::IsNullOrWhiteSpace($parent)) {
            $parent = Split-Path -Parent $SourcePath
        }
        if ([string]::IsNullOrWhiteSpace($parent)) {
            $NormalizedOutputPath = 'normalized-ownership.csv'
        }
        else {
            $NormalizedOutputPath = Join-Path $parent 'normalized-ownership.csv'
        }
    }

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('# Reusable ShareSurfer ownership profile commands')
    $lines.Add('# This reuses the saved mapping profile so you do not need to repeat the header interview.')
    $lines.Add(('$sourcePath = {0}' -f (ConvertTo-ShareSurferPowerShellLiteral -Value $SourcePath)))
    $lines.Add(('$profilePath = {0}' -f (ConvertTo-ShareSurferPowerShellLiteral -Value $ProfilePath)))
    $lines.Add(('$normalizedPath = {0}' -f (ConvertTo-ShareSurferPowerShellLiteral -Value $NormalizedOutputPath)))
    $lines.Add('')
    $lines.Add('Test-ShareSurferOwnershipSource -Path $sourcePath -MappingProfilePath $profilePath')
    $lines.Add('Import-ShareSurferOwnershipSource -Path $sourcePath -MappingProfilePath $profilePath -OutputPath $normalizedPath -Force')

    $lines -join [Environment]::NewLine
}

function New-ShareSurferOwnerMappingDraftReusableCommands {
    param(
        [Parameter(Mandatory = $true)]
        [string] $ExportPath,

        [Parameter(Mandatory = $true)]
        [string] $DraftPath,

        [Parameter(Mandatory = $true)]
        [string] $Scope,

        [Parameter(Mandatory = $true)]
        [int] $MaximumRows
    )

    $parent = Split-Path -Parent $DraftPath
    $ownerMappingPath = if ([string]::IsNullOrWhiteSpace($parent)) {
        'owner-mapping.csv'
    }
    else {
        Join-Path $parent 'owner-mapping.csv'
    }

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('# Reusable ShareSurfer owner mapping draft commands')
    $lines.Add('# First regenerate the draft if the scan export changes.')
    $lines.Add(('$exportPath = {0}' -f (ConvertTo-ShareSurferPowerShellLiteral -Value $ExportPath)))
    $lines.Add(('$draftPath = {0}' -f (ConvertTo-ShareSurferPowerShellLiteral -Value $DraftPath)))
    $lines.Add(('$ownerMappingPath = {0}' -f (ConvertTo-ShareSurferPowerShellLiteral -Value $ownerMappingPath)))
    $lines.Add('')
    $lines.Add(('New-ShareSurferOwnerMappingDraft -ExportPath $exportPath -OutputPath $draftPath -Scope {0} -MaximumRows {1} -Force' -f (ConvertTo-ShareSurferPowerShellLiteral -Value $Scope), $MaximumRows))
    $lines.Add('')
    $lines.Add('# Then edit owner-mapping-draft.csv, fill Owner and BusinessUnit, and save it as owner-mapping.csv.')
    $lines.Add('Copy-Item -LiteralPath $draftPath -Destination $ownerMappingPath -Force')
    $lines.Add('')
    $lines.Add('# Use $ownerMappingPath with Invoke-ShareSurferScan -OwnerMappingPath $ownerMappingPath on the next scan.')

    $lines -join [Environment]::NewLine
}
