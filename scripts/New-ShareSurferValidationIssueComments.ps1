[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $RunRoot,

    [string] $OutputDirectory = '',

    [string] $Repository = 'jonathanweinberg/ShareSurfer',

    [switch] $PassThru
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function ConvertTo-ShareSurferIssueCommentBool {
    param($Value)

    if ($null -eq $Value) {
        return $false
    }

    $text = [string]$Value
    return ($text -eq 'True' -or $text -eq 'true' -or $text -eq '1')
}

function Get-ShareSurferIssueCommentJson {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return $null
    }

    Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

function Get-ShareSurferIssueCommentCsv {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return @()
    }

    @(Import-Csv -LiteralPath $Path)
}

function Add-ShareSurferIssueCommentLine {
    param(
        [System.Collections.ArrayList] $Lines,

        [string] $Text = ''
    )

    [void]$Lines.Add($Text)
}

function ConvertTo-ShareSurferIssueCommentStatus {
    param(
        $Row
    )

    if ($null -eq $Row) {
        return 'Missing'
    }

    $passed = $false
    if ($Row.PSObject.Properties['Passed']) {
        $passed = ConvertTo-ShareSurferIssueCommentBool $Row.Passed
    }

    if (-not $passed) {
        return 'Needs review'
    }

    if ($Row.PSObject.Properties['EvidenceStatus']) {
        $status = [string]$Row.EvidenceStatus
        if (-not [string]::IsNullOrWhiteSpace($status)) {
            return $status
        }
    }

    return 'Passed'
}

function ConvertTo-ShareSurferIssueCommentValue {
    param($Value)

    if ($null -eq $Value) {
        return ''
    }

    $text = [string]$Value
    if ([string]::IsNullOrWhiteSpace($text)) {
        return ''
    }

    $text.Replace('|', '/').Replace("`r", ' ').Replace("`n", ' ')
}

function Add-ShareSurferIssueCommentCriteriaTable {
    param(
        [System.Collections.ArrayList] $Lines,

        [object[]] $CriteriaRows,

        [Parameter(Mandatory = $true)]
        [string[]] $Names
    )

    Add-ShareSurferIssueCommentLine -Lines $Lines -Text '| Evidence | Status | Actual | Minimum | Unit |'
    Add-ShareSurferIssueCommentLine -Lines $Lines -Text '| --- | --- | ---: | ---: | --- |'

    foreach ($name in @($Names)) {
        $row = @($CriteriaRows | Where-Object { [string]$_.Name -eq $name } | Select-Object -First 1)
        if ($row.Count -eq 0) {
            Add-ShareSurferIssueCommentLine -Lines $Lines -Text ('| `{0}` | Missing |  |  |  |' -f $name)
            continue
        }

        $current = $row[0]
        Add-ShareSurferIssueCommentLine -Lines $Lines -Text ('| `{0}` | `{1}` | `{2}` | `{3}` | `{4}` |' -f
            (ConvertTo-ShareSurferIssueCommentValue $current.Name),
            (ConvertTo-ShareSurferIssueCommentValue (ConvertTo-ShareSurferIssueCommentStatus -Row $current)),
            (ConvertTo-ShareSurferIssueCommentValue $current.ActualValue),
            (ConvertTo-ShareSurferIssueCommentValue $current.MinimumValue),
            (ConvertTo-ShareSurferIssueCommentValue $current.Unit))
    }
}

function Add-ShareSurferIssueCommentCheckTable {
    param(
        [System.Collections.ArrayList] $Lines,

        [object[]] $Checks,

        [Parameter(Mandatory = $true)]
        [string[]] $Names
    )

    Add-ShareSurferIssueCommentLine -Lines $Lines -Text '| Acceptance Check | Status |'
    Add-ShareSurferIssueCommentLine -Lines $Lines -Text '| --- | --- |'

    foreach ($name in @($Names)) {
        $row = @($Checks | Where-Object { [string]$_.Name -eq $name } | Select-Object -First 1)
        if ($row.Count -eq 0) {
            Add-ShareSurferIssueCommentLine -Lines $Lines -Text ('| `{0}` | Missing |' -f $name)
            continue
        }

        $status = if (ConvertTo-ShareSurferIssueCommentBool $row[0].Passed) { 'Passed' } else { 'Needs review' }
        Add-ShareSurferIssueCommentLine -Lines $Lines -Text ('| `{0}` | `{1}` |' -f (ConvertTo-ShareSurferIssueCommentValue $row[0].Name), $status)
    }
}

