function New-ShareSurferEvent {
    param(
        [ValidateSet('Info', 'Warning', 'Error')]
        [string] $Level = 'Info',

        [Parameter(Mandatory = $true)]
        [string] $EventType,

        [string] $Source = 'ShareSurfer',
        [string] $ShareId = '',
        [string] $ItemId = '',
        [string] $Message = '',
        [string] $Detail = ''
    )

    [pscustomobject]@{
        EventId = [guid]::NewGuid().ToString('N')
        Timestamp = (Get-Date).ToUniversalTime().ToString('o')
        Level = $Level
        EventType = $EventType
        Source = $Source
        ShareId = $ShareId
        ItemId = $ItemId
        Message = $Message
        Detail = $Detail
    }
}
