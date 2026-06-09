import { startTransition, useDeferredValue, useEffect, useMemo, useState } from "react";
import {
  Activity,
  AlertTriangle,
  ArrowLeft,
  Building2,
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
import { datasetLabels, expectedColumns, tooltipRegistry } from "./data/schema";
import { KpiCard } from "./ui/KpiCard";
import { Tooltip } from "./ui/Tooltip";
import { VirtualTable } from "./ui/VirtualTable";

type ViewKey = "overview" | "findings" | "migration" | "groups" | "identity" | "diagnostics" | "raw";

interface FilterState {
  query: string;
  businessUnit: string;
  owner: string;
  risk: string;
  source: string;
  brokenSidOnly: boolean;
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
}

interface ParsedSearchQuery {
  scoped: ScopedSearchToken[];
  freeText: string[];
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
  backLabel: string;
  emptyMessage: string;
}

type ReviewDecisionValue = "Expected" | "Needs Follow-up";

interface ReviewDecision {
  issueId: string;
  decision: ReviewDecisionValue;
  updatedAt: string;
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
  brokenSidOnly: false
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
  scan_manifest: ["GeneratedAt", "ExportVersion", "SourceMode", "GroupExpansionMaxDepth", "AdLookupMode", "IncludeFiles"]
};

function columnsForDataset(datasetKey: DatasetKey, showAll = false): string[] {
  return showAll ? expectedColumns[datasetKey] : curatedColumns[datasetKey] ?? expectedColumns[datasetKey].slice(0, 8);
}

function formatNumber(value: number): string {
  return new Intl.NumberFormat().format(value);
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
    (candidate.brokenSidOnly === undefined || typeof candidate.brokenSidOnly === "boolean")
  );
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
      filters: isFilterState(parsed.filters) ? { ...defaultFilters, ...parsed.filters } : undefined,
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
    )
  );
}

