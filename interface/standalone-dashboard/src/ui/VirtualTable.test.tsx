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
});
