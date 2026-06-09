import {
  datasetKeys,
  datasetLabels,
  expectedColumns,
  type DataRow,
  type DatasetKey,
  type DatasetMap
} from "./schema";
import type { RawSnapshot } from "./fixtures";

export interface NormalizedSnapshot {
  generatedAt: string;
  datasets: DatasetMap;
  manifest: DataRow;
  rowCounts: Record<DatasetKey, number>;
  schemaWarnings: string[];
}

export interface ScanSummary {
  generatedAt: string;
  sourceMode: string;
  obsAttribute: string;
  totalShares: number;
  totalItems: number;
  totalFindings: number;
  highPriorityItems: number;
  conflicts: number;
  partialShares: number;
  longPathRisks: number;
  permissionedGroups: number;
  expandedMembers: number;
  potentialServiceAccounts: number;
  brokenSidFindings: number;
  scanConfidence: number;
  confidenceLabel: "Good" | "Review" | "Partial";
}

export interface ReviewQueueRow {
  id: string;
  businessUnit: string;
  owner: string;
  source: string;
  riskLevel: string;
  whyReview: string;
  firstAction: string;
  matchingItems: number;
  findingCount: number;
  conflictCount: number;
  partialShareCount: number;
  permissionedGroups: number;
  expandedMembers: number;
  migrationReadiness: string;
}

export interface IssueSummary {
  id: string;
  source: "finding" | "conflict";
  category: string;
  severity: string;
  title: string;
  owner: string;
  businessUnit: string;
  path: string;
  identity: string;
  whatHappened: string;
  whyItMatters: string;
  nextAction: string;
  raw: DataRow;
}

export interface MigrationCluster {
  id: string;
  name: string;
  businessUnit: string;
  owner: string;
  riskLevel: string;
  readiness: string;
  shares: number;
  folders: number;
  files: number;
  reviewItems: number;
  permissionedGroups: number;
  relatedSignals: string[];
  nextAction: string;
  raw: DataRow;
}

export interface GroupTreeRow {
  group: string;
  displayName: string;
  riskLevel: string;
  expandedMembers: number;
  shareAssignments: number;
  ntfsAssignments: number;
  maxDepth: number;
  hasCycle: boolean;
  isTruncated: boolean;
  obsPath: string;
  rights: string;
  shareIds: string;
  sources: string;
  fullPath: string;
  examplePath: string;
  children: DataRow[];
  raw: DataRow;
}

export interface IdentityReviewSignals {
  serviceAccounts: Array<DataRow & { reviewLabel: string }>;
  managerChains: DataRow[];
}

export interface DiagnosticSummary {
  collectionErrors: DataRow[];
  partialShares: DataRow[];
  schemaWarnings: string[];
  scanEvents: DataRow[];
}

export interface CriticalScanBlock extends DataRow {
  ErrorId: string;
  ErrorType: string;
  Severity: string;
  Source: string;
  FullPath: string;
  Message: string;
  Detail: string;
}

export interface RawEvidenceDataset {
  key: DatasetKey;
  label: string;
  columns: string[];
  rows: DataRow[];
  totalRows: number;
}

export interface DashboardModel {
  scanSummary: ScanSummary;
  reviewQueue: ReviewQueueRow[];
  issueSummaries: IssueSummary[];
  criticalScanBlocks: CriticalScanBlock[];
  migrationClusters: MigrationCluster[];
  permissionedGroupTree: GroupTreeRow[];
  identityReviewSignals: IdentityReviewSignals;
  diagnosticSummary: DiagnosticSummary;
  rawEvidenceCatalog: RawEvidenceDataset[];
  filters: {
    businessUnits: string[];
    owners: string[];
    riskLevels: string[];
    sources: string[];
  };
}

const riskRank: Record<string, number> = {
  Critical: 5,
  High: 4,
  Warning: 3,
  Review: 3,
  Medium: 2,
  Low: 1,
  Info: 0,
  Good: 0
};

const readinessRank: Record<string, number> = {
  "Blocked by scan gaps": 5,
  Blocked: 5,
  High: 4,
  Review: 3,
  Warning: 3,
  Partial: 3,
  Ready: 1,
  Complete: 0
};

export function isTruthy(value: unknown): boolean {
  return ["true", "1", "yes"].includes(String(value ?? "").trim().toLowerCase());
}

