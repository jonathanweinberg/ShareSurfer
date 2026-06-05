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
                UserPrincipalName = ''
                Mail = 'finance.readers@example.test'
                Department = 'Finance Shared Data'
                Title = ''
                Company = 'Contoso Finance'
                Office = 'HQ-4'
                AccountEnabled = ''
                Manager = ''
                ManagerLevel1 = ''
                ManagerLevel2 = ''
                ObsPath = 'CORP.FIN'
                ObsAttribute = 'extensionAttribute10'
                DistinguishedName = 'CN=Finance Readers Group,OU=Groups,DC=example,DC=test'
            },
            [pscustomobject]@{
                Identity = 'CONTOSO\FinanceEditors'
                SamAccountName = 'FinanceEditors'
                DistinguishedName = 'CN=Finance Editors Group,OU=Groups,DC=example,DC=test'
                DisplayName = 'Finance Editors'
                ObjectClass = 'group'
                EmployeeId = ''
                EmployeeNumber = ''
                UserPrincipalName = ''
                Mail = 'finance.editors@example.test'
                Department = 'Accounts Payable'
                Title = ''
                Company = 'Contoso Finance'
                Office = 'HQ-4'
                AccountEnabled = ''
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
                UserPrincipalName = 'ava.accounting@example.test'
                Mail = 'ava.accounting@example.test'
                Department = 'Accounts Payable'
                Title = 'Accounting Analyst'
                Company = 'Contoso Finance'
                Office = 'HQ-4'
                AccountEnabled = 'True'
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
            Assert-True ($plan.ValidationCriteria.Name -contains 'EnterpriseGroupPopulation') 'Enterprise lab plan should include a group-population validation criterion.'
            Assert-True ($plan.ValidationCriteria.Name -contains 'EnterpriseSharePopulation') 'Enterprise lab plan should include a share-population validation criterion.'
            Assert-True ($plan.ValidationCriteria.Name -contains 'EnterpriseRealFiles') 'Enterprise lab plan should include a real-file validation criterion.'
            Assert-True ($plan.ValidationCriteria.Name -contains 'EnterpriseDiskBudget') 'Enterprise lab plan should include a disk-budget validation criterion.'
            Assert-True ($plan.ValidationCriteria.Name -contains 'EnterpriseOwnerRiskPivots') 'Enterprise lab plan should include owner risk pivot validation.'
            Assert-True ($plan.ValidationCriteria.Name -contains 'EnterpriseRelatedDataAreas') 'Enterprise lab plan should include related data area validation.'
            Assert-True ($plan.ValidationCriteria.Name -contains 'EnterpriseOwnerReviewPackets') 'Enterprise lab plan should include owner review packet validation.'
            Assert-True ($plan.ValidationCriteria.Name -contains 'EnterprisePermissionGroupObsCoverage') 'Enterprise lab plan should include permission-group OBS coverage validation.'
            Assert-True ($plan.ValidationCriteria.Name -contains 'EnterpriseCollectionErrors') 'Enterprise lab plan should include collection-error evidence validation.'
            Assert-True ($plan.ValidationCriteria.Name -contains 'EnterpriseOwnershipEvidence') 'Enterprise lab plan should include scanned ownership evidence validation.'
            Assert-True ($plan.ValidationCriteria.Name -contains 'EnterpriseEmployeeIdentifierCoverage') 'Enterprise lab plan should include employee identifier coverage validation.'
            Assert-True ($plan.ValidationCriteria.Name -contains 'EnterpriseManagerChainCoverage') 'Enterprise lab plan should include manager-chain coverage validation.'
            Assert-True ($plan.ValidationCriteria.Name -contains 'EnterpriseUserObsCoverage') 'Enterprise lab plan should include user OBS coverage validation.'
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
            Assert-True ($initializerScript -like '*New-ShareSurferLabDefaultPassword*') 'Lab directory initializer should generate a lab password per creation run.'
            Assert-True ($initializerScript -notlike '*ShareSurfer-Lab-Passw0rd!*') 'Lab directory initializer should not use the old fixed lab password pattern.'
            Assert-True ($initializerScript -like '*Get-ShareSurferLabOrganizationalUnit -DistinguishedName $ouDn*') 'Lab directory initializer should resolve the dedicated OU through the lab OU helper.'
            Assert-True ($initializerScript -like '*Get-ADOrganizationalUnit -LDAPFilter "(distinguishedName=$DistinguishedName)"*') 'Lab directory initializer should look up the dedicated OU by distinguished name.'
            Assert-True ($initializerScript -like '*Get-ADUser -Filter $filter -SearchBase $SearchBase*') 'Lab directory initializer should search users inside the lab OU.'
            Assert-True ($initializerScript -like '*Get-ADGroup -Filter $filter -SearchBase $SearchBase*') 'Lab directory initializer should search groups inside the lab OU.'
            Assert-True ($initializerScript -like '*already exists outside the ShareSurferLab OU*') 'Lab directory initializer should fail clearly on same-name objects outside the lab OU.'
            Assert-True ($initializerScript -like '*Set-ADUser -Identity $managedUser.DistinguishedName -Manager $manager.DistinguishedName*') 'Lab directory initializer should set managers using lab OU distinguished names.'
            Assert-True ($initializerScript -like '*Add-ADGroupMember -Identity $labGroup.DistinguishedName -Members $memberObject.DistinguishedName*') 'Lab directory initializer should add group members using lab OU distinguished names.'

            $fixtureScript = Get-Content -LiteralPath (Join-Path $repoRoot 'src/ShareSurfer/Public/New-ShareSurferLabFixture.ps1') -Raw
            Assert-True ($fixtureScript -like '*Assert-ShareSurferLabSmbSharePath -ShareName $share.ShareName -ExistingShare $existing -PlannedPath $share.LocalPath*') 'Lab fixture should validate existing SMB share paths before reusing share names.'
            Assert-True ($fixtureScript -like '*already exists at*but the lab plan expects*') 'Lab fixture should fail clearly when a planned SMB share name points at another path.'
            Assert-True ($fixtureScript -like '*ConvertTo-ShareSurferLabComparablePath*') 'Lab fixture should normalize paths before comparing existing and planned SMB share paths.'
            Assert-True ($fixtureScript.Contains('[System.IO.Directory]::CreateDirectory((ConvertTo-ShareSurferLabFilesystemPath -Path $Path))')) 'Lab fixture should create directories through .NET extended-length path handling.'
            Assert-True ($fixtureScript.Contains('[System.IO.File]::WriteAllBytes((ConvertTo-ShareSurferLabFilesystemPath -Path $Path), $bytes)')) 'Lab fixture should create file fixtures through .NET extended-length path handling.'
            Assert-True ($fixtureScript.Contains('return ''\\?\UNC\{0}'' -f $Path.TrimStart(''\'')')) 'Lab fixture should convert UNC paths to extended-length UNC paths.'
            Assert-True ($fixtureScript.Contains('$Path -match ''^[A-Za-z]:[\\/]''')) 'Lab fixture should recognize Windows drive-letter paths without relying on the local test OS path rules.'
            Assert-True ($fixtureScript.Contains('return ''\\?\{0}'' -f $Path')) 'Lab fixture should convert rooted Windows paths to extended-length local paths.'
            Assert-True ($fixtureScript -notlike '*Set-Content -Path $scenarioPath*') 'Long-path scenario file creation should not use normal Set-Content path handling.'
            Assert-True ($fixtureScript -notlike '*New-Item -ItemType Directory -Path $scenarioPath*') 'Long-path scenario directory creation should not use normal New-Item path handling.'
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
                [pscustomobject]@{ ErrorId = 'collection-error-001'; ShareId = 'share-002'; ItemId = ''; FullPath = '\\files01\Share002'; ErrorType = 'SharePermissionCollectionUnavailable'; Message = 'Share permission proof was unavailable'; Detail = 'Unit test collection gap evidence' }
                [pscustomobject]@{ ErrorId = 'collection-error-002'; ShareId = 'share-001'; ItemId = 'item-001'; FullPath = '\\files01\Share001\Deep\Path\file01.txt'; ErrorType = 'AclReadError'; Message = 'ACL read failed'; Detail = 'Unit test ACL error evidence' }
            ) | Export-Csv -LiteralPath (Join-Path $exportPath 'collection_errors.csv') -NoTypeInformation -Encoding UTF8
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
                [pscustomobject]@{ Identity = 'CONTOSO\FileReaders'; SamAccountName = 'FileReaders'; DisplayName = 'File Readers'; ObjectClass = 'group'; EmployeeId = ''; EmployeeNumber = ''; Manager = ''; ManagerLevel1 = ''; ManagerLevel2 = ''; ObsPath = 'CORP.TEST.FILE'; ObsAttribute = 'extensionAttribute10' },
                [pscustomobject]@{ Identity = 'CONTOSO\SSUser00001'; SamAccountName = 'SSUser00001'; DisplayName = 'ShareSurfer User 00001'; ObjectClass = 'user'; EmployeeId = 'E0000001'; EmployeeNumber = '0000001'; Manager = 'CONTOSO\Manager01'; ManagerLevel1 = 'CONTOSO\Manager01'; ManagerLevel2 = 'CONTOSO\Director01'; ObsPath = 'CORP.TEST.USER'; ObsAttribute = 'extensionAttribute10' }
            ) | Export-Csv -LiteralPath (Join-Path $exportPath 'identities.csv') -NoTypeInformation -Encoding UTF8
            @(
                [pscustomobject]@{ Identity = 'CONTOSO\SSUser00001'; EmployeeId = 'E0000001'; ManagerLevel1 = 'CONTOSO\Manager01'; ManagerLevel2 = 'CONTOSO\Director01'; ObsPath = 'CORP.TEST.USER'; ObsAttribute = 'extensionAttribute10' }
            ) | Export-Csv -LiteralPath (Join-Path $exportPath 'org_chains.csv') -NoTypeInformation -Encoding UTF8
            @(
                [pscustomobject]@{ BusinessUnit = 'Finance'; Owner = 'Finance Operations'; Pattern = '\\files01\Share001*'; Source = 'unit-test'; MatchingItems = '2'; Directories = '0'; Files = '2'; FindingCount = '3'; ConflictCount = '1'; PartialShareCount = '0'; DirectIdentityCount = '3'; DirectGroupCount = '3'; ExpandedMemberCount = '1'; RiskLevel = 'High' }
            ) | Export-Csv -LiteralPath (Join-Path $exportPath 'owner_risk_pivots.csv') -NoTypeInformation -Encoding UTF8
            @(
                [pscustomobject]@{ RelatedAreaId = 'related-area-0001'; RelatedDataArea = 'Finance / Finance Operations'; BusinessUnit = 'Finance'; Owner = 'Finance Operations'; Pattern = '\\files01\Share001*'; Source = 'unit-test'; RiskLevel = 'High'; MigrationReadiness = 'Review'; MatchingShares = '1'; MatchingItems = '2'; Directories = '0'; Files = '2'; FindingCount = '3'; ConflictCount = '1'; ReviewItemCount = '4'; PartialShareCount = '0'; DirectIdentityCount = '3'; DirectGroupCount = '3'; ExpandedMemberCount = '1'; RelatedBecause = 'same owner mapping; same business unit; matching path pattern; shared permission group; shared review risk'; SuggestedNextAction = 'Confirm ownership, review access groups, and clean up findings or conflicts before migration.' }
            ) | Export-Csv -LiteralPath (Join-Path $exportPath 'related_data_areas.csv') -NoTypeInformation -Encoding UTF8
            @(
                [pscustomobject]@{ ReviewPacketId = 'owner-review-0001'; BusinessUnit = 'Finance'; Owner = 'Finance Operations'; Pattern = '\\files01\Share001*'; Source = 'unit-test'; RiskLevel = 'High'; ReviewStatus = 'High priority review'; WhyReview = 'high-priority access or migration risk; permission-bearing security groups'; WhatToReviewFirst = 'access conflicts; findings; permissioned groups'; SuggestedNextAction = 'Confirm ownership, review assigned groups, and document the remediation decision.'; MatchingItems = '2'; Directories = '0'; Files = '2'; FindingCount = '3'; ConflictCount = '1'; PartialShareCount = '0'; DirectIdentityCount = '3'; DirectGroupCount = '3'; ExpandedMemberCount = '1'; MigrationReadiness = 'Review'; RelatedDataAreaCount = '1' }
            ) | Export-Csv -LiteralPath (Join-Path $exportPath 'owner_review_packets.csv') -NoTypeInformation -Encoding UTF8
            @(
                [pscustomobject]@{ ScanId = 'scan-001'; GeneratedAt = '2026-06-05T00:00:00Z'; ExportVersion = '1'; ObsAttribute = 'extensionAttribute10'; SourceMode = 'SmbShare'; OperationalPathLengthThreshold = '256'; AzurePathComponentLimit = '255'; AzureFullPathLimit = '2048'; ExplicitAceDepthThreshold = '2'; GroupExpansionMaxDepth = '20'; AdLookupMode = 'DirectoryOnly'; IncludeFiles = 'True' }
            ) | Export-Csv -LiteralPath (Join-Path $exportPath 'scan_manifest.csv') -NoTypeInformation -Encoding UTF8

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
                    [pscustomobject]@{ Name = 'EnterpriseGroupPopulation'; Required = $true; MinimumValue = 2; Unit = 'groups'; Description = 'Groups' },
                    [pscustomobject]@{ Name = 'EnterpriseEmployeeIdentifierCoverage'; Required = $true; MinimumValue = 1; Unit = 'users with employee identifiers'; Description = 'Employee identifiers' },
                    [pscustomobject]@{ Name = 'EnterpriseManagerChainCoverage'; Required = $true; MinimumValue = 1; Unit = 'two-level manager chains'; Description = 'Manager chains' },
                    [pscustomobject]@{ Name = 'EnterpriseUserObsCoverage'; Required = $true; MinimumValue = 1; Unit = 'users with OBS'; Description = 'User OBS coverage' },
                    [pscustomobject]@{ Name = 'EnterpriseSharePopulation'; Required = $true; MinimumValue = 2; Unit = 'shares'; Description = 'Shares' },
                    [pscustomobject]@{ Name = 'EnterpriseRealFiles'; Required = $true; MinimumValue = 3; Unit = 'file fixtures'; Description = 'Files' },
                    [pscustomobject]@{ Name = 'EnterpriseDeepPaths'; Required = $true; MinimumValue = 1; Unit = 'deep file fixtures'; Description = 'Deep paths' },
                    [pscustomobject]@{ Name = 'EnterpriseLongPathPolicy'; Required = $true; MinimumValue = 1; Unit = 'long-path scenarios'; Description = 'Long paths' },
                    [pscustomobject]@{ Name = 'EnterpriseSharePermissions'; Required = $true; MinimumValue = 1; Unit = 'share permission rows'; Description = 'Share permissions' },
                    [pscustomobject]@{ Name = 'EnterpriseAclEntries'; Required = $true; MinimumValue = 2; Unit = 'acl rows'; Description = 'ACL rows' },
                    [pscustomobject]@{ Name = 'EnterpriseFileAclEntries'; Required = $true; MinimumValue = 1; Unit = 'file acl rows'; Description = 'File ACL rows' },
                    [pscustomobject]@{ Name = 'EnterpriseOwnershipEvidence'; Required = $true; MinimumValue = 1; Unit = 'owned items'; Description = 'Ownership evidence' },
                    [pscustomobject]@{ Name = 'EnterpriseDeepExplicitAceFindings'; Required = $true; MinimumValue = 1; Unit = 'findings'; Description = 'Deep explicit ACE findings' },
                    [pscustomobject]@{ Name = 'EnterpriseBrokenInheritanceFindings'; Required = $true; MinimumValue = 1; Unit = 'findings'; Description = 'Broken inheritance findings' },
                    [pscustomobject]@{ Name = 'EnterpriseConflictFindings'; Required = $true; MinimumValue = 1; Unit = 'conflicts'; Description = 'Conflicts' },
                    [pscustomobject]@{ Name = 'EnterpriseCollectionErrors'; Required = $true; MinimumValue = 0; Unit = 'collection error rows'; Description = 'Collection error rows' },
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
            $groupPopulationCriterion = @($criteria | Where-Object { $_.Name -eq 'EnterpriseGroupPopulation' })[0]
            $employeeIdentifierCriterion = @($criteria | Where-Object { $_.Name -eq 'EnterpriseEmployeeIdentifierCoverage' })[0]
            $managerChainCriterion = @($criteria | Where-Object { $_.Name -eq 'EnterpriseManagerChainCoverage' })[0]
            $userObsCriterion = @($criteria | Where-Object { $_.Name -eq 'EnterpriseUserObsCoverage' })[0]
            $shareCriterion = @($criteria | Where-Object { $_.Name -eq 'EnterpriseSharePopulation' })[0]
            $fileCriterion = @($criteria | Where-Object { $_.Name -eq 'EnterpriseRealFiles' })[0]
            $deepCriterion = @($criteria | Where-Object { $_.Name -eq 'EnterpriseDeepPaths' })[0]
            $longPathCriterion = @($criteria | Where-Object { $_.Name -eq 'EnterpriseLongPathPolicy' })[0]
            $sharePermissionCriterion = @($criteria | Where-Object { $_.Name -eq 'EnterpriseSharePermissions' })[0]
            $aclCriterion = @($criteria | Where-Object { $_.Name -eq 'EnterpriseAclEntries' })[0]
            $fileAclCriterion = @($criteria | Where-Object { $_.Name -eq 'EnterpriseFileAclEntries' })[0]
            $ownershipCriterion = @($criteria | Where-Object { $_.Name -eq 'EnterpriseOwnershipEvidence' })[0]
            $deepAceCriterion = @($criteria | Where-Object { $_.Name -eq 'EnterpriseDeepExplicitAceFindings' })[0]
            $brokenInheritanceCriterion = @($criteria | Where-Object { $_.Name -eq 'EnterpriseBrokenInheritanceFindings' })[0]
            $conflictCriterion = @($criteria | Where-Object { $_.Name -eq 'EnterpriseConflictFindings' })[0]
            $collectionErrorCriterion = @($criteria | Where-Object { $_.Name -eq 'EnterpriseCollectionErrors' })[0]
            $groupExpansionCriterion = @($criteria | Where-Object { $_.Name -eq 'EnterpriseGroupExpansion' })[0]
            $permissionGroupObsCriterion = @($criteria | Where-Object { $_.Name -eq 'EnterprisePermissionGroupObsCoverage' })[0]
            $ownerRiskCriterion = @($criteria | Where-Object { $_.Name -eq 'EnterpriseOwnerRiskPivots' })[0]
            $relatedDataAreaCriterion = @($criteria | Where-Object { $_.Name -eq 'EnterpriseRelatedDataAreas' })[0]
            $ownerReviewPacketCriterion = @($criteria | Where-Object { $_.Name -eq 'EnterpriseOwnerReviewPackets' })[0]
            $diskCriterion = @($criteria | Where-Object { $_.Name -eq 'EnterpriseDiskBudget' })[0]

            Assert-Equal ([int]$userCriterion.ActualValue) 4 'User validation should prefer directory counts when available.'
            Assert-Equal $userCriterion.EvidenceSource 'ActiveDirectory' 'User validation should identify directory evidence.'
            Assert-Equal ([int]$groupPopulationCriterion.ActualValue) 2 'Group validation should prefer directory counts when available.'
            Assert-Equal $groupPopulationCriterion.EvidenceSource 'ActiveDirectory' 'Group validation should identify directory evidence.'
            Assert-True ([string]$groupPopulationCriterion.EvidenceDetail -like '*DirectoryGroups=2*') 'Group population evidence should record directory group counts.'
            Assert-Equal ([int]$employeeIdentifierCriterion.ActualValue) 1 'Employee identifier validation should count enriched user identities.'
            Assert-Equal $employeeIdentifierCriterion.EvidenceSource 'ScanExport:identities.csv' 'Employee identifier validation should identify identity export evidence.'
            Assert-True ([string]$employeeIdentifierCriterion.EvidenceDetail -like '*UsersWithEmployeeIdentifiers=1*') 'Employee identifier evidence should record enriched user counts.'
            Assert-Equal ([int]$managerChainCriterion.ActualValue) 1 'Manager-chain validation should count two-level manager evidence.'
            Assert-Equal $managerChainCriterion.EvidenceSource 'ScanExport:identities.csv' 'Manager-chain validation should prefer identity export evidence when present.'
            Assert-True ([string]$managerChainCriterion.EvidenceDetail -like '*OrgChainTwoLevelManagerChains=1*') 'Manager-chain evidence should record org-chain export counts.'
            Assert-Equal ([int]$userObsCriterion.ActualValue) 1 'User OBS validation should count enriched user OBS values.'
            Assert-Equal $userObsCriterion.EvidenceSource 'ScanExport:identities.csv' 'User OBS validation should identify identity export evidence.'
            Assert-True ([string]$userObsCriterion.EvidenceDetail -like '*ObsAttribute=extensionAttribute10*') 'User OBS evidence should record the runtime OBS attribute.'
            Assert-Equal ([int]$shareCriterion.ActualValue) 2 'Share validation should use scanned shares.'
            Assert-Equal $shareCriterion.EvidenceSource 'ScanExport:shares.csv' 'Share validation should identify scan export evidence.'
            Assert-Equal ([int]$fileCriterion.ActualValue) 3 'File validation should use scanned file item rows.'
            Assert-Equal $fileCriterion.EvidenceSource 'ScanExport:items.csv' 'File validation should identify scanned item evidence.'
            Assert-True ([string]$fileCriterion.EvidenceDetail -like '*ManifestIncludeFiles=True*') 'File validation should record the scan manifest IncludeFiles setting.'
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
            Assert-Equal ([int]$ownershipCriterion.ActualValue) 3 'Ownership validation should use scanned item owner rows.'
            Assert-Equal $ownershipCriterion.EvidenceSource 'ScanExport:items.csv' 'Ownership validation should identify scanned item evidence.'
            Assert-True ([string]$ownershipCriterion.EvidenceDetail -like '*OwnedItemRows=3*') 'Ownership evidence should record owned item row counts.'
            Assert-Equal ([int]$deepAceCriterion.ActualValue) 1 'Deep explicit ACE validation should use findings.'
            Assert-Equal $deepAceCriterion.EvidenceSource 'ScanExport:findings.csv' 'Deep explicit ACE validation should identify findings evidence.'
            Assert-Equal ([int]$brokenInheritanceCriterion.ActualValue) 1 'Broken inheritance validation should use findings.'
            Assert-Equal $brokenInheritanceCriterion.EvidenceSource 'ScanExport:findings.csv' 'Broken inheritance validation should identify findings evidence.'
            Assert-Equal ([int]$conflictCriterion.ActualValue) 1 'Conflict validation should use conflict rows.'
            Assert-Equal $conflictCriterion.EvidenceSource 'ScanExport:conflicts.csv' 'Conflict validation should identify conflicts evidence.'
            Assert-Equal ([int]$collectionErrorCriterion.ActualValue) 2 'Collection-error validation should count collection error rows.'
            Assert-Equal $collectionErrorCriterion.EvidenceSource 'ScanExport:collection_errors.csv' 'Collection-error validation should identify collection-error export evidence.'
            Assert-True ([string]$collectionErrorCriterion.EvidenceDetail -like '*CollectionErrorRows=2*') 'Collection-error evidence should record row counts.'
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

            @(
                [pscustomobject]@{ ScanId = 'scan-001'; GeneratedAt = '2026-06-05T00:00:00Z'; ExportVersion = '1'; ObsAttribute = 'extensionAttribute10'; SourceMode = 'SmbShare'; OperationalPathLengthThreshold = '256'; AzurePathComponentLimit = '255'; AzureFullPathLimit = '2048'; ExplicitAceDepthThreshold = '2'; GroupExpansionMaxDepth = '20'; AdLookupMode = 'DirectoryOnly'; IncludeFiles = 'False' }
            ) | Export-Csv -LiteralPath (Join-Path $exportPath 'scan_manifest.csv') -NoTypeInformation -Encoding UTF8
            $mismatchedManifestCriteria = @(New-ShareSurferLabValidationCriteriaRows -Plan $plan -ExportPath $exportPath -LabRoot $labRoot -CreateLab -IncludeFiles)
            $mismatchedManifestFileCriterion = @($mismatchedManifestCriteria | Where-Object { $_.Name -eq 'EnterpriseRealFiles' })[0]
            Assert-True (-not [bool]$mismatchedManifestFileCriterion.Passed) 'File validation should fail when scanned file rows disagree with the IncludeFiles manifest setting.'
            Assert-Equal $mismatchedManifestFileCriterion.EvidenceSource 'ScanExportMismatch:scan_manifest.csv' 'File validation should identify mismatched scan manifest evidence.'
            Assert-True ([string]$mismatchedManifestFileCriterion.EvidenceDetail -like '*ManifestIncludeFiles=False*') 'Mismatched file evidence should show the manifest IncludeFiles value.'
            @(
                [pscustomobject]@{ ScanId = 'scan-001'; GeneratedAt = '2026-06-05T00:00:00Z'; ExportVersion = '1'; ObsAttribute = 'extensionAttribute10'; SourceMode = 'SmbShare'; OperationalPathLengthThreshold = '256'; AzurePathComponentLimit = '255'; AzureFullPathLimit = '2048'; ExplicitAceDepthThreshold = '2'; GroupExpansionMaxDepth = '20'; AdLookupMode = 'DirectoryOnly'; IncludeFiles = 'True' }
            ) | Export-Csv -LiteralPath (Join-Path $exportPath 'scan_manifest.csv') -NoTypeInformation -Encoding UTF8

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
            Assert-True ($preflightRows.Name -contains 'TargetVolumeFreeSpace') 'Preflight should report target volume free-space readiness.'
            Assert-True ($preflightRows.Name -contains 'WindowsPathComponents') 'Preflight should report Windows path component safety.'
            Assert-True ($preflightRows.Name -contains 'EnterpriseIncludeFiles') 'Preflight should report enterprise IncludeFiles readiness.'
            Assert-True ($preflightRows.Name -contains 'AdObjectNameCollisions') 'Preflight should report AD object name collision readiness.'
            Assert-True ($preflightRows.Name -contains 'SmbSharePathCollisions') 'Preflight should report SMB share path collision readiness.'
            Assert-True ($preflightRows.Name -contains 'ObsAttributeSchema') 'Preflight should report whether the runtime OBS attribute is writable in the AD schema.'
            Assert-True ($preflightRows.Name -contains 'LabPasswordPolicy') 'Preflight should report domain password policy readiness for lab user creation.'
            $includeFilesPreflight = @($preflightRows | Where-Object { $_.Name -eq 'EnterpriseIncludeFiles' })[0]
            Assert-True ([bool]$includeFilesPreflight.Passed) 'Enterprise IncludeFiles preflight should pass when IncludeFiles is set.'
            $targetVolumePreflight = @($preflightRows | Where-Object { $_.Name -eq 'TargetVolumeFreeSpace' })[0]
            Assert-True ([string]$targetVolumePreflight.Evidence -like '*FreeBytes=*') 'Target volume preflight should include available byte evidence when the root is measurable.'
            Assert-True (-not [bool]$targetVolumePreflight.Required) 'Target volume preflight should be advisory until live lab creation is requested.'

            $tinyVolumePlan = [pscustomobject]@{ MaxLabBytes = [int64]1; EstimatedLabBytes = [int64]1 }
            $targetVolumeResult = Test-ShareSurferLabValidationTargetVolumeFreeSpace -Plan $tinyVolumePlan -LabRoot $labRoot
            Assert-True ([bool]$targetVolumeResult.Passed) 'Target volume helper should pass when available free space is greater than the configured byte budget.'
            Assert-True ([string]$targetVolumeResult.Evidence -like '*RequiredBytes=1*') 'Target volume helper should record the configured byte requirement.'

            try {
                function global:Get-ADDefaultDomainPasswordPolicy {
                    [pscustomobject]@{
                        MinPasswordLength = 14
                        ComplexityEnabled = $true
                        PasswordHistoryCount = 24
                    }
                }

                $passwordPolicyResult = Test-ShareSurferLabValidationPasswordPolicy
                Assert-True ([bool]$passwordPolicyResult.Passed) 'Lab password policy helper should pass when the generated password pattern satisfies the default domain policy.'
                Assert-True ([string]$passwordPolicyResult.Evidence -like '*GeneratedPasswordLength=33*MinPasswordLength=14*ComplexityEnabled=True*') 'Lab password policy evidence should record generated password shape and domain policy without revealing the password.'

                function global:Get-ADDefaultDomainPasswordPolicy {
                    [pscustomobject]@{
                        MinPasswordLength = 64
                        ComplexityEnabled = $true
                        PasswordHistoryCount = 24
                    }
                }

                $strictPasswordPolicyResult = Test-ShareSurferLabValidationPasswordPolicy
                Assert-True (-not [bool]$strictPasswordPolicyResult.Passed) 'Lab password policy helper should fail when the domain minimum length is stricter than the generated password pattern.'
                $passwordPolicyPreflight = @(New-ShareSurferLabValidationPreflight -Plan $plan -LabRoot $labRoot -RunRoot $exportPath -CreateLab -IncludeFiles | Where-Object { $_.Name -eq 'LabPasswordPolicy' })[0]
                Assert-True (-not [bool]$passwordPolicyPreflight.Passed) 'CreateLab preflight should block when the generated lab password pattern cannot satisfy the default domain policy.'
                Assert-True ([bool]$passwordPolicyPreflight.Required) 'CreateLab preflight should make lab password policy readiness required evidence.'
            }
            finally {
                Remove-Item -Path function:\Get-ADDefaultDomainPasswordPolicy -ErrorAction SilentlyContinue
            }

            try {
                . (Join-Path $repoRoot 'src/ShareSurfer/Private/Initialize-ShareSurferLabDirectoryObjects.ps1')
                function global:Get-ADRootDSE {
                    [pscustomobject]@{ schemaNamingContext = 'CN=Schema,CN=Configuration,DC=example,DC=test' }
                }
                function global:Get-ADObject {
                    param(
                        [string] $SearchBase,
                        [string] $LDAPFilter,
                        [string[]] $Properties
                    )

                    if ($LDAPFilter -like '*attributeSchema*info*') {
                        return [pscustomobject]@{ lDAPDisplayName = 'info' }
                    }
                    if ($LDAPFilter -like '*attributeSchema*employeeNumber*') {
                        return $null
                    }
                    if ($LDAPFilter -like '*attributeSchema*extensionAttribute10*') {
                        return $null
                    }
                    if ($LDAPFilter -like '*classSchema*user*') {
                        return [pscustomobject]@{ lDAPDisplayName = 'user'; subClassOf = 'organizationalPerson'; mayContain = @() }
                    }
                    if ($LDAPFilter -like '*classSchema*organizationalPerson*') {
                        return [pscustomobject]@{ lDAPDisplayName = 'organizationalPerson'; mayContain = @('info') }
                    }
                    if ($LDAPFilter -like '*classSchema*shareSurferGroupAux*') {
                        return [pscustomobject]@{ lDAPDisplayName = 'shareSurferGroupAux'; mayContain = @('info') }
                    }
                    if ($LDAPFilter -like '*classSchema*group*') {
                        return [pscustomobject]@{ lDAPDisplayName = 'group'; auxiliaryClass = 'shareSurferGroupAux'; mayContain = @() }
                    }
                    $null
                }

                $schemaPlan = [pscustomobject]@{ ObsAttribute = 'info' }
                $schemaResult = Test-ShareSurferLabValidationObsAttributeSchema -Plan $schemaPlan
                Assert-True ([bool]$schemaResult.Passed) 'OBS attribute schema helper should pass when the attribute exists and is allowed through direct, inherited, or auxiliary class schema.'
                Assert-True ([string]$schemaResult.Evidence -like '*ObsAttribute=info*UserAllows=True*GroupAllows=True*') 'OBS attribute schema evidence should show the checked attribute and allowed classes.'

                $missingSchemaPlan = [pscustomobject]@{ ObsAttribute = 'extensionAttribute10' }
                $missingSchemaResult = Test-ShareSurferLabValidationObsAttributeSchema -Plan $missingSchemaPlan
                Assert-True (-not [bool]$missingSchemaResult.Passed) 'OBS attribute schema helper should fail when the selected attribute is absent from the AD schema.'
                Assert-True ([string]$missingSchemaResult.Evidence -like '*AttributeExists=False*') 'OBS attribute schema evidence should show when the selected attribute is absent.'
                Assert-True (Test-ShareSurferLabUserAttributeAllowed -AttributeName 'info') 'Lab directory helper should detect optional user attributes allowed through inherited schema classes.'
                Assert-True (-not (Test-ShareSurferLabUserAttributeAllowed -AttributeName 'employeeNumber')) 'Lab directory helper should treat employeeNumber as optional when it is absent from the schema.'

                $obsSchemaPreflight = @(New-ShareSurferLabValidationPreflight -Plan $plan -LabRoot $labRoot -RunRoot $exportPath -CreateLab -IncludeFiles | Where-Object { $_.Name -eq 'ObsAttributeSchema' })[0]
                Assert-True (-not [bool]$obsSchemaPreflight.Passed) 'CreateLab preflight should block when the configured OBS attribute is absent from the AD schema.'
                Assert-True ([bool]$obsSchemaPreflight.Required) 'CreateLab preflight should make OBS schema readiness required evidence.'
                Assert-True ([string]$obsSchemaPreflight.NextAction -like '*-ObsAttribute*') 'OBS schema preflight should tell the operator to rerun with a valid attribute.'
            }
            finally {
                Remove-Item -Path function:\Get-ADRootDSE -ErrorAction SilentlyContinue
                Remove-Item -Path function:\Get-ADObject -ErrorAction SilentlyContinue
            }

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
                'permissioned_groups.csv',
                'org_chains.csv',
                'owner_mappings.csv',
                'owner_risk_pivots.csv',
                'related_data_areas.csv',
                'owner_review_packets.csv',
                'conflicts.csv',
                'findings.csv',
                'collection_errors.csv',
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

            $permissionedGroups = Import-Csv -LiteralPath (Join-Path $outputPath 'permissioned_groups.csv')
            Assert-True ($permissionedGroups.Group -contains 'CONTOSO\FinanceEditors') 'Permissioned group export should include NTFS-assigned groups.'
            Assert-True ($permissionedGroups.Group -contains 'CONTOSO\FinanceReaders') 'Permissioned group export should include share-assigned groups.'
            $financeEditorsGroup = @($permissionedGroups | Where-Object { $_.Group -eq 'CONTOSO\FinanceEditors' })[0]
            Assert-True ([int]$financeEditorsGroup.NtfsAssignments -gt 0) 'Permissioned group export should count NTFS assignments.'
            Assert-True ([int]$financeEditorsGroup.ExpandedMembers -gt 0) 'Permissioned group export should count expanded members.'
            Assert-True ($financeEditorsGroup.Rights -like '*Modify*') 'Permissioned group export should preserve observed rights.'
            Assert-True ($financeEditorsGroup.ExamplePath -like '*Finance*') 'Permissioned group export should include example path context.'

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
            $collectionErrors = Import-Csv -LiteralPath (Join-Path $outputPath 'collection_errors.csv')

            Assert-Equal $shares[0].PartialData 'True' 'Share rows should be partial when collection errors were recorded for the share.'
            Assert-True ($shares[0].PartialReason -like '*AclReadError=1*') 'Partial reason should summarize ACL read errors.'
            Assert-True ($shares[0].PartialReason -like '*EnumerationError=1*') 'Partial reason should summarize enumeration errors.'
            Assert-True ($findings.FindingType -contains 'CollectionError') 'Findings should preserve collection errors for troubleshooting.'
            Assert-True ($collectionErrors.ErrorType -contains 'AclReadError') 'Collection error export should preserve ACL read error rows.'
            Assert-True ($collectionErrors.ErrorType -contains 'EnumerationError') 'Collection error export should preserve enumeration error rows.'
            Assert-True ($collectionErrors[0].PSObject.Properties.Name -contains 'ErrorId') 'Collection error export should include stable row IDs.'
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
            $collectionErrors = @(Import-Csv -LiteralPath (Join-Path $outputPath 'collection_errors.csv'))
            $events = @(Import-Csv -LiteralPath (Join-Path $outputPath 'scan_events.csv'))

            Assert-Equal $shares.Count 2 'Mixed TargetPath scan should export both valid and failed target rows.'
            Assert-True (@($shares | Where-Object { $_.LocalPath -eq $validTarget }).Count -eq 1) 'Valid TargetPath should still be scanned and exported.'
            $failedShare = @($shares | Where-Object { $_.LocalPath -eq $missingTarget })[0]
            Assert-Equal $failedShare.PartialData 'True' 'Failed TargetPath row should be marked partial.'
            Assert-True ($failedShare.PartialReason -like '*Target path could not be resolved*') 'Failed TargetPath row should explain resolution failure.'
            Assert-True ($failedShare.PartialReason -like '*TargetPathResolveError=1*') 'Failed TargetPath row should summarize the resolution error count.'
            Assert-True (@($items | Where-Object { $_.FullPath -like "$validTarget*" }).Count -gt 0) 'Valid TargetPath should still export item evidence.'
            Assert-True (@($findings | Where-Object { $_.FindingType -eq 'CollectionError' -and $_.ObservedValue -eq 'TargetPathResolveError' }).Count -gt 0) 'Findings should include the failed TargetPath collection error.'
            Assert-True (@($collectionErrors | Where-Object { $_.ErrorType -eq 'TargetPathResolveError' -and $_.ShareId -eq $failedShare.ShareId }).Count -gt 0) 'Collection error export should preserve failed TargetPath evidence.'
            Assert-True (@($events | Where-Object { $_.EventType -eq 'TargetPathResolveError' }).Count -gt 0) 'Scan events should record the failed TargetPath resolution.'
        }
    },
    @{
        Name = 'Invoke-ShareSurferScan records share-permission collection gaps as collection errors'
        Body = {
            Import-Module $moduleManifest -Force
            $targetPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferBestEffort-' + [guid]::NewGuid().ToString('N'))
            New-Item -ItemType Directory -Path $targetPath -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $targetPath 'readme.txt') -Value 'best effort evidence' -Encoding UTF8
            function global:Get-SmbShareAccess {
                param([string] $Name)
                @()
            }
            try {
                $outputPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferExport-' + [guid]::NewGuid().ToString('N'))
                Invoke-ShareSurferScan -TargetPath $targetPath -OutputPath $outputPath -IncludeFiles -SkipIdentityEnrichment | Out-Null

                $shares = @(Import-Csv -LiteralPath (Join-Path $outputPath 'shares.csv'))
                $collectionErrors = @(Import-Csv -LiteralPath (Join-Path $outputPath 'collection_errors.csv'))
                $findings = @(Import-Csv -LiteralPath (Join-Path $outputPath 'findings.csv'))
                $events = @(Import-Csv -LiteralPath (Join-Path $outputPath 'scan_events.csv'))

                Assert-Equal $shares[0].PartialData 'True' 'Best-effort target path share should be marked partial when share permissions cannot be proven.'
                Assert-True ($shares[0].PartialReason -like '*Share-level permissions were not collected*') 'Partial reason should explain the missing share-level permission proof.'
                Assert-True ($shares[0].PartialReason -like '*SharePermissionCollectionUnavailable=1*') 'Partial reason should summarize the share-permission collection gap.'
                Assert-True (@($collectionErrors | Where-Object { $_.ErrorType -eq 'SharePermissionCollectionUnavailable' -and $_.Source -eq 'Get-SmbShareAccess' }).Count -eq 1) 'Collection errors should preserve missing share-permission proof as first-class evidence.'
                Assert-True (@($findings | Where-Object { $_.FindingType -eq 'CollectionError' -and $_.ObservedValue -eq 'SharePermissionCollectionUnavailable' }).Count -eq 1) 'Findings should include the share-permission collection gap for business review.'
                Assert-True (@($events | Where-Object { $_.EventType -eq 'SharePermissionCollectionUnavailable' }).Count -eq 1) 'Scan events should record the missing share-permission proof.'
            }
            finally {
                Remove-Item -Path function:\Get-SmbShareAccess -ErrorAction SilentlyContinue
            }
        }
    },
    @{
        Name = 'Scanner diagnostics preserve specific enumeration error targets when available'
        Body = {
            Import-Module $moduleManifest -Force
            $module = Get-Module ShareSurfer
            $targetPath = 'C:\ShareSurferLab\Finance\Restricted'
            $fallbackPath = 'C:\ShareSurferLab\Finance'
            $exception = New-Object System.UnauthorizedAccessException('Access denied while enumerating children.')
            $errorRecord = New-Object System.Management.Automation.ErrorRecord($exception, 'UnauthorizedAccess', [System.Management.Automation.ErrorCategory]::PermissionDenied, $targetPath)

            $resolvedPath = & $module {
                param($Record, $Fallback)
                Get-ShareSurferCollectionErrorPath -ErrorRecord $Record -FallbackPath $Fallback
            } $errorRecord $fallbackPath

            Assert-Equal $resolvedPath $targetPath 'Enumeration diagnostics should prefer the specific failed child path when PowerShell provides it.'
            $fallbackResolvedPath = & $module {
                param($Fallback)
                Get-ShareSurferCollectionErrorPath -FallbackPath $Fallback
            } $fallbackPath
            Assert-Equal $fallbackResolvedPath $fallbackPath 'Enumeration diagnostics should fall back to the scanned target root when no child target is available.'

            $localScannerText = Get-Content -LiteralPath (Join-Path $repoRoot 'src/ShareSurfer/Private/Get-ShareSurferLocalInventory.ps1') -Raw
            Assert-True ($localScannerText -like '*Get-ShareSurferCollectionErrorPath -ErrorRecord $childError*') 'Local scanner should use the collection-error path resolver for enumeration errors.'
            Assert-True ($localScannerText -like '*Source = ''Get-ChildItem''*') 'Local scanner should identify Get-ChildItem as the source for enumeration error rows.'
            Assert-True ($localScannerText -like '*EventType ''EnumerationError''*') 'Local scanner should record enumeration errors as scan events for diagnostics.'
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
            $avaIdentity = @($identities | Where-Object { $_.Identity -eq 'CONTOSO\Ava.Accounting' })[0]
            Assert-Equal $avaIdentity.UserPrincipalName 'ava.accounting@example.test' 'Identity enrichment should export user principal names for correlation.'
            Assert-Equal $avaIdentity.Mail 'ava.accounting@example.test' 'Identity enrichment should export mail for correlation.'
            Assert-Equal $avaIdentity.Department 'Accounts Payable' 'Identity enrichment should export department for owner correlation.'
            Assert-Equal $avaIdentity.Title 'Accounting Analyst' 'Identity enrichment should export job title for owner correlation.'
            Assert-Equal $avaIdentity.Company 'Contoso Finance' 'Identity enrichment should export company for owner correlation.'
            Assert-Equal $avaIdentity.Office 'HQ-4' 'Identity enrichment should export office for owner correlation.'
            Assert-Equal $avaIdentity.AccountEnabled 'True' 'Identity enrichment should export account enabled status when known.'
            Assert-True ($avaIdentity.DistinguishedName -like 'CN=Ava Human Name*') 'Identity enrichment should export distinguished names for directory correlation.'
            Assert-True ($groupEdges.ParentGroup -contains 'CONTOSO\FinanceEditors') 'Group expansion should include the top-level permission group.'
            Assert-True ($orgChains.Identity -contains 'CONTOSO\Ava.Accounting') 'Org chains should include enriched user manager and OBS data.'
            $avaOrgChain = @($orgChains | Where-Object { $_.Identity -eq 'CONTOSO\Ava.Accounting' })[0]
            Assert-Equal $avaOrgChain.Department 'Accounts Payable' 'Org chains should carry department for manager and OBS rollups.'
        }
    },
    @{
        Name = 'Invoke-ShareSurferScan records AD lookup mode and marks truncated group expansion'
        Body = {
            Import-Module $moduleManifest -Force
            $outputPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferExport-' + [guid]::NewGuid().ToString('N'))

            Invoke-ShareSurferScan -InputObject (New-TestInventory) -OutputPath $outputPath -AdLookupMode DirectoryOnly -GroupExpansionMaxDepth 1 -IncludeFiles | Out-Null

            $manifest = Import-Csv -LiteralPath (Join-Path $outputPath 'scan_manifest.csv')
            $groupEdges = Import-Csv -LiteralPath (Join-Path $outputPath 'group_edges.csv')

            Assert-Equal $manifest[0].AdLookupMode 'DirectoryOnly' 'Scan manifest should record the requested AD lookup mode.'
            Assert-Equal $manifest[0].IncludeFiles 'True' 'Scan manifest should record whether file objects were requested.'
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
                userprincipalname = @('ava.accounting@example.test')
                mail = @('ava.accounting@example.test')
                department = @('Accounts Payable')
                title = @('Accounting Analyst')
                company = @('Contoso Finance')
                physicaldeliveryofficename = @('HQ-4')
                useraccountcontrol = @('512')
                distinguishedname = @('CN=Ava Accounting,OU=Users,DC=example,DC=test')
                manager = @('CN=Morgan Manager,OU=Users,DC=example,DC=test')
                extensionattribute10 = @('CORP.FIN.AP')
            }

            $user = New-ShareSurferLdapIdentityRecord -Identity 'CONTOSO\Ava.Accounting' -Properties $userProperties -ObsAttribute 'extensionAttribute10' -ManagerLevel2 'CN=Taylor Director,OU=Users,DC=example,DC=test'
            Assert-Equal $user.ObjectClass 'user' 'LDAP user record should identify user object class.'
            Assert-Equal $user.ManagerLevel1 'CN=Morgan Manager,OU=Users,DC=example,DC=test' 'LDAP user record should preserve direct manager DN.'
            Assert-Equal $user.ManagerLevel2 'CN=Taylor Director,OU=Users,DC=example,DC=test' 'LDAP user record should preserve manager manager DN.'
            Assert-Equal $user.ObsPath 'CORP.FIN.AP' 'LDAP user record should read the configured OBS attribute.'
            Assert-Equal $user.EmployeeId 'E1001' 'LDAP user record should preserve employee ID.'
            Assert-Equal $user.UserPrincipalName 'ava.accounting@example.test' 'LDAP user record should preserve UPN.'
            Assert-Equal $user.Mail 'ava.accounting@example.test' 'LDAP user record should preserve mail.'
            Assert-Equal $user.Department 'Accounts Payable' 'LDAP user record should preserve department.'
            Assert-Equal $user.Title 'Accounting Analyst' 'LDAP user record should preserve title.'
            Assert-Equal $user.Company 'Contoso Finance' 'LDAP user record should preserve company.'
            Assert-Equal $user.Office 'HQ-4' 'LDAP user record should preserve office.'
            Assert-Equal $user.AccountEnabled 'True' 'LDAP user record should derive account enabled status from userAccountControl.'
            Assert-True ($user.DistinguishedName -like 'CN=Ava Accounting*') 'LDAP user record should preserve distinguished name.'

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
            $dnResolverScript = Get-Content -LiteralPath (Join-Path $repoRoot 'src/ShareSurfer/Private/Resolve-ShareSurferDistinguishedNameIdentity.ps1') -Raw
            foreach ($propertyName in @('userPrincipalName', 'mail', 'department', 'title', 'company', 'physicalDeliveryOfficeName', 'userAccountControl', 'distinguishedName')) {
                Assert-True ($dnResolverScript -like ('*{0}*' -f $propertyName)) ('LDAP DN member resolution should load {0} for group-expanded identity correlation.' -f $propertyName)
            }
        }
    },
    @{
        Name = 'ActiveDirectory identity lookup retries when optional employeeNumber is absent'
        Body = {
            Import-Module $moduleManifest -Force
            . (Join-Path $repoRoot 'src/ShareSurfer/Private/Get-ShareSurferIdentityName.ps1')
            . (Join-Path $repoRoot 'src/ShareSurfer/Private/Get-ShareSurferIdentityDomain.ps1')
            . (Join-Path $repoRoot 'src/ShareSurfer/Private/Get-ShareSurferDirectoryIdentity.ps1')

            try {
                $script:adUserLookupPropertySets = @()
                function global:Get-ADUser {
                    param(
                        [string] $Identity,
                        [string[]] $Properties
                    )

                    $script:adUserLookupPropertySets += ,@($Properties)
                    if (@($Properties | Where-Object { $_ -eq 'employeeNumber' }).Count -gt 0) {
                        throw 'The specified directory service attribute or value does not exist: employeeNumber'
                    }

                    [pscustomobject]@{
                        SamAccountName = $Identity
                        DisplayName = 'Ava Accounting'
                        EmployeeID = 'E1001'
                        UserPrincipalName = 'ava.accounting@example.test'
                        Mail = 'ava.accounting@example.test'
                        Department = 'Accounts Payable'
                        Title = 'Accounting Analyst'
                        Company = 'Contoso Finance'
                        physicalDeliveryOfficeName = 'HQ-4'
                        Enabled = $true
                        Manager = ''
                        extensionAttribute10 = 'CORP.FIN.AP'
                        DistinguishedName = 'CN=Ava Accounting,OU=ShareSurferLab,DC=example,DC=test'
                    }
                }
                function global:Get-ADGroup {
                    throw 'User lookup should succeed before group fallback.'
                }

                $identity = Get-ShareSurferDirectoryIdentity -Identity 'CONTOSO\Ava.Accounting' -ObsAttribute 'extensionAttribute10' -AdLookupMode ActiveDirectory
                Assert-Equal $identity.EmployeeId 'E1001' 'AD identity lookup should preserve employeeID when employeeNumber is unavailable.'
                Assert-Equal $identity.EmployeeNumber '' 'AD identity lookup should leave employeeNumber blank when the schema rejects it.'
                Assert-Equal $identity.ObsPath 'CORP.FIN.AP' 'AD identity lookup should preserve the selected OBS attribute after retrying without employeeNumber.'
                Assert-True ($script:adUserLookupPropertySets.Count -ge 2) 'AD identity lookup should retry after removing an optional rejected property.'
                Assert-True (@($script:adUserLookupPropertySets[-1] | Where-Object { $_ -eq 'employeeNumber' }).Count -eq 0) 'AD identity retry should omit employeeNumber after the schema rejects it.'
            }
            finally {
                Remove-Item -Path function:\Get-ADUser -ErrorAction SilentlyContinue
                Remove-Item -Path function:\Get-ADGroup -ErrorAction SilentlyContinue
                Remove-Variable -Name adUserLookupPropertySets -Scope Script -ErrorAction SilentlyContinue
            }
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
            Assert-True ($report -like '*active-filter-chips*') 'Report should expose active filter chips for business-review context.'
            Assert-True ($report -like '*renderActiveFilterChips*') 'Report should render active filter chips dynamically.'
            Assert-True ($report -like '*clearDashboardFilter*') 'Report should let reviewers clear individual dashboard filters.'
            Assert-True ($report -like '*clearAllDashboardFilters*') 'Report should let reviewers reset dashboard filters in one action.'
            Assert-True ($report -like '*ShareSurferDashboardState*') 'Report should persist the dashboard view and filters for offline review.'
            Assert-True ($report -like '*restoreDashboardState*') 'Report should restore dashboard view and filters from saved state.'
            Assert-True ($report -like '*URLSearchParams*') 'Report should keep dashboard filter state shareable in the URL hash.'
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
            Assert-True ($report -like '*permissioned_groups.csv*') 'Raw evidence view should expose permissioned groups.'
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
                    $CimSession
                )
                [pscustomobject]@{
                    Name = $Name
                    Path = $shareRoot
                    Description = 'Mocked SMB share'
                    PSComputerName = if ($null -eq $CimSession) { '' } else { [string]$CimSession.ComputerName }
                }
            }

            function global:Get-SmbShareAccess {
                param(
                    [string] $Name,
                    $CimSession
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
                Invoke-ShareSurferScan -ComputerName ([System.Environment]::MachineName) -ShareName 'Finance' -OutputPath $outputPath -IncludeFiles -SkipIdentityEnrichment | Out-Null
                $shares = Import-Csv -LiteralPath (Join-Path $outputPath 'shares.csv')
                $permissions = Import-Csv -LiteralPath (Join-Path $outputPath 'share_permissions.csv')
                $collectionErrors = @(Import-Csv -LiteralPath (Join-Path $outputPath 'collection_errors.csv'))
                $events = Import-Csv -LiteralPath (Join-Path $outputPath 'scan_events.csv')

                Assert-Equal $shares[0].ComputerName ([System.Environment]::MachineName) 'SMB share scans should preserve the requested computer name.'
                Assert-Equal $shares[0].ShareName 'Finance' 'SMB share scans should preserve the requested share name.'
                Assert-Equal $shares[0].PartialData 'False' 'SMB share scans should not remain partial when share-level permissions were collected for the requested share.'
                Assert-Equal $shares[0].PartialReason '' 'SMB share scans should clear stale local-path permission partial reasons after share-level permissions are proven.'
                Assert-True ($permissions.Identity -contains 'CONTOSO\ShareModeReaders') 'SMB share scans should collect share-level permissions.'
                Assert-True (@($collectionErrors | Where-Object { $_.ErrorType -eq 'SharePermissionCollectionUnavailable' }).Count -eq 0) 'SMB share scans should clear stale share-permission collection errors after share-level permissions are proven.'
                Assert-True ($events.EventType -contains 'ShareTargetResolved') 'SMB share scans should log share target resolution.'
            }
            finally {
                Remove-Item -Path function:\Get-SmbShare -ErrorAction SilentlyContinue
                Remove-Item -Path function:\Get-SmbShareAccess -ErrorAction SilentlyContinue
            }
        }
    },
    @{
        Name = 'Invoke-ShareSurferScan uses real CIM session objects for remote SMB share targets'
        Body = {
            Import-Module $moduleManifest -Force
            $shareRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferRemoteSmbShare-' + [guid]::NewGuid().ToString('N'))
            New-Item -ItemType Directory -Path $shareRoot -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $shareRoot 'remote-file.txt') -Value 'remote share mode'
            $script:newCimSessionCount = 0
            $script:removeCimSessionCount = 0
            $script:getSmbShareSawSession = $false
            $script:getSmbShareAccessSawSession = $false

            function global:New-CimSession {
                param([string] $ComputerName)
                $script:newCimSessionCount++
                [pscustomobject]@{
                    ComputerName = $ComputerName
                    SessionId = 'mock-session-001'
                }
            }

            function global:Remove-CimSession {
                param($CimSession)
                if ($null -ne $CimSession -and $CimSession.SessionId -eq 'mock-session-001') {
                    $script:removeCimSessionCount++
                }
            }

            function global:Get-SmbShare {
                param(
                    [string] $Name,
                    $CimSession
                )
                Assert-True ($null -ne $CimSession -and $CimSession.SessionId -eq 'mock-session-001') 'Remote Get-SmbShare should receive a CIM session object.'
                $script:getSmbShareSawSession = $true
                [pscustomobject]@{
                    Name = $Name
                    Path = $shareRoot
                    Description = 'Mocked remote SMB share'
                }
            }

            function global:Get-SmbShareAccess {
                param(
                    [string] $Name,
                    $CimSession
                )
                Assert-True ($null -ne $CimSession -and $CimSession.SessionId -eq 'mock-session-001') 'Remote Get-SmbShareAccess should receive the same CIM session object.'
                $script:getSmbShareAccessSawSession = $true
                [pscustomobject]@{
                    Name = $Name
                    AccountName = 'CONTOSO\RemoteShareReaders'
                    AccessRight = 'Read'
                    AccessControlType = 'Allow'
                }
            }

            try {
                $outputPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferRemoteExport-' + [guid]::NewGuid().ToString('N'))
                Invoke-ShareSurferScan -ComputerName 'remote-files01' -ShareName 'Finance' -OutputPath $outputPath -IncludeFiles -SkipIdentityEnrichment | Out-Null
                $shares = Import-Csv -LiteralPath (Join-Path $outputPath 'shares.csv')
                $permissions = Import-Csv -LiteralPath (Join-Path $outputPath 'share_permissions.csv')
                $events = Import-Csv -LiteralPath (Join-Path $outputPath 'scan_events.csv')

                Assert-Equal $script:newCimSessionCount 1 'Remote SMB scans should create one CIM session for the target computer.'
                Assert-Equal $script:removeCimSessionCount 1 'Remote SMB scans should dispose the created CIM session.'
                Assert-True $script:getSmbShareSawSession 'Remote SMB share lookup should use the CIM session.'
                Assert-True $script:getSmbShareAccessSawSession 'Remote SMB permission lookup should reuse the CIM session.'
                Assert-Equal $shares[0].PartialData 'False' 'Remote SMB share data should not be partial when share-level permissions were collected.'
                Assert-True ($permissions.Identity -contains 'CONTOSO\RemoteShareReaders') 'Remote SMB scans should collect share-level permissions through the CIM session.'
                Assert-True ($events.EventType -contains 'RemoteCimSessionCreated') 'Remote SMB scans should log CIM session creation.'
            }
            finally {
                Remove-Item -Path function:\New-CimSession -ErrorAction SilentlyContinue
                Remove-Item -Path function:\Remove-CimSession -ErrorAction SilentlyContinue
                Remove-Item -Path function:\Get-SmbShare -ErrorAction SilentlyContinue
                Remove-Item -Path function:\Get-SmbShareAccess -ErrorAction SilentlyContinue
            }
        }
    },
    @{
        Name = 'Invoke-ShareSurferScan marks remote SMB shares partial when CIM session setup fails'
        Body = {
            Import-Module $moduleManifest -Force
            function global:New-CimSession {
                throw 'mock CIM session failure'
            }
            function global:Get-SmbShare {
                throw 'Get-SmbShare should not be called without a remote CIM session.'
            }
            function global:Get-SmbShareAccess {
                throw 'Get-SmbShareAccess should not be called without a remote CIM session.'
            }

            try {
                $outputPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferRemotePartialExport-' + [guid]::NewGuid().ToString('N'))
                Invoke-ShareSurferScan -ComputerName 'remote-files02' -ShareName 'Finance' -OutputPath $outputPath -IncludeFiles -SkipIdentityEnrichment | Out-Null
                $shares = Import-Csv -LiteralPath (Join-Path $outputPath 'shares.csv')
                $permissions = Import-Csv -LiteralPath (Join-Path $outputPath 'share_permissions.csv')
                $findings = Import-Csv -LiteralPath (Join-Path $outputPath 'findings.csv')
                $events = Import-Csv -LiteralPath (Join-Path $outputPath 'scan_events.csv')

                Assert-Equal $shares[0].ComputerName 'remote-files02' 'Remote partial scans should preserve the requested computer name.'
                Assert-Equal $shares[0].PartialData 'True' 'Remote SMB share should be partial when remote CIM setup and share permissions fail.'
                Assert-True ([string]$shares[0].PartialReason -like '*Share-level permissions were not collected*') 'Remote partial scans should explain missing share-level permissions.'
                Assert-Equal @($permissions).Count 0 'Remote partial scans should not fabricate share-level permissions.'
                Assert-True ($findings.FindingType -contains 'CollectionError') 'Remote CIM session setup failures should be exported as collection-error findings.'
                Assert-True ($events.EventType -contains 'RemoteCimSessionError') 'Remote CIM session setup failures should be logged as scan events.'
            }
            finally {
                Remove-Item -Path function:\New-CimSession -ErrorAction SilentlyContinue
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
            $inventory | Add-Member -MemberType NoteProperty -Name ScanErrors -Value @(
                [pscustomobject]@{
                    ShareId = 'share-finance'
                    FullPath = '\\files01\Finance\Delegated'
                    ErrorType = 'AclReadError'
                    Message = 'Access denied while reading CONTOSO\FinanceEditors ACL.'
                    Detail = '\\files01\Finance\Delegated'
                }
            )
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
            $issueCommentDirectory = Join-Path $runRoot 'issue-comments'
            New-Item -ItemType Directory -Path $issueCommentDirectory -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $issueCommentDirectory 'issue-1-lab-fixture-live-proof.md') -Value @(
                'ShareSurfer live validation update for issue #1: lab fixture proof.',
                '',
                '**Safe Sharing Note**',
                '- This public-safe comment omits raw evidence detail values.'
            ) -Encoding UTF8
            Set-Content -LiteralPath (Join-Path $issueCommentDirectory 'issue-3-scanner-live-proof.md') -Value @(
                'ShareSurfer live validation update for issue #3: scanner proof.',
                '',
                '**Safe Sharing Note**',
                '- This public-safe comment omits raw evidence detail values.'
            ) -Encoding UTF8
            @(
                [pscustomobject]@{ IssueNumber = 1; FileName = 'issue-1-lab-fixture-live-proof.md'; CriteriaPassed = $true; AcceptanceChecksPassed = $true; BlockingLiveReviewRows = 0; OutputPath = (Join-Path $issueCommentDirectory 'issue-1-lab-fixture-live-proof.md') },
                [pscustomobject]@{ IssueNumber = 3; FileName = 'issue-3-scanner-live-proof.md'; CriteriaPassed = $true; AcceptanceChecksPassed = $true; BlockingLiveReviewRows = 0; OutputPath = (Join-Path $issueCommentDirectory 'issue-3-scanner-live-proof.md') }
            ) | Export-Csv -LiteralPath (Join-Path $issueCommentDirectory 'issue-comment-manifest.csv') -NoTypeInformation -Encoding UTF8
            Set-Content -LiteralPath (Join-Path $issueCommentDirectory 'post-commands.txt') -Value @(
                ('gh issue comment 1 --repo jonathanweinberg/ShareSurfer --body-file "{0}"' -f (Join-Path $issueCommentDirectory 'issue-1-lab-fixture-live-proof.md')),
                ('gh issue comment 3 --repo jonathanweinberg/ShareSurfer --body-file "{0}"' -f (Join-Path $issueCommentDirectory 'issue-3-scanner-live-proof.md'))
            ) -Encoding UTF8

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
            $redactedCollectionErrors = Get-Content -LiteralPath (Join-Path $bundlePath 'collection_errors.csv') -Raw
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
            $redactedPermissionedGroups = Get-Content -LiteralPath (Join-Path $bundlePath 'permissioned_groups.csv') -Raw
            $redactedOwners = Get-Content -LiteralPath (Join-Path $bundlePath 'owner_mappings.csv') -Raw
            $redactedOwnerRiskPivots = Get-Content -LiteralPath (Join-Path $bundlePath 'owner_risk_pivots.csv') -Raw
            $redactedRelatedDataAreas = Get-Content -LiteralPath (Join-Path $bundlePath 'related_data_areas.csv') -Raw
            $redactedOwnerReviewPackets = Get-Content -LiteralPath (Join-Path $bundlePath 'owner_review_packets.csv') -Raw
            Assert-True ($redactedIdentities -notlike '*E1001*') 'Employee IDs must be anonymized.'
            Assert-True ($redactedIdentities -notlike '*1001*') 'Employee numbers must be anonymized.'
            Assert-True ($redactedIdentities -notlike '*finance.editors@example.test*') 'Identity mail values must be anonymized.'
            Assert-True ($redactedIdentities -notlike '*Accounts Payable*') 'Identity department values must be anonymized.'
            Assert-True ($redactedIdentities -notlike '*Contoso Finance*') 'Identity company values must be anonymized.'
            Assert-True ($redactedIdentities -notlike '*CN=Finance Editors Group*') 'Identity distinguished names must be anonymized.'
            Assert-True ($redactedPermissionedGroups -notlike '*FinanceEditors*') 'Permissioned group export must anonymize group names.'
            Assert-True ($redactedPermissionedGroups -notlike '*\\files01\Finance*') 'Permissioned group export must anonymize example paths.'
            Assert-True ($redactedPermissionedGroups -like '*ID-*') 'Permissioned group export should preserve relationships with stable tokens.'
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
            Assert-True ([int]$bundleDiagnostics.Inventory.CollectionErrorCount -gt 0) 'Support bundle diagnostics should summarize collection error counts.'
            Assert-True (@($bundleDiagnostics.Rollups.FindingsByType | Where-Object { $_.Name -eq 'DeepExplicitAce' }).Count -gt 0) 'Support bundle diagnostics should include finding type rollups.'
            Assert-True (@($bundleDiagnostics.Rollups.CollectionErrorsByType | Where-Object { $_.Name -eq 'AclReadError' }).Count -gt 0) 'Support bundle diagnostics should include collection error type rollups.'
            Assert-True ($bundleDiagnostics.ScanSettings.PSObject.Properties.Name -contains 'AdLookupMode') 'Support bundle diagnostics should preserve safe scan settings.'
            Assert-True ([int]$bundleDiagnostics.Inventory.RelatedDataAreaCount -gt 0) 'Support bundle diagnostics should summarize related data area counts.'
            Assert-True ([int]$bundleDiagnostics.Inventory.OwnerReviewPacketCount -gt 0) 'Support bundle diagnostics should summarize owner review packet counts.'
            Assert-True ([int]$bundleDiagnostics.Inventory.PermissionedGroupCount -gt 0) 'Support bundle diagnostics should summarize permissioned group counts.'
            Assert-True (@($bundleSummary.Files | Where-Object { $_.FileName -eq 'acl_entries.csv' }).Count -eq 1) 'Support bundle summary should include redacted file diagnostics.'
            Assert-True ($bundleSummaryText -notlike '*CONTOSO*') 'Support bundle summary must not contain source domain names.'
            Assert-True ($bundleSummaryText -notlike '*FinanceEditors*') 'Support bundle summary must not contain source group names.'
            Assert-True ($bundleSummaryText -notlike '*unit-test*') 'Support bundle summary must not expose the redaction salt.'
            Assert-True ($bundleDiagnosticsText -notlike '*CONTOSO*') 'Support bundle diagnostics must not contain source domain names.'
            Assert-True ($bundleDiagnosticsText -notlike '*FinanceEditors*') 'Support bundle diagnostics must not contain source group names.'
            Assert-True ($bundleDiagnosticsText -notlike '*unit-test*') 'Support bundle diagnostics must not expose the redaction salt.'
            Assert-True ($redactedCollectionErrors -notlike '*CONTOSO*') 'Redacted collection errors must not contain source domain names.'
            Assert-True ($redactedCollectionErrors -notlike '*files01*') 'Redacted collection errors must not contain source server names.'
            Assert-True ($redactedCollectionErrors -like '*AclReadError*') 'Redacted collection errors should preserve safe error types.'
            Assert-True ($labRunDiagnosticsText -notlike '*CONTOSO*') 'Lab-run diagnostics must not contain source domain names.'
            Assert-True ($labRunDiagnosticsText -notlike '*FinanceEditors*') 'Lab-run diagnostics must not contain source group names.'
            Assert-True ($labRunDiagnosticsText -notlike '*files01*') 'Lab-run diagnostics must not contain source server names.'
            Assert-True ($labRunDiagnosticsText -notlike '*unit-test*') 'Lab-run diagnostics must not expose the redaction salt.'
            Assert-True ($labRunDiagnosticsText -like '*ID-*') 'Lab-run diagnostics should preserve relationships with stable tokens.'
            Assert-Equal ([string]$labRunDiagnostics.IssueComments.Included) 'True' 'Lab-run diagnostics should record bundled issue comment inclusion.'
            Assert-Equal ([int]$labRunDiagnostics.IssueComments.CommentCount) 2 'Lab-run diagnostics should record bundled issue comment count.'
            Assert-Equal ([string]$labRunDiagnostics.IssueComments.ManifestIncluded) 'True' 'Lab-run diagnostics should record bundled issue comment manifest inclusion.'
            Assert-Equal ([string]$labRunDiagnostics.IssueComments.PostCommandsIncluded) 'True' 'Lab-run diagnostics should record bundled issue comment post-command inclusion.'
            Assert-True ($bundleFiles.FileName -contains 'acl_entries.csv') 'Support bundle file diagnostics should include redacted ACL export.'
            Assert-True ($bundleFiles.FileName -contains 'owner_risk_pivots.csv') 'Support bundle file diagnostics should include owner risk pivots.'
            Assert-True ($bundleFiles.FileName -contains 'related_data_areas.csv') 'Support bundle file diagnostics should include related data areas.'
            Assert-True ($bundleFiles.FileName -contains 'owner_review_packets.csv') 'Support bundle file diagnostics should include owner review packets.'
            Assert-True ($bundleFiles.FileName -contains 'permissioned_groups.csv') 'Support bundle file diagnostics should include permissioned groups.'
            Assert-True ($bundleFiles.FileName -contains 'collection_errors.csv') 'Support bundle file diagnostics should include redacted collection errors.'
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
            Assert-True ($bundleFiles.FileName -contains 'issue_comments/issue-1-lab-fixture-live-proof.md') 'Support bundle file diagnostics should include bundled issue #1 comment body.'
            Assert-True ($bundleFiles.FileName -contains 'issue_comments/issue-3-scanner-live-proof.md') 'Support bundle file diagnostics should include bundled issue #3 comment body.'
            Assert-True ($bundleFiles.FileName -contains 'issue_comments/issue_comment_manifest.csv') 'Support bundle file diagnostics should include sanitized issue comment manifest.'
            Assert-True ($bundleFiles.FileName -contains 'issue_comments/post_commands.txt') 'Support bundle file diagnostics should include sanitized issue comment post commands.'
            Assert-True ($bundleFiles.FileName -contains 'support_bundle_redaction_audit.csv') 'Support bundle file diagnostics should include redaction audit diagnostics.'
            $bundledIssueOneComment = Get-Content -LiteralPath (Join-Path $bundlePath 'issue_comments/issue-1-lab-fixture-live-proof.md') -Raw
            Assert-True ($bundledIssueOneComment -like '*ShareSurfer live validation update for issue #1*') 'Bundled issue comment should preserve the public-safe body.'
            Assert-True ($bundledIssueOneComment -notlike '*CONTOSO*') 'Bundled issue comment must not contain source domain names.'
            $bundledIssueCommentManifest = Get-Content -LiteralPath (Join-Path $bundlePath 'issue_comments/issue_comment_manifest.csv') -Raw
            $bundledIssueCommentPostCommands = Get-Content -LiteralPath (Join-Path $bundlePath 'issue_comments/post_commands.txt') -Raw
            Assert-True ($bundledIssueCommentManifest -notlike "*$runRoot*") 'Bundled issue comment manifest must not contain raw run-root paths.'
            Assert-True ($bundledIssueCommentManifest -notlike '*OutputPath*') 'Bundled issue comment manifest must not include raw output path columns.'
            Assert-True ($bundledIssueCommentManifest -like '*BundledFileName*') 'Bundled issue comment manifest should include relative bundle file names.'
            Assert-True ($bundledIssueCommentPostCommands -notlike "*$runRoot*") 'Bundled issue comment post commands must not contain raw run-root paths.'
            Assert-True ($bundledIssueCommentPostCommands -like '*--body-file "issue_comments/issue-1-lab-fixture-live-proof.md"*') 'Bundled issue comment post commands should use relative bundle paths.'
            Assert-True ($redactionAudit.Count -gt 0) 'Redaction audit should include checked sensitive source values.'
            Assert-True (@($redactionAudit | Where-Object { $_.LeakDetected -eq 'True' }).Count -eq 0) 'Redaction audit should not detect leaked source values.'
            Assert-True (($redactionAudit | Get-Member -MemberType NoteProperty).Name -contains 'ValueToken') 'Redaction audit should use synthetic tokens instead of raw source values.'
            Assert-True ($redactionAudit.SourceFile -contains 'lab-preflight.csv') 'Redaction audit should include sensitive lab preflight evidence values.'
            Assert-True ($redactionAudit.SourceFile -contains 'lab-validation-criteria.csv') 'Redaction audit should include sensitive lab validation criteria evidence values.'
            Assert-True ($redactionAudit.SourceFile -contains 'live-evidence-review.csv') 'Redaction audit should include sensitive live evidence review values.'
            Assert-True ($redactionAudit.SourceFile -contains 'lab-run-events.jsonl') 'Redaction audit should include sensitive raw lab-run event details.'
            Assert-True ($redactionAudit.SourceFile -contains 'v1-acceptance.json') 'Redaction audit should include sensitive acceptance check detail values.'
            Assert-True (@($redactionAudit | Where-Object { $_.SourceFile -eq 'lab-run-events.jsonl' -and $_.ColumnName -eq 'Detail' -and $_.ValueToken -like 'ID-*' }).Count -gt 0) 'Lab-run event audit rows should use stable tokens instead of raw details.'
            $auditContent = Get-Content -LiteralPath $redactionAuditPath -Raw
            Assert-True ($auditContent -notlike '*CONTOSO*') 'Redaction audit must not contain source domain names.'
            Assert-True ($auditContent -notlike '*FinanceEditors*') 'Redaction audit must not contain source group names.'
            Assert-True ($auditContent -notlike '*files01*') 'Redaction audit must not contain source server names from lab-run evidence.'
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
            $issueSummaryScript = Join-Path $repoRoot 'scripts/New-ShareSurferValidationIssueSummary.ps1'
            $issueCommentScript = Join-Path $repoRoot 'scripts/New-ShareSurferValidationIssueComments.ps1'
            $issueCommentPublisherScript = Join-Path $repoRoot 'scripts/Publish-ShareSurferValidationIssueComments.ps1'
            $closeoutChecklistScript = Join-Path $repoRoot 'scripts/New-ShareSurferValidationCloseoutChecklist.ps1'
            $dashboardReviewScript = Join-Path $repoRoot 'scripts/New-ShareSurferDashboardReview.ps1'
            $collectorEnvironmentScript = Join-Path $repoRoot 'scripts/New-ShareSurferCollectorEnvironment.ps1'
            $runRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferAcceptance-' + [guid]::NewGuid().ToString('N'))
            $exportPath = Join-Path $runRoot 'export'
            $reportPath = Join-Path $runRoot 'report.html'
            $dashboardReviewPath = Join-Path $runRoot 'dashboard-review.md'
            $collectorEnvironmentPath = Join-Path $runRoot 'collector-environment.json'
            $bundlePath = Join-Path $runRoot 'support-bundle-redacted'
            $acceptanceSummaryPath = Join-Path $runRoot 'v1-acceptance-summary.json'
            $closeoutChecklistPath = Join-Path $runRoot 'validation-closeout-checklist.md'
            $issueCommentDirectory = Join-Path $runRoot 'issue-comments'
            New-Item -ItemType Directory -Path $runRoot -Force | Out-Null

            Invoke-ShareSurferScan -InputObject (New-TestInventory) -OutputPath $exportPath -SkipIdentityEnrichment -IncludeFiles | Out-Null
            ConvertTo-ShareSurferReport -ExportPath $exportPath -OutputPath $reportPath | Out-Null
            & $dashboardReviewScript -RunRoot $runRoot -ExportPath $exportPath -ReportPath $reportPath -OutputPath $dashboardReviewPath | Out-Null
            & $collectorEnvironmentScript -OutputPath $collectorEnvironmentPath | Out-Null
            @(
                [pscustomobject]@{ Name = 'EnterpriseUserPopulation'; Required = $true; MinimumValue = 1; ActualValue = 1; Unit = 'users'; Passed = $true; EvidenceSource = 'ActiveDirectory'; EvidenceDetail = 'Synthetic acceptance proof'; Description = 'Users' },
                [pscustomobject]@{ Name = 'EnterpriseGroupPopulation'; Required = $true; MinimumValue = 1; ActualValue = 1; Unit = 'groups'; Passed = $true; EvidenceSource = 'ActiveDirectory'; EvidenceDetail = 'Synthetic acceptance proof'; Description = 'Groups' },
                [pscustomobject]@{ Name = 'EnterpriseSharePopulation'; Required = $true; MinimumValue = 1; ActualValue = 1; Unit = 'shares'; Passed = $true; EvidenceSource = 'ScanExport:shares.csv'; EvidenceDetail = 'Synthetic acceptance proof'; Description = 'Shares' },
                [pscustomobject]@{ Name = 'EnterpriseRealFiles'; Required = $true; MinimumValue = 1; ActualValue = 1; Unit = 'file fixtures'; Passed = $true; EvidenceSource = 'ScanExport:items.csv'; EvidenceDetail = 'Synthetic acceptance proof'; Description = 'Files' },
                [pscustomobject]@{ Name = 'EnterpriseDeepPaths'; Required = $true; MinimumValue = 1; ActualValue = 1; Unit = 'deep file fixtures'; Passed = $true; EvidenceSource = 'ScanExport:items.csv'; EvidenceDetail = 'Synthetic acceptance proof'; Description = 'Deep paths' },
                [pscustomobject]@{ Name = 'EnterpriseLongPathPolicy'; Required = $true; MinimumValue = 1; ActualValue = 1; Unit = 'long-path scenarios'; Passed = $true; EvidenceSource = 'ScanExport:findings.csv'; EvidenceDetail = 'Synthetic acceptance proof'; Description = 'Long paths' },
                [pscustomobject]@{ Name = 'EnterpriseDiskBudget'; Required = $true; MinimumValue = 1; ActualValue = 1; Unit = 'pass/fail'; Passed = $true; EvidenceSource = 'FileSystem'; EvidenceDetail = 'Synthetic acceptance proof'; Description = 'Disk budget' },
                [pscustomobject]@{ Name = 'EnterpriseSharePermissions'; Required = $true; MinimumValue = 1; ActualValue = 1; Unit = 'share permission rows'; Passed = $true; EvidenceSource = 'ScanExport:share_permissions.csv'; EvidenceDetail = 'Synthetic acceptance proof'; Description = 'Share permissions' },
                [pscustomobject]@{ Name = 'EnterpriseAclEntries'; Required = $true; MinimumValue = 1; ActualValue = 1; Unit = 'ACL rows'; Passed = $true; EvidenceSource = 'ScanExport:acl_entries.csv'; EvidenceDetail = 'Synthetic acceptance proof'; Description = 'ACL entries' },
                [pscustomobject]@{ Name = 'EnterpriseFileAclEntries'; Required = $true; MinimumValue = 1; ActualValue = 1; Unit = 'file ACL rows'; Passed = $true; EvidenceSource = 'ScanExport:acl_entries.csv'; EvidenceDetail = 'Synthetic acceptance proof'; Description = 'File ACL entries' },
                [pscustomobject]@{ Name = 'EnterpriseOwnershipEvidence'; Required = $true; MinimumValue = 1; ActualValue = 1; Unit = 'owned item rows'; Passed = $true; EvidenceSource = 'ScanExport:items.csv'; EvidenceDetail = 'Synthetic acceptance proof'; Description = 'Ownership evidence' },
                [pscustomobject]@{ Name = 'EnterpriseDeepExplicitAceFindings'; Required = $true; MinimumValue = 1; ActualValue = 1; Unit = 'deep explicit ACE findings'; Passed = $true; EvidenceSource = 'ScanExport:findings.csv'; EvidenceDetail = 'Synthetic acceptance proof'; Description = 'Deep explicit ACE findings' },
                [pscustomobject]@{ Name = 'EnterpriseBrokenInheritanceFindings'; Required = $true; MinimumValue = 1; ActualValue = 1; Unit = 'broken inheritance findings'; Passed = $true; EvidenceSource = 'ScanExport:findings.csv'; EvidenceDetail = 'Synthetic acceptance proof'; Description = 'Broken inheritance findings' },
                [pscustomobject]@{ Name = 'EnterpriseConflictFindings'; Required = $true; MinimumValue = 1; ActualValue = 1; Unit = 'conflict rows'; Passed = $true; EvidenceSource = 'ScanExport:conflicts.csv'; EvidenceDetail = 'Synthetic acceptance proof'; Description = 'Conflicts' },
                [pscustomobject]@{ Name = 'EnterpriseCollectionErrors'; Required = $true; MinimumValue = 0; ActualValue = 0; Unit = 'collection error rows'; Passed = $true; EvidenceSource = 'ScanExport:collection_errors.csv'; EvidenceDetail = 'Synthetic acceptance proof'; Description = 'Collection errors' },
                [pscustomobject]@{ Name = 'EnterpriseEmployeeIdentifierCoverage'; Required = $true; MinimumValue = 1; ActualValue = 1; Unit = 'users with employee identifiers'; Passed = $true; EvidenceSource = 'ScanExport:identities.csv'; EvidenceDetail = 'Synthetic acceptance proof'; Description = 'Employee identifiers' },
                [pscustomobject]@{ Name = 'EnterpriseManagerChainCoverage'; Required = $true; MinimumValue = 1; ActualValue = 1; Unit = 'two-level manager chains'; Passed = $true; EvidenceSource = 'ScanExport:org_chains.csv'; EvidenceDetail = 'Synthetic acceptance proof'; Description = 'Manager chains' },
                [pscustomobject]@{ Name = 'EnterpriseUserObsCoverage'; Required = $true; MinimumValue = 1; ActualValue = 1; Unit = 'users with OBS'; Passed = $true; EvidenceSource = 'ScanExport:identities.csv'; EvidenceDetail = 'Synthetic acceptance proof'; Description = 'User OBS coverage' },
                [pscustomobject]@{ Name = 'EnterpriseGroupExpansion'; Required = $true; MinimumValue = 1; ActualValue = 1; Unit = 'group edges'; Passed = $true; EvidenceSource = 'ScanExport:group_edges.csv'; EvidenceDetail = 'Synthetic acceptance proof'; Description = 'Group expansion' },
                [pscustomobject]@{ Name = 'EnterprisePermissionGroupObsCoverage'; Required = $true; MinimumValue = 1; ActualValue = 1; Unit = 'groups with OBS'; Passed = $true; EvidenceSource = 'ScanExport:identities.csv'; EvidenceDetail = 'Synthetic acceptance proof'; Description = 'Permission group OBS coverage' }
            ) | Export-Csv -LiteralPath (Join-Path $runRoot 'lab-validation-criteria.csv') -NoTypeInformation -Encoding UTF8
            [pscustomobject]@{
                IsValid = $true
                FallbackCount = 0
                FallbackCriteria = @()
                FallbackEvidenceSources = @()
            } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $runRoot 'live-evidence.json') -Encoding UTF8
            @(
                [pscustomobject]@{ Name = 'EnterpriseUserPopulation'; Required = $true; Passed = $true; EvidenceStatus = 'LiveEvidence'; EvidenceSource = 'ActiveDirectory'; ActualValue = '1'; MinimumValue = '1'; EvidenceDetail = 'Synthetic acceptance proof'; NextAction = 'No action needed for this criterion.' },
                [pscustomobject]@{ Name = 'EnterpriseGroupPopulation'; Required = $true; Passed = $true; EvidenceStatus = 'LiveEvidence'; EvidenceSource = 'ActiveDirectory'; ActualValue = '1'; MinimumValue = '1'; EvidenceDetail = 'Synthetic acceptance proof'; NextAction = 'No action needed for this criterion.' },
                [pscustomobject]@{ Name = 'EnterpriseSharePopulation'; Required = $true; Passed = $true; EvidenceStatus = 'LiveEvidence'; EvidenceSource = 'ScanExport:shares.csv'; ActualValue = '1'; MinimumValue = '1'; EvidenceDetail = 'Synthetic acceptance proof'; NextAction = 'No action needed for this criterion.' },
                [pscustomobject]@{ Name = 'EnterpriseRealFiles'; Required = $true; Passed = $true; EvidenceStatus = 'LiveEvidence'; EvidenceSource = 'ScanExport:items.csv'; ActualValue = '1'; MinimumValue = '1'; EvidenceDetail = 'Synthetic acceptance proof'; NextAction = 'No action needed for this criterion.' },
                [pscustomobject]@{ Name = 'EnterpriseDeepPaths'; Required = $true; Passed = $true; EvidenceStatus = 'LiveEvidence'; EvidenceSource = 'ScanExport:items.csv'; ActualValue = '1'; MinimumValue = '1'; EvidenceDetail = 'Synthetic acceptance proof'; NextAction = 'No action needed for this criterion.' },
                [pscustomobject]@{ Name = 'EnterpriseLongPathPolicy'; Required = $true; Passed = $true; EvidenceStatus = 'LiveEvidence'; EvidenceSource = 'ScanExport:findings.csv'; ActualValue = '1'; MinimumValue = '1'; EvidenceDetail = 'Synthetic acceptance proof'; NextAction = 'No action needed for this criterion.' },
                [pscustomobject]@{ Name = 'EnterpriseDiskBudget'; Required = $true; Passed = $true; EvidenceStatus = 'LiveEvidence'; EvidenceSource = 'FileSystem'; ActualValue = '1'; MinimumValue = '1'; EvidenceDetail = 'Synthetic acceptance proof'; NextAction = 'No action needed for this criterion.' },
                [pscustomobject]@{ Name = 'EnterpriseSharePermissions'; Required = $true; Passed = $true; EvidenceStatus = 'LiveEvidence'; EvidenceSource = 'ScanExport:share_permissions.csv'; ActualValue = '1'; MinimumValue = '1'; EvidenceDetail = 'Synthetic acceptance proof'; NextAction = 'No action needed for this criterion.' },
                [pscustomobject]@{ Name = 'EnterpriseAclEntries'; Required = $true; Passed = $true; EvidenceStatus = 'LiveEvidence'; EvidenceSource = 'ScanExport:acl_entries.csv'; ActualValue = '1'; MinimumValue = '1'; EvidenceDetail = 'Synthetic acceptance proof'; NextAction = 'No action needed for this criterion.' },
                [pscustomobject]@{ Name = 'EnterpriseFileAclEntries'; Required = $true; Passed = $true; EvidenceStatus = 'LiveEvidence'; EvidenceSource = 'ScanExport:acl_entries.csv'; ActualValue = '1'; MinimumValue = '1'; EvidenceDetail = 'Synthetic acceptance proof'; NextAction = 'No action needed for this criterion.' },
                [pscustomobject]@{ Name = 'EnterpriseOwnershipEvidence'; Required = $true; Passed = $true; EvidenceStatus = 'LiveEvidence'; EvidenceSource = 'ScanExport:items.csv'; ActualValue = '1'; MinimumValue = '1'; EvidenceDetail = 'Synthetic acceptance proof'; NextAction = 'No action needed for this criterion.' },
                [pscustomobject]@{ Name = 'EnterpriseDeepExplicitAceFindings'; Required = $true; Passed = $true; EvidenceStatus = 'LiveEvidence'; EvidenceSource = 'ScanExport:findings.csv'; ActualValue = '1'; MinimumValue = '1'; EvidenceDetail = 'Synthetic acceptance proof'; NextAction = 'No action needed for this criterion.' },
                [pscustomobject]@{ Name = 'EnterpriseBrokenInheritanceFindings'; Required = $true; Passed = $true; EvidenceStatus = 'LiveEvidence'; EvidenceSource = 'ScanExport:findings.csv'; ActualValue = '1'; MinimumValue = '1'; EvidenceDetail = 'Synthetic acceptance proof'; NextAction = 'No action needed for this criterion.' },
                [pscustomobject]@{ Name = 'EnterpriseConflictFindings'; Required = $true; Passed = $true; EvidenceStatus = 'LiveEvidence'; EvidenceSource = 'ScanExport:conflicts.csv'; ActualValue = '1'; MinimumValue = '1'; EvidenceDetail = 'Synthetic acceptance proof'; NextAction = 'No action needed for this criterion.' },
                [pscustomobject]@{ Name = 'EnterpriseCollectionErrors'; Required = $true; Passed = $true; EvidenceStatus = 'LiveEvidence'; EvidenceSource = 'ScanExport:collection_errors.csv'; ActualValue = '0'; MinimumValue = '0'; EvidenceDetail = 'Synthetic acceptance proof'; NextAction = 'No action needed for this criterion.' },
                [pscustomobject]@{ Name = 'EnterpriseEmployeeIdentifierCoverage'; Required = $true; Passed = $true; EvidenceStatus = 'LiveEvidence'; EvidenceSource = 'ScanExport:identities.csv'; ActualValue = '1'; MinimumValue = '1'; EvidenceDetail = 'Synthetic acceptance proof'; NextAction = 'No action needed for this criterion.' },
                [pscustomobject]@{ Name = 'EnterpriseManagerChainCoverage'; Required = $true; Passed = $true; EvidenceStatus = 'LiveEvidence'; EvidenceSource = 'ScanExport:org_chains.csv'; ActualValue = '1'; MinimumValue = '1'; EvidenceDetail = 'Synthetic acceptance proof'; NextAction = 'No action needed for this criterion.' },
                [pscustomobject]@{ Name = 'EnterpriseUserObsCoverage'; Required = $true; Passed = $true; EvidenceStatus = 'LiveEvidence'; EvidenceSource = 'ScanExport:identities.csv'; ActualValue = '1'; MinimumValue = '1'; EvidenceDetail = 'Synthetic acceptance proof'; NextAction = 'No action needed for this criterion.' },
                [pscustomobject]@{ Name = 'EnterpriseGroupExpansion'; Required = $true; Passed = $true; EvidenceStatus = 'LiveEvidence'; EvidenceSource = 'ScanExport:group_edges.csv'; ActualValue = '1'; MinimumValue = '1'; EvidenceDetail = 'Synthetic acceptance proof'; NextAction = 'No action needed for this criterion.' },
                [pscustomobject]@{ Name = 'EnterprisePermissionGroupObsCoverage'; Required = $true; Passed = $true; EvidenceStatus = 'LiveEvidence'; EvidenceSource = 'ScanExport:identities.csv'; ActualValue = '1'; MinimumValue = '1'; EvidenceDetail = 'Synthetic acceptance proof'; NextAction = 'No action needed for this criterion.' }
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
            Assert-True (Test-Path -LiteralPath $issueSummaryScript) 'Validation issue summary script should exist.'
            Assert-True (Test-Path -LiteralPath $issueCommentScript) 'Validation issue comment generator script should exist.'
            Assert-True (Test-Path -LiteralPath $issueCommentPublisherScript) 'Validation issue comment publisher script should exist.'
            Assert-True (Test-Path -LiteralPath $closeoutChecklistScript) 'Validation closeout checklist script should exist.'
            Assert-True (Test-Path -LiteralPath $dashboardReviewScript) 'Dashboard review generator script should exist.'
            Assert-True (Test-Path -LiteralPath $collectorEnvironmentScript) 'Collector environment generator script should exist.'
            Assert-True (Test-Path -LiteralPath $dashboardReviewPath) 'Dashboard review generator should write a review artifact.'
            $dashboardReviewText = Get-Content -LiteralPath $dashboardReviewPath -Raw
            Assert-True ($dashboardReviewText -like '*Dashboard review status: Pass*') 'Dashboard review should pass for the synthetic report.'
            Assert-True ($dashboardReviewText -like '*Operator Live Review*') 'Dashboard review should include operator review guidance.'
            Assert-True ($dashboardReviewText -notlike "*$runRoot*") 'Dashboard review should not include raw run-root paths.'
            Assert-True (Test-Path -LiteralPath $collectorEnvironmentPath) 'Collector environment generator should write a JSON artifact.'
            $collectorEnvironment = Get-Content -LiteralPath $collectorEnvironmentPath -Raw | ConvertFrom-Json
            Assert-Equal ([string]$collectorEnvironment.ArtifactType) 'ShareSurferCollectorEnvironment' 'Collector environment should identify its schema.'
            Assert-True (@($collectorEnvironment.Commands).Count -ge 4) 'Collector environment should include command availability rows.'
            Assert-True (@($collectorEnvironment.Modules).Count -ge 2) 'Collector environment should include module availability rows.'
            $pendingBundleResult = & $acceptanceScript -RunRoot $runRoot -RequireLiveEvidence -AllowMissingBundledAcceptance -AllowMissingIssueComments
            Assert-True $pendingBundleResult.IsValid 'First acceptance pass should allow the bundled acceptance summary to be pending.'
            $pendingBundleResult | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $runRoot 'v1-acceptance.json') -Encoding UTF8
            $summaryBuildResult = & $acceptanceScript -RunRoot $runRoot -RequireLiveEvidence -AllowMissingBundledAcceptance -AllowMissingIssueComments -SummaryPath $acceptanceSummaryPath
            Assert-True $summaryBuildResult.IsValid 'Acceptance summary build should pass while the refreshed bundle is pending.'
            New-ShareSurferSupportBundle -ExportPath $exportPath -OutputPath $bundlePath -RedactionMode StableToken -RedactionSalt 'acceptance-test' -IncludeReport -RunRoot $runRoot | Out-Null
            $stagedIssueCommentResult = & $acceptanceScript -RunRoot $runRoot -RequireLiveEvidence -AllowMissingIssueComments
            Assert-True $stagedIssueCommentResult.IsValid 'Staged acceptance should allow issue-comment artifacts to be pending before the generator runs.'
            Assert-True ($stagedIssueCommentResult.Checks.Name -contains 'ValidationIssueComments') 'Staged acceptance should include raw issue-comment artifact checks.'
            Assert-True ($stagedIssueCommentResult.Checks.Name -contains 'BundledValidationIssueComments') 'Staged acceptance should include bundled issue-comment artifact checks.'

            $issueSummaryPath = Join-Path $runRoot 'issue-summary.md'
            $issueSummary = & $issueSummaryScript -RunRoot $runRoot -OutputPath $issueSummaryPath -PassThru
            $issueSummaryText = [string]($issueSummary -join "`n")
            Assert-True (Test-Path -LiteralPath $issueSummaryPath) 'Validation issue summary script should write Markdown when OutputPath is provided.'
            Assert-True ($issueSummaryText -like '*ShareSurfer live validation evidence summary*') 'Validation issue summary should include a recognizable title.'
            Assert-True ($issueSummaryText -like '*V1 acceptance valid:*True*') 'Validation issue summary should include acceptance status.'
            Assert-True ($issueSummaryText -like '*Fallback criteria count:*0*') 'Validation issue summary should include live-evidence fallback count.'
            Assert-True ($issueSummaryText -like '*Redaction leak count:*0*') 'Validation issue summary should include redaction leak count.'
            Assert-True ($issueSummaryText -like '*issue #1*') 'Validation issue summary should point to the remaining lab proof issue.'
            Assert-True ($issueSummaryText -like '*issue #6*') 'Validation issue summary should point to the remaining dashboard proof issue.'
            Assert-True ($issueSummaryText -notlike '*Synthetic acceptance proof*') 'Validation issue summary should not include raw evidence detail values.'
            Assert-True ($issueSummaryText -notlike '*RunRoot=C:\ShareSurfer\acceptance*') 'Validation issue summary should not include raw lab-run detail values.'
            $issueCommentManifest = & $issueCommentScript -RunRoot $runRoot -OutputDirectory $issueCommentDirectory -Repository 'jonathanweinberg/ShareSurfer' -PassThru
            Assert-Equal @($issueCommentManifest).Count 4 'Validation issue comment generator should write one comment body for each remaining proof issue.'
            Assert-True (Test-Path -LiteralPath (Join-Path $issueCommentDirectory 'issue-comment-manifest.csv')) 'Validation issue comments should include a manifest CSV.'
            Assert-True (Test-Path -LiteralPath (Join-Path $issueCommentDirectory 'post-commands.txt')) 'Validation issue comments should include body-file post commands.'
            foreach ($issueNumber in @(1, 3, 5, 6)) {
                Assert-True (@($issueCommentManifest | Where-Object { [int]$_.IssueNumber -eq $issueNumber }).Count -eq 1) ('Validation issue comments should include issue #{0}.' -f $issueNumber)
            }
            $issueOneCommentPath = Join-Path $issueCommentDirectory 'issue-1-lab-fixture-live-proof.md'
            $issueThreeCommentPath = Join-Path $issueCommentDirectory 'issue-3-scanner-live-proof.md'
            $issueFiveCommentPath = Join-Path $issueCommentDirectory 'issue-5-identity-group-live-proof.md'
            $issueSixCommentPath = Join-Path $issueCommentDirectory 'issue-6-dashboard-live-proof.md'
            foreach ($commentPath in @($issueOneCommentPath, $issueThreeCommentPath, $issueFiveCommentPath, $issueSixCommentPath)) {
                Assert-True (Test-Path -LiteralPath $commentPath) ('Validation issue comment file should exist: {0}' -f $commentPath)
                $commentText = Get-Content -LiteralPath $commentPath -Raw
                Assert-True ($commentText -like '*ShareSurfer live validation update for issue*') 'Validation issue comment should include a recognizable title.'
                Assert-True ($commentText -like '*Safe Sharing Note*') 'Validation issue comment should include safe-sharing wording.'
                Assert-True ($commentText -notlike '*Synthetic acceptance proof*') 'Validation issue comment should not include raw evidence detail values.'
                Assert-True ($commentText -notlike '*RunRoot=C:\ShareSurfer\acceptance*') 'Validation issue comment should not include raw lab-run detail values.'
            }
            $issueOneComment = Get-Content -LiteralPath $issueOneCommentPath -Raw
            $issueThreeComment = Get-Content -LiteralPath $issueThreeCommentPath -Raw
            $issueFiveComment = Get-Content -LiteralPath $issueFiveCommentPath -Raw
            $issueSixComment = Get-Content -LiteralPath $issueSixCommentPath -Raw
            Assert-True ($issueOneComment -like '*EnterpriseUserPopulation*') 'Issue #1 comment should summarize lab fixture population evidence.'
            Assert-True ($issueOneComment -like '*CollectorEnvironment*') 'Issue #1 comment should summarize collector environment evidence.'
            Assert-True ($issueThreeComment -like '*EnterpriseAclEntries*') 'Issue #3 comment should summarize scanner ACL evidence.'
            Assert-True ($issueThreeComment -like '*EnterpriseOwnershipEvidence*') 'Issue #3 comment should summarize scanner ownership evidence.'
            Assert-True ($issueThreeComment -like '*ScanManifestIncludeFiles*') 'Issue #3 comment should summarize scan manifest file-object evidence.'
            Assert-True ($issueFiveComment -like '*EnterpriseGroupExpansion*') 'Issue #5 comment should summarize group expansion evidence.'
            Assert-True ($issueSixComment -like '*OwnerReviewPackets*') 'Issue #6 comment should summarize dashboard and owner review evidence.'
            Assert-True ($issueSixComment -like '*DashboardReviewEvidence*') 'Issue #6 comment should summarize dashboard review evidence.'
            $postCommands = Get-Content -LiteralPath (Join-Path $issueCommentDirectory 'post-commands.txt') -Raw
            Assert-True ($postCommands -like '*gh issue comment 1 --repo jonathanweinberg/ShareSurfer --body-file*') 'Post commands should use the body-file issue comment pattern.'
            Assert-True ($postCommands -like '*issue-6-dashboard-live-proof.md*') 'Post commands should include the dashboard proof issue body file.'
            $publishPreview = @(& $issueCommentPublisherScript -RunRoot $runRoot -Repository 'jonathanweinberg/ShareSurfer')
            Assert-Equal $publishPreview.Count 4 'Publisher dry run should plan all generated issue comments without posting.'
            Assert-True (@($publishPreview | Where-Object { [int]$_.IssueNumber -eq 1 -and [string]$_.Status -eq 'DryRun' }).Count -eq 1) 'Publisher dry run should include issue #1.'
            Assert-True (@($publishPreview | Where-Object { [int]$_.IssueNumber -eq 6 -and [string]$_.Command -like '*--body-file*issue-6-dashboard-live-proof.md*' }).Count -eq 1) 'Publisher dry run should use body-file commands for issue #6.'
            Assert-True (@($publishPreview | Where-Object { [string]$_.PostedUrl -ne '' }).Count -eq 0) 'Publisher dry run should not post comments.'
            $publishPreviewPath = Join-Path $runRoot 'issue-comment-publish-preview.csv'
            $publishPreview | Export-Csv -LiteralPath $publishPreviewPath -NoTypeInformation -Encoding UTF8
            Assert-True (Test-Path -LiteralPath $publishPreviewPath) 'Publisher dry run should be capturable as validation evidence.'
            $closeoutChecklist = & $closeoutChecklistScript -RunRoot $runRoot -OutputPath $closeoutChecklistPath -PassThru
            $closeoutChecklistText = [string]($closeoutChecklist -join "`n")
            Assert-True (Test-Path -LiteralPath $closeoutChecklistPath) 'Closeout checklist script should write a Markdown checklist.'
            Assert-True ($closeoutChecklistText -like '*ShareSurfer live validation closeout checklist*') 'Closeout checklist should include a recognizable title.'
            Assert-True ($closeoutChecklistText -like '*Ready for proof review:*') 'Closeout checklist should include ready-for-proof-review status.'
            Assert-True ($closeoutChecklistText -like '*Scan manifest proves file-object scanning*') 'Closeout checklist should summarize scan manifest file-object evidence.'
            Assert-True ($closeoutChecklistText -like '*Collector environment evidence exists*') 'Closeout checklist should summarize collector environment evidence.'
            Assert-True ($closeoutChecklistText -like '*Dashboard review evidence exists*') 'Closeout checklist should summarize dashboard review evidence.'
            Assert-True ($closeoutChecklistText -like '*Lab population criteria prove the enterprise user, group, and share counts*') 'Closeout checklist should summarize lab population proof gates.'
            Assert-True ($closeoutChecklistText -like '*Lab fixture criteria prove real files, deep paths, long-path policy fixtures*') 'Closeout checklist should summarize lab fixture proof gates.'
            Assert-True ($closeoutChecklistText -like '*Scanner permission criteria prove share permissions, folder ACLs, and file ACL entries*') 'Closeout checklist should summarize scanner permission proof gates.'
            Assert-True ($closeoutChecklistText -like '*Scanner finding criteria prove ownership evidence, deep explicit ACE findings*') 'Closeout checklist should summarize scanner finding proof gates.'
            Assert-True ($closeoutChecklistText -like '*Scanner conflict criteria prove share-vs-NTFS conflicts and collection-error evidence*') 'Closeout checklist should summarize scanner conflict proof gates.'
            Assert-True ($closeoutChecklistText -like '*Identity enrichment criteria prove employee identifiers*') 'Closeout checklist should summarize identity enrichment proof gates.'
            Assert-True ($closeoutChecklistText -like '*Security group criteria prove recursive group expansion*') 'Closeout checklist should summarize security group expansion proof gates.'
            Assert-True ($closeoutChecklistText -like '*Issue comment publish preview is dry-run only*') 'Closeout checklist should summarize publish preview readiness.'
            Assert-True ($closeoutChecklistText -notlike '*Synthetic acceptance proof*') 'Closeout checklist should not include raw evidence detail values.'
            Assert-True ($closeoutChecklistText -notlike '*RunRoot=C:\ShareSurfer\acceptance*') 'Closeout checklist should not include raw lab-run detail values.'
            $publishFilteredPreview = @(& $issueCommentPublisherScript -RunRoot $runRoot -Repository 'jonathanweinberg/ShareSurfer' -IssueNumber 3)
            Assert-Equal $publishFilteredPreview.Count 1 'Publisher should filter to a requested issue number.'
            Assert-Equal ([int]$publishFilteredPreview[0].IssueNumber) 3 'Publisher issue filter should select issue #3.'
            $publisherScriptText = Get-Content -LiteralPath $issueCommentPublisherScript -Raw
            Assert-True ($publisherScriptText -like '*gh issue comment*--body-file*') 'Publisher should post issue comments with the body-file pattern.'
            Assert-True ($publisherScriptText -like '*gh api*issues/comments*') 'Publisher should read back posted comments by comment id.'
            Assert-True ($publisherScriptText -like '*SkipReadyCheck*') 'Publisher should expose an explicit override for the closeout readiness guard.'
            $readyGuardMessage = ''
            $goodCloseoutChecklistText = Get-Content -LiteralPath $closeoutChecklistPath -Raw
            Set-Content -LiteralPath $closeoutChecklistPath -Value ($goodCloseoutChecklistText -replace 'Ready for proof review: `True`', 'Ready for proof review: `False`') -Encoding UTF8
            try {
                & $issueCommentPublisherScript -RunRoot $runRoot -Repository 'jonathanweinberg/ShareSurfer' -IssueNumber 3 -Post | Out-Null
            }
            catch {
                $readyGuardMessage = $_.Exception.Message
            }
            Assert-True ($readyGuardMessage -like '*not ready for proof review*') 'Publisher should refuse to post from a run folder when the closeout checklist is not ready.'
            Set-Content -LiteralPath $closeoutChecklistPath -Value $goodCloseoutChecklistText -Encoding UTF8
            New-ShareSurferSupportBundle -ExportPath $exportPath -OutputPath $bundlePath -RedactionMode StableToken -RedactionSalt 'acceptance-test' -IncludeReport -RunRoot $runRoot | Out-Null
            $result = & $acceptanceScript -RunRoot $runRoot -RequireLiveEvidence -SummaryPath $acceptanceSummaryPath
            Assert-True $result.IsValid 'Complete synthetic run package should pass acceptance checks.'
            Assert-True (Test-Path -LiteralPath $acceptanceSummaryPath) 'Acceptance checker should write the concise acceptance summary when requested.'
            $acceptanceSummary = Get-Content -LiteralPath $acceptanceSummaryPath -Raw | ConvertFrom-Json
            $acceptanceSummaryRaw = Get-Content -LiteralPath $acceptanceSummaryPath -Raw
            Assert-Equal ([string]$acceptanceSummary.SummaryType) 'ShareSurferV1AcceptanceSummary' 'Acceptance summary should identify its schema.'
            Assert-Equal ([string]$acceptanceSummary.IsValid) 'True' 'Acceptance summary should carry the overall pass/fail status.'
            Assert-Equal ([int]$acceptanceSummary.FailedCheckCount) 0 'Acceptance summary should include failed check count.'
            Assert-True (@($acceptanceSummary.Checks).Count -ge 1) 'Acceptance summary should include check names and pass/fail states.'
            Assert-True ($acceptanceSummaryRaw -notlike '*Synthetic acceptance proof*') 'Acceptance summary should omit raw check detail values.'
            Assert-True ($acceptanceSummaryRaw -notlike '*RunRoot=C:\ShareSurfer\acceptance*') 'Acceptance summary should omit raw lab-run detail values.'
            Assert-True ($result.Checks.Name -contains 'NormalizedCsvExport') 'Acceptance checks should include normalized CSV validation.'
            Assert-True ($result.Checks.Name -contains 'ScanManifestIncludeFiles') 'Acceptance checks should include scan manifest file-object evidence.'
            Assert-True ($result.Checks.Name -contains 'OwnerReviewPackets') 'Acceptance checks should include owner review packet evidence.'
            Assert-True ($result.Checks.Name -contains 'OfflineReport') 'Acceptance checks should include offline report output.'
            Assert-True ($result.Checks.Name -contains 'DashboardReviewEvidence') 'Acceptance checks should include dashboard review evidence.'
            Assert-True ($result.Checks.Name -contains 'RawEventLog') 'Acceptance checks should include raw JSONL event log output.'
            Assert-True ($result.Checks.Name -contains 'RedactedSupportBundle') 'Acceptance checks should include redacted support bundle output.'
            Assert-True ($result.Checks.Name -contains 'LabRunSupportBundleEvidence') 'Acceptance checks should include redacted lab-run support bundle evidence.'
            Assert-True ($result.Checks.Name -contains 'ValidationIssueComments') 'Acceptance checks should include raw validation issue-comment artifacts.'
            Assert-True ($result.Checks.Name -contains 'ValidationIssueCommentPublishPreview') 'Acceptance checks should include raw validation issue-comment publish preview evidence.'
            Assert-True ($result.Checks.Name -contains 'BundledValidationIssueComments') 'Acceptance checks should include bundled validation issue-comment artifacts.'
            Assert-True ($result.Checks.Name -contains 'ValidationCloseoutChecklist') 'Acceptance checks should include the raw validation closeout checklist.'
            Assert-True ($result.Checks.Name -contains 'BundledValidationCloseoutChecklist') 'Acceptance checks should include the bundled validation closeout checklist.'
            Assert-True ($result.Checks.Name -contains 'LabPreflight') 'Acceptance checks should include lab preflight readiness evidence.'
            Assert-True ($result.Checks.Name -contains 'CollectorEnvironment') 'Acceptance checks should include collector environment evidence.'
            Assert-True ($result.Checks.Name -contains 'LiveEvidenceGate') 'Acceptance checks should include live evidence gate output.'
            Assert-True ($result.Checks.Name -contains 'LiveEvidenceReview') 'Acceptance checks should include the operator live evidence review CSV.'
            $bundleFilesAfterIssueSummary = @(Import-Csv -LiteralPath (Join-Path $bundlePath 'support_bundle_files.csv'))
            Assert-True ($bundleFilesAfterIssueSummary.FileName -contains 'issue_summary.md') 'Final lab support bundle should include the public-safe issue summary.'
            Assert-True ($bundleFilesAfterIssueSummary.FileName -contains 'dashboard_review.md') 'Final lab support bundle should include the dashboard review artifact.'
            Assert-True ($bundleFilesAfterIssueSummary.FileName -contains 'collector_environment.json') 'Final lab support bundle should include redacted collector environment evidence.'
            $bundledIssueSummaryPath = Join-Path $bundlePath 'issue_summary.md'
            $bundledIssueSummary = Get-Content -LiteralPath $bundledIssueSummaryPath -Raw
            Assert-True ($bundledIssueSummary -like '*ShareSurfer live validation evidence summary*') 'Bundled issue summary should keep the public-safe validation title.'
            Assert-True ($bundledIssueSummary -notlike '*Synthetic acceptance proof*') 'Bundled issue summary should not include raw evidence detail values.'
            Assert-True ($bundledIssueSummary -notlike '*RunRoot=C:\ShareSurfer\acceptance*') 'Bundled issue summary should not include raw lab-run detail values.'
            $labRunDiagnosticsWithIssueSummary = Get-Content -LiteralPath (Join-Path $bundlePath 'lab_run_diagnostics.json') -Raw | ConvertFrom-Json
            Assert-Equal ([string]$labRunDiagnosticsWithIssueSummary.CollectorEnvironment.Included) 'True' 'Lab-run diagnostics should record bundled collector environment inclusion.'
            Assert-Equal ([string]$labRunDiagnosticsWithIssueSummary.DashboardReview.Included) 'True' 'Lab-run diagnostics should record bundled dashboard review inclusion.'
            Assert-Equal ([string]$labRunDiagnosticsWithIssueSummary.DashboardReview.FileName) 'dashboard_review.md' 'Lab-run diagnostics should name the bundled dashboard review file.'
            Assert-Equal ([string]$labRunDiagnosticsWithIssueSummary.IssueSummary.Included) 'True' 'Lab-run diagnostics should record bundled issue summary inclusion.'
            Assert-Equal ([string]$labRunDiagnosticsWithIssueSummary.IssueSummary.FileName) 'issue_summary.md' 'Lab-run diagnostics should name the bundled issue summary file.'

            $scanManifestPath = Join-Path $exportPath 'scan_manifest.csv'
            $goodScanManifest = Get-Content -LiteralPath $scanManifestPath -Raw
            $badScanManifestRows = @(Import-Csv -LiteralPath $scanManifestPath)
            $badScanManifestRows[0].IncludeFiles = 'False'
            $badScanManifestRows | Export-Csv -LiteralPath $scanManifestPath -NoTypeInformation -Encoding UTF8
            $badScanManifestResult = & $acceptanceScript -RunRoot $runRoot -RequireLiveEvidence
            Assert-True (-not $badScanManifestResult.IsValid) 'Acceptance checker should fail when live evidence requires file scans but the manifest has IncludeFiles=False.'
            Assert-True (@($badScanManifestResult.Checks | Where-Object { $_.Name -eq 'ScanManifestIncludeFiles' -and -not $_.Passed }).Count -gt 0) 'Acceptance checker should report scan manifest IncludeFiles failures.'
            Set-Content -LiteralPath $scanManifestPath -Value $goodScanManifest -Encoding UTF8

            Set-Content -LiteralPath $reportPath -Value '<html><body>not a ShareSurfer dashboard</body></html>' -Encoding UTF8
            $badReportResult = & $acceptanceScript -RunRoot $runRoot -RequireLiveEvidence
            Assert-True (-not $badReportResult.IsValid) 'Acceptance checker should fail when the offline report is present but missing dashboard content.'
            Assert-True (@($badReportResult.Checks | Where-Object { $_.Name -eq 'OfflineReport' -and -not $_.Passed }).Count -gt 0) 'Acceptance checker should report offline report content failures.'
            ConvertTo-ShareSurferReport -ExportPath $exportPath -OutputPath $reportPath | Out-Null
            & $dashboardReviewScript -RunRoot $runRoot -ExportPath $exportPath -ReportPath $reportPath -OutputPath $dashboardReviewPath | Out-Null

            Set-Content -LiteralPath $dashboardReviewPath -Value '# ShareSurfer Dashboard Review' -Encoding UTF8
            $badDashboardReviewResult = & $acceptanceScript -RunRoot $runRoot -RequireLiveEvidence
            Assert-True (-not $badDashboardReviewResult.IsValid) 'Acceptance checker should fail when dashboard review evidence is incomplete.'
            Assert-True (@($badDashboardReviewResult.Checks | Where-Object { $_.Name -eq 'DashboardReviewEvidence' -and -not $_.Passed }).Count -gt 0) 'Acceptance checker should report dashboard review evidence failures.'
            & $dashboardReviewScript -RunRoot $runRoot -ExportPath $exportPath -ReportPath $reportPath -OutputPath $dashboardReviewPath | Out-Null

            $bundleManifestPath = Join-Path $bundlePath 'support_bundle_manifest.csv'
            $bundleFilesPath = Join-Path $bundlePath 'support_bundle_files.csv'
            $bundleFiles = @(Import-Csv -LiteralPath $bundleFilesPath)
            Assert-True ($bundleFiles.FileName -contains 'v1_acceptance.json') 'Final lab support bundle should include the redacted acceptance summary.'
            Assert-True ($bundleFiles.FileName -contains 'v1_acceptance_summary.json') 'Final lab support bundle should include the concise acceptance summary.'
            Assert-True ($bundleFiles.FileName -contains 'collector_environment.json') 'Final lab support bundle should include the redacted collector environment artifact.'
            Assert-True ($bundleFiles.FileName -contains 'lab_run_events.jsonl') 'Final lab support bundle should include the redacted lab-run event log.'
            Assert-True ($bundleFiles.FileName -contains 'dashboard_review.md') 'Final lab support bundle should include the dashboard review artifact.'
            Assert-True ($bundleFiles.FileName -contains 'issue_summary.md') 'Final lab support bundle should include the public-safe issue summary.'
            Assert-True ($bundleFiles.FileName -contains 'validation_closeout_checklist.md') 'Final lab support bundle should include the public-safe closeout checklist.'
            Assert-True ($bundleFiles.FileName -contains 'issue_comments/publish_preview.csv') 'Final lab support bundle should include the sanitized issue-comment publish preview.'
            $bundledCloseoutChecklist = Get-Content -LiteralPath (Join-Path $bundlePath 'validation_closeout_checklist.md') -Raw
            Assert-True ($bundledCloseoutChecklist -like '*ShareSurfer live validation closeout checklist*') 'Bundled closeout checklist should preserve the public-safe title.'
            Assert-True ($bundledCloseoutChecklist -like '*Scan manifest proves file-object scanning*') 'Bundled closeout checklist should preserve scan manifest file-object evidence.'
            Assert-True ($bundledCloseoutChecklist -notlike "*$runRoot*") 'Bundled closeout checklist must not contain raw run-root paths.'
            $bundledPublishPreview = Get-Content -LiteralPath (Join-Path $bundlePath 'issue_comments/publish_preview.csv') -Raw
            $bundledPublishPreviewRows = @(Import-Csv -LiteralPath (Join-Path $bundlePath 'issue_comments/publish_preview.csv'))
            Assert-True ($bundledPublishPreview -notlike "*$runRoot*") 'Bundled issue-comment publish preview must not contain raw run-root paths.'
            Assert-True (@($bundledPublishPreviewRows | Where-Object { [string]$_.BodyFile -eq 'issue_comments/issue-1-lab-fixture-live-proof.md' }).Count -eq 1) 'Bundled issue-comment publish preview should use relative body-file paths.'
            $bundledAcceptanceSummary = Get-Content -LiteralPath (Join-Path $bundlePath 'v1_acceptance_summary.json') -Raw
            Assert-True ($bundledAcceptanceSummary -notlike '*Synthetic acceptance proof*') 'Bundled acceptance summary should not include raw evidence detail values.'
            $labRunDiagnostics = Get-Content -LiteralPath (Join-Path $bundlePath 'lab_run_diagnostics.json') -Raw | ConvertFrom-Json
            Assert-Equal ([string]$labRunDiagnostics.AcceptanceSummary.IsValid) 'True' 'Lab-run diagnostics should summarize the bundled acceptance summary.'
            Assert-Equal ([string]$labRunDiagnostics.CollectorEnvironment.Included) 'True' 'Lab-run diagnostics should summarize collector environment evidence.'
            Assert-Equal ([string]$labRunDiagnostics.DashboardReview.Included) 'True' 'Lab-run diagnostics should summarize dashboard review evidence.'
            Assert-Equal ([string]$labRunDiagnostics.IssueSummary.Included) 'True' 'Lab-run diagnostics should summarize the bundled issue summary.'
            Assert-Equal ([string]$labRunDiagnostics.CloseoutChecklist.Included) 'True' 'Lab-run diagnostics should summarize the bundled closeout checklist.'
            Assert-Equal ([string]$labRunDiagnostics.CloseoutChecklist.FileName) 'validation_closeout_checklist.md' 'Lab-run diagnostics should name the bundled closeout checklist.'
            Assert-Equal ([string]$labRunDiagnostics.IssueComments.PublishPreviewIncluded) 'True' 'Lab-run diagnostics should summarize the issue-comment publish preview.'
            Assert-Equal ([int]$labRunDiagnostics.IssueComments.PublishPreviewRowCount) 4 'Lab-run diagnostics should count issue-comment publish preview rows.'
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

            $bundledIssueCommentsPath = Join-Path $bundlePath 'issue_comments'
            Remove-Item -LiteralPath $bundledIssueCommentsPath -Recurse -Force
            $badBundledIssueCommentResult = & $acceptanceScript -RunRoot $runRoot -RequireLiveEvidence
            Assert-True (-not $badBundledIssueCommentResult.IsValid) 'Acceptance checker should fail when bundled issue-comment artifacts are missing.'
            Assert-True (@($badBundledIssueCommentResult.Checks | Where-Object { $_.Name -eq 'BundledValidationIssueComments' -and -not $_.Passed }).Count -gt 0) 'Acceptance checker should report missing bundled issue-comment artifacts.'
            New-ShareSurferSupportBundle -ExportPath $exportPath -OutputPath $bundlePath -RedactionMode StableToken -RedactionSalt 'acceptance-test' -IncludeReport -RunRoot $runRoot | Out-Null

            Remove-Item -LiteralPath (Join-Path $issueCommentDirectory 'issue-6-dashboard-live-proof.md') -Force
            $badRawIssueCommentResult = & $acceptanceScript -RunRoot $runRoot -RequireLiveEvidence
            Assert-True (-not $badRawIssueCommentResult.IsValid) 'Acceptance checker should fail when raw issue-comment artifacts are missing.'
            Assert-True (@($badRawIssueCommentResult.Checks | Where-Object { $_.Name -eq 'ValidationIssueComments' -and -not $_.Passed }).Count -gt 0) 'Acceptance checker should report missing raw issue-comment artifacts.'
            & $issueCommentScript -RunRoot $runRoot -OutputDirectory $issueCommentDirectory -Repository 'jonathanweinberg/ShareSurfer' | Out-Null
            & $issueCommentPublisherScript -RunRoot $runRoot -Repository 'jonathanweinberg/ShareSurfer' | Export-Csv -LiteralPath $publishPreviewPath -NoTypeInformation -Encoding UTF8
            & $closeoutChecklistScript -RunRoot $runRoot -OutputPath $closeoutChecklistPath | Out-Null
            New-ShareSurferSupportBundle -ExportPath $exportPath -OutputPath $bundlePath -RedactionMode StableToken -RedactionSalt 'acceptance-test' -IncludeReport -RunRoot $runRoot | Out-Null

            Remove-Item -LiteralPath $publishPreviewPath -Force
            $badPublishPreviewResult = & $acceptanceScript -RunRoot $runRoot -RequireLiveEvidence
            Assert-True (-not $badPublishPreviewResult.IsValid) 'Acceptance checker should fail when raw issue-comment publish preview evidence is missing.'
            Assert-True (@($badPublishPreviewResult.Checks | Where-Object { $_.Name -eq 'ValidationIssueCommentPublishPreview' -and -not $_.Passed }).Count -gt 0) 'Acceptance checker should report missing raw issue-comment publish preview evidence.'
            & $issueCommentPublisherScript -RunRoot $runRoot -Repository 'jonathanweinberg/ShareSurfer' | Export-Csv -LiteralPath $publishPreviewPath -NoTypeInformation -Encoding UTF8
            & $closeoutChecklistScript -RunRoot $runRoot -OutputPath $closeoutChecklistPath | Out-Null
            New-ShareSurferSupportBundle -ExportPath $exportPath -OutputPath $bundlePath -RedactionMode StableToken -RedactionSalt 'acceptance-test' -IncludeReport -RunRoot $runRoot | Out-Null

            Remove-Item -LiteralPath $closeoutChecklistPath -Force
            $badCloseoutChecklistResult = & $acceptanceScript -RunRoot $runRoot -RequireLiveEvidence
            Assert-True (-not $badCloseoutChecklistResult.IsValid) 'Acceptance checker should fail when the raw closeout checklist is missing.'
            Assert-True (@($badCloseoutChecklistResult.Checks | Where-Object { $_.Name -eq 'ValidationCloseoutChecklist' -and -not $_.Passed }).Count -gt 0) 'Acceptance checker should report missing raw closeout checklist evidence.'
            & $closeoutChecklistScript -RunRoot $runRoot -OutputPath $closeoutChecklistPath | Out-Null
            New-ShareSurferSupportBundle -ExportPath $exportPath -OutputPath $bundlePath -RedactionMode StableToken -RedactionSalt 'acceptance-test' -IncludeReport -RunRoot $runRoot | Out-Null

            Remove-Item -LiteralPath (Join-Path $bundlePath 'scan_events.jsonl') -Force
            $failedResult = & $acceptanceScript -RunRoot $runRoot -RequireLiveEvidence
            Assert-True (-not $failedResult.IsValid) 'Acceptance checker should fail when a required support bundle artifact is missing.'
            Assert-True (@($failedResult.Checks | Where-Object { $_.Name -eq 'RedactedSupportBundle' -and -not $_.Passed }).Count -gt 0) 'Acceptance checker should identify missing redacted support bundle evidence.'

            $labValidationScript = Get-Content -LiteralPath (Join-Path $repoRoot 'scripts/Invoke-ShareSurferLabValidation.ps1') -Raw
            Assert-True ($labValidationScript -like '*Test-ShareSurferV1Acceptance.ps1*') 'Lab validation should run the V1 acceptance checker automatically.'
            Assert-True ($labValidationScript -like '*-AllowMissingBundledAcceptance*') 'Lab validation should allow bundled acceptance to be pending only for the first acceptance pass.'
            Assert-True ($labValidationScript -like '*-AllowMissingIssueComments*') 'Lab validation should allow issue-comment evidence to be pending only for staged acceptance passes.'
            Assert-True ($labValidationScript -like '*$finishedPackageAcceptance = & $acceptanceScriptPath*') 'Lab validation should verify the finished bundle after strict acceptance is bundled.'
            Assert-True ($labValidationScript -like '*PreflightOnly*') 'Lab validation should expose a non-mutating preflight-only mode.'
            Assert-True ($labValidationScript -like '*if ($PreflightOnly)*') 'Lab validation should return after preflight artifacts when preflight-only mode is used.'
            Assert-True ($labValidationScript -like '*PreflightPassed*') 'Lab validation preflight-only output should report preflight status.'
            Assert-True ($labValidationScript -like '*lab-run-events.jsonl*') 'Lab validation should write a raw lab-run event log.'
            Assert-True ($labValidationScript -like '*Add-ShareSurferLabRunEvent*') 'Lab validation should record phase events for run diagnostics.'
            Assert-True ($labValidationScript -like '*LabRunEventPath*') 'Lab validation output should include the lab-run event artifact path.'
            Assert-True ($labValidationScript -like '*collector-environment.json*') 'Lab validation should write collector environment evidence.'
            Assert-True ($labValidationScript -like '*New-ShareSurferCollectorEnvironment.ps1*') 'Lab validation should call the collector environment generator automatically.'
            Assert-True ($labValidationScript -like '*CollectorEnvironmentPath*') 'Lab validation output should include the collector environment artifact path.'
            Assert-True ($labValidationScript -like '*lab-preflight.csv*') 'Lab validation should write a preflight readiness CSV.'
            Assert-True ($labValidationScript -like '*PreflightPath*') 'Lab validation output should include the preflight artifact path.'
            Assert-True ($labValidationScript -like '*v1-acceptance.json*') 'Lab validation should write an acceptance result artifact.'
            Assert-True ($labValidationScript -like '*AcceptancePath*') 'Lab validation output should include the acceptance artifact path.'
            Assert-True ($labValidationScript -like '*v1-acceptance-summary.json*') 'Lab validation should write a concise acceptance summary artifact.'
            Assert-True ($labValidationScript -like '*AcceptanceSummaryPath*') 'Lab validation output should include the acceptance summary artifact path.'
            Assert-True ($labValidationScript -like '*-SummaryPath $acceptanceSummaryPath*') 'Lab validation should write the summary before refreshing the final support bundle.'
            Assert-True ($labValidationScript -like '*dashboard-review.md*') 'Lab validation should write dashboard review evidence.'
            Assert-True ($labValidationScript -like '*New-ShareSurferDashboardReview.ps1*') 'Lab validation should call the dashboard review generator automatically.'
            Assert-True ($labValidationScript -like '*DashboardReviewPath*') 'Lab validation output should include the dashboard review artifact path.'
            Assert-True ($labValidationScript -like '*issue-summary.md*') 'Lab validation should write a public-safe issue summary artifact.'
            Assert-True ($labValidationScript -like '*New-ShareSurferValidationIssueSummary.ps1*') 'Lab validation should call the validation issue summary generator automatically.'
            Assert-True ($labValidationScript -like '*IssueSummaryPath*') 'Lab validation output should include the issue summary artifact path.'
            Assert-True ($labValidationScript -like '*IssueSummary*') 'Lab validation should record issue summary generation events.'
            Assert-True ($labValidationScript -like '*New-ShareSurferValidationIssueComments.ps1*') 'Lab validation should call the validation issue comment generator automatically.'
            Assert-True ($labValidationScript -like '*IssueCommentDirectory*') 'Lab validation output should include the issue comment artifact directory.'
            Assert-True ($labValidationScript -like '*IssueComments*') 'Lab validation should record issue comment generation events.'
            Assert-True ($labValidationScript -like '*Publish-ShareSurferValidationIssueComments.ps1*') 'Lab validation should call the validation issue comment publisher in dry-run preview mode.'
            Assert-True ($labValidationScript -like '*issue-comment-publish-preview.csv*') 'Lab validation should write the issue-comment publish preview artifact.'
            Assert-True ($labValidationScript -like '*IssueCommentPublishPreviewPath*') 'Lab validation output should include the issue-comment publish preview artifact path.'
            Assert-True ($labValidationScript -like '*New-ShareSurferValidationCloseoutChecklist.ps1*') 'Lab validation should call the validation closeout checklist generator automatically.'
            Assert-True ($labValidationScript -like '*validation-closeout-checklist.md*') 'Lab validation should write the validation closeout checklist artifact.'
            Assert-True ($labValidationScript -like '*CloseoutChecklistPath*') 'Lab validation output should include the closeout checklist artifact path.'
            Assert-True ($labValidationScript -like '*Live evidence gate failed; continuing to generate diagnostics before final failure*') 'Lab validation should keep generating diagnostics when live evidence is not ready.'
            Assert-True ($labValidationScript -like '*Finished V1 acceptance package is not ready; refreshing final redacted support bundle before final failure*') 'Lab validation should refresh the final bundle before reporting a failed proof package.'
            Assert-True ($labValidationScript -like '*final validation package is not ready for proof review*') 'Lab validation should fail clearly after producing closeout diagnostics.'
            Assert-True ($labValidationScript -like '*refreshing final redacted support bundle with issue summary*') 'Lab validation should refresh the final support bundle after the issue summary exists.'
            Assert-True ($labValidationScript -like '*owner-mapping.csv*') 'Lab validation should write a deterministic owner mapping CSV.'
            Assert-True ($labValidationScript -like '*-OwnerMappingPath $ownerMappingPath*') 'Lab validation should pass owner mappings into the scan.'
            Assert-True ($labValidationScript -like '*live-evidence-review.csv*') 'Lab validation should write an operator-friendly live evidence review CSV.'
            Assert-True ($labValidationScript -like '*LiveEvidenceReviewPath*') 'Lab validation output should include the live evidence review artifact path.'
            Assert-True ($labValidationScript -like '*-RunRoot $runRoot*') 'Lab validation should include redacted lab-run evidence in generated support bundles.'
            Assert-True ((Get-Content -LiteralPath (Join-Path $repoRoot 'docs/windows-lab-readiness-checklist.md') -Raw) -like '*New-ShareSurferValidationIssueSummary.ps1*') 'Lab readiness checklist should document the validation issue summary script.'
        }
    },
    @{
        Name = 'Documentation includes workflow visuals for operator review'
        Body = {
            $pesterWrapper = Join-Path $repoRoot 'tests/ShareSurfer.Tests.ps1'
            $visualDoc = Join-Path $repoRoot 'docs/workflow-visuals.md'
            $visualRoot = Join-Path $repoRoot 'docs/visuals'
            $visualReadme = Join-Path $visualRoot 'README.md'
            $screenshotScript = Join-Path $repoRoot 'scripts/New-ShareSurferDashboardScreenshots.ps1'
            $firstRunGuide = Join-Path $repoRoot 'docs/first-run-guide.md'
            $managementOverview = Join-Path $repoRoot 'docs/management-overview.md'
            $managementSlide = Join-Path $repoRoot 'docs/management-overview.html'
            $labReadinessChecklist = Join-Path $repoRoot 'docs/windows-lab-readiness-checklist.md'
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
            Assert-True (Test-Path -LiteralPath $visualReadme) 'Visual assets should include a README explaining screenshot provenance and refresh.'
            $visualReadmeText = Get-Content -LiteralPath $visualReadme -Raw
            Assert-True ($visualReadmeText -like '*synthetic CONTOSO-style demo data*') 'Visual README should explain screenshot data provenance.'
            Assert-True ($visualReadmeText -like '*New-ShareSurferDashboardScreenshots.ps1*') 'Visual README should document the screenshot refresh script.'
            Assert-True ($visualReadmeText -like '*-SkipBrowserCapture*') 'Visual README should document dry-run report generation.'
            foreach ($screenshot in $expectedScreenshots) {
                Assert-True ($visualReadmeText -like ("*{0}*" -f $screenshot)) ("Visual README should name screenshot {0}." -f $screenshot)
            }

            Assert-True (Test-Path -LiteralPath $screenshotScript) 'Repository should include a script to refresh dashboard screenshots from demo report output.'
            $screenshotScriptText = Get-Content -LiteralPath $screenshotScript -Raw
            Assert-True ($screenshotScriptText -like '*Invoke-ShareSurferScan*') 'Screenshot refresh script should route demo data through the collector export path.'
            Assert-True ($screenshotScriptText -like '*ConvertTo-ShareSurferReport*') 'Screenshot refresh script should generate the offline report before capture.'
            Assert-True ($screenshotScriptText -like '*playwright*') 'Screenshot refresh script should use Playwright for browser capture.'
            Assert-True ($screenshotScriptText -like '*DirectoryOnly*') 'Screenshot refresh script should use deterministic directory-only enrichment.'
            Assert-True ($screenshotScriptText -like '*CONTOSO*') 'Screenshot refresh script should use safe demo identity names.'
            foreach ($screenshot in $expectedScreenshots) {
                Assert-True ($screenshotScriptText -like ("*{0}*" -f $screenshot)) ("Screenshot refresh script should capture {0}." -f $screenshot)
            }

            $screenshotOutputRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferScreenshotDryRun-' + [guid]::NewGuid().ToString('N'))
            $screenshotResult = & $screenshotScript -OutputRoot $screenshotOutputRoot -VisualOutputPath (Join-Path $screenshotOutputRoot 'visuals') -SkipBrowserCapture
            Assert-True ([bool]$screenshotResult.CaptureSkipped) 'Screenshot refresh dry run should skip browser capture when requested.'
            Assert-True (Test-Path -LiteralPath ([string]$screenshotResult.ReportPath)) 'Screenshot refresh dry run should generate report.html.'
            Assert-True (Test-Path -LiteralPath ([string]$screenshotResult.CaptureScriptPath)) 'Screenshot refresh dry run should generate the capture helper script.'
            Assert-True (@($screenshotResult.Screenshots).Count -eq 4) 'Screenshot refresh dry run should report four screenshot targets.'
            Assert-True (@($screenshotResult.Screenshots | Where-Object { $_ -eq 'report-dashboard-migration.png' }).Count -eq 1) 'Screenshot refresh dry run should include the migration screenshot target.'

            Assert-True (Test-Path -LiteralPath $pesterWrapper) 'Tests should include a Pester-compatible entrypoint.'
            $pesterWrapperText = Get-Content -LiteralPath $pesterWrapper -Raw
            Assert-True ($pesterWrapperText -like '*Describe*ShareSurfer*') 'Pester wrapper should expose a ShareSurfer Describe block.'
            Assert-True ($pesterWrapperText -like '*Invoke-ShareSurferTests.ps1*') 'Pester wrapper should run the fast dependency-free test suite.'
            $readmeText = Get-Content -LiteralPath $readme -Raw
            Assert-True ($readmeText -like '*Invoke-ShareSurferPester.ps1*') 'README should document the optional Pester wrapper.'
            Assert-True ($readmeText -like '*windows-lab-readiness-checklist.md*') 'README should link the Windows lab readiness checklist.'

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
            Assert-True ($firstRunText -like '*choose an attribute that exists on both users and groups*') 'First-run guide should explain OBS attribute schema fallback.'

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

            Assert-True (Test-Path -LiteralPath $labReadinessChecklist) 'Documentation should include a Windows lab readiness checklist.'
            $labReadinessText = Get-Content -LiteralPath $labReadinessChecklist -Raw
            Assert-True ($labReadinessText -like '*Run Preflight First*') 'Lab readiness checklist should tell operators to run preflight first.'
            Assert-True ($labReadinessText -like '*-PreflightOnly*') 'Lab readiness checklist should include the preflight-only command.'
            Assert-True ($labReadinessText -like '*-CreateLab*') 'Lab readiness checklist should run preflight in lab-creation mode.'
            Assert-True ($labReadinessText -like '*checks the same creation blockers*') 'Lab readiness checklist should explain why preflight includes CreateLab.'
            Assert-True ($labReadinessText -like '*ObsAttributeSchema*') 'Lab readiness checklist should include the OBS attribute schema preflight row.'
            Assert-True ($labReadinessText -like '*LabPasswordPolicy*') 'Lab readiness checklist should include the lab password policy preflight row.'
            Assert-True ($labReadinessText -like '*-Scale Enterprise*') 'Lab readiness checklist should include the enterprise validation command.'
            Assert-True ($labReadinessText -like '*v1-acceptance-summary.json*') 'Lab readiness checklist should explain the concise acceptance artifact.'
            Assert-True ($labReadinessText -like '*issue-summary.md*') 'Lab readiness checklist should explain the public-safe issue summary artifact.'
            Assert-True ($labReadinessText -like '*support-bundle-redacted*') 'Lab readiness checklist should explain the redacted support bundle artifact.'
            Assert-True ($labReadinessText -like '*Go Gates*') 'Lab readiness checklist should include go gates.'
            Assert-True ($labReadinessText -like '*Stop Gates*') 'Lab readiness checklist should include stop gates.'
            $operatorWorkflowText = Get-Content -LiteralPath (Join-Path $repoRoot 'docs/operator-workflow.md') -Raw
            Assert-True ($operatorWorkflowText -like '*-PreflightOnly -CreateLab*') 'Operator workflow should tell lab operators to run creation-mode preflight before creating enterprise fixtures.'
            Assert-True ($operatorWorkflowText -like '*target-volume free space*') 'Operator workflow should explain creation-mode preflight blockers.'
            Assert-True ($operatorWorkflowText.Contains('selected `-ObsAttribute` exists and is allowed on both users and groups')) 'Operator workflow should explain the OBS attribute schema preflight check.'
            Assert-True ($operatorWorkflowText -like '*generated lab user password pattern fits the default domain password policy*') 'Operator workflow should explain the lab password policy preflight check.'

            $publicText = @(
                Get-Content -LiteralPath (Join-Path $repoRoot 'README.md') -Raw
                Get-Content -LiteralPath $visualDoc -Raw
                Get-Content -LiteralPath $visualReadme -Raw
                Get-Content -LiteralPath $firstRunGuide -Raw
                Get-Content -LiteralPath $managementOverview -Raw
                Get-Content -LiteralPath $managementSlide -Raw
                Get-Content -LiteralPath $labReadinessChecklist -Raw
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
