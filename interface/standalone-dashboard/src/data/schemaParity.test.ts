import { readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { describe, expect, test } from "vitest";
import { datasetKeys, expectedColumns } from "./schema";

type SchemaMap = Record<string, string[]>;

const currentDirectory = path.dirname(fileURLToPath(import.meta.url));
const repositoryRoot = path.resolve(currentDirectory, "../../../..");

function parsePowerShellSchema(relativePath: string): SchemaMap {
  const source = readFileSync(path.join(repositoryRoot, relativePath), "utf8");
  const schema: SchemaMap = {};
  const entryPattern = /'([^']+\.csv)'\s*=\s*@\(([\s\S]*?)\)/g;

  for (const match of source.matchAll(entryPattern)) {
    schema[match[1]] = Array.from(match[2].matchAll(/'([^']+)'/g), (columnMatch) => columnMatch[1]);
  }

  return schema;
}

function mergeSchemas(...schemas: SchemaMap[]): SchemaMap {
  const merged: SchemaMap = {};

  for (const schema of schemas) {
    for (const [fileName, columns] of Object.entries(schema)) {
      if (merged[fileName]) {
        expect(columns, `${fileName} has conflicting schema definitions`).toEqual(merged[fileName]);
      }
      merged[fileName] = columns;
    }
  }

  return merged;
}

function runtimeSchema(): SchemaMap {
  return Object.fromEntries(datasetKeys.map((datasetKey) => [`${datasetKey}.csv`, expectedColumns[datasetKey]]));
}

describe("ShareSurfer dashboard schema parity", () => {
  test("dashboard runtime schema includes exported evidence confidence", () => {
    expect(datasetKeys as readonly string[]).toContain("evidence_confidence");
    expect(expectedColumns["evidence_confidence" as keyof typeof expectedColumns]).toEqual([
      "ConfidenceId",
      "Scope",
      "ScopeId",
      "ScopeName",
      "ConfidenceLabel",
      "ConfidenceScore",
      "StopGate",
      "ReviewGate",
      "SignalCount",
      "Signals",
      "PartialShareCount",
      "CollectionErrorCount",
      "HighSeverityErrorCount",
      "TotalShares",
      "TotalItems",
      "RequestedProvider",
      "EffectiveProvider",
      "ProviderFallback",
      "RecommendedAction",
      "Detail"
    ]);
  });

  test("standalone packager schema covers every normalized PowerShell export CSV", () => {
    const exportSchema = parsePowerShellSchema("src/ShareSurfer/Private/Get-ShareSurferExportSchema.ps1");
    const packagerSchema = parsePowerShellSchema("scripts/New-ShareSurferStandaloneDashboard.ps1");

    for (const [fileName, columns] of Object.entries(exportSchema)) {
      expect(packagerSchema[fileName], `${fileName} is missing from the standalone dashboard packager contract`).toBeDefined();
      expect(packagerSchema[fileName], `${fileName} columns drifted between PowerShell export and standalone packager`).toEqual(columns);
    }
  });

  test("dashboard runtime schema matches the PowerShell and standalone packager contracts", () => {
    const powerShellSchema = mergeSchemas(
      parsePowerShellSchema("src/ShareSurfer/Private/Get-ShareSurferExportSchema.ps1"),
      parsePowerShellSchema("src/ShareSurfer/Private/Get-ShareSurferOpenFileExportSchema.ps1"),
      parsePowerShellSchema("src/ShareSurfer/Private/Get-ShareSurferPortProtocolExportSchema.ps1")
    );
    const packagerSchema = parsePowerShellSchema("scripts/New-ShareSurferStandaloneDashboard.ps1");

    for (const [fileName, columns] of Object.entries(runtimeSchema())) {
      expect(powerShellSchema[fileName], `${fileName} is expected by the dashboard runtime but is not produced by a PowerShell schema`).toBeDefined();
      expect(packagerSchema[fileName], `${fileName} is expected by the dashboard runtime but is missing from the standalone packager`).toBeDefined();
      expect(columns, `${fileName} columns drifted between dashboard runtime and PowerShell schema`).toEqual(powerShellSchema[fileName]);
      expect(columns, `${fileName} columns drifted between dashboard runtime and standalone packager`).toEqual(packagerSchema[fileName]);
    }
  });
});
