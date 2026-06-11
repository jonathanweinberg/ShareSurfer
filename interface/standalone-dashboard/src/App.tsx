import { startTransition, useDeferredValue, useEffect, useMemo, useState } from "react";
import {
  Activity,
  AlertTriangle,
  ArrowLeft,
  Building2,
  CalendarDays,
  ClipboardCheck,
  Database,
  FileWarning,
  FolderOpen,
  Gauge,
  Info,
  KeyRound,
  Layers3,
  Network,
  PanelLeftClose,
  PanelLeftOpen,
  Search,
  ServerCog,
  ShieldAlert,
  UserCheck,
  Users,
  Workflow
} from "lucide-react";
import { demoSnapshot } from "./data/fixtures";
import {
  deriveDashboard,
  isTruthy,
  normalizeSnapshot,
  type CriticalScanBlock,
  type DashboardModel,
  type GroupTreeRow,
  type IssueSummary,
  type MigrationCluster,
  type NormalizedSnapshot,
  type ReviewQueueRow,
  type ScanSummary
} from "./data/deriveDashboard";
import type { RawSnapshot } from "./data/fixtures";
import type { DataRow, DatasetKey } from "./data/schema";
import { datasetLabels, expectedColumns, glossaryTerms, tooltipRegistry } from "./data/schema";
import { KpiCard } from "./ui/KpiCard";
import { Tooltip } from "./ui/Tooltip";
import { VirtualTable } from "./ui/VirtualTable";

type ViewKey = "overview" | "findings" | "migration" | "groups" | "identity" | "diagnostics" | "raw";
type BrokenSidMode = "all" | "only" | "hide";

interface FilterState {
  query: string;
  businessUnit: string;
  owner: string;
  risk: string;
  source: string;
  brokenSidMode: BrokenSidMode;
}

interface RuntimeSnapshotState {
  status: "ready" | "missing";
  snapshot?: RawSnapshot;
  datasetLabel: string;
  message: string;
}

type SearchScope = "owner" | "share" | "identity" | "path" | "group";

interface ScopedSearchToken {
  scope: SearchScope;
  value: string;
  normalizedValue: string;
  rawTerm: string;
  excluded: boolean;
}

interface ParsedSearchQuery {
  scoped: ScopedSearchToken[];
  excludedScoped: ScopedSearchToken[];
  freeText: string[];
  excludedFreeText: string[];
}

interface PersistedDashboardState {
  activeView?: ViewKey;
  filters?: FilterState;
  selectedIssueId?: string;
  selectedClusterId?: string;
  selectedGroupName?: string;
  rawDatasetKey?: DatasetKey;
  returnTrail?: ReturnTrail | null;
}

interface ReturnTrail {
  from: ViewKey;
  label: string;
  backLabel: string;
}

interface EvidenceDrill {
  title: string;
  subtitle: string;
  rows: DataRow[];
  columns: string[];
  columnLabels?: Record<string, string>;
  enableExport?: boolean;
  exportFileName?: string;
  backLabel: string;
  emptyMessage: string;
}

type ReviewDecisionValue = "Expected" | "Needs Follow-up";

interface ReviewDecision {
  issueId: string;
  decision: ReviewDecisionValue;
  updatedAt: string;
  reviewer: string;
  note: string;
  title: string;
  category: string;
  severity: string;
  owner: string;
  businessUnit: string;
  path: string;
  identity: string;
  source: string;
}

type ReviewDecisionMap = Record<string, ReviewDecision>;

const views: Array<{ key: ViewKey; label: string; icon: JSX.Element; helper: string }> = [
  { key: "overview", label: "Overview", icon: <Gauge size={18} />, helper: "Start here" },
  { key: "findings", label: "Findings", icon: <ShieldAlert size={18} />, helper: "Issues & conflicts" },
  { key: "migration", label: "Migration", icon: <FolderOpen size={18} />, helper: "Related data" },
  { key: "groups", label: "Groups", icon: <Users size={18} />, helper: "Access expansion" },
  { key: "identity", label: "Identity", icon: <UserCheck size={18} />, helper: "Org context" },
  { key: "diagnostics", label: "Diagnostics", icon: <Activity size={18} />, helper: "Scan health" },
  { key: "raw", label: "Raw Evidence", icon: <Database size={18} />, helper: "All tables" }
];

const defaultFilters: FilterState = {
  query: "",
  businessUnit: "",
  owner: "",
  risk: "",
  source: "",
  brokenSidMode: "all"
};

const dashboardSessionKey = "sharesurfer.dashboard.state.v1";
const reviewDecisionsStorageKey = "sharesurfer.reviewDecisions.v1";

const searchScopeFields: Record<SearchScope, string[]> = {
  owner: ["Owner", "DataOwner", "BusinessUnit", "Department"],
  share: ["ShareName", "ShareId", "ShareIds", "UNCPath", "LocalPath", "Source"],
  identity: ["Identity", "DisplayName", "SamAccountName", "UserPrincipalName", "Mail"],
  path: ["FullPath", "ExamplePath", "RelativePath", "UNCPath", "LocalPath", "Pattern"],
  group: ["Group", "ParentGroup", "ChildIdentity", "DisplayName", "Rights"]
};

const curatedColumns: Partial<Record<DatasetKey, string[]>> = {
  shares: ["ShareId", "ShareName", "UNCPath", "PartialData", "PartialReason"],
  items: ["ItemId", "ShareId", "ItemType", "FullPath", "Depth", "InheritanceEnabled"],
  share_permissions: ["ShareId", "Identity", "Rights", "AccessControlType", "Source"],
  acl_entries: ["ShareId", "FullPath", "Identity", "Rights", "AccessControlType", "IsInherited", "Depth"],
  identities: ["Identity", "DisplayName", "ObjectClass", "Department", "Title", "ObsPath", "PotentialServiceAccount"],
  group_edges: ["ParentGroup", "ChildIdentity", "ChildObjectClass", "Depth", "IsCycle", "IsTruncated"],
  permissioned_groups: ["Group", "DisplayName", "ShareAssignments", "NtfsAssignments", "ExpandedMembers", "MaxDepth", "HasCycle", "IsTruncated"],
  owner_review_packets: ["Owner", "BusinessUnit", "RiskLevel", "ReviewStatus", "WhyReview", "WhatToReviewFirst", "SuggestedNextAction"],
  related_data_areas: ["RelatedDataArea", "Owner", "BusinessUnit", "RiskLevel", "MigrationReadiness", "RelatedBecause", "SuggestedNextAction"],
  conflicts: ["Severity", "ConflictType", "ShareId", "Identity", "Message"],
  findings: ["Severity", "FindingType", "ShareId", "Identity", "FullPath", "Message"],
  collection_errors: ["ErrorType", "ShareId", "FullPath", "Message"],
  scan_events: ["Timestamp", "Level", "EventType", "Message"],
  scan_manifest: ["GeneratedAt", "ExportVersion", "SourceMode", "GroupExpansionMaxDepth", "AdLookupMode", "IncludeFiles"],
  open_file_manifest: ["GeneratedAt", "ComputerName", "ShareNames", "Provider", "IntervalSeconds", "SampleCount"],
  open_file_samples: ["SampleTimestamp", "ShareName", "ClientUserName", "ClientComputerName", "Path", "Permissions", "Locks"],
  open_file_summary: ["ShareName", "FolderPath", "ObservationCount", "UniqueUsers", "UniqueClients", "HeatScore", "HotFolder"],
  open_file_errors: ["Timestamp", "ComputerName", "ShareName", "Provider", "Message"]
};

function columnsForDataset(datasetKey: DatasetKey, showAll = false): string[] {
  return showAll ? expectedColumns[datasetKey] : curatedColumns[datasetKey] ?? expectedColumns[datasetKey].slice(0, 8);
}

const numberFormatter = new Intl.NumberFormat();

function formatNumber(value: number): string {
  return numberFormatter.format(value);
}

function uniqueStrings(values: string[]): string[] {
  return Array.from(new Set(values.filter((value) => value.trim() !== ""))).sort((a, b) => a.localeCompare(b));
}

function trimMailtoPrefix(value: string): string {
  return value.replace(/^mailto:/i, "");
}

function trimManagerDisplayRow(row: DataRow): DataRow {
  return {
    ...row,
    ManagerLevel1: trimMailtoPrefix(row.ManagerLevel1 ?? ""),
    ManagerLevel2: trimMailtoPrefix(row.ManagerLevel2 ?? ""),
    ManagerLevel3: trimMailtoPrefix(row.ManagerLevel3 ?? "")
  };
}

function safeFileToken(value: string): string {
  return value
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "") || "selection";
}

function formatReportDate(value: string): string {
  if (!value) {
    return "Unknown";
  }

  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    return value;
  }

  return new Intl.DateTimeFormat(undefined, {
    dateStyle: "medium",
    timeStyle: "short"
  }).format(date);
}

function riskTone(value: string): "danger" | "warning" | "good" | "neutral" {
  const normalized = value.toLowerCase();
  if (normalized.includes("high") || normalized.includes("critical") || normalized.includes("blocked")) {
    return "danger";
  }
  if (normalized.includes("review") || normalized.includes("warning") || normalized.includes("partial") || normalized.includes("medium")) {
    return "warning";
  }
  if (normalized.includes("good") || normalized.includes("low") || normalized.includes("complete")) {
    return "good";
  }
  return "neutral";
}

function isViewKey(value: unknown): value is ViewKey {
  return typeof value === "string" && views.some((view) => view.key === value);
}

function isDatasetKey(value: unknown): value is DatasetKey {
  return typeof value === "string" && value in datasetLabels;
}

function isFilterState(value: unknown): value is FilterState {
  if (!value || typeof value !== "object") {
    return false;
  }
  const candidate = value as Partial<FilterState>;
  return (
    ["query", "businessUnit", "owner", "risk", "source"].every((key) => typeof candidate[key as keyof FilterState] === "string") &&
    (candidate.brokenSidMode === undefined || candidate.brokenSidMode === "all" || candidate.brokenSidMode === "only" || candidate.brokenSidMode === "hide") &&
    ((candidate as { brokenSidOnly?: unknown }).brokenSidOnly === undefined || typeof (candidate as { brokenSidOnly?: unknown }).brokenSidOnly === "boolean")
  );
}

function normalizeFilterState(value: unknown): FilterState | undefined {
  if (!isFilterState(value)) {
    return undefined;
  }

  const legacyBrokenSidOnly = (value as { brokenSidOnly?: boolean }).brokenSidOnly === true;
  return {
    ...defaultFilters,
    ...value,
    brokenSidMode: value.brokenSidMode ?? (legacyBrokenSidOnly ? "only" : defaultFilters.brokenSidMode)
  };
}

function isReturnTrail(value: unknown): value is ReturnTrail {
  if (!value || typeof value !== "object") {
    return false;
  }
  const candidate = value as Partial<ReturnTrail>;
  return isViewKey(candidate.from) && typeof candidate.label === "string" && typeof candidate.backLabel === "string";
}

function loadDashboardState(): PersistedDashboardState {
  try {
    const raw = window.sessionStorage.getItem(dashboardSessionKey);
    if (!raw) {
      return {};
    }
    const parsed = JSON.parse(raw) as PersistedDashboardState;
    return {
      activeView: isViewKey(parsed.activeView) ? parsed.activeView : undefined,
      filters: normalizeFilterState(parsed.filters),
      selectedIssueId: typeof parsed.selectedIssueId === "string" ? parsed.selectedIssueId : undefined,
      selectedClusterId: typeof parsed.selectedClusterId === "string" ? parsed.selectedClusterId : undefined,
      selectedGroupName: typeof parsed.selectedGroupName === "string" ? parsed.selectedGroupName : undefined,
      rawDatasetKey: isDatasetKey(parsed.rawDatasetKey) ? parsed.rawDatasetKey : undefined,
      returnTrail: parsed.returnTrail === null || isReturnTrail(parsed.returnTrail) ? parsed.returnTrail : undefined
    };
  } catch {
    return {};
  }
}

