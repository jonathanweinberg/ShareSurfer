import { fireEvent, render, screen, within } from "@testing-library/react";
import { beforeEach, describe, expect, test } from "vitest";
import { App } from "./App";
import { demoSnapshot } from "./data/fixtures";

function renderWithDemoSnapshot() {
  window.__SHARESURFER_SNAPSHOT__ = demoSnapshot;
  return render(<App />);
}

function renderWithBrokenSidSnapshot() {
  const snapshot = JSON.parse(JSON.stringify(demoSnapshot)) as typeof demoSnapshot;
  snapshot.datasets?.findings?.push({
    FindingId: "finding-broken-sid",
    FindingType: "BrokenOrMissingSid",
    Severity: "High",
    ShareId: "share-finance",
    ItemId: "item-finance",
    FullPath: "\\\\files01\\Finance",
    Identity: "S-1-5-21-1000-2000-3000-4040",
    ObservedValue: "S-1-5-21-1000-2000-3000-4040",
    PolicyValue: "Resolvable identity",
    Message: "Permission references a SID or account name that could not be resolved."
  });
  snapshot.datasets?.related_data_areas?.push({
    RelatedAreaId: "related-hr",
    RelatedDataArea: "HR / Employee Records",
    BusinessUnit: "HR",
    Owner: "HR Operations",
    Pattern: "\\\\files01\\HR*",
    Source: "demo",
    RiskLevel: "Review",
    MigrationReadiness: "Review",
    MatchingShares: "1",
    MatchingItems: "1",
    Directories: "1",
    Files: "0",
    FindingCount: "0",
    ConflictCount: "0",
    ReviewItemCount: "0",
    PartialShareCount: "1",
    DirectIdentityCount: "1",
    DirectGroupCount: "1",
    ExpandedMemberCount: "1",
    RelatedBecause: "same owner mapping; matching path pattern",
    SuggestedNextAction: "Confirm HR ownership before migration."
  });
  snapshot.datasets?.permissioned_groups?.push({
    Group: "CONTOSO\\HRReaders",
    DisplayName: "HR Readers",
    ObjectClass: "group",
    ObsPath: "CORP.HR",
    ManagerLevel1: "",
    ShareAssignments: "1",
    NtfsAssignments: "0",
    ExpandedMembers: "1",
    MaxDepth: "1",
    HasCycle: "False",
    IsTruncated: "False",
    Rights: "Read",
    ShareId: "share-hr",
    ShareIds: "share-hr",
    Sources: "Share",
    FullPath: "\\\\files01\\HR",
    ExamplePath: "\\\\files01\\HR"
  });
  window.__SHARESURFER_SNAPSHOT__ = snapshot;
  return render(<App />);
}

function renderWithEmployeePrefixSnapshot() {
  const snapshot = JSON.parse(JSON.stringify(demoSnapshot)) as typeof demoSnapshot;
  snapshot.datasets?.findings?.push({
    FindingId: "finding-employee-prefix",
    FindingType: "DeepExplicitAce",
    Severity: "High",
    ShareId: "share-finance",
    ItemId: "item-payroll",
    FullPath: "\\\\files01\\Finance\\Payroll",
    Identity: "CONTOSO\\Ava.Accounting",
    ObservedValue: "3",
    PolicyValue: "2",
    Message: "Explicit permissions were introduced deeper than the configured review threshold."
  });
  window.__SHARESURFER_SNAPSHOT__ = snapshot;
  return render(<App />);
}

function ensureLocalStorage() {
  if (window.localStorage) {
    return;
  }

  const store = new Map<string, string>();
  Object.defineProperty(window, "localStorage", {
    configurable: true,
    value: {
      clear: () => store.clear(),
      getItem: (key: string) => store.get(key) ?? null,
      removeItem: (key: string) => store.delete(key),
      setItem: (key: string, value: string) => store.set(key, value)
    }
  });
}

