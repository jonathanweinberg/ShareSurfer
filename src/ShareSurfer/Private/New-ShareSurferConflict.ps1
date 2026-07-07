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
        [int] $AffectedItemCount = 0,
        [string] $ExamplePath = '',
        [string] $AffectedPathPrefix = '',
        [string] $FirstSeenPath = '',
        [int] $MaxDepth = 0,
        [string] $EvidenceCompleteness = '',

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
        AffectedItemCount = $AffectedItemCount
        ExamplePath = $ExamplePath
        AffectedPathPrefix = $AffectedPathPrefix
        FirstSeenPath = $FirstSeenPath
        MaxDepth = $MaxDepth
        EvidenceCompleteness = $EvidenceCompleteness
        Severity = $Severity
        Message = $Message
    }
}
