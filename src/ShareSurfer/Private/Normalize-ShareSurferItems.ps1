function Normalize-ShareSurferItems {
    param(
        [Parameter(Mandatory = $true)]
        $Items
    )

    $rows = @(ConvertTo-ShareSurferArray $Items)
    $protectedByPath = @{}
    foreach ($seedItem in $rows) {
        if ($null -ne $seedItem.PSObject.Properties['InheritanceBrokenAt']) {
            $seedBreak = [string]$seedItem.InheritanceBrokenAt
            if ($seedBreak -ne '' -and -not $protectedByPath.ContainsKey($seedBreak)) {
                $protectedByPath[$seedBreak] = $true
            }
        }
    }
    $sorted = @($rows | Sort-Object @{ Expression = { ([string]$_.FullPath).Length } }, FullPath)
    $normalized = New-Object System.Collections.ArrayList

    foreach ($item in $sorted) {
        $fullPath = [string]$item.FullPath
        $knownBreak = ''
        $ancestorPath = $fullPath
        while (-not [string]::IsNullOrWhiteSpace($ancestorPath)) {
            $parentPath = Get-ShareSurferPathParent -Path $ancestorPath
            if ([string]::IsNullOrWhiteSpace($parentPath) -or $parentPath -eq $ancestorPath) {
                break
            }

            if ($protectedByPath.ContainsKey($parentPath)) {
                $knownBreak = $parentPath
                break
            }

            $ancestorPath = $parentPath
        }

        $inheritanceEnabled = $true
        if ($null -ne $item.PSObject.Properties['InheritanceEnabled'] -and [string]$item.InheritanceEnabled -ne '') {
            $inheritanceEnabled = [System.Convert]::ToBoolean($item.InheritanceEnabled)
        }

        $inheritanceBrokenAt = ''
        if ($null -ne $item.PSObject.Properties['InheritanceBrokenAt']) {
            $inheritanceBrokenAt = [string]$item.InheritanceBrokenAt
        }

        if ($inheritanceBrokenAt -eq '' -and $knownBreak -ne '') {
            $inheritanceBrokenAt = $knownBreak
        }

        if (-not $inheritanceEnabled -and $inheritanceBrokenAt -eq '') {
            $inheritanceBrokenAt = $fullPath
        }

        if ($inheritanceBrokenAt -ne '' -and -not $protectedByPath.ContainsKey($inheritanceBrokenAt)) {
            $protectedByPath[$inheritanceBrokenAt] = $true
        }

        [void]$normalized.Add([pscustomobject]@{
            ItemId = $item.ItemId
            ShareId = $item.ShareId
            ItemType = $item.ItemType
            FullPath = $item.FullPath
            RelativePath = $item.RelativePath
            Depth = $item.Depth
            Owner = $item.Owner
            InheritanceEnabled = $inheritanceEnabled
            InheritanceBrokenAt = $inheritanceBrokenAt
        })
    }

    @($normalized)
}

function Get-ShareSurferPathParent {
    param(
        [string] $Path = ''
    )

    $text = ([string]$Path).TrimEnd('\', '/')
    if ($text -eq '') {
        return ''
    }

    $lastBackslash = $text.LastIndexOf('\')
    $lastSlash = $text.LastIndexOf('/')
    $lastSeparator = [Math]::Max($lastBackslash, $lastSlash)
    if ($lastSeparator -le 0) {
        return ''
    }

    if ($lastSeparator -eq 2 -and $text.Length -ge 3 -and $text[1] -eq ':') {
        return ''
    }

    $text.Substring(0, $lastSeparator)
}
