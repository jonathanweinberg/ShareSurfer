import { fireEvent, render, screen, within } from "@testing-library/react";
import { beforeEach, describe, expect, test } from "vitest";
import { App } from "./App";
import { demoSnapshot } from "./data/fixtures";

function renderWithDemoSnapshot() {
  window.__SHARESURFER_SNAPSHOT__ = demoSnapshot;
  return render(<App />);
}

describe("dashboard workbench interactions", () => {
  beforeEach(() => {
    delete window.__SHARESURFER_SNAPSHOT__;
    window.sessionStorage.clear();
    window.localStorage?.clear();
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

  test("migration metrics drill into evidence rows and can return to the cluster", () => {
    renderWithDemoSnapshot();

    fireEvent.click(screen.getByRole("button", { name: /Migration/i }));
    fireEvent.click(screen.getByRole("button", { name: /Shares 1/i }));

    expect(screen.getByRole("heading", { name: /Shares Evidence/i })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: /Back to migration cluster/i })).toBeInTheDocument();
    expect(screen.getByText(/Finance \/ Accounts Payable/i)).toBeInTheDocument();
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
