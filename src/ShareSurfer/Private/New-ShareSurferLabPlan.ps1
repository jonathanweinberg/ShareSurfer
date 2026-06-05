function New-ShareSurferLabPlan {
    param(
        [Parameter(Mandatory = $true)]
        [string] $RootPath,

        [string] $DomainNetBiosName = 'CONTOSO',
        [string] $ObsAttribute = 'extensionAttribute10',

        [ValidateSet('Focused', 'Enterprise')]
        [string] $Scale = 'Focused',

        [int] $EnterpriseUserCount = 2500,
        [int] $EnterpriseShareCount = 250,
        [int] $EnterpriseFilesPerShare = 8,
        [int] $EnterpriseTargetDepth = 5,
        [int64] $EnterpriseFileSizeBytes = 512,
        [int] $LongPathShareCount = 1,
        [int64] $MaxLabBytes = 2147483648,
        [int64] $AbsoluteMaxLabBytes = 8589934592
    )

    if ($MaxLabBytes -gt $AbsoluteMaxLabBytes) {
        throw ('MaxLabBytes {0} exceeds AbsoluteMaxLabBytes {1}. Use a lower explicit disk budget.' -f $MaxLabBytes, $AbsoluteMaxLabBytes)
    }

    $users = @(
        @{ SamAccountName = 'Ava.Accounting'; DisplayName = 'Ava Accounting'; EmployeeId = 'E1001'; EmployeeNumber = '1001'; Manager = 'Morgan.Manager'; Obs = 'CORP.FIN.AP' },
        @{ SamAccountName = 'Noah.Payroll'; DisplayName = 'Noah Payroll'; EmployeeId = 'E1002'; EmployeeNumber = '1002'; Manager = 'Morgan.Manager'; Obs = 'CORP.FIN.PAY' },
        @{ SamAccountName = 'Mia.Engineering'; DisplayName = 'Mia Engineering'; EmployeeId = 'E2001'; EmployeeNumber = '2001'; Manager = 'Parker.Manager'; Obs = 'CORP.ENG.PLAT' },
        @{ SamAccountName = 'Leo.Operations'; DisplayName = 'Leo Operations'; EmployeeId = 'E3001'; EmployeeNumber = '3001'; Manager = 'Quinn.Manager'; Obs = 'CORP.OPS.FILE' },
        @{ SamAccountName = 'Morgan.Manager'; DisplayName = 'Morgan Manager'; EmployeeId = 'M1001'; EmployeeNumber = '9001'; Manager = 'Riley.Director'; Obs = 'CORP.FIN' },
        @{ SamAccountName = 'Parker.Manager'; DisplayName = 'Parker Manager'; EmployeeId = 'M2001'; EmployeeNumber = '9002'; Manager = 'Riley.Director'; Obs = 'CORP.ENG' },
        @{ SamAccountName = 'Quinn.Manager'; DisplayName = 'Quinn Manager'; EmployeeId = 'M3001'; EmployeeNumber = '9003'; Manager = 'Riley.Director'; Obs = 'CORP.OPS' },
        @{ SamAccountName = 'Riley.Director'; DisplayName = 'Riley Director'; EmployeeId = 'D1001'; EmployeeNumber = '9901'; Manager = ''; Obs = 'CORP' }
    ) | ForEach-Object {
        $record = [ordered]@{
            SamAccountName = $_.SamAccountName
            UserPrincipalName = ('{0}@example.test' -f $_.SamAccountName)
            DisplayName = $_.DisplayName
            EmployeeId = $_.EmployeeId
            EmployeeNumber = $_.EmployeeNumber
            Manager = $_.Manager
            Enabled = $true
        }
        $record[$ObsAttribute] = $_.Obs
        [pscustomobject]$record
    }

    if ($Scale -eq 'Enterprise') {
        $userList = New-Object System.Collections.ArrayList
        foreach ($user in @($users)) {
            [void]$userList.Add($user)
        }

        $departments = @('FIN', 'ENG', 'OPS', 'HR', 'LEGAL', 'SALES', 'MKT', 'RISK')
        $managers = @('Morgan.Manager', 'Parker.Manager', 'Quinn.Manager')
        $nextUserId = 1
        while ($userList.Count -lt $EnterpriseUserCount) {
            $department = $departments[($nextUserId - 1) % $departments.Count]
            $manager = $managers[($nextUserId - 1) % $managers.Count]
            $sam = 'SSUser{0:D5}' -f $nextUserId
            $record = [ordered]@{
                SamAccountName = $sam
                UserPrincipalName = ('{0}@example.test' -f $sam)
                DisplayName = ('ShareSurfer User {0:D5}' -f $nextUserId)
                EmployeeId = ('E{0:D7}' -f $nextUserId)
                EmployeeNumber = ('{0:D7}' -f $nextUserId)
                Manager = $manager
                Enabled = $true
            }
            $record[$ObsAttribute] = ('CORP.{0}.UNIT{1:D2}' -f $department, (($nextUserId - 1) % 25) + 1)
            [void]$userList.Add([pscustomobject]$record)
            $nextUserId++
        }
        $users = @($userList)
    }

    $groups = @(
        New-ShareSurferLabGroupRecord -Name 'SS-Finance-Readers' -Members @('Ava.Accounting', 'Noah.Payroll') -Description 'Finance share read access' -ObsAttribute $ObsAttribute -Obs 'CORP.FIN.ACCESS.READ'
        New-ShareSurferLabGroupRecord -Name 'SS-Finance-Editors' -Members @('SS-Finance-Readers', 'Morgan.Manager') -Description 'Finance NTFS modify access' -ObsAttribute $ObsAttribute -Obs 'CORP.FIN.ACCESS.MODIFY'
        New-ShareSurferLabGroupRecord -Name 'SS-Eng-Readers' -Members @('Mia.Engineering', 'Parker.Manager') -Description 'Engineering share read access' -ObsAttribute $ObsAttribute -Obs 'CORP.ENG.ACCESS.READ'
        New-ShareSurferLabGroupRecord -Name 'SS-Operations-Owners' -Members @('Leo.Operations', 'Quinn.Manager') -Description 'Operations share full control' -ObsAttribute $ObsAttribute -Obs 'CORP.OPS.ACCESS.OWNER'
        New-ShareSurferLabGroupRecord -Name 'SS-Recursive-A' -Members @('SS-Recursive-B') -Description 'Cycle test group A' -ObsAttribute $ObsAttribute -Obs 'CORP.TEST.RECURSIVE'
        New-ShareSurferLabGroupRecord -Name 'SS-Recursive-B' -Members @('SS-Recursive-A') -Description 'Cycle test group B' -ObsAttribute $ObsAttribute -Obs 'CORP.TEST.RECURSIVE'
    )

    $shares = @(
        [pscustomobject]@{
            ShareName = 'SSFinance'
            LocalPath = Join-ShareSurferLabPlanPath -RootPath $RootPath -ChildPath 'Finance'
            Description = 'Finance lab share with deep explicit ACEs and share-vs-NTFS conflict'
            SharePermissions = @(
                [pscustomobject]@{ Identity = "$DomainNetBiosName\SS-Finance-Readers"; Rights = 'Read' }
            )
        },
        [pscustomobject]@{
            ShareName = 'SSEngineering'
            LocalPath = Join-ShareSurferLabPlanPath -RootPath $RootPath -ChildPath 'Engineering'
            Description = 'Engineering lab share with normal inherited permissions'
            SharePermissions = @(
                [pscustomobject]@{ Identity = "$DomainNetBiosName\SS-Eng-Readers"; Rights = 'Read' }
            )
        },
        [pscustomobject]@{
            ShareName = 'SSOperations'
            LocalPath = Join-ShareSurferLabPlanPath -RootPath $RootPath -ChildPath 'Operations'
            Description = 'Operations lab share with ownership and broken inheritance examples'
            SharePermissions = @(
                [pscustomobject]@{ Identity = "$DomainNetBiosName\SS-Operations-Owners"; Rights = 'Full' }
            )
        }
    )

    $aclScenarios = @(
        [pscustomobject]@{ Name = 'InheritedBaseline'; ShareName = 'SSEngineering'; RelativePath = 'Projects'; TargetType = 'Directory'; Identity = "$DomainNetBiosName\SS-Eng-Readers"; Rights = 'ReadAndExecute'; AccessControlType = 'Allow'; IsInherited = $true; Depth = 1; OwnerIdentity = '' },
        [pscustomobject]@{ Name = 'BrokenInheritance'; ShareName = 'SSOperations'; RelativePath = 'Restricted'; TargetType = 'Directory'; Identity = "$DomainNetBiosName\SS-Operations-Owners"; Rights = 'Modify'; AccessControlType = 'Allow'; IsInherited = $false; Depth = 1; OwnerIdentity = "$DomainNetBiosName\Quinn.Manager" },
        [pscustomobject]@{ Name = 'DeepExplicitAce'; ShareName = 'SSFinance'; RelativePath = 'AP\Vendor\Archive'; TargetType = 'Directory'; Identity = "$DomainNetBiosName\SS-Finance-Editors"; Rights = 'Modify'; AccessControlType = 'Allow'; IsInherited = $false; Depth = 3; OwnerIdentity = '' },
        [pscustomobject]@{ Name = 'LongPath'; ShareName = 'SSFinance'; RelativePath = ('AP\LongPath\' + ('A' * 125) + '\' + ('B' * 125)); TargetType = 'Directory'; Identity = "$DomainNetBiosName\SS-Finance-Editors"; Rights = 'ReadAndExecute'; AccessControlType = 'Allow'; IsInherited = $false; Depth = 4; OwnerIdentity = '' },
        [pscustomobject]@{ Name = 'ShareVsNtfsConflict'; ShareName = 'SSFinance'; RelativePath = 'AP\Conflict'; TargetType = 'Directory'; Identity = "$DomainNetBiosName\SS-Finance-Editors"; Rights = 'Modify'; AccessControlType = 'Allow'; IsInherited = $false; Depth = 2; OwnerIdentity = '' },
        [pscustomobject]@{ Name = 'ShareRightsRestriction'; ShareName = 'SSFinance'; RelativePath = 'AP\Conflict\ReaderModify'; TargetType = 'Directory'; Identity = "$DomainNetBiosName\SS-Finance-Readers"; Rights = 'Modify'; AccessControlType = 'Allow'; IsInherited = $false; Depth = 3; OwnerIdentity = "$DomainNetBiosName\Morgan.Manager" },
        [pscustomobject]@{ Name = 'NtfsDenyCollision'; ShareName = 'SSFinance'; RelativePath = 'AP\Conflict\ReaderModify'; TargetType = 'Directory'; Identity = "$DomainNetBiosName\SS-Finance-Readers"; Rights = 'Read'; AccessControlType = 'Deny'; IsInherited = $false; Depth = 3; OwnerIdentity = '' },
        [pscustomobject]@{ Name = 'FileSpecificAce'; ShareName = 'SSOperations'; RelativePath = 'Restricted\FileOnly\executive-note.txt'; TargetType = 'File'; Identity = "$DomainNetBiosName\SS-Operations-Owners"; Rights = 'Read'; AccessControlType = 'Allow'; IsInherited = $false; Depth = 3; OwnerIdentity = "$DomainNetBiosName\Leo.Operations" }
    )

    $fileFixtures = New-Object System.Collections.ArrayList
    [void]$fileFixtures.Add([pscustomobject]@{ ShareName = 'SSFinance'; RelativePath = 'AP\Vendor\Archive\sample.txt'; SizeBytes = 512; ContentTag = 'FocusedDeepExplicitAce' })
    [void]$fileFixtures.Add([pscustomobject]@{ ShareName = 'SSOperations'; RelativePath = 'Restricted\FileOnly\executive-note.txt'; SizeBytes = 512; ContentTag = 'FocusedFileSpecificAce' })

    if ($Scale -eq 'Enterprise') {
        $groupList = New-Object System.Collections.ArrayList
        foreach ($group in @($groups)) {
            [void]$groupList.Add($group)
        }
        $shareList = New-Object System.Collections.ArrayList
        foreach ($share in @($shares)) {
            [void]$shareList.Add($share)
        }
        $aclList = New-Object System.Collections.ArrayList
        foreach ($scenario in @($aclScenarios)) {
            [void]$aclList.Add($scenario)
        }

        $targetShareCount = [Math]::Max($EnterpriseShareCount, 1)
        for ($i = 1; $shareList.Count -lt $targetShareCount; $i++) {
            $shareName = 'SSEnt{0:D4}' -f $i
            $readerGroup = 'SS-ENT-{0:D4}-Readers' -f $i
            $editorGroup = 'SS-ENT-{0:D4}-Editors' -f $i
            $firstUser = 'SSUser{0:D5}' -f ((($i - 1) % [Math]::Max($EnterpriseUserCount - 8, 1)) + 1)
            $secondUser = 'SSUser{0:D5}' -f (($i % [Math]::Max($EnterpriseUserCount - 8, 1)) + 1)

            $enterpriseObs = 'CORP.ENT.SHARE{0:D4}' -f $i
            [void]$groupList.Add((New-ShareSurferLabGroupRecord -Name $readerGroup -Members @($firstUser, $secondUser) -Description ('Enterprise share {0:D4} read access' -f $i) -ObsAttribute $ObsAttribute -Obs ('{0}.READ' -f $enterpriseObs)))
            [void]$groupList.Add((New-ShareSurferLabGroupRecord -Name $editorGroup -Members @($readerGroup) -Description ('Enterprise share {0:D4} modify access' -f $i) -ObsAttribute $ObsAttribute -Obs ('{0}.MODIFY' -f $enterpriseObs)))

            [void]$shareList.Add([pscustomobject]@{
                ShareName = $shareName
                LocalPath = Join-ShareSurferLabPlanPath -RootPath $RootPath -ChildPath ('Enterprise\Share{0:D4}' -f $i)
                Description = ('Enterprise-scale complex share {0:D4}' -f $i)
                SharePermissions = @(
                    [pscustomobject]@{ Identity = "$DomainNetBiosName\$readerGroup"; Rights = 'Read' }
                )
            })

            $deepPath = New-ShareSurferEnterpriseRelativePath -Index $i -TargetDepth $EnterpriseTargetDepth
            [void]$aclList.Add([pscustomobject]@{ Name = ('EnterpriseDeepExplicitAce{0:D4}' -f $i); ShareName = $shareName; RelativePath = $deepPath; TargetType = 'Directory'; Identity = "$DomainNetBiosName\$editorGroup"; Rights = 'Modify'; AccessControlType = 'Allow'; IsInherited = $false; Depth = $EnterpriseTargetDepth; OwnerIdentity = '' })

            if ($i -le $LongPathShareCount) {
                $longRelativePath = $deepPath + '\' + ('L' * 120) + '\' + ('M' * 120)
                [void]$aclList.Add([pscustomobject]@{ Name = ('EnterpriseLongPath{0:D4}' -f $i); ShareName = $shareName; RelativePath = $longRelativePath; TargetType = 'Directory'; Identity = "$DomainNetBiosName\$editorGroup"; Rights = 'ReadAndExecute'; AccessControlType = 'Allow'; IsInherited = $false; Depth = ($EnterpriseTargetDepth + 2); OwnerIdentity = '' })
            }

            for ($fileIndex = 1; $fileIndex -le $EnterpriseFilesPerShare; $fileIndex++) {
                $fileRelativePath = $deepPath + ('\Folder{0:D2}\File{1:D2}.txt' -f $fileIndex, $fileIndex)
                [void]$fileFixtures.Add([pscustomobject]@{
                    ShareName = $shareName
                    RelativePath = $fileRelativePath
                    SizeBytes = $EnterpriseFileSizeBytes
                    ContentTag = ('EnterpriseShare{0:D4}File{1:D2}' -f $i, $fileIndex)
                })
            }
        }

        $groups = @($groupList)
        $shares = @($shareList)
        $aclScenarios = @($aclList)

        foreach ($share in @($shares)) {
            $shareFileCount = @($fileFixtures | Where-Object { $_.ShareName -eq $share.ShareName }).Count
            for ($fileIndex = $shareFileCount + 1; $fileIndex -le $EnterpriseFilesPerShare; $fileIndex++) {
                [void]$fileFixtures.Add([pscustomobject]@{
                    ShareName = $share.ShareName
                    RelativePath = 'EnterpriseEvidence\Fixture{0:D2}.txt' -f $fileIndex
                    SizeBytes = $EnterpriseFileSizeBytes
                    ContentTag = ('EnterpriseSupplemental{0}File{1:D2}' -f $share.ShareName, $fileIndex)
                })
            }
        }
    }

    $estimatedLabBytes = 0
    foreach ($file in @($fileFixtures)) {
        $estimatedLabBytes += [int64]$file.SizeBytes
    }
    if ($estimatedLabBytes -gt $MaxLabBytes) {
        throw ('Lab plan estimates {0} bytes, which exceeds MaxLabBytes {1}.' -f $estimatedLabBytes, $MaxLabBytes)
    }

    $ownerMappings = foreach ($share in @($shares)) {
        $businessUnit = switch -Regex ([string]$share.ShareName) {
            'Finance' { 'Finance'; break }
            'Engineering' { 'Engineering'; break }
            'Operations' { 'Operations'; break }
            '^SSEnt' { 'Enterprise'; break }
            default { 'Shared Services' }
        }

        [pscustomobject]@{
            Pattern = ('{0}*' -f [string]$share.LocalPath)
            Owner = ('{0} Data Owners' -f $businessUnit)
            BusinessUnit = $businessUnit
            Source = 'LabPlan'
        }
    }

    $validationCriteria = New-Object System.Collections.ArrayList
    [void]$validationCriteria.Add([pscustomobject]@{
        Name = 'FocusedAclScenarios'
        MinimumValue = 1
        ActualPlanValue = @($aclScenarios).Count
        Unit = 'acl scenarios'
        Required = $true
        Description = 'Fixture includes ACL scenarios for inheritance, explicit ACEs, long paths, ownership, file ACLs, and share-vs-NTFS conflicts.'
    })

    if ($Scale -eq 'Enterprise') {
        [void]$validationCriteria.Add([pscustomobject]@{
            Name = 'EnterpriseUserPopulation'
            MinimumValue = $EnterpriseUserCount
            ActualPlanValue = @($users).Count
            Unit = 'users'
            Required = $true
            Description = 'Enterprise validation includes a multi-thousand user population.'
        })
        [void]$validationCriteria.Add([pscustomobject]@{
            Name = 'EnterpriseGroupPopulation'
            MinimumValue = @($groups).Count
            ActualPlanValue = @($groups).Count
            Unit = 'groups'
            Required = $true
            Description = 'Enterprise validation includes the generated security group population for share and ACL access scenarios.'
        })
        [void]$validationCriteria.Add([pscustomobject]@{
            Name = 'EnterpriseEmployeeIdentifierCoverage'
            MinimumValue = 1
            ActualPlanValue = @($users | Where-Object { [string]$_.EmployeeId -ne '' -and [string]$_.EmployeeNumber -ne '' }).Count
            Unit = 'users with employee identifiers'
            Required = $true
            Description = 'Enterprise validation proves enriched user identities include employeeId and employeeNumber evidence.'
        })
        $userManagerMap = @{}
        foreach ($user in @($users)) {
            $userManagerMap[[string]$user.SamAccountName] = [string]$user.Manager
        }
        $plannedTwoLevelManagerChains = @($users | Where-Object {
            $manager = [string]$_.Manager
            $manager -ne '' -and $userManagerMap.ContainsKey($manager) -and [string]$userManagerMap[$manager] -ne ''
        })
        [void]$validationCriteria.Add([pscustomobject]@{
            Name = 'EnterpriseManagerChainCoverage'
            MinimumValue = 1
            ActualPlanValue = @($plannedTwoLevelManagerChains).Count
            Unit = 'two-level manager chains'
            Required = $true
            Description = 'Enterprise validation proves enriched user identities include manager and manager-manager context.'
        })
        [void]$validationCriteria.Add([pscustomobject]@{
            Name = 'EnterpriseUserObsCoverage'
            MinimumValue = 1
            ActualPlanValue = @($users | Where-Object { $_.PSObject.Properties[$ObsAttribute] -and [string]$_.PSObject.Properties[$ObsAttribute].Value -ne '' }).Count
            Unit = 'users with OBS'
            Required = $true
            Description = 'Enterprise validation proves enriched user identities carry the runtime-selected OBS/OID extension attribute.'
        })
        [void]$validationCriteria.Add([pscustomobject]@{
            Name = 'EnterpriseSharePopulation'
            MinimumValue = $EnterpriseShareCount
            ActualPlanValue = @($shares).Count
            Unit = 'shares'
            Required = $true
            Description = 'Enterprise validation includes hundreds of SMB shares.'
        })
        [void]$validationCriteria.Add([pscustomobject]@{
            Name = 'EnterpriseRealFiles'
            MinimumValue = $EnterpriseShareCount * $EnterpriseFilesPerShare
            ActualPlanValue = @($fileFixtures).Count
            Unit = 'file fixtures'
            Required = $true
            Description = 'Enterprise validation includes real small file objects throughout share trees.'
        })
        [void]$validationCriteria.Add([pscustomobject]@{
            Name = 'EnterpriseDeepPaths'
            MinimumValue = 1
            ActualPlanValue = @($fileFixtures | Where-Object { ([string]$_.RelativePath -split '\\').Count -ge 6 }).Count
            Unit = 'deep file fixtures'
            Required = $true
            Description = 'Enterprise validation includes deep share trees and intricate folder paths.'
        })
        [void]$validationCriteria.Add([pscustomobject]@{
            Name = 'EnterpriseLongPathPolicy'
            MinimumValue = 1
            ActualPlanValue = @($aclScenarios | Where-Object { ([string]$_.RelativePath).Length -gt 256 }).Count
            Unit = 'long-path scenarios'
            Required = $true
            Description = 'Enterprise validation includes paths beyond the operational 256-character migration policy threshold.'
        })
        [void]$validationCriteria.Add([pscustomobject]@{
            Name = 'EnterpriseSharePermissions'
            MinimumValue = @($shares).Count
            ActualPlanValue = @($shares | ForEach-Object { @($_.SharePermissions).Count } | Measure-Object -Sum).Sum
            Unit = 'share permission rows'
            Required = $true
            Description = 'Enterprise validation includes collected share-level permission rows.'
        })
        [void]$validationCriteria.Add([pscustomobject]@{
            Name = 'EnterpriseAclEntries'
            MinimumValue = @($aclScenarios).Count
            ActualPlanValue = @($aclScenarios).Count
            Unit = 'acl rows'
            Required = $true
            Description = 'Enterprise validation includes collected folder and file ACL entries.'
        })
        [void]$validationCriteria.Add([pscustomobject]@{
            Name = 'EnterpriseFileAclEntries'
            MinimumValue = 1
            ActualPlanValue = @($aclScenarios | Where-Object { $_.TargetType -eq 'File' }).Count
            Unit = 'file acl rows'
            Required = $true
            Description = 'Enterprise validation includes file-specific ACL evidence.'
        })
        [void]$validationCriteria.Add([pscustomobject]@{
            Name = 'EnterpriseDeepExplicitAceFindings'
            MinimumValue = 1
            ActualPlanValue = @($aclScenarios | Where-Object { $_.Depth -gt 2 -and -not $_.IsInherited }).Count
            Unit = 'findings'
            Required = $true
            Description = 'Enterprise validation includes deep explicit ACE findings.'
        })
        [void]$validationCriteria.Add([pscustomobject]@{
            Name = 'EnterpriseBrokenInheritanceFindings'
            MinimumValue = 1
            ActualPlanValue = @($aclScenarios | Where-Object { $_.Name -like '*BrokenInheritance*' }).Count
            Unit = 'findings'
            Required = $true
            Description = 'Enterprise validation includes broken inheritance findings.'
        })
        [void]$validationCriteria.Add([pscustomobject]@{
            Name = 'EnterpriseConflictFindings'
            MinimumValue = 1
            ActualPlanValue = @($aclScenarios | Where-Object { $_.Name -like '*Conflict*' -or $_.Name -like '*Restriction*' -or $_.AccessControlType -eq 'Deny' }).Count
            Unit = 'conflicts'
            Required = $true
            Description = 'Enterprise validation includes share-vs-NTFS conflict evidence.'
        })
        [void]$validationCriteria.Add([pscustomobject]@{
            Name = 'EnterpriseCollectionErrors'
            MinimumValue = 0
            ActualPlanValue = 0
            Unit = 'collection error rows'
            Required = $true
            Description = 'Enterprise validation surfaces collection-error export evidence for partial-data and scanner-gap review; zero rows can be valid for a clean scan.'
        })
        [void]$validationCriteria.Add([pscustomobject]@{
            Name = 'EnterpriseGroupExpansion'
            MinimumValue = 1
            ActualPlanValue = @($groups | Where-Object { @($_.Members).Count -gt 0 }).Count
            Unit = 'group edges'
            Required = $true
            Description = 'Enterprise validation includes expandable security group membership evidence.'
        })
        $permissionGroupNames = @(Get-ShareSurferLabPlanPermissionGroupNames -Shares $shares -AclScenarios $aclScenarios -Groups $groups)
        $permissionGroupsWithObs = @($groups | Where-Object {
            $permissionGroupNames -contains [string]$_.Name -and
            $_.PSObject.Properties[$ObsAttribute] -and
            [string]$_.PSObject.Properties[$ObsAttribute].Value -ne ''
        })
        [void]$validationCriteria.Add([pscustomobject]@{
            Name = 'EnterprisePermissionGroupObsCoverage'
            MinimumValue = @($permissionGroupNames).Count
            ActualPlanValue = @($permissionGroupsWithObs).Count
            Unit = 'groups with OBS'
            Required = $true
            Description = 'Enterprise validation proves permission-bearing security groups carry the runtime-selected OBS/OID extension attribute into identity exports.'
        })
        [void]$validationCriteria.Add([pscustomobject]@{
            Name = 'EnterpriseOwnerRiskPivots'
            MinimumValue = 1
            ActualPlanValue = @($ownerMappings).Count
            Unit = 'owner risk pivots'
            Required = $true
            Description = 'Enterprise validation includes owner/business-unit risk pivot evidence.'
        })
        [void]$validationCriteria.Add([pscustomobject]@{
            Name = 'EnterpriseRelatedDataAreas'
            MinimumValue = 1
            ActualPlanValue = @($ownerMappings).Count
            Unit = 'related data areas'
            Required = $true
            Description = 'Enterprise validation includes migration discovery evidence for like-owned shares, folders, and files.'
        })
        [void]$validationCriteria.Add([pscustomobject]@{
            Name = 'EnterpriseOwnerReviewPackets'
            MinimumValue = 1
            ActualPlanValue = @($ownerMappings).Count
            Unit = 'owner review packets'
            Required = $true
            Description = 'Enterprise validation includes business-owner review packet evidence with why-review and next-action guidance.'
        })
        [void]$validationCriteria.Add([pscustomobject]@{
            Name = 'EnterpriseDiskBudget'
            MinimumValue = 1
            ActualPlanValue = if ($estimatedLabBytes -le $MaxLabBytes) { 1 } else { 0 }
            Unit = 'pass/fail'
            Required = $true
            Description = 'Enterprise validation keeps generated lab file data under the configured disk budget.'
        })
    }

    [pscustomobject]@{
        LabName = 'ShareSurferLab'
        ScaleProfile = $Scale
        RootPath = $RootPath
        DomainNetBiosName = $DomainNetBiosName
        ObsAttribute = $ObsAttribute
        MaxLabBytes = $MaxLabBytes
        AbsoluteMaxLabBytes = $AbsoluteMaxLabBytes
        EnterpriseTargetDepth = $EnterpriseTargetDepth
        EnterpriseFileSizeBytes = $EnterpriseFileSizeBytes
        LongPathShareCount = $LongPathShareCount
        EstimatedLabBytes = $estimatedLabBytes
        OrganizationalUnit = 'OU=ShareSurferLab'
        Users = @($users)
        Groups = @($groups)
        Shares = @($shares)
        AclScenarios = @($aclScenarios)
        FileFixtures = @($fileFixtures)
        OwnerMappings = @($ownerMappings)
        ValidationCriteria = @($validationCriteria)
    }
}

function Join-ShareSurferLabPlanPath {
    param(
        [Parameter(Mandatory = $true)]
        [string] $RootPath,

        [Parameter(Mandatory = $true)]
        [string] $ChildPath
    )

    if ($RootPath -match '^[A-Za-z]:[\\/]' -or $RootPath -like '\\*') {
        return ('{0}\{1}' -f ($RootPath -replace '[\\/]+$', ''), ($ChildPath -replace '^[\\/]+', ''))
    }

    Join-Path $RootPath $ChildPath
}

function New-ShareSurferEnterpriseRelativePath {
    param(
        [Parameter(Mandatory = $true)]
        [int] $Index,

        [int] $TargetDepth = 5
    )

    $segments = @(
        'Division{0:D2}' -f (($Index % 12) + 1)
        'Region{0:D2}' -f (($Index % 18) + 1)
        'Program{0:D2}' -f (($Index % 30) + 1)
        'Project{0:D2}' -f (($Index % 40) + 1)
        'Workstream{0:D2}' -f (($Index % 50) + 1)
        'Portfolio{0:D2}' -f (($Index % 60) + 1)
        'Service{0:D2}' -f (($Index % 70) + 1)
        'Dataset{0:D2}' -f (($Index % 80) + 1)
        'Archive{0:D2}' -f (($Index % 90) + 1)
        'Quarter{0:D2}' -f (($Index % 12) + 1)
        'Review{0:D2}' -f (($Index % 24) + 1)
        'Evidence{0:D2}' -f (($Index % 36) + 1)
    )

    ($segments[0..([Math]::Min($TargetDepth, $segments.Count) - 1)]) -join '\'
}

function New-ShareSurferLabGroupRecord {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Name,

        [Parameter(Mandatory = $true)]
        [object[]] $Members,

        [Parameter(Mandatory = $true)]
        [string] $Description,

        [Parameter(Mandatory = $true)]
        [string] $ObsAttribute,

        [Parameter(Mandatory = $true)]
        [string] $Obs
    )

    $record = [ordered]@{
        Name = $Name
        Members = @($Members)
        Description = $Description
    }
    $record[$ObsAttribute] = $Obs
    [pscustomobject]$record
}

function Get-ShareSurferLabPlanPermissionGroupNames {
    param(
        [Parameter(Mandatory = $true)]
        $Shares,

        [Parameter(Mandatory = $true)]
        $AclScenarios,

        [Parameter(Mandatory = $true)]
        $Groups
    )

    $knownGroups = @{}
    foreach ($group in @($Groups)) {
        $knownGroups[[string]$group.Name] = $true
    }

    $permissionGroups = [ordered]@{}
    foreach ($share in @($Shares)) {
        foreach ($permission in @($share.SharePermissions)) {
            $name = Get-ShareSurferLabPlanSamName -Identity ([string]$permission.Identity)
            if ($knownGroups.ContainsKey($name)) {
                $permissionGroups[$name] = $true
            }
        }
    }
    foreach ($scenario in @($AclScenarios)) {
        $name = Get-ShareSurferLabPlanSamName -Identity ([string]$scenario.Identity)
        if ($knownGroups.ContainsKey($name)) {
            $permissionGroups[$name] = $true
        }
    }

    @($permissionGroups.Keys)
}

function Get-ShareSurferLabPlanSamName {
    param(
        [string] $Identity = ''
    )

    $value = $Identity.Trim()
    if ($value -like '*\*') {
        return ($value -split '\\')[-1]
    }

    $value
}
