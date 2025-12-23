param(
    [switch]$Apply,
    [switch]$Revert,
    [int]$ActiveHoursStart = 8,
    [int]$ActiveHoursEnd = 23
)

function Test-IsAdmin {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}

function Set-RegDword {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][int]$Value
    )
    if (-not (Test-Path $Path)) {
        New-Item -Path $Path -Force | Out-Null
    }
    New-ItemProperty -Path $Path -Name $Name -PropertyType DWord -Value $Value -Force | Out-Null
}

function Remove-RegValue {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Name
    )
    if (Test-Path $Path) {
        Remove-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue
    }
}

if (-not $Apply -and -not $Revert) {
    $Apply = $true
}

if ($Apply -and $Revert) {
    Write-Error "Choose either -Apply or -Revert."
    exit 1
}

if ($ActiveHoursStart -lt 0 -or $ActiveHoursStart -gt 23 -or $ActiveHoursEnd -lt 0 -or $ActiveHoursEnd -gt 23) {
    Write-Error "Active hours must be between 0 and 23."
    exit 1
}

if ($ActiveHoursStart -ge $ActiveHoursEnd) {
    Write-Error "ActiveHoursStart must be less than ActiveHoursEnd."
    exit 1
}

$policyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
$uxPath = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings"

if (-not (Test-IsAdmin)) {
    Write-Output "Warning: not running as administrator. Policy changes may fail."
}

if ($Apply) {
    # Prevent auto reboot while a user is logged in and require user approval for updates.
    Set-RegDword -Path $policyPath -Name "NoAutoRebootWithLoggedOnUsers" -Value 1
    Set-RegDword -Path $policyPath -Name "AUOptions" -Value 2
    Set-RegDword -Path $policyPath -Name "AlwaysAutoRebootAtScheduledTime" -Value 0

    # Active hours to reduce update interruptions.
    Set-RegDword -Path $uxPath -Name "IsActiveHoursEnabled" -Value 1
    Set-RegDword -Path $uxPath -Name "ActiveHoursStart" -Value $ActiveHoursStart
    Set-RegDword -Path $uxPath -Name "ActiveHoursEnd" -Value $ActiveHoursEnd

    Write-Output "Windows Update hardening applied."
    Write-Output "Active hours: $ActiveHoursStart-$ActiveHoursEnd"
    Write-Output "AUOptions=Notify, NoAutoRebootWithLoggedOnUsers=1"
    exit 0
}

if ($Revert) {
    Remove-RegValue -Path $policyPath -Name "NoAutoRebootWithLoggedOnUsers"
    Remove-RegValue -Path $policyPath -Name "AUOptions"
    Remove-RegValue -Path $policyPath -Name "AlwaysAutoRebootAtScheduledTime"
    Remove-RegValue -Path $uxPath -Name "IsActiveHoursEnabled"
    Write-Output "Windows Update hardening reverted (policy values removed)."
    exit 0
}