export function toNumber(value: unknown): number {
  const parsed = Number(String(value ?? "").replace(/,/g, ""));
  return Number.isFinite(parsed) ? parsed : 0;
}

function normalizeText(value: unknown): string {
  if (value === null || value === undefined) {
    return "";
  }
  return String(value);
}

function unique(values: string[]): string[] {
  return Array.from(new Set(values.filter((value) => value.trim() !== ""))).sort((a, b) => a.localeCompare(b));
}

function splitReasonList(value: string): string[] {
  return value
    .split(";")
    .map((item) => item.trim())
    .filter(Boolean);
}

function addUnique(target: string[], values: string[]): void {
  for (const value of values) {
    if (value && !target.some((current) => current.toLowerCase() === value.toLowerCase())) {
      target.push(value);
    }
  }
}

function worseLabel(current: string, next: string, ranks: Record<string, number>): string {
  return (ranks[next] ?? 0) > (ranks[current] ?? 0) ? next : current;
}

function inferPotentialServiceAccount(row: DataRow): string {
  const isUser = row.ObjectClass.trim().toLowerCase() === "user";
  const lacksOwnerSignals = !row.ObsPath.trim() && !row.EmployeeId.trim() && !row.EmployeeNumber.trim();
  return isUser && lacksOwnerSignals ? "True" : "False";
}

function normalizeRows(datasetKey: DatasetKey, rows: DataRow[] | undefined, warnings: Set<string>): DataRow[] {
  const sourceRows = Array.isArray(rows) ? rows : [];
  if (!Array.isArray(rows)) {
    warnings.add(`${datasetKey}.csv was not present in the snapshot. The view will show empty evidence for that dataset.`);
  }

  return sourceRows.map((row, rowIndex) => {
    const record: DataRow = {};
    for (const [key, value] of Object.entries(row ?? {})) {
      record[key.replace(/^\uFEFF/, "")] = normalizeText(value);
    }

    for (const column of expectedColumns[datasetKey]) {
      if (!(column in record)) {
        if (datasetKey === "identities" && column === "PotentialServiceAccount") {
          record[column] = inferPotentialServiceAccount(record);
        } else if (datasetKey === "org_chains" && column === "PotentialServiceAccount") {
          record[column] = "False";
        } else {
          record[column] = "";
        }
        warnings.add(`${datasetKey}.csv is missing column ${column}; defaulted row ${rowIndex + 1}.`);
      }
    }

    if (datasetKey === "identities") {
      record.PotentialServiceAccount = record.PotentialServiceAccount || inferPotentialServiceAccount(record);
    }

    return record;
  });
}

export function normalizeSnapshot(rawSnapshot: RawSnapshot | undefined): NormalizedSnapshot {
  const warnings = new Set(rawSnapshot?.schemaWarnings ?? []);
  const datasets = {} as DatasetMap;
  const sourceDatasets = rawSnapshot?.datasets ?? {};

  for (const key of datasetKeys) {
    datasets[key] = normalizeRows(key, sourceDatasets[key], warnings);
  }

  const rowCounts = {} as Record<DatasetKey, number>;
  for (const key of datasetKeys) {
    rowCounts[key] = datasets[key].length;
  }

  return {
    generatedAt: rawSnapshot?.generatedAt ?? datasets.scan_manifest[0]?.GeneratedAt ?? "",
    datasets,
    manifest: datasets.scan_manifest[0] ?? {},
    rowCounts,
    schemaWarnings: Array.from(warnings)
  };
}

function categoryForFinding(type: string): string {
  switch (type) {
    case "BrokenInheritance":
      return "Inheritance Stopped";
    case "DeepExplicitAce":
      return "Deep Custom Permission";
    case "LongPathOperationalPolicy":
    case "AzureFullPathLimit":
    case "AzurePathComponentLimit":
      return "Long Path Warning";
    case "PartialSharePermissionData":
    case "CollectionError":
      return "Incomplete Collection";
    case "PotentialServiceAccount":
      return "Service Account Review";
    case "BrokenOrMissingSid":
      return "Broken/Missing SID";
    default:
      return type || "Finding";
  }
}

function categoryForConflict(type: string): string {
  if (type.includes("Share") || type.includes("Ntfs")) {
    return "Access Mismatch";
  }
  return type || "Conflict";
}

