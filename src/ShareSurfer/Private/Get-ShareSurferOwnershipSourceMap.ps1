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
