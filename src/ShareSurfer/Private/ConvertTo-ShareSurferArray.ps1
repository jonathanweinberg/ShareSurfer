function ConvertTo-ShareSurferArray {
    param(
        [Parameter(ValueFromPipeline = $true)]
        $Value
    )

    process {
        if ($null -eq $Value) {
            return @()
        }

        if ($Value -is [string]) {
            return @($Value)
        }

        if ($Value -is [System.Collections.IEnumerable]) {
            return @($Value)
        }

        return @($Value)
    }
}
