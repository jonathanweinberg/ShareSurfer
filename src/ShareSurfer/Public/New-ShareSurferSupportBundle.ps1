function New-ShareSurferSupportBundle {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $ExportPath,

        [Parameter(Mandatory = $true)]
        [string] $OutputPath,

        [ValidateSet('StableToken', 'Strict')]
        [string] $RedactionMode = 'StableToken',

        [string] $RedactionSalt = '',

        [switch] $IncludeReport,

        [string] $RunRoot = ''
    )

    if ($RedactionSalt -eq '') {
        $RedactionSalt = [guid]::NewGuid().ToString('N')
    }

    if (-not (Test-Path -LiteralPath $OutputPath)) {
        New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
    }

    $schema = Get-ShareSurferExportSchema
    $generatedAt = (Get-Date).ToUniversalTime().ToString('o')
    $fileDiagnostics = New-Object System.Collections.ArrayList
    foreach ($fileName in $schema.Keys) {
        $sourcePath = Join-Path $ExportPath $fileName
        $destinationPath = Join-Path $OutputPath $fileName
        $rows = @(Read-ShareSurferCsv -Path $sourcePath)

        $redactedRows = foreach ($row in $rows) {
            Protect-ShareSurferRow -Row $row -FileName $fileName -Columns $schema[$fileName] -RedactionMode $RedactionMode -RedactionSalt $RedactionSalt
        }

        Export-ShareSurferCsv -Path $destinationPath -Columns $schema[$fileName] -Rows $redactedRows
        [void]$fileDiagnostics.Add([pscustomobject]@{
            FileName = $fileName
            RowCount = @($redactedRows).Count
            Sha256 = Get-ShareSurferFileSha256 -Path $destinationPath
        })
    }

    $redactedEventLogPath = Join-Path $OutputPath 'scan_events.jsonl'
    $redactedEventRows = @(Read-ShareSurferCsv -Path (Join-Path $OutputPath 'scan_events.csv'))
    Export-ShareSurferJsonLines -Path $redactedEventLogPath -Rows $redactedEventRows
    [void]$fileDiagnostics.Add([pscustomobject]@{
        FileName = 'scan_events.jsonl'
        RowCount = @($redactedEventRows).Count
        Sha256 = Get-ShareSurferFileSha256 -Path $redactedEventLogPath
    })

    $validation = Test-ShareSurferExport -ExportPath $OutputPath
    $reportIncluded = $false
    if ($IncludeReport) {
        $reportPath = Join-Path $OutputPath 'report.html'
        ConvertTo-ShareSurferReport -ExportPath $OutputPath -OutputPath $reportPath | Out-Null
        $reportIncluded = $true
        [void]$fileDiagnostics.Add([pscustomobject]@{
            FileName = 'report.html'
            RowCount = 1
            Sha256 = Get-ShareSurferFileSha256 -Path $reportPath
        })
    }

    $labRunIncluded = $false
    $labRunFileDiagnostics = @()
    if (-not [string]::IsNullOrWhiteSpace($RunRoot)) {
        $labRunFileDiagnostics = @(New-ShareSurferSupportBundleLabRunEvidence -RunRoot $RunRoot -BundlePath $OutputPath -GeneratedAt $generatedAt -RedactionMode $RedactionMode -RedactionSalt $RedactionSalt)
        foreach ($diagnostic in $labRunFileDiagnostics) {
            [void]$fileDiagnostics.Add($diagnostic)
        }
        $labRunIncluded = ($labRunFileDiagnostics.Count -gt 0)
    }

    $redactionAuditPath = Join-Path $OutputPath 'support_bundle_redaction_audit.csv'
    $redactionAudit = @(New-ShareSurferRedactionAudit -ExportPath $ExportPath -BundlePath $OutputPath -Schema $schema -RedactionSalt $RedactionSalt -RunRoot $RunRoot)
    $redactionAudit | Export-Csv -LiteralPath $redactionAuditPath -NoTypeInformation -Encoding UTF8
    [void]$fileDiagnostics.Add([pscustomobject]@{
        FileName = 'support_bundle_redaction_audit.csv'
        RowCount = @($redactionAudit).Count
        Sha256 = Get-ShareSurferFileSha256 -Path $redactionAuditPath
    })
    $redactionLeakCount = @($redactionAudit | Where-Object { $_.LeakDetected }).Count

    $diagnosticsPath = Join-Path $OutputPath 'support_bundle_diagnostics.json'
    $diagnostics = New-ShareSurferSupportBundleDiagnostics -BundlePath $OutputPath -GeneratedAt $generatedAt -RedactionMode $RedactionMode -ReportIncluded:$reportIncluded -LabRunIncluded:$labRunIncluded -LabRunFileDiagnostics $labRunFileDiagnostics -Validation $validation -RedactionLeakCount $redactionLeakCount -FileDiagnostics $fileDiagnostics
    $diagnostics | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $diagnosticsPath -Encoding UTF8
    [void]$fileDiagnostics.Add([pscustomobject]@{
        FileName = 'support_bundle_diagnostics.json'
        RowCount = 1
        Sha256 = Get-ShareSurferFileSha256 -Path $diagnosticsPath
    })

    $summaryPath = Join-Path $OutputPath 'support_bundle_summary.json'
    $summary = [ordered]@{
        BundleType = 'ShareSurferRedactedSupportBundle'
        GeneratedAt = $generatedAt
        RedactionMode = $RedactionMode
        RelationshipPreserving = [bool]($RedactionMode -eq 'StableToken')
        ReportIncluded = [bool]$reportIncluded
        LabRunIncluded = [bool]$labRunIncluded
        Validation = [ordered]@{
            IsValid = [bool]$validation.IsValid
            MissingFileCount = @($validation.MissingFiles).Count
            SchemaErrorCount = @($validation.SchemaErrors).Count
        }
        Redaction = [ordered]@{
            AuditCount = @($redactionAudit).Count
            LeakCount = [int]$redactionLeakCount
            LeakDetected = ([int]$redactionLeakCount -gt 0)
        }
        Diagnostics = [ordered]@{
            FileName = 'support_bundle_diagnostics.json'
            FindingCount = [int]$diagnostics.Inventory.FindingCount
            ConflictCount = [int]$diagnostics.Inventory.ConflictCount
            PartialShareCount = [int]$diagnostics.Inventory.PartialShareCount
            CollectionErrorCount = [int]$diagnostics.Inventory.CollectionErrorCount
        }
        Files = @($fileDiagnostics | ForEach-Object {
            [ordered]@{
                FileName = [string]$_.FileName
                RowCount = [int]$_.RowCount
                Sha256 = [string]$_.Sha256
            }
        })
        Notes = @(
            'This summary is safe to share with the redacted bundle.',
            'The redaction salt and any reversal map are not included.',
            'Use support_bundle_diagnostics.json for redacted scan settings, counts, and collection-health context.',
            'Use support_bundle_redaction_audit.csv to review checked value tokens and leak status.'
        )
    }
    $summary | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $summaryPath -Encoding UTF8
    [void]$fileDiagnostics.Add([pscustomobject]@{
        FileName = 'support_bundle_summary.json'
        RowCount = 1
        Sha256 = Get-ShareSurferFileSha256 -Path $summaryPath
    })

    $manifest = @(
        [pscustomobject]@{
            GeneratedAt = $generatedAt
            RedactionMode = $RedactionMode
            RelationshipPreserving = [bool]($RedactionMode -eq 'StableToken')
            ExportFileCount = @($schema.Keys).Count
            DiagnosticFileCount = @($fileDiagnostics).Count
            ReportIncluded = [bool]$reportIncluded
            LabRunIncluded = [bool]$labRunIncluded
            RedactionAuditCount = @($redactionAudit).Count
            RedactionLeakCount = [int]$redactionLeakCount
            ValidationIsValid = [bool]$validation.IsValid
            MissingFileCount = @($validation.MissingFiles).Count
            SchemaErrorCount = @($validation.SchemaErrors).Count
        }
    )

    $manifest | Export-Csv -LiteralPath (Join-Path $OutputPath 'support_bundle_manifest.csv') -NoTypeInformation -Encoding UTF8
    @($fileDiagnostics) | Export-Csv -LiteralPath (Join-Path $OutputPath 'support_bundle_files.csv') -NoTypeInformation -Encoding UTF8

    Set-Content -LiteralPath (Join-Path $OutputPath 'README.txt') -Value @(
        'ShareSurfer redacted support bundle',
        ('GeneratedAt={0}' -f $generatedAt),
        ('RedactionMode={0}' -f $RedactionMode),
        ('ValidationIsValid={0}' -f [bool]$validation.IsValid),
        ('ReportIncluded={0}' -f [bool]$reportIncluded),
        ('LabRunIncluded={0}' -f [bool]$labRunIncluded),
        ('RedactionLeakCount={0}' -f [int]$redactionLeakCount),
        'Relationship-preserving StableToken mode uses salted synthetic IDs and does not include the salt in this bundle.',
        'support_bundle_manifest.csv records bundle-level diagnostics.',
        'support_bundle_files.csv records redacted file row counts and hashes.',
        'support_bundle_summary.json provides a quick redacted bundle health summary for support triage.',
        'support_bundle_diagnostics.json summarizes redacted scan settings, export counts, findings, conflicts, partial shares, and collection errors.',
        'support_bundle_redaction_audit.csv records checked source-value tokens and leak status without storing raw source values.',
        'scan_events.jsonl is a redacted JSON Lines event log for support tools that prefer append-friendly logs.',
        'lab_run_events.jsonl is included when a lab validation run root was supplied and records redacted lab-validation phase events.',
        'lab_run_diagnostics.json is included when a lab validation run root was supplied.',
        'issue_summary.md is included when a lab validation run has generated a public-safe issue summary.',
        'validation_closeout_checklist.md is included when a lab validation run has generated a public-safe closeout checklist.',
        'issue_comments contains public-safe issue comment bodies when a lab validation run generated targeted issue updates.'
    ) -Encoding UTF8

    [pscustomobject]@{
        OutputPath = $OutputPath
        RedactionMode = $RedactionMode
        ValidationIsValid = [bool]$validation.IsValid
        ReportIncluded = [bool]$reportIncluded
        LabRunIncluded = [bool]$labRunIncluded
        RedactionLeakCount = [int]$redactionLeakCount
    }
}

