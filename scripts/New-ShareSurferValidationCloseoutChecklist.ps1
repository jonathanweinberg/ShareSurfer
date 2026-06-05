[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $RunRoot,

    [string] $OutputPath = '',

    [switch] $PassThru
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-ShareSurferCloseoutJson {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return $null
    }

    Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

function Get-ShareSurferCloseoutCsv {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return @()
    }

    @(Import-Csv -LiteralPath $Path)
}

function ConvertTo-ShareSurferCloseoutBool {
    param($Value)

    if ($null -eq $Value) {
        return $false
    }

    $text = [string]$Value
    $text -eq 'True' -or $text -eq 'true' -or $text -eq '1'
}

function Add-ShareSurferCloseoutLine {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [System.Collections.ArrayList] $Lines,

        [string] $Text = ''
    )

    [void]$Lines.Add($Text)
}

function Get-ShareSurferCloseoutStatus {
    param(
        [bool] $Passed
    )

    if ($Passed) {
        return '[PASS]'
    }

    '[REVIEW]'
}

function Join-ShareSurferCloseoutNames {
    param(
        $Rows
    )

    $names = @($Rows | ForEach-Object {
            if ($_.PSObject.Properties['Name']) {
                [string]$_.Name
            }
        } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique)

    if ($names.Count -eq 0) {
        return 'None'
    }

    $names -join ', '
}

function Test-ShareSurferCloseoutAcceptanceCheck {
    param(
        $AcceptanceSummary,

        [Parameter(Mandatory = $true)]
        [string] $Name
    )

    if ($null -eq $AcceptanceSummary -or -not $AcceptanceSummary.PSObject.Properties['Checks']) {
        return $false
    }

    $matchingRows = @($AcceptanceSummary.Checks | Where-Object { [string]$_.Name -eq $Name })
    if ($matchingRows.Count -eq 0) {
        return $false
    }

    ConvertTo-ShareSurferCloseoutBool $matchingRows[0].Passed
}

function Test-ShareSurferCloseoutCriteriaRows {
    param(
        [AllowEmptyCollection()]
        $Rows,

        [Parameter(Mandatory = $true)]
        [string[]] $Names
    )

    foreach ($name in $Names) {
        $matchingRows = @($Rows | Where-Object { [string]$_.Name -eq $name })
        if ($matchingRows.Count -eq 0) {
            return $false
        }

        if (-not (ConvertTo-ShareSurferCloseoutBool $matchingRows[0].Passed)) {
            return $false
        }
    }

    $true
}

if (-not (Test-Path -LiteralPath $RunRoot)) {
    throw ('Run root not found: {0}' -f $RunRoot)
}

$acceptanceSummary = Get-ShareSurferCloseoutJson -Path (Join-Path $RunRoot 'v1-acceptance-summary.json')
$liveEvidence = Get-ShareSurferCloseoutJson -Path (Join-Path $RunRoot 'live-evidence.json')
$liveEvidenceReview = @(Get-ShareSurferCloseoutCsv -Path (Join-Path $RunRoot 'live-evidence-review.csv'))
$criteriaRows = @(Get-ShareSurferCloseoutCsv -Path (Join-Path $RunRoot 'lab-validation-criteria.csv'))
$preflightRows = @(Get-ShareSurferCloseoutCsv -Path (Join-Path $RunRoot 'lab-preflight.csv'))
$issueCommentDirectory = Join-Path $RunRoot 'issue-comments'
$issueCommentRows = @(Get-ShareSurferCloseoutCsv -Path (Join-Path $issueCommentDirectory 'issue-comment-manifest.csv'))
$publishPreviewRows = @(Get-ShareSurferCloseoutCsv -Path (Join-Path $RunRoot 'issue-comment-publish-preview.csv'))
$supportBundleDirectory = Join-Path $RunRoot 'support-bundle-redacted'
$bundleManifestRows = @(Get-ShareSurferCloseoutCsv -Path (Join-Path $supportBundleDirectory 'support_bundle_manifest.csv'))

