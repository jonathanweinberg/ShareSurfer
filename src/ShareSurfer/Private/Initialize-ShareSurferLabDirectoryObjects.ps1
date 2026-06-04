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
    if ($null -eq (Get-ADOrganizationalUnit -LDAPFilter "(distinguishedName=$ouDn)" -ErrorAction SilentlyContinue)) {
        New-ADOrganizationalUnit -Name $ouName -Path $domain.DistinguishedName -ProtectedFromAccidentalDeletion:$false | Out-Null
    }

    $defaultPassword = ConvertTo-SecureString 'ShareSurfer-Lab-Passw0rd!' -AsPlainText -Force
    foreach ($user in $Plan.Users) {
        $existingUser = Get-ADUser -Filter ("SamAccountName -eq '{0}'" -f $user.SamAccountName) -ErrorAction SilentlyContinue
        $otherAttributes = @{
            employeeNumber = [string]$user.EmployeeNumber
        }
        $otherAttributes[$Plan.ObsAttribute] = [string]$user.PSObject.Properties[$Plan.ObsAttribute].Value

        if ($null -eq $existingUser) {
            New-ADUser -SamAccountName $user.SamAccountName -Name $user.DisplayName -DisplayName $user.DisplayName -UserPrincipalName $user.UserPrincipalName -Path $ouDn -Enabled $true -AccountPassword $defaultPassword -EmployeeID $user.EmployeeId -OtherAttributes $otherAttributes | Out-Null
        }
        else {
            Set-ADUser -Identity $existingUser -DisplayName $user.DisplayName -EmployeeID $user.EmployeeId -Replace $otherAttributes | Out-Null
        }
    }

    foreach ($user in $Plan.Users) {
        if ([string]$user.Manager -ne '') {
            $manager = Get-ADUser -Filter ("SamAccountName -eq '{0}'" -f $user.Manager) -ErrorAction SilentlyContinue
            if ($null -ne $manager) {
                Set-ADUser -Identity $user.SamAccountName -Manager $manager.DistinguishedName | Out-Null
            }
        }
    }

    foreach ($group in $Plan.Groups) {
        $existingGroup = Get-ADGroup -Filter ("SamAccountName -eq '{0}'" -f $group.Name) -ErrorAction SilentlyContinue
        if ($null -eq $existingGroup) {
            New-ADGroup -Name $group.Name -SamAccountName $group.Name -GroupScope Global -GroupCategory Security -Path $ouDn -Description $group.Description | Out-Null
        }
    }

    foreach ($group in $Plan.Groups) {
        foreach ($member in $group.Members) {
            Add-ADGroupMember -Identity $group.Name -Members $member -ErrorAction SilentlyContinue
        }
    }
}
