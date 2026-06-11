export const datasetKeys = [
  "shares",
  "items",
  "share_permissions",
  "acl_entries",
  "identities",
  "group_edges",
  "discounted_principals",
  "permissioned_groups",
  "org_chains",
  "owner_mappings",
  "owner_risk_pivots",
  "related_data_areas",
  "owner_review_packets",
  "conflicts",
  "findings",
  "collection_errors",
  "scan_events",
  "scan_manifest",
  "open_file_manifest",
  "open_file_samples",
  "open_file_summary",
  "open_file_errors",
  "port_protocol_manifest",
  "port_protocol_targets",
  "port_protocol_checks"
] as const;

export const optionalDatasetKeys = [
  "open_file_manifest",
  "open_file_samples",
  "open_file_summary",
  "open_file_errors",
  "port_protocol_manifest",
  "port_protocol_targets",
  "port_protocol_checks"
] as const satisfies readonly DatasetKey[];

export type DatasetKey = (typeof datasetKeys)[number];
export type DataRow = Record<string, string>;
export type DatasetMap = Record<DatasetKey, DataRow[]>;

export const datasetLabels: Record<DatasetKey, string> = {
  shares: "Shares",
  items: "Folders and files",
  share_permissions: "Share-level access",
  acl_entries: "Folder/file permissions",
  identities: "Identities",
  group_edges: "Group expansion",
  discounted_principals: "Discounted access principals",
  permissioned_groups: "Permissioned groups",
  org_chains: "Org context",
  owner_mappings: "Owner mappings",
  owner_risk_pivots: "Owner pivots",
  related_data_areas: "Migration clusters",
  owner_review_packets: "Review packets",
  conflicts: "Access conflicts",
  findings: "Findings",
  collection_errors: "Collection errors",
  scan_events: "Scan events",
  scan_manifest: "Scan manifest",
  open_file_manifest: "Open-file assessment manifest",
  open_file_samples: "Open-file samples",
  open_file_summary: "Open-file hot folders",
  open_file_errors: "Open-file collection errors",
  port_protocol_manifest: "Ports/protocols assessment manifest",
  port_protocol_targets: "Ports/protocols targets",
  port_protocol_checks: "Ports/protocols checks"
};

