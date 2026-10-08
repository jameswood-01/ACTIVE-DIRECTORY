<#
.SYNOPSIS
    Bulk-creates Active Directory user accounts for lab/testing environments.

.DESCRIPTION
    Create-BulkADUsers.ps1 generates a specified number of Active Directory
    user accounts, places them into a target Organizational Unit (OU), assigns
    them to an optional security group, sets an initial password, and enforces
    a password change at first logon. All actions are logged to a CSV file for
    auditing.

    User data (first/last names) is generated from built-in name pools, or you
    can supply your own CSV of names via -NameListPath.

.PARAMETER UserCount
    Number of user accounts to create. Default: 1000

.PARAMETER OU
    Distinguished Name of the target Organizational Unit.
    Example: "OU=Employees,DC=lab,DC=local"

.PARAMETER Group
    (Optional) Name of an existing AD security group to add all created users to.

.PARAMETER DefaultPassword
    Initial password assigned to every account. Default: "ChangeMe!2025"
    (Users are required to change this at first logon.)

.PARAMETER NameListPath
    (Optional) Path to a CSV file with "FirstName,LastName" columns. If omitted,
    names are generated from internal sample pools.

.PARAMETER LogPath
    Path to write the CSV log of created accounts. Default: ".\ADUserCreation_Log.csv"

.EXAMPLE
    .\Create-BulkADUsers.ps1 -UserCount 1000 -OU "OU=Employees,DC=lab,DC=local"

.EXAMPLE
    .\Create-BulkADUsers.ps1 -UserCount 500 -OU "OU=Staff,DC=corp,DC=local" -Group "AllStaff" -NameListPath ".\names.csv"

.NOTES
    Requires: RSAT / ActiveDirectory PowerShell module, run on a domain-joined
    machine (or the DC itself) with rights to create users in the target OU.
    Author: Woody
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $false)]
    [int]$UserCount = 1000,

    [Parameter(Mandatory = $true)]
    [string]$OU,

    [Parameter(Mandatory = $false)]
    [string]$Group,

    [Parameter(Mandatory = $false)]
    [string]$DefaultPassword = "ChangeMe!2025",

    [Parameter(Mandatory = $false)]
    [string]$NameListPath,

    [Parameter(Mandatory = $false)]
    [string]$LogPath = ".\ADUserCreation_Log.csv"
)

Import-Module ActiveDirectory -ErrorAction Stop

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
    if (-not (Test-Path $NameListPath)) {
        throw "NameListPath '$NameListPath' not found."
    }
    $UsersToCreate = Import-Csv -Path $NameListPath
    if ($UsersToCreate.Count -lt $UserCount) {
        Write-Warning "Name list contains fewer entries ($($UsersToCreate.Count)) than requested UserCount ($UserCount). Creating $($UsersToCreate.Count) users instead."
        $UserCount = $UsersToCreate.Count
    }
}
else {
    for ($i = 1; $i -le $UserCount; $i++) {
        $first = Get-Random -InputObject $FirstNames
        $last  = Get-Random -InputObject $LastNames
        $UsersToCreate += [PSCustomObject]@{
            FirstName = $first
            LastName  = $last
        }
    }
}

# ---------------------------------------------------------------------------
# Verify target OU exists
# ---------------------------------------------------------------------------
try {
    Get-ADOrganizationalUnit -Identity $OU -ErrorAction Stop | Out-Null
}
catch {
    throw "Target OU '$OU' could not be found. Verify the Distinguished Name and try again."
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
# Create users
# ---------------------------------------------------------------------------
$SecurePassword = ConvertTo-SecureString $DefaultPassword -AsPlainText -Force
$Results = @()
$UsedSamAccountNames = @{}
$counter = 0

foreach ($user in $UsersToCreate[0..($UserCount - 1)]) {
    $counter++
    $first = $user.FirstName
    $last  = $user.LastName

    # Build a unique sAMAccountName (handles duplicate name collisions)
    $baseSam = ("{0}.{1}" -f $first, $last).ToLower() -replace '[^a-z0-9.]', ''
    $sam = $baseSam
    $suffix = 1
    while ($UsedSamAccountNames.ContainsKey($sam) -or (Get-ADUser -Filter "SamAccountName -eq '$sam'" -ErrorAction SilentlyContinue)) {
        $sam = "$baseSam$suffix"
        $suffix++
    }
    $UsedSamAccountNames[$sam] = $true

    $upn = "$sam@$((Get-ADDomain).DNSRoot)"
    $displayName = "$first $last"
    $status = "Success"
    $errorMsg = ""

    if ($PSCmdlet.ShouldProcess($sam, "Create AD User")) {
        try {
            New-ADUser `
                -Name              $displayName `
                -GivenName         $first `
                -Surname           $last `
                -SamAccountName    $sam `
                -UserPrincipalName $upn `
                -Path              $OU `
                -AccountPassword   $SecurePassword `
                -ChangePasswordAtLogon $true `
                -Enabled           $true `
                -ErrorAction       Stop

            if ($Group) {
                Add-ADGroupMember -Identity $Group -Members $sam -ErrorAction Stop
            }
        }
        catch {
            $status = "Failed"
            $errorMsg = $_.Exception.Message
        }
    }

    $Results += [PSCustomObject]@{
        Number          = $counter
        DisplayName     = $displayName
        SamAccountName  = $sam
        UPN             = $upn
        OU              = $OU
        Group           = $Group
        Status          = $status
        Error           = $errorMsg
        Timestamp       = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    }

    if ($counter % 50 -eq 0) {
        Write-Host "Processed $counter of $UserCount users..." -ForegroundColor Cyan
    }
}

# ---------------------------------------------------------------------------
# Export log and summary
# ---------------------------------------------------------------------------
$Results | Export-Csv -Path $LogPath -NoTypeInformation -Encoding UTF8

$successCount = ($Results | Where-Object { $_.Status -eq "Success" }).Count
$failCount    = ($Results | Where-Object { $_.Status -eq "Failed" }).Count

Write-Host "`n===== AD Bulk User Creation Complete =====" -ForegroundColor Green
Write-Host "Total requested : $UserCount"
Write-Host "Succeeded       : $successCount" -ForegroundColor Green
Write-Host "Failed          : $failCount" -ForegroundColor $(if ($failCount -gt 0) { "Red" } else { "Green" })
Write-Host "Log file        : $LogPath"
