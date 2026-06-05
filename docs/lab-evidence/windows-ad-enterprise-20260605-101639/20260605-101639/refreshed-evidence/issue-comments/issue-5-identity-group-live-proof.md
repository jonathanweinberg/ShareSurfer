ShareSurfer live validation update for issue #5: identity enrichment and recursive security group expansion.

**Focus**
- Prove directory-backed identity enrichment, employee identifiers, manager chains, runtime OBS/OID coverage, recursive group expansion, and permission-bearing group OBS/OID coverage from live evidence.

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
| `EnterpriseEmployeeIdentifierCoverage` | `Passed` | `255` | `1` | `users with employee identifiers` |
| `EnterpriseManagerChainCoverage` | `Passed` | `252` | `1` | `two-level manager chains` |
| `EnterpriseUserObsCoverage` | `Passed` | `255` | `1` | `users with OBS` |
| `EnterpriseGroupExpansion` | `Passed` | `1253` | `1` | `group edges` |
| `EnterprisePermissionGroupObsCoverage` | `Passed` | `498` | `498` | `groups with OBS` |

**Related Acceptance Checks**
| Acceptance Check | Status |
| --- | --- |
| `NormalizedCsvExport` | `Passed` |
| `LiveEvidenceReview` | `Passed` |
| `LiveEvidenceGate` | `Passed` |

**Suggested Next Step**
- Evidence is ready for human review against this issue. Close only after the reviewer agrees the live run proves the acceptance criteria.

**Safe Sharing Note**
- This comment intentionally omits raw run paths, raw identities, employee identifiers, manager chains, and evidence detail values.
