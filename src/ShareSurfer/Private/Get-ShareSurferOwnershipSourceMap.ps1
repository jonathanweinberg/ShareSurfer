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
        [pscustomobject]@{ Field = 'OwnerMail'; Required = $false; Recommended = $false; Synonyms = @('ownermail', 'owner_mail', 'owneremail', 'owner_email', 'dataowneremail', 'data_owner_email') },
        [pscustomobject]@{ Field = 'Project'; Required = $false; Recommended = $false; Synonyms = @('project', 'projectname', 'project_name', 'project name', 'program', 'programname', 'program_name') },
        [pscustomobject]@{ Field = 'ProjectCode'; Required = $false; Recommended = $false; Synonyms = @('projectcode', 'project_code', 'project code', 'programcode', 'program_code', 'chargecode', 'charge_code', 'wbs', 'wbsid') },
        [pscustomobject]@{ Field = 'ProjectDescription'; Required = $false; Recommended = $false; Synonyms = @('projectdescription', 'project_description', 'project description', 'description', 'desc', 'projectsummary', 'project_summary', 'applicationdescription', 'application_description') },
        [pscustomobject]@{ Field = 'GroupName'; Required = $false; Recommended = $false; Synonyms = @('groupname', 'group_name', 'group name', 'securitygroup', 'security_group', 'adgroup', 'ad_group', 'permissiongroup', 'permission_group') },
        [pscustomobject]@{ Field = 'PathPattern'; Required = $false; Recommended = $false; Synonyms = @('pathpattern', 'path_pattern', 'path pattern', 'pathprefix', 'path_prefix', 'path prefix', 'sharepath', 'share_path', 'folderpath', 'folder_path', 'uncpath', 'unc_path') }
    )
}

function Get-ShareSurferOwnershipEnrichmentColumns {
    @(
        'OwnershipKey',
        'MatchStatus',
        'MatchMethod',
        'SourcePaths',
        'SourceRowNumbers',
        'EmployeeId',
        'EmployeeNumber',
        'SamAccountName',
        'UserPrincipalName',
        'Mail',
        'DisplayName',
        'Title',
        'Office',
        'Department',
        'Company',
        'Manager',
        'ManagerLevel1',
        'ManagerLevel2',
        'ManagerLevel3',
        'ManagerLevel1Raw',
        'ManagerLevel2Raw',
        'ManagerLevel3Raw',
        'OBS',
        'AdObsPath',
        'ObsAttribute',
        'BusinessUnit',
        'DataOwner',
        'OwnerMail',
        'Project',
        'ProjectCode',
        'AccountEnabled',
        'DistinguishedName',
        'ForbiddenOuMatched',
        'PotentialServiceAccount',
        'ImportWarnings'
    )
}

function Get-ShareSurferOwnershipSourceTypes {
    @('Identity', 'ObsContext', 'ProjectContext', 'PathOwnership', 'GroupContext', 'Mixed')
}

function Get-ShareSurferOwnershipAuthorityLevels {
    @('Authoritative', 'ReviewerHint', 'ContextOnly', 'Unknown')
}

function Get-ShareSurferOwnershipContextColumns {
    @(
        'ContextId',
        'SourceType',
        'SourcePath',
        'SourceRowNumber',
        'EntityType',
        'EntityKey',
        'EntityLabel',
        'OBS',
        'BusinessUnit',
        'DataOwner',
        'OwnerMail',
        'Project',
        'ProjectCode',
        'ProjectDescription',
        'GroupName',
        'PathPattern',
        'AuthorityLevel',
        'ConfidenceLabel',
        'EvidenceReason',
        'ImportWarnings'
    )
}

function Get-ShareSurferOwnershipRelationshipColumns {
    @(
        'RelationshipId',
        'SourceType',
        'SourcePath',
        'SourceRowNumber',
        'FromType',
        'FromValue',
        'RelationshipType',
        'ToType',
        'ToValue',
        'AuthorityLevel',
        'ConfidenceLabel',
        'EvidenceReason'
    )
}

