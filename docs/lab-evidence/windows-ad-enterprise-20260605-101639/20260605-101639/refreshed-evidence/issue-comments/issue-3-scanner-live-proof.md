ShareSurfer live validation update for issue #3: scanner core for SMB shares, ACLs, ownership, and inheritance.

**Focus**
- Prove the scanner collected share permissions, ACL entries, file ACLs, ownership evidence, deep explicit ACE findings, inheritance breaks, conflicts, collection-error evidence, normalized exports, and raw event logs.

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
| `EnterpriseSharePermissions` | `Passed` | `500` | `250` | `share permission rows` |
| `EnterpriseAclEntries` | `Passed` | `41278` | `256` | `acl rows` |
| `EnterpriseFileAclEntries` | `Passed` | `11244` | `1` | `file acl rows` |
| `EnterpriseOwnershipEvidence` | `Passed` | `5726` | `1` | `owned items` |
| `EnterpriseDeepExplicitAceFindings` | `Passed` | `251` | `1` | `findings` |
| `EnterpriseBrokenInheritanceFindings` | `Passed` | `4` | `1` | `findings` |
| `EnterpriseConflictFindings` | `Passed` | `32309` | `1` | `conflicts` |
| `EnterpriseCollectionErrors` | `Passed` | `4` | `0` | `collection error rows` |

**Related Acceptance Checks**
| Acceptance Check | Status |
| --- | --- |
| `NormalizedCsvExport` | `Passed` |
| `ScanManifestIncludeFiles` | `Passed` |
| `RawEventLog` | `Passed` |
| `LabValidationCriteria` | `Passed` |
| `LiveEvidenceGate` | `Passed` |

**Suggested Next Step**
- Evidence is ready for human review against this issue. Close only after the reviewer agrees the live run proves the acceptance criteria.

**Safe Sharing Note**
- This comment intentionally omits raw run paths, raw identities, employee identifiers, manager chains, and evidence detail values.