function New-ShareSurferSupportBundleLabRunEvidence {
    param(
        [Parameter(Mandatory = $true)]
        [string] $RunRoot,

        [Parameter(Mandatory = $true)]
        [string] $BundlePath,

        [Parameter(Mandatory = $true)]
        [string] $GeneratedAt,

        [ValidateSet('StableToken', 'Strict')]
        [string] $RedactionMode = 'StableToken',

        [string] $RedactionSalt = 'ShareSurfer'
    )

    $fileDiagnostics = New-Object System.Collections.ArrayList
    if (-not (Test-Path -LiteralPath $RunRoot)) {
        return @()
    }

    $includedFiles = New-Object System.Collections.ArrayList
    $issueSummaryIncluded = $false
    $issueSummaryLineCount = 0
    $closeoutChecklistIncluded = $false
    $closeoutChecklistLineCount = 0
    $issueCommentCount = 0
    $issueCommentManifestIncluded = $false
    $issueCommentPostCommandsIncluded = $false
    $issueCommentPublishPreviewIncluded = $false
    $issueCommentPublishPreviewRowCount = 0
    $preflightRows = @(New-ShareSurferRedactedLabCsv -SourcePath (Join-Path $RunRoot 'lab-preflight.csv') -DestinationPath (Join-Path $BundlePath 'lab_preflight.csv') -RedactColumns @('Evidence') -RedactionMode $RedactionMode -RedactionSalt $RedactionSalt)
    if ($preflightRows.Count -gt 0 -or (Test-Path -LiteralPath (Join-Path $BundlePath 'lab_preflight.csv'))) {
        [void]$fileDiagnostics.Add((New-ShareSurferSupportBundleFileDiagnostic -Path (Join-Path $BundlePath 'lab_preflight.csv') -FileName 'lab_preflight.csv' -RowCount $preflightRows.Count))
        [void]$includedFiles.Add('lab_preflight.csv')
    }

    $criteriaRows = @(New-ShareSurferRedactedLabCsv -SourcePath (Join-Path $RunRoot 'lab-validation-criteria.csv') -DestinationPath (Join-Path $BundlePath 'lab_validation_criteria.csv') -RedactColumns @('EvidenceDetail') -RedactionMode $RedactionMode -RedactionSalt $RedactionSalt)
    if ($criteriaRows.Count -gt 0 -or (Test-Path -LiteralPath (Join-Path $BundlePath 'lab_validation_criteria.csv'))) {
        [void]$fileDiagnostics.Add((New-ShareSurferSupportBundleFileDiagnostic -Path (Join-Path $BundlePath 'lab_validation_criteria.csv') -FileName 'lab_validation_criteria.csv' -RowCount $criteriaRows.Count))
        [void]$includedFiles.Add('lab_validation_criteria.csv')
    }

    $reviewRows = @(New-ShareSurferRedactedLabCsv -SourcePath (Join-Path $RunRoot 'live-evidence-review.csv') -DestinationPath (Join-Path $BundlePath 'live_evidence_review.csv') -RedactColumns @('EvidenceDetail') -RedactionMode $RedactionMode -RedactionSalt $RedactionSalt)
    if ($reviewRows.Count -gt 0 -or (Test-Path -LiteralPath (Join-Path $BundlePath 'live_evidence_review.csv'))) {
        [void]$fileDiagnostics.Add((New-ShareSurferSupportBundleFileDiagnostic -Path (Join-Path $BundlePath 'live_evidence_review.csv') -FileName 'live_evidence_review.csv' -RowCount $reviewRows.Count))
        [void]$includedFiles.Add('live_evidence_review.csv')
    }

    $liveEvidence = New-ShareSurferRedactedLabJsonSummary -SourcePath (Join-Path $RunRoot 'live-evidence.json') -Kind 'LiveEvidence' -RedactionMode $RedactionMode -RedactionSalt $RedactionSalt
    if ($null -ne $liveEvidence) {
        $liveEvidencePath = Join-Path $BundlePath 'live_evidence.json'
        $liveEvidence | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $liveEvidencePath -Encoding UTF8
        [void]$fileDiagnostics.Add((New-ShareSurferSupportBundleFileDiagnostic -Path $liveEvidencePath -FileName 'live_evidence.json' -RowCount 1))
        [void]$includedFiles.Add('live_evidence.json')
    }

    $acceptance = New-ShareSurferRedactedLabJsonSummary -SourcePath (Join-Path $RunRoot 'v1-acceptance.json') -Kind 'Acceptance' -RedactionMode $RedactionMode -RedactionSalt $RedactionSalt
    if ($null -ne $acceptance) {
        $acceptancePath = Join-Path $BundlePath 'v1_acceptance.json'
        $acceptance | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $acceptancePath -Encoding UTF8
        [void]$fileDiagnostics.Add((New-ShareSurferSupportBundleFileDiagnostic -Path $acceptancePath -FileName 'v1_acceptance.json' -RowCount 1))
        [void]$includedFiles.Add('v1_acceptance.json')
    }

    $acceptanceSummary = New-ShareSurferRedactedLabJsonSummary -SourcePath (Join-Path $RunRoot 'v1-acceptance-summary.json') -Kind 'AcceptanceSummary' -RedactionMode $RedactionMode -RedactionSalt $RedactionSalt
    if ($null -ne $acceptanceSummary) {
        $acceptanceSummaryPath = Join-Path $BundlePath 'v1_acceptance_summary.json'
        $acceptanceSummary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $acceptanceSummaryPath -Encoding UTF8
        [void]$fileDiagnostics.Add((New-ShareSurferSupportBundleFileDiagnostic -Path $acceptanceSummaryPath -FileName 'v1_acceptance_summary.json' -RowCount 1))
        [void]$includedFiles.Add('v1_acceptance_summary.json')
    }

    $issueSummarySourcePath = Join-Path $RunRoot 'issue-summary.md'
    if (Test-Path -LiteralPath $issueSummarySourcePath) {
        $issueSummaryPath = Join-Path $BundlePath 'issue_summary.md'
        Copy-Item -LiteralPath $issueSummarySourcePath -Destination $issueSummaryPath -Force
        $issueSummaryLineCount = @((Get-Content -LiteralPath $issueSummaryPath -ErrorAction SilentlyContinue)).Count
        [void]$fileDiagnostics.Add((New-ShareSurferSupportBundleFileDiagnostic -Path $issueSummaryPath -FileName 'issue_summary.md' -RowCount $issueSummaryLineCount))
        [void]$includedFiles.Add('issue_summary.md')
        $issueSummaryIncluded = $true
    }

    $closeoutChecklistSourcePath = Join-Path $RunRoot 'validation-closeout-checklist.md'
    if (Test-Path -LiteralPath $closeoutChecklistSourcePath) {
        $closeoutChecklistPath = Join-Path $BundlePath 'validation_closeout_checklist.md'
        Copy-Item -LiteralPath $closeoutChecklistSourcePath -Destination $closeoutChecklistPath -Force
        $closeoutChecklistLineCount = @((Get-Content -LiteralPath $closeoutChecklistPath -ErrorAction SilentlyContinue)).Count
        [void]$fileDiagnostics.Add((New-ShareSurferSupportBundleFileDiagnostic -Path $closeoutChecklistPath -FileName 'validation_closeout_checklist.md' -RowCount $closeoutChecklistLineCount))
        [void]$includedFiles.Add('validation_closeout_checklist.md')
        $closeoutChecklistIncluded = $true
    }

    $issueCommentSourceDirectory = Join-Path $RunRoot 'issue-comments'
    if (Test-Path -LiteralPath $issueCommentSourceDirectory) {
        $issueCommentBundleDirectory = Join-Path $BundlePath 'issue_comments'
        New-Item -ItemType Directory -Path $issueCommentBundleDirectory -Force | Out-Null
        $issueCommentFiles = @(Get-ChildItem -LiteralPath $issueCommentSourceDirectory -Filter 'issue-*.md' -File -ErrorAction SilentlyContinue | Sort-Object Name)
        foreach ($issueCommentFile in @($issueCommentFiles)) {
            $destinationPath = Join-Path $issueCommentBundleDirectory $issueCommentFile.Name
            Copy-Item -LiteralPath $issueCommentFile.FullName -Destination $destinationPath -Force
            $bundleFileName = 'issue_comments/{0}' -f $issueCommentFile.Name
            $lineCount = @((Get-Content -LiteralPath $destinationPath -ErrorAction SilentlyContinue)).Count
            [void]$fileDiagnostics.Add((New-ShareSurferSupportBundleFileDiagnostic -Path $destinationPath -FileName $bundleFileName -RowCount $lineCount))
            [void]$includedFiles.Add($bundleFileName)
            $issueCommentCount++
        }

        $repository = 'jonathanweinberg/ShareSurfer'
        $issueCommentManifestPath = Join-Path $issueCommentSourceDirectory 'issue-comment-manifest.csv'
        if (Test-Path -LiteralPath $issueCommentManifestPath) {
            $manifestRows = @(Import-Csv -LiteralPath $issueCommentManifestPath)
            $safeManifestRows = foreach ($row in @($manifestRows)) {
                $fileName = [string]$row.FileName
                [pscustomobject]@{
                    IssueNumber = [string]$row.IssueNumber
                    FileName = $fileName
                    BundledFileName = if ([string]::IsNullOrWhiteSpace($fileName)) { '' } else { 'issue_comments/{0}' -f $fileName }
                    CriteriaPassed = [string]$row.CriteriaPassed
                    AcceptanceChecksPassed = [string]$row.AcceptanceChecksPassed
                    BlockingLiveReviewRows = [string]$row.BlockingLiveReviewRows
                }
            }
            $bundleManifestPath = Join-Path $issueCommentBundleDirectory 'issue_comment_manifest.csv'
            @($safeManifestRows) | Export-Csv -LiteralPath $bundleManifestPath -NoTypeInformation -Encoding UTF8
            [void]$fileDiagnostics.Add((New-ShareSurferSupportBundleFileDiagnostic -Path $bundleManifestPath -FileName 'issue_comments/issue_comment_manifest.csv' -RowCount @($safeManifestRows).Count))
            [void]$includedFiles.Add('issue_comments/issue_comment_manifest.csv')
            $issueCommentManifestIncluded = $true

            $sourcePostCommandsPath = Join-Path $issueCommentSourceDirectory 'post-commands.txt'
            if (Test-Path -LiteralPath $sourcePostCommandsPath) {
                $sourceCommandText = Get-Content -LiteralPath $sourcePostCommandsPath -Raw -ErrorAction SilentlyContinue
                $repositoryMatch = [regex]::Match([string]$sourceCommandText, '--repo\s+([^\s]+)')
                if ($repositoryMatch.Success) {
                    $repository = $repositoryMatch.Groups[1].Value.Trim('"')
                }
            }
            $safePostCommands = @($safeManifestRows | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_.IssueNumber) -and -not [string]::IsNullOrWhiteSpace([string]$_.BundledFileName) } | ForEach-Object {
                'gh issue comment {0} --repo {1} --body-file "{2}"' -f [string]$_.IssueNumber, $repository, [string]$_.BundledFileName
            })
            if ($safePostCommands.Count -gt 0) {
                $bundlePostCommandsPath = Join-Path $issueCommentBundleDirectory 'post_commands.txt'
                Set-Content -LiteralPath $bundlePostCommandsPath -Value $safePostCommands -Encoding UTF8
                [void]$fileDiagnostics.Add((New-ShareSurferSupportBundleFileDiagnostic -Path $bundlePostCommandsPath -FileName 'issue_comments/post_commands.txt' -RowCount $safePostCommands.Count))
                [void]$includedFiles.Add('issue_comments/post_commands.txt')
                $issueCommentPostCommandsIncluded = $true
            }
        }

        $publishPreviewSourcePath = Join-Path $RunRoot 'issue-comment-publish-preview.csv'
        if (Test-Path -LiteralPath $publishPreviewSourcePath) {
            $previewRows = @(Import-Csv -LiteralPath $publishPreviewSourcePath)
            $safePreviewRows = foreach ($row in @($previewRows)) {
                $bodyFile = [string]$row.BodyFile
                $bodyLeaf = if ([string]::IsNullOrWhiteSpace($bodyFile)) { '' } else { Split-Path -Leaf $bodyFile }
                $bundledBodyFile = if ([string]::IsNullOrWhiteSpace($bodyLeaf)) { '' } else { 'issue_comments/{0}' -f $bodyLeaf }
                $issueNumber = [string]$row.IssueNumber
                $command = if ([string]::IsNullOrWhiteSpace($issueNumber) -or [string]::IsNullOrWhiteSpace($bundledBodyFile)) {
                    ''
                }
                else {
                    'gh issue comment {0} --repo {1} --body-file "{2}"' -f $issueNumber, $repository, $bundledBodyFile
                }

                [pscustomobject]@{
                    IssueNumber = $issueNumber
                    BodyFile = $bundledBodyFile
                    Status = [string]$row.Status
                    Command = $command
                    PostedUrl = [string]$row.PostedUrl
                    ReadbackVerified = [string]$row.ReadbackVerified
                    Detail = [string]$row.Detail
                }
            }

            $bundlePublishPreviewPath = Join-Path $issueCommentBundleDirectory 'publish_preview.csv'
            @($safePreviewRows) | Export-Csv -LiteralPath $bundlePublishPreviewPath -NoTypeInformation -Encoding UTF8
            [void]$fileDiagnostics.Add((New-ShareSurferSupportBundleFileDiagnostic -Path $bundlePublishPreviewPath -FileName 'issue_comments/publish_preview.csv' -RowCount @($safePreviewRows).Count))
            [void]$includedFiles.Add('issue_comments/publish_preview.csv')
            $issueCommentPublishPreviewIncluded = $true
            $issueCommentPublishPreviewRowCount = @($safePreviewRows).Count
        }
    }

    $labRunEvents = @(New-ShareSurferRedactedLabRunEvents -SourcePath (Join-Path $RunRoot 'lab-run-events.jsonl') -DestinationPath (Join-Path $BundlePath 'lab_run_events.jsonl') -RedactionMode $RedactionMode -RedactionSalt $RedactionSalt)
    if ($labRunEvents.Count -gt 0 -or (Test-Path -LiteralPath (Join-Path $BundlePath 'lab_run_events.jsonl'))) {
        [void]$fileDiagnostics.Add((New-ShareSurferSupportBundleFileDiagnostic -Path (Join-Path $BundlePath 'lab_run_events.jsonl') -FileName 'lab_run_events.jsonl' -RowCount $labRunEvents.Count))
        [void]$includedFiles.Add('lab_run_events.jsonl')
    }

    $labDiagnostics = [ordered]@{
        BundleType = 'ShareSurferRedactedLabRunDiagnostics'
        GeneratedAt = $GeneratedAt
        RunRootToken = Protect-ShareSurferValue -Value $RunRoot -ColumnName 'FullPath' -RedactionMode $RedactionMode -RedactionSalt $RedactionSalt
        IncludedFiles = @($includedFiles)
        RunEvents = [ordered]@{
            RowCount = $labRunEvents.Count
            ErrorCount = @($labRunEvents | Where-Object { [string]$_.Level -eq 'Error' }).Count
            WarningCount = @($labRunEvents | Where-Object { [string]$_.Level -eq 'Warning' }).Count
        }
        Preflight = [ordered]@{
            RowCount = $preflightRows.Count
            FailedRequiredCount = @($preflightRows | Where-Object { [string]$_.Required -eq 'True' -and [string]$_.Passed -ne 'True' }).Count
        }
        Criteria = [ordered]@{
            RowCount = $criteriaRows.Count
            FailedRequiredCount = @($criteriaRows | Where-Object { [string]$_.Required -eq 'True' -and [string]$_.Passed -ne 'True' }).Count
        }
        LiveEvidenceReview = [ordered]@{
            RowCount = $reviewRows.Count
            BlockingCount = @($reviewRows | Where-Object { [string]$_.Required -eq 'True' -and @('Failed', 'MissingEvidenceSource', 'PlanOnly', 'EvidenceUnavailable') -contains [string]$_.EvidenceStatus }).Count
        }
        LiveEvidence = if ($null -eq $liveEvidence) { $null } else { [ordered]@{ IsValid = $liveEvidence.IsValid; FallbackCount = $liveEvidence.FallbackCount } }
        Acceptance = if ($null -eq $acceptance) { $null } else { [ordered]@{ IsValid = $acceptance.IsValid; FailedCheckCount = $acceptance.FailedCheckCount } }
        AcceptanceSummary = if ($null -eq $acceptanceSummary) { $null } else { [ordered]@{ IsValid = $acceptanceSummary.IsValid; FailedCheckCount = $acceptanceSummary.FailedCheckCount; CheckCount = $acceptanceSummary.CheckCount } }
        IssueSummary = [ordered]@{
            Included = [bool]$issueSummaryIncluded
            FileName = if ($issueSummaryIncluded) { 'issue_summary.md' } else { '' }
            LineCount = [int]$issueSummaryLineCount
        }
        CloseoutChecklist = [ordered]@{
            Included = [bool]$closeoutChecklistIncluded
            FileName = if ($closeoutChecklistIncluded) { 'validation_closeout_checklist.md' } else { '' }
            LineCount = [int]$closeoutChecklistLineCount
        }
        IssueComments = [ordered]@{
            Included = ([int]$issueCommentCount -gt 0)
            Directory = if ([int]$issueCommentCount -gt 0) { 'issue_comments' } else { '' }
            CommentCount = [int]$issueCommentCount
            ManifestIncluded = [bool]$issueCommentManifestIncluded
            PostCommandsIncluded = [bool]$issueCommentPostCommandsIncluded
            PublishPreviewIncluded = [bool]$issueCommentPublishPreviewIncluded
            PublishPreviewRowCount = [int]$issueCommentPublishPreviewRowCount
        }
        Notes = @(
            'This file summarizes lab validation evidence from redacted bundle artifacts.',
            'Raw run paths and evidence details are replaced with redacted values or stable tokens.',
            'Use the companion lab evidence files for row-level status review.'
        )
    }
    $labDiagnosticsPath = Join-Path $BundlePath 'lab_run_diagnostics.json'
    $labDiagnostics | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $labDiagnosticsPath -Encoding UTF8
    [void]$fileDiagnostics.Add((New-ShareSurferSupportBundleFileDiagnostic -Path $labDiagnosticsPath -FileName 'lab_run_diagnostics.json' -RowCount 1))

    @($fileDiagnostics)
}

