import { describe, expect, test } from "vitest";
import { deriveDashboard, normalizeSnapshot } from "./deriveDashboard";
import { demoSnapshot } from "./fixtures";
import { expectedColumns } from "./schema";

describe("ShareSurfer dashboard data model", () => {
  test("normalizes legacy identity columns and records schema warnings", () => {
    const snapshot = normalizeSnapshot({
      datasets: {
        identities: [
          {
            Identity: "CONTOSO\\svc.Legacy",
            ObjectClass: "user",
            EmployeeId: "",
            EmployeeNumber: "",
            ObsPath: ""
          }
        ],
        org_chains: [
          {
            Identity: "CONTOSO\\Ava.Accounting",
            ManagerLevel1: "CONTOSO\\Morgan.Manager",
            ManagerLevel2: "CONTOSO\\Riley.Director"
          }
        ]
      }
    });

    expect(snapshot.datasets.identities[0].ManagerLevel3).toBe("");
    expect(snapshot.datasets.identities[0].PotentialServiceAccount).toBe("True");
    expect(snapshot.datasets.org_chains[0].PotentialServiceAccount).toBe("False");
    expect(snapshot.schemaWarnings.some((warning) => warning.includes("ManagerLevel3"))).toBe(true);
    expect(snapshot.schemaWarnings.some((warning) => warning.includes("PotentialServiceAccount"))).toBe(true);
  });

  test("deduplicates missing-column warnings across large datasets", () => {
    const snapshot = normalizeSnapshot({
      datasets: {
        identities: Array.from({ length: 500 }, (_, index) => ({
          Identity: `CONTOSO\\User${index}`,
          ObjectClass: "user",
          EmployeeId: "",
          EmployeeNumber: "",
          ObsPath: ""
        }))
      }
    });

    const managerLevelWarnings = snapshot.schemaWarnings.filter((warning) =>
      warning.includes("identities.csv is missing column ManagerLevel3;")
    );
    const potentialServiceAccountWarnings = snapshot.schemaWarnings.filter((warning) =>
      warning.includes("identities.csv is missing column PotentialServiceAccount;")
    );

    expect(managerLevelWarnings).toHaveLength(1);
    expect(potentialServiceAccountWarnings).toHaveLength(1);
    expect(snapshot.schemaWarnings.length).toBeLessThan(60);
  });

  test("derives novice-friendly dashboard signals from V1 exports", () => {
    const dashboard = deriveDashboard(normalizeSnapshot(demoSnapshot));

    expect(dashboard.scanSummary.totalShares).toBe(3);
    expect(dashboard.scanSummary.partialShares).toBe(1);
    expect(dashboard.scanSummary.potentialServiceAccounts).toBe(1);
    expect(dashboard.reviewQueue[0].owner).toBe("Finance Operations");
    expect(dashboard.issueSummaries.map((issue) => issue.category)).toContain("Service Account Review");
    expect(dashboard.identityReviewSignals.serviceAccounts[0].reviewLabel).toBe("Account purpose needs review");
    expect(dashboard.migrationClusters[0].relatedSignals.length).toBeGreaterThan(1);
    expect(dashboard.permissionedGroupTree[0].children.length).toBeGreaterThan(0);
    expect(dashboard.rawEvidenceCatalog.find((dataset) => dataset.key === "acl_entries")?.totalRows).toBe(3);
  });

  test("prefers exported evidence confidence while keeping legacy fallback available", () => {
    const legacyDashboard = deriveDashboard(
      normalizeSnapshot({
        datasets: {
          shares: [
            {
              ShareId: "share-legacy",
              PartialData: "True"
            }
          ],
          collection_errors: [
            {
              ErrorId: "error-legacy",
              ErrorType: "AclReadError",
              Severity: "High",
              Message: "Access denied while reading ACLs."
            }
          ]
        }
      })
    );

    expect(legacyDashboard.scanSummary.scanConfidence).toBe(80);
    expect(legacyDashboard.scanSummary.confidenceLabel).toBe("Review");

    const exportedDashboard = deriveDashboard(
      normalizeSnapshot({
        datasets: {
          shares: [
            {
              ShareId: "share-exported",
              PartialData: "True"
            }
          ],
          collection_errors: [
            {
              ErrorId: "error-exported",
              ErrorType: "AclReadError",
              Severity: "High",
              Message: "Access denied while reading ACLs."
            }
          ],
          evidence_confidence: [
            {
              ConfidenceId: "confidence-scan",
              Scope: "Scan",
              ScopeId: "scan",
              ScopeName: "Scan evidence completeness",
              ConfidenceLabel: "Partial",
              ConfidenceScore: "62",
              StopGate: "",
              ReviewGate: "Partial collection evidence; provider fallback changed metadata path.",
              SignalCount: "3",
              Signals: "Partial shares: 1; collection errors: 1; provider fallback used.",
              PartialShareCount: "1",
              CollectionErrorCount: "1",
              HighSeverityErrorCount: "1",
              TotalShares: "1",
              TotalItems: "0",
              RequestedProvider: "Auto",
              EffectiveProvider: "NativeSmbRpc",
              ProviderFallback: "True",
              RecommendedAction: "Review Diagnostics before owner signoff."
            }
          ]
        }
      })
    );

    expect(exportedDashboard.scanSummary.scanConfidence).toBe(62);
    expect(exportedDashboard.scanSummary.confidenceLabel).toBe("Partial");
    expect(exportedDashboard.scanSummary.confidenceScope).toBe("Scan");
    expect(exportedDashboard.scanSummary.confidenceSignals).toContain("provider fallback");
    expect(exportedDashboard.scanSummary.confidenceProviderFallback).toBe(true);
    expect(exportedDashboard.scanSummary.confidenceRecommendedAction).toBe("Review Diagnostics before owner signoff.");
    expect(exportedDashboard.rawEvidenceCatalog.find((dataset) => dataset.key === "evidence_confidence")?.totalRows).toBe(1);

    const inconsistentExportedDashboard = deriveDashboard(
      normalizeSnapshot({
        datasets: {
          shares: [],
          evidence_confidence: [
            {
              ConfidenceId: "confidence-bad",
              Scope: "Scan",
              ScopeId: "scan",
              ScopeName: "Scan evidence completeness",
              ConfidenceLabel: "Good",
              ConfidenceScore: "96",
              StopGate: "No share evidence was exported.",
              ReviewGate: "",
              Signals: "No shares were exported.",
              ProviderFallback: "False",
              RecommendedAction: "Rerun collection."
            }
          ]
        }
      })
    );

    expect(inconsistentExportedDashboard.scanSummary.scanConfidence).toBe(64);
    expect(inconsistentExportedDashboard.scanSummary.confidenceLabel).toBe("Partial");
  });

  test("derives port and protocol stop and review gates without treating reachability as security descriptor proof", () => {
    const dashboard = deriveDashboard(normalizeSnapshot(demoSnapshot));

    const stopGate = dashboard.protocolReadinessGates.find((gate) => gate.gateType === "Stop" && gate.protocol === "SMB");
    const winRmGate = dashboard.protocolReadinessGates.find((gate) => gate.gateType === "Review" && gate.protocol.includes("WinRM"));
    const smbProofNote = dashboard.protocolReadinessGates.find((gate) => gate.gateType === "Info" && gate.protocol === "SMB");

    expect(stopGate?.message).toContain("Required SMB reachability failed");
    expect(stopGate?.recommendedAction).toContain("Resolve required SMB reachability");
    expect(winRmGate?.message).toMatch(/fallback|partial metadata/i);
    expect(smbProofNote?.message).toMatch(/does not prove ACL or security descriptor readability/i);

    const edgeDashboard = deriveDashboard(
      normalizeSnapshot({
        datasets: {
          port_protocol_checks: [
            {
              CheckId: "winrm-pass",
              Target: "\\\\files01\\Finance",
              TargetType: "SmbTarget",
              Protocol: "WinRM HTTP",
              Port: "5985",
              Requirement: "Recommended",
              Provider: "CIM",
              Purpose: "Remote SMB metadata collection",
              RequiredFor: "Get-SmbShare and Get-SmbShareAccess through CIM",
              Status: "Pass",
              Severity: "Info"
            },
            {
              CheckId: "rpc-pass",
              Target: "\\\\files01\\Finance",
              TargetType: "SmbTarget",
              Protocol: "RPC Endpoint Mapper",
              Port: "135",
              Requirement: "Recommended",
              Provider: "NativeSmbRpc",
              Purpose: "Native share metadata route",
              RequiredFor: "Native SMB/RPC metadata",
              Status: "Pass",
              Severity: "Info"
            },
            {
              CheckId: "smb-skipped",
              Target: "\\\\files02\\Archive",
              TargetType: "SmbTarget",
              Protocol: "SMB",
              Port: "445",
              Requirement: "Required",
              Provider: "SMB",
              Purpose: "File share and ACL evidence",
              RequiredFor: "SMB enumeration",
              Status: "Skipped",
              Severity: "Info"
            }
          ]
        }
      })
    );

    expect(edgeDashboard.protocolReadinessGates.some((gate) => gate.gateType === "Info" && gate.protocol === "WinRM HTTP")).toBe(false);
    expect(edgeDashboard.protocolReadinessGates.some((gate) => gate.gateType === "Info" && gate.protocol === "RPC Endpoint Mapper" && /only proves that this RPC route answered/.test(gate.message))).toBe(true);
    expect(edgeDashboard.protocolReadinessGates.some((gate) => gate.gateType === "Stop" && gate.protocol === "SMB" && /skipped/i.test(gate.message))).toBe(true);
  });

  test("treats ownership enrichment as optional labeled raw evidence", () => {
    const legacySnapshot = normalizeSnapshot({
      datasets: {
        scan_manifest: [{ GeneratedAt: "2026-06-15T12:00:00Z" }]
      }
    });

    expect(legacySnapshot.schemaWarnings.some((warning) => warning.includes("ownership_enrichment.csv was not present"))).toBe(false);

    const dashboard = deriveDashboard(
      normalizeSnapshot({
        datasets: {
          ownership_enrichment: [
            {
              OwnershipKey: "E123",
              MatchStatus: "Matched",
              MatchMethod: "EmployeeId",
              SourcePaths: "hr.csv",
              SourceRowNumbers: "2",
              EmployeeId: "E123",
              DisplayName: "Ava Accounting",
              BusinessUnit: "Finance",
              AccountEnabled: "True",
              PotentialServiceAccount: "False",
              ForbiddenOuMatched: "False"
            },
            {
              OwnershipKey: "svc-sharebot",
              MatchStatus: "SourceOnly",
              MatchMethod: "SamAccountName",
              SourcePaths: "projects.csv",
              SourceRowNumbers: "8",
              SamAccountName: "svc-sharebot",
              DisplayName: "Share Bot",
              BusinessUnit: "Operations",
              AccountEnabled: "True",
              PotentialServiceAccount: "True",
              ForbiddenOuMatched: "False"
            },
            {
              OwnershipKey: "E404",
              MatchStatus: "ForbiddenOuSkipped",
              MatchMethod: "EmployeeId",
              SourcePaths: "disabled.csv",
              SourceRowNumbers: "4",
              EmployeeId: "E404",
              DisplayName: "Former User",
              AccountEnabled: "False",
              PotentialServiceAccount: "False",
              ForbiddenOuMatched: "OU=Disabled Accounts,DC=example,DC=test"
            },
            {
              OwnershipKey: "E777",
              MatchStatus: "Ambiguous",
              MatchMethod: "EmployeeId",
              SourcePaths: "hr.csv",
              SourceRowNumbers: "9",
              EmployeeId: "E777",
              DisplayName: "Duplicate Identity",
              AccountEnabled: "True",
              PotentialServiceAccount: "False",
              ForbiddenOuMatched: "False"
            }
          ]
        }
      })
    );

    const rawEvidence = dashboard.rawEvidenceCatalog.find((dataset) => dataset.key === "ownership_enrichment");

    expect(rawEvidence?.label).toBe("Ownership enrichment");
    expect(rawEvidence?.columns).toEqual(expectedColumns.ownership_enrichment);
    expect(rawEvidence?.totalRows).toBe(4);
    expect(dashboard.scanSummary.ownershipEnrichmentRows).toBe(4);
    expect(dashboard.scanSummary.ownershipEnrichmentMatched).toBe(1);
    expect(dashboard.scanSummary.ownershipEnrichmentAmbiguous).toBe(1);
    expect(dashboard.scanSummary.ownershipEnrichmentForbiddenOuSkipped).toBe(1);
    expect(dashboard.scanSummary.ownershipEnrichmentSourceOnly).toBe(1);
    expect(dashboard.scanSummary.ownershipEnrichmentPotentialServiceAccounts).toBe(1);
  });

  test("includes ownership context graph datasets in raw evidence when present", () => {
    const dashboard = deriveDashboard(normalizeSnapshot(JSON.parse(JSON.stringify(demoSnapshot))));

    const contextEvidence = dashboard.rawEvidenceCatalog.find((dataset) => dataset.key === "ownership_context");
    const relationshipEvidence = dashboard.rawEvidenceCatalog.find((dataset) => dataset.key === "ownership_relationships");
    const manifestEvidence = dashboard.rawEvidenceCatalog.find((dataset) => dataset.key === "ownership_import_manifest");

    expect(contextEvidence?.label).toBe("Ownership context");
    expect(contextEvidence?.columns).toEqual(expectedColumns.ownership_context);
    expect(contextEvidence?.totalRows).toBe(1);
    expect(relationshipEvidence?.label).toBe("Ownership relationships");
    expect(relationshipEvidence?.columns).toEqual(expectedColumns.ownership_relationships);
    expect(relationshipEvidence?.totalRows).toBe(1);
    expect(manifestEvidence?.label).toBe("Ownership import manifest");
    expect(manifestEvidence?.columns).toEqual(expectedColumns.ownership_import_manifest);
    expect(manifestEvidence?.totalRows).toBe(1);
  });

  test("promotes broken SID and access-denied collection blockers for focused review", () => {
    const snapshot = JSON.parse(JSON.stringify(demoSnapshot));
    snapshot.datasets.findings = [
      ...snapshot.datasets.findings,
      {
        FindingId: "finding-sid",
        FindingType: "BrokenOrMissingSid",
        Severity: "High",
        ShareId: "share-finance",
        ItemId: "item-finance",
        FullPath: "\\\\files01\\Finance",
        Identity: "S-1-5-21-1000-2000-3000-4040",
        ObservedValue: "S-1-5-21-1000-2000-3000-4040",
        PolicyValue: "Resolvable identity",
        Message: "ACL identity is an unresolved SID."
      },
      {
        FindingId: "finding-owner-metadata",
        FindingType: "OwnerMetadataUnavailable",
        Severity: "Warning",
        ShareId: "share-finance",
        ItemId: "item-budget",
        FullPath: "\\\\files01\\Finance\\OwnerUnknown\\budget.xlsx",
        Identity: "",
        ObservedValue: "blank",
        PolicyValue: "Usable NTFS owner value",
        Message: "ShareSurfer could not collect a usable NTFS owner value for this file."
      }
    ];
    snapshot.datasets.collection_errors = [
      ...snapshot.datasets.collection_errors,
      {
        ErrorId: "error-denied",
        ShareId: "share-finance",
        ItemId: "item-payroll",
        FullPath: "\\\\files01\\Finance\\Payroll",
        ErrorType: "AclReadError",
        Severity: "High",
        Source: "Get-Acl",
        Message: "Access to the path was denied while reading ACLs.",
        Detail: "UnauthorizedAccessException"
      }
    ];

    const dashboard = deriveDashboard(normalizeSnapshot(snapshot));

    expect(dashboard.issueSummaries.map((issue) => issue.category)).toContain("Broken/Missing SID");
    expect(dashboard.issueSummaries.map((issue) => issue.category)).toContain("Owner Metadata Unavailable");
    expect(dashboard.issueSummaries.find((issue) => issue.category === "Owner Metadata Unavailable")?.title).toBe(
      "NTFS owner metadata was unavailable"
    );
    expect(dashboard.criticalScanBlocks).toHaveLength(2);
    expect(dashboard.criticalScanBlocks.map((block) => block.ErrorType)).toContain("AclReadError");
    expect(dashboard.criticalScanBlocks.map((block) => block.ErrorType)).toContain("SharePermissionCollectionUnavailable");
  });

  test("classifies critical collection blocks by severity before legacy text heuristics", () => {
    const snapshot = JSON.parse(JSON.stringify(demoSnapshot));
    snapshot.datasets.collection_errors = [
      {
        ErrorId: "error-high-new-wording",
        ShareId: "share-finance",
        ItemId: "item-payroll",
        FullPath: "\\\\files01\\Finance\\Payroll",
        ErrorType: "DirectoryMetadataGap",
        Severity: "High",
        Source: "Collector",
        Message: "Collector skipped a protected branch.",
        Detail: "New message wording that does not match the legacy critical-block heuristic."
      },
      {
        ErrorId: "error-warning-access-denied",
        ShareId: "share-hr",
        ItemId: "item-hr",
        FullPath: "\\\\files01\\HR",
        ErrorType: "AclReadError",
        Severity: "Warning",
        Source: "Get-Acl",
        Message: "Access denied while reading optional metadata.",
        Detail: "Severity is populated, so dashboard should trust it over text matching."
      },
      {
        ErrorId: "error-legacy-access-denied",
        ShareId: "share-legacy",
        ItemId: "item-legacy",
        FullPath: "\\\\files01\\Legacy",
        ErrorType: "AclReadError",
        Severity: "",
        Source: "Get-Acl",
        Message: "Access denied while reading ACLs.",
        Detail: "Legacy export without severity should still use text fallback."
      }
    ];

    const dashboard = deriveDashboard(normalizeSnapshot(snapshot));
    const criticalIds = dashboard.criticalScanBlocks.map((block) => block.ErrorId);

    expect(criticalIds).toContain("error-high-new-wording");
    expect(criticalIds).toContain("error-legacy-access-denied");
    expect(criticalIds).not.toContain("error-warning-access-denied");
  });

  test("aggregates repeated owner-level review and migration rows into one workbench cluster", () => {
    const snapshot = JSON.parse(JSON.stringify(demoSnapshot));
    const related = snapshot.datasets.related_data_areas[0];
    snapshot.datasets.related_data_areas = [
      { ...related, RelatedAreaId: "area-1", Pattern: "\\\\files01\\Finance\\AP*", MatchingShares: "1", MatchingItems: "2", ReviewItemCount: "4" },
      { ...related, RelatedAreaId: "area-2", Pattern: "\\\\files01\\Finance\\AR*", MatchingShares: "1", MatchingItems: "3", ReviewItemCount: "6" }
    ];
    const packet = snapshot.datasets.owner_review_packets[0];
    snapshot.datasets.owner_review_packets = [
      { ...packet, ReviewPacketId: "packet-1", Pattern: "\\\\files01\\Finance\\AP*", MatchingItems: "2", ConflictCount: "4" },
      { ...packet, ReviewPacketId: "packet-2", Pattern: "\\\\files01\\Finance\\AR*", MatchingItems: "3", ConflictCount: "6" }
    ];

    const dashboard = deriveDashboard(normalizeSnapshot(snapshot));

    expect(dashboard.migrationClusters).toHaveLength(1);
    expect(dashboard.migrationClusters[0].shares).toBe(2);
    expect(dashboard.migrationClusters[0].reviewItems).toBe(10);
    expect(dashboard.migrationClusters[0].raw.ClusterRowCount).toBe("2");
    expect(dashboard.reviewQueue).toHaveLength(1);
    expect(dashboard.reviewQueue[0].matchingItems).toBe(5);
    expect(dashboard.reviewQueue[0].conflictCount).toBe(10);
  });
});
