function New-ShareSurferFileShareConnectivityTarget {
    param(
        [Parameter(Mandatory = $true)]
        [string] $AssessmentId,

        [Parameter(Mandatory = $true)]
        [int] $Index,

        [Parameter(Mandatory = $true)]
        [string] $InputType,

        [Parameter(Mandatory = $true)]
        [string] $Target,

        [string] $ComputerName = '',
        [string] $ShareName = ''
    )

    $uncPath = ''
    if (-not [string]::IsNullOrWhiteSpace($ComputerName) -and -not [string]::IsNullOrWhiteSpace($ShareName)) {
        $uncPath = '\\{0}\{1}' -f $ComputerName, $ShareName
    }

    [pscustomobject]@{
        AssessmentId = $AssessmentId
        TargetId = 'target-{0:000}' -f $Index
        Target = $Target
        InputType = $InputType
        ComputerName = $ComputerName
        ShareName = $ShareName
        UNCPath = $uncPath
    }
}

function Get-ShareSurferFileShareConnectivityTargets {
    param(
        [string[]] $TargetPath,
        [string[]] $ComputerName,
        [string[]] $ShareName,
        [string] $AssessmentId
    )

    $targets = New-Object System.Collections.ArrayList
    $index = 0

    foreach ($path in @($TargetPath)) {
        if ([string]::IsNullOrWhiteSpace($path)) {
            continue
        }

        $normalized = ([string]$path).Trim()
        if ($normalized -match '^//') {
            $normalized = $normalized -replace '/', '\'
        }

        if ($normalized -match '^\\\\([^\\]+)\\([^\\]+)') {
            $index++
            [void]$targets.Add((New-ShareSurferFileShareConnectivityTarget -AssessmentId $AssessmentId -Index $index -InputType 'UNCPath' -Target $normalized -ComputerName $matches[1] -ShareName $matches[2]))
        }
        else {
            $index++
            [void]$targets.Add((New-ShareSurferFileShareConnectivityTarget -AssessmentId $AssessmentId -Index $index -InputType 'PathOrComputer' -Target $normalized -ComputerName $normalized))
        }
    }

    $computerNames = @($ComputerName | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    $shareNames = @($ShareName | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    foreach ($computer in $computerNames) {
        if ($shareNames.Count -eq 0) {
            $index++
            [void]$targets.Add((New-ShareSurferFileShareConnectivityTarget -AssessmentId $AssessmentId -Index $index -InputType 'ComputerName' -Target $computer -ComputerName $computer))
            continue
        }

        foreach ($share in $shareNames) {
            $index++
            $target = '\\{0}\{1}' -f $computer, $share
            [void]$targets.Add((New-ShareSurferFileShareConnectivityTarget -AssessmentId $AssessmentId -Index $index -InputType 'ComputerShare' -Target $target -ComputerName $computer -ShareName $share))
        }
    }

    @($targets)
}

function New-ShareSurferFileShareConnectivityCheck {
    param(
        [Parameter(Mandatory = $true)]
        [string] $AssessmentId,

        [Parameter(Mandatory = $true)]
        [int] $Index,

        [Parameter(Mandatory = $true)]
        $Target,

        [Parameter(Mandatory = $true)]
        [string] $Layer,

        [Parameter(Mandatory = $true)]
        [string] $Capability,

        [string] $Provider = '',
        [string] $Attempted = 'True',
        [string] $Status = 'Skipped',
        [string] $Severity = 'Review',
        [string] $EvidenceType = '',
        [string] $RawResultCode = '',
        [string] $Message = '',
        [string] $Detail = '',
        [string] $RecommendedAction = ''
    )

    [pscustomobject]@{
        AssessmentId = $AssessmentId
        CheckId = 'check-{0:0000}' -f $Index
        TargetId = [string]$Target.TargetId
        Target = [string]$Target.Target
        InputType = [string]$Target.InputType
        ComputerName = [string]$Target.ComputerName
        ShareName = [string]$Target.ShareName
        Layer = $Layer
        Capability = $Capability
        Provider = $Provider
        Attempted = $Attempted
        Status = $Status
        Severity = $Severity
        EvidenceType = $EvidenceType
        RawResultCode = $RawResultCode
        Message = $Message
        Detail = $Detail
        RecommendedAction = $RecommendedAction
    }
}

function Invoke-ShareSurferFileShareConnectivityProvider {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Action,

        [Parameter(Mandatory = $true)]
        $Context
    )

    $provider = Get-Variable -Name 'ShareSurferFileShareConnectivityProvider' -Scope Global -ErrorAction SilentlyContinue
    if ($null -eq $provider -or -not ($provider.Value -is [scriptblock])) {
        return $null
    }

    & $provider.Value -Action $Action -Context $Context
}

function ConvertTo-ShareSurferFileShareConnectivityProviderCheck {
    param(
        $ProviderResult,
        [string] $AssessmentId,
        [int] $Index,
        $Target,
        [string] $Layer,
        [string] $Capability,
        [string] $Provider,
        [string] $DefaultRecommendedAction
    )

    if ($null -eq $ProviderResult) {
        return $null
    }

    $status = if ([string]::IsNullOrWhiteSpace([string]$ProviderResult.Status)) { 'Skipped' } else { [string]$ProviderResult.Status }
    $severity = if ([string]::IsNullOrWhiteSpace([string]$ProviderResult.Severity)) {
        switch ($status) {
            'Pass' { 'Info' }
            'Warning' { 'Warning' }
            'Fail' { 'High' }
            default { 'Review' }
        }
    }
    else {
        [string]$ProviderResult.Severity
    }

    New-ShareSurferFileShareConnectivityCheck -AssessmentId $AssessmentId -Index $Index -Target $Target -Layer $Layer -Capability $Capability -Provider $Provider -Attempted 'True' -Status $status -Severity $severity -EvidenceType ([string]$ProviderResult.EvidenceType) -RawResultCode ([string]$ProviderResult.RawResultCode) -Message ([string]$ProviderResult.Message) -Detail ([string]$ProviderResult.Detail) -RecommendedAction $(if ([string]::IsNullOrWhiteSpace([string]$ProviderResult.RecommendedAction)) { $DefaultRecommendedAction } else { [string]$ProviderResult.RecommendedAction })
}

function Get-ShareSurferFileShareConnectivityTargetStatus {
    param($Checks)

    $targetChecks = @($Checks)
    if (@($targetChecks | Where-Object { $_.Status -eq 'Fail' -and $_.Severity -eq 'High' }).Count -gt 0) {
        return 'Blocked'
    }
    if (@($targetChecks | Where-Object { $_.Status -eq 'Fail' -or $_.Status -eq 'Warning' }).Count -gt 0) {
        return 'NeedsReview'
    }
    if (@($targetChecks | Where-Object { $_.Status -eq 'Pass' }).Count -gt 0) {
        return 'CollectionReady'
    }
    'NotProven'
}

function Get-ShareSurferFileShareConnectivityRecommendedProvider {
    param($Checks)

    $targetChecks = @($Checks)
    $cimReady = (@($targetChecks | Where-Object { $_.Capability -eq 'CimSession' -and $_.Status -eq 'Pass' }).Count -gt 0) -and
        (@($targetChecks | Where-Object { $_.Capability -eq 'CimShareMetadata' -and $_.Status -eq 'Pass' }).Count -gt 0) -and
        (@($targetChecks | Where-Object { $_.Capability -eq 'CimSharePermissions' -and $_.Status -eq 'Pass' }).Count -gt 0)
    if ($cimReady) {
        return 'PowerShellCim'
    }

    $nativeReady = (@($targetChecks | Where-Object { $_.Capability -eq 'NativeShareMetadata' -and $_.Status -eq 'Pass' }).Count -gt 0) -and
        (@($targetChecks | Where-Object { $_.Capability -eq 'NativeShareDescriptorParsed' -and $_.Status -eq 'Pass' }).Count -gt 0) -and
        (@($targetChecks | Where-Object { $_.Capability -eq 'FileSystemSecurityDescriptorRead' -and $_.Status -eq 'Pass' }).Count -gt 0)
    if ($nativeReady) {
        return 'NativeSmbRpc'
    }

    if (@($targetChecks | Where-Object { $_.Capability -eq 'SmbTcp445' -and $_.Status -eq 'Pass' }).Count -gt 0) {
        return 'NeedsReview'
    }

    'Blocked'
}

function Get-ShareSurferFileShareConnectivitySuggestedAction {
    param(
        [string] $TargetStatus,
        [string] $RecommendedProvider
    )

    if ($TargetStatus -eq 'CollectionReady') {
        return ('Run Invoke-ShareSurferScan with provider {0} or keep current successful provider.' -f $RecommendedProvider)
    }
    if ($RecommendedProvider -eq 'NeedsReview') {
        return 'SMB transport is reachable, but collection evidence is incomplete. Review failed capability rows before trusting scan results.'
    }
    if ($TargetStatus -eq 'NotProven') {
        return 'No live collection proof was attempted. Rerun without skip switches when ready.'
    }

    'Resolve blocked transport, authentication, permissions, or descriptor-read failures before scan acceptance.'
}

function New-ShareSurferFileShareConnectivityEventRows {
    param(
        [string] $AssessmentId,
        $Checks
    )

    $events = New-Object System.Collections.ArrayList
    $index = 0
    foreach ($check in @($Checks)) {
        $index++
        [void]$events.Add([pscustomobject]@{
            EventId = 'event-{0:0000}' -f $index
            AssessmentId = $AssessmentId
            Timestamp = (Get-Date).ToUniversalTime().ToString('o')
            TargetId = [string]$check.TargetId
            CheckId = [string]$check.CheckId
            Layer = [string]$check.Layer
            Capability = [string]$check.Capability
            Provider = [string]$check.Provider
            Status = [string]$check.Status
            Severity = [string]$check.Severity
            EvidenceType = [string]$check.EvidenceType
            RawResultCode = [string]$check.RawResultCode
            Message = [string]$check.Message
            Detail = [string]$check.Detail
            RecommendedAction = [string]$check.RecommendedAction
        })
    }

    @($events)
}

function Write-ShareSurferFileShareConnectivityJsonLines {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Path,

        $Rows
    )

    $lines = New-Object System.Collections.ArrayList
    foreach ($row in @($Rows)) {
        [void]$lines.Add(($row | ConvertTo-Json -Depth 8 -Compress))
    }

    Set-Content -LiteralPath $Path -Value @($lines) -Encoding UTF8
}