$acceptanceValid = $false
$acceptanceFailedCount = 0
$scanManifestIncludeFilesPassed = $false
$collectorEnvironmentPassed = $false
$dashboardReviewPassed = $false
if ($null -ne $acceptanceSummary) {
    $acceptanceValid = ConvertTo-ShareSurferCloseoutBool $acceptanceSummary.IsValid
    if ($acceptanceSummary.PSObject.Properties['FailedCheckCount']) {
        $acceptanceFailedCount = [int]$acceptanceSummary.FailedCheckCount
    }
    $scanManifestIncludeFilesPassed = Test-ShareSurferCloseoutAcceptanceCheck -AcceptanceSummary $acceptanceSummary -Name 'ScanManifestIncludeFiles'
    $collectorEnvironmentPassed = Test-ShareSurferCloseoutAcceptanceCheck -AcceptanceSummary $acceptanceSummary -Name 'CollectorEnvironment'
    $dashboardReviewPassed = Test-ShareSurferCloseoutAcceptanceCheck -AcceptanceSummary $acceptanceSummary -Name 'DashboardReviewEvidence'
}

$liveEvidenceValid = $false
$fallbackCount = 0
if ($null -ne $liveEvidence) {
    $liveEvidenceValid = ConvertTo-ShareSurferCloseoutBool $liveEvidence.IsValid
    if ($liveEvidence.PSObject.Properties['FallbackCount']) {
        $fallbackCount = [int]$liveEvidence.FallbackCount
    }
}

$failedPreflightRows = @($preflightRows | Where-Object { [string]$_.Required -eq 'True' -and [string]$_.Passed -ne 'True' })
$failedCriteriaRows = @($criteriaRows | Where-Object { [string]$_.Required -eq 'True' -and [string]$_.Passed -ne 'True' })
$blockingStatuses = @('Failed', 'MissingEvidenceSource', 'PlanOnly', 'EvidenceUnavailable')
$blockingReviewRows = @($liveEvidenceReview | Where-Object { [string]$_.Required -eq 'True' -and $blockingStatuses -contains [string]$_.EvidenceStatus })

$bundleValid = $false
$bundleLeakCount = 0
if ($bundleManifestRows.Count -gt 0) {
    $bundleValid = ConvertTo-ShareSurferCloseoutBool $bundleManifestRows[0].ValidationIsValid
    [void][int]::TryParse([string]$bundleManifestRows[0].RedactionLeakCount, [ref]$bundleLeakCount)
}

$identityDirectoryCriteria = @('EnterpriseEmployeeIdentifierCoverage', 'EnterpriseManagerChainCoverage', 'EnterpriseUserObsCoverage')
$groupExpansionCriteria = @('EnterpriseGroupExpansion', 'EnterprisePermissionGroupObsCoverage')
$labPopulationCriteria = @('EnterpriseUserPopulation', 'EnterpriseGroupPopulation', 'EnterpriseSharePopulation')
$labFixtureCriteria = @('EnterpriseRealFiles', 'EnterpriseDeepPaths', 'EnterpriseLongPathPolicy', 'EnterpriseDiskBudget')
$scannerPermissionCriteria = @('EnterpriseSharePermissions', 'EnterpriseAclEntries', 'EnterpriseFileAclEntries')
$scannerFindingCriteria = @('EnterpriseOwnershipEvidence', 'EnterpriseDeepExplicitAceFindings', 'EnterpriseBrokenInheritanceFindings')
$scannerConflictCriteria = @('EnterpriseConflictFindings', 'EnterpriseCollectionErrors')
$identityDirectoryCriteriaPassed = Test-ShareSurferCloseoutCriteriaRows -Rows $criteriaRows -Names $identityDirectoryCriteria
$groupExpansionCriteriaPassed = Test-ShareSurferCloseoutCriteriaRows -Rows $criteriaRows -Names $groupExpansionCriteria
$labPopulationCriteriaPassed = Test-ShareSurferCloseoutCriteriaRows -Rows $criteriaRows -Names $labPopulationCriteria
$labFixtureCriteriaPassed = Test-ShareSurferCloseoutCriteriaRows -Rows $criteriaRows -Names $labFixtureCriteria
$scannerPermissionCriteriaPassed = Test-ShareSurferCloseoutCriteriaRows -Rows $criteriaRows -Names $scannerPermissionCriteria
$scannerFindingCriteriaPassed = Test-ShareSurferCloseoutCriteriaRows -Rows $criteriaRows -Names $scannerFindingCriteria
$scannerConflictCriteriaPassed = Test-ShareSurferCloseoutCriteriaRows -Rows $criteriaRows -Names $scannerConflictCriteria

$expectedIssueNumbers = @('1', '3', '5', '6')
$issueNumbers = @($issueCommentRows | ForEach-Object { [string]$_.IssueNumber } | Sort-Object -Unique)
$missingIssueNumbers = @($expectedIssueNumbers | Where-Object { $issueNumbers -notcontains $_ })
$issueCommentsReady = ($issueCommentRows.Count -ge 4 -and $missingIssueNumbers.Count -eq 0)

