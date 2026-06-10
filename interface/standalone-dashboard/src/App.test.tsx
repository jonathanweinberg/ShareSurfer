import { fireEvent, render, screen, within } from "@testing-library/react";
import { beforeEach, describe, expect, test } from "vitest";
import { App } from "./App";
import { demoSnapshot } from "./data/fixtures";

function renderWithDemoSnapshot() {
  window.__SHARESURFER_SNAPSHOT__ = demoSnapshot;
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