function New-ShareSurferRedactedLabCsv {
    param(
        [Parameter(Mandatory = $true)]
        [string] $SourcePath,

        [Parameter(Mandatory = $true)]
        [string] $DestinationPath,

        [string[]] $RedactColumns = @(),

        [ValidateSet('StableToken', 'Strict')]
        [string] $RedactionMode = 'StableToken',

        [string] $RedactionSalt = 'ShareSurfer'
    )

    if (-not (Test-Path -LiteralPath $SourcePath)) {
        return @()
    }

    $rows = @(Import-Csv -LiteralPath $SourcePath)
    $redactedRows = foreach ($row in $rows) {
        $record = [ordered]@{}
        foreach ($property in $row.PSObject.Properties) {
            $columnName = [string]$property.Name
            if ($RedactColumns -contains $columnName) {
                $record[$columnName] = Protect-ShareSurferValue -Value $property.Value -ColumnName 'Detail' -RedactionMode $RedactionMode -RedactionSalt $RedactionSalt
            }
            else {
                $record[$columnName] = [string]$property.Value
            }
        }
        [pscustomobject]$record
    }

    @($redactedRows) | Export-Csv -LiteralPath $DestinationPath -NoTypeInformation -Encoding UTF8
    @($redactedRows)
}

function New-ShareSurferRedactedLabRunEvents {
    param(
        [Parameter(Mandatory = $true)]
        [string] $SourcePath,

        [Parameter(Mandatory = $true)]
        [string] $DestinationPath,

        [ValidateSet('StableToken', 'Strict')]
        [string] $RedactionMode = 'StableToken',

        [string] $RedactionSalt = 'ShareSurfer'
    )

    if (-not (Test-Path -LiteralPath $SourcePath)) {
        return @()
    }

    $rows = New-Object System.Collections.ArrayList
    foreach ($line in @(Get-Content -LiteralPath $SourcePath -ErrorAction SilentlyContinue)) {
        if ([string]::IsNullOrWhiteSpace($line)) {
            continue
        }

        try {
            $event = $line | ConvertFrom-Json
        }
        catch {
            $event = [pscustomobject]@{
                Timestamp = ''
                Phase = 'ParseError'
                Level = 'Warning'
                Message = 'Unable to parse lab run event line.'
                Detail = $line
            }
        }

        $record = [ordered]@{
            Timestamp = if ($event.PSObject.Properties['Timestamp']) { [string]$event.Timestamp } else { '' }
            Phase = if ($event.PSObject.Properties['Phase']) { [string]$event.Phase } else { '' }
            Level = if ($event.PSObject.Properties['Level']) { [string]$event.Level } else { '' }
            Message = if ($event.PSObject.Properties['Message']) { [string]$event.Message } else { '' }
            Detail = if ($event.PSObject.Properties['Detail']) { Protect-ShareSurferValue -Value $event.Detail -ColumnName 'Detail' -RedactionMode $RedactionMode -RedactionSalt $RedactionSalt } else { '' }
        }
        [void]$rows.Add([pscustomobject]$record)
    }

    Export-ShareSurferJsonLines -Path $DestinationPath -Rows @($rows)
    @($rows)
}

