import { mkdirSync, writeFileSync } from "node:fs";
import path from "node:path";
import { demoSnapshot } from "../src/data/fixtures";
import { datasetKeys, expectedColumns, type DataRow, type DatasetKey } from "../src/data/schema";

export const expectedPackagedRowCounts = {
  shares: 3,
  items: 3,
  acl_entries: 3,
  findings: 3,
  conflicts: 1,
  owner_review_packets: 1,
  related_data_areas: 1
} as const;

export function writeRepresentativeExportFixture(exportPath: string): Partial<Record<DatasetKey, number>> {
  mkdirSync(exportPath, { recursive: true });

  const rowCounts: Partial<Record<DatasetKey, number>> = {};
  for (const datasetKey of datasetKeys) {
    const rows = demoSnapshot.datasets?.[datasetKey] ?? [];
    writeCsv(path.join(exportPath, `${datasetKey}.csv`), expectedColumns[datasetKey], rows);
    rowCounts[datasetKey] = rows.length;
  }

  return rowCounts;
}

function writeCsv(filePath: string, columns: string[], rows: DataRow[]): void {
  const lines = [columns.map(formatCsvCell).join(",")];
  for (const row of rows) {
    lines.push(columns.map((column) => formatCsvCell(row[column] ?? "")).join(","));
  }

  writeFileSync(filePath, `${lines.join("\n")}\n`, "utf8");
}

function formatCsvCell(value: string): string {
  if (!/[",\r\n]/.test(value)) {
    return value;
  }

  return `"${value.replace(/"/g, '""')}"`;
}