$publishIssueNumbers = @($publishPreviewRows | ForEach-Object { [string]$_.IssueNumber } | Sort-Object -Unique)
$missingPublishIssueNumbers = @($expectedIssueNumbers | Where-Object { $publishIssueNumbers -notcontains $_ })
$nonDryRunRows = @($publishPreviewRows | Where-Object { [string]$_.Status -ne 'DryRun' })
$postedRows = @($publishPreviewRows | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_.PostedUrl) })
$publishPreviewReady = ($publishPreviewRows.Count -ge 4 -and $missingPublishIssueNumbers.Count -eq 0 -and $nonDryRunRows.Count -eq 0 -and $postedRows.Count -eq 0)
$missingIssueLabel = if ($missingIssueNumbers.Count -eq 0) { 'None' } else { $missingIssueNumbers -join ', ' }
$missingPublishIssueLabel = if ($missingPublishIssueNumbers.Count -eq 0) { 'None' } else { $missingPublishIssueNumbers -join ', ' }

$readyForProofReview = (
    $acceptanceValid -and
    $scanManifestIncludeFilesPassed -and
    $collectorEnvironmentPassed -and
    $dashboardReviewPassed -and
    $labPopulationCriteriaPassed -and
    $labFixtureCriteriaPassed -and
    $scannerPermissionCriteriaPassed -and
    $scannerFindingCriteriaPassed -and
    $scannerConflictCriteriaPassed -and
    $identityDirectoryCriteriaPassed -and
    $groupExpansionCriteriaPassed -and
    $liveEvidenceValid -and
    $failedPreflightRows.Count -eq 0 -and
    $failedCriteriaRows.Count -eq 0 -and
    $blockingReviewRows.Count -eq 0 -and
    $bundleValid -and
    $bundleLeakCount -eq 0 -and
    $issueCommentsReady -and
    $publishPreviewReady
)
$scanManifestIncludeFilesLabel = if ($scanManifestIncludeFilesPassed) { 'Passed' } else { 'Review ScanManifestIncludeFiles' }
$collectorEnvironmentLabel = if ($collectorEnvironmentPassed) { 'Passed' } else { 'Review CollectorEnvironment' }
$dashboardReviewLabel = if ($dashboardReviewPassed) { 'Passed' } else { 'Review DashboardReviewEvidence' }
$labPopulationCriteriaLabel = if ($labPopulationCriteriaPassed) { 'Passed' } else { 'Review lab population criteria' }
$labFixtureCriteriaLabel = if ($labFixtureCriteriaPassed) { 'Passed' } else { 'Review lab fixture criteria' }
$scannerPermissionCriteriaLabel = if ($scannerPermissionCriteriaPassed) { 'Passed' } else { 'Review scanner permission criteria' }
$scannerFindingCriteriaLabel = if ($scannerFindingCriteriaPassed) { 'Passed' } else { 'Review scanner finding criteria' }
$scannerConflictCriteriaLabel = if ($scannerConflictCriteriaPassed) { 'Passed' } else { 'Review scanner conflict and collection-error criteria' }
$identityDirectoryCriteriaLabel = if ($identityDirectoryCriteriaPassed) { 'Passed' } else { 'Review identity directory criteria' }
$groupExpansionCriteriaLabel = if ($groupExpansionCriteriaPassed) { 'Passed' } else { 'Review group expansion criteria' }