function issueTitle(row: DataRow, source: "finding" | "conflict"): string {
  const type = source === "finding" ? row.FindingType : row.ConflictType;
  const category = source === "finding" ? categoryForFinding(type) : categoryForConflict(type);
  if (category === "Access Mismatch") {
    return "Share gate and folder permissions differ";
  }
  if (category === "Service Account Review") {
    return "Account purpose needs review";
  }
  if (category === "Broken/Missing SID") {
    return "Permission references an unresolved SID";
  }
  return category;
}

function issueNextAction(category: string): string {
  switch (category) {
    case "Access Mismatch":
      return "Confirm whether share-level and folder/file permissions should be aligned.";
    case "Inheritance Stopped":
      return "Ask the data owner whether inheritance was intentionally stopped here.";
    case "Deep Custom Permission":
      return "Review the custom permission with the owner before cleanup or migration.";
    case "Long Path Warning":
      return "Plan path cleanup or migration exception handling before moving this data.";
    case "Incomplete Collection":
      return "Open Diagnostics and rerun or supplement the scan before approval.";
    case "Service Account Review":
      return "Ask the owner or directory team to confirm whether this account is automation or incomplete directory data.";
    case "Broken/Missing SID":
      return "Ask the directory or file-share team to confirm whether the SID is a deleted account, broken trust reference, or lookup gap.";
    default:
      return "Review the raw evidence and decide whether owner follow-up is needed.";
  }
}

function issueWhyItMatters(category: string): string {
  switch (category) {
    case "Access Mismatch":
      return "Users may be blocked or allowed differently than the share owner expects.";
    case "Service Account Review":
      return "Accounts without owner signals can be hard to route during access review.";
    case "Incomplete Collection":
      return "Approvals based on incomplete evidence can miss access or migration blockers.";
    case "Broken/Missing SID":
      return "Unresolved SIDs make access hard to explain and can block clean owner review or migration planning.";
    default:
      return "This signal may affect ownership, access review, or migration readiness.";
  }
}

function isCriticalCollectionBlock(row: DataRow): boolean {
  const text = `${row.ErrorType} ${row.Message} ${row.Detail}`.toLowerCase();
  return (
    text.includes("access denied") ||
    text.includes("unauthorized") ||
    text.includes("aclreaderror") ||
    text.includes("enumerationerror") ||
    text.includes("sharepermissioncollectionunavailable") ||
    text.includes("targetpathresolveerror") ||
    text.includes("remotecimsessionerror") ||
    text.includes("cannot connect")
  );
}

function buildCriticalScanBlocks(rows: DataRow[]): CriticalScanBlock[] {
  return rows
    .filter(isCriticalCollectionBlock)
    .map((row, index) => ({
      ...row,
      ErrorId: row.ErrorId || `critical-block-${index}`,
      ErrorType: row.ErrorType || "CollectionError",
      Severity: row.Severity || "High",
      Source: row.Source || "",
      FullPath: row.FullPath || "",
      Message: row.Message || "Collection was blocked for this area.",
      Detail: row.Detail || ""
    }))
    .sort((a, b) => (riskRank[b.Severity] ?? 0) - (riskRank[a.Severity] ?? 0) || a.ErrorType.localeCompare(b.ErrorType));
}

function buildOwnerLookup(reviewPackets: ReviewQueueRow[]): Map<string, ReviewQueueRow> {
  const lookup = new Map<string, ReviewQueueRow>();
  for (const packet of reviewPackets) {
    lookup.set(packet.businessUnit.toLowerCase(), packet);
    lookup.set(packet.owner.toLowerCase(), packet);
  }
  return lookup;
}