function Get-ShareSurferOwnershipImportManifestColumns {
    @(
        'SourcePath',
        'SourceType',
        'AuthorityLevel',
        'PrimaryAnchor',
        'MappedFields',
        'RowCount',
        'ContextRowCount',
        'RelationshipRowCount',
        'Warnings'
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

function Get-ShareSurferOwnershipMergeKey {
    param(
        [Parameter(Mandatory = $true)]
        $Row
    )

    foreach ($field in @(Get-ShareSurferOwnershipJoinKeyFields)) {
        $property = $Row.PSObject.Properties[$field]
        if ($null -ne $property -and -not [string]::IsNullOrWhiteSpace([string]$property.Value)) {
            return ('{0}:{1}' -f $field, ([string]$property.Value).Trim().ToLowerInvariant())
        }
    }

    $source = ''
    if ($null -ne $Row.PSObject.Properties['SourcePaths']) {
        $source = [string]$Row.SourcePaths
    }
    $rowNumber = ''
    if ($null -ne $Row.PSObject.Properties['SourceRowNumbers']) {
        $rowNumber = [string]$Row.SourceRowNumbers
    }

    'SourceOnly:{0}:{1}' -f $source.ToLowerInvariant(), $rowNumber
}

function Test-ShareSurferOwnershipStrongJoinKey {
    param(
        [Parameter(Mandatory = $true)]
        $Row
    )

    foreach ($field in @(Get-ShareSurferOwnershipJoinKeyFields)) {
        $property = $Row.PSObject.Properties[$field]
        if ($null -ne $property -and -not [string]::IsNullOrWhiteSpace([string]$property.Value)) {
            return $true
        }
    }

    $false
}

function Get-ShareSurferOwnershipObsMergeKey {
    param(
        [Parameter(Mandatory = $true)]
        $Row
    )

    $obs = ''
    if ($null -ne $Row.PSObject.Properties['OBS']) {
        $obs = [string]$Row.OBS
    }
    if ([string]::IsNullOrWhiteSpace($obs) -and $null -ne $Row.PSObject.Properties['AdObsPath']) {
        $obs = [string]$Row.AdObsPath
    }
    if ([string]::IsNullOrWhiteSpace($obs)) {
        return ''
    }

    'OBS:{0}' -f $obs.Trim().ToLowerInvariant()
}

function Get-ShareSurferOwnershipMappedFieldNames {
    param(
        [Parameter(Mandatory = $true)]
        $FieldMap
    )

    @($FieldMap.PSObject.Properties | Where-Object {
        -not [string]::IsNullOrWhiteSpace([string]$_.Value)
    } | ForEach-Object {
        [string]$_.Name
    })
}

function Get-ShareSurferOwnershipDefaultSourceType {
    param(
        [Parameter(Mandatory = $true)]
        $FieldMap
    )

    $mapped = @(Get-ShareSurferOwnershipMappedFieldNames -FieldMap $FieldMap)
    foreach ($field in @(Get-ShareSurferOwnershipJoinKeyFields)) {
        if ($mapped -contains $field) {
            return 'Identity'
        }
    }
    if (($mapped -contains 'Project' -or $mapped -contains 'ProjectCode' -or $mapped -contains 'ProjectDescription') -and $mapped -contains 'OBS') {
        return 'ProjectContext'
    }
    if ($mapped -contains 'PathPattern') {
        return 'PathOwnership'
    }
    if ($mapped -contains 'GroupName') {
        return 'GroupContext'
    }
    if ($mapped -contains 'OBS') {
        return 'ObsContext'
    }

    'Mixed'
}

function Get-ShareSurferOwnershipDefaultAuthorityLevel {
    param(
        [string] $SourceType = 'Mixed'
    )

    switch ($SourceType) {
        'ObsContext' { 'ReviewerHint'; break }
        'ProjectContext' { 'ReviewerHint'; break }
        'PathOwnership' { 'ReviewerHint'; break }
        'GroupContext' { 'ContextOnly'; break }
        'Identity' { 'Authoritative'; break }
        default { 'Unknown' }
    }
}

function Get-ShareSurferOwnershipDefaultPrimaryAnchor {
    param(
        [Parameter(Mandatory = $true)]
        $FieldMap,

        [string] $SourceType = 'Mixed'
    )

    $mapped = @(Get-ShareSurferOwnershipMappedFieldNames -FieldMap $FieldMap)
    foreach ($candidate in @('EmployeeId', 'EmployeeNumber', 'SamAccountName', 'UserPrincipalName', 'Mail')) {
        if ($mapped -contains $candidate) {
            return $candidate
        }
    }

    switch ($SourceType) {
        'ProjectContext' {
            foreach ($candidate in @('ProjectCode', 'Project', 'OBS')) {
                if ($mapped -contains $candidate) { return $candidate }
            }
        }
        'PathOwnership' {
            foreach ($candidate in @('PathPattern', 'OBS', 'DataOwner')) {
                if ($mapped -contains $candidate) { return $candidate }
            }
        }
        'GroupContext' {
            foreach ($candidate in @('GroupName', 'OBS', 'BusinessUnit')) {
                if ($mapped -contains $candidate) { return $candidate }
            }
        }
        default {
            foreach ($candidate in @('OBS', 'BusinessUnit', 'DataOwner', 'ProjectCode', 'Project', 'GroupName', 'PathPattern')) {
                if ($mapped -contains $candidate) { return $candidate }
            }
        }
    }

    ''
}

function New-ShareSurferOwnershipSourceProfile {
    param(
        [Parameter(Mandatory = $true)]
        [string] $SourcePath,

        [Parameter(Mandatory = $true)]
        $FieldMap,

        [string] $SourceType = '',

        [string] $AuthorityLevel = '',

        [string] $PrimaryAnchor = '',

        [string[]] $Warnings = @()
    )

    $validSourceTypes = @(Get-ShareSurferOwnershipSourceTypes)
    $validAuthorityLevels = @(Get-ShareSurferOwnershipAuthorityLevels)
    if ([string]::IsNullOrWhiteSpace($SourceType)) {
        $SourceType = Get-ShareSurferOwnershipDefaultSourceType -FieldMap $FieldMap
    }
    if ($validSourceTypes -notcontains $SourceType) {
        $Warnings += "Unsupported SourceType '$SourceType'; using Mixed."
        $SourceType = 'Mixed'
    }
    if ([string]::IsNullOrWhiteSpace($AuthorityLevel)) {
        $AuthorityLevel = Get-ShareSurferOwnershipDefaultAuthorityLevel -SourceType $SourceType
    }
    if ($validAuthorityLevels -notcontains $AuthorityLevel) {
        $Warnings += "Unsupported AuthorityLevel '$AuthorityLevel'; using Unknown."
        $AuthorityLevel = 'Unknown'
    }
    if ([string]::IsNullOrWhiteSpace($PrimaryAnchor)) {
        $PrimaryAnchor = Get-ShareSurferOwnershipDefaultPrimaryAnchor -FieldMap $FieldMap -SourceType $SourceType
    }

    [pscustomobject]@{
        SourcePath = $SourcePath
        SourceType = $SourceType
        AuthorityLevel = $AuthorityLevel
        PrimaryAnchor = $PrimaryAnchor
        MappedFields = (@(Get-ShareSurferOwnershipMappedFieldNames -FieldMap $FieldMap) -join '; ')
        Warnings = (@($Warnings | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) }) -join '; ')
    }
}

function ConvertTo-ShareSurferOwnershipSourceProfileMap {
    param(
        [object[]] $SourceProfiles = @()
    )

    $map = @{}
    foreach ($profile in @($SourceProfiles)) {
        if ($null -eq $profile -or $null -eq $profile.PSObject.Properties['SourcePath']) {
            continue
        }
        $path = [string]$profile.SourcePath
        if ([string]::IsNullOrWhiteSpace($path)) {
            continue
        }
        $map[$path.ToLowerInvariant()] = $profile
    }

    $map
}

function Get-ShareSurferOwnershipSavedSourceProfile {
    param(
        [hashtable] $ProfileMap = @{},

        [string] $SourcePath = ''
    )

    if ([string]::IsNullOrWhiteSpace($SourcePath)) {
        return $null
    }
    $key = $SourcePath.ToLowerInvariant()
    if ($ProfileMap.ContainsKey($key)) {
        return $ProfileMap[$key]
    }

    $null
}

function New-ShareSurferOwnershipContextRecord {
    param(
        [string] $SourceType = 'Mixed',
        [string] $SourcePath = '',
        [int] $SourceRowNumber = 0,
        [string] $EntityType = '',
        [string] $EntityKey = '',
        [string] $EntityLabel = '',
        [string] $OBS = '',
        [string] $BusinessUnit = '',
        [string] $DataOwner = '',
        [string] $OwnerMail = '',
        [string] $Project = '',
        [string] $ProjectCode = '',
        [string] $ProjectDescription = '',
        [string] $GroupName = '',
        [string] $PathPattern = '',
        [string] $AuthorityLevel = 'Unknown',
        [string] $ConfidenceLabel = 'NeedsReview',
        [string] $EvidenceReason = '',
        [string] $ImportWarnings = ''
    )

    [pscustomobject]@{
        ContextId = ''
        SourceType = $SourceType
        SourcePath = $SourcePath
        SourceRowNumber = [string]$SourceRowNumber
        EntityType = $EntityType
        EntityKey = $EntityKey
        EntityLabel = $EntityLabel
        OBS = $OBS
        BusinessUnit = $BusinessUnit
        DataOwner = $DataOwner
        OwnerMail = $OwnerMail
        Project = $Project
        ProjectCode = $ProjectCode
        ProjectDescription = $ProjectDescription
        GroupName = $GroupName
        PathPattern = $PathPattern
        AuthorityLevel = $AuthorityLevel
        ConfidenceLabel = $ConfidenceLabel
        EvidenceReason = $EvidenceReason
        ImportWarnings = $ImportWarnings
    }
}

