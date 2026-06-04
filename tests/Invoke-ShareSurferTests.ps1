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
            Assert-True ($plan.FileFixtures.Count -ge 1000) 'Enterprise lab plan should include real file objects throughout share trees.'
            Assert-True ([int64]$plan.EstimatedLabBytes -le $eightGb) 'Enterprise lab plan should stay under the 8 GB lab-data budget.'
            Assert-True (@($plan.FileFixtures | Where-Object { ([string]$_.RelativePath -split '\\').Count -ge 6 }).Count -gt 0) 'Enterprise lab plan should include deep folder/file paths.'
            Assert-True (@($plan.AclScenarios | Where-Object { ([string]$_.RelativePath).Length -gt 256 }).Count -gt 0) 'Enterprise lab plan should include operational long-path fixtures.'
            Assert-True ($plan.ValidationCriteria.Name -contains 'EnterpriseUserPopulation') 'Enterprise lab plan should include a user-population validation criterion.'
            Assert-True ($plan.ValidationCriteria.Name -contains 'EnterpriseSharePopulation') 'Enterprise lab plan should include a share-population validation criterion.'
            Assert-True ($plan.ValidationCriteria.Name -contains 'EnterpriseRealFiles') 'Enterprise lab plan should include a real-file validation criterion.'
            Assert-True ($plan.ValidationCriteria.Name -contains 'EnterpriseDiskBudget') 'Enterprise lab plan should include an 8 GB disk-budget validation criterion.'
            Assert-True (-not (Test-Path -LiteralPath $labRoot)) 'OutputPlanOnly enterprise planning must not create the lab root.'
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
                'conflicts.csv',
                'findings.csv',
                'scan_events.csv',
                'scan_manifest.csv'
            )
            foreach ($file in $expectedFiles) {
                Assert-True (Test-Path -LiteralPath (Join-Path $outputPath $file)) ("Missing export file {0}" -f $file)
            }

            $findings = Import-Csv -LiteralPath (Join-Path $outputPath 'findings.csv')
            Assert-True ($findings.FindingType -contains 'LongPathOperationalPolicy') 'Findings should include the operational 256-character warning.'
            Assert-True ($findings.FindingType -contains 'DeepExplicitAce') 'Findings should include explicit ACEs deeper than level 2.'
            Assert-True ($findings.FindingType -contains 'BrokenInheritance') 'Findings should include broken inheritance.'

            $conflicts = Import-Csv -LiteralPath (Join-Path $outputPath 'conflicts.csv')
            Assert-True ($conflicts.ConflictType -contains 'NtfsIdentityMissingShareGate') 'Conflicts should show NTFS identities missing at the share gate.'

            $events = Import-Csv -LiteralPath (Join-Path $outputPath 'scan_events.csv')
            Assert-True ($events.EventType -contains 'ScanStarted') 'Scan events should record scan start.'
            Assert-True ($events.EventType -contains 'ExportCompleted') 'Scan events should record export completion.'
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
            Invoke-ShareSurferScan -InputObject (New-TestInventory) -OutputPath $outputPath -SkipIdentityEnrichment | Out-Null

            ConvertTo-ShareSurferReport -ExportPath $outputPath -OutputPath $reportPath | Out-Null
            $report = Get-Content -LiteralPath $reportPath -Raw

            Assert-True ($report -like '*ShareSurfer*') 'Report should include ShareSurfer branding.'
            Assert-True ($report -like '*255-character path components*') 'Report should document Azure Files component limits.'
            Assert-True ($report -like '*2,048-character full paths*') 'Report should document Azure Files full path limit.'
            Assert-True ($report -like '*operational migration policy*') 'Report should distinguish policy warning from hard Azure limit.'
            Assert-True ($report -like '*type="application/json"*') 'Report should embed scan data as application/json rather than executable JavaScript.'
            Assert-True ($report -notlike '*innerHTML = columns.map*') 'Report table rendering must not inject CSV-derived values with innerHTML.'
            Assert-True ($report -like '*Scan Events*') 'Report should expose scan event logs.'
            Assert-True ($report -like '*Business Unit Pivots*') 'Report should expose business-unit pivots.'
            Assert-True ($report -like '*owner_pivots*') 'Report should build owner pivots from exported mappings and items.'
            Assert-True ($report -like '*Finding Rollups*') 'Report should expose finding rollups for business-unit triage.'
            Assert-True ($report -like '*Conflict Rollups*') 'Report should expose conflict rollups for access-model triage.'
            Assert-True ($report -like '*Org Chain Rollups*') 'Report should expose manager and OBS rollups.'
            Assert-True ($report -like '*Group Browser*') 'Report should expose a group expansion browsing view.'
            Assert-True ($report -like '*buildRollups*') 'Report should build dynamic rollup tables from CSV exports.'
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
            Invoke-ShareSurferScan -InputObject (New-TestInventory) -OutputPath $outputPath -SkipIdentityEnrichment | Out-Null
            ConvertTo-ShareSurferReport -ExportPath $outputPath -OutputPath (Join-Path $outputPath 'report.html') | Out-Null

            New-ShareSurferSupportBundle -ExportPath $outputPath -OutputPath $bundlePath -RedactionMode StableToken -RedactionSalt 'unit-test' -IncludeReport | Out-Null
            $redactedAcl = Get-Content -LiteralPath (Join-Path $bundlePath 'acl_entries.csv') -Raw
            $redactedFindings = Get-Content -LiteralPath (Join-Path $bundlePath 'findings.csv') -Raw
            $redactedConflicts = Get-Content -LiteralPath (Join-Path $bundlePath 'conflicts.csv') -Raw
            $redactedEvents = Get-Content -LiteralPath (Join-Path $bundlePath 'scan_events.csv') -Raw
            $redactedManifest = Get-Content -LiteralPath (Join-Path $bundlePath 'scan_manifest.csv') -Raw
            $redactedReportPath = Join-Path $bundlePath 'report.html'
            $bundleManifestPath = Join-Path $bundlePath 'support_bundle_manifest.csv'
            $bundleFilesPath = Join-Path $bundlePath 'support_bundle_files.csv'

            Assert-True ($redactedAcl -notlike '*CONTOSO*') 'Redacted bundle must not contain the source domain name.'
            Assert-True ($redactedAcl -notlike '*FinanceEditors*') 'Redacted bundle must not contain source group names.'
            Assert-True ($redactedAcl -like '*ID-*') 'Stable token redaction should preserve relationships with synthetic IDs.'
            Assert-True ($redactedFindings -notlike '*\\files01\Finance\Delegated*') 'ObservedValue must redact inheritance break paths.'
            Assert-True ($redactedConflicts -like '*ID-*') 'Conflicts should retain stable tokens for cross-file identity correlation.'

            $redactedIdentities = Get-Content -LiteralPath (Join-Path $bundlePath 'identities.csv') -Raw
            $redactedOwners = Get-Content -LiteralPath (Join-Path $bundlePath 'owner_mappings.csv') -Raw
            Assert-True ($redactedIdentities -notlike '*E1001*') 'Employee IDs must be anonymized.'
            Assert-True ($redactedIdentities -notlike '*1001*') 'Employee numbers must be anonymized.'
            Assert-True ($redactedOwners -notlike '*Finance*') 'Business unit names and owner mappings must be anonymized.'
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

            $bundleManifest = Import-Csv -LiteralPath $bundleManifestPath
            $bundleFiles = Import-Csv -LiteralPath $bundleFilesPath
            Assert-Equal $bundleManifest[0].RedactionMode 'StableToken' 'Support bundle manifest should record the redaction mode.'
            Assert-Equal $bundleManifest[0].ValidationIsValid 'True' 'Support bundle manifest should record validation status.'
            Assert-Equal $bundleManifest[0].ReportIncluded 'True' 'Support bundle manifest should record that the redacted report was included.'
            Assert-True ($bundleFiles.FileName -contains 'acl_entries.csv') 'Support bundle file diagnostics should include redacted ACL export.'
            Assert-True ($bundleFiles.FileName -contains 'report.html') 'Support bundle file diagnostics should include the redacted report.'
            $aclFile = @($bundleFiles | Where-Object { $_.FileName -eq 'acl_entries.csv' })[0]
            Assert-True ([int]$aclFile.RowCount -gt 0) 'Support bundle file diagnostics should record row counts.'
            Assert-True ($aclFile.Sha256 -match '^[0-9A-Fa-f]{64}$') 'Support bundle file diagnostics should record a SHA256 hash for redacted files.'

            $aclToken = ([regex]::Match($redactedAcl, 'ID-[0-9A-F]{12}')).Value
            Assert-True ($aclToken -ne '') 'ACL export should contain at least one stable token.'
            Assert-True ($redactedConflicts -like "*$aclToken*") 'The same identity token should be reused across ACL and conflict exports.'
        }
    },
    @{
        Name = 'Documentation includes workflow visuals for operator review'
        Body = {
            $visualDoc = Join-Path $repoRoot 'docs/workflow-visuals.md'
            $visualRoot = Join-Path $repoRoot 'docs/visuals'
            $expectedVisuals = @(
                'collector-to-report.svg',
                'enterprise-lab-validation.svg',
                'support-bundle-diagnostics.svg'
            )

            Assert-True (Test-Path -LiteralPath $visualDoc) 'Workflow visual documentation should exist.'
            $visualDocText = Get-Content -LiteralPath $visualDoc -Raw
            Assert-True ($visualDocText -like '*image-gen2 visual concept*') 'Workflow visual documentation should record the image-gen2 visual concept.'
            Assert-True (Test-Path -LiteralPath (Join-Path $visualRoot 'share-surfer-workflow-concept.png')) 'Workflow visuals should include the generated image-gen2 concept PNG.'
            Assert-True ($visualDocText -like '*visuals/share-surfer-workflow-concept.png*') 'Workflow visual doc should reference the generated image-gen2 concept.'
            foreach ($visual in $expectedVisuals) {
                $path = Join-Path $visualRoot $visual
                Assert-True (Test-Path -LiteralPath $path) ("Missing workflow visual {0}" -f $visual)
                $svg = Get-Content -LiteralPath $path -Raw
                Assert-True ($svg -like '*<svg*') ("Workflow visual {0} should be an SVG asset." -f $visual)
                Assert-True ($visualDocText -like ("*visuals/{0}*" -f $visual)) ("Workflow visual doc should reference {0}" -f $visual)
            }
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
