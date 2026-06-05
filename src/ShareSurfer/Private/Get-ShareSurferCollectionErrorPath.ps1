function Get-ShareSurferCollectionErrorPath {
    param(
        $ErrorRecord,

        [string] $FallbackPath = ''
    )

    if ($null -ne $ErrorRecord) {
        if ($null -ne $ErrorRecord.TargetObject) {
            $targetObject = [string]$ErrorRecord.TargetObject
            if (-not [string]::IsNullOrWhiteSpace($targetObject)) {
                return $targetObject
            }
        }

        if ($null -ne $ErrorRecord.CategoryInfo) {
            $targetName = [string]$ErrorRecord.CategoryInfo.TargetName
            if (-not [string]::IsNullOrWhiteSpace($targetName)) {
                return $targetName
            }
        }
    }

    $FallbackPath
}