function New-ShareSurferOwnershipRelationshipRecord {
    param(
        [string] $SourceType = 'Mixed',
        [string] $SourcePath = '',
        [int] $SourceRowNumber = 0,
        [string] $FromType = '',
        [string] $FromValue = '',
        [string] $RelationshipType = '',
        [string] $ToType = '',
        [string] $ToValue = '',
        [string] $AuthorityLevel = 'Unknown',
        [string] $ConfidenceLabel = 'NeedsReview',
        [string] $EvidenceReason = ''
    )

    if ([string]::IsNullOrWhiteSpace($FromValue) -or [string]::IsNullOrWhiteSpace($ToValue)) {
        return $null
    }

    [pscustomobject]@{
        RelationshipId = ''
        SourceType = $SourceType
        SourcePath = $SourcePath
        SourceRowNumber = [string]$SourceRowNumber
        FromType = $FromType
        FromValue = $FromValue
        RelationshipType = $RelationshipType
        ToType = $ToType
        ToValue = $ToValue
        AuthorityLevel = $AuthorityLevel
        ConfidenceLabel = $ConfidenceLabel
        EvidenceReason = $EvidenceReason
    }
}

function Get-ShareSurferOwnershipContextValueSet {
    param(
        [Parameter(Mandatory = $true)]
        $SourceRow,

        [Parameter(Mandatory = $true)]
        $FieldMap
    )

    [pscustomobject]@{
        EmployeeId = Get-ShareSurferOwnershipMappedValue -Row $SourceRow -FieldMap $FieldMap -Field 'EmployeeId'
        EmployeeNumber = Get-ShareSurferOwnershipMappedValue -Row $SourceRow -FieldMap $FieldMap -Field 'EmployeeNumber'
        SamAccountName = Get-ShareSurferOwnershipMappedValue -Row $SourceRow -FieldMap $FieldMap -Field 'SamAccountName'
        UserPrincipalName = Get-ShareSurferOwnershipMappedValue -Row $SourceRow -FieldMap $FieldMap -Field 'UserPrincipalName'
        Mail = Get-ShareSurferOwnershipMappedValue -Row $SourceRow -FieldMap $FieldMap -Field 'Mail'
        OBS = Get-ShareSurferOwnershipMappedValue -Row $SourceRow -FieldMap $FieldMap -Field 'OBS'
        BusinessUnit = Get-ShareSurferOwnershipMappedValue -Row $SourceRow -FieldMap $FieldMap -Field 'BusinessUnit'
        DataOwner = Get-ShareSurferOwnershipMappedValue -Row $SourceRow -FieldMap $FieldMap -Field 'DataOwner'
        OwnerMail = Get-ShareSurferOwnershipMappedValue -Row $SourceRow -FieldMap $FieldMap -Field 'OwnerMail'
        Project = Get-ShareSurferOwnershipMappedValue -Row $SourceRow -FieldMap $FieldMap -Field 'Project'
        ProjectCode = Get-ShareSurferOwnershipMappedValue -Row $SourceRow -FieldMap $FieldMap -Field 'ProjectCode'
        ProjectDescription = Get-ShareSurferOwnershipMappedValue -Row $SourceRow -FieldMap $FieldMap -Field 'ProjectDescription'
        GroupName = Get-ShareSurferOwnershipMappedValue -Row $SourceRow -FieldMap $FieldMap -Field 'GroupName'
        PathPattern = Get-ShareSurferOwnershipMappedValue -Row $SourceRow -FieldMap $FieldMap -Field 'PathPattern'
    }
}

