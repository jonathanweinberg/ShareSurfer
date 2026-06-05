function Import-ShareSurferLabValidationCsv {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return @()
    }

    $content = Get-Content -LiteralPath $Path -Raw
    if ([string]::IsNullOrWhiteSpace($content)) {
        return @()
    }

    @(Import-Csv -LiteralPath $Path)
}

function New-ShareSurferLabValidationPreflightRow {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Name,

        [Parameter(Mandatory = $true)]
        [bool] $Required,

        [Parameter(Mandatory = $true)]
        [bool] $Passed,

        [Parameter(Mandatory = $true)]
        [string] $Evidence,

        [Parameter(Mandatory = $true)]
        [string] $NextAction
    )

    [pscustomobject]@{
        Name = $Name
        Required = $Required
        Passed = $Passed
        Status = if ($Passed) { 'Pass' } elseif ($Required) { 'Blocker' } else { 'Review' }
        Evidence = $Evidence
        NextAction = $NextAction
    }
}

function Test-ShareSurferLabValidationWindowsPathComponents {
    param(
        [Parameter(Mandatory = $true)]
        $Plan
    )

    $badSegments = New-Object System.Collections.ArrayList
    $paths = New-Object System.Collections.ArrayList
    foreach ($share in @($Plan.Shares)) {
        if ($share.PSObject.Properties['LocalPath']) {
            [void]$paths.Add([string]$share.LocalPath)
        }
    }
    foreach ($scenario in @($Plan.AclScenarios)) {
        if ($scenario.PSObject.Properties['RelativePath']) {
            [void]$paths.Add([string]$scenario.RelativePath)
        }
    }
    foreach ($file in @($Plan.FileFixtures)) {
        if ($file.PSObject.Properties['RelativePath']) {
            [void]$paths.Add([string]$file.RelativePath)
        }
    }

    foreach ($path in @($paths)) {
        foreach ($segment in @($path -split '[\\/]')) {
            $normalized = $segment
            if ($normalized -match '^[A-Za-z]:$') {
                continue
            }
            if ($normalized.Length -gt 255) {
                [void]$badSegments.Add(('{0} ({1} chars)' -f $normalized.Substring(0, [Math]::Min(40, $normalized.Length)), $normalized.Length))
            }
        }
    }

    [pscustomobject]@{
        Passed = ($badSegments.Count -eq 0)
        BadSegmentCount = $badSegments.Count
        BadSegments = @($badSegments)
    }
}

