Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$moduleManifest = Join-Path $repoRoot 'src/ShareSurfer/ShareSurfer.psd1'

function Assert-True {
    param(
        [Parameter(Mandatory = $true)]
        [bool] $Condition,

        [Parameter(Mandatory = $true)]
        [string] $Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

function Assert-Equal {
    param(
        [Parameter(Mandatory = $true)]
        $Actual,

        [Parameter(Mandatory = $true)]
        $Expected,

        [Parameter(Mandatory = $true)]
        [string] $Message
    )

    if ($Actual -ne $Expected) {
        throw ('{0} Expected: {1}; Actual: {2}' -f $Message, $Expected, $Actual)
    }
}

function New-TestInventory {
    $longSegment = ('A' * 260)
    $longPath = '\\files01\Finance\' + $longSegment

    [pscustomobject]@{
        Shares = @(
            [pscustomobject]@{
                ShareId = 'share-finance'
                Source = 'Fixture'
                ComputerName = 'files01'
                ShareName = 'Finance'
                UNCPath = '\\files01\Finance'
                LocalPath = 'C:\ShareSurferLab\Finance'
                Description = 'Finance test share'
                PartialData = $false
                PartialReason = ''
            }
        )
        Items = @(
            [pscustomobject]@{
                ItemId = 'item-root'
                ShareId = 'share-finance'
                ItemType = 'Directory'
                FullPath = '\\files01\Finance'
                RelativePath = ''
                Depth = 0
                Owner = 'CONTOSO\FinanceOwner'
                InheritanceEnabled = $true
                InheritanceBrokenAt = ''
            },
            [pscustomobject]@{
                ItemId = 'item-deep'
                ShareId = 'share-finance'
                ItemType = 'Directory'
                FullPath = $longPath
                RelativePath = $longSegment
                Depth = 3
                Owner = 'CONTOSO\FinanceOwner'
                InheritanceEnabled = $false
                InheritanceBrokenAt = '\\files01\Finance\Delegated'
            }
        )
        SharePermissions = @(
            [pscustomobject]@{
                ShareId = 'share-finance'
                Identity = 'CONTOSO\FinanceReaders'
                Rights = 'Read'
                AccessControlType = 'Allow'
                Source = 'Get-SmbShareAccess'
            }
        )
        AclEntries = @(
            [pscustomobject]@{
                ItemId = 'item-deep'
                ShareId = 'share-finance'
                FullPath = $longPath
                Identity = 'CONTOSO\FinanceEditors'
                Rights = 'Modify'
                AccessControlType = 'Allow'
                IsInherited = $false
                InheritanceFlags = 'ContainerInherit,ObjectInherit'
                PropagationFlags = 'None'
                Depth = 3
            }
        )
        Identities = @(
            [pscustomobject]@{
                Identity = 'CONTOSO\FinanceReaders'
                SamAccountName = 'FinanceReaders'
                DisplayName = 'Finance Readers'
                ObjectClass = 'group'
                EmployeeId = ''
                EmployeeNumber = ''
                Manager = ''
                ManagerLevel1 = ''
                ManagerLevel2 = ''
                ObsPath = 'CORP.FIN'
                ObsAttribute = 'extensionAttribute10'
            },
            [pscustomobject]@{
                Identity = 'CONTOSO\FinanceEditors'
                SamAccountName = 'FinanceEditors'
                DistinguishedName = 'CN=Finance Editors Group,OU=Groups,DC=example,DC=test'
                DisplayName = 'Finance Editors'
                ObjectClass = 'group'
                EmployeeId = ''
                EmployeeNumber = ''
                Manager = ''
                ManagerLevel1 = ''
                ManagerLevel2 = ''
                ObsPath = 'CORP.FIN.AP'
                ObsAttribute = 'extensionAttribute10'
            }
        )
        GroupEdges = @(
            [pscustomobject]@{
                ParentGroup = 'CONTOSO\FinanceEditors'
                ChildIdentity = 'CONTOSO\Ava.Accounting'
                ChildObjectClass = 'user'
                Depth = 1
                IsCycle = $false
                IsTruncated = $false
            }
        )
        OrgChains = @(
            [pscustomobject]@{
                Identity = 'CONTOSO\Ava.Accounting'
                EmployeeId = 'E1001'
                ManagerLevel1 = 'CONTOSO\Morgan.Manager'
                ManagerLevel2 = 'CONTOSO\Riley.Director'
                ObsPath = 'CORP.FIN.AP'
                ObsAttribute = 'extensionAttribute10'
            }
        )
        OwnerMappings = @(
            [pscustomobject]@{
                Pattern = '\\files01\Finance*'
                Owner = 'Finance Operations'
                BusinessUnit = 'Finance'
                Source = 'unit-test'
            }
        )
        IdentityDirectory = @(
            [pscustomobject]@{
                Identity = 'CONTOSO\FinanceEditors'
                SamAccountName = 'FinanceEditors'
                DisplayName = 'Finance Editors'
                ObjectClass = 'group'
                EmployeeId = ''
                EmployeeNumber = ''
                Manager = ''
                ManagerLevel1 = ''
                ManagerLevel2 = ''
                ObsPath = 'CORP.FIN.AP'
                ObsAttribute = 'extensionAttribute10'
                Members = @('CN=Ava Human Name,OU=Users,DC=example,DC=test', 'CN=Finance Readers Group,OU=Groups,DC=example,DC=test')
            },
            [pscustomobject]@{
                Identity = 'CONTOSO\FinanceReaders'
                SamAccountName = 'FinanceReaders'
                DistinguishedName = 'CN=Finance Readers Group,OU=Groups,DC=example,DC=test'
                DisplayName = 'Finance Readers'
                ObjectClass = 'group'
                EmployeeId = ''
                EmployeeNumber = ''
                Manager = ''
                ManagerLevel1 = ''
                ManagerLevel2 = ''
                ObsPath = 'CORP.FIN'
                ObsAttribute = 'extensionAttribute10'
                Members = @('CN=Ava Human Name,OU=Users,DC=example,DC=test')
            },
            [pscustomobject]@{
                Identity = 'CONTOSO\Ava.Accounting'
                SamAccountName = 'Ava.Accounting'
                DistinguishedName = 'CN=Ava Human Name,OU=Users,DC=example,DC=test'
                DisplayName = 'Ava Accounting'
                ObjectClass = 'user'
                EmployeeId = 'E1001'
                EmployeeNumber = '1001'
                Manager = 'CONTOSO\Morgan.Manager'
                ManagerLevel1 = 'CONTOSO\Morgan.Manager'
                ManagerLevel2 = 'CONTOSO\Riley.Director'
                ObsPath = 'CORP.FIN.AP'
                ObsAttribute = 'extensionAttribute10'
                Members = @()
            }
        )
    }
}

$tests = @(
    @{
        Name = 'New-ShareSurferLabFixture returns a deterministic AD and share fixture plan without mutating when OutputPlanOnly is used'
        Body = {
            Import-Module $moduleManifest -Force
            $labRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferLab-' + [guid]::NewGuid().ToString('N'))

            $plan = New-ShareSurferLabFixture -OutputPlanOnly -RootPath $labRoot -DomainNetBiosName 'CONTOSO' -ObsAttribute 'extensionAttribute11'

            Assert-Equal $plan.ObsAttribute 'extensionAttribute11' 'OBS attribute should be runtime-selectable.'
            Assert-True ($plan.Users.Count -ge 6) 'Lab plan should include multiple demo users.'
            Assert-True ($plan.Groups.Count -ge 4) 'Lab plan should include nested security groups.'
            Assert-True ($plan.Shares.Count -ge 2) 'Lab plan should include multiple SMB share scenarios.'
            Assert-True ($plan.AclScenarios.Name -contains 'DeepExplicitAce') 'Lab plan should include deep explicit ACE scenario.'
            Assert-True ($plan.AclScenarios.Name -contains 'ShareVsNtfsConflict') 'Lab plan should include share-vs-NTFS conflict scenario.'
            Assert-True ($plan.AclScenarios.TargetType -contains 'File') 'Lab plan should include file-level ACL scenarios.'
            Assert-True ($plan.AclScenarios.AccessControlType -contains 'Deny') 'Lab plan should include NTFS deny examples for conflict testing.'
            Assert-True (@($plan.AclScenarios | Where-Object { [string]$_.OwnerIdentity -ne '' }).Count -gt 0) 'Lab plan should include ownership examples.'
            $longScenario = @($plan.AclScenarios | Where-Object { $_.Name -eq 'LongPath' })[0]
            $longSegments = @($longScenario.RelativePath -split '\\')
            Assert-True (@($longSegments | Where-Object { $_.Length -gt 255 }).Count -eq 0) 'Long-path lab scenario must use Windows-creatable path components.'
            Assert-True ($longScenario.RelativePath.Length -gt 256) 'Long-path lab scenario should still exceed the operational path warning threshold.'
            Assert-True (-not (Test-Path -LiteralPath $labRoot)) 'OutputPlanOnly must not create the lab root.'
        }
    },
    @{
        Name = 'New-ShareSurferLabFixture can plan an enterprise-scale lab under the disk budget'
        Body = {
            Import-Module $moduleManifest -Force
            $labRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferEnterpriseLab-' + [guid]::NewGuid().ToString('N'))
            $eightGb = [int64]8589934592

            $plan = New-ShareSurferLabFixture -OutputPlanOnly -RootPath $labRoot -DomainNetBiosName 'CONTOSO' -ObsAttribute 'extensionAttribute10' -Scale Enterprise -EnterpriseUserCount 2500 -EnterpriseShareCount 200 -MaxLabBytes $eightGb

            Assert-Equal $plan.ScaleProfile 'Enterprise' 'Enterprise lab plan should record its scale profile.'
            Assert-True ($plan.Users.Count -ge 2500) 'Enterprise lab plan should include a multi-thousand user population.'
            Assert-True ($plan.Shares.Count -ge 200) 'Enterprise lab plan should include hundreds of SMB shares.'
            Assert-True ($plan.FileFixtures.Count -ge (200 * 8)) 'Enterprise lab plan should include real file objects throughout share trees.'
            Assert-True ([int64]$plan.EstimatedLabBytes -le $eightGb) 'Enterprise lab plan should stay under the 8 GB lab-data budget.'
            Assert-True (@($plan.FileFixtures | Where-Object { ([string]$_.RelativePath -split '\\').Count -ge 6 }).Count -gt 0) 'Enterprise lab plan should include deep folder/file paths.'
            Assert-True (@($plan.AclScenarios | Where-Object { ([string]$_.RelativePath).Length -gt 256 }).Count -gt 0) 'Enterprise lab plan should include operational long-path fixtures.'
            Assert-True ($plan.ValidationCriteria.Name -contains 'EnterpriseUserPopulation') 'Enterprise lab plan should include a user-population validation criterion.'
            Assert-True ($plan.ValidationCriteria.Name -contains 'EnterpriseSharePopulation') 'Enterprise lab plan should include a share-population validation criterion.'
            Assert-True ($plan.ValidationCriteria.Name -contains 'EnterpriseRealFiles') 'Enterprise lab plan should include a real-file validation criterion.'
            Assert-True ($plan.ValidationCriteria.Name -contains 'EnterpriseDiskBudget') 'Enterprise lab plan should include an 8 GB disk-budget validation criterion.'
            Assert-True ($plan.ValidationCriteria.Name -contains 'EnterpriseOwnerRiskPivots') 'Enterprise lab plan should include owner risk pivot validation.'
            foreach ($criterion in @($plan.ValidationCriteria | Where-Object { [string]$_.Name -like 'Enterprise*' -and [bool]$_.Required })) {
                Assert-True ([int64]$criterion.ActualPlanValue -ge [int64]$criterion.MinimumValue) ('Enterprise plan criterion should be satisfiable before live evidence replaces plan evidence: {0}' -f $criterion.Name)
            }
            Assert-True ($plan.OwnerMappings.Count -ge $plan.Shares.Count) 'Enterprise lab plan should include owner mappings for generated shares.'
            Assert-True (-not (Test-Path -LiteralPath $labRoot)) 'OutputPlanOnly enterprise planning must not create the lab root.'

            $windowsRootErrors = @()
            $windowsRootPlan = New-ShareSurferLabFixture -OutputPlanOnly -RootPath 'C:\ShareSurferEnterpriseLab' -Scale Enterprise -EnterpriseUserCount 50 -EnterpriseShareCount 10 -EnterpriseFilesPerShare 2 -ErrorVariable windowsRootErrors
            Assert-Equal $windowsRootErrors.Count 0 'OutputPlanOnly should not emit local drive errors when planning Windows target paths from a non-Windows workstation.'
            Assert-True ([string]$windowsRootPlan.Shares[0].LocalPath -like 'C:\ShareSurferEnterpriseLab\*') 'Windows target root paths should be preserved in plan-only output.'
        }
    },
    @{
        Name = 'Lab validation criteria prefer scan and filesystem evidence over plan-only values'
        Body = {
            Import-Module $moduleManifest -Force
            $helperPath = Join-Path $repoRoot 'scripts/ShareSurferLabValidation.Helpers.ps1'
            . $helperPath

            $labRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferEvidenceLab-' + [guid]::NewGuid().ToString('N'))
            $exportPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferEvidenceExport-' + [guid]::NewGuid().ToString('N'))
            New-Item -ItemType Directory -Path $labRoot -Force | Out-Null
            New-Item -ItemType Directory -Path $exportPath -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $labRoot 'Share001\Deep\Path') -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $labRoot 'Share001\Deep\Path\file01.txt') -Value 'evidence file' -Encoding UTF8

            @(
                [pscustomobject]@{ ShareId = 'share-001'; Source = 'SMB'; ComputerName = 'files01'; ShareName = 'Share001'; UNCPath = '\\files01\Share001'; LocalPath = (Join-Path $labRoot 'Share001'); Description = ''; PartialData = 'False'; PartialReason = '' },
                [pscustomobject]@{ ShareId = 'share-002'; Source = 'SMB'; ComputerName = 'files01'; ShareName = 'Share002'; UNCPath = '\\files01\Share002'; LocalPath = (Join-Path $labRoot 'Share002'); Description = ''; PartialData = 'False'; PartialReason = '' }
            ) | Export-Csv -LiteralPath (Join-Path $exportPath 'shares.csv') -NoTypeInformation -Encoding UTF8
            @(
                [pscustomobject]@{ ItemId = 'item-001'; ShareId = 'share-001'; ItemType = 'File'; FullPath = '\\files01\Share001\Deep\Path\file01.txt'; RelativePath = 'Deep\Path\file01.txt'; Depth = 7; Owner = 'CONTOSO\Owner'; InheritanceEnabled = 'True'; InheritanceBrokenAt = '' },
                [pscustomobject]@{ ItemId = 'item-002'; ShareId = 'share-001'; ItemType = 'File'; FullPath = '\\files01\Share001\file02.txt'; RelativePath = 'file02.txt'; Depth = 1; Owner = 'CONTOSO\Owner'; InheritanceEnabled = 'True'; InheritanceBrokenAt = '' },
                [pscustomobject]@{ ItemId = 'item-003'; ShareId = 'share-002'; ItemType = 'File'; FullPath = '\\files01\Share002\file03.txt'; RelativePath = 'file03.txt'; Depth = 1; Owner = 'CONTOSO\Owner'; InheritanceEnabled = 'True'; InheritanceBrokenAt = '' }
            ) | Export-Csv -LiteralPath (Join-Path $exportPath 'items.csv') -NoTypeInformation -Encoding UTF8
            @(
                [pscustomobject]@{ FindingId = 'finding-001'; FindingType = 'LongPathOperationalPolicy'; Severity = 'Warning'; ShareId = 'share-001'; ItemId = 'item-001'; FullPath = '\\files01\Share001\Deep\Path\file01.txt'; Identity = ''; ObservedValue = '300'; PolicyValue = '256'; Message = 'Long path evidence' }
                [pscustomobject]@{ FindingId = 'finding-002'; FindingType = 'DeepExplicitAce'; Severity = 'High'; ShareId = 'share-001'; ItemId = 'item-001'; FullPath = '\\files01\Share001\Deep\Path\file01.txt'; Identity = 'CONTOSO\Editors'; ObservedValue = '7'; PolicyValue = '2'; Message = 'Deep explicit ACE evidence' }
                [pscustomobject]@{ FindingId = 'finding-003'; FindingType = 'BrokenInheritance'; Severity = 'Medium'; ShareId = 'share-001'; ItemId = 'item-001'; FullPath = '\\files01\Share001\Deep\Path\file01.txt'; Identity = ''; ObservedValue = '\\files01\Share001\Deep'; PolicyValue = 'Inherited'; Message = 'Broken inheritance evidence' }
            ) | Export-Csv -LiteralPath (Join-Path $exportPath 'findings.csv') -NoTypeInformation -Encoding UTF8
            @(
                [pscustomobject]@{ ConflictId = 'conflict-001'; ConflictType = 'NtfsIdentityMissingShareGate'; ShareId = 'share-001'; ItemId = 'item-001'; Identity = 'CONTOSO\Editors'; ShareRights = ''; NtfsRights = 'Modify'; Severity = 'High'; Message = 'Conflict evidence' }
            ) | Export-Csv -LiteralPath (Join-Path $exportPath 'conflicts.csv') -NoTypeInformation -Encoding UTF8
            @(
                [pscustomobject]@{ ShareId = 'share-001'; Identity = 'CONTOSO\Readers'; Rights = 'Read'; AccessControlType = 'Allow'; Source = 'Get-SmbShareAccess' }
            ) | Export-Csv -LiteralPath (Join-Path $exportPath 'share_permissions.csv') -NoTypeInformation -Encoding UTF8
            @(
                [pscustomobject]@{ ItemId = 'item-001'; ShareId = 'share-001'; FullPath = '\\files01\Share001\Deep\Path\file01.txt'; Identity = 'CONTOSO\Editors'; Rights = 'Modify'; AccessControlType = 'Allow'; IsInherited = 'False'; InheritanceFlags = 'ContainerInherit,ObjectInherit'; PropagationFlags = 'None'; Depth = '7' },
                [pscustomobject]@{ ItemId = 'item-002'; ShareId = 'share-001'; FullPath = '\\files01\Share001\file02.txt'; Identity = 'CONTOSO\FileReaders'; Rights = 'Read'; AccessControlType = 'Allow'; IsInherited = 'False'; InheritanceFlags = 'None'; PropagationFlags = 'None'; Depth = '1' }
            ) | Export-Csv -LiteralPath (Join-Path $exportPath 'acl_entries.csv') -NoTypeInformation -Encoding UTF8
            @(
                [pscustomobject]@{ ParentGroup = 'CONTOSO\Readers'; ChildIdentity = 'CONTOSO\SSUser00001'; ChildObjectClass = 'user'; Depth = '1'; IsCycle = 'False'; IsTruncated = 'False' }
            ) | Export-Csv -LiteralPath (Join-Path $exportPath 'group_edges.csv') -NoTypeInformation -Encoding UTF8
            @(
                [pscustomobject]@{ BusinessUnit = 'Finance'; Owner = 'Finance Operations'; Pattern = '\\files01\Share001*'; Source = 'unit-test'; MatchingItems = '2'; Directories = '0'; Files = '2'; FindingCount = '3'; ConflictCount = '1'; PartialShareCount = '0'; RiskLevel = 'High' }
            ) | Export-Csv -LiteralPath (Join-Path $exportPath 'owner_risk_pivots.csv') -NoTypeInformation -Encoding UTF8

            $plan = [pscustomobject]@{
                MaxLabBytes = [int64]8589934592
                Users = @(
                    [pscustomobject]@{ SamAccountName = 'SSUser00001' },
                    [pscustomobject]@{ SamAccountName = 'SSUser00002' },
                    [pscustomobject]@{ SamAccountName = 'SSUser00003' }
                )
                Shares = @(
                    [pscustomobject]@{ ShareName = 'Share001' },
                    [pscustomobject]@{ ShareName = 'Share002' }
                )
                FileFixtures = @(
                    [pscustomobject]@{ ShareName = 'Share001'; RelativePath = 'Deep\Path\file01.txt'; SizeBytes = 512 }
                )
                AclScenarios = @(
                    [pscustomobject]@{ Name = 'EnterpriseLongPath'; RelativePath = ('A' * 260) }
                )
                ValidationCriteria = @(
                    [pscustomobject]@{ Name = 'EnterpriseUserPopulation'; Required = $true; MinimumValue = 3; Unit = 'users'; Description = 'Users' },
                    [pscustomobject]@{ Name = 'EnterpriseSharePopulation'; Required = $true; MinimumValue = 2; Unit = 'shares'; Description = 'Shares' },
                    [pscustomobject]@{ Name = 'EnterpriseRealFiles'; Required = $true; MinimumValue = 3; Unit = 'file fixtures'; Description = 'Files' },
                    [pscustomobject]@{ Name = 'EnterpriseDeepPaths'; Required = $true; MinimumValue = 1; Unit = 'deep file fixtures'; Description = 'Deep paths' },
                    [pscustomobject]@{ Name = 'EnterpriseLongPathPolicy'; Required = $true; MinimumValue = 1; Unit = 'long-path scenarios'; Description = 'Long paths' },
                    [pscustomobject]@{ Name = 'EnterpriseSharePermissions'; Required = $true; MinimumValue = 1; Unit = 'share permission rows'; Description = 'Share permissions' },
                    [pscustomobject]@{ Name = 'EnterpriseAclEntries'; Required = $true; MinimumValue = 2; Unit = 'acl rows'; Description = 'ACL rows' },
                    [pscustomobject]@{ Name = 'EnterpriseFileAclEntries'; Required = $true; MinimumValue = 1; Unit = 'file acl rows'; Description = 'File ACL rows' },
                    [pscustomobject]@{ Name = 'EnterpriseDeepExplicitAceFindings'; Required = $true; MinimumValue = 1; Unit = 'findings'; Description = 'Deep explicit ACE findings' },
                    [pscustomobject]@{ Name = 'EnterpriseBrokenInheritanceFindings'; Required = $true; MinimumValue = 1; Unit = 'findings'; Description = 'Broken inheritance findings' },
                    [pscustomobject]@{ Name = 'EnterpriseConflictFindings'; Required = $true; MinimumValue = 1; Unit = 'conflicts'; Description = 'Conflicts' },
                    [pscustomobject]@{ Name = 'EnterpriseGroupExpansion'; Required = $true; MinimumValue = 1; Unit = 'group edges'; Description = 'Group expansion' },
                    [pscustomobject]@{ Name = 'EnterpriseOwnerRiskPivots'; Required = $true; MinimumValue = 1; Unit = 'owner risk pivots'; Description = 'Owner risk pivots' },
                    [pscustomobject]@{ Name = 'EnterpriseDiskBudget'; Required = $true; MinimumValue = 1; Unit = 'pass/fail'; Description = 'Disk budget' }
                )
            }

            function Get-ShareSurferLabValidationDirectoryCounts {
                [pscustomobject]@{
                    UserCount = 4
                    GroupCount = 2
                    EvidenceSource = 'ActiveDirectory'
                    EvidenceDetail = 'MockedDirectoryUsers=4; MockedDirectoryGroups=2'
                }
            }

            $criteria = @(New-ShareSurferLabValidationCriteriaRows -Plan $plan -ExportPath $exportPath -LabRoot $labRoot -CreateLab -IncludeFiles)
            $userCriterion = @($criteria | Where-Object { $_.Name -eq 'EnterpriseUserPopulation' })[0]
            $shareCriterion = @($criteria | Where-Object { $_.Name -eq 'EnterpriseSharePopulation' })[0]
            $fileCriterion = @($criteria | Where-Object { $_.Name -eq 'EnterpriseRealFiles' })[0]
            $deepCriterion = @($criteria | Where-Object { $_.Name -eq 'EnterpriseDeepPaths' })[0]
            $longPathCriterion = @($criteria | Where-Object { $_.Name -eq 'EnterpriseLongPathPolicy' })[0]
            $sharePermissionCriterion = @($criteria | Where-Object { $_.Name -eq 'EnterpriseSharePermissions' })[0]
            $aclCriterion = @($criteria | Where-Object { $_.Name -eq 'EnterpriseAclEntries' })[0]
            $fileAclCriterion = @($criteria | Where-Object { $_.Name -eq 'EnterpriseFileAclEntries' })[0]
            $deepAceCriterion = @($criteria | Where-Object { $_.Name -eq 'EnterpriseDeepExplicitAceFindings' })[0]
            $brokenInheritanceCriterion = @($criteria | Where-Object { $_.Name -eq 'EnterpriseBrokenInheritanceFindings' })[0]
            $conflictCriterion = @($criteria | Where-Object { $_.Name -eq 'EnterpriseConflictFindings' })[0]
            $groupExpansionCriterion = @($criteria | Where-Object { $_.Name -eq 'EnterpriseGroupExpansion' })[0]
            $ownerRiskCriterion = @($criteria | Where-Object { $_.Name -eq 'EnterpriseOwnerRiskPivots' })[0]
            $diskCriterion = @($criteria | Where-Object { $_.Name -eq 'EnterpriseDiskBudget' })[0]

            Assert-Equal ([int]$userCriterion.ActualValue) 4 'User validation should prefer directory counts when available.'
            Assert-Equal $userCriterion.EvidenceSource 'ActiveDirectory' 'User validation should identify directory evidence.'
            Assert-Equal ([int]$shareCriterion.ActualValue) 2 'Share validation should use scanned shares.'
            Assert-Equal $shareCriterion.EvidenceSource 'ScanExport:shares.csv' 'Share validation should identify scan export evidence.'
            Assert-Equal ([int]$fileCriterion.ActualValue) 3 'File validation should use scanned file item rows.'
            Assert-Equal $fileCriterion.EvidenceSource 'ScanExport:items.csv' 'File validation should identify scanned item evidence.'
            Assert-Equal ([int]$deepCriterion.ActualValue) 1 'Deep path validation should use scanned item depth.'
            Assert-Equal $deepCriterion.EvidenceSource 'ScanExport:items.csv' 'Deep path validation should identify scanned item evidence.'
            Assert-Equal ([int]$longPathCriterion.ActualValue) 1 'Long-path validation should use generated findings.'
            Assert-Equal $longPathCriterion.EvidenceSource 'ScanExport:findings.csv' 'Long-path validation should identify findings evidence.'
            Assert-Equal ([int]$sharePermissionCriterion.ActualValue) 1 'Share permission validation should use scanned share permission rows.'
            Assert-Equal $sharePermissionCriterion.EvidenceSource 'ScanExport:share_permissions.csv' 'Share permission validation should identify share permission evidence.'
            Assert-Equal ([int]$aclCriterion.ActualValue) 2 'ACL validation should use scanned ACL rows.'
            Assert-Equal $aclCriterion.EvidenceSource 'ScanExport:acl_entries.csv' 'ACL validation should identify ACL export evidence.'
            Assert-Equal ([int]$fileAclCriterion.ActualValue) 1 'File ACL validation should use file-specific ACL rows.'
            Assert-Equal $fileAclCriterion.EvidenceSource 'ScanExport:acl_entries.csv' 'File ACL validation should identify ACL export evidence.'
            Assert-Equal ([int]$deepAceCriterion.ActualValue) 1 'Deep explicit ACE validation should use findings.'
            Assert-Equal $deepAceCriterion.EvidenceSource 'ScanExport:findings.csv' 'Deep explicit ACE validation should identify findings evidence.'
            Assert-Equal ([int]$brokenInheritanceCriterion.ActualValue) 1 'Broken inheritance validation should use findings.'
            Assert-Equal $brokenInheritanceCriterion.EvidenceSource 'ScanExport:findings.csv' 'Broken inheritance validation should identify findings evidence.'
            Assert-Equal ([int]$conflictCriterion.ActualValue) 1 'Conflict validation should use conflict rows.'
            Assert-Equal $conflictCriterion.EvidenceSource 'ScanExport:conflicts.csv' 'Conflict validation should identify conflicts evidence.'
            Assert-Equal ([int]$groupExpansionCriterion.ActualValue) 1 'Group expansion validation should use group edge rows.'
            Assert-Equal $groupExpansionCriterion.EvidenceSource 'ScanExport:group_edges.csv' 'Group expansion validation should identify group expansion evidence.'
            Assert-Equal ([int]$ownerRiskCriterion.ActualValue) 1 'Owner risk pivot validation should use owner risk pivot rows.'
            Assert-Equal $ownerRiskCriterion.EvidenceSource 'ScanExport:owner_risk_pivots.csv' 'Owner risk pivot validation should identify owner risk pivot export evidence.'
            Assert-Equal ([int]$diskCriterion.ActualValue) 1 'Disk budget validation should pass under the configured budget.'
            Assert-Equal $diskCriterion.EvidenceSource 'FileSystem' 'Disk budget validation should measure the lab root when available.'
            Assert-True ([string]$diskCriterion.EvidenceDetail -like '*ActualBytes=*') 'Disk budget evidence should include measured bytes.'
            Assert-True (@($criteria | Where-Object { -not $_.Passed }).Count -eq 0) 'All synthetic validation criteria should pass.'

            $existingLabCriteria = @(New-ShareSurferLabValidationCriteriaRows -Plan $plan -ExportPath $exportPath -LabRoot $labRoot -IncludeFiles)
            $existingLabDiskCriterion = @($existingLabCriteria | Where-Object { $_.Name -eq 'EnterpriseDiskBudget' })[0]
            Assert-Equal $existingLabDiskCriterion.EvidenceSource 'FileSystem' 'Disk budget validation should use filesystem evidence for an existing lab root even when -CreateLab is not set.'
            Assert-True ([string]$existingLabDiskCriterion.EvidenceDetail -like '*ActualBytes=*') 'Existing lab disk-budget evidence should include measured bytes.'

            $liveEvidence = Test-ShareSurferLabValidationLiveEvidence -CriteriaRows $criteria
            Assert-True $liveEvidence.IsValid 'Live evidence gate should pass when all required criteria have live evidence.'
            Assert-Equal ([int]$liveEvidence.FallbackCount) 0 'Live evidence gate should not report fallback criteria when live evidence is present.'

            $fallbackCriteria = @(
                $criteria
                [pscustomobject]@{
                    Name = 'EnterprisePlanOnlyProof'
                    Required = $true
                    EvidenceSource = 'LabPlan'
                    EvidenceDetail = 'Planned only'
                }
                [pscustomobject]@{
                    Name = 'EnterpriseUnavailableProof'
                    Required = $true
                    EvidenceSource = 'DirectoryUnavailable'
                    EvidenceDetail = 'Directory query failed'
                }
            )
            $fallbackResult = Test-ShareSurferLabValidationLiveEvidence -CriteriaRows $fallbackCriteria
            Assert-True (-not $fallbackResult.IsValid) 'Live evidence gate should fail when required criteria use fallback evidence.'
            Assert-Equal ([int]$fallbackResult.FallbackCount) 2 'Live evidence gate should count required fallback criteria.'
            Assert-True ($fallbackResult.FallbackCriteria -contains 'EnterprisePlanOnlyProof') 'Live evidence gate should identify plan-only criteria.'
            Assert-True ($fallbackResult.FallbackCriteria -contains 'EnterpriseUnavailableProof') 'Live evidence gate should identify unavailable evidence criteria.'

            $reviewRows = @(New-ShareSurferLabValidationEvidenceReview -CriteriaRows $fallbackCriteria)
            $planOnlyReview = @($reviewRows | Where-Object { $_.Name -eq 'EnterprisePlanOnlyProof' })[0]
            $unavailableReview = @($reviewRows | Where-Object { $_.Name -eq 'EnterpriseUnavailableProof' })[0]
            Assert-Equal $planOnlyReview.EvidenceStatus 'PlanOnly' 'Evidence review should classify plan-only required criteria.'
            Assert-Equal $unavailableReview.EvidenceStatus 'EvidenceUnavailable' 'Evidence review should classify unavailable required criteria.'
            Assert-True ([string]$planOnlyReview.NextAction -like '*Create or scan the lab*') 'Evidence review should give an operator next action for plan-only criteria.'
        }
    },
    @{
        Name = 'Invoke-ShareSurferScan exports normalized CSVs and findings from imported inventory'
        Body = {
            Import-Module $moduleManifest -Force
            $outputPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferExport-' + [guid]::NewGuid().ToString('N'))

            Invoke-ShareSurferScan -InputObject (New-TestInventory) -OutputPath $outputPath -OperationalPathLengthThreshold 256 -ExplicitAceDepthThreshold 2 -ObsAttribute 'extensionAttribute10' -SkipIdentityEnrichment | Out-Null

            $expectedFiles = @(
                'shares.csv',
                'items.csv',
                'share_permissions.csv',
                'acl_entries.csv',
                'identities.csv',
                'group_edges.csv',
                'org_chains.csv',
                'owner_mappings.csv',
                'owner_risk_pivots.csv',
                'conflicts.csv',
                'findings.csv',
                'scan_events.csv',
                'scan_manifest.csv'
            )
            foreach ($file in $expectedFiles) {
                Assert-True (Test-Path -LiteralPath (Join-Path $outputPath $file)) ("Missing export file {0}" -f $file)
            }
            Assert-True (Test-Path -LiteralPath (Join-Path $outputPath 'scan_events.jsonl')) 'Scan exports should include a first-class raw JSONL event log.'
            $eventLogLines = @(Get-Content -LiteralPath (Join-Path $outputPath 'scan_events.jsonl'))
            Assert-True ($eventLogLines.Count -gt 0) 'Raw JSONL event log should include scan events.'
            $firstEventLogRow = $eventLogLines[0] | ConvertFrom-Json
            Assert-True (-not [string]::IsNullOrWhiteSpace([string]$firstEventLogRow.EventType)) 'Raw JSONL event log rows should be structured event objects.'

            $findings = Import-Csv -LiteralPath (Join-Path $outputPath 'findings.csv')
            Assert-True ($findings.FindingType -contains 'LongPathOperationalPolicy') 'Findings should include the operational 256-character warning.'
            Assert-True ($findings.FindingType -contains 'DeepExplicitAce') 'Findings should include explicit ACEs deeper than level 2.'
            Assert-True ($findings.FindingType -contains 'BrokenInheritance') 'Findings should include broken inheritance.'

            $conflicts = Import-Csv -LiteralPath (Join-Path $outputPath 'conflicts.csv')
            Assert-True ($conflicts.ConflictType -contains 'NtfsIdentityMissingShareGate') 'Conflicts should show NTFS identities missing at the share gate.'

            $ownerRiskPivots = Import-Csv -LiteralPath (Join-Path $outputPath 'owner_risk_pivots.csv')
            Assert-True ($ownerRiskPivots.BusinessUnit -contains 'Finance') 'Owner risk pivots should expose business-unit review rows as CSV.'
            Assert-True ($ownerRiskPivots[0].PSObject.Properties.Name -contains 'FindingCount') 'Owner risk pivot CSV should include finding counts.'
            Assert-True ($ownerRiskPivots[0].PSObject.Properties.Name -contains 'ConflictCount') 'Owner risk pivot CSV should include conflict counts.'
            Assert-True ($ownerRiskPivots[0].PSObject.Properties.Name -contains 'PartialShareCount') 'Owner risk pivot CSV should include partial-share counts.'
            Assert-True ($ownerRiskPivots[0].PSObject.Properties.Name -contains 'RiskLevel') 'Owner risk pivot CSV should include review risk levels.'

            $events = Import-Csv -LiteralPath (Join-Path $outputPath 'scan_events.csv')
            Assert-True ($events.EventType -contains 'ScanStarted') 'Scan events should record scan start.'
            Assert-True ($events.EventType -contains 'ExportCompleted') 'Scan events should record export completion.'
        }
    },
    @{
        Name = 'Invoke-ShareSurferScan marks shares partial when collection errors are recorded'
        Body = {
            Import-Module $moduleManifest -Force
            $outputPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferExport-' + [guid]::NewGuid().ToString('N'))
            $inventory = New-TestInventory
            $inventory | Add-Member -MemberType NoteProperty -Name ScanErrors -Value @(
                [pscustomobject]@{
                    ShareId = 'share-finance'
                    FullPath = '\\files01\Finance\Denied'
                    ErrorType = 'AclReadError'
                    Message = 'Access denied while reading ACL.'
                },
                [pscustomobject]@{
                    ShareId = 'share-finance'
                    FullPath = '\\files01\Finance\Hidden'
                    ErrorType = 'EnumerationError'
                    Message = 'Access denied while enumerating children.'
                }
            )

            Invoke-ShareSurferScan -InputObject $inventory -OutputPath $outputPath -SkipIdentityEnrichment | Out-Null

            $shares = Import-Csv -LiteralPath (Join-Path $outputPath 'shares.csv')
            $findings = Import-Csv -LiteralPath (Join-Path $outputPath 'findings.csv')

            Assert-Equal $shares[0].PartialData 'True' 'Share rows should be partial when collection errors were recorded for the share.'
            Assert-True ($shares[0].PartialReason -like '*AclReadError=1*') 'Partial reason should summarize ACL read errors.'
            Assert-True ($shares[0].PartialReason -like '*EnumerationError=1*') 'Partial reason should summarize enumeration errors.'
            Assert-True ($findings.FindingType -contains 'CollectionError') 'Findings should preserve collection errors for troubleshooting.'
            Assert-True ($findings.FindingType -contains 'PartialSharePermissionData') 'Findings should include a partial-share row for business review.'
        }
    },
    @{
        Name = 'Invoke-ShareSurferScan enriches identities and recursive group edges from an inventory directory graph'
        Body = {
            Import-Module $moduleManifest -Force
            $outputPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferExport-' + [guid]::NewGuid().ToString('N'))

            Invoke-ShareSurferScan -InputObject (New-TestInventory) -OutputPath $outputPath -GroupExpansionMaxDepth 5 | Out-Null

            $identities = Import-Csv -LiteralPath (Join-Path $outputPath 'identities.csv')
            $groupEdges = Import-Csv -LiteralPath (Join-Path $outputPath 'group_edges.csv')
            $orgChains = Import-Csv -LiteralPath (Join-Path $outputPath 'org_chains.csv')

            Assert-True ($identities.Identity -contains 'CONTOSO\Ava.Accounting') 'Identity enrichment should include user members discovered through group expansion.'
            Assert-True ($groupEdges.ParentGroup -contains 'CONTOSO\FinanceEditors') 'Group expansion should include the top-level permission group.'
            Assert-True ($orgChains.Identity -contains 'CONTOSO\Ava.Accounting') 'Org chains should include enriched user manager and OBS data.'
        }
    },
    @{
        Name = 'Invoke-ShareSurferScan records AD lookup mode and marks truncated group expansion'
        Body = {
            Import-Module $moduleManifest -Force
            $outputPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferExport-' + [guid]::NewGuid().ToString('N'))

            Invoke-ShareSurferScan -InputObject (New-TestInventory) -OutputPath $outputPath -AdLookupMode DirectoryOnly -GroupExpansionMaxDepth 1 | Out-Null

            $manifest = Import-Csv -LiteralPath (Join-Path $outputPath 'scan_manifest.csv')
            $groupEdges = Import-Csv -LiteralPath (Join-Path $outputPath 'group_edges.csv')

            Assert-Equal $manifest[0].AdLookupMode 'DirectoryOnly' 'Scan manifest should record the requested AD lookup mode.'
            Assert-True (@($groupEdges | Where-Object { $_.ParentGroup -eq 'CONTOSO\FinanceEditors' -and $_.IsTruncated -eq 'True' }).Count -gt 0) 'Group expansion should mark edges truncated at the configured max depth.'
        }
    },
    @{
        Name = 'LDAP identity normalization preserves two-level manager chains and OBS attributes'
        Body = {
            Import-Module $moduleManifest -Force
            . (Join-Path $repoRoot 'src/ShareSurfer/Private/ConvertTo-ShareSurferArray.ps1')
            . (Join-Path $repoRoot 'src/ShareSurfer/Private/New-ShareSurferLdapIdentityRecord.ps1')

            $userProperties = @{
                samaccountname = @('Ava.Accounting')
                displayname = @('Ava Accounting')
                objectclass = @('top', 'person', 'organizationalPerson', 'user')
                employeeid = @('E1001')
                employeenumber = @('1001')
                manager = @('CN=Morgan Manager,OU=Users,DC=example,DC=test')
                extensionattribute10 = @('CORP.FIN.AP')
            }

            $user = New-ShareSurferLdapIdentityRecord -Identity 'CONTOSO\Ava.Accounting' -Properties $userProperties -ObsAttribute 'extensionAttribute10' -ManagerLevel2 'CN=Taylor Director,OU=Users,DC=example,DC=test'
            Assert-Equal $user.ObjectClass 'user' 'LDAP user record should identify user object class.'
            Assert-Equal $user.ManagerLevel1 'CN=Morgan Manager,OU=Users,DC=example,DC=test' 'LDAP user record should preserve direct manager DN.'
            Assert-Equal $user.ManagerLevel2 'CN=Taylor Director,OU=Users,DC=example,DC=test' 'LDAP user record should preserve manager manager DN.'
            Assert-Equal $user.ObsPath 'CORP.FIN.AP' 'LDAP user record should read the configured OBS attribute.'
            Assert-Equal $user.EmployeeId 'E1001' 'LDAP user record should preserve employee ID.'

            $groupProperties = @{
                samaccountname = @('FinanceEditors')
                displayname = @('Finance Editors')
                objectclass = @('top', 'group')
                member = @('CN=Ava Accounting,OU=Users,DC=example,DC=test')
                extensionattribute10 = @('CORP.FIN')
            }
            $group = New-ShareSurferLdapIdentityRecord -Identity 'CONTOSO\FinanceEditors' -Properties $groupProperties -ObsAttribute 'extensionAttribute10' -Members @('CONTOSO\Ava.Accounting')
            Assert-Equal $group.ObjectClass 'group' 'LDAP group record should identify group object class.'
            Assert-True ($group.Members -contains 'CONTOSO\Ava.Accounting') 'LDAP group record should preserve resolved members.'

            $ldapScript = Get-Content -LiteralPath (Join-Path $repoRoot 'src/ShareSurfer/Private/Get-ShareSurferDirectoryIdentity.ps1') -Raw
            Assert-True ($ldapScript -like '*Get-ShareSurferLdapManagerLevel2*') 'LDAP fallback should resolve manager manager for org-chain rollups.'
        }
    },
    @{
        Name = 'Invoke-ShareSurferScan classifies restrictive share gates and NTFS deny collisions'
        Body = {
            Import-Module $moduleManifest -Force
            $outputPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferExport-' + [guid]::NewGuid().ToString('N'))
            $inventory = New-TestInventory
            $inventory.AclEntries += [pscustomobject]@{
                ItemId = 'item-root'
                ShareId = 'share-finance'
                FullPath = '\\files01\Finance'
                Identity = 'CONTOSO\FinanceReaders'
                Rights = 'Modify'
                AccessControlType = 'Allow'
                IsInherited = $false
                InheritanceFlags = 'ContainerInherit,ObjectInherit'
                PropagationFlags = 'None'
                Depth = 0
            }
            $inventory.AclEntries += [pscustomobject]@{
                ItemId = 'item-root'
                ShareId = 'share-finance'
                FullPath = '\\files01\Finance'
                Identity = 'CONTOSO\FinanceReaders'
                Rights = 'Read'
                AccessControlType = 'Deny'
                IsInherited = $false
                InheritanceFlags = 'ContainerInherit,ObjectInherit'
                PropagationFlags = 'None'
                Depth = 0
            }

            Invoke-ShareSurferScan -InputObject $inventory -OutputPath $outputPath -SkipIdentityEnrichment | Out-Null
            $conflicts = Import-Csv -LiteralPath (Join-Path $outputPath 'conflicts.csv')

            Assert-True ($conflicts.ConflictType -contains 'ShareRightsRestrictNtfs') 'Conflicts should show when share-level rights restrict broader NTFS allows.'
            Assert-True ($conflicts.ConflictType -contains 'NtfsDenyAllowCollision') 'Conflicts should show when the same identity has NTFS allow and deny entries on an item.'
            Assert-True ($conflicts.ConflictType -contains 'ShareAllowsNtfsDenies') 'Conflicts should show when a share gate allows an identity that is denied by NTFS.'
        }
    },
    @{
        Name = 'Invoke-ShareSurferScan carries inheritance break ancestry to descendants'
        Body = {
            Import-Module $moduleManifest -Force
            $outputPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferExport-' + [guid]::NewGuid().ToString('N'))
            $inventory = New-TestInventory
            $inventory.Items += [pscustomobject]@{
                ItemId = 'item-child'
                ShareId = 'share-finance'
                ItemType = 'File'
                FullPath = '\\files01\Finance\Delegated\Child\report.xlsx'
                RelativePath = 'Delegated\Child\report.xlsx'
                Depth = 3
                Owner = 'CONTOSO\FinanceOwner'
                InheritanceEnabled = $true
                InheritanceBrokenAt = ''
            }

            Invoke-ShareSurferScan -InputObject $inventory -OutputPath $outputPath -SkipIdentityEnrichment | Out-Null
            $items = Import-Csv -LiteralPath (Join-Path $outputPath 'items.csv')
            $child = @($items | Where-Object { $_.ItemId -eq 'item-child' })[0]

            Assert-Equal $child.InheritanceBrokenAt '\\files01\Finance\Delegated' 'Descendants should retain the ancestor where inheritance first broke.'
        }
    },
    @{
        Name = 'Invoke-ShareSurferScan imports owner mapping CSVs for business-unit pivots'
        Body = {
            Import-Module $moduleManifest -Force
            $outputPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferExport-' + [guid]::NewGuid().ToString('N'))
            $mappingPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferOwnerMap-' + [guid]::NewGuid().ToString('N') + '.csv')
            @(
                [pscustomobject]@{
                    Pattern = '\\files01\Finance*'
                    Owner = 'Finance Operations'
                    BusinessUnit = 'Finance'
                    Source = 'unit-test-csv'
                }
            ) | Export-Csv -LiteralPath $mappingPath -NoTypeInformation -Encoding UTF8
            $inventory = New-TestInventory
            $inventory.OwnerMappings = @()

            Invoke-ShareSurferScan -InputObject $inventory -OutputPath $outputPath -OwnerMappingPath $mappingPath -SkipIdentityEnrichment | Out-Null
            $ownerMappings = Import-Csv -LiteralPath (Join-Path $outputPath 'owner_mappings.csv')

            Assert-Equal $ownerMappings[0].Pattern '\\files01\Finance*' 'Owner mapping pattern should be imported from CSV.'
            Assert-Equal $ownerMappings[0].BusinessUnit 'Finance' 'Owner mapping business unit should be imported from CSV.'
            Assert-Equal $ownerMappings[0].Source 'unit-test-csv' 'Owner mapping source should be imported from CSV.'
        }
    },
    @{
        Name = 'Test-ShareSurferExport validates the normalized CSV set'
        Body = {
            Import-Module $moduleManifest -Force
            $outputPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferExport-' + [guid]::NewGuid().ToString('N'))
            Invoke-ShareSurferScan -InputObject (New-TestInventory) -OutputPath $outputPath -SkipIdentityEnrichment | Out-Null

            $result = Test-ShareSurferExport -ExportPath $outputPath

            Assert-True $result.IsValid 'Export validation should pass for a complete export set.'
            Assert-Equal $result.MissingFiles.Count 0 'No expected CSV files should be missing.'
        }
    },
    @{
        Name = 'Test-ShareSurferExport reports row counts and structured schema errors'
        Body = {
            Import-Module $moduleManifest -Force
            $outputPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferExport-' + [guid]::NewGuid().ToString('N'))
            Invoke-ShareSurferScan -InputObject (New-TestInventory) -OutputPath $outputPath -SkipIdentityEnrichment | Out-Null

            $validResult = Test-ShareSurferExport -ExportPath $outputPath
            $aclResult = @($validResult.FileResults | Where-Object { $_.FileName -eq 'acl_entries.csv' })[0]
            $manifestResult = @($validResult.FileResults | Where-Object { $_.FileName -eq 'scan_manifest.csv' })[0]
            Assert-True ([int]$aclResult.RowCount -gt 0) 'Export validation should report row counts for populated CSVs.'
            Assert-Equal ([int]$manifestResult.RowCount) 1 'Export validation should report the single scan manifest row.'

            $aclPath = Join-Path $outputPath 'acl_entries.csv'
            $brokenRows = Import-Csv -LiteralPath $aclPath | Select-Object ItemId, ShareId, FullPath, Rights, AccessControlType, IsInherited, InheritanceFlags, PropagationFlags, Depth
            $brokenRows | Export-Csv -LiteralPath $aclPath -NoTypeInformation -Encoding UTF8

            $brokenResult = Test-ShareSurferExport -ExportPath $outputPath
            $brokenAclResult = @($brokenResult.FileResults | Where-Object { $_.FileName -eq 'acl_entries.csv' })[0]
            Assert-True (-not $brokenResult.IsValid) 'Export validation should fail when a required column is missing.'
            Assert-True ($brokenAclResult.MissingColumns -contains 'Identity') 'File-level validation should report the missing column.'
            Assert-True ($brokenResult.SchemaErrors -contains 'acl_entries.csv is missing column Identity.') 'Top-level schema errors should keep the readable error message.'
        }
    },
    @{
        Name = 'ConvertTo-ShareSurferReport generates an offline static report with Azure path policy language'
        Body = {
            Import-Module $moduleManifest -Force
            $outputPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferExport-' + [guid]::NewGuid().ToString('N'))
            $reportPath = Join-Path $outputPath 'report.html'
            $inventory = New-TestInventory
            $inventory | Add-Member -MemberType NoteProperty -Name ScanErrors -Value @(
                [pscustomobject]@{
                    ShareId = 'share-finance'
                    FullPath = '\\files01\Finance\Denied'
                    ErrorType = 'AclReadError'
                    Message = 'Access denied while reading ACL.'
                }
            )
            Invoke-ShareSurferScan -InputObject $inventory -OutputPath $outputPath -SkipIdentityEnrichment | Out-Null

            ConvertTo-ShareSurferReport -ExportPath $outputPath -OutputPath $reportPath | Out-Null
            $report = Get-Content -LiteralPath $reportPath -Raw

            Assert-True ($report -like '*ShareSurfer*') 'Report should include ShareSurfer branding.'
            Assert-True ($report -like '*255-character path components*') 'Report should document Azure Files component limits.'
            Assert-True ($report -like '*2,048-character full paths*') 'Report should document Azure Files full path limit.'
            Assert-True ($report -like '*operational migration policy*') 'Report should distinguish policy warning from hard Azure limit.'
            Assert-True ($report -like '*type="application/json"*') 'Report should embed scan data as application/json rather than executable JavaScript.'
            Assert-True ($report -like '*rel="icon" href="data:,"*') 'Report should suppress missing favicon requests for offline review.'
            Assert-True ($report -notlike '*innerHTML = columns.map*') 'Report table rendering must not inject CSV-derived values with innerHTML.'
            Assert-True ($report -like '*Scan Events*') 'Report should expose scan event logs.'
            Assert-True ($report -like '*Business Unit Pivots*') 'Report should expose business-unit pivots.'
            Assert-True ($report -like '*owner_pivots*') 'Report should build owner pivots from exported mappings and items.'
            Assert-True ($report -like '*Owner Risk Pivots*') 'Report should expose risk-aware owner and business-unit pivots.'
            Assert-True ($report -like '*FindingCount*') 'Owner pivots should include finding counts for mapped paths.'
            Assert-True ($report -like '*ConflictCount*') 'Owner pivots should include conflict counts for mapped paths.'
            Assert-True ($report -like '*PartialShareCount*') 'Owner pivots should include partial-share counts for mapped paths.'
            Assert-True ($report -like '*RiskLevel*') 'Owner pivots should include a business-review risk level.'
            Assert-True ($report -like '*Finding Rollups*') 'Report should expose finding rollups for business-unit triage.'
            Assert-True ($report -like '*Conflict Rollups*') 'Report should expose conflict rollups for access-model triage.'
            Assert-True ($report -like '*Org Chain Rollups*') 'Report should expose manager and OBS rollups.'
            Assert-True ($report -like '*Group Browser*') 'Report should expose a group expansion browsing view.'
            Assert-True ($report -like '*buildRollups*') 'Report should build dynamic rollup tables from CSV exports.'
            Assert-True ($report -like '*Business Review Dashboard*') 'Report should present as a business-review dashboard.'
            Assert-True ($report -like '*Executive Summary*') 'Report should include an executive summary section.'
            Assert-True ($report -like '*Priority Actions*') 'Report should include prioritized next actions for business reviewers.'
            Assert-True ($report -like '*Dashboard Filters*') 'Report should include dashboard-level filters.'
            Assert-True ($report -like '*business-unit-filter*') 'Report should include an explicit business-unit filter.'
            Assert-True ($report -like '*owner-filter*') 'Report should include an explicit data-owner filter.'
            Assert-True ($report -like '*risk-filter*') 'Report should include an explicit review-risk filter.'
            Assert-True ($report -like '*populateDashboardFilters*') 'Report should populate owner/business-unit filter controls from owner pivots.'
            Assert-True ($report -like '*rowMatchesOwnerContext*') 'Report should apply owner-context filters to mapped findings and conflicts.'
            Assert-True ($report -like '*Active dashboard filters*') 'Report should show the active owner/business-unit filter context.'
            Assert-True ($report -like '*data-view="findings"*') 'Report should include tabbed dashboard views.'
            Assert-True ($report -like '*renderPriorityActions*') 'Report should dynamically build priority actions from exported data.'
            Assert-True ($report -like '*showView*') 'Report should dynamically switch dashboard views.'
            Assert-True ($report -like '*risk-badge*') 'Report should include visual risk badges for business users.'
            Assert-True ($report -like '*Visual Risk Rollups*') 'Report should include visual risk rollups for business reviewers.'
            Assert-True ($report -like '*data-chart="finding"*') 'Report should expose a finding chart container.'
            Assert-True ($report -like '*data-chart="conflict"*') 'Report should expose a conflict chart container.'
            Assert-True ($report -like '*data-chart="owner"*') 'Report should expose an owner/business-unit chart container.'
            Assert-True ($report -like '*data-view="diagnostics"*') 'Report should include a diagnostics dashboard view.'
            Assert-True ($report -like '*Collection Error Drilldown*') 'Report should expose collection errors as a first-class diagnostic table.'
            Assert-True ($report -like '*Collection Errors by Type*') 'Report should chart collection errors by error type.'
            Assert-True ($report -like '*data-chart="collection-error"*') 'Report should expose a collection-error chart container.'
            Assert-True ($report -like '*collection_error_rollups*') 'Report should build collection-error rollups from findings.'
            Assert-True ($report -like '*collection-error-chart*') 'Report should render a collection-error chart.'
            Assert-True ($report -like '*renderBarChart*') 'Report should render offline native bar charts from embedded CSV data.'
            Assert-True ($report -like '*focusDashboardValue*') 'Report should support chart-driven drilldown filtering.'
            Assert-True ($report -like '*min-width: 760px*') 'Report tables should remain readable inside horizontal scroll containers on mobile.'
            Assert-True ($report -like '*.summary, .visual-grid { grid-template-columns: 1fr; }*') 'Report summary and visual grids should collapse cleanly on mobile.'
        }
    },
    @{
        Name = 'Invoke-ShareSurferScan collects mocked share-level permissions during target path scans'
        Body = {
            Import-Module $moduleManifest -Force
            $targetPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferTarget-' + [guid]::NewGuid().ToString('N'))
            New-Item -ItemType Directory -Path $targetPath -Force | Out-Null
            function global:Get-SmbShareAccess {
                param([string] $Name)
                [pscustomobject]@{
                    Name = $Name
                    AccountName = 'CONTOSO\MockShareReaders'
                    AccessRight = 'Read'
                    AccessControlType = 'Allow'
                }
            }
            try {
                $outputPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferExport-' + [guid]::NewGuid().ToString('N'))
                Invoke-ShareSurferScan -TargetPath $targetPath -OutputPath $outputPath -SkipIdentityEnrichment | Out-Null
                $sharePermissions = Import-Csv -LiteralPath (Join-Path $outputPath 'share_permissions.csv')
                $shares = Import-Csv -LiteralPath (Join-Path $outputPath 'shares.csv')

                Assert-True ($sharePermissions.Identity -contains 'CONTOSO\MockShareReaders') 'TargetPath scans should collect share-level permissions when Get-SmbShareAccess is available.'
                Assert-Equal $shares[0].PartialData 'False' 'Share data should not be partial when share permissions were collected.'
            }
            finally {
                Remove-Item -Path function:\Get-SmbShareAccess -ErrorAction SilentlyContinue
            }
        }
    },
    @{
        Name = 'Invoke-ShareSurferScan scans mocked SMB share targets by ComputerName and ShareName'
        Body = {
            Import-Module $moduleManifest -Force
            $shareRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferSmbShare-' + [guid]::NewGuid().ToString('N'))
            New-Item -ItemType Directory -Path $shareRoot -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $shareRoot 'share-file.txt') -Value 'share mode'

            function global:Get-SmbShare {
                param(
                    [string] $Name,
                    [string] $CimSession
                )
                [pscustomobject]@{
                    Name = $Name
                    Path = $shareRoot
                    Description = 'Mocked SMB share'
                    PSComputerName = $CimSession
                }
            }

            function global:Get-SmbShareAccess {
                param(
                    [string] $Name,
                    [string] $CimSession
                )
                [pscustomobject]@{
                    Name = $Name
                    AccountName = 'CONTOSO\ShareModeReaders'
                    AccessRight = 'Read'
                    AccessControlType = 'Allow'
                }
            }

            try {
                $outputPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferExport-' + [guid]::NewGuid().ToString('N'))
                Invoke-ShareSurferScan -ComputerName 'files01' -ShareName 'Finance' -OutputPath $outputPath -IncludeFiles -SkipIdentityEnrichment | Out-Null
                $shares = Import-Csv -LiteralPath (Join-Path $outputPath 'shares.csv')
                $permissions = Import-Csv -LiteralPath (Join-Path $outputPath 'share_permissions.csv')
                $events = Import-Csv -LiteralPath (Join-Path $outputPath 'scan_events.csv')

                Assert-Equal $shares[0].ComputerName 'files01' 'SMB share scans should preserve the requested computer name.'
                Assert-Equal $shares[0].ShareName 'Finance' 'SMB share scans should preserve the requested share name.'
                Assert-True ($permissions.Identity -contains 'CONTOSO\ShareModeReaders') 'SMB share scans should collect share-level permissions.'
                Assert-True ($events.EventType -contains 'ShareTargetResolved') 'SMB share scans should log share target resolution.'
            }
            finally {
                Remove-Item -Path function:\Get-SmbShare -ErrorAction SilentlyContinue
                Remove-Item -Path function:\Get-SmbShareAccess -ErrorAction SilentlyContinue
            }
        }
    },
    @{
        Name = 'New-ShareSurferSupportBundle redacts sensitive values with stable tokens'
        Body = {
            Import-Module $moduleManifest -Force
            $outputPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferExport-' + [guid]::NewGuid().ToString('N'))
            $bundlePath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferBundle-' + [guid]::NewGuid().ToString('N'))
            $inventory = New-TestInventory
            $inventory | Add-Member -MemberType NoteProperty -Name ScanEvents -Value @(
                [pscustomobject]@{
                    EventId = 'event-sensitive'
                    Timestamp = '2026-06-04T00:00:00.0000000Z'
                    Level = 'Info'
                    EventType = 'FixtureSensitiveEvent'
                    Source = 'Fixture'
                    ShareId = 'share-finance'
                    ItemId = 'item-deep'
                    Message = 'Collected CONTOSO\FinanceEditors from \\files01\Finance'
                    Detail = '\\files01\Finance\Delegated'
                }
            )
            Invoke-ShareSurferScan -InputObject $inventory -OutputPath $outputPath -SkipIdentityEnrichment | Out-Null
            ConvertTo-ShareSurferReport -ExportPath $outputPath -OutputPath (Join-Path $outputPath 'report.html') | Out-Null

            New-ShareSurferSupportBundle -ExportPath $outputPath -OutputPath $bundlePath -RedactionMode StableToken -RedactionSalt 'unit-test' -IncludeReport | Out-Null
            $rawEventLogPath = Join-Path $outputPath 'scan_events.jsonl'
            $redactedEventLogPath = Join-Path $bundlePath 'scan_events.jsonl'
            $rawEventLog = Get-Content -LiteralPath $rawEventLogPath -Raw
            $redactedEventLog = Get-Content -LiteralPath $redactedEventLogPath -Raw
            $redactedAcl = Get-Content -LiteralPath (Join-Path $bundlePath 'acl_entries.csv') -Raw
            $redactedFindings = Get-Content -LiteralPath (Join-Path $bundlePath 'findings.csv') -Raw
            $redactedConflicts = Get-Content -LiteralPath (Join-Path $bundlePath 'conflicts.csv') -Raw
            $redactedEvents = Get-Content -LiteralPath (Join-Path $bundlePath 'scan_events.csv') -Raw
            $redactedManifest = Get-Content -LiteralPath (Join-Path $bundlePath 'scan_manifest.csv') -Raw
            $redactedReportPath = Join-Path $bundlePath 'report.html'
            $bundleManifestPath = Join-Path $bundlePath 'support_bundle_manifest.csv'
            $bundleFilesPath = Join-Path $bundlePath 'support_bundle_files.csv'
            $redactionAuditPath = Join-Path $bundlePath 'support_bundle_redaction_audit.csv'

            Assert-True ($rawEventLog -like '*CONTOSO*') 'Raw JSONL event log should preserve source values for trusted internal debugging.'
            Assert-True ($redactedEventLog -notlike '*CONTOSO*') 'Redacted JSONL event log must not contain source domain names.'
            Assert-True ($redactedEventLog -notlike '*files01*') 'Redacted JSONL event log must not contain source server names.'
            Assert-True ($redactedEventLog -like '*ID-*') 'Redacted JSONL event log should preserve relationships with stable tokens.'
            Assert-True ($redactedAcl -notlike '*CONTOSO*') 'Redacted bundle must not contain the source domain name.'
            Assert-True ($redactedAcl -notlike '*FinanceEditors*') 'Redacted bundle must not contain source group names.'
            Assert-True ($redactedAcl -like '*ID-*') 'Stable token redaction should preserve relationships with synthetic IDs.'
            Assert-True ($redactedFindings -notlike '*\\files01\Finance\Delegated*') 'ObservedValue must redact inheritance break paths.'
            Assert-True ($redactedConflicts -like '*ID-*') 'Conflicts should retain stable tokens for cross-file identity correlation.'

            $redactedIdentities = Get-Content -LiteralPath (Join-Path $bundlePath 'identities.csv') -Raw
            $redactedOwners = Get-Content -LiteralPath (Join-Path $bundlePath 'owner_mappings.csv') -Raw
            $redactedOwnerRiskPivots = Get-Content -LiteralPath (Join-Path $bundlePath 'owner_risk_pivots.csv') -Raw
            Assert-True ($redactedIdentities -notlike '*E1001*') 'Employee IDs must be anonymized.'
            Assert-True ($redactedIdentities -notlike '*1001*') 'Employee numbers must be anonymized.'
            Assert-True ($redactedOwners -notlike '*Finance*') 'Business unit names and owner mappings must be anonymized.'
            Assert-True ($redactedOwnerRiskPivots -notlike '*Finance*') 'Owner risk pivot business-unit names must be anonymized.'
            Assert-True ($redactedOwnerRiskPivots -like '*ID-*') 'Owner risk pivots should preserve review relationships with stable tokens.'
            Assert-True ($redactedEvents -notlike '*files01*') 'Redacted scan events must not leak server names.'
            Assert-True ($redactedManifest -like '*AdLookupMode*') 'Redacted manifest should preserve AD lookup mode as a support diagnostic setting.'
            Assert-True ($redactedManifest -like '*Auto*') 'Redacted manifest should preserve the selected AD lookup mode value.'
            Assert-True (Test-Path -LiteralPath $redactedReportPath) 'Support bundle should include a regenerated redacted report when requested.'
            $redactedReport = Get-Content -LiteralPath $redactedReportPath -Raw
            Assert-True ($redactedReport -notlike '*CONTOSO*') 'Redacted report must not contain source domain names.'
            Assert-True ($redactedReport -notlike '*FinanceEditors*') 'Redacted report must not contain source group names.'
            Assert-True ($redactedReport -like '*ID-*') 'Redacted report should preserve relationships with stable tokens.'
            Assert-True (Test-Path -LiteralPath $bundleManifestPath) 'Support bundle should include a machine-readable support bundle manifest.'
            Assert-True (Test-Path -LiteralPath $bundleFilesPath) 'Support bundle should include per-file diagnostics.'
            Assert-True (Test-Path -LiteralPath $redactionAuditPath) 'Support bundle should include a redaction leak audit.'

            $bundleManifest = Import-Csv -LiteralPath $bundleManifestPath
            $bundleFiles = Import-Csv -LiteralPath $bundleFilesPath
            $redactionAudit = Import-Csv -LiteralPath $redactionAuditPath
            Assert-Equal $bundleManifest[0].RedactionMode 'StableToken' 'Support bundle manifest should record the redaction mode.'
            Assert-Equal $bundleManifest[0].ValidationIsValid 'True' 'Support bundle manifest should record validation status.'
            Assert-Equal $bundleManifest[0].ReportIncluded 'True' 'Support bundle manifest should record that the redacted report was included.'
            Assert-Equal $bundleManifest[0].RedactionLeakCount '0' 'Support bundle manifest should record zero redaction leaks.'
            Assert-True ($bundleFiles.FileName -contains 'acl_entries.csv') 'Support bundle file diagnostics should include redacted ACL export.'
            Assert-True ($bundleFiles.FileName -contains 'owner_risk_pivots.csv') 'Support bundle file diagnostics should include owner risk pivots.'
            Assert-True ($bundleFiles.FileName -contains 'scan_events.jsonl') 'Support bundle file diagnostics should include the redacted JSONL event log.'
            Assert-True ($bundleFiles.FileName -contains 'report.html') 'Support bundle file diagnostics should include the redacted report.'
            Assert-True ($bundleFiles.FileName -contains 'support_bundle_redaction_audit.csv') 'Support bundle file diagnostics should include redaction audit diagnostics.'
            Assert-True ($redactionAudit.Count -gt 0) 'Redaction audit should include checked sensitive source values.'
            Assert-True (@($redactionAudit | Where-Object { $_.LeakDetected -eq 'True' }).Count -eq 0) 'Redaction audit should not detect leaked source values.'
            Assert-True (($redactionAudit | Get-Member -MemberType NoteProperty).Name -contains 'ValueToken') 'Redaction audit should use synthetic tokens instead of raw source values.'
            $auditContent = Get-Content -LiteralPath $redactionAuditPath -Raw
            Assert-True ($auditContent -notlike '*CONTOSO*') 'Redaction audit must not contain source domain names.'
            Assert-True ($auditContent -notlike '*FinanceEditors*') 'Redaction audit must not contain source group names.'
            $aclFile = @($bundleFiles | Where-Object { $_.FileName -eq 'acl_entries.csv' })[0]
            Assert-True ([int]$aclFile.RowCount -gt 0) 'Support bundle file diagnostics should record row counts.'
            Assert-True ($aclFile.Sha256 -match '^[0-9A-Fa-f]{64}$') 'Support bundle file diagnostics should record a SHA256 hash for redacted files.'

            $aclToken = ([regex]::Match($redactedAcl, 'ID-[0-9A-F]{12}')).Value
            Assert-True ($aclToken -ne '') 'ACL export should contain at least one stable token.'
            Assert-True ($redactedConflicts -like "*$aclToken*") 'The same identity token should be reused across ACL and conflict exports.'
        }
    },
    @{
        Name = 'Test-ShareSurferV1Acceptance validates a complete run package'
        Body = {
            Import-Module $moduleManifest -Force
            $acceptanceScript = Join-Path $repoRoot 'scripts/Test-ShareSurferV1Acceptance.ps1'
            $runRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferAcceptance-' + [guid]::NewGuid().ToString('N'))
            $exportPath = Join-Path $runRoot 'export'
            $reportPath = Join-Path $runRoot 'report.html'
            $bundlePath = Join-Path $runRoot 'support-bundle-redacted'
            New-Item -ItemType Directory -Path $runRoot -Force | Out-Null

            Invoke-ShareSurferScan -InputObject (New-TestInventory) -OutputPath $exportPath -SkipIdentityEnrichment | Out-Null
            ConvertTo-ShareSurferReport -ExportPath $exportPath -OutputPath $reportPath | Out-Null
            New-ShareSurferSupportBundle -ExportPath $exportPath -OutputPath $bundlePath -RedactionMode StableToken -RedactionSalt 'acceptance-test' -IncludeReport | Out-Null
            @(
                [pscustomobject]@{ Name = 'EnterpriseUserPopulation'; Required = $true; MinimumValue = 1; ActualValue = 1; Unit = 'users'; Passed = $true; EvidenceSource = 'ActiveDirectory'; EvidenceDetail = 'Synthetic acceptance proof'; Description = 'Users' },
                [pscustomobject]@{ Name = 'EnterpriseSharePopulation'; Required = $true; MinimumValue = 1; ActualValue = 1; Unit = 'shares'; Passed = $true; EvidenceSource = 'ScanExport:shares.csv'; EvidenceDetail = 'Synthetic acceptance proof'; Description = 'Shares' }
            ) | Export-Csv -LiteralPath (Join-Path $runRoot 'lab-validation-criteria.csv') -NoTypeInformation -Encoding UTF8
            [pscustomobject]@{
                IsValid = $true
                FallbackCount = 0
                FallbackCriteria = @()
                FallbackEvidenceSources = @()
            } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $runRoot 'live-evidence.json') -Encoding UTF8
            @(
                [pscustomobject]@{ Name = 'EnterpriseUserPopulation'; Required = $true; Passed = $true; EvidenceStatus = 'LiveEvidence'; EvidenceSource = 'ActiveDirectory'; ActualValue = '1'; MinimumValue = '1'; EvidenceDetail = 'Synthetic acceptance proof'; NextAction = 'No action needed for this criterion.' },
                [pscustomobject]@{ Name = 'EnterpriseSharePopulation'; Required = $true; Passed = $true; EvidenceStatus = 'LiveEvidence'; EvidenceSource = 'ScanExport:shares.csv'; ActualValue = '1'; MinimumValue = '1'; EvidenceDetail = 'Synthetic acceptance proof'; NextAction = 'No action needed for this criterion.' }
            ) | Export-Csv -LiteralPath (Join-Path $runRoot 'live-evidence-review.csv') -NoTypeInformation -Encoding UTF8

            Assert-True (Test-Path -LiteralPath $acceptanceScript) 'Acceptance checker script should exist.'
            $result = & $acceptanceScript -RunRoot $runRoot -RequireLiveEvidence
            Assert-True $result.IsValid 'Complete synthetic run package should pass acceptance checks.'
            Assert-True ($result.Checks.Name -contains 'NormalizedCsvExport') 'Acceptance checks should include normalized CSV validation.'
            Assert-True ($result.Checks.Name -contains 'OfflineReport') 'Acceptance checks should include offline report output.'
            Assert-True ($result.Checks.Name -contains 'RawEventLog') 'Acceptance checks should include raw JSONL event log output.'
            Assert-True ($result.Checks.Name -contains 'RedactedSupportBundle') 'Acceptance checks should include redacted support bundle output.'
            Assert-True ($result.Checks.Name -contains 'LiveEvidenceGate') 'Acceptance checks should include live evidence gate output.'
            Assert-True ($result.Checks.Name -contains 'LiveEvidenceReview') 'Acceptance checks should include the operator live evidence review CSV.'

            Set-Content -LiteralPath $reportPath -Value '<html><body>not a ShareSurfer dashboard</body></html>' -Encoding UTF8
            $badReportResult = & $acceptanceScript -RunRoot $runRoot -RequireLiveEvidence
            Assert-True (-not $badReportResult.IsValid) 'Acceptance checker should fail when the offline report is present but missing dashboard content.'
            Assert-True (@($badReportResult.Checks | Where-Object { $_.Name -eq 'OfflineReport' -and -not $_.Passed }).Count -gt 0) 'Acceptance checker should report offline report content failures.'
            ConvertTo-ShareSurferReport -ExportPath $exportPath -OutputPath $reportPath | Out-Null

            $bundleManifestPath = Join-Path $bundlePath 'support_bundle_manifest.csv'
            $goodBundleManifest = @(Import-Csv -LiteralPath $bundleManifestPath)
            $badBundleManifest = @(
                [pscustomobject]@{
                    GeneratedAt = $goodBundleManifest[0].GeneratedAt
                    RedactionMode = $goodBundleManifest[0].RedactionMode
                    RelationshipPreserving = $goodBundleManifest[0].RelationshipPreserving
                    ExportFileCount = $goodBundleManifest[0].ExportFileCount
                    DiagnosticFileCount = $goodBundleManifest[0].DiagnosticFileCount
                    ReportIncluded = $goodBundleManifest[0].ReportIncluded
                    RedactionAuditCount = $goodBundleManifest[0].RedactionAuditCount
                    RedactionLeakCount = '1'
                    ValidationIsValid = 'False'
                    MissingFileCount = '0'
                    SchemaErrorCount = '0'
                }
            )
            $badBundleManifest | Export-Csv -LiteralPath $bundleManifestPath -NoTypeInformation -Encoding UTF8
            $badBundleResult = & $acceptanceScript -RunRoot $runRoot -RequireLiveEvidence
            Assert-True (-not $badBundleResult.IsValid) 'Acceptance checker should fail when the redacted support bundle manifest reports validation failure or redaction leaks.'
            Assert-True (@($badBundleResult.Checks | Where-Object { $_.Name -eq 'RedactedSupportBundle' -and -not $_.Passed }).Count -gt 0) 'Acceptance checker should report redacted support bundle manifest failures.'
            $goodBundleManifest | Export-Csv -LiteralPath $bundleManifestPath -NoTypeInformation -Encoding UTF8

            @(
                [pscustomobject]@{ Name = 'EnterprisePlanOnlyProof'; Required = $true; Passed = $true; EvidenceStatus = 'PlanOnly'; EvidenceSource = 'LabPlan'; ActualValue = '1'; MinimumValue = '1'; EvidenceDetail = 'Planned only'; NextAction = 'Create or scan the lab.' }
            ) | Export-Csv -LiteralPath (Join-Path $runRoot 'live-evidence-review.csv') -NoTypeInformation -Encoding UTF8
            $badReviewResult = & $acceptanceScript -RunRoot $runRoot -RequireLiveEvidence
            Assert-True (-not $badReviewResult.IsValid) 'Acceptance checker should fail when the live evidence review contains required blocking statuses.'
            Assert-True (@($badReviewResult.Checks | Where-Object { $_.Name -eq 'LiveEvidenceReview' -and -not $_.Passed }).Count -gt 0) 'Acceptance checker should report live evidence review failures.'
            @(
                [pscustomobject]@{ Name = 'EnterpriseUserPopulation'; Required = $true; Passed = $true; EvidenceStatus = 'LiveEvidence'; EvidenceSource = 'ActiveDirectory'; ActualValue = '1'; MinimumValue = '1'; EvidenceDetail = 'Synthetic acceptance proof'; NextAction = 'No action needed for this criterion.' },
                [pscustomobject]@{ Name = 'EnterpriseSharePopulation'; Required = $true; Passed = $true; EvidenceStatus = 'LiveEvidence'; EvidenceSource = 'ScanExport:shares.csv'; ActualValue = '1'; MinimumValue = '1'; EvidenceDetail = 'Synthetic acceptance proof'; NextAction = 'No action needed for this criterion.' }
            ) | Export-Csv -LiteralPath (Join-Path $runRoot 'live-evidence-review.csv') -NoTypeInformation -Encoding UTF8

            Remove-Item -LiteralPath (Join-Path $bundlePath 'scan_events.jsonl') -Force
            $failedResult = & $acceptanceScript -RunRoot $runRoot -RequireLiveEvidence
            Assert-True (-not $failedResult.IsValid) 'Acceptance checker should fail when a required support bundle artifact is missing.'
            Assert-True (@($failedResult.Checks | Where-Object { $_.Name -eq 'RedactedSupportBundle' -and -not $_.Passed }).Count -gt 0) 'Acceptance checker should identify missing redacted support bundle evidence.'

            $labValidationScript = Get-Content -LiteralPath (Join-Path $repoRoot 'scripts/Invoke-ShareSurferLabValidation.ps1') -Raw
            Assert-True ($labValidationScript -like '*Test-ShareSurferV1Acceptance.ps1*') 'Lab validation should run the V1 acceptance checker automatically.'
            Assert-True ($labValidationScript -like '*v1-acceptance.json*') 'Lab validation should write an acceptance result artifact.'
            Assert-True ($labValidationScript -like '*AcceptancePath*') 'Lab validation output should include the acceptance artifact path.'
            Assert-True ($labValidationScript -like '*owner-mapping.csv*') 'Lab validation should write a deterministic owner mapping CSV.'
            Assert-True ($labValidationScript -like '*-OwnerMappingPath $ownerMappingPath*') 'Lab validation should pass owner mappings into the scan.'
            Assert-True ($labValidationScript -like '*live-evidence-review.csv*') 'Lab validation should write an operator-friendly live evidence review CSV.'
            Assert-True ($labValidationScript -like '*LiveEvidenceReviewPath*') 'Lab validation output should include the live evidence review artifact path.'
        }
    },
    @{
        Name = 'Documentation includes workflow visuals for operator review'
        Body = {
            $pesterWrapper = Join-Path $repoRoot 'tests/ShareSurfer.Tests.ps1'
            $visualDoc = Join-Path $repoRoot 'docs/workflow-visuals.md'
            $visualRoot = Join-Path $repoRoot 'docs/visuals'
            $firstRunGuide = Join-Path $repoRoot 'docs/first-run-guide.md'
            $managementOverview = Join-Path $repoRoot 'docs/management-overview.md'
            $managementSlide = Join-Path $repoRoot 'docs/management-overview.html'
            $readme = Join-Path $repoRoot 'README.md'
            $expectedVisuals = @(
                'collector-to-report.svg',
                'enterprise-lab-validation.svg',
                'support-bundle-diagnostics.svg'
            )
            $expectedScreenshots = @(
                'report-dashboard-overview.png',
                'report-dashboard-findings.png'
            )

            Assert-True (Test-Path -LiteralPath $visualDoc) 'Workflow visual documentation should exist.'
            $visualDocText = Get-Content -LiteralPath $visualDoc -Raw
            Assert-True ($visualDocText -like '*Workflow Overview*') 'Workflow visual documentation should include the overview section.'
            Assert-True (Test-Path -LiteralPath (Join-Path $visualRoot 'share-surfer-workflow-concept.png')) 'Workflow visuals should include the overview PNG.'
            Assert-True ($visualDocText -like '*visuals/share-surfer-workflow-concept.png*') 'Workflow visual doc should reference the overview PNG.'
            foreach ($visual in $expectedVisuals) {
                $path = Join-Path $visualRoot $visual
                Assert-True (Test-Path -LiteralPath $path) ("Missing workflow visual {0}" -f $visual)
                $svg = Get-Content -LiteralPath $path -Raw
                Assert-True ($svg -like '*<svg*') ("Workflow visual {0} should be an SVG asset." -f $visual)
                Assert-True ($visualDocText -like ("*visuals/{0}*" -f $visual)) ("Workflow visual doc should reference {0}" -f $visual)
            }
            foreach ($screenshot in $expectedScreenshots) {
                $path = Join-Path $visualRoot $screenshot
                Assert-True (Test-Path -LiteralPath $path) ("Missing report screenshot {0}" -f $screenshot)
                Assert-True ((Get-Item -LiteralPath $path).Length -gt 10000) ("Report screenshot {0} should be a real image asset." -f $screenshot)
            }

            Assert-True (Test-Path -LiteralPath $pesterWrapper) 'Tests should include a Pester-compatible entrypoint.'
            $pesterWrapperText = Get-Content -LiteralPath $pesterWrapper -Raw
            Assert-True ($pesterWrapperText -like '*Describe*ShareSurfer*') 'Pester wrapper should expose a ShareSurfer Describe block.'
            Assert-True ($pesterWrapperText -like '*Invoke-ShareSurferTests.ps1*') 'Pester wrapper should run the fast dependency-free test suite.'
            $readmeText = Get-Content -LiteralPath $readme -Raw
            Assert-True ($readmeText -like '*Invoke-ShareSurferPester.ps1*') 'README should document the optional Pester wrapper.'

            Assert-True (Test-Path -LiteralPath $firstRunGuide) 'Documentation should include an amateur-admin-friendly first-run guide.'
            $firstRunText = Get-Content -LiteralPath $firstRunGuide -Raw
            Assert-True ($firstRunText -like '*first-time*') 'First-run guide should explicitly address first-time operators.'
            Assert-True ($firstRunText -like '*Prerequisites*') 'First-run guide should explain prerequisites.'
            Assert-True ($firstRunText -like '*Choose Scan Targets*') 'First-run guide should explain choosing scan targets.'
            Assert-True ($firstRunText -like '*Run the Collector*') 'First-run guide should explain running the collector.'
            Assert-True ($firstRunText -like '*Understand Outputs*') 'First-run guide should explain output interpretation.'
            Assert-True ($firstRunText -like '*Redacted Support Bundle*') 'First-run guide should explain redacted support bundle creation.'
            Assert-True ($firstRunText -like '*visuals/report-dashboard-overview.png*') 'First-run guide should show an example dashboard screenshot.'
            Assert-True ($firstRunText -like '*visuals/report-dashboard-findings.png*') 'First-run guide should show an example findings screenshot.'

            Assert-True (Test-Path -LiteralPath $managementOverview) 'Documentation should include a management overview artifact.'
            Assert-True (Test-Path -LiteralPath $managementSlide) 'Documentation should include an offline management overview slide.'
            $managementText = (Get-Content -LiteralPath $managementOverview -Raw) + (Get-Content -LiteralPath $managementSlide -Raw)
            Assert-True ($managementText -like '*business value*') 'Management overview should explain business value.'
            Assert-True ($managementText -like '*migration-risk*') 'Management overview should explain migration-risk findings.'
            Assert-True ($managementText -like '*owner/business-unit*') 'Management overview should explain owner/business-unit pivots.'
            Assert-True ($managementText -like '*expected outcomes*') 'Management overview should explain expected outcomes.'
            Assert-True ($managementText -like '*visuals/report-dashboard-overview.png*') 'Management overview should include an example dashboard screenshot.'
            Assert-True ($managementText -like '*visuals/report-dashboard-findings.png*') 'Management overview should include an example findings screenshot.'

            $publicText = @(
                Get-Content -LiteralPath (Join-Path $repoRoot 'README.md') -Raw
                Get-Content -LiteralPath $visualDoc -Raw
                Get-Content -LiteralPath $firstRunGuide -Raw
                Get-Content -LiteralPath $managementOverview -Raw
                Get-Content -LiteralPath $managementSlide -Raw
                Get-Content -LiteralPath (Join-Path $repoRoot 'docs/operator-workflow.md') -Raw
                Get-Content -LiteralPath (Join-Path $visualRoot 'enterprise-lab-validation.svg') -Raw
            ) -join "`n"
            Assert-True ($publicText -like '*Test-ShareSurferV1Acceptance.ps1*') 'Operator documentation should include the final V1 acceptance checker.'
            $oldLabToolPattern = 'pr' + 'lctl'
            $internalVisualPattern = '(?i)' + 'image' + '-gen2'
            Assert-True ($publicText -notmatch $oldLabToolPattern) 'Public docs should not mention old internal test-environment tooling.'
            Assert-True ($publicText -notmatch $internalVisualPattern) 'Public docs should not expose internal visual provenance labels.'
        }
    }
)

$passed = 0
foreach ($test in $tests) {
    try {
        & $test.Body
        $passed++
        Write-Host ("PASS {0}" -f $test.Name)
    }
    catch {
        Write-Error ("FAIL {0}: {1}" -f $test.Name, $_.Exception.Message)
        exit 1
    }
}

Write-Host ("{0}/{1} tests passed" -f $passed, $tests.Count)
