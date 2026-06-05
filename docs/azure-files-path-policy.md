# Azure Files Path Policy

ShareSurfer V1 separates Azure Files hard limits from ShareSurfer's operational migration warnings.

## Azure Files Hard Limits

Microsoft documents these Azure Files path limits:

- Path component limit: 255 characters for an individual file or directory name segment.
- Full path limit: 2,048 characters.

These are platform limits. A path component over 255 characters or a full path over 2,048 characters should be treated as a hard Azure Files compatibility problem.

## ShareSurfer Operational Warning

ShareSurfer defaults to flagging full paths over 256 characters with the `LongPathOperationalPolicy` finding.

That 256-character threshold is an operational migration policy. It is not the Azure Files full-path hard limit. A path can exceed ShareSurfer's default warning threshold and still be below Azure Files' documented 2,048-character full path limit.

The default exists because migrations often involve tools, scripts, legacy clients, reporting systems, and human review processes that become fragile well before the Azure Files hard limit.

## Scan Setting

The warning threshold is controlled at scan time:

```powershell
Invoke-ShareSurferScan -OutputPath $exportPath -OperationalPathLengthThreshold 256
```

Set a different threshold only when the migration program has a documented path policy.

## How To Interpret Findings

| Condition | Meaning | Typical action |
| --- | --- | --- |
| Full path is 256 characters or less | No default ShareSurfer long-path warning. | Continue normal review. |
| Full path is over 256 and 2,048 or less | Operational migration warning, not necessarily an Azure hard-limit failure. | Review tooling, client, sync, backup, and user workflow impact. |
| Any path component is over 255 | Azure Files hard-limit issue. | Rename or restructure before migration. |
| Full path is over 2,048 | Azure Files hard-limit issue. | Shorten path before migration. |

## Report Language

Use precise wording in reports and stakeholder updates:

- Good: "ShareSurfer flagged this path because it exceeds the operational migration warning threshold of 256 characters."
- Good: "Azure Files documents a 2,048-character full-path limit and 255-character path component limit."
- Avoid: "This path is over 256 characters, so Azure Files does not support it."

## Operator Notes

- Prioritize hard-limit issues first because they block Azure Files compatibility.
- Use operational warnings to estimate remediation effort and migration risk.
- Keep the threshold visible in `scan_manifest.csv` so later reviewers know which policy produced the finding.
