function New-ShareSurferOwnerMappingDraft {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $ExportPath,

        [Parameter(Mandatory = $true)]
        [string] $OutputPath,

        [ValidateSet('Share', 'TopLevelFolder')]
        [string] $Scope = 'Share',

        [int] $MaximumRows = 500,

        [string] $ReusableCommandPath = '',

        [switch] $Force
    )

    if (-not (Test-Path -LiteralPath $ExportPath)) {
        throw "ShareSurfer export path was not found: $ExportPath"
    }

    if ((Test-Path -LiteralPath $OutputPath) -and -not $Force) {
        throw "Owner mapping draft already exists: $OutputPath. Use -Force to overwrite it."
    }

    $shares = @(Read-ShareSurferCsv -Path (Join-Path $ExportPath 'shares.csv'))
    $items = @(Read-ShareSurferCsv -Path (Join-Path $ExportPath 'items.csv'))
    $ownerMappings = @(Read-ShareSurferCsv -Path (Join-Path $ExportPath 'owner_mappings.csv'))

    $candidates = New-Object System.Collections.Generic.List[object]
    if ($Scope -eq 'Share') {
        foreach ($share in $shares) {
            $path = [string]$share.UNCPath
            if ([string]::IsNullOrWhiteSpace($path)) {
                $path = [string]$share.LocalPath
            }
            if (-not [string]::IsNullOrWhiteSpace($path)) {
                $candidates.Add([pscustomobject]@{
                    Path = $path
                    ShareId = [string]$share.ShareId
                    Scope = 'Share'
                })
            }
        }
    }
    else {
        foreach ($item in @($items | Where-Object { [string]$_.ItemType -eq 'Directory' -and [int]$_.Depth -le 1 })) {
            $path = [string]$item.FullPath
            if (-not [string]::IsNullOrWhiteSpace($path)) {
                $candidates.Add([pscustomobject]@{
                    Path = $path
                    ShareId = [string]$item.ShareId
                    Scope = 'TopLevelFolder'
                })
            }
        }
    }

    $draftRows = New-Object System.Collections.Generic.List[object]
    foreach ($candidate in @($candidates | Sort-Object Path -Unique)) {
        $path = [string]$candidate.Path
        $hasMapping = $false
        foreach ($mapping in $ownerMappings) {
            $pattern = [string]$mapping.Pattern
            if ((Test-ShareSurferWildcardMatch -Pattern $pattern -Value $path) -or (Test-ShareSurferWildcardMatch -Pattern $pattern -Value ($path + '\'))) {
                $hasMapping = $true
                break
            }
        }

        if (-not $hasMapping) {
            $pattern = New-ShareSurferOwnerMappingPattern -Path $path
            $draftRows.Add([pscustomobject]@{
                Pattern = $pattern
                Owner = ''
                BusinessUnit = ''
                Source = 'OwnerMappingDraft'
                PathPrefix = $path
                OwnerMail = ''
                OBS = ''
                Confidence = 'NeedsAdminReview'
                MappingScope = [string]$candidate.Scope
                ShareId = [string]$candidate.ShareId
                Notes = 'Fill Owner and BusinessUnit before using this as -OwnerMappingPath. Extra columns are for review notes.'
            })
        }

        if ($draftRows.Count -ge $MaximumRows) {
            break
        }
    }

    $parent = Split-Path -Parent $OutputPath
    if (-not [string]::IsNullOrWhiteSpace($parent) -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    Export-ShareSurferCsv -Path $OutputPath -Columns (Get-ShareSurferOwnerMappingColumns) -Rows @($draftRows.ToArray())
    $reusableCommands = New-ShareSurferOwnerMappingDraftReusableCommands -ExportPath $ExportPath -DraftPath $OutputPath -Scope $Scope -MaximumRows $MaximumRows
    $writtenReusableCommandPath = Write-ShareSurferReusableCommandFile -Path $ReusableCommandPath -CommandText $reusableCommands

    [pscustomobject]@{
        ExportPath = $ExportPath
        OutputPath = $OutputPath
        Scope = $Scope
        DraftRowCount = $draftRows.Count
        ExistingOwnerMappingCount = $ownerMappings.Count
        CandidateCount = $candidates.Count
        MaximumRows = $MaximumRows
        ReusableCommandPath = $writtenReusableCommandPath
        ReusableCommands = $reusableCommands
    }
}
