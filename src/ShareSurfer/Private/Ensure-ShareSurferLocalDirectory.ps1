function Ensure-ShareSurferLocalDirectory {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Path,

        [string] $Purpose = 'local output',

        [switch] $NoCreateMissingFolders,

        [switch] $Quiet
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return [pscustomobject]@{
            Path = $Path
            Purpose = $Purpose
            Exists = $false
            Created = $false
        }
    }

    if (Test-Path -LiteralPath $Path -PathType Container) {
        return [pscustomobject]@{
            Path = $Path
            Purpose = $Purpose
            Exists = $true
            Created = $false
        }
    }

    if (Test-Path -LiteralPath $Path -PathType Leaf) {
        throw ('Expected a directory for {0}, but a file already exists: {1}' -f $Purpose, $Path)
    }

    if ($NoCreateMissingFolders) {
        throw ('Required {0} folder does not exist and automatic folder creation was disabled: {1}' -f $Purpose, $Path)
    }

    Write-ShareSurferStatus -Phase 'Folders' -Message ('Creating missing local {0} folder: {1}. Use -NoCreateMissingFolders to opt out and fail instead.' -f $Purpose, $Path) -Quiet:$Quiet
    New-Item -ItemType Directory -Path $Path -Force | Out-Null

    [pscustomobject]@{
        Path = $Path
        Purpose = $Purpose
        Exists = $true
        Created = $true
    }
}

function Ensure-ShareSurferLocalFileParentDirectory {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Path,

        [string] $Purpose = 'local output',

        [switch] $NoCreateMissingFolders,

        [switch] $Quiet
    )

    $parent = Split-Path -Parent $Path
    if ([string]::IsNullOrWhiteSpace($parent)) {
        return [pscustomobject]@{
            Path = ''
            Purpose = $Purpose
            Exists = $true
            Created = $false
        }
    }

    Ensure-ShareSurferLocalDirectory -Path $parent -Purpose $Purpose -NoCreateMissingFolders:$NoCreateMissingFolders -Quiet:$Quiet
}
