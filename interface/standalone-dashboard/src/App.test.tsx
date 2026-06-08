import { fireEvent, render, screen, within } from "@testing-library/react";
import { describe, expect, test } from "vitest";
import { App } from "./App";

describe("dashboard workbench interactions", () => {
  test("active filters scope overview KPI cards instead of leaving global totals", () => {
    render(<App />);

    expect(screen.getByRole("button", { name: "Open Access Conflicts" })).toHaveTextContent("1");

    fireEvent.change(screen.getByLabelText(/Review Risk/i), { target: { value: "Warning" } });

    expect(screen.getByRole("button", { name: "Open Access Conflicts" })).toHaveTextContent("0");
    expect(screen.getByRole("button", { name: "Open Items Reviewed" })).toHaveTextContent("0");
  });

  test("overview KPI cards open real destinations with a return path", () => {
    render(<App />);

    fireEvent.click(screen.getByRole("button", { name: "Open Access Conflicts" }));

    expect(screen.getByRole("heading", { name: /Findings & Conflicts/i })).toBeInTheDocument();
    expect(screen.getByText("Overview / Access Conflicts")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: /Back to overview/i })).toBeInTheDocument();
  });

  test("migration metrics drill into evidence rows and can return to the cluster", () => {
    render(<App />);

    fireEvent.click(screen.getByRole("button", { name: /Migration/i }));
    fireEvent.click(screen.getByRole("button", { name: /Shares 1/i }));

    expect(screen.getByRole("heading", { name: /Shares Evidence/i })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: /Back to migration cluster/i })).toBeInTheDocument();
    expect(screen.getByText(/Finance \/ Accounts Payable/i)).toBeInTheDocument();
  });

  test("file and folder evidence explains depth in reviewer language", () => {
    render(<App />);

    fireEvent.click(screen.getByRole("button", { name: /Migration/i }));
    fireEvent.click(screen.getByRole("button", { name: /Files 0/i }));

    expect(screen.getByRole("columnheader", { name: "Folder Depth" })).toBeInTheDocument();
  });

  test("identity workbench can hide low-value org columns while exploring manager routing", () => {
    render(<App />);

    fireEvent.click(screen.getByRole("button", { name: /Identity/i }));
    expect(screen.getByRole("columnheader", { name: "Department" })).toBeInTheDocument();

    fireEvent.click(screen.getByRole("button", { name: /Hide org fields/i }));

    expect(screen.queryByRole("columnheader", { name: "Department" })).not.toBeInTheDocument();
    expect(screen.getByRole("columnheader", { name: "Manager Level1" })).toBeInTheDocument();
  });

  test("raw evidence uses readable curated columns before showing all CSV fields", () => {
    render(<App />);

    fireEvent.click(screen.getByRole("button", { name: /Raw Evidence/i }));

    const table = screen.getByRole("table", { name: /Review packets/i });
    expect(within(table).getByRole("columnheader", { name: "Why Review" })).toBeInTheDocument();
    expect(within(table).queryByRole("columnheader", { name: "ReviewPacketId" })).not.toBeInTheDocument();

    fireEvent.click(screen.getByRole("button", { name: /Show all columns/i }));
    expect(within(table).getByRole("columnheader", { name: "Review Packet Id" })).toBeInTheDocument();
  });

  test("raw evidence rows can be opened as vertical details without horizontal scrolling", () => {
    render(<App />);

    fireEvent.click(screen.getByRole("button", { name: /Raw Evidence/i }));
    fireEvent.click(screen.getByRole("row", { name: /Finance Operations/i }));

    expect(screen.getByRole("heading", { name: /Selected row details/i })).toBeInTheDocument();
    expect(screen.getByText("ReviewPacketId")).toBeInTheDocument();
    expect(screen.getByText("owner-review-finance")).toBeInTheDocument();
  });
});