export const expectedColumns: Record<DatasetKey, string[]> = {
  shares: [
    "ShareId",
    "Source",
    "ComputerName",
    "ShareName",
    "UNCPath",
    "LocalPath",
    "Description",
    "PartialData",
    "PartialReason"
  ],
  items: [
    "ItemId",
    "ShareId",
    "ItemType",
    "FullPath",
    "RelativePath",
    "Depth",
    "Owner",
    "InheritanceEnabled",
    "InheritanceBrokenAt"
  ],
  share_permissions: ["ShareId", "Identity", "Rights", "AccessControlType", "Source"],
  acl_entries: [
    "ItemId",
    "ShareId",
    "FullPath",
    "Identity",
    "Rights",
    "AccessControlType",
    "IsInherited",
    "InheritanceFlags",
    "PropagationFlags",
    "Depth"
  ],
  identities: [
    "Identity",
    "SamAccountName",
    "DisplayName",
    "ObjectClass",
    "EmployeeId",
    "EmployeeNumber",
    "UserPrincipalName",
    "Mail",
    "Department",
    "Title",
    "Company",
    "Office",
    "AccountEnabled",
    "Manager",
    "ManagerLevel1",
    "ManagerLevel2",
    "ManagerLevel3",
    "ManagerLevel1Raw",
    "ManagerLevel2Raw",
    "ManagerLevel3Raw",
    "ObsPath",
    "ObsAttribute",
    "PotentialServiceAccount",
    "DistinguishedName"
  ],
  group_edges: ["ParentGroup", "ChildIdentity", "ChildObjectClass", "Depth", "IsCycle", "IsTruncated"],
  discounted_principals: ["Identity", "Reason", "Scope", "MatchType"],
  permissioned_groups: [
    "Group",
    "DisplayName",
    "ObjectClass",
    "ObsPath",
    "ManagerLevel1",
    "ShareAssignments",
    "NtfsAssignments",
    "ExpandedMembers",
    "MaxDepth",
    "HasCycle",
    "IsTruncated",
    "Rights",
    "ShareId",
    "ShareIds",
    "Sources",
    "FullPath",
    "ExamplePath",
    "DiscountedPrincipal",
    "DiscountReason",
    "DiscountScope"
  ],
  org_chains: [
    "Identity",
    "EmployeeId",
    "EmployeeNumber",
    "Department",
    "Title",
    "Company",
    "Office",
    "ManagerLevel1",
    "ManagerLevel2",
    "ManagerLevel3",
    "ManagerLevel1Raw",
    "ManagerLevel2Raw",
    "ManagerLevel3Raw",
    "ObsPath",
    "ObsAttribute",
    "PotentialServiceAccount"
  ],
  owner_mappings: ["Pattern", "Owner", "BusinessUnit", "Source"],
  owner_risk_pivots: [
    "BusinessUnit",
    "Owner",
    "Pattern",
    "Source",
    "MatchingItems",
    "Directories",
    "Files",
    "FindingCount",
    "ConflictCount",
    "PartialShareCount",
    "DirectIdentityCount",
    "DirectGroupCount",
    "ExpandedMemberCount",
    "RiskLevel",
    "ReadinessSignals",
    "DiscountedPrincipal",
    "DiscountedPrincipalCount",
    "DiscountedGroupCount",
    "DiscountedPrincipals",
    "DiscountReason"
  ],
  related_data_areas: [
    "RelatedAreaId",
    "RelatedDataArea",
    "BusinessUnit",
    "Owner",
    "Pattern",
    "Source",
    "RelatednessStrength",
    "RelationshipSignalCount",
    "SupportingSignalCount",
    "ReadinessSignalCount",
    "RelationshipSignals",
    "SupportingEvidence",
    "ReadinessSignals",
    "CoreFiveChips",
    "EvidenceCompleteness",
    "RiskLevel",
    "MigrationReadiness",
    "MatchingShares",
    "MatchingItems",
    "Directories",
    "Files",
    "FindingCount",
    "ConflictCount",
    "ReviewItemCount",
    "PartialShareCount",
    "DirectIdentityCount",
    "DirectGroupCount",
    "ExpandedMemberCount",
    "RelatedBecauseShort",
    "RelatedBecause",
    "SuggestedNextAction",
    "DiscountedPrincipal",
    "DiscountedPrincipalCount",
    "DiscountedGroupCount",
    "DiscountedPrincipals",
    "DiscountReason"
  ],
  owner_review_packets: [
    "ReviewPacketId",
    "BusinessUnit",
    "Owner",
    "Pattern",
    "Source",
    "RiskLevel",
    "ReviewStatus",
    "WhyReview",
    "WhatToReviewFirst",
    "SuggestedNextAction",
    "MatchingItems",
    "Directories",
    "Files",
    "FindingCount",
    "ConflictCount",
    "PartialShareCount",
    "DirectIdentityCount",
    "DirectGroupCount",
    "ExpandedMemberCount",
    "MigrationReadiness",
    "RelatedDataAreaCount",
    "RelatednessStrength",
    "RelationshipSignalCount",
    "ReadinessSignals",
    "DiscountedPrincipal",
    "DiscountedPrincipalCount",
    "DiscountedGroupCount",
    "DiscountedPrincipals",
    "DiscountReason"
  ],
  conflicts: [
    "ConflictId",
    "ConflictType",
    "ShareId",
    "ItemId",
    "Identity",
    "ShareRights",
    "NtfsRights",
    "Severity",
    "Message"
  ],
  findings: [
    "FindingId",
    "FindingType",
    "Severity",
    "ShareId",
    "ItemId",
    "FullPath",
    "Identity",
    "ObservedValue",
    "PolicyValue",
    "Message"
  ],
  collection_errors: ["ErrorId", "ShareId", "ItemId", "FullPath", "ErrorType", "Severity", "Source", "Message", "Detail"],
  scan_events: ["EventId", "Timestamp", "Level", "EventType", "Source", "ShareId", "ItemId", "Message", "Detail"],
  scan_manifest: [
    "ScanId",
    "GeneratedAt",
    "ExportVersion",
    "ObsAttribute",
    "SourceMode",
    "OperationalPathLengthThreshold",
    "AzurePathComponentLimit",
    "AzureFullPathLimit",
    "ExplicitAceDepthThreshold",
    "GroupExpansionMaxDepth",
    "AdLookupMode",
    "ManagerIdentityFormat",
    "IncludeFiles"
  ],
  open_file_manifest: [
    "AssessmentId",
    "GeneratedAt",
    "ExportVersion",
    "ComputerName",
    "ShareNames",
    "Provider",
    "IntervalSeconds",
    "SampleCount",
    "DurationMinutes",
    "StartedAt",
    "CompletedAt",
    "PackageKind"
  ],
  open_file_samples: [
    "AssessmentId",
    "SampleId",
    "SampleTimestamp",
    "ComputerName",
    "ShareName",
    "Provider",
    "FileId",
    "SessionId",
    "ClientComputerName",
    "ClientUserName",
    "Path",
    "FolderPath",
    "ShareRelativePath",
    "ShareRelativeFolder",
    "Permissions",
    "Locks",
    "Source",
    "CollectionStatus",
    "ErrorMessage"
  ],
  open_file_summary: [
    "AssessmentId",
    "ComputerName",
    "ShareName",
    "FolderPath",
    "ShareRelativeFolder",
    "ObservationCount",
    "SampleCount",
    "FirstSeen",
    "LastSeen",
    "UniqueUsers",
    "UniqueClients",
    "TopUsers",
    "TopClients",
    "TotalLocks",
    "MaxLocks",
    "HeatScore",
    "HotFolder",
    "PathProximityKey"
  ],
  open_file_errors: [
    "ErrorId",
    "AssessmentId",
    "SampleId",
    "Timestamp",
    "ComputerName",
    "ShareName",
    "Provider",
    "ErrorType",
    "Message",
    "Detail"
  ],
  port_protocol_manifest: [
    "AssessmentId",
    "GeneratedAt",
    "ExportVersion",
    "CollectorComputerName",
    "CollectorFqdn",
    "CollectorUser",
    "UserDomain",
    "IsWindows",
    "IsElevated",
    "OSDescription",
    "OSArchitecture",
    "PowerShellVersion",
    "PSEdition",
    "ActiveDirectoryModuleAvailable",
    "SmbShareModuleAvailable",
    "TargetCount",
    "CheckCount",
    "PassedCount",
    "WarningCount",
    "FailedCount",
    "SkippedCount",
    "PackageKind"
  ],
  port_protocol_targets: [
    "AssessmentId",
    "TargetId",
    "Target",
    "TargetType",
    "ComputerName",
    "ShareName",
    "UNCPath",
    "CheckCount",
    "PassedCount",
    "WarningCount",
    "FailedCount",
    "SkippedCount",
    "TargetStatus",
    "SuggestedNextAction"
  ],
  port_protocol_checks: [
    "AssessmentId",
    "CheckId",
    "TargetId",
    "Target",
    "TargetType",
    "ComputerName",
    "ShareName",
    "Protocol",
    "Transport",
    "Port",
    "Requirement",
    "Provider",
    "Purpose",
    "RequiredFor",
    "Status",
    "Severity",
    "LatencyMs",
    "RemoteAddress",
    "Message",
    "Detail"
  ]
};