function New-ShareSurferOwnershipContextRows {
    param(
        [Parameter(Mandatory = $true)]
        $SourceRow,

        [Parameter(Mandatory = $true)]
        $FieldMap,

        [Parameter(Mandatory = $true)]
        $SourceProfile,

        [Parameter(Mandatory = $true)]
        [string] $SourcePath,

        [Parameter(Mandatory = $true)]
        [int] $SourceRowNumber
    )

    $values = Get-ShareSurferOwnershipContextValueSet -SourceRow $SourceRow -FieldMap $FieldMap
    $rows = New-Object System.Collections.Generic.List[object]
    $sourceType = [string]$SourceProfile.SourceType
    $authorityLevel = [string]$SourceProfile.AuthorityLevel
    $confidence = switch ($sourceType) {
        'Identity' { 'DirectIdentityMatch'; break }
        'ObsContext' { 'ObsContextMatch'; break }
        'ProjectContext' { 'ProjectContextMatch'; break }
        'PathOwnership' { 'PathMapping'; break }
        'GroupContext' { 'GroupContextMatch'; break }
        default { 'NeedsReview' }
    }

    if (-not [string]::IsNullOrWhiteSpace([string]$values.ProjectCode) -or -not [string]::IsNullOrWhiteSpace([string]$values.Project)) {
        $key = if (-not [string]::IsNullOrWhiteSpace([string]$values.ProjectCode)) { [string]$values.ProjectCode } else { [string]$values.Project }
        $label = if (-not [string]::IsNullOrWhiteSpace([string]$values.Project)) { [string]$values.Project } else { $key }
        [void]$rows.Add((New-ShareSurferOwnershipContextRecord -SourceType $sourceType -SourcePath $SourcePath -SourceRowNumber $SourceRowNumber -EntityType 'Project' -EntityKey $key -EntityLabel $label -OBS $values.OBS -BusinessUnit $values.BusinessUnit -DataOwner $values.DataOwner -OwnerMail $values.OwnerMail -Project $values.Project -ProjectCode $values.ProjectCode -ProjectDescription $values.ProjectDescription -GroupName $values.GroupName -PathPattern $values.PathPattern -AuthorityLevel $authorityLevel -ConfidenceLabel $confidence -EvidenceReason 'Source row describes a project, program, application, or initiative.'))
    }

    if (-not [string]::IsNullOrWhiteSpace([string]$values.OBS)) {
        [void]$rows.Add((New-ShareSurferOwnershipContextRecord -SourceType $sourceType -SourcePath $SourcePath -SourceRowNumber $SourceRowNumber -EntityType 'OBS' -EntityKey $values.OBS -EntityLabel $values.OBS -OBS $values.OBS -BusinessUnit $values.BusinessUnit -DataOwner $values.DataOwner -OwnerMail $values.OwnerMail -Project $values.Project -ProjectCode $values.ProjectCode -ProjectDescription $values.ProjectDescription -GroupName $values.GroupName -PathPattern $values.PathPattern -AuthorityLevel $authorityLevel -ConfidenceLabel $confidence -EvidenceReason 'Source row provides OBS/OID or business-structure context.'))
    }

    if (-not [string]::IsNullOrWhiteSpace([string]$values.PathPattern)) {
        [void]$rows.Add((New-ShareSurferOwnershipContextRecord -SourceType $sourceType -SourcePath $SourcePath -SourceRowNumber $SourceRowNumber -EntityType 'Path' -EntityKey $values.PathPattern -EntityLabel $values.PathPattern -OBS $values.OBS -BusinessUnit $values.BusinessUnit -DataOwner $values.DataOwner -OwnerMail $values.OwnerMail -Project $values.Project -ProjectCode $values.ProjectCode -ProjectDescription $values.ProjectDescription -GroupName $values.GroupName -PathPattern $values.PathPattern -AuthorityLevel $authorityLevel -ConfidenceLabel $confidence -EvidenceReason 'Source row provides path or path-prefix ownership context.'))
    }

    if (-not [string]::IsNullOrWhiteSpace([string]$values.GroupName)) {
        [void]$rows.Add((New-ShareSurferOwnershipContextRecord -SourceType $sourceType -SourcePath $SourcePath -SourceRowNumber $SourceRowNumber -EntityType 'Group' -EntityKey $values.GroupName -EntityLabel $values.GroupName -OBS $values.OBS -BusinessUnit $values.BusinessUnit -DataOwner $values.DataOwner -OwnerMail $values.OwnerMail -Project $values.Project -ProjectCode $values.ProjectCode -ProjectDescription $values.ProjectDescription -GroupName $values.GroupName -PathPattern $values.PathPattern -AuthorityLevel $authorityLevel -ConfidenceLabel $confidence -EvidenceReason 'Source row provides security-group context.'))
    }

    if ($rows.Count -eq 0) {
        $fallbackKey = if (-not [string]::IsNullOrWhiteSpace([string]$values.DataOwner)) { [string]$values.DataOwner } elseif (-not [string]::IsNullOrWhiteSpace([string]$values.BusinessUnit)) { [string]$values.BusinessUnit } else { 'SourceRow:{0}' -f $SourceRowNumber }
        [void]$rows.Add((New-ShareSurferOwnershipContextRecord -SourceType $sourceType -SourcePath $SourcePath -SourceRowNumber $SourceRowNumber -EntityType 'SourceRow' -EntityKey $fallbackKey -EntityLabel $fallbackKey -OBS $values.OBS -BusinessUnit $values.BusinessUnit -DataOwner $values.DataOwner -OwnerMail $values.OwnerMail -Project $values.Project -ProjectCode $values.ProjectCode -ProjectDescription $values.ProjectDescription -GroupName $values.GroupName -PathPattern $values.PathPattern -AuthorityLevel $authorityLevel -ConfidenceLabel 'NeedsReview' -EvidenceReason 'Source row had useful ownership context but no strong typed anchor.'))
    }

    @($rows.ToArray())
}

function New-ShareSurferOwnershipRelationshipRows {
    param(
        [Parameter(Mandatory = $true)]
        $SourceRow,

        [Parameter(Mandatory = $true)]
        $FieldMap,

        [Parameter(Mandatory = $true)]
        $SourceProfile,

        [Parameter(Mandatory = $true)]
        [string] $SourcePath,

        [Parameter(Mandatory = $true)]
        [int] $SourceRowNumber
    )

    $values = Get-ShareSurferOwnershipContextValueSet -SourceRow $SourceRow -FieldMap $FieldMap
    $rows = New-Object System.Collections.Generic.List[object]
    $sourceType = [string]$SourceProfile.SourceType
    $authorityLevel = [string]$SourceProfile.AuthorityLevel
    $projectKey = if (-not [string]::IsNullOrWhiteSpace([string]$values.ProjectCode)) { [string]$values.ProjectCode } else { [string]$values.Project }
    $confidence = switch ($sourceType) {
        'ObsContext' { 'ObsContextMatch'; break }
        'ProjectContext' { 'ProjectContextMatch'; break }
        'PathOwnership' { 'PathMapping'; break }
        'GroupContext' { 'GroupContextMatch'; break }
        default { 'NeedsReview' }
    }

    foreach ($candidate in @(
        (New-ShareSurferOwnershipRelationshipRecord -SourceType $sourceType -SourcePath $SourcePath -SourceRowNumber $SourceRowNumber -FromType 'Project' -FromValue $projectKey -RelationshipType 'BelongsTo' -ToType 'OBS' -ToValue $values.OBS -AuthorityLevel $authorityLevel -ConfidenceLabel $confidence -EvidenceReason 'Project source linked project or project code to OBS.'),
        (New-ShareSurferOwnershipRelationshipRecord -SourceType $sourceType -SourcePath $SourcePath -SourceRowNumber $SourceRowNumber -FromType 'OBS' -FromValue $values.OBS -RelationshipType 'PartOf' -ToType 'BusinessUnit' -ToValue $values.BusinessUnit -AuthorityLevel $authorityLevel -ConfidenceLabel 'ObsContextMatch' -EvidenceReason 'Source supplied BusinessUnit for OBS.'),
        (New-ShareSurferOwnershipRelationshipRecord -SourceType $sourceType -SourcePath $SourcePath -SourceRowNumber $SourceRowNumber -FromType 'OBS' -FromValue $values.OBS -RelationshipType 'ReviewedBy' -ToType 'DataOwner' -ToValue $values.DataOwner -AuthorityLevel $authorityLevel -ConfidenceLabel 'ReviewerHint' -EvidenceReason 'Source supplied DataOwner for OBS.'),
        (New-ShareSurferOwnershipRelationshipRecord -SourceType $sourceType -SourcePath $SourcePath -SourceRowNumber $SourceRowNumber -FromType 'Project' -FromValue $projectKey -RelationshipType 'ReviewedBy' -ToType 'DataOwner' -ToValue $values.DataOwner -AuthorityLevel $authorityLevel -ConfidenceLabel 'ReviewerHint' -EvidenceReason 'Source supplied DataOwner for project context.'),
        (New-ShareSurferOwnershipRelationshipRecord -SourceType $sourceType -SourcePath $SourcePath -SourceRowNumber $SourceRowNumber -FromType 'Path' -FromValue $values.PathPattern -RelationshipType 'ReviewedBy' -ToType 'DataOwner' -ToValue $values.DataOwner -AuthorityLevel $authorityLevel -ConfidenceLabel 'PathMapping' -EvidenceReason 'Source supplied DataOwner for a path or path prefix.'),
        (New-ShareSurferOwnershipRelationshipRecord -SourceType $sourceType -SourcePath $SourcePath -SourceRowNumber $SourceRowNumber -FromType 'Group' -FromValue $values.GroupName -RelationshipType 'RelatedTo' -ToType 'OBS' -ToValue $values.OBS -AuthorityLevel $authorityLevel -ConfidenceLabel 'GroupContextMatch' -EvidenceReason 'Source linked security group context to OBS.')
    )) {
        if ($null -ne $candidate) {
            [void]$rows.Add($candidate)
        }
    }

    @($rows.ToArray())
}

