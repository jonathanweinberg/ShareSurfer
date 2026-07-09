param(
    [string] $Name = ''
)

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

function Assert-SignalContains {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Actual,

        [Parameter(Mandatory = $true)]
        [string] $Expected,

        [Parameter(Mandatory = $true)]
        [string] $Message
    )

    $tokens = @([string]$Actual -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })
    Assert-True ($tokens -contains $Expected) $Message
}

function New-TestSecurityDescriptorBytes {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Sddl
    )

    $descriptor = New-Object System.Security.AccessControl.RawSecurityDescriptor $Sddl
    $bytes = New-Object byte[] $descriptor.BinaryLength
    $descriptor.GetBinaryForm($bytes, 0)
    ,$bytes
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
            },
            [pscustomobject]@{
                ItemId = 'item-root'
                ShareId = 'share-finance'
                FullPath = '\\files01\Finance'
                Identity = 'CONTOSO\svc.ShareBot'
                Rights = 'Read'
                AccessControlType = 'Allow'
                IsInherited = $false
                InheritanceFlags = 'ContainerInherit,ObjectInherit'
                PropagationFlags = 'None'
                Depth = 1
            },
            [pscustomobject]@{
                ItemId = 'item-root'
                ShareId = 'share-finance'
                FullPath = '\\files01\Finance'
                Identity = 'S-1-5-21-1000-2000-3000-4040'
                Rights = 'Read'
                AccessControlType = 'Allow'
                IsInherited = $false
                InheritanceFlags = 'ContainerInherit,ObjectInherit'
                PropagationFlags = 'None'
                Depth = 1
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
                ManagerLevel3 = ''
                ObsPath = 'CORP.FIN'
                ObsAttribute = 'extensionAttribute10'
                PotentialServiceAccount = $false
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
                ManagerLevel3 = ''
                ObsPath = 'CORP.FIN.AP'
                ObsAttribute = 'extensionAttribute10'
                PotentialServiceAccount = $false
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
                EmployeeNumber = '1001'
                Department = 'Accounts Payable'
                Title = 'Accounting Analyst'
                Company = 'Contoso Finance'
                Office = 'HQ-4'
                ManagerLevel1 = 'CONTOSO\Morgan.Manager'
                ManagerLevel2 = 'CONTOSO\Riley.Director'
                ManagerLevel3 = 'CONTOSO\Jordan.VP'
                ObsPath = 'CORP.FIN.AP'
                ObsAttribute = 'extensionAttribute10'
                PotentialServiceAccount = $false
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
                ManagerLevel3 = ''
                ObsPath = 'CORP.FIN.AP'
                ObsAttribute = 'extensionAttribute10'
                PotentialServiceAccount = $false
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
                ManagerLevel3 = ''
                ObsPath = 'CORP.FIN'
                ObsAttribute = 'extensionAttribute10'
                PotentialServiceAccount = $false
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
                ManagerLevel3 = 'CONTOSO\Jordan.VP'
                ObsPath = 'CORP.FIN.AP'
                ObsAttribute = 'extensionAttribute10'
                PotentialServiceAccount = $false
                Members = @()
            },
            [pscustomobject]@{
                Identity = 'CONTOSO\Morgan.Manager'
                SamAccountName = 'Morgan.Manager'
                DistinguishedName = 'CN=Morgan Manager,OU=Users,DC=example,DC=test'
                DisplayName = 'Morgan Manager'
                ObjectClass = 'user'
                EmployeeId = 'E2001'
                EmployeeNumber = '2001'
                UserPrincipalName = 'morgan.manager@example.test'
                Mail = 'morgan.manager@example.test'
                Department = 'Finance'
                Title = 'Finance Manager'
                Company = 'Contoso Finance'
                Office = 'HQ-4'
                AccountEnabled = 'True'
                Manager = 'CONTOSO\Riley.Director'
                ManagerLevel1 = 'CONTOSO\Riley.Director'
                ManagerLevel2 = 'CONTOSO\Jordan.VP'
                ManagerLevel3 = ''
                ObsPath = 'CORP.FIN'
                ObsAttribute = 'extensionAttribute10'
                PotentialServiceAccount = $false
                Members = @()
            },
            [pscustomobject]@{
                Identity = 'CONTOSO\Riley.Director'
                SamAccountName = 'Riley.Director'
                DistinguishedName = 'CN=Riley Director,OU=Users,DC=example,DC=test'
                DisplayName = 'Riley Director'
                ObjectClass = 'user'
                EmployeeId = 'E3001'
                EmployeeNumber = '3001'
                UserPrincipalName = 'riley.director@example.test'
                Mail = 'riley.director@example.test'
                Department = 'Finance'
                Title = 'Finance Director'
                Company = 'Contoso Finance'
                Office = 'HQ-4'
                AccountEnabled = 'True'
                Manager = 'CONTOSO\Jordan.VP'
                ManagerLevel1 = 'CONTOSO\Jordan.VP'
                ManagerLevel2 = ''
                ManagerLevel3 = ''
                ObsPath = 'CORP.FIN'
                ObsAttribute = 'extensionAttribute10'
                PotentialServiceAccount = $false
                Members = @()
            },
            [pscustomobject]@{
                Identity = 'CONTOSO\Jordan.VP'
                SamAccountName = 'Jordan.VP'
                DistinguishedName = 'CN=Jordan VP,OU=Users,DC=example,DC=test'
                DisplayName = 'Jordan VP'
                ObjectClass = 'user'
                EmployeeId = 'E4001'
                EmployeeNumber = '4001'
                UserPrincipalName = 'jordan.vp@example.test'
                Mail = 'jordan.vp@example.test'
                Department = 'Finance'
                Title = 'Finance VP'
                Company = 'Contoso Finance'
                Office = 'HQ-4'
                AccountEnabled = 'True'
                Manager = ''
                ManagerLevel1 = ''
                ManagerLevel2 = ''
                ManagerLevel3 = ''
                ObsPath = 'CORP.FIN'
                ObsAttribute = 'extensionAttribute10'
                PotentialServiceAccount = $false
                Members = @()
            },
            [pscustomobject]@{
                Identity = 'CONTOSO\svc.ShareBot'
                SamAccountName = 'svc.ShareBot'
                DistinguishedName = 'CN=svc ShareBot,OU=Service Accounts,DC=example,DC=test'
                DisplayName = 'svc ShareBot'
                ObjectClass = 'user'
                EmployeeId = ''
                EmployeeNumber = ''
                UserPrincipalName = ''
                Mail = ''
                Department = ''
                Title = 'Automation Account'
                Company = 'Contoso Finance'
                Office = ''
                AccountEnabled = 'True'
                Manager = ''
                ManagerLevel1 = ''
                ManagerLevel2 = ''
                ManagerLevel3 = ''
                ObsPath = ''
                ObsAttribute = 'extensionAttribute10'
                PotentialServiceAccount = $true
                Members = @()
            }
        )
    }
}

function New-TestDiscountedPrincipalInventory {
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
            },
            [pscustomobject]@{
                ShareId = 'share-legal'
                Source = 'Fixture'
                ComputerName = 'files01'
                ShareName = 'Legal'
                UNCPath = '\\files01\Legal'
                LocalPath = 'C:\ShareSurferLab\Legal'
                Description = 'Legal test share'
                PartialData = $false
                PartialReason = ''
            }
        )
        Items = @(
            [pscustomobject]@{
                ItemId = 'item-finance-root'
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
                ItemId = 'item-legal-root'
                ShareId = 'share-legal'
                ItemType = 'Directory'
                FullPath = '\\files01\Legal'
                RelativePath = ''
                Depth = 0
                Owner = 'CONTOSO\LegalOwner'
                InheritanceEnabled = $true
                InheritanceBrokenAt = ''
            }
        )
        SharePermissions = @(
            [pscustomobject]@{
                ShareId = 'share-finance'
                Identity = 'CONTOSO\HelpDeskOps'
                Rights = 'Full'
                AccessControlType = 'Allow'
                Source = 'Get-SmbShareAccess'
            },
            [pscustomobject]@{
                ShareId = 'share-legal'
                Identity = 'CONTOSO\HelpDeskOps'
                Rights = 'Full'
                AccessControlType = 'Allow'
                Source = 'Get-SmbShareAccess'
            }
        )
        AclEntries = @()
        Identities = @(
            [pscustomobject]@{
                Identity = 'CONTOSO\HelpDeskOps'
                SamAccountName = 'HelpDeskOps'
                DisplayName = 'HelpDesk Operators'
                ObjectClass = 'group'
                EmployeeId = ''
                EmployeeNumber = ''
                UserPrincipalName = ''
                Mail = 'helpdesk@example.test'
                Department = 'Technology Support'
                Title = ''
                Company = 'Contoso'
                Office = 'HQ-IT'
                AccountEnabled = ''
                Manager = ''
                ManagerLevel1 = 'CONTOSO\IT.Manager'
                ManagerLevel2 = ''
                ManagerLevel3 = ''
                ObsPath = 'CORP.IT.HELPDESK'
                ObsAttribute = 'extensionAttribute10'
                PotentialServiceAccount = $false
                DistinguishedName = 'CN=HelpDesk Operators,OU=Groups,DC=example,DC=test'
            }
        )
        GroupEdges = @(
            [pscustomobject]@{
                ParentGroup = 'CONTOSO\HelpDeskOps'
                ChildIdentity = 'CONTOSO\Casey.Support'
                ChildObjectClass = 'user'
                Depth = 1
                IsCycle = $false
                IsTruncated = $false
            }
        )
        OrgChains = @()
        OwnerMappings = @(
            [pscustomobject]@{
                Pattern = '\\files01\Finance*'
                Owner = 'Finance Operations'
                BusinessUnit = 'Finance'
                Source = 'unit-test'
            },
            [pscustomobject]@{
                Pattern = '\\files01\Legal*'
                Owner = 'Legal Operations'
                BusinessUnit = 'Legal'
                Source = 'unit-test'
            }
        )
        IdentityDirectory = @()
    }
}

function New-TestMigrationDiscoveryQualityInventory {
    [pscustomobject]@{
        Shares = @(
            [pscustomobject]@{
                ShareId = 'share-finance-ap-active'
                Source = 'Fixture'
                ComputerName = 'files01'
                ShareName = 'Finance-AP'
                UNCPath = '\\files01\Finance-AP'
                LocalPath = 'C:\ShareSurferLab\Finance-AP'
                Description = 'Finance AP active share'
                PartialData = $false
                PartialReason = ''
            },
            [pscustomobject]@{
                ShareId = 'share-finance-ap-archive'
                Source = 'Fixture'
                ComputerName = 'files02'
                ShareName = 'Finance-AP-Archive'
                UNCPath = '\\files02\Finance-AP-Archive'
                LocalPath = 'D:\ShareSurferLab\Finance-AP-Archive'
                Description = 'Finance AP archive share'
                PartialData = $false
                PartialReason = ''
            },
            [pscustomobject]@{
                ShareId = 'share-legal-ap-hold'
                Source = 'Fixture'
                ComputerName = 'files01'
                ShareName = 'Legal-AP-Hold'
                UNCPath = '\\files01\Legal-AP-Hold'
                LocalPath = 'C:\ShareSurferLab\Legal-AP-Hold'
                Description = 'Legal AP hold share'
                PartialData = $false
                PartialReason = ''
            },
            [pscustomobject]@{
                ShareId = 'share-project-phoenix'
                Source = 'Fixture'
                ComputerName = 'files03'
                ShareName = 'Project-Phoenix'
                UNCPath = '\\files03\Project-Phoenix'
                LocalPath = 'C:\ShareSurferLab\Project-Phoenix'
                Description = 'Project Phoenix collaboration share'
                PartialData = $false
                PartialReason = ''
            },
            [pscustomobject]@{
                ShareId = 'share-legacy-unknown'
                Source = 'Fixture'
                ComputerName = 'files04'
                ShareName = 'Legacy-Unknown'
                UNCPath = '\\files04\Legacy-Unknown'
                LocalPath = 'C:\ShareSurferLab\Legacy-Unknown'
                Description = 'Legacy share with insufficient ownership evidence'
                PartialData = $false
                PartialReason = ''
            }
        )
        Items = @(
            [pscustomobject]@{
                ItemId = 'item-finance-ap-active-root'
                ShareId = 'share-finance-ap-active'
                ItemType = 'Directory'
                FullPath = '\\files01\Finance-AP'
                RelativePath = ''
                Depth = 0
                Owner = 'CONTOSO\FinanceOwner'
                InheritanceEnabled = $true
                InheritanceBrokenAt = ''
            },
            [pscustomobject]@{
                ItemId = 'item-finance-ap-active-invoices'
                ShareId = 'share-finance-ap-active'
                ItemType = 'Directory'
                FullPath = '\\files01\Finance-AP\Invoices'
                RelativePath = 'Invoices'
                Depth = 1
                Owner = 'CONTOSO\FinanceOwner'
                InheritanceEnabled = $true
                InheritanceBrokenAt = ''
            },
            [pscustomobject]@{
                ItemId = 'item-finance-ap-archive-root'
                ShareId = 'share-finance-ap-archive'
                ItemType = 'Directory'
                FullPath = '\\files02\Finance-AP-Archive'
                RelativePath = ''
                Depth = 0
                Owner = 'CONTOSO\FinanceOwner'
                InheritanceEnabled = $true
                InheritanceBrokenAt = ''
            },
            [pscustomobject]@{
                ItemId = 'item-finance-ap-archive-deep'
                ShareId = 'share-finance-ap-archive'
                ItemType = 'Directory'
                FullPath = '\\files02\Finance-AP-Archive\FY2024\Closed\Invoices\Vendor'
                RelativePath = 'FY2024\Closed\Invoices\Vendor'
                Depth = 4
                Owner = 'CONTOSO\FinanceOwner'
                InheritanceEnabled = $true
                InheritanceBrokenAt = ''
            },
            [pscustomobject]@{
                ItemId = 'item-legal-ap-hold-root'
                ShareId = 'share-legal-ap-hold'
                ItemType = 'Directory'
                FullPath = '\\files01\Legal-AP-Hold'
                RelativePath = ''
                Depth = 0
                Owner = 'CONTOSO\LegalOwner'
                InheritanceEnabled = $true
                InheritanceBrokenAt = ''
            },
            [pscustomobject]@{
                ItemId = 'item-project-phoenix-root'
                ShareId = 'share-project-phoenix'
                ItemType = 'Directory'
                FullPath = '\\files03\Project-Phoenix'
                RelativePath = ''
                Depth = 0
                Owner = 'CONTOSO\ProjectOwner'
                InheritanceEnabled = $true
                InheritanceBrokenAt = ''
            },
            [pscustomobject]@{
                ItemId = 'item-legacy-unknown-root'
                ShareId = 'share-legacy-unknown'
                ItemType = 'Directory'
                FullPath = '\\files04\Legacy-Unknown'
                RelativePath = ''
                Depth = 0
                Owner = 'CONTOSO\LegacyOwner'
                InheritanceEnabled = $true
                InheritanceBrokenAt = ''
            }
        )
        SharePermissions = @(
            [pscustomobject]@{ ShareId = 'share-finance-ap-active'; Identity = 'CONTOSO\FinanceAPAccess'; Rights = 'Read'; AccessControlType = 'Allow'; Source = 'quality-harness' },
            [pscustomobject]@{ ShareId = 'share-finance-ap-active'; Identity = 'CONTOSO\HelpDeskOps'; Rights = 'Full'; AccessControlType = 'Allow'; Source = 'quality-harness' },
            [pscustomobject]@{ ShareId = 'share-finance-ap-archive'; Identity = 'CONTOSO\FinanceAPAccess'; Rights = 'Read'; AccessControlType = 'Allow'; Source = 'quality-harness' },
            [pscustomobject]@{ ShareId = 'share-finance-ap-archive'; Identity = 'CONTOSO\HelpDeskOps'; Rights = 'Full'; AccessControlType = 'Allow'; Source = 'quality-harness' },
            [pscustomobject]@{ ShareId = 'share-legal-ap-hold'; Identity = 'CONTOSO\LegalHoldAccess'; Rights = 'Change'; AccessControlType = 'Allow'; Source = 'quality-harness' },
            [pscustomobject]@{ ShareId = 'share-legal-ap-hold'; Identity = 'CONTOSO\HelpDeskOps'; Rights = 'Full'; AccessControlType = 'Allow'; Source = 'quality-harness' },
            [pscustomobject]@{ ShareId = 'share-project-phoenix'; Identity = 'CONTOSO\HelpDeskOps'; Rights = 'Full'; AccessControlType = 'Allow'; Source = 'quality-harness' },
            [pscustomobject]@{ ShareId = 'share-legacy-unknown'; Identity = 'CONTOSO\HelpDeskOps'; Rights = 'Full'; AccessControlType = 'Allow'; Source = 'quality-harness' }
        )
        AclEntries = @(
            [pscustomobject]@{
                ItemId = 'item-finance-ap-archive-deep'
                ShareId = 'share-finance-ap-archive'
                FullPath = '\\files02\Finance-AP-Archive\FY2024\Closed\Invoices\Vendor'
                Identity = 'CONTOSO\FinanceAPAccess'
                Rights = 'Modify'
                AccessControlType = 'Allow'
                IsInherited = $false
                InheritanceFlags = 'ContainerInherit,ObjectInherit'
                PropagationFlags = 'None'
                Depth = 4
            }
        )
        Identities = @(
            [pscustomobject]@{ Identity = 'CONTOSO\FinanceAPAccess'; SamAccountName = 'FinanceAPAccess'; DisplayName = 'Finance AP Access'; ObjectClass = 'group'; EmployeeId = ''; EmployeeNumber = ''; UserPrincipalName = ''; Mail = 'finance.ap.access@example.test'; Department = 'Accounts Payable'; Title = ''; Company = 'Contoso Finance'; Office = 'HQ-4'; AccountEnabled = ''; Manager = ''; ManagerLevel1 = ''; ManagerLevel2 = ''; ManagerLevel3 = ''; ObsPath = 'CORP.FIN.AP'; ObsAttribute = 'extensionAttribute10'; PotentialServiceAccount = $false; DistinguishedName = 'CN=Finance AP Access,OU=Groups,DC=example,DC=test' },
            [pscustomobject]@{ Identity = 'CONTOSO\LegalHoldAccess'; SamAccountName = 'LegalHoldAccess'; DisplayName = 'Legal Hold Access'; ObjectClass = 'group'; EmployeeId = ''; EmployeeNumber = ''; UserPrincipalName = ''; Mail = 'legal.hold.access@example.test'; Department = 'Legal'; Title = ''; Company = 'Contoso Legal'; Office = 'HQ-3'; AccountEnabled = ''; Manager = ''; ManagerLevel1 = ''; ManagerLevel2 = ''; ManagerLevel3 = ''; ObsPath = 'CORP.LEGAL'; ObsAttribute = 'extensionAttribute10'; PotentialServiceAccount = $false; DistinguishedName = 'CN=Legal Hold Access,OU=Groups,DC=example,DC=test' },
            [pscustomobject]@{ Identity = 'CONTOSO\HelpDeskOps'; SamAccountName = 'HelpDeskOps'; DisplayName = 'HelpDesk Operators'; ObjectClass = 'group'; EmployeeId = ''; EmployeeNumber = ''; UserPrincipalName = ''; Mail = 'helpdesk@example.test'; Department = 'Technology Support'; Title = ''; Company = 'Contoso'; Office = 'HQ-IT'; AccountEnabled = ''; Manager = ''; ManagerLevel1 = 'CONTOSO\IT.Manager'; ManagerLevel2 = ''; ManagerLevel3 = ''; ObsPath = 'CORP.IT.HELPDESK'; ObsAttribute = 'extensionAttribute10'; PotentialServiceAccount = $false; DistinguishedName = 'CN=HelpDesk Operators,OU=Groups,DC=example,DC=test' }
        )
        GroupEdges = @(
            [pscustomobject]@{ ParentGroup = 'CONTOSO\FinanceAPAccess'; ChildIdentity = 'CONTOSO\Ava.Accounting'; ChildObjectClass = 'user'; Depth = 1; IsCycle = $false; IsTruncated = $false },
            [pscustomobject]@{ ParentGroup = 'CONTOSO\LegalHoldAccess'; ChildIdentity = 'CONTOSO\Lena.Legal'; ChildObjectClass = 'user'; Depth = 1; IsCycle = $false; IsTruncated = $false },
            [pscustomobject]@{ ParentGroup = 'CONTOSO\HelpDeskOps'; ChildIdentity = 'CONTOSO\Casey.Support'; ChildObjectClass = 'user'; Depth = 1; IsCycle = $false; IsTruncated = $false }
        )
        OrgChains = @()
        OwnerMappings = @(
            [pscustomobject]@{ Pattern = '\\files??\Finance-AP*'; Owner = 'Accounts Payable'; BusinessUnit = 'Finance'; Source = 'migration-quality-harness' },
            [pscustomobject]@{ Pattern = '\\files??\Legal-AP*'; Owner = 'Legal Operations'; BusinessUnit = 'Legal'; Source = 'migration-quality-harness' },
            [pscustomobject]@{ Pattern = '\\files03\Project-Phoenix*'; Owner = 'Project Phoenix'; BusinessUnit = ''; Source = 'migration-quality-harness' },
            [pscustomobject]@{ Pattern = '\\files04\Legacy-Unknown*'; Owner = ''; BusinessUnit = ''; Source = 'migration-quality-harness' }
        )
        IdentityDirectory = @()
    }
}

$tests = @(
    @{
        Name = 'Archived enterprise proof verifier refreshes to temp output and validates current export schema'
        Body = {
            $verifierScript = Join-Path $repoRoot 'scripts/Test-ShareSurferArchivedEnterpriseProof.ps1'

            Assert-True (Test-Path -LiteralPath $verifierScript) 'Repository should include a one-command archived enterprise proof verifier.'
            $verifierText = Get-Content -LiteralPath $verifierScript -Raw
            Assert-True ($verifierText -like '*windows-ad-enterprise-20260605-101639*20260605-101639*') 'Verifier should default to the archived enterprise proof run root.'
            Assert-True ($verifierText -like '*New-ShareSurferArchivedEvidenceRefresh.ps1*') 'Verifier should call the archived evidence refresh flow.'
            Assert-True ($verifierText -like '*Test-ShareSurferExport*') 'Verifier should explicitly validate the regenerated export schema.'

            $result = & $verifierScript
            $expectedProperties = 'IsValid,OutputPath,ExportPath,AcceptanceIsValid,AcceptanceFailedCheckCount,LiveEvidenceIsValid,LiveEvidenceFallbackCount,MissingFiles,SchemaErrorCount'

            Assert-Equal (@($result.PSObject.Properties.Name) -join ',') $expectedProperties 'Verifier should emit the small integration object expected by automation.'
            Assert-True ([bool]$result.IsValid) 'Archived enterprise proof should be valid against the current verifier.'
            Assert-True ([bool]$result.AcceptanceIsValid) 'Archived enterprise proof should pass V1 acceptance.'
            Assert-Equal ([int]$result.AcceptanceFailedCheckCount) 0 'Archived enterprise proof should have no failed acceptance checks.'
            Assert-True ([bool]$result.LiveEvidenceIsValid) 'Archived enterprise proof should pass the live evidence gate.'
            Assert-Equal ([int]$result.LiveEvidenceFallbackCount) 0 'Archived enterprise proof should have no live evidence fallbacks.'
            Assert-Equal (@($result.MissingFiles).Count) 0 'Regenerated export should not be missing current schema files.'
            Assert-Equal ([int]$result.SchemaErrorCount) 0 'Regenerated export should have no current schema errors.'

            $outputFullPath = [System.IO.Path]::GetFullPath([string]$result.OutputPath)
            $repoFullPath = [System.IO.Path]::GetFullPath($repoRoot)
            Assert-True (-not $outputFullPath.StartsWith($repoFullPath, [System.StringComparison]::OrdinalIgnoreCase)) 'Verifier default output should be outside the repository.'
            Assert-Equal ([string]$result.ExportPath) (Join-Path ([string]$result.OutputPath) 'export') 'Verifier should validate the export regenerated inside the output path.'
            Assert-True (Test-Path -LiteralPath ([string]$result.ExportPath) -PathType Container) 'Verifier should leave the regenerated export in the output path.'
            Assert-True (Test-Path -LiteralPath (Join-Path ([string]$result.ExportPath) 'discounted_principals.csv')) 'Regenerated export should include the current discounted principals schema file.'
        }
    },
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
            Assert-True ($fixtureScript.Contains('$aclFilesystemPath = ConvertTo-ShareSurferLabFilesystemPath -Path $aclTargetPath')) 'Lab fixture should prepare ACL target paths through extended-length path handling.'
            Assert-True ($fixtureScript.Contains('Get-Acl -LiteralPath $aclFilesystemPath')) 'Lab fixture should read ACLs through extended-length path handling.'
            Assert-True ($fixtureScript.Contains('Set-Acl -LiteralPath $aclFilesystemPath')) 'Lab fixture should write ACLs through extended-length path handling.'
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
            New-Item -ItemType Directory -Path (Join-Path $labRoot 'Share001\A\B\C\D\E') -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $labRoot 'Share001\A\B\C\D\E\deep-file.txt') -Value 'deep evidence file' -Encoding UTF8

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
                [pscustomobject]@{ ShareId = 'share-001'; Identity = 'CONTOSO\Readers'; Rights = 'Read'; AccessMask = ''; AccessControlType = 'Allow'; Source = 'Get-SmbShareAccess' }
            ) | Export-Csv -LiteralPath (Join-Path $exportPath 'share_permissions.csv') -NoTypeInformation -Encoding UTF8
            @(
                [pscustomobject]@{ ErrorId = 'collection-error-001'; ShareId = 'share-002'; ItemId = ''; FullPath = '\\files01\Share002'; ErrorType = 'SharePermissionCollectionUnavailable'; Message = 'Share permission proof was unavailable'; Detail = 'Unit test collection gap evidence' }
                [pscustomobject]@{ ErrorId = 'collection-error-002'; ShareId = 'share-001'; ItemId = 'item-001'; FullPath = '\\files01\Share001\Deep\Path\file01.txt'; ErrorType = 'AclReadError'; Message = 'ACL read failed'; Detail = 'Unit test ACL error evidence' }
            ) | Export-Csv -LiteralPath (Join-Path $exportPath 'collection_errors.csv') -NoTypeInformation -Encoding UTF8
            @(
                [pscustomobject]@{ ItemId = 'item-001'; ShareId = 'share-001'; FullPath = '\\files01\Share001\Deep\Path\file01.txt'; Identity = 'CONTOSO\Editors'; Rights = 'Modify'; AccessMask = ''; AccessControlType = 'Allow'; IsInherited = 'False'; InheritanceFlags = 'ContainerInherit,ObjectInherit'; PropagationFlags = 'None'; Depth = '7' },
                [pscustomobject]@{ ItemId = 'item-002'; ShareId = 'share-001'; FullPath = '\\files01\Share001\file02.txt'; Identity = 'CONTOSO\FileReaders'; Rights = 'Read'; AccessMask = ''; AccessControlType = 'Allow'; IsInherited = 'False'; InheritanceFlags = 'None'; PropagationFlags = 'None'; Depth = '1' }
            ) | Export-Csv -LiteralPath (Join-Path $exportPath 'acl_entries.csv') -NoTypeInformation -Encoding UTF8
            @(
                [pscustomobject]@{ ParentGroup = 'CONTOSO\Readers'; ChildIdentity = 'CONTOSO\SSUser00001'; ChildObjectClass = 'user'; Depth = '1'; IsCycle = 'False'; IsTruncated = 'False' }
            ) | Export-Csv -LiteralPath (Join-Path $exportPath 'group_edges.csv') -NoTypeInformation -Encoding UTF8
            Set-Content -LiteralPath (Join-Path $exportPath 'discounted_principals.csv') -Value '"Identity","Reason","Scope","MatchType"' -Encoding UTF8
            @(
                [pscustomobject]@{ Identity = 'CONTOSO\Readers'; SamAccountName = 'Readers'; DisplayName = 'Readers'; ObjectClass = 'group'; EmployeeId = ''; EmployeeNumber = ''; Manager = ''; ManagerLevel1 = ''; ManagerLevel2 = ''; ManagerLevel3 = ''; ObsPath = 'CORP.TEST.READ'; ObsAttribute = 'extensionAttribute10'; PotentialServiceAccount = 'False' },
                [pscustomobject]@{ Identity = 'CONTOSO\Editors'; SamAccountName = 'Editors'; DisplayName = 'Editors'; ObjectClass = 'group'; EmployeeId = ''; EmployeeNumber = ''; Manager = ''; ManagerLevel1 = ''; ManagerLevel2 = ''; ManagerLevel3 = ''; ObsPath = 'CORP.TEST.MODIFY'; ObsAttribute = 'extensionAttribute10'; PotentialServiceAccount = 'False' },
                [pscustomobject]@{ Identity = 'CONTOSO\FileReaders'; SamAccountName = 'FileReaders'; DisplayName = 'File Readers'; ObjectClass = 'group'; EmployeeId = ''; EmployeeNumber = ''; Manager = ''; ManagerLevel1 = ''; ManagerLevel2 = ''; ManagerLevel3 = ''; ObsPath = 'CORP.TEST.FILE'; ObsAttribute = 'extensionAttribute10'; PotentialServiceAccount = 'False' },
                [pscustomobject]@{ Identity = 'CONTOSO\SSUser00001'; SamAccountName = 'SSUser00001'; DisplayName = 'ShareSurfer User 00001'; ObjectClass = 'user'; EmployeeId = 'E0000001'; EmployeeNumber = '0000001'; Manager = 'CONTOSO\Manager01'; ManagerLevel1 = 'CONTOSO\Manager01'; ManagerLevel2 = 'CONTOSO\Director01'; ManagerLevel3 = 'CONTOSO\VP01'; ObsPath = 'CORP.TEST.USER'; ObsAttribute = 'extensionAttribute10'; PotentialServiceAccount = 'False' }
            ) | Export-Csv -LiteralPath (Join-Path $exportPath 'identities.csv') -NoTypeInformation -Encoding UTF8
            @(
                [pscustomobject]@{ Identity = 'CONTOSO\SSUser00001'; EmployeeId = 'E0000001'; EmployeeNumber = '0000001'; ManagerLevel1 = 'CONTOSO\Manager01'; ManagerLevel2 = 'CONTOSO\Director01'; ManagerLevel3 = 'CONTOSO\VP01'; ObsPath = 'CORP.TEST.USER'; ObsAttribute = 'extensionAttribute10'; PotentialServiceAccount = 'False' }
            ) | Export-Csv -LiteralPath (Join-Path $exportPath 'org_chains.csv') -NoTypeInformation -Encoding UTF8
            @(
                [pscustomobject]@{ BusinessUnit = 'Finance'; Owner = 'Finance Operations'; Pattern = '\\files01\Share001*'; Source = 'unit-test'; MatchingItems = '2'; Directories = '0'; Files = '2'; FindingCount = '3'; ConflictCount = '1'; PartialShareCount = '0'; DirectIdentityCount = '3'; DirectGroupCount = '3'; ExpandedMemberCount = '1'; RiskLevel = 'High'; ReadinessSignals = 'broken inheritance; conflicts; deep explicit ACE; long path'; DiscountedPrincipal = 'False'; DiscountedPrincipalCount = '0'; DiscountedGroupCount = '0'; DiscountedPrincipals = ''; DiscountReason = '' }
            ) | Export-Csv -LiteralPath (Join-Path $exportPath 'owner_risk_pivots.csv') -NoTypeInformation -Encoding UTF8
            @(
                [pscustomobject]@{ RelatedAreaId = 'related-area-0001'; RelatedDataArea = 'Finance / Finance Operations'; BusinessUnit = 'Finance'; Owner = 'Finance Operations'; Pattern = '\\files01\Share001*'; Source = 'unit-test'; RelatednessStrength = 'Strong'; RelationshipSignalCount = '3'; SupportingSignalCount = '1'; ReadinessSignalCount = '4'; RelationshipSignals = 'same business unit; same owner; shared non-discounted business permission group'; SupportingEvidence = 'path/share/folder naming similarity'; ReadinessSignals = 'broken inheritance; conflicts; deep explicit ACE; long path'; CoreFiveChips = 'Confidence: Strong | Relationship: same owner + same business unit | Readiness: Review | Discounted access: 0 | Evidence: Complete with readiness review'; EvidenceCompleteness = 'Complete with readiness review'; RiskLevel = 'High'; MigrationReadiness = 'Review'; MatchingShares = '1'; MatchingItems = '2'; Directories = '0'; Files = '2'; FindingCount = '3'; ConflictCount = '1'; ReviewItemCount = '4'; PartialShareCount = '0'; DirectIdentityCount = '3'; DirectGroupCount = '3'; ExpandedMemberCount = '1'; RelatedBecauseShort = 'This area appears together because strong confidence; same owner; same business unit; shared non-discounted business permission group; path/share/folder naming similarity.'; RelatedBecause = 'Strong confidence; same owner; same business unit; shared non-discounted business permission group; path/share/folder naming similarity'; SuggestedNextAction = 'Review ownership, access groups, findings, and conflicts before migration planning.'; DiscountedPrincipal = 'False'; DiscountedPrincipalCount = '0'; DiscountedGroupCount = '0'; DiscountedPrincipals = ''; DiscountReason = '' }
            ) | Export-Csv -LiteralPath (Join-Path $exportPath 'related_data_areas.csv') -NoTypeInformation -Encoding UTF8
            @(
                [pscustomobject]@{ ReviewPacketId = 'owner-review-0001'; BusinessUnit = 'Finance'; Owner = 'Finance Operations'; Pattern = '\\files01\Share001*'; Source = 'unit-test'; RiskLevel = 'High'; ReviewStatus = 'High priority review'; WhyReview = 'high-priority access or migration risk; permission-bearing security groups'; WhatToReviewFirst = 'access conflicts; findings; permissioned groups'; SuggestedNextAction = 'Confirm ownership, review assigned groups, and document the remediation decision.'; MatchingItems = '2'; Directories = '0'; Files = '2'; FindingCount = '3'; ConflictCount = '1'; PartialShareCount = '0'; DirectIdentityCount = '3'; DirectGroupCount = '3'; ExpandedMemberCount = '1'; MigrationReadiness = 'Review'; RelatedDataAreaCount = '1'; RelatednessStrength = 'Strong'; RelationshipSignalCount = '3'; ReadinessSignals = 'broken inheritance; conflicts; deep explicit ACE; long path'; DiscountedPrincipal = 'False'; DiscountedPrincipalCount = '0'; DiscountedGroupCount = '0'; DiscountedPrincipals = ''; DiscountReason = '' }
            ) | Export-Csv -LiteralPath (Join-Path $exportPath 'owner_review_packets.csv') -NoTypeInformation -Encoding UTF8
            @(
                [pscustomobject]@{ ScanId = 'scan-001'; GeneratedAt = '2026-06-05T00:00:00Z'; ExportVersion = '1'; ObsAttribute = 'extensionAttribute10'; SourceMode = 'SmbShare'; CollectionProvider = 'Auto'; OperationalPathLengthThreshold = '256'; AzurePathComponentLimit = '255'; AzureFullPathLimit = '2048'; ExplicitAceDepthThreshold = '2'; GroupExpansionMaxDepth = '20'; AdLookupMode = 'DirectoryOnly'; ManagerIdentityFormat = 'MailTo'; AclExportMode = 'FullEffective'; FullAclEntryCount = '2'; ExportedAclEntryCount = '2'; SuppressedInheritedAclEntryCount = '0'; IncludeFiles = 'True' }
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
                    [pscustomobject]@{ Name = 'FocusedAclScenarios'; Required = $true; MinimumValue = 1; Unit = 'acl scenarios'; Description = 'Focused ACL scenarios' },
                    [pscustomobject]@{ Name = 'EnterpriseUserPopulation'; Required = $true; MinimumValue = 3; Unit = 'users'; Description = 'Users' },
                    [pscustomobject]@{ Name = 'EnterpriseGroupPopulation'; Required = $true; MinimumValue = 2; Unit = 'groups'; Description = 'Groups' },
                    [pscustomobject]@{ Name = 'EnterpriseEmployeeIdentifierCoverage'; Required = $true; MinimumValue = 1; Unit = 'users with employee identifiers'; Description = 'Employee identifiers' },
                    [pscustomobject]@{ Name = 'EnterpriseManagerChainCoverage'; Required = $true; MinimumValue = 1; Unit = 'three-level manager chains'; Description = 'Manager chains' },
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

            $fileEvidence = Get-ShareSurferLabValidationFileEvidence -LabRoot $labRoot
            Assert-True ([bool]$fileEvidence.Available) 'Validation file evidence helper should enumerate the lab root when it exists.'
            Assert-Equal ([int]$fileEvidence.FileCount) 2 'Validation file evidence helper should count real filesystem files.'
            Assert-Equal ([int]$fileEvidence.DeepFileCount) 1 'Validation file evidence helper should count deep filesystem files using display paths.'
            Assert-True ([int64]$fileEvidence.TotalBytes -gt 0) 'Validation file evidence helper should sum real file bytes.'
            Assert-Equal (ConvertTo-ShareSurferLabValidationFilesystemPath -Path 'C:\ShareSurferLab\Finance') '\\?\C:\ShareSurferLab\Finance' 'Validation helper should convert Windows drive paths to extended-length paths.'
            Assert-Equal (ConvertTo-ShareSurferLabValidationFilesystemPath -Path '\\files01\Finance') '\\?\UNC\files01\Finance' 'Validation helper should convert UNC paths to extended-length paths.'
            Assert-Equal (ConvertFrom-ShareSurferLabValidationFilesystemPath -Path '\\?\UNC\files01\Finance') '\\files01\Finance' 'Validation helper should restore display UNC paths.'

            $criteria = @(New-ShareSurferLabValidationCriteriaRows -Plan $plan -ExportPath $exportPath -LabRoot $labRoot -CreateLab -IncludeFiles)
            $focusedAclCriterion = @($criteria | Where-Object { $_.Name -eq 'FocusedAclScenarios' })[0]
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

            Assert-True ([int]$focusedAclCriterion.ActualValue -ge 1) 'Focused ACL validation should use scan/export evidence when ACL, finding, conflict, or ownership evidence exists.'
            Assert-Equal $focusedAclCriterion.EvidenceSource 'ScanExport:acl_entries.csv;findings.csv;conflicts.csv;items.csv' 'Focused ACL validation should not remain plan-only when live scan/export evidence proves ACL scenarios.'
            Assert-True ([string]$focusedAclCriterion.EvidenceDetail -like '*PlanAclScenarios=2*') 'Focused ACL validation should retain the planned ACL scenario count in detail.'
            Assert-Equal ([int]$userCriterion.ActualValue) 4 'User validation should prefer directory counts when available.'
            Assert-Equal $userCriterion.EvidenceSource 'ActiveDirectory' 'User validation should identify directory evidence.'
            Assert-Equal ([int]$groupPopulationCriterion.ActualValue) 2 'Group validation should prefer directory counts when available.'
            Assert-Equal $groupPopulationCriterion.EvidenceSource 'ActiveDirectory' 'Group validation should identify directory evidence.'
            Assert-True ([string]$groupPopulationCriterion.EvidenceDetail -like '*DirectoryGroups=2*') 'Group population evidence should record directory group counts.'
            Assert-Equal ([int]$employeeIdentifierCriterion.ActualValue) 1 'Employee identifier validation should count enriched user identities.'
            Assert-Equal $employeeIdentifierCriterion.EvidenceSource 'ScanExport:identities.csv' 'Employee identifier validation should identify identity export evidence.'
            Assert-True ([string]$employeeIdentifierCriterion.EvidenceDetail -like '*UsersWithEmployeeIdentifiers=1*') 'Employee identifier evidence should record enriched user counts.'
            Assert-Equal ([int]$managerChainCriterion.ActualValue) 1 'Manager-chain validation should count three-level manager evidence.'
            Assert-Equal $managerChainCriterion.EvidenceSource 'ScanExport:identities.csv' 'Manager-chain validation should prefer identity export evidence when present.'
            Assert-True ([string]$managerChainCriterion.EvidenceDetail -like '*OrgChainThreeLevelManagerChains=1*') 'Manager-chain evidence should record org-chain export counts.'
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
                [pscustomobject]@{ ScanId = 'scan-001'; GeneratedAt = '2026-06-05T00:00:00Z'; ExportVersion = '1'; ObsAttribute = 'extensionAttribute10'; SourceMode = 'SmbShare'; CollectionProvider = 'Auto'; OperationalPathLengthThreshold = '256'; AzurePathComponentLimit = '255'; AzureFullPathLimit = '2048'; ExplicitAceDepthThreshold = '2'; GroupExpansionMaxDepth = '20'; AdLookupMode = 'DirectoryOnly'; ManagerIdentityFormat = 'MailTo'; AclExportMode = 'FullEffective'; FullAclEntryCount = '0'; ExportedAclEntryCount = '0'; SuppressedInheritedAclEntryCount = '0'; IncludeFiles = 'False' }
            ) | Export-Csv -LiteralPath (Join-Path $exportPath 'scan_manifest.csv') -NoTypeInformation -Encoding UTF8
            $mismatchedManifestCriteria = @(New-ShareSurferLabValidationCriteriaRows -Plan $plan -ExportPath $exportPath -LabRoot $labRoot -CreateLab -IncludeFiles)
            $mismatchedManifestFileCriterion = @($mismatchedManifestCriteria | Where-Object { $_.Name -eq 'EnterpriseRealFiles' })[0]
            Assert-True (-not [bool]$mismatchedManifestFileCriterion.Passed) 'File validation should fail when scanned file rows disagree with the IncludeFiles manifest setting.'
            Assert-Equal $mismatchedManifestFileCriterion.EvidenceSource 'ScanExportMismatch:scan_manifest.csv' 'File validation should identify mismatched scan manifest evidence.'
            Assert-True ([string]$mismatchedManifestFileCriterion.EvidenceDetail -like '*ManifestIncludeFiles=False*') 'Mismatched file evidence should show the manifest IncludeFiles value.'
            @(
                [pscustomobject]@{ ScanId = 'scan-001'; GeneratedAt = '2026-06-05T00:00:00Z'; ExportVersion = '1'; ObsAttribute = 'extensionAttribute10'; SourceMode = 'SmbShare'; CollectionProvider = 'Auto'; OperationalPathLengthThreshold = '256'; AzurePathComponentLimit = '255'; AzureFullPathLimit = '2048'; ExplicitAceDepthThreshold = '2'; GroupExpansionMaxDepth = '20'; AdLookupMode = 'DirectoryOnly'; ManagerIdentityFormat = 'MailTo'; AclExportMode = 'FullEffective'; FullAclEntryCount = '0'; ExportedAclEntryCount = '0'; SuppressedInheritedAclEntryCount = '0'; IncludeFiles = 'True' }
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
                'discounted_principals.csv',
                'permissioned_groups.csv',
                'org_chains.csv',
                'owner_mappings.csv',
                'owner_risk_pivots.csv',
                'related_data_areas.csv',
                'owner_review_packets.csv',
                'owner_review_decisions.csv',
                'migration_cluster_decisions.csv',
                'conflicts.csv',
                'findings.csv',
                'evidence_confidence.csv',
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
            Assert-True ($findings.FindingType -contains 'BrokenOrMissingSid') 'Findings should flag unresolved SID ACL identities separately from normal access findings.'

            $identities = Import-Csv -LiteralPath (Join-Path $outputPath 'identities.csv')
            $orgChains = Import-Csv -LiteralPath (Join-Path $outputPath 'org_chains.csv')
            foreach ($columnName in @('Title', 'Office', 'ManagerLevel3', 'ManagerLevel1Raw', 'ManagerLevel2Raw', 'ManagerLevel3Raw', 'PotentialServiceAccount')) {
                Assert-True ($identities[0].PSObject.Properties.Name -contains $columnName) ("Identity export should include {0} for owner and service-account review." -f $columnName)
            }
            foreach ($columnName in @('Office', 'ManagerLevel3', 'ManagerLevel1Raw', 'ManagerLevel2Raw', 'ManagerLevel3Raw', 'PotentialServiceAccount')) {
                Assert-True ($orgChains[0].PSObject.Properties.Name -contains $columnName) ("Org chain export should include {0} for owner and service-account review." -f $columnName)
            }

            $conflicts = Import-Csv -LiteralPath (Join-Path $outputPath 'conflicts.csv')
            Assert-True ($conflicts.ConflictType -contains 'NtfsIdentityMissingShareGate') 'Conflicts should show NTFS identities missing at the share gate.'
            foreach ($columnName in @('AffectedItemCount', 'ExamplePath', 'AffectedPathPrefix', 'FirstSeenPath', 'MaxDepth', 'EvidenceCompleteness')) {
                Assert-True ($conflicts[0].PSObject.Properties.Name -contains $columnName) ("Conflict export should include {0} for repeated conflict rollup review." -f $columnName)
            }

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
            Assert-True ($relatedDataAreas[0].PSObject.Properties.Name -contains 'RelatednessStrength') 'Related data area CSV should classify balanced relatedness strength.'
            Assert-True ($relatedDataAreas[0].PSObject.Properties.Name -contains 'RelationshipSignalCount') 'Related data area CSV should count relationship signals separately from readiness signals.'
            Assert-True ($relatedDataAreas[0].PSObject.Properties.Name -contains 'ReadinessSignals') 'Related data area CSV should explain readiness risks separately from relatedness.'
            Assert-True ($relatedDataAreas[0].PSObject.Properties.Name -contains 'CoreFiveChips') 'Related data area CSV should include Progressive Chips Core Five summary.'
            Assert-True ($relatedDataAreas[0].PSObject.Properties.Name -contains 'EvidenceCompleteness') 'Related data area CSV should include evidence completeness for adaptive rows.'
            Assert-True ($relatedDataAreas[0].PSObject.Properties.Name -contains 'RelatedBecauseShort') 'Related data area CSV should include an adaptive-row short related-because sentence.'
            Assert-True ($relatedDataAreas[0].CoreFiveChips -like '*Confidence:*' -and $relatedDataAreas[0].CoreFiveChips -like '*Discounted access:*') 'Core Five chips should include confidence and discounted access presence.'
            Assert-True ($relatedDataAreas[0].RelatedBecause -notlike '*shared review risk*') 'Readiness risks should not create relatedness explanations.'
            Assert-True ($relatedDataAreas[0].ReadinessSignals -like '*finding*' -or $relatedDataAreas[0].ReadinessSignals -like '*conflict*') 'Readiness signals should preserve review-priority evidence.'
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

            $confidenceRows = @(Import-Csv -LiteralPath (Join-Path $outputPath 'evidence_confidence.csv'))
            Assert-Equal $confidenceRows.Count 2 'Evidence confidence export should include one scan-level row plus one row per share.'
            Assert-Equal $confidenceRows[0].Scope 'Scan' 'Evidence confidence should identify its review scope.'
            Assert-Equal $confidenceRows[1].Scope 'Share' 'Evidence confidence should include share-level confidence rows.'
            Assert-Equal $confidenceRows[1].ScopeId 'share-finance' 'Share confidence rows should preserve the share identifier.'
            Assert-True ($confidenceRows[0].PSObject.Properties.Name -contains 'ConfidenceScore') 'Evidence confidence should include a visible score.'
            Assert-True ($confidenceRows[0].PSObject.Properties.Name -contains 'ConfidenceLabel') 'Evidence confidence should include a visible label.'
            Assert-True ($confidenceRows[0].PSObject.Properties.Name -contains 'SignalCount') 'Evidence confidence should count explainable signals.'
            Assert-True ($confidenceRows[0].PSObject.Properties.Name -contains 'Signals') 'Evidence confidence should include explainable signals.'
            Assert-True ($confidenceRows[0].PSObject.Properties.Name -contains 'TotalShares') 'Evidence confidence should include total share count.'
            Assert-True ($confidenceRows[0].PSObject.Properties.Name -contains 'TotalItems') 'Evidence confidence should include total item count.'
            Assert-True ($confidenceRows[0].PSObject.Properties.Name -contains 'RequestedProvider') 'Evidence confidence should include requested provider state.'
            Assert-True ($confidenceRows[0].PSObject.Properties.Name -contains 'EffectiveProvider') 'Evidence confidence should include effective provider state.'
            Assert-True ($confidenceRows[0].PSObject.Properties.Name -contains 'ProviderFallback') 'Evidence confidence should include provider fallback state.'
            Assert-True ($confidenceRows[0].PSObject.Properties.Name -contains 'StopGate') 'Evidence confidence should include stop gates.'
            Assert-True ($confidenceRows[0].PSObject.Properties.Name -contains 'ReviewGate') 'Evidence confidence should include review gates.'
            Assert-True ($confidenceRows[0].PSObject.Properties.Name -contains 'RecommendedAction') 'Evidence confidence should include a recommended action.'
            Assert-True ($confidenceRows[0].PSObject.Properties.Name -contains 'Detail') 'Evidence confidence should include readable detail.'
	        }
	    },
    @{
        Name = 'Invoke-ShareSurferScan can compact repeated inherited ACL exports without changing analysis inputs'
        Body = {
            Import-Module $moduleManifest -Force
            $outputPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferCompactAcl-' + [guid]::NewGuid().ToString('N'))
            $inventory = New-TestInventory
            $inventory.Items += @(
                [pscustomobject]@{
                    ItemId = 'item-child'
                    ShareId = 'share-finance'
                    ItemType = 'Directory'
                    FullPath = '\\files01\Finance\Reports'
                    RelativePath = 'Reports'
                    Depth = 1
                    Owner = 'CONTOSO\FinanceOwner'
                    InheritanceEnabled = $true
                    InheritanceBrokenAt = ''
                },
                [pscustomobject]@{
                    ItemId = 'item-deep-child'
                    ShareId = 'share-finance'
                    ItemType = 'File'
                    FullPath = '\\files01\Finance\Delegated\Child\report.xlsx'
                    RelativePath = 'Delegated\Child\report.xlsx'
                    Depth = 4
                    Owner = 'CONTOSO\FinanceOwner'
                    InheritanceEnabled = $true
                    InheritanceBrokenAt = ''
                }
            )
            $inventory.AclEntries += @(
                [pscustomobject]@{
                    ItemId = 'item-root'
                    ShareId = 'share-finance'
                    FullPath = '\\files01\Finance'
                    Identity = 'CONTOSO\FinanceReaders'
                    Rights = 'Read'
                    AccessControlType = 'Allow'
                    IsInherited = $true
                    InheritanceFlags = 'ContainerInherit,ObjectInherit'
                    PropagationFlags = 'None'
                    Depth = 0
                },
                [pscustomobject]@{
                    ItemId = 'item-child'
                    ShareId = 'share-finance'
                    FullPath = '\\files01\Finance\Reports'
                    Identity = 'CONTOSO\FinanceReaders'
                    Rights = 'Read'
                    AccessControlType = 'Allow'
                    IsInherited = $true
                    InheritanceFlags = 'ContainerInherit,ObjectInherit'
                    PropagationFlags = 'None'
                    Depth = 1
                },
                [pscustomobject]@{
                    ItemId = 'item-child'
                    ShareId = 'share-finance'
                    FullPath = '\\files01\Finance\Reports'
                    Identity = 'CONTOSO\FinanceEditors'
                    Rights = 'Modify'
                    AccessControlType = 'Allow'
                    IsInherited = $false
                    InheritanceFlags = 'ContainerInherit,ObjectInherit'
                    PropagationFlags = 'None'
                    Depth = 1
                },
                [pscustomobject]@{
                    ItemId = 'item-deep'
                    ShareId = 'share-finance'
                    FullPath = '\\files01\Finance\Delegated'
                    Identity = 'CONTOSO\FinanceReaders'
                    Rights = 'Read'
                    AccessControlType = 'Allow'
                    IsInherited = $true
                    InheritanceFlags = 'ContainerInherit,ObjectInherit'
                    PropagationFlags = 'None'
                    Depth = 3
                },
                [pscustomobject]@{
                    ItemId = 'item-deep-child'
                    ShareId = 'share-finance'
                    FullPath = '\\files01\Finance\Delegated\Child\report.xlsx'
                    Identity = 'CONTOSO\FinanceReaders'
                    Rights = 'Read'
                    AccessControlType = 'Allow'
                    IsInherited = $true
                    InheritanceFlags = 'ContainerInherit,ObjectInherit'
                    PropagationFlags = 'None'
                    Depth = 4
                }
            )

            $summary = Invoke-ShareSurferScan -InputObject $inventory -OutputPath $outputPath -SkipIdentityEnrichment -AclExportMode Compact
            $aclRows = @(Import-Csv -LiteralPath (Join-Path $outputPath 'acl_entries.csv'))
            $manifest = @(Import-Csv -LiteralPath (Join-Path $outputPath 'scan_manifest.csv'))[0]
            $findings = @(Import-Csv -LiteralPath (Join-Path $outputPath 'findings.csv'))
            $validationResult = Test-ShareSurferExport -ExportPath $outputPath

            Assert-Equal $manifest.AclExportMode 'Compact' 'Manifest should record compact ACL export mode.'
            Assert-Equal ([int]$manifest.FullAclEntryCount) 8 'Manifest should preserve the full ACL row count used by analysis.'
            Assert-Equal ([int]$manifest.ExportedAclEntryCount) 6 'Manifest should record the compact exported ACL row count.'
            Assert-Equal ([int]$manifest.SuppressedInheritedAclEntryCount) 2 'Manifest should record suppressed inherited duplicate rows.'
            Assert-Equal $summary.AclExportMode 'Compact' 'Command summary should expose the active ACL export mode.'
            Assert-Equal ([int]$summary.FullAclEntries) 8 'Command summary should expose full ACL row count.'
            Assert-Equal ([int]$summary.AclEntries) 6 'Command summary should expose compact exported ACL row count.'
            Assert-Equal ([int]$summary.SuppressedInheritedAclEntries) 2 'Command summary should expose suppressed inherited duplicate count.'
            Assert-True ([bool]$validationResult.IsValid) 'Compact ACL export should pass normal export validation.'
            Assert-Equal (@($aclRows | Where-Object { $_.ItemId -eq 'item-child' -and $_.Identity -eq 'CONTOSO\FinanceReaders' }).Count) 0 'Repeated inherited descendant rows should be suppressed in compact mode.'
            Assert-Equal (@($aclRows | Where-Object { $_.ItemId -eq 'item-child' -and $_.Identity -eq 'CONTOSO\FinanceEditors' -and $_.IsInherited -eq 'False' }).Count) 1 'Explicit ACEs must stay visible in compact mode.'
            Assert-Equal (@($aclRows | Where-Object { $_.ItemId -eq 'item-root' -and $_.Identity -eq 'CONTOSO\FinanceReaders' }).Count) 1 'Root inherited baseline ACEs should remain visible in compact mode.'
            Assert-Equal (@($aclRows | Where-Object { $_.ItemId -eq 'item-deep' -and $_.Identity -eq 'CONTOSO\FinanceReaders' }).Count) 1 'Inheritance-break boundary ACEs should remain visible in compact mode.'
            Assert-True ($findings.FindingType -contains 'BrokenInheritance') 'Findings should still use full analysis inputs even when ACL export is compacted.'
        }
    },
	    @{
	        Name = 'Get-ShareSurferConflicts dedupes missing share gate noise and respects broad gates'
	        Body = {
            Import-Module $moduleManifest -Force
            $sharePermissionsWithBroadGate = @(
                [pscustomobject]@{ ShareId = 'share-001'; Identity = 'Everyone'; Rights = 'Full'; AccessControlType = 'Allow' }
            )
            $aclEntries = @(
                [pscustomobject]@{ ShareId = 'share-001'; ItemId = 'item-001'; Identity = 'CONTOSO\FinanceRW'; Rights = 'Modify'; AccessControlType = 'Allow' },
                [pscustomobject]@{ ShareId = 'share-001'; ItemId = 'item-002'; Identity = 'CONTOSO\FinanceRW'; Rights = 'ReadAndExecute'; AccessControlType = 'Allow' }
            )
            $shareSurferModule = Get-Module ShareSurfer
            $broadGateConflicts = @(& $shareSurferModule {
                param($SharePermissions, $AclEntries)
                Get-ShareSurferConflicts -SharePermissions $SharePermissions -AclEntries $AclEntries
            } $sharePermissionsWithBroadGate $aclEntries)
            Assert-True (@($broadGateConflicts | Where-Object { $_.ConflictType -eq 'NtfsIdentityMissingShareGate' }).Count -eq 0) 'A broad allow share gate should not create per-ACE high-severity missing-gate noise.'

            $specificSharePermissions = @(
                [pscustomobject]@{ ShareId = 'share-001'; Identity = 'CONTOSO\OtherGroup'; Rights = 'Read'; AccessControlType = 'Allow' }
            )
            $specificGateConflicts = @(& $shareSurferModule {
                param($SharePermissions, $AclEntries)
                Get-ShareSurferConflicts -SharePermissions $SharePermissions -AclEntries $AclEntries
            } $specificSharePermissions $aclEntries)
            $missingGateConflicts = @($specificGateConflicts | Where-Object { $_.ConflictType -eq 'NtfsIdentityMissingShareGate' })
            Assert-Equal $missingGateConflicts.Count 1 'Repeated ACEs for the same missing identity should collapse to one share-level gate conflict.'
            Assert-Equal $missingGateConflicts[0].Identity 'CONTOSO\FinanceRW' 'The deduped conflict should still name the missing NTFS identity.'
            Assert-Equal ([int]$missingGateConflicts[0].AffectedItemCount) 2 'Missing share-gate rollups should count affected items.'
            Assert-Equal $missingGateConflicts[0].EvidenceCompleteness 'RolledUp' 'Repeated missing share-gate evidence should identify itself as a rollup.'
        }
    },
    @{
        Name = 'Get-ShareSurferConflicts handles repeated inherited ACLs without per-row conflict blowup'
        Body = {
            Import-Module $moduleManifest -Force
            $sharePermissions = @(
                [pscustomobject]@{ ShareId = 'share-001'; Identity = 'CONTOSO\FinanceReaders'; Rights = 'Read'; AccessControlType = 'Allow' },
                [pscustomobject]@{ ShareId = 'share-001'; Identity = 'CONTOSO\OtherGroup'; Rights = 'Read'; AccessControlType = 'Allow' }
            )
            $aclEntries = for ($i = 0; $i -lt 20000; $i++) {
                [pscustomobject]@{
                    ShareId = 'share-001'
                    ItemId = 'item-{0}' -f $i
                    FullPath = '\\files01\Finance\Inherited\Folder{0}' -f $i
                    Identity = 'CONTOSO\FinanceReaders'
                    Rights = 'Modify'
                    AccessControlType = 'Allow'
                    Depth = 3
                }
            }

            $shareSurferModule = Get-Module ShareSurfer
            $result = $null
            $elapsed = Measure-Command {
                $result = @(& $shareSurferModule {
                    param($SharePermissions, $AclEntries)
                    Get-ShareSurferConflicts -SharePermissions $SharePermissions -AclEntries $AclEntries -Quiet
                } $sharePermissions $aclEntries)
            }

            Assert-True ($elapsed.TotalSeconds -lt 10) ('Conflict classification should stay bounded for repeated ACL rows. ElapsedSeconds={0:N2}' -f $elapsed.TotalSeconds)
            Assert-Equal @($result | Where-Object { $_.ConflictType -eq 'ShareRightsRestrictNtfs' }).Count 1 'Repeated share-vs-NTFS restriction evidence should collapse to one representative conflict.'
            Assert-Equal @($result | Where-Object { $_.ConflictType -eq 'ShareIdentityMissingNtfsEntry' }).Count 1 'Share identities missing from NTFS should still be reported once.'
            Assert-True ($result.Count -lt 10) 'Repeated inherited ACL rows should not create one conflict per ACL row.'
            $restriction = @($result | Where-Object { $_.ConflictType -eq 'ShareRightsRestrictNtfs' })[0]
            Assert-Equal ([int]$restriction.AffectedItemCount) 20000 'Rolled-up restrictions should count unique affected items.'
            Assert-True ([string]$restriction.ExamplePath -like '\\files01\Finance\Inherited*') 'Rolled-up restrictions should preserve an example path.'
            Assert-True ([string]$restriction.AffectedPathPrefix -like '\\files01\Finance\Inherited*') 'Rolled-up restrictions should preserve a common affected path prefix.'
            Assert-Equal ([int]$restriction.MaxDepth) 3 'Rolled-up restrictions should preserve max observed depth.'
            Assert-Equal $restriction.EvidenceCompleteness 'RolledUp' 'Rolled-up restrictions should be labeled for dashboard review.'
        }
    },
    @{
        Name = 'Get-ShareSurferConflicts prunes share-covered nonrestrictive ACL evidence at scale'
        Body = {
            Import-Module $moduleManifest -Force
            $sharePermissions = @(
                [pscustomobject]@{ ShareId = 'share-001'; Identity = 'CONTOSO\FinanceReaders'; Rights = 'Full'; AccessControlType = 'Allow' }
            )
            $aclEntries = for ($i = 0; $i -lt 50000; $i++) {
                [pscustomobject]@{
                    ShareId = 'share-001'
                    ItemId = 'item-{0}' -f $i
                    FullPath = '\\files01\Finance\Inherited\Department\Team\Folder{0}' -f $i
                    Identity = 'CONTOSO\FinanceReaders'
                    Rights = 'ReadAndExecute'
                    AccessControlType = 'Allow'
                    Depth = 5
                }
            }

            $shareSurferModule = Get-Module ShareSurfer
            $result = $null
            $elapsed = Measure-Command {
                $result = @(& $shareSurferModule {
                    param($SharePermissions, $AclEntries)
                    Get-ShareSurferConflicts -SharePermissions $SharePermissions -AclEntries $AclEntries -Quiet
                } $sharePermissions $aclEntries)
            }

            Assert-Equal @($result).Count 0 'Share-covered NTFS rows that are not broader than the share gate should not produce conflicts.'
            Assert-True ($elapsed.TotalSeconds -lt 15) ('Conflict classification should prune non-conflict ACL rows before building rollup evidence. ElapsedSeconds={0:N2}' -f $elapsed.TotalSeconds)
        }
    },
    @{
        Name = 'Get-ShareSurferConflicts slows high-volume progress heartbeat without disabling forced progress'
        Body = {
            Import-Module $moduleManifest -Force
            $shareSurferModule = Get-Module ShareSurfer
            $intervals = & $shareSurferModule {
                [pscustomobject]@{
                    SmallDefault = Get-ShareSurferConflictStatusIntervalSeconds -RequestedSeconds 15 -AclRowCount 1000
                    MediumDefault = Get-ShareSurferConflictStatusIntervalSeconds -RequestedSeconds 15 -AclRowCount 25000
                    LargeDefault = Get-ShareSurferConflictStatusIntervalSeconds -RequestedSeconds 15 -AclRowCount 543220
                    Forced = Get-ShareSurferConflictStatusIntervalSeconds -RequestedSeconds 0 -AclRowCount 543220
                }
            }

            Assert-Equal ([int]$intervals.SmallDefault) 15 'Small conflict runs should keep the requested heartbeat interval.'
            Assert-Equal ([int]$intervals.MediumDefault) 30 'Medium conflict runs should avoid overly chatty progress lines.'
            Assert-Equal ([int]$intervals.LargeDefault) 60 'Large conflict runs should avoid every-15-second scrollback during long ACL indexing.'
            Assert-Equal ([int]$intervals.Forced) 0 'A forced zero-second interval should remain available for deterministic tests and explicit diagnostics.'
        }
    },
    @{
        Name = 'Get-ShareSurferConflicts avoids false merges across identities shares rights and direct deny items'
        Body = {
            Import-Module $moduleManifest -Force
            $sharePermissions = @(
                [pscustomobject]@{ ShareId = 'share-001'; Identity = 'CONTOSO\FinanceReaders'; Rights = 'Read'; AccessControlType = 'Allow' },
                [pscustomobject]@{ ShareId = 'share-001'; Identity = 'CONTOSO\FinanceEditors'; Rights = 'Read'; AccessControlType = 'Allow' },
                [pscustomobject]@{ ShareId = 'share-002'; Identity = 'CONTOSO\FinanceReaders'; Rights = 'Read'; AccessControlType = 'Allow' }
            )
            $aclEntries = @(
                [pscustomobject]@{ ShareId = 'share-001'; ItemId = 'item-001'; FullPath = '\\files01\Finance\AreaA'; Identity = 'CONTOSO\FinanceReaders'; Rights = 'Modify'; AccessControlType = 'Allow'; Depth = 2 },
                [pscustomobject]@{ ShareId = 'share-001'; ItemId = 'item-002'; FullPath = '\\files01\Finance\AreaB'; Identity = 'CONTOSO\FinanceReaders'; Rights = 'Modify'; AccessControlType = 'Allow'; Depth = 2 },
                [pscustomobject]@{ ShareId = 'share-001'; ItemId = 'item-003'; FullPath = '\\files01\Finance\AreaC'; Identity = 'CONTOSO\FinanceEditors'; Rights = 'Modify'; AccessControlType = 'Allow'; Depth = 2 },
                [pscustomobject]@{ ShareId = 'share-002'; ItemId = 'item-004'; FullPath = '\\files02\Finance\AreaD'; Identity = 'CONTOSO\FinanceReaders'; Rights = 'Modify'; AccessControlType = 'Allow'; Depth = 2 },
                [pscustomobject]@{ ShareId = 'share-001'; ItemId = 'item-005'; FullPath = '\\files01\Finance\AreaE'; Identity = 'CONTOSO\FinanceReaders'; Rights = 'FullControl'; AccessControlType = 'Allow'; Depth = 2 },
                [pscustomobject]@{ ShareId = 'share-001'; ItemId = 'item-deny-001'; FullPath = '\\files01\Finance\ProtectedA'; Identity = 'CONTOSO\FinanceReaders'; Rights = 'Read'; AccessControlType = 'Allow'; Depth = 4 },
                [pscustomobject]@{ ShareId = 'share-001'; ItemId = 'item-deny-001'; FullPath = '\\files01\Finance\ProtectedA'; Identity = 'CONTOSO\FinanceReaders'; Rights = 'Read'; AccessControlType = 'Deny'; Depth = 4 },
                [pscustomobject]@{ ShareId = 'share-001'; ItemId = 'item-deny-002'; FullPath = '\\files01\Finance\ProtectedB'; Identity = 'CONTOSO\FinanceReaders'; Rights = 'Read'; AccessControlType = 'Allow'; Depth = 4 },
                [pscustomobject]@{ ShareId = 'share-001'; ItemId = 'item-deny-002'; FullPath = '\\files01\Finance\ProtectedB'; Identity = 'CONTOSO\FinanceReaders'; Rights = 'Read'; AccessControlType = 'Deny'; Depth = 4 }
            )

            $shareSurferModule = Get-Module ShareSurfer
            $result = @(& $shareSurferModule {
                param($SharePermissions, $AclEntries)
                Get-ShareSurferConflicts -SharePermissions $SharePermissions -AclEntries $AclEntries -Quiet
            } $sharePermissions $aclEntries)

            $restrictions = @($result | Where-Object { $_.ConflictType -eq 'ShareRightsRestrictNtfs' })
            Assert-Equal $restrictions.Count 4 'Different identity, share, or rights evidence should not collapse into the same restriction rollup.'
            $financeReaderModify = @($restrictions | Where-Object { $_.ShareId -eq 'share-001' -and $_.Identity -eq 'CONTOSO\FinanceReaders' -and $_.NtfsRights -eq 'Modify' })[0]
            Assert-Equal ([int]$financeReaderModify.AffectedItemCount) 2 'Only matching repeated evidence should roll up together.'

            $denyCollisions = @($result | Where-Object { $_.ConflictType -eq 'NtfsDenyAllowCollision' })
            $shareAllowsDenies = @($result | Where-Object { $_.ConflictType -eq 'ShareAllowsNtfsDenies' })
            Assert-Equal $denyCollisions.Count 2 'Direct item deny collisions should remain distinct by item.'
            Assert-Equal $shareAllowsDenies.Count 2 'Share-allows/NTFS-denies conflicts should remain distinct by item.'
            Assert-True (@($denyCollisions | Where-Object { [int]$_.AffectedItemCount -eq 1 }).Count -eq 2) 'Direct deny collision rows should describe one affected item each.'
        }
    },
    @{
        Name = 'Get-ShareSurferFindings handles large repeated ACLs with cached SID checks and progress'
        Body = {
            Import-Module $moduleManifest -Force
            $items = for ($i = 0; $i -lt 5000; $i++) {
                [pscustomobject]@{
                    ShareId = 'share-001'
                    ItemId = 'item-{0}' -f $i
                    FullPath = '\\files01\Finance\Folder{0}' -f $i
                    Owner = 'CONTOSO\FinanceOwner'
                    InheritanceEnabled = $true
                    InheritanceBrokenAt = ''
                }
            }
            $aclEntries = for ($i = 0; $i -lt 20000; $i++) {
                [pscustomobject]@{
                    ShareId = 'share-001'
                    ItemId = 'item-{0}' -f ($i % 5000)
                    FullPath = '\\files01\Finance\Folder{0}' -f ($i % 5000)
                    Identity = 'CONTOSO\FinanceReaders'
                    Rights = 'ReadAndExecute'
                    AccessControlType = 'Allow'
                    IsInherited = $true
                    Depth = 1
                }
            }

            $shareSurferModule = Get-Module ShareSurfer
            $result = $null
            $elapsed = Measure-Command {
                $result = @(& $shareSurferModule {
                    param($Items, $AclEntries)
                    Get-ShareSurferFindings -Items $Items -AclEntries $AclEntries -SharePermissions @() -Shares @() -GroupEdges @() -Identities @() -ScanErrors @() -Quiet
                } $items $aclEntries)
            }

            Assert-True ($elapsed.TotalSeconds -lt 10) ('Finding classification should stay bounded for repeated inherited ACL rows. ElapsedSeconds={0:N2}' -f $elapsed.TotalSeconds)
            Assert-Equal @($result).Count 0 'Inherited repeated ACL rows with resolved identities and normal owners should not create findings.'

            $smallItems = @($items | Select-Object -First 2)
            $smallAclEntries = @($aclEntries | Select-Object -First 3)
            $progressText = (& $shareSurferModule {
                param($Items, $AclEntries)
                Get-ShareSurferFindings -Items $Items -AclEntries $AclEntries -SharePermissions @() -Shares @() -GroupEdges @() -Identities @() -ScanErrors @() -StatusIntervalSeconds 0 -ShowProgress | Out-Null
            } $smallItems $smallAclEntries *>&1 | Out-String)

            Assert-True ($progressText -like '*Finding classification progress: checked*ACL row(s)*') 'Finding classification should print ACL progress when requested.'
            Assert-True ($progressText -like '*SID cache=1*') 'Finding classification should cache repeated identity SID checks.'
            Assert-True ($progressText -like '*Finding classification complete:*') 'Finding classification should print a completion summary.'
        }
    },
    @{
        Name = 'Normalize-ShareSurferItems keeps inheritance breaks on path boundaries'
        Body = {
            Import-Module $moduleManifest -Force
            $items = @(
                [pscustomobject]@{ ItemId = 'item-drive-root'; ShareId = 'share-001'; ItemType = 'Directory'; FullPath = 'E:\'; RelativePath = ''; Depth = 0; Owner = ''; InheritanceEnabled = $false; InheritanceBrokenAt = 'E:\' },
                [pscustomobject]@{ ItemId = 'item-drive-child'; ShareId = 'share-001'; ItemType = 'Directory'; FullPath = 'E:\DriveChild'; RelativePath = 'DriveChild'; Depth = 1; Owner = ''; InheritanceEnabled = $true; InheritanceBrokenAt = '' },
                [pscustomobject]@{ ItemId = 'item-fin'; ShareId = 'share-001'; ItemType = 'Directory'; FullPath = 'C:\Data\Fin'; RelativePath = 'Fin'; Depth = 1; Owner = ''; InheritanceEnabled = $false; InheritanceBrokenAt = 'C:\Data\Fin' },
                [pscustomobject]@{ ItemId = 'item-fin-child'; ShareId = 'share-001'; ItemType = 'Directory'; FullPath = 'C:\Data\Fin\Reports'; RelativePath = 'Fin\Reports'; Depth = 2; Owner = ''; InheritanceEnabled = $true; InheritanceBrokenAt = '' },
                [pscustomobject]@{ ItemId = 'item-finance'; ShareId = 'share-001'; ItemType = 'Directory'; FullPath = 'C:\Data\Finance'; RelativePath = 'Finance'; Depth = 1; Owner = ''; InheritanceEnabled = $true; InheritanceBrokenAt = '' }
            )

            $shareSurferModule = Get-Module ShareSurfer
            $normalized = @(& $shareSurferModule {
                param($Items)
                Normalize-ShareSurferItems -Items $Items
            } $items)
            $finance = @($normalized | Where-Object { $_.ItemId -eq 'item-finance' })[0]
            $fin = @($normalized | Where-Object { $_.ItemId -eq 'item-fin' })[0]
            $finChild = @($normalized | Where-Object { $_.ItemId -eq 'item-fin-child' })[0]
            $driveRoot = @($normalized | Where-Object { $_.ItemId -eq 'item-drive-root' })[0]
            $driveChild = @($normalized | Where-Object { $_.ItemId -eq 'item-drive-child' })[0]

            Assert-Equal $finance.InheritanceBrokenAt '' 'Sibling paths that share a string prefix should not inherit another folder inheritance break.'
            Assert-Equal $finChild.InheritanceBrokenAt 'C:\Data\Fin' 'True descendants should inherit the nearest broken-inheritance ancestor.'
            Assert-Equal $driveChild.InheritanceBrokenAt 'E:\' 'Drive-root inheritance breaks should be reachable for descendants.'
            Assert-Equal $fin.InheritanceBreakType 'Direct' 'Rows where inheritance is disabled should identify a direct inheritance break.'
            Assert-Equal $driveRoot.InheritanceBreakType 'Direct' 'Drive-root inheritance breaks should identify the root row as direct.'
            Assert-Equal $finChild.InheritanceBreakType 'InheritedAncestor' 'Descendants should identify inherited break context without looking like direct breaks.'
            Assert-Equal $finance.InheritanceBreakType 'None' 'Unrelated sibling rows should identify no known inheritance break.'
        }
    },
    @{
        Name = 'Invoke-ShareSurferScan creates missing local output folders with opt-out'
        Body = {
            Import-Module $moduleManifest -Force
            $root = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferFolderPreflight-' + [guid]::NewGuid().ToString('N'))
            $outputPath = Join-Path $root 'exports\finance-001'
            $optOutPath = Join-Path $root 'exports\blocked-001'

            $captured = @(& {
                Invoke-ShareSurferScan -InputObject (New-TestInventory) -OutputPath $outputPath -SkipIdentityEnrichment | Out-Null
            } 6>&1)
            $capturedText = ($captured | ForEach-Object { [string]$_ }) -join "`n"

            Assert-True (Test-Path -LiteralPath $outputPath -PathType Container) 'Scan should create the missing local export folder.'
            Assert-True ($capturedText -like '*Creating missing local scan export folder*') 'Scan should tell the operator which missing local output folder is being created.'
            Assert-True ($capturedText -like '*-NoCreateMissingFolders*') 'Folder creation message should explain the opt-out switch.'

            $threw = $false
            try {
                Invoke-ShareSurferScan -InputObject (New-TestInventory) -OutputPath $optOutPath -SkipIdentityEnrichment -NoCreateMissingFolders | Out-Null
            }
            catch {
                $threw = ($_.Exception.Message -like '*automatic folder creation was disabled*' -and $_.Exception.Message -like ('*{0}*' -f $optOutPath))
            }

            Assert-True $threw 'Scan should fail with a clear message when missing-folder creation is disabled.'
            Assert-True (-not (Test-Path -LiteralPath $optOutPath)) 'Opt-out scan should not create the missing local export folder.'
        }
    },
    @{
        Name = 'Invoke-ShareSurferScan prints operator completion summary unless quiet'
        Body = {
            Import-Module $moduleManifest -Force
            $outputPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferSummaryExport-' + [guid]::NewGuid().ToString('N'))
            $quietOutputPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferSummaryQuietExport-' + [guid]::NewGuid().ToString('N'))

            $captured = @(& {
                Invoke-ShareSurferScan -InputObject (New-TestInventory) -OutputPath $outputPath -SkipIdentityEnrichment | Out-Null
            } 6>&1)
            $capturedText = ($captured | ForEach-Object { [string]$_ }) -join "`n"

            Assert-True ($capturedText -like '*ShareSurfer Summary:*') 'Scan should print an operator summary when it completes.'
            Assert-True ($capturedText -like '*Shares=*Items=*Findings=*Conflicts=*CollectionErrors=*PartialShares=*') 'Summary should include core collection and review counts.'
            Assert-True ($capturedText -like ('*OutputPath={0}*' -f $outputPath)) 'Summary should include the export path.'
            Assert-True ($capturedText -like ('*Next: Test-ShareSurferExport -ExportPath ''{0}''*' -f $outputPath)) 'Summary should show the next validation command.'

            $quietCaptured = @(& {
                Invoke-ShareSurferScan -InputObject (New-TestInventory) -OutputPath $quietOutputPath -SkipIdentityEnrichment -Quiet | Out-Null
            } 6>&1)
            $quietText = ($quietCaptured | ForEach-Object { [string]$_ }) -join "`n"

            Assert-True ($quietText -notlike '*ShareSurfer Summary:*') 'Quiet mode should suppress the operator completion summary.'
            Assert-True ($quietText -notlike '*Next: Test-ShareSurferExport*') 'Quiet mode should suppress the next-command hint.'
        }
    },
    @{
        Name = 'Invoke-ShareSurferScan flags unavailable item owner metadata without claiming no owner'
        Body = {
            Import-Module $moduleManifest -Force
            $outputPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferOwnerMetadataExport-' + [guid]::NewGuid().ToString('N'))
            $inventory = New-TestInventory
            $inventory.Items += [pscustomobject]@{
                ItemId = 'item-owner-unavailable'
                ShareId = 'share-finance'
                ItemType = 'File'
                FullPath = '\\files01\Finance\OwnerUnknown\budget.xlsx'
                RelativePath = 'OwnerUnknown\budget.xlsx'
                Depth = 2
                Owner = ''
                InheritanceEnabled = $true
                InheritanceBrokenAt = ''
            }

            Invoke-ShareSurferScan -InputObject $inventory -OutputPath $outputPath -SkipIdentityEnrichment | Out-Null

            $findings = Import-Csv -LiteralPath (Join-Path $outputPath 'findings.csv')
            $ownerFindings = @($findings | Where-Object { $_.FindingType -eq 'OwnerMetadataUnavailable' })

            Assert-Equal $ownerFindings.Count 1 'Blank item owner metadata should produce one explicit finding.'
            Assert-Equal $ownerFindings[0].ItemId 'item-owner-unavailable' 'Owner metadata finding should point at the item whose owner metadata was unavailable.'
            Assert-True ($ownerFindings[0].Message -like '*could not collect a usable NTFS owner value*') 'Owner metadata finding should explain that collection did not receive a usable owner value.'
            Assert-True ($ownerFindings[0].Message -notlike '*has no owner*') 'Owner metadata finding should not claim the Windows object has no owner.'
        }
    },
    @{
        Name = 'Invoke-ShareSurferScan keeps discounted broad access visible without migration relatedness inflation'
        Body = {
            Import-Module $moduleManifest -Force
            $outputPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferDiscountedExport-' + [guid]::NewGuid().ToString('N'))
            $discountedPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferDiscountedPrincipals-' + [guid]::NewGuid().ToString('N') + '.csv')
            @(
                [pscustomobject]@{
                    Identity = 'CONTOSO\HelpDeskOps'
                    Reason = 'Broad helpdesk access'
                    Scope = 'Global'
                }
            ) | Export-Csv -LiteralPath $discountedPath -NoTypeInformation -Encoding UTF8

            Invoke-ShareSurferScan -InputObject (New-TestDiscountedPrincipalInventory) -OutputPath $outputPath -DiscountedPrincipalPath $discountedPath -SkipIdentityEnrichment | Out-Null

            $rawSharePermissions = Import-Csv -LiteralPath (Join-Path $outputPath 'share_permissions.csv')
            Assert-Equal (@($rawSharePermissions | Where-Object { $_.Identity -eq 'CONTOSO\HelpDeskOps' }).Count) 2 'Raw share permissions must preserve discounted HelpDesk access evidence.'

            $discountedPrincipals = Import-Csv -LiteralPath (Join-Path $outputPath 'discounted_principals.csv')
            Assert-Equal $discountedPrincipals[0].Identity 'CONTOSO\HelpDeskOps' 'Discounted principal export should preserve the configured identity.'
            Assert-Equal $discountedPrincipals[0].Reason 'Broad helpdesk access' 'Discounted principal export should preserve the configured reason.'
            Assert-Equal $discountedPrincipals[0].Scope 'Global' 'Discounted principal export should preserve optional scope metadata.'

            $permissionedGroups = Import-Csv -LiteralPath (Join-Path $outputPath 'permissioned_groups.csv')
            $helpDeskGroup = @($permissionedGroups | Where-Object { $_.Group -eq 'CONTOSO\HelpDeskOps' })[0]
            Assert-True ($helpDeskGroup.DiscountedPrincipal -eq 'True') 'Permissioned group review should mark discounted broad-access groups.'
            Assert-Equal $helpDeskGroup.DiscountReason 'Broad helpdesk access' 'Permissioned group review should expose the discount reason.'
            Assert-Equal ([int]$helpDeskGroup.ShareAssignments) 2 'Permissioned group review should still count raw assignments for discounted groups.'

            $ownerRiskPivots = Import-Csv -LiteralPath (Join-Path $outputPath 'owner_risk_pivots.csv')
            Assert-Equal (@($ownerRiskPivots).Count) 2 'Unrelated owner mappings should remain separate pivots.'
            foreach ($pivot in @($ownerRiskPivots)) {
                Assert-Equal ([int]$pivot.DirectIdentityCount) 0 'Discounted principals should not inflate migration direct identity counts.'
                Assert-Equal ([int]$pivot.DirectGroupCount) 0 'Discounted groups should not inflate migration direct group counts.'
                Assert-Equal ([int]$pivot.ExpandedMemberCount) 0 'Discounted groups should not inflate migration expanded member counts.'
                Assert-True ($pivot.DiscountedPrincipal -eq 'True') 'Owner pivots should show that visible access was discounted from relatedness.'
                Assert-True ($pivot.DiscountReason -like '*Broad helpdesk access*') 'Owner pivots should carry the discount reason for the main hub.'
            }

            $relatedDataAreas = Import-Csv -LiteralPath (Join-Path $outputPath 'related_data_areas.csv')
            Assert-Equal (@($relatedDataAreas).Count) 2 'Discounted broad access should not collapse unrelated shares into one related data area.'
            foreach ($area in @($relatedDataAreas)) {
                Assert-Equal ([int]$area.DirectGroupCount) 0 'Related data areas should exclude discounted groups from group relatedness counts.'
                Assert-True ($area.RelatedBecause -notlike '*shared permission group*') 'Related data areas should not cite discounted groups as shared permission-group relatedness.'
                Assert-True ($area.RelatedBecause -notlike '*shared review risk*') 'Relatedness explanations should not cite readiness risks.'
                Assert-True ([int]$area.RelationshipSignalCount -ge 1) 'Related data areas should count non-discounted relationship signals.'
                Assert-True ($area.DiscountedPrincipal -eq 'True') 'Related data areas should visibly mark discounted broad-access principals.'
                Assert-True ($area.DiscountReason -like '*visible but not used for migration relatedness*') 'Related data areas should explain visible-but-not-relatedness semantics.'
            }

            $ownerReviewPackets = Import-Csv -LiteralPath (Join-Path $outputPath 'owner_review_packets.csv')
            foreach ($packet in @($ownerReviewPackets)) {
                Assert-Equal ([int]$packet.DirectGroupCount) 0 'Owner review packets should use non-discounted direct group counts for migration review sizing.'
                Assert-True ($packet.DiscountedPrincipal -eq 'True') 'Owner review packets should keep discounted access visible in the main review hub.'
                Assert-True ($packet.DiscountReason -like '*Broad helpdesk access*') 'Owner review packets should carry the discount reason.'
                Assert-True ($packet.WhyReview -notlike '*permission-bearing security groups*') 'Discounted-only groups should not make owner packets look related by permissioned groups.'
            }
        }
    },
    @{
        Name = 'Invoke-ShareSurferScan proves migration discovery expected clusters and explainable signals'
        Body = {
            Import-Module $moduleManifest -Force
            $outputPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferMigrationQualityExport-' + [guid]::NewGuid().ToString('N'))
            $discountedPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferMigrationQualityDiscounted-' + [guid]::NewGuid().ToString('N') + '.csv')
            $expectedPath = Join-Path $repoRoot 'tests/fixtures/migration-discovery-quality/expected_related_data_areas.csv'
            Assert-True (Test-Path -LiteralPath $expectedPath) 'Migration discovery quality harness should include durable expected cluster data.'

            @(
                [pscustomobject]@{
                    Identity = 'CONTOSO\HelpDeskOps'
                    Reason = 'Broad operational support access'
                    Scope = 'All quality-harness shares'
                }
            ) | Export-Csv -LiteralPath $discountedPath -NoTypeInformation -Encoding UTF8

            Invoke-ShareSurferScan -InputObject (New-TestMigrationDiscoveryQualityInventory) -OutputPath $outputPath -DiscountedPrincipalPath $discountedPath -SkipIdentityEnrichment | Out-Null

            $expectedRows = @(Import-Csv -LiteralPath $expectedPath)
            $relatedDataAreas = @(Import-Csv -LiteralPath (Join-Path $outputPath 'related_data_areas.csv'))
            $ownerRiskPivots = @(Import-Csv -LiteralPath (Join-Path $outputPath 'owner_risk_pivots.csv'))
            Assert-Equal $relatedDataAreas.Count $expectedRows.Count 'Migration quality harness should emit exactly the expected related data areas.'
            Assert-Equal $ownerRiskPivots.Count $expectedRows.Count 'Owner risk pivots should stay aligned with the expected migration harness clusters.'

            foreach ($expected in $expectedRows) {
                $actualMatches = @($relatedDataAreas | Where-Object {
                    [string]$_.BusinessUnit -eq [string]$expected.BusinessUnit -and
                        [string]$_.Owner -eq [string]$expected.Owner -and
                        [string]$_.Pattern -eq [string]$expected.Pattern
                })
                Assert-Equal $actualMatches.Count 1 ("Expected exactly one related data area for harness cluster {0}." -f $expected.ExpectedClusterId)
                $actual = $actualMatches[0]

                Assert-Equal $actual.RelatednessStrength $expected.ExpectedRelatednessStrength ("Relatedness strength should match harness expectation for {0}." -f $expected.ExpectedClusterId)
                Assert-Equal $actual.MigrationReadiness $expected.ExpectedMigrationReadiness ("Migration readiness should match harness expectation for {0}." -f $expected.ExpectedClusterId)
                Assert-Equal ([int]$actual.MatchingShares) ([int]$expected.ExpectedMatchingShares) ("Matching share count should match harness expectation for {0}." -f $expected.ExpectedClusterId)
                Assert-True ([int]$actual.RelationshipSignalCount -ge [int]$expected.MinimumRelationshipSignalCount) ("Relationship signal count should meet harness expectation for {0}." -f $expected.ExpectedClusterId)

                foreach ($signal in @([string]$expected.RequiredRelationshipSignals -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })) {
                    Assert-SignalContains -Actual $actual.RelationshipSignals -Expected $signal -Message ("Cluster {0} should explain relationship signal {1}." -f $expected.ExpectedClusterId, $signal)
                    Assert-SignalContains -Actual $actual.RelatedBecause -Expected $signal -Message ("Cluster {0} should include relationship signal {1} in RelatedBecause." -f $expected.ExpectedClusterId, $signal)
                }
                foreach ($signal in @([string]$expected.RequiredSupportingEvidence -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })) {
                    Assert-SignalContains -Actual $actual.SupportingEvidence -Expected $signal -Message ("Cluster {0} should explain supporting evidence {1}." -f $expected.ExpectedClusterId, $signal)
                    Assert-SignalContains -Actual $actual.RelatedBecause -Expected $signal -Message ("Cluster {0} should include supporting evidence {1} in RelatedBecause." -f $expected.ExpectedClusterId, $signal)
                }
                Assert-SignalContains -Actual $actual.RelatedBecause -Expected ('{0} confidence' -f $expected.ExpectedRelatednessStrength) -Message ("Cluster {0} should include visible confidence language." -f $expected.ExpectedClusterId)
                Assert-True ($actual.CoreFiveChips -like '*Confidence:*' -and $actual.CoreFiveChips -like '*Readiness:*' -and $actual.CoreFiveChips -like '*Evidence:*') ("Cluster {0} should carry the Core Five chip summary." -f $expected.ExpectedClusterId)
            }

            $financeArea = @($relatedDataAreas | Where-Object { $_.BusinessUnit -eq 'Finance' -and $_.Owner -eq 'Accounts Payable' })[0]
            $legalArea = @($relatedDataAreas | Where-Object { $_.BusinessUnit -eq 'Legal' -and $_.Owner -eq 'Legal Operations' })[0]
            $projectArea = @($relatedDataAreas | Where-Object { $_.Owner -eq 'Project Phoenix' })[0]
            $unknownArea = @($relatedDataAreas | Where-Object { $_.Pattern -eq '\\files04\Legacy-Unknown*' })[0]

            Assert-Equal ([int]$financeArea.MatchingShares) 2 'False split harness: Finance AP active and archive shares should appear as one related area.'
            Assert-Equal ([int]$legalArea.MatchingShares) 1 'False merge harness: similarly named Legal AP content should remain outside the Finance AP area.'
            Assert-True ($financeArea.RelatedBecause -notlike '*shared review risk*') 'Readiness risks should not be used as relationship proof.'
            Assert-True ($financeArea.ReadinessSignals -like '*deep explicit ACE*') 'Finance AP readiness should preserve migration cleanup evidence.'
            Assert-Equal $projectArea.RelatednessStrength 'Possible' 'Owner plus path pattern should be possible relatedness, not strong.'
            Assert-Equal $unknownArea.RelatednessStrength 'Needs Evidence' 'Pattern-only legacy areas should remain needs-evidence.'

            foreach ($area in @($relatedDataAreas)) {
                Assert-True ($area.DiscountedPrincipal -eq 'True') 'Discounted HelpDesk access should remain visible on every harness area.'
                Assert-True ($area.DiscountReason -like '*visible but not used for migration relatedness*') 'Discount reason should explain that support access was not used for relatedness.'
                Assert-True ($area.RelatedBecause -notlike '*HelpDeskOps*') 'Discounted HelpDesk access should not become relationship proof.'
            }
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
            $confidenceRows = @(Import-Csv -LiteralPath (Join-Path $outputPath 'evidence_confidence.csv'))

            Assert-Equal $shares[0].PartialData 'True' 'Share rows should be partial when collection errors were recorded for the share.'
            Assert-True ($shares[0].PartialReason -like '*AclReadError=1*') 'Partial reason should summarize ACL read errors.'
            Assert-True ($shares[0].PartialReason -like '*EnumerationError=1*') 'Partial reason should summarize enumeration errors.'
            Assert-True ($findings.FindingType -contains 'CollectionError') 'Findings should preserve collection errors for troubleshooting.'
            Assert-True ($collectionErrors.ErrorType -contains 'AclReadError') 'Collection error export should preserve ACL read error rows.'
            Assert-True ($collectionErrors.ErrorType -contains 'EnumerationError') 'Collection error export should preserve enumeration error rows.'
            Assert-True ($collectionErrors[0].PSObject.Properties.Name -contains 'ErrorId') 'Collection error export should include stable row IDs.'
            Assert-True ($findings.FindingType -contains 'PartialSharePermissionData') 'Findings should include a partial-share row for business review.'
            Assert-Equal $confidenceRows[0].PartialShareCount '1' 'Evidence confidence should count partial shares.'
            Assert-Equal $confidenceRows[0].CollectionErrorCount '2' 'Evidence confidence should count collection errors.'
            Assert-True ($confidenceRows[0].ConfidenceLabel -eq 'Review' -or $confidenceRows[0].ConfidenceLabel -eq 'Partial') 'Evidence confidence should lower the label when scan evidence is incomplete.'
            Assert-True ($confidenceRows[0].ConfidenceLabel -ne 'Good') 'Evidence confidence should not report Good when review or stop gates are present.'
            Assert-True ($confidenceRows[0].Signals -like '*partial share*' -and $confidenceRows[0].Signals -like '*collection error*') 'Evidence confidence signals should explain the incomplete evidence.'
            Assert-True ($confidenceRows[0].ReviewGate -like '*partial*' -or $confidenceRows[0].StopGate -like '*partial*') 'Evidence confidence should expose incomplete collection as a gate before owner signoff.'
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
        Name = 'Invoke-ShareSurferScan optionally collects multiple target paths in parallel'
        Body = {
            Import-Module $moduleManifest -Force
            $scanRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferParallelTargets-' + [guid]::NewGuid().ToString('N'))
            $targetOne = Join-Path $scanRoot 'Finance'
            $targetTwo = Join-Path $scanRoot 'Operations'
            New-Item -ItemType Directory -Path (Join-Path $targetOne 'Reports') -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $targetTwo 'Planning') -Force | Out-Null

            try {
                $outputPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferParallelExport-' + [guid]::NewGuid().ToString('N'))
                $statusText = (& {
                    Invoke-ShareSurferScan -TargetPath @($targetOne, $targetTwo) -OutputPath $outputPath -IncludeFiles -SkipIdentityEnrichment -ParallelTargetCollection -TargetCollectionThrottle 2 -StatusIntervalSeconds 0
                } *>&1 | Out-String)

                $shares = @(Import-Csv -LiteralPath (Join-Path $outputPath 'shares.csv'))
                $items = @(Import-Csv -LiteralPath (Join-Path $outputPath 'items.csv'))
                $events = @(Import-Csv -LiteralPath (Join-Path $outputPath 'scan_events.csv'))

                Assert-Equal $shares.Count 2 'Parallel target scan should export one share row per target.'
                Assert-True ($shares.ShareId -contains 'target-1') 'Parallel target scan should preserve deterministic first target ShareId.'
                Assert-True ($shares.ShareId -contains 'target-2') 'Parallel target scan should preserve deterministic second target ShareId.'
                Assert-True (@($items | Where-Object { $_.FullPath -like "$targetOne*" }).Count -gt 0) 'Parallel target scan should export item evidence for first target.'
                Assert-True (@($items | Where-Object { $_.FullPath -like "$targetTwo*" }).Count -gt 0) 'Parallel target scan should export item evidence for second target.'
                Assert-True ($events.EventType -contains 'ParallelTargetCollectionStarted') 'Scan events should record the parallel collection start boundary.'
                Assert-True ($events.EventType -contains 'ParallelTargetCollectionCompleted') 'Scan events should record the parallel collection completion boundary.'
                Assert-True ($statusText -like '*Parallel target collection enabled*') 'Console status should clearly announce parallel target collection.'
                Assert-True ($statusText -like '*Parallel target collection complete*') 'Console status should report parallel collection completion.'
            }
            finally {
                Remove-Item -LiteralPath $scanRoot -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    },
    @{
        Name = 'Invoke-ShareSurferScan records share-permission collection gaps as collection errors'
        Body = {
            Import-Module $moduleManifest -Force
            $targetPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferBestEffort-' + [guid]::NewGuid().ToString('N'))
            New-Item -ItemType Directory -Path $targetPath -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $targetPath 'readme.txt') -Value 'best effort evidence' -Encoding UTF8
            function global:Get-SmbShare {
                param([string] $Name)
                [pscustomobject]@{
                    Name = $Name
                    Path = $targetPath
                    Description = 'Mocked matching local share'
                }
            }
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
                Remove-Item -Path function:\Get-SmbShare -ErrorAction SilentlyContinue
                Remove-Item -Path function:\Get-SmbShareAccess -ErrorAction SilentlyContinue
            }
        }
    },
    @{
        Name = 'Invoke-ShareSurferScan preserves thrown Get-SmbShareAccess failures'
        Body = {
            Import-Module $moduleManifest -Force
            $targetPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferShareAccessThrow-' + [guid]::NewGuid().ToString('N'))
            New-Item -ItemType Directory -Path $targetPath -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $targetPath 'readme.txt') -Value 'share access throw evidence' -Encoding UTF8
            function global:Get-SmbShare {
                param([string] $Name)
                [pscustomobject]@{
                    Name = $Name
                    Path = $targetPath
                    Description = 'Mocked matching local share'
                }
            }
            function global:Get-SmbShareAccess {
                throw 'mock Get-SmbShareAccess access denied'
            }
            try {
                $outputPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferExport-' + [guid]::NewGuid().ToString('N'))
                Invoke-ShareSurferScan -TargetPath $targetPath -OutputPath $outputPath -IncludeFiles -SkipIdentityEnrichment | Out-Null

                $collectionErrors = @(Import-Csv -LiteralPath (Join-Path $outputPath 'collection_errors.csv'))
                $events = @(Import-Csv -LiteralPath (Join-Path $outputPath 'scan_events.csv'))

                Assert-True (@($collectionErrors | Where-Object { $_.ErrorType -eq 'SharePermissionCollectionUnavailable' }).Count -eq 1) 'Generic share-permission unavailable evidence should still be exported.'
                Assert-True (@($collectionErrors | Where-Object { $_.ErrorType -eq 'GetSmbShareAccessError' -and $_.Message -like '*mock Get-SmbShareAccess access denied*' }).Count -eq 1) 'The original Get-SmbShareAccess exception should be preserved as a specific collection error.'
                Assert-True (@($events | Where-Object { $_.EventType -eq 'GetSmbShareAccessError' -and $_.Message -like '*mock Get-SmbShareAccess access denied*' }).Count -eq 1) 'The original Get-SmbShareAccess exception should be preserved as a scan event.'
            }
            finally {
                Remove-Item -Path function:\Get-SmbShare -ErrorAction SilentlyContinue
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

            $extendedDrivePath = & $module {
                ConvertTo-ShareSurferFilesystemPath -Path 'C:\ShareSurferLab\Finance'
            }
            Assert-Equal $extendedDrivePath '\\?\C:\ShareSurferLab\Finance' 'Filesystem helper should convert local Windows paths to extended-length paths for collector access.'
            $extendedUncPath = & $module {
                ConvertTo-ShareSurferFilesystemPath -Path '\\files01\Finance'
            }
            Assert-Equal $extendedUncPath '\\?\UNC\files01\Finance' 'Filesystem helper should convert UNC paths to extended-length UNC paths for collector access.'
            $displayDrivePath = & $module {
                ConvertFrom-ShareSurferFilesystemPath -Path '\\?\C:\ShareSurferLab\Finance'
            }
            Assert-Equal $displayDrivePath 'C:\ShareSurferLab\Finance' 'Filesystem helper should restore display paths before export.'
            $displayUncPath = & $module {
                ConvertFrom-ShareSurferFilesystemPath -Path '\\?\UNC\files01\Finance'
            }
            Assert-Equal $displayUncPath '\\files01\Finance' 'Filesystem helper should restore display UNC paths before export.'

            $localScannerText = Get-Content -LiteralPath (Join-Path $repoRoot 'src/ShareSurfer/Private/Get-ShareSurferLocalInventory.ps1') -Raw
            $smbScannerText = Get-Content -LiteralPath (Join-Path $repoRoot 'src/ShareSurfer/Private/Get-ShareSurferSmbShareInventory.ps1') -Raw
            Assert-True ($localScannerText -like '*Get-ShareSurferCollectionErrorPath -ErrorRecord $childError*') 'Local scanner should use the collection-error path resolver for enumeration errors.'
            Assert-True ($localScannerText -like '*Source = ''Get-ChildItem''*') 'Local scanner should identify Get-ChildItem as the source for enumeration error rows.'
            Assert-True ($localScannerText -like '*EventType ''EnumerationError''*') 'Local scanner should record enumeration errors as scan events for diagnostics.'
            Assert-True ($localScannerText -like '*ConvertTo-ShareSurferFilesystemPath -Path $target*') 'Local scanner should resolve target roots through extended-length filesystem paths.'
            Assert-True ($localScannerText.Contains('ConvertTo-ShareSurferFilesystemPath -Path ([string]$directoryItem.FullName)')) 'Local scanner should enumerate children through extended-length filesystem paths.'
            Assert-True ($localScannerText.Contains('ConvertTo-ShareSurferFilesystemPath -Path ([string]$scanItem.FullName)')) 'Local scanner should read ACLs through extended-length filesystem paths.'
            Assert-True ($localScannerText -like '*ConvertFrom-ShareSurferFilesystemPath*') 'Local scanner should convert internal filesystem paths back to display paths for exported rows.'
            Assert-True ($localScannerText.Contains('System.Collections.Generic.Queue[object]')) 'Local scanner should use queue-based traversal instead of repeated array growth for large trees.'
            Assert-True ($localScannerText -notmatch 'Get-ChildItem[\s\S]*-Recurse') 'Local scanner should avoid recursive Get-ChildItem traversal that can cross reparse points unexpectedly.'
            Assert-True ($localScannerText -notmatch '\$scanItems\s*\+=') 'Local scanner should avoid quadratic scan item accumulation.'
            Assert-True ($localScannerText -like '*ReparsePointSkipped*') 'Local scanner should record skipped reparse-point directories as scan events.'
            Assert-True ($smbScannerText -like '*Test-Path -LiteralPath (ConvertTo-ShareSurferFilesystemPath -Path $localPath)*') 'SMB scanner should test local share paths through extended-length filesystem paths.'
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
            $findings = Import-Csv -LiteralPath (Join-Path $outputPath 'findings.csv')
            $manifest = Import-Csv -LiteralPath (Join-Path $outputPath 'scan_manifest.csv')

            Assert-True ($identities.Identity -contains 'CONTOSO\Ava.Accounting') 'Identity enrichment should include user members discovered through group expansion.'
            $avaIdentity = @($identities | Where-Object { $_.Identity -eq 'CONTOSO\Ava.Accounting' })[0]
            Assert-Equal $avaIdentity.UserPrincipalName 'ava.accounting@example.test' 'Identity enrichment should export user principal names for correlation.'
            Assert-Equal $avaIdentity.Mail 'ava.accounting@example.test' 'Identity enrichment should export mail for correlation.'
            Assert-Equal $avaIdentity.Department 'Accounts Payable' 'Identity enrichment should export department for owner correlation.'
            Assert-Equal $avaIdentity.Title 'Accounting Analyst' 'Identity enrichment should export job title for owner correlation.'
            Assert-Equal $avaIdentity.Company 'Contoso Finance' 'Identity enrichment should export company for owner correlation.'
            Assert-Equal $avaIdentity.Office 'HQ-4' 'Identity enrichment should export office for owner correlation.'
            Assert-Equal $avaIdentity.AccountEnabled 'True' 'Identity enrichment should export account enabled status when known.'
            Assert-Equal $avaIdentity.ManagerLevel1 'mailto:morgan.manager@example.test' 'Identity enrichment should default first-level manager context to a mailto link for business review.'
            Assert-Equal $avaIdentity.ManagerLevel2 'mailto:riley.director@example.test' 'Identity enrichment should default second-level manager context to a mailto link for business review.'
            Assert-Equal $avaIdentity.ManagerLevel3 'mailto:jordan.vp@example.test' 'Identity enrichment should default third-level manager context to a mailto link for business review.'
            Assert-Equal $avaIdentity.ManagerLevel1Raw 'CONTOSO\Morgan.Manager' 'Identity enrichment should preserve raw first-level manager context for directory correlation.'
            Assert-Equal $avaIdentity.ManagerLevel2Raw 'CONTOSO\Riley.Director' 'Identity enrichment should preserve raw second-level manager context for directory correlation.'
            Assert-Equal $avaIdentity.ManagerLevel3Raw 'CONTOSO\Jordan.VP' 'Identity enrichment should preserve raw third-level manager context for directory correlation.'
            Assert-Equal $avaIdentity.PotentialServiceAccount 'False' 'Identity enrichment should not flag users with employee and OBS data as potential service accounts.'
            Assert-True ($avaIdentity.DistinguishedName -like 'CN=Ava Human Name*') 'Identity enrichment should export distinguished names for directory correlation.'
            $serviceIdentity = @($identities | Where-Object { $_.Identity -eq 'CONTOSO\svc.ShareBot' })[0]
            Assert-Equal $serviceIdentity.PotentialServiceAccount 'True' 'Identity enrichment should flag users with no OBS and no employee identifiers as potential service account candidates.'
            Assert-Equal $serviceIdentity.Title 'Automation Account' 'Identity enrichment should still preserve optional title when a potential service account is flagged.'
            Assert-True ($groupEdges.ParentGroup -contains 'CONTOSO\FinanceEditors') 'Group expansion should include the top-level permission group.'
            Assert-True ($orgChains.Identity -contains 'CONTOSO\Ava.Accounting') 'Org chains should include enriched user manager and OBS data.'
            $avaOrgChain = @($orgChains | Where-Object { $_.Identity -eq 'CONTOSO\Ava.Accounting' })[0]
            Assert-Equal $avaOrgChain.Department 'Accounts Payable' 'Org chains should carry department for manager and OBS rollups.'
            Assert-Equal $avaOrgChain.ManagerLevel3 'mailto:jordan.vp@example.test' 'Org chains should pursue manager context three levels deep and default to mailto display.'
            Assert-Equal $avaOrgChain.ManagerLevel3Raw 'CONTOSO\Jordan.VP' 'Org chains should preserve raw third-level manager context.'
            Assert-True ($orgChains.Identity -contains 'CONTOSO\svc.ShareBot') 'Org chains should include potential service account candidates so report pivots can surface them.'
            Assert-True ($findings.FindingType -contains 'PotentialServiceAccount') 'Findings should flag potential service accounts for report review.'
            Assert-Equal $manifest[0].ManagerIdentityFormat 'MailTo' 'Scan manifest should record the default manager identity display format.'
        }
    },
    @{
        Name = 'Invoke-ShareSurferScan prints identity and export heartbeat status'
        Body = {
            Import-Module $moduleManifest -Force
            $outputPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferHeartbeat-' + [guid]::NewGuid().ToString('N'))

            $statusText = (& {
                Invoke-ShareSurferScan -InputObject (New-TestInventory) -OutputPath $outputPath -AdLookupMode DirectoryOnly -StatusIntervalSeconds 0
            } *>&1 | Out-String)

            Assert-True ($statusText -like '*Identity enrichment roots:*') 'Identity heartbeat should announce root identity count.'
            Assert-True ($statusText -like '*Identity enrichment progress:*') 'Identity heartbeat should announce processed identity progress.'
            Assert-True ($statusText -like '*Group expansion progress:*') 'Identity heartbeat should announce group expansion progress.'
            Assert-True ($statusText -like '*directory lookups=*') 'Identity heartbeat should include directory lookup counters.'
            Assert-True ($statusText -like '*potential service accounts=*') 'Identity heartbeat should include potential service-account counts.'
            Assert-True ($statusText -like '*Conflicts classified:*') 'Export status should report conflict classification completion.'
            Assert-True ($statusText -like '*Finding classification progress:*') 'Export status should report finding classification progress.'
            Assert-True ($statusText -like '*Findings classified:*') 'Export status should report finding classification completion.'
            Assert-True ($statusText -like '*Permissioned group review rows ready:*') 'Export status should report permissioned group row completion.'
            Assert-True ($statusText -like '*Owner/business-unit pivots ready:*') 'Export status should report owner pivot completion.'
            Assert-True ($statusText -like '*Migration discovery rows ready:*') 'Export status should report migration discovery completion.'
            Assert-True ($statusText -like '*Owner review packets ready:*') 'Export status should report owner review packet completion.'
            Assert-True ($statusText -like '*Evidence confidence rows ready:*') 'Export status should report evidence confidence completion.'
            Assert-True ($statusText -like '*Writing CSV*') 'Export status should report CSV writing progress.'

            $events = Import-Csv -LiteralPath (Join-Path $outputPath 'scan_events.csv')
            Assert-True (@($events | Where-Object { $_.EventType -eq 'IdentityEnrichmentStarted' }).Count -eq 1) 'Scan events should include one durable identity start boundary.'
            Assert-True (@($events | Where-Object { $_.EventType -eq 'IdentityEnrichmentCompleted' }).Count -eq 1) 'Scan events should include one durable identity completion boundary.'
            Assert-True (@($events | Where-Object { $_.EventType -eq 'ExportClassificationStarted' }).Count -eq 1) 'Scan events should include one durable export classification start boundary.'
            Assert-True (@($events | Where-Object { $_.EventType -eq 'ExportClassificationCompleted' }).Count -eq 1) 'Scan events should include one durable export classification completion boundary.'
            Assert-True (@($events | Where-Object { $_.EventType -like '*progress*' -or $_.Message -like '*progress*' }).Count -eq 0) 'High-frequency heartbeat progress should stay out of scan_events.csv.'
        }
    },
    @{
        Name = 'Invoke-ShareSurferScan suppresses heartbeat status under Quiet'
        Body = {
            Import-Module $moduleManifest -Force
            $outputPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferHeartbeatQuiet-' + [guid]::NewGuid().ToString('N'))

            $statusText = (& {
                Invoke-ShareSurferScan -InputObject (New-TestInventory) -OutputPath $outputPath -AdLookupMode DirectoryOnly -StatusIntervalSeconds 0 -Quiet
            } *>&1 | Out-String)

            Assert-True ($statusText -notlike '*Identity enrichment roots:*') 'Quiet mode should suppress identity heartbeat status.'
            Assert-True ($statusText -notlike '*Writing CSV*') 'Quiet mode should suppress CSV writing heartbeat status.'
            Assert-True ($statusText -notlike '*Conflicts classified:*') 'Quiet mode should suppress export classification heartbeat status.'

            $events = Import-Csv -LiteralPath (Join-Path $outputPath 'scan_events.csv')
            Assert-True (@($events | Where-Object { $_.EventType -eq 'IdentityEnrichmentCompleted' }).Count -eq 1) 'Quiet mode should still keep durable identity completion events.'
            Assert-True (@($events | Where-Object { $_.EventType -eq 'ExportClassificationCompleted' }).Count -eq 1) 'Quiet mode should still keep durable export classification completion events.'
        }
    },
    @{
        Name = 'Invoke-ShareSurferScan logs manager identity format fallback without stopping export'
        Body = {
            Import-Module $moduleManifest -Force
            $outputPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferExport-' + [guid]::NewGuid().ToString('N'))
            $inventory = New-TestInventory
            $avaDirectory = @($inventory.IdentityDirectory | Where-Object { $_.Identity -eq 'CONTOSO\Ava.Accounting' })[0]
            $avaDirectory.Manager = 'CONTOSO\NoMail.Manager'
            $avaDirectory.ManagerLevel1 = 'CONTOSO\NoMail.Manager'
            $avaDirectory.ManagerLevel2 = ''
            $avaDirectory.ManagerLevel3 = ''
            $inventory.IdentityDirectory += [pscustomobject]@{
                Identity = 'CONTOSO\NoMail.Manager'
                SamAccountName = 'NoMail.Manager'
                DistinguishedName = 'CN=NoMail Manager,OU=Users,DC=example,DC=test'
                DisplayName = 'NoMail Manager'
                ObjectClass = 'user'
                EmployeeId = 'E9001'
                EmployeeNumber = '9001'
                UserPrincipalName = ''
                Mail = ''
                Department = 'Finance'
                Title = 'Manager without mail'
                Company = 'Contoso Finance'
                Office = 'HQ-4'
                AccountEnabled = 'True'
                Manager = ''
                ManagerLevel1 = ''
                ManagerLevel2 = ''
                ManagerLevel3 = ''
                ObsPath = 'CORP.FIN'
                ObsAttribute = 'extensionAttribute10'
                PotentialServiceAccount = $false
                Members = @()
            }

            Invoke-ShareSurferScan -InputObject $inventory -OutputPath $outputPath | Out-Null

            $identities = Import-Csv -LiteralPath (Join-Path $outputPath 'identities.csv')
            $events = Import-Csv -LiteralPath (Join-Path $outputPath 'scan_events.csv')
            $avaIdentity = @($identities | Where-Object { $_.Identity -eq 'CONTOSO\Ava.Accounting' })[0]
            Assert-Equal $avaIdentity.ManagerLevel1 'CONTOSO\NoMail.Manager' 'Manager format fallback should keep the raw manager reference visible.'
            Assert-True (@($events | Where-Object { $_.EventType -eq 'ManagerIdentityFormatFallback' -and $_.Detail -like '*CONTOSO\NoMail.Manager*' }).Count -gt 0) 'Manager format fallback should be logged as a scan event for diagnostics.'
        }
    },
    @{
        Name = 'Invoke-ShareSurferScan records AD lookup mode and marks truncated group expansion'
        Body = {
            Import-Module $moduleManifest -Force
            $outputPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferExport-' + [guid]::NewGuid().ToString('N'))

            Invoke-ShareSurferScan -InputObject (New-TestInventory) -OutputPath $outputPath -AdLookupMode DirectoryOnly -GroupExpansionMaxDepth 1 -IncludeFiles -ObsAttribute 'info' -ManagerIdentityFormat DistinguishedName | Out-Null

            $manifest = Import-Csv -LiteralPath (Join-Path $outputPath 'scan_manifest.csv')
            $groupEdges = Import-Csv -LiteralPath (Join-Path $outputPath 'group_edges.csv')
            $identities = Import-Csv -LiteralPath (Join-Path $outputPath 'identities.csv')

            Assert-Equal $manifest[0].AdLookupMode 'DirectoryOnly' 'Scan manifest should record the requested AD lookup mode.'
            Assert-Equal $manifest[0].ObsAttribute 'info' 'Scan manifest should record the operator-selected OBS attribute.'
            Assert-Equal $manifest[0].IncludeFiles 'True' 'Scan manifest should record whether file objects were requested.'
            Assert-Equal $manifest[0].ManagerIdentityFormat 'DistinguishedName' 'Scan manifest should record the requested manager identity display format.'
            $avaIdentity = @($identities | Where-Object { $_.Identity -eq 'CONTOSO\Ava.Accounting' })[0]
            Assert-Equal $avaIdentity.ManagerLevel1 'CN=Morgan Manager,OU=Users,DC=example,DC=test' 'Manager identity format should support distinguished-name output for directory correlation.'
            Assert-True (@($groupEdges | Where-Object { $_.ParentGroup -eq 'CONTOSO\FinanceEditors' -and $_.IsTruncated -eq 'True' }).Count -gt 0) 'Group expansion should mark edges truncated at the configured max depth.'
        }
    },
    @{
        Name = 'LDAP identity normalization preserves three-level manager chains and OBS attributes'
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

            $user = New-ShareSurferLdapIdentityRecord -Identity 'CONTOSO\Ava.Accounting' -Properties $userProperties -ObsAttribute 'extensionAttribute10' -ManagerLevel2 'CN=Taylor Director,OU=Users,DC=example,DC=test' -ManagerLevel3 'CN=Jordan VP,OU=Users,DC=example,DC=test'
            Assert-Equal $user.ObjectClass 'user' 'LDAP user record should identify user object class.'
            Assert-Equal $user.ManagerLevel1 'CN=Morgan Manager,OU=Users,DC=example,DC=test' 'LDAP user record should preserve direct manager DN.'
            Assert-Equal $user.ManagerLevel2 'CN=Taylor Director,OU=Users,DC=example,DC=test' 'LDAP user record should preserve manager manager DN.'
            Assert-Equal $user.ManagerLevel3 'CN=Jordan VP,OU=Users,DC=example,DC=test' 'LDAP user record should preserve third-level manager DN.'
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
            Assert-True ($ldapScript -like '*ManagerLevel3*') 'LDAP fallback should resolve third-level manager context for org-chain rollups.'
            $dnResolverScript = Get-Content -LiteralPath (Join-Path $repoRoot 'src/ShareSurfer/Private/Resolve-ShareSurferDistinguishedNameIdentity.ps1') -Raw
            foreach ($propertyName in @('userPrincipalName', 'mail', 'department', 'title', 'company', 'physicalDeliveryOfficeName', 'userAccountControl', 'distinguishedName')) {
                Assert-True ($dnResolverScript -like ('*{0}*' -f $propertyName)) ('LDAP DN member resolution should load {0} for group-expanded identity correlation.' -f $propertyName)
            }
        }
    },
    @{
        Name = 'ActiveDirectory manager-chain lookup stops when manager references cycle'
        Body = {
            Import-Module $moduleManifest -Force
            . (Join-Path $repoRoot 'src/ShareSurfer/Private/Get-ShareSurferIdentityName.ps1')
            . (Join-Path $repoRoot 'src/ShareSurfer/Private/Get-ShareSurferIdentityDomain.ps1')
            . (Join-Path $repoRoot 'src/ShareSurfer/Private/Get-ShareSurferDirectoryIdentity.ps1')

            try {
                function global:Get-ADUser {
                    param(
                        [string] $Identity,
                        [string[]] $Properties
                    )

                    switch ($Identity) {
                        'Ava.Accounting' {
                            [pscustomobject]@{
                                SamAccountName = 'Ava.Accounting'
                                DisplayName = 'Ava Accounting'
                                EmployeeID = 'E1001'
                                employeeNumber = '1001'
                                UserPrincipalName = 'ava.accounting@example.test'
                                Mail = 'ava.accounting@example.test'
                                Department = 'Accounts Payable'
                                Title = 'Accounting Analyst'
                                Company = 'Contoso Finance'
                                physicalDeliveryOfficeName = 'HQ-4'
                                Enabled = $true
                                Manager = 'CN=Morgan Manager,OU=Users,DC=example,DC=test'
                                extensionAttribute10 = 'CORP.FIN.AP'
                                DistinguishedName = 'CN=Ava Accounting,OU=Users,DC=example,DC=test'
                            }
                        }
                        'CN=Morgan Manager,OU=Users,DC=example,DC=test' {
                            [pscustomobject]@{ SamAccountName = 'Morgan.Manager'; Manager = 'CN=Riley Director,OU=Users,DC=example,DC=test' }
                        }
                        'CN=Riley Director,OU=Users,DC=example,DC=test' {
                            [pscustomobject]@{ SamAccountName = 'Riley.Director'; Manager = 'CN=Morgan Manager,OU=Users,DC=example,DC=test' }
                        }
                        default {
                            throw ('Unexpected Get-ADUser identity {0}' -f $Identity)
                        }
                    }
                }
                function global:Get-ADGroup {
                    throw 'User lookup should succeed before group fallback.'
                }

                $identity = Get-ShareSurferDirectoryIdentity -Identity 'CONTOSO\Ava.Accounting' -ObsAttribute 'extensionAttribute10' -AdLookupMode ActiveDirectory
                Assert-Equal $identity.ManagerLevel1 'CN=Morgan Manager,OU=Users,DC=example,DC=test' 'AD manager chain should keep the direct manager.'
                Assert-Equal $identity.ManagerLevel2 'CN=Riley Director,OU=Users,DC=example,DC=test' 'AD manager chain should include the next manager before the cycle.'
                Assert-Equal $identity.ManagerLevel3 '' 'AD manager chain should stop before repeating a previously seen manager.'
            }
            finally {
                Remove-Item -Path function:\Get-ADUser -ErrorAction SilentlyContinue
                Remove-Item -Path function:\Get-ADGroup -ErrorAction SilentlyContinue
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
            $direct = @($items | Where-Object { $_.ItemId -eq 'item-deep' })[0]
            $findings = @(Import-Csv -LiteralPath (Join-Path $outputPath 'findings.csv'))
            $brokenFindings = @($findings | Where-Object { $_.FindingType -eq 'BrokenInheritance' })

            Assert-Equal $child.InheritanceBrokenAt '\\files01\Finance\Delegated' 'Descendants should retain the ancestor where inheritance first broke.'
            Assert-Equal $child.InheritanceBreakType 'InheritedAncestor' 'Descendants should carry inherited break context instead of being direct broken-inheritance rows.'
            Assert-Equal $direct.InheritanceBreakType 'Direct' 'Rows with protected inheritance should export direct break context.'
            Assert-Equal (@($brokenFindings | Where-Object { $_.ItemId -eq 'item-child' }).Count) 0 'Descendants under a break should not create duplicate broken-inheritance findings.'
            Assert-Equal (@($brokenFindings | Where-Object { $_.ItemId -eq 'item-deep' }).Count) 1 'The direct inheritance break should remain a review finding.'
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
        Name = 'Invoke-ShareSurferScan exports owner mapping validation warnings as scan events'
        Body = {
            Import-Module $moduleManifest -Force
            $outputPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferExportOwnerMappingWarnings-' + [guid]::NewGuid().ToString('N'))
            $mappingPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferOwnerMapWarnings-' + [guid]::NewGuid().ToString('N') + '.csv')
            Set-Content -LiteralPath $mappingPath -Value @(
                'Pattern,Owner,BusinessUnit,Source',
                '\\files01\Finance*,Finance Operations,,warning-test'
            ) -Encoding UTF8

            Invoke-ShareSurferScan -InputObject (New-TestInventory) -OutputPath $outputPath -OwnerMappingPath $mappingPath -SkipIdentityEnrichment | Out-Null
            $events = @(Import-Csv -LiteralPath (Join-Path $outputPath 'scan_events.csv'))

            Assert-True (@($events | Where-Object { $_.EventType -eq 'OwnerMappingValidationWarning' -and $_.Message -like '*blank BusinessUnit*' }).Count -eq 1) 'Blank BusinessUnit warnings should be visible in scan_events.csv.'
            Assert-True (@($events | Where-Object { $_.EventType -eq 'OwnerMappingValidationWarning' -and $_.Message -like '*may match sibling paths*' }).Count -eq 1) 'Sibling-prefix warnings should be visible in scan_events.csv.'
            Assert-True (@($events | Where-Object { $_.EventType -eq 'OwnerMappingValidationWarning' -and $_.Detail -like '*Problem=BlankBusinessUnit*' }).Count -eq 1) 'Owner mapping warning event detail should preserve the validation problem.'
        }
    },
    @{
        Name = 'Test-ShareSurferOwnerMapping validates required columns and row values'
        Body = {
            Import-Module $moduleManifest -Force
            $missingColumnPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferOwnerMapMissing-' + [guid]::NewGuid().ToString('N') + '.csv')
            $blankValuePath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferOwnerMapBlank-' + [guid]::NewGuid().ToString('N') + '.csv')
            $blankBusinessUnitPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferOwnerMapBlankBu-' + [guid]::NewGuid().ToString('N') + '.csv')
            $headersOnlyPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferOwnerMapHeadersOnly-' + [guid]::NewGuid().ToString('N') + '.csv')
            $validPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferOwnerMapValid-' + [guid]::NewGuid().ToString('N') + '.csv')
            Set-Content -LiteralPath $missingColumnPath -Value @('Pattern,Owner', '\\files01\Finance\*,Finance Operations') -Encoding UTF8
            Set-Content -LiteralPath $blankValuePath -Value @('Pattern,Owner,BusinessUnit', '\\files01\Finance\*,Finance Operations,Finance', '\\files01\HR\*,,Human Resources') -Encoding UTF8
            Set-Content -LiteralPath $blankBusinessUnitPath -Value @('Pattern,Owner,BusinessUnit', '\\files01\Finance\*,Finance Operations,') -Encoding UTF8
            Set-Content -LiteralPath $headersOnlyPath -Value @('Pattern,Owner,BusinessUnit') -Encoding UTF8
            Set-Content -LiteralPath $validPath -Value @('Pattern,Owner,BusinessUnit,Source', '\\files01\Finance\*,Finance Operations,Finance,unit-test') -Encoding UTF8

            $missingColumn = Test-ShareSurferOwnerMapping -Path $missingColumnPath
            $blankValue = Test-ShareSurferOwnerMapping -Path $blankValuePath
            $blankBusinessUnit = Test-ShareSurferOwnerMapping -Path $blankBusinessUnitPath
            $headersOnly = Test-ShareSurferOwnerMapping -Path $headersOnlyPath
            $valid = Test-ShareSurferOwnerMapping -Path $validPath

            Assert-True (-not $missingColumn.IsValid) 'Owner mapping validation should fail when BusinessUnit is missing.'
            Assert-True ((@($missingColumn.Errors) -join ' ') -like '*missing required column*BusinessUnit*') 'Missing-column error should name the missing required column.'
            Assert-True (-not $blankValue.IsValid) 'Owner mapping validation should fail when a required row value is blank.'
            Assert-True ((@($blankValue.Errors) -join ' ') -like '*blank Owner*') 'Blank value error should name the blank required value.'
            Assert-True $blankBusinessUnit.IsValid 'Blank BusinessUnit values should warn without blocking scans.'
            Assert-True ((@($blankBusinessUnit.Warnings) -join ' ') -like '*blank BusinessUnit*') 'Blank BusinessUnit warning should name the attribution gap.'
            Assert-True $headersOnly.IsValid 'Headers-only owner mapping files should warn without blocking scans.'
            Assert-True ((@($headersOnly.Warnings) -join ' ') -like '*headers but no data rows*') 'Headers-only owner mapping warning should explain that no mappings will be added.'
            Assert-True $valid.IsValid 'Owner mapping validation should pass with Pattern, Owner, and BusinessUnit populated.'
            Assert-Equal (Get-Command -Name Test-ShareSurferOwnerMapping -Module ShareSurfer).Name 'Test-ShareSurferOwnerMapping' 'Owner mapping validator should be exported.'
        }
    },
    @{
        Name = 'Test-ShareSurferOwnerMapping warns on sibling-prefix patterns and verifies export matches'
        Body = {
            Import-Module $moduleManifest -Force
            $exportPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferExport-' + [guid]::NewGuid().ToString('N'))
            $mappingPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferOwnerMapSibling-' + [guid]::NewGuid().ToString('N') + '.csv')
            Invoke-ShareSurferScan -InputObject (New-TestInventory) -OutputPath $exportPath -SkipIdentityEnrichment | Out-Null
            Set-Content -LiteralPath $mappingPath -Value @(
                'Pattern,Owner,BusinessUnit,Source',
                '\\files01\Finance*,Finance Operations,Finance,old-shape',
                '\\files01\Finance\*,Finance Operations,Finance,boundary-safe',
                '\\files01\NoSuchShare\*,Ghost Owner,Ghost,dead-pattern'
            ) -Encoding UTF8

            $result = Test-ShareSurferOwnerMapping -Path $mappingPath -ExportPath $exportPath

            Assert-True $result.IsValid 'Sibling-prefix warnings should not make an otherwise complete mapping invalid.'
            Assert-True ((@($result.Warnings) -join ' ') -like '*may match sibling paths*') 'Validator should warn about sibling-prefix wildcard patterns.'
            Assert-Equal $result.ZeroMatchPatternCount 1 'Validator should count patterns that match no share or item paths.'
            Assert-True ((@($result.Warnings) -join ' ') -like '*NoSuchShare*') 'Validator should name the dead pattern.'
        }
    },
    @{
        Name = 'Test-ShareSurferOwnerMapping defers item candidate loading when shares match'
        Body = {
            Import-Module $moduleManifest -Force
            $exportPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferExportLazyItems-' + [guid]::NewGuid().ToString('N'))
            $mappingPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferOwnerMapLazyItems-' + [guid]::NewGuid().ToString('N') + '.csv')
            New-Item -ItemType Directory -Path $exportPath -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $exportPath 'shares.csv') -Value @(
                'ShareId,Source,ComputerName,ShareName,UNCPath,LocalPath,Description,PartialData,PartialReason',
                'share-finance,Fixture,files01,Finance,\\files01\Finance,C:\Finance,Finance share,False,'
            ) -Encoding UTF8
            New-Item -ItemType Directory -Path (Join-Path $exportPath 'items.csv') -Force | Out-Null
            Set-Content -LiteralPath $mappingPath -Value @(
                'Pattern,Owner,BusinessUnit,Source',
                '\\files01\Finance\*,Finance Operations,Finance,unit-test'
            ) -Encoding UTF8

            $result = Test-ShareSurferOwnerMapping -Path $mappingPath -ExportPath $exportPath

            Assert-True $result.IsValid 'Owner mapping validation should pass when the pattern matches a share path.'
            Assert-Equal $result.ZeroMatchPatternCount 0 'Share-level matches should avoid item candidate loading.'
        }
    },
    @{
        Name = 'Test-ShareSurferOwnershipSource infers flexible ownership headers'
        Body = {
            Import-Module $moduleManifest -Force
            $sourcePath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferOwnershipSource-' + [guid]::NewGuid().ToString('N') + '.csv')
            @(
                [pscustomobject]@{
                    employee_number = '1001'
                    display_name = 'Ava Accounting'
                    mail_address = 'ava.accounting@example.test'
                    cost_center_path = 'CORP.FIN.AP'
                    mgr_email = 'manager@example.test'
                    title = 'Accounting Analyst'
                    location = 'HQ-4'
                    business_unit = 'Finance'
                }
            ) | Export-Csv -LiteralPath $sourcePath -NoTypeInformation -Encoding UTF8

            $result = Test-ShareSurferOwnershipSource -Path $sourcePath

            Assert-True $result.IsUsable 'Ownership source should be usable when at least one join key can be inferred.'
            Assert-Equal $result.FieldMap.EmployeeNumber 'employee_number' 'employee_number should map to EmployeeNumber.'
            Assert-Equal $result.FieldMap.Mail 'mail_address' 'mail_address should map to Mail.'
            Assert-Equal $result.FieldMap.OBS 'cost_center_path' 'cost_center_path should map to OBS.'
            Assert-Equal $result.FieldMap.ManagerMail 'mgr_email' 'mgr_email should map to ManagerMail.'
            Assert-Equal $result.FieldMap.Office 'location' 'location should map to Office.'
            Assert-True ([string]$result.JoinKeyFields -like '*EmployeeNumber*') 'Join key summary should mention EmployeeNumber.'
            Assert-True ([string]$result.CanonicalHeaders -like '*EmployeeId*') 'Result should tell operators the canonical headers ShareSurfer understands.'
        }
    },
    @{
        Name = 'Test-ShareSurferOwnershipSource explains missing join keys'
        Body = {
            Import-Module $moduleManifest -Force
            $sourcePath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferOwnershipSource-' + [guid]::NewGuid().ToString('N') + '.csv')
            @(
                [pscustomobject]@{
                    friendly_name = 'Mystery Person'
                    org_path = 'CORP.UNKNOWN'
                }
            ) | Export-Csv -LiteralPath $sourcePath -NoTypeInformation -Encoding UTF8

            $result = Test-ShareSurferOwnershipSource -Path $sourcePath

            Assert-True (-not $result.IsUsable) 'Ownership source should not be considered usable without a stable join key.'
            Assert-True ((@($result.Warnings) -join ' ') -like '*EmployeeId, EmployeeNumber, SamAccountName, UserPrincipalName, or Mail*') 'Warning should tell the operator which join key headers are acceptable.'
            Assert-True ([string]$result.CanonicalHeaders -like '*OBS*') 'Result should include the OBS canonical header in the guidance.'
        }
    },
    @{
        Name = 'New-ShareSurferOwnershipMappingProfile writes reusable header mappings'
        Body = {
            Import-Module $moduleManifest -Force
            $sourcePath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferOwnershipSource-' + [guid]::NewGuid().ToString('N') + '.csv')
            $profilePath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferOwnershipSource-' + [guid]::NewGuid().ToString('N') + '.mapping.json')
            $commandPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferOwnershipSource-' + [guid]::NewGuid().ToString('N') + '.rerun.ps1')
            @(
                [pscustomobject]@{
                    workerid = 'E1001'
                    user_name = 'Ava.Accounting'
                    org_path = 'CORP.FIN.AP'
                    owner_email = 'finance.owner@example.test'
                }
            ) | Export-Csv -LiteralPath $sourcePath -NoTypeInformation -Encoding UTF8

            $summary = New-ShareSurferOwnershipMappingProfile -Path $sourcePath -OutputPath $profilePath -SourceName 'HR OBS export' -ObsHeader 'org_path' -ReusableCommandPath $commandPath
            $profile = Get-Content -LiteralPath $profilePath -Raw | ConvertFrom-Json
            $assessment = Test-ShareSurferOwnershipSource -Path $sourcePath -MappingProfilePath $profilePath
            $commandText = Get-Content -LiteralPath $commandPath -Raw

            Assert-True (Test-Path -LiteralPath $profilePath) 'Mapping profile should be written to disk.'
            Assert-Equal $summary.SourceName 'HR OBS export' 'Profile summary should preserve the provided source name.'
            Assert-Equal $profile.FieldMap.EmployeeId 'workerid' 'Profile should preserve the inferred employee ID source header.'
            Assert-Equal $profile.FieldMap.OBS 'org_path' 'Profile should preserve the operator-selected OBS header.'
            Assert-Equal $profile.FieldMap.OwnerMail 'owner_email' 'Profile should preserve owner mail mapping.'
            Assert-True $assessment.IsUsable 'A saved mapping profile should be reusable by the source tester.'
            Assert-Equal $summary.ReusableCommandPath $commandPath 'Profile summary should report the reusable command file path.'
            Assert-True ([string]$summary.ReusableCommands -like '*Import-ShareSurferOwnershipSource*') 'Profile summary should return reusable import commands.'
            Assert-True ([string]$summary.ReusableCommands -like '*MappingProfilePath*') 'Reusable profile commands should reuse the saved mapping profile.'
            Assert-True ($commandText -like '*Test-ShareSurferOwnershipSource*') 'Reusable command file should include a source test command.'
            Assert-True ($commandText -like '*normalized-ownership.csv*') 'Reusable command file should include a default normalized output path.'
        }
    },
    @{
        Name = 'New-ShareSurferOwnershipMappingProfile interactive skips stay blank'
        Body = {
            Import-Module $moduleManifest -Force
            $sourcePath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferOwnershipSource-' + [guid]::NewGuid().ToString('N') + '.csv')
            $profilePath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferOwnershipSource-' + [guid]::NewGuid().ToString('N') + '.mapping.json')
            @(
                [pscustomobject]@{
                    workerid = 'E1001'
                    user_name = 'Ava.Accounting'
                    org_path = 'CORP.FIN.AP'
                    owner_email = 'finance.owner@example.test'
                }
            ) | Export-Csv -LiteralPath $sourcePath -NoTypeInformation -Encoding UTF8

            $script:shareSurferPromptAnswers = New-Object 'System.Collections.Generic.Queue[string]'
            for ($index = 0; $index -lt 22; $index++) {
                $script:shareSurferPromptAnswers.Enqueue('S')
            }
            function global:Read-Host {
                param([string] $Prompt)
                if ($script:shareSurferPromptAnswers.Count -eq 0) {
                    throw ('Unexpected prompt: {0}' -f $Prompt)
                }
                $script:shareSurferPromptAnswers.Dequeue()
            }

            try {
                New-ShareSurferOwnershipMappingProfile -Path $sourcePath -OutputPath $profilePath -Interactive -Force | Out-Null
                $profile = Get-Content -LiteralPath $profilePath -Raw | ConvertFrom-Json

                Assert-Equal $profile.FieldMap.EmployeeId '' 'A deliberate interactive skip should stay blank in the saved profile.'
                Assert-Equal $profile.FieldMap.OBS '' 'A deliberate interactive skip should not be auto-remapped by profile creation.'
                Assert-Equal $script:shareSurferPromptAnswers.Count 0 'Profile interview should consume one answer per canonical field.'
            }
            finally {
                Remove-Item -Path function:\Read-Host -ErrorAction SilentlyContinue
                Remove-Variable -Name shareSurferPromptAnswers -Scope Script -ErrorAction SilentlyContinue
            }
        }
    },
    @{
        Name = 'Import-ShareSurferOwnershipSource normalizes rows and flags review warnings'
        Body = {
            Import-Module $moduleManifest -Force
            $sourcePath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferOwnershipSource-' + [guid]::NewGuid().ToString('N') + '.csv')
            $profilePath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferOwnershipSource-' + [guid]::NewGuid().ToString('N') + '.mapping.json')
            $outputPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferOwnershipNormalized-' + [guid]::NewGuid().ToString('N') + '.csv')
            $commandPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferOwnershipNormalized-' + [guid]::NewGuid().ToString('N') + '.rerun.ps1')
            @(
                [pscustomobject]@{
                    employee_number = '1001'
                    display_name = 'Ava Accounting'
                    mail_address = 'ava.accounting@example.test'
                    cost_center_path = 'CORP.FIN.AP'
                    mgr_email = 'manager@example.test'
                    title = 'Accounting Analyst'
                    location = 'HQ-4'
                    sam = 'Ava.Accounting'
                    business_unit = 'Finance'
                },
                [pscustomobject]@{
                    employee_number = '1001'
                    display_name = 'Duplicate Employee'
                    mail_address = 'duplicate.employee@example.test'
                    cost_center_path = 'CORP.FIN.AP'
                    mgr_email = 'manager@example.test'
                    title = 'Reviewer'
                    location = 'HQ-4'
                    sam = 'Duplicate.Employee'
                    business_unit = 'Finance'
                },
                [pscustomobject]@{
                    employee_number = ''
                    display_name = 'Share Bot'
                    mail_address = 'svc.sharebot@example.test'
                    cost_center_path = ''
                    mgr_email = ''
                    title = 'Automation Account'
                    location = 'DataCenter'
                    sam = 'svc.ShareBot'
                    business_unit = 'IT'
                }
            ) | Export-Csv -LiteralPath $sourcePath -NoTypeInformation -Encoding UTF8

            New-ShareSurferOwnershipMappingProfile -Path $sourcePath -OutputPath $profilePath -Force | Out-Null
            $summary = Import-ShareSurferOwnershipSource -Path $sourcePath -MappingProfilePath $profilePath -OutputPath $outputPath -ReusableCommandPath $commandPath
            $rows = Import-Csv -LiteralPath $outputPath
            $commandText = Get-Content -LiteralPath $commandPath -Raw

            Assert-Equal $summary.RowCount 3 'Import summary should report normalized row count.'
            Assert-Equal $summary.PotentialServiceAccountCount 1 'Import summary should count potential service-account-like rows.'
            Assert-Equal $rows[0].EmployeeNumber '1001' 'Normalized CSV should preserve employee number.'
            Assert-Equal $rows[0].OBS 'CORP.FIN.AP' 'Normalized CSV should preserve OBS.'
            Assert-Equal $rows[0].ManagerMail 'manager@example.test' 'Normalized CSV should preserve manager mail.'
            Assert-Equal $rows[0].Title 'Accounting Analyst' 'Normalized CSV should preserve title.'
            Assert-Equal $rows[0].Office 'HQ-4' 'Normalized CSV should preserve office.'
            Assert-True ([string]$rows[1].ImportWarnings -like '*DuplicateEmployeeNumber*') 'Duplicate employee numbers should be flagged for review.'
            Assert-Equal $rows[2].PotentialServiceAccount 'True' 'Rows with no OBS and no employee identifiers should be flagged as potential service-account-like identities.'
            Assert-True ([string]$rows[2].ImportWarnings -like '*PotentialServiceAccount*') 'Potential service-account-like rows should carry an import warning.'
            Assert-Equal $summary.ReusableCommandPath $commandPath 'Import summary should report the reusable command file path.'
            Assert-True ([string]$summary.ReusableCommands -like '*Import-ShareSurferOwnershipSource*') 'Import summary should return reusable import commands.'
            Assert-True ($commandText -like '*MappingProfilePath*') 'Reusable import command file should keep the mapping profile path.'
            Assert-True ($commandText -like '*OutputPath `$normalizedPath*') 'Reusable import command file should preserve the normalized output variable.'
        }
    },
    @{
        Name = 'Ownership import definition round-trips selected paths and settings'
        Body = {
            Import-Module $moduleManifest -Force
            $definitionPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferOwnershipDefinition-' + [guid]::NewGuid().ToString('N') + '.json')
            $sourceOne = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferDefinitionHr-' + [guid]::NewGuid().ToString('N') + '.csv')
            $sourceTwo = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferDefinitionProject-' + [guid]::NewGuid().ToString('N') + '.csv')
            $outputPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferDefinitionOutput-' + [guid]::NewGuid().ToString('N') + '.csv')
            Set-Content -LiteralPath $sourceOne -Value @('EmployeeID,OBS,BusinessUnit', 'E1001,CORP.FIN.AP,Finance') -Encoding UTF8
            Set-Content -LiteralPath $sourceTwo -Value @('OBS,ProjectCode,Project', 'CORP.FIN.AP,AP-2026,Accounts Payable') -Encoding UTF8

            Join-ShareSurferOwnershipSources `
                -Path @($sourceOne, $sourceTwo) `
                -DefinitionPath $definitionPath `
                -OutputPath $outputPath `
                -ObsHeader 'Org Path' `
                -ObsAttribute 'info' `
                -AdLookupMode 'DirectoryOnly' `
                -ForbiddenOu @('OU=Disabled,DC=example,DC=test') `
                -Force | Out-Null

            $definition = Get-Content -LiteralPath $definitionPath -Raw | ConvertFrom-Json
            Assert-Equal $definition.version 1 'Definition version should be 1.'
            Assert-Equal @($definition.selectedCsvPaths).Count 2 'Definition should preserve selected CSV paths.'
            Assert-Equal $definition.obsHeader 'Org Path' 'Definition should preserve OBS header.'
            Assert-Equal $definition.obsAttribute 'info' 'Definition should preserve OBS attribute.'
            Assert-Equal $definition.adLookupMode 'DirectoryOnly' 'Definition should preserve AD lookup mode.'
            Assert-Equal @($definition.forbiddenOus).Count 1 'Definition should preserve forbidden OUs.'
            Assert-True (-not [string]::IsNullOrWhiteSpace([string]$definition.createdAt)) 'Definition should include created metadata.'
            Assert-True (-not [string]::IsNullOrWhiteSpace([string]$definition.updatedAt)) 'Definition should include updated metadata.'
        }
    },
    @{
        Name = 'CSV picker state toggles files and navigates folders'
        Body = {
            Import-Module $moduleManifest -Force
            . (Join-Path $repoRoot 'src/ShareSurfer/Public/Join-ShareSurferOwnershipSources.ps1')
            $root = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferPickerRoot-' + [guid]::NewGuid().ToString('N'))
            $child = Join-Path $root 'Child'
            New-Item -ItemType Directory -Path $child -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $root 'a.csv') -Value 'EmployeeID,OBS' -Encoding UTF8
            Set-Content -LiteralPath (Join-Path $child 'b.csv') -Value 'EmployeeID,OBS' -Encoding UTF8

            $state = New-ShareSurferCsvPickerState -StartFolder $root
            $view = Get-ShareSurferCsvPickerView -State $state
            Assert-True (@($view.Entries | Where-Object { $_.Name -eq 'a.csv' }).Count -eq 1) 'Picker should show CSV files.'

            Invoke-ShareSurferCsvPickerCommand -State $state -Command '2' | Out-Null
            Assert-Equal @($state.SelectedCsvPaths).Count 1 'Numeric CSV command should toggle selection.'

            Invoke-ShareSurferCsvPickerCommand -State $state -Command '1' | Out-Null
            Assert-True ([string]$state.CurrentFolder -like '*Child') 'Numeric folder command should navigate into folder.'

            Invoke-ShareSurferCsvPickerCommand -State $state -Command 'A' | Out-Null
            Assert-Equal @($state.SelectedCsvPaths).Count 2 'A should select all CSVs in the current folder.'

            Invoke-ShareSurferCsvPickerCommand -State $state -Command 'C' | Out-Null
            Assert-Equal @($state.SelectedCsvPaths).Count 0 'C should clear selected CSVs.'
        }
    },
    @{
        Name = 'Console choice state supports keyboard-style navigation and cancellation'
        Body = {
            Import-Module $moduleManifest -Force
            . (Join-Path $repoRoot 'src/ShareSurfer/Private/ShareSurfer.Console.ps1')
            $state = New-ShareSurferConsoleChoiceState -Options @(
                (New-ShareSurferConsoleChoiceOption -Value 'One'),
                (New-ShareSurferConsoleChoiceOption -Value 'Two'),
                (New-ShareSurferConsoleChoiceOption -Value 'Three')
            ) -DefaultValue 'One'

            Invoke-ShareSurferConsoleChoiceCommand -State $state -Command 'Down' -AllowBack -AllowSkip -AllowQuit | Out-Null
            Assert-Equal $state.SelectedIndex 1 'Down should advance the selection.'
            Invoke-ShareSurferConsoleChoiceCommand -State $state -Command 'Up' -AllowBack -AllowSkip -AllowQuit | Out-Null
            Assert-Equal $state.SelectedIndex 0 'Up should move the selection back.'
            Invoke-ShareSurferConsoleChoiceCommand -State $state -Command '3' -AllowBack -AllowSkip -AllowQuit | Out-Null
            Assert-Equal $state.Action 'Select' 'Numbered fallback should select an option.'
            Assert-Equal $state.SelectedValue 'Three' 'Numbered fallback should select the requested value.'

            $backState = New-ShareSurferConsoleChoiceState -Options @('One', 'Two') -DefaultValue 'One'
            Invoke-ShareSurferConsoleChoiceCommand -State $backState -Command 'B' -AllowBack | Out-Null
            Assert-Equal $backState.Action 'Back' 'B should request back navigation when allowed.'

            $cancelState = New-ShareSurferConsoleChoiceState -Options @('One', 'Two') -DefaultValue 'Two'
            Assert-Equal $cancelState.SelectedIndex 1 'Default value should seed the selected index.'
            Invoke-ShareSurferConsoleChoiceCommand -State $cancelState -Command 'Q' -AllowQuit | Out-Null
            Assert-Equal $cancelState.Action 'Cancel' 'Q should report a Cancel action under the cancellation contract.'
            Assert-Equal $cancelState.SelectedValue '' 'Cancellation must not return a normal field value.'

            $disabledState = New-ShareSurferConsoleChoiceState -Options @(
                (New-ShareSurferConsoleChoiceOption -Value 'Disabled' -Enabled $false -UnavailableReason 'Finish setup first.'),
                (New-ShareSurferConsoleChoiceOption -Value 'Ready'),
                (New-ShareSurferConsoleChoiceOption -Value 'AlsoDisabled' -Enabled $false -UnavailableReason 'No export yet.')
            ) -DefaultValue 'Disabled'
            Assert-Equal $disabledState.SelectedIndex 1 'Default selection should move to the first enabled choice.'
            Invoke-ShareSurferConsoleChoiceCommand -State $disabledState -Command '1' | Out-Null
            Assert-Equal $disabledState.Done $false 'A disabled numbered choice must not complete selection.'
            Assert-True ([string]$disabledState.Message -like '*Finish setup first*') 'A disabled choice should explain its prerequisite.'
            Invoke-ShareSurferConsoleChoiceCommand -State $disabledState -Command 'Down' | Out-Null
            Assert-Equal $disabledState.SelectedIndex 1 'Arrow navigation should skip disabled choices and remain on the only enabled choice.'

            $noBackState = New-ShareSurferConsoleChoiceState -Options @('One', 'Two') -DefaultValue 'One'
            Invoke-ShareSurferConsoleChoiceCommand -State $noBackState -Command 'B' | Out-Null
            Assert-Equal $noBackState.Done $false 'B should not finish a prompt when back navigation is not enabled.'
            Assert-True ([string]$noBackState.Message -like '*Back is not available*') 'Disabled back navigation should explain why B did not work.'

            $plainScreen = @(Get-ShareSurferConsoleChoiceScreen -State (New-ShareSurferConsoleChoiceState -Options @('One', 'Two')) -Title 'Pick one' -AllowQuit) -join [Environment]::NewLine
            Assert-True ($plainScreen -like '*Q=quit*') 'Choice screen should show quit when cancellation is enabled.'
            Assert-True (-not ($plainScreen -like '*B=back*')) 'Choice screen should not advertise back when the prompt cannot go back.'
            Assert-True (-not ($plainScreen -like '*S=skip*')) 'Choice screen should not advertise skip when the prompt cannot skip.'

            $backSkipScreen = @(Get-ShareSurferConsoleChoiceScreen -State (New-ShareSurferConsoleChoiceState -Options @('One', 'Two')) -Title 'Pick one' -AllowSkip -AllowBack -AllowQuit) -join [Environment]::NewLine
            Assert-True ($backSkipScreen -like '*B=back*') 'Choice screen should advertise back when enabled.'
            Assert-True ($backSkipScreen -like '*S=skip*') 'Choice screen should advertise skip when enabled.'

            $shimState = New-ShareSurferPromptChoiceState -Options @('One', 'Two') -DefaultValue 'One'
            Invoke-ShareSurferPromptChoiceCommand -State $shimState -Command '2' | Out-Null
            Assert-Equal $shimState.SelectedValue 'Two' 'Compatibility shims should keep the legacy prompt names working.'

            $yesNoState = New-ShareSurferConsoleChoiceState -Options @(
                (New-ShareSurferConsoleChoiceOption -Value 'Yes'),
                (New-ShareSurferConsoleChoiceOption -Value 'No')
            ) -DefaultValue 'No'
            Invoke-ShareSurferConsoleChoiceCommand -State $yesNoState -Command 'Y' | Out-Null
            Assert-Equal $yesNoState.SelectedValue 'Yes' 'Boolean choice prompts should preserve Y/N shortcuts.'

            $plainCapabilities = Get-ShareSurferConsoleCapabilities -ConsoleMode Plain
            Assert-Equal $plainCapabilities.EffectiveConsoleMode 'Plain' 'Plain console mode should force the numbered fallback.'
            Assert-Equal $plainCapabilities.RawKeys $false 'Plain console mode should not require raw key support.'
            $launcherText = Get-Content -LiteralPath (Join-Path $repoRoot 'Start-ShareSurfer.ps1') -Raw
            Assert-True ($launcherText -like "*`$ConsoleMode = 'Plain'*") 'Release-root launcher should default to the reliable plain console mode.'
            $singleFrameBehavior = Get-ShareSurferConsoleChoiceRenderBehavior -Capabilities ([pscustomobject]@{ RedrawMode = 'SingleFrame' })
            Assert-Equal $singleFrameBehavior.ClearBeforeRender $true 'Enhanced console rendering should use a single-frame redraw behavior.'
        }
    },
    @{
        Name = 'Console key translation ignores modifier and function keys'
        Body = {
            Import-Module $moduleManifest -Force
            . (Join-Path $repoRoot 'src/ShareSurfer/Private/ShareSurfer.Console.ps1')
            $shiftKey = [pscustomobject]@{ VirtualKeyCode = 16; Character = [char]0 }
            Assert-True ((ConvertFrom-ShareSurferConsoleKeyInfo -KeyInfo $shiftKey) -eq '') 'Shift keydown should translate to an ignorable empty command.'
            $f5Key = [pscustomobject]@{ VirtualKeyCode = 116; Character = [char]0 }
            Assert-True ((ConvertFrom-ShareSurferConsoleKeyInfo -KeyInfo $f5Key) -eq '') 'Function keys should translate to an ignorable empty command.'
            $upKey = [pscustomobject]@{ VirtualKeyCode = 38; Character = [char]0 }
            Assert-Equal (ConvertFrom-ShareSurferConsoleKeyInfo -KeyInfo $upKey) 'Up' 'Up arrow should translate to Up.'
            $enterKey = [pscustomobject]@{ VirtualKeyCode = 13; Character = [char]13 }
            Assert-Equal (ConvertFrom-ShareSurferConsoleKeyInfo -KeyInfo $enterKey) 'Enter' 'Enter should translate to Enter.'
            $letterKey = [pscustomobject]@{ VirtualKeyCode = 83; Character = [char]'S' }
            Assert-Equal (ConvertFrom-ShareSurferConsoleKeyInfo -KeyInfo $letterKey) 'S' 'Character keys should pass through as commands.'
        }
    },
    @{
        Name = 'Console multi-select state toggles ranges and cancels'
        Body = {
            Import-Module $moduleManifest -Force
            . (Join-Path $repoRoot 'src/ShareSurfer/Private/ShareSurfer.Console.ps1')
            . (Join-Path $repoRoot 'src/ShareSurfer/Public/Join-ShareSurferOwnershipSources.ps1')
            $state = New-ShareSurferConsoleMultiSelectState -Options @('a.csv', 'b.csv', 'c.csv', 'd.csv')
            Invoke-ShareSurferConsoleMultiSelectCommand -State $state -Command '2-3' | Out-Null
            Assert-Equal (@(Get-ShareSurferConsoleMultiSelectValues -State $state) -join ',') 'b.csv,c.csv' 'Ranges should toggle selections on.'
            Invoke-ShareSurferConsoleMultiSelectCommand -State $state -Command '2' | Out-Null
            Assert-Equal (@(Get-ShareSurferConsoleMultiSelectValues -State $state) -join ',') 'c.csv' 'Repeating a number should toggle it off.'
            Invoke-ShareSurferConsoleMultiSelectCommand -State $state -Command 'A' | Out-Null
            Assert-Equal @(Get-ShareSurferConsoleMultiSelectValues -State $state).Count 4 'A should select all options.'
            Invoke-ShareSurferConsoleMultiSelectCommand -State $state -Command 'C' | Out-Null
            Assert-True (@(Get-ShareSurferConsoleMultiSelectValues -State $state).Count -eq 0) 'C should clear selections.'
            Invoke-ShareSurferConsoleMultiSelectCommand -State $state -Command 'D' | Out-Null
            Assert-Equal $state.Action 'Done' 'D should finish the multi-select.'

            $screen = @(Get-ShareSurferConsoleMultiSelectScreen -State $state -Title 'Pick CSVs') -join [Environment]::NewLine
            Assert-True ($screen -like '*Pick CSVs*') 'Multi-select screen should render its title.'
            Assert-True ($screen.Contains('[ ] 1. a.csv')) 'Multi-select screen should render unselected markers.'

            $cancelState = New-ShareSurferConsoleMultiSelectState -Options @('a.csv')
            Invoke-ShareSurferConsoleMultiSelectCommand -State $cancelState -Command 'Q' -AllowQuit | Out-Null
            Assert-Equal $cancelState.Action 'Cancel' 'Q should cancel the multi-select when allowed.'
        }
    },
    @{
        Name = 'Console text prompt validates, defaults, and cancels'
        Body = {
            Import-Module $moduleManifest -Force
            . (Join-Path $repoRoot 'src/ShareSurfer/Private/ShareSurfer.Console.ps1')
            $state = New-ShareSurferConsoleTextState -Default 'default-value'
            Invoke-ShareSurferConsoleTextCommand -State $state -Command '' | Out-Null
            Assert-Equal $state.Action 'Accept' 'Enter should accept the default.'
            Assert-Equal $state.Value 'default-value' 'Enter should return the default value.'

            $validateState = New-ShareSurferConsoleTextState
            $validator = { param($text) if ($text -ne 'good') { 'Only good is allowed.' } else { '' } }
            Invoke-ShareSurferConsoleTextCommand -State $validateState -Command '' -Validate $validator | Out-Null
            Assert-True (-not $validateState.Done) 'An empty default should still be validated before Enter is accepted.'
            Assert-True ($validateState.Message -like 'Only good*') 'An invalid empty default should explain why the operator must enter a value.'
            Invoke-ShareSurferConsoleTextCommand -State $validateState -Command 'bad' -Validate $validator | Out-Null
            Assert-True (-not $validateState.Done) 'Validation failure should keep the prompt open.'
            Assert-True ($validateState.Message -like 'Only good*') 'Validation failure should explain the problem.'
            Invoke-ShareSurferConsoleTextCommand -State $validateState -Command 'good' -Validate $validator | Out-Null
            Assert-Equal $validateState.Action 'Accept' 'Valid input should accept.'
            Assert-Equal $validateState.Value 'good' 'Valid input should return the typed value.'

            $cancelState = New-ShareSurferConsoleTextState
            Invoke-ShareSurferConsoleTextCommand -State $cancelState -Command 'Q' -AllowQuit | Out-Null
            Assert-Equal $cancelState.Action 'Cancel' 'Q should cancel the text prompt when allowed.'
            Assert-Equal $cancelState.Value '' 'Cancelled text input must not return Q as field data.'

            $backState = New-ShareSurferConsoleTextState -Default 'keep-me'
            Invoke-ShareSurferConsoleTextCommand -State $backState -Command 'B' -AllowBack | Out-Null
            Assert-Equal $backState.Action 'Back' 'B should return from a text prompt when enabled.'
            Assert-Equal $backState.Value '' 'Back navigation must not overwrite the retained default.'

            $noBackState = New-ShareSurferConsoleTextState -Default 'keep-me'
            Invoke-ShareSurferConsoleTextCommand -State $noBackState -Command 'B' | Out-Null
            Assert-True (-not $noBackState.Done) 'B should not be accepted as field data when Back is unavailable.'
            Assert-True ($noBackState.Message -like '*Back is not available*') 'A prompt without Back should explain the available-control boundary.'
            Assert-Equal $noBackState.Value '' 'Unavailable Back input must not overwrite the field value.'
        }
    },
    @{
        Name = 'Console layer owns all interactive Read-Host prompts'
        Body = {
            $allowedReadHostCounts = @{
                'Private/ShareSurfer.Console.ps1' = 5
                'Public/Join-ShareSurferOwnershipSources.ps1' = 4
            }
            $moduleRoot = Join-Path $repoRoot 'src/ShareSurfer'
            foreach ($file in @(Get-ChildItem -LiteralPath $moduleRoot -Recurse -Filter '*.ps1' -File)) {
                $relativePath = $file.FullName.Substring($moduleRoot.Length + 1).Replace('\', '/')
                $matchingLines = @(Select-String -LiteralPath $file.FullName -Pattern 'Read-Host' -SimpleMatch)
                $allowed = 0
                if ($allowedReadHostCounts.ContainsKey($relativePath)) {
                    $allowed = [int]$allowedReadHostCounts[$relativePath]
                }
                Assert-True ($matchingLines.Count -le $allowed) ('New ad hoc Read-Host prompt found in {0} ({1} use(s), {2} allowed). Use the ShareSurfer.Console prompt layer instead of raw Read-Host loops.' -f $relativePath, $matchingLines.Count, $allowed)
            }
        }
    },
    @{
        Name = 'Goal-based home shows one task list with unavailable reasons and wrapped output'
        Body = {
            Import-Module $moduleManifest -Force
            $module = Get-Module ShareSurfer
            $root = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferMenu-' + [guid]::NewGuid().ToString('N'))
            $inputRoot = Join-Path $root 'inputs'
            $exportPath = Join-Path $root 'export'
            New-Item -ItemType Directory -Path $inputRoot -Force | Out-Null
            New-Item -ItemType Directory -Path $exportPath -Force | Out-Null

            try {
                $entries = @(& $module {
                    param($InputRoot, $ExportPath)
                    Get-ShareSurferMenuEntries -InputRoot $InputRoot -ExportPath $ExportPath -ConsoleMode Plain
                } $inputRoot $exportPath)

                Assert-Equal $entries.Count 6 'The goal-based home should list six operator choices.'
                Assert-Equal (@($entries | ForEach-Object { [string]$_.Key }) -join ',') 'first_scan,saved_scan,review_results,ownership,advanced,exit' 'Home choices should follow the approved goal order.'
                Assert-True ([bool]$entries[0].Available) 'Start a first scan should be available in fresh state.'
                Assert-True ([bool]$entries[0].Recommended) 'Start a first scan should be the recommended choice.'
                Assert-True (-not [bool]$entries[1].Available) 'Saved scan should be unavailable before setup exists.'
                Assert-True ([string]$entries[1].UnavailableReason -like '*Finish first-scan setup*') 'Saved scan should explain how to unlock it.'
                Assert-True (-not [bool]$entries[2].Available) 'Results review should be unavailable before an export exists.'

                foreach ($width in @(80, 120)) {
                    $screenLines = @(& $module {
                        param($Entries, $InputRoot, $ExportPath, $Width)
                        Get-ShareSurferMenuScreen -Entries $Entries -InputRoot $InputRoot -ExportPath $ExportPath -Width $Width
                    } $entries $inputRoot $exportPath $width)
                    $screen = $screenLines -join [Environment]::NewLine
                    foreach ($entry in $entries) {
                        Assert-Equal ([regex]::Matches($screen, [regex]::Escape([string]$entry.Label))).Count 1 ('Home should render {0} exactly once.' -f [string]$entry.Label)
                    }
                    Assert-True (@($screenLines | Where-Object { $_.Length -gt $width }).Count -eq 0) ('Home output should wrap to {0} columns.' -f $width)
                }

                Set-Content -LiteralPath (Join-Path $exportPath 'shares.csv') -Value 'ShareId' -Encoding UTF8
                $withExport = @(& $module {
                    param($InputRoot, $ExportPath)
                    Get-ShareSurferMenuEntries -InputRoot $InputRoot -ExportPath $ExportPath -ConsoleMode Plain
                } $inputRoot $exportPath)
                $review = @($withExport | Where-Object { $_.Key -eq 'review_results' })[0]
                Assert-True ([bool]$review.Available) 'An existing shares.csv should unlock results validation and review.'
                Assert-True ([string]$review.Description -like '*validate it before review*') 'File presence should say validation is required instead of claiming success.'

                $validatedEntries = @(& $module {
                    param($InputRoot, $ExportPath)
                    Get-ShareSurferMenuEntries -InputRoot $InputRoot -ExportPath $ExportPath -ConsoleMode Plain -SessionValidationPassed $true
                } $inputRoot $exportPath)
                $validatedHelp = & $module {
                    param($Entries)
                    Get-ShareSurferMenuHelpText -Entries $Entries
                } $validatedEntries
                Assert-True ([string]$validatedHelp -like '*Results: validated in this session*') 'Home help should agree with the validated results row.'
                Assert-True ([string]$validatedHelp -notlike '*validation is required*') 'Home help must not ask for validation again after current-session success.'

                Set-Content -LiteralPath (Join-Path $inputRoot 'sharesurfer-startup.config.json') -Value '{not-json' -Encoding UTF8
                $withCorruptConfig = @(& $module {
                    param($InputRoot, $ExportPath)
                    Get-ShareSurferMenuEntries -InputRoot $InputRoot -ExportPath $ExportPath -ConsoleMode Plain
                } $inputRoot $exportPath)
                $saved = @($withCorruptConfig | Where-Object { $_.Key -eq 'saved_scan' })[0]
                Assert-True (-not [bool]$saved.Available) 'A corrupt saved config must not unlock saved scan.'
                Assert-True ([string]$saved.UnavailableReason -like '*could not be read*') 'A corrupt saved config should provide a repair path.'
            }
            finally {
                Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    },
    @{
        Name = 'Goal-based home restores saved custom export paths without overriding explicit paths'
        Body = {
            Import-Module $moduleManifest -Force
            $module = Get-Module ShareSurfer
            $root = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferMenuSavedPaths-' + [guid]::NewGuid().ToString('N'))
            $inputRoot = Join-Path $root 'inputs'
            $defaultExport = Join-Path (Join-Path $root 'exports') 'startup-scan'
            $defaultDashboard = Join-Path $defaultExport 'standalone-dashboard'
            $savedExport = Join-Path $root 'custom-export'
            $savedDashboard = Join-Path $root 'custom-dashboard'
            $explicitExport = Join-Path $root 'explicit-export'
            $explicitDashboard = Join-Path $root 'explicit-dashboard'
            $configPath = Join-Path $inputRoot 'sharesurfer-startup.config.json'
            $rerunPath = Join-Path $inputRoot 'operator-assistant-rerun.ps1'
            New-Item -ItemType Directory -Path $inputRoot -Force | Out-Null
            Set-Content -LiteralPath $rerunPath -Value "Write-Host 'saved path test'" -Encoding UTF8
            Set-Content -LiteralPath $configPath -Value (([ordered]@{
                exportPath = $savedExport
                standaloneDashboardPath = $savedDashboard
                targetPaths = @('\\files01\Finance')
                obsAttribute = 'info'
                adLookupMode = 'DirectoryOnly'
                managerIdentityFormat = 'SamAccountName'
                aclExportMode = 'FullEffective'
                consoleMode = 'Enhanced'
                generatedFiles = [ordered]@{ operatorReusableCommandPath = $rerunPath }
            }) | ConvertTo-Json -Depth 5) -Encoding UTF8

            try {
                $restored = & $module {
                    param($InputRoot, $ExportPath, $DashboardPath)
                    Get-ShareSurferMenuInitialPaths -InputRoot $InputRoot -ExportPath $ExportPath -StandaloneDashboardPath $DashboardPath
                } $inputRoot $defaultExport $defaultDashboard
                Assert-Equal $restored.ExportPath $savedExport 'A normal launcher restart should restore the saved custom export path.'
                Assert-Equal $restored.StandaloneDashboardPath $savedDashboard 'A normal launcher restart should restore the saved custom dashboard path.'
                Assert-True ([bool]$restored.HydratedFromSavedConfig) 'Restored paths should identify their saved-config source.'
                $restoredSettings = & $module {
                    param($InputRoot)
                    Get-ShareSurferMenuInitialSettings -InputRoot $InputRoot
                } $inputRoot
                Assert-Equal $restoredSettings.ObsAttribute 'info' 'A normal restart should restore the saved OBS attribute for ownership work.'
                Assert-Equal $restoredSettings.AdLookupMode 'DirectoryOnly' 'A normal restart should restore the saved directory lookup mode.'
                Assert-Equal $restoredSettings.ManagerIdentityFormat 'SamAccountName' 'A normal restart should restore the saved manager identity format.'
                Assert-Equal $restoredSettings.AclExportMode 'FullEffective' 'A normal restart should restore the saved ACL export mode.'
                Assert-Equal $restoredSettings.ConsoleMode 'Enhanced' 'A normal restart should restore the saved console preference when the launcher uses its default.'

                $explicit = & $module {
                    param($InputRoot, $ExportPath, $DashboardPath)
                    Get-ShareSurferMenuInitialPaths -InputRoot $InputRoot -ExportPath $ExportPath -StandaloneDashboardPath $DashboardPath
                } $inputRoot $explicitExport $explicitDashboard
                Assert-Equal $explicit.ExportPath $explicitExport 'An explicitly different export path should not be overwritten by saved config.'
                Assert-Equal $explicit.StandaloneDashboardPath $explicitDashboard 'An explicitly different dashboard path should not be overwritten by saved config.'
                Assert-True (-not [bool]$explicit.HydratedFromSavedConfig) 'Explicit path overrides should remain authoritative.'
                $explicitSettings = & $module {
                    param($InputRoot)
                    Get-ShareSurferMenuInitialSettings -InputRoot $InputRoot -ObsAttribute 'department' -AdLookupMode Ldap -ManagerIdentityFormat Mail -AclExportMode Compact -ConsoleMode Auto -PreserveObsAttribute -PreserveAdLookupMode -PreserveManagerIdentityFormat -PreserveAclExportMode -PreserveConsoleMode
                } $inputRoot
                Assert-Equal $explicitSettings.ObsAttribute 'department' 'An explicitly different OBS attribute should remain authoritative.'
                Assert-Equal $explicitSettings.AdLookupMode 'Ldap' 'An explicitly different directory mode should remain authoritative.'
            }
            finally {
                Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    },
    @{
        Name = 'Start-ShareSurfer keeps unavailable choices non-actionable and exits cleanly'
        Body = {
            Import-Module $moduleManifest -Force
            $module = Get-Module ShareSurfer
            $root = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferMenuRun-' + [guid]::NewGuid().ToString('N'))
            $exportPath = Join-Path $root 'export'
            New-Item -ItemType Directory -Path $exportPath -Force | Out-Null

            $env:SHARESURFER_PLAIN_CONSOLE = '1'
            $script:shareSurferMenuAnswers = New-Object 'System.Collections.Generic.Queue[string]'
            $script:shareSurferMenuAnswers.Enqueue('2')
            $script:shareSurferMenuAnswers.Enqueue('Q')
            function global:Read-Host {
                param([string] $Prompt)
                if ($script:shareSurferMenuAnswers.Count -eq 0) {
                    throw ('Unexpected menu prompt: {0}' -f $Prompt)
                }
                $script:shareSurferMenuAnswers.Dequeue()
            }

            try {
                Start-ShareSurfer -ExportPath $exportPath
                Assert-Equal $script:shareSurferMenuAnswers.Count 0 'Menu should reject the unavailable saved scan without another prompt, then accept Q.'
            }
            finally {
                Remove-Item -Path Env:SHARESURFER_PLAIN_CONSOLE -ErrorAction SilentlyContinue
                Remove-Item -Path function:\Read-Host -ErrorAction SilentlyContinue
                Remove-Variable -Name shareSurferMenuAnswers -Scope Script -ErrorAction SilentlyContinue
                Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    },
    @{
        Name = 'Start-ShareSurfer recommended first scan reaches review with four choices and defers ownership'
        Body = {
            Import-Module $moduleManifest -Force
            $root = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferMenuStartup-' + [guid]::NewGuid().ToString('N'))
            $inputRoot = Join-Path $root 'inputs'
            $exportPath = Join-Path $root 'export'
            $dashboardPath = Join-Path $exportPath 'standalone-dashboard'
            $configPath = Join-Path $inputRoot 'sharesurfer-startup.config.json'
            New-Item -ItemType Directory -Path $inputRoot -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $inputRoot 'owner-mapping.csv') -Value 'Pattern,Owner,BusinessUnit' -Encoding UTF8

            $env:SHARESURFER_PLAIN_CONSOLE = '1'
            $script:shareSurferMenuStartupAnswers = New-Object 'System.Collections.Generic.Queue[string]'
            foreach ($answer in @('', '\\files01\Finance', '', '', '', 'Q')) {
                $script:shareSurferMenuStartupAnswers.Enqueue($answer)
            }
            function global:Read-Host {
                param([string] $Prompt)
                if ($script:shareSurferMenuStartupAnswers.Count -eq 0) {
                    throw ('Unexpected startup menu prompt: {0}' -f $Prompt)
                }
                $script:shareSurferMenuStartupAnswers.Dequeue()
            }

            try {
                Start-ShareSurfer `
                    -ReleaseRoot $repoRoot `
                    -InputRoot $inputRoot `
                    -ExportPath $exportPath `
                    -StandaloneDashboardPath $dashboardPath `
                    -ObsAttribute 'info' `
                    -AdLookupMode DirectoryOnly `
                    -ManagerIdentityFormat SamAccountName `
                    -AclExportMode Compact `
                    -ConsoleMode Plain

                $config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
                Assert-Equal $config.obsAttribute 'info' 'Menu-launched startup should preserve the menu OBS attribute.'
                Assert-Equal $config.adLookupMode 'DirectoryOnly' 'Menu-launched startup should preserve the menu AD lookup mode.'
                Assert-Equal $config.managerIdentityFormat 'SamAccountName' 'Menu-launched startup should preserve the menu manager identity format.'
                Assert-Equal $config.aclExportMode 'Compact' 'Menu-launched startup should preserve the menu ACL export mode.'
                Assert-Equal $config.consoleMode 'Plain' 'Menu-launched startup should preserve the menu console mode in saved config.'
                Assert-Equal $config.targetPaths[0] '\\files01\Finance' 'Menu-launched startup should save the prompted target path.'
                Assert-Equal $config.includeFiles $false 'Recommended first scan should collect folders only.'
                Assert-Equal $config.includeSharePermissionDiagnostics $true 'Recommended first scan should enable share-permission diagnostics.'
                Assert-Equal $config.skipIdentityEnrichment $false 'Recommended first scan should collect identity details.'
                Assert-Equal ([string]$config.optionalInputs.ownerMappingPath) '' 'Recommended first scan should defer optional ownership files even when one is discovered.'
                Assert-Equal $script:shareSurferMenuStartupAnswers.Count 0 'Home, target, location, defaults, save, and final quit should consume only six inputs.'
            }
            finally {
                Remove-Item -Path Env:SHARESURFER_PLAIN_CONSOLE -ErrorAction SilentlyContinue
                Remove-Item -Path function:\Read-Host -ErrorAction SilentlyContinue
                Remove-Variable -Name shareSurferMenuStartupAnswers -Scope Script -ErrorAction SilentlyContinue
                Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    },
    @{
        Name = 'First-scan setup replaces existing saved files only after explicit confirmation'
        Body = {
            Import-Module $moduleManifest -Force
            $root = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferFirstScanReplace-' + [guid]::NewGuid().ToString('N'))
            $inputRoot = Join-Path $root 'inputs'
            $exportPath = Join-Path $root 'export'
            $dashboardPath = Join-Path $exportPath 'standalone-dashboard'
            $configPath = Join-Path $inputRoot 'sharesurfer-startup.config.json'
            $planPath = Join-Path $inputRoot 'operator-assistant.plan.json'
            $rerunPath = Join-Path $inputRoot 'operator-assistant-rerun.ps1'
            New-Item -ItemType Directory -Path $inputRoot -Force | Out-Null
            Set-Content -LiteralPath $configPath -Value 'existing-config-sentinel' -Encoding UTF8
            Set-Content -LiteralPath $planPath -Value 'existing-plan-sentinel' -Encoding UTF8
            Set-Content -LiteralPath $rerunPath -Value 'existing-rerun-sentinel' -Encoding UTF8

            $env:SHARESURFER_PLAIN_CONSOLE = '1'
            try {
                $script:shareSurferReplaceAnswers = New-Object 'System.Collections.Generic.Queue[string]'
                foreach ($answer in @('\\files01\Finance', '', '', '', 'N')) { $script:shareSurferReplaceAnswers.Enqueue($answer) }
                function global:Read-Host {
                    param([string] $Prompt)
                    if ($script:shareSurferReplaceAnswers.Count -eq 0) { throw ('Unexpected replace-decline prompt: {0}' -f $Prompt) }
                    $script:shareSurferReplaceAnswers.Dequeue()
                }
                $declined = Start-ShareSurferStartup -ReleaseRoot $repoRoot -InputRoot $inputRoot -ExportPath $exportPath -StandaloneDashboardPath $dashboardPath -Interactive -SkipUnblock
                Assert-True ([bool]$declined.Cancelled) 'Declining replacement should return without writing startup files.'
                Assert-Equal (Get-Content -LiteralPath $configPath -Raw).Trim() 'existing-config-sentinel' 'Declining replacement should preserve the existing config.'
                Assert-Equal (Get-Content -LiteralPath $planPath -Raw).Trim() 'existing-plan-sentinel' 'Declining replacement should preserve the existing plan.'
                Assert-Equal (Get-Content -LiteralPath $rerunPath -Raw).Trim() 'existing-rerun-sentinel' 'Declining replacement should preserve the existing rerun script.'

                Remove-Item -Path function:\Read-Host -ErrorAction SilentlyContinue
                $script:shareSurferReplaceAnswers = New-Object 'System.Collections.Generic.Queue[string]'
                foreach ($answer in @('\\files01\Finance', '', '', '', 'Y')) { $script:shareSurferReplaceAnswers.Enqueue($answer) }
                function global:Read-Host {
                    param([string] $Prompt)
                    if ($script:shareSurferReplaceAnswers.Count -eq 0) { throw ('Unexpected replace-accept prompt: {0}' -f $Prompt) }
                    $script:shareSurferReplaceAnswers.Dequeue()
                }
                $accepted = Start-ShareSurferStartup -ReleaseRoot $repoRoot -InputRoot $inputRoot -ExportPath $exportPath -StandaloneDashboardPath $dashboardPath -Interactive -SkipUnblock
                Assert-True (-not [bool]$accepted.Cancelled) 'Explicit replacement confirmation should allow startup generation to finish.'
                $savedConfig = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
                Assert-Equal $savedConfig.targetPaths[0] '\\files01\Finance' 'Confirmed replacement should write the reviewed target into valid config JSON.'
                Assert-True ((Get-Content -LiteralPath $planPath -Raw).Trim() -ne 'existing-plan-sentinel') 'Confirmed replacement should update the operator plan.'
                Assert-True ((Get-Content -LiteralPath $rerunPath -Raw).Trim() -ne 'existing-rerun-sentinel') 'Confirmed replacement should update the rerun script.'
                Assert-Equal $script:shareSurferReplaceAnswers.Count 0 'Confirmed replacement should consume the expected prompts.'
            }
            finally {
                Remove-Item -Path Env:SHARESURFER_PLAIN_CONSOLE -ErrorAction SilentlyContinue
                Remove-Item -Path function:\Read-Host -ErrorAction SilentlyContinue
                Remove-Variable -Name shareSurferReplaceAnswers -Scope Script -ErrorAction SilentlyContinue
                Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    },
    @{
        Name = 'First-scan flow cancels cleanly at every stage and preserves values on Back'
        Body = {
            Import-Module $moduleManifest -Force
            $module = Get-Module ShareSurfer
            $root = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferFirstScanCancel-' + [guid]::NewGuid().ToString('N'))

            function New-TestFirstScanState {
                param([string] $Suffix)
                $inputRoot = Join-Path $root ('inputs-' + $Suffix)
                [pscustomobject]@{
                    EnvironmentMode = 'Permissive'; ReleaseRoot = $repoRoot; InputRoot = $inputRoot
                    ExportPath = (Join-Path $root ('export-' + $Suffix)); StandaloneDashboardPath = (Join-Path $root ('dashboard-' + $Suffix))
                    TargetPath = @(); ObsAttribute = 'extensionAttribute10'; AdLookupMode = 'Auto'; ManagerIdentityFormat = 'MailTo'
                    AclExportMode = 'Compact'; ConsoleMode = 'Plain'; IncludeFiles = $false; IncludeSharePermissionDiagnostics = $true
                    SkipIdentityEnrichment = $false; SkipUnblock = $true; SaveConfigPath = (Join-Path $inputRoot 'sharesurfer-startup.config.json')
                    HandoffPath = ''; OwnerMappingPath = ''; OwnershipEnrichmentPath = ''; OwnershipContextPath = ''
                    OwnershipRelationshipPath = ''; OwnershipImportManifestPath = ''; DiscountedPrincipalPath = ''
                    OwnershipSetupSummary = $null; DeferOwnershipInputs = $true; RunNow = $false
                }
            }

            $cases = @(
                [pscustomobject]@{ Name = 'target'; Answers = @('Q') },
                [pscustomobject]@{ Name = 'target-empty'; Answers = @('', 'Q') },
                [pscustomobject]@{ Name = 'location'; Answers = @('\\files01\Finance', 'Q') },
                [pscustomobject]@{ Name = 'settings'; Answers = @('\\files01\Finance', '', 'Q') },
                [pscustomobject]@{ Name = 'review'; Answers = @('\\files01\Finance', '', '', 'Q') }
            )

            try {
                foreach ($case in $cases) {
                    $script:firstScanCancelAnswers = New-Object 'System.Collections.Generic.Queue[string]'
                    foreach ($answer in @($case.Answers)) { $script:firstScanCancelAnswers.Enqueue([string]$answer) }
                    function global:Read-Host {
                        param([string] $Prompt)
                        if ($script:firstScanCancelAnswers.Count -eq 0) { throw ('Unexpected cancellation prompt: {0}' -f $Prompt) }
                        $script:firstScanCancelAnswers.Dequeue()
                    }
                    $state = New-TestFirstScanState -Suffix ([string]$case.Name)
                    $result = & $module {
                        param($State)
                        Read-ShareSurferFirstScanConfiguration -State $State -ConsoleMode Plain -Force
                    } $state
                    Assert-Equal $result.Action 'Cancel' ('Q should cancel cleanly at the {0} stage.' -f [string]$case.Name)
                    Assert-True (@($state.PSObject.Properties.Value | Where-Object { [string]$_ -in @('Q', 'Cancel') }).Count -eq 0) 'Cancellation must never become normal configuration data.'
                    Assert-True (-not (Test-Path -LiteralPath $state.SaveConfigPath -PathType Leaf)) 'Cancelled flow must not write startup config.'
                    Remove-Item -Path function:\Read-Host -ErrorAction SilentlyContinue
                }

                $script:firstScanCancelAnswers = New-Object 'System.Collections.Generic.Queue[string]'
                foreach ($answer in @('\\files01\Finance', 'B', '', '', '', 'Q')) { $script:firstScanCancelAnswers.Enqueue($answer) }
                function global:Read-Host {
                    param([string] $Prompt)
                    if ($script:firstScanCancelAnswers.Count -eq 0) { throw ('Unexpected back-navigation prompt: {0}' -f $Prompt) }
                    $script:firstScanCancelAnswers.Dequeue()
                }
                $backState = New-TestFirstScanState -Suffix 'back'
                $backResult = & $module {
                    param($State)
                    Read-ShareSurferFirstScanConfiguration -State $State -ConsoleMode Plain -Force
                } $backState
                Assert-Equal $backResult.Action 'Cancel' 'Back-navigation scenario should reach the final Q without writing.'
                Assert-Equal $backState.TargetPath[0] '\\files01\Finance' 'Returning from review location should preserve the previously entered target as the default.'

                Remove-Item -Path function:\Read-Host -ErrorAction SilentlyContinue
                $script:firstScanCancelAnswers = New-Object 'System.Collections.Generic.Queue[string]'
                foreach ($answer in @('\\files01\Finance', '', '2', '1', '2', '', '', '', '', '', '', 'B', '', '', 'Q')) { $script:firstScanCancelAnswers.Enqueue($answer) }
                function global:Read-Host {
                    param([string] $Prompt)
                    if ($script:firstScanCancelAnswers.Count -eq 0) { throw ('Unexpected custom-back prompt: {0}' -f $Prompt) }
                    $script:firstScanCancelAnswers.Dequeue()
                }
                $customBackState = New-TestFirstScanState -Suffix 'custom-back'
                $customBackResult = & $module {
                    param($State)
                    Read-ShareSurferFirstScanConfiguration -State $State -ConsoleMode Plain -Force
                } $customBackState
                Assert-Equal $customBackResult.Action 'Cancel' 'Custom Back scenario should return to review and then accept Q.'
                Assert-Equal $customBackState.AclExportMode 'FullEffective' 'Returning from final review should preserve custom settings instead of reapplying recommended defaults.'
                $technicalCommand = & $module {
                    param($State)
                    Get-ShareSurferFirstScanCommandPreview -State $State
                } $customBackState
                Assert-True ([string]$technicalCommand -like '*-AclExportMode*FullEffective*') 'Technical command should reproduce the reviewed custom ACL setting.'
                Assert-True ([string]$technicalCommand -like '*-DisableOptionalInputDiscovery*') 'Technical command should preserve deferred ownership instead of rediscovering files.'
                Assert-True ([string]$technicalCommand -like '*-SkipOwnershipSetup*') 'Technical command should preserve the reviewed decision to defer ownership setup.'
                Assert-True ([string]$technicalCommand -notlike '*-Force*') 'Technical command should not silently authorize overwriting existing files.'

                $customBackState.DeferOwnershipInputs = $false
                $customBackState.OwnershipSetupSummary = [pscustomobject]@{
                    CreateOwnerMappingDraftAfterScan = $true
                    OwnerMappingDraftPath = (Join-Path $customBackState.InputRoot 'owner-mapping-draft.csv')
                    OwnerMappingDraftReusableCommandPath = (Join-Path $customBackState.InputRoot 'owner-mapping-draft-rerun.ps1')
                }
                $draftTechnicalCommand = & $module {
                    param($State)
                    Get-ShareSurferFirstScanCommandPreview -State $State
                } $customBackState
                Assert-True ([string]$draftTechnicalCommand -like '*-CreateOwnerMappingDraftAfterScan*') 'Technical command should reproduce queued post-scan owner-mapping draft creation.'
                Assert-True ([string]$draftTechnicalCommand -like '*-OwnerMappingDraftPath*owner-mapping-draft.csv*') 'Technical command should preserve the owner-mapping draft output path.'
                Assert-True ([string]$draftTechnicalCommand -like '*-OwnerMappingDraftReusableCommandPath*owner-mapping-draft-rerun.ps1*') 'Technical command should preserve the owner-mapping draft rerun path.'
                Assert-Equal $script:firstScanCancelAnswers.Count 0 'Custom Back scenario should consume the expected prompts.'
            }
            finally {
                Remove-Item -Path function:\Read-Host -ErrorAction SilentlyContinue
                Remove-Variable -Name firstScanCancelAnswers -Scope Script -ErrorAction SilentlyContinue
                Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    },
    @{
        Name = 'Start-ShareSurfer runs a saved workflow and refreshes home afterward'
        Body = {
            Import-Module $moduleManifest -Force
            $module = Get-Module ShareSurfer
            $root = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferMenuSavedRun-' + [guid]::NewGuid().ToString('N'))
            $inputRoot = Join-Path $root 'inputs'
            $exportPath = Join-Path $root 'export'
            $dashboardPath = Join-Path $exportPath 'standalone-dashboard'
            $savedExportPath = Join-Path $root 'saved-export'
            $savedDashboardPath = Join-Path $savedExportPath 'standalone-dashboard'
            $configPath = Join-Path $inputRoot 'sharesurfer-startup.config.json'
            $rerunPath = Join-Path $inputRoot 'operator-assistant-rerun.ps1'
            $sentinelPath = Join-Path $root 'rerun-executed.txt'
            New-Item -ItemType Directory -Path $inputRoot -Force | Out-Null
            New-Item -ItemType Directory -Path $exportPath -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $exportPath 'shares.csv') -Value 'InvalidHeader' -Encoding UTF8
            Invoke-ShareSurferScan -InputObject (New-TestInventory) -OutputPath $savedExportPath -SkipIdentityEnrichment -Quiet | Out-Null

            $config = [ordered]@{
                exportPath = $savedExportPath
                standaloneDashboardPath = $savedDashboardPath
                targetPaths = @('\\files01\Finance')
                generatedFiles = [ordered]@{
                    operatorReusableCommandPath = $rerunPath
                }
                commands = [ordered]@{
                    operatorRerun = $rerunPath
                }
            }
            Set-Content -LiteralPath $configPath -Value ($config | ConvertTo-Json -Depth 5) -Encoding UTF8
            Set-Content -LiteralPath $rerunPath -Value ("Set-Content -LiteralPath '{0}' -Value 'ran' -Encoding UTF8" -f $sentinelPath) -Encoding UTF8

            $entries = @(& $module {
                param($InputRoot, $ExportPath, $DashboardPath)
                Get-ShareSurferMenuEntries -InputRoot $InputRoot -ExportPath $ExportPath -StandaloneDashboardPath $DashboardPath -ConsoleMode Plain
            } $inputRoot $exportPath $dashboardPath)
            $saved = @($entries | Where-Object { $_.Key -eq 'saved_scan' })[0]
            Assert-Equal ([string]$saved.Label) 'Run a saved scan' 'Saved config plus rerun script should unlock the saved-scan goal.'
            Assert-True ([bool]$saved.Available) 'Saved workflow should be selectable when its config and rerun script exist.'
            Assert-Equal ([string]$saved.RerunPath) $rerunPath 'Saved workflow should point to the configured rerun script.'
            Assert-Equal ([string]$saved.ExportPath) $savedExportPath 'Saved workflow entry should retain its configured export path.'

            $env:SHARESURFER_PLAIN_CONSOLE = '1'
            $script:shareSurferSavedRunAnswers = New-Object 'System.Collections.Generic.Queue[string]'
            foreach ($answer in @('2', 'Y', 'Q')) {
                $script:shareSurferSavedRunAnswers.Enqueue($answer)
            }
            function global:Read-Host {
                param([string] $Prompt)
                if ($script:shareSurferSavedRunAnswers.Count -eq 0) {
                    throw ('Unexpected saved-run menu prompt: {0}' -f $Prompt)
                }
                $script:shareSurferSavedRunAnswers.Dequeue()
            }

            try {
                $menuOutput = (Start-ShareSurfer `
                    -ReleaseRoot $repoRoot `
                    -InputRoot $inputRoot `
                    -ExportPath $exportPath `
                    -StandaloneDashboardPath $dashboardPath `
                    -ConsoleMode Plain 6>&1 | Out-String)

                Assert-True (Test-Path -LiteralPath $sentinelPath -PathType Leaf) 'Saved rerun script should execute from the menu.'
                Assert-Equal (Get-Content -LiteralPath $sentinelPath -Raw).Trim() 'ran' 'Saved rerun script should write the expected sentinel content.'
                Assert-True ([string]$menuOutput -like ('*Switching to the saved workflow export*{0}*' -f $savedExportPath)) 'Saved scan should switch from an explicit review path to the export bound to its rerun config.'
                Assert-True ([string]$menuOutput -like ('*Export validation passed*{0}*' -f $savedExportPath)) 'Saved scan should validate the export produced by the saved workflow.'
                Assert-Equal $script:shareSurferSavedRunAnswers.Count 0 'Saved-run flow should return to refreshed home and consume the final Q.'
            }
            finally {
                Remove-Item -Path Env:SHARESURFER_PLAIN_CONSOLE -ErrorAction SilentlyContinue
                Remove-Item -Path function:\Read-Host -ErrorAction SilentlyContinue
                Remove-Variable -Name shareSurferSavedRunAnswers -Scope Script -ErrorAction SilentlyContinue
                Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    },
    @{
        Name = 'Start-ShareSurfer recovers from saved workflow errors and returns home'
        Body = {
            Import-Module $moduleManifest -Force
            $root = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferMenuSavedFailure-' + [guid]::NewGuid().ToString('N'))
            $inputRoot = Join-Path $root 'inputs'
            $exportPath = Join-Path $root 'export'
            $configPath = Join-Path $inputRoot 'sharesurfer-startup.config.json'
            $rerunPath = Join-Path $inputRoot 'operator-assistant-rerun.ps1'
            New-Item -ItemType Directory -Path $inputRoot -Force | Out-Null
            Set-Content -LiteralPath $configPath -Value (([ordered]@{ generatedFiles = [ordered]@{ operatorReusableCommandPath = $rerunPath } }) | ConvertTo-Json -Depth 5) -Encoding UTF8
            Set-Content -LiteralPath $rerunPath -Value "throw 'synthetic saved workflow failure'" -Encoding UTF8

            $env:SHARESURFER_PLAIN_CONSOLE = '1'
            $script:shareSurferSavedFailureAnswers = New-Object 'System.Collections.Generic.Queue[string]'
            foreach ($answer in @('2', 'Y', 'Q')) { $script:shareSurferSavedFailureAnswers.Enqueue($answer) }
            function global:Read-Host {
                param([string] $Prompt)
                if ($script:shareSurferSavedFailureAnswers.Count -eq 0) { throw ('Unexpected saved-failure prompt: {0}' -f $Prompt) }
                $script:shareSurferSavedFailureAnswers.Dequeue()
            }

            try {
                Start-ShareSurfer -ReleaseRoot $repoRoot -InputRoot $inputRoot -ExportPath $exportPath -ConsoleMode Plain
                Assert-Equal $script:shareSurferSavedFailureAnswers.Count 0 'A thrown saved workflow should be caught and return to home for Q.'
            }
            finally {
                Remove-Item -Path Env:SHARESURFER_PLAIN_CONSOLE -ErrorAction SilentlyContinue
                Remove-Item -Path function:\Read-Host -ErrorAction SilentlyContinue
                Remove-Variable -Name shareSurferSavedFailureAnswers -Scope Script -ErrorAction SilentlyContinue
                Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    },
    @{
        Name = 'Advanced dashboard packaging requires successful current-session export validation'
        Body = {
            Import-Module $moduleManifest -Force
            $module = Get-Module ShareSurfer
            $root = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferMenuValidationGate-' + [guid]::NewGuid().ToString('N'))
            $invalidExport = Join-Path $root 'invalid'
            $validExport = Join-Path $root 'valid'
            New-Item -ItemType Directory -Path $invalidExport -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $invalidExport 'shares.csv') -Value 'NotAValidHeader' -Encoding UTF8

            try {
                $invalidSession = [pscustomobject]@{ ValidationPassed = $false }
                & $module {
                    param($ExportPath, $Session)
                    Invoke-ShareSurferMenuExportValidation -ExportPath $ExportPath -SessionState $Session | Out-Null
                } $invalidExport $invalidSession
                Assert-True (-not [bool]$invalidSession.ValidationPassed) 'Invalid export validation should fail closed.'
                $invalidEntries = @(& $module {
                    param($ExportPath, $ReleaseRoot, $Session)
                    Get-ShareSurferAdvancedMenuEntries -ExportPath $ExportPath -StandaloneDashboardPath (Join-Path $ExportPath 'dashboard') -ReleaseRoot $ReleaseRoot -SessionState $Session
                } $invalidExport $repoRoot $invalidSession)
                $invalidDashboard = @($invalidEntries | Where-Object { $_.Key -eq 'dashboard' })[0]
                Assert-True (-not [bool]$invalidDashboard.Available) 'Dashboard packaging must remain unavailable after failed validation.'

                Invoke-ShareSurferScan -InputObject (New-TestInventory) -OutputPath $validExport -SkipIdentityEnrichment -Quiet | Out-Null
                $validSession = [pscustomobject]@{ ValidationPassed = $false }
                & $module {
                    param($ExportPath, $Session)
                    Invoke-ShareSurferMenuExportValidation -ExportPath $ExportPath -SessionState $Session | Out-Null
                } $validExport $validSession
                Assert-True ([bool]$validSession.ValidationPassed) 'Complete export validation should unlock the current session.'
                $validEntries = @(& $module {
                    param($ExportPath, $ReleaseRoot, $Session)
                    Get-ShareSurferAdvancedMenuEntries -ExportPath $ExportPath -StandaloneDashboardPath (Join-Path $ExportPath 'dashboard') -ReleaseRoot $ReleaseRoot -SessionState $Session
                } $validExport $repoRoot $validSession)
                $validDashboard = @($validEntries | Where-Object { $_.Key -eq 'dashboard' })[0]
                Assert-True ([bool]$validDashboard.Available) 'Dashboard packaging should unlock only after successful validation.'

                $otherExport = Join-Path $root 'other-export'
                New-Item -ItemType Directory -Path $otherExport -Force | Out-Null
                Copy-Item -LiteralPath (Join-Path $validExport 'shares.csv') -Destination (Join-Path $otherExport 'shares.csv')
                $otherEntries = @(& $module {
                    param($ExportPath, $ReleaseRoot, $Session)
                    Get-ShareSurferAdvancedMenuEntries -ExportPath $ExportPath -StandaloneDashboardPath (Join-Path $ExportPath 'dashboard') -ReleaseRoot $ReleaseRoot -SessionState $Session
                } $otherExport $repoRoot $validSession)
                $otherDashboard = @($otherEntries | Where-Object { $_.Key -eq 'dashboard' })[0]
                Assert-True (-not [bool]$otherDashboard.Available) 'Validation for one export path must not unlock dashboard packaging for another export.'
                Assert-True ([string]$otherDashboard.UnavailableReason -like '*Validate this export*') 'A different export should explain that it needs its own current-session validation.'

                $packagedDashboard = Join-Path $validExport 'packaged-dashboard'
                Remove-Item -LiteralPath (Join-Path $validExport 'items.csv') -Force
                $env:SHARESURFER_PLAIN_CONSOLE = '1'
                $script:shareSurferRevalidationAnswers = New-Object 'System.Collections.Generic.Queue[string]'
                foreach ($answer in @('3', 'Y', '6')) { $script:shareSurferRevalidationAnswers.Enqueue($answer) }
                function global:Read-Host {
                    param([string] $Prompt)
                    if ($script:shareSurferRevalidationAnswers.Count -eq 0) { throw ('Unexpected packaging revalidation prompt: {0}' -f $Prompt) }
                    $script:shareSurferRevalidationAnswers.Dequeue()
                }
                & $module {
                    param($InputRoot, $ExportPath, $DashboardPath, $ReleaseRoot, $Session)
                    Invoke-ShareSurferAdvancedMenu -InputRoot $InputRoot -ExportPath $ExportPath -StandaloneDashboardPath $DashboardPath -ReleaseRoot $ReleaseRoot -ConsoleMode Plain -SessionState $Session
                } (Join-Path $root 'inputs') $validExport $packagedDashboard $repoRoot $validSession
                Assert-True (-not (Test-Path -LiteralPath $packagedDashboard)) 'Dashboard packaging should stop when a required export file changes after validation.'
                Assert-True (-not [bool]$validSession.ValidationPassed) 'Failed just-in-time revalidation should revoke the session validation token.'
                Assert-Equal $script:shareSurferRevalidationAnswers.Count 0 'Revalidation failure should return to Advanced tools and consume Back to home.'
            }
            finally {
                Remove-Item -Path Env:SHARESURFER_PLAIN_CONSOLE -ErrorAction SilentlyContinue
                Remove-Item -Path function:\Read-Host -ErrorAction SilentlyContinue
                Remove-Variable -Name shareSurferRevalidationAnswers -Scope Script -ErrorAction SilentlyContinue
                Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    },
    @{
        Name = 'Validated results offer an optional owner-mapping draft and return home'
        Body = {
            Import-Module $moduleManifest -Force
            $root = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferMenuOwnerDraft-' + [guid]::NewGuid().ToString('N'))
            $inputRoot = Join-Path $root 'inputs'
            $exportPath = Join-Path $root 'export'
            $draftPath = Join-Path $inputRoot 'owner-mapping-draft.csv'
            $rerunPath = Join-Path $inputRoot 'owner-mapping-draft-rerun.ps1'
            New-Item -ItemType Directory -Path $inputRoot -Force | Out-Null
            $inventory = New-TestInventory
            $inventory.OwnerMappings = @()
            Invoke-ShareSurferScan -InputObject $inventory -OutputPath $exportPath -SkipIdentityEnrichment -Quiet | Out-Null

            $env:SHARESURFER_PLAIN_CONSOLE = '1'
            $script:shareSurferOwnerDraftAnswers = New-Object 'System.Collections.Generic.Queue[string]'
            foreach ($answer in @('3', '1', 'Q')) { $script:shareSurferOwnerDraftAnswers.Enqueue($answer) }
            function global:Read-Host {
                param([string] $Prompt)
                if ($script:shareSurferOwnerDraftAnswers.Count -eq 0) { throw ('Unexpected owner-draft prompt: {0}' -f $Prompt) }
                $script:shareSurferOwnerDraftAnswers.Dequeue()
            }

            try {
                Start-ShareSurfer -ReleaseRoot $repoRoot -InputRoot $inputRoot -ExportPath $exportPath -ConsoleMode Plain
                Assert-True (Test-Path -LiteralPath $draftPath -PathType Leaf) 'Validated review should create the selected owner-mapping draft.'
                Assert-True (Test-Path -LiteralPath $rerunPath -PathType Leaf) 'Owner-mapping draft creation should include a reusable command file.'
                $draftRows = @(Import-Csv -LiteralPath $draftPath)
                Assert-True ($draftRows.Count -gt 0) 'Owner-mapping draft should contain reviewable path candidates.'
                Assert-True ($draftRows[0].PSObject.Properties.Name -contains 'Owner') 'Owner-mapping draft should include the Owner field for human completion.'
                Assert-True ($draftRows[0].PSObject.Properties.Name -contains 'BusinessUnit') 'Owner-mapping draft should include the BusinessUnit field for human completion.'
                Assert-Equal $script:shareSurferOwnerDraftAnswers.Count 0 'Owner-mapping draft flow should return to the refreshed home and consume Q.'
            }
            finally {
                Remove-Item -Path Env:SHARESURFER_PLAIN_CONSOLE -ErrorAction SilentlyContinue
                Remove-Item -Path function:\Read-Host -ErrorAction SilentlyContinue
                Remove-Variable -Name shareSurferOwnerDraftAnswers -Scope Script -ErrorAction SilentlyContinue
                Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    },
    @{
        Name = 'Startup selections screen summarizes choices and missing optional inputs'
        Body = {
            Import-Module $moduleManifest -Force
            $module = Get-Module ShareSurfer
            $screen = @(& $module {
                Get-ShareSurferStartupSelectionsScreen `
                    -EnvironmentMode 'Permissive' `
                    -TargetPath @('\\filer01\finance') `
                    -ExportPath 'C:\ShareSurfer\export' `
                    -StandaloneDashboardPath 'C:\ShareSurfer\dashboard' `
                    -ObsAttribute 'extensionAttribute10' `
                    -AdLookupMode 'Auto' `
                    -ManagerIdentityFormat 'MailTo' `
                    -AclExportMode 'Compact' `
                    -OwnerMappingPath '' `
                    -OwnershipEnrichmentPath 'C:\missing\ownership-enrichment.csv' `
                    -DiscountedPrincipalPath '' `
                    -SaveConfigPath 'C:\ShareSurfer\inputs\sharesurfer-startup.config.json'
            }) -join [Environment]::NewLine

            Assert-True ($screen.Contains('Startup selections')) 'Selections screen should render a heading.'
            Assert-True ($screen.Contains('Startup path: Permissive')) 'Selections screen should show the chosen startup path.'
            Assert-True ($screen.Contains('\\filer01\finance')) 'Selections screen should show scan targets.'
            Assert-True ($screen.Contains('Owner mapping CSV: (none - the scan runs without it)')) 'Selections screen should mark skipped optional inputs.'
            Assert-True ($screen.Contains('ACL export mode: Compact')) 'Selections screen should show the selected ACL export mode.'
            Assert-True ($screen.Contains('(not found yet)')) 'Selections screen should mark optional paths that do not exist yet.'
            Assert-True ($screen.Contains('sharesurfer-startup.config.json')) 'Selections screen should show where the config will be saved.'
        }
    },
    @{
        Name = 'Ownership header interview supports backtracking and skip'
        Body = {
            Import-Module $moduleManifest -Force
            . (Join-Path $repoRoot 'src/ShareSurfer/Private/Get-ShareSurferOwnershipSourceMap.ps1')
            . (Join-Path $repoRoot 'src/ShareSurfer/Private/ShareSurfer.Console.ps1')
            . (Join-Path $repoRoot 'src/ShareSurfer/Public/Join-ShareSurferOwnershipSources.ps1')
            $headers = @('employee_id', 'employee_number', 'obs')
            $initial = [pscustomobject][ordered]@{
                EmployeeId = 'employee_id'
                EmployeeNumber = 'employee_number'
                SamAccountName = ''
                UserPrincipalName = ''
                Mail = ''
                DisplayName = ''
                Title = ''
                Office = ''
                Department = ''
                Company = ''
                ManagerMail = ''
                ManagerLevel2Mail = ''
                ManagerLevel3Mail = ''
                OBS = 'obs'
                BusinessUnit = ''
                DataOwner = ''
                OwnerMail = ''
                Project = ''
                ProjectCode = ''
                ProjectDescription = ''
                GroupName = ''
                PathPattern = ''
            }
            $env:SHARESURFER_PLAIN_CONSOLE = '1'
            $script:shareSurferPromptAnswers = New-Object 'System.Collections.Generic.Queue[string]'
            foreach ($answer in @('wrong_header', 'B', 'employee_id', 'S')) {
                $script:shareSurferPromptAnswers.Enqueue($answer)
            }
            for ($index = 0; $index -lt 20; $index++) {
                $script:shareSurferPromptAnswers.Enqueue('S')
            }
            function global:Read-Host {
                param([string] $Prompt)
                if ($script:shareSurferPromptAnswers.Count -eq 0) {
                    throw ('Unexpected prompt: {0}' -f $Prompt)
                }
                $script:shareSurferPromptAnswers.Dequeue()
            }

            try {
                $interview = Read-ShareSurferOwnershipHeaderSelections -Headers $headers -InitialFieldMap $initial -SourcePath 'ownership.csv'
                Assert-True (-not [bool]$interview.Cancelled) 'Interview should complete without cancellation.'
                Assert-Equal $interview.FieldMap.EmployeeId 'employee_id' 'Backtracking should allow the previous field to be corrected.'
                Assert-Equal $interview.FieldMap.EmployeeNumber '' 'S should skip the current field.'
                Assert-Equal $script:shareSurferPromptAnswers.Count 0 'Header interview should consume the expected prompts.'
            }
            finally {
                Remove-Item -Path Env:SHARESURFER_PLAIN_CONSOLE -ErrorAction SilentlyContinue
                Remove-Item -Path function:\Read-Host -ErrorAction SilentlyContinue
                Remove-Variable -Name shareSurferPromptAnswers -Scope Script -ErrorAction SilentlyContinue
            }
        }
    },
    @{
        Name = 'Ownership header wizard requires an explicit skip when no suggestion exists'
        Body = {
            Import-Module $moduleManifest -Force
            . (Join-Path $repoRoot 'src/ShareSurfer/Private/Get-ShareSurferOwnershipSourceMap.ps1')
            . (Join-Path $repoRoot 'src/ShareSurfer/Private/ShareSurfer.Console.ps1')
            . (Join-Path $repoRoot 'src/ShareSurfer/Public/Join-ShareSurferOwnershipSources.ps1')
            $initial = [pscustomobject][ordered]@{
                EmployeeId = ''
                EmployeeNumber = ''
                SamAccountName = ''
                UserPrincipalName = ''
                Mail = ''
                DisplayName = ''
                Title = ''
                Office = ''
                Department = ''
                Company = ''
                ManagerMail = ''
                ManagerLevel2Mail = ''
                ManagerLevel3Mail = ''
                OBS = ''
                BusinessUnit = ''
                DataOwner = ''
                OwnerMail = ''
                Project = ''
                ProjectCode = ''
                ProjectDescription = ''
                GroupName = ''
                PathPattern = ''
            }

            $state = New-ShareSurferOwnershipHeaderWizardState -Headers @('PersonKey', 'OrgPath') -InitialFieldMap $initial -SourcePath 'ownership.csv'
            Invoke-ShareSurferOwnershipHeaderWizardCommand -State $state -Command '' | Out-Null
            Assert-Equal $state.FieldIndex 0 'Blank Enter with no suggestion should keep the admin on the current field.'
            Assert-True ([string]$state.Message -like '*No suggestion exists*') 'Blank Enter with no suggestion should explain how to choose or skip deliberately.'

            Invoke-ShareSurferOwnershipHeaderWizardCommand -State $state -Command 'S' | Out-Null
            Assert-Equal $state.FieldIndex 1 'S should still skip deliberately and advance.'
            Assert-Equal $state.FieldMap.EmployeeId '' 'Deliberate skip should leave the field blank.'
        }
    },
    @{
        Name = 'Ownership header wizard selects headers by number and records typo warnings'
        Body = {
            Import-Module $moduleManifest -Force
            . (Join-Path $repoRoot 'src/ShareSurfer/Private/Get-ShareSurferOwnershipSourceMap.ps1')
            . (Join-Path $repoRoot 'src/ShareSurfer/Private/ShareSurfer.Console.ps1')
            . (Join-Path $repoRoot 'src/ShareSurfer/Public/Join-ShareSurferOwnershipSources.ps1')
            $headers = @('PersonKey', 'OrgPath')
            $initial = [pscustomobject][ordered]@{
                EmployeeId = ''
                EmployeeNumber = ''
                SamAccountName = ''
                UserPrincipalName = ''
                Mail = ''
                DisplayName = ''
                Title = ''
                Office = ''
                Department = ''
                Company = ''
                ManagerMail = ''
                ManagerLevel2Mail = ''
                ManagerLevel3Mail = ''
                OBS = ''
                BusinessUnit = ''
                DataOwner = ''
                OwnerMail = ''
                Project = ''
                ProjectCode = ''
                ProjectDescription = ''
                GroupName = ''
                PathPattern = ''
            }
            $env:SHARESURFER_PLAIN_CONSOLE = '1'
            $script:shareSurferPromptAnswers = New-Object 'System.Collections.Generic.Queue[string]'
            $script:shareSurferPromptAnswers.Enqueue('1')
            $script:shareSurferPromptAnswers.Enqueue('zz_nope')
            for ($index = 0; $index -lt 20; $index++) {
                $script:shareSurferPromptAnswers.Enqueue('S')
            }
            function global:Read-Host {
                param([string] $Prompt)
                if ($script:shareSurferPromptAnswers.Count -eq 0) {
                    throw ('Unexpected prompt: {0}' -f $Prompt)
                }
                $script:shareSurferPromptAnswers.Dequeue()
            }

            try {
                $interview = Read-ShareSurferOwnershipHeaderSelections -Headers $headers -InitialFieldMap $initial -SourcePath 'ownership.csv'
                Assert-Equal $interview.FieldMap.EmployeeId 'PersonKey' 'Typing a number should map the field to that header from the visible list.'
                Assert-Equal $interview.FieldMap.EmployeeNumber '' 'A typo header with no synonym match should resolve to blank.'
                Assert-True ((@($interview.Warnings) -join ' ').Contains('zz_nope')) 'A typo header should surface as a recorded interview warning.'
                Assert-Equal $script:shareSurferPromptAnswers.Count 0 'Header wizard test should consume the expected prompts.'
            }
            finally {
                Remove-Item -Path Env:SHARESURFER_PLAIN_CONSOLE -ErrorAction SilentlyContinue
                Remove-Item -Path function:\Read-Host -ErrorAction SilentlyContinue
                Remove-Variable -Name shareSurferPromptAnswers -Scope Script -ErrorAction SilentlyContinue
            }
        }
    },
    @{
        Name = 'Ownership source profile selector explains and records choices'
        Body = {
            Import-Module $moduleManifest -Force
            . (Join-Path $repoRoot 'src/ShareSurfer/Private/Get-ShareSurferOwnershipSourceMap.ps1')
            . (Join-Path $repoRoot 'src/ShareSurfer/Private/ShareSurfer.Console.ps1')
            . (Join-Path $repoRoot 'src/ShareSurfer/Public/Join-ShareSurferOwnershipSources.ps1')
            $fieldMap = [pscustomobject][ordered]@{
                ProjectCode = 'project_code'
                OBS = 'obs'
                DataOwner = 'owner'
            }
            $initialProfile = [pscustomobject]@{
                SourcePath = 'projects.csv'
                SourceType = 'Mixed'
                AuthorityLevel = 'Unknown'
                PrimaryAnchor = ''
                MappedFields = 'ProjectCode; OBS; DataOwner'
                Warnings = ''
            }
            $env:SHARESURFER_PLAIN_CONSOLE = '1'
            $script:shareSurferPromptAnswers = New-Object 'System.Collections.Generic.Queue[string]'
            foreach ($answer in @('3', '1', '2')) {
                $script:shareSurferPromptAnswers.Enqueue($answer)
            }
            function global:Read-Host {
                param([string] $Prompt)
                if ($script:shareSurferPromptAnswers.Count -eq 0) {
                    throw ('Unexpected prompt: {0}' -f $Prompt)
                }
                $script:shareSurferPromptAnswers.Dequeue()
            }

            try {
                $profile = Read-ShareSurferOwnershipSourceProfile -SourcePath 'projects.csv' -FieldMap $fieldMap -InitialProfile $initialProfile
                Assert-Equal $profile.SourceType 'ProjectContext' 'Source type selector should accept numbered fallback choices.'
                Assert-Equal $profile.AuthorityLevel 'Authoritative' 'Authority selector should accept alternate choices.'
                Assert-Equal $profile.PrimaryAnchor 'OBS' 'Primary anchor selector should record the selected mapped field.'
                Assert-Equal $script:shareSurferPromptAnswers.Count 0 'Profile selector should consume the expected prompts.'
            }
            finally {
                Remove-Item -Path Env:SHARESURFER_PLAIN_CONSOLE -ErrorAction SilentlyContinue
                Remove-Item -Path function:\Read-Host -ErrorAction SilentlyContinue
                Remove-Variable -Name shareSurferPromptAnswers -Scope Script -ErrorAction SilentlyContinue
            }
        }
    },
    @{
        Name = 'Ownership header wizard renders guided screens and filters headers'
        Body = {
            Import-Module $moduleManifest -Force
            . (Join-Path $repoRoot 'src/ShareSurfer/Private/Get-ShareSurferOwnershipSourceMap.ps1')
            . (Join-Path $repoRoot 'src/ShareSurfer/Private/ShareSurfer.Console.ps1')
            . (Join-Path $repoRoot 'src/ShareSurfer/Public/Join-ShareSurferOwnershipSources.ps1')
            $headers = @('PersonKey', 'OrgPath', 'ProjectCode', 'OwnerMail')
            $initial = [pscustomobject][ordered]@{
                EmployeeId = 'PersonKey'
                EmployeeNumber = ''
                SamAccountName = ''
                UserPrincipalName = ''
                Mail = ''
                DisplayName = ''
                Title = ''
                Office = ''
                Department = ''
                Company = ''
                ManagerMail = ''
                ManagerLevel2Mail = ''
                ManagerLevel3Mail = ''
                OBS = ''
                BusinessUnit = ''
                DataOwner = ''
                OwnerMail = ''
                Project = ''
                ProjectCode = ''
                ProjectDescription = ''
                GroupName = ''
                PathPattern = ''
            }
            $state = New-ShareSurferOwnershipHeaderWizardState -Headers $headers -InitialFieldMap $initial -SourcePath 'hr-export.csv'
            $screen = @(Get-ShareSurferOwnershipHeaderWizardScreen -State $state -WindowWidth 100) -join [Environment]::NewLine
            Assert-True ($screen.Contains('ShareSurfer Ownership Import')) 'Wizard screen should render the title.'
            Assert-True ($screen.Contains('Source: hr-export.csv')) 'Wizard screen should render the source file.'
            Assert-True ($screen.Contains('Step 1/22 - EmployeeId (recommended)')) 'Wizard screen should render the step counter and field.'
            Assert-True ($screen.Contains('Suggested header')) 'Wizard screen should render the suggestion section.'
            Assert-True ($screen.Contains('> PersonKey')) 'Wizard screen should render the suggested header.'
            Assert-True ($screen.Contains('1 PersonKey')) 'Wizard screen should render numbered available headers.'
            Assert-True ($screen.Contains('Why this matters')) 'Wizard screen should explain the field.'
            Assert-True ($screen.Contains('Q=quit')) 'Wizard screen should render the controls contract.'

            Invoke-ShareSurferOwnershipHeaderWizardCommand -State $state -Command '/org' | Out-Null
            $visible = @(Get-ShareSurferOwnershipHeaderWizardVisibleHeaders -State $state)
            Assert-Equal ($visible -join ',') 'OrgPath' 'The /text filter should narrow visible headers.'
            $filteredScreen = @(Get-ShareSurferOwnershipHeaderWizardScreen -State $state -WindowWidth 100) -join [Environment]::NewLine
            Assert-True ($filteredScreen.Contains('Filter: org')) 'Filtered screen should show the active filter.'
            Assert-True ($filteredScreen.Contains('1 OrgPath')) 'Filtered screen should renumber the visible headers.'

            Invoke-ShareSurferOwnershipHeaderWizardCommand -State $state -Command '1' | Out-Null
            Assert-Equal ([string]$state.FieldMap['EmployeeId']) 'OrgPath' 'Numbered selection should map from the filtered list.'
            Assert-Equal ([string]$state.Filter) '' 'Advancing to the next field should clear the filter.'
            Assert-Equal ([int]$state.FieldIndex) 1 'Selection should advance to the next field.'
        }
    },
    @{
        Name = 'Ownership source classification cancel returns without throwing'
        Body = {
            Import-Module $moduleManifest -Force
            . (Join-Path $repoRoot 'src/ShareSurfer/Private/Get-ShareSurferOwnershipSourceMap.ps1')
            . (Join-Path $repoRoot 'src/ShareSurfer/Private/ShareSurfer.Console.ps1')
            . (Join-Path $repoRoot 'src/ShareSurfer/Public/Join-ShareSurferOwnershipSources.ps1')
            $fieldMap = [pscustomobject][ordered]@{
                ProjectCode = 'project_code'
                OBS = 'obs'
            }
            $initialProfile = [pscustomobject]@{
                SourcePath = 'projects.csv'
                SourceType = 'Mixed'
                AuthorityLevel = 'Unknown'
                PrimaryAnchor = ''
                MappedFields = 'ProjectCode; OBS'
                Warnings = ''
            }
            $env:SHARESURFER_PLAIN_CONSOLE = '1'
            $script:shareSurferPromptAnswers = New-Object 'System.Collections.Generic.Queue[string]'
            $script:shareSurferPromptAnswers.Enqueue('Q')
            function global:Read-Host {
                param([string] $Prompt)
                if ($script:shareSurferPromptAnswers.Count -eq 0) {
                    throw ('Unexpected prompt: {0}' -f $Prompt)
                }
                $script:shareSurferPromptAnswers.Dequeue()
            }

            try {
                $result = Read-ShareSurferOwnershipSourceProfile -SourcePath 'projects.csv' -FieldMap $fieldMap -InitialProfile $initialProfile
                Assert-True ([bool]$result.Cancelled) 'Q should return a Cancelled result instead of throwing.'
            }
            finally {
                Remove-Item -Path Env:SHARESURFER_PLAIN_CONSOLE -ErrorAction SilentlyContinue
                Remove-Item -Path function:\Read-Host -ErrorAction SilentlyContinue
                Remove-Variable -Name shareSurferPromptAnswers -Scope Script -ErrorAction SilentlyContinue
            }
        }
    },
    @{
        Name = 'Ownership mapping profile stores interview warnings and cancels cleanly'
        Body = {
            Import-Module $moduleManifest -Force
            . (Join-Path $repoRoot 'src/ShareSurfer/Private/Get-ShareSurferOwnershipSourceMap.ps1')
            . (Join-Path $repoRoot 'src/ShareSurfer/Private/ShareSurfer.Console.ps1')
            . (Join-Path $repoRoot 'src/ShareSurfer/Public/Join-ShareSurferOwnershipSources.ps1')
            . (Join-Path $repoRoot 'src/ShareSurfer/Public/Test-ShareSurferOwnershipSource.ps1')
            . (Join-Path $repoRoot 'src/ShareSurfer/Public/New-ShareSurferOwnershipMappingProfile.ps1')
            $sourcePath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferProfileWarnings-' + [guid]::NewGuid().ToString('N') + '.csv')
            $profilePath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferProfileWarnings-' + [guid]::NewGuid().ToString('N') + '.json')
            $cancelProfilePath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferProfileCancel-' + [guid]::NewGuid().ToString('N') + '.json')
            Set-Content -LiteralPath $sourcePath -Value @('PersonKey,OrgPath', 'p1,Corp/Finance') -Encoding UTF8

            $env:SHARESURFER_PLAIN_CONSOLE = '1'
            $script:shareSurferPromptAnswers = New-Object 'System.Collections.Generic.Queue[string]'
            $script:shareSurferPromptAnswers.Enqueue('zz_nope')
            for ($index = 0; $index -lt 21; $index++) {
                $script:shareSurferPromptAnswers.Enqueue('S')
            }
            $script:shareSurferPromptAnswers.Enqueue('Q')
            function global:Read-Host {
                param([string] $Prompt)
                if ($script:shareSurferPromptAnswers.Count -eq 0) {
                    throw ('Unexpected prompt: {0}' -f $Prompt)
                }
                $script:shareSurferPromptAnswers.Dequeue()
            }

            try {
                $summary = New-ShareSurferOwnershipMappingProfile -Path $sourcePath -OutputPath $profilePath -Interactive -Force
                Assert-True ((@($summary.Warnings) -join ' ').Contains('zz_nope')) 'Profile summary should carry post-interview warnings.'
                $savedProfile = Get-Content -LiteralPath $profilePath -Raw | ConvertFrom-Json
                Assert-True ((@($savedProfile.Warnings) -join ' ').Contains('zz_nope')) 'Saved mapping profile should record interview typo warnings.'

                $threw = $false
                try {
                    New-ShareSurferOwnershipMappingProfile -Path $sourcePath -OutputPath $cancelProfilePath -Interactive -Force | Out-Null
                }
                catch {
                    $threw = $true
                    Assert-True ($_.Exception.Message.Contains('cancelled by operator')) 'Cancel should abort with the operator-cancel message.'
                }
                Assert-True $threw 'Cancelling the interview should abort mapping profile creation.'
                Assert-True (-not (Test-Path -LiteralPath $cancelProfilePath)) 'A cancelled interview should not write a partial mapping profile.'
                Assert-Equal $script:shareSurferPromptAnswers.Count 0 'Mapping profile tests should consume the expected prompts.'
            }
            finally {
                Remove-Item -Path Env:SHARESURFER_PLAIN_CONSOLE -ErrorAction SilentlyContinue
                Remove-Item -Path function:\Read-Host -ErrorAction SilentlyContinue
                Remove-Variable -Name shareSurferPromptAnswers -Scope Script -ErrorAction SilentlyContinue
                Remove-Item -LiteralPath $sourcePath -ErrorAction SilentlyContinue
                Remove-Item -LiteralPath $profilePath -ErrorAction SilentlyContinue
                Remove-Item -LiteralPath $cancelProfilePath -ErrorAction SilentlyContinue
            }
        }
    },
    @{
        Name = 'Join-ShareSurferOwnershipSources merges partial ownership CSVs'
        Body = {
            Import-Module $moduleManifest -Force
            $sourceOnePath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferOwnershipHr-' + [guid]::NewGuid().ToString('N') + '.csv')
            $sourceTwoPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferOwnershipProjects-' + [guid]::NewGuid().ToString('N') + '.csv')
            $outputPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferOwnershipEnrichment-' + [guid]::NewGuid().ToString('N') + '.csv')
            $commandPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferOwnershipEnrichment-' + [guid]::NewGuid().ToString('N') + '.rerun.ps1')

            @(
                [pscustomobject]@{
                    employee_id = 'E1001'
                    display_name = 'Ava Accounting'
                    mail = 'ava.accounting@example.test'
                    obs = 'CORP.FIN.AP'
                    business_unit = 'Finance'
                }
            ) | Export-Csv -LiteralPath $sourceOnePath -NoTypeInformation -Encoding UTF8
            @(
                [pscustomobject]@{
                    obs = 'CORP.FIN.AP'
                    project_code = 'AP-2026'
                    project = 'Accounts Payable Modernization'
                }
            ) | Export-Csv -LiteralPath $sourceTwoPath -NoTypeInformation -Encoding UTF8

            $summary = Join-ShareSurferOwnershipSources -Path @($sourceOnePath, $sourceTwoPath) -OutputPath $outputPath -ReusableCommandPath $commandPath -AdLookupMode DirectoryOnly
            $rows = Import-Csv -LiteralPath $outputPath
            $commandText = Get-Content -LiteralPath $commandPath -Raw

            Assert-Equal $summary.RowCount 1 'Join summary should merge rows with the same EmployeeID.'
            Assert-Equal $rows.Count 1 'Enrichment CSV should contain one merged row.'
            Assert-Equal $rows[0].EmployeeId 'E1001' 'Merged row should preserve EmployeeID.'
            Assert-Equal $rows[0].DisplayName 'Ava Accounting' 'Merged row should preserve person fields from the HR source.'
            Assert-Equal $rows[0].OBS 'CORP.FIN.AP' 'Merged row should preserve OBS from the second source.'
            Assert-Equal $rows[0].ProjectCode 'AP-2026' 'Merged row should preserve project code from the second source.'
            Assert-True ([string]$rows[0].SourcePaths -like '*ShareSurferOwnershipHr*') 'Merged row should retain source path provenance.'
            Assert-True ([string]$rows[0].SourcePaths -like '*ShareSurferOwnershipProjects*') 'Merged row should retain second source provenance.'
            Assert-True ($commandText -like '*Join-ShareSurferOwnershipSources*') 'Reusable command should rerun the joined enrichment command.'
            Assert-True ($commandText -like '*OwnershipEnrichmentPath*') 'Reusable command should explain passing the output into the scan.'
        }
    },
    @{
        Name = 'Join-ShareSurferOwnershipSources reports progress during ownership import'
        Body = {
            Import-Module $moduleManifest -Force
            $sourceOnePath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferOwnershipProgressHr-' + [guid]::NewGuid().ToString('N') + '.csv')
            $sourceTwoPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferOwnershipProgressProjects-' + [guid]::NewGuid().ToString('N') + '.csv')
            $outputPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferOwnershipProgressOutput-' + [guid]::NewGuid().ToString('N') + '.csv')

            @(
                [pscustomobject]@{ employee_id = 'E1001'; display_name = 'Ava Accounting'; obs = 'CORP.FIN.AP' },
                [pscustomobject]@{ employee_id = 'E1002'; display_name = 'Ben Billing'; obs = 'CORP.FIN.AR' }
            ) | Export-Csv -LiteralPath $sourceOnePath -NoTypeInformation -Encoding UTF8
            @(
                [pscustomobject]@{ obs = 'CORP.FIN.AP'; project_code = 'AP-2026'; project = 'Accounts Payable Modernization' },
                [pscustomobject]@{ obs = 'CORP.FIN.AR'; project_code = 'AR-2026'; project = 'Accounts Receivable Cleanup' }
            ) | Export-Csv -LiteralPath $sourceTwoPath -NoTypeInformation -Encoding UTF8

            $captured = & {
                Join-ShareSurferOwnershipSources `
                    -Path @($sourceOnePath, $sourceTwoPath) `
                    -OutputPath $outputPath `
                    -AdLookupMode DirectoryOnly `
                    -ProgressRowInterval 1 `
                    -ProgressIntervalSeconds 0 `
                    -Force | Out-Null
            } 6>&1
            $capturedText = (@($captured) | ForEach-Object { [string]$_ }) -join "`n"

            Assert-True ($capturedText -like '*Selected 2 ownership source CSV file(s)*') 'Progress output should announce selected CSV source count.'
            Assert-True ($capturedText -like '*Source 1/2: processing 2 row(s)*') 'Progress output should announce per-source row counts.'
            Assert-True ($capturedText -like '*Source 2/2: processed 2/2 row(s)*') 'Progress output should announce OBS-only context source progress.'
            Assert-True ($capturedText -like '*Directory enrichment: processed 2/2 row(s)*') 'Progress output should announce directory enrichment progress.'
            Assert-True ($capturedText -like '*Ownership import complete: 2 row(s)*') 'Progress output should announce completion summary.'
            Assert-True (Test-Path -LiteralPath $outputPath) 'Ownership import should still write the enrichment output.'
        }
    },
    @{
        Name = 'Join-ShareSurferOwnershipSources writes context graph rows for project OBS sources'
        Body = {
            Import-Module $moduleManifest -Force
            $sourcePath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferOwnershipProjectContext-' + [guid]::NewGuid().ToString('N') + '.csv')
            $outputPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferOwnershipProjectContext-' + [guid]::NewGuid().ToString('N') + '.csv')
            $definitionPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferOwnershipProjectContext-' + [guid]::NewGuid().ToString('N') + '.json')
            $contextPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferOwnershipContext-' + [guid]::NewGuid().ToString('N') + '.csv')
            $relationshipPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferOwnershipRelationships-' + [guid]::NewGuid().ToString('N') + '.csv')
            $manifestPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferOwnershipImportManifest-' + [guid]::NewGuid().ToString('N') + '.csv')
            Set-Content -LiteralPath $sourcePath -Value @(
                'OBS,ProjectCode,ProjectDescription,BusinessUnit,DataOwner',
                'CORP.FIN.AP,FIN-AP,Accounts Payable modernization,Finance,Finance Operations'
            ) -Encoding UTF8

            $summary = Join-ShareSurferOwnershipSources `
                -Path $sourcePath `
                -OutputPath $outputPath `
                -DefinitionPath $definitionPath `
                -IncludeContextGraph `
                -ContextOutputPath $contextPath `
                -RelationshipOutputPath $relationshipPath `
                -ManifestOutputPath $manifestPath `
                -AdLookupMode DirectoryOnly `
                -Force

            $contextRows = @(Import-Csv -LiteralPath $contextPath)
            $relationshipRows = @(Import-Csv -LiteralPath $relationshipPath)
            $manifestRows = @(Import-Csv -LiteralPath $manifestPath)
            $definition = Get-Content -LiteralPath $definitionPath -Raw | ConvertFrom-Json

            Assert-Equal $summary.ContextRowCount 2 'Project/OBS source should emit project and OBS context rows.'
            Assert-True (@($contextRows | Where-Object { $_.SourceType -eq 'ProjectContext' -and $_.EntityType -eq 'Project' -and $_.EntityKey -eq 'FIN-AP' }).Count -eq 1) 'Context rows should include the project entity.'
            Assert-True (@($contextRows | Where-Object { $_.EntityType -eq 'OBS' -and $_.EntityKey -eq 'CORP.FIN.AP' }).Count -eq 1) 'Context rows should include the OBS entity.'
            Assert-True (@($relationshipRows | Where-Object { $_.FromType -eq 'Project' -and $_.FromValue -eq 'FIN-AP' -and $_.RelationshipType -eq 'BelongsTo' -and $_.ToType -eq 'OBS' -and $_.ToValue -eq 'CORP.FIN.AP' }).Count -eq 1) 'Relationships should explain Project to OBS.'
            Assert-True (@($relationshipRows | Where-Object { $_.FromType -eq 'OBS' -and $_.RelationshipType -eq 'ReviewedBy' -and $_.ToType -eq 'DataOwner' -and $_.ToValue -eq 'Finance Operations' }).Count -eq 1) 'Relationships should explain OBS reviewer hint.'
            Assert-Equal $manifestRows[0].SourceType 'ProjectContext' 'Manifest should record inferred ProjectContext source type.'
            Assert-Equal $manifestRows[0].PrimaryAnchor 'ProjectCode' 'Manifest should record ProjectCode as the primary anchor.'
            Assert-Equal ([string]$definition.includeContextGraph) 'True' 'Definition should remember context graph mode.'
            Assert-Equal $definition.sourceProfiles[0].sourceType 'ProjectContext' 'Definition should remember source profile type.'

            $rerunOutputPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferOwnershipProjectContextRerun-' + [guid]::NewGuid().ToString('N') + '.csv')
            $rerunSummary = Join-ShareSurferOwnershipSources -DefinitionPath $definitionPath -OutputPath $rerunOutputPath -Force
            Assert-Equal $rerunSummary.ContextRowCount 2 'Definition rerun should reproduce context rows without interactive prompts.'
            Assert-True (Test-Path -LiteralPath $rerunSummary.RelationshipOutputPath) 'Definition rerun should reproduce relationship output.'
        }
    },
    @{
        Name = 'Join-ShareSurferOwnershipSources defers OBS context fan-out until bucket merge'
        Body = {
            Import-Module $moduleManifest -Force
            $identityPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferOwnershipFanoutIdentity-' + [guid]::NewGuid().ToString('N') + '.csv')
            $contextPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferOwnershipFanoutContext-' + [guid]::NewGuid().ToString('N') + '.csv')
            $outputPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferOwnershipFanoutOutput-' + [guid]::NewGuid().ToString('N') + '.csv')
            $ownershipContextPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferOwnershipFanoutContextOut-' + [guid]::NewGuid().ToString('N') + '.csv')
            $relationshipPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferOwnershipFanoutRelationships-' + [guid]::NewGuid().ToString('N') + '.csv')
            $manifestPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferOwnershipFanoutManifest-' + [guid]::NewGuid().ToString('N') + '.csv')

            $identityRows = for ($index = 1; $index -le 5; $index++) {
                [pscustomobject]@{
                    employee_id = 'E{0:0000}' -f $index
                    display_name = 'User {0}' -f $index
                    obs = 'CORP.FIN.AP'
                    business_unit = 'Finance'
                }
            }
            $contextRows = for ($index = 1; $index -le 10; $index++) {
                [pscustomobject]@{
                    obs = 'CORP.FIN.AP'
                    project_code = 'AP-{0:0000}' -f $index
                    project = 'Accounts Payable {0}' -f $index
                    business_unit = 'Finance'
                    data_owner = 'Finance Operations'
                }
            }
            $identityRows | Export-Csv -LiteralPath $identityPath -NoTypeInformation -Encoding UTF8
            $contextRows | Export-Csv -LiteralPath $contextPath -NoTypeInformation -Encoding UTF8

            $summary = Join-ShareSurferOwnershipSources `
                -Path @($identityPath, $contextPath) `
                -OutputPath $outputPath `
                -ContextOutputPath $ownershipContextPath `
                -RelationshipOutputPath $relationshipPath `
                -ManifestOutputPath $manifestPath `
                -IncludeContextGraph `
                -AdLookupMode DirectoryOnly `
                -Quiet `
                -Force
            $rows = @(Import-Csv -LiteralPath $outputPath)

            Assert-Equal $summary.RowCount 5 'Strong identity rows should remain the output ownership rows.'
            Assert-Equal $summary.ObsContextStrongRowMergeCount 5 'OBS context should be applied once per matching strong row, not once per context row per strong row.'
            Assert-Equal $summary.ObsContextOrphanRowCount 0 'Matching OBS context should not create orphan ownership rows.'
            Assert-True (@($rows | Where-Object { $_.ProjectCode -eq 'AP-0001' }).Count -eq 5) 'Strong rows should still receive aggregated OBS context.'
        }
    },
    @{
        Name = 'Join-ShareSurferOwnershipSources applies context-before-identity provenance once'
        Body = {
            Import-Module $moduleManifest -Force
            $identityPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferOwnershipContextFirstIdentity-' + [guid]::NewGuid().ToString('N') + '.csv')
            $contextPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferOwnershipContextFirstContext-' + [guid]::NewGuid().ToString('N') + '.csv')
            $outputPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferOwnershipContextFirstOutput-' + [guid]::NewGuid().ToString('N') + '.csv')

            Set-Content -LiteralPath $contextPath -Value @(
                'obs,project_code,project,business_unit,data_owner',
                'CORP.FIN.AP,AP-2026,Accounts Payable Modernization,Finance,Finance Operations',
                'CORP.FIN.AP,AP-2027,Accounts Payable Archive,Finance,Finance Operations'
            ) -Encoding UTF8
            Set-Content -LiteralPath $identityPath -Value @(
                'employee_id,display_name,obs,business_unit',
                'E1001,Ava Accounting,CORP.FIN.AP,Finance'
            ) -Encoding UTF8

            $summary = Join-ShareSurferOwnershipSources `
                -Path @($contextPath, $identityPath) `
                -OutputPath $outputPath `
                -AdLookupMode DirectoryOnly `
                -Quiet `
                -Force
            $rows = @(Import-Csv -LiteralPath $outputPath)

            Assert-Equal $summary.RowCount 1 'Context-first input should still produce one strong ownership row.'
            Assert-Equal $summary.ObsContextStrongRowMergeCount 1 'OBS context should be applied once to the matching strong row.'
            Assert-Equal $rows[0].SourceRowNumbers '2; 3' 'Context provenance row numbers should not be duplicated by ingest-time and post-pass merges.'
            Assert-True ([string]$rows[0].SourcePaths -like '*ShareSurferOwnershipContextFirstContext*') 'Context source path should remain visible in provenance.'
            Assert-True ([string]$rows[0].SourcePaths -like '*ShareSurferOwnershipContextFirstIdentity*') 'Identity source path should remain visible in provenance.'
            Assert-True ([string]$rows[0].ImportWarnings -notlike '*NoJoinKey*') 'Strong rows should not inherit row-scoped NoJoinKey warnings from OBS context files.'
        }
    },
    @{
        Name = 'Join-ShareSurferOwnershipSources warns when a source maps no join or OBS keys'
        Body = {
            Import-Module $moduleManifest -Force
            $sourcePath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferOwnershipNoKeys-' + [guid]::NewGuid().ToString('N') + '.csv')
            $outputPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferOwnershipNoKeysOutput-' + [guid]::NewGuid().ToString('N') + '.csv')
            Set-Content -LiteralPath $sourcePath -Value @(
                'UnmappedColumn,AnotherUnmappedColumn',
                'alpha,beta'
            ) -Encoding UTF8

            $summary = Join-ShareSurferOwnershipSources `
                -Path $sourcePath `
                -OutputPath $outputPath `
                -AdLookupMode DirectoryOnly `
                -Quiet `
                -Force

            Assert-Equal $summary.RowCount 1 'No-key source should still export evidence for review.'
            Assert-True ((@($summary.Warnings) -join "`n") -like '*no rows mapped to an employee/account join key or OBS key*') 'No-key source should produce a source-level warning.'
        }
    },
    @{
        Name = 'Join-ShareSurferOwnershipSources handles skewed OBS context buckets without crawl'
        Body = {
            Import-Module $moduleManifest -Force
            $contextPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferOwnershipSkewContext-' + [guid]::NewGuid().ToString('N') + '.csv')
            $outputPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferOwnershipSkewOutput-' + [guid]::NewGuid().ToString('N') + '.csv')
            $lines = New-Object System.Collections.Generic.List[string]
            $lines.Add('obs,project_code,project,business_unit,data_owner')
            for ($index = 1; $index -le 1500; $index++) {
                $lines.Add(('CORP.FIN.AP,AP-{0:0000},Accounts Payable {0},Finance,Finance Operations' -f $index))
            }
            Set-Content -LiteralPath $contextPath -Value $lines -Encoding UTF8

            $clock = [System.Diagnostics.Stopwatch]::StartNew()
            $summary = Join-ShareSurferOwnershipSources `
                -Path $contextPath `
                -OutputPath $outputPath `
                -AdLookupMode DirectoryOnly `
                -Quiet `
                -Force
            $clock.Stop()

            Assert-Equal $summary.RowCount 1 'Skewed OBS-only context should aggregate into one orphan OBS row.'
            Assert-Equal $summary.ObsContextOrphanRowCount 1 'Skewed OBS-only context should be reported as one orphan OBS bucket.'
            Assert-True ($clock.Elapsed.TotalSeconds -lt 20) ('Skewed OBS context import should not crawl; elapsed seconds: {0:n2}' -f $clock.Elapsed.TotalSeconds)
        }
    },
    @{
        Name = 'Join-ShareSurferOwnershipSources reruns from ownership import definition'
        Body = {
            Import-Module $moduleManifest -Force
            $sourcePath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferDefinitionRerunHr-' + [guid]::NewGuid().ToString('N') + '.csv')
            $definitionPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferOwnershipDefinitionRerun-' + [guid]::NewGuid().ToString('N') + '.json')
            $definitionOutputPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferOwnershipDefinitionOutput-' + [guid]::NewGuid().ToString('N') + '.csv')
            $outputPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferOwnershipDefinitionRerunOutput-' + [guid]::NewGuid().ToString('N') + '.csv')
            $commandPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferOwnershipDefinitionRerun-' + [guid]::NewGuid().ToString('N') + '.ps1')
            Set-Content -LiteralPath $sourcePath -Value @(
                'EmployeeID,OBS,BusinessUnit',
                'E1001,CORP.FIN.AP,Finance'
            ) -Encoding UTF8

            Join-ShareSurferOwnershipSources `
                -Path @($sourcePath) `
                -DefinitionPath $definitionPath `
                -OutputPath $definitionOutputPath `
                -ObsAttribute 'extensionAttribute10' `
                -AdLookupMode 'DirectoryOnly' `
                -Force | Out-Null

            $summary = Join-ShareSurferOwnershipSources -DefinitionPath $definitionPath -OutputPath $outputPath -ReusableCommandPath $commandPath -Force -AclExportMode Compact
            $rows = @(Import-Csv -LiteralPath $outputPath)
            $commandText = Get-Content -LiteralPath $commandPath -Raw
            Assert-Equal $summary.SourceCount 1 'Definition rerun should use one source path.'
            Assert-Equal $summary.DefinitionPath $definitionPath 'Summary should report the definition path.'
            Assert-Equal $rows[0].EmployeeId 'E1001' 'Definition rerun should import selected CSV rows.'
            Assert-True ($commandText -like '*DefinitionPath*') 'Reusable command should prefer the definition path.'
            Assert-True ($commandText -like '*Join-ShareSurferOwnershipSources -DefinitionPath*') 'Reusable command should rerun from the definition.'
            Assert-True ($commandText -notlike '*AclExportMode*') 'Reusable ownership import command should not emit scan-only ACL export parameters.'
        }
    },
    @{
        Name = 'Join-ShareSurferOwnershipSources enriches by employee ID and skips forbidden OUs'
        Body = {
            Import-Module $moduleManifest -Force
            $sourcePath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferOwnershipAd-' + [guid]::NewGuid().ToString('N') + '.csv')
            $outputPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferOwnershipAdEnrichment-' + [guid]::NewGuid().ToString('N') + '.csv')
            @(
                [pscustomobject]@{ employee_id = 'E1001'; obs = 'CORP.FIN.AP' },
                [pscustomobject]@{ employee_id = 'E1001'; obs = 'CORP.FIN.AP.REPEAT' },
                [pscustomobject]@{ employee_id = 'E2002'; obs = 'CORP.OLD.DISABLED' }
            ) | Export-Csv -LiteralPath $sourcePath -NoTypeInformation -Encoding UTF8

            try {
                $script:shareSurferOwnershipAdLookupCount = 0
                function global:Get-ADUser {
                    param(
                        [string] $LDAPFilter,
                        [string] $Identity,
                        [string[]] $Properties
                    )

                    if ($LDAPFilter) {
                        $script:shareSurferOwnershipAdLookupCount++
                    }
                    if ($LDAPFilter -like '*E1001*') {
                        return [pscustomobject]@{
                            SamAccountName = 'Ava.Accounting'
                            DisplayName = 'Ava Accounting'
                            EmployeeID = 'E1001'
                            EmployeeNumber = '1001'
                            UserPrincipalName = 'ava.accounting@example.test'
                            Mail = 'ava.accounting@example.test'
                            Department = 'Accounts Payable'
                            Title = 'Accounting Analyst'
                            Company = 'Contoso Finance'
                            physicalDeliveryOfficeName = 'HQ-4'
                            Enabled = $true
                            Manager = ''
                            extensionAttribute10 = 'CORP.FIN.AP.AD'
                            DistinguishedName = 'CN=Ava Accounting,OU=Users,DC=example,DC=test'
                        }
                    }
                    if ($LDAPFilter -like '*E2002*') {
                        return [pscustomobject]@{
                            SamAccountName = 'Old.Account'
                            DisplayName = 'Old Account'
                            EmployeeID = 'E2002'
                            EmployeeNumber = '2002'
                            UserPrincipalName = 'old.account@example.test'
                            Mail = 'old.account@example.test'
                            Department = 'Archive'
                            Title = 'Former Employee'
                            Company = 'Contoso'
                            physicalDeliveryOfficeName = 'Archive'
                            Enabled = $false
                            Manager = ''
                            extensionAttribute10 = 'CORP.OLD.DISABLED.AD'
                            DistinguishedName = 'CN=Old Account,OU=Disabled Accounts,DC=example,DC=test'
                        }
                    }
                    throw ('Unexpected Get-ADUser lookup. LDAPFilter={0}; Identity={1}' -f $LDAPFilter, $Identity)
                }

                $summary = Join-ShareSurferOwnershipSources -Path $sourcePath -OutputPath $outputPath -AdLookupMode ActiveDirectory -ForbiddenOu 'OU=Disabled Accounts,DC=example,DC=test'
                $rows = Import-Csv -LiteralPath $outputPath
                $matched = @($rows | Where-Object { $_.EmployeeId -eq 'E1001' })[0]
                $forbidden = @($rows | Where-Object { $_.EmployeeId -eq 'E2002' })[0]

                Assert-Equal $summary.MatchedCount 1 'Join summary should count the allowed AD match.'
                Assert-Equal $summary.ForbiddenOuSkippedCount 1 'Join summary should count the forbidden OU skip.'
                Assert-Equal $summary.AdLookupAttemptCount 2 'Join summary should count unique AD lookup attempts after merge.'
                Assert-Equal $summary.DirectoryLookupCacheHitCount 0 'Exact duplicate employee IDs should be merged before lookup caching is needed.'
                Assert-Equal $script:shareSurferOwnershipAdLookupCount 2 'AD lookup should run once per merged employee identifier.'
                Assert-Equal $matched.MatchStatus 'Matched' 'Allowed row should be marked as matched.'
                Assert-Equal $matched.SamAccountName 'Ava.Accounting' 'Allowed row should be enriched with SAM account name.'
                Assert-Equal $matched.Title 'Accounting Analyst' 'Allowed row should be enriched with title.'
                Assert-Equal $matched.Office 'HQ-4' 'Allowed row should be enriched with office.'
                Assert-Equal $matched.OBS 'CORP.FIN.AP' 'Source OBS should be preserved over AD OBS.'
                Assert-Equal $matched.AdObsPath 'CORP.FIN.AP.AD' 'AD OBS should be retained separately.'
                Assert-Equal $forbidden.MatchStatus 'ForbiddenOuSkipped' 'Forbidden OU row should be marked as skipped.'
                Assert-True ([string]$forbidden.ForbiddenOuMatched -like '*Disabled Accounts*') 'Forbidden OU row should record the OU that caused the skip.'
            }
            finally {
                Remove-Item -Path function:\Get-ADUser -ErrorAction SilentlyContinue
            }
        }
    },
    @{
        Name = 'Invoke-ShareSurferScan exports ownership enrichment evidence'
        Body = {
            Import-Module $moduleManifest -Force
            $outputPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferExport-' + [guid]::NewGuid().ToString('N'))
            $enrichmentPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferOwnershipEnrichment-' + [guid]::NewGuid().ToString('N') + '.csv')
            @(
                [pscustomobject]@{
                    OwnershipKey = 'EmployeeId:e1001'
                    MatchStatus = 'Matched'
                    MatchMethod = 'EmployeeId'
                    SourcePaths = 'hr.csv'
                    SourceRowNumbers = '2'
                    EmployeeId = 'E1001'
                    EmployeeNumber = '1001'
                    SamAccountName = 'Ava.Accounting'
                    UserPrincipalName = 'ava.accounting@example.test'
                    Mail = 'ava.accounting@example.test'
                    DisplayName = 'Ava Accounting'
                    Title = 'Accounting Analyst'
                    Office = 'HQ-4'
                    Department = 'Accounts Payable'
                    Company = 'Contoso Finance'
                    Manager = ''
                    ManagerLevel1 = ''
                    ManagerLevel2 = ''
                    ManagerLevel3 = ''
                    ManagerLevel1Raw = ''
                    ManagerLevel2Raw = ''
                    ManagerLevel3Raw = ''
                    OBS = 'CORP.FIN.AP'
                    AdObsPath = 'CORP.FIN.AP'
                    ObsAttribute = 'extensionAttribute10'
                    BusinessUnit = 'Finance'
                    DataOwner = 'Finance Operations'
                    OwnerMail = 'finance.owner@example.test'
                    Project = 'Accounts Payable'
                    ProjectCode = 'AP-2026'
                    AccountEnabled = 'True'
                    DistinguishedName = 'CN=Ava Accounting,OU=Users,DC=example,DC=test'
                    ForbiddenOuMatched = ''
                    PotentialServiceAccount = 'False'
                    ImportWarnings = ''
                }
            ) | Export-Csv -LiteralPath $enrichmentPath -NoTypeInformation -Encoding UTF8

            $summary = Invoke-ShareSurferScan -InputObject (New-TestInventory) -OutputPath $outputPath -OwnershipEnrichmentPath $enrichmentPath -SkipIdentityEnrichment
            $rows = Import-Csv -LiteralPath (Join-Path $outputPath 'ownership_enrichment.csv')

            Assert-Equal $summary.OwnershipEnrichment 1 'Scan summary should report ownership enrichment row count.'
            Assert-Equal $rows.Count 1 'Export should include ownership enrichment rows.'
            Assert-Equal $rows[0].ProjectCode 'AP-2026' 'Exported ownership enrichment should preserve project code.'
            Assert-Equal $rows[0].MatchStatus 'Matched' 'Exported ownership enrichment should preserve match status.'
        }
    },
    @{
        Name = 'Invoke-ShareSurferScan exports ownership context graph evidence'
        Body = {
            Import-Module $moduleManifest -Force
            $outputPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferExportContextGraph-' + [guid]::NewGuid().ToString('N'))
            $contextPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferOwnershipContext-' + [guid]::NewGuid().ToString('N') + '.csv')
            $relationshipPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferOwnershipRelationships-' + [guid]::NewGuid().ToString('N') + '.csv')
            $manifestPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferOwnershipImportManifest-' + [guid]::NewGuid().ToString('N') + '.csv')
            @(
                [pscustomobject]@{
                    ContextId = 'context-000001'
                    SourceType = 'ProjectContext'
                    SourcePath = 'project-obs.csv'
                    SourceRowNumber = '2'
                    EntityType = 'Project'
                    EntityKey = 'FIN-AP'
                    EntityLabel = 'Accounts Payable modernization'
                    OBS = 'CORP.FIN.AP'
                    BusinessUnit = 'Finance'
                    DataOwner = 'Finance Operations'
                    OwnerMail = 'finance.owner@example.test'
                    Project = 'Accounts Payable modernization'
                    ProjectCode = 'FIN-AP'
                    ProjectDescription = 'Modernize AP share cleanup and migration planning.'
                    GroupName = ''
                    PathPattern = ''
                    AuthorityLevel = 'ReviewerHint'
                    ConfidenceLabel = 'ProjectContextMatch'
                    EvidenceReason = 'Source row describes a project, program, application, or initiative.'
                    ImportWarnings = ''
                }
            ) | Export-Csv -LiteralPath $contextPath -NoTypeInformation -Encoding UTF8
            @(
                [pscustomobject]@{
                    RelationshipId = 'relationship-000001'
                    SourceType = 'ProjectContext'
                    SourcePath = 'project-obs.csv'
                    SourceRowNumber = '2'
                    FromType = 'Project'
                    FromValue = 'FIN-AP'
                    RelationshipType = 'BelongsTo'
                    ToType = 'OBS'
                    ToValue = 'CORP.FIN.AP'
                    AuthorityLevel = 'ReviewerHint'
                    ConfidenceLabel = 'ProjectContextMatch'
                    EvidenceReason = 'Project source linked project or project code to OBS.'
                }
            ) | Export-Csv -LiteralPath $relationshipPath -NoTypeInformation -Encoding UTF8
            @(
                [pscustomobject]@{
                    SourcePath = 'project-obs.csv'
                    SourceType = 'ProjectContext'
                    AuthorityLevel = 'ReviewerHint'
                    PrimaryAnchor = 'ProjectCode'
                    MappedFields = 'OBS; BusinessUnit; DataOwner; OwnerMail; Project; ProjectCode; ProjectDescription'
                    RowCount = '1'
                    ContextRowCount = '1'
                    RelationshipRowCount = '1'
                    Warnings = ''
                }
            ) | Export-Csv -LiteralPath $manifestPath -NoTypeInformation -Encoding UTF8

            Invoke-ShareSurferScan `
                -InputObject (New-TestInventory) `
                -OutputPath $outputPath `
                -OwnershipContextPath $contextPath `
                -OwnershipRelationshipPath $relationshipPath `
                -OwnershipImportManifestPath $manifestPath `
                -SkipIdentityEnrichment | Out-Null

            $contextRows = @(Import-Csv -LiteralPath (Join-Path $outputPath 'ownership_context.csv'))
            $relationshipRows = @(Import-Csv -LiteralPath (Join-Path $outputPath 'ownership_relationships.csv'))
            $manifestRows = @(Import-Csv -LiteralPath (Join-Path $outputPath 'ownership_import_manifest.csv'))
            $validation = Test-ShareSurferExport -ExportPath $outputPath

            Assert-Equal $contextRows[0].EntityKey 'FIN-AP' 'Export should include ownership context rows.'
            Assert-Equal $relationshipRows[0].RelationshipType 'BelongsTo' 'Export should include ownership relationship rows.'
            Assert-Equal $manifestRows[0].SourceType 'ProjectContext' 'Export should include ownership import manifest rows.'
            Assert-True $validation.IsValid 'Export validation should accept ownership context graph files.'
        }
    },
    @{
        Name = 'Invoke-ShareSurferScan rejects malformed ownership context graph files'
        Body = {
            Import-Module $moduleManifest -Force
            $outputPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferExportBadContextGraph-' + [guid]::NewGuid().ToString('N'))
            $badRelationshipPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferBadOwnershipRelationships-' + [guid]::NewGuid().ToString('N') + '.csv')
            Set-Content -LiteralPath $badRelationshipPath -Value @(
                'FromType,FromValue,ToType,ToValue',
                'Project,FIN-AP,OBS,CORP.FIN.AP'
            ) -Encoding UTF8

            $threw = $false
            $message = ''
            try {
                Invoke-ShareSurferScan `
                    -InputObject (New-TestInventory) `
                    -OutputPath $outputPath `
                    -OwnershipRelationshipPath $badRelationshipPath `
                    -SkipIdentityEnrichment | Out-Null
            }
            catch {
                $threw = $true
                $message = [string]$_.Exception.Message
            }

            Assert-True $threw 'Scan should reject malformed ownership context graph files.'
            Assert-True ($message -like '*ownership_relationships.csv*') 'Error should identify the malformed context graph file.'
            Assert-True ($message -like '*Missing column(s)*') 'Error should identify missing schema columns.'
            Assert-True ($message -like '*Join-ShareSurferOwnershipSources -IncludeContextGraph*') 'Error should tell the operator how to rebuild context graph files.'
        }
    },
    @{
        Name = 'Invoke-ShareSurferScan rejects normalized ownership CSVs passed as ownership enrichment'
        Body = {
            Import-Module $moduleManifest -Force
            $outputPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferExport-' + [guid]::NewGuid().ToString('N'))
            $normalizedPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferNormalizedOwnership-' + [guid]::NewGuid().ToString('N') + '.csv')
            Set-Content -LiteralPath $normalizedPath -Value @(
                'EmployeeId,EmployeeNumber,SamAccountName,UserPrincipalName,Mail,DisplayName,ManagerMail,SourceRowNumber,SourcePath',
                'E1001,1001,Ava.Accounting,ava.accounting@example.test,ava.accounting@example.test,Ava Accounting,manager@example.test,2,hr.csv'
            ) -Encoding UTF8

            $threw = $false
            $message = ''
            try {
                Invoke-ShareSurferScan -InputObject (New-TestInventory) -OutputPath $outputPath -OwnershipEnrichmentPath $normalizedPath -SkipIdentityEnrichment | Out-Null
            }
            catch {
                $threw = $true
                $message = [string]$_.Exception.Message
            }

            Assert-True $threw 'Scan should reject a normalized ownership import file passed as ownership enrichment.'
            Assert-True ($message -like '*does not look like Join-ShareSurferOwnershipSources output*') 'Error should explain the expected ownership enrichment producer.'
            Assert-True ($message -like '*normalized-ownership.csv*') 'Error should identify the common wrong file type.'
        }
    },
    @{
        Name = 'Start-ShareSurferOperatorAssistant writes a reusable first-run plan and command script'
        Body = {
            Import-Module $moduleManifest -Force
            $command = Get-Command -Name Start-ShareSurferOperatorAssistant -Module ShareSurfer -ErrorAction Stop
            Assert-Equal $command.Name 'Start-ShareSurferOperatorAssistant' 'Operator assistant should be exported by the module.'

            $root = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferOperatorAssistant-' + [guid]::NewGuid().ToString('N'))
            $inputRoot = Join-Path $root 'inputs'
            $exportPath = Join-Path $root 'exports\finance-001'
            $dashboardPath = Join-Path $exportPath 'standalone-dashboard'
            $planPath = Join-Path $inputRoot 'operator-assistant.plan.json'
            $rerunPath = Join-Path $inputRoot 'operator-assistant-rerun.ps1'
            $releaseMetadata = Get-Content -LiteralPath (Join-Path $repoRoot 'release-metadata.json') -Raw | ConvertFrom-Json
            $releaseRoot = 'C:\{0}' -f [string]$releaseMetadata.packageName
            $ownerMappingPath = Join-Path $inputRoot 'owner-mapping.csv'
            $ownershipEnrichmentPath = Join-Path $inputRoot 'ownership-enrichment.csv'
            $ownershipContextPath = Join-Path $inputRoot 'ownership_context.csv'
            $ownershipRelationshipPath = Join-Path $inputRoot 'ownership_relationships.csv'
            $ownershipImportManifestPath = Join-Path $inputRoot 'ownership_import_manifest.csv'
            $discountedPrincipalPath = Join-Path $inputRoot 'discounted-principals.csv'

            $summary = Start-ShareSurferOperatorAssistant `
                -ReleaseRoot $releaseRoot `
                -InputRoot $inputRoot `
                -ExportPath $exportPath `
                -StandaloneDashboardPath $dashboardPath `
                -TargetPath '\\files01\Finance' `
                -ObsAttribute 'info' `
                -AdLookupMode DirectoryOnly `
                -ManagerIdentityFormat MailTo `
                -AclExportMode Compact `
                -OwnerMappingPath $ownerMappingPath `
                -OwnershipEnrichmentPath $ownershipEnrichmentPath `
                -OwnershipContextPath $ownershipContextPath `
                -OwnershipRelationshipPath $ownershipRelationshipPath `
                -OwnershipImportManifestPath $ownershipImportManifestPath `
                -DiscountedPrincipalPath $discountedPrincipalPath `
                -PlanPath $planPath `
                -ReusableCommandPath $rerunPath `
                -IncludeFiles `
                -Force

            $plan = Get-Content -LiteralPath $planPath -Raw | ConvertFrom-Json
            $scriptText = Get-Content -LiteralPath $rerunPath -Raw

            Assert-Equal $summary.PlanPath $planPath 'Assistant summary should report the plan path.'
            Assert-Equal $summary.ReusableCommandPath $rerunPath 'Assistant summary should report the reusable command path.'
            Assert-Equal $plan.version 1 'Assistant plan should have a stable version.'
            Assert-Equal $plan.releaseRoot $releaseRoot 'Assistant plan should preserve release root.'
            Assert-Equal $plan.exportPath $exportPath 'Assistant plan should preserve export path.'
            Assert-Equal $plan.obsAttribute 'info' 'Assistant plan should preserve OBS attribute.'
            Assert-Equal $plan.adLookupMode 'DirectoryOnly' 'Assistant plan should preserve AD lookup mode.'
            Assert-Equal $plan.aclExportMode 'Compact' 'Assistant plan should preserve ACL export mode.'
            Assert-Equal $plan.includeSharePermissionDiagnostics $true 'Assistant plan should enable share-permission diagnostics by default.'
            Assert-Equal $plan.optionalInputs.ownerMappingPath $ownerMappingPath 'Assistant plan should preserve owner mapping path.'
            Assert-Equal $plan.optionalInputs.ownershipEnrichmentPath $ownershipEnrichmentPath 'Assistant plan should preserve ownership enrichment path.'
            Assert-Equal $plan.optionalInputs.ownershipContextPath $ownershipContextPath 'Assistant plan should preserve ownership context path.'
            Assert-Equal $plan.optionalInputs.ownershipRelationshipPath $ownershipRelationshipPath 'Assistant plan should preserve ownership relationship path.'
            Assert-Equal $plan.optionalInputs.ownershipImportManifestPath $ownershipImportManifestPath 'Assistant plan should preserve ownership import manifest path.'
            Assert-True ([string]$plan.commands.sharePermissionDiagnostics -like '*Invoke-ShareSurferSharePermissionDiagnostic*') 'Assistant plan should include a share-permission diagnostic command preview.'
            Assert-True ([string]$plan.commands.sharePermissionDiagnostics -like '*share-permission-diagnostics*') 'Diagnostic command preview should show the diagnostic output folder.'
            Assert-True ([string]$plan.commands.portProtocolAssessment -like '*Invoke-ShareSurferPortProtocolAssessment*') 'Assistant plan should include a port/protocol assessment command preview.'
            Assert-True ([string]$plan.commands.portProtocolAssessment -like '*-OutputPath*') 'Port/protocol assessment command preview should write beside the export.'
            Assert-True ([string]$plan.commands.scan -like '*Invoke-ShareSurferScan*') 'Assistant plan should include a scan command preview.'
            Assert-True ([string]$plan.commands.scan -like '*-AclExportMode*Compact*') 'Scan command preview should include ACL export mode.'
            Assert-True ([string]$plan.commands.scan -like '*-OwnershipEnrichmentPath*') 'Scan command preview should show ownership enrichment when provided.'
            Assert-True ([string]$plan.commands.scan -like '*-OwnershipContextPath*') 'Scan command preview should show ownership context when provided.'
            Assert-True ([string]$plan.commands.scan -like '*-OwnershipRelationshipPath*') 'Scan command preview should show ownership relationships when provided.'
            Assert-True ([string]$plan.commands.scan -like '*-OwnershipImportManifestPath*') 'Scan command preview should show ownership import manifest when provided.'
            Assert-True ([string]$plan.commands.validate -like '*Test-ShareSurferExport*') 'Assistant plan should include export validation command preview.'
            Assert-True ([string]$plan.commands.packageStandaloneDashboard -like '*New-ShareSurferStandaloneDashboard.ps1*') 'Assistant plan should include standalone dashboard packaging command preview.'
            Assert-True ([string]$plan.commands.optionalInputBehavior -like '*rerun script is authoritative*') 'Assistant plan should explain that optional CSV path handling is conditional in the rerun script.'
            Assert-True (@($plan.stopGates | Where-Object { [string]$_ -like '*evidence_confidence.csv*' }).Count -eq 1) 'Assistant plan should include evidence confidence stop gate guidance.'
            Assert-True (@($plan.stopGates | Where-Object { [string]$_ -like '*share-permission-diagnostics*' }).Count -eq 1) 'Assistant plan should include share-permission diagnostic stop gate guidance.'
            Assert-True ($scriptText -like '*Import-Module $modulePath -Force*') 'Reusable script should import the module.'
            Assert-True ($scriptText -like '*$sharePermissionDiagnosticPath = Join-Path $exportPath*share-permission-diagnostics*') 'Reusable script should define the share-permission diagnostic output path.'
            Assert-True ($scriptText -like '*$aclExportMode = ''Compact''*') 'Reusable script should record the ACL export mode.'
            Assert-True ($scriptText -like '*Invoke-ShareSurferSharePermissionDiagnostic -TargetPath $targetPaths -OutputPath $sharePermissionDiagnosticPath -Force*') 'Reusable script should run intensive share-permission diagnostics before scanning.'
            Assert-True ($scriptText -like '*Invoke-ShareSurferPortProtocolAssessment -TargetPath $targetPaths -OutputPath $exportPath -Force*') 'Reusable script should write port/protocol assessment CSVs beside the export before dashboard packaging.'
            Assert-True ($scriptText.IndexOf('Invoke-ShareSurferSharePermissionDiagnostic') -lt $scriptText.IndexOf('Invoke-ShareSurferScan @scanParams')) 'Reusable script should run share-permission diagnostics before the scan.'
            Assert-True ($scriptText.IndexOf('Invoke-ShareSurferPortProtocolAssessment') -lt $scriptText.IndexOf('& $standaloneDashboardScript')) 'Reusable script should run port/protocol assessment before dashboard packaging.'
            Assert-True ($scriptText -like '*Invoke-ShareSurferScan @scanParams*') 'Reusable script should run the scan through a splatted command.'
            Assert-True ($scriptText -like '*AclExportMode = $aclExportMode*') 'Reusable script should pass ACL export mode into Invoke-ShareSurferScan.'
            Assert-True ($scriptText -like '*$validation = Test-ShareSurferExport -ExportPath $exportPath*') 'Reusable script should validate the export.'
            Assert-True ($scriptText -like '*ShareSurfer export validation failed*') 'Reusable script should stop when export validation fails.'
            Assert-True ($scriptText -like '*New-ShareSurferStandaloneDashboard.ps1*') 'Reusable script should package the standalone dashboard.'
            Assert-True ($scriptText -like '*Test-Path -LiteralPath $ownerMappingPath*') 'Reusable script should only pass optional owner mapping when the file exists.'
            Assert-True ($scriptText -like '*Test-Path -LiteralPath $ownershipEnrichmentPath*') 'Reusable script should only pass optional ownership enrichment when the file exists.'
            Assert-True ($scriptText -like '*Test-Path -LiteralPath $ownershipContextPath*') 'Reusable script should only pass optional ownership context when the file exists.'
            Assert-True ($scriptText -like '*Test-Path -LiteralPath $ownershipRelationshipPath*') 'Reusable script should only pass optional ownership relationships when the file exists.'
            Assert-True ($scriptText -like '*Test-Path -LiteralPath $ownershipImportManifestPath*') 'Reusable script should only pass optional ownership import manifest when the file exists.'
            Assert-True ($scriptText -like '*Test-Path -LiteralPath $discountedPrincipalPath*') 'Reusable script should only pass optional discounted principals when the file exists.'

            $threw = $false
            try {
                Start-ShareSurferOperatorAssistant -ReleaseRoot $releaseRoot -InputRoot $inputRoot -TargetPath '\\files01\Finance' -PlanPath $planPath -ReusableCommandPath $rerunPath | Out-Null
            }
            catch {
                $threw = $true
            }
            Assert-True $threw 'Assistant should not overwrite existing plan or rerun script without -Force.'

            $samePathThrew = $false
            try {
                $sameOutputPath = Join-Path $inputRoot 'same-output.ps1'
                Start-ShareSurferOperatorAssistant -ReleaseRoot $releaseRoot -InputRoot $inputRoot -TargetPath '\\files01\Finance' -PlanPath $sameOutputPath -ReusableCommandPath $sameOutputPath -Force | Out-Null
            }
            catch {
                $samePathThrew = ($_.Exception.Message -like '*must be different files*')
            }
            Assert-True $samePathThrew 'Assistant should reject identical plan and rerun paths before writing.'

            $invalidExportPath = Join-Path $root 'invalid-export'
            New-Item -ItemType Directory -Force -Path $invalidExportPath | Out-Null
            Set-Content -LiteralPath (Join-Path $invalidExportPath 'shares.csv') -Value 'NotAValidHeader' -Encoding UTF8
            $validationGuardScriptPath = Join-Path $root 'operator-assistant-validation-guard.ps1'
            $packageSentinelPath = Join-Path $root 'dashboard-package-attempted.txt'
            $invalidExportPathLiteral = "'" + ($invalidExportPath -replace "'", "''") + "'"
            $packageSentinelPathLiteral = "'" + ($packageSentinelPath -replace "'", "''") + "'"
            $moduleManifestLiteral = "'" + ($moduleManifest -replace "'", "''") + "'"
            $validationGuardScript = $scriptText `
                -replace '\$exportPath = .+', ('$exportPath = {0}' -f $invalidExportPathLiteral) `
                -replace '\$modulePath = Join-Path \$releaseRoot .+', ('$modulePath = {0}' -f $moduleManifestLiteral) `
                -replace '\$standaloneDashboardScript = Join-Path \$releaseRoot .+', '$standaloneDashboardScript = ''unused-by-validation-guard-test''' `
                -replace [regex]::Escape('Invoke-ShareSurferSharePermissionDiagnostic -TargetPath $targetPaths -OutputPath $sharePermissionDiagnosticPath -Force'), '# Diagnostics intentionally skipped by validation guard regression test.' `
                -replace [regex]::Escape('Invoke-ShareSurferPortProtocolAssessment -TargetPath $targetPaths -OutputPath $exportPath -Force'), '# Port/protocol assessment intentionally skipped by validation guard regression test.' `
                -replace [regex]::Escape('Invoke-ShareSurferScan @scanParams'), '# Scan intentionally skipped by validation guard regression test.' `
                -replace [regex]::Escape('& $standaloneDashboardScript -ExportPath $exportPath -OutputPath $standaloneDashboardPath -Force'), ('Set-Content -LiteralPath {0} -Value ''packaged'' -Encoding UTF8' -f $packageSentinelPathLiteral)
            Set-Content -LiteralPath $validationGuardScriptPath -Value $validationGuardScript -Encoding UTF8

            $validationThrew = $false
            try {
                & $validationGuardScriptPath
            }
            catch {
                $validationThrew = ($_.Exception.Message -like '*ShareSurfer export validation failed*')
            }
            Assert-True $validationThrew 'Reusable script should throw before dashboard packaging when export validation fails.'
            Assert-True (-not (Test-Path -LiteralPath $packageSentinelPath)) 'Reusable script should not package a dashboard from an invalid export.'
        }
    },
    @{
        Name = 'Start-ShareSurferOperatorAssistant can add post-scan owner mapping draft creation'
        Body = {
            Import-Module $moduleManifest -Force

            $root = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferOperatorAssistantOwnerDraft-' + [guid]::NewGuid().ToString('N'))
            $inputRoot = Join-Path $root 'inputs'
            $exportPath = Join-Path $root 'exports\finance-001'
            $dashboardPath = Join-Path $exportPath 'standalone-dashboard'
            $planPath = Join-Path $inputRoot 'operator-assistant.plan.json'
            $rerunPath = Join-Path $inputRoot 'operator-assistant-rerun.ps1'
            $draftPath = Join-Path $inputRoot 'owner-mapping-draft.csv'
            $draftRerunPath = Join-Path $inputRoot 'owner-mapping-draft-rerun.ps1'
            $releaseMetadata = Get-Content -LiteralPath (Join-Path $repoRoot 'release-metadata.json') -Raw | ConvertFrom-Json
            $releaseRoot = 'C:\{0}' -f [string]$releaseMetadata.packageName

            $summary = Start-ShareSurferOperatorAssistant `
                -ReleaseRoot $releaseRoot `
                -InputRoot $inputRoot `
                -ExportPath $exportPath `
                -StandaloneDashboardPath $dashboardPath `
                -TargetPath '\\files01\Finance' `
                -ObsAttribute 'info' `
                -AdLookupMode DirectoryOnly `
                -PlanPath $planPath `
                -ReusableCommandPath $rerunPath `
                -CreateOwnerMappingDraftAfterScan `
                -OwnerMappingDraftPath $draftPath `
                -OwnerMappingDraftReusableCommandPath $draftRerunPath `
                -Force

            $plan = Get-Content -LiteralPath $planPath -Raw | ConvertFrom-Json
            $scriptText = Get-Content -LiteralPath $rerunPath -Raw

            Assert-Equal $summary.CreateOwnerMappingDraftAfterScan $true 'Assistant summary should report post-scan owner mapping draft creation.'
            Assert-Equal $summary.OwnerMappingDraftPath $draftPath 'Assistant summary should preserve requested owner mapping draft path.'
            Assert-Equal $summary.OwnerMappingDraftReusableCommandPath $draftRerunPath 'Assistant summary should preserve requested owner mapping draft rerun path.'
            Assert-Equal $plan.generatedFiles.ownerMappingDraftPath $draftPath 'Assistant plan should record owner mapping draft output path.'
            Assert-Equal $plan.generatedFiles.ownerMappingDraftReusableCommandPath $draftRerunPath 'Assistant plan should record owner mapping draft reusable command path.'
            Assert-True ([string]$plan.commands.ownerMappingDraft -like '*New-ShareSurferOwnerMappingDraft*') 'Assistant plan should include an owner mapping draft command preview.'
            Assert-True ([string]$plan.commands.optionalInputBehavior -like '*owner-mapping draft*') 'Assistant plan should explain post-scan owner mapping draft behavior.'
            Assert-True ($scriptText -like '*$createOwnerMappingDraftAfterScan = $true*') 'Reusable script should record owner mapping draft creation state.'
            Assert-True ($scriptText -like '*Owner mapping CSV was not available for this scan*') 'Reusable script should tell operators why a draft is being created.'
            Assert-True ($scriptText -like '*New-ShareSurferOwnerMappingDraft -ExportPath $exportPath*') 'Reusable script should create the owner mapping draft after validation.'
            Assert-True ($scriptText -like '*Fill Owner and BusinessUnit*') 'Reusable script should tell operators how to complete the draft before rerun.'
            Assert-True ($scriptText.IndexOf('Test-ShareSurferExport -ExportPath $exportPath') -lt $scriptText.IndexOf('New-ShareSurferOwnerMappingDraft -ExportPath $exportPath')) 'Reusable script should create the draft only after export validation.'
        }
    },
    @{
        Name = 'Start-ShareSurferStartup writes and replays startup config'
        Body = {
            Import-Module $moduleManifest -Force
            $command = Get-Command -Name Start-ShareSurferStartup -Module ShareSurfer -ErrorAction Stop
            Assert-Equal $command.Name 'Start-ShareSurferStartup' 'Startup command should be exported by the module.'
            Assert-True $command.Parameters.ContainsKey('DisableOptionalInputDiscovery') 'Startup command should support exact replay without implicit ownership discovery.'
            Assert-True $command.Parameters.ContainsKey('CreateOwnerMappingDraftAfterScan') 'Startup command should support replaying queued owner-mapping draft creation.'
            Assert-True $command.Parameters.ContainsKey('OwnerMappingDraftPath') 'Startup command should accept the reviewed owner-mapping draft path.'
            Assert-True $command.Parameters.ContainsKey('OwnerMappingDraftReusableCommandPath') 'Startup command should accept the reviewed owner-mapping draft rerun path.'

            $root = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferStartup-' + [guid]::NewGuid().ToString('N'))
            $inputRoot = Join-Path $root 'inputs'
            $exportPath = Join-Path $root 'exports\finance-001'
            $dashboardPath = Join-Path $exportPath 'standalone-dashboard'
            $configPath = Join-Path $inputRoot 'sharesurfer-startup.config.json'
            $planPath = Join-Path $inputRoot 'operator-assistant.plan.json'
            $rerunPath = Join-Path $inputRoot 'operator-assistant-rerun.ps1'
            $handoffPath = Join-Path $root 'handoff\finance-001.zip'
            $releaseMetadata = Get-Content -LiteralPath (Join-Path $repoRoot 'release-metadata.json') -Raw | ConvertFrom-Json
            $releaseRoot = 'C:\{0}' -f [string]$releaseMetadata.packageName
            $ownerMappingPath = Join-Path $inputRoot 'owner-mapping.csv'
            $ownershipEnrichmentPath = Join-Path $inputRoot 'ownership-enrichment.csv'
            $ownershipContextPath = Join-Path $inputRoot 'ownership_context.csv'
            $ownershipRelationshipPath = Join-Path $inputRoot 'ownership_relationships.csv'
            $ownershipImportManifestPath = Join-Path $inputRoot 'ownership_import_manifest.csv'
            $discountedPrincipalPath = Join-Path $inputRoot 'discounted-principals.csv'

            $summary = Start-ShareSurferStartup `
                -EnvironmentMode Nonpermissive `
                -ReleaseRoot $releaseRoot `
                -InputRoot $inputRoot `
                -ExportPath $exportPath `
                -StandaloneDashboardPath $dashboardPath `
                -TargetPath '\\files01\Finance' `
                -ObsAttribute 'info' `
                -AdLookupMode DirectoryOnly `
                -ManagerIdentityFormat MailTo `
                -OwnerMappingPath $ownerMappingPath `
                -OwnershipEnrichmentPath $ownershipEnrichmentPath `
                -OwnershipContextPath $ownershipContextPath `
                -OwnershipRelationshipPath $ownershipRelationshipPath `
                -OwnershipImportManifestPath $ownershipImportManifestPath `
                -DiscountedPrincipalPath $discountedPrincipalPath `
                -HandoffPath $handoffPath `
                -SaveConfigPath $configPath `
                -PlanPath $planPath `
                -ReusableCommandPath $rerunPath `
                -IncludeFiles `
                -SkipUnblock `
                -Force

            $config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
            $operatorPlan = Get-Content -LiteralPath $planPath -Raw | ConvertFrom-Json
            $scriptText = Get-Content -LiteralPath $rerunPath -Raw

            Assert-Equal $summary.StartupConfigPath $configPath 'Startup summary should report config path.'
            Assert-Equal $summary.EnvironmentMode 'Nonpermissive' 'Startup summary should preserve selected environment mode.'
            Assert-Equal $summary.UnblockStatus 'Skipped' 'Startup summary should report skipped unblock when requested.'
            Assert-Equal $summary.UnblockZoneIdentifierRemovedCount 0 'Skipped startup unblock should report zero cleared downloaded-file markers.'
            Assert-Equal $summary.PostStartupReviewShown $false 'Non-interactive startup should not show the post-startup review prompt.'
            Assert-Equal $summary.PostStartupRerunLaunched $false 'Non-interactive startup should not launch the rerun script.'
            Assert-Equal $summary.OperatorPlanPath $planPath 'Startup summary should report operator plan path.'
            Assert-Equal $summary.OperatorReusableCommandPath $rerunPath 'Startup summary should report operator rerun path.'
            Assert-Equal $summary.AclExportMode 'Compact' 'Startup summary should preserve ACL export mode.'
            Assert-Equal $config.version 1 'Startup config should have a stable version.'
            Assert-Equal $config.environmentMode 'Nonpermissive' 'Startup config should preserve environment mode.'
            Assert-Equal $config.releaseRoot $releaseRoot 'Startup config should preserve release root.'
            Assert-Equal $config.obsAttribute 'info' 'Startup config should preserve OBS attribute.'
            Assert-Equal $config.aclExportMode 'Compact' 'Startup config should preserve ACL export mode.'
            Assert-Equal $config.includeSharePermissionDiagnostics $true 'Startup config should preserve the share-permission diagnostic choice.'
            Assert-Equal $config.optionalInputs.ownerMappingPath $ownerMappingPath 'Startup config should preserve owner mapping path.'
            Assert-Equal $config.optionalInputs.ownershipEnrichmentPath $ownershipEnrichmentPath 'Startup config should preserve ownership enrichment path.'
            Assert-Equal $config.optionalInputs.ownershipContextPath $ownershipContextPath 'Startup config should preserve ownership context path.'
            Assert-Equal $config.optionalInputs.ownershipRelationshipPath $ownershipRelationshipPath 'Startup config should preserve ownership relationship path.'
            Assert-Equal $config.optionalInputs.ownershipImportManifestPath $ownershipImportManifestPath 'Startup config should preserve ownership import manifest path.'
            Assert-Equal $config.optionalInputs.discountedPrincipalPath $discountedPrincipalPath 'Startup config should preserve discounted principals path.'
            Assert-Equal $config.ownershipSetup.OwnerMappingPath $ownerMappingPath 'Startup config should record ownership setup owner mapping path.'
            Assert-Equal $config.ownershipSetup.OwnershipEnrichmentPath $ownershipEnrichmentPath 'Startup config should record ownership setup enrichment path.'
            Assert-Equal $config.nonpermissive.handoffPath $handoffPath 'Startup config should preserve nonpermissive handoff path.'
            Assert-Equal $config.generatedFiles.operatorPlanPath $planPath 'Startup config should record generated operator plan path.'
            Assert-Equal $config.generatedFiles.operatorReusableCommandPath $rerunPath 'Startup config should record generated rerun path.'
            Assert-True ([string]$config.commands.startupReplay -like '*Start-ShareSurferStartup*') 'Startup config should include a replay command.'
            Assert-True ([string]$config.commands.startupScriptReplay -like '*Start-ShareSurfer.ps1*') 'Startup config should include release-root script replay command.'
            Assert-True (@($config.stopGates | Where-Object { [string]$_ -like '*ObsAttribute*' }).Count -eq 1) 'Startup config should include OBS stop gate guidance.'
            Assert-True (@($config.stopGates | Where-Object { [string]$_ -like '*share-permission-diagnostics*' }).Count -eq 1) 'Startup config should include share-permission diagnostic stop gate guidance.'
            Assert-Equal $operatorPlan.obsAttribute 'info' 'Startup should delegate selected OBS attribute into operator assistant plan.'
            Assert-Equal $operatorPlan.aclExportMode 'Compact' 'Startup should delegate selected ACL export mode into operator assistant plan.'
            Assert-Equal $operatorPlan.includeSharePermissionDiagnostics $true 'Startup should delegate share-permission diagnostic choice into operator assistant plan.'
            Assert-Equal $operatorPlan.optionalInputs.ownershipContextPath $ownershipContextPath 'Startup should delegate ownership context path into operator assistant plan.'
            Assert-Equal $operatorPlan.optionalInputs.ownershipRelationshipPath $ownershipRelationshipPath 'Startup should delegate ownership relationship path into operator assistant plan.'
            Assert-Equal $operatorPlan.optionalInputs.ownershipImportManifestPath $ownershipImportManifestPath 'Startup should delegate ownership import manifest path into operator assistant plan.'
            Assert-Equal $summary.IncludeSharePermissionDiagnostics $true 'Startup summary should report share-permission diagnostic choice.'
            Assert-Equal $summary.OwnershipContextPath $ownershipContextPath 'Startup summary should report ownership context path.'
            Assert-Equal $summary.OwnershipRelationshipPath $ownershipRelationshipPath 'Startup summary should report ownership relationship path.'
            Assert-Equal $summary.OwnershipImportManifestPath $ownershipImportManifestPath 'Startup summary should report ownership import manifest path.'
            Assert-True ($scriptText -like '*Invoke-ShareSurferSharePermissionDiagnostic*') 'Startup-generated operator rerun script should run share-permission diagnostics by default.'
            Assert-True ($scriptText -like '*Invoke-ShareSurferPortProtocolAssessment -TargetPath $targetPaths -OutputPath $exportPath -Force*') 'Startup-generated operator rerun script should generate port/protocol readiness CSVs by default.'
            Assert-True ($scriptText -like '*AclExportMode = $aclExportMode*') 'Startup-generated operator rerun script should pass ACL export mode to the scan.'
            Assert-True ($scriptText -like '*Invoke-ShareSurferScan @scanParams*') 'Startup-generated operator rerun script should run the scan.'
            Assert-True ($scriptText -like '*Test-ShareSurferExport -ExportPath $exportPath*') 'Startup-generated operator rerun script should validate the export.'

            $replaySummary = Start-ShareSurferStartup -ConfigPath $configPath -Force
            Assert-Equal $replaySummary.EnvironmentMode 'Nonpermissive' 'Replay should load environment mode from startup config.'
            Assert-Equal $replaySummary.ExportPath $exportPath 'Replay should load export path from startup config.'
            Assert-Equal $replaySummary.TargetPath[0] '\\files01\Finance' 'Replay should load target path from startup config.'
            Assert-Equal $replaySummary.AclExportMode 'Compact' 'Replay should load ACL export mode from startup config.'
            Assert-Equal $replaySummary.IncludeSharePermissionDiagnostics $true 'Replay should load share-permission diagnostic choice from startup config.'
            Assert-Equal $replaySummary.SkipUnblock $true 'Replay should preserve skipped unblock setting from startup config.'
            Assert-Equal $replaySummary.OwnershipContextPath $ownershipContextPath 'Replay should load ownership context path from startup config.'
            Assert-Equal $replaySummary.OwnershipRelationshipPath $ownershipRelationshipPath 'Replay should load ownership relationship path from startup config.'
            Assert-Equal $replaySummary.OwnershipImportManifestPath $ownershipImportManifestPath 'Replay should load ownership import manifest path from startup config.'
            Assert-Equal $replaySummary.UnblockZoneIdentifierRemovedCount 0 'Replay with skipped unblock should report zero cleared downloaded-file markers.'
            Assert-Equal $replaySummary.PostStartupReviewShown $false 'Config replay should not show the post-startup review prompt unless interactive.'
            Assert-Equal $replaySummary.PostStartupRerunLaunched $false 'Config replay should not launch the rerun script unless interactive.'
            Assert-Equal $replaySummary.HandoffPath $handoffPath 'Replay should load nonpermissive handoff path from startup config.'

            $overwriteThrew = $false
            try {
                Start-ShareSurferStartup `
                    -EnvironmentMode Permissive `
                    -ReleaseRoot $releaseRoot `
                    -InputRoot $inputRoot `
                    -ExportPath $exportPath `
                    -TargetPath '\\files01\Finance' `
                    -SaveConfigPath $configPath `
                    -PlanPath $planPath `
                    -ReusableCommandPath $rerunPath `
                    -SkipUnblock | Out-Null
            }
            catch {
                $overwriteThrew = ($_.Exception.Message -like '*startup config already exists*')
            }
            Assert-True $overwriteThrew 'Startup command should not overwrite a different existing startup config without -Force.'
        }
    },
    @{
        Name = 'Start-ShareSurferStartup discovers conventional optional input CSVs'
        Body = {
            Import-Module $moduleManifest -Force
            $root = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferStartupDiscovery-' + [guid]::NewGuid().ToString('N'))
            $inputRoot = Join-Path $root 'inputs'
            $exportPath = Join-Path $root 'exports\finance-001'
            $configPath = Join-Path $inputRoot 'sharesurfer-startup.config.json'
            $planPath = Join-Path $inputRoot 'operator-assistant.plan.json'
            $rerunPath = Join-Path $inputRoot 'operator-assistant-rerun.ps1'
            $releaseMetadata = Get-Content -LiteralPath (Join-Path $repoRoot 'release-metadata.json') -Raw | ConvertFrom-Json
            $releaseRoot = 'C:\{0}' -f [string]$releaseMetadata.packageName
            $ownerMappingPath = Join-Path $inputRoot 'owner-mapping.csv'
            $ownershipEnrichmentPath = Join-Path $inputRoot 'ownership-enrichment.csv'
            $ownershipContextPath = Join-Path $inputRoot 'ownership_context.csv'
            $ownershipRelationshipPath = Join-Path $inputRoot 'ownership_relationships.csv'
            $ownershipImportManifestPath = Join-Path $inputRoot 'ownership_import_manifest.csv'
            $discountedPrincipalPath = Join-Path $inputRoot 'discounted-principals.csv'

            New-Item -ItemType Directory -Path $inputRoot -Force | Out-Null
            Set-Content -LiteralPath $ownerMappingPath -Value 'Pattern,Owner,BusinessUnit,Source,Confidence,Notes' -Encoding UTF8
            Set-Content -LiteralPath $ownershipContextPath -Value 'ContextId,ContextType,ContextKey,DisplayName,ObsPath,Owner,BusinessUnit,Source,Notes' -Encoding UTF8
            Set-Content -LiteralPath $ownershipRelationshipPath -Value 'FromContextId,ToContextId,RelationshipType,Confidence,Source,Notes' -Encoding UTF8
            Set-Content -LiteralPath $ownershipImportManifestPath -Value 'SourcePath,SourceKind,RowCount,OutputPath,DefinitionPath,ReusableCommandPath,Notes' -Encoding UTF8
            Set-Content -LiteralPath $discountedPrincipalPath -Value 'Principal,Reason,Scope,Notes' -Encoding UTF8

            $summary = Start-ShareSurferStartup `
                -EnvironmentMode Permissive `
                -ReleaseRoot $releaseRoot `
                -InputRoot $inputRoot `
                -ExportPath $exportPath `
                -TargetPath '\\files01\Finance' `
                -SaveConfigPath $configPath `
                -PlanPath $planPath `
                -ReusableCommandPath $rerunPath `
                -SkipUnblock `
                -Force

            $config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
            $operatorPlan = Get-Content -LiteralPath $planPath -Raw | ConvertFrom-Json
            $scriptText = Get-Content -LiteralPath $rerunPath -Raw

            Assert-Equal $summary.OptionalInputDiscovery.ownerMapping.status 'FoundInInputRoot' 'Startup summary should mark owner mapping as discovered from inputs.'
            Assert-Equal $summary.OptionalInputDiscovery.ownershipEnrichment.status 'NotFoundSkipped' 'Startup summary should mark missing ownership enrichment as skipped.'
            Assert-Equal $summary.OptionalInputDiscovery.ownershipContext.status 'FoundInInputRoot' 'Startup summary should mark ownership context as discovered from inputs.'
            Assert-Equal $summary.OptionalInputDiscovery.ownershipRelationships.status 'FoundInInputRoot' 'Startup summary should mark ownership relationships as discovered from inputs.'
            Assert-Equal $summary.OptionalInputDiscovery.ownershipImportManifest.status 'FoundInInputRoot' 'Startup summary should mark ownership import manifest as discovered from inputs.'
            Assert-Equal $summary.OptionalInputDiscovery.discountedPrincipals.status 'FoundInInputRoot' 'Startup summary should mark discounted principals as discovered from inputs.'
            Assert-Equal $config.optionalInputs.ownerMappingPath $ownerMappingPath 'Startup config should auto-use conventional owner mapping path when present.'
            Assert-Equal $config.optionalInputs.ownershipEnrichmentPath '' 'Startup config should leave missing conventional ownership enrichment blank.'
            Assert-Equal $config.optionalInputs.ownershipContextPath $ownershipContextPath 'Startup config should auto-use conventional ownership context path when present.'
            Assert-Equal $config.optionalInputs.ownershipRelationshipPath $ownershipRelationshipPath 'Startup config should auto-use conventional ownership relationship path when present.'
            Assert-Equal $config.optionalInputs.ownershipImportManifestPath $ownershipImportManifestPath 'Startup config should auto-use conventional ownership import manifest path when present.'
            Assert-Equal $config.optionalInputs.discountedPrincipalPath $discountedPrincipalPath 'Startup config should auto-use conventional discounted principals path when present.'
            Assert-Equal $config.optionalInputDiscovery.ownerMapping.status 'FoundInInputRoot' 'Startup config should include durable optional input discovery detail.'
            Assert-Equal $config.optionalInputDiscovery.ownershipContext.status 'FoundInInputRoot' 'Startup config should include ownership context discovery detail.'
            Assert-Equal $operatorPlan.optionalInputs.ownerMappingPath $ownerMappingPath 'Operator plan should receive discovered owner mapping path.'
            Assert-Equal $operatorPlan.optionalInputs.ownershipContextPath $ownershipContextPath 'Operator plan should receive discovered ownership context path.'
            Assert-True ($scriptText -like ('*{0}*' -f [string]$ownerMappingPath)) 'Reusable script should include the discovered owner mapping path.'
            Assert-True ($scriptText -like ('*{0}*' -f [string]$ownershipContextPath)) 'Reusable script should include the discovered ownership context path.'

            Set-Content -LiteralPath $ownershipEnrichmentPath -Value 'EmployeeId,ObsPath,Source' -Encoding UTF8
            $replaySummary = Start-ShareSurferStartup -ConfigPath $configPath -Force
            $replayedConfig = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
            Assert-Equal $replaySummary.OptionalInputDiscovery.ownershipEnrichment.status 'SkippedFoundInput' 'Config replay should preserve a previously blank optional input even if a conventional file is added later.'
            Assert-Equal $replayedConfig.optionalInputs.ownershipEnrichmentPath '' 'Config replay should not silently add a new optional input that was absent from the saved config.'
        }
    },
    @{
        Name = 'Optional input prompts only treat SKIP as skip'
        Body = {
            Import-Module $moduleManifest -Force
            $module = Get-Module ShareSurfer
            $root = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferOptionalPrompt-' + [guid]::NewGuid().ToString('N'))
            $inputRoot = Join-Path $root 'inputs'
            New-Item -ItemType Directory -Path $inputRoot -Force | Out-Null
            $expectedOwnerMappingPath = Join-Path $inputRoot 'owner-mapping.csv'
            Set-Content -LiteralPath $expectedOwnerMappingPath -Value 'Pattern,Owner,BusinessUnit,Source,Confidence,Notes' -Encoding UTF8

            $script:shareSurferOptionalPromptAnswers = New-Object 'System.Collections.Generic.Queue[string]'
            $script:shareSurferOptionalPromptAnswers.Enqueue('no')
            $script:shareSurferOptionalPromptAnswers.Enqueue('SKIP')
            $script:shareSurferOptionalPromptAnswers.Enqueue('')
            function global:Read-Host {
                param([string] $Prompt)
                $script:shareSurferOptionalPromptAnswers.Dequeue()
            }

            try {
                $answerNo = & $module {
                    param($InputRoot)
                    Read-ShareSurferOptionalInputPath -Prompt 'Owner mapping CSV path' -InputRoot $InputRoot -FileName 'owner-mapping.csv'
                } $inputRoot
                $answerSkip = & $module {
                    param($InputRoot)
                    Read-ShareSurferOptionalInputPath -Prompt 'Owner mapping CSV path' -InputRoot $InputRoot -FileName 'owner-mapping.csv'
                } $inputRoot
                $answerEnter = & $module {
                    param($InputRoot)
                    Read-ShareSurferOptionalInputPath -Prompt 'Owner mapping CSV path' -InputRoot $InputRoot -FileName 'owner-mapping.csv'
                } $inputRoot

                Assert-Equal $answerNo.Action 'Accept' 'Optional path prompt should use the shared return-based result contract.'
                Assert-Equal $answerNo.Value 'no' 'Typing no should be preserved as operator input instead of silently skipping a found optional file.'
                Assert-Equal $answerSkip.Value '' 'Typing SKIP should explicitly skip a found optional file.'
                Assert-Equal $answerEnter.Value $expectedOwnerMappingPath 'Pressing Enter should use a found conventional optional file.'
            }
            finally {
                Remove-Item -Path function:\Read-Host -ErrorAction SilentlyContinue
                Remove-Variable -Name shareSurferOptionalPromptAnswers -Scope Script -ErrorAction SilentlyContinue
            }
        }
    },
    @{
        Name = 'Start-ShareSurferStartup ownership setup can defer enrichment and queue owner mapping draft'
        Body = {
            Import-Module $moduleManifest -Force
            $module = Get-Module ShareSurfer
            $root = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferStartupOwnershipSetup-' + [guid]::NewGuid().ToString('N'))
            $inputRoot = Join-Path $root 'inputs'

            $script:shareSurferOwnershipSetupAnswers = New-Object 'System.Collections.Generic.Queue[string]'
            $script:shareSurferOwnershipSetupAnswers.Enqueue('N')
            $script:shareSurferOwnershipSetupAnswers.Enqueue('Y')
            function global:Read-Host {
                param([string] $Prompt)
                if ($script:shareSurferOwnershipSetupAnswers.Count -eq 0) {
                    throw ('Unexpected ownership setup prompt: {0}' -f $Prompt)
                }
                $script:shareSurferOwnershipSetupAnswers.Dequeue()
            }

            try {
                $summary = & $module {
                    param($InputRoot)
                    Invoke-ShareSurferStartupOwnershipSetup -InputRoot $InputRoot -ObsAttribute 'info' -AdLookupMode DirectoryOnly
                } $inputRoot

                Assert-Equal $summary.Skipped $false 'Ownership setup should not be marked skipped when prompts are enabled.'
                Assert-Equal $summary.Cancelled $false 'Completed ownership setup should not be marked cancelled.'
                Assert-Equal $summary.OwnershipEnrichmentOffered $true 'Ownership setup should offer enrichment when ownership-enrichment.csv is missing.'
                Assert-Equal $summary.OwnershipEnrichmentBuilt $false 'Declining enrichment should return to startup without building enrichment.'
                Assert-Equal $summary.OwnerMappingDraftOffered $true 'Ownership setup should offer a post-scan owner mapping draft when owner-mapping.csv is missing.'
                Assert-Equal $summary.CreateOwnerMappingDraftAfterScan $true 'Accepting the draft prompt should queue post-scan draft creation.'
                Assert-Equal $summary.OwnerMappingDraftPath (Join-Path $inputRoot 'owner-mapping-draft.csv') 'Ownership setup should use the conventional owner mapping draft path.'
                Assert-Equal $summary.OwnerMappingDraftReusableCommandPath (Join-Path $inputRoot 'owner-mapping-draft-rerun.ps1') 'Ownership setup should use the conventional owner mapping draft rerun path.'
                Assert-True ([string]$summary.Message -like '*Owner-mapping draft creation*') 'Ownership setup should explain the queued draft behavior.'
                Assert-Equal $script:shareSurferOwnershipSetupAnswers.Count 0 'Ownership setup should consume the expected prompts.'
            }
            finally {
                Remove-Item -Path function:\Read-Host -ErrorAction SilentlyContinue
                Remove-Variable -Name shareSurferOwnershipSetupAnswers -Scope Script -ErrorAction SilentlyContinue
            }
        }
    },
    @{
        Name = 'Start-ShareSurferStartup ownership setup returns cancellation without treating Q as data'
        Body = {
            Import-Module $moduleManifest -Force
            $module = Get-Module ShareSurfer
            $root = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferStartupOwnershipCancel-' + [guid]::NewGuid().ToString('N'))

            $script:shareSurferOwnershipCancelAnswers = New-Object 'System.Collections.Generic.Queue[string]'
            $script:shareSurferOwnershipCancelAnswers.Enqueue('Q')
            function global:Read-Host {
                param([string] $Prompt)
                if ($script:shareSurferOwnershipCancelAnswers.Count -eq 0) { throw ('Unexpected ownership cancellation prompt: {0}' -f $Prompt) }
                $script:shareSurferOwnershipCancelAnswers.Dequeue()
            }

            try {
                $summary = & $module {
                    param($InputRoot)
                    Invoke-ShareSurferStartupOwnershipSetup -InputRoot $InputRoot -ObsAttribute 'info' -AdLookupMode DirectoryOnly
                } $root
                Assert-True ([bool]$summary.Cancelled) 'Q should return an explicit cancelled ownership result.'
                Assert-True ([string]$summary.Message -like '*cancelled*') 'Cancelled ownership setup should explain that no import started.'
                Assert-True (@($summary.PSObject.Properties.Value | Where-Object { [string]$_ -eq 'Q' }).Count -eq 0) 'Q must not be stored as ownership configuration data.'
                Assert-Equal $script:shareSurferOwnershipCancelAnswers.Count 0 'Ownership cancellation should consume only Q.'
            }
            finally {
                Remove-Item -Path function:\Read-Host -ErrorAction SilentlyContinue
                Remove-Variable -Name shareSurferOwnershipCancelAnswers -Scope Script -ErrorAction SilentlyContinue
                Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    },
    @{
        Name = 'Start-ShareSurferStartup run-now handoff ignores generated script pipeline output'
        Body = {
            Import-Module $moduleManifest -Force
            $module = Get-Module ShareSurfer
            $root = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferStartupRunNow-' + [guid]::NewGuid().ToString('N'))
            New-Item -ItemType Directory -Path $root -Force | Out-Null
            $configPath = Join-Path $root 'sharesurfer-startup.config.json'
            $planPath = Join-Path $root 'operator-assistant.plan.json'
            $rerunPath = Join-Path $root 'operator-assistant-rerun.ps1'
            Set-Content -LiteralPath $configPath -Value '{"version":1}' -Encoding UTF8
            Set-Content -LiteralPath $planPath -Value '{"version":1}' -Encoding UTF8
            Set-Content -LiteralPath $rerunPath -Value @(
                "Write-Host 'Generated rerun script is running.'",
                "[pscustomobject]@{ EmittedBy = 'GeneratedRerunScript'; ScanComplete = `$true }"
            ) -Encoding UTF8

            $global:ShareSurferStartupPromptAnswers = New-Object System.Collections.Queue
            [void]$global:ShareSurferStartupPromptAnswers.Enqueue('N')
            [void]$global:ShareSurferStartupPromptAnswers.Enqueue('Y')
            function global:Read-Host {
                param([string] $Prompt)
                if ($global:ShareSurferStartupPromptAnswers.Count -eq 0) {
                    throw ('Unexpected startup prompt: {0}' -f $Prompt)
                }
                $global:ShareSurferStartupPromptAnswers.Dequeue()
            }

            try {
                $handoffResult = @(& $module {
                    param($StartupConfigPath, $OperatorPlanPath, $ReusableCommandPath)
                    Invoke-ShareSurferStartupPostPlanHandoff -StartupConfigPath $StartupConfigPath -OperatorPlanPath $OperatorPlanPath -ReusableCommandPath $ReusableCommandPath
                } $configPath $planPath $rerunPath)

                Assert-Equal $handoffResult.Count 1 'Run-now handoff should not return generated script pipeline output alongside its summary.'
                Assert-Equal $handoffResult[0].ReviewShown $false 'Run-now handoff should preserve the review-shown flag.'
                Assert-Equal $handoffResult[0].RerunLaunched $true 'Run-now handoff should report that the generated script was launched.'
                Assert-Equal $global:ShareSurferStartupPromptAnswers.Count 0 'Run-now handoff should consume the expected review and run prompts.'
            }
            finally {
                Remove-Item -Path function:\Read-Host -ErrorAction SilentlyContinue
                Remove-Variable -Name ShareSurferStartupPromptAnswers -Scope Global -ErrorAction SilentlyContinue
            }
        }
    },
    @{
        Name = 'New-ShareSurferOwnerMappingDraft creates admin-review rows for unmapped shares'
        Body = {
            Import-Module $moduleManifest -Force
            $exportPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferExport-' + [guid]::NewGuid().ToString('N'))
            $draftPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferOwnerMappingDraft-' + [guid]::NewGuid().ToString('N') + '.csv')
            $commandPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferOwnerMappingDraft-' + [guid]::NewGuid().ToString('N') + '.rerun.ps1')
            $inventory = New-TestInventory
            $inventory.OwnerMappings = @()

            Invoke-ShareSurferScan -InputObject $inventory -OutputPath $exportPath -SkipIdentityEnrichment | Out-Null
            $summary = New-ShareSurferOwnerMappingDraft -ExportPath $exportPath -OutputPath $draftPath -ReusableCommandPath $commandPath
            $rows = Import-Csv -LiteralPath $draftPath
            $commandText = Get-Content -LiteralPath $commandPath -Raw

            Assert-Equal $summary.DraftRowCount 1 'Draft summary should report one unmapped share row.'
            Assert-Equal $rows[0].Pattern '\\files01\Finance\*' 'Draft row should use a boundary-safe wildcard pattern shape.'
            Assert-Equal $rows[0].Source 'OwnerMappingDraft' 'Draft row should identify itself as an owner mapping draft.'
            Assert-Equal $rows[0].Confidence 'NeedsAdminReview' 'Draft row should make clear the owner still needs admin confirmation.'
            Assert-True ([string]$rows[0].Notes -like '*Fill Owner and BusinessUnit*') 'Draft row should tell the admin what must be filled before scanning.'
            Assert-Equal $summary.ReusableCommandPath $commandPath 'Draft summary should report the reusable command file path.'
            Assert-True ([string]$summary.ReusableCommands -like '*New-ShareSurferOwnerMappingDraft*') 'Draft summary should return reusable draft commands.'
            Assert-True ($commandText -like '*owner-mapping.csv*') 'Reusable draft command file should show the completed owner mapping destination.'
            Assert-True ($commandText -like '*Invoke-ShareSurferScan -OwnerMappingPath*') 'Reusable draft command file should explain how to use the completed owner mapping on the next scan.'
        }
    },
    @{
        Name = 'New-ShareSurferOwnerMappingDraft keeps headers when no draft rows are needed'
        Body = {
            Import-Module $moduleManifest -Force
            $exportPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferExport-' + [guid]::NewGuid().ToString('N'))
            $draftPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferOwnerMappingDraftEmpty-' + [guid]::NewGuid().ToString('N') + '.csv')
            Invoke-ShareSurferScan -InputObject (New-TestInventory) -OutputPath $exportPath -SkipIdentityEnrichment | Out-Null

            $summary = New-ShareSurferOwnerMappingDraft -ExportPath $exportPath -OutputPath $draftPath
            $header = Get-Content -LiteralPath $draftPath -TotalCount 1
            $rows = @(Import-Csv -LiteralPath $draftPath)

            Assert-Equal $summary.DraftRowCount 0 'Draft summary should report zero rows when all shares are already mapped.'
            Assert-True ($header -like '*"Pattern"*') 'Empty draft CSV should still include the Pattern header.'
            Assert-True ($header -like '*"Owner"*') 'Empty draft CSV should still include the Owner header.'
            Assert-Equal $rows.Count 0 'Empty draft CSV should import as zero data rows.'
        }
    },
    @{
        Name = 'New-ShareSurferReviewDecisionDraft creates owner and migration decision CSVs'
        Body = {
            Import-Module $moduleManifest -Force
            $exportPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferReviewDraftExport-' + [guid]::NewGuid().ToString('N'))
            $commandPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferReviewDraft-' + [guid]::NewGuid().ToString('N') + '.rerun.ps1')
            Invoke-ShareSurferScan -InputObject (New-TestInventory) -OutputPath $exportPath -SkipIdentityEnrichment | Out-Null

            $summary = New-ShareSurferReviewDecisionDraft -ExportPath $exportPath -ReusableCommandPath $commandPath -Force
            $ownerRows = @(Import-Csv -LiteralPath (Join-Path $exportPath 'owner_review_decisions.csv'))
            $migrationRows = @(Import-Csv -LiteralPath (Join-Path $exportPath 'migration_cluster_decisions.csv'))
            $commandText = Get-Content -LiteralPath $commandPath -Raw

            Assert-Equal $summary.OwnerReviewDecisionCount 1 'Draft summary should report owner review decision row count.'
            Assert-Equal $summary.MigrationClusterDecisionCount 1 'Draft summary should report migration decision row count.'
            Assert-Equal $ownerRows[0].ReviewPacketId 'owner-review-0001' 'Owner decision draft should be keyed by ReviewPacketId.'
            Assert-Equal $ownerRows[0].DecisionStatus 'Pending' 'Blank owner decision drafts should start as pending.'
            Assert-Equal $ownerRows[0].Decision '' 'Draft decision should be blank for reviewer input.'
            Assert-True ($ownerRows[0].AllowedDecisions -like '*ConfirmedOwner*WrongOwner*') 'Draft rows should show allowed decision values.'
            Assert-Equal $migrationRows[0].RelatedAreaId 'related-area-0001' 'Migration decision draft should be keyed by RelatedAreaId.'
            Assert-Equal $migrationRows[0].DecisionStatus 'Pending' 'Blank migration decision drafts should start as pending.'
            Assert-Equal $summary.ReusableCommandPath $commandPath 'Draft summary should report reusable command path.'
            Assert-True ($commandText -like '*New-ShareSurferReviewDecisionDraft*') 'Reusable command file should show how to regenerate the draft.'
            Assert-True ($commandText -like '*Import-ShareSurferReviewDecisions*') 'Reusable command file should show how to import reviewed decisions.'
            Assert-True ($commandText -like '*$importOutputPath*') 'Reusable command file should make the normalized import output path explicit.'
            Assert-True ($commandText -like '*# New-ShareSurferReviewDecisionDraft*') 'Reusable command file should not overwrite reviewer edits when run as-is.'
            Assert-True ($commandText -like '*-OutputPath $importOutputPath -Force*') 'Reusable import command should explicitly overwrite normalized decision outputs.'

            $scopedPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferReviewDraftOwnerOnly-' + [guid]::NewGuid().ToString('N'))
            $scopedCommandPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferReviewDraftOwnerOnly-' + [guid]::NewGuid().ToString('N') + '.rerun.ps1')
            New-ShareSurferReviewDecisionDraft -ExportPath $exportPath -OutputPath $scopedPath -DecisionScope OwnerReview -ReusableCommandPath $scopedCommandPath -Force | Out-Null
            $scopedCommandText = Get-Content -LiteralPath $scopedCommandPath -Raw
            Assert-True (Test-Path -LiteralPath (Join-Path $scopedPath 'owner_review_decisions.csv')) 'Owner-only decision drafts should write owner_review_decisions.csv.'
            Assert-True (-not (Test-Path -LiteralPath (Join-Path $scopedPath 'migration_cluster_decisions.csv'))) 'Owner-only decision drafts should not write migration_cluster_decisions.csv.'
            Assert-True ($scopedCommandText -like '*-DecisionScope OwnerReview*') 'Owner-only reusable commands should preserve the selected decision scope.'
            Assert-True ($scopedCommandText -like '*-OwnerDecisionPath*') 'Owner-only reusable commands should import owner decision CSVs.'
            Assert-True ($scopedCommandText -notlike '*-MigrationDecisionPath*') 'Owner-only reusable commands should not point at a missing migration decision CSV.'
        }
    },
    @{
        Name = 'Import-ShareSurferReviewDecisions normalizes aliases and retains invalid decisions for correction'
        Body = {
            Import-Module $moduleManifest -Force
            $exportPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferReviewImportExport-' + [guid]::NewGuid().ToString('N'))
            $reviewPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferReviewImportSource-' + [guid]::NewGuid().ToString('N'))
            New-Item -ItemType Directory -Path $reviewPath -Force | Out-Null
            Invoke-ShareSurferScan -InputObject (New-TestInventory) -OutputPath $exportPath -SkipIdentityEnrichment | Out-Null
            New-ShareSurferReviewDecisionDraft -ExportPath $exportPath -OutputPath $reviewPath -Force | Out-Null

            $ownerRows = @(Import-Csv -LiteralPath (Join-Path $reviewPath 'owner_review_decisions.csv'))
            $ownerRows[0].Decision = 'confirmed owner'
            $ownerRows[0].ConfirmedOwner = 'Finance Ops Confirmed'
            $ownerRows[0].ConfirmedBusinessUnit = 'Finance Confirmed'
            $ownerRows[0].Reviewer = 'Riley Reviewer'
            $ownerRows[0].ReviewedAt = '2026-06-17T12:00:00Z'
            $ownerRows[0].Notes = 'Owner confirmed from review meeting.'
            $ownerRows[0].NextAction = 'Proceed with migration planning.'
            $ownerRows | Export-Csv -LiteralPath (Join-Path $reviewPath 'owner_review_decisions.csv') -NoTypeInformation -Encoding UTF8

            $migrationRows = @(Import-Csv -LiteralPath (Join-Path $reviewPath 'migration_cluster_decisions.csv'))
            $migrationRows[0].Decision = 'not sure yet'
            $migrationRows[0].DecisionStatus = 'reviewed'
            $migrationRows[0].Reviewer = 'Riley Reviewer'
            $migrationRows | Export-Csv -LiteralPath (Join-Path $reviewPath 'migration_cluster_decisions.csv') -NoTypeInformation -Encoding UTF8

            $summary = Import-ShareSurferReviewDecisions -ExportPath $exportPath -DecisionPath $reviewPath -Force
            $normalizedOwnerRows = @(Import-Csv -LiteralPath (Join-Path $exportPath 'owner_review_decisions.csv'))
            $normalizedMigrationRows = @(Import-Csv -LiteralPath (Join-Path $exportPath 'migration_cluster_decisions.csv'))

            Assert-Equal $summary.OwnerReviewDecisionCount 1 'Import summary should report normalized owner decision rows.'
            Assert-Equal $summary.MigrationClusterDecisionCount 1 'Import summary should report normalized migration decision rows.'
            Assert-Equal $normalizedOwnerRows[0].Decision 'ConfirmedOwner' 'Friendly owner decision aliases should normalize to canonical values.'
            Assert-Equal $normalizedOwnerRows[0].DecisionStatus 'Reviewed' 'Valid nonblank decisions should default to reviewed.'
            Assert-Equal $normalizedOwnerRows[0].ConfirmedOwner 'Finance Ops Confirmed' 'Reviewer-entered owner confirmation should be preserved.'
            Assert-Equal $normalizedMigrationRows[0].Decision 'not sure yet' 'Invalid decisions should be retained for reviewer correction.'
            Assert-Equal $normalizedMigrationRows[0].DecisionStatus 'NeedsCorrection' 'Invalid decisions should be marked as needing correction.'
            Assert-True ($normalizedMigrationRows[0].ImportWarnings -like '*Allowed values:*ConfirmedOwner*WrongOwner*') 'Invalid decisions should explain allowed values.'

            $normalizedMigrationRows[0].Decision = 'rerun'
            $normalizedMigrationRows | Export-Csv -LiteralPath (Join-Path $reviewPath 'migration_cluster_decisions.csv') -NoTypeInformation -Encoding UTF8
            Import-ShareSurferReviewDecisions -ExportPath $exportPath -DecisionPath $reviewPath -Force | Out-Null
            $correctedMigrationRows = @(Import-Csv -LiteralPath (Join-Path $exportPath 'migration_cluster_decisions.csv'))
            Assert-Equal $correctedMigrationRows[0].Decision 'RerunNeeded' 'Corrected invalid decisions should normalize on a later import.'
            Assert-Equal $correctedMigrationRows[0].DecisionStatus 'Reviewed' 'Corrected invalid decisions should become reviewed.'
            Assert-True ($correctedMigrationRows[0].ImportWarnings -notlike '*Invalid decision*') 'Corrected decisions should not keep stale invalid-decision warnings.'
        }
    },
    @{
        Name = 'Import-ShareSurferReviewDecisions merges reviewer edits and refreshes source context'
        Body = {
            Import-Module $moduleManifest -Force
            $exportPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferReviewMergeExport-' + [guid]::NewGuid().ToString('N'))
            $reviewPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferReviewMergeSource-' + [guid]::NewGuid().ToString('N'))
            New-Item -ItemType Directory -Path $reviewPath -Force | Out-Null
            Invoke-ShareSurferScan -InputObject (New-TestInventory) -OutputPath $exportPath -SkipIdentityEnrichment | Out-Null
            New-ShareSurferReviewDecisionDraft -ExportPath $exportPath -OutputPath $reviewPath -Force | Out-Null

            $firstOwnerRows = @(Import-Csv -LiteralPath (Join-Path $reviewPath 'owner_review_decisions.csv'))
            $firstOwnerRows[0].Decision = 'CleanupNeeded'
            $firstOwnerRows[0].Reviewer = 'Initial Reviewer'
            $firstOwnerRows[0].Notes = 'Initial cleanup note.'
            $firstOwnerRows | Export-Csv -LiteralPath (Join-Path $reviewPath 'owner_review_decisions.csv') -NoTypeInformation -Encoding UTF8
            Import-ShareSurferReviewDecisions -ExportPath $exportPath -DecisionPath $reviewPath -Force | Out-Null

            $packetRows = @(Import-Csv -LiteralPath (Join-Path $exportPath 'owner_review_packets.csv'))
            $packetRows[0].Owner = 'Finance Operations Updated'
            $packetRows[0].RiskLevel = 'Review'
            $packetRows | Export-Csv -LiteralPath (Join-Path $exportPath 'owner_review_packets.csv') -NoTypeInformation -Encoding UTF8

            $secondOwnerRows = @(Import-Csv -LiteralPath (Join-Path $reviewPath 'owner_review_decisions.csv'))
            $secondOwnerRows[0].Decision = 'WrongOwner'
            $secondOwnerRows[0].Reviewer = 'Second Reviewer'
            $secondOwnerRows[0].Notes = 'Updated owner is wrong.'
            $secondOwnerRows | Export-Csv -LiteralPath (Join-Path $reviewPath 'owner_review_decisions.csv') -NoTypeInformation -Encoding UTF8
            Import-ShareSurferReviewDecisions -ExportPath $exportPath -DecisionPath $reviewPath -Force | Out-Null

            $mergedRows = @(Import-Csv -LiteralPath (Join-Path $exportPath 'owner_review_decisions.csv'))
            Assert-Equal $mergedRows.Count 1 'Merge should keep one row for the same ReviewPacketId.'
            Assert-Equal $mergedRows[0].Decision 'WrongOwner' 'Later reviewer edits should update reviewer-editable fields.'
            Assert-Equal $mergedRows[0].Reviewer 'Second Reviewer' 'Later reviewer should replace the previous reviewer value.'
            Assert-Equal $mergedRows[0].Owner 'Finance Operations Updated' 'Merge should refresh context from current owner review packets.'
            Assert-Equal $mergedRows[0].RiskLevel 'Review' 'Merge should refresh current risk context.'
        }
    },
    @{
        Name = 'Import-ShareSurferReviewDecisions keeps newer reviewed decisions over stale drafts'
        Body = {
            Import-Module $moduleManifest -Force
            $exportPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferReviewStaleExport-' + [guid]::NewGuid().ToString('N'))
            $firstReviewPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferReviewStaleFirst-' + [guid]::NewGuid().ToString('N'))
            $staleReviewPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferReviewStaleDraft-' + [guid]::NewGuid().ToString('N'))
            $newerReviewPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferReviewNewerDraft-' + [guid]::NewGuid().ToString('N'))
            New-Item -ItemType Directory -Path $firstReviewPath, $staleReviewPath, $newerReviewPath -Force | Out-Null
            Invoke-ShareSurferScan -InputObject (New-TestInventory) -OutputPath $exportPath -SkipIdentityEnrichment | Out-Null

            New-ShareSurferReviewDecisionDraft -ExportPath $exportPath -OutputPath $firstReviewPath -Force | Out-Null
            $firstOwnerRows = @(Import-Csv -LiteralPath (Join-Path $firstReviewPath 'owner_review_decisions.csv'))
            $firstOwnerRows[0].Decision = 'ConfirmedOwner'
            $firstOwnerRows[0].Reviewer = 'First Reviewer'
            $firstOwnerRows[0].ReviewedAt = '2026-07-01T12:00:00Z'
            $firstOwnerRows | Export-Csv -LiteralPath (Join-Path $firstReviewPath 'owner_review_decisions.csv') -NoTypeInformation -Encoding UTF8
            Import-ShareSurferReviewDecisions -ExportPath $exportPath -OwnerDecisionPath (Join-Path $firstReviewPath 'owner_review_decisions.csv') -Force | Out-Null

            New-ShareSurferReviewDecisionDraft -ExportPath $exportPath -OutputPath $staleReviewPath -Force | Out-Null
            $staleOwnerRows = @(Import-Csv -LiteralPath (Join-Path $staleReviewPath 'owner_review_decisions.csv'))
            $staleOwnerRows[0].Decision = ''
            $staleOwnerRows[0].Reviewer = 'Stale Draft Reviewer'
            $staleOwnerRows[0].ReviewedAt = '2026-06-01T12:00:00Z'
            $staleOwnerRows | Export-Csv -LiteralPath (Join-Path $staleReviewPath 'owner_review_decisions.csv') -NoTypeInformation -Encoding UTF8
            Import-ShareSurferReviewDecisions -ExportPath $exportPath -OwnerDecisionPath (Join-Path $staleReviewPath 'owner_review_decisions.csv') -Force | Out-Null
            $keptRows = @(Import-Csv -LiteralPath (Join-Path $exportPath 'owner_review_decisions.csv'))
            Assert-Equal $keptRows[0].Decision 'ConfirmedOwner' 'A stale blank/pending draft should not replace an existing reviewed decision.'
            Assert-Equal $keptRows[0].Reviewer 'First Reviewer' 'A stale draft should not replace reviewer attribution.'
            Assert-True ($keptRows[0].ImportWarnings -like '*Skipped older or pending incoming decision*') 'Skipped stale decisions should leave warning evidence.'

            New-ShareSurferReviewDecisionDraft -ExportPath $exportPath -OutputPath $newerReviewPath -Force | Out-Null
            $newerOwnerRows = @(Import-Csv -LiteralPath (Join-Path $newerReviewPath 'owner_review_decisions.csv'))
            $newerOwnerRows[0].Decision = 'WrongOwner'
            $newerOwnerRows[0].Reviewer = 'Newer Reviewer'
            $newerOwnerRows[0].ReviewedAt = '2026-07-02T12:00:00Z'
            $newerOwnerRows | Export-Csv -LiteralPath (Join-Path $newerReviewPath 'owner_review_decisions.csv') -NoTypeInformation -Encoding UTF8
            Import-ShareSurferReviewDecisions -ExportPath $exportPath -OwnerDecisionPath (Join-Path $newerReviewPath 'owner_review_decisions.csv') -Force | Out-Null
            $updatedRows = @(Import-Csv -LiteralPath (Join-Path $exportPath 'owner_review_decisions.csv'))
            Assert-Equal $updatedRows[0].Decision 'WrongOwner' 'A newer reviewed incoming decision should replace the older reviewed decision.'
            Assert-Equal $updatedRows[0].Reviewer 'Newer Reviewer' 'A newer reviewed incoming decision should preserve the newer reviewer.'
            Assert-True ($updatedRows[0].ImportWarnings -like '*Replaced existing decision*') 'Reviewed decision replacement should leave warning evidence.'
        }
    },
    @{
        Name = 'Import-ShareSurferReviewDecisions parses ReviewedAt with invariant culture'
        Body = {
            Import-Module $moduleManifest -Force
            $originalCulture = [System.Threading.Thread]::CurrentThread.CurrentCulture
            $originalUiCulture = [System.Threading.Thread]::CurrentThread.CurrentUICulture
            try {
                [System.Threading.Thread]::CurrentThread.CurrentCulture = [System.Globalization.CultureInfo]::GetCultureInfo('de-DE')
                [System.Threading.Thread]::CurrentThread.CurrentUICulture = [System.Globalization.CultureInfo]::GetCultureInfo('de-DE')
                $shareSurferModule = Get-Module ShareSurfer
                $parsed = & $shareSurferModule {
                    $row = [pscustomobject]@{ ReviewedAt = '03/07/2026 12:00:00' }
                    Get-ShareSurferReviewDecisionReviewedAt -Row $row
                }

                Assert-Equal $parsed.Month 3 'ReviewedAt fallback parsing should use invariant month/day interpretation, not the collector culture.'
                Assert-Equal $parsed.Day 7 'ReviewedAt fallback parsing should use invariant month/day interpretation, not the collector culture.'
                Assert-Equal $parsed.Kind ([System.DateTimeKind]::Utc) 'ReviewedAt parsing should normalize decision timestamps to UTC before precedence comparison.'
            }
            finally {
                [System.Threading.Thread]::CurrentThread.CurrentCulture = $originalCulture
                [System.Threading.Thread]::CurrentThread.CurrentUICulture = $originalUiCulture
            }
        }
    },
    @{
        Name = 'Import-ShareSurferReviewDecisions validates decision CSV headers'
        Body = {
            Import-Module $moduleManifest -Force
            $exportPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferReviewHeaderExport-' + [guid]::NewGuid().ToString('N'))
            $badOwnerPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferBadOwnerDecision-' + [guid]::NewGuid().ToString('N') + '.csv')
            Invoke-ShareSurferScan -InputObject (New-TestInventory) -OutputPath $exportPath -SkipIdentityEnrichment | Out-Null
            @(
                [pscustomobject]@{ RelatedAreaId = 'related-area-0001'; Decision = 'ConfirmedOwner' }
            ) | Export-Csv -LiteralPath $badOwnerPath -NoTypeInformation -Encoding UTF8

            $threw = $false
            try {
                Import-ShareSurferReviewDecisions -ExportPath $exportPath -OwnerDecisionPath $badOwnerPath -Force | Out-Null
            }
            catch {
                $threw = ($_.Exception.Message -like '*missing required column(s): ReviewPacketId*')
            }
            Assert-True $threw 'Owner decision imports should fail fast with a readable missing-header message.'
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
            $confidenceResult = @($validResult.FileResults | Where-Object { $_.FileName -eq 'evidence_confidence.csv' })[0]
            Assert-True ([int]$aclResult.RowCount -gt 0) 'Export validation should report row counts for populated CSVs.'
            Assert-Equal ([int]$manifestResult.RowCount) 1 'Export validation should report the single scan manifest row.'
            Assert-Equal ([int]$confidenceResult.RowCount) 2 'Export validation should report the scan and share evidence confidence rows.'

            Remove-Item -LiteralPath (Join-Path $outputPath 'evidence_confidence.csv') -Force
            $legacyResult = Test-ShareSurferExport -ExportPath $outputPath
            $legacyConfidenceResult = @($legacyResult.FileResults | Where-Object { $_.FileName -eq 'evidence_confidence.csv' })[0]
            Assert-True $legacyResult.IsValid 'Legacy exports should remain valid when additive evidence confidence rows are absent.'
            Assert-True ($legacyResult.MissingFiles -notcontains 'evidence_confidence.csv') 'Evidence confidence should not be a missing-file failure for older exports.'
            Assert-True ([bool]$legacyConfidenceResult.Optional) 'Evidence confidence should be marked optional when absent for legacy exports.'

            Invoke-ShareSurferScan -InputObject (New-TestInventory) -OutputPath $outputPath -SkipIdentityEnrichment | Out-Null

            $aclPath = Join-Path $outputPath 'acl_entries.csv'
            $brokenRows = Import-Csv -LiteralPath $aclPath | Select-Object ItemId, ShareId, FullPath, Rights, AccessMask, AccessControlType, IsInherited, InheritanceFlags, PropagationFlags, Depth
            $brokenRows | Export-Csv -LiteralPath $aclPath -NoTypeInformation -Encoding UTF8

            $brokenResult = Test-ShareSurferExport -ExportPath $outputPath
            $brokenAclResult = @($brokenResult.FileResults | Where-Object { $_.FileName -eq 'acl_entries.csv' })[0]
            Assert-True (-not $brokenResult.IsValid) 'Export validation should fail when a required column is missing.'
            Assert-True ($brokenAclResult.MissingColumns -contains 'Identity') 'File-level validation should report the missing column.'
            Assert-True ($brokenResult.SchemaErrors -contains 'acl_entries.csv is missing column Identity.') 'Top-level schema errors should keep the readable error message.'
        }
    },
    @{
        Name = 'Test-ShareSurferExport treats review decision CSVs as optional but validates them when present'
        Body = {
            Import-Module $moduleManifest -Force
            $outputPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferDecisionValidation-' + [guid]::NewGuid().ToString('N'))
            Invoke-ShareSurferScan -InputObject (New-TestInventory) -OutputPath $outputPath -SkipIdentityEnrichment | Out-Null

            Remove-Item -LiteralPath (Join-Path $outputPath 'owner_review_decisions.csv') -Force
            Remove-Item -LiteralPath (Join-Path $outputPath 'migration_cluster_decisions.csv') -Force
            $legacyResult = Test-ShareSurferExport -ExportPath $outputPath
            $legacyDecisionResults = @($legacyResult.FileResults | Where-Object { $_.FileName -in @('owner_review_decisions.csv', 'migration_cluster_decisions.csv') })
            Assert-True $legacyResult.IsValid 'Legacy exports should remain valid when decision CSVs are absent.'
            Assert-Equal $legacyDecisionResults.Count 2 'Validation should still report optional decision file status.'
            Assert-True (@($legacyDecisionResults | Where-Object { -not $_.Optional }).Count -eq 0) 'Decision file results should be marked optional.'

            New-ShareSurferReviewDecisionDraft -ExportPath $outputPath -Force | Out-Null
            $validResult = Test-ShareSurferExport -ExportPath $outputPath
            Assert-True $validResult.IsValid 'Draft decision CSVs should validate when present.'

            $ownerDecisionPath = Join-Path $outputPath 'owner_review_decisions.csv'
            $brokenRows = Import-Csv -LiteralPath $ownerDecisionPath | Select-Object ReviewPacketId, BusinessUnit, Owner, Pattern, Source, RiskLevel, ReviewStatus, MigrationReadiness, RelatedDataAreaCount, RelatednessStrength, SuggestedNextAction, Decision, ConfirmedOwner, ConfirmedBusinessUnit, Reviewer, ReviewedAt, Notes, NextAction, SourceDecisionPath, ImportWarnings, AllowedDecisions
            $brokenRows | Export-Csv -LiteralPath $ownerDecisionPath -NoTypeInformation -Encoding UTF8

            $brokenResult = Test-ShareSurferExport -ExportPath $outputPath
            Assert-True (-not $brokenResult.IsValid) 'Export validation should fail when a present decision CSV is missing a required column.'
            Assert-True ($brokenResult.SchemaErrors -contains 'owner_review_decisions.csv is missing column DecisionStatus.') 'Decision schema errors should keep readable file and column names.'
        }
    },
    @{
        Name = 'New-ShareSurferSupportBundle redacts reviewer fields while preserving decision status'
        Body = {
            Import-Module $moduleManifest -Force
            $exportPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferDecisionBundleExport-' + [guid]::NewGuid().ToString('N'))
            $reviewPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferDecisionBundleReview-' + [guid]::NewGuid().ToString('N'))
            $bundlePath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferDecisionBundle-' + [guid]::NewGuid().ToString('N'))
            New-Item -ItemType Directory -Path $reviewPath -Force | Out-Null
            Invoke-ShareSurferScan -InputObject (New-TestInventory) -OutputPath $exportPath -SkipIdentityEnrichment | Out-Null
            New-ShareSurferReviewDecisionDraft -ExportPath $exportPath -OutputPath $reviewPath -Force | Out-Null

            $ownerRows = @(Import-Csv -LiteralPath (Join-Path $reviewPath 'owner_review_decisions.csv'))
            $ownerRows[0].Decision = 'ConfirmedOwner'
            $ownerRows[0].ConfirmedOwner = 'Finance Sensitive Owner'
            $ownerRows[0].ConfirmedBusinessUnit = 'Finance Sensitive Unit'
            $ownerRows[0].Reviewer = 'Riley Sensitive Reviewer'
            $ownerRows[0].Notes = 'Sensitive business context that must not leak.'
            $ownerRows | Export-Csv -LiteralPath (Join-Path $reviewPath 'owner_review_decisions.csv') -NoTypeInformation -Encoding UTF8

            $migrationRows = @(Import-Csv -LiteralPath (Join-Path $reviewPath 'migration_cluster_decisions.csv'))
            $migrationRows[0].Decision = 'Do not migrate Legal Secret Area'
            $migrationRows | Export-Csv -LiteralPath (Join-Path $reviewPath 'migration_cluster_decisions.csv') -NoTypeInformation -Encoding UTF8
            Import-ShareSurferReviewDecisions -ExportPath $exportPath -DecisionPath $reviewPath -Force | Out-Null

            New-ShareSurferSupportBundle -ExportPath $exportPath -OutputPath $bundlePath -RedactionMode StableToken -RedactionSalt 'decision-test' | Out-Null
            $bundledRows = @(Import-Csv -LiteralPath (Join-Path $bundlePath 'owner_review_decisions.csv'))
            $bundledMigrationRows = @(Import-Csv -LiteralPath (Join-Path $bundlePath 'migration_cluster_decisions.csv'))

            Assert-Equal $bundledRows[0].Decision 'ConfirmedOwner' 'Decision enum should remain readable in support bundles.'
            Assert-Equal $bundledRows[0].DecisionStatus 'Reviewed' 'Decision status should remain readable in support bundles.'
            Assert-True ($bundledRows[0].ConfirmedOwner -ne 'Finance Sensitive Owner') 'Confirmed owner should be redacted.'
            Assert-True ($bundledRows[0].ConfirmedBusinessUnit -ne 'Finance Sensitive Unit') 'Confirmed business unit should be redacted.'
            Assert-True ($bundledRows[0].Reviewer -ne 'Riley Sensitive Reviewer') 'Reviewer should be redacted.'
            Assert-True ($bundledRows[0].Notes -ne 'Sensitive business context that must not leak.') 'Reviewer notes should be redacted.'
            Assert-Equal $bundledMigrationRows[0].DecisionStatus 'NeedsCorrection' 'Invalid decision status should remain readable in support bundles.'
            Assert-True ($bundledMigrationRows[0].Decision -ne 'Do not migrate Legal Secret Area') 'Invalid free-text decisions should be redacted in support bundles.'
        }
    },
    @{
        Name = 'Test-ShareSurferExport validates optional open-file assessment package when present'
        Body = {
            Import-Module $moduleManifest -Force
            $outputPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferOptionalOpenFiles-' + [guid]::NewGuid().ToString('N'))
            Invoke-ShareSurferScan -InputObject (New-TestInventory) -OutputPath $outputPath -SkipIdentityEnrichment | Out-Null

            $baselineResult = Test-ShareSurferExport -ExportPath $outputPath
            Assert-True $baselineResult.IsValid 'Baseline export validation should pass without optional open-file assessment files.'
            Assert-Equal (@($baselineResult.FileResults | Where-Object { $_.FileName -like 'open_file_*.csv' }).Count) 0 'Baseline validation should not require absent open-file assessment files.'

            $global:ShareSurferOpenFileProvider = {
                param(
                    [string] $ComputerName,
                    [string[]] $ShareName,
                    [string] $AssessmentId,
                    [string] $SampleId,
                    [string] $SampleTimestamp,
                    [string] $Provider
                )

                [pscustomobject]@{
                    AssessmentId = $AssessmentId
                    SampleId = $SampleId
                    SampleTimestamp = $SampleTimestamp
                    ComputerName = $ComputerName
                    ShareName = 'Finance'
                    Provider = $Provider
                    FileId = '1001'
                    SessionId = '2001'
                    ClientComputerName = 'WKSTN-001'
                    ClientUserName = 'CONTOSO\Ava.Accounting'
                    Path = 'C:\Shares\Finance\AP\invoice.xlsx'
                    FolderPath = 'C:\Shares\Finance\AP'
                    ShareRelativePath = 'AP\invoice.xlsx'
                    ShareRelativeFolder = 'AP'
                    Permissions = 'Read'
                    Locks = 1
                    Source = 'MockOpenFileProvider'
                    CollectionStatus = 'Open'
                    ErrorMessage = ''
                }
            }

            try {
                Invoke-ShareSurferOpenFileAssessment -ComputerName 'files01' -ShareName 'Finance' -OutputPath $outputPath -Provider NativeRpc -IntervalSeconds 0 -SampleCount 1 -Quiet | Out-Null

                $withPackageResult = Test-ShareSurferExport -ExportPath $outputPath
                $openFileResults = @($withPackageResult.FileResults | Where-Object { $_.FileName -like 'open_file_*.csv' })
                Assert-True $withPackageResult.IsValid 'Export validation should pass when a complete optional open-file package is present.'
                Assert-Equal $openFileResults.Count 4 'Export validation should inspect all open-file assessment CSVs when any are present.'
                Assert-True (@($openFileResults | Where-Object { -not $_.Optional }).Count -eq 0) 'Open-file package file results should be marked optional.'

                $samplesPath = Join-Path $outputPath 'open_file_samples.csv'
                $brokenSamples = Import-Csv -LiteralPath $samplesPath | Select-Object AssessmentId, SampleId, SampleTimestamp, ComputerName, ShareName, Provider, FileId, SessionId, ClientComputerName, ClientUserName, Path, FolderPath, ShareRelativePath, ShareRelativeFolder, Permissions, Locks, Source, CollectionStatus
                $brokenSamples | Export-Csv -LiteralPath $samplesPath -NoTypeInformation -Encoding UTF8

                $brokenResult = Test-ShareSurferExport -ExportPath $outputPath
                Assert-True (-not $brokenResult.IsValid) 'Export validation should fail when a present optional open-file package is missing a required column.'
                Assert-True ($brokenResult.SchemaErrors -contains 'open_file_samples.csv is missing column ErrorMessage.') 'Optional open-file schema errors should keep readable file and column names.'
            }
            finally {
                Remove-Variable -Name ShareSurferOpenFileProvider -Scope Global -ErrorAction SilentlyContinue
            }
        }
    },
    @{
        Name = 'Test-ShareSurferExport validates optional port protocol assessment package when present'
        Body = {
            Import-Module $moduleManifest -Force
            $outputPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferOptionalPortProtocol-' + [guid]::NewGuid().ToString('N'))
            Invoke-ShareSurferScan -InputObject (New-TestInventory) -OutputPath $outputPath -SkipIdentityEnrichment | Out-Null

            $baselineResult = Test-ShareSurferExport -ExportPath $outputPath
            Assert-True $baselineResult.IsValid 'Baseline export validation should pass without optional port/protocol assessment files.'
            Assert-Equal (@($baselineResult.FileResults | Where-Object { $_.FileName -like 'port_protocol_*.csv' }).Count) 0 'Baseline validation should not require absent port/protocol assessment files.'

            Invoke-ShareSurferPortProtocolAssessment -ComputerName 'files01' -ShareName 'Finance' -DirectoryServer 'dc01.contoso.test' -OutputPath $outputPath -SkipNetworkTests -Force | Out-Null

            $withPackageResult = Test-ShareSurferExport -ExportPath $outputPath
            $portProtocolResults = @($withPackageResult.FileResults | Where-Object { $_.FileName -like 'port_protocol_*.csv' })
            Assert-True $withPackageResult.IsValid 'Export validation should pass when a complete optional port/protocol package is present.'
            Assert-Equal $portProtocolResults.Count 3 'Export validation should inspect all port/protocol assessment CSVs when any are present.'
            Assert-True (@($portProtocolResults | Where-Object { -not $_.Optional }).Count -eq 0) 'Port/protocol package file results should be marked optional.'

            $checksPath = Join-Path $outputPath 'port_protocol_checks.csv'
            $brokenChecks = Import-Csv -LiteralPath $checksPath | Select-Object AssessmentId, CheckId, TargetId, Target, TargetType, ComputerName, ShareName, Protocol, Transport, Port, Requirement, Provider, Purpose, RequiredFor, Status, Severity, EnvironmentProfile, CollectionImpact, OperatorGuidance, RemediationHint, LatencyMs, RemoteAddress, Message
            $brokenChecks | Export-Csv -LiteralPath $checksPath -NoTypeInformation -Encoding UTF8

            $brokenResult = Test-ShareSurferExport -ExportPath $outputPath
            Assert-True (-not $brokenResult.IsValid) 'Export validation should fail when a present optional port/protocol package is missing a required column.'
            Assert-True ($brokenResult.SchemaErrors -contains 'port_protocol_checks.csv is missing column Detail.') 'Optional port/protocol schema errors should keep readable file and column names.'
        }
    },
    @{
        Name = 'Test-ShareSurferExport validates optional file-share connectivity assessment package when present'
        Body = {
            Import-Module $moduleManifest -Force
            $outputPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferOptionalConnectivity-' + [guid]::NewGuid().ToString('N'))
            Invoke-ShareSurferScan -InputObject (New-TestInventory) -OutputPath $outputPath -SkipIdentityEnrichment | Out-Null

            $baselineResult = Test-ShareSurferExport -ExportPath $outputPath
            Assert-True $baselineResult.IsValid 'Baseline export validation should pass without optional file-share connectivity files.'
            Assert-Equal (@($baselineResult.FileResults | Where-Object { $_.FileName -like 'fileshare_connectivity_*.csv' }).Count) 0 'Baseline validation should not require absent file-share connectivity assessment files.'

            Invoke-ShareSurferFileShareConnectivityAssessment -TargetPath '\\files01\Finance' -OutputPath $outputPath -SkipNetworkTests -SkipCimChecks -SkipNativeChecks -Quiet -Force | Out-Null

            $withPackageResult = Test-ShareSurferExport -ExportPath $outputPath
            $connectivityResults = @($withPackageResult.FileResults | Where-Object { $_.FileName -like 'fileshare_connectivity_*.csv' })
            $shareDiagnosticResults = @($withPackageResult.FileResults | Where-Object { $_.FileName -like 'share_permission_diagnostic*.csv' -or $_.FileName -eq 'share_permission_diagnostics.csv' })
            Assert-True $withPackageResult.IsValid 'Export validation should pass when a complete optional file-share connectivity package is present.'
            Assert-Equal $connectivityResults.Count 3 'Export validation should inspect all file-share connectivity assessment CSVs when any are present.'
            Assert-Equal $shareDiagnosticResults.Count 2 'Export validation should inspect the share-permission diagnostic CSVs when the diagnostic package is present.'
            Assert-True (@($connectivityResults | Where-Object { -not $_.Optional }).Count -eq 0) 'File-share connectivity package file results should be marked optional.'
            Assert-True (@($shareDiagnosticResults | Where-Object { -not $_.Optional }).Count -eq 0) 'Share-permission diagnostic package file results should be marked optional.'

            $checksPath = Join-Path $outputPath 'fileshare_connectivity_checks.csv'
            $brokenChecks = Import-Csv -LiteralPath $checksPath | Select-Object AssessmentId, CheckId, TargetId, Target, InputType, ComputerName, ShareName, Layer, Capability, Provider, Attempted, Status, Severity, EvidenceType, RawResultCode, Message, Detail
            $brokenChecks | Export-Csv -LiteralPath $checksPath -NoTypeInformation -Encoding UTF8

            $brokenResult = Test-ShareSurferExport -ExportPath $outputPath
            Assert-True (-not $brokenResult.IsValid) 'Export validation should fail when a present optional file-share connectivity package is missing a required column.'
            Assert-True ($brokenResult.SchemaErrors -contains 'fileshare_connectivity_checks.csv is missing column RecommendedAction.') 'Optional file-share connectivity schema errors should keep readable file and column names.'
        }
    },
    @{
        Name = 'Invoke-ShareSurferFileShareConnectivityAssessment writes raw and redacted capability evidence'
        Body = {
            Import-Module $moduleManifest -Force
            $outputPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferConnectivity-' + [guid]::NewGuid().ToString('N'))
            $descriptorBytes = [byte[]]@(1, 2, 3, 4)

            $global:ShareSurferFileShareConnectivityProvider = {
                param(
                    [string] $Action,
                    $Context
                )

                if ($Action -eq 'NameResolution') {
                    return [pscustomobject]@{
                        Status = 'Pass'
                        Severity = 'Info'
                        EvidenceType = 'NameResolved'
                        RawResultCode = ''
                        Message = 'Resolved files01.'
                        Detail = 'files01 resolved for testing.'
                        RecommendedAction = 'Continue to collection checks.'
                    }
                }

                if ($Action -eq 'TcpPort') {
                    return [pscustomobject]@{
                        Status = 'Pass'
                        Severity = 'Info'
                        EvidenceType = ([string]$Context.Capability + 'Reachable')
                        RawResultCode = ''
                        Message = ('TCP check passed for files01 port {0}.' -f $Context.Port)
                        Detail = 'TCP reachability is not descriptor proof.'
                        RecommendedAction = 'Continue to collection proof.'
                    }
                }

                $null
            }

            $global:ShareSurferSmbRpcShareInfoProvider = {
                param(
                    [string] $ComputerName,
                    [string] $ShareName
                )

                [pscustomobject]@{
                    ShareName = $ShareName
                    Path = 'C:\Shares\Finance'
                    Description = 'Finance share'
                    Source = 'MockSmbRpcNetShareGetInfo'
                    ResultCode = 0
                    Level = 502
                    SecurityDescriptorBytes = $descriptorBytes
                }
            }

            $global:ShareSurferNativeSecurityInfoProvider = {
                param(
                    [string] $Path,
                    [string] $ShareId,
                    [string] $ItemId,
                    [string] $FullPath,
                    [int] $Depth
                )

                [pscustomobject]@{
                    Owner = 'CONTOSO\Admin.Owner'
                    InheritanceEnabled = $true
                    InheritanceBrokenAt = ''
                    AclEntries = @(
                        [pscustomobject]@{
                            ItemId = $ItemId
                            ShareId = $ShareId
                            FullPath = $FullPath
                            Identity = 'CONTOSO\Admin.Owner'
                            Rights = 'FullControl'
                            AccessMask = '0x001F01FF'
                            AccessControlType = 'Allow'
                            IsInherited = $false
                            InheritanceFlags = 'None'
                            PropagationFlags = 'None'
                            Depth = $Depth
                        }
                    )
                    Source = 'MockNativeSecurity'
                }
            }

            $global:ShareSurferOpenFileProvider = {
                param(
                    [string] $ComputerName,
                    [string[]] $ShareName,
                    [string] $AssessmentId,
                    [string] $SampleId,
                    [string] $SampleTimestamp,
                    [string] $Provider
                )

                [pscustomobject]@{
                    AssessmentId = $AssessmentId
                    SampleId = $SampleId
                    SampleTimestamp = $SampleTimestamp
                    ComputerName = $ComputerName
                    ShareName = 'Finance'
                    Provider = $Provider
                    FileId = '1001'
                    SessionId = '2001'
                    ClientComputerName = 'WKSTN-001'
                    ClientUserName = 'CONTOSO\Ava.Accounting'
                    Path = 'C:\Shares\Finance\AP\invoice.xlsx'
                    FolderPath = 'C:\Shares\Finance\AP'
                    ShareRelativePath = 'AP\invoice.xlsx'
                    ShareRelativeFolder = 'AP'
                    Permissions = 'Read'
                    Locks = 1
                    Source = 'MockOpenFileProvider'
                    CollectionStatus = 'Open'
                    ErrorMessage = ''
                }
            }

            $global:ShareSurferNativeSessionProvider = {
                param(
                    [string] $ComputerName,
                    [int] $MaxRows
                )

                [pscustomobject]@{
                    ComputerName = $ComputerName
                    ClientComputerName = 'WKSTN-001'
                    ClientUserName = 'CONTOSO\Ava.Accounting'
                    ConnectedSeconds = 120
                    IdleSeconds = 10
                    Source = 'MockSessionProvider'
                }
            }

            try {
                $result = Invoke-ShareSurferFileShareConnectivityAssessment -TargetPath '\\files01\Finance' -OutputPath $outputPath -SkipCimChecks -IncludeOpenFiles -IncludeSessions -Quiet -PassThru
                $manifest = @(Import-Csv -LiteralPath (Join-Path $outputPath 'fileshare_connectivity_manifest.csv'))
                $targets = @(Import-Csv -LiteralPath (Join-Path $outputPath 'fileshare_connectivity_targets.csv'))
                $checks = @(Import-Csv -LiteralPath (Join-Path $outputPath 'fileshare_connectivity_checks.csv'))
                $diagnosticManifest = @(Import-Csv -LiteralPath (Join-Path $outputPath 'share_permission_diagnostic_manifest.csv'))
                $diagnostics = @(Import-Csv -LiteralPath (Join-Path $outputPath 'share_permission_diagnostics.csv'))
                $summary = Get-Content -LiteralPath (Join-Path $outputPath 'fileshare_connectivity_summary.json') -Raw | ConvertFrom-Json
                $diagnosticSummaryText = Get-Content -LiteralPath (Join-Path $outputPath 'share_permission_diagnostics.md') -Raw
                $redactedChecksText = Get-Content -LiteralPath (Join-Path $outputPath 'redacted/fileshare_connectivity_checks.csv') -Raw
                $redactedDiagnosticsText = Get-Content -LiteralPath (Join-Path $outputPath 'redacted/share_permission_diagnostics.csv') -Raw
                $redactedDiagnosticSummaryText = Get-Content -LiteralPath (Join-Path $outputPath 'redacted/share_permission_diagnostics.md') -Raw
                $redactedSummaryText = Get-Content -LiteralPath (Join-Path $outputPath 'redacted/fileshare_connectivity_llm_summary.md') -Raw

                Assert-True $result.IsValid 'Connectivity assessment should produce a complete raw and redacted diagnostic package.'
                Assert-Equal $manifest[0].PackageKind 'FileShareConnectivityAssessment' 'Connectivity manifest should identify the package kind.'
                Assert-Equal $diagnosticManifest[0].PackageKind 'SharePermissionDiagnostic' 'Share-permission diagnostic manifest should identify the package kind.'
                Assert-Equal $targets[0].RecommendedScanProvider 'NeedsReview' 'Native metadata with descriptor parse failure should require review even when SMB is reachable.'
                Assert-True ($checks.Capability -contains 'NativeShareDescriptorParsed') 'Connectivity checks should include share descriptor parse proof.'
                Assert-True ($checks.Capability -contains 'FileSystemSecurityDescriptorRead') 'Connectivity checks should include filesystem owner/DACL proof.'
                Assert-True (@($diagnostics | Where-Object { $_.AttemptedMethod -like '*Get-SmbShareAccess*' }).Count -gt 0) 'Share-permission diagnostics should include the CIM Get-SmbShareAccess proof path.'
                Assert-True (@($diagnostics | Where-Object { $_.AttemptedMethod -like '*NetShareGetInfo*' }).Count -gt 0) 'Share-permission diagnostics should include the native NetShareGetInfo proof path.'
                Assert-True (@($diagnostics | Where-Object { $_.WhyItMatters -like '*TCP*permission proof*' -or $_.WhyItMatters -like '*share security descriptor*' }).Count -gt 0) 'Share-permission diagnostics should explain signal meaning beyond port reachability.'
                Assert-True ($checks.Capability -contains 'OpenFileEnumeration') 'Connectivity checks should include open-file capability when requested.'
                Assert-True ($checks.Capability -contains 'SessionEnumeration') 'Connectivity checks should include session capability when requested.'
                Assert-True (@($checks | Where-Object { $_.Capability -eq 'SmbTcp445' -and $_.Status -eq 'Pass' }).Count -eq 1) 'Connectivity checks should prove SMB TCP without treating it as descriptor proof.'
                Assert-True (@($checks | Where-Object { $_.Capability -eq 'NativeShareDescriptorParsed' -and $_.EvidenceType -eq 'NativeShareSecurityDescriptorParseFailed' }).Count -eq 1) 'Connectivity checks should classify native share descriptor parse failures separately from SMB reachability.'
                Assert-True (@($diagnostics | Where-Object { $_.EvidenceType -eq 'NativeShareSecurityDescriptorParseFailed' -and $_.RecommendedAction -like '*raw diagnostics*' }).Count -eq 1) 'Share-permission diagnostics should surface native descriptor parse failures with review guidance.'
                Assert-True (@($checks | Where-Object { $_.Capability -eq 'FileSystemSecurityDescriptorRead' -and $_.Status -eq 'Pass' }).Count -eq 1) 'Connectivity checks should prove filesystem owner/DACL reads independently from share descriptor parsing.'
                Assert-Equal $summary.PackageKind 'FileShareConnectivityAssessment' 'Connectivity summary JSON should parse and identify the package kind.'
                Assert-True ($diagnosticSummaryText -like '*Where To Look*') 'Share-permission diagnostic summary should tell operators which files to open.'
                Assert-True ($diagnosticSummaryText -like '*TCP port success*') 'Share-permission diagnostic summary should warn that transport success is not permission proof.'
                Assert-True (Test-Path -LiteralPath $result.SharePermissionDiagnosticPath -PathType Leaf) 'PassThru result should point to the raw share-permission diagnostic CSV.'
                Assert-True (Test-Path -LiteralPath $result.SharePermissionDiagnosticSummaryPath -PathType Leaf) 'PassThru result should point to the human share-permission diagnostic summary.'
                Assert-True ($redactedSummaryText -like '*Why TCP Is Not Enough*') 'LLM-ready summary should explain why transport reachability is not collection proof.'
                Assert-True ($redactedSummaryText -like '*Safe to share*' -or $redactedSummaryText -like '*safe to share*') 'LLM-ready summary should state safe-sharing intent.'
                Assert-True ($redactedChecksText -notlike '*files01*') 'Redacted checks should not preserve the raw host name.'
                Assert-True ($redactedChecksText -notlike '*Finance*') 'Redacted checks should not preserve the raw share name.'
                Assert-True ($redactedDiagnosticsText -notlike '*files01*') 'Redacted share-permission diagnostics should not preserve the raw host name.'
                Assert-True ($redactedDiagnosticsText -notlike '*Finance*') 'Redacted share-permission diagnostics should not preserve the raw share name.'
                Assert-True ($redactedDiagnosticSummaryText -notlike '*files01*') 'Redacted share-permission summary should not preserve the raw host name.'
                Assert-True ($redactedDiagnosticSummaryText -notlike '*Finance*') 'Redacted share-permission summary should not preserve the raw share name.'
                Assert-True ($redactedChecksText -notlike '*CONTOSO*') 'Redacted checks should not preserve raw account names.'
                Assert-True ($redactedSummaryText -notlike '*files01*') 'Redacted LLM summary should not preserve the raw host name.'
                Assert-True ($redactedSummaryText -notlike '*Finance*') 'Redacted LLM summary should not preserve the raw share name.'
            }
            finally {
                Remove-Variable -Name ShareSurferFileShareConnectivityProvider -Scope Global -ErrorAction SilentlyContinue
                Remove-Variable -Name ShareSurferSmbRpcShareInfoProvider -Scope Global -ErrorAction SilentlyContinue
                Remove-Variable -Name ShareSurferNativeSecurityInfoProvider -Scope Global -ErrorAction SilentlyContinue
                Remove-Variable -Name ShareSurferOpenFileProvider -Scope Global -ErrorAction SilentlyContinue
                Remove-Variable -Name ShareSurferNativeSessionProvider -Scope Global -ErrorAction SilentlyContinue
            }
        }
    },
    @{
        Name = 'File-share connectivity redaction handles casing drift and fallback raw details'
        Body = {
            Import-Module $moduleManifest -Force
            $module = Get-Module ShareSurfer

            $redactedText = & $module {
                $tokenMap = New-Object -TypeName System.Collections.Hashtable -ArgumentList ([System.StringComparer]::OrdinalIgnoreCase)
                $tokenMap['\\files01\Finance'] = 'UNC_TOKEN'
                Protect-ShareSurferFileShareConnectivityText -Value 'Failed for \\FILES01\FINANCE as CONTOSO\User and ava.owner@example.test from C:\Shares\Finance.' -TokenMap $tokenMap
            }

            Assert-True ($redactedText -like '*UNC_TOKEN*') 'Connectivity redaction should replace known sensitive values regardless of casing.'
            Assert-True ($redactedText -notmatch '(?i)files01|finance|contoso|ava\.owner@example\.test|C:\\Shares') 'Connectivity redaction should scrub residual host, share, identity, email, and path details.'
            Assert-True ($redactedText -like '*IDENTITY_REDACTED*') 'Connectivity redaction should scrub residual Windows identity strings.'
            Assert-True ($redactedText -like '*USER_REDACTED*') 'Connectivity redaction should scrub residual email strings.'
            Assert-True ($redactedText -like '*PATH_REDACTED*') 'Connectivity redaction should scrub residual drive paths.'
        }
    },
    @{
        Name = 'Share-permission diagnostics use UNC descriptor fallback when returned share path is not collector-local'
        Body = {
            Import-Module $moduleManifest -Force
            $outputPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferSanDescriptorFallback-' + [guid]::NewGuid().ToString('N'))
            $global:ShareSurferTestDescriptorAttemptPaths = New-Object System.Collections.ArrayList

            $global:ShareSurferSmbRpcShareInfoProvider = {
                param(
                    [string] $ComputerName,
                    [string] $ShareName
                )

                [pscustomobject]@{
                    ShareName = $ShareName
                    Path = 'C:\Public\GEO LOCATION\TestLocation'
                    Description = 'SAN returned server-local path'
                    Source = 'MockSmbRpcNetShareGetInfo'
                    ResultCode = 0
                    Level = 502
                    SecurityDescriptorBytes = @()
                }
            }

            $global:ShareSurferNativeSecurityInfoProvider = {
                param(
                    [string] $Path,
                    [string] $ShareId,
                    [string] $ItemId,
                    [string] $FullPath,
                    [int] $Depth
                )

                [void]$global:ShareSurferTestDescriptorAttemptPaths.Add($Path)
                if ($Path -like 'C:\Public*') {
                    throw 'NativeSecurityDescriptorReadFailed: GetNamedSecurityInfoW failed for \\?\C:\Public\GEO LOCATION\TestLocation with Win32 result 3 (The system cannot find the path specified).'
                }

                [pscustomobject]@{
                    Owner = 'CONTOSO\Data.Owner'
                    InheritanceEnabled = $true
                    InheritanceBrokenAt = ''
                    AclEntries = @(
                        [pscustomobject]@{
                            ItemId = $ItemId
                            ShareId = $ShareId
                            FullPath = $FullPath
                            Identity = 'CONTOSO\Data.Owner'
                            Rights = 'ReadAndExecute'
                            AccessMask = '0x001200A9'
                            AccessControlType = 'Allow'
                            IsInherited = $false
                            InheritanceFlags = 'None'
                            PropagationFlags = 'None'
                            Depth = $Depth
                        }
                    )
                    Source = 'MockNativeSecurity'
                }
            }

            try {
                $result = Invoke-ShareSurferFileShareConnectivityAssessment -TargetPath '\\testsystem\TestLocation' -OutputPath $outputPath -SkipNetworkTests -SkipCimChecks -Quiet -PassThru
                $checks = @(Import-Csv -LiteralPath (Join-Path $outputPath 'fileshare_connectivity_checks.csv'))
                $diagnostics = @(Import-Csv -LiteralPath (Join-Path $outputPath 'share_permission_diagnostics.csv'))

                $pathSelection = @($checks | Where-Object { $_.Capability -eq 'FileSystemSecurityDescriptorPathSelection' })[0]
                $descriptorRead = @($checks | Where-Object { $_.Capability -eq 'FileSystemSecurityDescriptorRead' })[0]

                Assert-True $result.IsValid 'SAN descriptor fallback diagnostic package should be valid.'
                Assert-Equal $global:ShareSurferTestDescriptorAttemptPaths.Count 1 'Descriptor read should skip the remote server-local C:\ path when it is not collector-local.'
                Assert-Equal ([string]$global:ShareSurferTestDescriptorAttemptPaths[0]) '\\testsystem\TestLocation' 'Descriptor read should attempt the target UNC path.'
                Assert-Equal $pathSelection.EvidenceType 'ReturnedSharePathNotCollectorLocal' 'Path selection should explain that the returned share path is not collector-local.'
                Assert-True ($pathSelection.Detail -like '*ReturnedShareLocalPath=C:\Public\GEO LOCATION\TestLocation*') 'Path selection detail should preserve the returned share-local path in raw diagnostics.'
                Assert-True ($pathSelection.Detail -like '*TargetUNCPath=\\testsystem\TestLocation*') 'Path selection detail should preserve the UNC fallback path.'
                Assert-Equal $descriptorRead.Status 'Pass' 'UNC fallback should make filesystem descriptor proof pass when the UNC descriptor read succeeds.'
                Assert-True ($descriptorRead.Detail -like '*AttemptPathKind=TargetUNCPath*') 'Descriptor proof should identify the selected UNC attempt path kind.'
                Assert-True ($descriptorRead.Detail -like '*DescriptorReadPath=\\testsystem\TestLocation*') 'Descriptor proof should identify the selected UNC descriptor path.'
                Assert-True (@($diagnostics | Where-Object { $_.EvidenceType -eq 'ReturnedSharePathNotCollectorLocal' -and $_.WhyItMatters -like '*server-local paths*collector*' }).Count -eq 1) 'Share-permission diagnostics should explain the server-local path signal.'
            }
            finally {
                Remove-Variable -Name ShareSurferSmbRpcShareInfoProvider -Scope Global -ErrorAction SilentlyContinue
                Remove-Variable -Name ShareSurferNativeSecurityInfoProvider -Scope Global -ErrorAction SilentlyContinue
                Remove-Variable -Name ShareSurferTestDescriptorAttemptPaths -Scope Global -ErrorAction SilentlyContinue
            }
        }
    },
    @{
        Name = 'Invoke-ShareSurferSharePermissionDiagnostic writes focused share-permission logs and console pointers'
        Body = {
            Import-Module $moduleManifest -Force
            $outputPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferSharePermDiag-' + [guid]::NewGuid().ToString('N'))

            $captured = @(& {
                Invoke-ShareSurferSharePermissionDiagnostic -TargetPath '\\files01\Finance' -OutputPath $outputPath -SkipNetworkTests -SkipCimChecks -SkipNativeChecks -Force
            } 6>&1)
            $capturedText = ($captured | ForEach-Object { [string]$_ }) -join "`n"
            $result = Invoke-ShareSurferSharePermissionDiagnostic -TargetPath '\\files01\Finance' -OutputPath $outputPath -SkipNetworkTests -SkipCimChecks -SkipNativeChecks -Force -Quiet -PassThru
            $diagnostics = @(Import-Csv -LiteralPath (Join-Path $outputPath 'share_permission_diagnostics.csv'))
            $manifest = @(Import-Csv -LiteralPath (Join-Path $outputPath 'share_permission_diagnostic_manifest.csv'))
            $diagnosticHeader = Get-Content -LiteralPath (Join-Path $outputPath 'share_permission_diagnostics.csv') -First 1

            Assert-True ($capturedText -like '*Starting intensive share-permission diagnostics*') 'Focused diagnostic command should announce that it is deeper than port checks.'
            Assert-True ($capturedText -like '*Open this first:*share_permission_diagnostics.md*') 'Focused diagnostic command should tell operators where to start reviewing logs.'
            Assert-True ($capturedText -like '*share_permission_diagnostics.csv*') 'Focused diagnostic command should point to raw diagnostic rows.'
            Assert-True $result.IsValid 'Focused diagnostic command should produce a valid diagnostic package.'
            Assert-Equal $manifest[0].PackageKind 'SharePermissionDiagnostic' 'Focused diagnostic package should include a share-permission manifest.'
            Assert-True (@($diagnostics | Where-Object { $_.AttemptedMethod -like '*Get-SmbShareAccess*' }).Count -gt 0) 'Focused diagnostics should show the CIM share-permission method even when skipped.'
            Assert-True (@($diagnostics | Where-Object { $_.AttemptedMethod -like '*NetShareGetInfo*' }).Count -gt 0) 'Focused diagnostics should show the native SMB/RPC method even when skipped.'
            Assert-True (Test-Path -LiteralPath (Join-Path $outputPath 'share_permission_diagnostics.jsonl') -PathType Leaf) 'Focused diagnostics should write a raw JSONL event-style log.'
            Assert-True (Test-Path -LiteralPath (Join-Path $outputPath 'redacted/share_permission_diagnostics.md') -PathType Leaf) 'Focused diagnostics should write a redacted support-safe summary.'
            Assert-True ($diagnosticHeader -like '*AttemptedMethod*' -and $diagnosticHeader -like '*RecommendedAction*') 'Focused standalone diagnostics should write the expected diagnostic CSV columns.'
        }
    },
    @{
        Name = 'Invoke-ShareSurferOpenFileAssessment writes samples and hot-folder summaries'
        Body = {
            Import-Module $moduleManifest -Force
            $outputPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferOpenFiles-' + [guid]::NewGuid().ToString('N'))
            $global:ShareSurferOpenFileProvider = {
                param(
                    [string] $ComputerName,
                    [string[]] $ShareName,
                    [string] $AssessmentId,
                    [string] $SampleId,
                    [string] $SampleTimestamp,
                    [string] $Provider
                )

                $share = if ($ShareName.Count -gt 0) { [string]$ShareName[0] } else { 'Finance' }
                @(
                    [pscustomobject]@{
                        AssessmentId = $AssessmentId
                        SampleId = $SampleId
                        SampleTimestamp = $SampleTimestamp
                        ComputerName = $ComputerName
                        ShareName = $share
                        Provider = $Provider
                        FileId = '1001'
                        SessionId = '2001'
                        ClientComputerName = 'WKSTN-001'
                        ClientUserName = 'CONTOSO\Ava.Accounting'
                        Path = 'C:\Shares\Finance\AP\invoice.xlsx'
                        FolderPath = 'C:\Shares\Finance\AP'
                        ShareRelativePath = 'AP\invoice.xlsx'
                        ShareRelativeFolder = 'AP'
                        Permissions = 'Read'
                        Locks = 1
                        Source = 'MockOpenFileProvider'
                        CollectionStatus = 'Open'
                        ErrorMessage = ''
                    },
                    [pscustomobject]@{
                        AssessmentId = $AssessmentId
                        SampleId = $SampleId
                        SampleTimestamp = $SampleTimestamp
                        ComputerName = $ComputerName
                        ShareName = $share
                        Provider = $Provider
                        FileId = '1002'
                        SessionId = '2002'
                        ClientComputerName = 'WKSTN-002'
                        ClientUserName = 'CONTOSO\Riley.Reviewer'
                        Path = 'C:\Shares\Finance\AP\invoice.xlsx'
                        FolderPath = 'C:\Shares\Finance\AP'
                        ShareRelativePath = 'AP\invoice.xlsx'
                        ShareRelativeFolder = 'AP'
                        Permissions = 'Read,Write'
                        Locks = 0
                        Source = 'MockOpenFileProvider'
                        CollectionStatus = 'Open'
                        ErrorMessage = ''
                    }
                )
            }

            try {
                $result = Invoke-ShareSurferOpenFileAssessment -ComputerName 'files01' -ShareName 'Finance' -OutputPath $outputPath -Provider NativeRpc -IntervalSeconds 0 -SampleCount 2 -Quiet -PassThru
                $manifest = @(Import-Csv -LiteralPath (Join-Path $outputPath 'open_file_manifest.csv'))
                $samples = @(Import-Csv -LiteralPath (Join-Path $outputPath 'open_file_samples.csv'))
                $summary = @(Import-Csv -LiteralPath (Join-Path $outputPath 'open_file_summary.csv'))
                $errors = @(Import-Csv -LiteralPath (Join-Path $outputPath 'open_file_errors.csv'))

                Assert-True $result.IsValid 'Open file assessment should report a valid package.'
                Assert-Equal $manifest[0].Provider 'NativeRpc' 'Open file assessment manifest should record provider selection.'
                Assert-Equal $manifest[0].SampleCount '2' 'Open file assessment manifest should record effective sample count.'
                Assert-Equal $samples.Count 4 'Open file assessment should write one sample row per observed open-file row.'
                Assert-True ($samples.ClientUserName -contains 'CONTOSO\Ava.Accounting') 'Open file samples should preserve client user evidence.'
                Assert-True ($summary.Count -ge 1) 'Open file assessment should produce folder summary pivots.'
                Assert-Equal $summary[0].ShareRelativeFolder 'AP' 'Open file summary should group by share-relative folder.'
                Assert-Equal $summary[0].HotFolder 'True' 'Repeated activity should mark the folder as hot.'
                Assert-Equal $errors.Count 0 'Successful open file assessment should still write an empty errors CSV with headers.'
            }
            finally {
                Remove-Variable -Name ShareSurferOpenFileProvider -Scope Global -ErrorAction SilentlyContinue
            }
        }
    },
    @{
        Name = 'Invoke-ShareSurferOpenFileAssessment records provider errors without dropping the package'
        Body = {
            Import-Module $moduleManifest -Force
            $outputPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferOpenFileErrors-' + [guid]::NewGuid().ToString('N'))
            $global:ShareSurferOpenFileProvider = {
                throw 'mock open-file provider failure'
            }

            try {
                $result = Invoke-ShareSurferOpenFileAssessment -ComputerName 'files01' -ShareName 'Finance' -OutputPath $outputPath -Provider NativeRpc -IntervalSeconds 0 -SampleCount 1 -Quiet -PassThru
                $samples = @(Import-Csv -LiteralPath (Join-Path $outputPath 'open_file_samples.csv'))
                $errors = @(Import-Csv -LiteralPath (Join-Path $outputPath 'open_file_errors.csv'))

                Assert-True $result.IsValid 'Open file assessment should keep package files valid when a sample errors.'
                Assert-Equal $result.ErrorCount 1 'Open file assessment should count provider errors.'
                Assert-Equal $samples.Count 0 'Provider failure should not fabricate sample rows.'
                Assert-Equal $errors.Count 1 'Provider failure should be exported as open-file error evidence.'
                Assert-True ($errors[0].Message -like '*mock open-file provider failure*') 'Open file error rows should preserve readable failure messages.'
            }
            finally {
                Remove-Variable -Name ShareSurferOpenFileProvider -Scope Global -ErrorAction SilentlyContinue
            }
        }
    },
    @{
        Name = 'Invoke-ShareSurferPortProtocolAssessment writes collector and target readiness CSVs'
        Body = {
            Import-Module $moduleManifest -Force
            $outputPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferPortProtocol-' + [guid]::NewGuid().ToString('N'))

            $result = Invoke-ShareSurferPortProtocolAssessment -ComputerName 'files01' -ShareName 'Finance' -DirectoryServer 'dc01.contoso.test' -OutputPath $outputPath -SkipNetworkTests -PassThru
            $manifest = @(Import-Csv -LiteralPath (Join-Path $outputPath 'port_protocol_manifest.csv'))
            $targets = @(Import-Csv -LiteralPath (Join-Path $outputPath 'port_protocol_targets.csv'))
            $checks = @(Import-Csv -LiteralPath (Join-Path $outputPath 'port_protocol_checks.csv'))

            Assert-True $result.IsValid 'Port/protocol assessment should report a valid CSV package.'
            Assert-Equal $manifest[0].PackageKind 'PortProtocolAssessment' 'Port/protocol manifest should identify its package kind.'
            Assert-Equal $manifest[0].SkippedCount $result.SkippedCount 'Manifest should summarize skipped dry-run checks.'
            Assert-True ($targets.Target -contains '\\files01\Finance') 'Target CSV should include the SMB share target.'
            Assert-True ($targets.TargetType -contains 'DirectoryTarget') 'Target CSV should include the directory server target when supplied.'
            Assert-True ($checks.Protocol -contains 'SMB') 'Check CSV should include SMB TCP 445 evidence.'
            Assert-True ($checks.Protocol -contains 'WinRM HTTP') 'Check CSV should include WinRM/CIM evidence.'
            Assert-True ($checks.Protocol -contains 'LDAP') 'Check CSV should include directory protocol evidence.'
            Assert-True ($targets[0].PSObject.Properties.Name -contains 'ReadinessSummary') 'Target CSV should include reader-facing readiness summaries.'
            Assert-True ($targets[0].PSObject.Properties.Name -contains 'CollectionImpact') 'Target CSV should include collection impact guidance.'
            Assert-True ($checks[0].PSObject.Properties.Name -contains 'EnvironmentProfile') 'Check CSV should include environment profile guidance.'
            Assert-True ($checks[0].PSObject.Properties.Name -contains 'OperatorGuidance') 'Check CSV should include operator guidance.'
            Assert-True ($checks[0].PSObject.Properties.Name -contains 'RemediationHint') 'Check CSV should include remediation hints.'
            Assert-True (@($checks | Where-Object { $_.Protocol -eq 'SMB' -and $_.EnvironmentProfile -eq 'Core SMB collection' }).Count -gt 0) 'SMB rows should explain the core collection profile.'
            Assert-True (@($checks | Where-Object { $_.Protocol -eq 'WinRM HTTP' -and $_.EnvironmentProfile -eq 'Default Windows CIM collection' }).Count -gt 0) 'WinRM rows should explain the CIM collection profile.'
            Assert-True (@($checks | Where-Object { $_.Protocol -eq 'WinRM HTTP' -and $_.OperatorGuidance -like '*without -SkipNetworkTests*' }).Count -gt 0) 'Skipped WinRM rows should tell operators how to get live reachability evidence.'
            Assert-True (@($checks | Where-Object { $_.Status -eq 'Skipped' }).Count -gt 0) 'SkipNetworkTests should keep deterministic skipped check rows.'
        }
    },
    @{
        Name = 'New-ShareSurferStandaloneDashboard packages a standalone static dashboard snapshot'
        Body = {
            Import-Module $moduleManifest -Force
            $exportPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferExport-' + [guid]::NewGuid().ToString('N'))
            $buildPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferDashboardBuild-' + [guid]::NewGuid().ToString('N'))
            $standalonePath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferStandaloneDashboard-' + [guid]::NewGuid().ToString('N'))
            $assetPath = Join-Path $buildPath 'assets'
            New-Item -ItemType Directory -Path $assetPath -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $buildPath 'index.html') -Value '<!doctype html><html><head><script src="./sharesurfer-data.js"></script><script type="module" src="./assets/index-demo.js"></script><link rel="stylesheet" href="./assets/index-demo.css"></head><body><div id="root"></div></body></html>' -Encoding UTF8
            Set-Content -LiteralPath (Join-Path $buildPath 'sharesurfer-data.js') -Value 'window.__SHARESURFER_SNAPSHOT__ = { datasets: {} };' -Encoding UTF8
            Set-Content -LiteralPath (Join-Path $assetPath 'index-demo.js') -Value 'window.ShareSurferStandaloneLoaded = true;' -Encoding UTF8
            Set-Content -LiteralPath (Join-Path $assetPath 'index-demo.css') -Value 'body { color: #0f172a; }' -Encoding UTF8

            Invoke-ShareSurferScan -InputObject (New-TestInventory) -OutputPath $exportPath -SkipIdentityEnrichment | Out-Null
            $global:ShareSurferOpenFileProvider = {
                param(
                    [string] $ComputerName,
                    [string[]] $ShareName,
                    [string] $AssessmentId,
                    [string] $SampleId,
                    [string] $SampleTimestamp,
                    [string] $Provider
                )

                [pscustomobject]@{
                    AssessmentId = $AssessmentId
                    SampleId = $SampleId
                    SampleTimestamp = $SampleTimestamp
                    ComputerName = $ComputerName
                    ShareName = 'Finance'
                    Provider = $Provider
                    FileId = '1001'
                    SessionId = '2001'
                    ClientComputerName = 'WKSTN-001'
                    ClientUserName = 'CONTOSO\Ava.Accounting'
                    Path = 'C:\Shares\Finance\AP\invoice.xlsx'
                    FolderPath = 'C:\Shares\Finance\AP'
                    ShareRelativePath = 'AP\invoice.xlsx'
                    ShareRelativeFolder = 'AP'
                    Permissions = 'Read'
                    Locks = 1
                    Source = 'MockOpenFileProvider'
                    CollectionStatus = 'Open'
                    ErrorMessage = ''
                }
            }
            try {
                Invoke-ShareSurferOpenFileAssessment -ComputerName 'files01' -ShareName 'Finance' -OutputPath $exportPath -Provider NativeRpc -IntervalSeconds 0 -SampleCount 1 -Quiet | Out-Null
            }
            finally {
                Remove-Variable -Name ShareSurferOpenFileProvider -Scope Global -ErrorAction SilentlyContinue
            }
            Invoke-ShareSurferPortProtocolAssessment -ComputerName 'files01' -ShareName 'Finance' -DirectoryServer 'dc01.contoso.test' -OutputPath $exportPath -SkipNetworkTests -Force | Out-Null
            Remove-Item -LiteralPath (Join-Path $exportPath 'owner_review_decisions.csv') -Force
            Remove-Item -LiteralPath (Join-Path $exportPath 'migration_cluster_decisions.csv') -Force

            $result = & (Join-Path $repoRoot 'scripts/New-ShareSurferStandaloneDashboard.ps1') -ExportPath $exportPath -DashboardBuildPath $buildPath -OutputPath $standalonePath -PassThru

            Assert-True $result.IsValid 'Standalone dashboard wrapper should report a valid output.'
            Assert-True (Test-Path -LiteralPath (Join-Path $standalonePath 'index.html')) 'Standalone dashboard should include index.html.'
            Assert-True (Test-Path -LiteralPath (Join-Path $standalonePath 'sharesurfer-data.js')) 'Standalone dashboard should include snapshot script.'
            Assert-True (Test-Path -LiteralPath (Join-Path $standalonePath 'dashboard-manifest.json')) 'Standalone dashboard should include a manifest.'
            Assert-True (Test-Path -LiteralPath (Join-Path (Join-Path $standalonePath 'assets') 'index-demo.js')) 'Standalone dashboard should copy relative assets.'
            Assert-True (Test-Path -LiteralPath (Join-Path $standalonePath 'datasets/sharesurfer-dataset-acl_entries.js')) 'Standalone dashboard should write lazy ACL evidence chunks.'
            Assert-True (Test-Path -LiteralPath (Join-Path $standalonePath 'datasets/sharesurfer-dataset-open_file_samples.js')) 'Standalone dashboard should write lazy open-file sample chunks when present.'

            $index = Get-Content -LiteralPath (Join-Path $standalonePath 'index.html') -Raw
            $dataScript = Get-Content -LiteralPath (Join-Path $standalonePath 'sharesurfer-data.js') -Raw
            $aclChunkScript = Get-Content -LiteralPath (Join-Path $standalonePath 'datasets/sharesurfer-dataset-acl_entries.js') -Raw
            $openFileChunkScript = Get-Content -LiteralPath (Join-Path $standalonePath 'datasets/sharesurfer-dataset-open_file_samples.js') -Raw
            $manifest = Get-Content -LiteralPath (Join-Path $standalonePath 'dashboard-manifest.json') -Raw | ConvertFrom-Json

            Assert-True ($index -like '*src="./sharesurfer-data.js"*') 'Standalone dashboard index should load snapshot through a relative script tag.'
            Assert-True ($index -like '*src="./assets/index-demo.js"*') 'Standalone dashboard index should keep relative asset paths.'
            Assert-True ($dataScript -like 'window.__SHARESURFER_SNAPSHOT__ = *') 'Snapshot script should assign the dashboard data on window.'
            Assert-True ($dataScript -like '*"snapshotKind":"export"*') 'Snapshot script should identify generated export data.'
            Assert-True ($dataScript -like '*"lazyDatasets"*') 'Snapshot script should advertise lazily packaged datasets.'
            Assert-True (-not $dataScript.Contains('"acl_entries":[{')) 'Snapshot script should not inline lazy ACL evidence rows.'
            Assert-True ($dataScript -notlike '*fetch(*') 'Snapshot script should not require fetch or a local server.'
            Assert-True ($aclChunkScript -like '*__SHARESURFER_DATASET_CHUNKS__*') 'ACL chunk should register itself through the offline script-chunk global.'
            Assert-True ($aclChunkScript -like '*"acl_entries"*') 'ACL chunk should identify the dataset key it registers.'
            Assert-True ($openFileChunkScript -like '*__SHARESURFER_DATASET_CHUNKS__*') 'Open-file sample chunk should register itself through the offline script-chunk global.'
            Assert-Equal $manifest.dashboardDataKind 'export' 'Dashboard manifest should identify generated export data.'
            Assert-True ([int]$manifest.rowCounts.shares -gt 0) 'Dashboard manifest should include export row counts.'
            Assert-True ([int]$manifest.rowCounts.acl_entries -gt 0) 'Dashboard manifest should include large raw-evidence dataset counts.'
            Assert-Equal $manifest.sizeGuardrailStatus 'WithinLimit' 'Small dashboard packages should stay within the default data-size guardrail.'
            Assert-True ([int64]$manifest.sourceDataBytes -gt 0) 'Dashboard manifest should include source CSV byte telemetry.'
            Assert-True ([int64]$manifest.bootstrapSourceDataBytes -gt 0) 'Dashboard manifest should include bootstrap source byte telemetry.'
            Assert-True ([int64]$manifest.projectedDataScriptBytes -gt 0) 'Dashboard manifest should include projected data-script byte telemetry.'
            Assert-True ([int64]$manifest.actualDataScriptBytes -gt 0) 'Dashboard manifest should include actual data-script byte telemetry.'
            Assert-True ([int64]$manifest.chunkDataScriptBytes -gt 0) 'Dashboard manifest should include lazy chunk byte telemetry.'
            Assert-True ([int64]$manifest.largestDataScriptBytes -gt 0) 'Dashboard manifest should include largest script byte telemetry.'
            Assert-True ([int64]$manifest.maximumDataScriptBytes -gt 0) 'Dashboard manifest should include the configured data-script guardrail.'
            Assert-True ([int]$manifest.lazyDatasetCount -gt 0) 'Dashboard manifest should count lazily packaged datasets.'
            Assert-Equal $manifest.lazyDatasets.acl_entries.script 'datasets/sharesurfer-dataset-acl_entries.js' 'Dashboard manifest should map ACL rows to their chunk script.'
            Assert-True ([string]::Join(';', @($manifest.bootstrapDatasetKeys)) -notlike '*acl_entries*') 'Dashboard bootstrap dataset list should not include lazy ACL rows.'
            Assert-True (@($manifest.largestDatasets).Count -gt 0) 'Dashboard manifest should name largest dataset contributors.'
            Assert-True ([int]$manifest.rowCounts.open_file_samples -gt 0) 'Dashboard manifest should include imported open-file sample counts when present.'
            Assert-True ([int]$manifest.rowCounts.open_file_summary -gt 0) 'Dashboard manifest should include imported open-file summary counts when present.'
            Assert-True ([int]$manifest.rowCounts.port_protocol_checks -gt 0) 'Dashboard manifest should include imported port/protocol check counts when present.'
            Assert-True ([string]::Join(';', @($manifest.schemaWarnings)) -notlike '*owner_review_decisions.csv*') 'Standalone dashboard packaging should not warn when optional owner decision CSVs are absent.'
            Assert-True ([string]::Join(';', @($manifest.schemaWarnings)) -notlike '*migration_cluster_decisions.csv*') 'Standalone dashboard packaging should not warn when optional migration decision CSVs are absent.'
            Assert-True ($dataScript -like '*"open_file_samples"*') 'Dashboard snapshot should advertise open-file sample chunks for raw evidence review.'
            Assert-True ($dataScript -like '*"port_protocol_checks"*') 'Dashboard snapshot should carry port/protocol datasets for connectivity review.'
        }
    },
    @{
        Name = 'New-ShareSurferStandaloneDashboard refuses oversized package without explicit override'
        Body = {
            Import-Module $moduleManifest -Force
            $exportPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferExport-' + [guid]::NewGuid().ToString('N'))
            $buildPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferDashboardBuild-' + [guid]::NewGuid().ToString('N'))
            $standalonePath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferStandaloneDashboard-' + [guid]::NewGuid().ToString('N'))
            New-Item -ItemType Directory -Path $buildPath -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $buildPath 'index.html') -Value '<!doctype html><html><head><script src="./sharesurfer-data.js"></script></head><body><div id="root"></div></body></html>' -Encoding UTF8
            Set-Content -LiteralPath (Join-Path $buildPath 'sharesurfer-data.js') -Value 'window.__SHARESURFER_SNAPSHOT__ = { snapshotKind: "template", datasets: {} };' -Encoding UTF8

            Invoke-ShareSurferScan -InputObject (New-TestInventory) -OutputPath $exportPath -SkipIdentityEnrichment | Out-Null

            $thrown = $false
            try {
                & (Join-Path $repoRoot 'scripts/New-ShareSurferStandaloneDashboard.ps1') -ExportPath $exportPath -DashboardBuildPath $buildPath -OutputPath $standalonePath -MaximumDataScriptBytes 1 -PassThru | Out-Null
            }
            catch {
                $thrown = $true
                Assert-True ($_.Exception.Message -like '*browser/runtime safety guardrail*') 'Large dashboard refusal should explain the browser/runtime safety guardrail.'
                Assert-True ($_.Exception.Message -like '*-ForceLargeDashboard*') 'Large dashboard refusal should name the explicit override switch.'
            }

            Assert-True $thrown 'Packaging should refuse an above-threshold dashboard without -ForceLargeDashboard.'
            Assert-True (Test-Path -LiteralPath (Join-Path $standalonePath 'dashboard-manifest.json')) 'Refused dashboard package should still write a manifest with guardrail evidence.'
            Assert-True (-not (Test-Path -LiteralPath (Join-Path $standalonePath 'sharesurfer-data.js'))) 'Refused dashboard package should not leave the copied template data script behind.'
            $manifest = Get-Content -LiteralPath (Join-Path $standalonePath 'dashboard-manifest.json') -Raw | ConvertFrom-Json
            Assert-Equal $manifest.sizeGuardrailStatus 'RefusedProjectedOverLimit' 'Manifest should record projected-size refusal.'
            Assert-True ([int64]$manifest.projectedDataScriptBytes -gt [int64]$manifest.maximumDataScriptBytes) 'Manifest should prove the projected size exceeded the guardrail.'
            Assert-True (@($manifest.largestDatasets).Count -gt 0) 'Manifest should preserve largest dataset contributors for troubleshooting.'
        }
    },
    @{
        Name = 'New-ShareSurferStandaloneDashboard packages oversized data when explicitly overridden'
        Body = {
            Import-Module $moduleManifest -Force
            $exportPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferExport-' + [guid]::NewGuid().ToString('N'))
            $buildPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferDashboardBuild-' + [guid]::NewGuid().ToString('N'))
            $standalonePath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferStandaloneDashboard-' + [guid]::NewGuid().ToString('N'))
            New-Item -ItemType Directory -Path $buildPath -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $buildPath 'index.html') -Value '<!doctype html><html><head><script src="./sharesurfer-data.js"></script></head><body><div id="root"></div></body></html>' -Encoding UTF8
            Set-Content -LiteralPath (Join-Path $buildPath 'sharesurfer-data.js') -Value 'window.__SHARESURFER_SNAPSHOT__ = { snapshotKind: "template", datasets: {} };' -Encoding UTF8

            Invoke-ShareSurferScan -InputObject (New-TestInventory) -OutputPath $exportPath -SkipIdentityEnrichment | Out-Null

            $result = & (Join-Path $repoRoot 'scripts/New-ShareSurferStandaloneDashboard.ps1') -ExportPath $exportPath -DashboardBuildPath $buildPath -OutputPath $standalonePath -MaximumDataScriptBytes 1 -ForceLargeDashboard -PassThru
            $manifest = Get-Content -LiteralPath (Join-Path $standalonePath 'dashboard-manifest.json') -Raw | ConvertFrom-Json

            Assert-True $result.IsValid 'Explicitly overridden large dashboard should still package.'
            Assert-True (Test-Path -LiteralPath (Join-Path $standalonePath 'sharesurfer-data.js')) 'Explicitly overridden large dashboard should write the snapshot script.'
            Assert-Equal $manifest.sizeGuardrailStatus 'ChunkOverLimitAllowed' 'Manifest should record that at least one lazy chunk exceeded the configured limit but was explicitly allowed.'
            Assert-True ([int64]$manifest.actualDataScriptBytes -gt [int64]$manifest.maximumDataScriptBytes) 'Manifest should prove the actual script exceeded the guardrail.'
            Assert-True ([int64]$manifest.chunkDataScriptBytes -gt [int64]$manifest.maximumDataScriptBytes) 'Manifest should prove a lazy chunk exceeded the guardrail.'
            Assert-True ([string]$manifest.sizeGuardrailMessage -like '*browser/runtime safety guardrail*') 'Manifest should preserve the guardrail explanation.'
            Assert-Equal $result.SizeGuardrailStatus 'ChunkOverLimitAllowed' 'PassThru result should expose the guardrail status.'
        }
    },
    @{
        Name = 'Release metadata defines the current prerelease package expectations'
        Body = {
            $releaseMetadataPath = Join-Path $repoRoot 'release-metadata.json'
            Assert-True (Test-Path -LiteralPath $releaseMetadataPath -PathType Leaf) 'Repository should keep release expectations in one metadata file.'

            $releaseMetadata = Get-Content -LiteralPath $releaseMetadataPath -Raw | ConvertFrom-Json
            $expectedTag = 'v{0}' -f $releaseMetadata.packageVersion
            $expectedPackageName = 'ShareSurfer-{0}' -f $releaseMetadata.packageVersion
            $expectedZipAssetName = '{0}.zip' -f $expectedPackageName
            $expectedReleaseUrl = 'https://github.com/jonathanweinberg/ShareSurfer/releases/tag/{0}' -f $expectedTag
            $expectedMinimumDependencyAgeDays = [int]$releaseMetadata.minimumDependencyAgeDays
            Assert-True ([string]$releaseMetadata.packageVersion -match '^0\.1\.0-pre\.\d+$') 'Release metadata should record a prerelease package version.'
            Assert-Equal $releaseMetadata.currentPrereleaseTag $expectedTag 'Release metadata should derive the current prerelease tag from the package version.'
            Assert-Equal $releaseMetadata.packageName $expectedPackageName 'Release metadata should derive the package directory name from the package version.'
            Assert-Equal $releaseMetadata.zipAssetName $expectedZipAssetName 'Release metadata should derive the zip asset name from the package version.'
            Assert-Equal $releaseMetadata.releaseUrl $expectedReleaseUrl 'Release metadata should derive the release URL from the current prerelease tag.'
            Assert-True ($expectedMinimumDependencyAgeDays -gt 0) 'Release metadata should record a positive release dependency age policy.'
            Assert-True (@($releaseMetadata.docsReferencePaths) -contains 'README.md') 'Release metadata should name README as a public release reference.'
            Assert-True (@($releaseMetadata.docsReferencePaths) -contains 'docs/first-run-guide.md') 'Release metadata should name the first-run guide as a public release reference.'
            Assert-True (@($releaseMetadata.internalPackageExcludePaths) -contains 'docs/reviews/*') 'Release metadata should exclude tracked internal review docs from packages.'
            Assert-True (@($releaseMetadata.internalPackageExcludePaths) -contains 'docs/superpowers/*') 'Release metadata should exclude tracked planning docs from packages.'

            foreach ($relativeDocPath in @($releaseMetadata.docsReferencePaths)) {
                $docPath = Join-Path $repoRoot ([string]$relativeDocPath)
                Assert-True (Test-Path -LiteralPath $docPath -PathType Leaf) ('Release metadata docs reference should exist: {0}' -f $relativeDocPath)
                $docText = Get-Content -LiteralPath $docPath -Raw
                Assert-True ($docText -like ('*{0}*' -f $releaseMetadata.currentPrereleaseTag) -or $docText -like ('*{0}*' -f $releaseMetadata.zipAssetName) -or $docText -like ('*{0}*' -f $releaseMetadata.packageName)) ('Public release doc should reference current metadata values: {0}' -f $relativeDocPath)
                $staleReleaseStrings = @([regex]::Matches($docText, 'v0\.1\.0-pre\.\d+|ShareSurfer-0\.1\.0-pre\.\d+\.zip|ShareSurfer-0\.1\.0-pre\.\d+') | ForEach-Object { $_.Value } | Where-Object {
                    $_ -ne [string]$releaseMetadata.currentPrereleaseTag -and
                    $_ -ne [string]$releaseMetadata.zipAssetName -and
                    $_ -ne [string]$releaseMetadata.packageName
                } | Sort-Object -Unique)
                Assert-Equal $staleReleaseStrings.Count 0 ('Public release doc should not contain stale prerelease strings: {0}' -f $relativeDocPath)
            }
        }
    },
    @{
        Name = 'CI workflows include runtime and release-readiness gates'
        Body = {
            $ciWorkflowPath = Join-Path $repoRoot '.github/workflows/ci.yml'
            $releaseWorkflowPath = Join-Path $repoRoot '.github/workflows/release.yml'
            Assert-True (Test-Path -LiteralPath $ciWorkflowPath -PathType Leaf) 'CI workflow should exist.'
            Assert-True (Test-Path -LiteralPath $releaseWorkflowPath -PathType Leaf) 'Release workflow should exist.'

            $ciWorkflow = Get-Content -LiteralPath $ciWorkflowPath -Raw
            $releaseWorkflow = Get-Content -LiteralPath $releaseWorkflowPath -Raw
            Assert-True ($ciWorkflow -like '*FORCE_JAVASCRIPT_ACTIONS_TO_NODE24: true*') 'CI should opt release-relevant JavaScript actions into the Node 24 runtime.'
            Assert-True ($releaseWorkflow -like '*FORCE_JAVASCRIPT_ACTIONS_TO_NODE24: true*') 'Release workflow should opt JavaScript actions into the Node 24 runtime.'
            Assert-True ($ciWorkflow -like '*windows-powershell-51:*') 'CI should include a Windows PowerShell 5.1 validation lane.'
            Assert-True ($ciWorkflow -like '*shell: powershell*') 'Windows PowerShell 5.1 lane should use the Windows PowerShell shell.'
            Assert-True ($ciWorkflow -like '*Test-ShareSurferWindowsPowerShell51.ps1*') 'CI should run the Windows PowerShell 5.1 smoke script.'
            Assert-True ($ciWorkflow -like '*Test-ShareSurferReleaseReadiness.ps1*') 'CI should run the release-readiness helper.'
            Assert-True ($ciWorkflow -like '*-DashboardBuildPath interface/standalone-dashboard/dist*') 'Release-readiness CI should reuse the built standalone dashboard assets.'
            Assert-True ($ciWorkflow -notlike '*-SkipDependencyAgeCheck*') 'Release-readiness CI should not skip dependency-age validation.'
        }
    },
    @{
        Name = 'Windows PowerShell 5.1 smoke helper validates parser and import behavior'
        Body = {
            $result = & (Join-Path $repoRoot 'scripts/Test-ShareSurferWindowsPowerShell51.ps1') -AllowPowerShellCore -PassThru
            Assert-True ([bool]$result.IsValid) 'Windows PowerShell smoke helper should report a valid compatibility check.'
            Assert-True ([int]$result.ParsedFileCount -gt 0) 'Windows PowerShell smoke helper should parse project PowerShell files.'
            Assert-True ([int]$result.RequiredCommandCount -ge 5) 'Windows PowerShell smoke helper should verify public command imports.'
            Assert-Equal $result.ModuleVersion '0.1.0' 'Windows PowerShell smoke helper should read the module manifest version.'
        }
    },
    @{
        Name = 'Release-readiness helper validates package and dependency-age evidence without publishing'
        Body = {
            $releaseMetadata = Get-Content -LiteralPath (Join-Path $repoRoot 'release-metadata.json') -Raw | ConvertFrom-Json
            $buildPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferReadinessDashboardBuild-' + [guid]::NewGuid().ToString('N'))
            $releaseOutput = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferReleaseReadiness-' + [guid]::NewGuid().ToString('N'))
            $dependencyAgeReportPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferReadinessDependencyAge-' + [guid]::NewGuid().ToString('N') + '.json')
            $assetPath = Join-Path $buildPath 'assets'
            New-Item -ItemType Directory -Path $assetPath -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $buildPath 'index.html') -Value '<!doctype html><html><head><script src="./sharesurfer-data.js"></script><script type="module" src="./assets/index-demo.js"></script></head><body><div id="root"></div></body></html>' -Encoding UTF8
            Set-Content -LiteralPath (Join-Path $buildPath 'sharesurfer-data.js') -Value 'window.__SHARESURFER_SNAPSHOT__ = { datasets: {} };' -Encoding UTF8
            Set-Content -LiteralPath (Join-Path $assetPath 'index-demo.js') -Value 'window.ShareSurferReadinessLoaded = true;' -Encoding UTF8
            Set-Content -LiteralPath $dependencyAgeReportPath -Value (@{
                isValid = $true
                skipped = $false
                minimumAgeDays = [int]$releaseMetadata.minimumDependencyAgeDays
                dependencyCount = 1
                violationCount = 0
                unknownCount = 0
                violations = @()
                unknown = @()
                dependencies = @(@{
                    name = 'react'
                    version = '18.3.1'
                    status = 'Allowed'
                    ageDays = 30
                })
            } | ConvertTo-Json -Depth 8) -Encoding UTF8

            $result = & (Join-Path $repoRoot 'scripts/Test-ShareSurferReleaseReadiness.ps1') -OutputRoot $releaseOutput -DashboardBuildPath $buildPath -DependencyAgeReportPath $dependencyAgeReportPath -SkipNpmInstall -PassThru

            Assert-True ([bool]$result.IsValid) 'Release-readiness helper should report valid readiness.'
            Assert-Equal $result.Version $releaseMetadata.packageVersion 'Release-readiness helper should package the metadata version.'
            Assert-Equal $result.CurrentPrereleaseTag $releaseMetadata.currentPrereleaseTag 'Release-readiness helper should report the metadata prerelease tag.'
            Assert-Equal ([int]$result.MinimumDependencyAgeDays) ([int]$releaseMetadata.minimumDependencyAgeDays) 'Release-readiness helper should apply the metadata dependency-age policy.'
            Assert-True (Test-Path -LiteralPath $result.PackageRoot -PathType Container) 'Release-readiness helper should create a package root.'
            Assert-True (Test-Path -LiteralPath $result.ZipPath -PathType Leaf) 'Release-readiness helper should create a zip.'
            Assert-True (Test-Path -LiteralPath $result.DependencyAgeReportPath -PathType Leaf) 'Release-readiness helper should preserve dependency-age evidence.'
        }
    },
    @{
        Name = 'Release-readiness helper rejects skipped dependency-age reports before packaging'
        Body = {
            $releaseMetadata = Get-Content -LiteralPath (Join-Path $repoRoot 'release-metadata.json') -Raw | ConvertFrom-Json
            $buildPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferSkippedAgeDashboardBuild-' + [guid]::NewGuid().ToString('N'))
            $releaseOutput = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferSkippedAgeReadiness-' + [guid]::NewGuid().ToString('N'))
            $dependencyAgeReportPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferSkippedAge-' + [guid]::NewGuid().ToString('N') + '.json')
            New-Item -ItemType Directory -Path $buildPath -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $buildPath 'index.html') -Value '<!doctype html><html><body><div id="root"></div></body></html>' -Encoding UTF8
            Set-Content -LiteralPath $dependencyAgeReportPath -Value (@{
                isValid = $true
                skipped = $true
                minimumAgeDays = [int]$releaseMetadata.minimumDependencyAgeDays
                dependencyCount = 0
                violationCount = 0
                unknownCount = 0
                violations = @()
                unknown = @()
                dependencies = @()
            } | ConvertTo-Json -Depth 8) -Encoding UTF8

            $failedClosed = $false
            try {
                & (Join-Path $repoRoot 'scripts/Test-ShareSurferReleaseReadiness.ps1') -OutputRoot $releaseOutput -DashboardBuildPath $buildPath -DependencyAgeReportPath $dependencyAgeReportPath -PassThru | Out-Null
            }
            catch {
                $failedClosed = ($_.Exception.Message -like '*supplied report is marked skipped*')
            }

            Assert-True $failedClosed 'Release-readiness helper should reject skipped dependency-age reports before packaging.'
            Assert-True (-not (Test-Path -LiteralPath (Join-Path $releaseOutput $releaseMetadata.packageName) -PathType Container)) 'Release-readiness helper should not create a package for skipped dependency-age evidence.'
            Assert-True (-not (Test-Path -LiteralPath (Join-Path $releaseOutput $releaseMetadata.zipAssetName) -PathType Leaf)) 'Release-readiness helper should not create a zip for skipped dependency-age evidence.'
        }
    },
    @{
        Name = 'New-ShareSurferRelease rejects a manual version that differs from release metadata'
        Body = {
            $releaseMetadata = Get-Content -LiteralPath (Join-Path $repoRoot 'release-metadata.json') -Raw | ConvertFrom-Json
            $buildPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferDashboardBuild-' + [guid]::NewGuid().ToString('N'))
            $releaseOutput = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferRelease-' + [guid]::NewGuid().ToString('N'))
            $dependencyAgeReportPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferDependencyAge-' + [guid]::NewGuid().ToString('N') + '.json')
            New-Item -ItemType Directory -Path $buildPath -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $buildPath 'index.html') -Value '<!doctype html><html><body><div id="root"></div></body></html>' -Encoding UTF8
            Set-Content -LiteralPath $dependencyAgeReportPath -Value (@{
                isValid = $true
                skipped = $false
                minimumAgeDays = [int]$releaseMetadata.minimumDependencyAgeDays
                dependencyCount = 0
                violationCount = 0
                unknownCount = 0
                dependencies = @()
            } | ConvertTo-Json -Depth 8) -Encoding UTF8

            $failedClosed = $false
            try {
                & (Join-Path $repoRoot 'scripts/New-ShareSurferRelease.ps1') -Version '0.1.0' -OutputRoot $releaseOutput -DashboardBuildPath $buildPath -SkipDashboardBuild -DependencyAgeReportPath $dependencyAgeReportPath -Force -PassThru | Out-Null
            }
            catch {
                $failedClosed = ($_.Exception.Message -like '*does not match release metadata*')
            }

            Assert-True $failedClosed 'Release packaging should fail closed when a manual version mismatches release metadata.'
            Assert-True (-not (Test-Path -LiteralPath (Join-Path $releaseOutput 'ShareSurfer-0.1.0.zip') -PathType Leaf)) 'Release packaging should not create a mismatched zip.'
        }
    },
    @{
        Name = 'New-ShareSurferRelease rejects invalid dependency age reports before creating a package'
        Body = {
            $releaseMetadata = Get-Content -LiteralPath (Join-Path $repoRoot 'release-metadata.json') -Raw | ConvertFrom-Json
            $buildPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferDashboardBuild-' + [guid]::NewGuid().ToString('N'))
            $releaseOutput = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferReleaseAgeFailure-' + [guid]::NewGuid().ToString('N'))
            $dependencyAgeReportPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferDependencyAgeFailure-' + [guid]::NewGuid().ToString('N') + '.json')
            New-Item -ItemType Directory -Path $buildPath -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $buildPath 'index.html') -Value '<!doctype html><html><body><div id="root"></div></body></html>' -Encoding UTF8
            Set-Content -LiteralPath $dependencyAgeReportPath -Value (@{
                isValid = $false
                skipped = $false
                minimumAgeDays = [int]$releaseMetadata.minimumDependencyAgeDays
                dependencyCount = 1
                violationCount = 1
                unknownCount = 0
                violations = @(@{
                    name = 'example-too-new'
                    version = '1.0.0'
                    status = 'TooNew'
                    ageDays = 0
                })
                unknown = @()
                dependencies = @()
            } | ConvertTo-Json -Depth 8) -Encoding UTF8

            $failedClosed = $false
            try {
                & (Join-Path $repoRoot 'scripts/New-ShareSurferRelease.ps1') -Version $releaseMetadata.packageVersion -OutputRoot $releaseOutput -DashboardBuildPath $buildPath -SkipDashboardBuild -DependencyAgeReportPath $dependencyAgeReportPath -Force -PassThru | Out-Null
            }
            catch {
                $failedClosed = ($_.Exception.Message -like '*NPM dependency age policy failed*')
            }

            Assert-True $failedClosed 'Release packaging should fail closed when dependency age validation fails.'
            Assert-True (Test-Path -LiteralPath (Join-Path $releaseOutput 'dependency-age-report.failed.json') -PathType Leaf) 'Release packaging should preserve the failed dependency age report for diagnosis.'
            Assert-True (-not (Test-Path -LiteralPath (Join-Path $releaseOutput $releaseMetadata.packageName) -PathType Container)) 'Release packaging should not create a package directory after dependency age failure.'
            Assert-True (-not (Test-Path -LiteralPath (Join-Path $releaseOutput $releaseMetadata.zipAssetName) -PathType Leaf)) 'Release packaging should not create a zip after dependency age failure.'
        }
    },
    @{
        Name = 'New-ShareSurferRelease creates an unsigned pre-1.0 package with prebuilt dashboard assets'
        Body = {
            $releaseMetadataPath = Join-Path $repoRoot 'release-metadata.json'
            $releaseMetadata = Get-Content -LiteralPath $releaseMetadataPath -Raw | ConvertFrom-Json
            $buildPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferDashboardBuild-' + [guid]::NewGuid().ToString('N'))
            $releaseOutput = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferRelease-' + [guid]::NewGuid().ToString('N'))
            $dependencyAgeReportPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferDependencyAge-' + [guid]::NewGuid().ToString('N') + '.json')
            $assetPath = Join-Path $buildPath 'assets'
            New-Item -ItemType Directory -Path $assetPath -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $buildPath 'index.html') -Value '<!doctype html><html><head><script src="./sharesurfer-data.js"></script><script type="module" src="./assets/index-demo.js"></script></head><body><div id="root"></div></body></html>' -Encoding UTF8
            Set-Content -LiteralPath (Join-Path $buildPath 'sharesurfer-data.js') -Value 'window.__SHARESURFER_SNAPSHOT__ = { datasets: {} };' -Encoding UTF8
            Set-Content -LiteralPath (Join-Path $assetPath 'index-demo.js') -Value 'window.ShareSurferReleaseLoaded = true;' -Encoding UTF8
            Set-Content -LiteralPath $dependencyAgeReportPath -Value (@{
                isValid = $true
                skipped = $false
                minimumAgeDays = [int]$releaseMetadata.minimumDependencyAgeDays
                dependencyCount = 1
                violationCount = 0
                unknownCount = 0
                dependencies = @(@{
                    name = 'react'
                    version = '18.3.1'
                    status = 'Allowed'
                    ageDays = 30
                })
            } | ConvertTo-Json -Depth 8) -Encoding UTF8

            $result = & (Join-Path $repoRoot 'scripts/New-ShareSurferRelease.ps1') -Version $releaseMetadata.packageVersion -OutputRoot $releaseOutput -DashboardBuildPath $buildPath -SkipDashboardBuild -DependencyAgeReportPath $dependencyAgeReportPath -Force -PassThru

            Assert-True $result.IsValid 'Release package should report a valid package.'
            Assert-Equal $result.Version $releaseMetadata.packageVersion 'Release result should use the metadata package version.'
            Assert-Equal $result.SigningStatus 'UnsignedPre1.0' 'Release package should record unsigned pre-1.0 status.'
            Assert-True $result.IncludesPrebuiltStandaloneDashboard 'Release package should include built dashboard assets.'
            Assert-Equal $result.MinimumDependencyAgeDays ([int]$releaseMetadata.minimumDependencyAgeDays) 'Release result should record the metadata npm dependency age policy.'
            Assert-True (Test-Path -LiteralPath $result.DependencyAgeReportPath -PathType Leaf) 'Release package should include the dependency age report.'
            Assert-True (Test-Path -LiteralPath $result.PackageRoot -PathType Container) 'Release package root should exist.'
            Assert-True (Test-Path -LiteralPath $result.ZipPath -PathType Leaf) 'Release zip should exist.'
            Assert-True (Test-Path -LiteralPath $result.ZipHashPath -PathType Leaf) 'Release zip SHA256 file should exist.'
            Assert-Equal (Split-Path -Leaf $result.ZipPath) $releaseMetadata.zipAssetName 'Release zip should use the metadata asset name.'
            Assert-True (Test-Path -LiteralPath (Join-Path $result.PackageRoot 'Start-ShareSurfer.ps1') -PathType Leaf) 'Release package should include the root startup launcher.'
            Assert-True (Test-Path -LiteralPath (Join-Path $result.PackageRoot 'interface/standalone-dashboard/dist/index.html') -PathType Leaf) 'Release package should include the prebuilt dashboard entry point.'
            Assert-True (Test-Path -LiteralPath (Join-Path $result.PackageRoot 'scripts/New-ShareSurferStandaloneDashboard.ps1') -PathType Leaf) 'Release package should include the standalone dashboard packager.'
            Assert-True (Test-Path -LiteralPath (Join-Path $result.PackageRoot 'scripts/New-ShareSurferRelease.ps1') -PathType Leaf) 'Release package should include the release packager.'
            Assert-True (-not (Test-Path -LiteralPath (Join-Path $result.PackageRoot 'docs/lab-evidence') -PathType Container)) 'Release package should not include bulky lab evidence snapshots.'
            Assert-True (-not (Test-Path -LiteralPath (Join-Path $result.PackageRoot 'docs/reviews') -PathType Container)) 'Release package should not include internal quality-review docs.'
            Assert-True (-not (Test-Path -LiteralPath (Join-Path $result.PackageRoot 'docs/superpowers') -PathType Container)) 'Release package should not include internal planning docs.'

            $manifest = Get-Content -LiteralPath $result.ManifestPath -Raw | ConvertFrom-Json
            $releaseNotes = Get-Content -LiteralPath (Join-Path $result.PackageRoot 'RELEASE.md') -Raw
            $hashes = Get-Content -LiteralPath $result.HashPath -Raw
            $zipHash = Get-Content -LiteralPath $result.ZipHashPath -Raw
            $releaseDashboardData = Get-Content -LiteralPath (Join-Path $result.PackageRoot 'interface/standalone-dashboard/dist/sharesurfer-data.js') -Raw
            $zipInspectPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferReleaseZipInspect-' + [guid]::NewGuid().ToString('N'))
            Expand-Archive -LiteralPath $result.ZipPath -DestinationPath $zipInspectPath -Force
            $zipEntries = @(Get-ChildItem -LiteralPath $zipInspectPath -File -Recurse | ForEach-Object {
                $_.FullName.Substring($zipInspectPath.Length + 1).Replace('\', '/')
            })

            Assert-Equal $manifest.packageName $releaseMetadata.packageName 'Release manifest should record the metadata package name.'
            Assert-Equal $manifest.version $releaseMetadata.packageVersion 'Release manifest should record the metadata package version.'
            Assert-Equal $manifest.currentPrereleaseTag $releaseMetadata.currentPrereleaseTag 'Release manifest should record the metadata prerelease tag.'
            Assert-Equal $manifest.releaseUrl $releaseMetadata.releaseUrl 'Release manifest should record the metadata release URL.'
            Assert-True (-not [bool]$manifest.signed) 'Release manifest should state that the package is unsigned.'
            Assert-Equal $manifest.signingStatus 'UnsignedPre1.0' 'Release manifest should keep the unsigned pre-1.0 marker.'
            Assert-True ([bool]$manifest.includesPrebuiltStandaloneDashboard) 'Release manifest should state that prebuilt dashboard assets are included.'
            Assert-Equal $manifest.dashboardAssetKind 'Template' 'Release manifest should state that bundled dashboard assets are templates, not scan data.'
            Assert-True ([bool]$manifest.dashboardRequiresExportPackaging) 'Release manifest should say release dashboard assets need export packaging before real review.'
            Assert-Equal $manifest.minimumDependencyAgeDays ([int]$releaseMetadata.minimumDependencyAgeDays) 'Release manifest should record the metadata minimum npm dependency age.'
            Assert-Equal $manifest.dependencyAgeReport 'dependency-age-report.json' 'Release manifest should point to the dependency age report.'
            Assert-True (-not [bool]$manifest.dependencyAgeCheckSkipped) 'Release manifest should show that the dependency age check was not skipped.'
            Assert-Equal $manifest.dashboardEntryPoint 'interface/standalone-dashboard/dist/index.html' 'Release manifest should name the dashboard entry point.'
            Assert-True ($releaseDashboardData -like '*"snapshotKind":"template"*') 'Release dashboard data placeholder should identify template assets.'
            Assert-True ($releaseNotes -like ('*at least {0} days old*' -f [int]$releaseMetadata.minimumDependencyAgeDays)) 'Release notes should describe the metadata npm dependency age policy.'
            Assert-True ($releaseNotes -like '*template dashboard assets*') 'Release notes should call bundled dashboard assets templates.'
            Assert-True ($releaseNotes -like '*No npm, Vite, development server, or internet access*') 'Release notes should explain offline dashboard use after unpacking.'
            Assert-True ($releaseNotes -like '*## Highlights*' -and $releaseNotes -like '*Zone.Identifier*') 'Release notes should include operator-facing highlights for startup unblock behavior.'
            Assert-True ($releaseNotes -like '*## Operator Impact*' -and $releaseNotes -like '*generated evidence files*' -and $releaseNotes -like '*explicit operator choice*') 'Release notes should explain the startup review and launch handoff.'
            Assert-True ($hashes -like '*interface/standalone-dashboard/dist/index.html*') 'Release package hash file should include the prebuilt dashboard entry point.'
            Assert-True ($hashes -like '*dependency-age-report.json*') 'Release package hash file should include the dependency age report.'
            Assert-True ($zipHash -like ('*{0}*' -f $releaseMetadata.zipAssetName)) 'Release zip hash should name the release archive.'
            Assert-True (@($zipEntries | Where-Object { $_ -like '*/Start-ShareSurfer.ps1' }).Count -gt 0) 'Release zip should include the root startup launcher.'
            Assert-True (@($zipEntries | Where-Object { $_ -like '*/interface/standalone-dashboard/dist/index.html' }).Count -gt 0) 'Release zip should include the prebuilt dashboard entry point.'
            Assert-True (@($zipEntries | Where-Object { $_ -like '*/interface/standalone-dashboard/dist/assets/index-demo.js' }).Count -gt 0) 'Release zip should include prebuilt dashboard assets.'
            Assert-True (@($zipEntries | Where-Object { $_ -like '*/docs/reviews/*' }).Count -eq 0) 'Release zip should exclude internal quality-review docs.'
            Assert-True (@($zipEntries | Where-Object { $_ -like '*/docs/superpowers/*' }).Count -eq 0) 'Release zip should exclude internal planning docs.'
        }
    },
    @{
        Name = 'Test-ShareSurferReleaseReadiness creates a no-publish package and dependency age report'
        Body = {
            $releaseMetadata = Get-Content -LiteralPath (Join-Path $repoRoot 'release-metadata.json') -Raw | ConvertFrom-Json
            $buildPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferDashboardBuild-' + [guid]::NewGuid().ToString('N'))
            $assetPath = Join-Path $buildPath 'assets'
            $outputRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferReleaseReadiness-' + [guid]::NewGuid().ToString('N'))
            New-Item -ItemType Directory -Path $assetPath -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $buildPath 'index.html') -Value '<!doctype html><html><head><script src="./sharesurfer-data.js"></script><script type="module" src="./assets/index-demo.js"></script></head><body><div id="root"></div></body></html>' -Encoding UTF8
            Set-Content -LiteralPath (Join-Path $buildPath 'sharesurfer-data.js') -Value 'window.__SHARESURFER_SNAPSHOT__ = { datasets: {} };' -Encoding UTF8
            Set-Content -LiteralPath (Join-Path $assetPath 'index-demo.js') -Value 'window.ShareSurferReleaseReadinessLoaded = true;' -Encoding UTF8

            $result = & (Join-Path $repoRoot 'scripts/Test-ShareSurferReleaseReadiness.ps1') -OutputRoot $outputRoot -DashboardBuildPath $buildPath -SkipDependencyAgeNetwork -PassThru

            Assert-True $result.IsValid 'Release readiness check should return a valid result.'
            Assert-Equal $result.Version $releaseMetadata.packageVersion 'Release readiness check should use the metadata package version.'
            Assert-Equal $result.MinimumDependencyAgeDays ([int]$releaseMetadata.minimumDependencyAgeDays) 'Release readiness should use the metadata dependency age policy.'
            Assert-True (Test-Path -LiteralPath $result.PackageRoot -PathType Container) 'Release readiness should create an unpacked package.'
            Assert-True (Test-Path -LiteralPath $result.ZipPath -PathType Leaf) 'Release readiness should create a zip artifact.'
            Assert-True (Test-Path -LiteralPath $result.DependencyAgeReportPath -PathType Leaf) 'Release readiness should create a dependency age report.'
            Assert-True (-not [bool]$result.DependencyAgeCheckSkipped) 'Release readiness should exercise dependency age report validation instead of skipping it.'
            $dependencyAgeReport = Get-Content -LiteralPath $result.DependencyAgeReportPath -Raw | ConvertFrom-Json
            Assert-True ([bool]$dependencyAgeReport.isValid) 'Generated dependency age report should be valid.'
            Assert-True (-not [bool]$dependencyAgeReport.skipped) 'Generated dependency age report should not be marked skipped.'
            Assert-Equal $dependencyAgeReport.minimumAgeDays ([int]$releaseMetadata.minimumDependencyAgeDays) 'Generated dependency age report should record the metadata age policy.'
            Assert-True ([int]$dependencyAgeReport.dependencyCount -gt 0) 'Generated dependency age report should enumerate package-lock dependencies.'
            Assert-Equal ([int]$dependencyAgeReport.violationCount) 0 'Generated dependency age report should have no violations in no-network mode.'
            Assert-Equal ([int]$dependencyAgeReport.unknownCount) 0 'Generated dependency age report should have no unknown packages in no-network mode.'
        }
    },
    @{
        Name = 'Test-ShareSurferReleaseReadiness preserves existing output unless forced'
        Body = {
            $releaseMetadata = Get-Content -LiteralPath (Join-Path $repoRoot 'release-metadata.json') -Raw | ConvertFrom-Json
            $buildPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferReadinessForceDashboardBuild-' + [guid]::NewGuid().ToString('N'))
            $assetPath = Join-Path $buildPath 'assets'
            $outputRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferReleaseReadinessForce-' + [guid]::NewGuid().ToString('N'))
            $packageRoot = Join-Path $outputRoot $releaseMetadata.packageName
            $markerPath = Join-Path $packageRoot 'keep-marker.txt'
            New-Item -ItemType Directory -Path $assetPath -Force | Out-Null
            New-Item -ItemType Directory -Path $packageRoot -Force | Out-Null
            Set-Content -LiteralPath $markerPath -Value 'do not replace without force' -Encoding UTF8
            Set-Content -LiteralPath (Join-Path $buildPath 'index.html') -Value '<!doctype html><html><head><script src="./sharesurfer-data.js"></script><script type="module" src="./assets/index-demo.js"></script></head><body><div id="root"></div></body></html>' -Encoding UTF8
            Set-Content -LiteralPath (Join-Path $buildPath 'sharesurfer-data.js') -Value 'window.__SHARESURFER_SNAPSHOT__ = { datasets: {} };' -Encoding UTF8
            Set-Content -LiteralPath (Join-Path $assetPath 'index-demo.js') -Value 'window.ShareSurferReleaseReadinessLoaded = true;' -Encoding UTF8

            $failedClosed = $false
            try {
                & (Join-Path $repoRoot 'scripts/Test-ShareSurferReleaseReadiness.ps1') -OutputRoot $outputRoot -DashboardBuildPath $buildPath -SkipDependencyAgeNetwork -PassThru | Out-Null
            }
            catch {
                $failedClosed = ($_.Exception.Message -like '*Release output already exists*')
            }

            Assert-True $failedClosed 'Release readiness should honor the release packager force contract.'
            Assert-True (Test-Path -LiteralPath $markerPath -PathType Leaf) 'Release readiness should preserve existing package output when -Force is not supplied.'
        }
    },
    @{
        Name = 'Test-ShareSurferReleaseReadiness fails closed when dashboard build is missing'
        Body = {
            $outputRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferReleaseReadinessFailure-' + [guid]::NewGuid().ToString('N'))
            $missingBuildPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferMissingDashboardBuild-' + [guid]::NewGuid().ToString('N'))
            $failedClosed = $false

            try {
                & (Join-Path $repoRoot 'scripts/Test-ShareSurferReleaseReadiness.ps1') -OutputRoot $outputRoot -DashboardBuildPath $missingBuildPath -SkipDependencyAgeNetwork -PassThru | Out-Null
            }
            catch {
                $failedClosed = ($_.Exception.Message -like '*Dashboard build output not found*')
            }

            Assert-True $failedClosed 'Release readiness should fail closed when dashboard build assets are missing.'
            Assert-True (-not (Test-Path -LiteralPath $outputRoot -PathType Container)) 'Release readiness should not create output after a missing dashboard build failure.'
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
            $global:ShareSurferOpenFileProvider = {
                param(
                    [string] $ComputerName,
                    [string[]] $ShareName,
                    [string] $AssessmentId,
                    [string] $SampleId,
                    [string] $SampleTimestamp,
                    [string] $Provider
                )

                [pscustomobject]@{
                    AssessmentId = $AssessmentId
                    SampleId = $SampleId
                    SampleTimestamp = $SampleTimestamp
                    ComputerName = $ComputerName
                    ShareName = if ($ShareName.Count -gt 0) { [string]$ShareName[0] } else { 'Finance' }
                    Provider = $Provider
                    FileId = '1001'
                    SessionId = '2001'
                    ClientComputerName = 'WKSTN-001'
                    ClientUserName = 'CONTOSO\Ava.Accounting'
                    Path = 'C:\Shares\Finance\AP\invoice.xlsx'
                    FolderPath = 'C:\Shares\Finance\AP'
                    ShareRelativePath = 'AP\invoice.xlsx'
                    ShareRelativeFolder = 'AP'
                    Permissions = 'Read'
                    Locks = 1
                    Source = 'MockOpenFileProvider'
                    CollectionStatus = 'Open'
                    ErrorMessage = ''
                }
            }
            try {
                Invoke-ShareSurferOpenFileAssessment -ComputerName 'files01' -ShareName 'Finance' -OutputPath $outputPath -Provider NativeRpc -IntervalSeconds 0 -SampleCount 1 -Quiet | Out-Null
            }
            finally {
                Remove-Variable -Name ShareSurferOpenFileProvider -Scope Global -ErrorAction SilentlyContinue
            }

            $reportResult = ConvertTo-ShareSurferReport -ExportPath $outputPath -OutputPath $reportPath
            $report = Get-Content -LiteralPath $reportPath -Raw

            Assert-True ([Int64]$reportResult.InlineDataBytes -gt 0) 'Report generation should return inline data size telemetry.'
            Assert-Equal $reportResult.SizeGuardrailStatus 'WithinLimit' 'Small reports should remain within the default inline-data guardrail.'
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
            Assert-True ($report -like '*Potential Service Accounts*') 'Report should expose potential service account candidates for review.'
            Assert-True ($report -like '*potential-service-accounts*') 'Report should render a potential service accounts table.'
            Assert-True ($report -like '*buildPotentialServiceAccountRows*') 'Report should dynamically build potential service account rows from identity exports.'
            Assert-True ($report -like '*ManagerLevel3*') 'Report should include third-level manager context in org rollups.'
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
            Assert-True ($report -like '*Selected Related Data Area Detail*') 'Report should include a selected-cluster detail panel for related data areas.'
            Assert-True ($report -like '*C Hybrid ranked list*') 'Report should describe the selected C Hybrid migration discovery presentation.'
            Assert-True ($report -like '*Adaptive Rows*') 'Report should describe adaptive row behavior for migration discovery.'
            Assert-True ($report -like '*Progressive Chips*') 'Report should expose progressive chip semantics for migration discovery rows.'
            Assert-True ($report -like '*Core Five*') 'Report should mention Core Five chips in the selected detail behavior.'
            Assert-True ($report -like '*Narrative Plus Evidence Blocks*') 'Report should use the accepted selected-cluster detail model.'
            $migrationDetailMatch = [regex]::Match($report, '<section class="view-panel" id="view-migration"[\s\S]*?<section class="view-panel" id="view-access"')
            Assert-True $migrationDetailMatch.Success 'Selected related data area detail should use an attached migration detail layout.'
            $migrationDetailHtml = $migrationDetailMatch.Value
            Assert-True ($migrationDetailHtml -like '*migration-guided-evidence*') 'Selected detail should include stacked guided evidence sections.'
            Assert-True ($migrationDetailHtml -like '*migration-raw-evidence-drawer*') 'Selected detail should include a right-side raw evidence drawer.'
            Assert-True ($migrationDetailHtml -like '*Evidence Type Selector*') 'Raw evidence drawer should expose the accepted evidence type selector model.'
            foreach ($evidenceType in @('Relationship proof', 'Access proof', 'Migration blockers', 'Discounted access', 'Raw CSV rows')) {
                Assert-True ($migrationDetailHtml -like ('*{0}*' -f $evidenceType)) ("Raw evidence drawer should include evidence type option {0}." -f $evidenceType)
            }
            foreach ($sectionId in @('migration-evidence-cluster-summary', 'migration-evidence-relationship', 'migration-evidence-readiness', 'migration-evidence-discounted', 'migration-evidence-shortcuts')) {
                Assert-True ($migrationDetailHtml -like ('*{0}*' -f $sectionId)) ("Guided evidence stack should include section {0}." -f $sectionId)
            }
            Assert-True ($report -like '*buildSelectedClusterEvidenceRows*') 'Raw evidence drawer should derive filtered evidence rows for the selected cluster.'
            Assert-True ($report -like '*renderMigrationEvidenceDrawer*') 'Raw evidence drawer should rerender when the selected cluster or evidence type changes.'
            Assert-True ($report -like '*getClusterMatchedShareIds*') 'Raw evidence drawer should filter exact export rows through selected-cluster share/item context.'
            Assert-True ($report -like '*migrationEvidenceDrawerDisplayLimit = 75*') 'Raw evidence drawer should declare a fixed display cap.'
            Assert-True ($report -like '*TotalMatchedRows*') 'Raw evidence drawer should track total filtered rows separately from displayed rows.'
            Assert-True ($report -like '*appendClusterEvidenceSource*') 'Raw evidence drawer should cap row construction before building display rows.'
            Assert-True ($report -like '*relationship-signal-filter*') 'Report should include a first-class relationship signal filter.'
            Assert-True ($report -like '*readiness-signal-filter*') 'Report should include a first-class readiness signal filter.'
            Assert-True ($report -like '*buildMigrationDiscoveryRows*') 'Report should dynamically derive related data areas from existing CSV exports.'
            Assert-True ($report -like '*RelatedBecause*') 'Migration discovery should explain why rows were grouped.'
            Assert-True ($report -like '*focusMigrationArea*') 'Migration discovery rows should focus owner and business-unit review filters.'
            Assert-True ($report -like '*Raw Evidence Tables*') 'Report should expose a secondary raw evidence table browser.'
            Assert-True ($report -like '*raw-dataset-filter*') 'Raw evidence view should let operators choose a normalized dataset.'
            Assert-True ($report -like '*renderRawEvidence*') 'Raw evidence view should dynamically render embedded CSV-shaped rows.'
            Assert-True ($report -like '*rawDatasetLabels*') 'Raw evidence view should present friendly dataset labels.'
            Assert-True ($report -like '*owner_review_packets.csv*') 'Raw evidence view should expose owner review packets.'
            Assert-True ($report -like '*open_file_summary.csv*') 'Raw evidence view should expose optional open-file activity summaries when present.'
            Assert-True ($report -like '*open_file_samples*') 'Report data should embed optional open-file sample rows when present.'
            Assert-True ($report -like '*min-width: 760px*') 'Report tables should remain readable inside horizontal scroll containers on mobile.'
            Assert-True ($report -like '*.summary, .visual-grid { grid-template-columns: 1fr; }*') 'Report summary and visual grids should collapse cleanly on mobile.'
        }
    },
    @{
        Name = 'ConvertTo-ShareSurferReport refuses oversized inline reports unless explicitly forced'
        Body = {
            Import-Module $moduleManifest -Force
            $outputPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferReportGuardrail-' + [guid]::NewGuid().ToString('N'))
            $reportPath = Join-Path $outputPath 'report.html'

            Invoke-ShareSurferScan -InputObject (New-TestInventory) -OutputPath $outputPath -SkipIdentityEnrichment -Quiet | Out-Null

            $failedClosed = $false
            $message = ''
            try {
                ConvertTo-ShareSurferReport -ExportPath $outputPath -OutputPath $reportPath -MaximumInlineDataBytes 1 | Out-Null
            }
            catch {
                $message = [string]$_.Exception.Message
                $failedClosed = ($message -like '*Legacy report inline data*' -and $message -like '*packaged standalone dashboard*' -and $message -like '*-ForceLargeReport*')
            }

            Assert-True $failedClosed 'Legacy report guardrail should fail closed with guidance when inline data exceeds the configured limit.'
            Assert-True (-not (Test-Path -LiteralPath $reportPath -PathType Leaf)) 'Refused oversized legacy report should not leave report.html behind.'

            $forcedResult = ConvertTo-ShareSurferReport -ExportPath $outputPath -OutputPath $reportPath -MaximumInlineDataBytes 1 -ForceLargeReport
            Assert-True (Test-Path -LiteralPath $reportPath -PathType Leaf) 'Explicitly forced legacy report should still write report.html.'
            Assert-Equal $forcedResult.SizeGuardrailStatus 'InlineDataOverLimitAllowed' 'Forced oversized reports should record that the inline-data guardrail was overridden.'
            Assert-True ([Int64]$forcedResult.InlineDataBytes -gt 1) 'Forced report result should return the measured inline data size.'
            Assert-True (@($forcedResult.LargestDatasets).Count -gt 0) 'Forced report result should identify largest source datasets for troubleshooting.'
        }
    },
    @{
        Name = 'Start-ShareSurferNativeViewer validates export-shaped data without launching a browser UI'
        Body = {
            Import-Module $moduleManifest -Force
            $outputPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferNativeViewer-' + [guid]::NewGuid().ToString('N'))
            $viewerScript = Join-Path $repoRoot 'scripts/Start-ShareSurferNativeViewer.ps1'

            Invoke-ShareSurferScan -InputObject (New-TestInventory) -OutputPath $outputPath -SkipIdentityEnrichment -AclExportMode Compact -Quiet | Out-Null
            $result = & $viewerScript -ExportPath $outputPath -ValidateOnly -PassThru
            $scriptText = Get-Content -LiteralPath $viewerScript -Raw

            Assert-Equal $result.ViewerMode 'HeadlessValidation' 'Native viewer validation mode should not launch WinForms.'
            Assert-True ([int]$result.DatasetCount -gt 5) 'Native viewer should discover multiple ShareSurfer CSV datasets.'
            Assert-True ([int]$result.TotalRows -gt 0) 'Native viewer should report export row counts.'
            Assert-Equal $result.AclExportMode 'Compact' 'Native viewer should read scan manifest context without loading a dashboard payload.'
            Assert-True (@($result.Datasets | Where-Object { $_.DatasetKey -eq 'owner_review_packets' }).Count -eq 1) 'Native viewer should expose owner review packets.'
            Assert-True (@($result.Datasets | Where-Object { $_.DatasetKey -eq 'findings' }).Count -eq 1) 'Native viewer should expose findings.'
            Assert-True ($scriptText -like '*System.Windows.Forms*') 'Native viewer should use Windows native forms for GUI mode.'
            Assert-True ($scriptText -notlike '*sharesurfer-data.js*') 'Native viewer should not package export data into the standalone dashboard JavaScript payload.'
            Assert-True ($scriptText -notlike '*Microsoft.Web.WebView2*') 'Native viewer should avoid WebView2 runtime dependencies by design.'
        }
    },
    @{
        Name = 'Start-ShareSurferNativeViewer handles header-only CSVs and missing export paths clearly'
        Body = {
            $outputPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferNativeViewerEmptyCsv-' + [guid]::NewGuid().ToString('N'))
            $viewerScript = Join-Path $repoRoot 'scripts/Start-ShareSurferNativeViewer.ps1'
            New-Item -ItemType Directory -Path $outputPath -Force | Out-Null

            @(
                [pscustomobject]@{
                    ScanId = 'scan-empty-csv'
                    GeneratedAt = '2026-07-07T00:00:00Z'
                    AclExportMode = 'Compact'
                }
            ) | Export-Csv -LiteralPath (Join-Path $outputPath 'scan_manifest.csv') -NoTypeInformation
            'HeaderOne,HeaderTwo' | Set-Content -LiteralPath (Join-Path $outputPath 'empty_dataset.csv') -Encoding UTF8

            $result = & $viewerScript -ExportPath $outputPath -ValidateOnly -PassThru
            $emptyDataset = @($result.Datasets | Where-Object { $_.DatasetKey -eq 'empty_dataset' })[0]

            Assert-Equal ([Int64]$result.TotalRows) 1 'Native viewer summary should keep Int64 row totals.'
            Assert-Equal ([int]$emptyDataset.RowCount) 0 'Header-only CSV should be reported as zero data rows.'
            Assert-True (@($emptyDataset.Columns) -contains 'HeaderOne') 'Header-only CSV should still expose its first header column.'
            Assert-True (@($emptyDataset.Columns) -contains 'HeaderTwo') 'Header-only CSV should still expose its second header column.'

            $missingMessage = ''
            try {
                & $viewerScript -ExportPath (Join-Path $outputPath 'missing-export') -ValidateOnly | Out-Null
            }
            catch {
                $missingMessage = [string]$_.Exception.Message
            }

            Assert-True ($missingMessage -like '*ShareSurfer export folder was not found*') 'Missing export paths should fail with friendly ShareSurfer guidance.'
        }
    },
    @{
        Name = 'Invoke-ShareSurferScan discovers local shares by path during target path scans'
        Body = {
            Import-Module $moduleManifest -Force
            $targetPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferTarget-' + [guid]::NewGuid().ToString('N'))
            New-Item -ItemType Directory -Path $targetPath -Force | Out-Null
            function global:Get-SmbShare {
                param([string] $Name)
                @(
                    [pscustomobject]@{
                        Name = 'C$'
                        Path = $targetPath
                        Description = 'Mocked matching admin share'
                        Special = $true
                    },
                    [pscustomobject]@{
                        Name = 'Finance'
                        Path = $targetPath
                        Description = 'Mocked matching local share'
                        Special = $false
                    }
                )
            }
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
                $events = Import-Csv -LiteralPath (Join-Path $outputPath 'scan_events.csv')

                Assert-True ($sharePermissions.Identity -contains 'CONTOSO\MockShareReaders') 'TargetPath scans should collect share-level permissions when Get-SmbShareAccess is available.'
                Assert-Equal $shares[0].PartialData 'False' 'Share data should not be partial when share permissions were collected.'
                Assert-Equal $shares[0].ShareName 'Finance' 'TargetPath scans should prefer a non-special matching local share over an admin share.'
                Assert-True (@($events | Where-Object { $_.EventType -eq 'MultipleLocalSharesMatchedPath' -and $_.Detail -like '*C$*' }).Count -eq 1) 'TargetPath scans should record additional local share names that matched the same path.'
            }
            finally {
                Remove-Item -Path function:\Get-SmbShare -ErrorAction SilentlyContinue
                Remove-Item -Path function:\Get-SmbShareAccess -ErrorAction SilentlyContinue
            }
        }
    },
    @{
        Name = 'Invoke-ShareSurferScan skips name-coincident local share permissions when paths differ'
        Body = {
            Import-Module $moduleManifest -Force
            $targetPath = Join-Path ([System.IO.Path]::GetTempPath()) 'Finance'
            if (Test-Path -LiteralPath $targetPath) {
                Remove-Item -LiteralPath $targetPath -Recurse -Force
            }
            New-Item -ItemType Directory -Path $targetPath -Force | Out-Null
            function global:Get-SmbShare {
                param([string] $Name)
                [pscustomobject]@{
                    Name = $Name
                    Path = (Join-Path ([System.IO.Path]::GetTempPath()) 'DifferentFinanceShare')
                    Description = 'Mocked nonmatching local share'
                }
            }
            function global:Get-SmbShareAccess {
                throw 'Get-SmbShareAccess should not be called for a nonmatching local folder/share path.'
            }
            try {
                $outputPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferLocalMismatch-' + [guid]::NewGuid().ToString('N'))
                Invoke-ShareSurferScan -TargetPath $targetPath -OutputPath $outputPath -SkipIdentityEnrichment | Out-Null
                $sharePermissions = @(Import-Csv -LiteralPath (Join-Path $outputPath 'share_permissions.csv'))
                $shares = @(Import-Csv -LiteralPath (Join-Path $outputPath 'shares.csv'))
                $collectionErrors = @(Import-Csv -LiteralPath (Join-Path $outputPath 'collection_errors.csv'))
                $events = @(Import-Csv -LiteralPath (Join-Path $outputPath 'scan_events.csv'))

                Assert-Equal $sharePermissions.Count 0 'Name-coincident local folder scans should not attach share permissions from a different share path.'
                Assert-Equal $shares[0].PartialData 'True' 'Local folder scan should stay partial when the share gate cannot be verified.'
                Assert-True ($collectionErrors.ErrorType -contains 'SharePermissionVerificationSkipped') 'Collection errors should explain local share path verification skip.'
                Assert-True ($events.EventType -contains 'SharePermissionVerificationSkipped') 'Scan events should record the local share path verification skip.'
            }
            finally {
                Remove-Item -Path function:\Get-SmbShare -ErrorAction SilentlyContinue
                Remove-Item -Path function:\Get-SmbShareAccess -ErrorAction SilentlyContinue
            }
        }
    },
    @{
        Name = 'Invoke-ShareSurferScan records when only a special local share matches'
        Body = {
            Import-Module $moduleManifest -Force
            $targetPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferTargetSpecial-' + [guid]::NewGuid().ToString('N'))
            New-Item -ItemType Directory -Path $targetPath -Force | Out-Null
            function global:Get-SmbShare {
                param([string] $Name)
                [pscustomobject]@{
                    Name = 'C$'
                    Path = $targetPath
                    Description = 'Mocked matching admin share'
                    Special = $true
                }
            }
            function global:Get-SmbShareAccess {
                param([string] $Name)
                [pscustomobject]@{
                    Name = $Name
                    AccountName = 'BUILTIN\Administrators'
                    AccessRight = 'Full'
                    AccessControlType = 'Allow'
                }
            }
            try {
                $outputPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferSpecialShare-' + [guid]::NewGuid().ToString('N'))
                Invoke-ShareSurferScan -TargetPath $targetPath -OutputPath $outputPath -SkipIdentityEnrichment | Out-Null
                $shares = @(Import-Csv -LiteralPath (Join-Path $outputPath 'shares.csv'))
                $events = @(Import-Csv -LiteralPath (Join-Path $outputPath 'scan_events.csv'))

                Assert-Equal $shares[0].ShareName 'C$' 'TargetPath scans should fall back to a special share when it is the only matching local share.'
                Assert-True (@($events | Where-Object { $_.EventType -eq 'SpecialLocalShareSelected' -and $_.Message -like '*special/admin local SMB share*' }).Count -eq 1) 'TargetPath scans should record when only special/admin share evidence is available.'
            }
            finally {
                Remove-Item -Path function:\Get-SmbShare -ErrorAction SilentlyContinue
                Remove-Item -Path function:\Get-SmbShareAccess -ErrorAction SilentlyContinue
            }
        }
    },
    @{
        Name = 'Invoke-ShareSurferScan enumerates explicit reparse-point targets while skipping child reparse points'
        Body = {
            Import-Module $moduleManifest -Force
            $rootPath = 'C:\ShareSurferMountRoot'
            $childPath = 'C:\ShareSurferMountRoot\Child'
            $linkPath = 'C:\ShareSurferMountRoot\LinkedChild'

            function global:Get-Item {
                param([string] $LiteralPath)
                [pscustomobject]@{
                    FullName = $rootPath
                    Name = 'ShareSurferMountRoot'
                    PSIsContainer = $true
                    Attributes = ([System.IO.FileAttributes]::Directory -bor [System.IO.FileAttributes]::ReparsePoint)
                }
            }
            function global:Get-ChildItem {
                param([string] $LiteralPath)
                $normalizedLiteralPath = [string]$LiteralPath
                if ($normalizedLiteralPath.StartsWith('\\?\', [System.StringComparison]::Ordinal)) {
                    $normalizedLiteralPath = $normalizedLiteralPath.Substring(4)
                }
                if ($normalizedLiteralPath -eq $rootPath) {
                    return @(
                        [pscustomobject]@{
                            FullName = $childPath
                            Name = 'Child'
                            PSIsContainer = $true
                            Attributes = [System.IO.FileAttributes]::Directory
                        },
                        [pscustomobject]@{
                            FullName = $linkPath
                            Name = 'LinkedChild'
                            PSIsContainer = $true
                            Attributes = ([System.IO.FileAttributes]::Directory -bor [System.IO.FileAttributes]::ReparsePoint)
                        }
                    )
                }
                @()
            }
            function global:Get-Acl {
                param([string] $LiteralPath)
                [pscustomobject]@{
                    Owner = 'CONTOSO\DataOwner'
                    AreAccessRulesProtected = $false
                    Access = @()
                }
            }
            function global:Get-SmbShare {
                param([string] $Name)
                [pscustomobject]@{
                    Name = $Name
                    Path = $rootPath
                    Description = 'Mocked mount-point share'
                }
            }
            function global:Get-SmbShareAccess {
                @()
            }
            try {
                $outputPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferReparseTarget-' + [guid]::NewGuid().ToString('N'))
                Invoke-ShareSurferScan -TargetPath $rootPath -OutputPath $outputPath -SkipIdentityEnrichment | Out-Null
                $items = @(Import-Csv -LiteralPath (Join-Path $outputPath 'items.csv'))
                $events = @(Import-Csv -LiteralPath (Join-Path $outputPath 'scan_events.csv'))

                Assert-True ($items.FullPath -contains $rootPath) 'Explicit reparse-point target should be recorded as an item.'
                Assert-True ($items.FullPath -contains $childPath) 'Explicit reparse-point target should still be enumerated.'
                Assert-True ($items.FullPath -contains $linkPath) 'Child reparse-point directories should be recorded as items.'
                Assert-True ($events.EventType -contains 'ReparsePointTargetEnumerated') 'Scan events should state that an explicit reparse-point target was enumerated by intent.'
                Assert-True ($events.EventType -contains 'ReparsePointSkipped') 'Child reparse-point directories should still be skipped and logged.'
            }
            finally {
                Remove-Item -Path function:\Get-Item -ErrorAction SilentlyContinue
                Remove-Item -Path function:\Get-ChildItem -ErrorAction SilentlyContinue
                Remove-Item -Path function:\Get-Acl -ErrorAction SilentlyContinue
                Remove-Item -Path function:\Get-SmbShare -ErrorAction SilentlyContinue
                Remove-Item -Path function:\Get-SmbShareAccess -ErrorAction SilentlyContinue
            }
        }
    },
    @{
        Name = 'Invoke-ShareSurferScan uses native share-permission fallback during UNC target path scans'
        Body = {
            Import-Module $moduleManifest -Force

            function global:Get-Item {
                param(
                    [string] $LiteralPath
                )
                [pscustomobject]@{
                    FullName = $LiteralPath
                    Name = 'Finance'
                    PSIsContainer = $true
                }
            }

            function global:Get-ChildItem {
                param(
                    [string] $LiteralPath,
                    [switch] $Recurse,
                    [switch] $Force
                )
                @()
            }

            function global:Get-Acl {
                param(
                    [string] $LiteralPath
                )
                [pscustomobject]@{
                    Owner = 'CONTOSO\DataOwner'
                    AreAccessRulesProtected = $false
                    Access = @()
                }
            }

            function global:Get-SmbShareAccess {
                @()
            }

            $global:ShareSurferSmbRpcShareInfoProvider = {
                param(
                    [string] $ComputerName,
                    [string] $ShareName
                )
                [pscustomobject]@{
                    ShareName = $ShareName
                    Path = 'C:\SanPresentedPath\Finance'
                    Description = 'Mocked SAN share metadata'
                    Source = 'SmbRpcNetShareGetInfo'
                    ResultCode = 0
                    SharePermissions = @(
                        [pscustomobject]@{
                            Identity = 'CONTOSO\NativeShareReaders'
                            Rights = 'Read'
                            AccessMask = '0x00120089'
                            AccessControlType = 'Allow'
                            Source = 'NativeSmbRpc'
                        }
                    )
                }
            }

            try {
                $outputPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferNativeTargetExport-' + [guid]::NewGuid().ToString('N'))
                Invoke-ShareSurferScan -TargetPath '\\remote-files07\Finance' -OutputPath $outputPath -SkipIdentityEnrichment | Out-Null
                $shares = @(Import-Csv -LiteralPath (Join-Path $outputPath 'shares.csv'))
                $permissions = @(Import-Csv -LiteralPath (Join-Path $outputPath 'share_permissions.csv'))
                $collectionErrors = @(Import-Csv -LiteralPath (Join-Path $outputPath 'collection_errors.csv'))
                $events = @(Import-Csv -LiteralPath (Join-Path $outputPath 'scan_events.csv'))

                Assert-Equal $shares[0].Source 'NativeSmbRpc' 'UNC target path scans should record native fallback as the share-permission evidence source.'
                Assert-Equal $shares[0].PartialData 'False' 'UNC target path scans should not remain partial when NativeSmbRpc proves share-level permissions.'
                Assert-True ($permissions.Identity -contains 'CONTOSO\NativeShareReaders') 'UNC target path scans should export NativeSmbRpc share permission rows.'
                Assert-True ($permissions.Source -contains 'NativeSmbRpc') 'Native fallback rows should preserve NativeSmbRpc provenance.'
                Assert-True (@($collectionErrors | Where-Object { $_.ErrorType -eq 'SharePermissionCollectionUnavailable' }).Count -eq 0) 'Native fallback should suppress the generic missing share-permission warning when it succeeds.'
                Assert-True (($events | Where-Object { $_.EventType -eq 'SharePermissionsCollected' -and $_.Source -eq 'NativeSmbRpc' }).Count -ge 1) 'Native fallback success should be logged as scan evidence.'
            }
            finally {
                Remove-Item -Path function:\Get-Item -ErrorAction SilentlyContinue
                Remove-Item -Path function:\Get-ChildItem -ErrorAction SilentlyContinue
                Remove-Item -Path function:\Get-Acl -ErrorAction SilentlyContinue
                Remove-Item -Path function:\Get-SmbShareAccess -ErrorAction SilentlyContinue
                Remove-Variable -Name ShareSurferSmbRpcShareInfoProvider -Scope Global -ErrorAction SilentlyContinue
            }
        }
    },
    @{
        Name = 'Get-ShareSurferNativeSessionRows treats NetSessionEnum more-data pages as usable evidence'
        Body = {
            $sessionSource = Get-Content -LiteralPath (Join-Path $repoRoot 'src/ShareSurfer/Private/Get-ShareSurferNativeSessionRows.ps1') -Raw
            Assert-True ($sessionSource -like '*$result -ne 0 -and $result -ne 234*') 'Native session enumeration should not treat ERROR_MORE_DATA as a fatal result.'
            Assert-True ($sessionSource -like '*while ($result -eq 234 -and $resumeHandle -ne 0 -and $rows.Count -lt $MaxRows)*') 'Native session enumeration should keep paging through ERROR_MORE_DATA until the cap or resume handle ends.'
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
                Assert-True (@($events | Where-Object { $_.EventType -eq 'ShareTargetResolved' -and $_.Detail -like '*PathSelection=ReturnedLocalPathUsedForLocalTarget*' }).Count -eq 1) 'Local SMB share scans should record that the returned local path was intentionally used.'
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
                Assert-Equal $shares[0].PartialData 'True' 'Remote SMB share data should remain partial when the server-local share path cannot be enumerated from the collector.'
                Assert-True ($permissions.Identity -contains 'CONTOSO\RemoteShareReaders') 'Remote SMB scans should collect share-level permissions through the CIM session.'
                Assert-True ($events.EventType -contains 'RemoteCimSessionCreated') 'Remote SMB scans should log CIM session creation.'
                Assert-True (@($events | Where-Object { $_.EventType -eq 'ShareTargetResolved' -and $_.Detail -like '*SelectedPath=\\remote-files01\Finance*' -and $_.Detail -like '*PathSelection=ReturnedLocalPathIgnoredForRemoteTarget*' }).Count -eq 1) 'Remote SMB scans should keep the UNC path instead of adopting a coincident collector-local path.'
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
        Name = 'Invoke-ShareSurferScan uses SMB RPC metadata fallback when remote CIM setup fails'
        Body = {
            Import-Module $moduleManifest -Force
            $shareRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferRpcFallback-' + [guid]::NewGuid().ToString('N'))
            New-Item -ItemType Directory -Path $shareRoot -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $shareRoot 'rpc-file.txt') -Value 'rpc fallback share mode'

            function global:New-CimSession {
                throw 'mock CIM session failure'
            }
            function global:Get-SmbShare {
                throw 'Get-SmbShare should not be called without a remote CIM session.'
            }
            function global:Get-SmbShareAccess {
                throw 'Get-SmbShareAccess should not be called without a remote CIM session.'
            }
            $global:ShareSurferSmbRpcShareInfoProvider = {
                param(
                    [string] $ComputerName,
                    [string] $ShareName
                )
                [pscustomobject]@{
                    ShareName = $ShareName
                    Path = $shareRoot
                    Description = 'Mocked SMB RPC metadata'
                    Source = 'SmbRpcNetShareGetInfo'
                    ResultCode = 0
                }
            }

            try {
                $outputPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferRpcFallbackExport-' + [guid]::NewGuid().ToString('N'))
                Invoke-ShareSurferScan -ComputerName 'remote-files04' -ShareName 'Finance' -OutputPath $outputPath -IncludeFiles -SkipIdentityEnrichment | Out-Null
                $shares = Import-Csv -LiteralPath (Join-Path $outputPath 'shares.csv')
                $items = Import-Csv -LiteralPath (Join-Path $outputPath 'items.csv')
                $permissions = @(Import-Csv -LiteralPath (Join-Path $outputPath 'share_permissions.csv'))
                $events = Import-Csv -LiteralPath (Join-Path $outputPath 'scan_events.csv')
                $manifest = @(Import-Csv -LiteralPath (Join-Path $outputPath 'scan_manifest.csv'))

                Assert-Equal $shares[0].Source 'SmbRpcNetShareGetInfo' 'SMB RPC fallback should be recorded as the share metadata source.'
                Assert-Equal $shares[0].LocalPath $shareRoot 'SMB RPC fallback should populate the resolved local path when available.'
                Assert-Equal $shares[0].Description 'Mocked SMB RPC metadata' 'SMB RPC fallback should populate share description metadata.'
                Assert-Equal $shares[0].PartialData 'True' 'Share should remain partial when share-level permissions are still unproven.'
                Assert-True ([string]$shares[0].PartialReason -like '*Share-level permissions were not collected*') 'Fallback metadata should not hide missing share-level permissions.'
                Assert-Equal @($items).Count 0 'Remote SMB RPC fallback should not enumerate a collector-local path returned by remote metadata.'
                Assert-Equal @($permissions).Count 0 'SMB RPC fallback should not fabricate share-level permissions.'
                Assert-True ($events.EventType -contains 'SmbRpcShareInfoResolved') 'SMB RPC metadata fallback should be logged as scan evidence.'
                Assert-True (($events | Where-Object { $_.EventType -eq 'ShareTargetResolved' -and $_.Source -eq 'SmbRpcNetShareGetInfo' }).Count -ge 1) 'Share target resolution should record the RPC fallback source.'
                Assert-True (@($events | Where-Object { $_.EventType -eq 'ShareTargetResolved' -and $_.Detail -like '*SelectedPath=\\remote-files04\Finance*' -and $_.Detail -like '*PathSelection=ReturnedLocalPathIgnoredForRemoteTarget*' }).Count -eq 1) 'Remote SMB RPC fallback should keep the target UNC path when metadata returns a server-local path.'
                Assert-Equal $manifest[0].RequestedSmbCollectionProvider 'Auto' 'Scan manifest should preserve the operator-requested SMB collection provider.'
                Assert-Equal $manifest[0].EffectiveSmbCollectionProvider 'NativeSmbRpc' 'Scan manifest should expose the effective provider used after SMB RPC fallback.'
            }
            finally {
                Remove-Item -Path function:\New-CimSession -ErrorAction SilentlyContinue
                Remove-Item -Path function:\Get-SmbShare -ErrorAction SilentlyContinue
                Remove-Item -Path function:\Get-SmbShareAccess -ErrorAction SilentlyContinue
                Remove-Variable -Name ShareSurferSmbRpcShareInfoProvider -Scope Global -ErrorAction SilentlyContinue
            }
        }
    },
    @{
        Name = 'Invoke-ShareSurferScan uses SMB RPC share-permission fallback when CIM permissions fail'
        Body = {
            Import-Module $moduleManifest -Force
            $shareRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferRpcPermissionFallback-' + [guid]::NewGuid().ToString('N'))
            New-Item -ItemType Directory -Path $shareRoot -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $shareRoot 'rpc-permission-file.txt') -Value 'rpc permission fallback share mode'

            function global:New-CimSession {
                throw 'mock CIM session failure'
            }
            function global:Get-SmbShare {
                throw 'Get-SmbShare should not be called without a remote CIM session.'
            }
            function global:Get-SmbShareAccess {
                throw 'Get-SmbShareAccess should not be called without a remote CIM session.'
            }
            $global:ShareSurferSmbRpcShareInfoProvider = {
                param(
                    [string] $ComputerName,
                    [string] $ShareName
                )
                [pscustomobject]@{
                    ShareName = $ShareName
                    Path = $shareRoot
                    Description = 'Mocked SMB RPC metadata and permissions'
                    Source = 'SmbRpcNetShareGetInfo'
                    ResultCode = 0
                    SharePermissions = @(
                        [pscustomobject]@{
                            Identity = 'CONTOSO\RpcFallbackReaders'
                            Rights = 'Read'
                            AccessMask = '0x00120089'
                            AccessControlType = 'Allow'
                            Source = 'NativeSmbRpc'
                        }
                    )
                }
            }

            try {
                $outputPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferRpcPermissionFallbackExport-' + [guid]::NewGuid().ToString('N'))
                Invoke-ShareSurferScan -ComputerName 'remote-files08' -ShareName 'Finance' -OutputPath $outputPath -IncludeFiles -SkipIdentityEnrichment | Out-Null
                $shares = Import-Csv -LiteralPath (Join-Path $outputPath 'shares.csv')
                $permissions = @(Import-Csv -LiteralPath (Join-Path $outputPath 'share_permissions.csv'))
                $collectionErrors = @(Import-Csv -LiteralPath (Join-Path $outputPath 'collection_errors.csv'))
                $events = Import-Csv -LiteralPath (Join-Path $outputPath 'scan_events.csv')
                $manifest = @(Import-Csv -LiteralPath (Join-Path $outputPath 'scan_manifest.csv'))

                Assert-Equal $shares[0].PartialData 'True' 'Remote SMB share scans should remain partial when the UNC path cannot be enumerated, even if NativeSmbRpc proves share-level permissions.'
                Assert-True ([string]$shares[0].PartialReason -like '*Unable to enumerate share path*') 'Remote SMB share scans should keep the enumeration partial reason separate from share-permission proof.'
                Assert-True ([string]$shares[0].PartialReason -notlike '*Share-level permissions were not collected*') 'NativeSmbRpc permission proof should clear missing share-permission partial reasons.'
                Assert-True ($permissions.Identity -contains 'CONTOSO\RpcFallbackReaders') 'SMB share scans should export NativeSmbRpc fallback share permission rows.'
                Assert-True ($permissions.Source -contains 'NativeSmbRpc') 'SMB RPC fallback permission rows should preserve NativeSmbRpc provenance.'
                Assert-True (@($collectionErrors | Where-Object { $_.ErrorType -eq 'SharePermissionCollectionUnavailable' }).Count -eq 0) 'SMB RPC fallback should avoid the generic missing share-permission error when it succeeds.'
                Assert-True (@($collectionErrors | Where-Object { $_.ErrorType -eq 'ShareEnumerationError' }).Count -eq 1) 'Remote SMB RPC fallback should preserve the remaining UNC enumeration gap as a separate collection error.'
                Assert-True (($events | Where-Object { $_.EventType -eq 'SharePermissionsCollected' -and $_.Source -eq 'NativeSmbRpc' }).Count -ge 1) 'SMB RPC permission fallback success should be logged.'
                Assert-Equal $manifest[0].EffectiveSmbCollectionProvider 'NativeSmbRpc' 'Scan manifest should expose NativeSmbRpc as an effective provider after permission fallback.'
            }
            finally {
                Remove-Item -Path function:\New-CimSession -ErrorAction SilentlyContinue
                Remove-Item -Path function:\Get-SmbShare -ErrorAction SilentlyContinue
                Remove-Item -Path function:\Get-SmbShareAccess -ErrorAction SilentlyContinue
                Remove-Variable -Name ShareSurferSmbRpcShareInfoProvider -Scope Global -ErrorAction SilentlyContinue
            }
        }
    },
    @{
        Name = 'Native ACL rights evidence normalizes readable rights and preserves raw masks'
        Body = {
            Import-Module $moduleManifest -Force
            $module = Get-Module ShareSurfer

            $shareFull = & $module {
                ConvertTo-ShareSurferNativeRightsEvidence -PermissionKind Share -AccessMask 0x001F01FF
            }
            $shareChange = & $module {
                ConvertTo-ShareSurferNativeRightsEvidence -PermissionKind Share -AccessMask 0x00120116
            }
            $shareRead = & $module {
                ConvertTo-ShareSurferNativeRightsEvidence -PermissionKind Share -AccessMask 0x00120089
            }
            $shareUnknown = & $module {
                ConvertTo-ShareSurferNativeRightsEvidence -PermissionKind Share -AccessMask 0
            }
            $fileRead = & $module {
                ConvertTo-ShareSurferNativeRightsEvidence -PermissionKind FileSystem -AccessMask 0x00120089
            }
            $fileGenericRead = & $module {
                ConvertTo-ShareSurferNativeRightsEvidence -PermissionKind FileSystem -AccessMask 0x80000000
            }

            Assert-Equal $shareFull.Rights 'Full' 'Share full-control masks should normalize to readable Full rights.'
            Assert-Equal $shareFull.AccessMask '0x001F01FF' 'Share full-control evidence should preserve the raw access mask.'
            Assert-Equal $shareChange.Rights 'Change' 'Share change masks should normalize to readable Change rights.'
            Assert-Equal $shareChange.AccessMask '0x00120116' 'Share change evidence should preserve the raw access mask.'
            Assert-Equal $shareRead.Rights 'Read' 'Share read masks should not be promoted to Change because of shared standard rights bits.'
            Assert-Equal $shareRead.AccessMask '0x00120089' 'Share read evidence should preserve the raw access mask.'
            Assert-Equal $shareUnknown.Rights 'Unknown' 'Unknown share rights masks should not default to Read.'
            Assert-Equal $shareUnknown.AccessMask '0x00000000' 'Unknown share rights evidence should still preserve the raw access mask.'
            Assert-True ([string]$fileRead.Rights -like '*Read*') 'Filesystem read masks should normalize to readable filesystem rights text.'
            Assert-Equal $fileRead.AccessMask '0x00120089' 'Filesystem rights evidence should preserve the raw access mask.'
            Assert-Equal $fileGenericRead.Rights 'GenericRead' 'Filesystem generic rights masks should normalize to readable generic rights instead of signed enum values.'
            Assert-Equal $fileGenericRead.AccessMask '0x80000000' 'Filesystem generic rights evidence should preserve the raw access mask.'
        }
    },
    @{
        Name = 'Native descriptor and export edge cases remain explicit and deterministic'
        Body = {
            Import-Module $moduleManifest -Force
            $module = Get-Module ShareSurfer
            $outputPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferExportEdges-' + [guid]::NewGuid().ToString('N'))
            New-Item -ItemType Directory -Path $outputPath -Force | Out-Null
            $jsonlPath = Join-Path $outputPath 'empty.jsonl'
            $csvPath = Join-Path $outputPath 'empty.csv'

            $nativeEvidence = & $module {
                $rpcShare = [pscustomobject]@{
                    ShareName = 'Finance'
                    Path = 'C:\Shares\Finance'
                    Source = 'Fixture'
                    SecurityDescriptorBytes = $null
                }
                Get-ShareSurferNativeSharePermissionEvidence -ShareId 'share-null' -ComputerName 'files01' -ShareName 'Finance' -RpcShare $rpcShare
            }
            & $module {
                param($JsonlPath, $CsvPath)
                Export-ShareSurferJsonLines -Path $JsonlPath -Rows @()
                Export-ShareSurferCsv -Path $CsvPath -Columns @('A', 'B') -Rows @()
            } $jsonlPath $csvPath

            $jsonBytes = [System.IO.File]::ReadAllBytes($jsonlPath)
            $csvBytes = [System.IO.File]::ReadAllBytes($csvPath)
            $csvText = Get-Content -LiteralPath $csvPath -Raw

            Assert-Equal $nativeEvidence.Available $false 'Null native share security descriptor bytes should be treated as unavailable evidence.'
            Assert-Equal $nativeEvidence.ErrorType 'NativeShareSecurityDescriptorUnavailable' 'Null native share security descriptor bytes should keep an explicit error type.'
            Assert-Equal $jsonBytes.Length 0 'Empty JSONL exports should be truly empty, not a blank-line row.'
            Assert-True ($csvBytes.Length -ge 3) 'Empty CSV exports should contain a UTF-8 BOM plus header.'
            Assert-Equal $csvBytes[0] 239 'CSV export should write UTF-8 BOM byte 1.'
            Assert-Equal $csvBytes[1] 187 'CSV export should write UTF-8 BOM byte 2.'
            Assert-Equal $csvBytes[2] 191 'CSV export should write UTF-8 BOM byte 3.'
            Assert-True ($csvText -like '*"A","B"*') 'Empty CSV exports should still write the normalized header.'
        }
    },
    @{
        Name = 'Stable-token redaction is case-insensitive and fail-closed for short unknown values'
        Body = {
            Import-Module $moduleManifest -Force
            $module = Get-Module ShareSurfer

            $tokens = & $module {
                [pscustomobject]@{
                    UpperIdentity = Get-ShareSurferStableToken -Value 'CONTOSO\FinanceEditors' -Salt 'case-test'
                    LowerIdentity = Get-ShareSurferStableToken -Value 'contoso\financeeditors' -Salt 'case-test'
                    ShortUnknown = Protect-ShareSurferValue -Value 'svcacct' -ColumnName 'Notes' -RedactionMode StableToken -RedactionSalt 'case-test'
                }
            }

            Assert-Equal $tokens.UpperIdentity $tokens.LowerIdentity 'Stable tokens should be case-insensitive so casing drift cannot bypass support-bundle redaction.'
            Assert-True ([string]$tokens.ShortUnknown -like 'ID-*') 'Short unknown free-text values should be tokenized instead of leaked as presumed-safe literals.'
        }
    },
    @{
        Name = 'Native SMB RPC descriptor rows preserve share permissions and unresolved SIDs'
        Body = {
            Import-Module $moduleManifest -Force
            if (-not ([System.Environment]::OSVersion.Platform -eq 'Win32NT')) {
                return
            }
            $module = Get-Module ShareSurfer
            $descriptorBytes = New-TestSecurityDescriptorBytes -Sddl 'O:BAG:BAD:(A;;FR;;;S-1-5-21-1000-2000-3000-4000)(D;;FW;;;S-1-5-21-1000-2000-3000-5000)'

            $rows = @(& $module {
                param($Bytes)
                ConvertTo-ShareSurferSharePermissionRowsFromSecurityDescriptor -ShareId 'share-native' -SecurityDescriptorBytes $Bytes
            } $descriptorBytes)

            Assert-Equal $rows.Count 2 'Native share security descriptor conversion should emit one row per share DACL ACE.'
            Assert-True ($rows.Identity -contains 'S-1-5-21-1000-2000-3000-4000') 'Unresolved share permission SIDs should be preserved as visible review evidence.'
            Assert-True ($rows.AccessControlType -contains 'Deny') 'Native share security descriptor conversion should preserve deny ACEs.'
            Assert-True ($rows.Source -contains 'NativeSmbRpc') 'Native share permission rows should record NativeSmbRpc provenance.'
        }
    },
    @{
        Name = 'Native security descriptor filesystem rows preserve ACE flags on Windows PowerShell'
        Body = {
            Import-Module $moduleManifest -Force
            if (-not ([System.Environment]::OSVersion.Platform -eq 'Win32NT')) {
                return
            }
            $module = Get-Module ShareSurfer
            $descriptorBytes = New-TestSecurityDescriptorBytes -Sddl 'O:BAG:BAD:(A;OICIID;FR;;;S-1-5-21-1000-2000-3000-4000)'

            $rows = @(& $module {
                param($Bytes)
                $descriptor = ConvertTo-ShareSurferRawSecurityDescriptor -SecurityDescriptorBytes $Bytes
                ConvertTo-ShareSurferSecurityDescriptorAclRows -RawSecurityDescriptor $descriptor -PermissionKind FileSystem -ShareId 'share-native' -ItemId 'item-native' -FullPath 'C:\Native\Path' -Depth 3
            } $descriptorBytes)

            Assert-Equal $rows.Count 1 'Native filesystem security descriptor conversion should emit one row per filesystem DACL ACE.'
            Assert-Equal $rows[0].IsInherited $true 'Native filesystem ACE conversion should detect inherited ACE flags without PowerShell enum cast failures.'
            Assert-Equal $rows[0].InheritanceFlags 'ContainerInherit,ObjectInherit' 'Native filesystem ACE conversion should preserve inheritance flags.'
            Assert-Equal $rows[0].Depth 3 'Native filesystem ACE conversion should preserve item depth.'
        }
    },
    @{
        Name = 'Invoke-ShareSurferScan NativeSmbRpc avoids CIM SMB cmdlets and Get-Acl for core evidence'
        Body = {
            Import-Module $moduleManifest -Force
            $shareRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferNativeRpc-' + [guid]::NewGuid().ToString('N'))
            New-Item -ItemType Directory -Path $shareRoot -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $shareRoot 'Delegated') -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $shareRoot 'native-file.txt') -Value 'native rpc share mode'

            function global:New-CimSession {
                throw 'New-CimSession should not be called by NativeSmbRpc.'
            }
            function global:Get-SmbShare {
                throw 'Get-SmbShare should not be called by NativeSmbRpc.'
            }
            function global:Get-SmbShareAccess {
                throw 'Get-SmbShareAccess should not be called by NativeSmbRpc.'
            }
            function global:Get-Acl {
                throw 'Get-Acl should not be called by NativeSmbRpc.'
            }

            $global:ShareSurferSmbRpcShareInfoProvider = {
                param(
                    [string] $ComputerName,
                    [string] $ShareName
                )
                [pscustomobject]@{
                    ShareName = $ShareName
                    Path = $shareRoot
                    Description = 'Mocked native SMB RPC metadata'
                    Source = 'SmbRpcNetShareGetInfo'
                    ResultCode = 0
                    Level = 502
                    SecurityDescriptorBytes = @()
                    SharePermissions = @(
                        [pscustomobject]@{
                            ShareId = ''
                            Identity = 'CONTOSO\NativeShareReaders'
                            Rights = 'Read'
                            AccessControlType = 'Allow'
                            Source = 'NativeSmbRpc'
                        }
                    )
                }
            }

            $global:ShareSurferNativeSecurityInfoProvider = {
                param(
                    [string] $Path,
                    [string] $ShareId,
                    [string] $ItemId,
                    [string] $FullPath,
                    [int] $Depth
                )

                [pscustomobject]@{
                    Owner = 'CONTOSO\NativeOwner'
                    InheritanceEnabled = $false
                    InheritanceBrokenAt = $FullPath
                    AclEntries = @(
                        [pscustomobject]@{
                            ItemId = $ItemId
                            ShareId = $ShareId
                            FullPath = $FullPath
                            Identity = 'CONTOSO\NativeEditors'
                            Rights = 'Modify'
                            AccessControlType = 'Allow'
                            IsInherited = $false
                            InheritanceFlags = 'ContainerInherit,ObjectInherit'
                            PropagationFlags = 'None'
                            Depth = $Depth
                        }
                    )
                    Source = 'NativeWin32Security'
                }
            }

            try {
                $outputPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferNativeRpcExport-' + [guid]::NewGuid().ToString('N'))
                Invoke-ShareSurferScan -ComputerName ([System.Environment]::MachineName) -ShareName 'Finance' -SmbCollectionProvider NativeSmbRpc -OutputPath $outputPath -IncludeFiles -SkipIdentityEnrichment | Out-Null
                $shares = @(Import-Csv -LiteralPath (Join-Path $outputPath 'shares.csv'))
                $items = @(Import-Csv -LiteralPath (Join-Path $outputPath 'items.csv'))
                $permissions = @(Import-Csv -LiteralPath (Join-Path $outputPath 'share_permissions.csv'))
                $aclRows = @(Import-Csv -LiteralPath (Join-Path $outputPath 'acl_entries.csv'))
                $events = @(Import-Csv -LiteralPath (Join-Path $outputPath 'scan_events.csv'))
                $manifest = @(Import-Csv -LiteralPath (Join-Path $outputPath 'scan_manifest.csv'))
                $validation = Test-ShareSurferExport -ExportPath $outputPath

                Assert-Equal $validation.IsValid $true 'Native SMB RPC scan export should validate against the normalized schema.'
                Assert-Equal $shares[0].Source 'NativeSmbRpc' 'Native provider should record NativeSmbRpc as the share source.'
                Assert-Equal $shares[0].PartialData 'False' 'Native provider should not mark the share partial when share permissions and ACLs were collected.'
                Assert-True ($items.Owner -contains 'CONTOSO\NativeOwner') 'Native provider should populate item owner evidence through native security reads.'
                Assert-True ($permissions.Source -contains 'NativeSmbRpc') 'Native provider should populate share permissions from native provider evidence.'
                Assert-True ($aclRows.Identity -contains 'CONTOSO\NativeEditors') 'Native provider should populate file/folder ACL rows through native security evidence.'
                Assert-Equal $manifest[0].CollectionProvider 'NativeSmbRpc' 'Scan manifest should record NativeSmbRpc provider selection.'
                Assert-Equal $manifest[0].RequestedSmbCollectionProvider 'NativeSmbRpc' 'Scan manifest should preserve explicit NativeSmbRpc requests.'
                Assert-Equal $manifest[0].EffectiveSmbCollectionProvider 'NativeSmbRpc' 'Scan manifest should show NativeSmbRpc as the effective provider.'
                Assert-True ($events.EventType -contains 'CollectionProviderSelected') 'Native provider should log provider selection.'
                Assert-True (@($events | Where-Object { $_.EventType -eq 'RemoteCimSessionCreated' }).Count -eq 0) 'Native provider should not create remote CIM sessions.'
            }
            finally {
                Remove-Item -Path function:\New-CimSession -ErrorAction SilentlyContinue
                Remove-Item -Path function:\Get-SmbShare -ErrorAction SilentlyContinue
                Remove-Item -Path function:\Get-SmbShareAccess -ErrorAction SilentlyContinue
                Remove-Item -Path function:\Get-Acl -ErrorAction SilentlyContinue
                Remove-Variable -Name ShareSurferSmbRpcShareInfoProvider -Scope Global -ErrorAction SilentlyContinue
                Remove-Variable -Name ShareSurferNativeSecurityInfoProvider -Scope Global -ErrorAction SilentlyContinue
            }
        }
    },
    @{
        Name = 'Invoke-ShareSurferScan NativeSmbRpc classifies reachable but unreadable security descriptors'
        Body = {
            Import-Module $moduleManifest -Force
            $shareRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferNativeDescriptorFailure-' + [guid]::NewGuid().ToString('N'))
            New-Item -ItemType Directory -Path $shareRoot -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $shareRoot 'descriptor-failure.txt') -Value 'native descriptor failure mode'

            $global:ShareSurferSmbRpcShareInfoProvider = {
                param(
                    [string] $ComputerName,
                    [string] $ShareName
                )
                [pscustomobject]@{
                    ShareName = $ShareName
                    Path = $shareRoot
                    Description = 'Mocked native SMB RPC metadata without share descriptor'
                    Source = 'SmbRpcNetShareGetInfo'
                    ResultCode = 0
                    Level = 502
                    SecurityDescriptorBytes = @()
                }
            }

            $global:ShareSurferNativeSecurityInfoProvider = {
                param(
                    [string] $Path,
                    [string] $ShareId,
                    [string] $ItemId,
                    [string] $FullPath,
                    [int] $Depth
                )

                throw 'NativeSecurityDescriptorReadFailed: GetNamedSecurityInfoW failed with Win32 result 5 (Access is denied).'
            }

            try {
                $nativeComputerName = [System.Environment]::MachineName
                $outputPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferNativeDescriptorFailureExport-' + [guid]::NewGuid().ToString('N'))
                Invoke-ShareSurferScan -ComputerName $nativeComputerName -ShareName 'Finance' -SmbCollectionProvider NativeSmbRpc -OutputPath $outputPath -IncludeFiles -SkipIdentityEnrichment | Out-Null
                $shares = @(Import-Csv -LiteralPath (Join-Path $outputPath 'shares.csv'))
                $collectionErrors = @(Import-Csv -LiteralPath (Join-Path $outputPath 'collection_errors.csv'))
                $events = @(Import-Csv -LiteralPath (Join-Path $outputPath 'scan_events.csv'))

                Assert-Equal $shares[0].PartialData 'True' 'Share should be marked partial when native security descriptors cannot be collected.'
                Assert-True ($collectionErrors.ErrorType -contains 'NativeShareSecurityDescriptorUnavailable') 'Missing native share security descriptors should have an explicit collection error type.'
                Assert-True ($collectionErrors.ErrorType -contains 'NativeSecurityDescriptorReadFailed') 'Unreadable native file/folder security descriptors should have an explicit collection error type.'
                Assert-True (($collectionErrors | Where-Object { $_.ErrorType -eq 'NativeSecurityDescriptorReadFailed' } | Select-Object -First 1).Detail -like '*SMB/RPC or UNC enumeration can be reachable*') 'Native descriptor read failures should explain reachability versus readable security evidence.'
                Assert-True ($events.EventType -contains 'NativeShareSecurityDescriptorUnavailable') 'Missing share descriptors should be logged as scan events.'
                Assert-True ($events.EventType -contains 'NativeSecurityDescriptorReadFailed') 'Unreadable filesystem descriptors should be logged as scan events.'
            }
            finally {
                Remove-Variable -Name ShareSurferSmbRpcShareInfoProvider -Scope Global -ErrorAction SilentlyContinue
                Remove-Variable -Name ShareSurferNativeSecurityInfoProvider -Scope Global -ErrorAction SilentlyContinue
            }
        }
    },
    @{
        Name = 'Invoke-ShareSurferScan keeps non-terminating WinRM failures out of the console error stream'
        Body = {
            Import-Module $moduleManifest -Force
            function global:New-CimSession {
                Write-Error 'mock non-terminating WinRM failure'
            }
            function global:Get-SmbShare {
                throw 'Get-SmbShare should not be called without a remote CIM session.'
            }
            function global:Get-SmbShareAccess {
                throw 'Get-SmbShareAccess should not be called without a remote CIM session.'
            }

            try {
                $outputPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferQuietWinRmExport-' + [guid]::NewGuid().ToString('N'))
                $captured = @(& {
                    Invoke-ShareSurferScan -ComputerName 'remote-files03' -ShareName 'Finance' -OutputPath $outputPath -IncludeFiles -SkipIdentityEnrichment -Quiet | Out-Null
                } 2>&1)
                $errorRecords = @($captured | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] })
                $collectionErrors = @(Import-Csv -LiteralPath (Join-Path $outputPath 'collection_errors.csv'))
                $events = @(Import-Csv -LiteralPath (Join-Path $outputPath 'scan_events.csv'))

                Assert-Equal @($errorRecords).Count 0 'Remote CIM non-terminating errors should be handled without leaking console error records.'
                Assert-True ($collectionErrors.ErrorType -contains 'RemoteCimSessionError') 'Remote CIM failures should still be exported as collection-error evidence.'
                Assert-True ($events.EventType -contains 'RemoteCimSessionError') 'Remote CIM failures should still be logged as scan events.'
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
                    Level = 'Error'
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
            $redactedEvidenceConfidence = Get-Content -LiteralPath (Join-Path $bundlePath 'evidence_confidence.csv') -Raw
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
            Assert-True ($redactedRelatedDataAreas -like '*Strong confidence*') 'Related data areas should preserve safe relatedness confidence reasons.'
            Assert-True ($redactedOwnerReviewPackets -notlike '*Finance*') 'Owner review packets must anonymize owner and business-unit labels.'
            Assert-True ($redactedOwnerReviewPackets -like '*WhyReview*') 'Owner review packets should preserve guidance headers.'
            Assert-True ($redactedOwnerReviewPackets -like '*SuggestedNextAction*') 'Owner review packets should preserve next-action guidance.'
            Assert-True ($redactedEvidenceConfidence -notlike '*Finance*') 'Evidence confidence support bundle rows must anonymize share scope names.'
            Assert-True ($redactedEvidenceConfidence -like '*ConfidenceLabel*' -and $redactedEvidenceConfidence -like '*Review*') 'Evidence confidence support bundle rows should preserve confidence labels.'
            Assert-True ($redactedEvidenceConfidence -like '*Partial data or collection errors*') 'Evidence confidence support bundle rows should preserve reader-facing review guidance.'
            Assert-True ($redactedEvents -notlike '*files01*') 'Redacted scan events must not leak server names.'
            Assert-True ($redactedEvents -like '*2026-06-04T00:00:00.0000000Z*') 'Redacted scan events should preserve timestamps for diagnostic ordering.'
            Assert-True ($redactedEvents -like '*Error*') 'Redacted scan events should preserve error levels as diagnostic vocabulary.'
            Assert-True ($redactedEvents -like '*FixtureSensitiveEvent*') 'Redacted scan events should preserve event type diagnostic vocabulary.'
            Assert-True ($redactedEvents -notlike '*Collected CONTOSO*') 'Redacted scan events should still redact free-form event messages.'
            Assert-True ($redactedManifest -like '*AdLookupMode*') 'Redacted manifest should preserve AD lookup mode as a support diagnostic setting.'
            Assert-True ($redactedManifest -like '*Auto*') 'Redacted manifest should preserve the selected AD lookup mode value.'
            Assert-True ($redactedManifest -like '*CollectionProvider*') 'Redacted manifest should preserve collection provider as a support diagnostic setting.'
            Assert-True ($redactedManifest -like '*RequestedSmbCollectionProvider*') 'Redacted manifest should preserve requested SMB collection provider as a support diagnostic setting.'
            Assert-True ($redactedManifest -like '*EffectiveSmbCollectionProvider*') 'Redacted manifest should preserve effective SMB collection provider as a support diagnostic setting.'
            Assert-True ($redactedManifest -like '*InputObject*') 'Redacted manifest should preserve safe collection provider values.'
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
            Assert-True ($bundleDiagnostics.ScanSettings.PSObject.Properties.Name -contains 'CollectionProvider') 'Support bundle diagnostics should preserve collection provider scan settings.'
            Assert-True ($bundleDiagnostics.ScanSettings.PSObject.Properties.Name -contains 'RequestedSmbCollectionProvider') 'Support bundle diagnostics should preserve requested SMB provider scan settings.'
            Assert-True ($bundleDiagnostics.ScanSettings.PSObject.Properties.Name -contains 'EffectiveSmbCollectionProvider') 'Support bundle diagnostics should preserve effective SMB provider scan settings.'
            Assert-True (@($redactionAudit | Where-Object { $_.SourceFile -eq 'scan_manifest.csv' -and $_.ColumnName -eq 'CollectionProvider' }).Count -eq 0) 'Collection provider should be treated as a safe diagnostic enum, not a redaction leak candidate.'
            Assert-True (@($redactionAudit | Where-Object { $_.SourceFile -eq 'scan_manifest.csv' -and $_.ColumnName -eq 'RequestedSmbCollectionProvider' }).Count -eq 0) 'Requested SMB provider should be treated as a safe diagnostic enum, not a redaction leak candidate.'
            Assert-True (@($redactionAudit | Where-Object { $_.SourceFile -eq 'scan_manifest.csv' -and $_.ColumnName -eq 'EffectiveSmbCollectionProvider' }).Count -eq 0) 'Effective SMB provider should be treated as a safe diagnostic enum, not a redaction leak candidate.'
            Assert-True (@($redactionAudit | Where-Object { $_.SourceFile -eq 'evidence_confidence.csv' -and $_.ColumnName -eq 'ConfidenceId' }).Count -gt 0) 'Evidence confidence IDs should be audited rather than treated as safe literals.'
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
            Assert-True ($bundleFiles.FileName -contains 'evidence_confidence.csv') 'Support bundle file diagnostics should include evidence confidence.'
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
                [pscustomobject]@{ Name = 'EnterpriseManagerChainCoverage'; Required = $true; MinimumValue = 1; ActualValue = 1; Unit = 'three-level manager chains'; Passed = $true; EvidenceSource = 'ScanExport:org_chains.csv'; EvidenceDetail = 'Synthetic acceptance proof'; Description = 'Manager chains' },
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
            Assert-True ($publisherScriptText.Contains('Ready for proof review: `True`')) 'Publisher should use a literal closeout readiness marker that preserves Markdown backticks.'
            Assert-True ($publisherScriptText.Contains('$closeoutText.Contains')) 'Publisher readiness guard should avoid wildcard matching against Markdown backticks.'
            Assert-True ($publisherScriptText.Contains('$readbackBodyLines')) 'Publisher should preserve multiline GitHub comment readback output.'
            Assert-True ($publisherScriptText.Contains('$readbackBodyLines -join "`n"')) 'Publisher should compare multiline GitHub comment readback with newline joins.'
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
            $allowedMissingBundlePath = Join-Path $runRoot 'not-generated-support-bundle'
            $allowedMissingBundleResult = & $acceptanceScript -RunRoot $runRoot -RequireLiveEvidence -SupportBundlePath $allowedMissingBundlePath -AllowMissingSupportBundle
            Assert-True $allowedMissingBundleResult.IsValid 'Acceptance checker should allow the optional rich support bundle to be skipped for enterprise lab proof runs.'
            Assert-True (@($allowedMissingBundleResult.Checks | Where-Object { $_.Name -eq 'RedactedSupportBundle' -and $_.Passed }).Count -gt 0) 'Acceptance checker should mark skipped optional support bundle evidence as passed.'
            Assert-True (@($allowedMissingBundleResult.Checks | Where-Object { $_.Name -eq 'LabRunSupportBundleEvidence' -and $_.Passed }).Count -gt 0) 'Acceptance checker should mark skipped optional lab-run bundle diagnostics as passed.'
            Assert-True (@($allowedMissingBundleResult.Checks | Where-Object { $_.Name -eq 'BundledValidationIssueComments' -and $_.Passed }).Count -gt 0) 'Acceptance checker should allow bundled issue-comment artifacts to be absent when the support bundle is skipped.'
            Assert-True (@($allowedMissingBundleResult.Checks | Where-Object { $_.Name -eq 'BundledValidationCloseoutChecklist' -and $_.Passed }).Count -gt 0) 'Acceptance checker should allow bundled closeout artifacts to be absent when the support bundle is skipped.'
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
            Assert-True ($labValidationScript -like '*IncludeRedactedSupportBundle*') 'Lab validation should expose rich redacted lab support bundles as an explicit opt-in.'
            Assert-True ($labValidationScript -like '*AllowMissingSupportBundle*') 'Lab validation should allow optional support-bundle evidence to be skipped by default for enterprise proof runs.'
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
            Assert-True ($labValidationScript -like '*Finished V1 acceptance package is not ready; continuing to final proof-package decision*') 'Lab validation should report a failed proof package without forcing optional support-bundle regeneration.'
            Assert-True ($labValidationScript -like '*final validation package is not ready for proof review*') 'Lab validation should fail clearly after producing closeout diagnostics.'
            Assert-True ($labValidationScript -like '*refreshing final redacted support bundle with issue summary*') 'Lab validation should refresh the final support bundle after the issue summary exists.'
            Assert-True ($labValidationScript -like '*owner-mapping.csv*') 'Lab validation should write a deterministic owner mapping CSV.'
            Assert-True ($labValidationScript -like '*-OwnerMappingPath $ownerMappingPath*') 'Lab validation should pass owner mappings into the scan.'
            Assert-True ($labValidationScript -like '*live-evidence-review.csv*') 'Lab validation should write an operator-friendly live evidence review CSV.'
            Assert-True ($labValidationScript -like '*LiveEvidenceReviewPath*') 'Lab validation output should include the live evidence review artifact path.'
            Assert-True ($labValidationScript -like '*-RunRoot $runRoot*') 'Lab validation should include redacted lab-run evidence in generated support bundles when requested.'
            Assert-True ((Get-Content -LiteralPath (Join-Path $repoRoot 'docs/windows-lab-readiness-checklist.md') -Raw) -like '*New-ShareSurferValidationIssueSummary.ps1*') 'Lab readiness checklist should document the validation issue summary script.'
        }
    },
    @{
        Name = 'Archived enterprise lab evidence refresh proves stale ACL scenario metadata from CSV exports'
        Body = {
            $refreshScript = Join-Path $repoRoot 'scripts/New-ShareSurferArchivedEvidenceRefresh.ps1'
            $archivedRunRoot = Join-Path $repoRoot 'docs/lab-evidence/windows-ad-enterprise-20260605-101639/20260605-101639'
            $refreshOutput = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferArchivedEvidenceRefresh-' + [guid]::NewGuid().ToString('N'))

            Assert-True (Test-Path -LiteralPath $refreshScript) 'Repository should include a script to create derived archived lab evidence refresh artifacts.'
            Assert-True (Test-Path -LiteralPath $archivedRunRoot) 'Archived enterprise lab evidence should be present for refresh validation.'

            $refreshResult = & $refreshScript -RunRoot $archivedRunRoot -OutputPath $refreshOutput -RequireLiveEvidence -AllowMissingSupportBundle -AllowMissingIssueComments
            Assert-True ([bool]$refreshResult.AcceptanceIsValid) 'Refreshed archived enterprise evidence should pass V1 acceptance with live evidence required.'
            Assert-Equal ([int]$refreshResult.AcceptanceFailedCheckCount) 0 'Refreshed archived enterprise evidence should have no failed acceptance checks.'
            Assert-True ([bool]$refreshResult.LiveEvidenceIsValid) 'Refreshed archived enterprise evidence should pass the live evidence gate.'
            Assert-Equal ([int]$refreshResult.LiveEvidenceFallbackCount) 0 'Refreshed archived enterprise evidence should have no fallback criteria.'
            Assert-True (@($refreshResult.StrengthenedCriteria | Where-Object { [string]$_.Name -eq 'FocusedAclScenarios' }).Count -eq 1) 'Refresh should strengthen the stale FocusedAclScenarios row.'
            Assert-True (Test-Path -LiteralPath ([string]$refreshResult.SummaryPath)) 'Refresh should write a human-readable summary.'
            Assert-True (Test-Path -LiteralPath ([string]$refreshResult.IssueSummaryPath)) 'Refresh should write a public-safe issue summary.'
            Assert-True (Test-Path -LiteralPath ([string]$refreshResult.CloseoutChecklistPath)) 'Refresh should write a validation closeout checklist.'
            Assert-True (Test-Path -LiteralPath ([string]$refreshResult.IssueCommentPublishPreviewPath)) 'Refresh should write a dry-run issue-comment publish preview.'
            Assert-True (Test-Path -LiteralPath (Join-Path ([string]$refreshResult.IssueCommentDirectory) 'issue-1-lab-fixture-live-proof.md')) 'Refresh should write issue #1 proof comment body.'

            $refreshedFocused = @(Import-Csv -LiteralPath ([string]$refreshResult.CriteriaPath) | Where-Object { [string]$_.Name -eq 'FocusedAclScenarios' })[0]
            Assert-Equal ([string]$refreshedFocused.EvidenceSource) 'ScanExport:acl_entries.csv;findings.csv;conflicts.csv;items.csv' 'Focused ACL scenario refresh should use scan/export evidence.'
            Assert-True ([string]$refreshedFocused.EvidenceDetail -like '*DeepExplicitAceFindings=251*') 'Focused ACL scenario refresh should preserve deep explicit ACE evidence counts from the archived export.'
            $refreshCloseout = Get-Content -LiteralPath ([string]$refreshResult.CloseoutChecklistPath) -Raw
            Assert-True ($refreshCloseout.Contains('Ready for proof review: `True`')) 'Refreshed closeout checklist should mark the archived proof review ready.'
            Assert-True ($refreshCloseout -like '*Optional rich support bundle skipped*') 'Refreshed closeout checklist should explain the optional rich support bundle was skipped.'
        }
    },
    @{
        Name = 'Archived evidence refresh normalizes empty legacy CSV headers'
        Body = {
            $refreshScript = Join-Path $repoRoot 'scripts/New-ShareSurferArchivedEvidenceRefresh.ps1'
            $tokens = $null
            $parseErrors = $null
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($refreshScript, [ref]$tokens, [ref]$parseErrors)
            Assert-True (@($parseErrors).Count -eq 0) 'Archived refresh script should parse before extracting helper function.'
            $functionAst = $ast.Find({
                    param($node)
                    $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Convert-ShareSurferArchivedCsvToSchema'
                }, $true)
            Assert-True ($null -ne $functionAst) 'Archived refresh script should define the schema conversion helper.'
            . ([scriptblock]::Create($functionAst.Extent.Text))

            $legacyCsv = Join-Path ([System.IO.Path]::GetTempPath()) ('ShareSurferEmptyLegacyCsv-' + [guid]::NewGuid().ToString('N') + '.csv')
            Set-Content -LiteralPath $legacyCsv -Value '"Group","DisplayName"' -Encoding UTF8

            Convert-ShareSurferArchivedCsvToSchema -Path $legacyCsv -Columns @(
                'Group',
                'DisplayName',
                'DiscountedPrincipal',
                'DiscountReason',
                'DiscountScope'
            )

            $header = Get-Content -LiteralPath $legacyCsv -First 1
            Assert-Equal $header '"Group","DisplayName","DiscountedPrincipal","DiscountReason","DiscountScope"' 'Empty legacy CSV should be rewritten with the expected current schema header.'
            Assert-Equal (@(Import-Csv -LiteralPath $legacyCsv).Count) 0 'Header-only legacy CSV should remain a zero-row CSV after schema normalization.'
        }
    },
    @{
        Name = 'Documentation includes workflow visuals for operator review'
        Body = {
            $pesterWrapper = Join-Path $repoRoot 'tests/ShareSurfer.Tests.ps1'
            $visualDoc = Join-Path $repoRoot 'docs/workflow-visuals.md'
            $visualFieldGuide = Join-Path $repoRoot 'docs/visual-field-guide.md'
            $visualRoot = Join-Path $repoRoot 'docs/visuals'
            $visualReadme = Join-Path $visualRoot 'README.md'
            $screenshotScript = Join-Path $repoRoot 'scripts/New-ShareSurferDashboardScreenshots.ps1'
            $firstRunGuide = Join-Path $repoRoot 'docs/first-run-guide.md'
            $glossary = Join-Path $repoRoot 'docs/glossary.md'
            $firstRunTroubleshooting = Join-Path $repoRoot 'docs/first-run-troubleshooting.md'
            $businessReviewHandoff = Join-Path $repoRoot 'docs/business-review-handoff.md'
            $workflowGuide = Join-Path $repoRoot 'docs/workflow-guides.md'
            $commandRecipes = Join-Path $repoRoot 'docs/command-recipes.md'
            $adminOwnershipImport = Join-Path $repoRoot 'docs/admin-ownership-import.md'
            $ownershipCsvIngestQuickReference = Join-Path $repoRoot 'docs/ownership-csv-ingest-quick-reference.md'
            $managementOverview = Join-Path $repoRoot 'docs/management-overview.md'
            $managementSlide = Join-Path $repoRoot 'docs/management-overview.html'
            $acceptanceAudit = Join-Path $repoRoot 'docs/v1-phase1-acceptance-audit.md'
            $labReadinessChecklist = Join-Path $repoRoot 'docs/windows-lab-readiness-checklist.md'
            $powershellLabVerification = Join-Path $repoRoot 'docs/powershell-testing-lab-verification.md'
            $labEvidenceOverview = Join-Path $repoRoot 'docs/lab-evidence/README.md'
            $enterpriseEvidenceReadme = Join-Path $repoRoot 'docs/lab-evidence/windows-ad-enterprise-20260605-101639/README.md'
            $nonpermissiveWorkflow = Join-Path $repoRoot 'docs/nonpermissive-collection-dashboard-workflow.md'
            $webView2ViewerDoc = Join-Path $repoRoot 'docs/webview2-dashboard-viewer.md'
            $webView2ViewerProject = Join-Path $repoRoot 'apps/ShareSurfer.DashboardViewer/ShareSurfer.DashboardViewer.csproj'
            $webView2ViewerReadme = Join-Path $repoRoot 'apps/ShareSurfer.DashboardViewer/README.md'
            $webView2ViewerWindow = Join-Path $repoRoot 'apps/ShareSurfer.DashboardViewer/MainWindow.xaml.cs'
            $readme = Join-Path $repoRoot 'README.md'
            $expectedVisuals = @(
                'collector-to-report.svg',
                'enterprise-lab-validation.svg',
                'support-bundle-diagnostics.svg'
            )
            $expectedWorkflowImages = @(
                'share-surfer-workflow-concept.png',
                'nonpermissive-collector-workflow.svg',
                'dataset-transfer-dashboard-workflow.svg',
                'readme-flow-guides/first-scan-owner-review.png',
                'readme-flow-guides/locked-down-collector-dashboard-host.png',
                'readme-flow-guides/migration-discovery-cleanup-planning.png',
                'field-guide/evidence-pipeline.png',
                'field-guide/share-gate-ntfs-model.png',
                'field-guide/identity-org-enrichment.png',
                'field-guide/migration-discovery-signals.png',
                'field-guide/diagnostics-trust-review.png',
                'field-guide/redacted-support-handoff.png'
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
            Assert-True (Test-Path -LiteralPath $visualFieldGuide) 'Documentation should include a visual field guide.'
            $visualFieldGuideText = Get-Content -LiteralPath $visualFieldGuide -Raw
            Assert-True ($visualFieldGuideText -like '*ShareSurfer Visual Field Guide*') 'Visual field guide should have a clear title.'
            Assert-True ($visualFieldGuideText -like '*Evidence Pipeline*') 'Visual field guide should explain the evidence pipeline.'
            Assert-True ($visualFieldGuideText -like '*Share Gate vs File and Folder Permissions*') 'Visual field guide should explain the access model.'
            Assert-True ($visualFieldGuideText -like '*Identity and Org Enrichment*') 'Visual field guide should explain identity enrichment.'
            Assert-True ($visualFieldGuideText -like '*Migration Discovery Signals*') 'Visual field guide should explain migration discovery signals.'
            Assert-True ($visualFieldGuideText -like '*Diagnostics and Trust Review*') 'Visual field guide should explain diagnostics and trust review.'
            Assert-True ($visualFieldGuideText -like '*Redacted Support Handoff*') 'Visual field guide should explain redacted support handoff.'
            foreach ($workflowImage in $expectedWorkflowImages) {
                $path = Join-Path $visualRoot $workflowImage
                Assert-True (Test-Path -LiteralPath $path) ("Missing workflow image {0}" -f $workflowImage)
                Assert-True ((Get-Item -LiteralPath $path).Length -gt 7000) ("Workflow image {0} should be a real descriptive asset." -f $workflowImage)
                Assert-True ($visualDocText -like ("*visuals/{0}*" -f $workflowImage) -or $visualFieldGuideText -like ("*visuals/{0}*" -f $workflowImage)) ("Workflow documentation should reference {0}" -f $workflowImage)
                if ($workflowImage -like '*.svg') {
                    $workflowSvg = Get-Content -LiteralPath $path -Raw
                    Assert-True ($workflowSvg -like '*<svg*') ("Workflow image {0} should be an SVG asset." -f $workflowImage)
                    Assert-True ($workflowSvg -like '*Collector host*' -or $workflowSvg -like '*Dashboard review side*') ("Workflow image {0} should include descriptive operator labels." -f $workflowImage)
                    Assert-True ($workflowSvg -like '*Test-ShareSurferExport*' -or $workflowSvg -like '*Transfer control point*') ("Workflow image {0} should show validation or transfer gates." -f $workflowImage)
                }
            }
            Assert-True (Test-Path -LiteralPath $workflowGuide) 'Documentation should include a README workflow guide.'
            $workflowGuideText = Get-Content -LiteralPath $workflowGuide -Raw
            Assert-True ($workflowGuideText -like '*Start Here*') 'Workflow guide should include a short operator start-here path.'
            Assert-True ($workflowGuideText -like '*latest published prerelease*') 'Workflow guide should explain what to do if the checkpoint tag is not published yet.'
            Assert-True ($workflowGuideText -like '*First Scan to Owner Review*') 'Workflow guide should explain first scan to owner review.'
            Assert-True ($workflowGuideText -like '*Locked-Down Collector to Dashboard Host*') 'Workflow guide should explain the two-host flow.'
            Assert-True ($workflowGuideText -like '*Migration Discovery and Cleanup Planning*') 'Workflow guide should explain migration discovery cleanup planning.'
            Assert-True ($workflowGuideText -like '*Stop gate*') 'Workflow guide should include stop gates.'
            Assert-True ($workflowGuideText -like '*Stop Gates For Owner Review*') 'Workflow guide should include owner-review stop gates.'
            Assert-True ($workflowGuideText -like '*Go gate*') 'Workflow guide should include go gates.'
            Assert-True ($workflowGuideText -like '*Discounted principals*' -or $workflowGuideText -like '*discounted access principals*') 'Workflow guide should explain discounted access signal handling.'
            Assert-True ($workflowGuideText -like '*New-ShareSurferStandaloneDashboard.ps1*') 'Workflow guide should show dashboard packaging.'
            Assert-True ($workflowGuideText -like '*Get-FileHash -Algorithm SHA256*') 'Workflow guide should show handoff hash verification evidence.'
            Assert-True (Test-Path -LiteralPath $commandRecipes) 'Documentation should include first-run command recipes.'
            $commandRecipeText = Get-Content -LiteralPath $commandRecipes -Raw
            Assert-True ($commandRecipeText -like '*ShareSurfer Command Recipes*') 'Command recipes should have a clear title.'
            Assert-True ($commandRecipeText -like '*Command Inventory by Workflow*') 'Command recipes should include a workflow-grouped command inventory.'
            Assert-True ($commandRecipeText -like '*Start-ShareSurferOperatorAssistant*') 'Command recipes should include the guided operator assistant.'
            Assert-True ($commandRecipeText -like '*Start-ShareSurferStartup*') 'Command recipes should include the guided startup command.'
            Assert-True ($commandRecipeText -like '*Start-ShareSurfer.ps1*') 'Command recipes should include the release-root startup launcher.'
            Assert-True ($commandRecipeText -like '*one goal-based home screen*' -and $commandRecipeText -like '*Start a first scan (recommended)*') 'Command recipes should explain the goal-based first-scan entry point.'
            Assert-True ($commandRecipeText -like '*Run now*' -and $commandRecipeText -like '*Save plan and return home*' -and $commandRecipeText -like '*Show technical command*') 'Command recipes should explain the plain-language review actions.'
            Assert-True ($commandRecipeText -like '*Ownership and HR inputs are deferred by default*' -and $commandRecipeText -like '*Add ownership or HR data*') 'Command recipes should explain that ownership enrichment is optional for the first scan.'
            Assert-True ($commandRecipeText -like '*validated first scan*owner-mapping-draft.csv*' -and $commandRecipeText -like '*owner-mapping.csv*') 'Command recipes should explain the optional owner-mapping draft after validation.'
            Assert-True ($commandRecipeText -like '*Get-ChildItem -LiteralPath $releaseRoot -Recurse -File*') 'Command recipes should use the literal-path recursive unblock pattern.'
            Assert-True ($commandRecipeText -like '*Run once*' -and $commandRecipeText -like '*launcher itself*') 'Command recipes should explain the one launcher prompt boundary.'
            Assert-True ($commandRecipeText -like '*operator-assistant.plan.json*' -and $commandRecipeText -like '*operator-assistant-rerun.ps1*') 'Command recipes should show operator assistant plan and rerun outputs.'
            Assert-True ($commandRecipeText -like '*Join-ShareSurferOwnershipSources*') 'Command recipes should include multi-source ownership join guidance.'
            Assert-True ($commandRecipeText -like '*-IncludeContextGraph*') 'Command recipes should show ownership context graph ingestion.'
            Assert-True ($commandRecipeText -like '*ownership_context.csv*' -and $commandRecipeText -like '*ownership_relationships.csv*') 'Command recipes should name ownership context graph outputs.'
            Assert-True ($commandRecipeText -like '*ownership-import.definition.json*') 'Command recipes should show reusable ownership import definition output.'
            Assert-True ($commandRecipeText -like '*-ForbiddenOu*') 'Command recipes should show forbidden OU handling for AD ownership enrichment.'
            Assert-True ($commandRecipeText -like '*-OwnershipEnrichmentPath*') 'Command recipes should explain passing ownership enrichment into the scan.'
            Assert-True ($commandRecipeText -like '*New-ShareSurferLabFixture*') 'Command recipes should include lab fixture command inventory.'
            Assert-True ($commandRecipeText -like '*Stop Gates Before Owner Signoff*') 'Command recipes should include signoff stop gates.'
            Assert-True ($commandRecipeText -like '*latest published prerelease*') 'Command recipes should explain what to do if the checkpoint tag is not published yet.'
            Assert-True ($commandRecipeText -like '*Quick UNC Path Scan*') 'Command recipes should include UNC path scan guidance.'
            Assert-True ($commandRecipeText -like '*SMB Scan When WinRM or CIM Is Blocked*') 'Command recipes should include NativeSmbRpc fallback guidance.'
            Assert-True ($commandRecipeText -like '*New-ShareSurferStandaloneDashboard.ps1*') 'Command recipes should include standalone dashboard packaging.'
            Assert-True ($commandRecipeText -like '*Invoke-ShareSurferOpenFileAssessment*') 'Command recipes should include open-file assessment.'
            Assert-True ($commandRecipeText -like '*Invoke-ShareSurferFileShareConnectivityAssessment*') 'Command recipes should include file-share connectivity assessment.'
            Assert-True ($commandRecipeText -like '*fileshare_connectivity_llm_summary.md*') 'Command recipes should explain the redacted file-share connectivity summary.'
            Assert-True ($commandRecipeText -like '*New-ShareSurferSupportBundle*') 'Command recipes should include redacted support bundle creation.'
            Assert-True ($commandRecipeText -like '*Get-FileHash -Algorithm SHA256*') 'Command recipes should include SHA256 handoff verification.'
            Assert-True ($commandRecipeText -like '*Normalize HR, Employee, OBS, or Owner CSVs*') 'Command recipes should include ownership import guidance.'
            Assert-True ($commandRecipeText -like '*Test-ShareSurferOwnershipSource*') 'Command recipes should include ownership source testing.'
            Assert-True ($commandRecipeText -like '*New-ShareSurferOwnerMappingDraft*') 'Command recipes should include owner mapping draft creation.'
            Assert-True ($commandRecipeText -like '*-ReusableCommandPath*') 'Command recipes should show reusable command file output.'
            Assert-True ($commandRecipeText -like '*ownership-import-rerun.ps1*') 'Command recipes should name the ownership import rerun script.'
            Assert-True ($commandRecipeText -like '*owner-mapping-rerun.ps1*') 'Command recipes should name the owner mapping rerun script.'
            Assert-True (Test-Path -LiteralPath $adminOwnershipImport) 'Documentation should include an admin ownership import guide.'
            $adminOwnershipImportText = Get-Content -LiteralPath $adminOwnershipImport -Raw
            Assert-True ($adminOwnershipImportText -like '*Admin Ownership Import*') 'Admin ownership import guide should have a clear title.'
            Assert-True ($adminOwnershipImportText -like '*without AI or LLM calls*' -or $adminOwnershipImportText -like '*does not call an AI service*') 'Admin ownership import guide should explain the workflow is deterministic and offline.'
            Assert-True ($adminOwnershipImportText -like '*visuals/readme-flow-guides/ownership-import-reusable-commands.png*') 'Admin ownership import guide should show the ownership import visual.'
            Assert-True ($adminOwnershipImportText -like '*Test-ShareSurferOwnershipSource*') 'Admin ownership import guide should document source testing.'
            Assert-True ($adminOwnershipImportText -like '*New-ShareSurferOwnershipMappingProfile*') 'Admin ownership import guide should document mapping profiles.'
            Assert-True ($adminOwnershipImportText -like '*Import-ShareSurferOwnershipSource*') 'Admin ownership import guide should document normalized import.'
            Assert-True ($adminOwnershipImportText -like '*Project, OBS, Path, And Group Context Files*') 'Admin ownership import guide should document context graph ingestion.'
            Assert-True ($adminOwnershipImportText -like '*Project -> OBS*' -and $adminOwnershipImportText -like '*OBS -> DataOwner*') 'Admin ownership import guide should explain project and OBS relationships.'
            Assert-True ($adminOwnershipImportText -like '*PotentialServiceAccount*') 'Admin ownership import guide should explain potential service-account-like flags.'
            Assert-True ($adminOwnershipImportText -like '*ReusableCommands*') 'Admin ownership import guide should explain reusable command output.'
            Assert-True ($adminOwnershipImportText -like '*-ReusableCommandPath*') 'Admin ownership import guide should document reusable command file output.'
            Assert-True ($adminOwnershipImportText -like '*ownership-csv-ingest-quick-reference.md*') 'Admin ownership import guide should link the ownership CSV ingest quick reference.'
            Assert-True (Test-Path -LiteralPath $ownershipCsvIngestQuickReference) 'Documentation should include an ownership CSV ingest quick reference.'
            $ownershipCsvIngestQuickReferenceText = Get-Content -LiteralPath $ownershipCsvIngestQuickReference -Raw
            Assert-True ($ownershipCsvIngestQuickReferenceText -like '*Ownership CSV Ingest Quick Reference*') 'Ownership CSV ingest quick reference should have a clear title.'
            Assert-True ($ownershipCsvIngestQuickReferenceText -like '*Test-ShareSurferOwnershipSource*') 'Ownership CSV ingest quick reference should show source testing.'
            Assert-True ($ownershipCsvIngestQuickReferenceText -like '*New-ShareSurferOwnershipMappingProfile*') 'Ownership CSV ingest quick reference should show mapping profile creation.'
            Assert-True ($ownershipCsvIngestQuickReferenceText -like '*Import-ShareSurferOwnershipSource*') 'Ownership CSV ingest quick reference should show normalized import.'
            Assert-True ($ownershipCsvIngestQuickReferenceText -like '*Include Project, OBS, Path, Or Group Context*') 'Ownership CSV ingest quick reference should show context graph ingestion.'
            Assert-True ($ownershipCsvIngestQuickReferenceText -like '*ownership_import_manifest.csv*') 'Ownership CSV ingest quick reference should name the context graph manifest.'
            Assert-True ($ownershipCsvIngestQuickReferenceText -like '*ownership-import-rerun.ps1*') 'Ownership CSV ingest quick reference should show reusable rerun script usage.'
            Assert-True ($ownershipCsvIngestQuickReferenceText -like '*PotentialServiceAccount=True*') 'Ownership CSV ingest quick reference should explain potential service-account review flags.'
            Assert-True (Test-Path -LiteralPath $glossary) 'Documentation should include a first-run glossary.'
            $glossaryText = Get-Content -LiteralPath $glossary -Raw
            Assert-True ($glossaryText -like '*ShareSurfer Glossary*') 'Glossary should have a clear title.'
            Assert-True ($glossaryText -like '*Owner*' -and $glossaryText -like '*NTFS owner*') 'Glossary should distinguish owner from NTFS owner.'
            Assert-True ($glossaryText -like '*Broken/Missing SID*') 'Glossary should define broken or missing SIDs.'
            Assert-True ($glossaryText -like '*Partial data*') 'Glossary should define partial data.'
            Assert-True ($glossaryText -like '*Discounted access principal*') 'Glossary should define discounted principals.'
            Assert-True ($glossaryText -like '*Migration Discovery*') 'Glossary should define Migration Discovery.'
            Assert-True ($glossaryText -like '*Dashboard host*') 'Glossary should define dashboard host.'
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
            foreach ($workflowImage in $expectedWorkflowImages) {
                Assert-True ($visualReadmeText -like ("*{0}*" -f $workflowImage)) ("Visual README should name workflow image {0}." -f $workflowImage)
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
            $startupLauncherText = Get-Content -LiteralPath (Join-Path $repoRoot 'Start-ShareSurfer.ps1') -Raw
            Assert-True ($startupLauncherText -like '*Remove-ShareSurferLauncherZoneIdentifierStream*') 'Release-root launcher should explicitly clear Zone.Identifier markers before module import.'
            Assert-True ($startupLauncherText -like '*Get-ChildItem -LiteralPath $Root -Recurse -File*') 'Release-root launcher should use literal recursive file enumeration for unblock.'
            Assert-True ($startupLauncherText -like '*explicitly cleared*downloaded-file marker*') 'Release-root launcher should report downloaded-file marker cleanup.'
            Assert-True ($startupLauncherText -like '*Import-Module $modulePath -Force -PassThru*') 'Release-root launcher should retain the imported module instance.'
            Assert-True ($startupLauncherText -like '*Invoke-ShareSurferLauncherModuleCommand*' -and $startupLauncherText -like '*Start-ShareSurfer*' -and $startupLauncherText -like '*ReleaseRoot = $releaseRoot*') 'Release-root launcher should enter the module-bound Start-ShareSurfer menu when no startup config path is supplied.'
            Assert-True ($startupLauncherText -like '*$menuParams*' -and $startupLauncherText -like '*$PSBoundParameters.ContainsKey(''ObsAttribute'')*') 'Release-root launcher should distinguish explicit settings from defaults so saved context can be restored safely.'
            Assert-True ($startupLauncherText -like '*Invoke-ShareSurferLauncherModuleCommand*' -and $startupLauncherText -like '*Start-ShareSurferStartup*' -and $startupLauncherText -like '*Parameters $startupParams*') 'Release-root launcher should preserve startup config replay through the imported module command.'
            $startupCommandText = Get-Content -LiteralPath (Join-Path $repoRoot 'src/ShareSurfer/Public/Start-ShareSurferStartup.ps1') -Raw
            Assert-True ($startupCommandText -like '*Read-ShareSurferFirstScanConfiguration*') 'Startup command should use the simplified first-scan configuration flow.'
            Assert-True ($startupCommandText -like '*Continue with recommended settings*' -and $startupCommandText -like '*Customize technical settings*') 'Startup command should make recommended settings the primary decision.'
            Assert-True ($startupCommandText -like '*Run now*' -and $startupCommandText -like '*Save plan and return home (recommended)*' -and $startupCommandText -like '*Show technical command*') 'Startup command should expose the approved final review actions.'
            $releaseMetadata = Get-Content -LiteralPath (Join-Path $repoRoot 'release-metadata.json') -Raw | ConvertFrom-Json
            $currentReleaseTag = [string]$releaseMetadata.currentPrereleaseTag
            $currentReleaseZip = [string]$releaseMetadata.zipAssetName
            $currentReleaseRoot = 'C:\{0}' -f [string]$releaseMetadata.packageName
            $oldNestedReleaseRoot = 'C:\ShareSurfer\{0}' -f [string]$releaseMetadata.packageName
            $readmeText = Get-Content -LiteralPath $readme -Raw
            Assert-True ($readmeText -like '*Invoke-ShareSurferPester.ps1*') 'README should document the optional Pester wrapper.'
            Assert-True ($readmeText -like '*windows-lab-readiness-checklist.md*') 'README should link the Windows lab readiness checklist.'
            Assert-True ($readmeText -like '*v1-phase1-acceptance-audit.md*') 'README should link the V1 phase-1 acceptance audit.'
            Assert-True ($readmeText -like '*Start Here*') 'README should include a short operator start-here path.'
            Assert-True ($readmeText -like '*Start-ShareSurferOperatorAssistant*') 'README should include the guided operator assistant command.'
            Assert-True ($readmeText -like '*Start-ShareSurferStartup*') 'README should include the guided startup command.'
            Assert-True ($readmeText -like '*Start-ShareSurfer.ps1*') 'README should include the release-root startup launcher.'
            Assert-True ($readmeText -like '*one goal-based home screen*' -and $readmeText -like '*Start a first scan (recommended)*') 'README should explain the goal-based home and recommended first-scan entry point.'
            Assert-True ($readmeText -like '*folders only*compact ACL output*identity enrichment*permission diagnostics enabled*ownership inputs deferred*') 'README should explain the recommended first-scan defaults.'
            Assert-True ($readmeText -like '*Run now*' -and $readmeText -like '*Save plan and return home*' -and $readmeText -like '*Show technical command*') 'README should explain the plain-language final review actions.'
            Assert-True ($readmeText -like '*recommended first-scan preset does not require ownership files*' -and $readmeText -like '*Add ownership or HR data*') 'README should explain that ownership enrichment is optional for a first scan.'
            Assert-True ($readmeText -like '*validated first scan*owner-mapping-draft.csv*') 'README should explain optional owner mapping draft creation after validation.'
            Assert-True ($readmeText -like '*share-permission-diagnostics*share_permission_diagnostics.md*') 'README should point operators to the share-permission diagnostic summary.'
            Assert-True ($readmeText -like '*operator-assistant.plan.json*' -and $readmeText -like '*operator-assistant-rerun.ps1*') 'README should explain operator assistant plan and rerun outputs.'
            Assert-True ($readmeText -like '*Pause Before Owner Signoff*') 'README should include owner signoff stop gates.'
            Assert-True ($readmeText -like '*Command Inventory by Workflow*') 'README should group public commands by workflow.'
            Assert-True ($readmeText -like '*Test-ShareSurferOwnershipSource*' -and $readmeText -like '*New-ShareSurferReviewDecisionDraft*') 'README command inventory should include ownership and review decision commands.'
            Assert-True ($readmeText -like '*Invoke-ShareSurferFileShareConnectivityAssessment*') 'README command inventory should include file-share connectivity assessment.'
            Assert-True ($readmeText -like '*fileshare_connectivity_checks.csv*') 'README should mention file-share connectivity output evidence.'
            Assert-True ($readmeText -like '*Evidence confidence or protocol readiness blockers*') 'README stop gates should mention evidence confidence and protocol readiness blockers.'
            Assert-True ($readmeText -like '*Missing owner or business-unit mapping*') 'README stop gates should mention missing owner or business-unit mapping.'
            Assert-True ($readmeText -like '*latest published prerelease*') 'README should explain what to do if the checkpoint tag is not published yet.'
            Assert-True ($readmeText -like '*How ShareSurfer Works*') 'README should tell the ShareSurfer story near the top.'
            Assert-True ($readmeText -like '*Owner** means the mapped business or data reviewer*') 'README should define ShareSurfer owner in the early story section.'
            Assert-True ($readmeText -like '*docs/visuals/field-guide/evidence-pipeline.png*') 'README should show the evidence pipeline visual in the early story section.'
            Assert-True ($readmeText -like '*docs/visuals/field-guide/share-gate-ntfs-model.png*') 'README should show the share gate visual in the early story section.'
            Assert-True ($readmeText -like '*docs/visuals/field-guide/identity-org-enrichment.png*') 'README should show the identity enrichment visual in the early story section.'
            Assert-True ($readmeText -like '*docs/visuals/field-guide/migration-discovery-signals.png*') 'README should show the migration discovery signals visual in the early story section.'
            Assert-True ($readmeText -like '*docs/visuals/field-guide/diagnostics-trust-review.png*') 'README should show the diagnostics trust visual in the early story section.'
            Assert-True ($readmeText -like '*docs/visuals/field-guide/redacted-support-handoff.png*') 'README should show the redacted support handoff visual in the early story section.'
            Assert-True ($readmeText -like '*Basic Use Cases*') 'README should present basic use cases.'
            Assert-True ($readmeText -like '*Workflow Guides*') 'README should include workflow guide visuals.'
            Assert-True ($readmeText -like '*docs/visual-field-guide.md*') 'README should link the visual field guide.'
            Assert-True ($readmeText -like '*docs/workflow-guides.md*') 'README should link the workflow guide.'
            Assert-True ($readmeText -like '*docs/command-recipes.md*') 'README should link the command recipes.'
            Assert-True ($readmeText -like '*docs/glossary.md*') 'README should link the glossary.'
            Assert-True ($readmeText -like '*docs/ownership-csv-ingest-quick-reference.md*') 'README should link the ownership CSV ingest quick reference.'
            Assert-True ($readmeText -like '*docs/visuals/readme-flow-guides/first-scan-owner-review.png*') 'README should show the first scan owner review visual.'
            Assert-True ($readmeText -like '*docs/visuals/readme-flow-guides/ownership-import-reusable-commands.png*') 'README should show the ownership import reusable commands visual.'
            Assert-True (Test-Path -LiteralPath (Join-Path $repoRoot 'docs/visuals/readme-flow-guides/ownership-import-reusable-commands.png')) 'Documentation should include the ownership import reusable commands visual asset.'
            Assert-True ($readmeText -like '*docs/visuals/readme-flow-guides/locked-down-collector-dashboard-host.png*') 'README should show the locked-down collector dashboard visual.'
            Assert-True ($readmeText -like '*docs/visuals/readme-flow-guides/migration-discovery-cleanup-planning.png*') 'README should show the migration discovery visual.'
            Assert-True ($readmeText -like '*ownership-import-rerun.ps1*') 'README should document the reusable ownership import command file.'
            Assert-True ($readmeText -like '*owner-mapping-rerun.ps1*') 'README should document the reusable owner mapping draft command file.'
            Assert-True ($readmeText -like '*ownership-import.definition.json*') 'README should document reusable ownership import definitions.'
            Assert-True ($readmeText -like '*Join-ShareSurferOwnershipSources*' -and $readmeText -like '*-ForbiddenOu*') 'README should show AD/OBS ownership enrichment and forbidden OU handling.'
            Assert-True ($readmeText -like '*employee ID or employee number*') 'README should explain AD ownership enrichment from employee identifiers.'
            Assert-True ($readmeText -like '*-OwnershipEnrichmentPath*') 'README should explain passing ownership enrichment into scans.'
            Assert-True ($readmeText -like '*Nonpermissive collector workflow*') 'README should present the nonpermissive collector use case.'
            Assert-True ($readmeText -like '*Nonpermissive / Two-Host Operation*') 'README should include the nonpermissive operating model on the main page.'
            Assert-True ($readmeText -like '*docs/visuals/nonpermissive-collector-workflow.svg*') 'README should show the nonpermissive collector workflow visual.'
            Assert-True ($readmeText -like '*Collector host:*') 'README should explain the collector host role.'
            Assert-True ($readmeText -like '*Dashboard host:*') 'README should explain the dashboard host role.'
            Assert-True ($readmeText -like '*docs/nonpermissive-collection-dashboard-workflow.md*') 'README should link the nonpermissive collection workflow.'
            Assert-True ($readmeText -like '*docs/visuals/dataset-transfer-dashboard-workflow.svg*') 'README should show the dataset transfer dashboard visual.'
            Assert-True ($readmeText -like '*Quick Start in a Nonpermissive Environment*') 'README should include nonpermissive quickstart setup instructions.'
            Assert-True ($readmeText -like ('*{0}*' -f $currentReleaseTag)) 'README should reference the current pre-release quickstart package.'
            Assert-True ($readmeText -like ('*{0}*' -f $currentReleaseZip)) 'README should name the current pre-release zip asset.'
            Assert-True ($readmeText -like ('*{0}*' -f $currentReleaseRoot)) 'README should show the simplified version-root release path.'
            Assert-True ($readmeText -notlike ('*{0}*' -f $oldNestedReleaseRoot)) 'README should not show the older nested release root path.'
            Assert-True ($readmeText -like '*Unblock-File*') 'README should show how to recursively unblock extracted PowerShell files.'
            Assert-True ($readmeText -like '*Get-ChildItem -LiteralPath $releaseRoot -Recurse -File*') 'README should use the literal-path recursive unblock pattern.'
            Assert-True ($readmeText -like '*one prompt for the launcher*' -and $readmeText -like '*cannot unblock itself before it starts*') 'README should explain why the launcher can still receive one Windows prompt.'
            Assert-True ($readmeText -like '*without npm, Vite, a development server, or internet access*') 'README should explain release dashboard use without npm or a server.'
            Assert-True ($readmeText -like '*template/onboarding screen*') 'README should explain release dashboard template behavior before export packaging.'
            Assert-True ($readmeText -like '*$shareSurferRoot*') 'README nonpermissive quickstart should show where the copied ShareSurfer folder is staged.'
            Assert-True ($readmeText -like '*$ownershipSourcePath*') 'README nonpermissive quickstart should show a candidate HR/OBS ownership source path.'
            Assert-True ($readmeText -like '*The*Unblock-File*line is repeated here on purpose*') 'README nonpermissive quickstart should explicitly repeat and explain the unblock step.'
            Assert-True ($readmeText -like '*Windows may still ask once for*Start-ShareSurfer.ps1*') 'README nonpermissive quickstart should explain the launcher first-prompt case.'
            Assert-True ($readmeText -like '*Compress-Archive*') 'README nonpermissive quickstart should show how to package the validated export folder.'
            Assert-True ($readmeText -like '*Get-FileHash -Algorithm SHA256*') 'README nonpermissive quickstart should show how to hash the handoff package.'
            Assert-True ($readmeText -like '*approved transfer process*') 'README nonpermissive quickstart should explain the approved transfer process.'
            Assert-True ($readmeText -like '*Pre-1.0 Release Packaging*') 'README should document the unsigned pre-1.0 package path.'
            Assert-True ($readmeText -like '*release-metadata.json*') 'README should document the release metadata source.'
            Assert-True ($readmeText -like '*New-ShareSurferRelease.ps1*') 'README should document the release packager script.'
            Assert-True ($readmeText -like '*UnsignedPre1.0*') 'README should name the release manifest unsigned status.'
            Assert-True ($readmeText -like '*interface/standalone-dashboard/dist*') 'README should explain where prebuilt dashboard assets are packaged.'
            Assert-True ($readmeText -like '*docs/webview2-dashboard-viewer.md*') 'README should link the WebView2 dashboard viewer concept.'
            Assert-True ($readmeText -like '*docs/first-run-troubleshooting.md*') 'README should link the first-run troubleshooting guide.'
            Assert-True ($readmeText -like '*docs/business-review-handoff.md*') 'README should link the business review handoff guide.'
            Assert-True ($readmeText -like '*docs/powershell-testing-lab-verification.md*') 'README should link PowerShell testing and lab verification guidance.'

            Assert-True (Test-Path -LiteralPath $webView2ViewerDoc) 'Documentation should include the WebView2 dashboard viewer concept.'
            $webView2Text = Get-Content -LiteralPath $webView2ViewerDoc -Raw
            Assert-True ($webView2Text -like '*small signed Windows executable*') 'WebView2 concept should explain the signed viewer purpose.'
            Assert-True ($webView2Text -like '*static dashboard package remains the portable evidence artifact*') 'WebView2 concept should keep the static dashboard package as source of truth.'
            Assert-True ($webView2Text -like '*Block external navigation*') 'WebView2 concept should define the external-navigation boundary.'
            Assert-True ($webView2Text -like '*WebView2 Evergreen Runtime*') 'WebView2 concept should explain runtime distribution.'
            Assert-True ($webView2Text -like '*future Authenticode signature*') 'WebView2 concept should distinguish future signing from the current concept.'
            Assert-True ($webView2Text -like '*Microsoft.Web.WebView2 NuGet package*') 'WebView2 concept should link the WebView2 SDK package reference.'
            Assert-True (Test-Path -LiteralPath $webView2ViewerProject) 'Repository should include the WebView2 viewer project scaffold.'
            Assert-True (Test-Path -LiteralPath $webView2ViewerReadme) 'Repository should include the WebView2 viewer README.'
            Assert-True (Test-Path -LiteralPath $webView2ViewerWindow) 'Repository should include the WebView2 viewer window code.'
            $webView2ProjectText = Get-Content -LiteralPath $webView2ViewerProject -Raw
            [xml]$webView2ProjectXml = $webView2ProjectText
            Assert-True ($webView2ProjectText -like '*net8.0-windows*') 'WebView2 viewer should target Windows .NET.'
            Assert-True ($webView2ProjectText -like '*UseWPF*') 'WebView2 viewer should use the WPF desktop stack.'
            Assert-True ($webView2ProjectText -like '*Microsoft.Web.WebView2*') 'WebView2 viewer should reference the WebView2 SDK.'
            Assert-True ($webView2ProjectXml.Project.ItemGroup.PackageReference.Include -eq 'Microsoft.Web.WebView2') 'WebView2 project XML should parse with the expected package reference.'
            $webView2WindowText = Get-Content -LiteralPath $webView2ViewerWindow -Raw
            Assert-True ($webView2WindowText -like '*BlockExternalNavigation*') 'WebView2 viewer code should include an external-navigation guard.'
            Assert-True ($webView2WindowText -like '*Uri.UriSchemeFile*') 'WebView2 viewer code should allow only local file navigation.'
            Assert-True ($webView2WindowText -like '*AreHostObjectsAllowed = false*') 'WebView2 viewer code should keep host objects disabled.'

            Assert-True (Test-Path -LiteralPath $acceptanceAudit) 'Documentation should include a V1 phase-1 acceptance audit.'
            $acceptanceAuditText = Get-Content -LiteralPath $acceptanceAudit -Raw
            Assert-True ($acceptanceAuditText -like '*Requirement Matrix*') 'Acceptance audit should include a requirement matrix.'
            Assert-True ($acceptanceAuditText -like '*Issue #1 lab fixture proof*') 'Acceptance audit should link issue #1 proof.'
            Assert-True ($acceptanceAuditText -like '*Issue #3 scanner proof*') 'Acceptance audit should link issue #3 proof.'
            Assert-True ($acceptanceAuditText -like '*Issue #5 identity and group proof*') 'Acceptance audit should link issue #5 proof.'
            Assert-True ($acceptanceAuditText -like '*Issue #6 dashboard proof*') 'Acceptance audit should link issue #6 proof.'
            Assert-True ($acceptanceAuditText -like '*FallbackCount=0*') 'Acceptance audit should summarize the live evidence fallback status.'
            Assert-True ($acceptanceAuditText -like '*Optional rich enterprise support bundle*') 'Acceptance audit should explain optional rich support-bundle scope.'
            Assert-True ($acceptanceAuditText -like '*Proof issues: #1, #3, #5, and #6 are closed after human review*') 'Acceptance audit should record the accepted phase-1 proof issue state.'
            Assert-True ($acceptanceAuditText -like '*issuecomment-4635064013*') 'Acceptance audit should link the issue #5 human-review closeout comment.'
            Assert-True ($acceptanceAuditText -like '*Current-schema verifier*Test-ShareSurferArchivedEnterpriseProof.ps1*') 'Acceptance audit should name the one-command current-schema verifier.'
            Assert-True ($acceptanceAuditText.Contains('regenerated export, not `refreshed-evidence/export`')) 'Acceptance audit should steer readers away from the untracked refreshed export path.'
            Assert-True ($acceptanceAuditText -like '*fresh live lab rerun*new host-side AD, filesystem, or collector evidence*') 'Acceptance audit should distinguish archived proof refresh from fresh live rerun needs.'

            Assert-True (Test-Path -LiteralPath $firstRunGuide) 'Documentation should include an amateur-admin-friendly first-run guide.'
            Assert-True (Test-Path -LiteralPath $firstRunTroubleshooting) 'Documentation should include first-run troubleshooting guidance.'
            Assert-True (Test-Path -LiteralPath $businessReviewHandoff) 'Documentation should include business review handoff guidance.'
            $firstRunText = Get-Content -LiteralPath $firstRunGuide -Raw
            $firstRunTroubleshootingText = Get-Content -LiteralPath $firstRunTroubleshooting -Raw
            $businessReviewHandoffText = Get-Content -LiteralPath $businessReviewHandoff -Raw
            Assert-True ($firstRunText -like '*Start Here*') 'First-run guide should include a short start-here section.'
            Assert-True ($firstRunText -like '*Start-ShareSurferOperatorAssistant*') 'First-run guide should include the guided operator assistant.'
            Assert-True ($firstRunText -like '*Start-ShareSurferStartup*') 'First-run guide should include the guided startup command.'
            Assert-True ($firstRunText -like '*Start-ShareSurfer.ps1*') 'First-run guide should include the release-root startup launcher.'
            Assert-True ($firstRunText -like '*Start a first scan (recommended)*' -and $firstRunText -like '*Continue with recommended settings*') 'First-run guide should explain the recommended goal-based path.'
            Assert-True ($firstRunText -like '*Run now*' -and $firstRunText -like '*Save plan and return home*' -and $firstRunText -like '*Show technical command*') 'First-run guide should explain the final review actions.'
            Assert-True ($firstRunText -like '*Ownership enrichment is optional for the first scan*' -and $firstRunText -like '*Add ownership or HR data*') 'First-run guide should defer ownership enrichment from the required first-scan path.'
            Assert-True ($firstRunText -like '*validated first scan*owner-mapping-draft.csv*' -and $firstRunText -like '*save it as*owner-mapping.csv*') 'First-run guide should explain optional owner mapping draft completion after validation.'
            Assert-True ($firstRunText -like '*share-permission-diagnostics*share_permission_diagnostics.md*') 'First-run guide should point operators to the share-permission diagnostic summary.'
            Assert-True ($firstRunText -like '*operator-assistant.plan.json*' -and $firstRunText -like '*operator-assistant-rerun.ps1*') 'First-run guide should explain operator assistant outputs.'
            Assert-True ($firstRunText -like '*Stop gates are conditions*') 'First-run guide should explain stop gates before the longer walkthrough.'
            Assert-True ($firstRunText -like '*latest published prerelease*') 'First-run guide should explain what to do if the checkpoint tag is not published yet.'
            Assert-True ($firstRunText -like '*first-time*') 'First-run guide should explicitly address first-time operators.'
            Assert-True ($firstRunText -like '*glossary*') 'First-run guide should link glossary definitions.'
            Assert-True ($firstRunText -like '*command recipes*') 'First-run guide should link command recipes.'
            Assert-True ($firstRunText -like '*Before You Run Checklist*') 'First-run guide should include a before-run checklist.'
            Assert-True ($firstRunText -like '*Which Scan Command Should I Use?*') 'First-run guide should help operators choose a scan command shape.'
            Assert-True ($firstRunText -like '*What good looks like after validation*') 'First-run guide should explain validation success criteria.'
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
            Assert-True ($firstRunText -like '*ownership-import-rerun.ps1*') 'First-run guide should show reusable ownership import commands.'
            Assert-True ($firstRunText -like '*ownership-import.definition.json*') 'First-run guide should show reusable ownership import definitions.'
            Assert-True ($firstRunText -like '*Join-ShareSurferOwnershipSources*') 'First-run guide should show multi-source ownership enrichment before scanning.'
            Assert-True ($firstRunText -like '*-ForbiddenOu*') 'First-run guide should show forbidden OU handling for AD enrichment.'
            Assert-True ($firstRunText -like '*-OwnershipEnrichmentPath*') 'First-run guide should explain passing ownership enrichment into scans.'
            Assert-True ($firstRunText -like '*owner-mapping-rerun.ps1*') 'First-run guide should show reusable owner mapping draft commands.'
            Assert-True ($firstRunText -like '*What Needs Review First*') 'First-run guide should point users to the owner review queue.'
            Assert-True ($firstRunText -like '*Access Model*') 'First-run guide should point users to the access model view.'
            Assert-True ($firstRunText -like '*OwnerMetadataUnavailable*') 'First-run guide should explain owner metadata unavailable findings.'
            Assert-True ($firstRunText -like '*does not automatically mean the file has no real Windows owner*') 'First-run guide should avoid implying blank owner metadata means no Windows owner exists.'
            Assert-True ($firstRunText -like '*choose an attribute that exists on both users and groups*') 'First-run guide should explain OBS attribute schema fallback.'
            Assert-True ($firstRunText -like '*Move the Dataset to a Dashboard Host*') 'First-run guide should explain the two-host dashboard workflow.'
            Assert-True ($firstRunText -like '*visuals/nonpermissive-collector-workflow.svg*') 'First-run guide should show the nonpermissive collector workflow visual.'
            Assert-True ($firstRunText -like ('*{0} release package*' -f $currentReleaseTag)) 'First-run guide should reference the current pre-release dashboard package.'
            Assert-True ($firstRunText -like ('*{0}*' -f $currentReleaseRoot)) 'First-run guide should show the simplified version-root release path.'
            Assert-True ($firstRunText -notlike ('*{0}*' -f $oldNestedReleaseRoot)) 'First-run guide should not show the older nested release root path.'
            Assert-True ($firstRunText -like '*Unblock-File*') 'First-run guide should show how to recursively unblock extracted PowerShell files.'
            Assert-True ($firstRunText -like '*Get-ChildItem -LiteralPath $releaseRoot -Recurse -File*') 'First-run guide should use the literal-path recursive unblock pattern.'
            Assert-True ($firstRunText -like '*Run once*' -and $firstRunText -like '*cannot unblock the launcher before Windows starts it*') 'First-run guide should explain the one launcher prompt boundary.'
            Assert-True ($firstRunText -like '*do not need Node, npm, Vite, a development server, or internet access*') 'First-run guide should explain release dashboard packaging without npm tooling.'
            Assert-True ($firstRunText -like '*first-run troubleshooting guide*') 'First-run guide should link the troubleshooting guide.'
            Assert-True ($firstRunText -like '*Invoke-ShareSurferFileShareConnectivityAssessment*') 'First-run guide should include file-share connectivity diagnostics.'
            Assert-True ($firstRunText -like '*fileshare_connectivity_llm_summary.md*') 'First-run guide should mention the redacted file-share connectivity summary.'
            Assert-True ($firstRunTroubleshootingText -like '*Start Here*') 'Troubleshooting guide should include a start-here triage section.'
            Assert-True ($firstRunTroubleshootingText -like '*WinRM or CIM cannot connect*') 'Troubleshooting guide should cover WinRM/CIM collection gaps.'
            Assert-True ($firstRunTroubleshootingText -like '*Owner mapping file was not found*') 'Troubleshooting guide should cover missing owner mapping inputs.'
            Assert-True ($firstRunTroubleshootingText -like '*ownership-enrichment.csv*is missing*' -and $firstRunTroubleshootingText -like '*ownership-import-rerun.ps1*') 'Troubleshooting guide should cover missing ownership enrichment setup.'
            Assert-True ($firstRunTroubleshootingText -like '*doubled folder*') 'Troubleshooting guide should cover common release extraction folder mistakes.'
            Assert-True ($firstRunTroubleshootingText -like '*release contains tools and dashboard template assets*') 'Troubleshooting guide should distinguish release folders from scan export folders.'
            Assert-True ($firstRunTroubleshootingText -like '*BrokenOrMissingSid*') 'Troubleshooting guide should cover broken or missing SID findings.'
            Assert-True ($firstRunTroubleshootingText -like '*When To Rerun*') 'Troubleshooting guide should distinguish rerun decisions.'
            Assert-True ($firstRunTroubleshootingText -like '*When To Hand Off To Reviewers*') 'Troubleshooting guide should distinguish business-review handoff decisions.'
            Assert-True ($firstRunText -like '*business-review handoff*' -or $firstRunText -like '*Business review handoff*') 'First-run guide should link business review handoff guidance.'
            Assert-True ($businessReviewHandoffText -like '*What To Send*') 'Business review handoff should explain what to send to reviewers.'
            Assert-True ($businessReviewHandoffText -like '*Do Not Hand Off Yet If*') 'Business review handoff should define stop conditions.'
            Assert-True ($businessReviewHandoffText -like '*Suggested Owner Review Request*') 'Business review handoff should include copy-ready owner request wording.'
            Assert-True ($businessReviewHandoffText -like '*This report is read-only evidence*') 'Business review handoff should explain the report is not a permissions change or approval record.'

            Assert-True (Test-Path -LiteralPath $nonpermissiveWorkflow) 'Documentation should include a nonpermissive collector to dashboard host workflow.'
            $nonpermissiveText = Get-Content -LiteralPath $nonpermissiveWorkflow -Raw
            Assert-True ($nonpermissiveText -like '*Collector host*') 'Nonpermissive workflow should define the collector host role.'
            Assert-True ($nonpermissiveText -like '*Dashboard host*') 'Nonpermissive workflow should define the dashboard host role.'
            Assert-True ($nonpermissiveText -like '*Compress-Archive*') 'Nonpermissive workflow should explain dataset packaging.'
            Assert-True ($nonpermissiveText -like '*Get-FileHash*') 'Nonpermissive workflow should explain hash generation.'
            Assert-True ($nonpermissiveText -like '*approved transfer process*') 'Nonpermissive workflow should require approved transfer handling.'
            Assert-True ($nonpermissiveText -like '*New-ShareSurferStandaloneDashboard.ps1*') 'Nonpermissive workflow should show dashboard packaging on the review host.'
            Assert-True ($nonpermissiveText -like ('*{0}*' -f $currentReleaseZip)) 'Nonpermissive workflow should name the current pre-release zip asset.'
            Assert-True ($nonpermissiveText -like ('*{0}*' -f $currentReleaseRoot)) 'Nonpermissive workflow should show the simplified version-root release path.'
            Assert-True ($nonpermissiveText -notlike ('*{0}*' -f $oldNestedReleaseRoot)) 'Nonpermissive workflow should not show the older nested release root path.'
            Assert-True ($nonpermissiveText -like '*Unblock-File*') 'Nonpermissive workflow should show how to recursively unblock extracted PowerShell files.'
            Assert-True ($nonpermissiveText -like '*ownership-enrichment.csv*') 'Nonpermissive workflow should show pre-scan ownership enrichment output.'
            Assert-True ($nonpermissiveText -like '*Join-ShareSurferOwnershipSources*') 'Nonpermissive workflow should show AD/OBS ownership normalization before scanning.'
            Assert-True ($nonpermissiveText -like '*-ForbiddenOu*') 'Nonpermissive workflow should show forbidden OU handling for AD ownership enrichment.'
            Assert-True ($nonpermissiveText -like '*OwnershipEnrichmentPath*') 'Nonpermissive workflow should pass ownership enrichment into collection when present.'
            Assert-True ($nonpermissiveText -like '*no npm or Vite is required*') 'Nonpermissive workflow should make release dashboard packaging no-npm.'
            Assert-True ($nonpermissiveText -like '*visuals/nonpermissive-collector-workflow.svg*') 'Nonpermissive workflow should reference the collector visual.'
            Assert-True ($nonpermissiveText -like '*visuals/dataset-transfer-dashboard-workflow.svg*') 'Nonpermissive workflow should reference the dashboard-transfer visual.'
            Assert-True ($nonpermissiveText -like '*Collector handoff checklist*') 'Nonpermissive workflow should include a collector handoff checklist.'
            Assert-True ($nonpermissiveText -like '*Dashboard host received-package checklist*') 'Nonpermissive workflow should include a dashboard-host intake checklist.'
            Assert-True ($nonpermissiveText -like '*$actualHash -eq $expectedHash*') 'Nonpermissive workflow should show a dashboard-host hash verification check.'
            Assert-True ($nonpermissiveText -like '*latest published prerelease*') 'Nonpermissive workflow should explain what to do if the checkpoint tag is not published yet.'

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
            Assert-True (Test-Path -LiteralPath $powershellLabVerification) 'Documentation should include PowerShell testing and lab verification guidance.'
            $powershellLabVerificationText = Get-Content -LiteralPath $powershellLabVerification -Raw
            Assert-True ($powershellLabVerificationText -like '*PowerShell Testing And Lab Verification*') 'PowerShell lab verification guide should have a clear title.'
            Assert-True ($powershellLabVerificationText -like '*Local PowerShell Core smoke*') 'PowerShell lab verification guide should distinguish local PowerShell Core smoke checks.'
            Assert-True ($powershellLabVerificationText -like '*Windows PowerShell 5.1 CI smoke*') 'PowerShell lab verification guide should distinguish Windows PowerShell 5.1 CI checks.'
            Assert-True ($powershellLabVerificationText -like '*Archived enterprise proof refresh*') 'PowerShell lab verification guide should explain archived enterprise proof refreshes.'
            Assert-True ($powershellLabVerificationText -like '*Fresh live enterprise validation*') 'PowerShell lab verification guide should explain fresh live enterprise validation.'
            Assert-True ($powershellLabVerificationText -like '*Test-ShareSurferArchivedEnterpriseProof.ps1*') 'PowerShell lab verification guide should include the archived proof verifier command.'
            Assert-True ($powershellLabVerificationText -like '*Test-ShareSurferWindowsPowerShell51.ps1*') 'PowerShell lab verification guide should include the Windows PowerShell 5.1 smoke command.'
            Assert-True ($powershellLabVerificationText -like '*Invoke-ShareSurferLabValidation.ps1*') 'PowerShell lab verification guide should include lab validation commands.'
            Assert-True ($powershellLabVerificationText.Contains('Do not describe it as Windows PowerShell 5.1 proof unless it ran under')) 'PowerShell lab verification guide should prevent overclaiming local pwsh evidence.'
            Assert-True ($powershellLabVerificationText.Contains('`powershell.exe` on Windows')) 'PowerShell lab verification guide should name the Windows PowerShell host requirement.'
            Assert-True ($labReadinessText -like '*powershell-testing-lab-verification.md*') 'Lab readiness checklist should link PowerShell testing and lab verification guidance.'
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
            Assert-True ($operatorWorkflowText -like '*Choose Your Operator Path*') 'Operator workflow should include a path selector for production, nonpermissive, business review, lab proof, and support use.'
            Assert-True ($operatorWorkflowText -like '*first-run-troubleshooting.md*') 'Operator workflow should link first-run troubleshooting.'
            Assert-True ($operatorWorkflowText -like '*powershell-testing-lab-verification.md*') 'Operator workflow should link PowerShell testing and lab verification guidance.'
            Assert-True (Test-Path -LiteralPath $labEvidenceOverview) 'Documentation should include a shared lab-evidence overview.'
            $labEvidenceText = Get-Content -LiteralPath $labEvidenceOverview -Raw
            Assert-True ($labEvidenceText -like '*synthetic/project-lab evidence*') 'Lab evidence overview should explain the snapshot provenance.'
            Assert-True ($labEvidenceText -like '*purpose-built*') 'Lab evidence overview should explain why the evidence is tracked.'
            Assert-True ($labEvidenceText -like '*not production*') 'Lab evidence overview should distinguish lab evidence from production evidence.'
            Assert-True ($labEvidenceText -like '*host, domain, and path-looking values*') 'Lab evidence overview should explain host/domain/path-looking values.'
            Assert-True ($labEvidenceText -like '*What it proves*') 'Lab evidence overview should say what the evidence proves.'
            Assert-True ($labEvidenceText -like '*What it does not prove*') 'Lab evidence overview should say what the evidence does not prove.'
            $enterpriseEvidenceText = Get-Content -LiteralPath $enterpriseEvidenceReadme -Raw
            Assert-True ($enterpriseEvidenceText -like '*../README.md*') 'Enterprise lab evidence README should link to the shared lab-evidence overview.'
            Assert-True ($enterpriseEvidenceText -like '*historical run evidence*') 'Enterprise lab evidence README should identify the original historical run evidence.'
            Assert-True ($enterpriseEvidenceText -like '*current-schema refresh output*') 'Enterprise lab evidence README should identify generated current-schema refresh output.'
            Assert-True ($enterpriseEvidenceText -like '*Test-ShareSurferArchivedEnterpriseProof.ps1*') 'Enterprise lab evidence README should document the one-command archived enterprise proof verifier.'
            Assert-True ($enterpriseEvidenceText -like '*temporary output folder*') 'Enterprise lab evidence README should explain the verifier default output location.'
            Assert-True ($enterpriseEvidenceText.Contains('`refreshed-evidence/export` is not tracked')) 'Enterprise lab evidence README should warn readers not to validate an untracked refreshed export folder.'
            Assert-True ($enterpriseEvidenceText -like '*fresh live lab rerun*new host-side AD, filesystem, or collector evidence*') 'Enterprise lab evidence README should say when a fresh live rerun is needed.'
            Assert-True ((Get-Content -LiteralPath (Join-Path $repoRoot 'docs/lab-evidence/issue184-native-smb-rpc-20260610-183619/README.md') -Raw) -like '*../README.md*') 'Native SMB/RPC evidence README should link to the shared lab-evidence overview.'

            $publicText = @(
                Get-Content -LiteralPath (Join-Path $repoRoot 'README.md') -Raw
                Get-Content -LiteralPath (Join-Path $repoRoot 'docs/export-schema.md') -Raw
                Get-Content -LiteralPath $glossary -Raw
                Get-Content -LiteralPath $visualFieldGuide -Raw
                Get-Content -LiteralPath $visualDoc -Raw
                Get-Content -LiteralPath $visualReadme -Raw
                Get-Content -LiteralPath $firstRunGuide -Raw
                Get-Content -LiteralPath $firstRunTroubleshooting -Raw
                Get-Content -LiteralPath $businessReviewHandoff -Raw
                Get-Content -LiteralPath $workflowGuide -Raw
                Get-Content -LiteralPath $commandRecipes -Raw
                Get-Content -LiteralPath $adminOwnershipImport -Raw
                Get-Content -LiteralPath $ownershipCsvIngestQuickReference -Raw
                Get-Content -LiteralPath $managementOverview -Raw
                Get-Content -LiteralPath $managementSlide -Raw
                Get-Content -LiteralPath $labReadinessChecklist -Raw
                Get-Content -LiteralPath $powershellLabVerification -Raw
                Get-Content -LiteralPath $labEvidenceOverview -Raw
                Get-Content -LiteralPath $nonpermissiveWorkflow -Raw
                Get-Content -LiteralPath (Join-Path $repoRoot 'docs/operator-workflow.md') -Raw
                Get-Content -LiteralPath (Join-Path $visualRoot 'enterprise-lab-validation.svg') -Raw
            ) -join "`n"
            Assert-True ($publicText -like '*Test-ShareSurferV1Acceptance.ps1*') 'Operator documentation should include the final V1 acceptance checker.'
            Assert-True ($publicText -like '*ScanExport:owner_review_packets.csv*') 'Operator documentation should call out owner review packet live evidence.'
            Assert-True ($publicText -like '*What Needs Review First*') 'Operator documentation should tell users to start with the owner review queue.'
            Assert-True ($publicText -like '*OwnerMetadataUnavailable*') 'Operator documentation should document owner metadata unavailable findings.'
            Assert-True ($publicText -like '*share gate*') 'Operator documentation should explain the share gate access model.'
            Assert-True ($publicText -like '*Raw Evidence Tables*') 'Operator documentation should mention the report raw evidence view.'
            Assert-True ($publicText -like '*-NoCreateMissingFolders*') 'Operator documentation should explain the missing local output folder opt-out.'
            Assert-True ($publicText -like '*Creating missing local handoff folder*') 'Operator documentation should show explicit handoff folder creation before native zip commands.'
            Assert-True ($publicText -like ('*{0}*' -f $currentReleaseRoot)) 'Operator documentation should include the simplified version-root release path.'
            Assert-True ($publicText -notlike ('*{0}*' -f $oldNestedReleaseRoot)) 'Operator documentation should not include the older nested release root path.'
            $oldLabToolPattern = 'pr' + 'lctl'
            $internalVisualPattern = '(?i)' + 'image' + '-gen2'
            Assert-True ($publicText -notmatch $oldLabToolPattern) 'Public docs should not mention old internal test-environment tooling.'
            Assert-True ($publicText -notmatch $internalVisualPattern) 'Public docs should not expose internal visual provenance labels.'
        }
    }
)

$selectedTests = @(if ([string]::IsNullOrWhiteSpace($Name)) {
    $tests
}
else {
    $tests | Where-Object { [string]$_.Name -like ('*{0}*' -f $Name) }
})
if ($selectedTests.Count -eq 0) {
    throw "No tests matched -Name '$Name'."
}

$passed = 0
foreach ($test in $selectedTests) {
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

Write-Host ("{0}/{1} tests passed" -f $passed, $selectedTests.Count)