function New-ShareSurferFileShareConnectivityToken {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Value,

        [Parameter(Mandatory = $true)]
        [string] $Prefix,

        [Parameter(Mandatory = $true)]
        [string] $Salt
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return ''
    }

    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($Salt + '|' + $Prefix + '|' + $Value)
        $hash = $sha.ComputeHash($bytes)
        $hex = -join ($hash[0..5] | ForEach-Object { $_.ToString('x2') })
        return ('{0}_{1}' -f $Prefix, $hex)
    }
    finally {
        $sha.Dispose()
    }
}

function Protect-ShareSurferFileShareConnectivityText {
    param(
        [string] $Value,
        [hashtable] $TokenMap
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return ''
    }

    $redacted = [string]$Value
    foreach ($key in @($TokenMap.Keys | Sort-Object { [string]$_ } -Descending)) {
        if ([string]::IsNullOrWhiteSpace([string]$key)) {
            continue
        }

        $redacted = $redacted.Replace([string]$key, [string]$TokenMap[$key])
    }

    if ($redacted -eq $Value) {
        return 'Provider detail redacted. See raw diagnostic output for exact host, share, path, user, or exception text.'
    }

    $redacted
}

function New-ShareSurferFileShareConnectivityTokenMap {
    param(
        $ManifestRows,
        $TargetRows,
        $CheckRows,
        $EventRows,
        [string] $Salt
    )

    $map = @{}
    $columns = @(
        'CollectorComputerName',
        'CollectorFqdn',
        'CollectorUser',
        'UserDomain',
        'Target',
        'ComputerName',
        'ShareName',
        'UNCPath'
    )

    foreach ($row in @($ManifestRows + $TargetRows + $CheckRows + $EventRows)) {
        if ($null -eq $row) {
            continue
        }

        foreach ($column in $columns) {
            if ($row.PSObject.Properties.Name -notcontains $column) {
                continue
            }

            $value = [string]$row.$column
            if ([string]::IsNullOrWhiteSpace($value) -or $map.ContainsKey($value)) {
                continue
            }

            $prefix = 'VALUE'
            if ($column -like '*Computer*' -or $column -eq 'CollectorFqdn') {
                $prefix = 'HOST'
            }
            elseif ($column -like '*User*' -or $column -eq 'UserDomain') {
                $prefix = 'USER'
            }
            elseif ($column -eq 'ShareName') {
                $prefix = 'SHARE'
            }
            elseif ($column -eq 'Target' -or $column -eq 'UNCPath') {
                $prefix = 'PATH'
            }

            $map[$value] = New-ShareSurferFileShareConnectivityToken -Value $value -Prefix $prefix -Salt $Salt
        }
    }

    $map
}

function Protect-ShareSurferFileShareConnectivityRows {
    param(
        $Rows,
        [hashtable] $TokenMap,
        [string[]] $SensitiveColumns,
        [string[]] $DetailColumns
    )

    $protected = New-Object System.Collections.ArrayList
    foreach ($row in @($Rows)) {
        $record = [ordered]@{}
        foreach ($property in $row.PSObject.Properties) {
            $name = [string]$property.Name
            $value = [string]$property.Value
            if ($DetailColumns -contains $name) {
                $record[$name] = Protect-ShareSurferFileShareConnectivityText -Value $value -TokenMap $TokenMap
            }
            elseif ($SensitiveColumns -contains $name) {
                if ([string]::IsNullOrWhiteSpace($value)) {
                    $record[$name] = ''
                }
                elseif ($TokenMap.ContainsKey($value)) {
                    $record[$name] = $TokenMap[$value]
                }
                else {
                    $record[$name] = New-ShareSurferFileShareConnectivityToken -Value $value -Prefix 'VALUE' -Salt 'adhoc'
                }
            }
            else {
                $record[$name] = $property.Value
            }
        }

        [void]$protected.Add([pscustomobject]$record)
    }

    @($protected)
}

function New-ShareSurferFileShareConnectivityLlmSummary {
    param(
        $Summary,
        $Targets,
        $Checks
    )

    $lines = New-Object System.Collections.ArrayList
    [void]$lines.Add('# ShareSurfer File Share Connectivity Assessment')
    [void]$lines.Add('')
    [void]$lines.Add('This redacted summary is safe to share for troubleshooting. It does not include raw host names, share names, UNC paths, account names, or exception text.')
    [void]$lines.Add('')
    [void]$lines.Add(('Assessment ID: `{0}`' -f $Summary.AssessmentId))
    [void]$lines.Add(('Generated at: `{0}`' -f $Summary.GeneratedAt))
    [void]$lines.Add(('Targets assessed: `{0}`' -f $Summary.TargetCount))
    [void]$lines.Add(('Overall recommendation: `{0}`' -f $Summary.OverallRecommendation))
    [void]$lines.Add('')
    [void]$lines.Add('## Why TCP Is Not Enough')
    [void]$lines.Add('')
    [void]$lines.Add('A successful SMB or RPC port check only proves that a socket opened. It does not prove that ShareSurfer can authenticate, enumerate a share, read share permissions, read owner/DACL security descriptors, parse descriptor bytes, or enumerate open files/sessions.')
    [void]$lines.Add('')
    [void]$lines.Add('## Target Summary')
    foreach ($target in @($Targets)) {
        [void]$lines.Add(('- `{0}` status `{1}`, recommended provider `{2}`, action: {3}' -f $target.TargetId, $target.TargetStatus, $target.RecommendedScanProvider, $target.SuggestedNextAction))
    }
    [void]$lines.Add('')
    [void]$lines.Add('## Capability Matrix')
    foreach ($group in @($Checks | Group-Object Capability | Sort-Object Name)) {
        $pass = @($group.Group | Where-Object { $_.Status -eq 'Pass' }).Count
        $fail = @($group.Group | Where-Object { $_.Status -eq 'Fail' }).Count
        $warning = @($group.Group | Where-Object { $_.Status -eq 'Warning' }).Count
        $skipped = @($group.Group | Where-Object { $_.Status -eq 'Skipped' }).Count
        [void]$lines.Add(('- `{0}`: pass `{1}`, fail `{2}`, warning `{3}`, skipped `{4}`' -f $group.Name, $pass, $fail, $warning, $skipped))
    }
    [void]$lines.Add('')
    [void]$lines.Add('## Blockers And Next Actions')
    foreach ($check in @($Checks | Where-Object { $_.Status -eq 'Fail' -or $_.Status -eq 'Warning' } | Select-Object -First 25)) {
        [void]$lines.Add(('- `{0}` `{1}` on `{2}`: {3}' -f $check.Status, $check.EvidenceType, $check.TargetId, $check.RecommendedAction))
    }
    if (@($Checks | Where-Object { $_.Status -eq 'Fail' -or $_.Status -eq 'Warning' }).Count -eq 0) {
        [void]$lines.Add('- No failed or warning checks were exported.')
    }
    [void]$lines.Add('')
    [void]$lines.Add('## Evidence Inventory')
    [void]$lines.Add('- `fileshare_connectivity_manifest.csv`')
    [void]$lines.Add('- `fileshare_connectivity_targets.csv`')
    [void]$lines.Add('- `fileshare_connectivity_checks.csv`')
    [void]$lines.Add('- `fileshare_connectivity_summary.json`')
    [void]$lines.Add('- `fileshare_connectivity_events.jsonl`')
    [void]$lines.Add('')
    [void]$lines.Add('Share only the redacted folder unless a trusted engineer specifically asks for raw evidence.')
    @($lines) -join [Environment]::NewLine
}

function Export-ShareSurferFileShareConnectivityRedactedPackage {
    param(
        [Parameter(Mandatory = $true)]
        [string] $OutputPath,

        [Parameter(Mandatory = $true)]
        [string] $RedactedPath,

        $ManifestRows,
        $TargetRows,
        $CheckRows,
        $EventRows,
        $Summary,
        [string] $RedactionSalt
    )

    New-Item -ItemType Directory -Path $RedactedPath -Force | Out-Null

    $salt = if ([string]::IsNullOrWhiteSpace($RedactionSalt)) { [string]$Summary.AssessmentId } else { $RedactionSalt }
    $tokenMap = New-ShareSurferFileShareConnectivityTokenMap -ManifestRows $ManifestRows -TargetRows $TargetRows -CheckRows $CheckRows -EventRows $EventRows -Salt $salt
    $sensitiveColumns = @('CollectorComputerName', 'CollectorFqdn', 'CollectorUser', 'UserDomain', 'Target', 'ComputerName', 'ShareName', 'UNCPath')
    $detailColumns = @('Message', 'Detail')

    $redactedManifestRows = Protect-ShareSurferFileShareConnectivityRows -Rows $ManifestRows -TokenMap $tokenMap -SensitiveColumns $sensitiveColumns -DetailColumns $detailColumns
    $redactedTargetRows = Protect-ShareSurferFileShareConnectivityRows -Rows $TargetRows -TokenMap $tokenMap -SensitiveColumns $sensitiveColumns -DetailColumns $detailColumns
    $redactedCheckRows = Protect-ShareSurferFileShareConnectivityRows -Rows $CheckRows -TokenMap $tokenMap -SensitiveColumns $sensitiveColumns -DetailColumns $detailColumns
    $redactedEventRows = Protect-ShareSurferFileShareConnectivityRows -Rows $EventRows -TokenMap $tokenMap -SensitiveColumns $sensitiveColumns -DetailColumns $detailColumns

    $schema = Get-ShareSurferFileShareConnectivityExportSchema
    Export-ShareSurferCsv -Path (Join-Path $RedactedPath 'fileshare_connectivity_manifest.csv') -Columns $schema['fileshare_connectivity_manifest.csv'] -Rows $redactedManifestRows
    Export-ShareSurferCsv -Path (Join-Path $RedactedPath 'fileshare_connectivity_targets.csv') -Columns $schema['fileshare_connectivity_targets.csv'] -Rows $redactedTargetRows
    Export-ShareSurferCsv -Path (Join-Path $RedactedPath 'fileshare_connectivity_checks.csv') -Columns $schema['fileshare_connectivity_checks.csv'] -Rows $redactedCheckRows
    Write-ShareSurferFileShareConnectivityJsonLines -Path (Join-Path $RedactedPath 'fileshare_connectivity_events.jsonl') -Rows $redactedEventRows

    $redactedSummary = [pscustomobject]@{
        AssessmentId = $Summary.AssessmentId
        GeneratedAt = $Summary.GeneratedAt
        PackageKind = $Summary.PackageKind
        TargetCount = $Summary.TargetCount
        CheckCount = $Summary.CheckCount
        PassedCount = $Summary.PassedCount
        WarningCount = $Summary.WarningCount
        FailedCount = $Summary.FailedCount
        SkippedCount = $Summary.SkippedCount
        OverallRecommendation = $Summary.OverallRecommendation
        SafeSharingNote = 'Share the redacted folder only. It contains stable tokens and no reversal map.'
    }
    $redactedSummary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $RedactedPath 'fileshare_connectivity_summary.json') -Encoding UTF8

    $llmSummary = New-ShareSurferFileShareConnectivityLlmSummary -Summary $redactedSummary -Targets $redactedTargetRows -Checks $redactedCheckRows
    Set-Content -LiteralPath (Join-Path $RedactedPath 'fileshare_connectivity_llm_summary.md') -Value $llmSummary -Encoding UTF8

    $manifestRows = New-Object System.Collections.ArrayList
    foreach ($column in $sensitiveColumns) {
        [void]$manifestRows.Add([pscustomobject]@{ SourceFile = 'fileshare_connectivity_*.csv/jsonl'; ColumnName = $column; Strategy = 'StableToken'; RawValuesIncluded = 'False' })
    }
    foreach ($column in $detailColumns) {
        [void]$manifestRows.Add([pscustomobject]@{ SourceFile = 'fileshare_connectivity_*.csv/jsonl'; ColumnName = $column; Strategy = 'TokenizeKnownValuesOrReplaceProviderDetail'; RawValuesIncluded = 'False' })
    }
    Export-ShareSurferCsv -Path (Join-Path $RedactedPath 'fileshare_connectivity_redaction_manifest.csv') -Columns @('SourceFile', 'ColumnName', 'Strategy', 'RawValuesIncluded') -Rows $manifestRows
}

