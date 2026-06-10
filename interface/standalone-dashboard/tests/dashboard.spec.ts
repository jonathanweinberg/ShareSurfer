import { expect, test } from "@playwright/test";
import { existsSync } from "node:fs";
import path from "node:path";
import { pathToFileURL } from "node:url";

test("standalone dashboard opens from file URL and exercises core views without network", async ({ page }) => {
  const indexPath = process.env.SHARESURFER_DASHBOARD_FILE
    ? path.resolve(process.env.SHARESURFER_DASHBOARD_FILE)
    : path.resolve(process.cwd(), "dist", "index.html");
  expect(existsSync(indexPath), "Run the dashboard build or set SHARESURFER_DASHBOARD_FILE before Playwright").toBe(true);

  const externalRequests: string[] = [];
  page.on("request", (request) => {
    const url = request.url();
    if (!url.startsWith("file:") && !url.startsWith("data:") && !url.startsWith("blob:")) {
      externalRequests.push(url);
    }
  });

  await page.goto(pathToFileURL(indexPath).toString());
  await expect(page.getByRole("heading", { name: /No ShareSurfer dataset found/i })).toBeVisible();
  await page.getByRole("button", { name: /Open demo dataset/i }).click();

  const nav = page.getByRole("navigation", { name: "Dashboard views" });
  await expect(page.getByRole("heading", { name: /Permission Review Dashboard/i })).toBeVisible();
  await expect(page.getByText(/Potential Service Accounts/i)).toBeVisible();

  await page.getByRole("button", { name: /High Priority Items help/i }).hover();
  await expect(page.getByRole("tooltip")).toContainText(/routing label/i);

  const scrollWidthBeforeTooltip = await page.evaluate(() => document.documentElement.scrollWidth);
  await page.getByRole("button", { name: /Items Reviewed help/i }).hover();
  await expect(page.getByRole("tooltip")).toContainText(/original CSV-shaped evidence/i);
  const scrollWidthAfterTooltip = await page.evaluate(() => document.documentElement.scrollWidth);
  expect(scrollWidthAfterTooltip).toBeLessThanOrEqual(scrollWidthBeforeTooltip + 2);

  await page.getByRole("button", { name: "Open Access Conflicts" }).click();
  await expect(page.getByRole("button", { name: /Back to overview/i })).toBeVisible();
  await page.getByRole("button", { name: /Back to overview/i }).click();
  await expect(page.getByRole("heading", { name: /What Needs Review First/i })).toBeVisible();

  await nav.getByRole("button", { name: /Findings/i }).click();
  await expect(page.getByRole("heading", { name: /Findings & Conflicts/i })).toBeVisible();
  await expect(page.getByText(/Recommended next action/i)).toBeVisible();

  await nav.getByRole("button", { name: /Migration/i }).click();
  await expect(page.getByRole("heading", { name: /Related Data Area Clusters/i })).toBeVisible();
  await expect(page.getByText(/Why these are related/i)).toBeVisible();
  const enterpriseClusterCount = await page.locator(".cluster-row", { hasText: "Enterprise / Enterprise Data Owners" }).count();
  expect(enterpriseClusterCount).toBeLessThanOrEqual(1);
  await page.getByRole("button", { name: /^Shares\s+\d+/i }).first().click();
  await expect(page.getByRole("heading", { name: /Shares Evidence/i })).toBeVisible();
  await page.getByRole("button", { name: /Back to migration cluster/i }).click();
  await expect(page.getByRole("heading", { name: /Related Data Area Clusters/i })).toBeVisible();
  await page.getByRole("button", { name: /^Files\s+\d+/i }).first().click();
  await expect(page.getByRole("heading", { name: /Files Evidence/i })).toBeVisible();
  await expect(page.getByRole("columnheader", { name: "Folder Depth" })).toBeVisible();
  await page.getByRole("button", { name: /Back to migration cluster/i }).click();

  await nav.getByRole("button", { name: /Groups/i }).click();
  await expect(page.getByRole("heading", { name: /Permissioned Groups/i })).toBeVisible();
  await expect(page.getByText(/Membership Tree/i)).toBeVisible();

  await nav.getByRole("button", { name: /Identity/i }).click();
  await expect(page.getByRole("columnheader", { name: "Department" })).toBeVisible();
  await page.getByRole("button", { name: /Hide org fields/i }).click();
  await expect(page.getByRole("columnheader", { name: "Department" })).toBeHidden();
  await expect(page.getByRole("columnheader", { name: "Manager Level1" })).toBeVisible();

  await nav.getByRole("button", { name: /Diagnostics/i }).click();
  await expect(page.getByRole("heading", { name: /Scan Health/i })).toBeVisible();

  await nav.getByRole("button", { name: /Raw Evidence/i }).click();
  await expect(page.getByRole("heading", { name: /Raw Evidence Explorer/i })).toBeVisible();
  await expect(page.getByRole("columnheader", { name: "Why Review" })).toBeVisible();
  await expect(page.getByText(/Showing 1-/i)).toBeVisible();
  await page.locator(".raw-panel tbody tr").first().click();
  await expect(page.getByRole("heading", { name: /Selected row details/i })).toBeVisible();
  await expect(page.getByText("ReviewPacketId")).toBeVisible();

  expect(externalRequests).toEqual([]);
});