function ConvertTo-ShareSurferLabValidationComparablePath {
    param(
        [string] $Path = ''
    )

    ([string]$Path).Trim().TrimEnd('\', '/').ToUpperInvariant()
}

function Test-ShareSurferLabValidationSmbSharePaths {
    param(
        [Parameter(Mandatory = $true)]
        $Plan
    )

    $command = Get-Command Get-SmbShare -ErrorAction SilentlyContinue
    if ($null -eq $command) {
        return [pscustomobject]@{
            Passed = $false
            CheckedShareCount = 0
            CollisionCount = 0
            Evidence = 'Get-SmbShare command is unavailable.'
        }
    }

    $collisions = New-Object System.Collections.ArrayList
    $checkedShareCount = 0
    foreach ($share in @($Plan.Shares)) {
        $existing = Get-SmbShare -Name $share.ShareName -ErrorAction SilentlyContinue
        if ($null -eq $existing) {
            continue
        }

        $checkedShareCount++
        $existingPath = ''
        if ($existing.PSObject.Properties['Path']) {
            $existingPath = [string]$existing.Path
        }

        $plannedPath = ''
        if ($share.PSObject.Properties['LocalPath']) {
            $plannedPath = [string]$share.LocalPath
        }
        $normalizedExistingPath = ConvertTo-ShareSurferLabValidationComparablePath -Path $existingPath
        $normalizedPlannedPath = ConvertTo-ShareSurferLabValidationComparablePath -Path $plannedPath
        if ($normalizedExistingPath -ne $normalizedPlannedPath) {
            [void]$collisions.Add(('{0}: existing={1}; planned={2}' -f $share.ShareName, $existingPath, $plannedPath))
        }
    }

    [pscustomobject]@{
        Passed = ($collisions.Count -eq 0)
        CheckedShareCount = $checkedShareCount
        CollisionCount = $collisions.Count
        Evidence = 'CheckedExistingShares={0}; Collisions={1}' -f $checkedShareCount, (@($collisions) -join ' | ')
    }
}

function Test-ShareSurferLabValidationAdObjectCollisions {
    param(
        [Parameter(Mandatory = $true)]
        $Plan
    )

    $requiredCommands = @('Get-ADDomain', 'Get-ADUser', 'Get-ADGroup')
    $missingCommands = @($requiredCommands | Where-Object { $null -eq (Get-Command $_ -ErrorAction SilentlyContinue) })
    if ($missingCommands.Count -gt 0) {
        return [pscustomobject]@{
            Passed = $false
            CheckedObjectCount = 0
            CollisionCount = 0
            Evidence = 'Missing AD commands: {0}' -f ($missingCommands -join ', ')
        }
    }

    try {
        $domain = Get-ADDomain -ErrorAction Stop
    }
    catch {
        return [pscustomobject]@{
            Passed = $false
            CheckedObjectCount = 0
            CollisionCount = 0
            Evidence = 'Unable to resolve AD domain: {0}' -f $_.Exception.Message
        }
    }

    $ouDn = 'OU=ShareSurferLab,{0}' -f $domain.DistinguishedName
    $collisions = New-Object System.Collections.ArrayList
    $checkedObjectCount = 0

    foreach ($user in @($Plan.Users)) {
        $sam = [string]$user.SamAccountName
        if ([string]::IsNullOrWhiteSpace($sam)) {
            continue
        }
        $matches = @(Get-ADUser -Filter ("SamAccountName -eq '{0}'" -f (ConvertTo-ShareSurferLabValidationAdFilterValue -Value $sam)) -ErrorAction SilentlyContinue | Where-Object { $null -ne $_ })
        foreach ($match in $matches) {
            $checkedObjectCount++
            if (-not (Test-ShareSurferLabValidationObjectInOu -DistinguishedName ([string]$match.DistinguishedName) -OuDn $ouDn)) {
                [void]$collisions.Add(('user {0}: {1}' -f $sam, [string]$match.DistinguishedName))
            }
        }
    }

    foreach ($group in @($Plan.Groups)) {
        $sam = [string]$group.Name
        if ([string]::IsNullOrWhiteSpace($sam)) {
            continue
        }
        $matches = @(Get-ADGroup -Filter ("SamAccountName -eq '{0}'" -f (ConvertTo-ShareSurferLabValidationAdFilterValue -Value $sam)) -ErrorAction SilentlyContinue | Where-Object { $null -ne $_ })
        foreach ($match in $matches) {
            $checkedObjectCount++
            if (-not (Test-ShareSurferLabValidationObjectInOu -DistinguishedName ([string]$match.DistinguishedName) -OuDn $ouDn)) {
                [void]$collisions.Add(('group {0}: {1}' -f $sam, [string]$match.DistinguishedName))
            }
        }
    }

    [pscustomobject]@{
        Passed = ($collisions.Count -eq 0)
        CheckedObjectCount = $checkedObjectCount
        CollisionCount = $collisions.Count
        Evidence = 'LabOu={0}; CheckedExistingObjects={1}; Collisions={2}' -f $ouDn, $checkedObjectCount, (@($collisions) -join ' | ')
    }
}

function Test-ShareSurferLabValidationObsAttributeSchema {
    param(
        [Parameter(Mandatory = $true)]
        $Plan
    )

    $obsAttribute = ''
    if ($Plan.PSObject.Properties['ObsAttribute']) {
        $obsAttribute = [string]$Plan.ObsAttribute
    }
    if ([string]::IsNullOrWhiteSpace($obsAttribute)) {
        return [pscustomobject]@{
            Passed = $false
            Evidence = 'ObsAttribute was blank.'
        }
    }

    $requiredCommands = @('Get-ADRootDSE', 'Get-ADObject')
    $missingCommands = @($requiredCommands | Where-Object { $null -eq (Get-Command $_ -ErrorAction SilentlyContinue) })
    if ($missingCommands.Count -gt 0) {
        return [pscustomobject]@{
            Passed = $false
            Evidence = 'Missing AD schema commands: {0}' -f ($missingCommands -join ', ')
        }
    }

    try {
        $rootDse = Get-ADRootDSE -ErrorAction Stop
        $schemaNamingContext = [string]$rootDse.schemaNamingContext
        if ([string]::IsNullOrWhiteSpace($schemaNamingContext)) {
            return [pscustomobject]@{
                Passed = $false
                Evidence = 'AD schema naming context was blank.'
            }
        }

        $escapedAttribute = ConvertTo-ShareSurferLabValidationLdapFilterValue -Value $obsAttribute
        $attributeSchema = Get-ADObject -SearchBase $schemaNamingContext -LDAPFilter "(&(objectClass=attributeSchema)(lDAPDisplayName=$escapedAttribute))" -Properties lDAPDisplayName -ErrorAction SilentlyContinue
        if ($null -eq $attributeSchema) {
            return [pscustomobject]@{
                Passed = $false
                Evidence = 'ObsAttribute={0}; AttributeExists=False; Schema={1}' -f $obsAttribute, $schemaNamingContext
            }
        }

        $userClass = Get-ShareSurferLabValidationSchemaClass -SchemaNamingContext $schemaNamingContext -ClassName 'user'
        $groupClass = Get-ShareSurferLabValidationSchemaClass -SchemaNamingContext $schemaNamingContext -ClassName 'group'
        $userAllows = Test-ShareSurferLabValidationSchemaClassAllowsAttribute -SchemaNamingContext $schemaNamingContext -ClassSchema $userClass -AttributeName $obsAttribute
        $groupAllows = Test-ShareSurferLabValidationSchemaClassAllowsAttribute -SchemaNamingContext $schemaNamingContext -ClassSchema $groupClass -AttributeName $obsAttribute

        [pscustomobject]@{
            Passed = ($userAllows -and $groupAllows)
            Evidence = 'ObsAttribute={0}; AttributeExists=True; UserAllows={1}; GroupAllows={2}; Schema={3}' -f $obsAttribute, $userAllows, $groupAllows, $schemaNamingContext
        }
    }
    catch {
        [pscustomobject]@{
            Passed = $false
            Evidence = 'OBS attribute schema check failed for {0}: {1}' -f $obsAttribute, $_.Exception.Message
        }
    }
}

function Test-ShareSurferLabValidationPasswordPolicy {
    $plannedPasswordLength = 33
    $plannedPasswordCategories = 4

    $command = Get-Command Get-ADDefaultDomainPasswordPolicy -ErrorAction SilentlyContinue
    if ($null -eq $command) {
        return [pscustomobject]@{
            Passed = $false
            Evidence = 'Get-ADDefaultDomainPasswordPolicy command is unavailable.'
        }
    }

    try {
        $policy = Get-ADDefaultDomainPasswordPolicy -ErrorAction Stop
        $minimumLength = 0
        if ($policy.PSObject.Properties['MinPasswordLength']) {
            [void][int]::TryParse([string]$policy.MinPasswordLength, [ref]$minimumLength)
        }

        $complexityEnabled = $false
        if ($policy.PSObject.Properties['ComplexityEnabled']) {
            $complexityEnabled = ConvertTo-ShareSurferLabValidationBool $policy.ComplexityEnabled
        }

        $historyCount = ''
        if ($policy.PSObject.Properties['PasswordHistoryCount']) {
            $historyCount = [string]$policy.PasswordHistoryCount
        }

        $lengthPassed = ($plannedPasswordLength -ge $minimumLength)
        $complexityPassed = ((-not $complexityEnabled) -or $plannedPasswordCategories -ge 3)

        [pscustomobject]@{
            Passed = ($lengthPassed -and $complexityPassed)
            Evidence = 'GeneratedPasswordLength={0}; GeneratedPasswordCategories={1}; MinPasswordLength={2}; ComplexityEnabled={3}; PasswordHistoryCount={4}' -f $plannedPasswordLength, $plannedPasswordCategories, $minimumLength, $complexityEnabled, $historyCount
        }
    }
    catch {
        [pscustomobject]@{
            Passed = $false
            Evidence = 'Unable to read default domain password policy: {0}' -f $_.Exception.Message
        }
    }
}

function Get-ShareSurferLabValidationSchemaClass {
    param(
        [Parameter(Mandatory = $true)]
        [string] $SchemaNamingContext,

        [Parameter(Mandatory = $true)]
        [string] $ClassName
    )

    $escapedClassName = ConvertTo-ShareSurferLabValidationLdapFilterValue -Value $ClassName
    Get-ADObject -SearchBase $SchemaNamingContext -LDAPFilter "(&(objectClass=classSchema)(lDAPDisplayName=$escapedClassName))" -Properties lDAPDisplayName, mayContain, systemMayContain, mustContain, systemMustContain, subClassOf, auxiliaryClass, systemAuxiliaryClass -ErrorAction SilentlyContinue
}

function Test-ShareSurferLabValidationSchemaClassAllowsAttribute {
    param(
        [Parameter(Mandatory = $true)]
        [string] $SchemaNamingContext,

        $ClassSchema,

        [Parameter(Mandatory = $true)]
        [string] $AttributeName,

        [hashtable] $VisitedClass = @{}
    )

    if ($null -eq $ClassSchema) {
        return $false
    }

    $className = ''
    if ($ClassSchema.PSObject.Properties['lDAPDisplayName']) {
        $className = [string]$ClassSchema.lDAPDisplayName
    }
    if (-not [string]::IsNullOrWhiteSpace($className)) {
        $classKey = $className.ToUpperInvariant()
        if ($VisitedClass.ContainsKey($classKey)) {
            return $false
        }
        $VisitedClass[$classKey] = $true
    }

    foreach ($propertyName in @('mayContain', 'systemMayContain', 'mustContain', 'systemMustContain')) {
        if (-not $ClassSchema.PSObject.Properties[$propertyName]) {
            continue
        }
        foreach ($value in @($ClassSchema.PSObject.Properties[$propertyName].Value)) {
            if ([string]::Equals([string]$value, $AttributeName, [System.StringComparison]::OrdinalIgnoreCase)) {
                return $true
            }
        }
    }

    foreach ($relatedClassProperty in @('subClassOf', 'auxiliaryClass', 'systemAuxiliaryClass')) {
        if (-not $ClassSchema.PSObject.Properties[$relatedClassProperty]) {
            continue
        }
        foreach ($relatedClassName in @($ClassSchema.PSObject.Properties[$relatedClassProperty].Value)) {
            if ([string]::IsNullOrWhiteSpace([string]$relatedClassName)) {
                continue
            }
            $relatedClass = Get-ShareSurferLabValidationSchemaClass -SchemaNamingContext $SchemaNamingContext -ClassName ([string]$relatedClassName)
            if (Test-ShareSurferLabValidationSchemaClassAllowsAttribute -SchemaNamingContext $SchemaNamingContext -ClassSchema $relatedClass -AttributeName $AttributeName -VisitedClass $VisitedClass) {
                return $true
            }
        }
    }

    $false
}

function Test-ShareSurferLabValidationObjectInOu {
    param(
        [string] $DistinguishedName = '',

        [Parameter(Mandatory = $true)]
        [string] $OuDn
    )

    $expectedSuffix = ',{0}' -f $OuDn
    ([string]$DistinguishedName).EndsWith($expectedSuffix, [System.StringComparison]::OrdinalIgnoreCase)
}

function ConvertTo-ShareSurferLabValidationAdFilterValue {
    param(
        [string] $Value = ''
    )

    $Value -replace "'", "''"
}

function ConvertTo-ShareSurferLabValidationLdapFilterValue {
    param(
        [string] $Value = ''
    )

    ([string]$Value).Replace('\', '\5c').Replace('*', '\2a').Replace('(', '\28').Replace(')', '\29').Replace([string][char]0, '\00')
}

function ConvertTo-ShareSurferLabValidationBool {
    param(
        $Value
    )

    if ($null -eq $Value) {
        return $false
    }

    $text = ([string]$Value).Trim()
    $text -eq 'True' -or $text -eq 'true' -or $text -eq '1' -or $text -eq 'Yes' -or $text -eq 'yes'
}

function Test-ShareSurferLabValidationTargetVolumeFreeSpace {
    param(
        [Parameter(Mandatory = $true)]
        $Plan,

        [Parameter(Mandatory = $true)]
        [string] $LabRoot
    )

    $requiredBytes = [int64]0
    if ($Plan.PSObject.Properties['MaxLabBytes']) {
        $requiredBytes = [int64]$Plan.MaxLabBytes
    }
    if ($requiredBytes -le 0 -and $Plan.PSObject.Properties['EstimatedLabBytes']) {
        $requiredBytes = [int64]$Plan.EstimatedLabBytes
    }

    try {
        $root = [System.IO.Path]::GetPathRoot($LabRoot)
        if ([string]::IsNullOrWhiteSpace($root)) {
            return [pscustomobject]@{
                Passed = $false
                FreeBytes = $null
                RequiredBytes = $requiredBytes
                Evidence = 'Unable to resolve a filesystem root for LabRoot={0}.' -f $LabRoot
            }
        }

        $drive = New-Object System.IO.DriveInfo($root)
        if (-not $drive.IsReady) {
            return [pscustomobject]@{
                Passed = $false
                FreeBytes = $null
                RequiredBytes = $requiredBytes
                Evidence = 'Target drive is not ready: {0}' -f $root
            }
        }

        $freeBytes = [int64]$drive.AvailableFreeSpace
        [pscustomobject]@{
            Passed = ($requiredBytes -gt 0 -and $freeBytes -ge $requiredBytes)
            FreeBytes = $freeBytes
            RequiredBytes = $requiredBytes
            Evidence = 'LabRoot={0}; Volume={1}; FreeBytes={2}; RequiredBytes={3}' -f $LabRoot, $drive.Name, $freeBytes, $requiredBytes
        }
    }
    catch {
        [pscustomobject]@{
            Passed = $false
            FreeBytes = $null
            RequiredBytes = $requiredBytes
            Evidence = 'Unable to measure target volume free space for LabRoot={0}: {1}' -f $LabRoot, $_.Exception.Message
        }
    }
}

function New-ShareSurferLabValidationPreflight {
    param(
        [Parameter(Mandatory = $true)]
        $Plan,

        [Parameter(Mandatory = $true)]
        [string] $LabRoot,

        [Parameter(Mandatory = $true)]
        [string] $RunRoot,

        [switch] $CreateLab,
        [switch] $IncludeFiles,
        [switch] $RequireLiveEvidence
    )

    $rows = New-Object System.Collections.ArrayList
    $scaleProfile = ''
    if ($Plan.PSObject.Properties['ScaleProfile']) {
        $scaleProfile = [string]$Plan.ScaleProfile
    }
    $collectorIsWindows = $false
    try {
        $collectorIsWindows = [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Windows)
    }
    catch {
        $collectorIsWindows = $env:OS -eq 'Windows_NT'
    }

    [void]$rows.Add((New-ShareSurferLabValidationPreflightRow -Name 'WindowsCollectorHost' -Required $true -Passed $collectorIsWindows -Evidence ('IsWindows={0}; PSVersion={1}; PSEdition={2}' -f $collectorIsWindows, $PSVersionTable.PSVersion, $PSVersionTable.PSEdition) -NextAction 'Run lab validation from a Windows collector host with Windows PowerShell 5.1.'))

    $isPs51 = ($PSVersionTable.PSVersion.Major -eq 5 -and $PSVersionTable.PSVersion.Minor -eq 1)
    [void]$rows.Add((New-ShareSurferLabValidationPreflightRow -Name 'PowerShell51' -Required $true -Passed $isPs51 -Evidence ('PSVersion={0}; PSEdition={1}' -f $PSVersionTable.PSVersion, $PSVersionTable.PSEdition) -NextAction 'Run from Windows PowerShell 5.1 for V1 validation.'))

    $adModule = Get-Module -ListAvailable ActiveDirectory | Select-Object -First 1
    $adRequired = ($scaleProfile -eq 'Enterprise' -or $CreateLab -or $RequireLiveEvidence)
    $adEvidence = 'Module not found.'
    if ($null -ne $adModule) {
        $adEvidence = 'Module={0}' -f $adModule.Path
    }
    [void]$rows.Add((New-ShareSurferLabValidationPreflightRow -Name 'ActiveDirectoryModule' -Required $adRequired -Passed ($null -ne $adModule) -Evidence $adEvidence -NextAction 'Install or enable RSAT Active Directory PowerShell tools on the collector host.'))

    $obsAttributeSchemaResult = Test-ShareSurferLabValidationObsAttributeSchema -Plan $Plan
    [void]$rows.Add((New-ShareSurferLabValidationPreflightRow -Name 'ObsAttributeSchema' -Required ([bool]$CreateLab) -Passed ((-not [bool]$CreateLab) -or [bool]$obsAttributeSchemaResult.Passed) -Evidence $obsAttributeSchemaResult.Evidence -NextAction 'Choose an AD attribute that exists and is allowed on both user and group objects, then rerun with -ObsAttribute using that attribute name.'))

    $passwordPolicyResult = Test-ShareSurferLabValidationPasswordPolicy
    [void]$rows.Add((New-ShareSurferLabValidationPreflightRow -Name 'LabPasswordPolicy' -Required ([bool]$CreateLab) -Passed ((-not [bool]$CreateLab) -or [bool]$passwordPolicyResult.Passed) -Evidence $passwordPolicyResult.Evidence -NextAction 'Review the default domain password policy before creating lab users, or update the generated lab password pattern if the configured policy is stricter.'))

    $adObjectCollisionResult = Test-ShareSurferLabValidationAdObjectCollisions -Plan $Plan
    [void]$rows.Add((New-ShareSurferLabValidationPreflightRow -Name 'AdObjectNameCollisions' -Required ([bool]$CreateLab) -Passed ([bool]$adObjectCollisionResult.Passed) -Evidence $adObjectCollisionResult.Evidence -NextAction 'Rename or remove any existing AD user or group whose name matches a planned ShareSurfer lab object but is outside the ShareSurferLab OU.'))

    $smbCommands = @('Get-SmbShare', 'Get-SmbShareAccess', 'New-SmbShare', 'Grant-SmbShareAccess')
    $missingSmbCommands = @($smbCommands | Where-Object { $null -eq (Get-Command $_ -ErrorAction SilentlyContinue) })
    $smbRequired = ($CreateLab -or $scaleProfile -eq 'Enterprise' -or $RequireLiveEvidence)
    [void]$rows.Add((New-ShareSurferLabValidationPreflightRow -Name 'SmbShareCommands' -Required $smbRequired -Passed ($missingSmbCommands.Count -eq 0) -Evidence ('Missing={0}' -f ($missingSmbCommands -join ', ')) -NextAction 'Run from a Windows host with the SMBShare PowerShell module available.'))

    $smbSharePathResult = Test-ShareSurferLabValidationSmbSharePaths -Plan $Plan
    [void]$rows.Add((New-ShareSurferLabValidationPreflightRow -Name 'SmbSharePathCollisions' -Required ([bool]$CreateLab) -Passed ([bool]$smbSharePathResult.Passed) -Evidence $smbSharePathResult.Evidence -NextAction 'Rename or remove any existing SMB share whose name matches a planned ShareSurfer lab share but points at a different path.'))

    $runRootExists = Test-Path -LiteralPath $RunRoot
    [void]$rows.Add((New-ShareSurferLabValidationPreflightRow -Name 'RunRootWritable' -Required $true -Passed $runRootExists -Evidence ('RunRoot={0}; Exists={1}' -f $RunRoot, $runRootExists) -NextAction 'Choose an output root that the collector account can create and write to.'))

    $labRootExists = Test-Path -LiteralPath $LabRoot
    $labRootRequired = (-not $CreateLab)
    [void]$rows.Add((New-ShareSurferLabValidationPreflightRow -Name 'ExistingLabRoot' -Required $labRootRequired -Passed ((-not $labRootRequired) -or $labRootExists) -Evidence ('LabRoot={0}; Exists={1}; CreateLab={2}' -f $LabRoot, $labRootExists, [bool]$CreateLab) -NextAction 'Use -CreateLab for a new fixture, or point -LabRoot at an existing ShareSurfer lab root.'))

    $estimatedLabBytes = [int64]0
    if ($Plan.PSObject.Properties['EstimatedLabBytes']) {
        $estimatedLabBytes = [int64]$Plan.EstimatedLabBytes
    }
    $maxLabBytes = [int64]0
    if ($Plan.PSObject.Properties['MaxLabBytes']) {
        $maxLabBytes = [int64]$Plan.MaxLabBytes
    }
    $diskPlanPassed = ($maxLabBytes -gt 0 -and $estimatedLabBytes -le $maxLabBytes)
    [void]$rows.Add((New-ShareSurferLabValidationPreflightRow -Name 'PlanDiskBudget' -Required $true -Passed $diskPlanPassed -Evidence ('EstimatedBytes={0}; MaxLabBytes={1}' -f $estimatedLabBytes, $maxLabBytes) -NextAction 'Reduce enterprise shares/files per share or raise MaxLabBytes before creating the lab.'))

    $targetVolumeResult = Test-ShareSurferLabValidationTargetVolumeFreeSpace -Plan $Plan -LabRoot $LabRoot
    [void]$rows.Add((New-ShareSurferLabValidationPreflightRow -Name 'TargetVolumeFreeSpace' -Required ([bool]$CreateLab) -Passed ([bool]$targetVolumeResult.Passed) -Evidence $targetVolumeResult.Evidence -NextAction 'Choose a lab root on a volume with enough free space for the configured MaxLabBytes, or lower the lab data budget before creating the lab.'))

    $failedPlanCriteria = @($Plan.ValidationCriteria | Where-Object {
        $actualPlanValue = 0
        if ($_.PSObject.Properties['ActualPlanValue']) {
            $actualPlanValue = [int64]$_.ActualPlanValue
        }
        [bool]$_.Required -and $actualPlanValue -lt [int64]$_.MinimumValue
    })
    [void]$rows.Add((New-ShareSurferLabValidationPreflightRow -Name 'PlanCriteria' -Required $true -Passed ($failedPlanCriteria.Count -eq 0) -Evidence ('FailedPlanCriteria={0}' -f (($failedPlanCriteria | ForEach-Object { $_.Name }) -join ', ')) -NextAction 'Adjust the lab scale inputs until all required plan criteria meet their minimum values.'))

    $pathComponentResult = Test-ShareSurferLabValidationWindowsPathComponents -Plan $Plan
    [void]$rows.Add((New-ShareSurferLabValidationPreflightRow -Name 'WindowsPathComponents' -Required $true -Passed ([bool]$pathComponentResult.Passed) -Evidence ('BadSegmentCount={0}; Examples={1}' -f $pathComponentResult.BadSegmentCount, (@($pathComponentResult.BadSegments) -join '; ')) -NextAction 'Shorten fixture path segments so each Windows path component is 255 characters or less.'))

    $includeFilesPassed = (($scaleProfile -ne 'Enterprise') -or $IncludeFiles)
    [void]$rows.Add((New-ShareSurferLabValidationPreflightRow -Name 'EnterpriseIncludeFiles' -Required ($scaleProfile -eq 'Enterprise') -Passed $includeFilesPassed -Evidence ('Scale={0}; IncludeFiles={1}' -f $scaleProfile, [bool]$IncludeFiles) -NextAction 'Use -IncludeFiles for enterprise validation so real file objects are scanned and proven.'))

    @($rows)
}

function Measure-ShareSurferLabValidationEvidence {
    param(
        [Parameter(Mandatory = $true)]
        $Plan,

        [Parameter(Mandatory = $true)]
        [string] $ExportPath,

        [Parameter(Mandatory = $true)]
        [string] $LabRoot,

        [switch] $CreateLab,
        [switch] $IncludeFiles
    )

    $shares = @(Import-ShareSurferLabValidationCsv -Path (Join-Path $ExportPath 'shares.csv'))
    $items = @(Import-ShareSurferLabValidationCsv -Path (Join-Path $ExportPath 'items.csv'))
    $findings = @(Import-ShareSurferLabValidationCsv -Path (Join-Path $ExportPath 'findings.csv'))
    $conflicts = @(Import-ShareSurferLabValidationCsv -Path (Join-Path $ExportPath 'conflicts.csv'))
    $sharePermissions = @(Import-ShareSurferLabValidationCsv -Path (Join-Path $ExportPath 'share_permissions.csv'))
    $aclEntries = @(Import-ShareSurferLabValidationCsv -Path (Join-Path $ExportPath 'acl_entries.csv'))
    $collectionErrors = @(Import-ShareSurferLabValidationCsv -Path (Join-Path $ExportPath 'collection_errors.csv'))
    $identities = @(Import-ShareSurferLabValidationCsv -Path (Join-Path $ExportPath 'identities.csv'))
    $orgChains = @(Import-ShareSurferLabValidationCsv -Path (Join-Path $ExportPath 'org_chains.csv'))
    $groupEdges = @(Import-ShareSurferLabValidationCsv -Path (Join-Path $ExportPath 'group_edges.csv'))
    $ownerRiskPivots = @(Import-ShareSurferLabValidationCsv -Path (Join-Path $ExportPath 'owner_risk_pivots.csv'))
    $relatedDataAreas = @(Import-ShareSurferLabValidationCsv -Path (Join-Path $ExportPath 'related_data_areas.csv'))
    $ownerReviewPackets = @(Import-ShareSurferLabValidationCsv -Path (Join-Path $ExportPath 'owner_review_packets.csv'))
    $manifestRows = @(Import-ShareSurferLabValidationCsv -Path (Join-Path $ExportPath 'scan_manifest.csv'))
    $manifestIncludeFiles = $null
    if ($manifestRows.Count -gt 0 -and $manifestRows[0].PSObject.Properties['IncludeFiles']) {
        $manifestIncludeFiles = ConvertTo-ShareSurferLabValidationBool $manifestRows[0].IncludeFiles
    }
    $scannedFiles = @($items | Where-Object { $_.ItemType -eq 'File' })
    $ownedItems = @($items | Where-Object { [string]$_.Owner -ne '' })
    $scannedDeepItems = @($items | Where-Object {
        $depth = 0
        [void][int]::TryParse([string]$_.Depth, [ref]$depth)
        $depth -ge 6
    })
    $longPathFindings = @($findings | Where-Object { $_.FindingType -eq 'LongPathOperationalPolicy' })
    $deepExplicitAceFindings = @($findings | Where-Object { $_.FindingType -eq 'DeepExplicitAce' })
    $brokenInheritanceFindings = @($findings | Where-Object { $_.FindingType -eq 'BrokenInheritance' })
    $scannedFileItemIds = @{}
    foreach ($file in @($scannedFiles)) {
        $fileItemId = [string]$file.ItemId
        if (-not [string]::IsNullOrWhiteSpace($fileItemId)) {
            $scannedFileItemIds[$fileItemId] = $true
        }
    }
    $fileAclEntries = @($aclEntries | Where-Object {
        $entryItemId = [string]$_.ItemId
        $scannedFileItemIds.ContainsKey($entryItemId) -and
        ([string]$_.InheritanceFlags -eq 'None')
    })
    $focusedAclEvidenceCount = 0
    if ($aclEntries.Count -gt 0) { $focusedAclEvidenceCount++ }
    if ($fileAclEntries.Count -gt 0) { $focusedAclEvidenceCount++ }
    if ($ownedItems.Count -gt 0) { $focusedAclEvidenceCount++ }
    if ($deepExplicitAceFindings.Count -gt 0) { $focusedAclEvidenceCount++ }
    if ($brokenInheritanceFindings.Count -gt 0) { $focusedAclEvidenceCount++ }
    if ($longPathFindings.Count -gt 0) { $focusedAclEvidenceCount++ }
    if ($conflicts.Count -gt 0) { $focusedAclEvidenceCount++ }
    $expectedPermissionGroupNames = @(Get-ShareSurferLabValidationPermissionGroupNames -Plan $Plan)
    $expectedPermissionGroupMap = @{}
    foreach ($groupName in @($expectedPermissionGroupNames)) {
        $expectedPermissionGroupMap[$groupName.ToUpperInvariant()] = $true
    }
    $plannedPermissionGroupsWithObs = @($Plan.Groups | Where-Object {
        $name = [string]$_.Name
        $expectedPermissionGroupMap.ContainsKey($name.ToUpperInvariant()) -and
        $_.PSObject.Properties[$Plan.ObsAttribute] -and
        [string]$_.PSObject.Properties[$Plan.ObsAttribute].Value -ne ''
    })
    $identityUserEmployeeIdentifierCount = @($identities | Where-Object {
        [string]$_.ObjectClass -eq 'user' -and
        ([string]$_.EmployeeId -ne '' -or [string]$_.EmployeeNumber -ne '')
    }).Count
    $identityUserObsCount = @($identities | Where-Object {
        [string]$_.ObjectClass -eq 'user' -and
        [string]$_.ObsPath -ne '' -and
        ([string]$_.ObsAttribute -eq '' -or [string]$_.ObsAttribute -eq [string]$Plan.ObsAttribute)
    }).Count
    $identityHasManagerLevel3Column = @($identities | Where-Object { $_.PSObject.Properties['ManagerLevel3'] }).Count -gt 0
    $orgHasManagerLevel3Column = @($orgChains | Where-Object { $_.PSObject.Properties['ManagerLevel3'] }).Count -gt 0
    $managerChainEvidenceMode = if ($identityHasManagerLevel3Column -or $orgHasManagerLevel3Column) { 'ThreeLevel' } else { 'LegacyTwoLevel' }
    $identityManagerChainCount = @($identities | Where-Object {
        $managerLevel3 = if ($_.PSObject.Properties['ManagerLevel3']) { [string]$_.ManagerLevel3 } else { '' }
        [string]$_.ObjectClass -eq 'user' -and
        [string]$_.ManagerLevel1 -ne '' -and
        [string]$_.ManagerLevel2 -ne '' -and
        ($managerChainEvidenceMode -eq 'LegacyTwoLevel' -or $managerLevel3 -ne '')
    }).Count
    $orgManagerChainCount = @($orgChains | Where-Object {
        $managerLevel3 = if ($_.PSObject.Properties['ManagerLevel3']) { [string]$_.ManagerLevel3 } else { '' }
        [string]$_.ManagerLevel1 -ne '' -and
        [string]$_.ManagerLevel2 -ne '' -and
        ($managerChainEvidenceMode -eq 'LegacyTwoLevel' -or $managerLevel3 -ne '')
    }).Count
    $identityPermissionGroupObsMap = @{}
    foreach ($identity in @($identities)) {
        if ([string]$identity.ObjectClass -ne 'group') {
            continue
        }
        $sam = [string]$identity.SamAccountName
        if ([string]::IsNullOrWhiteSpace($sam)) {
            $sam = Get-ShareSurferLabValidationSamName -Identity ([string]$identity.Identity)
        }
        if (-not $expectedPermissionGroupMap.ContainsKey($sam.ToUpperInvariant())) {
            continue
        }
        if ([string]$identity.ObsPath -eq '') {
            continue
        }
        if ([string]$identity.ObsAttribute -ne '' -and [string]$identity.ObsAttribute -ne [string]$Plan.ObsAttribute) {
            continue
        }
        $identityPermissionGroupObsMap[$sam.ToUpperInvariant()] = $true
    }
    $directoryCounts = Get-ShareSurferLabValidationDirectoryCounts -Plan $Plan

    $actualFileCount = $null
    $actualBytes = $null
    $actualDeepFileCount = $null
    $fileEvidence = Get-ShareSurferLabValidationFileEvidence -LabRoot $LabRoot
    if ($fileEvidence.Available) {
        $actualFileCount = $fileEvidence.FileCount
        $actualBytes = $fileEvidence.TotalBytes
        $actualDeepFileCount = $fileEvidence.DeepFileCount
    }

    [pscustomobject]@{
        PlannedUserCount = @($Plan.Users).Count
        PlannedShareCount = @($Plan.Shares).Count
        PlannedFileFixtureCount = @($Plan.FileFixtures).Count
        PlannedDeepFileFixtureCount = @($Plan.FileFixtures | Where-Object { ([string]$_.RelativePath -split '\\').Count -ge 6 }).Count
        PlannedLongPathScenarioCount = @($Plan.AclScenarios | Where-Object { ([string]$_.RelativePath).Length -gt 256 }).Count
        DirectoryUserCount = $directoryCounts.UserCount
        DirectoryGroupCount = $directoryCounts.GroupCount
        DirectoryEvidenceSource = $directoryCounts.EvidenceSource
        DirectoryEvidenceDetail = $directoryCounts.EvidenceDetail
        ExpectedPermissionGroupCount = $expectedPermissionGroupNames.Count
        IdentityUserEmployeeIdentifierCount = $identityUserEmployeeIdentifierCount
        IdentityUserObsCount = $identityUserObsCount
        IdentityManagerChainCount = $identityManagerChainCount
        OrgManagerChainCount = $orgManagerChainCount
        ManagerChainEvidenceMode = $managerChainEvidenceMode
        PlannedPermissionGroupObsCount = $plannedPermissionGroupsWithObs.Count
        IdentityPermissionGroupObsCount = $identityPermissionGroupObsMap.Count
        ScannedShareCount = $shares.Count
        ScannedItemCount = $items.Count
        ScannedFileItemCount = $scannedFiles.Count
        OwnedItemCount = $ownedItems.Count
        ScannedDeepItemCount = $scannedDeepItems.Count
        LongPathFindingCount = $longPathFindings.Count
        DeepExplicitAceFindingCount = $deepExplicitAceFindings.Count
        BrokenInheritanceFindingCount = $brokenInheritanceFindings.Count
        ConflictCount = $conflicts.Count
        FocusedAclEvidenceCount = $focusedAclEvidenceCount
        SharePermissionCount = $sharePermissions.Count
        AclEntryCount = $aclEntries.Count
        CollectionErrorCount = $collectionErrors.Count
        FileAclEntryCount = $fileAclEntries.Count
        GroupEdgeCount = $groupEdges.Count
        OwnerRiskPivotCount = $ownerRiskPivots.Count
        RelatedDataAreaCount = $relatedDataAreas.Count
        OwnerReviewPacketCount = $ownerReviewPackets.Count
        ActualFileCount = $actualFileCount
        ActualDeepFileCount = $actualDeepFileCount
        ActualLabBytes = $actualBytes
        IncludeFiles = [bool]$IncludeFiles
        ManifestIncludeFiles = $manifestIncludeFiles
        CreateLab = [bool]$CreateLab
    }
}

function Get-ShareSurferLabValidationFileEvidence {
    param(
        [Parameter(Mandatory = $true)]
        [string] $LabRoot
    )

    $result = [ordered]@{
        Available = $false
        FileCount = $null
        DeepFileCount = $null
        TotalBytes = $null
    }

    $displayRoot = ConvertFrom-ShareSurferLabValidationFilesystemPath -Path $LabRoot
    $filesystemRoot = ConvertTo-ShareSurferLabValidationFilesystemPath -Path $LabRoot
    if (-not [System.IO.Directory]::Exists($filesystemRoot)) {
        return [pscustomobject]$result
    }

    $fileCount = [int64]0
    $deepFileCount = [int64]0
    $totalBytes = [int64]0

    foreach ($path in [System.IO.Directory]::EnumerateFiles($filesystemRoot, '*', [System.IO.SearchOption]::AllDirectories)) {
        $displayPath = ConvertFrom-ShareSurferLabValidationFilesystemPath -Path ([string]$path)
        $fileCount++
        $fileInfo = New-Object System.IO.FileInfo($path)
        $totalBytes += [int64]$fileInfo.Length
        if ($displayPath.Length -ge $displayRoot.Length) {
            $relative = $displayPath.Substring($displayRoot.Length).TrimStart('\', '/')
            if (@($relative -split '[\\/]' | Where-Object { $_ -ne '' }).Count -ge 6) {
                $deepFileCount++
            }
        }
    }

    $result.Available = $true
    $result.FileCount = $fileCount
    $result.DeepFileCount = $deepFileCount
    $result.TotalBytes = $totalBytes
    [pscustomobject]$result
}

function ConvertTo-ShareSurferLabValidationFilesystemPath {
    param(
        [string] $Path = ''
    )

    if ([string]::IsNullOrWhiteSpace($Path) -or $Path.StartsWith('\\?\', [System.StringComparison]::Ordinal)) {
        return $Path
    }

    if ($Path.StartsWith('\\', [System.StringComparison]::Ordinal)) {
        return '\\?\UNC\{0}' -f $Path.TrimStart('\')
    }

    if ($Path -match '^[A-Za-z]:[\\/]') {
        return '\\?\{0}' -f $Path
    }

    $Path
}

function ConvertFrom-ShareSurferLabValidationFilesystemPath {
    param(
        [string] $Path = ''
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $Path
    }

    if ($Path.StartsWith('\\?\UNC\', [System.StringComparison]::Ordinal)) {
        return '\\{0}' -f $Path.Substring(8)
    }

    if ($Path.StartsWith('\\?\', [System.StringComparison]::Ordinal)) {
        return $Path.Substring(4)
    }

    $Path
}

function Get-ShareSurferLabValidationDirectoryCounts {
    param(
        [Parameter(Mandatory = $true)]
        $Plan
    )

    $result = [ordered]@{
        UserCount = $null
        GroupCount = $null
        EvidenceSource = 'DirectoryUnavailable'
        EvidenceDetail = 'ActiveDirectory module was not available or the ShareSurferLab OU could not be queried.'
    }

    try {
        $adModule = Get-Module -ListAvailable ActiveDirectory | Select-Object -First 1
        if ($null -eq $adModule) {
            return [pscustomobject]$result
        }

        Import-Module ActiveDirectory -ErrorAction Stop
        $domain = Get-ADDomain -ErrorAction Stop
        $ouDn = 'OU=ShareSurferLab,{0}' -f $domain.DistinguishedName
        $ou = Get-ADOrganizationalUnit -LDAPFilter "(distinguishedName=$ouDn)" -ErrorAction SilentlyContinue
        if ($null -eq $ou) {
            $result.EvidenceDetail = 'ShareSurferLab OU was not found: {0}' -f $ouDn
            return [pscustomobject]$result
        }

        $users = @(Get-ADUser -SearchBase $ouDn -Filter * -ErrorAction Stop)
        $groups = @(Get-ADGroup -SearchBase $ouDn -Filter * -ErrorAction Stop)
        $result.UserCount = $users.Count
        $result.GroupCount = $groups.Count
        $result.EvidenceSource = 'ActiveDirectory'
        $result.EvidenceDetail = 'OU={0}; DirectoryUsers={1}; DirectoryGroups={2}' -f $ouDn, $users.Count, $groups.Count
        [pscustomobject]$result
    }
    catch {
        $result.EvidenceDetail = 'Directory count failed: {0}' -f $_.Exception.Message
        [pscustomobject]$result
    }
}

function New-ShareSurferLabValidationCriteriaRows {
    param(
        [Parameter(Mandatory = $true)]
        $Plan,

        [Parameter(Mandatory = $true)]
        [string] $ExportPath,

        [Parameter(Mandatory = $true)]
        [string] $LabRoot,

        [switch] $CreateLab,
        [switch] $IncludeFiles
    )

    $evidence = Measure-ShareSurferLabValidationEvidence -Plan $Plan -ExportPath $ExportPath -LabRoot $LabRoot -CreateLab:$CreateLab -IncludeFiles:$IncludeFiles

    foreach ($criterion in @($Plan.ValidationCriteria)) {
        $actual = [int64]0
        if ($criterion.PSObject.Properties['ActualPlanValue']) {
            $actual = [int64]$criterion.ActualPlanValue
        }
        $source = 'LabPlan'
        $detail = ''

        switch ($criterion.Name) {
            'FocusedAclScenarios' {
                if ([int64]$evidence.FocusedAclEvidenceCount -gt 0) {
                    $actual = [int64]$evidence.FocusedAclEvidenceCount
                    $source = 'ScanExport:acl_entries.csv;findings.csv;conflicts.csv;items.csv'
                }
                $detail = 'AclRows={0}; FileAclRows={1}; OwnedItemRows={2}; DeepExplicitAceFindings={3}; BrokenInheritanceFindings={4}; LongPathFindings={5}; ConflictRows={6}; PlanAclScenarios={7}' -f $evidence.AclEntryCount, $evidence.FileAclEntryCount, $evidence.OwnedItemCount, $evidence.DeepExplicitAceFindingCount, $evidence.BrokenInheritanceFindingCount, $evidence.LongPathFindingCount, $evidence.ConflictCount, @($Plan.AclScenarios).Count
            }
            'EnterpriseUserPopulation' {
                if ($null -ne $evidence.DirectoryUserCount) {
                    $actual = [int64]$evidence.DirectoryUserCount
                    $source = [string]$evidence.DirectoryEvidenceSource
                }
                else {
                    $actual = [int64]$evidence.PlannedUserCount
                    $source = 'LabPlan'
                }
                $detail = 'DirectoryUsers={0}; PlannedUsers={1}; {2}' -f $evidence.DirectoryUserCount, $evidence.PlannedUserCount, $evidence.DirectoryEvidenceDetail
            }
            'EnterpriseGroupPopulation' {
                if ($null -ne $evidence.DirectoryGroupCount) {
                    $actual = [int64]$evidence.DirectoryGroupCount
                    $source = [string]$evidence.DirectoryEvidenceSource
                }
                else {
                    $actual = [int64]@($Plan.Groups).Count
                    $source = 'LabPlan'
                }
                $detail = 'DirectoryGroups={0}; PlannedGroups={1}; {2}' -f $evidence.DirectoryGroupCount, @($Plan.Groups).Count, $evidence.DirectoryEvidenceDetail
            }
            'EnterpriseEmployeeIdentifierCoverage' {
                if ([int64]$evidence.IdentityUserEmployeeIdentifierCount -gt 0) {
                    $actual = [int64]$evidence.IdentityUserEmployeeIdentifierCount
                    $source = 'ScanExport:identities.csv'
                }
                $detail = 'UsersWithEmployeeIdentifiers={0}' -f $evidence.IdentityUserEmployeeIdentifierCount
            }
            'EnterpriseManagerChainCoverage' {
                if ([int64]$evidence.IdentityManagerChainCount -gt 0 -or [int64]$evidence.OrgManagerChainCount -gt 0) {
                    $actual = [Math]::Max([int64]$evidence.IdentityManagerChainCount, [int64]$evidence.OrgManagerChainCount)
                    $source = if ([int64]$evidence.IdentityManagerChainCount -gt 0) { 'ScanExport:identities.csv' } else { 'ScanExport:org_chains.csv' }
                }
                $managerChainLabel = if ([string]$evidence.ManagerChainEvidenceMode -eq 'LegacyTwoLevel') { 'LegacyTwoLevel' } else { 'ThreeLevel' }
                $detail = 'ManagerChainEvidenceMode={0}; Identity{0}ManagerChains={1}; OrgChain{0}ManagerChains={2}' -f $managerChainLabel, $evidence.IdentityManagerChainCount, $evidence.OrgManagerChainCount
            }
            'EnterpriseUserObsCoverage' {
                if ([int64]$evidence.IdentityUserObsCount -gt 0) {
                    $actual = [int64]$evidence.IdentityUserObsCount
                    $source = 'ScanExport:identities.csv'
                }
                $detail = 'IdentityUsersWithObs={0}; ObsAttribute={1}' -f $evidence.IdentityUserObsCount, $Plan.ObsAttribute
            }
            'EnterpriseSharePopulation' {
                if ([int64]$evidence.ScannedShareCount -gt 0) {
                    $actual = [int64]$evidence.ScannedShareCount
                    $source = 'ScanExport:shares.csv'
                }
                else {
                    $actual = [int64]$evidence.PlannedShareCount
                    $source = 'LabPlan'
                }
                $detail = 'ScannedShares={0}; PlannedShares={1}' -f $evidence.ScannedShareCount, $evidence.PlannedShareCount
            }
            'EnterpriseRealFiles' {
                if ([int64]$evidence.ScannedFileItemCount -gt 0 -and $true -eq $evidence.ManifestIncludeFiles) {
                    $actual = [int64]$evidence.ScannedFileItemCount
                    $source = 'ScanExport:items.csv'
                }
                elseif ([int64]$evidence.ScannedFileItemCount -gt 0 -and $true -ne $evidence.ManifestIncludeFiles) {
                    $actual = 0
                    $source = 'ScanExportMismatch:scan_manifest.csv'
                }
                elseif ($null -ne $evidence.ActualFileCount) {
                    $actual = [int64]$evidence.ActualFileCount
                    $source = 'FileSystem'
                }
                else {
                    $actual = [int64]$evidence.PlannedFileFixtureCount
                    $source = 'LabPlan'
                }
                $detail = 'ScannedFileItems={0}; ActualFiles={1}; PlannedFileFixtures={2}; IncludeFiles={3}; ManifestIncludeFiles={4}' -f $evidence.ScannedFileItemCount, $evidence.ActualFileCount, $evidence.PlannedFileFixtureCount, $evidence.IncludeFiles, $evidence.ManifestIncludeFiles
            }
            'EnterpriseDeepPaths' {
                if ([int64]$evidence.ScannedDeepItemCount -gt 0) {
                    $actual = [int64]$evidence.ScannedDeepItemCount
                    $source = 'ScanExport:items.csv'
                }
                elseif ($null -ne $evidence.ActualDeepFileCount) {
                    $actual = [int64]$evidence.ActualDeepFileCount
                    $source = 'FileSystem'
                }
                else {
                    $actual = [int64]$evidence.PlannedDeepFileFixtureCount
                    $source = 'LabPlan'
                }
                $detail = 'ScannedDeepItems={0}; ActualDeepFiles={1}; PlannedDeepFileFixtures={2}' -f $evidence.ScannedDeepItemCount, $evidence.ActualDeepFileCount, $evidence.PlannedDeepFileFixtureCount
            }
            'EnterpriseLongPathPolicy' {
                if ([int64]$evidence.LongPathFindingCount -gt 0) {
                    $actual = [int64]$evidence.LongPathFindingCount
                    $source = 'ScanExport:findings.csv'
                }
                else {
                    $actual = [int64]$evidence.PlannedLongPathScenarioCount
                    $source = 'LabPlan'
                }
                $detail = 'LongPathFindings={0}; PlannedLongPathScenarios={1}' -f $evidence.LongPathFindingCount, $evidence.PlannedLongPathScenarioCount
            }
            'EnterpriseSharePermissions' {
                $actual = [int64]$evidence.SharePermissionCount
                $source = 'ScanExport:share_permissions.csv'
                $detail = 'SharePermissionRows={0}' -f $evidence.SharePermissionCount
            }
            'EnterpriseAclEntries' {
                $actual = [int64]$evidence.AclEntryCount
                $source = 'ScanExport:acl_entries.csv'
                $detail = 'AclRows={0}' -f $evidence.AclEntryCount
            }
            'EnterpriseFileAclEntries' {
                $actual = [int64]$evidence.FileAclEntryCount
                $source = 'ScanExport:acl_entries.csv'
                $detail = 'FileAclRows={0}; ScannedFileItems={1}' -f $evidence.FileAclEntryCount, $evidence.ScannedFileItemCount
            }
            'EnterpriseOwnershipEvidence' {
                $actual = [int64]$evidence.OwnedItemCount
                $source = 'ScanExport:items.csv'
                $detail = 'OwnedItemRows={0}' -f $evidence.OwnedItemCount
            }
            'EnterpriseDeepExplicitAceFindings' {
                $actual = [int64]$evidence.DeepExplicitAceFindingCount
                $source = 'ScanExport:findings.csv'
                $detail = 'DeepExplicitAceFindings={0}' -f $evidence.DeepExplicitAceFindingCount
            }
            'EnterpriseBrokenInheritanceFindings' {
                $actual = [int64]$evidence.BrokenInheritanceFindingCount
                $source = 'ScanExport:findings.csv'
                $detail = 'BrokenInheritanceFindings={0}' -f $evidence.BrokenInheritanceFindingCount
            }
            'EnterpriseConflictFindings' {
                $actual = [int64]$evidence.ConflictCount
                $source = 'ScanExport:conflicts.csv'
                $detail = 'ConflictRows={0}' -f $evidence.ConflictCount
            }
            'EnterpriseCollectionErrors' {
                $actual = [int64]$evidence.CollectionErrorCount
                $source = 'ScanExport:collection_errors.csv'
                $detail = 'CollectionErrorRows={0}' -f $evidence.CollectionErrorCount
            }
            'EnterpriseGroupExpansion' {
                $actual = [int64]$evidence.GroupEdgeCount
                $source = 'ScanExport:group_edges.csv'
                $detail = 'GroupEdgeRows={0}' -f $evidence.GroupEdgeCount
            }
            'EnterprisePermissionGroupObsCoverage' {
                if ([int64]$evidence.IdentityPermissionGroupObsCount -gt 0) {
                    $actual = [int64]$evidence.IdentityPermissionGroupObsCount
                    $source = 'ScanExport:identities.csv'
                }
                else {
                    $actual = [int64]$evidence.PlannedPermissionGroupObsCount
                    $source = 'LabPlan'
                }
                $detail = 'IdentityGroupsWithObs={0}; PlannedGroupsWithObs={1}; ExpectedPermissionGroups={2}; ObsAttribute={3}' -f $evidence.IdentityPermissionGroupObsCount, $evidence.PlannedPermissionGroupObsCount, $evidence.ExpectedPermissionGroupCount, $Plan.ObsAttribute
            }
            'EnterpriseOwnerRiskPivots' {
                $actual = [int64]$evidence.OwnerRiskPivotCount
                $source = 'ScanExport:owner_risk_pivots.csv'
                $detail = 'OwnerRiskPivotRows={0}' -f $evidence.OwnerRiskPivotCount
            }
            'EnterpriseRelatedDataAreas' {
                $actual = [int64]$evidence.RelatedDataAreaCount
                $source = 'ScanExport:related_data_areas.csv'
                $detail = 'RelatedDataAreaRows={0}' -f $evidence.RelatedDataAreaCount
            }
            'EnterpriseOwnerReviewPackets' {
                $actual = [int64]$evidence.OwnerReviewPacketCount
                $source = 'ScanExport:owner_review_packets.csv'
                $detail = 'OwnerReviewPacketRows={0}' -f $evidence.OwnerReviewPacketCount
            }
            'EnterpriseDiskBudget' {
                if ($null -ne $evidence.ActualLabBytes) {
                    $actual = if ([int64]$evidence.ActualLabBytes -le [int64]$Plan.MaxLabBytes) { 1 } else { 0 }
                    $source = 'FileSystem'
                    $detail = 'ActualBytes={0}; MaxLabBytes={1}' -f $evidence.ActualLabBytes, $Plan.MaxLabBytes
                }
                else {
                    $actual = if ([int64]$Plan.EstimatedLabBytes -le [int64]$Plan.MaxLabBytes) { 1 } else { 0 }
                    $source = 'LabPlan'
                    $detail = 'EstimatedBytes={0}; MaxLabBytes={1}' -f $Plan.EstimatedLabBytes, $Plan.MaxLabBytes
                }
            }
            default {
                $detail = 'PlanValue={0}' -f $actual
            }
        }

        [pscustomobject]@{
            Name = [string]$criterion.Name
            Required = [bool]$criterion.Required
            MinimumValue = [int64]$criterion.MinimumValue
            ActualValue = [int64]$actual
            Unit = [string]$criterion.Unit
            Passed = ([int64]$actual -ge [int64]$criterion.MinimumValue)
            EvidenceSource = $source
            EvidenceDetail = $detail
            Description = [string]$criterion.Description
        }
    }
}

function Get-ShareSurferLabValidationPermissionGroupNames {
    param(
        [Parameter(Mandatory = $true)]
        $Plan
    )

    $knownGroups = @{}
    foreach ($group in @($Plan.Groups)) {
        $knownGroups[[string]$group.Name] = $true
    }

    $permissionGroups = [ordered]@{}
    foreach ($share in @($Plan.Shares)) {
        foreach ($permission in @($share.SharePermissions)) {
            $name = Get-ShareSurferLabValidationSamName -Identity ([string]$permission.Identity)
            if ($knownGroups.ContainsKey($name)) {
                $permissionGroups[$name] = $true
            }
        }
    }
    foreach ($scenario in @($Plan.AclScenarios)) {
        $name = Get-ShareSurferLabValidationSamName -Identity ([string]$scenario.Identity)
        if ($knownGroups.ContainsKey($name)) {
            $permissionGroups[$name] = $true
        }
    }

    @($permissionGroups.Keys)
}

function Get-ShareSurferLabValidationSamName {
    param(
        [string] $Identity = ''
    )

    $value = $Identity.Trim()
    if ($value -like '*\*') {
        return ($value -split '\\')[-1]
    }

    $value
}

function Test-ShareSurferLabValidationLiveEvidence {
    param(
        [Parameter(Mandatory = $true)]
        [object[]] $CriteriaRows
    )

    $fallbackRows = @($CriteriaRows | Where-Object {
        $source = [string]$_.EvidenceSource
        [bool]$_.Required -and (
            [string]::IsNullOrWhiteSpace($source) -or
            $source -eq 'LabPlan' -or
            $source -like '*Unavailable*'
        )
    })

    [pscustomobject]@{
        IsValid = ($fallbackRows.Count -eq 0)
        FallbackCount = $fallbackRows.Count
        FallbackCriteria = @($fallbackRows | ForEach-Object { [string]$_.Name })
        FallbackEvidenceSources = @($fallbackRows | ForEach-Object { [string]$_.EvidenceSource } | Sort-Object -Unique)
    }
}

function New-ShareSurferLabValidationEvidenceReview {
    param(
        [Parameter(Mandatory = $true)]
        [object[]] $CriteriaRows
    )

    foreach ($row in @($CriteriaRows)) {
        $source = [string]$row.EvidenceSource
        $required = [bool]$row.Required
        $passed = $true
        if ($row.PSObject.Properties['Passed']) {
            $passed = [bool]$row.Passed
        }
        $status = 'LiveEvidence'
        $nextAction = 'No action needed for this criterion.'

        if (-not $passed) {
            $status = 'Failed'
            $nextAction = 'Fix the lab, scan, or validation inputs until this criterion meets its minimum value.'
        }
        elseif ([string]::IsNullOrWhiteSpace($source)) {
            $status = 'MissingEvidenceSource'
            $nextAction = 'Rerun validation so this criterion records a concrete evidence source.'
        }
        elseif ($source -eq 'LabPlan') {
            $status = 'PlanOnly'
            $nextAction = 'Create or scan the lab so this criterion is backed by live directory, filesystem, or export evidence.'
        }
        elseif ($source -like '*Unavailable*') {
            $status = 'EvidenceUnavailable'
            $nextAction = 'Run validation from a host with the required module, share, directory, or filesystem access.'
        }
        elseif (-not $required) {
            $status = 'Optional'
        }

        [pscustomobject]@{
            Name = [string]$row.Name
            Required = $required
            Passed = $passed
            EvidenceStatus = $status
            EvidenceSource = $source
            ActualValue = if ($row.PSObject.Properties['ActualValue']) { [string]$row.ActualValue } else { '' }
            MinimumValue = if ($row.PSObject.Properties['MinimumValue']) { [string]$row.MinimumValue } else { '' }
            EvidenceDetail = if ($row.PSObject.Properties['EvidenceDetail']) { [string]$row.EvidenceDetail } else { '' }
            NextAction = $nextAction
        }
    }
}
