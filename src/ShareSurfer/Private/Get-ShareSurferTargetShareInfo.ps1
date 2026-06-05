function Get-ShareSurferTargetShareInfo {
    param(
        [Parameter(Mandatory = $true)]
        [string] $TargetPath,

        [Parameter(Mandatory = $true)]
        $TargetItem
    )

    if ($TargetPath -match '^\\\\([^\\]+)\\([^\\]+)') {
        return [pscustomobject]@{
            ComputerName = $matches[1]
            ShareName = $matches[2]
            UNCPath = ('\\{0}\{1}' -f $matches[1], $matches[2])
        }
    }

    [pscustomobject]@{
        ComputerName = if ($env:COMPUTERNAME) { $env:COMPUTERNAME } else { [System.Environment]::MachineName }
        ShareName = $TargetItem.Name
        UNCPath = ConvertFrom-ShareSurferFilesystemPath -Path ([string]$TargetItem.FullName)
    }
}
