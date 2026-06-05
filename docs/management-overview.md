# ShareSurfer Management Overview

This artifact gives non-technical leaders a plain-language view of why ShareSurfer exists and what outcomes to expect from a scan.

## Purpose

ShareSurfer helps teams understand who can access shared business data before cleanup, audit, ownership review, or migration work.

Most file-share environments have years of accumulated permissions. Access can be granted at the share level, the folder level, the file level, or through nested security groups. ShareSurfer collects those layers and turns them into exports and reports that business owners can review.

## Business Value

ShareSurfer supports business value by:

- Giving business units easier-to-read views of complex file-share access.
- Showing which owners or managers should review access.
- Exposing security groups so assigned rights can be browsed and explained.
- Reducing migration surprises before moving shares to Azure Files or another platform.
- Creating repeatable CSV evidence for Excel, Power BI, audit, and remediation tracking.
- Producing redacted support bundles so issues can be investigated without sharing raw names and paths.

## Migration-Risk Findings

ShareSurfer highlights migration-risk findings such as:

- Broken inheritance where permissions stop following the parent folder.
- Explicit permissions added deep inside a folder tree.
- Paths that exceed the organization's operational migration threshold.
- Conflicts between share-level permissions and file or folder permissions.
- Partial data where a scan could not prove all metadata.

Path note: Microsoft documents Azure Files limits of 255-character path components and 2,048-character full paths. ShareSurfer's default 256-character full-path warning is an operational migration policy warning.

## Owner/Business-Unit Pivots

The main goal is to help route findings to the right people.

ShareSurfer can pivot access and findings by:

- Data owner.
- Business unit.
- OBS or OID path from a selected extension attribute.
- Manager and manager's manager.
- Security group and expanded membership.
- Share, folder, file, and path pattern.

## Migration Discovery

ShareSurfer also helps migration teams avoid splitting related data across waves. The report can group areas that appear to belong together because they share the same owner, business unit, path pattern, permission-bearing group, or review-risk signal. This is not migration approval; it is a starting point for confirming ownership and deciding what should move together.

## Expected Outcomes

After a useful scan, leaders should expect:

- A validated CSV export set.
- An offline report that business reviewers can open locally.
- A list of high-priority access conflicts and migration risks.
- A clearer owner or business-unit view for each reviewed share.
- A related-data view for identifying like-owned shares, folders, and files before migration planning.
- Redacted support evidence when the project team needs help diagnosing a bug.
- A repeatable process for rescanning after cleanup.

## Example Report Views

Dashboard overview:

![ShareSurfer dashboard overview](visuals/report-dashboard-overview.png)

Owner review workbench:

![ShareSurfer review workbench](visuals/report-dashboard-workbench.png)

Findings drilldown:

![ShareSurfer findings drilldown](visuals/report-dashboard-findings.png)

Migration discovery:

![ShareSurfer migration discovery view](visuals/report-dashboard-migration.png)

## Suggested Leadership Message

ShareSurfer is not changing permissions. It is creating understandable evidence so business owners can decide what should be cleaned up before migration or audit work. The expected result is fewer surprises, clearer ownership, and a prioritized remediation list.

## Offline Slide

Open [management-overview.html](management-overview.html) for a one-page management briefing slide.