function Test-ShareSurferIssueCommentRowsPassed {
    param(
        [object[]] $Rows,
        [string[]] $Names
    )

    foreach ($name in @($Names)) {
        $row = @($Rows | Where-Object { [string]$_.Name -eq $name } | Select-Object -First 1)
        if ($row.Count -eq 0) {
            return $false
        }
        if (-not (ConvertTo-ShareSurferIssueCommentBool $row[0].Passed)) {
            return $false
        }
        if ($row[0].PSObject.Properties['EvidenceStatus']) {
            if (@('Failed', 'MissingEvidenceSource', 'PlanOnly', 'EvidenceUnavailable') -contains [string]$row[0].EvidenceStatus) {
                return $false
            }
        }
    }

    return $true
}

function New-ShareSurferIssueCommentBody {
    param(
        [Parameter(Mandatory = $true)]
        [int] $IssueNumber,

        [Parameter(Mandatory = $true)]
        [string] $Title,

        [Parameter(Mandatory = $true)]
        [string] $Focus,

        [Parameter(Mandatory = $true)]
        [string[]] $CriteriaNames,

        [Parameter(Mandatory = $true)]
        [string[]] $AcceptanceCheckNames,

        [object[]] $CriteriaRows,

        [object[]] $AcceptanceChecks,

        $AcceptanceSummary,
        $LiveEvidence,
        [object[]] $BlockingRows,
        [string] $BundleValidation,
        [string] $BundleLeakCount,
        [bool] $IssueCriteriaPassed,
        [bool] $AcceptanceChecksPassed
    )

    $acceptanceValid = if ($null -eq $AcceptanceSummary) { 'Missing' } else { [string](ConvertTo-ShareSurferIssueCommentBool $AcceptanceSummary.IsValid) }
    $failedCheckCount = if ($null -eq $AcceptanceSummary) { 'Unknown' } else { [string]$AcceptanceSummary.FailedCheckCount }
    $liveEvidenceValid = if ($null -eq $LiveEvidence) { 'Missing' } else { [string](ConvertTo-ShareSurferIssueCommentBool $LiveEvidence.IsValid) }
    $fallbackCount = if ($null -eq $LiveEvidence) { 'Unknown' } else { [string]$LiveEvidence.FallbackCount }
    $readyForReview = ($IssueCriteriaPassed -and $AcceptanceChecksPassed -and $acceptanceValid -eq 'True' -and $liveEvidenceValid -eq 'True' -and [string]$BundleValidation -eq 'True' -and [string]$BundleLeakCount -eq '0')

    $lines = New-Object System.Collections.ArrayList
    Add-ShareSurferIssueCommentLine -Lines $lines -Text ('ShareSurfer live validation update for issue #{0}: {1}.' -f $IssueNumber, $Title)
    Add-ShareSurferIssueCommentLine -Lines $lines
    Add-ShareSurferIssueCommentLine -Lines $lines -Text '**Focus**'
    Add-ShareSurferIssueCommentLine -Lines $lines -Text ('- {0}' -f $Focus)
    Add-ShareSurferIssueCommentLine -Lines $lines
    Add-ShareSurferIssueCommentLine -Lines $lines -Text '**Overall Run Status**'
    Add-ShareSurferIssueCommentLine -Lines $lines -Text ('- V1 acceptance valid: `{0}`' -f $acceptanceValid)
    Add-ShareSurferIssueCommentLine -Lines $lines -Text ('- Failed acceptance checks: `{0}`' -f $failedCheckCount)
    Add-ShareSurferIssueCommentLine -Lines $lines -Text ('- Live evidence valid: `{0}`' -f $liveEvidenceValid)
    Add-ShareSurferIssueCommentLine -Lines $lines -Text ('- Fallback criteria count: `{0}`' -f $fallbackCount)
    Add-ShareSurferIssueCommentLine -Lines $lines -Text ('- Blocking live review rows: `{0}`' -f @($BlockingRows).Count)
    Add-ShareSurferIssueCommentLine -Lines $lines -Text ('- Redacted bundle validation: `{0}`' -f $BundleValidation)
    Add-ShareSurferIssueCommentLine -Lines $lines -Text ('- Redaction leak count: `{0}`' -f $BundleLeakCount)
    Add-ShareSurferIssueCommentLine -Lines $lines
    Add-ShareSurferIssueCommentLine -Lines $lines -Text '**Issue-Specific Evidence**'
    Add-ShareSurferIssueCommentCriteriaTable -Lines $lines -CriteriaRows $CriteriaRows -Names $CriteriaNames
    Add-ShareSurferIssueCommentLine -Lines $lines
    Add-ShareSurferIssueCommentLine -Lines $lines -Text '**Related Acceptance Checks**'
    Add-ShareSurferIssueCommentCheckTable -Lines $lines -Checks $AcceptanceChecks -Names $AcceptanceCheckNames
    Add-ShareSurferIssueCommentLine -Lines $lines
    Add-ShareSurferIssueCommentLine -Lines $lines -Text '**Suggested Next Step**'
    if ($readyForReview) {
        Add-ShareSurferIssueCommentLine -Lines $lines -Text '- Evidence is ready for human review against this issue. Close only after the reviewer agrees the live run proves the acceptance criteria.'
    }
    else {
        Add-ShareSurferIssueCommentLine -Lines $lines -Text '- Keep this issue open until the blocking or missing evidence above is resolved and the live run is rerun.'
    }
    Add-ShareSurferIssueCommentLine -Lines $lines
    Add-ShareSurferIssueCommentLine -Lines $lines -Text '**Safe Sharing Note**'
    Add-ShareSurferIssueCommentLine -Lines $lines -Text '- This comment intentionally omits raw run paths, raw identities, employee identifiers, manager chains, and evidence detail values.'

    $lines -join [Environment]::NewLine
}

