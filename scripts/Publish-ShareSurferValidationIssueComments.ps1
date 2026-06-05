[CmdletBinding()]
param(
    [string] $RunRoot = '',

    [string] $IssueCommentPath = '',

    [string] $Repository = 'jonathanweinberg/ShareSurfer',

    [int[]] $IssueNumber = @(),

    [switch] $Post,

    [switch] $SkipReadyCheck,

    [switch] $SkipReadback
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-ShareSurferIssueCommentPath {
    param(
        [string] $RunRoot = '',
        [string] $IssueCommentPath = ''
    )

    if (-not [string]::IsNullOrWhiteSpace($IssueCommentPath)) {
        return $IssueCommentPath
    }

    if (-not [string]::IsNullOrWhiteSpace($RunRoot)) {
        return (Join-Path $RunRoot 'issue-comments')
    }

    throw 'Specify -RunRoot or -IssueCommentPath.'
}

function Get-ShareSurferIssueCommentManifestPath {
    param(
        [Parameter(Mandatory = $true)]
        [string] $IssueCommentPath
    )

    foreach ($fileName in @('issue-comment-manifest.csv', 'issue_comment_manifest.csv')) {
        $candidate = Join-Path $IssueCommentPath $fileName
        if (Test-Path -LiteralPath $candidate) {
            return $candidate
        }
    }

    throw ('Issue comment manifest not found under: {0}' -f $IssueCommentPath)
}

function Resolve-ShareSurferIssueCommentBodyFile {
    param(
        [Parameter(Mandatory = $true)]
        [string] $IssueCommentPath,

        [Parameter(Mandatory = $true)]
        $ManifestRow
    )

    $fileName = ''
    if ($ManifestRow.PSObject.Properties['FileName']) {
        $fileName = [string]$ManifestRow.FileName
    }
    if ([string]::IsNullOrWhiteSpace($fileName) -and $ManifestRow.PSObject.Properties['BundledFileName']) {
        $fileName = [string]$ManifestRow.BundledFileName
    }

    if ([string]::IsNullOrWhiteSpace($fileName)) {
        return ''
    }

    $normalized = $fileName.Replace('/', [System.IO.Path]::DirectorySeparatorChar)
    if ($normalized -like ('issue_comments{0}*' -f [System.IO.Path]::DirectorySeparatorChar)) {
        $normalized = Split-Path -Leaf $normalized
    }

    Join-Path $IssueCommentPath $normalized
}

function New-ShareSurferIssueCommentPublishResult {
    param(
        [int] $IssueNumber,
        [string] $BodyFile,
        [string] $Status,
        [string] $Command,
        [string] $PostedUrl = '',
        [bool] $ReadbackVerified = $false,
        [string] $Detail = ''
    )

    [pscustomobject]@{
        IssueNumber = $IssueNumber
        BodyFile = $BodyFile
        Status = $Status
        Command = $Command
        PostedUrl = $PostedUrl
        ReadbackVerified = [bool]$ReadbackVerified
        Detail = $Detail
    }
}

function Test-ShareSurferProofReviewReady {
    param(
        [string] $RunRoot = ''
    )

    if ([string]::IsNullOrWhiteSpace($RunRoot)) {
        return $true
    }

    $closeoutPath = Join-Path $RunRoot 'validation-closeout-checklist.md'
    if (-not (Test-Path -LiteralPath $closeoutPath)) {
        throw ('Validation closeout checklist not found. Run New-ShareSurferValidationCloseoutChecklist.ps1 or Invoke-ShareSurferLabValidation.ps1 before posting proof comments: {0}' -f $closeoutPath)
    }

    $closeoutText = Get-Content -LiteralPath $closeoutPath -Raw
    if ($closeoutText -notlike '*Ready for proof review: `True`*') {
        throw ('Validation closeout checklist is not ready for proof review. Review validation-closeout-checklist.md and rerun validation before posting, or use -SkipReadyCheck only for a deliberate manual override: {0}' -f $closeoutPath)
    }

    $true
}

$resolvedIssueCommentPath = Resolve-ShareSurferIssueCommentPath -RunRoot $RunRoot -IssueCommentPath $IssueCommentPath
if (-not (Test-Path -LiteralPath $resolvedIssueCommentPath)) {
    throw ('Issue comment path not found: {0}' -f $resolvedIssueCommentPath)
}

$manifestPath = Get-ShareSurferIssueCommentManifestPath -IssueCommentPath $resolvedIssueCommentPath
$manifestRows = @(Import-Csv -LiteralPath $manifestPath)
if ($manifestRows.Count -eq 0) {
    throw ('Issue comment manifest has no rows: {0}' -f $manifestPath)
}

$selectedRows = foreach ($row in @($manifestRows)) {
    $rowIssueNumber = 0
    if (-not [int]::TryParse([string]$row.IssueNumber, [ref]$rowIssueNumber)) {
        continue
    }
    if ($IssueNumber.Count -gt 0 -and $IssueNumber -notcontains $rowIssueNumber) {
        continue
    }

    [pscustomobject]@{
        IssueNumber = $rowIssueNumber
        BodyFile = Resolve-ShareSurferIssueCommentBodyFile -IssueCommentPath $resolvedIssueCommentPath -ManifestRow $row
    }
}

if (@($selectedRows).Count -eq 0) {
    throw 'No issue comments matched the requested issue filter.'
}

if ($Post -and -not $SkipReadyCheck) {
    [void](Test-ShareSurferProofReviewReady -RunRoot $RunRoot)
}

if ($Post -and $null -eq (Get-Command gh -ErrorAction SilentlyContinue)) {
    throw 'GitHub CLI command `gh` was not found in PATH.'
}

foreach ($row in @($selectedRows)) {
    $bodyFile = [string]$row.BodyFile
    $commandText = 'gh issue comment {0} --repo {1} --body-file "{2}"' -f [int]$row.IssueNumber, $Repository, $bodyFile
    if ([string]::IsNullOrWhiteSpace($bodyFile) -or -not (Test-Path -LiteralPath $bodyFile)) {
        New-ShareSurferIssueCommentPublishResult -IssueNumber ([int]$row.IssueNumber) -BodyFile $bodyFile -Status 'MissingBodyFile' -Command $commandText -Detail 'Body file was not found.'
        continue
    }

    if (-not $Post) {
        New-ShareSurferIssueCommentPublishResult -IssueNumber ([int]$row.IssueNumber) -BodyFile $bodyFile -Status 'DryRun' -Command $commandText -Detail 'Use -Post to publish this comment.'
        continue
    }

    $ghArgs = @('issue', 'comment', [string]$row.IssueNumber, '--repo', $Repository, '--body-file', $bodyFile)
    $postedUrl = ''
    $readbackVerified = $false
    $detail = ''
    try {
        $postedUrl = [string](& gh @ghArgs 2>&1)
        if ($LASTEXITCODE -ne 0) {
            New-ShareSurferIssueCommentPublishResult -IssueNumber ([int]$row.IssueNumber) -BodyFile $bodyFile -Status 'PostFailed' -Command $commandText -Detail $postedUrl
            continue
        }

        if (-not $SkipReadback) {
            $commentId = ''
            $match = [regex]::Match($postedUrl, 'issuecomment-([0-9]+)')
            if ($match.Success) {
                $commentId = $match.Groups[1].Value
            }
            if ([string]::IsNullOrWhiteSpace($commentId)) {
                $detail = 'Posted URL did not include an issue comment id.'
            }
            else {
                $bodyText = Get-Content -LiteralPath $bodyFile -Raw
                $readbackBody = [string](& gh api ('repos/{0}/issues/comments/{1}' -f $Repository, $commentId) --jq '.body' 2>&1)
                if ($LASTEXITCODE -eq 0 -and $readbackBody.Trim() -eq $bodyText.Trim()) {
                    $readbackVerified = $true
                    $detail = 'Readback body matched the posted body file.'
                }
                else {
                    $detail = 'Readback did not match the posted body file.'
                }
            }
        }
        else {
            $detail = 'Readback verification skipped.'
        }

        New-ShareSurferIssueCommentPublishResult -IssueNumber ([int]$row.IssueNumber) -BodyFile $bodyFile -Status 'Posted' -Command $commandText -PostedUrl $postedUrl.Trim() -ReadbackVerified:$readbackVerified -Detail $detail
    }
    catch {
        New-ShareSurferIssueCommentPublishResult -IssueNumber ([int]$row.IssueNumber) -BodyFile $bodyFile -Status 'PostFailed' -Command $commandText -PostedUrl $postedUrl.Trim() -Detail $_.Exception.Message
    }
}
