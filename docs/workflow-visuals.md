# ShareSurfer Workflow Visuals

This page gives operators and business reviewers a visual map of the V1 workflow. The committed visuals are intentionally plain, offline, and airgap-friendly.

## Workflow Overview

![ShareSurfer workflow overview](visuals/share-surfer-workflow-concept.png)

## README Flow Guides

The README includes three descriptive workflow maps for first-time readers:

![First scan to owner review workflow](visuals/readme-flow-guides/first-scan-owner-review.png)

![Locked-down collector to dashboard host workflow](visuals/readme-flow-guides/locked-down-collector-dashboard-host.png)

![Migration discovery and cleanup planning workflow](visuals/readme-flow-guides/migration-discovery-cleanup-planning.png)

Use [workflow-guides.md](workflow-guides.md) for the step-by-step version with commands, handoff checks, and stop gates.

## Visual Field Guide

Use [visual-field-guide.md](visual-field-guide.md) for the richer diagram set that explains the evidence pipeline, share gate vs NTFS permissions, identity enrichment, migration discovery, diagnostics, and redacted support handoff.

![ShareSurfer evidence pipeline](visuals/field-guide/evidence-pipeline.png)

![Share gate vs NTFS permissions](visuals/field-guide/share-gate-ntfs-model.png)

![Identity and org enrichment](visuals/field-guide/identity-org-enrichment.png)

![Migration discovery signals](visuals/field-guide/migration-discovery-signals.png)

![Diagnostics and trust review](visuals/field-guide/diagnostics-trust-review.png)

![Redacted support handoff](visuals/field-guide/redacted-support-handoff.png)

## Locked-Down Collection

![Locked-down collector workflow](visuals/nonpermissive-collector-workflow.svg)

Use this visual when explaining collection from a nonpermissive Windows environment. The collector stays read-only, writes CSV/report evidence, and keeps the raw dataset inside the trusted boundary until transfer is approved.

## Dataset Transfer and Dashboard Review

![Dataset transfer to dashboard host](visuals/dataset-transfer-dashboard-workflow.svg)

Use this visual when explaining the two-host workflow: collect in the restricted network, move the validated dataset by an approved process, and open the report or packaged standalone dashboard on a more permissive review workstation.

## Collector To Report

![Collector to report workflow](visuals/collector-to-report.svg)

Use this visual when explaining how raw Windows and Samba-style share data becomes normalized CSVs and an offline report.

## Enterprise Lab Validation

![Enterprise lab validation workflow](visuals/enterprise-lab-validation.svg)

Use this visual when planning the scaled Windows/AD lab run. The validation criteria must prove multi-thousand users, hundreds of SMB shares, deep paths with real files, and generated lab file data under the configured budget. The default budget is 2 GiB; 8 GiB is reserved for explicit stress runs. Final enterprise proof should use the live-evidence gate so required criteria are backed by directory, scan, or filesystem evidence.

## Redacted Support Bundle

![Redacted support bundle workflow](visuals/support-bundle-diagnostics.svg)

Use this visual when explaining what can be shared outside the trusted team. Raw exports stay internal; redacted CSVs, bundle manifests, row counts, and hashes can be attached to support cases.

## Management Overview

Use [management-overview.html](management-overview.html) when briefing non-technical leaders. It is a high-level management overview slide that explains purpose, business value, migration-risk findings, owner/business-unit pivots, and expected outcomes without requiring Windows or AD expertise.

## Dashboard Screenshots

The dashboard screenshots in `docs/visuals` use synthetic CONTOSO-style demo data and show the current offline report, not future concept art. See [visual asset notes](visuals/README.md) for the screenshot list and refresh command.
