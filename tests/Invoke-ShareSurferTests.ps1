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
            $longScenario = @($plan.AclScenarios | Where-Object { $_.Name -eq 'LongPath' })[0]
            $longSegments = @($longScenario.RelativePath -split '\\')
            Assert-True (@($longSegments | Where-Object { $_.Length -gt 255 }).Count -eq 0) 'Long-path lab scenario must use Windows-creatable path components.'
            Assert-True ($longScenario.RelativePath.Length -gt 256) 'Long-path lab scenario should still exceed the operational path warning threshold.'
            Assert-True (-not (Test-Path -LiteralPath $labRoot)) 'OutputPlanOnly must not create the lab root.'
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
        Name = 'New-ShareSurferSupportBundle redacts sensitive values with stable tokens'
        Body = {
            Import-Module $moduleManifest -Force
            $outputPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferExport-' + [guid]::NewGuid().ToString('N'))
            $bundlePath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferBundle-' + [guid]::NewGuid().ToString('N'))
            Invoke-ShareSurferScan -InputObject (New-TestInventory) -OutputPath $outputPath -SkipIdentityEnrichment | Out-Null

            New-ShareSurferSupportBundle -ExportPath $outputPath -OutputPath $bundlePath -RedactionMode StableToken -RedactionSalt 'unit-test' | Out-Null
            $redactedAcl = Get-Content -LiteralPath (Join-Path $bundlePath 'acl_entries.csv') -Raw
            $redactedFindings = Get-Content -LiteralPath (Join-Path $bundlePath 'findings.csv') -Raw
            $redactedConflicts = Get-Content -LiteralPath (Join-Path $bundlePath 'conflicts.csv') -Raw

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

            $aclToken = ([regex]::Match($redactedAcl, 'ID-[0-9A-F]{12}')).Value
            Assert-True ($aclToken -ne '') 'ACL export should contain at least one stable token.'
            Assert-True ($redactedConflicts -like "*$aclToken*") 'The same identity token should be reused across ACL and conflict exports.'
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