function Add-ShareSurferDelimitedValue {
    param(
        [string] $Existing = '',

        [string] $Value = '',

        [string] $Delimiter = '; '
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $Existing
    }

    $values = New-Object System.Collections.Generic.List[string]
    foreach ($item in @($Existing -split [regex]::Escape($Delimiter))) {
        if (-not [string]::IsNullOrWhiteSpace($item)) {
            $values.Add($item.Trim())
        }
    }

    $candidate = $Value.Trim()
    if (-not (@($values) | Where-Object { $_.ToLowerInvariant() -eq $candidate.ToLowerInvariant() })) {
        $values.Add($candidate)
    }

    (@($values) -join $Delimiter)
}

function Merge-ShareSurferOwnershipEnrichmentRow {
    param(
        [Parameter(Mandatory = $true)]
        $Existing,

        [Parameter(Mandatory = $true)]
        $Incoming
    )

    foreach ($column in @(Get-ShareSurferOwnershipEnrichmentColumns)) {
        if ($column -eq 'OwnershipKey') {
            continue
        }

        $incomingProperty = $Incoming.PSObject.Properties[$column]
        if ($null -eq $incomingProperty -or $null -eq $incomingProperty.Value -or [string]::IsNullOrWhiteSpace([string]$incomingProperty.Value)) {
            continue
        }

        if ($column -in @('SourcePaths', 'SourceRowNumbers', 'ImportWarnings')) {
            $existingValue = ''
            if ($null -ne $Existing.PSObject.Properties[$column]) {
                $existingValue = [string]$Existing.PSObject.Properties[$column].Value
            }
            $Existing.PSObject.Properties[$column].Value = Add-ShareSurferDelimitedValue -Existing $existingValue -Value ([string]$incomingProperty.Value)
            continue
        }

        $existingProperty = $Existing.PSObject.Properties[$column]
        if ($null -ne $existingProperty -and [string]::IsNullOrWhiteSpace([string]$existingProperty.Value)) {
            $existingProperty.Value = [string]$incomingProperty.Value
        }
    }

    $Existing
}

function New-ShareSurferOwnershipEnrichmentRow {
    param(
        [Parameter(Mandatory = $true)]
        $SourceRow,

        [Parameter(Mandatory = $true)]
        $FieldMap,

        [Parameter(Mandatory = $true)]
        [string] $SourcePath,

        [Parameter(Mandatory = $true)]
        [int] $SourceRowNumber,

        [string] $ObsAttribute = 'extensionAttribute10'
    )

    $employeeId = Get-ShareSurferOwnershipMappedValue -Row $SourceRow -FieldMap $FieldMap -Field 'EmployeeId'
    $employeeNumber = Get-ShareSurferOwnershipMappedValue -Row $SourceRow -FieldMap $FieldMap -Field 'EmployeeNumber'
    $samAccountName = Get-ShareSurferOwnershipMappedValue -Row $SourceRow -FieldMap $FieldMap -Field 'SamAccountName'
    $userPrincipalName = Get-ShareSurferOwnershipMappedValue -Row $SourceRow -FieldMap $FieldMap -Field 'UserPrincipalName'
    $mail = Get-ShareSurferOwnershipMappedValue -Row $SourceRow -FieldMap $FieldMap -Field 'Mail'
    $obs = Get-ShareSurferOwnershipMappedValue -Row $SourceRow -FieldMap $FieldMap -Field 'OBS'

    $warnings = New-Object System.Collections.Generic.List[string]
    if ([string]::IsNullOrWhiteSpace($employeeId) -and [string]::IsNullOrWhiteSpace($employeeNumber) -and [string]::IsNullOrWhiteSpace($samAccountName) -and [string]::IsNullOrWhiteSpace($userPrincipalName) -and [string]::IsNullOrWhiteSpace($mail)) {
        $warnings.Add('NoJoinKey')
    }

    $row = [pscustomobject]@{
        OwnershipKey = ''
        MatchStatus = 'SourceOnly'
        MatchMethod = ''
        SourcePaths = $SourcePath
        SourceRowNumbers = [string]$SourceRowNumber
        EmployeeId = $employeeId
        EmployeeNumber = $employeeNumber
        SamAccountName = $samAccountName
        UserPrincipalName = $userPrincipalName
        Mail = $mail
        DisplayName = Get-ShareSurferOwnershipMappedValue -Row $SourceRow -FieldMap $FieldMap -Field 'DisplayName'
        Title = Get-ShareSurferOwnershipMappedValue -Row $SourceRow -FieldMap $FieldMap -Field 'Title'
        Office = Get-ShareSurferOwnershipMappedValue -Row $SourceRow -FieldMap $FieldMap -Field 'Office'
        Department = Get-ShareSurferOwnershipMappedValue -Row $SourceRow -FieldMap $FieldMap -Field 'Department'
        Company = Get-ShareSurferOwnershipMappedValue -Row $SourceRow -FieldMap $FieldMap -Field 'Company'
        Manager = ''
        ManagerLevel1 = Get-ShareSurferOwnershipMappedValue -Row $SourceRow -FieldMap $FieldMap -Field 'ManagerMail'
        ManagerLevel2 = Get-ShareSurferOwnershipMappedValue -Row $SourceRow -FieldMap $FieldMap -Field 'ManagerLevel2Mail'
        ManagerLevel3 = Get-ShareSurferOwnershipMappedValue -Row $SourceRow -FieldMap $FieldMap -Field 'ManagerLevel3Mail'
        ManagerLevel1Raw = ''
        ManagerLevel2Raw = ''
        ManagerLevel3Raw = ''
        OBS = $obs
        AdObsPath = ''
        ObsAttribute = $ObsAttribute
        BusinessUnit = Get-ShareSurferOwnershipMappedValue -Row $SourceRow -FieldMap $FieldMap -Field 'BusinessUnit'
        DataOwner = Get-ShareSurferOwnershipMappedValue -Row $SourceRow -FieldMap $FieldMap -Field 'DataOwner'
        OwnerMail = Get-ShareSurferOwnershipMappedValue -Row $SourceRow -FieldMap $FieldMap -Field 'OwnerMail'
        Project = Get-ShareSurferOwnershipMappedValue -Row $SourceRow -FieldMap $FieldMap -Field 'Project'
        ProjectCode = Get-ShareSurferOwnershipMappedValue -Row $SourceRow -FieldMap $FieldMap -Field 'ProjectCode'
        AccountEnabled = ''
        DistinguishedName = ''
        ForbiddenOuMatched = ''
        PotentialServiceAccount = [string]([string]::IsNullOrWhiteSpace($obs) -and [string]::IsNullOrWhiteSpace($employeeId) -and [string]::IsNullOrWhiteSpace($employeeNumber))
        ImportWarnings = (@($warnings) -join '; ')
    }
    $row.OwnershipKey = Get-ShareSurferOwnershipMergeKey -Row $row
    $row
}

