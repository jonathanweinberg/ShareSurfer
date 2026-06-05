function Initialize-ShareSurferLabDirectoryObjects {
    param(
        [Parameter(Mandatory = $true)]
        $Plan
    )

    $adModule = Get-Module -ListAvailable ActiveDirectory | Select-Object -First 1
    if ($null -eq $adModule) {
        Write-Verbose 'ActiveDirectory module was not detected. Directory object details are returned in the fixture plan.'
        return
    }

    Import-Module ActiveDirectory -ErrorAction Stop
    $domain = Get-ADDomain -ErrorAction Stop
    $ouName = 'ShareSurferLab'
    $ouDn = 'OU={0},{1}' -f $ouName, $domain.DistinguishedName
    if ($null -eq (Get-ADOrganizationalUnit -Identity $ouDn -ErrorAction SilentlyContinue)) {
        New-ADOrganizationalUnit -Name $ouName -Path $domain.DistinguishedName -ProtectedFromAccidentalDeletion:$false | Out-Null
    }

    $defaultPassword = ConvertTo-SecureString 'ShareSurfer-Lab-Passw0rd!' -AsPlainText -Force
    foreach ($user in $Plan.Users) {
        $samAccountName = [string]$user.SamAccountName
        $existingUser = Get-ShareSurferLabAdUser -SamAccountName $samAccountName -SearchBase $ouDn
        $otherAttributes = @{
            employeeNumber = [string]$user.EmployeeNumber
        }
        $otherAttributes[$Plan.ObsAttribute] = [string]$user.PSObject.Properties[$Plan.ObsAttribute].Value

        if ($null -eq $existingUser) {
            $conflictingUser = Get-ShareSurferLabAdUser -SamAccountName $samAccountName
            Assert-ShareSurferLabAdObjectNotOutsideOu -Object $conflictingUser -ObjectType 'user' -SamAccountName $samAccountName -OuDn $ouDn
            New-ADUser -SamAccountName $user.SamAccountName -Name $user.DisplayName -DisplayName $user.DisplayName -UserPrincipalName $user.UserPrincipalName -Path $ouDn -Enabled $true -AccountPassword $defaultPassword -EmployeeID $user.EmployeeId -OtherAttributes $otherAttributes | Out-Null
        }
        else {
            Set-ADUser -Identity $existingUser.DistinguishedName -DisplayName $user.DisplayName -EmployeeID $user.EmployeeId -Replace $otherAttributes | Out-Null
        }
    }

    foreach ($user in $Plan.Users) {
        if ([string]$user.Manager -ne '') {
            $managedUser = Get-ShareSurferLabAdUser -SamAccountName ([string]$user.SamAccountName) -SearchBase $ouDn
            $manager = Get-ShareSurferLabAdUser -SamAccountName ([string]$user.Manager) -SearchBase $ouDn
            if ($null -ne $managedUser -and $null -ne $manager) {
                Set-ADUser -Identity $managedUser.DistinguishedName -Manager $manager.DistinguishedName | Out-Null
            }
        }
    }

    foreach ($group in $Plan.Groups) {
        $samAccountName = [string]$group.Name
        $existingGroup = Get-ShareSurferLabAdGroup -SamAccountName $samAccountName -SearchBase $ouDn
        $groupAttributes = @{}
        if ($group.PSObject.Properties[$Plan.ObsAttribute]) {
            $groupAttributes[$Plan.ObsAttribute] = [string]$group.PSObject.Properties[$Plan.ObsAttribute].Value
        }
        if ($null -eq $existingGroup) {
            $conflictingGroup = Get-ShareSurferLabAdGroup -SamAccountName $samAccountName
            Assert-ShareSurferLabAdObjectNotOutsideOu -Object $conflictingGroup -ObjectType 'group' -SamAccountName $samAccountName -OuDn $ouDn
            New-ADGroup -Name $group.Name -SamAccountName $group.Name -GroupScope Global -GroupCategory Security -Path $ouDn -Description $group.Description -OtherAttributes $groupAttributes | Out-Null
        }
        elseif ($groupAttributes.Count -gt 0) {
            Set-ADGroup -Identity $existingGroup.DistinguishedName -Description $group.Description -Replace $groupAttributes | Out-Null
        }
    }

    foreach ($group in $Plan.Groups) {
        $labGroup = Get-ShareSurferLabAdGroup -SamAccountName ([string]$group.Name) -SearchBase $ouDn
        if ($null -eq $labGroup) {
            continue
        }
        foreach ($member in $group.Members) {
            $memberObject = Resolve-ShareSurferLabAdMember -SamAccountName ([string]$member) -SearchBase $ouDn
            if ($null -eq $memberObject) {
                Write-Warning ("Unable to resolve ShareSurfer lab group member {0} in {1}." -f $member, $ouDn)
                continue
            }
            Add-ADGroupMember -Identity $labGroup.DistinguishedName -Members $memberObject.DistinguishedName -ErrorAction SilentlyContinue
        }
    }
}

function Get-ShareSurferLabAdUser {
    param(
        [Parameter(Mandatory = $true)]
        [string] $SamAccountName,

        [string] $SearchBase = ''
    )

    $filter = "SamAccountName -eq '{0}'" -f (ConvertTo-ShareSurferLabAdFilterValue -Value $SamAccountName)
    if ([string]::IsNullOrWhiteSpace($SearchBase)) {
        return Get-ADUser -Filter $filter -ErrorAction SilentlyContinue
    }

    Get-ADUser -Filter $filter -SearchBase $SearchBase -ErrorAction SilentlyContinue
}

function Get-ShareSurferLabAdGroup {
    param(
        [Parameter(Mandatory = $true)]
        [string] $SamAccountName,

        [string] $SearchBase = ''
    )

    $filter = "SamAccountName -eq '{0}'" -f (ConvertTo-ShareSurferLabAdFilterValue -Value $SamAccountName)
    if ([string]::IsNullOrWhiteSpace($SearchBase)) {
        return Get-ADGroup -Filter $filter -ErrorAction SilentlyContinue
    }

    Get-ADGroup -Filter $filter -SearchBase $SearchBase -ErrorAction SilentlyContinue
}

function Resolve-ShareSurferLabAdMember {
    param(
        [Parameter(Mandatory = $true)]
        [string] $SamAccountName,

        [Parameter(Mandatory = $true)]
        [string] $SearchBase
    )

    $user = Get-ShareSurferLabAdUser -SamAccountName $SamAccountName -SearchBase $SearchBase
    if ($null -ne $user) {
        return $user
    }

    Get-ShareSurferLabAdGroup -SamAccountName $SamAccountName -SearchBase $SearchBase
}

function Assert-ShareSurferLabAdObjectNotOutsideOu {
    param(
        $Object,

        [Parameter(Mandatory = $true)]
        [string] $ObjectType,

        [Parameter(Mandatory = $true)]
        [string] $SamAccountName,

        [Parameter(Mandatory = $true)]
        [string] $OuDn
    )

    if ($null -eq $Object) {
        return
    }

    $objectDn = [string]$Object.DistinguishedName
    $expectedSuffix = ',{0}' -f $OuDn
    if ($objectDn.EndsWith($expectedSuffix, [System.StringComparison]::OrdinalIgnoreCase)) {
        return
    }

    throw ("ShareSurfer lab {0} '{1}' already exists outside the ShareSurferLab OU: {2}. Rename or remove the conflicting object before creating the lab fixture." -f $ObjectType, $SamAccountName, $objectDn)
}

function ConvertTo-ShareSurferLabAdFilterValue {
    param(
        [string] $Value = ''
    )

    $Value -replace "'", "''"
}