$lines = New-Object System.Collections.ArrayList
Add-ShareSurferCloseoutLine -Lines $lines -Text 'ShareSurfer live validation closeout checklist.'
Add-ShareSurferCloseoutLine -Lines $lines
Add-ShareSurferCloseoutLine -Lines $lines -Text '**Overall Status**'
Add-ShareSurferCloseoutLine -Lines $lines -Text ('- Ready for proof review: `{0}`' -f $readyForProofReview)
Add-ShareSurferCloseoutLine -Lines $lines -Text '- Close GitHub proof issues only after a human reviewer agrees the live run proves the issue acceptance criteria.'
Add-ShareSurferCloseoutLine -Lines $lines
Add-ShareSurferCloseoutLine -Lines $lines -Text '**Go Gates**'
Add-ShareSurferCloseoutLine -Lines $lines -Text ('- {0} V1 acceptance passed with `{1}` failed checks.' -f (Get-ShareSurferCloseoutStatus -Passed $acceptanceValid), $acceptanceFailedCount)
Add-ShareSurferCloseoutLine -Lines $lines -Text ('- {0} Scan manifest proves file-object scanning when live evidence is required.' -f (Get-ShareSurferCloseoutStatus -Passed $scanManifestIncludeFilesPassed))
Add-ShareSurferCloseoutLine -Lines $lines -Text ('- {0} Collector environment evidence exists so reviewers can see the host, PowerShell, module, and command context for the run.' -f (Get-ShareSurferCloseoutStatus -Passed $collectorEnvironmentPassed))
Add-ShareSurferCloseoutLine -Lines $lines -Text ('- {0} Dashboard review evidence exists so reviewers can confirm the offline report rendered and was operator-reviewed.' -f (Get-ShareSurferCloseoutStatus -Passed $dashboardReviewPassed))
Add-ShareSurferCloseoutLine -Lines $lines -Text ('- {0} Lab population criteria prove the enterprise user, group, and share counts requested for validation.' -f (Get-ShareSurferCloseoutStatus -Passed $labPopulationCriteriaPassed))
Add-ShareSurferCloseoutLine -Lines $lines -Text ('- {0} Lab fixture criteria prove real files, deep paths, long-path policy fixtures, and the configured disk budget.' -f (Get-ShareSurferCloseoutStatus -Passed $labFixtureCriteriaPassed))
Add-ShareSurferCloseoutLine -Lines $lines -Text ('- {0} Scanner permission criteria prove share permissions, folder ACLs, and file ACL entries were collected.' -f (Get-ShareSurferCloseoutStatus -Passed $scannerPermissionCriteriaPassed))
Add-ShareSurferCloseoutLine -Lines $lines -Text ('- {0} Scanner finding criteria prove ownership evidence, deep explicit ACE findings, and inheritance-break findings.' -f (Get-ShareSurferCloseoutStatus -Passed $scannerFindingCriteriaPassed))
Add-ShareSurferCloseoutLine -Lines $lines -Text ('- {0} Scanner conflict criteria prove share-vs-NTFS conflicts and collection-error evidence were recorded.' -f (Get-ShareSurferCloseoutStatus -Passed $scannerConflictCriteriaPassed))
Add-ShareSurferCloseoutLine -Lines $lines -Text ('- {0} Identity enrichment criteria prove employee identifiers, two-level manager chains, and the selected OBS/OID attribute.' -f (Get-ShareSurferCloseoutStatus -Passed $identityDirectoryCriteriaPassed))
Add-ShareSurferCloseoutLine -Lines $lines -Text ('- {0} Security group criteria prove recursive group expansion and OBS/OID coverage for permission-bearing groups.' -f (Get-ShareSurferCloseoutStatus -Passed $groupExpansionCriteriaPassed))
Add-ShareSurferCloseoutLine -Lines $lines -Text ('- {0} Live evidence gate passed with `{1}` fallback criteria.' -f (Get-ShareSurferCloseoutStatus -Passed $liveEvidenceValid), $fallbackCount)
Add-ShareSurferCloseoutLine -Lines $lines -Text ('- {0} Required preflight blockers: `{1}`.' -f (Get-ShareSurferCloseoutStatus -Passed ($failedPreflightRows.Count -eq 0)), $failedPreflightRows.Count)
Add-ShareSurferCloseoutLine -Lines $lines -Text ('- {0} Failed required validation criteria: `{1}`.' -f (Get-ShareSurferCloseoutStatus -Passed ($failedCriteriaRows.Count -eq 0)), $failedCriteriaRows.Count)
Add-ShareSurferCloseoutLine -Lines $lines -Text ('- {0} Blocking live-evidence review rows: `{1}`.' -f (Get-ShareSurferCloseoutStatus -Passed ($blockingReviewRows.Count -eq 0)), $blockingReviewRows.Count)
Add-ShareSurferCloseoutLine -Lines $lines -Text ('- {0} Redacted support bundle validation passed with `{1}` redaction leaks.' -f (Get-ShareSurferCloseoutStatus -Passed ($bundleValid -and $bundleLeakCount -eq 0)), $bundleLeakCount)
Add-ShareSurferCloseoutLine -Lines $lines -Text ('- {0} Issue comment bodies exist for issues #1, #3, #5, and #6.' -f (Get-ShareSurferCloseoutStatus -Passed $issueCommentsReady))
Add-ShareSurferCloseoutLine -Lines $lines -Text ('- {0} Issue comment publish preview is dry-run only and has no posted URLs.' -f (Get-ShareSurferCloseoutStatus -Passed $publishPreviewReady))
Add-ShareSurferCloseoutLine -Lines $lines
Add-ShareSurferCloseoutLine -Lines $lines -Text '**Review If Not Ready**'
Add-ShareSurferCloseoutLine -Lines $lines -Text ('- Preflight blockers: `{0}`' -f (Join-ShareSurferCloseoutNames -Rows $failedPreflightRows))
Add-ShareSurferCloseoutLine -Lines $lines -Text ('- Failed criteria: `{0}`' -f (Join-ShareSurferCloseoutNames -Rows $failedCriteriaRows))
Add-ShareSurferCloseoutLine -Lines $lines -Text ('- Scan manifest file-object check: `{0}`' -f $scanManifestIncludeFilesLabel)
Add-ShareSurferCloseoutLine -Lines $lines -Text ('- Collector environment check: `{0}`' -f $collectorEnvironmentLabel)
Add-ShareSurferCloseoutLine -Lines $lines -Text ('- Dashboard review check: `{0}`' -f $dashboardReviewLabel)
Add-ShareSurferCloseoutLine -Lines $lines -Text ('- Lab population criteria check: `{0}`' -f $labPopulationCriteriaLabel)
Add-ShareSurferCloseoutLine -Lines $lines -Text ('- Lab fixture criteria check: `{0}`' -f $labFixtureCriteriaLabel)
Add-ShareSurferCloseoutLine -Lines $lines -Text ('- Scanner permission criteria check: `{0}`' -f $scannerPermissionCriteriaLabel)
Add-ShareSurferCloseoutLine -Lines $lines -Text ('- Scanner finding criteria check: `{0}`' -f $scannerFindingCriteriaLabel)
Add-ShareSurferCloseoutLine -Lines $lines -Text ('- Scanner conflict and collection-error criteria check: `{0}`' -f $scannerConflictCriteriaLabel)
Add-ShareSurferCloseoutLine -Lines $lines -Text ('- Identity enrichment criteria check: `{0}`' -f $identityDirectoryCriteriaLabel)
Add-ShareSurferCloseoutLine -Lines $lines -Text ('- Security group expansion criteria check: `{0}`' -f $groupExpansionCriteriaLabel)
Add-ShareSurferCloseoutLine -Lines $lines -Text ('- Blocking live-evidence criteria: `{0}`' -f (Join-ShareSurferCloseoutNames -Rows $blockingReviewRows))
Add-ShareSurferCloseoutLine -Lines $lines -Text ('- Missing issue comment targets: `{0}`' -f $missingIssueLabel)
Add-ShareSurferCloseoutLine -Lines $lines -Text ('- Missing publish preview targets: `{0}`' -f $missingPublishIssueLabel)
Add-ShareSurferCloseoutLine -Lines $lines
Add-ShareSurferCloseoutLine -Lines $lines -Text '**Next Actions**'
Add-ShareSurferCloseoutLine -Lines $lines -Text '- If ready, review every generated issue comment Markdown file before posting.'
Add-ShareSurferCloseoutLine -Lines $lines -Text '- Post proof comments with the publish helper after review, then read back the GitHub comments.'
Add-ShareSurferCloseoutLine -Lines $lines -Text '- Keep raw run folders inside the trusted lab environment. Share only the redacted support bundle outside that environment.'
Add-ShareSurferCloseoutLine -Lines $lines -Text '- If not ready, fix the rows named above and rerun the validation from a fresh timestamped output folder.'
Add-ShareSurferCloseoutLine -Lines $lines
Add-ShareSurferCloseoutLine -Lines $lines -Text '**Safe Sharing Note**'
Add-ShareSurferCloseoutLine -Lines $lines -Text '- This checklist intentionally omits raw run paths, raw identities, employee identifiers, manager chains, and evidence detail values.'

$markdown = $lines -join [Environment]::NewLine

if (-not [string]::IsNullOrWhiteSpace($OutputPath)) {
    $outputDirectory = Split-Path -Parent $OutputPath
    if (-not [string]::IsNullOrWhiteSpace($outputDirectory)) {
        New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
    }
    Set-Content -LiteralPath $OutputPath -Value $markdown -Encoding UTF8
}

if ($PassThru -or [string]::IsNullOrWhiteSpace($OutputPath)) {
    $markdown
}
