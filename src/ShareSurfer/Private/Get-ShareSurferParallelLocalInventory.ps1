function Get-ShareSurferParallelLocalInventory {
    param(
        [Parameter(Mandatory = $true)]
        [string[]] $TargetPath,

        [switch] $IncludeFiles,

        [ValidateSet('PowerShellGetAcl', 'NativeWin32Security')]
        [string] $AclProvider = 'PowerShellGetAcl',

        [switch] $SkipSharePermissionCollection,

        [ValidateRange(1, 64)]
        [int] $ThrottleLimit = 4,

        [int] $StatusIntervalSeconds = 15,

        [switch] $Quiet
    )

    $targets = @($TargetPath | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | ForEach-Object { [string]$_ })
    if ($targets.Count -le 1 -or $ThrottleLimit -le 1) {
        return Get-ShareSurferLocalInventory -TargetPath $targets -IncludeFiles:$IncludeFiles -AclProvider $AclProvider -SkipSharePermissionCollection:$SkipSharePermissionCollection -Quiet:$Quiet
    }

    $modulePath = Join-Path (Split-Path -Parent $PSScriptRoot) 'ShareSurfer.psd1'
    if (-not (Test-Path -LiteralPath $modulePath -PathType Leaf)) {
        throw ('Unable to locate ShareSurfer module manifest for parallel target collection: {0}' -f $modulePath)
    }

    $effectiveThrottle = [Math]::Min($ThrottleLimit, $targets.Count)
    Write-ShareSurferStatus -Phase 'Collect' -Message ('Parallel target collection enabled for {0} target path(s) with throttle {1}.' -f $targets.Count, $effectiveThrottle) -Quiet:$Quiet

    $pool = [runspacefactory]::CreateRunspacePool(1, $effectiveThrottle)
    $pool.Open()
    $jobs = New-Object System.Collections.ArrayList
    $resultsByIndex = @{}
    $errorsByIndex = @{}
    $statusClock = [System.Diagnostics.Stopwatch]::StartNew()
    $lastStatusSeconds = -999.0

    $workerScript = {
        param(
            [string] $WorkerModulePath,
            [string] $WorkerTargetPath,
            [int] $WorkerTargetIndex,
            [int] $WorkerTargetTotal,
            [bool] $WorkerIncludeFiles,
            [string] $WorkerAclProvider,
            [bool] $WorkerSkipSharePermissionCollection
        )

        Import-Module $WorkerModulePath -Force -ErrorAction Stop
        $shareSurferModule = Get-Module ShareSurfer
        & $shareSurferModule {
            param($Parameters)
            Get-ShareSurferLocalInventory @Parameters
        } @{
            TargetPath = @($WorkerTargetPath)
            IncludeFiles = $WorkerIncludeFiles
            AclProvider = $WorkerAclProvider
            SkipSharePermissionCollection = $WorkerSkipSharePermissionCollection
            StartingTargetIndex = $WorkerTargetIndex
            TargetTotal = $WorkerTargetTotal
            Quiet = $true
        }
    }

    try {
        for ($i = 0; $i -lt $targets.Count; $i++) {
            $powershell = [powershell]::Create()
            $powershell.RunspacePool = $pool
            [void]$powershell.AddScript($workerScript)
            [void]$powershell.AddArgument($modulePath)
            [void]$powershell.AddArgument($targets[$i])
            [void]$powershell.AddArgument($i + 1)
            [void]$powershell.AddArgument($targets.Count)
            [void]$powershell.AddArgument([bool]$IncludeFiles)
            [void]$powershell.AddArgument($AclProvider)
            [void]$powershell.AddArgument([bool]$SkipSharePermissionCollection)
            [void]$jobs.Add([pscustomobject]@{
                Index = $i + 1
                TargetPath = $targets[$i]
                PowerShell = $powershell
                Handle = $powershell.BeginInvoke()
            })
        }

        while ($jobs.Count -gt 0) {
            $completedJobs = @($jobs | Where-Object { $_.Handle.IsCompleted })
            foreach ($job in $completedJobs) {
                try {
                    $result = $job.PowerShell.EndInvoke($job.Handle)
                    if ($job.PowerShell.Streams.Error.Count -gt 0) {
                        $errorsByIndex[[int]$job.Index] = ($job.PowerShell.Streams.Error | ForEach-Object { [string]$_.Exception.Message }) -join '; '
                    }
                    else {
                        $resultsByIndex[[int]$job.Index] = @($result)[0]
                    }
                }
                catch {
                    $errorsByIndex[[int]$job.Index] = [string]$_.Exception.Message
                }
                finally {
                    $job.PowerShell.Dispose()
                    [void]$jobs.Remove($job)
                }
            }

            $completedCount = $resultsByIndex.Count + $errorsByIndex.Count
            $elapsed = [double]$statusClock.Elapsed.TotalSeconds
            if (-not $Quiet -and ($StatusIntervalSeconds -le 0 -or ($elapsed - $lastStatusSeconds) -ge $StatusIntervalSeconds)) {
                $lastStatusSeconds = $elapsed
                Write-ShareSurferStatus -Phase 'Collect' -Message ('Parallel target collection progress: completed {0}/{1} target path(s); running={2}.' -f $completedCount, $targets.Count, $jobs.Count)
            }

            if ($jobs.Count -gt 0) {
                Start-Sleep -Milliseconds 200
            }
        }
    }
    finally {
        foreach ($job in @($jobs)) {
            try {
                $job.PowerShell.Stop()
            }
            catch {
            }
            $job.PowerShell.Dispose()
        }
        $pool.Close()
        $pool.Dispose()
    }

    $shares = New-Object System.Collections.ArrayList
    $items = New-Object System.Collections.ArrayList
    $aclEntries = New-Object System.Collections.ArrayList
    $sharePermissions = New-Object System.Collections.ArrayList
    $scanErrors = New-Object System.Collections.ArrayList
    $scanEvents = New-Object System.Collections.ArrayList
    [void]$scanEvents.Add((New-ShareSurferEvent -EventType 'ParallelTargetCollectionStarted' -Source 'TargetPath' -Message ('Parallel target collection started for {0} target path(s) with throttle {1}.' -f $targets.Count, $effectiveThrottle) -Detail ('Targets={0}' -f ($targets -join '; '))))

    for ($i = 1; $i -le $targets.Count; $i++) {
        if ($resultsByIndex.ContainsKey($i)) {
            $inventory = $resultsByIndex[$i]
            foreach ($row in @(ConvertTo-ShareSurferArray $inventory.Shares)) { [void]$shares.Add($row) }
            foreach ($row in @(ConvertTo-ShareSurferArray $inventory.Items)) { [void]$items.Add($row) }
            foreach ($row in @(ConvertTo-ShareSurferArray $inventory.SharePermissions)) { [void]$sharePermissions.Add($row) }
            foreach ($row in @(ConvertTo-ShareSurferArray $inventory.AclEntries)) { [void]$aclEntries.Add($row) }
            foreach ($row in @(ConvertTo-ShareSurferArray $inventory.ScanErrors)) { [void]$scanErrors.Add($row) }
            foreach ($row in @(ConvertTo-ShareSurferArray $inventory.ScanEvents)) { [void]$scanEvents.Add($row) }
            continue
        }

        $shareId = 'target-{0}' -f $i
        $target = $targets[$i - 1]
        $message = if ($errorsByIndex.ContainsKey($i)) { [string]$errorsByIndex[$i] } else { 'Parallel target collection did not return inventory.' }
        [void]$shares.Add([pscustomobject]@{
            ShareId = $shareId
            Source = 'BestEffort'
            ComputerName = ''
            ShareName = Split-Path -Leaf $target
            UNCPath = $target
            LocalPath = $target
            Description = 'Best-effort target path scan'
            PartialData = $true
            PartialReason = 'Parallel target collection failed.'
        })
        [void]$scanErrors.Add([pscustomobject]@{
            ShareId = $shareId
            FullPath = $target
            ErrorType = 'ParallelTargetCollectionError'
            Severity = 'Warning'
            Source = 'Runspace'
            Message = $message
            Detail = 'Target-level parallel collection failed before normalized row output was returned.'
        })
        [void]$scanEvents.Add((New-ShareSurferEvent -Level 'Warning' -EventType 'ParallelTargetCollectionError' -Source 'Runspace' -ShareId $shareId -Message ('Parallel target collection failed for {0}.' -f $target) -Detail $message))
    }

    [void]$scanEvents.Add((New-ShareSurferEvent -EventType 'ParallelTargetCollectionCompleted' -Source 'TargetPath' -Message ('Parallel target collection completed for {0} target path(s).' -f $targets.Count) -Detail ('Shares={0}; Items={1}; AclEntries={2}; CollectionErrors={3}' -f $shares.Count, $items.Count, $aclEntries.Count, $scanErrors.Count)))
    Write-ShareSurferStatus -Phase 'Collect' -Message ('Parallel target collection complete. Shares={0}; Items={1}; ACL entries={2}; CollectionErrors={3}' -f $shares.Count, $items.Count, $aclEntries.Count, $scanErrors.Count) -Quiet:$Quiet

    [pscustomobject]@{
        Shares = @($shares)
        Items = @($items)
        SharePermissions = @($sharePermissions)
        AclEntries = @($aclEntries)
        Identities = @()
        GroupEdges = @()
        OrgChains = @()
        OwnerMappings = @()
        ScanErrors = @($scanErrors)
        ScanEvents = @($scanEvents)
    }
}