function buildReviewQueue(rows: DataRow[]): ReviewQueueRow[] {
  const aggregates = new Map<
    string,
    ReviewQueueRow & {
      whyReasons: string[];
      firstActions: string[];
      packetIds: string[];
      patterns: string[];
    }
  >();

  rows.forEach((row, index) => {
    const businessUnit = row.BusinessUnit || "Unmapped";
    const owner = row.Owner || "Unassigned";
    const key = `${businessUnit.toLowerCase()}|${owner.toLowerCase()}`;
    const riskLevel = row.RiskLevel || row.ReviewStatus || "Review";
    const migrationReadiness = row.MigrationReadiness || "Review";
    const existing =
      aggregates.get(key) ??
      {
        id: row.ReviewPacketId || `review-${index}`,
        businessUnit,
        owner,
        source: row.Source || "",
        riskLevel,
        whyReview: "",
        firstAction: "",
        matchingItems: 0,
        findingCount: 0,
        conflictCount: 0,
        partialShareCount: 0,
        permissionedGroups: 0,
        expandedMembers: 0,
        migrationReadiness,
        whyReasons: [],
        firstActions: [],
        packetIds: [],
        patterns: []
      };

    existing.source = unique([existing.source, row.Source]).join("; ");
    existing.riskLevel = worseLabel(existing.riskLevel, riskLevel, riskRank);
    existing.migrationReadiness = worseLabel(existing.migrationReadiness, migrationReadiness, readinessRank);
    existing.matchingItems += toNumber(row.MatchingItems);
    existing.findingCount += toNumber(row.FindingCount);
    existing.conflictCount += toNumber(row.ConflictCount);
    existing.partialShareCount += toNumber(row.PartialShareCount);
    existing.permissionedGroups += toNumber(row.DirectGroupCount);
    existing.expandedMembers += toNumber(row.ExpandedMemberCount);
    addUnique(existing.whyReasons, splitReasonList(row.WhyReview || "Review evidence before approval."));
    addUnique(existing.firstActions, [row.SuggestedNextAction || row.WhatToReviewFirst || "Confirm ownership and access intent."]);
    addUnique(existing.packetIds, [row.ReviewPacketId]);
    addUnique(existing.patterns, [row.Pattern]);
    aggregates.set(key, existing);
  });

  return Array.from(aggregates.values())
    .map(({ whyReasons, firstActions, packetIds, patterns, ...row }) => ({
      ...row,
      id: packetIds[0] || row.id,
      whyReview: whyReasons.join("; ") || "Review evidence before approval.",
      firstAction: firstActions[0] || "Confirm ownership and access intent."
    }))
    .sort(
      (a, b) =>
        (riskRank[b.riskLevel] ?? 0) - (riskRank[a.riskLevel] ?? 0) ||
        b.findingCount + b.conflictCount - (a.findingCount + a.conflictCount)
    );
}

function buildIssues(snapshot: NormalizedSnapshot, ownerLookup: Map<string, ReviewQueueRow>): IssueSummary[] {
  const issues: IssueSummary[] = [];

  for (const row of snapshot.datasets.findings) {
    const category = categoryForFinding(row.FindingType);
    const owner = ownerLookup.get((row.Owner || "").toLowerCase());
    issues.push({
      id: row.FindingId || `finding-${issues.length}`,
      source: "finding",
      category,
      severity: row.Severity || "Warning",
      title: issueTitle(row, "finding"),
      owner: owner?.owner ?? row.Owner ?? "",
      businessUnit: owner?.businessUnit ?? row.BusinessUnit ?? "",
      path: row.FullPath || row.ObservedValue || "",
      identity: row.Identity || "",
      whatHappened: row.Message || `${category} was observed in the export.`,
      whyItMatters: issueWhyItMatters(category),
      nextAction: issueNextAction(category),
      raw: row
    });
  }

  for (const row of snapshot.datasets.conflicts) {
    const category = categoryForConflict(row.ConflictType);
    issues.push({
      id: row.ConflictId || `conflict-${issues.length}`,
      source: "conflict",
      category,
      severity: row.Severity || "High",
      title: issueTitle(row, "conflict"),
      owner: "",
      businessUnit: "",
      path: row.FullPath || row.ItemId || row.ShareId || "",
      identity: row.Identity || "",
      whatHappened: row.Message || "Share-level and folder/file permissions do not line up.",
      whyItMatters: issueWhyItMatters(category),
      nextAction: issueNextAction(category),
      raw: row
    });
  }

  return issues.sort((a, b) => (riskRank[b.severity] ?? 0) - (riskRank[a.severity] ?? 0));
}

