function ConvertTo-ShareSurferOpenFileSummaryRows {
    param(
        $Samples
    )

    $rows = @(ConvertTo-ShareSurferArray $Samples | Where-Object {
        -not [string]::IsNullOrWhiteSpace([string]$_.Path) -or
            -not [string]::IsNullOrWhiteSpace([string]$_.ShareRelativePath)
    })

    $summaryRows = New-Object System.Collections.ArrayList
    $groups = @($rows | Group-Object -Property ComputerName, ShareName, FolderPath, ShareRelativeFolder)
    foreach ($group in $groups) {
        $items = @($group.Group)
        if ($items.Count -eq 0) {
            continue
        }

        $first = $items[0]
        $sampleIds = @($items | ForEach-Object { [string]$_.SampleId } | Where-Object { $_ -ne '' } | Sort-Object -Unique)
        $timestamps = @($items | ForEach-Object { [string]$_.SampleTimestamp } | Where-Object { $_ -ne '' } | Sort-Object)
        $users = @($items | ForEach-Object { [string]$_.ClientUserName } | Where-Object { $_ -ne '' } | Sort-Object)
        $clients = @($items | ForEach-Object { [string]$_.ClientComputerName } | Where-Object { $_ -ne '' } | Sort-Object)
        $uniqueUsers = @($users | Sort-Object -Unique)
        $uniqueClients = @($clients | Sort-Object -Unique)
        $locks = @($items | ForEach-Object {
            $value = 0
            if ([int]::TryParse([string]$_.Locks, [ref]$value)) {
                $value
            }
            else {
                0
            }
        })
        $totalLocks = 0
        foreach ($lock in $locks) {
            $totalLocks += [int]$lock
        }
        $maxLocks = 0
        foreach ($lock in $locks) {
            if ([int]$lock -gt $maxLocks) {
                $maxLocks = [int]$lock
            }
        }

        $heatScore = $items.Count + ($uniqueUsers.Count * 2) + $uniqueClients.Count + $totalLocks
        $pathKey = ('{0}|{1}|{2}' -f [string]$first.ComputerName, [string]$first.ShareName, [string]$first.ShareRelativeFolder).Trim('|')
        if ([string]::IsNullOrWhiteSpace($pathKey)) {
            $pathKey = [string]$first.FolderPath
        }

        [void]$summaryRows.Add([pscustomobject]@{
            AssessmentId = [string]$first.AssessmentId
            ComputerName = [string]$first.ComputerName
            ShareName = [string]$first.ShareName
            FolderPath = [string]$first.FolderPath
            ShareRelativeFolder = [string]$first.ShareRelativeFolder
            ObservationCount = $items.Count
            SampleCount = $sampleIds.Count
            FirstSeen = if ($timestamps.Count -gt 0) { [string]$timestamps[0] } else { '' }
            LastSeen = if ($timestamps.Count -gt 0) { [string]$timestamps[-1] } else { '' }
            UniqueUsers = $uniqueUsers.Count
            UniqueClients = $uniqueClients.Count
            TopUsers = (@($uniqueUsers | Select-Object -First 8) -join '; ')
            TopClients = (@($uniqueClients | Select-Object -First 8) -join '; ')
            TotalLocks = $totalLocks
            MaxLocks = $maxLocks
            HeatScore = $heatScore
            HotFolder = [bool]($items.Count -ge 3 -or $uniqueUsers.Count -ge 2 -or $uniqueClients.Count -ge 2 -or $heatScore -ge 6)
            PathProximityKey = $pathKey
        })
    }

    @($summaryRows | Sort-Object -Property @{ Expression = { [int]$_.HeatScore }; Descending = $true }, FolderPath)
}
