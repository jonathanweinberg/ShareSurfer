ShareSurfer live validation update for issue #1: lab fixture system for AD users, groups, shares, and ACL scenarios.

**Focus**
- Prove the enterprise ShareSurferLab fixture was created and scanned with the expected users, groups, shares, files, deep paths, long-path policy fixtures, and disk budget.

**Overall Run Status**
- V1 acceptance valid: `True`
- Failed acceptance checks: `0`
- Live evidence valid: `True`
- Fallback criteria count: `0`
- Blocking live review rows: `0`
- Redacted bundle validation: `SkippedOptional`
- Redaction leak count: `0`

**Issue-Specific Evidence**
| Evidence | Status | Actual | Minimum | Unit |
| --- | --- | ---: | ---: | --- |
| `EnterpriseUserPopulation` | `Passed` | `2500` | `2500` | `users` |
| `EnterpriseGroupPopulation` | `Passed` | `500` | `500` | `groups` |
| `EnterpriseSharePopulation` | `Passed` | `250` | `250` | `shares` |
| `EnterpriseRealFiles` | `Passed` | `2251` | `2000` | `file fixtures` |
| `EnterpriseDeepPaths` | `Passed` | `4201` | `1` | `deep file fixtures` |
| `EnterpriseLongPathPolicy` | `Passed` | `2` | `1` | `long-path scenarios` |
| `EnterpriseDiskBudget` | `Passed` | `1` | `1` | `pass/fail` |

**Related Acceptance Checks**
| Acceptance Check | Status |
| --- | --- |
| `CollectorEnvironment` | `Passed` |
| `LabPreflight` | `Passed` |
| `LabValidationCriteria` | `Passed` |
| `LiveEvidenceGate` | `Passed` |
| `LabRunSupportBundleEvidence` | `Passed` |

**Suggested Next Step**
- Evidence is ready for human review against this issue. Close only after the reviewer agrees the live run proves the acceptance criteria.

**Safe Sharing Note**
- This comment intentionally omits raw run paths, raw identities, employee identifiers, manager chains, and evidence detail values.