if (-not (Test-Path -LiteralPath $RunRoot)) {
    throw ('Run root not found: {0}' -f $RunRoot)
}

if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path $RunRoot 'issue-comments'
}
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null

$acceptanceSummary = Get-ShareSurferIssueCommentJson -Path (Join-Path $RunRoot 'v1-acceptance-summary.json')
$acceptanceResult = Get-ShareSurferIssueCommentJson -Path (Join-Path $RunRoot 'v1-acceptance.json')
$liveEvidence = Get-ShareSurferIssueCommentJson -Path (Join-Path $RunRoot 'live-evidence.json')
$criteriaRows = @(Get-ShareSurferIssueCommentCsv -Path (Join-Path $RunRoot 'lab-validation-criteria.csv'))
$liveEvidenceReview = @(Get-ShareSurferIssueCommentCsv -Path (Join-Path $RunRoot 'live-evidence-review.csv'))
$bundleManifestRows = @(Get-ShareSurferIssueCommentCsv -Path (Join-Path (Join-Path $RunRoot 'support-bundle-redacted') 'support_bundle_manifest.csv'))
$acceptanceChecks = if ($null -eq $acceptanceResult) { @() } else { @($acceptanceResult.Checks) }

$blockingStatuses = @('Failed', 'MissingEvidenceSource', 'PlanOnly', 'EvidenceUnavailable')
$blockingRows = @($liveEvidenceReview | Where-Object { [string]$_.Required -eq 'True' -and $blockingStatuses -contains [string]$_.EvidenceStatus })
$bundleValidation = 'Missing'
$bundleLeakCount = 'Unknown'
if ($bundleManifestRows.Count -gt 0) {
    $bundleValidation = [string]$bundleManifestRows[0].ValidationIsValid
    $bundleLeakCount = [string]$bundleManifestRows[0].RedactionLeakCount
}

