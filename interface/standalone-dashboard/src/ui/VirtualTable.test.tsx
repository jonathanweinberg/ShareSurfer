import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, test } from "vitest";
import { VirtualTable } from "./VirtualTable";

describe("VirtualTable", () => {
  test("renders a bounded page and paginates without mounting every row", async () => {
    const user = userEvent.setup();
    const rows = Array.from({ length: 75 }, (_, index) => ({
      Name: `Row ${index + 1}`,
      Severity: index % 2 === 0 ? "High" : "Low"
    }));

    render(<VirtualTable rows={rows} columns={["Name", "Severity"]} pageSize={20} title="Raw evidence" />);

    expect(screen.getByText("Showing 1-20 of 75")).toBeInTheDocument();
    expect(screen.getByText("Row 1")).toBeInTheDocument();
    expect(screen.queryByText("Row 30")).not.toBeInTheDocument();

    await user.click(screen.getByRole("button", { name: /next page/i }));
    expect(screen.getByText("Showing 21-40 of 75")).toBeInTheDocument();
    expect(screen.getByText("Row 30")).toBeInTheDocument();
  });

  test("sorts rows when a column header is toggled", async () => {
    const user = userEvent.setup();
    const rows = [
      { Name: "Charlie", Severity: "Low" },
      { Name: "Alpha", Severity: "High" },
      { Name: "Bravo", Severity: "Medium" }
    ];

    render(<VirtualTable rows={rows} columns={["Name", "Severity"]} pageSize={20} title="Raw evidence" />);

    await user.click(screen.getByRole("button", { name: /Sort by Name/i }));
    expect(screen.getAllByRole("row").slice(1).map((row) => row.textContent)).toEqual([
      "AlphaHigh",
      "BravoMedium",
      "CharlieLow"
    ]);

    await user.click(screen.getByRole("button", { name: /Sort by Name/i }));
    expect(screen.getAllByRole("row").slice(1).map((row) => row.textContent)).toEqual([
      "CharlieLow",
      "BravoMedium",
      "AlphaHigh"
    ]);
  });

  test("filters rows locally without relying on the global dashboard search", async () => {
    const user = userEvent.setup();
    const rows = [
      { Name: "Finance Readers", Path: "\\\\files01\\Finance" },
      { Name: "HR Readers", Path: "\\\\files01\\HR" },
      { Name: "Operations Readers", Path: "\\\\files01\\Operations" }
    ];

    render(<VirtualTable rows={rows} columns={["Name", "Path"]} pageSize={20} title="Permissioned groups" />);

    await user.type(screen.getByRole("searchbox", { name: /Filter Permissioned groups rows/i }), "finance");

    expect(screen.getByText("Showing 1-1 of 1 (filtered from 3)")).toBeInTheDocument();
    expect(screen.getByText("Finance Readers")).toBeInTheDocument();
    expect(screen.queryByText("HR Readers")).not.toBeInTheDocument();
  });

  test("uses compact sort indicators and shows the unfiltered total when filtered", async () => {
    const user = userEvent.setup();
    const rows = [
      { Name: "Finance Readers", Path: "\\\\files01\\Finance" },
      { Name: "HR Readers", Path: "\\\\files01\\HR" },
      { Name: "Operations Readers", Path: "\\\\files01\\Operations" }
    ];

    render(<VirtualTable rows={rows} columns={["Name", "Path"]} pageSize={20} title="Permissioned groups" />);

    expect(screen.getAllByText("↕")).toHaveLength(2);
    expect(screen.queryByText("SORT")).not.toBeInTheDocument();

    await user.click(screen.getByRole("button", { name: /Sort by Name/i }));
    expect(screen.getByText("▲")).toBeInTheDocument();
    expect(screen.queryByText("ASC")).not.toBeInTheDocument();

    await user.type(screen.getByRole("searchbox", { name: /Filter Permissioned groups rows/i }), "finance");

    expect(screen.getByText("Showing 1-1 of 1 (filtered from 3)")).toBeInTheDocument();
  });
});
