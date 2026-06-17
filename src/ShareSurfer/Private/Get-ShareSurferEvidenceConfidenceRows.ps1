function Get-ShareSurferEvidenceConfidenceRows {
    param(
        [object[]] $Shares = @(),
        [object[]] $Items = @(),
        [object[]] $CollectionErrors = @(),
        [string] $RequestedProvider = '',
        [string] $EffectiveProvider = ''
    )

    function New-ShareSurferEvidenceConfidenceRow {
        param(
            [string] $Scope,
            [string] $ScopeId,
            [string] $ScopeName,
            [int] $PartialShareCount,
            [int] $CollectionErrorCount,
            [int] $HighSeverityErrorCount,
            [int] $TotalShares,
            [int] $TotalItems,
            [string] $RequestedProvider,
            [string] $EffectiveProvider,
            [bool] $ProviderFallback
        )

        $signals = New-Object System.Collections.ArrayList
        if ($PartialShareCount -gt 0) {
            [void]$signals.Add(('{0} partial share(s) need review.' -f $PartialShareCount))
        }
        if ($CollectionErrorCount -gt 0) {
            [void]$signals.Add(('{0} collection error(s) recorded.' -f $CollectionErrorCount))
        }
        if ($HighSeverityErrorCount -gt 0) {
            [void]$signals.Add(('{0} high-severity collection error(s) may hide evidence.' -f $HighSeverityErrorCount))
        }
        if ($TotalShares -eq 0) {
            [void]$signals.Add('No shares were exported.')
        }
        if ($ProviderFallback) {
            [void]$signals.Add(('Provider fallback used: requested {0}, effective {1}.' -f $RequestedProvider, $EffectiveProvider))
        }
        if ($signals.Count -eq 0) {
            [void]$signals.Add('No evidence completeness blockers were detected in the normalized export.')
        }

        $scorePenalty =
            [Math]::Min(35, $PartialShareCount * 12) +
            [Math]::Min(30, $CollectionErrorCount * 8) +
            [Math]::Min(18, $HighSeverityErrorCount * 6) +
            [Math]::Min(15, $(if ($TotalShares -eq 0) { 15 } else { 0 })) +
            [Math]::Min(8, $(if ($ProviderFallback) { 8 } else { 0 }))
        $score = [Math]::Max(20, 100 - $scorePenalty)

        $stopGate = ''
        if ($TotalShares -eq 0) {
            $stopGate = 'No share evidence was exported; do not use this scan for owner signoff.'
        }
        elseif ($HighSeverityErrorCount -gt 0) {
            $stopGate = 'High-severity collection errors can hide permissions or paths; review Diagnostics before owner signoff.'
        }

        $reviewGate = ''
        if ($PartialShareCount -gt 0 -or $CollectionErrorCount -gt 0) {
            $reviewGate = 'Partial data or collection errors were recorded; treat affected areas as incomplete until reviewed.'
        }
        elseif ($ProviderFallback) {
            $reviewGate = 'Collection provider fallback changed the metadata path; review diagnostics before final approval.'
        }

        if (-not [string]::IsNullOrWhiteSpace($stopGate)) {
            $score = [Math]::Min($score, 64)
        }
        elseif (-not [string]::IsNullOrWhiteSpace($reviewGate)) {
            $score = [Math]::Min($score, 84)
        }
        $label = if ($score -ge 85) { 'Good' } elseif ($score -ge 65) { 'Review' } else { 'Partial' }

        $recommendedAction = if (-not [string]::IsNullOrWhiteSpace($stopGate)) {
            $stopGate
        }
        elseif (-not [string]::IsNullOrWhiteSpace($reviewGate)) {
            $reviewGate
        }
        else {
            'Proceed with owner review using the exported evidence, while still validating business intent.'
        }

        $providerState = if ([string]::IsNullOrWhiteSpace($RequestedProvider) -and [string]::IsNullOrWhiteSpace($EffectiveProvider)) {
            'Provider not recorded.'
        }
        else {
            'Requested provider: {0}; effective provider: {1}.' -f $RequestedProvider, $EffectiveProvider
        }

        [pscustomobject]@{
            ConfidenceId = Get-ShareSurferStableToken -Value ('{0}|{1}' -f $Scope, $ScopeId) -Salt 'EvidenceConfidence'
            Scope = $Scope
            ScopeId = $ScopeId
            ScopeName = $ScopeName
            ConfidenceLabel = $label
            ConfidenceScore = $score
            StopGate = $stopGate
            ReviewGate = $reviewGate
            SignalCount = $signals.Count
            Signals = (@($signals) -join ' ')
            PartialShareCount = $PartialShareCount
            CollectionErrorCount = $CollectionErrorCount
            HighSeverityErrorCount = $HighSeverityErrorCount
            TotalShares = $TotalShares
            TotalItems = $TotalItems
            RequestedProvider = $RequestedProvider
            EffectiveProvider = $EffectiveProvider
            ProviderFallback = $ProviderFallback
            RecommendedAction = $recommendedAction
            Detail = $providerState
        }
    }

    $requested = if ([string]::IsNullOrWhiteSpace($RequestedProvider)) { '' } else { $RequestedProvider }
    $effective = if ([string]::IsNullOrWhiteSpace($EffectiveProvider)) { $requested } else { $EffectiveProvider }
    $providerFallback = -not [string]::IsNullOrWhiteSpace($requested) -and
        -not [string]::IsNullOrWhiteSpace($effective) -and
        $requested -ne $effective

    $partialShares = @($Shares | Where-Object {
        $null -ne $_.PSObject.Properties['PartialData'] -and [string]$_.PartialData -eq 'True'
    })
    $highSeverityErrors = @($CollectionErrors | Where-Object {
        $null -ne $_.PSObject.Properties['Severity'] -and [string]$_.Severity -eq 'High'
    })

    $rows = New-Object System.Collections.ArrayList
    [void]$rows.Add((New-ShareSurferEvidenceConfidenceRow `
        -Scope 'Scan' `
        -ScopeId 'scan' `
        -ScopeName 'Overall scan evidence completeness' `
        -PartialShareCount $partialShares.Count `
        -CollectionErrorCount $CollectionErrors.Count `
        -HighSeverityErrorCount $highSeverityErrors.Count `
        -TotalShares $Shares.Count `
        -TotalItems $Items.Count `
        -RequestedProvider $requested `
        -EffectiveProvider $effective `
        -ProviderFallback $providerFallback))

    foreach ($share in @($Shares)) {
        $shareId = if ($null -ne $share.PSObject.Properties['ShareId']) { [string]$share.ShareId } else { '' }
        $shareName = if ($null -ne $share.PSObject.Properties['ShareName']) { [string]$share.ShareName } else { $shareId }
        $shareErrors = @($CollectionErrors | Where-Object {
            $null -ne $_.PSObject.Properties['ShareId'] -and [string]$_.ShareId -eq $shareId
        })
        $shareItems = @($Items | Where-Object {
            $null -ne $_.PSObject.Properties['ShareId'] -and [string]$_.ShareId -eq $shareId
        })
        $sharePartial = $null -ne $share.PSObject.Properties['PartialData'] -and [string]$share.PartialData -eq 'True'
        $shareHighErrors = @($shareErrors | Where-Object {
            $null -ne $_.PSObject.Properties['Severity'] -and [string]$_.Severity -eq 'High'
        })

        [void]$rows.Add((New-ShareSurferEvidenceConfidenceRow `
            -Scope 'Share' `
            -ScopeId $shareId `
            -ScopeName $shareName `
            -PartialShareCount $(if ($sharePartial) { 1 } else { 0 }) `
            -CollectionErrorCount $shareErrors.Count `
            -HighSeverityErrorCount $shareHighErrors.Count `
            -TotalShares 1 `
            -TotalItems $shareItems.Count `
            -RequestedProvider $requested `
            -EffectiveProvider $effective `
            -ProviderFallback $providerFallback))
    }

    @($rows)
}