function loadReviewDecisions(): ReviewDecisionMap {
  try {
    const raw = window.localStorage.getItem(reviewDecisionsStorageKey);
    if (!raw) {
      return {};
    }
    const parsed = JSON.parse(raw) as Record<string, unknown>;
    return Object.fromEntries(Object.entries(parsed).filter(([, value]) => isReviewDecision(value))) as ReviewDecisionMap;
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

function buildReviewDecision(issue: IssueSummary, decision: ReviewDecisionValue): ReviewDecision {
  return {
    issueId: issue.id,
    decision,
    updatedAt: new Date().toISOString(),
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
  const headers = ["IssueId", "Decision", "UpdatedAt", "Title", "Category", "Severity", "Owner", "BusinessUnit", "Path", "Identity", "Source"];
  const rows = decisions
    .slice()
    .sort((a, b) => a.issueId.localeCompare(b.issueId))
    .map((decision) =>
      [
        decision.issueId,
        decision.decision,
        decision.updatedAt,
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

function parseSearchQuery(query: string): ParsedSearchQuery {
  const scoped: ScopedSearchToken[] = [];
  const freeText: string[] = [];
  const terms = query.match(/"[^"]+"|\S+/g) ?? [];

  for (const term of terms) {
    const normalizedTerm = term.replace(/^"|"$/g, "");
    const scopedMatch = normalizedTerm.match(/^([a-z]+):(.+)$/i);
    if (scopedMatch) {
      const scope = scopedMatch[1].toLowerCase() as SearchScope;
      const value = scopedMatch[2].trim();
      if (scope in searchScopeFields && value) {
        scoped.push({ scope, value, normalizedValue: value.toLowerCase() });
        continue;
      }
    }

    if (normalizedTerm.trim()) {
      freeText.push(normalizedTerm.toLowerCase());
    }
  }

  return { scoped, freeText };
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
  if (parsedQuery.scoped.length === 0 && parsedQuery.freeText.length === 0) {
    return true;
  }

  const fullText = objectText(row);
  return (
    parsedQuery.freeText.every((term) => fullText.includes(term)) &&
    parsedQuery.scoped.every((token) => scopedRowText(row, token.scope).includes(token.normalizedValue))
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
    if (row.ShareId && shareIds.has(row.ShareId)) {
      return true;
    }
    const pathText = `${row.FullPath} ${row.UNCPath} ${row.LocalPath}`.toLowerCase();
    return prefixes.some((prefix) => pathText.includes(prefix));
  });
}

function rowsMatchingGroup(group: GroupTreeRow, dashboard: DashboardModel, key: DatasetKey): DataRow[] {
  const groupName = group.group.toLowerCase();
  const shareIds = new Set(splitIds(group.raw.ShareIds || group.raw.ShareId || ""));
  const paths = [group.examplePath, group.fullPath].filter(Boolean).map((path) => path.toLowerCase());
  return datasetRows(dashboard, key).filter((row) => {
    const identityMatch = `${row.Identity} ${row.Group} ${row.ParentGroup}`.toLowerCase().includes(groupName);
    const shareMatch = row.ShareId ? shareIds.has(row.ShareId) : false;
    const rowPath = `${row.FullPath} ${row.ExamplePath} ${row.UNCPath} ${row.LocalPath}`.toLowerCase();
    const pathMatch = paths.some((path) => path !== "" && rowPath.includes(path));
    return identityMatch || shareMatch || pathMatch;
  });
}

function rowsMatchingPathContext(group: GroupTreeRow, dashboard: DashboardModel): DataRow[] {
  const shareIds = new Set(splitIds(group.raw.ShareIds || group.raw.ShareId || ""));
  const paths = [group.examplePath, group.fullPath].filter(Boolean).map((path) => path.toLowerCase());
  const contextRows: DataRow[] = [];
  const keys: DatasetKey[] = ["items", "permissioned_groups", "acl_entries", "share_permissions", "findings", "conflicts", "collection_errors"];

  for (const key of keys) {
    for (const row of datasetRows(dashboard, key)) {
      const shareMatch = row.ShareId ? shareIds.has(row.ShareId) : false;
      const rowPath = `${row.FullPath} ${row.ExamplePath} ${row.UNCPath} ${row.LocalPath}`.toLowerCase();
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
    <button key={label} type="button" className="filter-chip" onClick={onRemove}>
      <span>{label}: {value}</span>
      <span aria-hidden="true">x</span>
    </button>
  );
}

function booleanChip(label: string, active: boolean, onRemove: () => void) {
  if (!active) {
    return null;
  }
  return (
    <button key={label} type="button" className="filter-chip" onClick={onRemove}>
      <span>{label}</span>
      <span aria-hidden="true">x</span>
    </button>
  );
}

function filtersAreClear(filters: FilterState): boolean {
  return !filters.query && !filters.businessUnit && !filters.owner && !filters.risk && !filters.source && !filters.brokenSidOnly;
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
    <section className="panel evidence-workbench">
      <div className="return-trail compact">
        <button type="button" onClick={onBack}>
          <ArrowLeft size={16} aria-hidden="true" />
          {drill.backLabel}
        </button>
        <span>{drill.subtitle}</span>
      </div>
      <SectionTitle tooltip={tooltipRegistry.rawEvidence}>{drill.title}</SectionTitle>
      <VirtualTable rows={drill.rows} columns={drill.columns} columnLabels={drill.columnLabels} pageSize={30} title={drill.title} />
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
  const scopedTokens = parseSearchQuery(filters.query).scoped;

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
      <label className="toggle-filter">
        <input
          type="checkbox"
          checked={filters.brokenSidOnly}
          onChange={(event) => update({ brokenSidOnly: event.target.checked })}
        />
        <span>Broken/Missing SID</span>
      </label>
      <div className="active-context">
        <strong>Active Context</strong>
        <div className="filter-chips">
          {scopedTokens.map((token) => (
            <span key={`${token.scope}:${token.value}`} className="filter-chip search-signal">
              {token.scope}: {token.value}
            </span>
          ))}
          {chip("Search", filters.query, () => update({ query: "" }))}
          {chip("Business Unit", filters.businessUnit, () => update({ businessUnit: "" }))}
          {chip("Owner", filters.owner, () => update({ owner: "" }))}
          {chip("Risk", filters.risk, () => update({ risk: "" }))}
          {chip("Source", filters.source, () => update({ source: "" }))}
          {booleanChip("Broken/Missing SID only", filters.brokenSidOnly, () => update({ brokenSidOnly: false }))}
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
      (!filters.brokenSidOnly || row.category === "Broken/Missing SID" || isBrokenSidIdentity(row.identity)) &&
      (!filters.risk || row.severity.toLowerCase().includes(filters.risk.toLowerCase()) || row.category.toLowerCase().includes(filters.risk.toLowerCase())) &&
      (!filters.owner || row.owner.toLowerCase() === filters.owner.toLowerCase()) &&
      (!filters.businessUnit || row.businessUnit.toLowerCase() === filters.businessUnit.toLowerCase()) &&
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

function filterClusters(rows: MigrationCluster[], filters: FilterState, query: string) {
  const parsedQuery = parseSearchQuery(query);
  return rows.filter(
    (row) =>
      matchesText(row.businessUnit, filters.businessUnit) &&
      matchesText(row.owner, filters.owner) &&
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

function filterGroups(rows: GroupTreeRow[], filters: FilterState, query: string) {
  const parsedQuery = parseSearchQuery(query);
  return rows.filter(
    (row) =>
      (!filters.risk || row.riskLevel.toLowerCase().includes(filters.risk.toLowerCase())) &&
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
          ChildIdentity: row.children.map((child) => child.ChildIdentity).join(" ")
        },
        parsedQuery
      )
  );
}

function filterCriticalBlocks(rows: CriticalScanBlock[], filters: FilterState, query: string) {
  const parsedQuery = parseSearchQuery(query);
  return rows.filter(
    (row) =>
      (!filters.risk || row.Severity.toLowerCase().includes(filters.risk.toLowerCase()) || row.ErrorType.toLowerCase().includes(filters.risk.toLowerCase())) &&
      matchesParsedSearch(row, parsedQuery)
  );
}

function hasActiveContext(filters: FilterState, query: string): boolean {
  return Boolean(query || filters.businessUnit || filters.owner || filters.risk || filters.source || filters.brokenSidOnly);
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

      <section className="panel queue-panel">
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

      <section className="panel workbench-panel">
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
      <section className="panel workbench-panel">
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
  onClearReviewDecision
}: {
  issues: IssueSummary[];
  criticalBlocks: CriticalScanBlock[];
  selectedIssue?: IssueSummary;
  onIssueSelect: (issue: IssueSummary) => void;
  reviewDecisions: ReviewDecisionMap;
  onReviewDecision: (issue: IssueSummary, decision: ReviewDecisionValue) => void;
  onClearReviewDecision: (issueId: string) => void;
}) {
  const [categoryFilter, setCategoryFilter] = useState("");
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
  const selected = selectedIssue && visibleIssues.some((issue) => issue.id === selectedIssue.id) ? selectedIssue : visibleIssues[0];
  const issueIds = new Set(issues.map((issue) => issue.id));
  const scopedReviewDecisions = Object.values(reviewDecisions).filter((decision) => issueIds.has(decision.issueId));
  const selectedReviewDecision = selected ? reviewDecisions[selected.id] : undefined;
  const rows = visibleIssues.map((issue) => ({
    IssueId: issue.id,
    Category: issue.category,
    Severity: issue.severity,
    Title: issue.title,
    Identity: issue.identity,
    Path: issue.path
  }));

  return (
    <div className="split-view">
      <section className="panel">
        <SectionTitle tooltip={tooltipRegistry.fileFolderPermissions}>Findings & Conflicts</SectionTitle>
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
              <div className="review-decision-actions">
                <button type="button" className="link-button" onClick={() => onReviewDecision(selected, "Expected")}>
                  Mark Expected
                </button>
                <button type="button" className="link-button" onClick={() => onReviewDecision(selected, "Needs Follow-up")}>
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
      <section className="panel list-panel">
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
      backLabel: "Back to permissioned group",
      emptyMessage: "No exported rows matched this example path or share context."
    });
  };

  if (drill) {
    return <EvidenceWorkbench drill={drill} onBack={() => setDrill(null)} />;
  }

  return (
    <div className="split-view">
      <section className="panel list-panel">
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
                <span key={`${child.ParentGroup}-${child.ChildIdentity}`}>{"->"} {child.ChildIdentity} ({child.ChildObjectClass || "identity"})</span>
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
  const managerColumns = showOrgFields
    ? ["Identity", "Department", "Title", "Office", "ManagerLevel1", "ManagerLevel2", "ManagerLevel3", "ObsPath"]
    : ["Identity", "ManagerLevel1", "ManagerLevel2", "ManagerLevel3", "ObsPath"];

  return (
    <div className="view-grid">
      <section className="panel">
        <SectionTitle tooltip={tooltipRegistry.potentialServiceAccount}>Potential Service Account Candidates</SectionTitle>
        <p className="panel-copy">These rows are review flags, not proof. Ask the data owner or directory team whether the account is automation or missing directory data.</p>
        <VirtualTable
          rows={dashboard.identityReviewSignals.serviceAccounts}
          columns={["Identity", "DisplayName", "Title", "Company", "AccountEnabled", "reviewLabel"]}
          pageSize={12}
          title="Potential service accounts"
        />
      </section>
      <section className="panel">
        <div className="panel-heading-row">
          <SectionTitle tooltip={tooltipRegistry.managerLevel3}>Manager & OBS Context</SectionTitle>
          <button type="button" className="clear-button" onClick={() => setShowOrgFields((current) => !current)}>
            {showOrgFields ? "Hide org fields" : "Show org fields"}
          </button>
        </div>
        <VirtualTable
          rows={dashboard.identityReviewSignals.managerChains}
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
      <section className="panel">
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
      <section className="panel">
        <SectionTitle tooltip={tooltipRegistry.collectionError}>Collection Errors</SectionTitle>
        <VirtualTable rows={dashboard.diagnosticSummary.collectionErrors} columns={["ErrorType", "ShareId", "FullPath", "Message"]} pageSize={10} title="Collection errors" />
      </section>
      <section className="panel">
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
  const rows = dataset.rows.filter((row) => matchesParsedSearch(row, parsedQuery) && (!filters.brokenSidOnly || rowHasBrokenSid(row)));
  const columns = columnsForDataset(dataset.key, showAllColumns);
  const detailRow = selectedRow ?? rows[0] ?? null;

  return (
    <section className="panel raw-panel">
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
        Showing {showAllColumns ? "every exported CSV column" : "the review-friendly column set"}. Use show all when you need exact source fields.
      </p>
      <VirtualTable
        rows={rows}
        columns={columns}
        pageSize={30}
        title={datasetLabels[dataset.key]}
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
  const filteredClusters = useMemo(() => filterClusters(dashboard.migrationClusters, filters, deferredQuery), [dashboard.migrationClusters, filters, deferredQuery]);
  const filteredGroups = useMemo(() => filterGroups(dashboard.permissionedGroupTree, filters, deferredQuery), [dashboard.permissionedGroupTree, filters, deferredQuery]);
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

  const setIssueReviewDecision = (issue: IssueSummary, decision: ReviewDecisionValue) => {
    setReviewDecisions((current) => ({
      ...current,
      [issue.id]: buildReviewDecision(issue, decision)
    }));
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
      setFilters({ ...filters, brokenSidOnly: true });
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
                Generated {formatReportDate(dashboard.scanSummary.generatedAt)} | Source {dashboard.scanSummary.sourceMode} | Read-only | {datasetLabel}
              </p>
            </div>
          </div>
          <div className="topbar-status">
            <StatusBadge value={dashboard.scanSummary.confidenceLabel} />
            <span>{formatNumber(snapshot.rowCounts.acl_entries)} ACL rows</span>
            <span>{formatNumber(snapshot.rowCounts.conflicts)} conflict rows</span>
          </div>
        </header>

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
            onClearReviewDecision={clearIssueReviewDecision}
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
