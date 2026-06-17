import { expect, test } from "@playwright/test";
import { execFileSync } from "node:child_process";
import { existsSync, mkdtempSync, readFileSync, readdirSync, rmSync, statSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { pathToFileURL } from "node:url";
import { expectedPackagedRowCounts, writeRepresentativeExportFixture } from "./packagedExportFixture";

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

test("packaged standalone dashboard opens export output from file URL without network", async ({ page }) => {
  const dashboardRoot = process.cwd();
  const repoRoot = path.resolve(dashboardRoot, "..", "..");
  const distPath = path.join(dashboardRoot, "dist");
  const packagerPath = path.join(repoRoot, "scripts", "New-ShareSurferStandaloneDashboard.ps1");
  const tempRoot = mkdtempSync(path.join(tmpdir(), "sharesurfer-packaged-dashboard-"));
  const exportPath = path.join(tempRoot, "export");
  const outputPath = path.join(tempRoot, "standalone-dashboard");
  const measurementPath = path.join(tempRoot, "packaged-dashboard-readiness.json");

  try {
    const fixtureRowCounts = writeRepresentativeExportFixture(exportPath);
    expect(fixtureRowCounts).toMatchObject(expectedPackagedRowCounts);

    const packageStartedAt = performance.now();
    execFileSync(
      "pwsh",
      [
        "-NoLogo",
        "-NoProfile",
        "-File",
        packagerPath,
        "-ExportPath",
        exportPath,
        "-OutputPath",
        outputPath,
        "-DashboardBuildPath",
        distPath,
        "-Force"
      ],
      {
        cwd: repoRoot,
        encoding: "utf8",
        stdio: "pipe"
      }
    );
    const packageDurationMs = Math.round(performance.now() - packageStartedAt);

    const packagedIndexPath = path.join(outputPath, "index.html");
    const packagedDataPath = path.join(outputPath, "sharesurfer-data.js");
    const packagedManifestPath = path.join(outputPath, "dashboard-manifest.json");

    for (const packagedFile of [packagedIndexPath, packagedDataPath, packagedManifestPath]) {
      expect(existsSync(packagedFile), `${path.basename(packagedFile)} should exist in packaged dashboard output`).toBe(true);
    }

    for (const relativeAssetPath of listStaticDashboardFiles(distPath)) {
      expect(existsSync(path.join(outputPath, relativeAssetPath)), `${relativeAssetPath} should be copied from dist`).toBe(true);
    }

    const manifest = JSON.parse(readFileSync(packagedManifestPath, "utf8")) as {
      dashboardDataKind?: string;
      rowCounts?: Record<string, number>;
    };
    expect(manifest.dashboardDataKind).toBe("export");
    for (const [dataset, expectedCount] of Object.entries(expectedPackagedRowCounts)) {
      expect(manifest.rowCounts?.[dataset], `${dataset} row count`).toBe(expectedCount);
      expect(manifest.rowCounts?.[dataset], `${dataset} row count should be nonzero`).toBeGreaterThan(0);
    }

    const externalRequests: string[] = [];
    page.on("request", (request) => {
      const url = request.url();
      if (!url.startsWith("file:") && !url.startsWith("data:") && !url.startsWith("blob:")) {
        externalRequests.push(url);
      }
    });

    const renderStartedAt = performance.now();
    await page.goto(pathToFileURL(packagedIndexPath).toString());
    await expect(page.getByRole("heading", { name: /Permission Review Dashboard/i })).toBeVisible();
    const firstRenderMs = Math.round(performance.now() - renderStartedAt);

    await expect(page.getByRole("heading", { name: /No ShareSurfer dataset found/i })).toHaveCount(0);
    await expect(page.locator("body")).toHaveText(/Export dataset/i);
    const bodyBox = await page.locator("body").boundingBox();
    expect(bodyBox?.width ?? 0).toBeGreaterThan(100);
    expect(bodyBox?.height ?? 0).toBeGreaterThan(100);

    await expect(page.getByRole("button", { name: "Open Items Reviewed" })).toHaveText(/3/);
    await expect(page.getByRole("button", { name: "Open High Priority Items" })).toHaveText(/1/);
    await expect(page.getByRole("button", { name: "Open Access Conflicts" })).toHaveText(/1/);
    await expect(page.getByRole("button", { name: "Open Permissioned Groups" })).toHaveText(/1/);

    const nav = page.getByRole("navigation", { name: "Dashboard views" });
    const navigationStartedAt = performance.now();
    await nav.getByRole("button", { name: /Findings/i }).click();
    await expect(page.getByRole("heading", { name: /Findings & Conflicts/i })).toBeVisible();

    await nav.getByRole("button", { name: /Migration/i }).click();
    await expect(page.getByRole("heading", { name: /Related Data Area Clusters/i })).toBeVisible();

    await nav.getByRole("button", { name: /Groups/i }).click();
    await expect(page.getByRole("heading", { name: /Permissioned Groups/i })).toBeVisible();

    await nav.getByRole("button", { name: /Diagnostics/i }).click();
    await expect(page.getByRole("heading", { name: /Scan Health/i })).toBeVisible();

    await nav.getByRole("button", { name: /Raw Evidence/i }).click();
    await expect(page.getByRole("heading", { name: /Raw Evidence Explorer/i })).toBeVisible();
    const datasetSelect = page.getByLabel(/Dataset/i);
    await expect(datasetSelect).toContainText("Review packets (1)");
    await expect(datasetSelect).toContainText("Migration clusters (1)");
    await expect(datasetSelect).toContainText("Folder/file permissions (3)");
    await datasetSelect.selectOption("owner_review_packets");
    await expect(page.getByRole("heading", { name: /Selected row details/i })).toBeVisible();
    await expect(page.getByText("ReviewPacketId")).toBeVisible();
    await expect(page.getByText("owner-review-finance")).toBeVisible();
    const navigationDurationMs = Math.round(performance.now() - navigationStartedAt);

    expect(externalRequests).toEqual([]);

    const readinessMeasurement = {
      packageBytes: directorySize(outputPath),
      packageDurationMs,
      firstRenderMs,
      navigationDurationMs,
      rowCounts: manifest.rowCounts
    };
    writeFileSync(measurementPath, `${JSON.stringify(readinessMeasurement, null, 2)}\n`, "utf8");
    console.info(`[sharesurfer-packaged-dashboard-readiness] ${JSON.stringify(readinessMeasurement)}`);
  } finally {
    rmSync(tempRoot, { recursive: true, force: true });
  }
});

function listStaticDashboardFiles(root: string): string[] {
  return listFiles(root).filter((relativePath) => relativePath !== "sharesurfer-data.js");
}

function listFiles(root: string, current = root): string[] {
  return readdirSync(current, { withFileTypes: true }).flatMap((entry) => {
    const fullPath = path.join(current, entry.name);
    if (entry.isDirectory()) {
      return listFiles(root, fullPath);
    }

    return [path.relative(root, fullPath)];
  });
}

function directorySize(root: string): number {
  return listFiles(root).reduce((total, relativePath) => total + statSync(path.join(root, relativePath)).size, 0);
}
