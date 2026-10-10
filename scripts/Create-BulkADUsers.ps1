<#
.SYNOPSIS
    Bulk-creates Active Directory user accounts for lab/testing environments.

.DESCRIPTION
    Create-BulkADUsers.ps1 generates a specified number of Active Directory
    user accounts, places them into a target Organizational Unit (OU) or
    container, assigns them to an optional security group, sets an initial
    password, and enforces a password change at first logon. All actions are
    logged to a CSV file for auditing.

    User data (first/last names) is generated from built-in name pools, or you
    can supply your own CSV of names via -NameListPath.

    Usernames (sAMAccountName) are built as "first.last", shortened to the AD
    limit of 20 characters, and made unique with a numeric suffix. If two users
    share a display name, the account's object name (CN) gets the username
    appended, e.g. "James Smith (james.smith1)", so it stays unique in the OU.

.PARAMETER UserCount
    Number of user accounts to create (1-100000). Default: 1000

.PARAMETER OU
    Distinguished Name of the target Organizational Unit or container.
    Examples: "OU=Employees,DC=lab,DC=local" or "CN=Users,DC=lab,DC=local"

.PARAMETER Group
    (Optional) Name of an existing AD security group to add all created users to.

.PARAMETER DefaultPassword
    (Optional) Initial password assigned to every account, as a SecureString.
    If omitted, you are prompted for it securely when the script runs.
    Users are required to change it at first logon.

.PARAMETER NameListPath
    (Optional) Path to a CSV file with "FirstName,LastName" columns. If omitted,
    names are generated from internal sample pools.

.PARAMETER LogPath
    Path to write the CSV log of created accounts. Default: ".\ADUserCreation_Log.csv"

.EXAMPLE
    .\Create-BulkADUsers.ps1 -UserCount 1000 -OU "OU=Employees,DC=lab,DC=local"

.EXAMPLE
    .\Create-BulkADUsers.ps1 -UserCount 500 -OU "OU=Staff,DC=corp,DC=local" -Group "AllStaff" -NameListPath ".\names.csv"

.EXAMPLE
    .\Create-BulkADUsers.ps1 -UserCount 1000 -OU "OU=Employees,DC=lab,DC=local" -WhatIf
    Dry run: nothing is created, but the log is still written with Status "WhatIf".

.NOTES
    Requires: RSAT / ActiveDirectory PowerShell module, run on a domain-joined
    machine (or the DC itself) with rights to create users in the target OU.
    Author: Woody
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 100000)]
    [int]$UserCount = 1000,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$OU,

    [Parameter(Mandatory = $false)]
    [string]$Group,

    [Parameter(Mandatory = $false)]
    [System.Security.SecureString]$DefaultPassword,

    [Parameter(Mandatory = $false)]
    [string]$NameListPath,

    [Parameter(Mandatory = $false)]
    [string]$LogPath = ".\ADUserCreation_Log.csv"
)

Import-Module ActiveDirectory -ErrorAction Stop

# AD limit for sAMAccountName (pre-Windows 2000 logon name)
$MaxSamLength = 20

# ---------------------------------------------------------------------------
# Name pools (used only if -NameListPath is not supplied)
# ---------------------------------------------------------------------------
$FirstNames = @(
    "James","Mary","John","Patricia","Robert","Jennifer","Michael","Linda",
    "William","Elizabeth","David","Barbara","Richard","Susan","Joseph","Jessica",
    "Thomas","Sarah","Charles","Karen","Christopher","Nancy","Daniel","Lisa",
    "Matthew","Betty","Anthony","Margaret","Mark","Sandra","Donald","Ashley",
    "Steven","Kimberly","Paul","Emily","Andrew","Donna","Joshua","Michelle"
)

$LastNames = @(
    "Smith","Johnson","Williams","Brown","Jones","Garcia","Miller","Davis",
    "Rodriguez","Martinez","Hernandez","Lopez","Gonzalez","Wilson","Anderson",
    "Thomas","Taylor","Moore","Jackson","Martin","Lee","Perez","Thompson",
    "White","Harris","Sanchez","Clark","Ramirez","Lewis","Robinson","Walker",
    "Young","Allen","King","Wright","Scott","Torres","Nguyen","Hill","Flores"
)

# ---------------------------------------------------------------------------
# Build the list of users to create
# ---------------------------------------------------------------------------
$UsersToCreate = @()

if ($NameListPath) {
    if (-not (Test-Path -Path $NameListPath -PathType Leaf)) {
        throw "NameListPath '$NameListPath' not found."
    }
    $UsersToCreate = @(Import-Csv -Path $NameListPath |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_.FirstName) -and -not [string]::IsNullOrWhiteSpace($_.LastName) })

    if ($UsersToCreate.Count -eq 0) {
        throw "NameListPath '$NameListPath' has no usable rows. It needs 'FirstName' and 'LastName' columns with values."
    }
    if ($UsersToCreate.Count -lt $UserCount) {
        Write-Warning "Name list contains fewer usable entries ($($UsersToCreate.Count)) than requested UserCount ($UserCount). Creating $($UsersToCreate.Count) users instead."
        $UserCount = $UsersToCreate.Count
    }
}
else {
    for ($i = 1; $i -le $UserCount; $i++) {
        $UsersToCreate += [PSCustomObject]@{
            FirstName = Get-Random -InputObject $FirstNames
            LastName  = Get-Random -InputObject $LastNames
        }
    }
}

# ---------------------------------------------------------------------------
# Verify target OU / container exists
# ---------------------------------------------------------------------------
try {
    $target = Get-ADObject -Identity $OU -ErrorAction Stop
}
catch {
    throw "Target '$OU' could not be found. Verify the Distinguished Name and try again."
}
if ($target.ObjectClass -notin @("organizationalUnit", "container", "builtinDomain")) {
    throw "Target '$OU' is a '$($target.ObjectClass)', not an OU or container."
}