describe("dashboard workbench interactions", () => {
  beforeEach(() => {
    ensureLocalStorage();
    delete window.__SHARESURFER_SNAPSHOT__;
    window.sessionStorage.clear();
    window.localStorage.clear();
  });

  test("missing runtime data shows an onboarding screen instead of silently rendering demo rows", () => {
    render(<App />);

    expect(screen.getByRole("heading", { name: /No ShareSurfer dataset found/i })).toBeInTheDocument();
    expect(screen.getByText(/Expected sharesurfer-data\.js/i)).toBeInTheDocument();
    expect(screen.queryByRole("heading", { name: /Permission Review Dashboard/i })).not.toBeInTheDocument();
  });

  test("template dashboard assets require a real export or an explicit demo choice", () => {
    window.__SHARESURFER_SNAPSHOT__ = {
      snapshotKind: "template",
      generatedAt: "2026-06-09T00:00:00Z",
      datasets: {}
    } as typeof demoSnapshot;

    render(<App />);

    expect(screen.getByRole("heading", { name: /No ShareSurfer dataset found/i })).toBeInTheDocument();

    fireEvent.click(screen.getByRole("button", { name: /Open demo dataset/i }));

    expect(screen.getByRole("heading", { name: /Permission Review Dashboard/i })).toBeInTheDocument();
    expect(screen.getByText(/Demo dataset/i)).toBeInTheDocument();
  });

  test("active filters scope overview KPI cards instead of leaving global totals", () => {
    renderWithDemoSnapshot();

    expect(screen.getByRole("button", { name: "Open Access Conflicts" })).toHaveTextContent("1");

    fireEvent.change(screen.getByLabelText(/Review Risk/i), { target: { value: "Warning" } });

    expect(screen.getByRole("button", { name: "Open Access Conflicts" })).toHaveTextContent("0");
    expect(screen.getByRole("button", { name: "Open Items Reviewed" })).toHaveTextContent("0");
  });

  test("overview KPI cards open real destinations with a return path", () => {
    renderWithDemoSnapshot();

    fireEvent.click(screen.getByRole("button", { name: "Open Access Conflicts" }));

    expect(screen.getByRole("heading", { name: /Findings & Conflicts/i })).toBeInTheDocument();
    expect(screen.getByText("Overview / Access Conflicts")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: /Back to overview/i })).toBeInTheDocument();
  });

  test("report date context is prominent in the header and findings review", () => {
    renderWithDemoSnapshot();

    const reportContext = screen.getByLabelText(/Report context/i);
    expect(within(reportContext).getByText("Report generated")).toBeInTheDocument();
    expect(within(reportContext).getByText(/Jun 5, 2026/i)).toBeInTheDocument();
    expect(within(reportContext).getByText("Source mode")).toBeInTheDocument();
    expect(within(reportContext).getByText("OBS attribute")).toBeInTheDocument();

    const nav = screen.getByRole("navigation", { name: /Dashboard views/i });
    fireEvent.click(within(nav).getByRole("button", { name: /Findings/i }));

    const findingsContext = screen.getByLabelText(/Findings report context/i);
    expect(within(findingsContext).getByText(/Findings use evidence generated Jun 5, 2026/i)).toBeInTheDocument();
  });

  test("overview includes first-run glossary terms for confusing review signals", () => {
    renderWithDemoSnapshot();

    const glossary = screen.getByRole("region", { name: /Key terms/i });

    expect(within(glossary).getByText("Owner")).toBeInTheDocument();
    expect(within(glossary).getByText("No owner")).toBeInTheDocument();
    expect(within(glossary).getByText("Broken/Missing SID")).toBeInTheDocument();
    expect(within(glossary).getByText("Collection error")).toBeInTheDocument();
    expect(within(glossary).getByText("Partial data")).toBeInTheDocument();
    expect(within(glossary).getByText("Discounted access principal")).toBeInTheDocument();
    expect(within(glossary).getByText("Critical scan information block")).toBeInTheDocument();
    expect(within(glossary).getByText(/business reviewer or data owner/i)).toBeInTheDocument();
    expect(within(glossary).getByText(/not the same thing as approval/i)).toBeInTheDocument();
  });

  test("sidebar can be hidden to give review panes more horizontal space", () => {
    const view = renderWithDemoSnapshot();

    fireEvent.click(screen.getByRole("button", { name: /Hide sidebar/i }));

    expect(view.container.querySelector(".app-shell")).toHaveClass("sidebar-collapsed");
    expect(screen.getByRole("button", { name: /Show sidebar/i })).toHaveAttribute("aria-expanded", "false");
  });

  test("table-heavy review panes use the full main viewport width", () => {
    const view = renderWithDemoSnapshot();
    const nav = screen.getByRole("navigation", { name: /Dashboard views/i });

    expect(screen.getByRole("table", { name: /What needs review first/i }).closest(".wide-scroll-pane")).toBeInTheDocument();

    fireEvent.click(within(nav).getByRole("button", { name: /Findings/i }));
    expect(screen.getByRole("table", { name: /Findings and conflicts/i }).closest(".wide-scroll-pane")).toBeInTheDocument();

    fireEvent.click(within(nav).getByRole("button", { name: /Migration/i }));
    expect(screen.getByRole("table", { name: /Related data area clusters/i }).closest(".wide-scroll-pane")).toBeInTheDocument();
    fireEvent.click(screen.getByRole("button", { name: /Shares 1/i }));
    expect(screen.getByRole("table", { name: /Shares Evidence/i }).closest(".evidence-workbench")).toHaveClass("wide-scroll-pane");

    fireEvent.click(screen.getByRole("button", { name: /Back to migration cluster/i }));
    fireEvent.click(within(nav).getByRole("button", { name: /Groups/i }));
    expect(screen.getByRole("table", { name: /Permissioned groups/i }).closest(".wide-scroll-pane")).toBeInTheDocument();

    fireEvent.click(within(nav).getByRole("button", { name: /Identity/i }));
    expect(screen.getByRole("table", { name: /Manager chains/i }).closest(".wide-scroll-pane")).toBeInTheDocument();

    fireEvent.click(within(nav).getByRole("button", { name: /Diagnostics/i }));
    expect(screen.getByRole("table", { name: /Collection errors/i }).closest(".wide-scroll-pane")).toBeInTheDocument();

    fireEvent.click(screen.getByRole("button", { name: /Raw Evidence/i }));
    expect(view.container.querySelector(".raw-panel")).toHaveClass("wide-scroll-pane");
  });

  test("overview review queue is filterable and still opens owner context", () => {
    renderWithDemoSnapshot();

    const table = screen.getByRole("table", { name: /What needs review first/i });
    expect(within(table).getByText("Finance Operations")).toBeInTheDocument();

    fireEvent.change(screen.getByLabelText(/Filter What needs review first rows/i), { target: { value: "not-a-real-owner" } });
    expect(within(table).getByText(/No rows match the current view/i)).toBeInTheDocument();

    fireEvent.change(screen.getByLabelText(/Filter What needs review first rows/i), { target: { value: "Finance" } });
    fireEvent.click(within(table).getByRole("row", { name: /Finance Operations/i }));

    expect(screen.getByRole("heading", { name: /Findings & Conflicts/i })).toBeInTheDocument();
    expect(screen.getByText("Overview / Finance Operations")).toBeInTheDocument();
  });

  test("findings rollups are clickable filters for the issue table", () => {
    renderWithDemoSnapshot();

    const nav = screen.getByRole("navigation", { name: /Dashboard views/i });
    fireEvent.click(within(nav).getByRole("button", { name: /Findings/i }));
    fireEvent.click(screen.getByRole("button", { name: /Filter findings by Deep Custom Permission/i }));

    const table = screen.getByRole("table", { name: /Findings and conflicts/i });
    const rows = within(table).getAllByRole("row");
    expect(rows).toHaveLength(2);
    expect(rows[1]).toHaveTextContent("Deep Custom Permission");
    expect(within(table).queryByText("Inheritance Stopped")).not.toBeInTheDocument();
  });

  test("finding review decisions persist locally and can be cleared", () => {
    const firstRender = renderWithDemoSnapshot();

    const nav = screen.getByRole("navigation", { name: /Dashboard views/i });
    fireEvent.click(within(nav).getByRole("button", { name: /Findings/i }));
    fireEvent.change(screen.getByLabelText(/Reviewer/i), { target: { value: "J. Weinberg" } });
    fireEvent.change(screen.getByLabelText(/Review note/i), { target: { value: "Known exception for migration freeze." } });
    fireEvent.click(screen.getByRole("button", { name: /Mark Expected/i }));

    expect(screen.getByText(/Decision: Expected/i)).toBeInTheDocument();
    expect(screen.getByText(/1 of 4 reviewed/i)).toBeInTheDocument();
    expect(window.localStorage.getItem("sharesurfer.reviewDecisions.v1")).toContain("Expected");
    expect(window.localStorage.getItem("sharesurfer.reviewDecisions.v1")).toContain("J. Weinberg");
    expect(window.localStorage.getItem("sharesurfer.reviewDecisions.v1")).toContain("Known exception");

    firstRender.unmount();
    renderWithDemoSnapshot();

    expect(screen.getByRole("heading", { name: /Findings & Conflicts/i })).toBeInTheDocument();
    expect(screen.getByText(/Decision: Expected/i)).toBeInTheDocument();
    expect(screen.getByLabelText(/Reviewer/i)).toHaveValue("J. Weinberg");
    expect(screen.getByLabelText(/Review note/i)).toHaveValue("Known exception for migration freeze.");
    expect(screen.getByText(/1 of 4 reviewed/i)).toBeInTheDocument();

    fireEvent.click(screen.getByRole("button", { name: /Clear decision/i }));

    expect(screen.getByText(/No decision recorded/i)).toBeInTheDocument();
    expect(screen.getByText(/0 of 4 reviewed/i)).toBeInTheDocument();
    expect(window.localStorage.getItem("sharesurfer.reviewDecisions.v1")).toBeNull();
  });

  test("finding review decisions can be exported as a local csv", () => {
    renderWithDemoSnapshot();

    const nav = screen.getByRole("navigation", { name: /Dashboard views/i });
    fireEvent.click(within(nav).getByRole("button", { name: /Findings/i }));
    fireEvent.change(screen.getByLabelText(/Reviewer/i), { target: { value: "Ava Reviewer" } });
    fireEvent.change(screen.getByLabelText(/Review note/i), { target: { value: "Known broad access, verify after migration." } });
    fireEvent.click(screen.getByRole("button", { name: /Mark Needs Follow-up/i }));

    const exportLink = screen.getByRole("link", { name: /Export review decisions/i });
    const href = decodeURIComponent(exportLink.getAttribute("href") ?? "");

    expect(exportLink).toHaveAttribute("download", "review-decisions.csv");
    expect(href).toContain("IssueId,Decision,UpdatedAt,Reviewer,Note,Title,Category,Severity,Owner,BusinessUnit,Path,Identity,Source");
    expect(href).toContain("Needs Follow-up");
    expect(href).toContain("Ava Reviewer");
    expect(href).toContain("Known broad access");
  });

  test("migration metrics drill into evidence rows and can return to the cluster", () => {
    renderWithDemoSnapshot();

    fireEvent.click(screen.getByRole("button", { name: /Migration/i }));
    fireEvent.click(screen.getByRole("button", { name: /Shares 1/i }));

    expect(screen.getByRole("heading", { name: /Shares Evidence/i })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: /Back to migration cluster/i })).toBeInTheDocument();
    expect(screen.getByText(/Finance \/ Accounts Payable/i)).toBeInTheDocument();
  });

  test("migration cluster selector has local row filtering", () => {
    renderWithDemoSnapshot();

    fireEvent.click(screen.getByRole("button", { name: /Migration/i }));
    const table = screen.getByRole("table", { name: /Related data area clusters/i });

    fireEvent.change(screen.getByLabelText(/Filter Related data area clusters rows/i), { target: { value: "not-a-real-cluster" } });
    expect(within(table).getByText(/No rows match the current view/i)).toBeInTheDocument();

    fireEvent.change(screen.getByLabelText(/Filter Related data area clusters rows/i), { target: { value: "Finance" } });
    expect(within(table).getByText("Finance / Accounts Payable")).toBeInTheDocument();
  });

  test("file and folder evidence explains depth in reviewer language", () => {
    renderWithDemoSnapshot();

    fireEvent.click(screen.getByRole("button", { name: /Migration/i }));
    fireEvent.click(screen.getByRole("button", { name: /Files 0/i }));

    expect(screen.getByRole("columnheader", { name: "Folder Depth" })).toBeInTheDocument();
  });

  test("identity workbench can hide low-value org columns while exploring manager routing", () => {
    renderWithDemoSnapshot();

    fireEvent.click(screen.getByRole("button", { name: /Identity/i }));
    expect(screen.getByRole("columnheader", { name: "Department" })).toBeInTheDocument();
    expect(screen.getByText("morgan.manager@example.test")).toBeInTheDocument();
    expect(screen.queryByText("mailto:morgan.manager@example.test")).not.toBeInTheDocument();

    fireEvent.click(screen.getByRole("button", { name: /Hide org fields/i }));

    expect(screen.queryByRole("columnheader", { name: "Department" })).not.toBeInTheDocument();
    expect(screen.getByRole("columnheader", { name: "Manager Level1" })).toBeInTheDocument();
  });

  test("permissioned group review keeps groups visible when filtering by example path", () => {
    renderWithDemoSnapshot();

    const nav = screen.getByRole("navigation", { name: /Dashboard views/i });
    fireEvent.click(within(nav).getByRole("button", { name: /Groups/i }));
    fireEvent.change(screen.getByRole("searchbox", { name: /Search dashboard/i }), { target: { value: "path:Finance" } });

    const table = screen.getByRole("table", { name: /Permissioned groups/i });
    expect(within(table).getByText("CONTOSO\\FinanceReaders")).toBeInTheDocument();
  });

  test("group permission review honors top business filters", () => {
    renderWithBrokenSidSnapshot();

    const nav = screen.getByRole("navigation", { name: /Dashboard views/i });
    fireEvent.click(within(nav).getByRole("button", { name: /Groups/i }));

    let table = screen.getByRole("table", { name: /Permissioned groups/i });
    expect(within(table).getByText("CONTOSO\\FinanceReaders")).toBeInTheDocument();
    expect(within(table).getByText("CONTOSO\\HRReaders")).toBeInTheDocument();

    fireEvent.change(screen.getByLabelText(/Business Unit/i), { target: { value: "Finance" } });

    table = screen.getByRole("table", { name: /Permissioned groups/i });
    expect(within(table).getByText("CONTOSO\\FinanceReaders")).toBeInTheDocument();
    expect(within(table).queryByText("CONTOSO\\HRReaders")).not.toBeInTheDocument();

    fireEvent.change(screen.getAllByLabelText(/Business Unit/i)[0], { target: { value: "HR" } });

    table = screen.getByRole("table", { name: /Permissioned groups/i });
    expect(within(table).queryByText("CONTOSO\\FinanceReaders")).not.toBeInTheDocument();
    expect(within(table).getByText("CONTOSO\\HRReaders")).toBeInTheDocument();
  });

  test("group folder and file assignments open a filtered exportable evidence pane", () => {
    renderWithDemoSnapshot();

    const nav = screen.getByRole("navigation", { name: /Dashboard views/i });
    fireEvent.click(within(nav).getByRole("button", { name: /Groups/i }));
    fireEvent.click(screen.getByRole("button", { name: /Folder\/File Assignments 2/i }));

    expect(screen.getByRole("heading", { name: /Folder\/File Assignments Evidence/i })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: /Back to permissioned group/i })).toBeInTheDocument();
    const exportLink = screen.getByRole("link", { name: /Export shown CSV/i });
    const href = decodeURIComponent(exportLink.getAttribute("href") ?? "");
    expect(exportLink).toHaveAttribute("download", "sharesurfer-folder-file-assignments-contoso-financereaders.csv");
    expect(href).toContain("CONTOSO\\FinanceReaders");
    expect(href).toContain("\\\\files01\\Finance");
  });

  test("scoped search chips remove individual signals without duplicating search context", () => {
    renderWithDemoSnapshot();

    const search = screen.getByRole("searchbox", { name: /Search dashboard/i });
    fireEvent.change(search, { target: { value: "owner:Finance path:Payroll broad access" } });

    const activeContext = screen.getByText("Active Context").closest(".active-context");
    expect(activeContext).not.toBeNull();
    const context = within(activeContext as HTMLElement);

    expect(context.getByRole("button", { name: /Remove owner search Finance/i })).toBeInTheDocument();
    expect(context.getByRole("button", { name: /Remove path search Payroll/i })).toBeInTheDocument();
    expect(context.getByText("Search: broad access")).toBeInTheDocument();
    expect(context.queryByText("Search: owner:Finance path:Payroll broad access")).not.toBeInTheDocument();

    fireEvent.click(context.getByRole("button", { name: /Remove owner search Finance/i }));

    expect(search).toHaveValue("path:Payroll broad access");
    expect(context.queryByRole("button", { name: /Remove owner search Finance/i })).not.toBeInTheDocument();
    expect(context.getByRole("button", { name: /Remove path search Payroll/i })).toBeInTheDocument();
    expect(context.getByText("Search: broad access")).toBeInTheDocument();

    fireEvent.change(search, { target: { value: "owner:Finance path:Payroll" } });

    expect(context.queryByText(/Search:/)).not.toBeInTheDocument();
    expect(context.getByRole("button", { name: /Remove owner search Finance/i })).toBeInTheDocument();
    expect(context.getByRole("button", { name: /Remove path search Payroll/i })).toBeInTheDocument();
  });

  test("Broken/Missing SID toggle scopes migration and group views to related rows", () => {
    renderWithBrokenSidSnapshot();

    const nav = screen.getByRole("navigation", { name: /Dashboard views/i });

    fireEvent.click(within(nav).getByRole("button", { name: /Migration/i }));
    const initialMigrationTable = screen.getByRole("table", { name: /Related data area clusters/i });
    expect(within(initialMigrationTable).getByText("Finance / Accounts Payable")).toBeInTheDocument();
    expect(within(initialMigrationTable).getByText("HR / Employee Records")).toBeInTheDocument();

    fireEvent.click(screen.getByLabelText(/Show only Broken\/Missing SIDs/i));

    const migrationTable = screen.getByRole("table", { name: /Related data area clusters/i });
    expect(within(migrationTable).getByText("Finance / Accounts Payable")).toBeInTheDocument();
    expect(within(migrationTable).queryByText("HR / Employee Records")).not.toBeInTheDocument();
    expect(screen.getByLabelText(/Show only Broken\/Missing SIDs/i)).toBeChecked();
    expect(screen.getByLabelText(/Hide Broken\/Missing SIDs/i)).not.toBeChecked();

    fireEvent.click(screen.getByLabelText(/Hide Broken\/Missing SIDs/i));

    expect(screen.getByLabelText(/Show only Broken\/Missing SIDs/i)).not.toBeChecked();
    expect(screen.getByLabelText(/Hide Broken\/Missing SIDs/i)).toBeChecked();

    fireEvent.click(within(nav).getByRole("button", { name: /Groups/i }));

    const groupsTable = screen.getByRole("table", { name: /Permissioned groups/i });
    expect(within(groupsTable).queryByText("CONTOSO\\FinanceReaders")).not.toBeInTheDocument();
    expect(within(groupsTable).getByText("CONTOSO\\HRReaders")).toBeInTheDocument();
  });

  test("raw evidence uses readable curated columns before showing all CSV fields", () => {
    renderWithDemoSnapshot();

    fireEvent.click(screen.getByRole("button", { name: /Raw Evidence/i }));

    const table = screen.getByRole("table", { name: /Review packets/i });
    expect(within(table).getByRole("columnheader", { name: "Why Review" })).toBeInTheDocument();
    expect(within(table).queryByRole("columnheader", { name: "ReviewPacketId" })).not.toBeInTheDocument();

    fireEvent.click(screen.getByRole("button", { name: /Show all columns/i }));
    expect(within(table).getByRole("columnheader", { name: "Review Packet Id" })).toBeInTheDocument();
  });

  test("raw evidence rows can be opened as vertical details without horizontal scrolling", () => {
    renderWithDemoSnapshot();

    fireEvent.click(screen.getByRole("button", { name: /Raw Evidence/i }));
    fireEvent.click(screen.getByRole("row", { name: /Finance Operations/i }));

    expect(screen.getByRole("heading", { name: /Selected row details/i })).toBeInTheDocument();
    expect(screen.getByText("ReviewPacketId")).toBeInTheDocument();
    expect(screen.getByText("owner-review-finance")).toBeInTheDocument();
  });

  test("raw evidence combines field filters and exports the shown csv", () => {
    renderWithDemoSnapshot();

    fireEvent.click(screen.getByRole("button", { name: /Raw Evidence/i }));
    fireEvent.change(screen.getByLabelText(/Dataset/i), { target: { value: "share_permissions" } });
    fireEvent.change(screen.getByLabelText(/Filter Share-level access by Share Id/i), { target: { value: "share-finance" } });
    fireEvent.change(screen.getByLabelText(/Filter Share-level access by Identity/i), { target: { value: "FinanceReaders" } });

    const table = screen.getByRole("table", { name: /Share-level access/i });
    expect(within(table).getByText("CONTOSO\\FinanceReaders")).toBeInTheDocument();
    expect(within(table).queryByText("Everyone")).not.toBeInTheDocument();

    const exportLink = screen.getByRole("link", { name: /Export shown CSV/i });
    const href = decodeURIComponent(exportLink.getAttribute("href") ?? "");
    expect(exportLink).toHaveAttribute("download", "sharesurfer-share_permissions-shown.csv");
    expect(href).toContain("CONTOSO\\FinanceReaders");
    expect(href).not.toContain("Everyone");
  });

  test("raw evidence accepts negative field filters", () => {
    renderWithDemoSnapshot();

    fireEvent.click(screen.getByRole("button", { name: /Raw Evidence/i }));
    fireEvent.change(screen.getByLabelText(/Dataset/i), { target: { value: "share_permissions" } });
    fireEvent.change(screen.getByLabelText(/Filter Share-level access by Identity/i), { target: { value: "-Everyone" } });

    const table = screen.getByRole("table", { name: /Share-level access/i });
    expect(within(table).getByText("CONTOSO\\FinanceReaders")).toBeInTheDocument();
    expect(within(table).queryByText("Everyone")).not.toBeInTheDocument();
  });

  test("ports and protocols view shows collector and target readiness evidence", () => {
    renderWithDemoSnapshot();

    const nav = screen.getByRole("navigation", { name: /Dashboard views/i });
    fireEvent.click(within(nav).getByRole("button", { name: /Ports & Protocols/i }));

    expect(screen.getByRole("heading", { name: /Ports & Protocols/i })).toBeInTheDocument();
    expect(screen.getByText("COLLECTOR01")).toBeInTheDocument();
    expect(screen.getByText(/ss-collector/)).toBeInTheDocument();
    expect(screen.getByText("Failed WinRM/CIM checks do not automatically block collection", { exact: false })).toBeInTheDocument();

    const targetsTable = screen.getByRole("table", { name: /Ports and protocols targets/i });
    expect(within(targetsTable).getByText("\\\\files01\\Finance")).toBeInTheDocument();
    expect(within(targetsTable).getAllByText("Blocked").length).toBeGreaterThan(0);
    expect(within(targetsTable).getByText(/Core collection is likely blocked/i)).toBeInTheDocument();

    const guidanceTable = screen.getByRole("table", { name: /Ports and protocols guidance/i });
    expect(within(guidanceTable).getByText("Default Windows CIM collection")).toBeInTheDocument();
    expect(within(guidanceTable).getAllByText(/NativeSmbRpc/i).length).toBeGreaterThan(0);
    expect(within(guidanceTable).getByText(/Check firewall rules/i)).toBeInTheDocument();

    const checksTable = screen.getByRole("table", { name: /Ports and protocols checks/i });
    expect(within(checksTable).getAllByText("SMB").length).toBeGreaterThan(0);
    expect(within(checksTable).getByText("WinRM HTTP")).toBeInTheDocument();
  });

  test("findings can be grouped and exported by employee identifier prefix", () => {
    renderWithEmployeePrefixSnapshot();

    const nav = screen.getByRole("navigation", { name: /Dashboard views/i });
    fireEvent.click(within(nav).getByRole("button", { name: /Findings/i }));
    fireEvent.change(screen.getByLabelText(/Employee ID or EmployeeNumber prefix/i), { target: { value: "1001" } });

    const table = screen.getByRole("table", { name: /Employee ID number prefix pivot/i });
    expect(within(table).getAllByText("1001").length).toBeGreaterThan(0);
    expect(within(table).getByText("CONTOSO\\Ava.Accounting")).toBeInTheDocument();

    const exportLinks = screen.getAllByRole("link", { name: /Export shown CSV/i });
    const pivotExport = exportLinks.find((link) => link.getAttribute("download") === "employee-prefix-findings-pivot.csv");
    expect(pivotExport).toBeDefined();
    const href = decodeURIComponent(pivotExport?.getAttribute("href") ?? "");
    expect(href).toContain("EmployeePrefix,MatchPrefix,IdentifierField");
    expect(href).toContain("1001");
    expect(href).toContain("finding-employee-prefix");
  });

  test("scoped search chips explain which signal is filtering raw evidence", () => {
    renderWithDemoSnapshot();

    fireEvent.click(screen.getByRole("button", { name: /Raw Evidence/i }));
    fireEvent.change(screen.getByLabelText(/Dataset/i), { target: { value: "shares" } });
    fireEvent.change(screen.getByRole("searchbox", { name: /Search dashboard/i }), { target: { value: "share:HR" } });

    expect(screen.getByText("share: HR")).toBeInTheDocument();

    const table = screen.getByRole("table", { name: /Shares/i });
    expect(within(table).getByText("HR")).toBeInTheDocument();
    expect(within(table).queryByText("Finance")).not.toBeInTheDocument();
  });

  test("session state restores active view and filters after a dashboard remount", () => {
    const firstRender = renderWithDemoSnapshot();

    fireEvent.click(screen.getByRole("button", { name: /Raw Evidence/i }));
    fireEvent.change(screen.getByRole("searchbox", { name: /Search dashboard/i }), { target: { value: "owner:Finance" } });

    firstRender.unmount();
    renderWithDemoSnapshot();

    expect(screen.getByRole("heading", { name: /Raw Evidence Explorer/i })).toBeInTheDocument();
    expect(screen.getByRole("searchbox", { name: /Search dashboard/i })).toHaveValue("owner:Finance");
    expect(screen.getByText("owner: Finance")).toBeInTheDocument();
  });
});
