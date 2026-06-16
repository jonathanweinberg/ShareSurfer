# ShareSurfer Lab Evidence

This folder contains tracked ShareSurfer lab evidence. It is synthetic/project-lab evidence, created in purpose-built ShareSurfer test labs so reviewers can see what the tool produced during known validation runs.

The values in these folders can look like real host names, domains, user names, shares, IP addresses, and Windows paths. Read them as lab labels from a controlled project environment, not as production customer data and not as systems you should try to connect to.

## Why this is tracked

ShareSurfer is an evidence tool, so the project keeps a small number of lab proof packs in source control. They help a first-time reader answer practical questions without needing to rebuild the same lab:

- What files does a scan/export create?
- What does a report or dashboard package look like after a run?
- What does validation evidence look like when a feature is accepted?
- Which CSVs, summaries, and review artifacts should an admin expect to hand to reviewers?

Keeping the evidence also gives maintainers a stable reference when documentation, packaging, or validation wording changes.

## What it proves

The tracked evidence proves that ShareSurfer produced the recorded outputs in the project lab run named by each folder. Depending on the folder, that may include:

- lab plan and preflight evidence
- normalized scan/export CSVs
- report or dashboard output
- validation summaries and checklists
- focused provider comparison evidence
- redacted support-bundle examples

Use each snapshot README for the exact run purpose, counts, and acceptance notes.

## What it does not prove

This evidence is not production evidence from a customer environment. It does not prove that your domain, file servers, groups, ownership data, or network rules are healthy. It also does not prove that every possible Windows, SMB, Active Directory, or filesystem setup behaves the same way.

Treat it as a public project proof pack and example dataset. For your own environment, run ShareSurfer against approved targets, validate the fresh export, and review the resulting evidence with your normal admin and business-review process.

## How to read host, domain, and path-looking values

Some rows contain values such as lab host names, domain-looking names, UNC paths, local Windows paths, account names, and IP-looking addresses. Those values are part of the synthetic/project-lab story for the snapshot.

When reading them:

- Use them to understand the shape of ShareSurfer evidence.
- Do not treat them as production inventory.
- Do not copy them into commands for your environment.
- Replace them with your approved collector host, domain, share, path, and owner-mapping values when running ShareSurfer yourself.

## Snapshot Index

- [Windows/AD enterprise lab evidence - 2026-06-05](windows-ad-enterprise-20260605-101639/README.md)
- [Issue #184 native SMB/RPC evidence](issue184-native-smb-rpc-20260610-183619/README.md)