function buildMigrationClusters(rows: DataRow[]): MigrationCluster[] {
  const aggregates = new Map<
    string,
    MigrationCluster & {
      rowIds: string[];
      patterns: string[];
      sources: string[];
    }
  >();

  rows.forEach((row, index) => {
    const name = row.RelatedDataArea || `${row.BusinessUnit || "Unmapped"} / ${row.Owner || "Unassigned"}`;
    const businessUnit = row.BusinessUnit || "Unmapped";
    const owner = row.Owner || "Unassigned";
    const key = `${name.toLowerCase()}|${businessUnit.toLowerCase()}|${owner.toLowerCase()}`;
    const existing =
      aggregates.get(key) ??
      {
        id: row.RelatedAreaId || `cluster-${index}`,
        name,
        businessUnit,
        owner,
        riskLevel: row.RiskLevel || "Review",
        readiness: row.MigrationReadiness || "Review",
        shares: 0,
        folders: 0,
        files: 0,
        reviewItems: 0,
        permissionedGroups: 0,
        relatedSignals: [],
        nextAction: row.SuggestedNextAction || "Confirm ownership and access before migration planning.",
        raw: { ...row, ClusterRowCount: "0", PatternList: "", RelatedAreaIdList: "" },
        rowIds: [],
        patterns: [],
        sources: []
      };

    existing.riskLevel = worseLabel(existing.riskLevel, row.RiskLevel || "Review", riskRank);
    existing.readiness = worseLabel(existing.readiness, row.MigrationReadiness || "Review", readinessRank);
    existing.shares += toNumber(row.MatchingShares);
    existing.folders += toNumber(row.Directories);
    existing.files += toNumber(row.Files);
    existing.reviewItems += toNumber(row.ReviewItemCount) || toNumber(row.FindingCount) + toNumber(row.ConflictCount);
    existing.permissionedGroups += toNumber(row.DirectGroupCount);
    addUnique(existing.relatedSignals, splitReasonList(row.RelatedBecause));
    addUnique(existing.rowIds, [row.RelatedAreaId]);
    addUnique(existing.patterns, [row.Pattern]);
    addUnique(existing.sources, [row.Source]);
    existing.raw = {
      ...existing.raw,
      ...row,
      RelatedAreaId: existing.id,
      RelatedDataArea: existing.name,
      BusinessUnit: existing.businessUnit,
      Owner: existing.owner,
      RiskLevel: existing.riskLevel,
      MigrationReadiness: existing.readiness,
      MatchingShares: String(existing.shares),
      Directories: String(existing.folders),
      Files: String(existing.files),
      ReviewItemCount: String(existing.reviewItems),
      DirectGroupCount: String(existing.permissionedGroups),
      RelatedBecause: existing.relatedSignals.join("; "),
      ClusterRowCount: String(existing.rowIds.length),
      PatternList: existing.patterns.join("; "),
      RelatedAreaIdList: existing.rowIds.join("; "),
      Source: existing.sources.join("; ")
    };
    aggregates.set(key, existing);
  });

  return Array.from(aggregates.values())
    .map(({ rowIds, patterns, sources, ...cluster }) => cluster)
    .sort(
      (a, b) =>
        (readinessRank[b.readiness] ?? 0) - (readinessRank[a.readiness] ?? 0) ||
        b.reviewItems - a.reviewItems ||
        a.name.localeCompare(b.name)
    );
}

function buildGroups(snapshot: NormalizedSnapshot): GroupTreeRow[] {
  const edgesByParent = new Map<string, DataRow[]>();
  for (const edge of snapshot.datasets.group_edges) {
    const key = edge.ParentGroup.toLowerCase();
    if (!edgesByParent.has(key)) {
      edgesByParent.set(key, []);
    }
    edgesByParent.get(key)?.push(edge);
  }

  return snapshot.datasets.permissioned_groups.map((row) => ({
    group: row.Group,
    displayName: row.DisplayName || row.Group,
    riskLevel: isTruthy(row.HasCycle) || isTruthy(row.IsTruncated) ? "High" : "Review",
    expandedMembers: toNumber(row.ExpandedMembers),
    shareAssignments: toNumber(row.ShareAssignments),
    ntfsAssignments: toNumber(row.NtfsAssignments),
    maxDepth: toNumber(row.MaxDepth),
    hasCycle: isTruthy(row.HasCycle),
    isTruncated: isTruthy(row.IsTruncated),
    obsPath: row.ObsPath,
    rights: row.Rights,
    shareIds: row.ShareIds || row.ShareId,
    sources: row.Sources,
    fullPath: row.FullPath,
    examplePath: row.ExamplePath,
    children: edgesByParent.get(row.Group.toLowerCase()) ?? [],
    raw: row
  }));
}

function confidence(
  summary: Omit<ScanSummary, "scanConfidence" | "confidenceLabel"> & { collectionErrors: number }
): Pick<ScanSummary, "scanConfidence" | "confidenceLabel"> {
  const penalties =
    Math.min(35, summary.partialShares * 12) +
    Math.min(30, summary.collectionErrors * 8) +
    Math.min(15, summary.totalShares === 0 ? 15 : 0);
  const score = Math.max(20, 100 - penalties);
  return {
    scanConfidence: score,
    confidenceLabel: score >= 85 ? "Good" : score >= 65 ? "Review" : "Partial"
  };
}