function saveDashboardState(state: PersistedDashboardState): void {
  try {
    window.sessionStorage.setItem(dashboardSessionKey, JSON.stringify(state));
  } catch {
    // Session persistence is a convenience; the dashboard must still work when browser storage is unavailable.
  }
}

function isReviewDecisionValue(value: unknown): value is ReviewDecisionValue {
  return value === "Expected" || value === "Needs Follow-up";
}

function isReviewDecision(value: unknown): value is ReviewDecision {
  if (!value || typeof value !== "object") {
    return false;
  }
  const candidate = value as Partial<ReviewDecision>;
  return (
    typeof candidate.issueId === "string" &&
    isReviewDecisionValue(candidate.decision) &&
    typeof candidate.updatedAt === "string" &&
    ["title", "category", "severity", "owner", "businessUnit", "path", "identity", "source"].every(
      (key) => typeof candidate[key as keyof ReviewDecision] === "string"
    ) &&
    (candidate.reviewer === undefined || typeof candidate.reviewer === "string") &&
    (candidate.note === undefined || typeof candidate.note === "string")
  );
}

function normalizeReviewDecision(value: unknown): ReviewDecision | null {
  if (!isReviewDecision(value)) {
    return null;
  }
  return {
    ...value,
    reviewer: value.reviewer ?? "",
    note: value.note ?? ""
  };
}

function loadReviewDecisions(): ReviewDecisionMap {
  try {
    const raw = window.localStorage.getItem(reviewDecisionsStorageKey);
    if (!raw) {
      return {};
    }
    const parsed = JSON.parse(raw) as Record<string, unknown>;
    const decisions = Object.entries(parsed)
      .map(([key, value]) => [key, normalizeReviewDecision(value)] as const)
      .filter((entry): entry is readonly [string, ReviewDecision] => entry[1] !== null);
    return Object.fromEntries(decisions) as ReviewDecisionMap;
  } catch {
    return {};
  }
}

function saveReviewDecisions(decisions: ReviewDecisionMap): void {
  try {
    if (Object.keys(decisions).length === 0) {
      window.localStorage.removeItem(reviewDecisionsStorageKey);
      return;
    }
    window.localStorage.setItem(reviewDecisionsStorageKey, JSON.stringify(decisions));
  } catch {
    // Local review decisions are a convenience layer; the evidence report remains read-only without storage.
  }
}

function buildReviewDecision(issue: IssueSummary, decision: ReviewDecisionValue, reviewer = "", note = ""): ReviewDecision {
  return {
    issueId: issue.id,
    decision,
    updatedAt: new Date().toISOString(),
    reviewer,
    note,
    title: issue.title,
    category: issue.category,
    severity: issue.severity,
    owner: issue.owner,
    businessUnit: issue.businessUnit,
    path: issue.path,
    identity: issue.identity,
    source: issue.source
  };
}

