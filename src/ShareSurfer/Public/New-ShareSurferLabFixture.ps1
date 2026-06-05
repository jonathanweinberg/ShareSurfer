function New-ShareSurferLabFixture {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)]
        [string] $RootPath,

        [string] $DomainNetBiosName = 'CONTOSO',
        [string] $ObsAttribute = 'extensionAttribute10',
        [ValidateSet('Focused', 'Enterprise')]
        [string] $Scale = 'Focused',
        [Alias('UserCount')]
        [ValidateRange(1000, 100000)]
        [int] $EnterpriseUserCount = 2500,
        [Alias('ShareCount')]
        [ValidateRange(100, 5000)]
        [int] $EnterpriseShareCount = 250,
        [Alias('FilesPerShare')]
        [ValidateRange(1, 128)]
        [int] $EnterpriseFilesPerShare = 8,
        [Alias('MaxDepth')]
        [ValidateRange(3, 12)]
        [int] $EnterpriseTargetDepth = 5,
        [Alias('FileSizeBytes')]
        [ValidateRange(128, 1048576)]
        [int64] $EnterpriseFileSizeBytes = 512,
        [ValidateRange(0, 5000)]
        [int] $LongPathShareCount = 1,
        [ValidateRange(1, 8589934592)]
        [int64] $MaxLabBytes = 2147483648,
        [ValidateRange(1, 8589934592)]
        [int64] $AbsoluteMaxLabBytes = 8589934592,
        [Alias('DiskBudgetGB')]
        [ValidateRange(1, 8)]
        [double] $MaxLabGiB = 0,
        [switch] $OutputPlanOnly,
        [switch] $Force
    )

    if ($PSBoundParameters.ContainsKey('MaxLabGiB')) {
        $MaxLabBytes = [int64]($MaxLabGiB * 1073741824)
    }
    if ($MaxLabBytes -gt $AbsoluteMaxLabBytes) {
        throw ('MaxLabBytes {0} exceeds AbsoluteMaxLabBytes {1}. Use a lower explicit disk budget.' -f $MaxLabBytes, $AbsoluteMaxLabBytes)
    }

    $plan = New-ShareSurferLabPlan -RootPath $RootPath -DomainNetBiosName $DomainNetBiosName -ObsAttribute $ObsAttribute -Scale $Scale -EnterpriseUserCount $EnterpriseUserCount -EnterpriseShareCount $EnterpriseShareCount -EnterpriseFilesPerShare $EnterpriseFilesPerShare -EnterpriseTargetDepth $EnterpriseTargetDepth -EnterpriseFileSizeBytes $EnterpriseFileSizeBytes -LongPathShareCount $LongPathShareCount -MaxLabBytes $MaxLabBytes -AbsoluteMaxLabBytes $AbsoluteMaxLabBytes
    if ($OutputPlanOnly) {
        return $plan
    }

    if (-not (Test-ShareSurferIsWindows)) {
        throw 'New-ShareSurferLabFixture can only create live SMB/AD fixtures on Windows. Use -OutputPlanOnly on non-Windows systems.'
    }

    if ((Test-Path -LiteralPath $RootPath) -and -not $Force) {
        throw "Lab root already exists: $RootPath. Use -Force to reuse it."
    }

    if ([int64]$plan.EstimatedLabBytes -gt [int64]$plan.MaxLabBytes) {
        throw ('Lab plan estimates {0} bytes, which exceeds MaxLabBytes {1}.' -f $plan.EstimatedLabBytes, $plan.MaxLabBytes)
    }

    if ($PSCmdlet.ShouldProcess($RootPath, 'Create ShareSurfer lab directories and Windows SMB shares')) {
        New-ShareSurferLabDirectory -Path $RootPath | Out-Null
        foreach ($share in $plan.Shares) {
            New-ShareSurferLabDirectory -Path $share.LocalPath | Out-Null
        }

        foreach ($scenario in $plan.AclScenarios) {
            $share = @($plan.Shares | Where-Object { $_.ShareName -eq $scenario.ShareName })[0]
            $scenarioPath = Join-Path $share.LocalPath $scenario.RelativePath
            $targetType = Get-ShareSurferLabScenarioTargetType -Scenario $scenario
            if ($targetType -eq 'File') {
                $parentPath = Split-Path -Parent $scenarioPath
                New-ShareSurferLabDirectory -Path $parentPath | Out-Null
                Set-ShareSurferLabFileContent -Path $scenarioPath -Content (New-ShareSurferLabFileContent -Tag $scenario.Name -SizeBytes 512)
            }
            else {
                New-ShareSurferLabDirectory -Path $scenarioPath | Out-Null
                Set-ShareSurferLabFileContent -Path (Join-Path $scenarioPath 'sample.txt') -Content (New-ShareSurferLabFileContent -Tag $scenario.Name -SizeBytes 512)
            }
        }

        if ($plan.PSObject.Properties['FileFixtures']) {
            foreach ($file in @($plan.FileFixtures)) {
                $share = @($plan.Shares | Where-Object { $_.ShareName -eq $file.ShareName })[0]
                if ($null -eq $share) {
                    continue
                }
                $filePath = Join-Path $share.LocalPath $file.RelativePath
                $parentPath = Split-Path -Parent $filePath
                New-ShareSurferLabDirectory -Path $parentPath | Out-Null
                $content = New-ShareSurferLabFileContent -Tag $file.ContentTag -SizeBytes $file.SizeBytes
                Set-ShareSurferLabFileContent -Path $filePath -Content $content
            }
        }

        Initialize-ShareSurferLabDirectoryObjects -Plan $plan

        $smbShareCommand = Get-Command New-SmbShare -ErrorAction SilentlyContinue
        if ($null -ne $smbShareCommand) {
            foreach ($share in $plan.Shares) {
                $existing = Get-SmbShare -Name $share.ShareName -ErrorAction SilentlyContinue
                if ($null -eq $existing) {
                    New-SmbShare -Name $share.ShareName -Path $share.LocalPath -Description $share.Description -FullAccess 'Administrators' | Out-Null
                }
                else {
                    Assert-ShareSurferLabSmbSharePath -ShareName $share.ShareName -ExistingShare $existing -PlannedPath $share.LocalPath
                }
                foreach ($permission in $share.SharePermissions) {
                    $accessRight = switch ($permission.Rights) {
                        'Full' { 'Full' }
                        'Modify' { 'Change' }
                        'Change' { 'Change' }
                        default { 'Read' }
                    }
                    Grant-SmbShareAccess -Name $share.ShareName -AccountName $permission.Identity -AccessRight $accessRight -Force -ErrorAction SilentlyContinue | Out-Null
                }
            }
        }

        foreach ($scenario in $plan.AclScenarios) {
            $share = @($plan.Shares | Where-Object { $_.ShareName -eq $scenario.ShareName })[0]
            $scenarioPath = Join-Path $share.LocalPath $scenario.RelativePath
            try {
                $targetType = Get-ShareSurferLabScenarioTargetType -Scenario $scenario
                $aclTargetPath = if ($scenario.IsInherited) { $share.LocalPath } else { $scenarioPath }
                $aclFilesystemPath = ConvertTo-ShareSurferLabFilesystemPath -Path $aclTargetPath
                $acl = Get-Acl -LiteralPath $aclFilesystemPath -ErrorAction Stop
                if ($scenario.Name -eq 'BrokenInheritance') {
                    $acl.SetAccessRuleProtection($true, $true)
                }
                $inheritanceFlags = if ($targetType -eq 'File') { 'None' } else { 'ContainerInherit,ObjectInherit' }
                $accessControlType = Get-ShareSurferLabScenarioAccessType -Scenario $scenario
                $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
                    $scenario.Identity,
                    $scenario.Rights,
                    $inheritanceFlags,
                    'None',
                    $accessControlType
                )
                if ($accessControlType -eq 'Deny') {
                    $acl.AddAccessRule($rule)
                }
                else {
                    $acl.SetAccessRule($rule)
                }
                $ownerIdentity = Get-ShareSurferLabScenarioOwnerIdentity -Scenario $scenario
                if ($ownerIdentity -ne '') {
                    $acl.SetOwner((New-Object System.Security.Principal.NTAccount($ownerIdentity)))
                }
                Set-Acl -LiteralPath $aclFilesystemPath -AclObject $acl -ErrorAction Stop
            }
            catch {
                Write-Warning ("Unable to apply ACL scenario {0} to {1}: {2}" -f $scenario.Name, $scenarioPath, $_.Exception.Message)
            }
        }
    }

    $plan
}

