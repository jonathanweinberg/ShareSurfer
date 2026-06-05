function New-ShareSurferConflict {
    param(
        [Parameter(Mandatory = $true)]
        [string] $ConflictType,

        [Parameter(Mandatory = $true)]
        [string] $ShareId,

        [string] $ItemId = '',
        [string] $Identity = '',
        [string] $ShareRights = '',
        [string] $NtfsRights = '',

        [Parameter(Mandatory = $true)]
        [string] $Severity,

        [Parameter(Mandatory = $true)]
        [string] $Message
    )

    [pscustomobject]@{
        ConflictId = [guid]::NewGuid().ToString('N')
        ConflictType = $ConflictType
        ShareId = $ShareId
        ItemId = $ItemId
        Identity = $Identity
        ShareRights = $ShareRights
        NtfsRights = $NtfsRights
        Severity = $Severity
        Message = $Message
    }
}
