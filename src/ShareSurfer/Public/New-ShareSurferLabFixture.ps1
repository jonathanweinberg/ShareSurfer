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
            $targetType = Get-ShareSurferLabScenarioTargetType -Scenario $scenario
            if ($targetType -eq 'File') {
                $parentPath = Split-Path -Parent $scenarioPath
                New-Item -ItemType Directory -Path $parentPath -Force | Out-Null
                Set-Content -Path $scenarioPath -Value ('ShareSurfer file fixture: {0}' -f $scenario.Name) -Encoding UTF8
            }
            else {
                New-Item -ItemType Directory -Path $scenarioPath -Force | Out-Null
                Set-Content -Path (Join-Path $scenarioPath 'sample.txt') -Value ('ShareSurfer fixture: {0}' -f $scenario.Name) -Encoding UTF8
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
                $acl = Get-Acl -LiteralPath $aclTargetPath -ErrorAction Stop
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
                Set-Acl -LiteralPath $aclTargetPath -AclObject $acl -ErrorAction Stop
            }
            catch {
                Write-Warning ("Unable to apply ACL scenario {0} to {1}: {2}" -f $scenario.Name, $scenarioPath, $_.Exception.Message)
            }
        }
    }

    $plan
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
