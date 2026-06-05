ShareSurfer live validation closeout checklist.

**Overall Status**
- Ready for proof review: `True`
- Close GitHub proof issues only after a human reviewer agrees the live run proves the issue acceptance criteria.

**Go Gates**
- [PASS] V1 acceptance passed with `0` failed checks.
- [PASS] Scan manifest proves file-object scanning when live evidence is required.
- [PASS] Collector environment evidence exists so reviewers can see the host, PowerShell, module, and command context for the run.
- [PASS] Dashboard review evidence exists so reviewers can confirm the offline report rendered and was operator-reviewed.
- [PASS] Lab population criteria prove the enterprise user, group, and share counts requested for validation.
- [PASS] Lab fixture criteria prove real files, deep paths, long-path policy fixtures, and the configured disk budget.
- [PASS] Scanner permission criteria prove share permissions, folder ACLs, and file ACL entries were collected.
- [PASS] Scanner finding criteria prove ownership evidence, deep explicit ACE findings, and inheritance-break findings.
- [PASS] Scanner conflict criteria prove share-vs-NTFS conflicts and collection-error evidence were recorded.
- [PASS] Identity enrichment criteria prove employee identifiers, two-level manager chains, and the selected OBS/OID attribute.
- [PASS] Security group criteria prove recursive group expansion and OBS/OID coverage for permission-bearing groups.
- [PASS] Live evidence gate passed with `0` fallback criteria.
- [PASS] Required preflight blockers: `0`.
- [PASS] Failed required validation criteria: `0`.
- [PASS] Blocking live-evidence review rows: `0`.
- [PASS] Redacted support bundle gate: `Optional rich support bundle skipped`.
- [PASS] Issue comment bodies exist for issues #1, #3, #5, and #6.
- [PASS] Issue comment publish preview is dry-run only and has no posted URLs.

**Review If Not Ready**
- Preflight blockers: `None`
- Failed criteria: `None`
- Scan manifest file-object check: `Passed`
- Collector environment check: `Passed`
- Dashboard review check: `Passed`
- Lab population criteria check: `Passed`
- Lab fixture criteria check: `Passed`
- Scanner permission criteria check: `Passed`
- Scanner finding criteria check: `Passed`
- Scanner conflict and collection-error criteria check: `Passed`
- Identity enrichment criteria check: `Passed`
- Security group expansion criteria check: `Passed`
- Blocking live-evidence criteria: `None`
- Missing issue comment targets: `None`
- Missing publish preview targets: `None`

**Next Actions**
- If ready, review every generated issue comment Markdown file before posting.
- Post proof comments with the publish helper after review, then read back the GitHub comments.
- Keep raw run folders inside the trusted lab environment. When a redacted support bundle is generated, share only the redacted bundle outside that environment.
- If not ready, fix the rows named above and rerun the validation from a fresh timestamped output folder.

**Safe Sharing Note**
- This checklist intentionally omits raw run paths, raw identities, employee identifiers, manager chains, and evidence detail values.
