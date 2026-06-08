import type { DataRow, DatasetKey } from "./schema";

export interface RawSnapshot {
  generatedAt?: string;
  datasets?: Partial<Record<DatasetKey | string, DataRow[]>>;
  schemaWarnings?: string[];
  rowCounts?: Partial<Record<DatasetKey, number>>;
}

export const demoSnapshot: RawSnapshot = {
  generatedAt: "2026-06-05T17:41:14Z",
  datasets: {
    shares: [
      {
        ShareId: "share-finance",
        Source: "Fixture",
        ComputerName: "files01",
        ShareName: "Finance",
        UNCPath: "\\\\files01\\Finance",
        LocalPath: "C:\\ShareSurferLab\\Finance",
        Description: "Finance review share",
        PartialData: "False",
        PartialReason: ""
      },
      {
        ShareId: "share-hr",
        Source: "Fixture",
        ComputerName: "files01",
        ShareName: "HR",
        UNCPath: "\\\\files01\\HR",
        LocalPath: "C:\\ShareSurferLab\\HR",
        Description: "HR employee records",
        PartialData: "True",
        PartialReason: "SharePermissionCollectionUnavailable"
      },
      {
        ShareId: "share-ops",
        Source: "Fixture",
        ComputerName: "files01",
        ShareName: "Operations",
        UNCPath: "\\\\files01\\Operations",
        LocalPath: "C:\\ShareSurferLab\\Operations",
        Description: "Operations share",
        PartialData: "False",
        PartialReason: ""
      }
    ],
    items: [
      {
        ItemId: "item-finance",
        ShareId: "share-finance",
        ItemType: "Directory",
        FullPath: "\\\\files01\\Finance",
        RelativePath: "",
        Depth: "0",
        Owner: "CONTOSO\\FinanceOwner",
        InheritanceEnabled: "True",
        InheritanceBrokenAt: ""
      },
      {
        ItemId: "item-payroll",
        ShareId: "share-finance",
        ItemType: "Directory",
        FullPath: "\\\\files01\\Finance\\Payroll",
        RelativePath: "Payroll",
        Depth: "1",
        Owner: "CONTOSO\\FinanceOwner",
        InheritanceEnabled: "False",
        InheritanceBrokenAt: "\\\\files01\\Finance\\Payroll"
      },
      {
        ItemId: "item-hr",
        ShareId: "share-hr",
        ItemType: "Directory",
        FullPath: "\\\\files01\\HR\\Employee Data",
        RelativePath: "Employee Data",
        Depth: "1",
        Owner: "CONTOSO\\HROwner",
        InheritanceEnabled: "True",
        InheritanceBrokenAt: ""
      }
    ],
    share_permissions: [
      {
        ShareId: "share-finance",
        Identity: "CONTOSO\\FinanceReaders",
        Rights: "Read",
        AccessControlType: "Allow",
        Source: "Get-SmbShareAccess"
      },
      {
        ShareId: "share-finance",
        Identity: "Everyone",
        Rights: "Change",
        AccessControlType: "Allow",
        Source: "Get-SmbShareAccess"
      }
    ],
    acl_entries: [
      {
        ItemId: "item-finance",
        ShareId: "share-finance",
        FullPath: "\\\\files01\\Finance",
        Identity: "CONTOSO\\FinanceReaders",
        Rights: "ReadAndExecute",
        AccessControlType: "Allow",
        IsInherited: "True",
        InheritanceFlags: "ContainerInherit,ObjectInherit",
        PropagationFlags: "None",
        Depth: "0"
      },
      {
        ItemId: "item-payroll",
        ShareId: "share-finance",
        FullPath: "\\\\files01\\Finance\\Payroll",
        Identity: "CONTOSO\\PayrollTeam",
        Rights: "Modify",
        AccessControlType: "Allow",
        IsInherited: "False",
        InheritanceFlags: "ContainerInherit,ObjectInherit",
        PropagationFlags: "None",
        Depth: "3"
      },
      {
        ItemId: "item-payroll",
        ShareId: "share-finance",
        FullPath: "\\\\files01\\Finance\\Payroll",
        Identity: "CONTOSO\\svc.ShareBot",
        Rights: "Read",
        AccessControlType: "Allow",
        IsInherited: "False",
        InheritanceFlags: "ContainerInherit",
        PropagationFlags: "None",
        Depth: "3"
      }
    ],
    identities: [
      {
        Identity: "CONTOSO\\Ava.Accounting",
        SamAccountName: "Ava.Accounting",
        DisplayName: "Ava Accounting",
        ObjectClass: "user",
        EmployeeId: "E1001",
        EmployeeNumber: "1001",
        UserPrincipalName: "ava.accounting@example.test",
        Mail: "ava.accounting@example.test",
        Department: "Accounts Payable",
        Title: "Accounting Analyst",
        Company: "Contoso Finance",
        Office: "HQ-4",
        AccountEnabled: "True",
        Manager: "CONTOSO\\Morgan.Manager",
        ManagerLevel1: "CONTOSO\\Morgan.Manager",
        ManagerLevel2: "CONTOSO\\Riley.Director",
        ManagerLevel3: "CONTOSO\\Jordan.VP",
        ObsPath: "CORP.FIN.AP",
        ObsAttribute: "extensionAttribute10",
        PotentialServiceAccount: "False",
        DistinguishedName: "CN=Ava Accounting,OU=Users,DC=example,DC=test"
      },
      {
        Identity: "CONTOSO\\svc.ShareBot",
        SamAccountName: "svc.ShareBot",
        DisplayName: "svc ShareBot",
        ObjectClass: "user",
        EmployeeId: "",
        EmployeeNumber: "",
        UserPrincipalName: "",
        Mail: "",
        Department: "",
        Title: "Automation Account",
        Company: "Contoso Finance",
        Office: "",
        AccountEnabled: "True",
        Manager: "",
        ManagerLevel1: "",
        ManagerLevel2: "",
        ManagerLevel3: "",
        ObsPath: "",
        ObsAttribute: "extensionAttribute10",
        PotentialServiceAccount: "True",
        DistinguishedName: "CN=svc ShareBot,OU=Service Accounts,DC=example,DC=test"
      },
      {
        Identity: "CONTOSO\\FinanceReaders",
        SamAccountName: "FinanceReaders",
        DisplayName: "Finance Readers",
        ObjectClass: "group",
        EmployeeId: "",
        EmployeeNumber: "",
        UserPrincipalName: "",
        Mail: "",
        Department: "Finance Shared Data",
        Title: "",
        Company: "Contoso Finance",
        Office: "HQ-4",
        AccountEnabled: "",
        Manager: "",
        ManagerLevel1: "",
        ManagerLevel2: "",
        ManagerLevel3: "",
        ObsPath: "CORP.FIN",
        ObsAttribute: "extensionAttribute10",
        PotentialServiceAccount: "False",
        DistinguishedName: "CN=Finance Readers,OU=Groups,DC=example,DC=test"
      }
    ],
    group_edges: [
      {
        ParentGroup: "CONTOSO\\FinanceReaders",
        ChildIdentity: "CONTOSO\\Ava.Accounting",
        ChildObjectClass: "user",
        Depth: "1",
        IsCycle: "False",
        IsTruncated: "False"
      },
      {
        ParentGroup: "CONTOSO\\FinanceReaders",
        ChildIdentity: "CONTOSO\\PayrollTeam",
        ChildObjectClass: "group",
        Depth: "1",
        IsCycle: "False",
        IsTruncated: "False"
      }
    ],
    permissioned_groups: [
      {
        Group: "CONTOSO\\FinanceReaders",
        DisplayName: "Finance Readers",
        ObjectClass: "group",
        ObsPath: "CORP.FIN",
        ManagerLevel1: "",
        ShareAssignments: "1",
        NtfsAssignments: "2",
        ExpandedMembers: "2",
        MaxDepth: "1",
        HasCycle: "False",
        IsTruncated: "False",
        Rights: "Read",
        ShareId: "share-finance",
        ShareIds: "share-finance",
        Sources: "Share; NTFS",
        FullPath: "\\\\files01\\Finance",
        ExamplePath: "\\\\files01\\Finance"
      }
    ],
    org_chains: [
      {
        Identity: "CONTOSO\\Ava.Accounting",
        EmployeeId: "E1001",
        EmployeeNumber: "1001",
        Department: "Accounts Payable",
        Title: "Accounting Analyst",
        Company: "Contoso Finance",
        Office: "HQ-4",
        ManagerLevel1: "CONTOSO\\Morgan.Manager",
        ManagerLevel2: "CONTOSO\\Riley.Director",
        ManagerLevel3: "CONTOSO\\Jordan.VP",
        ObsPath: "CORP.FIN.AP",
        ObsAttribute: "extensionAttribute10",
        PotentialServiceAccount: "False"
      }
    ],
    owner_mappings: [
      {
        Pattern: "\\\\files01\\Finance*",
        Owner: "Finance Operations",
        BusinessUnit: "Finance",
        Source: "demo"
      }
    ],
    owner_risk_pivots: [
      {
        BusinessUnit: "Finance",
        Owner: "Finance Operations",
        Pattern: "\\\\files01\\Finance*",
        Source: "demo",
        MatchingItems: "2",
        Directories: "2",
        Files: "0",
        FindingCount: "3",
        ConflictCount: "1",
        PartialShareCount: "0",
        DirectIdentityCount: "3",
        DirectGroupCount: "2",
        ExpandedMemberCount: "2",
        RiskLevel: "High"
      }
    ],
    related_data_areas: [
      {
        RelatedAreaId: "related-finance",
        RelatedDataArea: "Finance / Accounts Payable",
        BusinessUnit: "Finance",
        Owner: "Finance Operations",
        Pattern: "\\\\files01\\Finance*",
        Source: "demo",
        RiskLevel: "High",
        MigrationReadiness: "Review",
        MatchingShares: "1",
        MatchingItems: "2",
        Directories: "2",
        Files: "0",
        FindingCount: "3",
        ConflictCount: "1",
        ReviewItemCount: "4",
        PartialShareCount: "0",
        DirectIdentityCount: "3",
        DirectGroupCount: "2",
        ExpandedMemberCount: "2",
        RelatedBecause:
          "same owner mapping; same business unit; matching path pattern; shared permission group; shared review risk",
        SuggestedNextAction: "Confirm ownership, review access groups, and resolve findings before migration."
      }
    ],
    owner_review_packets: [
      {
        ReviewPacketId: "owner-review-finance",
        BusinessUnit: "Finance",
        Owner: "Finance Operations",
        Pattern: "\\\\files01\\Finance*",
        Source: "demo",
        RiskLevel: "High",
        ReviewStatus: "High priority review",
        WhyReview: "high-priority access or migration risk; permission-bearing security groups",
        WhatToReviewFirst: "access conflicts; findings; permissioned groups",
        SuggestedNextAction: "Confirm ownership, review assigned groups, and document the remediation decision.",
        MatchingItems: "2",
        Directories: "2",
        Files: "0",
        FindingCount: "3",
        ConflictCount: "1",
        PartialShareCount: "0",
        DirectIdentityCount: "3",
        DirectGroupCount: "2",
        ExpandedMemberCount: "2",
        MigrationReadiness: "Review",
        RelatedDataAreaCount: "1"
      }
    ],
    conflicts: [
      {
        ConflictId: "conflict-share-ntfs",
        ConflictType: "NtfsIdentityMissingShareGate",
        ShareId: "share-finance",
        ItemId: "item-payroll",
        Identity: "CONTOSO\\PayrollTeam",
        ShareRights: "",
        NtfsRights: "Modify",
        Severity: "High",
        Message: "NTFS identity is not present at the share gate."
      }
    ],
    findings: [
      {
        FindingId: "finding-broken",
        FindingType: "BrokenInheritance",
        Severity: "Warning",
        ShareId: "share-finance",
        ItemId: "item-payroll",
        FullPath: "\\\\files01\\Finance\\Payroll",
        Identity: "",
        ObservedValue: "\\\\files01\\Finance\\Payroll",
        PolicyValue: "Inheritance enabled",
        Message: "Inheritance is disabled or was recorded as broken for this item."
      },
      {
        FindingId: "finding-deep",
        FindingType: "DeepExplicitAce",
        Severity: "High",
        ShareId: "share-finance",
        ItemId: "item-payroll",
        FullPath: "\\\\files01\\Finance\\Payroll",
        Identity: "CONTOSO\\PayrollTeam",
        ObservedValue: "3",
        PolicyValue: "2",
        Message: "Explicit permissions were introduced deeper than the configured review threshold."
      },
      {
        FindingId: "finding-service",
        FindingType: "PotentialServiceAccount",
        Severity: "Warning",
        ShareId: "",
        ItemId: "",
        FullPath: "",
        Identity: "CONTOSO\\svc.ShareBot",
        ObservedValue: "Missing OBS path and employee identifiers",
        PolicyValue: "User account should have OBS, employeeID, or employeeNumber unless it is a service account",
        Message:
          "User account has no OBS value and no employee identifier. Review whether this is a service account or incomplete directory data."
      }
    ],
    collection_errors: [
      {
        ErrorId: "error-hr",
        ShareId: "share-hr",
        ItemId: "",
        FullPath: "\\\\files01\\HR",
        ErrorType: "SharePermissionCollectionUnavailable",
        Message: "Share-level permissions could not be collected.",
        Detail: "Demo collection gap"
      }
    ],
    scan_events: [
      {
        Timestamp: "2026-06-05T17:41:14Z",
        Level: "Info",
        EventType: "Export",
        Message: "Demo export loaded",
        Detail: ""
      }
    ],
    scan_manifest: [
      {
        ScanId: "demo-scan",
        GeneratedAt: "2026-06-05T17:41:14Z",
        ExportVersion: "1",
        ObsAttribute: "extensionAttribute10",
        SourceMode: "Fixture",
        OperationalPathLengthThreshold: "256",
        AzurePathComponentLimit: "255",
        AzureFullPathLimit: "2048",
        ExplicitAceDepthThreshold: "2",
        GroupExpansionMaxDepth: "20",
        AdLookupMode: "DirectoryOnly",
        IncludeFiles: "True"
      }
    ]
  }
};