function Update-ShareSurferOwnershipRowFromDirectory {
    param(
        [Parameter(Mandatory = $true)]
        $Row,

        [Parameter(Mandatory = $true)]
        $LookupResult
    )

    if ($null -eq $LookupResult) {
        return $Row
    }

    if ($null -ne $LookupResult.PSObject.Properties['Status'] -and -not [string]::IsNullOrWhiteSpace([string]$LookupResult.Status)) {
        $Row.MatchStatus = [string]$LookupResult.Status
    }
    if ($null -ne $LookupResult.PSObject.Properties['MatchMethod']) {
        $Row.MatchMethod = [string]$LookupResult.MatchMethod
    }
    if ($null -ne $LookupResult.PSObject.Properties['ForbiddenOuMatched']) {
        $Row.ForbiddenOuMatched = [string]$LookupResult.ForbiddenOuMatched
    }
    if ($null -ne $LookupResult.PSObject.Properties['Message'] -and -not [string]::IsNullOrWhiteSpace([string]$LookupResult.Message)) {
        $Row.ImportWarnings = Add-ShareSurferDelimitedValue -Existing ([string]$Row.ImportWarnings) -Value ([string]$LookupResult.Message)
    }

    if ($null -eq $LookupResult.PSObject.Properties['IdentityRecord'] -or $null -eq $LookupResult.IdentityRecord) {
        return $Row
    }

    $identity = $LookupResult.IdentityRecord
    foreach ($pair in @(
        @('SamAccountName', 'SamAccountName'),
        @('UserPrincipalName', 'UserPrincipalName'),
        @('Mail', 'Mail'),
        @('DisplayName', 'DisplayName'),
        @('Title', 'Title'),
        @('Office', 'Office'),
        @('Department', 'Department'),
        @('Company', 'Company'),
        @('Manager', 'Manager'),
        @('ManagerLevel1', 'ManagerLevel1'),
        @('ManagerLevel2', 'ManagerLevel2'),
        @('ManagerLevel3', 'ManagerLevel3'),
        @('ManagerLevel1', 'ManagerLevel1Raw'),
        @('ManagerLevel2', 'ManagerLevel2Raw'),
        @('ManagerLevel3', 'ManagerLevel3Raw'),
        @('AccountEnabled', 'AccountEnabled'),
        @('DistinguishedName', 'DistinguishedName')
    )) {
        $sourceProperty = $identity.PSObject.Properties[$pair[0]]
        if ($null -eq $sourceProperty -or $null -eq $sourceProperty.Value -or [string]::IsNullOrWhiteSpace([string]$sourceProperty.Value)) {
            continue
        }

        $targetProperty = $Row.PSObject.Properties[$pair[1]]
        if ($null -ne $targetProperty -and [string]::IsNullOrWhiteSpace([string]$targetProperty.Value)) {
            $targetProperty.Value = [string]$sourceProperty.Value
        }
    }

    if ($null -ne $identity.PSObject.Properties['EmployeeId'] -and [string]::IsNullOrWhiteSpace([string]$Row.EmployeeId)) {
        $Row.EmployeeId = [string]$identity.EmployeeId
    }
    if ($null -ne $identity.PSObject.Properties['EmployeeNumber'] -and [string]::IsNullOrWhiteSpace([string]$Row.EmployeeNumber)) {
        $Row.EmployeeNumber = [string]$identity.EmployeeNumber
    }
    if ($null -ne $identity.PSObject.Properties['ObsPath'] -and -not [string]::IsNullOrWhiteSpace([string]$identity.ObsPath)) {
        $Row.AdObsPath = [string]$identity.ObsPath
        if ([string]::IsNullOrWhiteSpace([string]$Row.OBS)) {
            $Row.OBS = [string]$identity.ObsPath
        }
    }

    $Row.PotentialServiceAccount = [string]([string]::IsNullOrWhiteSpace([string]$Row.OBS) -and [string]::IsNullOrWhiteSpace([string]$Row.AdObsPath) -and [string]::IsNullOrWhiteSpace([string]$Row.EmployeeId) -and [string]::IsNullOrWhiteSpace([string]$Row.EmployeeNumber))
    $Row.OwnershipKey = Get-ShareSurferOwnershipMergeKey -Row $Row
    $Row
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

function ConvertTo-ShareSurferPowerShellArrayLiteral {
    param(
        [string[]] $Values = @()
    )

    $items = @($Values | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object {
        ConvertTo-ShareSurferPowerShellLiteral -Value ([string]$_)
    })

    if ($items.Count -eq 0) {
        return '@()'
    }

    '@({0})' -f ($items -join ', ')
}

function Write-ShareSurferReusableCommandFile {
    param(
        [string] $Path = '',

        [Parameter(Mandatory = $true)]
        [string] $CommandText,

        [switch] $NoCreateMissingFolders,

        [switch] $Quiet
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return ''
    }

    Ensure-ShareSurferLocalFileParentDirectory -Path $Path -Purpose 'reusable command output' -NoCreateMissingFolders:$NoCreateMissingFolders -Quiet:$Quiet | Out-Null

    Set-Content -LiteralPath $Path -Value $CommandText -Encoding UTF8
    $Path
}

function Get-ShareSurferDefinitionArrayProperty {
    param(
        [Parameter(Mandatory = $true)]
        $Definition,

        [Parameter(Mandatory = $true)]
        [string] $Name
    )

    if ($null -eq $Definition.PSObject.Properties[$Name] -or $null -eq $Definition.PSObject.Properties[$Name].Value) {
        return @()
    }

    @($Definition.PSObject.Properties[$Name].Value | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | ForEach-Object { [string]$_ })
}

function Get-ShareSurferDefinitionStringProperty {
    param(
        [Parameter(Mandatory = $true)]
        $Definition,

        [Parameter(Mandatory = $true)]
        [string] $Name
    )

    if ($null -eq $Definition.PSObject.Properties[$Name] -or $null -eq $Definition.PSObject.Properties[$Name].Value) {
        return ''
    }

    [string]$Definition.PSObject.Properties[$Name].Value
}

function Get-ShareSurferDefinitionBoolProperty {
    param(
        [Parameter(Mandatory = $true)]
        $Definition,

        [Parameter(Mandatory = $true)]
        [string] $Name
    )

    if ($null -eq $Definition.PSObject.Properties[$Name] -or $null -eq $Definition.PSObject.Properties[$Name].Value) {
        return $false
    }

    [bool]$Definition.PSObject.Properties[$Name].Value
}

function Get-ShareSurferDefinitionObjectArrayProperty {
    param(
        [Parameter(Mandatory = $true)]
        $Definition,

        [Parameter(Mandatory = $true)]
        [string] $Name
    )

    if ($null -eq $Definition.PSObject.Properties[$Name] -or $null -eq $Definition.PSObject.Properties[$Name].Value) {
        return @()
    }

    @($Definition.PSObject.Properties[$Name].Value)
}

function Get-ShareSurferOwnershipImportDefinition {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Ownership import definition was not found: $Path"
    }

    $definition = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
    $version = Get-ShareSurferDefinitionStringProperty -Definition $definition -Name 'version'
    if ([string]::IsNullOrWhiteSpace($version) -or [int]$version -ne 1) {
        throw "Unsupported ownership import definition version in $Path"
    }

    [pscustomobject]@{
        Version = [int]$version
        SelectedCsvPaths = @(Get-ShareSurferDefinitionArrayProperty -Definition $definition -Name 'selectedCsvPaths')
        SourceFolder = Get-ShareSurferDefinitionStringProperty -Definition $definition -Name 'sourceFolder'
        OutputPath = Get-ShareSurferDefinitionStringProperty -Definition $definition -Name 'outputPath'
        MappingProfilePaths = @(Get-ShareSurferDefinitionArrayProperty -Definition $definition -Name 'mappingProfilePaths')
        ObsHeader = Get-ShareSurferDefinitionStringProperty -Definition $definition -Name 'obsHeader'
        ObsAttribute = Get-ShareSurferDefinitionStringProperty -Definition $definition -Name 'obsAttribute'
        AdLookupMode = Get-ShareSurferDefinitionStringProperty -Definition $definition -Name 'adLookupMode'
        ForbiddenOus = @(Get-ShareSurferDefinitionArrayProperty -Definition $definition -Name 'forbiddenOus')
        IncludeContextGraph = Get-ShareSurferDefinitionBoolProperty -Definition $definition -Name 'includeContextGraph'
        ContextOutputPath = Get-ShareSurferDefinitionStringProperty -Definition $definition -Name 'contextOutputPath'
        RelationshipOutputPath = Get-ShareSurferDefinitionStringProperty -Definition $definition -Name 'relationshipOutputPath'
        ManifestOutputPath = Get-ShareSurferDefinitionStringProperty -Definition $definition -Name 'manifestOutputPath'
        SourceProfiles = @(Get-ShareSurferDefinitionObjectArrayProperty -Definition $definition -Name 'sourceProfiles' | ForEach-Object {
            [pscustomobject]@{
                SourcePath = if ($null -ne $_.PSObject.Properties['sourcePath']) { [string]$_.sourcePath } elseif ($null -ne $_.PSObject.Properties['SourcePath']) { [string]$_.SourcePath } else { '' }
                SourceType = if ($null -ne $_.PSObject.Properties['sourceType']) { [string]$_.sourceType } elseif ($null -ne $_.PSObject.Properties['SourceType']) { [string]$_.SourceType } else { 'Mixed' }
                AuthorityLevel = if ($null -ne $_.PSObject.Properties['authorityLevel']) { [string]$_.authorityLevel } elseif ($null -ne $_.PSObject.Properties['AuthorityLevel']) { [string]$_.AuthorityLevel } else { 'Unknown' }
                PrimaryAnchor = if ($null -ne $_.PSObject.Properties['primaryAnchor']) { [string]$_.primaryAnchor } elseif ($null -ne $_.PSObject.Properties['PrimaryAnchor']) { [string]$_.PrimaryAnchor } else { '' }
                MappedFields = if ($null -ne $_.PSObject.Properties['mappedFields']) { [string]$_.mappedFields } elseif ($null -ne $_.PSObject.Properties['MappedFields']) { [string]$_.MappedFields } else { '' }
                Warnings = if ($null -ne $_.PSObject.Properties['warnings']) { [string]$_.warnings } elseif ($null -ne $_.PSObject.Properties['Warnings']) { [string]$_.Warnings } else { '' }
            }
        })
        CreatedBy = Get-ShareSurferDefinitionStringProperty -Definition $definition -Name 'createdBy'
        CreatedAt = Get-ShareSurferDefinitionStringProperty -Definition $definition -Name 'createdAt'
        UpdatedAt = Get-ShareSurferDefinitionStringProperty -Definition $definition -Name 'updatedAt'
    }
}