export const tooltipRegistry = {
  shareGate:
    "The front door to the share. A user still needs folder or file permission after passing this gate.",
  fileFolderPermissions:
    "Permissions on folders or files inside the share. These can allow, limit, or deny access after the share gate.",
  partialData:
    "ShareSurfer found the target but could not prove all expected metadata. Open Diagnostics before using this area for approval.",
  reviewRisk:
    "A routing label based on high-severity findings, conflicts, or scan gaps. It is not final approval.",
  migrationReadiness:
    "A planning signal that shows whether scan gaps, conflicts, or findings should be reviewed before migration.",
  ownerMapping:
    "A rule that maps paths or shares to an owner and business unit. Owners should confirm it before cleanup.",
  relatedDataArea:
    "Shares, folders, or files that appear related by owner, business unit, path pattern, group overlap, or shared risk.",
  permissionedGroup:
    "A security group observed directly on share-level or folder/file permissions.",
  expandedMembers:
    "Users or nested groups found by recursively expanding group membership. If a cycle is detected or the configured max depth is reached, ShareSurfer marks the result so reviewers know the proof is partial.",
  groupTruncation:
    "Group expansion stopped at the configured depth or size limit. Increase the limit or review directory access if needed.",
  obsPath:
    "A directory attribute used to connect identities and groups to business structure. The attribute name is scan-specific.",
  managerLevel3:
    "The next manager above a manager's manager when directory data is available. It helps route escalation, not approval.",
  potentialServiceAccount:
    "A user account with no OBS value and no employee identifier collected. It may be automation, or it may be incomplete directory data.",
  brokenSid:
    "A permission references a SID or account name ShareSurfer could not resolve. This can happen after account deletion, trust changes, or directory lookup gaps.",
  collectionError:
    "A recorded problem while resolving, enumerating, or reading share, folder, file, ACL, or directory metadata.",
  rawEvidence:
    "The original CSV-shaped evidence. Use it to prove or troubleshoot a dashboard summary.",
  scanConfidence:
    "A quick health signal that combines partial shares, collection errors, missing files, and group expansion gaps.",
  longPath:
    "The path exceeded ShareSurfer's operational migration threshold. This is separate from Azure Files hard limits.",
  deepExplicit:
    "A non-inherited permission was found below the configured depth threshold. It may need owner review.",
  brokenInheritance:
    "A folder or file stopped inheriting permissions from its parent. Review whether that was intentional.",
  portsProtocols:
    "Read-only reachability evidence for SMB, WinRM/CIM, native SMB/RPC, and optional directory protocols ShareSurfer may use during collection."
} as const;

export const glossaryTerms = [
  {
    term: "Owner",
    definition:
      "The mapped business reviewer or data owner for a path, share, or related data area. This is separate from the Windows or NTFS file owner field."
  },
  {
    term: "No owner",
    definition:
      "ShareSurfer could not collect or map a usable owner. That usually means the owner needs to be supplied by mapping, directory data, or manual business review."
  },
  {
    term: "Broken/Missing SID",
    definition:
      "A permission references a SID or account name that could not be resolved. Common causes include deleted accounts, trust changes, or directory lookup gaps."
  },
  {
    term: "Collection error",
    definition:
      "A recorded problem while resolving, enumerating, or reading share, folder, file, ACL, or directory metadata."
  },
  {
    term: "Partial data",
    definition:
      "ShareSurfer found the target but could not prove every expected detail. Treat that area as incomplete until the diagnostic evidence is reviewed."
  },
  {
    term: "Discounted access principal",
    definition:
      "An admin, helpdesk, or service principal that the operator told ShareSurfer to discount from ownership and migration signal calculations."
  },
  {
    term: "Critical scan information block",
    definition:
      "A severe collection gap that can hide permissions or paths. Fixing the block is not the same thing as approval; it only makes review evidence more trustworthy."
  }
] as const;