function New-ShareSurferRedactedLabJsonSummary {
    param(
        [Parameter(Mandatory = $true)]
        [string] $SourcePath,

        [Parameter(Mandatory = $true)]
        [ValidateSet('LiveEvidence', 'Acceptance', 'AcceptanceSummary')]
        [string] $Kind,

        [ValidateSet('StableToken', 'Strict')]
        [string] $RedactionMode = 'StableToken',

        [string] $RedactionSalt = 'ShareSurfer'
    )

    if (-not (Test-Path -LiteralPath $SourcePath)) {
        return $null
    }

    $source = Get-Content -LiteralPath $SourcePath -Raw | ConvertFrom-Json
    if ($Kind -eq 'LiveEvidence') {
        return [ordered]@{
            IsValid = [bool]$source.IsValid
            FallbackCount = [int]$source.FallbackCount
            FallbackCriteria = @($source.FallbackCriteria | ForEach-Object { [string]$_ })
            FallbackEvidenceSources = @($source.FallbackEvidenceSources | ForEach-Object { [string]$_ })
        }
    }

    if ($Kind -eq 'AcceptanceSummary') {
        return [ordered]@{
            SummaryType = [string]$source.SummaryType
            GeneratedAt = [string]$source.GeneratedAt
            IsValid = [bool]$source.IsValid
            RequireLiveEvidence = [bool]$source.RequireLiveEvidence
            CheckCount = [int]$source.CheckCount
            PassedCheckCount = [int]$source.PassedCheckCount
            FailedCheckCount = [int]$source.FailedCheckCount
            FailedChecks = @($source.FailedChecks | ForEach-Object { [string]$_ })
            Checks = @($source.Checks | ForEach-Object {
                [ordered]@{
                    Name = [string]$_.Name
                    Passed = [bool]$_.Passed
                }
            })
            DetailPolicy = [string]$source.DetailPolicy
        }
    }

    [ordered]@{
        IsValid = [bool]$source.IsValid
        RequireLiveEvidence = [bool]$source.RequireLiveEvidence
        FailedCheckCount = [int]$source.FailedCheckCount
        Checks = @($source.Checks | ForEach-Object {
            [ordered]@{
                Name = [string]$_.Name
                Passed = [bool]$_.Passed
                Detail = Protect-ShareSurferValue -Value $_.Detail -ColumnName 'Detail' -RedactionMode $RedactionMode -RedactionSalt $RedactionSalt
            }
        })
    }
}

