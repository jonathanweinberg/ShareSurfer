function ConvertTo-ShareSurferFilesystemPath {
    param(
        [string] $Path = ''
    )

    if ([string]::IsNullOrWhiteSpace($Path) -or $Path.StartsWith('\\?\', [System.StringComparison]::Ordinal)) {
        return $Path
    }

    if ($Path.StartsWith('\\', [System.StringComparison]::Ordinal)) {
        return '\\?\UNC\{0}' -f $Path.TrimStart('\')
    }

    if ($Path -match '^[A-Za-z]:[\\/]') {
        return '\\?\{0}' -f $Path
    }

    $Path
}

function ConvertFrom-ShareSurferFilesystemPath {
    param(
        [string] $Path = ''
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $Path
    }

    if ($Path.StartsWith('\\?\UNC\', [System.StringComparison]::Ordinal)) {
        return '\\{0}' -f $Path.Substring(8)
    }

    if ($Path.StartsWith('\\?\', [System.StringComparison]::Ordinal)) {
        return $Path.Substring(4)
    }

    $Path
}
