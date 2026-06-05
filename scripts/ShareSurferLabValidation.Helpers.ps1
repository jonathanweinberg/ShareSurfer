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
    $groupEdges = @(Import-ShareSurferLabValidationCsv -Path (Join-Path $ExportPath 'group_edges.csv'))
    $ownerRiskPivots = @(Import-ShareSurferLabValidationCsv -Path (Join-Path $ExportPath 'owner_risk_pivots.csv'))
    $scannedFiles = @($items | Where-Object { $_.ItemType -eq 'File' })
    $scannedDeepItems = @($items | Where-Object {
        $depth = 0
        [void][int]::TryParse([string]$_.Depth, [ref]$depth)
        $depth -ge 6
    })
    $longPathFindings = @($findings | Where-Object { $_.FindingType -eq 'LongPathOperationalPolicy' })
    $deepExplicitAceFindings = @($findings | Where-Object { $_.FindingType -eq 'DeepExplicitAce' })
    $brokenInheritanceFindings = @($findings | Where-Object { $_.FindingType -eq 'BrokenInheritance' })
    $fileAclEntries = @($aclEntries | Where-Object {
        $entryItemId = [string]$_.ItemId
        (@($scannedFiles | Where-Object { [string]$_.ItemId -eq $entryItemId }).Count -gt 0) -and
        ([string]$_.InheritanceFlags -eq 'None')
    })
    $directoryCounts = Get-ShareSurferLabValidationDirectoryCounts -Plan $Plan

    $actualFileCount = $null
    $actualBytes = $null
    $actualDeepFileCount = $null
    if (Test-Path -LiteralPath $LabRoot) {
        $actualFiles = @(Get-ChildItem -LiteralPath $LabRoot -Recurse -File -ErrorAction SilentlyContinue)
        $actualFileCount = $actualFiles.Count
        $actualBytes = [int64]0
        foreach ($file in $actualFiles) {
            $actualBytes += [int64]$file.Length
        }
        $actualDeepFileCount = @($actualFiles | Where-Object {
            $relative = $_.FullName.Substring($LabRoot.Length).TrimStart('\', '/')
            @($relative -split '[\\/]').Count -ge 6
        }).Count
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
        ScannedShareCount = $shares.Count
        ScannedItemCount = $items.Count
        ScannedFileItemCount = $scannedFiles.Count
        ScannedDeepItemCount = $scannedDeepItems.Count
        LongPathFindingCount = $longPathFindings.Count
        DeepExplicitAceFindingCount = $deepExplicitAceFindings.Count
        BrokenInheritanceFindingCount = $brokenInheritanceFindings.Count
        ConflictCount = $conflicts.Count
        SharePermissionCount = $sharePermissions.Count
        AclEntryCount = $aclEntries.Count
        FileAclEntryCount = $fileAclEntries.Count
        GroupEdgeCount = $groupEdges.Count
        OwnerRiskPivotCount = $ownerRiskPivots.Count
        ActualFileCount = $actualFileCount
        ActualDeepFileCount = $actualDeepFileCount
        ActualLabBytes = $actualBytes
        IncludeFiles = [bool]$IncludeFiles
        CreateLab = [bool]$CreateLab
    }
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
                if ([int64]$evidence.ScannedFileItemCount -gt 0) {
                    $actual = [int64]$evidence.ScannedFileItemCount
                    $source = 'ScanExport:items.csv'
                }
                elseif ($null -ne $evidence.ActualFileCount) {
                    $actual = [int64]$evidence.ActualFileCount
                    $source = 'FileSystem'
                }
                else {
                    $actual = [int64]$evidence.PlannedFileFixtureCount
                    $source = 'LabPlan'
                }
                $detail = 'ScannedFileItems={0}; ActualFiles={1}; PlannedFileFixtures={2}; IncludeFiles={3}' -f $evidence.ScannedFileItemCount, $evidence.ActualFileCount, $evidence.PlannedFileFixtureCount, $evidence.IncludeFiles
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
            'EnterpriseGroupExpansion' {
                $actual = [int64]$evidence.GroupEdgeCount
                $source = 'ScanExport:group_edges.csv'
                $detail = 'GroupEdgeRows={0}' -f $evidence.GroupEdgeCount
            }
            'EnterpriseOwnerRiskPivots' {
                $actual = [int64]$evidence.OwnerRiskPivotCount
                $source = 'ScanExport:owner_risk_pivots.csv'
                $detail = 'OwnerRiskPivotRows={0}' -f $evidence.OwnerRiskPivotCount
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
