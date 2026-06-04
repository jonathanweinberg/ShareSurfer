# ShareSurfer Workflow Visuals

This page gives operators and business reviewers a visual map of the V1 workflow. The committed SVGs are intentionally plain, offline, and airgap-friendly. An image-gen2 visual concept was also generated and committed to guide the visual language: a clean enterprise workflow from SMB shares through ACL collection, identity enrichment, CSV exports, offline reporting, and redacted support bundles.

## Image-Gen2 Concept

![Image-gen2 workflow concept](visuals/share-surfer-workflow-concept.png)

## Collector To Report

![Collector to report workflow](visuals/collector-to-report.svg)

Use this visual when explaining how raw Windows and Samba-style share data becomes normalized CSVs and an offline report.

## Enterprise Lab Validation

![Enterprise lab validation workflow](visuals/enterprise-lab-validation.svg)

Use this visual when planning the scaled Windows/AD lab run. The validation criteria must prove multi-thousand users, hundreds of SMB shares, deep paths with real files, and less than 8 GB of generated lab file data.

## Redacted Support Bundle

![Redacted support bundle workflow](visuals/support-bundle-diagnostics.svg)

Use this visual when explaining what can be shared outside the trusted team. Raw exports stay internal; redacted CSVs, bundle manifests, row counts, and hashes can be attached to support cases.