$issueDefinitions = @(
    [pscustomobject]@{
        IssueNumber = 1
        Slug = 'lab-fixture-live-proof'
        Title = 'lab fixture system for AD users, groups, shares, and ACL scenarios'
        Focus = 'Prove the enterprise ShareSurferLab fixture was created and scanned with the expected users, groups, shares, files, deep paths, long-path policy fixtures, and disk budget.'
        Criteria = @('EnterpriseUserPopulation', 'EnterpriseSharePopulation', 'EnterpriseRealFiles', 'EnterpriseDeepPaths', 'EnterpriseLongPathPolicy', 'EnterpriseDiskBudget')
        Checks = @('LabPreflight', 'LabValidationCriteria', 'LiveEvidenceGate', 'LabRunSupportBundleEvidence')
    },
    [pscustomobject]@{
        IssueNumber = 3
        Slug = 'scanner-live-proof'
        Title = 'scanner core for SMB shares, ACLs, ownership, and inheritance'
        Focus = 'Prove the scanner collected share permissions, ACL entries, file ACLs, deep explicit ACE findings, inheritance breaks, conflicts, collection-error evidence, normalized exports, and raw event logs.'
        Criteria = @('EnterpriseSharePermissions', 'EnterpriseAclEntries', 'EnterpriseFileAclEntries', 'EnterpriseDeepExplicitAceFindings', 'EnterpriseBrokenInheritanceFindings', 'EnterpriseConflictFindings', 'EnterpriseCollectionErrors')
        Checks = @('NormalizedCsvExport', 'RawEventLog', 'LabValidationCriteria', 'LiveEvidenceGate')
    },
    [pscustomobject]@{
        IssueNumber = 5
        Slug = 'identity-group-live-proof'
        Title = 'identity enrichment and recursive security group expansion'
        Focus = 'Prove directory-backed identity enrichment, employee identifiers, manager chains, runtime OBS/OID coverage, recursive group expansion, and permission-bearing group OBS/OID coverage from live evidence.'
        Criteria = @('EnterpriseUserPopulation', 'EnterpriseEmployeeIdentifierCoverage', 'EnterpriseManagerChainCoverage', 'EnterpriseUserObsCoverage', 'EnterpriseGroupExpansion', 'EnterprisePermissionGroupObsCoverage')
        Checks = @('NormalizedCsvExport', 'LiveEvidenceReview', 'LiveEvidenceGate')
    },
    [pscustomobject]@{
        IssueNumber = 6
        Slug = 'dashboard-live-proof'
        Title = 'dynamic offline HTML report package'
        Focus = 'Prove the offline report and business review exports remain usable with enterprise lab output, owner review packets, related data areas, and redacted support evidence.'
        Criteria = @('EnterpriseOwnerRiskPivots', 'EnterpriseRelatedDataAreas', 'EnterpriseOwnerReviewPackets')
        Checks = @('OfflineReport', 'OwnerReviewPackets', 'RedactedSupportBundle', 'LabRunSupportBundleEvidence')
    }
)

$manifestRows = New-Object System.Collections.ArrayList
$postCommands = New-Object System.Collections.ArrayList
foreach ($definition in @($issueDefinitions)) {
    $criteriaPassed = Test-ShareSurferIssueCommentRowsPassed -Rows $criteriaRows -Names $definition.Criteria
    $checksPassed = Test-ShareSurferIssueCommentRowsPassed -Rows $acceptanceChecks -Names $definition.Checks
    $body = New-ShareSurferIssueCommentBody -IssueNumber $definition.IssueNumber -Title $definition.Title -Focus $definition.Focus -CriteriaNames $definition.Criteria -AcceptanceCheckNames $definition.Checks -CriteriaRows $criteriaRows -AcceptanceChecks $acceptanceChecks -AcceptanceSummary $acceptanceSummary -LiveEvidence $liveEvidence -BlockingRows $blockingRows -BundleValidation $bundleValidation -BundleLeakCount $bundleLeakCount -IssueCriteriaPassed:$criteriaPassed -AcceptanceChecksPassed:$checksPassed
    $fileName = 'issue-{0}-{1}.md' -f $definition.IssueNumber, $definition.Slug
    $filePath = Join-Path $OutputDirectory $fileName
    Set-Content -LiteralPath $filePath -Value $body -Encoding UTF8

    [void]$manifestRows.Add([pscustomobject]@{
        IssueNumber = [int]$definition.IssueNumber
        FileName = $fileName
        CriteriaPassed = [bool]$criteriaPassed
        AcceptanceChecksPassed = [bool]$checksPassed
        BlockingLiveReviewRows = @($blockingRows).Count
        OutputPath = $filePath
    })

    if (-not [string]::IsNullOrWhiteSpace($Repository)) {
        [void]$postCommands.Add(('gh issue comment {0} --repo {1} --body-file "{2}"' -f $definition.IssueNumber, $Repository, $filePath))
    }
}

$manifestPath = Join-Path $OutputDirectory 'issue-comment-manifest.csv'
@($manifestRows) | Export-Csv -LiteralPath $manifestPath -NoTypeInformation -Encoding UTF8

if ($postCommands.Count -gt 0) {
    Set-Content -LiteralPath (Join-Path $OutputDirectory 'post-commands.txt') -Value @($postCommands) -Encoding UTF8
}

if ($PassThru) {
    @($manifestRows)
}
