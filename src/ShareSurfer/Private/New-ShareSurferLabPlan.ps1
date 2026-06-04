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
        [int64] $MaxLabBytes = 8589934592
    )

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
        [pscustomobject]@{ Name = 'SS-Finance-Readers'; Members = @('Ava.Accounting', 'Noah.Payroll'); Description = 'Finance share read access' },
        [pscustomobject]@{ Name = 'SS-Finance-Editors'; Members = @('SS-Finance-Readers', 'Morgan.Manager'); Description = 'Finance NTFS modify access' },
        [pscustomobject]@{ Name = 'SS-Engineering-Readers'; Members = @('Mia.Engineering', 'Parker.Manager'); Description = 'Engineering share read access' },
        [pscustomobject]@{ Name = 'SS-Operations-Owners'; Members = @('Leo.Operations', 'Quinn.Manager'); Description = 'Operations share full control' },
        [pscustomobject]@{ Name = 'SS-Recursive-A'; Members = @('SS-Recursive-B'); Description = 'Cycle test group A' },
        [pscustomobject]@{ Name = 'SS-Recursive-B'; Members = @('SS-Recursive-A'); Description = 'Cycle test group B' }
    )

    $shares = @(
        [pscustomobject]@{
            ShareName = 'SSFinance'
            LocalPath = Join-Path $RootPath 'Finance'
            Description = 'Finance lab share with deep explicit ACEs and share-vs-NTFS conflict'
            SharePermissions = @(
                [pscustomobject]@{ Identity = "$DomainNetBiosName\SS-Finance-Readers"; Rights = 'Read' }
            )
        },
        [pscustomobject]@{
            ShareName = 'SSEngineering'
            LocalPath = Join-Path $RootPath 'Engineering'
            Description = 'Engineering lab share with normal inherited permissions'
            SharePermissions = @(
                [pscustomobject]@{ Identity = "$DomainNetBiosName\SS-Engineering-Readers"; Rights = 'Read' }
            )
        },
        [pscustomobject]@{
            ShareName = 'SSOperations'
            LocalPath = Join-Path $RootPath 'Operations'
            Description = 'Operations lab share with ownership and broken inheritance examples'
            SharePermissions = @(
                [pscustomobject]@{ Identity = "$DomainNetBiosName\SS-Operations-Owners"; Rights = 'Full' }
            )
        }
    )

    $aclScenarios = @(
        [pscustomobject]@{ Name = 'InheritedBaseline'; ShareName = 'SSEngineering'; RelativePath = 'Projects'; TargetType = 'Directory'; Identity = "$DomainNetBiosName\SS-Engineering-Readers"; Rights = 'ReadAndExecute'; AccessControlType = 'Allow'; IsInherited = $true; Depth = 1; OwnerIdentity = '' },
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

            [void]$groupList.Add([pscustomobject]@{ Name = $readerGroup; Members = @($firstUser, $secondUser); Description = ('Enterprise share {0:D4} read access' -f $i) })
            [void]$groupList.Add([pscustomobject]@{ Name = $editorGroup; Members = @($readerGroup); Description = ('Enterprise share {0:D4} modify access' -f $i) })

            [void]$shareList.Add([pscustomobject]@{
                ShareName = $shareName
                LocalPath = Join-Path $RootPath ('Enterprise\Share{0:D4}' -f $i)
                Description = ('Enterprise-scale complex share {0:D4}' -f $i)
                SharePermissions = @(
                    [pscustomobject]@{ Identity = "$DomainNetBiosName\$readerGroup"; Rights = 'Read' }
                )
            })

            $deepPath = 'Division{0:D2}\Region{1:D2}\Program{2:D2}\Project{3:D2}\Workstream{4:D2}' -f (($i % 12) + 1), (($i % 18) + 1), (($i % 30) + 1), (($i % 40) + 1), (($i % 50) + 1)
            [void]$aclList.Add([pscustomobject]@{ Name = ('EnterpriseDeepExplicitAce{0:D4}' -f $i); ShareName = $shareName; RelativePath = $deepPath; TargetType = 'Directory'; Identity = "$DomainNetBiosName\$editorGroup"; Rights = 'Modify'; AccessControlType = 'Allow'; IsInherited = $false; Depth = 5; OwnerIdentity = '' })

            if ($i -eq 1) {
                $longRelativePath = $deepPath + '\' + ('L' * 120) + '\' + ('M' * 120)
                [void]$aclList.Add([pscustomobject]@{ Name = 'EnterpriseLongPath'; ShareName = $shareName; RelativePath = $longRelativePath; TargetType = 'Directory'; Identity = "$DomainNetBiosName\$editorGroup"; Rights = 'ReadAndExecute'; AccessControlType = 'Allow'; IsInherited = $false; Depth = 7; OwnerIdentity = '' })
            }

            for ($fileIndex = 1; $fileIndex -le $EnterpriseFilesPerShare; $fileIndex++) {
                $fileRelativePath = $deepPath + ('\Folder{0:D2}\File{1:D2}.txt' -f $fileIndex, $fileIndex)
                [void]$fileFixtures.Add([pscustomobject]@{
                    ShareName = $shareName
                    RelativePath = $fileRelativePath
                    SizeBytes = 512
                    ContentTag = ('EnterpriseShare{0:D4}File{1:D2}' -f $i, $fileIndex)
                })
            }
        }

        $groups = @($groupList)
        $shares = @($shareList)
        $aclScenarios = @($aclList)
    }

    $estimatedLabBytes = 0
    foreach ($file in @($fileFixtures)) {
        $estimatedLabBytes += [int64]$file.SizeBytes
    }
    if ($estimatedLabBytes -gt $MaxLabBytes) {
        throw ('Lab plan estimates {0} bytes, which exceeds MaxLabBytes {1}.' -f $estimatedLabBytes, $MaxLabBytes)
    }

    [pscustomobject]@{
        LabName = 'ShareSurferLab'
        ScaleProfile = $Scale
        RootPath = $RootPath
        DomainNetBiosName = $DomainNetBiosName
        ObsAttribute = $ObsAttribute
        MaxLabBytes = $MaxLabBytes
        EstimatedLabBytes = $estimatedLabBytes
        OrganizationalUnit = 'OU=ShareSurferLab'
        Users = @($users)
        Groups = @($groups)
        Shares = @($shares)
        AclScenarios = @($aclScenarios)
        FileFixtures = @($fileFixtures)
    }
}
