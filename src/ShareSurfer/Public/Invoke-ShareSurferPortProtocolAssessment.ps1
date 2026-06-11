function Test-ShareSurferPortProtocolIsWindows {
    try {
        return [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Windows)
    }
    catch {
        return ($env:OS -eq 'Windows_NT')
    }
}

function Test-ShareSurferPortProtocolIsElevated {
    if (-not (Test-ShareSurferPortProtocolIsWindows)) {
        return $false
    }

    try {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($identity)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    catch {
        return $false
    }
}

function Test-ShareSurferPortProtocolModuleAvailable {
    param([string] $Name)

    $null -ne (Get-Module -ListAvailable -Name $Name | Select-Object -First 1)
}

function Get-ShareSurferPortProtocolOsDescription {
    try {
        return [string][System.Runtime.InteropServices.RuntimeInformation]::OSDescription
    }
    catch {
        return [string]$env:OS
    }
}

function Get-ShareSurferPortProtocolOsArchitecture {
    try {
        return [string][System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture
    }
    catch {
        return ''
    }
}

function New-ShareSurferPortProtocolTarget {
    param(
        [Parameter(Mandatory = $true)]
        [string] $AssessmentId,

        [Parameter(Mandatory = $true)]
        [int] $Index,

        [Parameter(Mandatory = $true)]
        [string] $TargetType,

        [Parameter(Mandatory = $true)]
        [string] $ComputerName,

        [string] $ShareName = '',

        [string] $Target = ''
    )

    $resolvedTarget = $Target
    if ([string]::IsNullOrWhiteSpace($resolvedTarget)) {
        if (-not [string]::IsNullOrWhiteSpace($ShareName)) {
            $resolvedTarget = '\\{0}\{1}' -f $ComputerName, $ShareName
        }
        else {
            $resolvedTarget = $ComputerName
        }
    }

    [pscustomobject]@{
        AssessmentId = $AssessmentId
        TargetId = 'target-{0:000}' -f $Index
        Target = $resolvedTarget
        TargetType = $TargetType
        ComputerName = $ComputerName
        ShareName = $ShareName
        UNCPath = if (-not [string]::IsNullOrWhiteSpace($ShareName)) { '\\{0}\{1}' -f $ComputerName, $ShareName } else { '' }
    }
}

function Get-ShareSurferPortProtocolTargets {
    param(
        [string[]] $ComputerName,
        [string[]] $ShareName,
        [string[]] $TargetPath,
        [string[]] $DirectoryServer,
        [string] $AssessmentId
    )

    $targets = New-Object System.Collections.ArrayList
    $index = 0
    foreach ($path in @($TargetPath)) {
        if ([string]::IsNullOrWhiteSpace($path)) {
            continue
        }

        if ($path -match '^\\\\([^\\]+)\\([^\\]+)') {
            $index++
            [void]$targets.Add((New-ShareSurferPortProtocolTarget -AssessmentId $AssessmentId -Index $index -TargetType 'SmbTarget' -ComputerName $matches[1] -ShareName $matches[2] -Target $path))
        }
        else {
            $index++
            [void]$targets.Add((New-ShareSurferPortProtocolTarget -AssessmentId $AssessmentId -Index $index -TargetType 'PathTarget' -ComputerName $path -Target $path))
        }
    }

    foreach ($computer in @($ComputerName)) {
        if ([string]::IsNullOrWhiteSpace($computer)) {
            continue
        }

        $shareNames = @($ShareName | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        if ($shareNames.Count -eq 0) {
            $index++
            [void]$targets.Add((New-ShareSurferPortProtocolTarget -AssessmentId $AssessmentId -Index $index -TargetType 'SmbTarget' -ComputerName $computer))
            continue
        }

        foreach ($share in $shareNames) {
            $index++
            [void]$targets.Add((New-ShareSurferPortProtocolTarget -AssessmentId $AssessmentId -Index $index -TargetType 'SmbTarget' -ComputerName $computer -ShareName $share))
        }
    }

    foreach ($server in @($DirectoryServer)) {
        if ([string]::IsNullOrWhiteSpace($server)) {
            continue
        }

        $index++
        [void]$targets.Add((New-ShareSurferPortProtocolTarget -AssessmentId $AssessmentId -Index $index -TargetType 'DirectoryTarget' -ComputerName $server -Target $server))
    }

    @($targets)
}

function Get-ShareSurferPortProtocolDefinitions {
    param([string] $TargetType)

    if ($TargetType -eq 'DirectoryTarget') {
        return @(
            [pscustomobject]@{ Protocol = 'LDAP'; Transport = 'TCP'; Port = 389; Requirement = 'Recommended'; Provider = 'Directory'; Purpose = 'Directory identity enrichment'; RequiredFor = 'LDAP fallback and directory lookups' },
            [pscustomobject]@{ Protocol = 'LDAPS'; Transport = 'TCP'; Port = 636; Requirement = 'Optional'; Provider = 'Directory'; Purpose = 'Encrypted directory identity enrichment'; RequiredFor = 'Secure LDAP directory lookups when configured' },
            [pscustomobject]@{ Protocol = 'Kerberos'; Transport = 'TCP'; Port = 88; Requirement = 'Recommended'; Provider = 'Directory'; Purpose = 'Domain authentication context'; RequiredFor = 'Kerberos-backed directory and file-server authentication' },
            [pscustomobject]@{ Protocol = 'Global Catalog'; Transport = 'TCP'; Port = 3268; Requirement = 'Optional'; Provider = 'Directory'; Purpose = 'Forest-wide identity lookups'; RequiredFor = 'Multi-domain identity correlation when used' },
            [pscustomobject]@{ Protocol = 'DNS'; Transport = 'TCP'; Port = 53; Requirement = 'Recommended'; Provider = 'Directory'; Purpose = 'Name resolution checks'; RequiredFor = 'Resolving file servers, domain controllers, and directory names' }
        )
    }

    @(
        [pscustomobject]@{ Protocol = 'SMB'; Transport = 'TCP'; Port = 445; Requirement = 'Required'; Provider = 'SMB'; Purpose = 'File share and ACL evidence'; RequiredFor = 'SMB enumeration, file/folder access, and native SMB/RPC metadata' },
        [pscustomobject]@{ Protocol = 'WinRM HTTP'; Transport = 'TCP'; Port = 5985; Requirement = 'Recommended'; Provider = 'CIM'; Purpose = 'Remote SMB metadata collection'; RequiredFor = 'Get-SmbShare and Get-SmbShareAccess through CIM when available' },
        [pscustomobject]@{ Protocol = 'WinRM HTTPS'; Transport = 'TCP'; Port = 5986; Requirement = 'Optional'; Provider = 'CIM'; Purpose = 'Encrypted remote SMB metadata collection'; RequiredFor = 'CIM over HTTPS in hardened environments' },
        [pscustomobject]@{ Protocol = 'RPC Endpoint Mapper'; Transport = 'TCP'; Port = 135; Requirement = 'Optional'; Provider = 'RPC'; Purpose = 'Classic RPC reachability signal'; RequiredFor = 'Legacy RPC-dependent file-server administration paths when present' }
    )
}

function Test-ShareSurferTcpPort {
    param(
        [Parameter(Mandatory = $true)]
        [string] $ComputerName,

        [Parameter(Mandatory = $true)]
        [int] $Port,

        [int] $TimeoutMilliseconds = 1500,

        [switch] $SkipNetworkTests
    )

    if ($SkipNetworkTests) {
        return [pscustomobject]@{
            Status = 'Skipped'
            LatencyMs = ''
            RemoteAddress = ''
            Detail = 'Network tests were skipped by request.'
        }
    }

    $client = New-Object System.Net.Sockets.TcpClient
    $asyncResult = $null
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $asyncResult = $client.BeginConnect($ComputerName, $Port, $null, $null)
        $connected = $asyncResult.AsyncWaitHandle.WaitOne($TimeoutMilliseconds, $false)
        if (-not $connected) {
            try { $client.Close() } catch {}
            return [pscustomobject]@{
                Status = 'Fail'
                LatencyMs = ''
                RemoteAddress = ''
                Detail = 'Connection timed out after {0} ms.' -f $TimeoutMilliseconds
            }
        }

        $client.EndConnect($asyncResult)
        $stopwatch.Stop()
        $remoteAddress = ''
        if ($null -ne $client.Client -and $null -ne $client.Client.RemoteEndPoint) {
            $remoteAddress = [string]$client.Client.RemoteEndPoint
        }

        [pscustomobject]@{
            Status = 'Pass'
            LatencyMs = [string][int]$stopwatch.ElapsedMilliseconds
            RemoteAddress = $remoteAddress
            Detail = 'TCP connection succeeded.'
        }
    }
    catch {
        [pscustomobject]@{
            Status = 'Fail'
            LatencyMs = ''
            RemoteAddress = ''
            Detail = [string]$_.Exception.Message
        }
    }
    finally {
        try { $client.Close() } catch {}
        if ($null -ne $asyncResult -and $null -ne $asyncResult.AsyncWaitHandle) {
            try { $asyncResult.AsyncWaitHandle.Close() } catch {}
        }
    }
}

function Get-ShareSurferPortProtocolSeverity {
    param(
        [string] $Status,
        [string] $Requirement
    )

    if ($Status -eq 'Pass') {
        return 'Info'
    }
    if ($Status -eq 'Skipped') {
        return 'Review'
    }
    if ($Requirement -eq 'Required') {
        return 'High'
    }
    if ($Requirement -eq 'Recommended') {
        return 'Warning'
    }
    'Info'
}

function Get-ShareSurferPortProtocolEnvironmentProfile {
    param(
        [string] $Protocol,
        [string] $TargetType
    )

    if ($TargetType -eq 'DirectoryTarget') {
        return 'Directory identity enrichment'
    }

    switch ($Protocol) {
        'SMB' { return 'Core SMB collection' }
        'WinRM HTTP' { return 'Default Windows CIM collection' }
        'WinRM HTTPS' { return 'Hardened Windows CIM collection' }
        'RPC Endpoint Mapper' { return 'Native SMB/RPC fallback signal' }
        default { return 'ShareSurfer collection support signal' }
    }
}

function Get-ShareSurferPortProtocolCollectionImpact {
    param(
        [string] $Status,
        [string] $Protocol,
        [string] $Requirement,
        [string] $RequiredFor
    )

    if ($Status -eq 'Skipped') {
        return 'Reachability was not tested, so this row is planning evidence rather than proof from the collector network.'
    }

    if ($Status -eq 'Pass') {
        if ($Protocol -eq 'SMB') {
            return 'Core SMB reachability is available from the collector; permissions and target security-descriptor behavior still determine how much share, folder, file, owner, and ACL evidence can be read and parsed.'
        }
        return ('The {0} route is reachable from the collector and can support {1}.' -f $Protocol, $RequiredFor)
    }

    switch ($Protocol) {
        'SMB' {
            return 'Required SMB reachability failed. ShareSurfer cannot reliably scan this SMB target from this collector until TCP 445 and share access work.'
        }
        'WinRM HTTP' {
            return 'Default PowerShell/CIM share metadata may be unavailable. ShareSurfer can often continue with NativeSmbRpc or partial share-level evidence when SMB itself is reachable.'
        }
        'WinRM HTTPS' {
            return 'The hardened CIM-over-HTTPS route is unavailable. This is usually acceptable unless your environment requires encrypted WinRM for remote SMB metadata.'
        }
        'RPC Endpoint Mapper' {
            return 'Classic RPC reachability is unavailable. Native SMB/RPC metadata fallback may be limited, but file/folder evidence can still work when SMB TCP 445 is reachable.'
        }
        'LDAP' {
            return 'Directory lookup fallback may be incomplete. Identity enrichment may depend on the ActiveDirectory module, cached evidence, or another reachable directory route.'
        }
        'LDAPS' {
            return 'Encrypted LDAP is unavailable. This is a hardening review item when policy requires encrypted directory lookup paths.'
        }
        'Kerberos' {
            return 'Kerberos reachability failed. Domain authentication and directory-backed identity context may be unreliable from this collector.'
        }
        'Global Catalog' {
            return 'Forest-wide identity lookups may be incomplete in multi-domain environments.'
        }
        'DNS' {
            return 'Name resolution checks failed. Target and directory names may need DNS, hosts-file, or explicit address review before relying on the scan.'
        }
        default {
            if ($Requirement -eq 'Required') {
                return ('Required reachability for {0} failed. Review before relying on {1}.' -f $Protocol, $RequiredFor)
            }
            return ('Optional or recommended reachability for {0} failed. ShareSurfer may continue, but {1} may be incomplete.' -f $Protocol, $RequiredFor)
        }
    }
}

function Get-ShareSurferPortProtocolOperatorGuidance {
    param(
        [string] $Status,
        [string] $Protocol,
        [string] $Requirement
    )

    if ($Status -eq 'Skipped') {
        return 'Run again without -SkipNetworkTests when you are allowed to test network reachability.'
    }
    if ($Status -eq 'Pass') {
        if ($Protocol -eq 'SMB') {
            return 'No network action is indicated for SMB. Still review scan diagnostics because reachable SMB/RPC does not prove readable or parseable share, owner, or DACL security descriptors.'
        }
        return 'No action is needed for this protocol before scanning, unless permissions or policy require separate review.'
    }

    switch ($Protocol) {
        'SMB' { return 'Resolve this before scanning the target; ShareSurfer needs SMB reachability for share and filesystem evidence.' }
        'WinRM HTTP' { return 'If WinRM is intentionally blocked, use -SmbCollectionProvider NativeSmbRpc for explicit Windows SMB shares and review partial evidence carefully.' }
        'WinRM HTTPS' { return 'If your environment requires encrypted WinRM, configure or allow TCP 5986; otherwise treat this as optional context.' }
        'RPC Endpoint Mapper' { return 'Review only when you expect classic RPC/native fallback routes to be available. SMB TCP 445 remains the core requirement.' }
        'LDAP' { return 'Confirm a supported directory lookup route before relying on full identity enrichment.' }
        'LDAPS' { return 'Review with directory administrators when policy requires encrypted LDAP.' }
        'Kerberos' { return 'Confirm domain authentication path, time sync, DNS, and firewall policy from the collector.' }
        'Global Catalog' { return 'Review if you need forest-wide identity correlation across multiple domains.' }
        'DNS' { return 'Fix name resolution or use explicit names/addresses that resolve consistently from the collector.' }
        default {
            if ($Requirement -eq 'Required') {
                return 'Resolve this required reachability failure before treating the target as scan-ready.'
            }
            return 'Review whether this route matters in your environment before owner approval.'
        }
    }
}

function Get-ShareSurferPortProtocolRemediationHint {
    param(
        [string] $Status,
        [string] $Protocol,
        [int] $Port
    )

    if ($Status -eq 'Pass') {
        return 'No remediation indicated by this reachability check.'
    }
    if ($Status -eq 'Skipped') {
        return 'No remediation was assessed because network testing was skipped.'
    }

    switch ($Protocol) {
        'SMB' { return ('Check firewall rules, network ACLs, DNS/name resolution, and share access for TCP {0} from the collector.' -f $Port) }
        'WinRM HTTP' { return ('If CIM collection is desired, enable/listen for WinRM on TCP {0}; otherwise plan to use NativeSmbRpc or accept partial share metadata.' -f $Port) }
        'WinRM HTTPS' { return ('If hardened CIM collection is desired, configure WinRM HTTPS listener/certificate/firewall for TCP {0}.' -f $Port) }
        'RPC Endpoint Mapper' { return ('If native RPC metadata paths are expected, review endpoint mapper/firewall policy for TCP {0} and related dynamic RPC rules.' -f $Port) }
        'LDAP' { return ('Review directory server firewall/listener policy for TCP {0} or use another supported identity lookup path.' -f $Port) }
        'LDAPS' { return ('Review LDAPS certificate, listener, and firewall policy for TCP {0}.' -f $Port) }
        'Kerberos' { return ('Review domain controller reachability, DNS, time sync, and firewall policy for TCP {0}.' -f $Port) }
        'Global Catalog' { return ('Review global catalog availability and firewall policy for TCP {0}.' -f $Port) }
        'DNS' { return ('Review DNS server reachability for TCP {0}; also confirm normal name resolution from the collector.' -f $Port) }
        default { return ('Review firewall, routing, name resolution, and listener state for TCP {0}.' -f $Port) }
    }
}

function Get-ShareSurferPortProtocolMessage {
    param(
        [string] $Status,
        [string] $Protocol,
        [string] $ComputerName,
        [int] $Port,
        [string] $Requirement,
        [string] $RequiredFor
    )

    if ($Status -eq 'Pass') {
        return ('{0} on {1}:{2} is reachable.' -f $Protocol, $ComputerName, $Port)
    }
    if ($Status -eq 'Skipped') {
        return ('{0} on {1}:{2} was not tested.' -f $Protocol, $ComputerName, $Port)
    }
    if ($Requirement -eq 'Required') {
        return ('{0} on {1}:{2} is not reachable. Review before relying on {3}.' -f $Protocol, $ComputerName, $Port, $RequiredFor)
    }
    return ('{0} on {1}:{2} is not reachable. ShareSurfer may continue, but this path can affect {3}.' -f $Protocol, $ComputerName, $Port, $RequiredFor)
}

function Get-ShareSurferPortProtocolTargetReadinessSummary {
    param(
        [string] $TargetStatus,
        [object[]] $Rows
    )

    if ($TargetStatus -eq 'Ready') {
        return 'No blocked or warning protocol checks were observed for this target.'
    }
    if ($TargetStatus -eq 'Not Tested') {
        return 'Reachability was not tested. Treat this as a runbook/planning package until a live check is allowed.'
    }

    $failedProtocols = @($Rows | Where-Object { $_.Status -eq 'Fail' } | Select-Object -ExpandProperty Protocol -Unique)
    if ($failedProtocols.Count -eq 0) {
        return 'Review this target before owner approval.'
    }

    if ($TargetStatus -eq 'Blocked') {
        return ('Required reachability failed: {0}.' -f ($failedProtocols -join ', '))
    }

    'Review non-required reachability gaps: {0}.' -f ($failedProtocols -join ', ')
}

function Get-ShareSurferPortProtocolTargetCollectionImpact {
    param(
        [string] $TargetStatus,
        [object[]] $Rows
    )

    if ($TargetStatus -eq 'Ready') {
        return 'The target looks reachable for the assessed ShareSurfer collection paths. Permissions can still limit evidence.'
    }
    if ($TargetStatus -eq 'Not Tested') {
        return 'The target readiness is unknown because the assessment was run without network tests.'
    }

    $requiredFailures = @($Rows | Where-Object { $_.Requirement -eq 'Required' -and $_.Status -eq 'Fail' })
    if ($requiredFailures.Count -gt 0) {
        return 'Core collection is likely blocked or severely incomplete until required reachability is restored.'
    }

    'Collection may still run, but ShareSurfer may need fallback providers or may mark some metadata partial.'
}

function Get-ShareSurferPortProtocolTargetStatus {
    param([object[]] $Rows)

    $requiredFailures = @($Rows | Where-Object { $_.Requirement -eq 'Required' -and $_.Status -eq 'Fail' })
    $failures = @($Rows | Where-Object { $_.Status -eq 'Fail' })
    $skipped = @($Rows | Where-Object { $_.Status -eq 'Skipped' })

    if ($requiredFailures.Count -gt 0) {
        return 'Blocked'
    }
    if ($failures.Count -gt 0) {
        return 'Review'
    }
    if ($skipped.Count -gt 0) {
        return 'Not Tested'
    }
    'Ready'
}

function Get-ShareSurferPortProtocolNextAction {
    param(
        [string] $TargetStatus,
        [object[]] $Rows
    )

    if ($TargetStatus -eq 'Ready') {
        return 'No port/protocol blockers were observed for this target.'
    }
    if ($TargetStatus -eq 'Not Tested') {
        return 'Run again without -SkipNetworkTests when network testing is allowed.'
    }

    $requiredFailures = @($Rows | Where-Object { $_.Requirement -eq 'Required' -and $_.Status -eq 'Fail' })
    if ($requiredFailures.Count -gt 0) {
        return 'Confirm SMB TCP 445 reachability and share access before scanning this target.'
    }

    'Review failed recommended or optional checks, especially WinRM/CIM, before assuming share-level metadata will be complete.'
}

function Invoke-ShareSurferPortProtocolAssessment {
    [CmdletBinding()]
    param(
        [string[]] $ComputerName = @(),

        [string[]] $ShareName = @(),

        [string[]] $TargetPath = @(),

        [string[]] $DirectoryServer = @(),

        [Parameter(Mandatory = $true)]
        [string] $OutputPath,

        [int] $TimeoutMilliseconds = 1500,

        [switch] $SkipNetworkTests,

        [switch] $Force,

        [switch] $PassThru
    )

    if ($TimeoutMilliseconds -lt 100) {
        throw 'TimeoutMilliseconds must be at least 100.'
    }

    if (Test-Path -LiteralPath $OutputPath) {
        $existingFiles = @(Get-ChildItem -LiteralPath $OutputPath -Filter 'port_protocol_*.csv' -File -ErrorAction SilentlyContinue)
        if ($existingFiles.Count -gt 0 -and -not $Force) {
            throw ('OutputPath already contains port/protocol assessment files. Pass -Force to replace them: {0}' -f $OutputPath)
        }
    }
    else {
        New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
    }

    $schema = Get-ShareSurferPortProtocolExportSchema
    $assessmentId = [guid]::NewGuid().ToString('N')
    $targets = @(Get-ShareSurferPortProtocolTargets -ComputerName $ComputerName -ShareName $ShareName -TargetPath $TargetPath -DirectoryServer $DirectoryServer -AssessmentId $assessmentId)
    if ($targets.Count -eq 0) {
        throw 'Supply at least one -ComputerName, -TargetPath, or -DirectoryServer value.'
    }

    $checks = New-Object System.Collections.ArrayList
    $checkIndex = 0
    foreach ($target in $targets) {
        foreach ($definition in @(Get-ShareSurferPortProtocolDefinitions -TargetType ([string]$target.TargetType))) {
            $checkIndex++
            $probe = Test-ShareSurferTcpPort -ComputerName ([string]$target.ComputerName) -Port ([int]$definition.Port) -TimeoutMilliseconds $TimeoutMilliseconds -SkipNetworkTests:$SkipNetworkTests
            $severity = Get-ShareSurferPortProtocolSeverity -Status ([string]$probe.Status) -Requirement ([string]$definition.Requirement)
            $message = Get-ShareSurferPortProtocolMessage -Status ([string]$probe.Status) -Protocol ([string]$definition.Protocol) -ComputerName ([string]$target.ComputerName) -Port ([int]$definition.Port) -Requirement ([string]$definition.Requirement) -RequiredFor ([string]$definition.RequiredFor)
            $environmentProfile = Get-ShareSurferPortProtocolEnvironmentProfile -Protocol ([string]$definition.Protocol) -TargetType ([string]$target.TargetType)
            $collectionImpact = Get-ShareSurferPortProtocolCollectionImpact -Status ([string]$probe.Status) -Protocol ([string]$definition.Protocol) -Requirement ([string]$definition.Requirement) -RequiredFor ([string]$definition.RequiredFor)
            $operatorGuidance = Get-ShareSurferPortProtocolOperatorGuidance -Status ([string]$probe.Status) -Protocol ([string]$definition.Protocol) -Requirement ([string]$definition.Requirement)
            $remediationHint = Get-ShareSurferPortProtocolRemediationHint -Status ([string]$probe.Status) -Protocol ([string]$definition.Protocol) -Port ([int]$definition.Port)
            [void]$checks.Add([pscustomobject]@{
                AssessmentId = $assessmentId
                CheckId = 'check-{0:0000}' -f $checkIndex
                TargetId = [string]$target.TargetId
                Target = [string]$target.Target
                TargetType = [string]$target.TargetType
                ComputerName = [string]$target.ComputerName
                ShareName = [string]$target.ShareName
                Protocol = [string]$definition.Protocol
                Transport = [string]$definition.Transport
                Port = [string]$definition.Port
                Requirement = [string]$definition.Requirement
                Provider = [string]$definition.Provider
                Purpose = [string]$definition.Purpose
                RequiredFor = [string]$definition.RequiredFor
                Status = [string]$probe.Status
                Severity = $severity
                EnvironmentProfile = $environmentProfile
                CollectionImpact = $collectionImpact
                OperatorGuidance = $operatorGuidance
                RemediationHint = $remediationHint
                LatencyMs = [string]$probe.LatencyMs
                RemoteAddress = [string]$probe.RemoteAddress
                Message = $message
                Detail = [string]$probe.Detail
            })
        }
    }

    $targetRows = foreach ($target in $targets) {
        $targetChecks = @($checks | Where-Object { [string]$_.TargetId -eq [string]$target.TargetId })
        $targetStatus = Get-ShareSurferPortProtocolTargetStatus -Rows $targetChecks
        [pscustomobject]@{
            AssessmentId = $assessmentId
            TargetId = [string]$target.TargetId
            Target = [string]$target.Target
            TargetType = [string]$target.TargetType
            ComputerName = [string]$target.ComputerName
            ShareName = [string]$target.ShareName
            UNCPath = [string]$target.UNCPath
            CheckCount = $targetChecks.Count
            PassedCount = @($targetChecks | Where-Object { $_.Status -eq 'Pass' }).Count
            WarningCount = @($targetChecks | Where-Object { $_.Status -eq 'Fail' -and $_.Requirement -ne 'Required' }).Count
            FailedCount = @($targetChecks | Where-Object { $_.Status -eq 'Fail' -and $_.Requirement -eq 'Required' }).Count
            SkippedCount = @($targetChecks | Where-Object { $_.Status -eq 'Skipped' }).Count
            TargetStatus = $targetStatus
            ReadinessSummary = Get-ShareSurferPortProtocolTargetReadinessSummary -TargetStatus $targetStatus -Rows $targetChecks
            CollectionImpact = Get-ShareSurferPortProtocolTargetCollectionImpact -TargetStatus $targetStatus -Rows $targetChecks
            SuggestedNextAction = Get-ShareSurferPortProtocolNextAction -TargetStatus $targetStatus -Rows $targetChecks
        }
    }

    $collectorComputerName = if (-not [string]::IsNullOrWhiteSpace([string]$env:COMPUTERNAME)) { [string]$env:COMPUTERNAME } else { [string][System.Net.Dns]::GetHostName() }
    $collectorFqdn = $collectorComputerName
    try {
        $hostEntry = [System.Net.Dns]::GetHostEntry([string]([System.Net.Dns]::GetHostName()))
        if ($null -ne $hostEntry -and -not [string]::IsNullOrWhiteSpace([string]$hostEntry.HostName)) {
            $collectorFqdn = [string]$hostEntry.HostName
        }
    }
    catch {
        $collectorFqdn = $collectorComputerName
    }
    $manifest = @(
        [pscustomobject]@{
            AssessmentId = $assessmentId
            GeneratedAt = (Get-Date).ToUniversalTime().ToString('o')
            ExportVersion = '1'
            CollectorComputerName = $collectorComputerName
            CollectorFqdn = $collectorFqdn
            CollectorUser = if (-not [string]::IsNullOrWhiteSpace([string]$env:USERNAME)) { [string]$env:USERNAME } else { [string]$env:USER }
            UserDomain = [string]$env:USERDOMAIN
            IsWindows = [bool](Test-ShareSurferPortProtocolIsWindows)
            IsElevated = [bool](Test-ShareSurferPortProtocolIsElevated)
            OSDescription = Get-ShareSurferPortProtocolOsDescription
            OSArchitecture = Get-ShareSurferPortProtocolOsArchitecture
            PowerShellVersion = [string]$PSVersionTable.PSVersion
            PSEdition = [string]$PSVersionTable.PSEdition
            ActiveDirectoryModuleAvailable = [bool](Test-ShareSurferPortProtocolModuleAvailable -Name 'ActiveDirectory')
            SmbShareModuleAvailable = [bool](Test-ShareSurferPortProtocolModuleAvailable -Name 'SmbShare')
            TargetCount = $targets.Count
            CheckCount = @($checks).Count
            PassedCount = @($checks | Where-Object { $_.Status -eq 'Pass' }).Count
            WarningCount = @($checks | Where-Object { $_.Status -eq 'Fail' -and $_.Requirement -ne 'Required' }).Count
            FailedCount = @($checks | Where-Object { $_.Status -eq 'Fail' -and $_.Requirement -eq 'Required' }).Count
            SkippedCount = @($checks | Where-Object { $_.Status -eq 'Skipped' }).Count
            PackageKind = 'PortProtocolAssessment'
        }
    )

    $data = @{
        'port_protocol_manifest.csv' = $manifest
        'port_protocol_targets.csv' = @($targetRows)
        'port_protocol_checks.csv' = @($checks)
    }

    foreach ($fileName in $schema.Keys) {
        Export-ShareSurferCsv -Path (Join-Path $OutputPath $fileName) -Columns $schema[$fileName] -Rows $data[$fileName]
    }

    $result = [pscustomobject]@{
        OutputPath = $OutputPath
        AssessmentId = $assessmentId
        TargetCount = $targets.Count
        CheckCount = @($checks).Count
        PassedCount = @($checks | Where-Object { $_.Status -eq 'Pass' }).Count
        WarningCount = @($checks | Where-Object { $_.Status -eq 'Fail' -and $_.Requirement -ne 'Required' }).Count
        FailedCount = @($checks | Where-Object { $_.Status -eq 'Fail' -and $_.Requirement -eq 'Required' }).Count
        SkippedCount = @($checks | Where-Object { $_.Status -eq 'Skipped' }).Count
        IsValid = (Test-Path -LiteralPath (Join-Path $OutputPath 'port_protocol_manifest.csv')) -and
            (Test-Path -LiteralPath (Join-Path $OutputPath 'port_protocol_targets.csv')) -and
            (Test-Path -LiteralPath (Join-Path $OutputPath 'port_protocol_checks.csv'))
    }

    if ($PassThru) {
        $result
    }
}