function Test-ShareSurferFileShareConnectivityDiagnosticPackage {
    param([string] $OutputPath)

    $required = @(
        'fileshare_connectivity_manifest.csv',
        'fileshare_connectivity_targets.csv',
        'fileshare_connectivity_checks.csv',
        'fileshare_connectivity_summary.json',
        'fileshare_connectivity_events.jsonl',
        'share_permission_diagnostic_manifest.csv',
        'share_permission_diagnostics.csv',
        'share_permission_diagnostics.jsonl',
        'share_permission_diagnostics.md',
        'redacted/fileshare_connectivity_manifest.csv',
        'redacted/fileshare_connectivity_targets.csv',
        'redacted/fileshare_connectivity_checks.csv',
        'redacted/fileshare_connectivity_summary.json',
        'redacted/fileshare_connectivity_events.jsonl',
        'redacted/fileshare_connectivity_llm_summary.md',
        'redacted/fileshare_connectivity_redaction_manifest.csv',
        'redacted/share_permission_diagnostic_manifest.csv',
        'redacted/share_permission_diagnostics.csv',
        'redacted/share_permission_diagnostics.jsonl',
        'redacted/share_permission_diagnostics.md',
        'redacted/share_permission_diagnostic_redaction_manifest.csv'
    )

    foreach ($fileName in $required) {
        if (-not (Test-Path -LiteralPath (Join-Path $OutputPath $fileName))) {
            return $false
        }
    }

    $true
}

function Get-ShareSurferSharePermissionDiagnosticAttemptedMethod {
    param($Check)

    switch ([string]$Check.Capability) {
        'NameResolution' { return 'Resolve file server name before any share-permission proof.' }
        'SmbTcp445' { return 'Open SMB TCP 445 to prove basic file-share transport only.' }
        'WinRmHttp5985' { return 'Open WinRM HTTP 5985 for possible CIM collection transport.' }
        'WinRmHttps5986' { return 'Open WinRM HTTPS 5986 for possible CIM collection transport.' }
        'RpcEndpointMapper135' { return 'Open RPC endpoint mapper 135 for native or administrative RPC paths.' }
        'CimSession' { return 'Create a remote CIM session with New-CimSession.' }
        'CimShareMetadata' { return 'Read share metadata with Get-SmbShare over CIM.' }
        'CimSharePermissions' { return 'Read share permissions with Get-SmbShareAccess over CIM.' }
        'NativeShareMetadata' { return 'Read share metadata with native NetShareGetInfo.' }
        'NativeShareDescriptorReturned' { return 'Request SHARE_INFO_502 share security descriptor bytes from NetShareGetInfo.' }
        'NativeShareDescriptorParsed' { return 'Parse returned share security descriptor bytes into share permission ACE rows.' }
        'FileSystemSecurityDescriptorRead' { return 'Read owner and DACL evidence from the share root with GetNamedSecurityInfoW.' }
        default { return ('Run {0} through {1}.' -f [string]$Check.Capability, [string]$Check.Provider) }
    }
}

function Get-ShareSurferSharePermissionDiagnosticWhyItMatters {
    param($Check)

    switch ([string]$Check.Capability) {
        'NameResolution' { return 'Share permission checks cannot start if the collector cannot resolve the file server name.' }
        'SmbTcp445' { return 'SMB reachability is necessary for UNC access, but it does not prove that share permissions or security descriptors can be read.' }
        'WinRmHttp5985' { return 'The default PowerShell CIM route commonly needs WinRM. A reachable port still does not prove authentication or SMB cmdlet access.' }
        'WinRmHttps5986' { return 'WinRM over HTTPS may be used in locked-down environments. It is transport evidence, not share-permission proof by itself.' }
        'RpcEndpointMapper135' { return 'RPC reachability can support native or administrative calls, but passing this check does not prove NetShareGetInfo or descriptor parsing.' }
        'CimSession' { return 'Get-SmbShare and Get-SmbShareAccess over CIM require a real session, not just an open WinRM port.' }
        'CimShareMetadata' { return 'Share metadata proves the share name can be resolved by SMB cmdlets before permissions are requested.' }
        'CimSharePermissions' { return 'This is the normal Windows SMB cmdlet proof that share-level permissions were readable.' }
        'NativeShareMetadata' { return 'Native SMB/RPC fallback needs NetShareGetInfo to return the share before share security descriptor checks can continue.' }
        'NativeShareDescriptorReturned' { return 'Native share-permission proof depends on the server returning the share security descriptor, not just confirming the share exists.' }
        'NativeShareDescriptorParsed' { return 'Returned descriptor bytes are only useful if ShareSurfer can parse them into ACE rows.' }
        'FileSystemSecurityDescriptorRead' { return 'ShareSurfer also needs file/folder owner and DACL evidence; this can fail even when share metadata succeeds.' }
        default { return 'This capability affects whether ShareSurfer can trust the share-permission evidence for this target.' }
    }
}

function New-ShareSurferSharePermissionDiagnosticRows {
    param(
        [string] $AssessmentId,
        $Checks
    )

    $sharePermissionCapabilities = @(
        'NameResolution',
        'SmbTcp445',
        'WinRmHttp5985',
        'WinRmHttps5986',
        'RpcEndpointMapper135',
        'CimSession',
        'CimShareMetadata',
        'CimSharePermissions',
        'NativeShareMetadata',
        'NativeShareDescriptorReturned',
        'NativeShareDescriptorParsed',
        'FileSystemSecurityDescriptorRead'
    )

    $rows = New-Object System.Collections.ArrayList
    $index = 0
    foreach ($check in @($Checks | Where-Object { $sharePermissionCapabilities -contains [string]$_.Capability })) {
        $index++
        $status = [string]$check.Status
        $whatSucceeded = ''
        $whatFailed = ''
        if ($status -eq 'Pass') {
            $whatSucceeded = [string]$check.Message
        }
        elseif ($status -eq 'Skipped') {
            $whatFailed = 'This check was not attempted.'
        }
        else {
            $whatFailed = [string]$check.Message
        }

        [void]$rows.Add([pscustomobject]@{
            AssessmentId = $AssessmentId
            DiagnosticId = 'shareperm-{0:0000}' -f $index
            TargetId = [string]$check.TargetId
            Target = [string]$check.Target
            ComputerName = [string]$check.ComputerName
            ShareName = [string]$check.ShareName
            Layer = [string]$check.Layer
            Provider = [string]$check.Provider
            AttemptedMethod = Get-ShareSurferSharePermissionDiagnosticAttemptedMethod -Check $check
            Status = $status
            Severity = [string]$check.Severity
            EvidenceType = [string]$check.EvidenceType
            RawResultCode = [string]$check.RawResultCode
            WhatSucceeded = $whatSucceeded
            WhatFailed = $whatFailed
            WhyItMatters = Get-ShareSurferSharePermissionDiagnosticWhyItMatters -Check $check
            Detail = [string]$check.Detail
            RecommendedAction = [string]$check.RecommendedAction
            SourceCheckId = [string]$check.CheckId
        })
    }

    @($rows)
}

function New-ShareSurferSharePermissionDiagnosticMarkdown {
    param(
        $Manifest,
        $Rows
    )

    $diagnostics = @($Rows)
    $failed = @($diagnostics | Where-Object { $_.Status -eq 'Fail' })
    $warnings = @($diagnostics | Where-Object { $_.Status -eq 'Warning' })
    $skipped = @($diagnostics | Where-Object { $_.Status -eq 'Skipped' })
    $passed = @($diagnostics | Where-Object { $_.Status -eq 'Pass' })

    $lines = New-Object System.Collections.ArrayList
    [void]$lines.Add('# Share Permission Diagnostics')
    [void]$lines.Add('')
    [void]$lines.Add('This diagnostic view focuses on why share-level permissions are, or are not, available to ShareSurfer. TCP port success is treated as transport evidence only.')
    [void]$lines.Add('')
    [void]$lines.Add(('Assessment ID: `{0}`' -f [string]$Manifest.AssessmentId))
    [void]$lines.Add(('Generated at: `{0}`' -f [string]$Manifest.GeneratedAt))
    [void]$lines.Add(('Targets: `{0}`; diagnostics: `{1}`; pass `{2}`; warning `{3}`; fail `{4}`; skipped `{5}`' -f [string]$Manifest.TargetCount, [string]$Manifest.DiagnosticCount, [string]$Manifest.PassedCount, [string]$Manifest.WarningCount, [string]$Manifest.FailedCount, [string]$Manifest.SkippedCount))
    [void]$lines.Add('')
    [void]$lines.Add('## Where To Look')
    [void]$lines.Add('')
    [void]$lines.Add('- Raw diagnostic matrix: `share_permission_diagnostics.csv`')
    [void]$lines.Add('- Raw event log: `share_permission_diagnostics.jsonl`')
    [void]$lines.Add('- Full capability evidence: `fileshare_connectivity_checks.csv`')
    [void]$lines.Add('- Support-safe copy: `redacted\\share_permission_diagnostics.csv` and `redacted\\share_permission_diagnostics.md`')
    [void]$lines.Add('')
    [void]$lines.Add('## First Things To Review')
    $problemRows = @($failed + $warnings | Select-Object -First 25)
    if ($problemRows.Count -eq 0) {
        [void]$lines.Add('- No failed or warning share-permission diagnostics were exported. Review skipped rows before treating the run as complete.')
    }
    foreach ($row in $problemRows) {
        [void]$lines.Add(('- `{0}` `{1}` on `{2}` with `{3}`: {4} Action: {5}' -f [string]$row.Status, [string]$row.EvidenceType, [string]$row.TargetId, [string]$row.Provider, [string]$row.WhyItMatters, [string]$row.RecommendedAction))
    }
    if ($skipped.Count -gt 0) {
        [void]$lines.Add(('- Skipped diagnostics: `{0}`. Skipped checks are not proof; rerun without skip switches when you need live evidence.' -f $skipped.Count))
    }
    [void]$lines.Add('')
    [void]$lines.Add('## Capability Counts')
    foreach ($group in @($diagnostics | Group-Object Provider | Sort-Object Name)) {
        [void]$lines.Add(('- `{0}`: pass `{1}`, warning `{2}`, fail `{3}`, skipped `{4}`' -f $group.Name, @($group.Group | Where-Object { $_.Status -eq 'Pass' }).Count, @($group.Group | Where-Object { $_.Status -eq 'Warning' }).Count, @($group.Group | Where-Object { $_.Status -eq 'Fail' }).Count, @($group.Group | Where-Object { $_.Status -eq 'Skipped' }).Count))
    }
    [void]$lines.Add('')
    [void]$lines.Add('## Reminder')
    [void]$lines.Add('')
    [void]$lines.Add('A reachable SMB/RPC route can still fail to return or parse share security descriptors. A working CIM session can still fail on `Get-SmbShareAccess`. Review the diagnostic rows before accepting share-level permission evidence as complete.')
    @($lines) -join [Environment]::NewLine
}

