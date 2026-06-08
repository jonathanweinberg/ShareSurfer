import { describe, expect, test } from "vitest";
import { deriveDashboard, normalizeSnapshot } from "./deriveDashboard";
import { demoSnapshot } from "./fixtures";

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
