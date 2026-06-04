function New-ShareSurferFinding {
    param(
        [Parameter(Mandatory = $true)]
        [string] $FindingType,

        [Parameter(Mandatory = $true)]
        [string] $Severity,

        [string] $ShareId = '',
        [string] $ItemId = '',
        [string] $FullPath = '',
        [string] $Identity = '',
        [string] $ObservedValue = '',
        [string] $PolicyValue = '',

        [Parameter(Mandatory = $true)]
        [string] $Message
    )

    [pscustomobject]@{
        FindingId = [guid]::NewGuid().ToString('N')
        FindingType = $FindingType
        Severity = $Severity
        ShareId = $ShareId
        ItemId = $ItemId
        FullPath = $FullPath
        Identity = $Identity
        ObservedValue = $ObservedValue
        PolicyValue = $PolicyValue
        Message = $Message
    }
}
