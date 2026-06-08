function Import-ShareSurferDiscountedPrincipals {
    param(
        [string] $Path = ''
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return @()
    }

    if (-not (Test-Path -LiteralPath $Path)) {
        throw ('Discounted principal CSV not found: {0}' -f $Path)
    }

    $rows = @(Import-Csv -LiteralPath $Path)
    $discounted = @{}
    foreach ($row in $rows) {
        if ($null -eq $row.PSObject.Properties['Identity']) {
            throw 'Discounted principal CSV must include an Identity column.'
        }

        $identity = ([string]$row.Identity).Trim()
        if ([string]::IsNullOrWhiteSpace($identity)) {
            continue
        }

        $reason = ''
        if ($null -ne $row.PSObject.Properties['Reason']) {
            $reason = ([string]$row.Reason).Trim()
        }
        if ([string]::IsNullOrWhiteSpace($reason)) {
            $reason = 'Discounted access principal'
        }

        $scope = ''
        if ($null -ne $row.PSObject.Properties['Scope']) {
            $scope = ([string]$row.Scope).Trim()
        }

        $key = $identity.ToUpperInvariant()
        if (-not $discounted.ContainsKey($key)) {
            $discounted[$key] = [pscustomobject]@{
                Identity = $identity
                Reason = $reason
                Scope = $scope
                MatchType = 'Exact'
            }
        }
    }

    @($discounted.Values | Sort-Object Identity)
}

function New-ShareSurferDiscountedPrincipalLookup {
    param(
        $DiscountedPrincipals = @()
    )

    $lookup = @{}
    foreach ($principal in @(ConvertTo-ShareSurferArray $DiscountedPrincipals)) {
        if ($null -eq $principal.PSObject.Properties['Identity']) {
            continue
        }
        $identity = ([string]$principal.Identity).Trim()
        if ($identity -eq '') {
            continue
        }
        $lookup[$identity.ToUpperInvariant()] = $principal
    }

    $lookup
}

function Get-ShareSurferDiscountedPrincipal {
    param(
        [string] $Identity = '',

        [hashtable] $DiscountedPrincipalLookup = @{}
    )

    if ([string]::IsNullOrWhiteSpace($Identity)) {
        return $null
    }

    $key = $Identity.ToUpperInvariant()
    if ($DiscountedPrincipalLookup.ContainsKey($key)) {
        return $DiscountedPrincipalLookup[$key]
    }

    $null
}

function Add-ShareSurferDiscountSummary {
    param(
        [System.Collections.ArrayList] $Values,

        $Principal
    )

    if ($null -eq $Principal) {
        return
    }

    $identity = ''
    if ($null -ne $Principal.PSObject.Properties['Identity']) {
        $identity = [string]$Principal.Identity
    }
    $reason = ''
    if ($null -ne $Principal.PSObject.Properties['Reason']) {
        $reason = [string]$Principal.Reason
    }
    if ([string]::IsNullOrWhiteSpace($reason)) {
        $reason = 'Discounted access principal'
    }

    $summary = $reason
    if (-not [string]::IsNullOrWhiteSpace($identity)) {
        $summary = '{0}: {1}' -f $identity, $reason
    }

    if ($Values -notcontains $summary) {
        [void]$Values.Add($summary)
    }
}

function New-ShareSurferDiscountReason {
    param(
        [string] $Reason = ''
    )

    if ([string]::IsNullOrWhiteSpace($Reason)) {
        return ''
    }

    'Visible but not used for migration relatedness: {0}' -f $Reason
}