function Export-ShareSurferSharePermissionDiagnosticPackage {
    param(
        [Parameter(Mandatory = $true)]
        [string] $OutputPath,

        [Parameter(Mandatory = $true)]
        [string] $RedactedPath,

        [Parameter(Mandatory = $true)]
        [string] $AssessmentId,

        [Parameter(Mandatory = $true)]
        [string] $GeneratedAt,

        $Targets,
        $Checks,
        [string] $RedactionSalt
    )

    $diagnosticRows = @(New-ShareSurferSharePermissionDiagnosticRows -AssessmentId $AssessmentId -Checks $Checks)
    $passedCount = @($diagnosticRows | Where-Object { $_.Status -eq 'Pass' }).Count
    $warningCount = @($diagnosticRows | Where-Object { $_.Status -eq 'Warning' }).Count
    $failedCount = @($diagnosticRows | Where-Object { $_.Status -eq 'Fail' }).Count
    $skippedCount = @($diagnosticRows | Where-Object { $_.Status -eq 'Skipped' }).Count
    $schema = Get-ShareSurferSharePermissionDiagnosticExportSchema

    $manifestRows = @([pscustomobject]@{
        AssessmentId = $AssessmentId
        GeneratedAt = $GeneratedAt
        ExportVersion = '1'
        PackageKind = 'SharePermissionDiagnostic'
        TargetCount = [string]@($Targets).Count
        DiagnosticCount = [string]$diagnosticRows.Count
        PassedCount = [string]$passedCount
        WarningCount = [string]$warningCount
        FailedCount = [string]$failedCount
        SkippedCount = [string]$skippedCount
        RawDiagnosticsPath = 'share_permission_diagnostics.csv'
        RawEventsPath = 'share_permission_diagnostics.jsonl'
        HumanSummaryPath = 'share_permission_diagnostics.md'
        RedactedOutputPath = 'redacted'
        RedactedSummaryPath = 'redacted/share_permission_diagnostics.md'
    })

    Export-ShareSurferCsv -Path (Join-Path $OutputPath 'share_permission_diagnostic_manifest.csv') -Columns $schema['share_permission_diagnostic_manifest.csv'] -Rows $manifestRows
    Export-ShareSurferCsv -Path (Join-Path $OutputPath 'share_permission_diagnostics.csv') -Columns $schema['share_permission_diagnostics.csv'] -Rows $diagnosticRows
    Export-ShareSurferJsonLines -Path (Join-Path $OutputPath 'share_permission_diagnostics.jsonl') -Rows $diagnosticRows
    Set-Content -LiteralPath (Join-Path $OutputPath 'share_permission_diagnostics.md') -Value (New-ShareSurferSharePermissionDiagnosticMarkdown -Manifest $manifestRows[0] -Rows $diagnosticRows) -Encoding UTF8

    $targetRows = @($Targets)
    $eventRows = @()
    $salt = if ([string]::IsNullOrWhiteSpace($RedactionSalt)) { $AssessmentId } else { $RedactionSalt }
    $tokenMap = New-ShareSurferFileShareConnectivityTokenMap -ManifestRows @() -TargetRows $targetRows -CheckRows $diagnosticRows -EventRows $eventRows -Salt $salt
    $sensitiveColumns = @('Target', 'ComputerName', 'ShareName')
    $detailColumns = @('WhatSucceeded', 'WhatFailed', 'Detail', 'RecommendedAction')
    $redactedManifestRows = $manifestRows
    $redactedDiagnosticRows = Protect-ShareSurferFileShareConnectivityRows -Rows $diagnosticRows -TokenMap $tokenMap -SensitiveColumns $sensitiveColumns -DetailColumns $detailColumns

    Export-ShareSurferCsv -Path (Join-Path $RedactedPath 'share_permission_diagnostic_manifest.csv') -Columns $schema['share_permission_diagnostic_manifest.csv'] -Rows $redactedManifestRows
    Export-ShareSurferCsv -Path (Join-Path $RedactedPath 'share_permission_diagnostics.csv') -Columns $schema['share_permission_diagnostics.csv'] -Rows $redactedDiagnosticRows
    Export-ShareSurferJsonLines -Path (Join-Path $RedactedPath 'share_permission_diagnostics.jsonl') -Rows $redactedDiagnosticRows
    Set-Content -LiteralPath (Join-Path $RedactedPath 'share_permission_diagnostics.md') -Value (New-ShareSurferSharePermissionDiagnosticMarkdown -Manifest $redactedManifestRows[0] -Rows $redactedDiagnosticRows) -Encoding UTF8

    $manifest = @(
        [pscustomobject]@{ SourceFile = 'share_permission_diagnostics.csv/jsonl/md'; ColumnName = 'Target'; Strategy = 'StableToken'; RawValuesIncluded = 'False' },
        [pscustomobject]@{ SourceFile = 'share_permission_diagnostics.csv/jsonl/md'; ColumnName = 'ComputerName'; Strategy = 'StableToken'; RawValuesIncluded = 'False' },
        [pscustomobject]@{ SourceFile = 'share_permission_diagnostics.csv/jsonl/md'; ColumnName = 'ShareName'; Strategy = 'StableToken'; RawValuesIncluded = 'False' },
        [pscustomobject]@{ SourceFile = 'share_permission_diagnostics.csv/jsonl/md'; ColumnName = 'WhatSucceeded/WhatFailed/Detail/RecommendedAction'; Strategy = 'TokenizeKnownValuesOrReplaceProviderDetail'; RawValuesIncluded = 'False' }
    )
    Export-ShareSurferCsv -Path (Join-Path $RedactedPath 'share_permission_diagnostic_redaction_manifest.csv') -Columns @('SourceFile', 'ColumnName', 'Strategy', 'RawValuesIncluded') -Rows $manifest

    [pscustomobject]@{
        DiagnosticPath = (Join-Path $OutputPath 'share_permission_diagnostics.csv')
        DiagnosticEventPath = (Join-Path $OutputPath 'share_permission_diagnostics.jsonl')
        DiagnosticSummaryPath = (Join-Path $OutputPath 'share_permission_diagnostics.md')
        RedactedDiagnosticPath = (Join-Path $RedactedPath 'share_permission_diagnostics.csv')
        RedactedDiagnosticSummaryPath = (Join-Path $RedactedPath 'share_permission_diagnostics.md')
        DiagnosticCount = $diagnosticRows.Count
        FailedCount = $failedCount
        WarningCount = $warningCount
        SkippedCount = $skippedCount
    }
}