function New-ShareSurferSupportBundleFileDiagnostic {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Path,

        [Parameter(Mandatory = $true)]
        [string] $FileName,

        [Parameter(Mandatory = $true)]
        [int] $RowCount
    )

    [pscustomobject]@{
        FileName = $FileName
        RowCount = $RowCount
        Sha256 = Get-ShareSurferFileSha256 -Path $Path
    }
}

function New-ShareSurferSupportBundleDiagnostics {
    param(
        [Parameter(Mandatory = $true)]
        [string] $BundlePath,

        [Parameter(Mandatory = $true)]
        [string] $GeneratedAt,

        [Parameter(Mandatory = $true)]
        [string] $RedactionMode,

        [switch] $ReportIncluded,

        [switch] $LabRunIncluded,

        $LabRunFileDiagnostics = @(),

        [Parameter(Mandatory = $true)]
        $Validation,

        [Parameter(Mandatory = $true)]
        [int] $RedactionLeakCount,

        [Parameter(Mandatory = $true)]
        $FileDiagnostics
    )

    $shares = @(Read-ShareSurferCsv -Path (Join-Path $BundlePath 'shares.csv'))
    $items = @(Read-ShareSurferCsv -Path (Join-Path $BundlePath 'items.csv'))
    $sharePermissions = @(Read-ShareSurferCsv -Path (Join-Path $BundlePath 'share_permissions.csv'))
    $aclEntries = @(Read-ShareSurferCsv -Path (Join-Path $BundlePath 'acl_entries.csv'))
    $identities = @(Read-ShareSurferCsv -Path (Join-Path $BundlePath 'identities.csv'))
    $groupEdges = @(Read-ShareSurferCsv -Path (Join-Path $BundlePath 'group_edges.csv'))
    $permissionedGroups = @(Read-ShareSurferCsv -Path (Join-Path $BundlePath 'permissioned_groups.csv'))
    $ownerPivots = @(Read-ShareSurferCsv -Path (Join-Path $BundlePath 'owner_risk_pivots.csv'))
    $relatedDataAreas = @(Read-ShareSurferCsv -Path (Join-Path $BundlePath 'related_data_areas.csv'))
    $ownerReviewPackets = @(Read-ShareSurferCsv -Path (Join-Path $BundlePath 'owner_review_packets.csv'))
    $findings = @(Read-ShareSurferCsv -Path (Join-Path $BundlePath 'findings.csv'))
    $collectionErrors = @(Read-ShareSurferCsv -Path (Join-Path $BundlePath 'collection_errors.csv'))
    $conflicts = @(Read-ShareSurferCsv -Path (Join-Path $BundlePath 'conflicts.csv'))
    $events = @(Read-ShareSurferCsv -Path (Join-Path $BundlePath 'scan_events.csv'))
    $manifestRows = @(Read-ShareSurferCsv -Path (Join-Path $BundlePath 'scan_manifest.csv'))
    $manifest = $null
    if ($manifestRows.Count -gt 0) {
        $manifest = $manifestRows[0]
    }

    $scanSettings = [ordered]@{}
    foreach ($column in @('ExportVersion', 'ObsAttribute', 'SourceMode', 'OperationalPathLengthThreshold', 'AzurePathComponentLimit', 'AzureFullPathLimit', 'ExplicitAceDepthThreshold', 'GroupExpansionMaxDepth', 'AdLookupMode')) {
        if ($null -ne $manifest -and $null -ne $manifest.PSObject.Properties[$column]) {
            $scanSettings[$column] = [string]$manifest.$column
        }
    }

    $partialShares = @($shares | Where-Object { [string]$_.PartialData -eq 'True' })
    if ($collectionErrors.Count -eq 0) {
        $collectionErrors = @($findings | Where-Object { [string]$_.FindingType -eq 'CollectionError' } | ForEach-Object {
            [pscustomobject]@{
                ErrorId = [string]$_.FindingId
                ShareId = [string]$_.ShareId
                ItemId = [string]$_.ItemId
                FullPath = [string]$_.FullPath
                ErrorType = [string]$_.ObservedValue
                Severity = [string]$_.Severity
                Source = 'findings.csv'
                Message = [string]$_.Message
                Detail = ''
            }
        })
    }
    $highFindings = @($findings | Where-Object { @('Critical', 'High') -contains [string]$_.Severity })
    $highConflicts = @($conflicts | Where-Object { @('Critical', 'High') -contains [string]$_.Severity })

    [ordered]@{
        BundleType = 'ShareSurferRedactedSupportBundleDiagnostics'
        GeneratedAt = $GeneratedAt
        RedactionMode = $RedactionMode
        RelationshipPreserving = [bool]($RedactionMode -eq 'StableToken')
        ReportIncluded = [bool]$ReportIncluded
        LabRunEvidence = [ordered]@{
            Included = [bool]$LabRunIncluded
            FileCount = @($LabRunFileDiagnostics).Count
            Files = @($LabRunFileDiagnostics | ForEach-Object {
                [ordered]@{
                    FileName = [string]$_.FileName
                    RowCount = [int]$_.RowCount
                    Sha256 = [string]$_.Sha256
                }
            })
        }
        Validation = [ordered]@{
            IsValid = [bool]$Validation.IsValid
            MissingFileCount = @($Validation.MissingFiles).Count
            SchemaErrorCount = @($Validation.SchemaErrors).Count
        }
        Redaction = [ordered]@{
            LeakCount = [int]$RedactionLeakCount
            LeakDetected = ([int]$RedactionLeakCount -gt 0)
        }
        ScanSettings = $scanSettings
        Inventory = [ordered]@{
            ShareCount = $shares.Count
            PartialShareCount = $partialShares.Count
            ItemCount = $items.Count
            FileCount = @($items | Where-Object { [string]$_.ItemType -eq 'File' }).Count
            DirectoryCount = @($items | Where-Object { [string]$_.ItemType -eq 'Directory' }).Count
            SharePermissionCount = $sharePermissions.Count
            AclEntryCount = $aclEntries.Count
            IdentityCount = $identities.Count
            GroupEdgeCount = $groupEdges.Count
            PermissionedGroupCount = $permissionedGroups.Count
            OwnerRiskPivotCount = $ownerPivots.Count
            RelatedDataAreaCount = $relatedDataAreas.Count
            OwnerReviewPacketCount = $ownerReviewPackets.Count
            FindingCount = $findings.Count
            HighFindingCount = $highFindings.Count
            ConflictCount = $conflicts.Count
            HighConflictCount = $highConflicts.Count
            ScanEventCount = $events.Count
            CollectionErrorCount = $collectionErrors.Count
        }
        Rollups = [ordered]@{
            FindingsByType = @(Group-ShareSurferSupportBundleRows -Rows $findings -Field 'FindingType')
            FindingsBySeverity = @(Group-ShareSurferSupportBundleRows -Rows $findings -Field 'Severity')
            ConflictsByType = @(Group-ShareSurferSupportBundleRows -Rows $conflicts -Field 'ConflictType')
            ConflictsBySeverity = @(Group-ShareSurferSupportBundleRows -Rows $conflicts -Field 'Severity')
            CollectionErrorsByType = @(Group-ShareSurferSupportBundleRows -Rows $collectionErrors -Field 'ErrorType')
            ScanEventsByType = @(Group-ShareSurferSupportBundleRows -Rows $events -Field 'EventType')
        }
        Files = @($FileDiagnostics | ForEach-Object {
            [ordered]@{
                FileName = [string]$_.FileName
                RowCount = [int]$_.RowCount
                Sha256 = [string]$_.Sha256
            }
        })
        Notes = @(
            'This diagnostics file is generated from redacted bundle data only.',
            'It is intended for support triage without opening every CSV file.',
            'It does not include the redaction salt or any reversal map.'
        )
    }
}