function New-ShareSurferLabDirectory {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Path
    )

    [System.IO.Directory]::CreateDirectory((ConvertTo-ShareSurferLabFilesystemPath -Path $Path))
}

function Set-ShareSurferLabFileContent {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Path,

        [string] $Content = ''
    )

    $bytes = [System.Text.Encoding]::ASCII.GetBytes($Content)
    [System.IO.File]::WriteAllBytes((ConvertTo-ShareSurferLabFilesystemPath -Path $Path), $bytes)
}

function ConvertTo-ShareSurferLabFilesystemPath {
    param(
        [string] $Path = ''
    )

    if ([string]::IsNullOrWhiteSpace($Path) -or $Path.StartsWith('\\?\', [System.StringComparison]::Ordinal)) {
        return $Path
    }

    if ($Path.StartsWith('\\', [System.StringComparison]::Ordinal)) {
        return '\\?\UNC\{0}' -f $Path.TrimStart('\')
    }

    if ($Path -match '^[A-Za-z]:[\\/]' -or [System.IO.Path]::IsPathRooted($Path)) {
        return '\\?\{0}' -f $Path
    }

    $Path
}

function Get-ShareSurferLabScenarioTargetType {
    param(
        $Scenario
    )

    if ($Scenario.PSObject.Properties['TargetType'] -and [string]$Scenario.TargetType -ne '') {
        return [string]$Scenario.TargetType
    }

    'Directory'
}

function Get-ShareSurferLabScenarioAccessType {
    param(
        $Scenario
    )

    if ($Scenario.PSObject.Properties['AccessControlType'] -and [string]$Scenario.AccessControlType -ne '') {
        return [string]$Scenario.AccessControlType
    }

    'Allow'
}

function Get-ShareSurferLabScenarioOwnerIdentity {
    param(
        $Scenario
    )

    if ($Scenario.PSObject.Properties['OwnerIdentity'] -and [string]$Scenario.OwnerIdentity -ne '') {
        return [string]$Scenario.OwnerIdentity
    }

    ''
}

function New-ShareSurferLabFileContent {
    param(
        [string] $Tag = 'Fixture',
        [int64] $SizeBytes = 512
    )

    $prefix = 'ShareSurfer synthetic file fixture: {0}. ' -f $Tag
    if ($SizeBytes -le $prefix.Length) {
        return $prefix.Substring(0, [int]$SizeBytes)
    }

    $remaining = [int]($SizeBytes - $prefix.Length)
    $prefix + ('x' * $remaining)
}

function Assert-ShareSurferLabSmbSharePath {
    param(
        [Parameter(Mandatory = $true)]
        [string] $ShareName,

        [Parameter(Mandatory = $true)]
        $ExistingShare,

        [Parameter(Mandatory = $true)]
        [string] $PlannedPath
    )

    $existingPath = ''
    if ($ExistingShare.PSObject.Properties['Path']) {
        $existingPath = [string]$ExistingShare.Path
    }

    $normalizedExistingPath = ConvertTo-ShareSurferLabComparablePath -Path $existingPath
    $normalizedPlannedPath = ConvertTo-ShareSurferLabComparablePath -Path $PlannedPath
    if ($normalizedExistingPath -eq $normalizedPlannedPath) {
        return
    }

    throw ("ShareSurfer lab SMB share '{0}' already exists at '{1}', but the lab plan expects '{2}'. Rename or remove the conflicting share before creating the lab fixture." -f $ShareName, $existingPath, $PlannedPath)
}

function ConvertTo-ShareSurferLabComparablePath {
    param(
        [string] $Path = ''
    )

    ([string]$Path).Trim().TrimEnd('\', '/').ToUpperInvariant()
}
