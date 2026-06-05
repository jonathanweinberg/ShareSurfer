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
            Assert-True ($plan.Groups[0].PSObject.Properties.Name -contains 'extensionAttribute11') 'Lab group records should include the runtime-selected OBS attribute.'
            Assert-True ([string]$plan.Groups[0].extensionAttribute11 -ne '') 'Lab group OBS values should be populated for security group review.'
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
            $twoGb = [int64]2147483648

            $plan = New-ShareSurferLabFixture -OutputPlanOnly -RootPath $labRoot -DomainNetBiosName 'CONTOSO' -ObsAttribute 'extensionAttribute10' -Scale Enterprise -EnterpriseUserCount 2500 -EnterpriseShareCount 250

            Assert-Equal $plan.ScaleProfile 'Enterprise' 'Enterprise lab plan should record its scale profile.'
            Assert-Equal ([int64]$plan.MaxLabBytes) $twoGb 'Enterprise lab plan should default to the 2 GiB generated file-data budget.'
            Assert-Equal ([int64]$plan.AbsoluteMaxLabBytes) ([int64]8589934592) 'Enterprise lab plan should record the explicit 8 GiB stress-run ceiling.'
            Assert-Equal ([int]$plan.EnterpriseTargetDepth) 5 'Enterprise lab plan should default to five business hierarchy folders.'
            Assert-Equal ([int64]$plan.EnterpriseFileSizeBytes) ([int64]512) 'Enterprise lab plan should default to 512-byte file fixtures.'
            Assert-Equal ([int]$plan.LongPathShareCount) 1 'Enterprise lab plan should default to one long-path policy fixture share.'
            Assert-True ($plan.Users.Count -ge 2500) 'Enterprise lab plan should include a multi-thousand user population.'
            Assert-Equal $plan.Shares.Count 250 'Enterprise lab plan should include the default 250 SMB shares.'
            Assert-Equal $plan.Groups.Count 500 'Enterprise lab plan should include two generated groups per enterprise share plus seed groups.'
            Assert-True ($plan.Groups.Name -contains 'SS-Eng-Readers') 'Enterprise lab plan should use an AD-safe Engineering reader group name.'
            Assert-True (-not ($plan.Groups.Name -contains 'SS-Engineering-Readers')) 'Enterprise lab plan should not use seed group names that exceed AD sAMAccountName length.'
            Assert-Equal (@($plan.Groups | Where-Object { [string]$_.Name -ne '' -and ([string]$_.Name).Length -gt 20 }).Count) 0 'Enterprise lab group names should fit the AD sAMAccountName length limit.'
            Assert-Equal $plan.AclScenarios.Count 256 'Enterprise lab plan should include seed ACL scenarios, generated explicit ACEs, and one long-path scenario.'
            Assert-Equal $plan.FileFixtures.Count 2000 'Enterprise lab plan should include eight real file objects per share.'
            Assert-Equal ([int64]$plan.EstimatedLabBytes) ([int64]1024000) 'Enterprise lab plan should estimate file data from fixture count and file size.'
            Assert-True ([int64]$plan.EstimatedLabBytes -le $twoGb) 'Enterprise lab plan should stay under the default 2 GiB lab-data budget.'
            Assert-True (@($plan.FileFixtures | Where-Object { ([string]$_.RelativePath -split '\\').Count -ge 6 }).Count -gt 0) 'Enterprise lab plan should include deep folder/file paths.'
            Assert-True (@($plan.AclScenarios | Where-Object { ([string]$_.RelativePath).Length -gt 256 }).Count -gt 0) 'Enterprise lab plan should include operational long-path fixtures.'
            Assert-True ($plan.ValidationCriteria.Name -contains 'EnterpriseUserPopulation') 'Enterprise lab plan should include a user-population validation criterion.'
            Assert-True ($plan.ValidationCriteria.Name -contains 'EnterpriseSharePopulation') 'Enterprise lab plan should include a share-population validation criterion.'
            Assert-True ($plan.ValidationCriteria.Name -contains 'EnterpriseRealFiles') 'Enterprise lab plan should include a real-file validation criterion.'
            Assert-True ($plan.ValidationCriteria.Name -contains 'EnterpriseDiskBudget') 'Enterprise lab plan should include a disk-budget validation criterion.'
            Assert-True ($plan.ValidationCriteria.Name -contains 'EnterpriseOwnerRiskPivots') 'Enterprise lab plan should include owner risk pivot validation.'
            Assert-True ($plan.ValidationCriteria.Name -contains 'EnterpriseRelatedDataAreas') 'Enterprise lab plan should include related data area validation.'
            Assert-True ($plan.ValidationCriteria.Name -contains 'EnterpriseOwnerReviewPackets') 'Enterprise lab plan should include owner review packet validation.'
            Assert-True ($plan.ValidationCriteria.Name -contains 'EnterprisePermissionGroupObsCoverage') 'Enterprise lab plan should include permission-group OBS coverage validation.'
            Assert-True (@($plan.Groups | Where-Object { $_.PSObject.Properties.Name -contains 'extensionAttribute10' -and [string]$_.extensionAttribute10 -ne '' }).Count -eq $plan.Groups.Count) 'Enterprise lab groups should all include OBS values for group review.'
            foreach ($criterion in @($plan.ValidationCriteria | Where-Object { [string]$_.Name -like 'Enterprise*' -and [bool]$_.Required })) {
                Assert-True ([int64]$criterion.ActualPlanValue -ge [int64]$criterion.MinimumValue) ('Enterprise plan criterion should be satisfiable before live evidence replaces plan evidence: {0}' -f $criterion.Name)
            }
            Assert-True ($plan.OwnerMappings.Count -ge $plan.Shares.Count) 'Enterprise lab plan should include owner mappings for generated shares.'
            Assert-True (-not (Test-Path -LiteralPath $labRoot)) 'OutputPlanOnly enterprise planning must not create the lab root.'

            $windowsRootErrors = @()
            $windowsRootPlan = New-ShareSurferLabFixture -OutputPlanOnly -RootPath 'C:\ShareSurferEnterpriseLab' -Scale Enterprise -UserCount 1000 -ShareCount 100 -FilesPerShare 2 -MaxDepth 6 -FileSizeBytes 1024 -DiskBudgetGB 2 -ErrorVariable windowsRootErrors
            Assert-Equal $windowsRootErrors.Count 0 'OutputPlanOnly should not emit local drive errors when planning Windows target paths from a non-Windows workstation.'
            Assert-True ([string]$windowsRootPlan.Shares[0].LocalPath -like 'C:\ShareSurferEnterpriseLab\*') 'Windows target root paths should be preserved in plan-only output.'
            Assert-Equal ([int]$windowsRootPlan.EnterpriseTargetDepth) 6 'Enterprise depth alias should feed the plan.'
            Assert-Equal ([int64]$windowsRootPlan.EnterpriseFileSizeBytes) ([int64]1024) 'Enterprise file-size alias should feed the plan.'
            Assert-Equal ([int64]$windowsRootPlan.MaxLabBytes) ([int64]2147483648) 'DiskBudgetGB alias should set MaxLabBytes.'

            $initializerScript = Get-Content -LiteralPath (Join-Path $repoRoot 'src/ShareSurfer/Private/Initialize-ShareSurferLabDirectoryObjects.ps1') -Raw
            Assert-True ($initializerScript -like '*Set-ADGroup*') 'Lab directory initializer should update existing security group attributes.'
            Assert-True ($initializerScript -like '*-OtherAttributes $groupAttributes*') 'Lab directory initializer should create security groups with OBS extension attributes.'
            Assert-True ($initializerScript -like '*$Plan.ObsAttribute*') 'Lab directory initializer should use the runtime-selected OBS attribute for groups.'
            Assert-True ($initializerScript -like '*Get-ADOrganizationalUnit -Identity $ouDn*') 'Lab directory initializer should resolve the dedicated OU by identity.'
            Assert-True ($initializerScript -like '*Get-ADUser -Filter $filter -SearchBase $SearchBase*') 'Lab directory initializer should search users inside the lab OU.'
            Assert-True ($initializerScript -like '*Get-ADGroup -Filter $filter -SearchBase $SearchBase*') 'Lab directory initializer should search groups inside the lab OU.'
            Assert-True ($initializerScript -like '*already exists outside the ShareSurferLab OU*') 'Lab directory initializer should fail clearly on same-name objects outside the lab OU.'
            Assert-True ($initializerScript -like '*Set-ADUser -Identity $managedUser.DistinguishedName -Manager $manager.DistinguishedName*') 'Lab directory initializer should set managers using lab OU distinguished names.'
            Assert-True ($initializerScript -like '*Add-ADGroupMember -Identity $labGroup.DistinguishedName -Members $memberObject.DistinguishedName*') 'Lab directory initializer should add group members using lab OU distinguished names.'

            $fixtureScript = Get-Content -LiteralPath (Join-Path $repoRoot 'src/ShareSurfer/Public/New-ShareSurferLabFixture.ps1') -Raw
            Assert-True ($fixtureScript -like '*Assert-ShareSurferLabSmbSharePath -ShareName $share.ShareName -ExistingShare $existing -PlannedPath $share.LocalPath*') 'Lab fixture should validate existing SMB share paths before reusing share names.'
            Assert-True ($fixtureScript -like '*already exists at*but the lab plan expects*') 'Lab fixture should fail clearly when a planned SMB share name points at another path.'
            Assert-True ($fixtureScript -like '*ConvertTo-ShareSurferLabComparablePath*') 'Lab fixture should normalize paths before comparing existing and planned SMB share paths.'
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
                [pscustomobject]@{ Identity = 'CONTOSO\Readers'; SamAccountName = 'Readers'; DisplayName = 'Readers'; ObjectClass = 'group'; EmployeeId = ''; EmployeeNumber = ''; Manager = ''; ManagerLevel1 = ''; ManagerLevel2 = ''; ObsPath = 'CORP.TEST.READ'; ObsAttribute = 'extensionAttribute10' },
                [pscustomobject]@{ Identity = 'CONTOSO\Editors'; SamAccountName = 'Editors'; DisplayName = 'Editors'; ObjectClass = 'group'; EmployeeId = ''; EmployeeNumber = ''; Manager = ''; ManagerLevel1 = ''; ManagerLevel2 = ''; ObsPath = 'CORP.TEST.MODIFY'; ObsAttribute = 'extensionAttribute10' },
                [pscustomobject]@{ Identity = 'CONTOSO\FileReaders'; SamAccountName = 'FileReaders'; DisplayName = 'File Readers'; ObjectClass = 'group'; EmployeeId = ''; EmployeeNumber = ''; Manager = ''; ManagerLevel1 = ''; ManagerLevel2 = ''; ObsPath = 'CORP.TEST.FILE'; ObsAttribute = 'extensionAttribute10' }
            ) | Export-Csv -LiteralPath (Join-Path $exportPath 'identities.csv') -NoTypeInformation -Encoding UTF8
            @(
                [pscustomobject]@{ BusinessUnit = 'Finance'; Owner = 'Finance Operations'; Pattern = '\\files01\Share001*'; Source = 'unit-test'; MatchingItems = '2'; Directories = '0'; Files = '2'; FindingCount = '3'; ConflictCount = '1'; PartialShareCount = '0'; DirectIdentityCount = '3'; DirectGroupCount = '3'; ExpandedMemberCount = '1'; RiskLevel = 'High' }
            ) | Export-Csv -LiteralPath (Join-Path $exportPath 'owner_risk_pivots.csv') -NoTypeInformation -Encoding UTF8
            @(
                [pscustomobject]@{ RelatedAreaId = 'related-area-0001'; RelatedDataArea = 'Finance / Finance Operations'; BusinessUnit = 'Finance'; Owner = 'Finance Operations'; Pattern = '\\files01\Share001*'; Source = 'unit-test'; RiskLevel = 'High'; MigrationReadiness = 'Review'; MatchingShares = '1'; MatchingItems = '2'; Directories = '0'; Files = '2'; FindingCount = '3'; ConflictCount = '1'; ReviewItemCount = '4'; PartialShareCount = '0'; DirectIdentityCount = '3'; DirectGroupCount = '3'; ExpandedMemberCount = '1'; RelatedBecause = 'same owner mapping; same business unit; matching path pattern; shared permission group; shared review risk'; SuggestedNextAction = 'Confirm ownership, review access groups, and clean up findings or conflicts before migration.' }
            ) | Export-Csv -LiteralPath (Join-Path $exportPath 'related_data_areas.csv') -NoTypeInformation -Encoding UTF8
            @(
                [pscustomobject]@{ ReviewPacketId = 'owner-review-0001'; BusinessUnit = 'Finance'; Owner = 'Finance Operations'; Pattern = '\\files01\Share001*'; Source = 'unit-test'; RiskLevel = 'High'; ReviewStatus = 'High priority review'; WhyReview = 'high-priority access or migration risk; permission-bearing security groups'; WhatToReviewFirst = 'access conflicts; findings; permissioned groups'; SuggestedNextAction = 'Confirm ownership, review assigned groups, and document the remediation decision.'; MatchingItems = '2'; Directories = '0'; Files = '2'; FindingCount = '3'; ConflictCount = '1'; PartialShareCount = '0'; DirectIdentityCount = '3'; DirectGroupCount = '3'; ExpandedMemberCount = '1'; MigrationReadiness = 'Review'; RelatedDataAreaCount = '1' }
            ) | Export-Csv -LiteralPath (Join-Path $exportPath 'owner_review_packets.csv') -NoTypeInformation -Encoding UTF8

            $plan = [pscustomobject]@{
                MaxLabBytes = [int64]8589934592
                ObsAttribute = 'extensionAttribute10'
                Users = @(
                    [pscustomobject]@{ SamAccountName = 'SSUser00001' },
                    [pscustomobject]@{ SamAccountName = 'SSUser00002' },
                    [pscustomobject]@{ SamAccountName = 'SSUser00003' }
                )
                Groups = @(
                    [pscustomobject]@{ Name = 'Readers'; extensionAttribute10 = 'CORP.TEST.READ' },
                    [pscustomobject]@{ Name = 'Editors'; extensionAttribute10 = 'CORP.TEST.MODIFY' },
                    [pscustomobject]@{ Name = 'FileReaders'; extensionAttribute10 = 'CORP.TEST.FILE' },
                    [pscustomobject]@{ Name = 'UnassignedRecursive'; extensionAttribute10 = 'CORP.TEST.UNASSIGNED' }
                )
                Shares = @(
                    [pscustomobject]@{ ShareName = 'Share001'; LocalPath = (Join-Path $labRoot 'Share001'); SharePermissions = @([pscustomobject]@{ Identity = 'CONTOSO\Readers'; Rights = 'Read' }) },
                    [pscustomobject]@{ ShareName = 'Share002'; LocalPath = (Join-Path $labRoot 'Share002'); SharePermissions = @() }
                )
                FileFixtures = @(
                    [pscustomobject]@{ ShareName = 'Share001'; RelativePath = 'Deep\Path\file01.txt'; SizeBytes = 512 }
                )
                AclScenarios = @(
                    [pscustomobject]@{ Name = 'EnterpriseLongPath'; RelativePath = ('A' * 260); Identity = 'CONTOSO\Editors' },
                    [pscustomobject]@{ Name = 'EnterpriseFileAce'; RelativePath = 'file02.txt'; Identity = 'CONTOSO\FileReaders' }
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
                    [pscustomobject]@{ Name = 'EnterprisePermissionGroupObsCoverage'; Required = $true; MinimumValue = 3; Unit = 'groups with OBS'; Description = 'Permission group OBS coverage' },
                    [pscustomobject]@{ Name = 'EnterpriseOwnerRiskPivots'; Required = $true; MinimumValue = 1; Unit = 'owner risk pivots'; Description = 'Owner risk pivots' },
                    [pscustomobject]@{ Name = 'EnterpriseRelatedDataAreas'; Required = $true; MinimumValue = 1; Unit = 'related data areas'; Description = 'Related data areas' },
                    [pscustomobject]@{ Name = 'EnterpriseOwnerReviewPackets'; Required = $true; MinimumValue = 1; Unit = 'owner review packets'; Description = 'Owner review packets' },
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
            $permissionGroupObsCriterion = @($criteria | Where-Object { $_.Name -eq 'EnterprisePermissionGroupObsCoverage' })[0]
            $ownerRiskCriterion = @($criteria | Where-Object { $_.Name -eq 'EnterpriseOwnerRiskPivots' })[0]
            $relatedDataAreaCriterion = @($criteria | Where-Object { $_.Name -eq 'EnterpriseRelatedDataAreas' })[0]
            $ownerReviewPacketCriterion = @($criteria | Where-Object { $_.Name -eq 'EnterpriseOwnerReviewPackets' })[0]
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
            Assert-Equal ([int]$permissionGroupObsCriterion.ActualValue) 3 'Permission group OBS validation should count enriched permission-bearing groups.'
            Assert-Equal $permissionGroupObsCriterion.EvidenceSource 'ScanExport:identities.csv' 'Permission group OBS validation should identify identity export evidence.'
            Assert-True ([string]$permissionGroupObsCriterion.EvidenceDetail -like '*ObsAttribute=extensionAttribute10*') 'Permission group OBS evidence should record the runtime OBS attribute.'
            Assert-Equal ([int]$ownerRiskCriterion.ActualValue) 1 'Owner risk pivot validation should use owner risk pivot rows.'
            Assert-Equal $ownerRiskCriterion.EvidenceSource 'ScanExport:owner_risk_pivots.csv' 'Owner risk pivot validation should identify owner risk pivot export evidence.'
            Assert-Equal ([int]$relatedDataAreaCriterion.ActualValue) 1 'Related data area validation should use related data area rows.'
            Assert-Equal $relatedDataAreaCriterion.EvidenceSource 'ScanExport:related_data_areas.csv' 'Related data area validation should identify migration discovery export evidence.'
            Assert-Equal ([int]$ownerReviewPacketCriterion.ActualValue) 1 'Owner review packet validation should use owner review packet rows.'
            Assert-Equal $ownerReviewPacketCriterion.EvidenceSource 'ScanExport:owner_review_packets.csv' 'Owner review packet validation should identify owner review packet export evidence.'
            Assert-True ([string]$ownerReviewPacketCriterion.EvidenceDetail -like '*OwnerReviewPacketRows=1*') 'Owner review packet evidence should record packet row counts.'
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

            $preflightRows = @(New-ShareSurferLabValidationPreflight -Plan $plan -LabRoot $labRoot -RunRoot $exportPath -IncludeFiles -RequireLiveEvidence)
            Assert-True ($preflightRows.Name -contains 'WindowsCollectorHost') 'Preflight should report whether the collector is a Windows host.'
            Assert-True ($preflightRows.Name -contains 'ActiveDirectoryModule') 'Preflight should report Active Directory module readiness.'
            Assert-True ($preflightRows.Name -contains 'SmbShareCommands') 'Preflight should report SMBShare command readiness.'
            Assert-True ($preflightRows.Name -contains 'PlanDiskBudget') 'Preflight should report plan disk budget readiness.'
            Assert-True ($preflightRows.Name -contains 'WindowsPathComponents') 'Preflight should report Windows path component safety.'
            Assert-True ($preflightRows.Name -contains 'EnterpriseIncludeFiles') 'Preflight should report enterprise IncludeFiles readiness.'
            Assert-True ($preflightRows.Name -contains 'AdObjectNameCollisions') 'Preflight should report AD object name collision readiness.'
            Assert-True ($preflightRows.Name -contains 'SmbSharePathCollisions') 'Preflight should report SMB share path collision readiness.'
            $includeFilesPreflight = @($preflightRows | Where-Object { $_.Name -eq 'EnterpriseIncludeFiles' })[0]
            Assert-True ([bool]$includeFilesPreflight.Passed) 'Enterprise IncludeFiles preflight should pass when IncludeFiles is set.'

            try {
                function global:Get-SmbShare {
                    param(
                        [string] $Name
                    )

                    if ($Name -eq 'Share001') {
                        return [pscustomobject]@{ Name = 'Share001'; Path = (Join-Path $labRoot 'Share001') }
                    }
                    if ($Name -eq 'Share002') {
                        return [pscustomobject]@{ Name = 'Share002'; Path = (Join-Path $labRoot 'WrongShare002') }
                    }
                    $null
                }

                $smbPathResult = Test-ShareSurferLabValidationSmbSharePaths -Plan $plan
                Assert-True (-not $smbPathResult.Passed) 'SMB share path preflight should fail when an existing share name points at another path.'
                Assert-Equal ([int]$smbPathResult.CheckedShareCount) 2 'SMB share path preflight should count existing shares it checked.'
                Assert-Equal ([int]$smbPathResult.CollisionCount) 1 'SMB share path preflight should count mismatched share paths.'
                Assert-True ([string]$smbPathResult.Evidence -like '*Share002*WrongShare002*') 'SMB share path preflight evidence should identify the colliding share.'

                $smbCollisionPreflight = @(New-ShareSurferLabValidationPreflight -Plan $plan -LabRoot $labRoot -RunRoot $exportPath -CreateLab -IncludeFiles | Where-Object { $_.Name -eq 'SmbSharePathCollisions' })[0]
                Assert-True (-not [bool]$smbCollisionPreflight.Passed) 'CreateLab preflight should fail on SMB share path collisions.'
                Assert-True ([bool]$smbCollisionPreflight.Required) 'CreateLab preflight should make SMB share path collisions required evidence.'
                Assert-True ([string]$smbCollisionPreflight.NextAction -like '*Rename or remove*') 'SMB share collision preflight should give a clear operator next action.'
            }
            finally {
                Remove-Item -Path function:\Get-SmbShare -ErrorAction SilentlyContinue
            }

            try {
                function global:Get-ADDomain {
                    [pscustomobject]@{ DistinguishedName = 'DC=example,DC=test' }
                }
                function global:Get-ADUser {
                    param(
                        [string] $Filter
                    )

                    if ($Filter -like '*SSUser00001*') {
                        return [pscustomobject]@{ SamAccountName = 'SSUser00001'; DistinguishedName = 'CN=SSUser00001,OU=ShareSurferLab,DC=example,DC=test' }
                    }
                    if ($Filter -like '*SSUser00002*') {
                        return [pscustomobject]@{ SamAccountName = 'SSUser00002'; DistinguishedName = 'CN=SSUser00002,OU=ExistingUsers,DC=example,DC=test' }
                    }
                    $null
                }
                function global:Get-ADGroup {
                    param(
                        [string] $Filter
                    )

                    if ($Filter -like "*'Readers'*") {
                        return [pscustomobject]@{ SamAccountName = 'Readers'; DistinguishedName = 'CN=Readers,OU=ShareSurferLab,DC=example,DC=test' }
                    }
                    if ($Filter -like "*'Editors'*") {
                        return [pscustomobject]@{ SamAccountName = 'Editors'; DistinguishedName = 'CN=Editors,OU=ExistingGroups,DC=example,DC=test' }
                    }
                    $null
                }

                $adCollisionResult = Test-ShareSurferLabValidationAdObjectCollisions -Plan $plan
                Assert-True (-not $adCollisionResult.Passed) 'AD object preflight should fail when planned lab names exist outside the lab OU.'
                Assert-Equal ([int]$adCollisionResult.CheckedObjectCount) 4 'AD object preflight should count existing planned users and groups it checked.'
                Assert-Equal ([int]$adCollisionResult.CollisionCount) 2 'AD object preflight should count planned names that collide outside the lab OU.'
                Assert-True ([string]$adCollisionResult.Evidence -like '*SSUser00002*ExistingUsers*') 'AD object preflight evidence should identify the colliding user.'
                Assert-True ([string]$adCollisionResult.Evidence -like '*Editors*ExistingGroups*') 'AD object preflight evidence should identify the colliding group.'

                $adCollisionPreflight = @(New-ShareSurferLabValidationPreflight -Plan $plan -LabRoot $labRoot -RunRoot $exportPath -CreateLab -IncludeFiles | Where-Object { $_.Name -eq 'AdObjectNameCollisions' })[0]
                Assert-True (-not [bool]$adCollisionPreflight.Passed) 'CreateLab preflight should fail on AD object name collisions.'
                Assert-True ([bool]$adCollisionPreflight.Required) 'CreateLab preflight should make AD object name collisions required evidence.'
                Assert-True ([string]$adCollisionPreflight.NextAction -like '*Rename or remove*') 'AD object collision preflight should give a clear operator next action.'
            }
            finally {
                Remove-Item -Path function:\Get-ADDomain -ErrorAction SilentlyContinue
                Remove-Item -Path function:\Get-ADUser -ErrorAction SilentlyContinue
                Remove-Item -Path function:\Get-ADGroup -ErrorAction SilentlyContinue
            }
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
                'related_data_areas.csv',
                'owner_review_packets.csv',
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
            Assert-True ($ownerRiskPivots[0].PSObject.Properties.Name -contains 'DirectIdentityCount') 'Owner risk pivot CSV should include direct identity counts.'
            Assert-True ($ownerRiskPivots[0].PSObject.Properties.Name -contains 'DirectGroupCount') 'Owner risk pivot CSV should include direct group counts.'
            Assert-True ($ownerRiskPivots[0].PSObject.Properties.Name -contains 'ExpandedMemberCount') 'Owner risk pivot CSV should include expanded member counts.'
            Assert-True ([int]$ownerRiskPivots[0].DirectIdentityCount -ge 2) 'Owner risk pivot should count direct share and NTFS identities for access review sizing.'
            Assert-True ([int]$ownerRiskPivots[0].DirectGroupCount -ge 2) 'Owner risk pivot should count direct groups for access review sizing.'
            Assert-True ([int]$ownerRiskPivots[0].ExpandedMemberCount -ge 1) 'Owner risk pivot should count expanded group members for access review sizing.'
            Assert-True ($ownerRiskPivots[0].PSObject.Properties.Name -contains 'RiskLevel') 'Owner risk pivot CSV should include review risk levels.'

            $relatedDataAreas = Import-Csv -LiteralPath (Join-Path $outputPath 'related_data_areas.csv')
            Assert-True ($relatedDataAreas.BusinessUnit -contains 'Finance') 'Related data areas should expose migration discovery rows as CSV.'
            Assert-True ($relatedDataAreas[0].PSObject.Properties.Name -contains 'MigrationReadiness') 'Related data area CSV should include migration readiness.'
            Assert-True ($relatedDataAreas[0].PSObject.Properties.Name -contains 'RelatedBecause') 'Related data area CSV should include explainable grouping reasons.'
            Assert-True ($relatedDataAreas[0].PSObject.Properties.Name -contains 'SuggestedNextAction') 'Related data area CSV should include suggested next actions.'
            Assert-True ([int]$relatedDataAreas[0].ReviewItemCount -ge 1) 'Related data areas should count findings and conflicts that need migration review.'
            Assert-True ([int]$relatedDataAreas[0].DirectGroupCount -ge 1) 'Related data areas should count permissioned groups.'

            $ownerReviewPackets = Import-Csv -LiteralPath (Join-Path $outputPath 'owner_review_packets.csv')
            Assert-True ($ownerReviewPackets.BusinessUnit -contains 'Finance') 'Owner review packets should expose business-unit review packets as CSV.'
            Assert-True ($ownerReviewPackets[0].PSObject.Properties.Name -contains 'WhyReview') 'Owner review packets should include plain why-review guidance.'
            Assert-True ($ownerReviewPackets[0].PSObject.Properties.Name -contains 'WhatToReviewFirst') 'Owner review packets should include where-to-start guidance.'
            Assert-True ($ownerReviewPackets[0].PSObject.Properties.Name -contains 'SuggestedNextAction') 'Owner review packets should include suggested next actions.'
            Assert-True ($ownerReviewPackets[0].WhyReview -like '*permission*' -or $ownerReviewPackets[0].WhyReview -like '*finding*' -or $ownerReviewPackets[0].WhyReview -like '*risk*') 'Owner review packet guidance should explain why review is needed.'
            Assert-True ([int]$ownerReviewPackets[0].DirectGroupCount -ge 1) 'Owner review packets should carry access-review group sizing.'

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
        Name = 'Invoke-ShareSurferScan continues when one TargetPath cannot be resolved'
        Body = {
            Import-Module $moduleManifest -Force
            $scanRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferTargetPath-' + [guid]::NewGuid().ToString('N'))
            $validTarget = Join-Path $scanRoot 'ValidShare'
            $missingTarget = Join-Path $scanRoot 'MissingShare'
            $outputPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferExport-' + [guid]::NewGuid().ToString('N'))
            New-Item -ItemType Directory -Path $validTarget -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $validTarget 'readme.txt') -Value 'valid target evidence' -Encoding UTF8

            Invoke-ShareSurferScan -TargetPath @($validTarget, $missingTarget) -OutputPath $outputPath -IncludeFiles -SkipIdentityEnrichment | Out-Null

            $shares = @(Import-Csv -LiteralPath (Join-Path $outputPath 'shares.csv'))
            $items = @(Import-Csv -LiteralPath (Join-Path $outputPath 'items.csv'))
            $findings = @(Import-Csv -LiteralPath (Join-Path $outputPath 'findings.csv'))
            $events = @(Import-Csv -LiteralPath (Join-Path $outputPath 'scan_events.csv'))

            Assert-Equal $shares.Count 2 'Mixed TargetPath scan should export both valid and failed target rows.'
            Assert-True (@($shares | Where-Object { $_.LocalPath -eq $validTarget }).Count -eq 1) 'Valid TargetPath should still be scanned and exported.'
            $failedShare = @($shares | Where-Object { $_.LocalPath -eq $missingTarget })[0]
            Assert-Equal $failedShare.PartialData 'True' 'Failed TargetPath row should be marked partial.'
            Assert-True ($failedShare.PartialReason -like '*Target path could not be resolved*') 'Failed TargetPath row should explain resolution failure.'
            Assert-True ($failedShare.PartialReason -like '*TargetPathResolveError=1*') 'Failed TargetPath row should summarize the resolution error count.'
            Assert-True (@($items | Where-Object { $_.FullPath -like "$validTarget*" }).Count -gt 0) 'Valid TargetPath should still export item evidence.'
            Assert-True (@($findings | Where-Object { $_.FindingType -eq 'CollectionError' -and $_.ObservedValue -eq 'TargetPathResolveError' }).Count -gt 0) 'Findings should include the failed TargetPath collection error.'
            Assert-True (@($events | Where-Object { $_.EventType -eq 'TargetPathResolveError' }).Count -gt 0) 'Scan events should record the failed TargetPath resolution.'
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
            [void]$inventory.PSObject.Properties.Remove('OwnerMappings')

            Invoke-ShareSurferScan -InputObject $inventory -OutputPath $outputPath -OwnerMappingPath $mappingPath -SkipIdentityEnrichment | Out-Null
            $ownerMappings = Import-Csv -LiteralPath (Join-Path $outputPath 'owner_mappings.csv')

            Assert-Equal $ownerMappings[0].Pattern '\\files01\Finance*' 'Owner mapping pattern should be imported from CSV.'
            Assert-Equal $ownerMappings[0].BusinessUnit 'Finance' 'Owner mapping business unit should be imported from CSV.'
            Assert-Equal $ownerMappings[0].Source 'unit-test-csv' 'Owner mapping source should be imported from CSV.'
            Assert-Equal $ownerMappings.Count 1 'Owner mapping import should work when a custom inventory object does not already expose OwnerMappings.'
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
            Assert-True ($report -like '*data-view="migration"*') 'Report should include a migration discovery dashboard view.'
            Assert-True ($report -like '*data-view="access"*') 'Report should include an access model dashboard view.'
            Assert-True ($report -like '*renderPriorityActions*') 'Report should dynamically build priority actions from exported data.'
            Assert-True ($report -like '*showView*') 'Report should dynamically switch dashboard views.'
            Assert-True ($report -like '*risk-badge*') 'Report should include visual risk badges for business users.'
            Assert-True ($report -like '*Visual Risk Rollups*') 'Report should include visual risk rollups for business reviewers.'
            Assert-True ($report -like '*data-chart="finding"*') 'Report should expose a finding chart container.'
            Assert-True ($report -like '*data-chart="conflict"*') 'Report should expose a conflict chart container.'
            Assert-True ($report -like '*data-chart="owner"*') 'Report should expose an owner/business-unit chart container.'
            Assert-True ($report -like '*data-view="diagnostics"*') 'Report should include a diagnostics dashboard view.'
            Assert-True ($report -like '*data-view="raw"*') 'Report should include a raw evidence dashboard view.'
            Assert-True ($report -like '*Collection Error Drilldown*') 'Report should expose collection errors as a first-class diagnostic table.'
            Assert-True ($report -like '*Collection Errors by Type*') 'Report should chart collection errors by error type.'
            Assert-True ($report -like '*data-chart="collection-error"*') 'Report should expose a collection-error chart container.'
            Assert-True ($report -like '*collection_error_rollups*') 'Report should build collection-error rollups from findings.'
            Assert-True ($report -like '*collection-error-chart*') 'Report should render a collection-error chart.'
            Assert-True ($report -like '*renderBarChart*') 'Report should render offline native bar charts from embedded CSV data.'
            Assert-True ($report -like '*focusDashboardValue*') 'Report should support chart-driven drilldown filtering.'
            Assert-True ($report -like '*getRowSearchText*') 'Report should search readable cell text instead of JSON-escaped rows.'
            Assert-True ($report -like '*Review Workbench*') 'Report should include an owner/business-unit review workbench.'
            Assert-True ($report -like '*What Needs Review First*') 'Report should include an owner review packet queue.'
            Assert-True ($report -like '*owner-review-queue*') 'Report should render owner review packet rows in a first-class table.'
            Assert-True ($report -like '*buildOwnerReviewPackets*') 'Report should build owner review packet rows from normalized exports.'
            Assert-True ($report -like '*focusOwnerReviewPacket*') 'Report should let packet rows focus the review workbench.'
            Assert-True ($report -like '*owner-review-fallback*') 'Report should gracefully fall back to owner risk pivots when packet exports are empty.'
            Assert-True ($report -like '*workbench-stats*') 'Report should include workbench context stats.'
            Assert-True ($report -like '*Direct Identities*') 'Report should summarize direct identity counts in the workbench.'
            Assert-True ($report -like '*Expanded Members*') 'Report should summarize expanded member counts in the workbench.'
            Assert-True ($report -like '*Direct Access Review*') 'Report should include direct identity access-review rows in the workbench.'
            Assert-True ($report -like '*workbench-access*') 'Report should render a workbench access-review table.'
            Assert-True ($report -like '*getWorkbenchAccessRows*') 'Report should dynamically build direct access-review rows from CSV exports.'
            Assert-True ($report -like '*countExpandedMembers*') 'Report should calculate expanded group member counts for access review.'
            Assert-True ($report -like '*Related Groups*') 'Report should expose workbench-related group rows.'
            Assert-True ($report -like '*Permissioned Group Review*') 'Report should include a group-centric review queue for assigned security groups.'
            Assert-True ($report -like '*permissioned-groups*') 'Report should render permissioned group review rows.'
            Assert-True ($report -like '*buildPermissionedGroupRows*') 'Report should dynamically build permissioned group rows from permissions and group edges.'
            Assert-True ($report -like '*focusGroupExpansion*') 'Report should focus the group browser from permissioned group rows.'
            Assert-True ($report -like '*clickable-row*') 'Report should make drilldown rows visibly interactive.'
            Assert-True ($report -like '*Share Gate vs File/Folder Permissions*') 'Report should explain the two-gate access model.'
            Assert-True ($report -like '*access-model*') 'Report should render access model rows.'
            Assert-True ($report -like '*buildAccessModelRows*') 'Report should dynamically build access model rows from share and ACL exports.'
            Assert-True ($report -like '*ShareGate*') 'Access model rows should include share gate summaries.'
            Assert-True ($report -like '*FileFolderPermissions*') 'Access model rows should include file/folder permission summaries.'
            Assert-True ($report -like '*ReviewSignal*') 'Access model rows should include plain review signals.'
            Assert-True ($report -like '*Top Findings and Conflicts*') 'Report should expose a ranked workbench risk list.'
            Assert-True ($report -like '*renderReviewWorkbench*') 'Report should dynamically update the review workbench from dashboard filters.'
            Assert-True ($report -like '*getWorkbenchRiskRows*') 'Report should combine findings and conflicts for workbench review.'
            Assert-True ($report -like '*getWorkbenchGroupRows*') 'Report should infer related groups for the current owner context.'
            Assert-True ($report -like '*Migration Discovery*') 'Report should include a migration discovery lane for related data areas.'
            Assert-True ($report -like '*RelatedDataArea*') 'Migration discovery rows should identify related data areas.'
            Assert-True ($report -like '*related_data_areas*') 'Report should prefer the related data areas CSV when present.'
            Assert-True ($report -like '*Migration Candidate Packet*') 'Report should include a candidate packet for selected related data areas.'
            Assert-True ($report -like '*buildMigrationDiscoveryRows*') 'Report should dynamically derive related data areas from existing CSV exports.'
            Assert-True ($report -like '*RelatedBecause*') 'Migration discovery should explain why rows were grouped.'
            Assert-True ($report -like '*focusMigrationArea*') 'Migration discovery rows should focus owner and business-unit review filters.'
            Assert-True ($report -like '*Raw Evidence Tables*') 'Report should expose a secondary raw evidence table browser.'
            Assert-True ($report -like '*raw-dataset-filter*') 'Raw evidence view should let operators choose a normalized dataset.'
            Assert-True ($report -like '*renderRawEvidence*') 'Raw evidence view should dynamically render embedded CSV-shaped rows.'
            Assert-True ($report -like '*rawDatasetLabels*') 'Raw evidence view should present friendly dataset labels.'
            Assert-True ($report -like '*owner_review_packets.csv*') 'Raw evidence view should expose owner review packets.'
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
                if ($Name -eq 'Finance') {
                    [pscustomobject]@{
                        Name = $Name
                        AccountName = 'CONTOSO\ShareModeReaders'
                        AccessRight = 'Read'
                        AccessControlType = 'Allow'
                    }
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
                Assert-Equal $shares[0].PartialData 'False' 'SMB share scans should not remain partial when share-level permissions were collected for the requested share.'
                Assert-Equal $shares[0].PartialReason '' 'SMB share scans should clear stale local-path permission partial reasons after share-level permissions are proven.'
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
            $runRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferRun-' + [guid]::NewGuid().ToString('N'))
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
            New-Item -ItemType Directory -Path $runRoot -Force | Out-Null
            @(
                [pscustomobject]@{ Name = 'WindowsCollectorHost'; Required = $true; Passed = $true; Status = 'Pass'; Evidence = 'RunRoot=C:\ShareSurfer\lab-validation\CONTOSO; Group=CONTOSO\FinanceEditors'; NextAction = 'No action needed.' },
                [pscustomobject]@{ Name = 'PlanCriteria'; Required = $true; Passed = $true; Status = 'Pass'; Evidence = '\\files01\Finance passed synthetic validation'; NextAction = 'No action needed.' }
            ) | Export-Csv -LiteralPath (Join-Path $runRoot 'lab-preflight.csv') -NoTypeInformation -Encoding UTF8
            @(
                [pscustomobject]@{ Name = 'EnterpriseUserPopulation'; Required = $true; MinimumValue = 1; ActualValue = 1; Unit = 'users'; Passed = $true; EvidenceSource = 'ActiveDirectory'; EvidenceDetail = 'Checked CONTOSO\FinanceEditors in C:\ShareSurferLab'; Description = 'Users' },
                [pscustomobject]@{ Name = 'EnterpriseSharePopulation'; Required = $true; MinimumValue = 1; ActualValue = 1; Unit = 'shares'; Passed = $true; EvidenceSource = 'ScanExport:shares.csv'; EvidenceDetail = 'Scanned \\files01\Finance'; Description = 'Shares' }
            ) | Export-Csv -LiteralPath (Join-Path $runRoot 'lab-validation-criteria.csv') -NoTypeInformation -Encoding UTF8
            @(
                [pscustomobject]@{ Name = 'EnterpriseUserPopulation'; Required = $true; Passed = $true; EvidenceStatus = 'LiveEvidence'; EvidenceSource = 'ActiveDirectory'; ActualValue = '1'; MinimumValue = '1'; EvidenceDetail = 'Manager chain includes CONTOSO\FinanceEditors'; NextAction = 'No action needed for this criterion.' },
                [pscustomobject]@{ Name = 'EnterpriseSharePopulation'; Required = $true; Passed = $true; EvidenceStatus = 'LiveEvidence'; EvidenceSource = 'ScanExport:shares.csv'; ActualValue = '1'; MinimumValue = '1'; EvidenceDetail = '\\files01\Finance evidence'; NextAction = 'No action needed for this criterion.' }
            ) | Export-Csv -LiteralPath (Join-Path $runRoot 'live-evidence-review.csv') -NoTypeInformation -Encoding UTF8
            [pscustomobject]@{
                IsValid = $true
                FallbackCount = 0
                FallbackCriteria = @()
                FallbackEvidenceSources = @()
            } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $runRoot 'live-evidence.json') -Encoding UTF8
            [pscustomobject]@{
                IsValid = $true
                RequireLiveEvidence = $true
                FailedCheckCount = 0
                Checks = @(
                    [pscustomobject]@{ Name = 'LabPreflight'; Passed = $true; Detail = 'Preflight=C:\ShareSurfer\lab-validation\CONTOSO\lab-preflight.csv' },
                    [pscustomobject]@{ Name = 'RedactedSupportBundle'; Passed = $true; Detail = 'Bundle=C:\ShareSurfer\lab-validation\CONTOSO\support-bundle-redacted' }
                )
            } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $runRoot 'v1-acceptance.json') -Encoding UTF8
            @(
                [pscustomobject]@{
                    Timestamp = '2026-06-04T00:00:00.0000000Z'
                    Phase = 'Start'
                    Level = 'Info'
                    Message = 'ShareSurfer lab validation run started.'
                    Detail = 'RunRoot=C:\ShareSurfer\lab-validation\CONTOSO; Computer=files01; Group=CONTOSO\FinanceEditors'
                },
                [pscustomobject]@{
                    Timestamp = '2026-06-04T00:00:01.0000000Z'
                    Phase = 'Preflight'
                    Level = 'Warning'
                    Message = 'Lab validation preflight completed.'
                    Detail = 'PreflightPath=C:\ShareSurfer\lab-validation\CONTOSO\lab-preflight.csv; FailedRequiredCount=1'
                }
            ) | ForEach-Object { $_ | ConvertTo-Json -Compress -Depth 4 } | Set-Content -LiteralPath (Join-Path $runRoot 'lab-run-events.jsonl') -Encoding UTF8

            New-ShareSurferSupportBundle -ExportPath $outputPath -OutputPath $bundlePath -RedactionMode StableToken -RedactionSalt 'unit-test' -IncludeReport -RunRoot $runRoot | Out-Null
            $rawEventLogPath = Join-Path $outputPath 'scan_events.jsonl'
            $redactedEventLogPath = Join-Path $bundlePath 'scan_events.jsonl'
            $redactedLabRunEventLogPath = Join-Path $bundlePath 'lab_run_events.jsonl'
            $rawEventLog = Get-Content -LiteralPath $rawEventLogPath -Raw
            $redactedEventLog = Get-Content -LiteralPath $redactedEventLogPath -Raw
            $rawLabRunEventLog = Get-Content -LiteralPath (Join-Path $runRoot 'lab-run-events.jsonl') -Raw
            $redactedLabRunEventLog = Get-Content -LiteralPath $redactedLabRunEventLogPath -Raw
            $redactedAcl = Get-Content -LiteralPath (Join-Path $bundlePath 'acl_entries.csv') -Raw
            $redactedFindings = Get-Content -LiteralPath (Join-Path $bundlePath 'findings.csv') -Raw
            $redactedConflicts = Get-Content -LiteralPath (Join-Path $bundlePath 'conflicts.csv') -Raw
            $redactedEvents = Get-Content -LiteralPath (Join-Path $bundlePath 'scan_events.csv') -Raw
            $redactedManifest = Get-Content -LiteralPath (Join-Path $bundlePath 'scan_manifest.csv') -Raw
            $redactedReportPath = Join-Path $bundlePath 'report.html'
            $bundleManifestPath = Join-Path $bundlePath 'support_bundle_manifest.csv'
            $bundleFilesPath = Join-Path $bundlePath 'support_bundle_files.csv'
            $bundleSummaryPath = Join-Path $bundlePath 'support_bundle_summary.json'
            $bundleDiagnosticsPath = Join-Path $bundlePath 'support_bundle_diagnostics.json'
            $labRunDiagnosticsPath = Join-Path $bundlePath 'lab_run_diagnostics.json'
            $redactionAuditPath = Join-Path $bundlePath 'support_bundle_redaction_audit.csv'

            Assert-True ($rawEventLog -like '*CONTOSO*') 'Raw JSONL event log should preserve source values for trusted internal debugging.'
            Assert-True ($redactedEventLog -notlike '*CONTOSO*') 'Redacted JSONL event log must not contain source domain names.'
            Assert-True ($redactedEventLog -notlike '*files01*') 'Redacted JSONL event log must not contain source server names.'
            Assert-True ($redactedEventLog -like '*ID-*') 'Redacted JSONL event log should preserve relationships with stable tokens.'
            Assert-True ($rawLabRunEventLog -like '*CONTOSO*') 'Raw lab-run event log should preserve source values for trusted internal debugging.'
            Assert-True ($redactedLabRunEventLog -notlike '*CONTOSO*') 'Redacted lab-run event log must not contain source domain names.'
            Assert-True ($redactedLabRunEventLog -notlike '*files01*') 'Redacted lab-run event log must not contain source server names.'
            Assert-True ($redactedLabRunEventLog -like '*Preflight*') 'Redacted lab-run event log should preserve phase names.'
            Assert-True ($redactedLabRunEventLog -like '*Warning*') 'Redacted lab-run event log should preserve event levels.'
            Assert-True ($redactedLabRunEventLog -like '*ID-*') 'Redacted lab-run event log should preserve sensitive detail relationships with stable tokens.'
            Assert-True ($redactedAcl -notlike '*CONTOSO*') 'Redacted bundle must not contain the source domain name.'
            Assert-True ($redactedAcl -notlike '*FinanceEditors*') 'Redacted bundle must not contain source group names.'
            Assert-True ($redactedAcl -like '*ID-*') 'Stable token redaction should preserve relationships with synthetic IDs.'
            Assert-True ($redactedFindings -notlike '*\\files01\Finance\Delegated*') 'ObservedValue must redact inheritance break paths.'
            Assert-True ($redactedConflicts -like '*ID-*') 'Conflicts should retain stable tokens for cross-file identity correlation.'

            $redactedIdentities = Get-Content -LiteralPath (Join-Path $bundlePath 'identities.csv') -Raw
            $redactedOwners = Get-Content -LiteralPath (Join-Path $bundlePath 'owner_mappings.csv') -Raw
            $redactedOwnerRiskPivots = Get-Content -LiteralPath (Join-Path $bundlePath 'owner_risk_pivots.csv') -Raw
            $redactedRelatedDataAreas = Get-Content -LiteralPath (Join-Path $bundlePath 'related_data_areas.csv') -Raw
            $redactedOwnerReviewPackets = Get-Content -LiteralPath (Join-Path $bundlePath 'owner_review_packets.csv') -Raw
            Assert-True ($redactedIdentities -notlike '*E1001*') 'Employee IDs must be anonymized.'
            Assert-True ($redactedIdentities -notlike '*1001*') 'Employee numbers must be anonymized.'
            Assert-True ($redactedOwners -notlike '*Finance*') 'Business unit names and owner mappings must be anonymized.'
            Assert-True ($redactedOwnerRiskPivots -notlike '*Finance*') 'Owner risk pivot business-unit names must be anonymized.'
            Assert-True ($redactedOwnerRiskPivots -like '*ID-*') 'Owner risk pivots should preserve review relationships with stable tokens.'
            Assert-True ($redactedRelatedDataAreas -notlike '*Finance*') 'Related data areas must anonymize source owner and business-unit labels.'
            Assert-True ($redactedRelatedDataAreas -like '*MigrationReadiness*') 'Related data areas should preserve migration readiness headers.'
            Assert-True ($redactedRelatedDataAreas -like '*same owner mapping*') 'Related data areas should preserve safe relatedness reasons.'
            Assert-True ($redactedOwnerReviewPackets -notlike '*Finance*') 'Owner review packets must anonymize owner and business-unit labels.'
            Assert-True ($redactedOwnerReviewPackets -like '*WhyReview*') 'Owner review packets should preserve guidance headers.'
            Assert-True ($redactedOwnerReviewPackets -like '*SuggestedNextAction*') 'Owner review packets should preserve next-action guidance.'
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
            Assert-True (Test-Path -LiteralPath $bundleSummaryPath) 'Support bundle should include a redacted JSON summary for support triage.'
            Assert-True (Test-Path -LiteralPath $bundleDiagnosticsPath) 'Support bundle should include redacted diagnostics for support triage.'
            Assert-True (Test-Path -LiteralPath $labRunDiagnosticsPath) 'Support bundle should include redacted lab-run diagnostics when a run root is supplied.'
            Assert-True (Test-Path -LiteralPath $redactionAuditPath) 'Support bundle should include a redaction leak audit.'

            $bundleManifest = Import-Csv -LiteralPath $bundleManifestPath
            $bundleFiles = Import-Csv -LiteralPath $bundleFilesPath
            $bundleSummaryText = Get-Content -LiteralPath $bundleSummaryPath -Raw
            $bundleSummary = $bundleSummaryText | ConvertFrom-Json
            $bundleDiagnosticsText = Get-Content -LiteralPath $bundleDiagnosticsPath -Raw
            $bundleDiagnostics = $bundleDiagnosticsText | ConvertFrom-Json
            $labRunDiagnosticsText = Get-Content -LiteralPath $labRunDiagnosticsPath -Raw
            $labRunDiagnostics = $labRunDiagnosticsText | ConvertFrom-Json
            $redactionAudit = Import-Csv -LiteralPath $redactionAuditPath
            Assert-Equal $bundleManifest[0].RedactionMode 'StableToken' 'Support bundle manifest should record the redaction mode.'
            Assert-Equal $bundleManifest[0].ValidationIsValid 'True' 'Support bundle manifest should record validation status.'
            Assert-Equal $bundleManifest[0].ReportIncluded 'True' 'Support bundle manifest should record that the redacted report was included.'
            Assert-Equal $bundleManifest[0].LabRunIncluded 'True' 'Support bundle manifest should record that lab-run evidence was included.'
            Assert-Equal $bundleManifest[0].RedactionLeakCount '0' 'Support bundle manifest should record zero redaction leaks.'
            Assert-Equal $bundleSummary.BundleType 'ShareSurferRedactedSupportBundle' 'Support bundle summary should identify the bundle type.'
            Assert-Equal ([string]$bundleSummary.Validation.IsValid) 'True' 'Support bundle summary should record validation status.'
            Assert-Equal ([string]$bundleSummary.LabRunIncluded) 'True' 'Support bundle summary should record lab-run evidence inclusion.'
            Assert-Equal ([int]$bundleSummary.Redaction.LeakCount) 0 'Support bundle summary should record redaction leak count.'
            Assert-Equal $bundleSummary.Diagnostics.FileName 'support_bundle_diagnostics.json' 'Support bundle summary should reference diagnostics JSON.'
            Assert-Equal $bundleDiagnostics.BundleType 'ShareSurferRedactedSupportBundleDiagnostics' 'Support bundle diagnostics should identify the diagnostics type.'
            Assert-Equal ([string]$bundleDiagnostics.Validation.IsValid) 'True' 'Support bundle diagnostics should record validation status.'
            Assert-Equal ([string]$bundleDiagnostics.LabRunEvidence.Included) 'True' 'Support bundle diagnostics should record lab-run evidence inclusion.'
            Assert-True ([int]$bundleDiagnostics.LabRunEvidence.FileCount -gt 0) 'Support bundle diagnostics should summarize lab-run evidence files.'
            Assert-Equal $labRunDiagnostics.BundleType 'ShareSurferRedactedLabRunDiagnostics' 'Lab-run diagnostics should identify the diagnostics type.'
            Assert-Equal ([int]$labRunDiagnostics.RunEvents.RowCount) 2 'Lab-run diagnostics should summarize redacted lab-run event rows.'
            Assert-Equal ([int]$labRunDiagnostics.RunEvents.WarningCount) 1 'Lab-run diagnostics should summarize warning event rows.'
            Assert-Equal ([int]$labRunDiagnostics.Preflight.RowCount) 2 'Lab-run diagnostics should summarize redacted preflight evidence.'
            Assert-Equal ([int]$labRunDiagnostics.Criteria.RowCount) 2 'Lab-run diagnostics should summarize redacted criteria evidence.'
            Assert-Equal ([string]$labRunDiagnostics.Acceptance.IsValid) 'True' 'Lab-run diagnostics should summarize acceptance when an acceptance artifact exists.'
            Assert-True ([int]$bundleDiagnostics.Inventory.FindingCount -gt 0) 'Support bundle diagnostics should summarize finding counts.'
            Assert-True ([int]$bundleDiagnostics.Inventory.ConflictCount -gt 0) 'Support bundle diagnostics should summarize conflict counts.'
            Assert-True ([int]$bundleDiagnostics.Inventory.ScanEventCount -gt 0) 'Support bundle diagnostics should summarize scan events.'
            Assert-True (@($bundleDiagnostics.Rollups.FindingsByType | Where-Object { $_.Name -eq 'DeepExplicitAce' }).Count -gt 0) 'Support bundle diagnostics should include finding type rollups.'
            Assert-True ($bundleDiagnostics.ScanSettings.PSObject.Properties.Name -contains 'AdLookupMode') 'Support bundle diagnostics should preserve safe scan settings.'
            Assert-True ([int]$bundleDiagnostics.Inventory.RelatedDataAreaCount -gt 0) 'Support bundle diagnostics should summarize related data area counts.'
            Assert-True ([int]$bundleDiagnostics.Inventory.OwnerReviewPacketCount -gt 0) 'Support bundle diagnostics should summarize owner review packet counts.'
            Assert-True (@($bundleSummary.Files | Where-Object { $_.FileName -eq 'acl_entries.csv' }).Count -eq 1) 'Support bundle summary should include redacted file diagnostics.'
            Assert-True ($bundleSummaryText -notlike '*CONTOSO*') 'Support bundle summary must not contain source domain names.'
            Assert-True ($bundleSummaryText -notlike '*FinanceEditors*') 'Support bundle summary must not contain source group names.'
            Assert-True ($bundleSummaryText -notlike '*unit-test*') 'Support bundle summary must not expose the redaction salt.'
            Assert-True ($bundleDiagnosticsText -notlike '*CONTOSO*') 'Support bundle diagnostics must not contain source domain names.'
            Assert-True ($bundleDiagnosticsText -notlike '*FinanceEditors*') 'Support bundle diagnostics must not contain source group names.'
            Assert-True ($bundleDiagnosticsText -notlike '*unit-test*') 'Support bundle diagnostics must not expose the redaction salt.'
            Assert-True ($labRunDiagnosticsText -notlike '*CONTOSO*') 'Lab-run diagnostics must not contain source domain names.'
            Assert-True ($labRunDiagnosticsText -notlike '*FinanceEditors*') 'Lab-run diagnostics must not contain source group names.'
            Assert-True ($labRunDiagnosticsText -notlike '*files01*') 'Lab-run diagnostics must not contain source server names.'
            Assert-True ($labRunDiagnosticsText -notlike '*unit-test*') 'Lab-run diagnostics must not expose the redaction salt.'
            Assert-True ($labRunDiagnosticsText -like '*ID-*') 'Lab-run diagnostics should preserve relationships with stable tokens.'
            Assert-True ($bundleFiles.FileName -contains 'acl_entries.csv') 'Support bundle file diagnostics should include redacted ACL export.'
            Assert-True ($bundleFiles.FileName -contains 'owner_risk_pivots.csv') 'Support bundle file diagnostics should include owner risk pivots.'
            Assert-True ($bundleFiles.FileName -contains 'related_data_areas.csv') 'Support bundle file diagnostics should include related data areas.'
            Assert-True ($bundleFiles.FileName -contains 'owner_review_packets.csv') 'Support bundle file diagnostics should include owner review packets.'
            Assert-True ($bundleFiles.FileName -contains 'scan_events.jsonl') 'Support bundle file diagnostics should include the redacted JSONL event log.'
            Assert-True ($bundleFiles.FileName -contains 'report.html') 'Support bundle file diagnostics should include the redacted report.'
            Assert-True ($bundleFiles.FileName -contains 'support_bundle_summary.json') 'Support bundle file diagnostics should include the redacted JSON summary.'
            Assert-True ($bundleFiles.FileName -contains 'support_bundle_diagnostics.json') 'Support bundle file diagnostics should include the redacted diagnostics JSON.'
            Assert-True ($bundleFiles.FileName -contains 'lab_run_diagnostics.json') 'Support bundle file diagnostics should include redacted lab-run diagnostics.'
            Assert-True ($bundleFiles.FileName -contains 'lab_run_events.jsonl') 'Support bundle file diagnostics should include the redacted lab-run event log.'
            Assert-True ($bundleFiles.FileName -contains 'lab_preflight.csv') 'Support bundle file diagnostics should include redacted lab preflight evidence.'
            Assert-True ($bundleFiles.FileName -contains 'lab_validation_criteria.csv') 'Support bundle file diagnostics should include redacted lab validation criteria.'
            Assert-True ($bundleFiles.FileName -contains 'live_evidence_review.csv') 'Support bundle file diagnostics should include redacted live evidence review.'
            Assert-True ($bundleFiles.FileName -contains 'live_evidence.json') 'Support bundle file diagnostics should include live evidence summary.'
            Assert-True ($bundleFiles.FileName -contains 'v1_acceptance.json') 'Support bundle file diagnostics should include acceptance summary when present.'
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
            @(
                [pscustomobject]@{ Name = 'WindowsCollectorHost'; Required = $true; Passed = $true; Status = 'Pass'; Evidence = 'Synthetic acceptance proof'; NextAction = 'No action needed.' },
                [pscustomobject]@{ Name = 'PlanCriteria'; Required = $true; Passed = $true; Status = 'Pass'; Evidence = 'Synthetic acceptance proof'; NextAction = 'No action needed.' }
            ) | Export-Csv -LiteralPath (Join-Path $runRoot 'lab-preflight.csv') -NoTypeInformation -Encoding UTF8
            @(
                [pscustomobject]@{ Timestamp = '2026-06-04T00:00:00.0000000Z'; Phase = 'Start'; Level = 'Info'; Message = 'ShareSurfer lab validation run started.'; Detail = 'RunRoot=C:\ShareSurfer\acceptance' },
                [pscustomobject]@{ Timestamp = '2026-06-04T00:00:01.0000000Z'; Phase = 'Complete'; Level = 'Info'; Message = 'ShareSurfer lab validation run completed.'; Detail = 'AcceptanceIsValid=True' }
            ) | ForEach-Object { $_ | ConvertTo-Json -Compress -Depth 4 } | Set-Content -LiteralPath (Join-Path $runRoot 'lab-run-events.jsonl') -Encoding UTF8
            New-ShareSurferSupportBundle -ExportPath $exportPath -OutputPath $bundlePath -RedactionMode StableToken -RedactionSalt 'acceptance-test' -IncludeReport -RunRoot $runRoot | Out-Null

            Assert-True (Test-Path -LiteralPath $acceptanceScript) 'Acceptance checker script should exist.'
            $pendingBundleResult = & $acceptanceScript -RunRoot $runRoot -RequireLiveEvidence -AllowMissingBundledAcceptance
            Assert-True $pendingBundleResult.IsValid 'First acceptance pass should allow the bundled acceptance summary to be pending.'
            $pendingBundleResult | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $runRoot 'v1-acceptance.json') -Encoding UTF8
            New-ShareSurferSupportBundle -ExportPath $exportPath -OutputPath $bundlePath -RedactionMode StableToken -RedactionSalt 'acceptance-test' -IncludeReport -RunRoot $runRoot | Out-Null
            $result = & $acceptanceScript -RunRoot $runRoot -RequireLiveEvidence
            Assert-True $result.IsValid 'Complete synthetic run package should pass acceptance checks.'
            Assert-True ($result.Checks.Name -contains 'NormalizedCsvExport') 'Acceptance checks should include normalized CSV validation.'
            Assert-True ($result.Checks.Name -contains 'OwnerReviewPackets') 'Acceptance checks should include owner review packet evidence.'
            Assert-True ($result.Checks.Name -contains 'OfflineReport') 'Acceptance checks should include offline report output.'
            Assert-True ($result.Checks.Name -contains 'RawEventLog') 'Acceptance checks should include raw JSONL event log output.'
            Assert-True ($result.Checks.Name -contains 'RedactedSupportBundle') 'Acceptance checks should include redacted support bundle output.'
            Assert-True ($result.Checks.Name -contains 'LabRunSupportBundleEvidence') 'Acceptance checks should include redacted lab-run support bundle evidence.'
            Assert-True ($result.Checks.Name -contains 'LabPreflight') 'Acceptance checks should include lab preflight readiness evidence.'
            Assert-True ($result.Checks.Name -contains 'LiveEvidenceGate') 'Acceptance checks should include live evidence gate output.'
            Assert-True ($result.Checks.Name -contains 'LiveEvidenceReview') 'Acceptance checks should include the operator live evidence review CSV.'

            Set-Content -LiteralPath $reportPath -Value '<html><body>not a ShareSurfer dashboard</body></html>' -Encoding UTF8
            $badReportResult = & $acceptanceScript -RunRoot $runRoot -RequireLiveEvidence
            Assert-True (-not $badReportResult.IsValid) 'Acceptance checker should fail when the offline report is present but missing dashboard content.'
            Assert-True (@($badReportResult.Checks | Where-Object { $_.Name -eq 'OfflineReport' -and -not $_.Passed }).Count -gt 0) 'Acceptance checker should report offline report content failures.'
            ConvertTo-ShareSurferReport -ExportPath $exportPath -OutputPath $reportPath | Out-Null

            $bundleManifestPath = Join-Path $bundlePath 'support_bundle_manifest.csv'
            $bundleFilesPath = Join-Path $bundlePath 'support_bundle_files.csv'
            $bundleFiles = @(Import-Csv -LiteralPath $bundleFilesPath)
            Assert-True ($bundleFiles.FileName -contains 'v1_acceptance.json') 'Final lab support bundle should include the redacted acceptance summary.'
            Assert-True ($bundleFiles.FileName -contains 'lab_run_events.jsonl') 'Final lab support bundle should include the redacted lab-run event log.'
            $goodBundleManifest = @(Import-Csv -LiteralPath $bundleManifestPath)
            $badBundleManifest = @(
                [pscustomobject]@{
                    GeneratedAt = $goodBundleManifest[0].GeneratedAt
                    RedactionMode = $goodBundleManifest[0].RedactionMode
                    RelationshipPreserving = $goodBundleManifest[0].RelationshipPreserving
                    ExportFileCount = $goodBundleManifest[0].ExportFileCount
                    DiagnosticFileCount = $goodBundleManifest[0].DiagnosticFileCount
                    ReportIncluded = $goodBundleManifest[0].ReportIncluded
                    LabRunIncluded = $goodBundleManifest[0].LabRunIncluded
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

            $ownerReviewPacketPath = Join-Path $exportPath 'owner_review_packets.csv'
            $goodOwnerReviewPackets = Get-Content -LiteralPath $ownerReviewPacketPath -Raw
            Set-Content -LiteralPath $ownerReviewPacketPath -Value 'ReviewPacketId,BusinessUnit,Owner,Pattern,Source,RiskLevel,ReviewStatus,WhyReview,WhatToReviewFirst,SuggestedNextAction,MatchingItems,Directories,Files,FindingCount,ConflictCount,PartialShareCount,DirectIdentityCount,DirectGroupCount,ExpandedMemberCount,MigrationReadiness,RelatedDataAreaCount' -Encoding UTF8
            $badOwnerReviewResult = & $acceptanceScript -RunRoot $runRoot -RequireLiveEvidence
            Assert-True (-not $badOwnerReviewResult.IsValid) 'Acceptance checker should fail when owner review packets are missing rows.'
            Assert-True (@($badOwnerReviewResult.Checks | Where-Object { $_.Name -eq 'OwnerReviewPackets' -and -not $_.Passed }).Count -gt 0) 'Acceptance checker should report owner review packet evidence failures.'
            Set-Content -LiteralPath $ownerReviewPacketPath -Value $goodOwnerReviewPackets -Encoding UTF8

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

            @(
                [pscustomobject]@{ Name = 'WindowsCollectorHost'; Required = $true; Passed = $false; Status = 'Blocker'; Evidence = 'Synthetic blocker'; NextAction = 'Run on Windows.' }
            ) | Export-Csv -LiteralPath (Join-Path $runRoot 'lab-preflight.csv') -NoTypeInformation -Encoding UTF8
            $badPreflightResult = & $acceptanceScript -RunRoot $runRoot -RequireLiveEvidence
            Assert-True (-not $badPreflightResult.IsValid) 'Acceptance checker should fail when required preflight rows failed.'
            Assert-True (@($badPreflightResult.Checks | Where-Object { $_.Name -eq 'LabPreflight' -and -not $_.Passed }).Count -gt 0) 'Acceptance checker should report preflight failures.'
            @(
                [pscustomobject]@{ Name = 'WindowsCollectorHost'; Required = $true; Passed = $true; Status = 'Pass'; Evidence = 'Synthetic acceptance proof'; NextAction = 'No action needed.' },
                [pscustomobject]@{ Name = 'PlanCriteria'; Required = $true; Passed = $true; Status = 'Pass'; Evidence = 'Synthetic acceptance proof'; NextAction = 'No action needed.' }
            ) | Export-Csv -LiteralPath (Join-Path $runRoot 'lab-preflight.csv') -NoTypeInformation -Encoding UTF8

            Remove-Item -LiteralPath (Join-Path $bundlePath 'scan_events.jsonl') -Force
            $failedResult = & $acceptanceScript -RunRoot $runRoot -RequireLiveEvidence
            Assert-True (-not $failedResult.IsValid) 'Acceptance checker should fail when a required support bundle artifact is missing.'
            Assert-True (@($failedResult.Checks | Where-Object { $_.Name -eq 'RedactedSupportBundle' -and -not $_.Passed }).Count -gt 0) 'Acceptance checker should identify missing redacted support bundle evidence.'

            $labValidationScript = Get-Content -LiteralPath (Join-Path $repoRoot 'scripts/Invoke-ShareSurferLabValidation.ps1') -Raw
            Assert-True ($labValidationScript -like '*Test-ShareSurferV1Acceptance.ps1*') 'Lab validation should run the V1 acceptance checker automatically.'
            Assert-True ($labValidationScript -like '*-AllowMissingBundledAcceptance*') 'Lab validation should allow bundled acceptance to be pending only for the first acceptance pass.'
            Assert-True ($labValidationScript -like '*$finishedPackageAcceptance = & $acceptanceScriptPath*') 'Lab validation should verify the finished bundle after strict acceptance is bundled.'
            Assert-True ($labValidationScript -like '*ShareSurfer finished support bundle validation failed*') 'Lab validation should fail clearly if the final refreshed support bundle is invalid.'
            Assert-True ($labValidationScript -like '*PreflightOnly*') 'Lab validation should expose a non-mutating preflight-only mode.'
            Assert-True ($labValidationScript -like '*if ($PreflightOnly)*') 'Lab validation should return after preflight artifacts when preflight-only mode is used.'
            Assert-True ($labValidationScript -like '*PreflightPassed*') 'Lab validation preflight-only output should report preflight status.'
            Assert-True ($labValidationScript -like '*lab-run-events.jsonl*') 'Lab validation should write a raw lab-run event log.'
            Assert-True ($labValidationScript -like '*Add-ShareSurferLabRunEvent*') 'Lab validation should record phase events for run diagnostics.'
            Assert-True ($labValidationScript -like '*LabRunEventPath*') 'Lab validation output should include the lab-run event artifact path.'
            Assert-True ($labValidationScript -like '*lab-preflight.csv*') 'Lab validation should write a preflight readiness CSV.'
            Assert-True ($labValidationScript -like '*PreflightPath*') 'Lab validation output should include the preflight artifact path.'
            Assert-True ($labValidationScript -like '*v1-acceptance.json*') 'Lab validation should write an acceptance result artifact.'
            Assert-True ($labValidationScript -like '*AcceptancePath*') 'Lab validation output should include the acceptance artifact path.'
            Assert-True ($labValidationScript -like '*owner-mapping.csv*') 'Lab validation should write a deterministic owner mapping CSV.'
            Assert-True ($labValidationScript -like '*-OwnerMappingPath $ownerMappingPath*') 'Lab validation should pass owner mappings into the scan.'
            Assert-True ($labValidationScript -like '*live-evidence-review.csv*') 'Lab validation should write an operator-friendly live evidence review CSV.'
            Assert-True ($labValidationScript -like '*LiveEvidenceReviewPath*') 'Lab validation output should include the live evidence review artifact path.'
            Assert-True ($labValidationScript -like '*-RunRoot $runRoot*') 'Lab validation should include redacted lab-run evidence in generated support bundles.'
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
                'report-dashboard-workbench.png',
                'report-dashboard-findings.png',
                'report-dashboard-migration.png'
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
            Assert-True ($firstRunText -like '*visuals/report-dashboard-workbench.png*') 'First-run guide should show an example review workbench screenshot.'
            Assert-True ($firstRunText -like '*visuals/report-dashboard-findings.png*') 'First-run guide should show an example findings screenshot.'
            Assert-True ($firstRunText -like '*visuals/report-dashboard-migration.png*') 'First-run guide should show an example migration discovery screenshot.'
            Assert-True ($firstRunText -like '*Raw Evidence Tables*') 'First-run guide should explain the raw evidence report view.'
            Assert-True ($firstRunText -like '*owner_review_packets.csv*') 'First-run guide should explain owner review packet exports.'
            Assert-True ($firstRunText -like '*What Needs Review First*') 'First-run guide should point users to the owner review queue.'
            Assert-True ($firstRunText -like '*Access Model*') 'First-run guide should point users to the access model view.'

            Assert-True (Test-Path -LiteralPath $managementOverview) 'Documentation should include a management overview artifact.'
            Assert-True (Test-Path -LiteralPath $managementSlide) 'Documentation should include an offline management overview slide.'
            $managementText = (Get-Content -LiteralPath $managementOverview -Raw) + (Get-Content -LiteralPath $managementSlide -Raw)
            Assert-True ($managementText -like '*business value*') 'Management overview should explain business value.'
            Assert-True ($managementText -like '*migration-risk*') 'Management overview should explain migration-risk findings.'
            Assert-True ($managementText -like '*owner/business-unit*') 'Management overview should explain owner/business-unit pivots.'
            Assert-True ($managementText -like '*expected outcomes*') 'Management overview should explain expected outcomes.'
            Assert-True ($managementText -like '*visuals/report-dashboard-overview.png*') 'Management overview should include an example dashboard screenshot.'
            Assert-True ($managementText -like '*visuals/report-dashboard-workbench.png*') 'Management overview should include an example review workbench screenshot.'
            Assert-True ($managementText -like '*visuals/report-dashboard-findings.png*') 'Management overview should include an example findings screenshot.'
            Assert-True ($managementText -like '*visuals/report-dashboard-migration.png*') 'Management overview should include an example migration discovery screenshot.'

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
            Assert-True ($publicText -like '*ScanExport:owner_review_packets.csv*') 'Operator documentation should call out owner review packet live evidence.'
            Assert-True ($publicText -like '*What Needs Review First*') 'Operator documentation should tell users to start with the owner review queue.'
            Assert-True ($publicText -like '*share gate*') 'Operator documentation should explain the share gate access model.'
            Assert-True ($publicText -like '*Raw Evidence Tables*') 'Operator documentation should mention the report raw evidence view.'
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
