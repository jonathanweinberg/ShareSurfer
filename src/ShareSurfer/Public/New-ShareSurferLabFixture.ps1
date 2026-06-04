function New-ShareSurferLabFixture {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)]
        [string] $RootPath,

        [string] $DomainNetBiosName = 'CONTOSO',
        [string] $ObsAttribute = 'extensionAttribute10',
        [switch] $OutputPlanOnly,
        [switch] $Force
    )

    $plan = New-ShareSurferLabPlan -RootPath $RootPath -DomainNetBiosName $DomainNetBiosName -ObsAttribute $ObsAttribute
    if ($OutputPlanOnly) {
        return $plan
    }

    if (-not (Test-ShareSurferIsWindows)) {
        throw 'New-ShareSurferLabFixture can only create live SMB/AD fixtures on Windows. Use -OutputPlanOnly on non-Windows systems.'
    }

    if ((Test-Path -LiteralPath $RootPath) -and -not $Force) {
        throw "Lab root already exists: $RootPath. Use -Force to reuse it."
    }

    if ($PSCmdlet.ShouldProcess($RootPath, 'Create ShareSurfer lab directories and Windows SMB shares')) {
        New-Item -ItemType Directory -Path $RootPath -Force | Out-Null
        foreach ($share in $plan.Shares) {
            New-Item -ItemType Directory -Path $share.LocalPath -Force | Out-Null
        }

        foreach ($scenario in $plan.AclScenarios) {
            $share = @($plan.Shares | Where-Object { $_.ShareName -eq $scenario.ShareName })[0]
            $scenarioPath = Join-Path $share.LocalPath $scenario.RelativePath
            New-Item -ItemType Directory -Path $scenarioPath -Force | Out-Null
            Set-Content -Path (Join-Path $scenarioPath 'sample.txt') -Value ('ShareSurfer fixture: {0}' -f $scenario.Name) -Encoding UTF8
        }

        Initialize-ShareSurferLabDirectoryObjects -Plan $plan

        $smbShareCommand = Get-Command New-SmbShare -ErrorAction SilentlyContinue
        if ($null -ne $smbShareCommand) {
            foreach ($share in $plan.Shares) {
                $existing = Get-SmbShare -Name $share.ShareName -ErrorAction SilentlyContinue
                if ($null -eq $existing) {
                    New-SmbShare -Name $share.ShareName -Path $share.LocalPath -Description $share.Description -FullAccess 'Administrators' | Out-Null
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
                $aclTargetPath = if ($scenario.IsInherited) { $share.LocalPath } else { $scenarioPath }
                $acl = Get-Acl -LiteralPath $aclTargetPath -ErrorAction Stop
                if ($scenario.Name -eq 'BrokenInheritance') {
                    $acl.SetAccessRuleProtection($true, $true)
                }
                $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
                    $scenario.Identity,
                    $scenario.Rights,
                    'ContainerInherit,ObjectInherit',
                    'None',
                    'Allow'
                )
                $acl.SetAccessRule($rule)
                Set-Acl -LiteralPath $aclTargetPath -AclObject $acl -ErrorAction Stop
            }
            catch {
                Write-Warning ("Unable to apply ACL scenario {0} to {1}: {2}" -f $scenario.Name, $scenarioPath, $_.Exception.Message)
            }
        }
    }

    $plan
}