function Group-ShareSurferSupportBundleRows {
    param(
        $Rows = @(),
        [string] $Field
    )

    @($Rows |
        Group-Object -Property $Field |
        Sort-Object @{ Expression = 'Count'; Descending = $true }, Name |
        ForEach-Object {
            [ordered]@{
                Name = if ([string]::IsNullOrWhiteSpace([string]$_.Name)) { 'Unspecified' } else { [string]$_.Name }
                Count = [int]$_.Count
            }
        })
}

function Get-ShareSurferFileSha256 {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Path
    )

    $sha = [System.Security.Cryptography.SHA256]::Create()
    $stream = [System.IO.File]::OpenRead($Path)
    try {
        $hash = $sha.ComputeHash($stream)
        ([System.BitConverter]::ToString($hash)).Replace('-', '')
    }
    finally {
        $stream.Dispose()
        $sha.Dispose()
    }
}

function New-ShareSurferRedactionAudit {
    param(
        [Parameter(Mandatory = $true)]
        [string] $ExportPath,

        [Parameter(Mandatory = $true)]
        [string] $BundlePath,

        [Parameter(Mandatory = $true)]
        [hashtable] $Schema,

        [Parameter(Mandatory = $true)]
        [string] $RedactionSalt,

        [string] $RunRoot = ''
    )

    $bundleFiles = @(Get-ChildItem -LiteralPath $BundlePath -File -ErrorAction SilentlyContinue | Where-Object {
        $_.Name -ne 'support_bundle_redaction_audit.csv'
    })
    $bundleContents = @{}
    foreach ($file in $bundleFiles) {
        try {
            $bundleContents[$file.Name] = Get-Content -LiteralPath $file.FullName -Raw -ErrorAction Stop
        }
        catch {
            $bundleContents[$file.Name] = ''
        }
    }

    $seen = @{}
    foreach ($fileName in $Schema.Keys) {
        $rows = @(Read-ShareSurferCsv -Path (Join-Path $ExportPath $fileName))
        foreach ($row in $rows) {
            $rowType = ''
            foreach ($typeColumn in @('FindingType', 'ConflictType')) {
                $typeProperty = $row.PSObject.Properties[$typeColumn]
                if ($null -ne $typeProperty -and $null -ne $typeProperty.Value) {
                    $rowType = [string]$typeProperty.Value
                    break
                }
            }

            foreach ($column in $Schema[$fileName]) {
                $property = $row.PSObject.Properties[$column]
                if ($null -eq $property) {
                    continue
                }
                $value = [string]$property.Value
                if (-not (Test-ShareSurferRedactionAuditValue -Value $value -ColumnName $column -RowType $rowType)) {
                    continue
                }

                $key = '{0}|{1}|{2}' -f $fileName, $column, $value
                if ($seen.ContainsKey($key)) {
                    continue
                }
                $seen[$key] = $true

                New-ShareSurferRedactionAuditRow -SourceFile $fileName -ColumnName $column -Value $value -BundleFiles $bundleFiles -BundleContents $bundleContents -RedactionSalt $RedactionSalt
            }
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($RunRoot) -and (Test-Path -LiteralPath $RunRoot)) {
        foreach ($sourceValue in @(Get-ShareSurferLabRunRedactionAuditValues -RunRoot $RunRoot)) {
            $value = [string]$sourceValue.Value
            if (-not (Test-ShareSurferRedactionAuditValue -Value $value -ColumnName ([string]$sourceValue.ColumnName))) {
                continue
            }

            $key = '{0}|{1}|{2}' -f [string]$sourceValue.SourceFile, [string]$sourceValue.ColumnName, $value
            if ($seen.ContainsKey($key)) {
                continue
            }
            $seen[$key] = $true

            New-ShareSurferRedactionAuditRow -SourceFile ([string]$sourceValue.SourceFile) -ColumnName ([string]$sourceValue.ColumnName) -Value $value -BundleFiles $bundleFiles -BundleContents $bundleContents -RedactionSalt $RedactionSalt
        }
    }
}

function New-ShareSurferRedactionAuditRow {
    param(
        [Parameter(Mandatory = $true)]
        [string] $SourceFile,

        [Parameter(Mandatory = $true)]
        [string] $ColumnName,

        [Parameter(Mandatory = $true)]
        [string] $Value,

        [Parameter(Mandatory = $true)]
        $BundleFiles,

        [Parameter(Mandatory = $true)]
        [hashtable] $BundleContents,

        [Parameter(Mandatory = $true)]
        [string] $RedactionSalt
    )

    $leakFiles = New-Object System.Collections.ArrayList
    foreach ($bundleFile in $BundleFiles) {
        $content = [string]$BundleContents[$bundleFile.Name]
        if ($content -ne '' -and $content.IndexOf($Value, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
            [void]$leakFiles.Add($bundleFile.Name)
        }
    }

    [pscustomobject]@{
        SourceFile = $SourceFile
        ColumnName = $ColumnName
        ValueToken = Get-ShareSurferStableToken -Value $Value -Salt $RedactionSalt
        ValueLength = $Value.Length
        CheckedFileCount = $BundleFiles.Count
        LeakDetected = ($leakFiles.Count -gt 0)
        LeakFiles = (@($leakFiles) -join ';')
    }
}

function Get-ShareSurferLabRunRedactionAuditValues {
    param(
        [Parameter(Mandatory = $true)]
        [string] $RunRoot
    )

    foreach ($definition in @(
        [pscustomobject]@{ FileName = 'lab-preflight.csv'; Columns = @('Evidence') },
        [pscustomobject]@{ FileName = 'lab-validation-criteria.csv'; Columns = @('EvidenceDetail') },
        [pscustomobject]@{ FileName = 'live-evidence-review.csv'; Columns = @('EvidenceDetail') }
    )) {
        $path = Join-Path $RunRoot $definition.FileName
        if (-not (Test-Path -LiteralPath $path)) {
            continue
        }

        foreach ($row in @(Import-Csv -LiteralPath $path)) {
            foreach ($column in @($definition.Columns)) {
                $property = $row.PSObject.Properties[$column]
                if ($null -eq $property) {
                    continue
                }
                [pscustomobject]@{
                    SourceFile = $definition.FileName
                    ColumnName = $column
                    Value = [string]$property.Value
                }
            }
        }
    }

    $eventPath = Join-Path $RunRoot 'lab-run-events.jsonl'
    if (Test-Path -LiteralPath $eventPath) {
        foreach ($line in @(Get-Content -LiteralPath $eventPath -ErrorAction SilentlyContinue)) {
            if ([string]::IsNullOrWhiteSpace($line)) {
                continue
            }

            try {
                $event = $line | ConvertFrom-Json
            }
            catch {
                $event = [pscustomobject]@{ Detail = $line }
            }

            if ($event.PSObject.Properties['Detail']) {
                [pscustomobject]@{
                    SourceFile = 'lab-run-events.jsonl'
                    ColumnName = 'Detail'
                    Value = [string]$event.Detail
                }
            }
        }
    }

    $acceptancePath = Join-Path $RunRoot 'v1-acceptance.json'
    if (Test-Path -LiteralPath $acceptancePath) {
        try {
            $acceptance = Get-Content -LiteralPath $acceptancePath -Raw | ConvertFrom-Json
            foreach ($check in @($acceptance.Checks)) {
                if ($check.PSObject.Properties['Detail']) {
                    [pscustomobject]@{
                        SourceFile = 'v1-acceptance.json'
                        ColumnName = 'Checks.Detail'
                        Value = [string]$check.Detail
                    }
                }
            }
        }
        catch {
            [pscustomobject]@{
                SourceFile = 'v1-acceptance.json'
                ColumnName = 'Detail'
                Value = [string](Get-Content -LiteralPath $acceptancePath -Raw -ErrorAction SilentlyContinue)
            }
        }
    }
}

function Test-ShareSurferRedactionAuditValue {
    param(
        [string] $Value,
        [string] $ColumnName = '',
        [string] $RowType = ''
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $false
    }

    $preserveColumns = @(
        'AccessControlType',
        'Rights',
        'Source',
        'Sources',
        'ItemType',
        'Depth',
        'IsInherited',
        'InheritanceFlags',
        'PropagationFlags',
        'InheritanceEnabled',
        'PartialData',
        'PartialReason',
        'AccountEnabled',
        'MigrationReadiness',
        'MatchingShares',
        'MatchingItems',
        'Directories',
        'Files',
        'FindingCount',
        'ConflictCount',
        'ReviewItemCount',
        'PartialShareCount',
        'DirectIdentityCount',
        'DirectGroupCount',
        'ExpandedMemberCount',
        'RelatedBecause',
        'SuggestedNextAction',
        'ReviewStatus',
        'WhyReview',
        'WhatToReviewFirst',
        'RelatedDataAreaCount',
        'RiskLevel',
        'ObjectClass',
        'ChildObjectClass',
        'IsCycle',
        'IsTruncated',
        'HasCycle',
        'ConflictType',
        'FindingType',
        'ErrorType',
        'Severity',
        'PolicyValue',
        'ExportVersion',
        'SourceMode',
        'OperationalPathLengthThreshold',
        'AzurePathComponentLimit',
        'AzureFullPathLimit',
        'ExplicitAceDepthThreshold',
        'GroupExpansionMaxDepth',
        'AdLookupMode',
        'ObsAttribute',
        'GeneratedAt'
    )
    $structuralColumns = @(
        'ShareId',
        'ItemId',
        'FindingId',
        'ConflictId',
        'ErrorId',
        'RelatedAreaId',
        'ReviewPacketId',
        'EventId',
        'Level',
        'EventType'
    )
    $observedValueSafeRows = @(
        'LongPathOperationalPolicy',
        'AzureFullPathLimit',
        'AzurePathComponentLimit',
        'DeepExplicitAce',
        'GroupExpansionTruncated',
        'PartialSharePermissionData',
        'CollectionError'
    )

    if ($preserveColumns -contains $ColumnName -or $structuralColumns -contains $ColumnName) {
        return $false
    }
    if ($ColumnName -eq 'ObservedValue' -and $observedValueSafeRows -contains $RowType) {
        return $false
    }
    if ($Value -match '^[0-9]+$') {
        return $false
    }
    if (@('True', 'False', 'Allow', 'Deny', 'Read', 'Modify', 'Full') -contains $Value) {
        return $false
    }

    $true
}
