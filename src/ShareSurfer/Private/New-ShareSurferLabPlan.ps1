function New-ShareSurferLabPlan {
    param(
        [Parameter(Mandatory = $true)]
        [string] $RootPath,

        [string] $DomainNetBiosName = 'CONTOSO',
        [string] $ObsAttribute = 'extensionAttribute10'
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

    [pscustomobject]@{
        LabName = 'ShareSurferLab'
        RootPath = $RootPath
        DomainNetBiosName = $DomainNetBiosName
        ObsAttribute = $ObsAttribute
        OrganizationalUnit = 'OU=ShareSurferLab'
        Users = @($users)
        Groups = @($groups)
        Shares = @($shares)
        AclScenarios = @($aclScenarios)
    }
}
