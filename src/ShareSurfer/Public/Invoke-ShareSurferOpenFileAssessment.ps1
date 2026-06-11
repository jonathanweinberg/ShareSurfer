function Invoke-ShareSurferOpenFileAssessment {
    [CmdletBinding()]
    param(
        [string] $ComputerName = $env:COMPUTERNAME,

        [string[]] $ShareName = @(),

        [Parameter(Mandatory = $true)]
        [string] $OutputPath,

        [ValidateSet('Auto', 'NativeRpc', 'PowerShellCim')]
        [string] $Provider = 'Auto',

        [ValidateRange(0, 86400)]
        [int] $IntervalSeconds = 60,

        [ValidateRange(1, 100000)]
        [int] $SampleCount = 1,

        [ValidateRange(0, 525600)]
        [int] $DurationMinutes = 0,

        [switch] $Force,

        [switch] $Quiet,

        [switch] $PassThru
    )

    if ([string]::IsNullOrWhiteSpace($ComputerName)) {
        $ComputerName = $env:COMPUTERNAME
    }

    if (Test-Path -LiteralPath $OutputPath) {
        if (-not $Force) {
            $existingFiles = @(Get-ChildItem -LiteralPath $OutputPath -Filter 'open_file_*.csv' -File -ErrorAction SilentlyContinue)
            if ($existingFiles.Count -gt 0) {
                throw ('Open file assessment files already exist in {0}. Pass -Force to replace them.' -f $OutputPath)
            }
        }
    }
    else {
        New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
    }

    $schema = Get-ShareSurferOpenFileExportSchema
    $assessmentId = [guid]::NewGuid().ToString('N')
    $startedAt = (Get-Date).ToUniversalTime()
    $providerName = $Provider
    if ($providerName -eq 'Auto') {
        $providerName = if (Test-ShareSurferIsWindows) { 'NativeRpc' } else { 'PowerShellCim' }
    }

    $effectiveSampleCount = $SampleCount
    if ($DurationMinutes -gt 0) {
        $durationSeconds = $DurationMinutes * 60
        if ($IntervalSeconds -le 0) {
            $effectiveSampleCount = 1
        }
        else {
            $effectiveSampleCount = [Math]::Max(1, [int][Math]::Floor($durationSeconds / $IntervalSeconds) + 1)
        }
    }

    Write-ShareSurferStatus -Phase 'OpenFiles' -Message ('Starting open-file assessment on {0}. Provider={1}; Samples={2}; IntervalSeconds={3}.' -f $ComputerName, $providerName, $effectiveSampleCount, $IntervalSeconds) -Quiet:$Quiet

    $samples = New-Object System.Collections.ArrayList
    $errors = New-Object System.Collections.ArrayList
    for ($sampleNumber = 1; $sampleNumber -le $effectiveSampleCount; $sampleNumber++) {
        $sampleId = 'sample-{0:000000}' -f $sampleNumber
        $sampleTimestamp = (Get-Date).ToUniversalTime().ToString('o')
        Write-ShareSurferStatus -Phase 'OpenFiles' -Message ('Collecting open-file sample {0} of {1}.' -f $sampleNumber, $effectiveSampleCount) -Quiet:$Quiet

        try {
            $sampleRows = @()
            if ($providerName -eq 'NativeRpc') {
                $sampleRows = @(Get-ShareSurferNativeOpenFileRows -ComputerName $ComputerName -ShareName $ShareName -AssessmentId $assessmentId -SampleId $sampleId -SampleTimestamp $sampleTimestamp)
            }
            else {
                $sampleRows = @(Get-ShareSurferPowerShellOpenFileRows -ComputerName $ComputerName -ShareName $ShareName -AssessmentId $assessmentId -SampleId $sampleId -SampleTimestamp $sampleTimestamp)
            }

            foreach ($row in $sampleRows) {
                [void]$samples.Add($row)
            }
        }
        catch {
            $shareText = if ($null -ne $ShareName -and @($ShareName).Count -gt 0) { @($ShareName) -join '; ' } else { '' }
            [void]$errors.Add([pscustomobject]@{
                ErrorId = 'open-file-error-{0:000000}' -f ($errors.Count + 1)
                AssessmentId = $assessmentId
                SampleId = $sampleId
                Timestamp = $sampleTimestamp
                ComputerName = $ComputerName
                ShareName = $shareText
                Provider = $providerName
                ErrorType = 'OpenFileCollectionError'
                Message = $_.Exception.Message
                Detail = $_.ToString()
            })
            Write-ShareSurferStatus -Phase 'OpenFiles' -Message ('Open-file sample {0} recorded a collection error: {1}' -f $sampleNumber, $_.Exception.Message) -Quiet:$Quiet
        }

        if ($sampleNumber -lt $effectiveSampleCount -and $IntervalSeconds -gt 0) {
            Start-Sleep -Seconds $IntervalSeconds
        }
    }

    $completedAt = (Get-Date).ToUniversalTime()
    $summary = @(ConvertTo-ShareSurferOpenFileSummaryRows -Samples @($samples))
    $manifest = @(
        [pscustomobject]@{
            AssessmentId = $assessmentId
            GeneratedAt = $completedAt.ToString('o')
            ExportVersion = '1'
            ComputerName = $ComputerName
            ShareNames = if ($null -ne $ShareName -and @($ShareName).Count -gt 0) { @($ShareName) -join '; ' } else { '' }
            Provider = $providerName
            IntervalSeconds = $IntervalSeconds
            SampleCount = $effectiveSampleCount
            DurationMinutes = $DurationMinutes
            StartedAt = $startedAt.ToString('o')
            CompletedAt = $completedAt.ToString('o')
            PackageKind = 'OpenFileAssessment'
        }
    )

    $data = @{
        'open_file_manifest.csv' = $manifest
        'open_file_samples.csv' = @($samples)
        'open_file_summary.csv' = $summary
        'open_file_errors.csv' = @($errors)
    }

    foreach ($fileName in $schema.Keys) {
        Export-ShareSurferCsv -Path (Join-Path $OutputPath $fileName) -Columns $schema[$fileName] -Rows $data[$fileName]
    }

    Write-ShareSurferStatus -Phase 'OpenFiles' -Message ('Open-file assessment complete. Samples={0}; OpenFileRows={1}; HotFolders={2}; Errors={3}; OutputPath={4}' -f $effectiveSampleCount, $samples.Count, @($summary | Where-Object { [string]$_.HotFolder -eq 'True' }).Count, $errors.Count, $OutputPath) -Quiet:$Quiet

    $result = [pscustomobject]@{
        AssessmentId = $assessmentId
        OutputPath = $OutputPath
        Provider = $providerName
        SampleCount = $effectiveSampleCount
        OpenFileRows = $samples.Count
        SummaryRows = $summary.Count
        ErrorCount = $errors.Count
        IsValid = (Test-Path -LiteralPath (Join-Path $OutputPath 'open_file_manifest.csv')) -and
            (Test-Path -LiteralPath (Join-Path $OutputPath 'open_file_samples.csv')) -and
            (Test-Path -LiteralPath (Join-Path $OutputPath 'open_file_summary.csv')) -and
            (Test-Path -LiteralPath (Join-Path $OutputPath 'open_file_errors.csv'))
    }

    if ($PassThru) {
        $result
    }
}