function csvCell(value: string): string {
  if (/[",\r\n]/.test(value)) {
    return `"${value.replace(/"/g, '""')}"`;
  }
  return value;
}

function buildReviewDecisionsCsv(decisions: ReviewDecision[]): string {
  const headers = ["IssueId", "Decision", "UpdatedAt", "Reviewer", "Note", "Title", "Category", "Severity", "Owner", "BusinessUnit", "Path", "Identity", "Source"];
  const rows = decisions
    .slice()
    .sort((a, b) => a.issueId.localeCompare(b.issueId))
    .map((decision) =>
      [
        decision.issueId,
        decision.decision,
        decision.updatedAt,
        decision.reviewer,
        decision.note,
        decision.title,
        decision.category,
        decision.severity,
        decision.owner,
        decision.businessUnit,
        decision.path,
        decision.identity,
        decision.source
      ].map(csvCell).join(",")
    );
  return [headers.join(","), ...rows].join("\r\n");
}

function buildReviewDecisionsDataUri(decisions: ReviewDecision[]): string {
  return `data:text/csv;charset=utf-8,${encodeURIComponent(buildReviewDecisionsCsv(decisions))}`;
}

function splitSearchTerms(query: string): string[] {
  return query.match(/[!-]?"[^"]+"|\S+/g) ?? [];
}

function parseSearchTermModifier(term: string): { value: string; excluded: boolean } {
  const excluded = term.startsWith("-") || term.startsWith("!");
  const withoutModifier = excluded ? term.slice(1) : term;
  return {
    value: withoutModifier.replace(/^"|"$/g, ""),
    excluded
  };
}

function parseScopedSearchTerm(term: string): ScopedSearchToken | null {
  const parsedTerm = parseSearchTermModifier(term);
  const normalizedTerm = parsedTerm.value;
  const scopedMatch = normalizedTerm.match(/^([a-z]+):(.+)$/i);
  if (!scopedMatch) {
    return null;
  }

  const scope = scopedMatch[1].toLowerCase() as SearchScope;
  const value = scopedMatch[2].trim();
  if (!(scope in searchScopeFields) || !value) {
    return null;
  }

  return { scope, value, normalizedValue: value.toLowerCase(), rawTerm: term, excluded: parsedTerm.excluded };
}

function parseSearchQuery(query: string): ParsedSearchQuery {
  const scoped: ScopedSearchToken[] = [];
  const excludedScoped: ScopedSearchToken[] = [];
  const freeText: string[] = [];
  const excludedFreeText: string[] = [];
  const terms = splitSearchTerms(query);

  for (const term of terms) {
    const scopedToken = parseScopedSearchTerm(term);
    if (scopedToken) {
      if (scopedToken.excluded) {
        excludedScoped.push(scopedToken);
      } else {
        scoped.push(scopedToken);
      }
      continue;
    }

    const parsedTerm = parseSearchTermModifier(term);
    const normalizedTerm = parsedTerm.value.trim();
    if (normalizedTerm) {
      if (parsedTerm.excluded) {
        excludedFreeText.push(normalizedTerm.toLowerCase());
      } else {
        freeText.push(normalizedTerm.toLowerCase());
      }
    }
  }

  return { scoped, excludedScoped, freeText, excludedFreeText };
}

function getSearchFreeTextDisplay(query: string): string {
  return splitSearchTerms(query)
    .filter((term) => !parseScopedSearchTerm(term))
    .map((term) => {
      const parsed = parseSearchTermModifier(term);
      return `${parsed.excluded ? "-" : ""}${parsed.value}`;
    })
    .join(" ");
}

function getScopedSearchTokens(query: string): ScopedSearchToken[] {
  return splitSearchTerms(query)
    .map((term) => parseScopedSearchTerm(term))
    .filter((token): token is ScopedSearchToken => token !== null);
}

function removeScopedSearchToken(query: string, targetIndex: number): string {
  let scopedIndex = -1;
  return splitSearchTerms(query)
    .filter((term) => {
      if (!parseScopedSearchTerm(term)) {
        return true;
      }

      scopedIndex += 1;
      return scopedIndex !== targetIndex;
    })
    .join(" ");
}

function objectText(row: Record<string, unknown>): string {
  return Object.values(row).join(" ").toLowerCase();
}

function getRowFieldValue(row: Record<string, unknown>, fieldName: string): string {
  const directValue = row[fieldName];
  if (directValue !== undefined && directValue !== null) {
    return String(directValue);
  }

  const matchingKey = Object.keys(row).find((key) => key.toLowerCase() === fieldName.toLowerCase());
  return matchingKey ? String(row[matchingKey] ?? "") : "";
}

function scopedRowText(row: Record<string, unknown>, scope: SearchScope): string {
  return searchScopeFields[scope].map((fieldName) => getRowFieldValue(row, fieldName)).join(" ").toLowerCase();
}

function matchesParsedSearch(row: Record<string, unknown>, parsedQuery: ParsedSearchQuery): boolean {
  if (parsedQuery.scoped.length === 0 && parsedQuery.excludedScoped.length === 0 && parsedQuery.freeText.length === 0 && parsedQuery.excludedFreeText.length === 0) {
    return true;
  }

  const fullText = objectText(row);
  return (
    parsedQuery.freeText.every((term) => fullText.includes(term)) &&
    parsedQuery.excludedFreeText.every((term) => !fullText.includes(term)) &&
    parsedQuery.scoped.every((token) => scopedRowText(row, token.scope).includes(token.normalizedValue)) &&
    parsedQuery.excludedScoped.every((token) => !scopedRowText(row, token.scope).includes(token.normalizedValue))
  );
}

function matchesText(value: string, filter: string): boolean {
  return !filter || value.toLowerCase() === filter.toLowerCase();
}

function isBrokenSidIdentity(value: string): boolean {
  const trimmed = value.trim();
  return /^S-\d-\d+(-\d+)+$/i.test(trimmed) || /account\s+unknown/i.test(trimmed) || /unknown\s+(account|sid)/i.test(trimmed);
}

function rowHasBrokenSid(row: Record<string, unknown>): boolean {
  const findingType = getRowFieldValue(row, "FindingType");
  const category = getRowFieldValue(row, "Category");
  const identity = getRowFieldValue(row, "Identity");
  return findingType === "BrokenOrMissingSid" || category === "Broken/Missing SID" || isBrokenSidIdentity(identity);
}

function matchesBrokenSidMode(hasBrokenSid: boolean, mode: BrokenSidMode): boolean {
  if (mode === "only") {
    return hasBrokenSid;
  }
  if (mode === "hide") {
    return !hasBrokenSid;
  }
  return true;
}

function datasetRows(dashboard: DashboardModel, key: DatasetKey): DataRow[] {
  return dashboard.rawEvidenceCatalog.find((entry) => entry.key === key)?.rows ?? [];
}

function splitIds(value: string): string[] {
  return value
    .split(/[;,]/)
    .map((item) => item.trim())
    .filter(Boolean);
}

function patternPrefix(pattern: string): string {
  return pattern.split("*")[0].toLowerCase();
}

function clusterPatterns(cluster: MigrationCluster): string[] {
  const values = splitIds(cluster.raw.PatternList || "");
  if (cluster.raw.Pattern) {
    values.push(cluster.raw.Pattern);
  }
  return Array.from(new Set(values.filter(Boolean)));
}

function shareIdsForCluster(cluster: MigrationCluster, dashboard: DashboardModel): Set<string> {
  const ids = new Set(splitIds(cluster.raw.ShareIds || cluster.raw.ShareId || ""));
  const prefixes = clusterPatterns(cluster).map(patternPrefix).filter(Boolean);
  if (ids.size === 0 && prefixes.length > 0) {
    for (const share of datasetRows(dashboard, "shares")) {
      const path = `${share.UNCPath} ${share.LocalPath}`.toLowerCase();
      if (prefixes.some((prefix) => path.startsWith(prefix) || path.includes(prefix))) {
        ids.add(share.ShareId);
      }
    }
  }
  return ids;
}

function rowsMatchingCluster(cluster: MigrationCluster, dashboard: DashboardModel, key: DatasetKey): DataRow[] {
  const shareIds = shareIdsForCluster(cluster, dashboard);
  const prefixes = clusterPatterns(cluster).map(patternPrefix).filter(Boolean);
  return datasetRows(dashboard, key).filter((row) => {
    return rowMatchesShareOrPath(row, shareIds, prefixes);
  });
}

function rowMatchesShareOrPath(row: Record<string, unknown>, shareIds: Set<string>, pathTokens: string[]): boolean {
  const shareId = getRowFieldValue(row, "ShareId");
  if (shareId && shareIds.has(shareId)) {
    return true;
  }

  const pathText = [
    getRowFieldValue(row, "FullPath"),
    getRowFieldValue(row, "ExamplePath"),
    getRowFieldValue(row, "UNCPath"),
    getRowFieldValue(row, "LocalPath")
  ].join(" ").toLowerCase();
  return pathTokens.some((token) => token !== "" && pathText.includes(token));
}

function brokenSidFindingRows(dashboard: DashboardModel): DataRow[] {
  return datasetRows(dashboard, "findings").filter(rowHasBrokenSid);
}

function clusterHasBrokenSidEvidence(cluster: MigrationCluster, dashboard: DashboardModel): boolean {
  const shareIds = shareIdsForCluster(cluster, dashboard);
  const prefixes = clusterPatterns(cluster).map(patternPrefix).filter(Boolean);
  return brokenSidFindingRows(dashboard).some((row) => rowMatchesShareOrPath(row, shareIds, prefixes));
}

function groupHasBrokenSidEvidence(group: GroupTreeRow, dashboard: DashboardModel): boolean {
  const shareIds = new Set(splitIds(group.raw.ShareIds || group.raw.ShareId || group.shareIds));
  const pathTokens = [group.examplePath, group.fullPath].filter(Boolean).map((path) => path.toLowerCase());
  return brokenSidFindingRows(dashboard).some((row) => rowMatchesShareOrPath(row, shareIds, pathTokens));
}

function rowsMatchingGroup(group: GroupTreeRow, dashboard: DashboardModel, key: DatasetKey): DataRow[] {
  const groupName = group.group.toLowerCase();
  const shareIds = new Set(splitIds(group.raw.ShareIds || group.raw.ShareId || ""));
  const paths = [group.examplePath, group.fullPath].filter(Boolean).map((path) => path.toLowerCase());
  return datasetRows(dashboard, key).filter((row) => {
    const identityMatch = `${row.Identity} ${row.Group} ${row.ParentGroup}`.toLowerCase().includes(groupName);
    const shareMatch = row.ShareId ? shareIds.has(row.ShareId) : false;
    const rowPath = `${row.FullPath} ${row.ExamplePath} ${row.UNCPath} ${row.LocalPath} ${row.Pattern} ${row.PatternList}`.toLowerCase();
    const rowPathPrefix = rowPath.replace(/\*+$/g, "").trim();
    const pathMatch = paths.some((path) => path !== "" && rowPathPrefix !== "" && (rowPath.includes(path) || path.includes(rowPathPrefix)));
    return identityMatch || shareMatch || pathMatch;
  });
}

function groupFilterEvidenceRows(group: GroupTreeRow, dashboard: DashboardModel): DataRow[] {
  const keys: DatasetKey[] = ["permissioned_groups", "owner_review_packets", "related_data_areas", "share_permissions", "acl_entries", "findings", "conflicts", "collection_errors"];
  return [
    group.raw,
    ...keys.flatMap((key) => rowsMatchingGroup(group, dashboard, key))
  ];
}

function evidenceRowsMatchFilter(rows: DataRow[], fields: string[], filter: string, requireEvidence = false): boolean {
  if (!filter) {
    return true;
  }

  const normalizedFilter = filter.toLowerCase();
  const values = rows.flatMap((row) => fields.map((field) => getRowFieldValue(row, field)).filter(Boolean));
  if (values.length === 0) {
    return !requireEvidence;
  }

  return values.some((value) => value.toLowerCase().includes(normalizedFilter));
}

function rawRowMatchesTopFilters(row: DataRow, filters: FilterState): boolean {
  return (
    evidenceRowsMatchFilter([row], ["BusinessUnit", "OwnerBusinessUnit", "Department"], filters.businessUnit) &&
    evidenceRowsMatchFilter([row], ["Owner", "DataOwner"], filters.owner) &&
    evidenceRowsMatchFilter([row], ["RiskLevel", "Severity", "ReviewStatus", "MigrationReadiness"], filters.risk) &&
    evidenceRowsMatchFilter([row], ["Source", "Sources", "SourceMode", "CollectionProvider"], filters.source)
  );
}

function rowsMatchingPathContext(group: GroupTreeRow, dashboard: DashboardModel): DataRow[] {
  const shareIds = new Set(splitIds(group.raw.ShareIds || group.raw.ShareId || ""));
  const paths = [group.examplePath, group.fullPath].filter(Boolean).map((path) => path.toLowerCase());
  const contextRows: DataRow[] = [];
  const keys: DatasetKey[] = ["items", "permissioned_groups", "acl_entries", "share_permissions", "findings", "conflicts", "collection_errors", "open_file_summary", "open_file_samples"];

  for (const key of keys) {
    for (const row of datasetRows(dashboard, key)) {
      const shareMatch = row.ShareId ? shareIds.has(row.ShareId) : false;
      const rowPath = `${row.FullPath} ${row.ExamplePath} ${row.UNCPath} ${row.LocalPath} ${row.Path} ${row.FolderPath} ${row.ShareRelativePath} ${row.ShareRelativeFolder}`.toLowerCase();
      const pathMatch = paths.some((path) => path !== "" && rowPath.includes(path));
      const identityMatch = `${row.Identity} ${row.Group}`.toLowerCase().includes(group.group.toLowerCase());
      if (shareMatch || pathMatch || identityMatch) {
        contextRows.push({
          Evidence: datasetLabels[key],
          ShareId: row.ShareId || "",
          ItemId: row.ItemId || "",
          Identity: row.Identity || row.Group || "",
          Type: row.FindingType || row.ConflictType || row.ErrorType || row.ItemType || row.AccessControlType || "",
          Rights: row.Rights || row.ShareRights || row.NtfsRights || "",
          Severity: row.Severity || "",
          Path: row.FullPath || row.ExamplePath || row.UNCPath || row.LocalPath || "",
          Message: row.Message || row.PartialReason || ""
        });
      }
    }
  }

  return contextRows;
}

function groupExpansionStatus(group: GroupTreeRow): string {
  if (group.hasCycle && group.isTruncated) {
    return "Cycle and depth protection";
  }
  if (group.hasCycle) {
    return "Cycle detected";
  }
  if (group.isTruncated) {
    return "Max depth reached";
  }
  return "Recursive expansion complete";
}

function chip(label: string, value: string, onRemove: () => void) {
  if (!value) {
    return null;
  }
  return (
    <button key={label} type="button" className="filter-chip" onClick={onRemove} aria-label={`Remove ${label} filter`}>
      <span>{label}: {value}</span>
      <span aria-hidden="true">×</span>
    </button>
  );
}

function booleanChip(label: string, active: boolean, onRemove: () => void) {
  if (!active) {
    return null;
  }
  return (
    <button key={label} type="button" className="filter-chip" onClick={onRemove} aria-label={`Remove ${label} filter`}>
      <span>{label}</span>
      <span aria-hidden="true">×</span>
    </button>
  );
}

function filtersAreClear(filters: FilterState): boolean {
  return !filters.query && !filters.businessUnit && !filters.owner && !filters.risk && !filters.source && filters.brokenSidMode === "all";
}

function hasRuntimeDatasets(snapshot?: RawSnapshot): boolean {
  if (!snapshot?.datasets) {
    return false;
  }

  const datasetValues = Object.values(snapshot.datasets);
  return datasetValues.some((rows) => Array.isArray(rows) && rows.length > 0);
}

function getRuntimeSnapshotState(useDemoSnapshot: boolean): RuntimeSnapshotState {
  if (useDemoSnapshot) {
    return {
      status: "ready",
      snapshot: demoSnapshot,
      datasetLabel: "Demo dataset",
      message: "Demo data is loaded intentionally."
    };
  }

  const runtime = window.__SHARESURFER_SNAPSHOT__;
  if (!runtime) {
    return {
      status: "missing",
      datasetLabel: "",
      message: "No runtime snapshot was found on window.__SHARESURFER_SNAPSHOT__."
    };
  }

  if (runtime.snapshotKind === "template") {
    return {
      status: "missing",
      datasetLabel: "",
      message: "This folder contains template dashboard assets, not a packaged ShareSurfer export."
    };
  }

  if (runtime.snapshotKind !== "export" && !hasRuntimeDatasets(runtime)) {
    return {
      status: "missing",
      datasetLabel: "",
      message: "The runtime snapshot did not include any export rows."
    };
  }

  return {
    status: "ready",
    snapshot: runtime,
    datasetLabel: runtime.snapshotKind === "export" ? "Export dataset" : "Runtime dataset",
    message: "ShareSurfer export data is loaded."
  };
}

function StatusBadge({ value }: { value: string }) {
  return <span className={`status-badge ${riskTone(value)}`}>{value || "Review"}</span>;
}

function SectionTitle({
  children,
  tooltip,
  eyebrow
}: {
  children: string;
  tooltip?: string;
  eyebrow?: string;
}) {
  return (
    <div className="section-title">
      <div>
        {eyebrow ? <p>{eyebrow}</p> : null}
        <h2>
          {children}
          {tooltip ? <Tooltip label={`${children} help`} text={tooltip} /> : null}
        </h2>
      </div>
    </div>
  );
}

function ReturnTrailBar({ trail, onBack }: { trail: ReturnTrail; onBack: () => void }) {
  return (
    <div className="return-trail" aria-label="Current drill-in context">
      <button type="button" onClick={onBack}>
        <ArrowLeft size={16} aria-hidden="true" />
        {trail.backLabel}
      </button>
      <span>{trail.label}</span>
    </div>
  );
}

function EvidenceWorkbench({ drill, onBack }: { drill: EvidenceDrill; onBack: () => void }) {
  return (
    <section className="panel evidence-workbench wide-scroll-pane">
      <div className="return-trail compact">
        <button type="button" onClick={onBack}>
          <ArrowLeft size={16} aria-hidden="true" />
          {drill.backLabel}
        </button>
        <span>{drill.subtitle}</span>
      </div>
      <SectionTitle tooltip={tooltipRegistry.rawEvidence}>{drill.title}</SectionTitle>
      <VirtualTable
        rows={drill.rows}
        columns={drill.columns}
        columnLabels={drill.columnLabels}
        pageSize={30}
        title={drill.title}
        enableExport={drill.enableExport}
        exportFileName={drill.exportFileName}
      />
      {drill.rows.length === 0 ? <p className="empty-state">{drill.emptyMessage}</p> : null}
    </section>
  );
}

function DatasetMissingScreen({ message, onOpenDemo }: { message: string; onOpenDemo: () => void }) {
  return (
    <main className="dataset-gate" aria-labelledby="dataset-gate-title">
      <section className="panel dataset-gate-panel">
        <div className="dataset-gate-icon" aria-hidden="true">
          <FileWarning size={36} />
        </div>
        <div>
          <p className="eyebrow">Standalone dashboard</p>
          <h1 id="dataset-gate-title">No ShareSurfer dataset found</h1>
          <p className="panel-copy">{message}</p>
        </div>
        <div className="info-banner">
          <strong>Expected sharesurfer-data.js</strong>
          <span>
            Package a validated export with <code>scripts/New-ShareSurferStandaloneDashboard.ps1</code>, then open the generated <code>index.html</code>.
          </span>
        </div>
        <ol className="dataset-gate-steps">
          <li>Run <code>Invoke-ShareSurferScan</code> on the collector host.</li>
          <li>Run <code>New-ShareSurferStandaloneDashboard.ps1</code> against the export folder.</li>
          <li>Open the packaged dashboard folder from the review workstation.</li>
        </ol>
        <button type="button" className="primary-action" onClick={onOpenDemo}>
          Open demo dataset
        </button>
      </section>
    </main>
  );
}

function MetricButton({
  label,
  value,
  onClick,
  detail
}: {
  label: string;
  value: number;
  onClick: () => void;
  detail?: string;
}) {
  return (
    <button type="button" className="stat-card interactive" onClick={onClick}>
      <span>{label}</span>
      <strong>{formatNumber(value)}</strong>
      {detail ? <small>{detail}</small> : null}
    </button>
  );
}

function ReportContextStrip({
  summary,
  datasetLabel
}: {
  summary: ScanSummary;
  datasetLabel: string;
}) {
  const generatedAt = formatReportDate(summary.generatedAt);
  const contextItems = [
    { label: "Report generated", value: generatedAt },
    { label: "Source mode", value: summary.sourceMode || "Unknown" },
    { label: "OBS attribute", value: summary.obsAttribute || "Not recorded" },
    { label: "Dataset", value: datasetLabel }
  ];

  return (
    <dl className="report-context-strip" aria-label="Report context">
      {contextItems.map((item) => (
        <div key={item.label}>
          <dt>{item.label}</dt>
          <dd>{item.value}</dd>
        </div>
      ))}
    </dl>
  );
}

function FilterBar({
  dashboard,
  filters,
  onFiltersChange
}: {
  dashboard: DashboardModel;
  filters: FilterState;
  onFiltersChange: (filters: FilterState) => void;
}) {
  const update = (patch: Partial<FilterState>) => {
    startTransition(() => onFiltersChange({ ...filters, ...patch }));
  };
  const updateQuery = (value: string) => update({ query: value });
  const scopedTokens = getScopedSearchTokens(filters.query);
  const freeTextSearch = getSearchFreeTextDisplay(filters.query);

  return (
    <section className="filter-bar" aria-label="Dashboard filters">
      <label className="search-box">
        <Search aria-hidden="true" size={18} />
        <span className="sr-only">Search dashboard</span>
        <input
          type="search"
          value={filters.query}
          onInput={(event) => updateQuery(event.currentTarget.value)}
          onChange={(event) => updateQuery(event.currentTarget.value)}
          placeholder="Search owners, shares, identities, paths, groups..."
        />
      </label>
      <label>
        <span>Business Unit</span>
        <select value={filters.businessUnit} onChange={(event) => update({ businessUnit: event.target.value })}>
          <option value="">All</option>
          {dashboard.filters.businessUnits.map((value) => (
            <option key={value}>{value}</option>
          ))}
        </select>
      </label>
      <label>
        <span>Data Owner</span>
        <select value={filters.owner} onChange={(event) => update({ owner: event.target.value })}>
          <option value="">All</option>
          {dashboard.filters.owners.map((value) => (
            <option key={value}>{value}</option>
          ))}
        </select>
      </label>
      <label>
        <span>Review Risk</span>
        <select value={filters.risk} onChange={(event) => update({ risk: event.target.value })}>
          <option value="">All</option>
          {dashboard.filters.riskLevels.map((value) => (
            <option key={value}>{value}</option>
          ))}
        </select>
      </label>
      <label>
        <span>Source</span>
        <select value={filters.source} onChange={(event) => update({ source: event.target.value })}>
          <option value="">All</option>
          {dashboard.filters.sources.map((value) => (
            <option key={value}>{value}</option>
          ))}
        </select>
      </label>
      <div className="sid-filter-stack" aria-label="Broken or missing SID filter mode">
        <label className="toggle-filter">
          <input
            type="checkbox"
            checked={filters.brokenSidMode === "only"}
            onChange={(event) => update({ brokenSidMode: event.target.checked ? "only" : "all" })}
          />
          <span>Show only Broken/Missing SIDs</span>
        </label>
        <label className="toggle-filter">
          <input
            type="checkbox"
            checked={filters.brokenSidMode === "hide"}
            onChange={(event) => update({ brokenSidMode: event.target.checked ? "hide" : "all" })}
          />
          <span>Hide Broken/Missing SIDs</span>
        </label>
      </div>
      <div className="active-context">
        <strong>Active Context</strong>
        <div className="filter-chips">
          {scopedTokens.map((token, index) => (
            <button
              key={`${token.scope}:${token.value}:${index}`}
              type="button"
              className="filter-chip search-signal"
              onClick={() => updateQuery(removeScopedSearchToken(filters.query, index))}
              aria-label={`Remove ${token.excluded ? "excluded " : ""}${token.scope} search ${token.value}`}
            >
              <span>{token.excluded ? "not " : ""}{token.scope}: {token.value}</span>
              <span aria-hidden="true">×</span>
            </button>
          ))}
          {chip("Search", freeTextSearch, () => update({ query: scopedTokens.map((token) => token.rawTerm).join(" ") }))}
          {chip("Business Unit", filters.businessUnit, () => update({ businessUnit: "" }))}
          {chip("Owner", filters.owner, () => update({ owner: "" }))}
          {chip("Risk", filters.risk, () => update({ risk: "" }))}
          {chip("Source", filters.source, () => update({ source: "" }))}
          {booleanChip("Showing only Broken/Missing SIDs", filters.brokenSidMode === "only", () => update({ brokenSidMode: "all" }))}
          {booleanChip("Broken/Missing SIDs hidden", filters.brokenSidMode === "hide", () => update({ brokenSidMode: "all" }))}
          {filtersAreClear(filters) ? <span className="muted">Enterprise-wide view</span> : null}
          {!filtersAreClear(filters) ? (
            <button type="button" className="clear-button" onClick={() => update(defaultFilters)}>
              Clear all
            </button>
          ) : null}
        </div>
      </div>
    </section>
  );
}

function filterQueue(rows: ReviewQueueRow[], filters: FilterState, query: string) {
  const parsedQuery = parseSearchQuery(query);
  return rows.filter(
    (row) =>
      matchesText(row.businessUnit, filters.businessUnit) &&
      matchesText(row.owner, filters.owner) &&
      (!filters.source || row.source.toLowerCase().includes(filters.source.toLowerCase())) &&
      (!filters.risk || row.riskLevel.toLowerCase().includes(filters.risk.toLowerCase())) &&
      matchesParsedSearch(
        {
          BusinessUnit: row.businessUnit,
          Owner: row.owner,
          Source: row.source,
          RiskLevel: row.riskLevel,
          WhyReview: row.whyReview,
          SuggestedNextAction: row.firstAction
        },
        parsedQuery
      )
  );
}

function filterIssues(rows: IssueSummary[], filters: FilterState, query: string) {
  const parsedQuery = parseSearchQuery(query);
  return rows.filter(
    (row) =>
      matchesBrokenSidMode(row.category === "Broken/Missing SID" || isBrokenSidIdentity(row.identity), filters.brokenSidMode) &&
      (!filters.risk || row.severity.toLowerCase().includes(filters.risk.toLowerCase()) || row.category.toLowerCase().includes(filters.risk.toLowerCase())) &&
      (!filters.owner || row.owner.toLowerCase() === filters.owner.toLowerCase()) &&
      (!filters.businessUnit || row.businessUnit.toLowerCase() === filters.businessUnit.toLowerCase()) &&
      (!filters.source || row.source.toLowerCase().includes(filters.source.toLowerCase())) &&
      matchesParsedSearch(
        {
          Owner: row.owner,
          BusinessUnit: row.businessUnit,
          Title: row.title,
          Category: row.category,
          FullPath: row.path,
          Identity: row.identity,
          WhatHappened: row.whatHappened
        },
        parsedQuery
      )
  );
}

function filterClusters(rows: MigrationCluster[], filters: FilterState, query: string, dashboard: DashboardModel) {
  const parsedQuery = parseSearchQuery(query);
  return rows.filter(
    (row) =>
      matchesBrokenSidMode(clusterHasBrokenSidEvidence(row, dashboard), filters.brokenSidMode) &&
      matchesText(row.businessUnit, filters.businessUnit) &&
      matchesText(row.owner, filters.owner) &&
      (!filters.source || row.raw.Source.toLowerCase().includes(filters.source.toLowerCase())) &&
      (!filters.risk || row.riskLevel.toLowerCase().includes(filters.risk.toLowerCase()) || row.readiness.toLowerCase().includes(filters.risk.toLowerCase())) &&
      matchesParsedSearch(
        {
          RelatedDataArea: row.name,
          Owner: row.owner,
          BusinessUnit: row.businessUnit,
          RiskLevel: row.riskLevel,
          MigrationReadiness: row.readiness,
          RelatedBecause: row.relatedSignals.join(" "),
          SuggestedNextAction: row.nextAction
        },
        parsedQuery
      )
  );
}

function filterGroups(rows: GroupTreeRow[], filters: FilterState, query: string, dashboard: DashboardModel) {
  const parsedQuery = parseSearchQuery(query);
  return rows.filter(
    (row) => {
      const evidenceRows = groupFilterEvidenceRows(row, dashboard);
      return (
      matchesBrokenSidMode(groupHasBrokenSidEvidence(row, dashboard), filters.brokenSidMode) &&
      evidenceRowsMatchFilter(evidenceRows, ["BusinessUnit", "OwnerBusinessUnit", "Department"], filters.businessUnit, true) &&
      evidenceRowsMatchFilter(evidenceRows, ["Owner", "DataOwner"], filters.owner, true) &&
      evidenceRowsMatchFilter(evidenceRows, ["Source", "Sources", "SourceMode", "CollectionProvider"], filters.source, true) &&
      (!filters.risk || row.riskLevel.toLowerCase().includes(filters.risk.toLowerCase()) || evidenceRowsMatchFilter(evidenceRows, ["RiskLevel", "Severity", "ReviewStatus", "MigrationReadiness"], filters.risk, true)) &&
      matchesParsedSearch(
        {
          Group: row.group,
          DisplayName: row.displayName,
          ObsPath: row.obsPath,
          Rights: row.rights,
          RiskLevel: row.riskLevel,
          ShareId: row.raw.ShareId,
          ShareIds: row.shareIds,
          Sources: row.sources,
          FullPath: row.fullPath,
          ExamplePath: row.examplePath,
          ChildIdentity: row.children.map((child) => child.ChildIdentity).join(" "),
          RelatedEvidence: evidenceRows.map((evidenceRow) => objectText(evidenceRow)).join(" ")
        },
        parsedQuery
      )
      );
    }
  );
}

function filterCriticalBlocks(rows: CriticalScanBlock[], filters: FilterState, query: string) {
  const parsedQuery = parseSearchQuery(query);
  return rows.filter(
    (row) =>
      matchesBrokenSidMode(rowHasBrokenSid(row), filters.brokenSidMode) &&
      rawRowMatchesTopFilters(row, filters) &&
      (!filters.risk || row.Severity.toLowerCase().includes(filters.risk.toLowerCase()) || row.ErrorType.toLowerCase().includes(filters.risk.toLowerCase())) &&
      matchesParsedSearch(row, parsedQuery)
  );
}

function hasActiveContext(filters: FilterState, query: string): boolean {
  return Boolean(query || filters.businessUnit || filters.owner || filters.risk || filters.source || filters.brokenSidMode !== "all");
}

function buildOverviewSummary(
  dashboard: DashboardModel,
  filteredQueue: ReviewQueueRow[],
  filteredIssues: IssueSummary[],
  filters: FilterState,
  query: string
): ScanSummary {
  if (!hasActiveContext(filters, query)) {
    return dashboard.scanSummary;
  }

  const queueTotals = filteredQueue.reduce(
    (totals, row) => ({
      matchingItems: totals.matchingItems + row.matchingItems,
      findingCount: totals.findingCount + row.findingCount,
      conflictCount: totals.conflictCount + row.conflictCount,
      partialShareCount: totals.partialShareCount + row.partialShareCount,
      permissionedGroups: totals.permissionedGroups + row.permissionedGroups,
      expandedMembers: totals.expandedMembers + row.expandedMembers
    }),
    {
      matchingItems: 0,
      findingCount: 0,
      conflictCount: 0,
      partialShareCount: 0,
      permissionedGroups: 0,
      expandedMembers: 0
    }
  );

  return {
    ...dashboard.scanSummary,
    totalItems: queueTotals.matchingItems,
    totalFindings: queueTotals.findingCount,
    highPriorityItems: filteredQueue
      .filter((row) => (row.riskLevel ? riskTone(row.riskLevel) === "danger" : false))
      .reduce((sum, row) => sum + row.matchingItems, 0),
    conflicts: queueTotals.conflictCount,
    partialShares: queueTotals.partialShareCount,
    permissionedGroups: queueTotals.permissionedGroups,
    expandedMembers: queueTotals.expandedMembers,
    potentialServiceAccounts: filteredIssues.filter((issue) => issue.category === "Service Account Review").length,
    longPathRisks: filteredIssues.filter((issue) => issue.category === "Long Path Warning").length,
    brokenSidFindings: filteredIssues.filter((issue) => issue.category === "Broken/Missing SID").length
  };
}

function OverviewView({
  dashboard,
  summary,
  filters,
  query,
  onOpenView,
  onKpiSelect,
  onOwnerSelect
}: {
  dashboard: DashboardModel;
  summary: ScanSummary;
  filters: FilterState;
  query: string;
  onOpenView: (view: ViewKey) => void;
  onKpiSelect: (destination: "high-priority" | "access-conflicts" | "partial-shares" | "permissioned-groups" | "service-accounts" | "broken-sids" | "items") => void;
  onOwnerSelect: (row: ReviewQueueRow) => void;
}) {
  const filteredReviewQueue = filterQueue(dashboard.reviewQueue, filters, query);
  const queue = filteredReviewQueue.slice(0, 8);
  const queueTableRows = filteredReviewQueue.map((row) => ({
    ReviewQueueId: row.id,
    Owner: row.owner,
    "Business Unit": row.businessUnit,
    Risk: row.riskLevel,
    "Review Why": row.whyReview,
    Items: String(row.matchingItems),
    Findings: String(row.findingCount),
    Conflicts: String(row.conflictCount),
    "Permissioned Groups": String(row.permissionedGroups)
  }));
  const quickInsights = [
    `${formatNumber(summary.conflicts)} access conflict rows need access-model review.`,
    `${formatNumber(summary.partialShares)} share(s) have partial evidence. Review Diagnostics before approval.`,
    `${formatNumber(summary.permissionedGroups)} permissioned groups are granting direct access.`,
    `${formatNumber(summary.brokenSidFindings)} unresolved SID signal(s) need directory or trust review.`,
    `${formatNumber(summary.potentialServiceAccounts)} account(s) need service-account purpose review.`
  ];

  return (
    <div className="view-grid overview-grid">
      <div className="kpi-grid">
        <KpiCard
          label="High Priority Items"
          value={formatNumber(summary.highPriorityItems)}
          tone="danger"
          detail="Requires review"
          tooltip={tooltipRegistry.reviewRisk}
          icon={<ShieldAlert />}
          onClick={() => onKpiSelect("high-priority")}
          actionLabel="Open High Priority Items"
        />
        <KpiCard
          label="Access Conflicts"
          value={formatNumber(summary.conflicts)}
          tone="warning"
          detail="Share vs. folder/file"
          tooltip={tooltipRegistry.shareGate}
          icon={<KeyRound />}
          onClick={() => onKpiSelect("access-conflicts")}
          actionLabel="Open Access Conflicts"
        />
        <KpiCard
          label="Partial Shares"
          value={formatNumber(summary.partialShares)}
          tone={summary.partialShares > 0 ? "warning" : "good"}
          detail="Incomplete data"
          tooltip={tooltipRegistry.partialData}
          icon={<AlertTriangle />}
          onClick={() => onKpiSelect("partial-shares")}
          actionLabel="Open Partial Shares"
        />
        <KpiCard
          label="Permissioned Groups"
          value={formatNumber(summary.permissionedGroups)}
          tone="info"
          detail="Granting access"
          tooltip={tooltipRegistry.permissionedGroup}
          icon={<Users />}
          onClick={() => onKpiSelect("permissioned-groups")}
          actionLabel="Open Permissioned Groups"
        />
        <KpiCard
          label="Potential Service Accounts"
          value={formatNumber(summary.potentialServiceAccounts)}
          tone={summary.potentialServiceAccounts > 0 ? "warning" : "good"}
          detail="Purpose needs review"
          tooltip={tooltipRegistry.potentialServiceAccount}
          icon={<ServerCog />}
          onClick={() => onKpiSelect("service-accounts")}
          actionLabel="Open Potential Service Accounts"
        />
        <KpiCard
          label="Broken/Missing SID"
          value={formatNumber(summary.brokenSidFindings)}
          tone={summary.brokenSidFindings > 0 ? "danger" : "good"}
          detail="Directory lookup gap"
          tooltip={tooltipRegistry.brokenSid}
          icon={<ShieldAlert />}
          onClick={() => onKpiSelect("broken-sids")}
          actionLabel="Open Broken/Missing SID"
        />
        <KpiCard
          label="Items Reviewed"
          value={formatNumber(summary.totalItems)}
          tone="neutral"
          detail="Files + folders"
          tooltip={tooltipRegistry.rawEvidence}
          icon={<FolderOpen />}
          onClick={() => onKpiSelect("items")}
          actionLabel="Open Items Reviewed"
        />
      </div>

      <section className="panel queue-panel wide-scroll-pane">
        <SectionTitle tooltip={tooltipRegistry.reviewRisk}>What Needs Review First</SectionTitle>
        <p className="panel-copy">
          Owner means the mapped business reviewer or data owner for this path. It is separate from the Windows/NTFS file owner field.
        </p>
        <VirtualTable
          rows={queueTableRows}
          columns={["Owner", "Business Unit", "Risk", "Items", "Findings", "Conflicts", "Permissioned Groups", "Review Why"]}
          pageSize={8}
          title="What needs review first"
          onRowSelect={(row) => {
            const selected = filteredReviewQueue.find((queueRow) => queueRow.id === row.ReviewQueueId);
            if (selected) {
              onOwnerSelect(selected);
            }
          }}
          rowKey={(row) => row.ReviewQueueId ?? `${row.Owner}-${row["Business Unit"]}`}
        />
      </section>

      <aside className="panel insights-panel">
        <SectionTitle tooltip={tooltipRegistry.scanConfidence}>Scan Confidence</SectionTitle>
        <p className="date-callout">Report generated {formatReportDate(summary.generatedAt)}</p>
        <div className={`confidence-ring ${riskTone(summary.confidenceLabel)}`}>
          <strong>{summary.scanConfidence}%</strong>
          <span>{summary.confidenceLabel}</span>
        </div>
        <ul className="insight-list">
          {quickInsights.map((insight) => (
            <li key={insight}>{insight}</li>
          ))}
        </ul>
        <button type="button" className="link-button" onClick={() => onOpenView("diagnostics")}>
          View diagnostics
        </button>
      </aside>

      <section className="panel glossary-panel" aria-label="Key terms">
        <SectionTitle tooltip="Plain-English definitions for the main labels and filters used in this dashboard.">Key Terms</SectionTitle>
        <dl className="glossary-grid">
          {glossaryTerms.map((item) => (
            <div key={item.term}>
              <dt>{item.term}</dt>
              <dd>{item.definition}</dd>
            </div>
          ))}
        </dl>
      </section>

      <section className="panel workbench-panel wide-scroll-pane">
        <SectionTitle tooltip={tooltipRegistry.ownerMapping}>Owner Workbench</SectionTitle>
        {queue[0] ? (
          <div className="workbench-layout">
            <div>
              <h3>{queue[0].owner}</h3>
              <p>{queue[0].whyReview}</p>
              <dl className="stat-grid">
                <div>
                  <dt>Business Unit</dt>
                  <dd>{queue[0].businessUnit}</dd>
                </div>
                <div>
                  <dt>Findings</dt>
                  <dd>{formatNumber(queue[0].findingCount)}</dd>
                </div>
                <div>
                  <dt>Conflicts</dt>
                  <dd>{formatNumber(queue[0].conflictCount)}</dd>
                </div>
                <div>
                  <dt>Expanded Members</dt>
                  <dd>{formatNumber(queue[0].expandedMembers)}</dd>
                </div>
              </dl>
            </div>
            <div className="action-box">
              <strong>Suggested next action</strong>
              <p>{queue[0].firstAction}</p>
              <button type="button" onClick={() => onOpenView("findings")}>
                Review issues
              </button>
            </div>
          </div>
        ) : (
          <p className="empty-state">No owner review packets match the current filters.</p>
        )}
      </section>
      <section className="panel workbench-panel wide-scroll-pane">
        <SectionTitle tooltip={tooltipRegistry.ownerMapping}>Ad-Hoc Owner Review Table</SectionTitle>
        <p className="panel-copy">Sort or filter this table when you need a quick owner, business-unit, risk, or signal count pivot.</p>
        <VirtualTable rows={queueTableRows} columns={["Owner", "Business Unit", "Risk", "Items", "Findings", "Conflicts", "Permissioned Groups", "Review Why"]} pageSize={12} title="Ad-Hoc owner review table" />
      </section>
    </div>
  );
}

function FindingsView({
  issues,
  criticalBlocks,
  onIssueSelect,
  selectedIssue,
  reviewDecisions,
  onReviewDecision,
  onReviewDecisionContextChange,
  onClearReviewDecision,
  generatedAt
}: {
  issues: IssueSummary[];
  criticalBlocks: CriticalScanBlock[];
  selectedIssue?: IssueSummary;
  onIssueSelect: (issue: IssueSummary) => void;
  reviewDecisions: ReviewDecisionMap;
  onReviewDecision: (issue: IssueSummary, decision: ReviewDecisionValue, reviewer: string, note: string) => void;
  onReviewDecisionContextChange: (issueId: string, patch: Pick<ReviewDecision, "reviewer" | "note">) => void;
  onClearReviewDecision: (issueId: string) => void;
  generatedAt: string;
}) {
  const [categoryFilter, setCategoryFilter] = useState("");
  const [employeePrefixFilter, setEmployeePrefixFilter] = useState("");
  const [reviewerDraft, setReviewerDraft] = useState("");
  const [noteDraft, setNoteDraft] = useState("");
  const issueRollups = useMemo(() => {
    const counts = new Map<string, number>();
    for (const issue of issues) {
      counts.set(issue.category, (counts.get(issue.category) ?? 0) + 1);
    }
    return Array.from(counts.entries())
      .map(([category, count]) => ({ category, count }))
      .sort((a, b) => b.count - a.count || a.category.localeCompare(b.category));
  }, [issues]);
  const visibleIssues = categoryFilter ? issues.filter((issue) => issue.category === categoryFilter) : issues;
  const employeePrefixRows = useMemo(() => {
    const requestedPrefix = employeePrefixFilter.trim();
    const groups = new Map<
      string,
      {
        EmployeePrefix: string;
        MatchPrefix: string;
        IdentifierField: string;
        IssueCount: number;
        HighSeverityCount: number;
        Identities: Set<string>;
        Categories: Set<string>;
        Owners: Set<string>;
        BusinessUnits: Set<string>;
        ExamplePath: string;
        IssueIds: string[];
      }
    >();

    for (const issue of visibleIssues) {
      const issuePrefix = issue.employeePrefix || "";
      if (requestedPrefix && !issuePrefix.startsWith(requestedPrefix)) {
        continue;
      }
      const groupPrefix = issuePrefix
        ? issuePrefix.slice(0, requestedPrefix ? requestedPrefix.length : Math.min(2, issuePrefix.length))
        : "No employee ID/number";
      const group =
        groups.get(groupPrefix) ??
        {
          EmployeePrefix: groupPrefix,
          MatchPrefix: requestedPrefix || groupPrefix,
          IdentifierField: issue.employeeIdentifierField || "Unavailable",
          IssueCount: 0,
          HighSeverityCount: 0,
          Identities: new Set<string>(),
          Categories: new Set<string>(),
          Owners: new Set<string>(),
          BusinessUnits: new Set<string>(),
          ExamplePath: "",
          IssueIds: []
        };

      group.IssueCount += 1;
      if (riskTone(issue.severity) === "danger") {
        group.HighSeverityCount += 1;
      }
      if (issue.employeeIdentifierField) {
        group.IdentifierField = uniqueStrings([group.IdentifierField === "Unavailable" ? "" : group.IdentifierField, issue.employeeIdentifierField]).join("; ");
      }
      if (issue.identity) {
        group.Identities.add(issue.identity);
      }
      if (issue.category) {
        group.Categories.add(issue.category);
      }
      if (issue.owner) {
        group.Owners.add(issue.owner);
      }
      if (issue.businessUnit) {
        group.BusinessUnits.add(issue.businessUnit);
      }
      if (!group.ExamplePath && issue.path) {
        group.ExamplePath = issue.path;
      }
      group.IssueIds.push(issue.id);
      groups.set(groupPrefix, group);
    }

    return Array.from(groups.values())
      .map((group) => ({
        EmployeePrefix: group.EmployeePrefix,
        MatchPrefix: group.MatchPrefix,
        IdentifierField: group.IdentifierField,
        IssueCount: String(group.IssueCount),
        HighSeverityCount: String(group.HighSeverityCount),
        Identities: Array.from(group.Identities).join("; "),
        Categories: Array.from(group.Categories).join("; "),
        Owners: Array.from(group.Owners).join("; "),
        BusinessUnits: Array.from(group.BusinessUnits).join("; "),
        ExamplePath: group.ExamplePath,
        IssueIds: group.IssueIds.join("; ")
      }))
      .sort((a, b) => Number(b.IssueCount) - Number(a.IssueCount) || a.EmployeePrefix.localeCompare(b.EmployeePrefix));
  }, [employeePrefixFilter, visibleIssues]);
  const selected = selectedIssue && visibleIssues.some((issue) => issue.id === selectedIssue.id) ? selectedIssue : visibleIssues[0];
  const issueIds = new Set(issues.map((issue) => issue.id));
  const scopedReviewDecisions = Object.values(reviewDecisions).filter((decision) => issueIds.has(decision.issueId));
  const selectedReviewDecision = selected ? reviewDecisions[selected.id] : undefined;
  const reviewedVisibleCount = visibleIssues.filter((issue) => Boolean(reviewDecisions[issue.id])).length;
  const rows = visibleIssues.map((issue) => ({
    IssueId: issue.id,
    Category: issue.category,
    Severity: issue.severity,
    Title: issue.title,
    Identity: issue.identity,
    Path: issue.path
  }));

  useEffect(() => {
    setReviewerDraft(selectedReviewDecision?.reviewer ?? "");
    setNoteDraft(selectedReviewDecision?.note ?? "");
  }, [selected?.id, selectedReviewDecision?.reviewer, selectedReviewDecision?.note]);

  const updateReviewerDraft = (value: string) => {
    setReviewerDraft(value);
    if (selectedReviewDecision) {
      onReviewDecisionContextChange(selectedReviewDecision.issueId, { reviewer: value, note: noteDraft });
    }
  };

  const updateNoteDraft = (value: string) => {
    setNoteDraft(value);
    if (selectedReviewDecision) {
      onReviewDecisionContextChange(selectedReviewDecision.issueId, { reviewer: reviewerDraft, note: value });
    }
  };

  return (
    <div className="split-view">
      <section className="panel wide-scroll-pane">
        <SectionTitle tooltip={tooltipRegistry.fileFolderPermissions}>Findings & Conflicts</SectionTitle>
        <div className="report-context-note" aria-label="Findings report context">
          <CalendarDays size={17} aria-hidden="true" />
          <span>Findings use evidence generated {formatReportDate(generatedAt)}. Treat this as current-state evidence, not approval status.</span>
        </div>
        <div className="review-progress" aria-label="Finding review progress">
          <div>
            <strong>{formatNumber(reviewedVisibleCount)} of {formatNumber(visibleIssues.length)} reviewed</strong>
            <span>Local decisions only. Export the CSV to share this review state.</span>
          </div>
          <progress value={reviewedVisibleCount} max={visibleIssues.length || 1} aria-label={`${reviewedVisibleCount} of ${visibleIssues.length} reviewed`} />
        </div>
        {criticalBlocks.length > 0 ? (
          <div className="critical-blocks" aria-label="Critical scan information blocks">
            <h3>Critical Scan Information Blocks</h3>
            <p className="panel-copy">These collection gaps can hide permissions or paths. Resolve or explain them before final owner approval.</p>
            <VirtualTable
              title="Critical scan information blocks"
              rows={criticalBlocks}
              columns={["Severity", "ErrorType", "Source", "FullPath", "Message"]}
              pageSize={6}
            />
          </div>
        ) : null}
        <div className="rollup-bar" aria-label="Finding rollups">
          <button
            type="button"
            className={`rollup-chip ${categoryFilter === "" ? "active" : ""}`}
            onClick={() => setCategoryFilter("")}
          >
            All <strong>{formatNumber(issues.length)}</strong>
          </button>
          {issueRollups.map((rollup) => (
            <button
              key={rollup.category}
              type="button"
              className={`rollup-chip ${categoryFilter === rollup.category ? "active" : ""}`}
              onClick={() => setCategoryFilter(rollup.category)}
              aria-label={`Filter findings by ${rollup.category}`}
            >
              {rollup.category} <strong>{formatNumber(rollup.count)}</strong>
            </button>
          ))}
        </div>
        <div className="employee-prefix-panel" aria-label="Employee ID number prefix pivot">
          <div className="pivot-heading">
            <div>
              <h3>EmployeeID/EmployeeNumber Prefix Pivot</h3>
              <p className="panel-copy">
                Type the first number(s), such as 67, to group and export findings tied to employee identifiers that start with that string.
              </p>
            </div>
            <label>
              Prefix
              <input
                type="search"
                value={employeePrefixFilter}
                onChange={(event) => setEmployeePrefixFilter(event.currentTarget.value)}
                placeholder="Example: 67"
                aria-label="Employee ID or EmployeeNumber prefix"
              />
            </label>
          </div>
          <VirtualTable
            title="Employee ID number prefix pivot"
            rows={employeePrefixRows}
            columns={[
              "EmployeePrefix",
              "MatchPrefix",
              "IdentifierField",
              "IssueCount",
              "HighSeverityCount",
              "Identities",
              "Categories",
              "Owners",
              "BusinessUnits",
              "ExamplePath",
              "IssueIds"
            ]}
            pageSize={8}
            enableFieldFilters
            enableExport
            exportFileName="employee-prefix-findings-pivot.csv"
          />
        </div>
        <VirtualTable
          title="Findings and conflicts"
          rows={rows}
          columns={["Severity", "Category", "Title", "Identity", "Path"]}
          pageSize={16}
          onRowSelect={(row) => {
            const nextIssue = visibleIssues.find((issue) => issue.id === row.IssueId);
            if (nextIssue) {
              onIssueSelect(nextIssue);
            }
          }}
          rowKey={(row) => row.IssueId}
        />
      </section>
      <aside className="panel detail-panel">
        {selected ? (
          <>
            <div className="detail-heading">
              <div>
                <h2>{selected.title}</h2>
                <p>{selected.category}</p>
              </div>
              <StatusBadge value={selected.severity} />
            </div>
            <section className="review-decision-panel" aria-label="Local finding review decision">
              <div>
                <h3>Local review decision</h3>
                <p className="panel-copy">Stored only in this browser. Export the CSV when you are ready to share reviewer notes outside the dashboard.</p>
                <strong className="decision-summary">
                  {selectedReviewDecision ? `Decision: ${selectedReviewDecision.decision}` : "No decision recorded"}
                </strong>
              </div>
              <div className="review-decision-fields">
                <label>
                  Reviewer
                  <input type="text" value={reviewerDraft} onChange={(event) => updateReviewerDraft(event.target.value)} placeholder="Name or initials" />
                </label>
                <label>
                  Review note
                  <textarea value={noteDraft} onChange={(event) => updateNoteDraft(event.target.value)} placeholder="Why this decision was made" rows={3} />
                </label>
              </div>
              <div className="review-decision-actions">
                <button type="button" className="link-button" onClick={() => onReviewDecision(selected, "Expected", reviewerDraft.trim(), noteDraft.trim())}>
                  Mark Expected
                </button>
                <button type="button" className="link-button" onClick={() => onReviewDecision(selected, "Needs Follow-up", reviewerDraft.trim(), noteDraft.trim())}>
                  Mark Needs Follow-up
                </button>
                <button type="button" className="clear-button" onClick={() => onClearReviewDecision(selected.id)} disabled={!selectedReviewDecision}>
                  Clear decision
                </button>
                {scopedReviewDecisions.length > 0 ? (
                  <a className="link-button" href={buildReviewDecisionsDataUri(scopedReviewDecisions)} download="review-decisions.csv">
                    Export review decisions
                  </a>
                ) : (
                  <button type="button" className="clear-button" disabled>
                    Export review decisions
                  </button>
                )}
              </div>
            </section>
            <div className="detail-grid">
              <article>
                <h3>What happened?</h3>
                <p>{selected.whatHappened}</p>
              </article>
              <article>
                <h3>Why it matters</h3>
                <p>{selected.whyItMatters}</p>
              </article>
              <article>
                <h3>Recommended next action</h3>
                <p>{selected.nextAction}</p>
              </article>
              <article>
                <h3>
                  Raw evidence
                  <Tooltip label="Raw evidence help" text={tooltipRegistry.rawEvidence} />
                </h3>
                <VirtualTable rows={[selected.raw]} columns={Object.keys(selected.raw).slice(0, 8)} pageSize={1} title="Selected raw evidence" />
              </article>
            </div>
          </>
        ) : (
          <p className="empty-state">No issue matches the current filters.</p>
        )}
      </aside>
    </div>
  );
}

function MigrationView({
  dashboard,
  clusters,
  selectedCluster,
  onClusterSelect
}: {
  dashboard: DashboardModel;
  clusters: MigrationCluster[];
  selectedCluster?: MigrationCluster;
  onClusterSelect: (cluster: MigrationCluster) => void;
}) {
  const selected = selectedCluster ?? clusters[0];
  const [drill, setDrill] = useState<EvidenceDrill | null>(null);
  const openEvidence = (
    label: string,
    key: DatasetKey,
    columns = columnsForDataset(key),
    options?: { itemType?: string; columnLabels?: Record<string, string> }
  ) => {
    if (!selected) {
      return;
    }
    const rows = rowsMatchingCluster(selected, dashboard, key).filter((row) => !options?.itemType || row.ItemType === options.itemType);
    setDrill({
      title: `${label} Evidence`,
      subtitle: selected.name,
      rows,
      columns,
      columnLabels: options?.columnLabels,
      backLabel: "Back to migration cluster",
      emptyMessage: "No exported rows matched this cluster with the current identifiers."
    });
  };

  if (drill) {
    return <EvidenceWorkbench drill={drill} onBack={() => setDrill(null)} />;
  }

  const clusterRows = clusters.map((cluster) => ({
    ClusterId: cluster.id,
    Area: cluster.name,
    Owner: cluster.owner,
    "Business Unit": cluster.businessUnit,
    Readiness: cluster.readiness,
    "Review Items": String(cluster.reviewItems),
    Shares: String(cluster.shares),
    Folders: String(cluster.folders),
    Files: String(cluster.files),
    "Permissioned Groups": String(cluster.permissionedGroups)
  }));

  return (
    <div className="split-view">
      <section className="panel list-panel wide-scroll-pane">
        <SectionTitle tooltip={tooltipRegistry.relatedDataArea}>Related Data Area Clusters</SectionTitle>
        <VirtualTable
          rows={clusterRows}
          columns={["Area", "Owner", "Business Unit", "Readiness", "Review Items", "Shares", "Folders", "Files", "Permissioned Groups"]}
          pageSize={12}
          title="Related data area clusters"
          onRowSelect={(row) => {
            const selected = clusters.find((cluster) => cluster.id === row.ClusterId);
            if (selected) {
              onClusterSelect(selected);
            }
          }}
          selectedKey={selected?.id}
          rowKey={(row) => row.ClusterId ?? `${row.Area}-${row.Owner}`}
        />
      </section>
      <section className="panel detail-panel">
        {selected ? (
          <>
            <div className="detail-heading">
              <div>
                <h2>{selected.name}</h2>
                <p>{selected.owner} | {selected.businessUnit}</p>
              </div>
              <StatusBadge value={selected.readiness} />
            </div>
            <div className="stat-grid action-stats" aria-label="Cluster evidence shortcuts">
              <MetricButton label="Shares" value={selected.shares} onClick={() => openEvidence("Shares", "shares", columnsForDataset("shares"))} />
              <MetricButton
                label="Folders"
                value={selected.folders}
                onClick={() =>
                  openEvidence("Folders", "items", ["ItemId", "ShareId", "ItemType", "FullPath", "Depth", "Owner"], {
                    itemType: "Directory",
                    columnLabels: { Depth: "Folder Depth" }
                  })
                }
              />
              <MetricButton
                label="Files"
                value={selected.files}
                onClick={() =>
                  openEvidence("Files", "items", ["ItemId", "ShareId", "ItemType", "FullPath", "Depth", "Owner"], {
                    itemType: "File",
                    columnLabels: { Depth: "Folder Depth" }
                  })
                }
              />
              <MetricButton
                label="Permissioned Groups"
                value={selected.permissionedGroups}
                onClick={() => openEvidence("Permissioned Groups", "permissioned_groups", columnsForDataset("permissioned_groups"))}
              />
            </div>
            <div className="signal-list">
              <h3>
                Why these are related
                <Tooltip label="Related data area help" text={tooltipRegistry.relatedDataArea} />
              </h3>
              {selected.relatedSignals.map((signal) => (
                <button
                  key={signal}
                  type="button"
                  onClick={() =>
                    setDrill({
                      title: "Related Evidence",
                      subtitle: `${selected.name} - ${signal}`,
                      rows: [selected.raw],
                      columns: columnsForDataset("related_data_areas"),
                      backLabel: "Back to migration cluster",
                      emptyMessage: "No related-data evidence row was available."
                    })
                  }
                >
                  {signal}
                </button>
              ))}
            </div>
            <div className="action-box wide">
              <strong>Recommended next action</strong>
              <p>{selected.nextAction}</p>
            </div>
          </>
        ) : (
          <p className="empty-state">No migration clusters match the current filters.</p>
        )}
      </section>
    </div>
  );
}

function GroupsView({
  dashboard,
  groups,
  selectedGroup,
  onGroupSelect
}: {
  dashboard: DashboardModel;
  groups: GroupTreeRow[];
  selectedGroup?: GroupTreeRow;
  onGroupSelect: (group: GroupTreeRow) => void;
}) {
  const selected = selectedGroup ?? groups[0];
  const [drill, setDrill] = useState<EvidenceDrill | null>(null);
  const openGroupEvidence = (label: string, key: DatasetKey, columns = columnsForDataset(key)) => {
    if (!selected) {
      return;
    }
    setDrill({
      title: `${label} Evidence`,
      subtitle: selected.displayName,
      rows: rowsMatchingGroup(selected, dashboard, key),
      columns,
      enableExport: true,
      exportFileName: `sharesurfer-${safeFileToken(label)}-${safeFileToken(selected.group)}.csv`,
      backLabel: "Back to permissioned group",
      emptyMessage: "No exported rows matched this group with the current identifiers."
    });
  };
  const openPathContext = () => {
    if (!selected) {
      return;
    }
    setDrill({
      title: "Example Path Context",
      subtitle: selected.examplePath || selected.fullPath || selected.displayName,
      rows: rowsMatchingPathContext(selected, dashboard),
      columns: ["Evidence", "ShareId", "ItemId", "Identity", "Type", "Rights", "Severity", "Path", "Message"],
      enableExport: true,
      exportFileName: `sharesurfer-example-path-${safeFileToken(selected.group)}.csv`,
      backLabel: "Back to permissioned group",
      emptyMessage: "No exported rows matched this example path or share context."
    });
  };

  if (drill) {
    return <EvidenceWorkbench drill={drill} onBack={() => setDrill(null)} />;
  }

  return (
    <div className="split-view">
      <section className="panel list-panel wide-scroll-pane">
        <SectionTitle tooltip={tooltipRegistry.permissionedGroup}>Permissioned Groups</SectionTitle>
        <VirtualTable
          title="Permissioned groups"
          rows={groups.map((group) => ({
            Group: group.group,
            Members: String(group.expandedMembers),
            Risk: group.riskLevel,
            Rights: group.rights,
            ExamplePath: group.examplePath || group.fullPath,
            OBS: group.obsPath
          }))}
          columns={["Group", "Members", "Risk", "Rights", "ExamplePath", "OBS"]}
          pageSize={14}
          onRowSelect={(_, index) => onGroupSelect(groups[index])}
          rowKey={(_, index) => groups[index]?.group ?? String(index)}
        />
      </section>
      <section className="panel detail-panel">
        {selected ? (
          <>
            <div className="detail-heading">
              <div>
                <h2>{selected.displayName}</h2>
                <p>{selected.group}</p>
              </div>
              <StatusBadge value={selected.riskLevel} />
            </div>
            <div className="warning-stack">
              <div className={`info-banner expansion-status ${selected.hasCycle || selected.isTruncated ? "attention" : ""}`}>
                <strong>{groupExpansionStatus(selected)}</strong>
                <span>
                  ShareSurfer recursively expands nested groups. It marks the result when cycle protection or max-depth protection limits what can be proven.
                </span>
              </div>
              {selected.hasCycle ? <div className="warning-banner">Nested group cycle detected.</div> : null}
              {selected.isTruncated ? <div className="info-banner">Not all members may be visible because expansion was truncated.</div> : null}
            </div>
            <div className="stat-grid action-stats" aria-label="Group evidence shortcuts">
              <MetricButton label="Expanded Members" value={selected.expandedMembers} onClick={() => openGroupEvidence("Expanded Members", "group_edges", columnsForDataset("group_edges"))} />
              <MetricButton label="Share Assignments" value={selected.shareAssignments} onClick={() => openGroupEvidence("Share Assignments", "share_permissions", columnsForDataset("share_permissions"))} />
              <MetricButton label="Folder/File Assignments" value={selected.ntfsAssignments} onClick={() => openGroupEvidence("Folder/File Assignments", "acl_entries", columnsForDataset("acl_entries"))} />
              <MetricButton label="Max Depth" value={selected.maxDepth} onClick={() => openGroupEvidence("Recursive Depth", "group_edges", columnsForDataset("group_edges"))} />
            </div>
            {(selected.examplePath || selected.fullPath) ? (
              <button type="button" className="path-context-button" onClick={openPathContext}>
                <strong>Example Path</strong>
                <span>{selected.examplePath || selected.fullPath}</span>
              </button>
            ) : null}
            <h3>
              Membership Tree
              <Tooltip label="Expanded members help" text={tooltipRegistry.expandedMembers} />
            </h3>
            <div className="tree-list">
              <strong>{selected.group}</strong>
              {selected.children.map((child) => (
                <span key={`${child.ParentGroup}-${child.ChildIdentity}`}>↳ {child.ChildIdentity} ({child.ChildObjectClass || "identity"})</span>
              ))}
              {selected.children.length === 0 ? <span>No expanded members were recorded for this group.</span> : null}
            </div>
          </>
        ) : (
          <p className="empty-state">No groups match the current filters.</p>
        )}
      </section>
    </div>
  );
}

function IdentityView({ dashboard }: { dashboard: DashboardModel }) {
  const [showOrgFields, setShowOrgFields] = useState(true);
  const managerRows = useMemo(
    () => dashboard.identityReviewSignals.managerChains.map(trimManagerDisplayRow),
    [dashboard.identityReviewSignals.managerChains]
  );
  const managerColumns = showOrgFields
    ? ["Identity", "Department", "Title", "Office", "ManagerLevel1", "ManagerLevel2", "ManagerLevel3", "ObsPath"]
    : ["Identity", "ManagerLevel1", "ManagerLevel2", "ManagerLevel3", "ObsPath"];

  return (
    <div className="view-grid">
      <section className="panel wide-scroll-pane">
        <SectionTitle tooltip={tooltipRegistry.potentialServiceAccount}>Potential Service Account Candidates</SectionTitle>
        <p className="panel-copy">These rows are review flags, not proof. Ask the data owner or directory team whether the account is automation or missing directory data.</p>
        <VirtualTable
          rows={dashboard.identityReviewSignals.serviceAccounts}
          columns={["Identity", "DisplayName", "Title", "Company", "AccountEnabled", "reviewLabel"]}
          pageSize={12}
          title="Potential service accounts"
        />
      </section>
      <section className="panel wide-scroll-pane">
        <div className="panel-heading-row">
          <SectionTitle tooltip={tooltipRegistry.managerLevel3}>Manager & OBS Context</SectionTitle>
          <button type="button" className="clear-button" onClick={() => setShowOrgFields((current) => !current)}>
            {showOrgFields ? "Hide org fields" : "Show org fields"}
          </button>
        </div>
        <VirtualTable
          rows={managerRows}
          columns={managerColumns}
          pageSize={14}
          title="Manager chains"
        />
      </section>
    </div>
  );
}

function DiagnosticsView({ snapshot, dashboard }: { snapshot: NormalizedSnapshot; dashboard: DashboardModel }) {
  return (
    <div className="view-grid">
      <section className="panel wide-scroll-pane">
        <SectionTitle tooltip={tooltipRegistry.scanConfidence}>Scan Health</SectionTitle>
        <dl className="stat-grid">
          <div>
            <dt>Report Generated</dt>
            <dd>{formatReportDate(dashboard.scanSummary.generatedAt)}</dd>
          </div>
          <div>
            <dt>Manifest Date</dt>
            <dd>{dashboard.scanSummary.generatedAt || "Unknown"}</dd>
          </div>
          <div>
            <dt>OBS Attribute</dt>
            <dd>{dashboard.scanSummary.obsAttribute || "Not recorded"}</dd>
          </div>
          <div>
            <dt>Source Mode</dt>
            <dd>{dashboard.scanSummary.sourceMode}</dd>
          </div>
          <div>
            <dt>Schema Warnings</dt>
            <dd>{formatNumber(snapshot.schemaWarnings.length)}</dd>
          </div>
        </dl>
      </section>
      <section className="panel wide-scroll-pane">
        <SectionTitle tooltip={tooltipRegistry.collectionError}>Collection Errors</SectionTitle>
        <VirtualTable rows={dashboard.diagnosticSummary.collectionErrors} columns={["ErrorType", "ShareId", "FullPath", "Message"]} pageSize={10} title="Collection errors" />
      </section>
      <section className="panel wide-scroll-pane">
        <SectionTitle tooltip={tooltipRegistry.partialData}>Partial Shares</SectionTitle>
        <VirtualTable rows={dashboard.diagnosticSummary.partialShares} columns={["ShareName", "UNCPath", "PartialReason"]} pageSize={10} title="Partial shares" />
      </section>
      <section className="panel">
        <SectionTitle>Schema Warnings</SectionTitle>
        <ul className="warning-list">
          {snapshot.schemaWarnings.slice(0, 30).map((warning) => (
            <li key={warning}>{warning}</li>
          ))}
          {snapshot.schemaWarnings.length === 0 ? <li>No schema warnings were detected.</li> : null}
        </ul>
      </section>
    </div>
  );
}

function RawEvidenceView({
  dashboard,
  query,
  filters,
  datasetKey,
  onDatasetChange
}: {
  dashboard: DashboardModel;
  query: string;
  filters: FilterState;
  datasetKey: DatasetKey;
  onDatasetChange: (datasetKey: DatasetKey) => void;
}) {
  const [showAllColumns, setShowAllColumns] = useState(false);
  const [selectedRow, setSelectedRow] = useState<DataRow | null>(null);
  const dataset = dashboard.rawEvidenceCatalog.find((entry) => entry.key === datasetKey) ?? dashboard.rawEvidenceCatalog[0];
  const parsedQuery = useMemo(() => parseSearchQuery(query), [query]);
  const rows = dataset.rows.filter((row) => matchesParsedSearch(row, parsedQuery) && matchesBrokenSidMode(rowHasBrokenSid(row), filters.brokenSidMode) && rawRowMatchesTopFilters(row, filters));
  const columns = columnsForDataset(dataset.key, showAllColumns);
  const detailRow = selectedRow ?? rows[0] ?? null;

  return (
    <section className="panel raw-panel wide-scroll-pane">
      <div className="raw-toolbar">
        <SectionTitle tooltip={tooltipRegistry.rawEvidence}>Raw Evidence Explorer</SectionTitle>
        <div className="raw-controls">
          <button type="button" className="clear-button" onClick={() => setShowAllColumns((current) => !current)}>
            {showAllColumns ? "Show curated columns" : "Show all columns"}
          </button>
          <label>
            <span>Dataset</span>
            <select
              value={datasetKey}
              onChange={(event) => {
                setSelectedRow(null);
                onDatasetChange(event.target.value as DatasetKey);
              }}
            >
              {dashboard.rawEvidenceCatalog.map((entry) => (
                <option key={entry.key} value={entry.key}>
                  {entry.label} ({formatNumber(entry.totalRows)})
                </option>
              ))}
            </select>
          </label>
        </div>
      </div>
      <p className="panel-copy">
        Showing {showAllColumns ? "every exported CSV column" : "the review-friendly column set"}. Use field filters to combine exact signals such as share path plus group name, then export the rows currently shown.
      </p>
      <VirtualTable
        rows={rows}
        columns={columns}
        selectableColumns={expectedColumns[dataset.key]}
        pageSize={30}
        title={datasetLabels[dataset.key]}
        enableFieldFilters
        enableExport
        exportFileName={`sharesurfer-${dataset.key}-shown.csv`}
        onRowSelect={(row) => setSelectedRow(row)}
        selectedKey={detailRow ? JSON.stringify(detailRow) : undefined}
        rowKey={(row) => JSON.stringify(row)}
      />
      {detailRow ? (
        <section className="row-detail-panel" aria-label="Selected raw evidence row">
          <h3>Selected row details</h3>
          <dl>
            {expectedColumns[dataset.key].map((column) => (
              <div key={column}>
                <dt>{column}</dt>
                <dd>{detailRow[column] || <span className="muted">blank</span>}</dd>
              </div>
            ))}
          </dl>
        </section>
      ) : null}
    </section>
  );
}

function DashboardApp({ snapshotInput, datasetLabel }: { snapshotInput: RawSnapshot; datasetLabel: string }) {
  const initialState = useMemo(() => loadDashboardState(), []);
  const [activeView, setActiveView] = useState<ViewKey>(initialState.activeView ?? "overview");
  const [filters, setFilters] = useState<FilterState>(initialState.filters ?? defaultFilters);
  const deferredQuery = useDeferredValue(filters.query);
  const snapshot = useMemo(() => normalizeSnapshot(snapshotInput), [snapshotInput]);
  const dashboard = useMemo(() => deriveDashboard(snapshot), [snapshot]);
  const [selectedIssueId, setSelectedIssueId] = useState<string>(initialState.selectedIssueId ?? "");
  const [selectedClusterId, setSelectedClusterId] = useState<string>(initialState.selectedClusterId ?? "");
  const [selectedGroupName, setSelectedGroupName] = useState<string>(initialState.selectedGroupName ?? "");
  const [rawDatasetKey, setRawDatasetKey] = useState<DatasetKey>(initialState.rawDatasetKey ?? "owner_review_packets");
  const [returnTrail, setReturnTrail] = useState<ReturnTrail | null>(initialState.returnTrail ?? null);
  const [sidebarCollapsed, setSidebarCollapsed] = useState(false);
  const [reviewDecisions, setReviewDecisions] = useState<ReviewDecisionMap>(() => loadReviewDecisions());

  const filteredQueue = useMemo(() => filterQueue(dashboard.reviewQueue, filters, deferredQuery), [dashboard.reviewQueue, filters, deferredQuery]);
  const filteredIssues = useMemo(() => filterIssues(dashboard.issueSummaries, filters, deferredQuery), [dashboard.issueSummaries, filters, deferredQuery]);
  const filteredCriticalBlocks = useMemo(() => filterCriticalBlocks(dashboard.criticalScanBlocks, filters, deferredQuery), [dashboard.criticalScanBlocks, filters, deferredQuery]);
  const filteredClusters = useMemo(() => filterClusters(dashboard.migrationClusters, filters, deferredQuery, dashboard), [dashboard, filters, deferredQuery]);
  const filteredGroups = useMemo(() => filterGroups(dashboard.permissionedGroupTree, filters, deferredQuery, dashboard), [dashboard, filters, deferredQuery]);
  const overviewSummary = useMemo(
    () => buildOverviewSummary(dashboard, filteredQueue, filteredIssues, filters, deferredQuery),
    [dashboard, filteredQueue, filteredIssues, filters, deferredQuery]
  );
  const selectedIssue = filteredIssues.find((issue) => issue.id === selectedIssueId) ?? filteredIssues[0];
  const selectedCluster = filteredClusters.find((cluster) => cluster.id === selectedClusterId) ?? filteredClusters[0];
  const selectedGroup = filteredGroups.find((group) => group.group === selectedGroupName) ?? filteredGroups[0];

  useEffect(() => {
    saveDashboardState({
      activeView,
      filters,
      selectedIssueId,
      selectedClusterId,
      selectedGroupName,
      rawDatasetKey,
      returnTrail
    });
  }, [activeView, filters, selectedIssueId, selectedClusterId, selectedGroupName, rawDatasetKey, returnTrail]);

  useEffect(() => {
    saveReviewDecisions(reviewDecisions);
  }, [reviewDecisions]);

  const openView = (view: ViewKey) => {
    setReturnTrail(null);
    setActiveView(view);
  };

  const setIssueReviewDecision = (issue: IssueSummary, decision: ReviewDecisionValue, reviewer: string, note: string) => {
    setReviewDecisions((current) => ({
      ...current,
      [issue.id]: buildReviewDecision(issue, decision, reviewer, note)
    }));
  };

  const updateIssueReviewDecisionContext = (issueId: string, patch: Pick<ReviewDecision, "reviewer" | "note">) => {
    setReviewDecisions((current) => {
      const existing = current[issueId];
      if (!existing) {
        return current;
      }
      return {
        ...current,
        [issueId]: {
          ...existing,
          ...patch,
          updatedAt: new Date().toISOString()
        }
      };
    });
  };

  const clearIssueReviewDecision = (issueId: string) => {
    setReviewDecisions((current) => {
      if (!current[issueId]) {
        return current;
      }
      const next = { ...current };
      delete next[issueId];
      return next;
    });
  };

  const setOwnerContext = (row: ReviewQueueRow) => {
    setFilters({ ...filters, businessUnit: row.businessUnit, owner: row.owner, risk: row.riskLevel });
    setReturnTrail({ from: "overview", label: `Overview / ${row.owner}`, backLabel: "Back to overview" });
    setActiveView("findings");
  };

  const openOverviewDestination = (
    destination: "high-priority" | "access-conflicts" | "partial-shares" | "permissioned-groups" | "service-accounts" | "broken-sids" | "items"
  ) => {
    const labels: Record<typeof destination, string> = {
      "high-priority": "High Priority Items",
      "access-conflicts": "Access Conflicts",
      "partial-shares": "Partial Shares",
      "permissioned-groups": "Permissioned Groups",
      "service-accounts": "Potential Service Accounts",
      "broken-sids": "Broken/Missing SID",
      items: "Items Reviewed"
    };
    setReturnTrail({ from: "overview", label: `Overview / ${labels[destination]}`, backLabel: "Back to overview" });
    if (destination === "partial-shares") {
      setActiveView("diagnostics");
      return;
    }
    if (destination === "permissioned-groups") {
      setActiveView("groups");
      return;
    }
    if (destination === "service-accounts") {
      setActiveView("identity");
      return;
    }
    if (destination === "broken-sids") {
      setFilters({ ...filters, brokenSidMode: "only" });
      setActiveView("findings");
      return;
    }
    if (destination === "items") {
      setRawDatasetKey("items");
      setActiveView("raw");
      return;
    }
    setActiveView("findings");
  };

  const returnToTrailOrigin = () => {
    if (!returnTrail) {
      return;
    }
    setActiveView(returnTrail.from);
    setReturnTrail(null);
  };

  return (
    <div className={`app-shell${sidebarCollapsed ? " sidebar-collapsed" : ""}`}>
      <aside className="sidebar" id="sharesurfer-sidebar" aria-label="ShareSurfer navigation">
        <div className="brand">
          <div className="brand-mark" aria-hidden="true">
            <Workflow size={28} />
          </div>
          <div>
            <strong>ShareSurfer</strong>
            <span>Know what you own. Protect what matters.</span>
          </div>
        </div>
        <nav aria-label="Dashboard views">
          {views.map((view) => (
            <button
              key={view.key}
              type="button"
              className={activeView === view.key ? "active" : ""}
              onClick={() => openView(view.key)}
            >
              {view.icon}
              <span>
                {view.label}
                <small>{view.helper}</small>
              </span>
            </button>
          ))}
        </nav>
        <div className="sidebar-footer">
          <Info size={16} aria-hidden="true" />
          <span>Read-only report. Generated {formatReportDate(dashboard.scanSummary.generatedAt)}</span>
        </div>
      </aside>

      <main>
        <header className="topbar">
          <div className="topbar-title">
            <button
              type="button"
              className="sidebar-toggle"
              onClick={() => setSidebarCollapsed((current) => !current)}
              aria-expanded={!sidebarCollapsed}
              aria-controls="sharesurfer-sidebar"
              aria-label={sidebarCollapsed ? "Show sidebar" : "Hide sidebar"}
              title={sidebarCollapsed ? "Show sidebar" : "Hide sidebar"}
            >
              {sidebarCollapsed ? <PanelLeftOpen size={18} aria-hidden="true" /> : <PanelLeftClose size={18} aria-hidden="true" />}
            </button>
            <div>
              <h1>Permission Review Dashboard</h1>
              <p>
                Generated {formatReportDate(dashboard.scanSummary.generatedAt)} | Source {dashboard.scanSummary.sourceMode} | Read-only
              </p>
            </div>
          </div>
          <div className="topbar-status">
            <StatusBadge value={dashboard.scanSummary.confidenceLabel} />
            <span>{formatNumber(snapshot.rowCounts.acl_entries)} ACL rows</span>
            <span>{formatNumber(snapshot.rowCounts.conflicts)} conflict rows</span>
          </div>
        </header>
        <ReportContextStrip summary={dashboard.scanSummary} datasetLabel={datasetLabel} />

        <FilterBar dashboard={dashboard} filters={filters} onFiltersChange={setFilters} />
        {returnTrail ? <ReturnTrailBar trail={returnTrail} onBack={returnToTrailOrigin} /> : null}

        {activeView === "overview" ? (
          <OverviewView
            dashboard={dashboard}
            summary={overviewSummary}
            filters={filters}
            query={deferredQuery}
            onOpenView={openView}
            onKpiSelect={openOverviewDestination}
            onOwnerSelect={setOwnerContext}
          />
        ) : null}
        {activeView === "findings" ? (
          <FindingsView
            issues={filteredIssues}
            criticalBlocks={filteredCriticalBlocks}
            selectedIssue={selectedIssue}
            reviewDecisions={reviewDecisions}
            onIssueSelect={(issue) => setSelectedIssueId(issue.id)}
            onReviewDecision={setIssueReviewDecision}
            onReviewDecisionContextChange={updateIssueReviewDecisionContext}
            onClearReviewDecision={clearIssueReviewDecision}
            generatedAt={dashboard.scanSummary.generatedAt}
          />
        ) : null}
        {activeView === "migration" ? (
          <MigrationView dashboard={dashboard} clusters={filteredClusters} selectedCluster={selectedCluster} onClusterSelect={(cluster) => setSelectedClusterId(cluster.id)} />
        ) : null}
        {activeView === "groups" ? (
          <GroupsView dashboard={dashboard} groups={filteredGroups} selectedGroup={selectedGroup} onGroupSelect={(group) => setSelectedGroupName(group.group)} />
        ) : null}
        {activeView === "identity" ? <IdentityView dashboard={dashboard} /> : null}
        {activeView === "diagnostics" ? <DiagnosticsView snapshot={snapshot} dashboard={dashboard} /> : null}
        {activeView === "raw" ? <RawEvidenceView dashboard={dashboard} query={deferredQuery} filters={filters} datasetKey={rawDatasetKey} onDatasetChange={setRawDatasetKey} /> : null}
      </main>
    </div>
  );
}

export function App() {
  const [useDemoSnapshot, setUseDemoSnapshot] = useState(false);
  const runtimeState = useMemo(() => getRuntimeSnapshotState(useDemoSnapshot), [useDemoSnapshot]);

  if (runtimeState.status !== "ready" || !runtimeState.snapshot) {
    return <DatasetMissingScreen message={runtimeState.message} onOpenDemo={() => setUseDemoSnapshot(true)} />;
  }

  return <DashboardApp snapshotInput={runtimeState.snapshot} datasetLabel={runtimeState.datasetLabel} />;
}