function Get-ShareSurferCurrentOperatorName {
    try {
        $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
        if ($null -ne $identity -and -not [string]::IsNullOrWhiteSpace([string]$identity.Name)) {
            return [string]$identity.Name
        }
    }
    catch {
    }

    $userName = [System.Environment]::UserName
    if ([string]::IsNullOrWhiteSpace($userName)) {
        $userName = $env:USERNAME
    }
    if ([string]::IsNullOrWhiteSpace($userName)) {
        $userName = $env:USER
    }

    if ([string]::IsNullOrWhiteSpace($userName)) {
        return 'unknown'
    }

    $domainName = [System.Environment]::UserDomainName
    if (-not [string]::IsNullOrWhiteSpace($domainName) -and $domainName -ne $userName) {
        return ('{0}\{1}' -f $domainName, $userName)
    }

    [string]$userName
}

function Export-ShareSurferOwnershipImportDefinition {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $Path,

        [string[]] $SelectedCsvPaths = @(),

        [string] $SourceFolder = '',

        [string] $OutputPath = '',

        [string[]] $MappingProfilePaths = @(),

        [string] $ObsHeader = '',

        [string] $ObsAttribute = 'extensionAttribute10',

        [string] $AdLookupMode = 'Auto',

        [string[]] $ForbiddenOu = @(),

        [bool] $IncludeContextGraph = $false,

        [string] $ContextOutputPath = '',

        [string] $RelationshipOutputPath = '',

        [string] $ManifestOutputPath = '',

        [object[]] $SourceProfiles = @(),

        [switch] $Force
    )

    if ((Test-Path -LiteralPath $Path) -and -not $Force) {
        throw "Ownership import definition already exists: $Path. Use -Force to overwrite it."
    }

    $parent = Split-Path -Parent $Path
    if (-not [string]::IsNullOrWhiteSpace($parent) -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    $now = [DateTimeOffset]::UtcNow.ToString('o')
    $createdBy = Get-ShareSurferCurrentOperatorName
    $createdAt = $now
    if (Test-Path -LiteralPath $Path -PathType Leaf) {
        try {
            $existing = Get-ShareSurferOwnershipImportDefinition -Path $Path
            if (-not [string]::IsNullOrWhiteSpace([string]$existing.CreatedBy)) {
                $createdBy = [string]$existing.CreatedBy
            }
            if (-not [string]::IsNullOrWhiteSpace([string]$existing.CreatedAt)) {
                $createdAt = [string]$existing.CreatedAt
            }
        }
        catch {
        }
    }

    $definition = [ordered]@{
        version = 1
        selectedCsvPaths = @($SelectedCsvPaths | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | ForEach-Object { [string]$_ })
        sourceFolder = $SourceFolder
        outputPath = $OutputPath
        mappingProfilePaths = @($MappingProfilePaths | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | ForEach-Object { [string]$_ })
        obsHeader = $ObsHeader
        obsAttribute = $ObsAttribute
        adLookupMode = $AdLookupMode
        forbiddenOus = @($ForbiddenOu | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | ForEach-Object { [string]$_ })
        includeContextGraph = [bool]$IncludeContextGraph
        contextOutputPath = $ContextOutputPath
        relationshipOutputPath = $RelationshipOutputPath
        manifestOutputPath = $ManifestOutputPath
        sourceProfiles = @($SourceProfiles | ForEach-Object {
            [ordered]@{
                sourcePath = if ($null -ne $_.PSObject.Properties['SourcePath']) { [string]$_.SourcePath } else { '' }
                sourceType = if ($null -ne $_.PSObject.Properties['SourceType']) { [string]$_.SourceType } else { 'Mixed' }
                authorityLevel = if ($null -ne $_.PSObject.Properties['AuthorityLevel']) { [string]$_.AuthorityLevel } else { 'Unknown' }
                primaryAnchor = if ($null -ne $_.PSObject.Properties['PrimaryAnchor']) { [string]$_.PrimaryAnchor } else { '' }
                mappedFields = if ($null -ne $_.PSObject.Properties['MappedFields']) { [string]$_.MappedFields } else { '' }
                warnings = if ($null -ne $_.PSObject.Properties['Warnings']) { [string]$_.Warnings } else { '' }
            }
        })
        createdBy = $createdBy
        createdAt = $createdAt
        updatedAt = $now
    }

    Set-Content -LiteralPath $Path -Value ($definition | ConvertTo-Json -Depth 8) -Encoding UTF8
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

function New-ShareSurferOwnershipEnrichmentReusableCommands {
    param(
        [Parameter(Mandatory = $true)]
        [string[]] $SourcePaths,

        [Parameter(Mandatory = $true)]
        [string] $OutputPath,

        [string[]] $MappingProfilePaths = @(),

        [string] $ObsHeader = '',

        [string] $ObsAttribute = 'extensionAttribute10',

        [string] $AdLookupMode = 'Auto',

        [string[]] $ForbiddenOu = @(),

        [string] $DefinitionPath = '',

        [switch] $IncludeContextGraph,

        [string] $ContextOutputPath = '',

        [string] $RelationshipOutputPath = '',

        [string] $ManifestOutputPath = ''
    )

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('# Reusable ShareSurfer ownership enrichment commands')
    $lines.Add('# This regenerates the enriched ownership CSV without repeating the interactive CSV/OU picker.')
    if (-not [string]::IsNullOrWhiteSpace($DefinitionPath)) {
        $lines.Add(('$definitionPath = {0}' -f (ConvertTo-ShareSurferPowerShellLiteral -Value $DefinitionPath)))
        $lines.Add(('$outputPath = {0}' -f (ConvertTo-ShareSurferPowerShellLiteral -Value $OutputPath)))
        $lines.Add('')
        $lines.Add('Join-ShareSurferOwnershipSources -DefinitionPath $definitionPath -OutputPath $outputPath -Force')
        $lines.Add('')
        $lines.Add('# Then pass $outputPath to Invoke-ShareSurferScan -OwnershipEnrichmentPath $outputPath.')

        return ($lines -join [Environment]::NewLine)
    }

    $lines.Add(('$sourcePaths = {0}' -f (ConvertTo-ShareSurferPowerShellArrayLiteral -Values $SourcePaths)))
    $lines.Add(('$profilePaths = {0}' -f (ConvertTo-ShareSurferPowerShellArrayLiteral -Values $MappingProfilePaths)))
    $lines.Add(('$forbiddenOus = {0}' -f (ConvertTo-ShareSurferPowerShellArrayLiteral -Values $ForbiddenOu)))
    $lines.Add(('$outputPath = {0}' -f (ConvertTo-ShareSurferPowerShellLiteral -Value $OutputPath)))
    $lines.Add(('$obsAttribute = {0}' -f (ConvertTo-ShareSurferPowerShellLiteral -Value $ObsAttribute)))
    $lines.Add(('$adLookupMode = {0}' -f (ConvertTo-ShareSurferPowerShellLiteral -Value $AdLookupMode)))
    if ($IncludeContextGraph) {
        $lines.Add(('$contextOutputPath = {0}' -f (ConvertTo-ShareSurferPowerShellLiteral -Value $ContextOutputPath)))
        $lines.Add(('$relationshipOutputPath = {0}' -f (ConvertTo-ShareSurferPowerShellLiteral -Value $RelationshipOutputPath)))
        $lines.Add(('$manifestOutputPath = {0}' -f (ConvertTo-ShareSurferPowerShellLiteral -Value $ManifestOutputPath)))
    }
    if (-not [string]::IsNullOrWhiteSpace($ObsHeader)) {
        $lines.Add(('$obsHeader = {0}' -f (ConvertTo-ShareSurferPowerShellLiteral -Value $ObsHeader)))
    }
    $lines.Add('')
    $command = 'Join-ShareSurferOwnershipSources -Path $sourcePaths -OutputPath $outputPath -ObsAttribute $obsAttribute -AdLookupMode $adLookupMode -ForbiddenOu $forbiddenOus -Force'
    if ($MappingProfilePaths.Count -gt 0) {
        $command += ' -MappingProfilePath $profilePaths'
    }
    if (-not [string]::IsNullOrWhiteSpace($ObsHeader)) {
        $command += ' -ObsHeader $obsHeader'
    }
    if ($IncludeContextGraph) {
        $command += ' -IncludeContextGraph -ContextOutputPath $contextOutputPath -RelationshipOutputPath $relationshipOutputPath -ManifestOutputPath $manifestOutputPath'
    }
    $lines.Add($command)
    $lines.Add('')
    $lines.Add('# Then pass $outputPath to Invoke-ShareSurferScan -OwnershipEnrichmentPath $outputPath.')

    $lines -join [Environment]::NewLine
}