# ---------------------------------------------------------------------------
# Verify group exists (if specified)
# ---------------------------------------------------------------------------
if ($Group) {
    try {
        Get-ADGroup -Identity $Group -ErrorAction Stop | Out-Null
    }
    catch {
        throw "Specified group '$Group' could not be found."
    }
}

# ---------------------------------------------------------------------------
# Initial password (prompted securely; never stored in the script)
# ---------------------------------------------------------------------------
if (-not $DefaultPassword -and -not $WhatIfPreference) {
    $DefaultPassword = Read-Host -Prompt "Enter the initial password for the new accounts" -AsSecureString
    if (-not $DefaultPassword -or $DefaultPassword.Length -eq 0) {
        throw "An initial password is required."
    }
}

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
$DomainDns = (Get-ADDomain -ErrorAction Stop).DNSRoot

function Get-UniqueSamAccountName {
    param([string]$First, [string]$Last, [hashtable]$Used)

    $base = ("{0}.{1}" -f $First, $Last).ToLower() -replace '[^a-z0-9.]', ''
    $base = ($base -replace '\.{2,}', '.').Trim('.')
    if (-not $base) { return $null }

    $suffix = 0
    while ($true) {
        $tail = if ($suffix -gt 0) { "$suffix" } else { "" }
        $head = $base.Substring(0, [Math]::Min($base.Length, $MaxSamLength - $tail.Length)).TrimEnd('.')
        $sam  = "$head$tail"
        if (-not $Used.ContainsKey($sam) -and
            -not (Get-ADUser -Filter "SamAccountName -eq '$sam'" -ErrorAction SilentlyContinue)) {
            return $sam
        }
        $suffix++
    }
}

function Test-NameInUse {
    param([string]$Name, [hashtable]$Used)

    if ($Used.ContainsKey($Name)) { return $true }
    $escaped = $Name -replace "'", "''"
    return [bool](Get-ADObject -Filter "Name -eq '$escaped'" -SearchBase $OU -SearchScope OneLevel -ErrorAction SilentlyContinue)
}

# ---------------------------------------------------------------------------
# Create users
# ---------------------------------------------------------------------------
$Results = New-Object System.Collections.Generic.List[object]
$UsedSamAccountNames = @{}
$UsedObjectNames = @{}
$counter = 0

foreach ($user in $UsersToCreate[0..($UserCount - 1)]) {
    $counter++
    $first = $user.FirstName.Trim()
    $last  = $user.LastName.Trim()
    $displayName = "$first $last"
    $status   = "Success"
    $errorMsg = ""

    $sam = Get-UniqueSamAccountName -First $first -Last $last -Used $UsedSamAccountNames
    if (-not $sam) {
        $upn = ""
        $status = "Failed"
        $errorMsg = "Could not build a username from '$displayName' (no usable characters)."
    }
    else {
        $UsedSamAccountNames[$sam] = $true
        $upn = "$sam@$DomainDns"

        # The object name (CN) must be unique within the OU
        $objectName = $displayName
        if (Test-NameInUse -Name $objectName -Used $UsedObjectNames) {
            $objectName = "$displayName ($sam)"
        }
        $UsedObjectNames[$objectName] = $true

        if ($PSCmdlet.ShouldProcess($sam, "Create AD User")) {
            try {
                New-ADUser `
                    -Name                  $objectName `
                    -DisplayName           $displayName `
                    -GivenName             $first `
                    -Surname               $last `
                    -SamAccountName        $sam `
                    -UserPrincipalName     $upn `
                    -Path                  $OU `
                    -AccountPassword       $DefaultPassword `
                    -ChangePasswordAtLogon $true `
                    -Enabled               $true `
                    -ErrorAction           Stop

                if ($Group) {
                    Add-ADGroupMember -Identity $Group -Members $sam -ErrorAction Stop
                }
            }
            catch {
                $status = "Failed"
                $errorMsg = $_.Exception.Message
            }
        }
        else {
            $status = "WhatIf"
        }
    }

    $Results.Add([PSCustomObject]@{
        Number          = $counter
        DisplayName     = $displayName
        SamAccountName  = $sam
        UPN             = $upn
        OU              = $OU
        Group           = $Group
        Status          = $status
        Error           = $errorMsg
        Timestamp       = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    })

    if ($counter % 50 -eq 0) {
        Write-Host "Processed $counter of $UserCount users..." -ForegroundColor Cyan
    }
}

# ---------------------------------------------------------------------------
# Export log and summary (the log is written even on a -WhatIf dry run)
# ---------------------------------------------------------------------------
$Results | Export-Csv -Path $LogPath -NoTypeInformation -Encoding UTF8 -WhatIf:$false

$successCount = @($Results | Where-Object { $_.Status -eq "Success" }).Count
$whatIfCount  = @($Results | Where-Object { $_.Status -eq "WhatIf" }).Count
$failCount    = @($Results | Where-Object { $_.Status -eq "Failed" }).Count

Write-Host "`n===== AD Bulk User Creation Complete =====" -ForegroundColor Green
Write-Host "Total requested : $UserCount"
if ($whatIfCount -gt 0) {
    Write-Host "WhatIf (dry run): $whatIfCount" -ForegroundColor Yellow
}
Write-Host "Succeeded       : $successCount" -ForegroundColor Green
Write-Host "Failed          : $failCount" -ForegroundColor $(if ($failCount -gt 0) { "Red" } else { "Green" })
Write-Host "Log file        : $LogPath"