function Invoke-ShareSurferFileShareConnectivityAssessment {
    [CmdletBinding()]
    param(
        [string[]] $TargetPath = @(),

        [string[]] $ComputerName = @(),

        [string[]] $ShareName = @(),

        [Parameter(Mandatory = $true)]
        [string] $OutputPath,

        [int] $TimeoutMilliseconds = 1500,

        [switch] $IncludeOpenFiles,

        [switch] $IncludeSessions,

        [switch] $SkipNetworkTests,

        [switch] $SkipCimChecks,

        [switch] $SkipNativeChecks,

        [ValidateSet('StableToken', 'Strict')]
        [string] $RedactionMode = 'StableToken',

        [string] $RedactionSalt = '',

        [switch] $Force,

        [switch] $NoCreateMissingFolders,

        [switch] $Quiet,

        [switch] $PassThru
    )

    if ((Test-Path -LiteralPath $OutputPath) -and -not $Force) {
        throw "Output path already exists: $OutputPath. Use -Force to overwrite assessment files."
    }

    Ensure-ShareSurferLocalDirectory -Path $OutputPath -Purpose 'file-share connectivity assessment output' -NoCreateMissingFolders:$NoCreateMissingFolders -Quiet:$Quiet | Out-Null
    $assessmentId = [guid]::NewGuid().ToString('N')
    $generatedAt = (Get-Date).ToUniversalTime().ToString('o')
    Write-ShareSurferStatus -Phase 'Assess' -Message ('Starting file-share connectivity assessment {0}.' -f $assessmentId) -Quiet:$Quiet

    $targets = @(Get-ShareSurferFileShareConnectivityTargets -TargetPath $TargetPath -ComputerName $ComputerName -ShareName $ShareName -AssessmentId $assessmentId)
    if ($targets.Count -eq 0) {
        throw 'At least one -TargetPath or -ComputerName value is required.'
    }

    $checks = New-Object System.Collections.ArrayList
    $checkIndex = 0

    foreach ($target in $targets) {
        Write-ShareSurferStatus -Phase 'Assess' -Message ('Assessing target {0} ({1}).' -f $target.TargetId, $target.InputType) -Quiet:$Quiet
        $checkIndex++
        [void]$checks.Add((New-ShareSurferFileShareConnectivityCheck -AssessmentId $assessmentId -Index $checkIndex -Target $target -Layer 'Target' -Capability 'TargetParse' -Provider 'ShareSurfer' -Status 'Pass' -Severity 'Info' -EvidenceType 'TargetParsed' -Message 'Target input was parsed into assessment fields.' -Detail ('Input type {0}; UNC path present: {1}.' -f $target.InputType, (-not [string]::IsNullOrWhiteSpace([string]$target.UNCPath))) -RecommendedAction 'Continue to transport and collection capability checks.'))

        $providerContext = [pscustomobject]@{ Target = $target; TimeoutMilliseconds = $TimeoutMilliseconds; SkipNetworkTests = [bool]$SkipNetworkTests }
        $providerCheck = ConvertTo-ShareSurferFileShareConnectivityProviderCheck -ProviderResult (Invoke-ShareSurferFileShareConnectivityProvider -Action 'NameResolution' -Context $providerContext) -AssessmentId $assessmentId -Index ($checkIndex + 1) -Target $target -Layer 'Resolve' -Capability 'NameResolution' -Provider 'Dns' -DefaultRecommendedAction 'Confirm DNS, NetBIOS, host file, or routing for the file server name.'
        if ($null -ne $providerCheck) {
            $checkIndex++
            [void]$checks.Add($providerCheck)
        }
        elseif ($SkipNetworkTests) {
            $checkIndex++
            [void]$checks.Add((New-ShareSurferFileShareConnectivityCheck -AssessmentId $assessmentId -Index $checkIndex -Target $target -Layer 'Resolve' -Capability 'NameResolution' -Provider 'Dns' -Attempted 'False' -Status 'Skipped' -Severity 'Review' -EvidenceType 'NetworkTestsSkipped' -Message 'Name resolution was skipped by request.' -Detail 'Rerun without -SkipNetworkTests to prove name resolution.' -RecommendedAction 'Rerun live network checks before treating this target as collection-ready.'))
        }
        else {
            try {
                $resolved = [System.Net.Dns]::GetHostEntry([string]$target.ComputerName)
                $checkIndex++
                [void]$checks.Add((New-ShareSurferFileShareConnectivityCheck -AssessmentId $assessmentId -Index $checkIndex -Target $target -Layer 'Resolve' -Capability 'NameResolution' -Provider 'Dns' -Status 'Pass' -Severity 'Info' -EvidenceType 'NameResolved' -Message 'Name resolution succeeded.' -Detail ('Resolved host name {0}; address count {1}.' -f $resolved.HostName, @($resolved.AddressList).Count) -RecommendedAction 'Continue to SMB, WinRM, and RPC checks.'))
            }
            catch {
                $checkIndex++
                [void]$checks.Add((New-ShareSurferFileShareConnectivityCheck -AssessmentId $assessmentId -Index $checkIndex -Target $target -Layer 'Resolve' -Capability 'NameResolution' -Provider 'Dns' -Status 'Fail' -Severity 'High' -EvidenceType 'NameResolutionFailed' -Message 'Name resolution failed.' -Detail ([string]$_.Exception.Message) -RecommendedAction 'Confirm DNS, NetBIOS, host file, or routing for the file server name.'))
            }
        }

        foreach ($portCheck in @(
            [pscustomobject]@{ Layer = 'Network'; Capability = 'SmbTcp445'; Provider = 'TcpClient'; Port = 445; EvidenceType = 'SmbTcpUnavailable'; Action = 'Confirm SMB TCP 445 reachability and host firewall policy.' },
            [pscustomobject]@{ Layer = 'Network'; Capability = 'WinRmHttp5985'; Provider = 'TcpClient'; Port = 5985; EvidenceType = 'WinRmTcpUnavailable'; Action = 'If using the default CIM collector, enable/allow WinRM HTTP or use a different provider.' },
            [pscustomobject]@{ Layer = 'Network'; Capability = 'WinRmHttps5986'; Provider = 'TcpClient'; Port = 5986; EvidenceType = 'WinRmTcpUnavailable'; Action = 'If using CIM over HTTPS, enable/allow WinRM HTTPS or use a different provider.' },
            [pscustomobject]@{ Layer = 'Network'; Capability = 'RpcEndpointMapper135'; Provider = 'TcpClient'; Port = 135; EvidenceType = 'RpcEndpointMapperUnavailable'; Action = 'RPC endpoint mapper reachability is useful for native and legacy administration paths, but does not prove descriptor reads.' }
        )) {
            $providerContext = [pscustomobject]@{ Target = $target; Port = $portCheck.Port; Capability = $portCheck.Capability; TimeoutMilliseconds = $TimeoutMilliseconds; SkipNetworkTests = [bool]$SkipNetworkTests }
            $providerRow = ConvertTo-ShareSurferFileShareConnectivityProviderCheck -ProviderResult (Invoke-ShareSurferFileShareConnectivityProvider -Action 'TcpPort' -Context $providerContext) -AssessmentId $assessmentId -Index ($checkIndex + 1) -Target $target -Layer $portCheck.Layer -Capability $portCheck.Capability -Provider $portCheck.Provider -DefaultRecommendedAction $portCheck.Action
            if ($null -ne $providerRow) {
                $checkIndex++
                [void]$checks.Add($providerRow)
                continue
            }

            $tcpResult = Test-ShareSurferTcpPort -ComputerName ([string]$target.ComputerName) -Port ([int]$portCheck.Port) -TimeoutMilliseconds $TimeoutMilliseconds -SkipNetworkTests:$SkipNetworkTests
            $status = $tcpResult.Status
            $severity = 'Info'
            $evidenceType = ('{0}Reachable' -f $portCheck.Capability)
            if ($status -eq 'Skipped') {
                $severity = 'Review'
                $evidenceType = 'NetworkTestsSkipped'
            }
            elseif ($status -ne 'Pass') {
                $severity = if ($portCheck.Port -eq 445) { 'High' } else { 'Warning' }
                $evidenceType = $portCheck.EvidenceType
            }
            $checkIndex++
            [void]$checks.Add((New-ShareSurferFileShareConnectivityCheck -AssessmentId $assessmentId -Index $checkIndex -Target $target -Layer $portCheck.Layer -Capability $portCheck.Capability -Provider $portCheck.Provider -Attempted $(if ($SkipNetworkTests) { 'False' } else { 'True' }) -Status $status -Severity $severity -EvidenceType $evidenceType -RawResultCode '' -Message ('TCP {0} check status: {1}.' -f $portCheck.Port, $status) -Detail ([string]$tcpResult.Detail) -RecommendedAction $(if ($status -eq 'Pass') { 'Remember that TCP reachability is not permission or descriptor proof.' } else { $portCheck.Action })))
        }

        if ($SkipCimChecks) {
            foreach ($capability in @('CimSession', 'CimShareMetadata', 'CimSharePermissions')) {
                $checkIndex++
                [void]$checks.Add((New-ShareSurferFileShareConnectivityCheck -AssessmentId $assessmentId -Index $checkIndex -Target $target -Layer 'CIM' -Capability $capability -Provider 'PowerShellCim' -Attempted 'False' -Status 'Skipped' -Severity 'Review' -EvidenceType 'CimChecksSkipped' -Message 'CIM collection proof was skipped by request.' -Detail 'Rerun without -SkipCimChecks to prove New-CimSession and SMB module commands.' -RecommendedAction 'Do not assume WinRM/CIM collection readiness until these checks pass.'))
            }
        }
        else {
            $cimSession = $null
            if ($null -eq (Get-Command -Name New-CimSession -ErrorAction SilentlyContinue)) {
                $checkIndex++
                [void]$checks.Add((New-ShareSurferFileShareConnectivityCheck -AssessmentId $assessmentId -Index $checkIndex -Target $target -Layer 'CIM' -Capability 'CimSession' -Provider 'PowerShellCim' -Attempted 'False' -Status 'Skipped' -Severity 'Review' -EvidenceType 'CimCommandUnavailable' -Message 'New-CimSession is not available in this PowerShell session.' -Detail 'Use Windows PowerShell 5.1 on a Windows collector host for first-class CIM checks.' -RecommendedAction 'Run from a supported Windows collector host or rely on native SMB/RPC checks if available.'))
            }
            else {
                try {
                    Write-ShareSurferStatus -Phase 'CIM' -Message ('Opening CIM session for {0}.' -f $target.TargetId) -Quiet:$Quiet
                    $cimSession = New-CimSession -ComputerName ([string]$target.ComputerName) -ErrorAction Stop
                    $checkIndex++
                    [void]$checks.Add((New-ShareSurferFileShareConnectivityCheck -AssessmentId $assessmentId -Index $checkIndex -Target $target -Layer 'CIM' -Capability 'CimSession' -Provider 'PowerShellCim' -Status 'Pass' -Severity 'Info' -EvidenceType 'CimSessionCreated' -Message 'New-CimSession succeeded.' -Detail 'CIM session was created. SMB cmdlets are still checked separately.' -RecommendedAction 'Continue to Get-SmbShare and Get-SmbShareAccess checks.'))
                }
                catch {
                    $checkIndex++
                    [void]$checks.Add((New-ShareSurferFileShareConnectivityCheck -AssessmentId $assessmentId -Index $checkIndex -Target $target -Layer 'CIM' -Capability 'CimSession' -Provider 'PowerShellCim' -Status 'Fail' -Severity 'Warning' -EvidenceType 'CimSessionError' -Message 'New-CimSession failed.' -Detail ([string]$_.Exception.Message) -RecommendedAction 'WinRM/CIM collection is not proven. Check WSMan service, firewall, authentication, and endpoint policy.'))
                }
            }

            try {
                if ($null -eq $cimSession) {
                    foreach ($capability in @('CimShareMetadata', 'CimSharePermissions')) {
                        $checkIndex++
                        [void]$checks.Add((New-ShareSurferFileShareConnectivityCheck -AssessmentId $assessmentId -Index $checkIndex -Target $target -Layer 'CIM' -Capability $capability -Provider 'PowerShellCim' -Attempted 'False' -Status 'Skipped' -Severity 'Review' -EvidenceType 'CimSessionRequired' -Message 'CIM command was skipped because no CIM session was available.' -Detail 'A reachable WinRM port is not enough; New-CimSession must succeed first.' -RecommendedAction 'Fix CIM session creation or use native SMB/RPC fallback evidence.'))
                    }
                }
                elseif ([string]::IsNullOrWhiteSpace([string]$target.ShareName)) {
                    foreach ($capability in @('CimShareMetadata', 'CimSharePermissions')) {
                        $checkIndex++
                        [void]$checks.Add((New-ShareSurferFileShareConnectivityCheck -AssessmentId $assessmentId -Index $checkIndex -Target $target -Layer 'CIM' -Capability $capability -Provider 'PowerShellCim' -Attempted 'False' -Status 'Skipped' -Severity 'Review' -EvidenceType 'ShareNameRequired' -Message 'Share-specific CIM command was skipped because the target did not include a share name.' -Detail 'Provide \\server\\share or -ComputerName plus -ShareName to prove share-level metadata and permissions.' -RecommendedAction 'Rerun with a share name for share-level proof.'))
                    }
                }
                else {
                    try {
                        if ($null -eq (Get-Command -Name Get-SmbShare -ErrorAction SilentlyContinue)) {
                            throw 'Get-SmbShare command is not available.'
                        }
                        $share = Get-SmbShare -CimSession $cimSession -Name ([string]$target.ShareName) -ErrorAction Stop
                        $checkIndex++
                        [void]$checks.Add((New-ShareSurferFileShareConnectivityCheck -AssessmentId $assessmentId -Index $checkIndex -Target $target -Layer 'CIM' -Capability 'CimShareMetadata' -Provider 'PowerShellCim' -Status 'Pass' -Severity 'Info' -EvidenceType 'CimShareMetadataRead' -Message 'Get-SmbShare succeeded through CIM.' -Detail ('Share metadata was returned with path {0}.' -f [string]$share.Path) -RecommendedAction 'Continue to share-permission proof.'))
                    }
                    catch {
                        $checkIndex++
                        [void]$checks.Add((New-ShareSurferFileShareConnectivityCheck -AssessmentId $assessmentId -Index $checkIndex -Target $target -Layer 'CIM' -Capability 'CimShareMetadata' -Provider 'PowerShellCim' -Status 'Fail' -Severity 'Warning' -EvidenceType 'CimShareLookupError' -Message 'Get-SmbShare failed through CIM.' -Detail ([string]$_.Exception.Message) -RecommendedAction 'Confirm SMBShare module availability, remote permissions, and share name accuracy.'))
                    }

                    try {
                        if ($null -eq (Get-Command -Name Get-SmbShareAccess -ErrorAction SilentlyContinue)) {
                            throw 'Get-SmbShareAccess command is not available.'
                        }
                        $accessRows = @(Get-SmbShareAccess -CimSession $cimSession -Name ([string]$target.ShareName) -ErrorAction Stop)
                        $checkIndex++
                        [void]$checks.Add((New-ShareSurferFileShareConnectivityCheck -AssessmentId $assessmentId -Index $checkIndex -Target $target -Layer 'CIM' -Capability 'CimSharePermissions' -Provider 'PowerShellCim' -Status 'Pass' -Severity 'Info' -EvidenceType 'CimSharePermissionsRead' -Message 'Get-SmbShareAccess succeeded through CIM.' -Detail ('Returned {0} share permission row(s).' -f $accessRows.Count) -RecommendedAction 'CIM share-level evidence is available for this target.'))
                    }
                    catch {
                        $checkIndex++
                        [void]$checks.Add((New-ShareSurferFileShareConnectivityCheck -AssessmentId $assessmentId -Index $checkIndex -Target $target -Layer 'CIM' -Capability 'CimSharePermissions' -Provider 'PowerShellCim' -Status 'Fail' -Severity 'Warning' -EvidenceType 'SharePermissionCollectionUnavailable' -Message 'Get-SmbShareAccess failed through CIM.' -Detail ([string]$_.Exception.Message) -RecommendedAction 'Share-level permissions cannot be proven through CIM. Review permissions, SMBShare module, or native SMB/RPC fallback.'))
                    }
                }
            }
            finally {
                if ($null -ne $cimSession) {
                    try { Remove-CimSession -CimSession $cimSession -ErrorAction SilentlyContinue } catch {}
                }
            }
        }

        if ($SkipNativeChecks) {
            foreach ($capability in @('NativeShareMetadata', 'NativeShareDescriptorReturned', 'NativeShareDescriptorParsed', 'FileSystemSecurityDescriptorRead')) {
                $checkIndex++
                [void]$checks.Add((New-ShareSurferFileShareConnectivityCheck -AssessmentId $assessmentId -Index $checkIndex -Target $target -Layer 'NativeRpc' -Capability $capability -Provider 'NativeSmbRpc' -Attempted 'False' -Status 'Skipped' -Severity 'Review' -EvidenceType 'NativeChecksSkipped' -Message 'Native SMB/RPC proof was skipped by request.' -Detail 'Rerun without -SkipNativeChecks on Windows to prove NetShareGetInfo and GetNamedSecurityInfoW behavior.' -RecommendedAction 'Do not assume native fallback readiness until these checks pass.'))
            }
        }
        elseif ((-not (Test-ShareSurferPortProtocolIsWindows)) -and $null -eq (Get-Variable -Name 'ShareSurferSmbRpcShareInfoProvider' -Scope Global -ErrorAction SilentlyContinue) -and $null -eq (Get-Variable -Name 'ShareSurferNativeSecurityInfoProvider' -Scope Global -ErrorAction SilentlyContinue)) {
            foreach ($capability in @('NativeShareMetadata', 'NativeShareDescriptorReturned', 'NativeShareDescriptorParsed', 'FileSystemSecurityDescriptorRead')) {
                $checkIndex++
                [void]$checks.Add((New-ShareSurferFileShareConnectivityCheck -AssessmentId $assessmentId -Index $checkIndex -Target $target -Layer 'NativeRpc' -Capability $capability -Provider 'NativeSmbRpc' -Attempted 'False' -Status 'Skipped' -Severity 'Review' -EvidenceType 'NativeProviderRequiresWindows' -Message 'Native SMB/RPC checks require a Windows collector host.' -Detail 'Run this assessment from Windows PowerShell 5.1 for native Win32 security descriptor proof.' -RecommendedAction 'Use a Windows collector host when validating NativeSmbRpc fallback behavior.'))
            }
        }
        elseif ([string]::IsNullOrWhiteSpace([string]$target.ShareName)) {
            foreach ($capability in @('NativeShareMetadata', 'NativeShareDescriptorReturned', 'NativeShareDescriptorParsed', 'FileSystemSecurityDescriptorRead')) {
                $checkIndex++
                [void]$checks.Add((New-ShareSurferFileShareConnectivityCheck -AssessmentId $assessmentId -Index $checkIndex -Target $target -Layer 'NativeRpc' -Capability $capability -Provider 'NativeSmbRpc' -Attempted 'False' -Status 'Skipped' -Severity 'Review' -EvidenceType 'ShareNameRequired' -Message 'Native share-specific command was skipped because the target did not include a share name.' -Detail 'Provide \\server\\share or -ComputerName plus -ShareName to prove native share metadata, share permissions, and owner/DACL reads.' -RecommendedAction 'Rerun with a share name for native SMB/RPC proof.'))
            }
        }
        else {
            $shareInfo = $null
            try {
                Write-ShareSurferStatus -Phase 'NativeRpc' -Message ('Calling NetShareGetInfo for {0}.' -f $target.TargetId) -Quiet:$Quiet
                $shareInfo = Get-ShareSurferSmbRpcShareInfo -ComputerName ([string]$target.ComputerName) -ShareName ([string]$target.ShareName) -PreferSecurityDescriptor
                if ($null -eq $shareInfo) {
                    throw 'NetShareGetInfo returned no share information.'
                }

                $checkIndex++
                [void]$checks.Add((New-ShareSurferFileShareConnectivityCheck -AssessmentId $assessmentId -Index $checkIndex -Target $target -Layer 'NativeRpc' -Capability 'NativeShareMetadata' -Provider 'NativeSmbRpc' -Status 'Pass' -Severity 'Info' -EvidenceType 'SmbRpcShareMetadataRead' -RawResultCode ([string]$shareInfo.ResultCode) -Message 'NetShareGetInfo returned share metadata.' -Detail ('Returned level {0}; local path {1}.' -f $shareInfo.Level, [string]$shareInfo.Path) -RecommendedAction 'Continue to share security descriptor parsing and filesystem descriptor reads.'))
            }
            catch {
                $checkIndex++
                [void]$checks.Add((New-ShareSurferFileShareConnectivityCheck -AssessmentId $assessmentId -Index $checkIndex -Target $target -Layer 'NativeRpc' -Capability 'NativeShareMetadata' -Provider 'NativeSmbRpc' -Status 'Fail' -Severity 'High' -EvidenceType 'SmbRpcShareLookupError' -Message 'NetShareGetInfo failed or returned no share metadata.' -Detail ([string]$_.Exception.Message) -RecommendedAction 'Confirm SMB/RPC administrative access, remote registry/server service behavior, and share name accuracy.'))
            }

            if ($null -eq $shareInfo) {
                foreach ($capability in @('NativeShareDescriptorReturned', 'NativeShareDescriptorParsed', 'FileSystemSecurityDescriptorRead')) {
                    $checkIndex++
                    [void]$checks.Add((New-ShareSurferFileShareConnectivityCheck -AssessmentId $assessmentId -Index $checkIndex -Target $target -Layer 'NativeRpc' -Capability $capability -Provider 'NativeSmbRpc' -Attempted 'False' -Status 'Skipped' -Severity 'Review' -EvidenceType 'NativeShareMetadataRequired' -Message 'Native descriptor check was skipped because share metadata was unavailable.' -Detail 'NetShareGetInfo must return share metadata before descriptor parsing or filesystem owner/DACL proof can continue.' -RecommendedAction 'Fix native share lookup first.'))
                }
            }
            else {
                $descriptorBytes = @($shareInfo.SecurityDescriptorBytes)
                if ($descriptorBytes.Count -eq 0) {
                    $checkIndex++
                    [void]$checks.Add((New-ShareSurferFileShareConnectivityCheck -AssessmentId $assessmentId -Index $checkIndex -Target $target -Layer 'NativeRpc' -Capability 'NativeShareDescriptorReturned' -Provider 'NativeSmbRpc' -Status 'Fail' -Severity 'Warning' -EvidenceType 'NativeShareSecurityDescriptorUnavailable' -RawResultCode ([string]$shareInfo.ResultCode) -Message 'NetShareGetInfo returned share metadata without a share security descriptor.' -Detail ('Returned level {0}; descriptor byte count 0.' -f $shareInfo.Level) -RecommendedAction 'Share metadata is available but share-level permissions are not proven through NativeSmbRpc.'))
                    $checkIndex++
                    [void]$checks.Add((New-ShareSurferFileShareConnectivityCheck -AssessmentId $assessmentId -Index $checkIndex -Target $target -Layer 'NativeRpc' -Capability 'NativeShareDescriptorParsed' -Provider 'NativeSmbRpc' -Attempted 'False' -Status 'Skipped' -Severity 'Review' -EvidenceType 'NativeShareSecurityDescriptorRequired' -Message 'Share descriptor parsing was skipped because no descriptor bytes were returned.' -Detail 'SMB/RPC reachability does not guarantee share security descriptor evidence.' -RecommendedAction 'Use CIM share-permission evidence or troubleshoot NativeSmbRpc descriptor access.'))
                }
                else {
                    $checkIndex++
                    [void]$checks.Add((New-ShareSurferFileShareConnectivityCheck -AssessmentId $assessmentId -Index $checkIndex -Target $target -Layer 'NativeRpc' -Capability 'NativeShareDescriptorReturned' -Provider 'NativeSmbRpc' -Status 'Pass' -Severity 'Info' -EvidenceType 'NativeShareSecurityDescriptorReturned' -RawResultCode ([string]$shareInfo.ResultCode) -Message 'NetShareGetInfo returned share security descriptor bytes.' -Detail ('Descriptor byte count {0}.' -f $descriptorBytes.Count) -RecommendedAction 'Continue to descriptor parse proof.'))
                    try {
                        $permissionRows = @(ConvertTo-ShareSurferSharePermissionRowsFromSecurityDescriptor -ShareId ([string]$target.TargetId) -SecurityDescriptorBytes ([byte[]]$descriptorBytes))
                        $checkIndex++
                        [void]$checks.Add((New-ShareSurferFileShareConnectivityCheck -AssessmentId $assessmentId -Index $checkIndex -Target $target -Layer 'NativeRpc' -Capability 'NativeShareDescriptorParsed' -Provider 'NativeSmbRpc' -Status 'Pass' -Severity 'Info' -EvidenceType 'NativeShareSecurityDescriptorParsed' -RawResultCode ([string]$shareInfo.ResultCode) -Message 'Share security descriptor parsed successfully.' -Detail ('Parsed {0} share permission ACE row(s).' -f $permissionRows.Count) -RecommendedAction 'Native share-level permission evidence is usable.'))
                    }
                    catch {
                        $checkIndex++
                        [void]$checks.Add((New-ShareSurferFileShareConnectivityCheck -AssessmentId $assessmentId -Index $checkIndex -Target $target -Layer 'NativeRpc' -Capability 'NativeShareDescriptorParsed' -Provider 'NativeSmbRpc' -Status 'Fail' -Severity 'High' -EvidenceType 'NativeShareSecurityDescriptorParseFailed' -RawResultCode ([string]$shareInfo.ResultCode) -Message 'Share security descriptor bytes could not be parsed.' -Detail ([string]$_.Exception.Message) -RecommendedAction 'Capture raw diagnostics and review descriptor parsing failure before trusting native share permission evidence.'))
                    }
                }

                if ([string]::IsNullOrWhiteSpace([string]$shareInfo.Path)) {
                    $checkIndex++
                    [void]$checks.Add((New-ShareSurferFileShareConnectivityCheck -AssessmentId $assessmentId -Index $checkIndex -Target $target -Layer 'Descriptor' -Capability 'FileSystemSecurityDescriptorRead' -Provider 'NativeWin32Security' -Attempted 'False' -Status 'Skipped' -Severity 'Review' -EvidenceType 'SharePathUnavailable' -Message 'Filesystem owner/DACL proof was skipped because the share local path was not returned.' -Detail 'A share path is required for GetNamedSecurityInfoW owner/DACL proof.' -RecommendedAction 'Use a target path scan or troubleshoot native share path metadata.'))
                }
                else {
                    try {
                        Write-ShareSurferStatus -Phase 'Descriptor' -Message ('Reading owner/DACL descriptor for {0}.' -f $target.TargetId) -Quiet:$Quiet
                        $securityInfo = Get-ShareSurferNativeSecurityInfo -Path ([string]$shareInfo.Path) -ShareId ([string]$target.TargetId) -ItemId ([string]$target.TargetId) -FullPath ([string]$target.UNCPath) -Depth 0
                        $aclCount = @($securityInfo.AclEntries).Count
                        $checkIndex++
                        [void]$checks.Add((New-ShareSurferFileShareConnectivityCheck -AssessmentId $assessmentId -Index $checkIndex -Target $target -Layer 'Descriptor' -Capability 'FileSystemSecurityDescriptorRead' -Provider 'NativeWin32Security' -Status 'Pass' -Severity 'Info' -EvidenceType 'NativeSecurityDescriptorRead' -Message 'GetNamedSecurityInfoW returned readable owner/DACL evidence.' -Detail ('Owner {0}; ACL row count {1}; inheritance enabled {2}.' -f [string]$securityInfo.Owner, $aclCount, [string]$securityInfo.InheritanceEnabled) -RecommendedAction 'Native filesystem owner/DACL evidence is usable for this share root.'))
                    }
                    catch {
                        $evidenceType = 'NativeSecurityDescriptorReadFailed'
                        $message = [string]$_.Exception.Message
                        if ($message -like 'NativeSecurityDescriptorUnavailable:*') {
                            $evidenceType = 'NativeSecurityDescriptorUnavailable'
                        }
                        elseif ($message -like 'NativeSecurityDescriptorParseFailed:*') {
                            $evidenceType = 'NativeSecurityDescriptorParseFailed'
                        }
                        $checkIndex++
                        [void]$checks.Add((New-ShareSurferFileShareConnectivityCheck -AssessmentId $assessmentId -Index $checkIndex -Target $target -Layer 'Descriptor' -Capability 'FileSystemSecurityDescriptorRead' -Provider 'NativeWin32Security' -Status 'Fail' -Severity 'High' -EvidenceType $evidenceType -Message 'GetNamedSecurityInfoW could not return usable owner/DACL evidence.' -Detail $message -RecommendedAction 'SMB/RPC metadata may work while filesystem owner/DACL reads fail. Review path access, privileges, long-path behavior, and native descriptor parsing details.'))
                    }
                }
            }
        }

        if ($IncludeOpenFiles) {
            if ((-not (Test-ShareSurferPortProtocolIsWindows)) -and $null -eq (Get-Variable -Name 'ShareSurferOpenFileProvider' -Scope Global -ErrorAction SilentlyContinue)) {
                $checkIndex++
                [void]$checks.Add((New-ShareSurferFileShareConnectivityCheck -AssessmentId $assessmentId -Index $checkIndex -Target $target -Layer 'OpenFiles' -Capability 'OpenFileEnumeration' -Provider 'NativeRpc' -Attempted 'False' -Status 'Skipped' -Severity 'Review' -EvidenceType 'NativeProviderRequiresWindows' -Message 'Open-file enumeration requires a Windows collector host for NativeRpc proof.' -Detail 'Run from Windows PowerShell 5.1 to prove NetFileEnum behavior.' -RecommendedAction 'Use a Windows collector host for open-file proof.'))
            }
            else {
                try {
                    Write-ShareSurferStatus -Phase 'OpenFiles' -Message ('Checking NetFileEnum open-file capability for {0}.' -f $target.TargetId) -Quiet:$Quiet
                    $openRows = @(Get-ShareSurferNativeOpenFileRows -ComputerName ([string]$target.ComputerName) -ShareName @([string]$target.ShareName) -AssessmentId $assessmentId -SampleId 'capability' -SampleTimestamp $generatedAt -Provider 'NativeRpc')
                    $status = if ($openRows.Count -gt 0) { 'Pass' } else { 'Warning' }
                    $evidenceType = if ($openRows.Count -gt 0) { 'OpenFileRowsObserved' } else { 'OpenFileNoRowsObserved' }
                    $severity = if ($openRows.Count -gt 0) { 'Info' } else { 'Review' }
                    $checkIndex++
                    [void]$checks.Add((New-ShareSurferFileShareConnectivityCheck -AssessmentId $assessmentId -Index $checkIndex -Target $target -Layer 'OpenFiles' -Capability 'OpenFileEnumeration' -Provider 'NativeRpc' -Status $status -Severity $severity -EvidenceType $evidenceType -Message 'NetFileEnum open-file capability check completed.' -Detail ('Observed {0} open-file row(s). Zero rows can mean no files were open at sample time.' -f $openRows.Count) -RecommendedAction 'If zero rows were observed, rerun during known user activity before concluding open-file collection is broken.'))
                }
                catch {
                    $checkIndex++
                    [void]$checks.Add((New-ShareSurferFileShareConnectivityCheck -AssessmentId $assessmentId -Index $checkIndex -Target $target -Layer 'OpenFiles' -Capability 'OpenFileEnumeration' -Provider 'NativeRpc' -Status 'Fail' -Severity 'Warning' -EvidenceType 'OpenFileCollectionError' -Message 'NetFileEnum open-file enumeration failed.' -Detail ([string]$_.Exception.Message) -RecommendedAction 'Open-file visibility is not proven. Confirm Server service, privileges, firewall, and native RPC behavior.'))
                }
            }
        }
        else {
            $checkIndex++
            [void]$checks.Add((New-ShareSurferFileShareConnectivityCheck -AssessmentId $assessmentId -Index $checkIndex -Target $target -Layer 'OpenFiles' -Capability 'OpenFileEnumeration' -Provider 'NativeRpc' -Attempted 'False' -Status 'Skipped' -Severity 'Review' -EvidenceType 'OpenFileCollectionSkipped' -Message 'Open-file enumeration was skipped.' -Detail 'Use -IncludeOpenFiles to prove NetFileEnum open-file visibility.' -RecommendedAction 'Run with -IncludeOpenFiles when open-file/hot-folder evidence matters.'))
        }

        if ($IncludeSessions) {
            if ((-not (Test-ShareSurferPortProtocolIsWindows)) -and $null -eq (Get-Variable -Name 'ShareSurferNativeSessionProvider' -Scope Global -ErrorAction SilentlyContinue)) {
                $checkIndex++
                [void]$checks.Add((New-ShareSurferFileShareConnectivityCheck -AssessmentId $assessmentId -Index $checkIndex -Target $target -Layer 'Sessions' -Capability 'SessionEnumeration' -Provider 'NativeRpc' -Attempted 'False' -Status 'Skipped' -Severity 'Review' -EvidenceType 'NativeProviderRequiresWindows' -Message 'Session enumeration requires a Windows collector host for NativeRpc proof.' -Detail 'Run from Windows PowerShell 5.1 to prove NetSessionEnum behavior.' -RecommendedAction 'Use a Windows collector host for session proof.'))
            }
            else {
                try {
                    Write-ShareSurferStatus -Phase 'Sessions' -Message ('Checking NetSessionEnum connection visibility for {0}.' -f $target.TargetId) -Quiet:$Quiet
                    $sessionRows = @(Get-ShareSurferNativeSessionRows -ComputerName ([string]$target.ComputerName) -MaxRows 25)
                    $status = if ($sessionRows.Count -gt 0) { 'Pass' } else { 'Warning' }
                    $evidenceType = if ($sessionRows.Count -gt 0) { 'SessionRowsObserved' } else { 'SessionNoRowsObserved' }
                    $severity = if ($sessionRows.Count -gt 0) { 'Info' } else { 'Review' }
                    $checkIndex++
                    [void]$checks.Add((New-ShareSurferFileShareConnectivityCheck -AssessmentId $assessmentId -Index $checkIndex -Target $target -Layer 'Sessions' -Capability 'SessionEnumeration' -Provider 'NativeRpc' -Status $status -Severity $severity -EvidenceType $evidenceType -Message 'NetSessionEnum connection capability check completed.' -Detail ('Observed {0} session row(s). Zero rows can mean no active connections at sample time.' -f $sessionRows.Count) -RecommendedAction 'If zero rows were observed, rerun during known user activity before concluding session collection is broken.'))
                }
                catch {
                    $checkIndex++
                    [void]$checks.Add((New-ShareSurferFileShareConnectivityCheck -AssessmentId $assessmentId -Index $checkIndex -Target $target -Layer 'Sessions' -Capability 'SessionEnumeration' -Provider 'NativeRpc' -Status 'Fail' -Severity 'Warning' -EvidenceType 'SessionEnumerationError' -Message 'NetSessionEnum connection enumeration failed.' -Detail ([string]$_.Exception.Message) -RecommendedAction 'Session visibility is not proven. Confirm Server service, privileges, firewall, and native RPC behavior.'))
                }
            }
        }
    }

    $targetRows = New-Object System.Collections.ArrayList
    foreach ($target in $targets) {
        $targetChecks = @($checks | Where-Object { $_.TargetId -eq $target.TargetId })
        $targetStatus = Get-ShareSurferFileShareConnectivityTargetStatus -Checks $targetChecks
        $provider = Get-ShareSurferFileShareConnectivityRecommendedProvider -Checks $targetChecks
        $summary = ('{0} passed, {1} warning, {2} failed, {3} skipped.' -f @($targetChecks | Where-Object { $_.Status -eq 'Pass' }).Count, @($targetChecks | Where-Object { $_.Status -eq 'Warning' }).Count, @($targetChecks | Where-Object { $_.Status -eq 'Fail' }).Count, @($targetChecks | Where-Object { $_.Status -eq 'Skipped' }).Count)
        [void]$targetRows.Add([pscustomobject]@{
            AssessmentId = $assessmentId
            TargetId = [string]$target.TargetId
            Target = [string]$target.Target
            InputType = [string]$target.InputType
            ComputerName = [string]$target.ComputerName
            ShareName = [string]$target.ShareName
            UNCPath = [string]$target.UNCPath
            TargetStatus = $targetStatus
            CapabilitySummary = $summary
            RecommendedScanProvider = $provider
            SuggestedNextAction = Get-ShareSurferFileShareConnectivitySuggestedAction -TargetStatus $targetStatus -RecommendedProvider $provider
        })
    }

    $passedCount = @($checks | Where-Object { $_.Status -eq 'Pass' }).Count
    $warningCount = @($checks | Where-Object { $_.Status -eq 'Warning' }).Count
    $failedCount = @($checks | Where-Object { $_.Status -eq 'Fail' }).Count
    $skippedCount = @($checks | Where-Object { $_.Status -eq 'Skipped' }).Count
    $redactedPath = Join-Path $OutputPath 'redacted'
    $collectorIdentity = ''
    try { $collectorIdentity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name } catch { $collectorIdentity = [string]$env:USERNAME }
    $collectorParts = @($collectorIdentity -split '\\', 2)
    $userDomain = if ($collectorParts.Count -eq 2) { $collectorParts[0] } else { [string]$env:USERDOMAIN }
    $collectorUser = if ($collectorParts.Count -eq 2) { $collectorParts[1] } else { $collectorIdentity }
    $collectorFqdn = ''
    try { $collectorFqdn = [System.Net.Dns]::GetHostEntry([System.Net.Dns]::GetHostName()).HostName } catch { $collectorFqdn = '' }

    $manifestRows = @([pscustomobject]@{
        AssessmentId = $assessmentId
        GeneratedAt = $generatedAt
        ExportVersion = '1'
        PackageKind = 'FileShareConnectivityAssessment'
        CollectorComputerName = [string]$env:COMPUTERNAME
        CollectorFqdn = $collectorFqdn
        CollectorUser = $collectorUser
        UserDomain = $userDomain
        IsWindows = [string](Test-ShareSurferPortProtocolIsWindows)
        IsElevated = [string](Test-ShareSurferPortProtocolIsElevated)
        PowerShellVersion = [string]$PSVersionTable.PSVersion
        PSEdition = [string]$PSVersionTable.PSEdition
        TargetCount = [string]$targets.Count
        CheckCount = [string]$checks.Count
        PassedCount = [string]$passedCount
        WarningCount = [string]$warningCount
        FailedCount = [string]$failedCount
        SkippedCount = [string]$skippedCount
        RedactedOutputPath = $redactedPath
    })

    $overallRecommendation = 'CollectionReady'
    if ($failedCount -gt 0) {
        $overallRecommendation = 'NeedsReview'
    }
    if (@($targetRows | Where-Object { $_.RecommendedScanProvider -eq 'Blocked' }).Count -gt 0) {
        $overallRecommendation = 'Blocked'
    }

    $summary = [pscustomobject]@{
        AssessmentId = $assessmentId
        GeneratedAt = $generatedAt
        PackageKind = 'FileShareConnectivityAssessment'
        TargetCount = $targets.Count
        CheckCount = $checks.Count
        PassedCount = $passedCount
        WarningCount = $warningCount
        FailedCount = $failedCount
        SkippedCount = $skippedCount
        OverallRecommendation = $overallRecommendation
        Note = 'TCP reachability does not prove CIM, SMB/RPC, share permission, filesystem security descriptor, open-file, or session collection capability.'
    }

    $schema = Get-ShareSurferFileShareConnectivityExportSchema
    Export-ShareSurferCsv -Path (Join-Path $OutputPath 'fileshare_connectivity_manifest.csv') -Columns $schema['fileshare_connectivity_manifest.csv'] -Rows $manifestRows
    Export-ShareSurferCsv -Path (Join-Path $OutputPath 'fileshare_connectivity_targets.csv') -Columns $schema['fileshare_connectivity_targets.csv'] -Rows $targetRows
    Export-ShareSurferCsv -Path (Join-Path $OutputPath 'fileshare_connectivity_checks.csv') -Columns $schema['fileshare_connectivity_checks.csv'] -Rows $checks
    $summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $OutputPath 'fileshare_connectivity_summary.json') -Encoding UTF8

    $eventRows = @(New-ShareSurferFileShareConnectivityEventRows -AssessmentId $assessmentId -Checks $checks)
    Write-ShareSurferFileShareConnectivityJsonLines -Path (Join-Path $OutputPath 'fileshare_connectivity_events.jsonl') -Rows $eventRows

    Write-ShareSurferStatus -Phase 'Redaction' -Message 'Writing redacted diagnostic package.' -Quiet:$Quiet
    Export-ShareSurferFileShareConnectivityRedactedPackage -OutputPath $OutputPath -RedactedPath $redactedPath -ManifestRows $manifestRows -TargetRows $targetRows -CheckRows $checks -EventRows $eventRows -Summary $summary -RedactionSalt $RedactionSalt

    $sharePermissionDiagnostic = Export-ShareSurferSharePermissionDiagnosticPackage -OutputPath $OutputPath -RedactedPath $redactedPath -AssessmentId $assessmentId -GeneratedAt $generatedAt -Targets $targets -Checks $checks -RedactionSalt $RedactionSalt
    Write-ShareSurferStatus -Phase 'Diagnostics' -Message ('Share permission diagnostic matrix: {0}' -f $sharePermissionDiagnostic.DiagnosticPath) -Quiet:$Quiet
    Write-ShareSurferStatus -Phase 'Diagnostics' -Message ('Share permission diagnostic event log: {0}' -f $sharePermissionDiagnostic.DiagnosticEventPath) -Quiet:$Quiet
    Write-ShareSurferStatus -Phase 'Diagnostics' -Message ('Share permission human summary: {0}' -f $sharePermissionDiagnostic.DiagnosticSummaryPath) -Quiet:$Quiet
    Write-ShareSurferStatus -Phase 'Diagnostics' -Message ('Redacted support-safe diagnostics: {0}' -f $sharePermissionDiagnostic.RedactedDiagnosticSummaryPath) -Quiet:$Quiet

    Write-ShareSurferStatus -Phase 'Summary' -Message ('Assessment complete: {0} pass, {1} warning, {2} fail, {3} skipped.' -f $passedCount, $warningCount, $failedCount, $skippedCount) -Quiet:$Quiet

    $result = [pscustomobject]@{
        AssessmentId = $assessmentId
        OutputPath = $OutputPath
        RedactedOutputPath = $redactedPath
        TargetCount = $targets.Count
        CheckCount = $checks.Count
        PassedCount = $passedCount
        WarningCount = $warningCount
        FailedCount = $failedCount
        SkippedCount = $skippedCount
        OverallRecommendation = $overallRecommendation
        SharePermissionDiagnosticPath = $sharePermissionDiagnostic.DiagnosticPath
        SharePermissionDiagnosticEventPath = $sharePermissionDiagnostic.DiagnosticEventPath
        SharePermissionDiagnosticSummaryPath = $sharePermissionDiagnostic.DiagnosticSummaryPath
        RedactedSharePermissionDiagnosticPath = $sharePermissionDiagnostic.RedactedDiagnosticPath
        RedactedSharePermissionDiagnosticSummaryPath = $sharePermissionDiagnostic.RedactedDiagnosticSummaryPath
        SharePermissionDiagnosticCount = $sharePermissionDiagnostic.DiagnosticCount
        SharePermissionDiagnosticFailedCount = $sharePermissionDiagnostic.FailedCount
        SharePermissionDiagnosticWarningCount = $sharePermissionDiagnostic.WarningCount
        SharePermissionDiagnosticSkippedCount = $sharePermissionDiagnostic.SkippedCount
        IsValid = (Test-ShareSurferFileShareConnectivityDiagnosticPackage -OutputPath $OutputPath)
    }

    if ($PassThru) {
        $result
    }
}
