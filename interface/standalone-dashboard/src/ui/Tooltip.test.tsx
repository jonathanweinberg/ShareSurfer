import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, test } from "vitest";
import { Tooltip } from "./Tooltip";

describe("Tooltip", () => {
  test("opens on hover and keyboard focus with accessible text", async () => {
    const user = userEvent.setup();
    render(
      <Tooltip label="Scan confidence" text="Shows whether missing evidence should be reviewed before approval." />
    );

    const trigger = screen.getByRole("button", { name: /scan confidence/i });
    expect(screen.queryByRole("tooltip")).not.toBeInTheDocument();

    await user.hover(trigger);
    expect(screen.getByRole("tooltip")).toHaveTextContent("missing evidence");

    await user.unhover(trigger);
    await user.tab();
    expect(trigger).toHaveFocus();
    expect(screen.getByRole("tooltip")).toHaveTextContent("missing evidence");

    await user.tab();
    expect(screen.queryByRole("tooltip")).not.toBeInTheDocument();
  });

  test("renders the bubble outside the local layout so it cannot add page scrollbars", async () => {
    const user = userEvent.setup();
    render(<Tooltip label="Raw evidence" text="The original CSV-shaped evidence." />);

    await user.hover(screen.getByRole("button", { name: /raw evidence/i }));

    const bubble = screen.getByRole("tooltip");
    expect(bubble.parentElement).toBe(document.body);
    expect(bubble).toHaveStyle({ position: "fixed" });
  });
});