export function deriveDashboard(snapshot: NormalizedSnapshot): DashboardModel {
  const serviceAccounts = snapshot.datasets.identities
    .filter((row) => isTruthy(row.PotentialServiceAccount))
    .map((row) => ({ ...row, reviewLabel: "Account purpose needs review" }));
  const managerChains = snapshot.datasets.org_chains.filter(
    (row) => row.ManagerLevel1 || row.ManagerLevel2 || row.ManagerLevel3 || row.ObsPath
  );
  const reviewQueue = buildReviewQueue(snapshot.datasets.owner_review_packets);
  const ownerLookup = buildOwnerLookup(reviewQueue);
  const permissionedGroups = buildGroups(snapshot);
  const criticalScanBlocks = buildCriticalScanBlocks(snapshot.datasets.collection_errors);
  const expandedMembers = permissionedGroups.reduce((sum, group) => sum + group.expandedMembers, 0);
  const brokenSidFindings = snapshot.datasets.findings.filter((row) => categoryForFinding(row.FindingType) === "Broken/Missing SID").length;
  const baseSummary = {
    generatedAt: snapshot.manifest.GeneratedAt || snapshot.generatedAt,
    sourceMode: snapshot.manifest.SourceMode || "Snapshot",
    obsAttribute: snapshot.manifest.ObsAttribute || "",
    totalShares: snapshot.datasets.shares.length,
    totalItems: snapshot.datasets.items.length,
    totalFindings: snapshot.datasets.findings.length,
    highPriorityItems: snapshot.datasets.findings.filter((row) => (riskRank[row.Severity] ?? 0) >= 4).length,
    conflicts: snapshot.datasets.conflicts.length,
    partialShares: snapshot.datasets.shares.filter((row) => isTruthy(row.PartialData)).length,
    longPathRisks: snapshot.datasets.findings.filter((row) => categoryForFinding(row.FindingType) === "Long Path Warning").length,
    permissionedGroups: snapshot.datasets.permissioned_groups.length,
    expandedMembers,
    potentialServiceAccounts: serviceAccounts.length,
    brokenSidFindings,
    collectionErrors: snapshot.datasets.collection_errors.length
  };
  const confidenceResult = confidence(baseSummary);
  const rawEvidenceCatalog = datasetKeys.map((key) => ({
    key,
    label: datasetLabels[key],
    columns: expectedColumns[key],
    rows: snapshot.datasets[key],
    totalRows: snapshot.datasets[key].length
  }));

  return {
    scanSummary: {
      ...baseSummary,
      scanConfidence: confidenceResult.scanConfidence,
      confidenceLabel: confidenceResult.confidenceLabel
    },
    reviewQueue,
    issueSummaries: buildIssues(snapshot, ownerLookup),
    criticalScanBlocks,
    migrationClusters: buildMigrationClusters(snapshot.datasets.related_data_areas),
    permissionedGroupTree: permissionedGroups,
    identityReviewSignals: {
      serviceAccounts,
      managerChains
    },
    diagnosticSummary: {
      collectionErrors: snapshot.datasets.collection_errors,
      partialShares: snapshot.datasets.shares.filter((row) => isTruthy(row.PartialData)),
      schemaWarnings: snapshot.schemaWarnings,
      scanEvents: snapshot.datasets.scan_events
    },
    rawEvidenceCatalog,
    filters: {
      businessUnits: unique([
        ...reviewQueue.map((row) => row.businessUnit),
        ...snapshot.datasets.related_data_areas.map((row) => row.BusinessUnit)
      ]),
      owners: unique([...reviewQueue.map((row) => row.owner), ...snapshot.datasets.related_data_areas.map((row) => row.Owner)]),
      riskLevels: unique([...reviewQueue.map((row) => row.riskLevel), ...snapshot.datasets.findings.map((row) => row.Severity)]),
      sources: unique([
        ...snapshot.datasets.shares.map((row) => row.Source),
        ...reviewQueue.flatMap((row) => row.source.split(";").map((source) => source.trim())),
        ...snapshot.datasets.related_data_areas.map((row) => row.Source),
        snapshot.manifest.SourceMode
      ])
    }
  };
}
