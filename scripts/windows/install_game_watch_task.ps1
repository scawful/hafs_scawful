param(
    [string]$TaskName = "hafs-game-watch",
    [string]$ProcessNames = $env:HAFS_GAME_PROCESS_NAMES,
    [string]$Mode = "both",
    [switch]$ApplyGpuLimits,
    [int]$GpuPower = 150,
    [switch]$ApplyEnergyMode,
    [string]$EnergyModeGame = "gaming",
    [string]$EnergyModeTraining = "training",
    [string]$EnergyModeIdle = "balanced",
    [string]$PluginRoot = $env:HAFS_WINDOWS_PLUGIN_DIR
)

if (-not $PluginRoot) { $PluginRoot = "C:/hafs_scawful" }
if (-not $ProcessNames) {
    Write-Error "ProcessNames not set. Provide -ProcessNames or set HAFS_GAME_PROCESS_NAMES."
    exit 1
}

$procList = $ProcessNames -split "[;,]" | ForEach-Object { $_.Trim() } | Where-Object { $_ }
if (-not $procList) {
    Write-Error "ProcessNames resolved to an empty list."
    exit 1
}

$scriptPath = Join-Path $PluginRoot "scripts/windows/watch_game_mode.ps1"
if (-not (Test-Path $scriptPath)) {
    Write-Error "watch_game_mode.ps1 not found at $scriptPath"
    exit 1
}

$procArgs = ($procList | ForEach-Object { "'$_'" }) -join ","
$arguments = "-NoProfile -NoLogo -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$scriptPath`" -ProcessNames $procArgs -Mode $Mode"
if ($ApplyGpuLimits) {
    $arguments += " -ApplyGpuLimits -GpuPower $GpuPower"
}
if ($ApplyEnergyMode) {
    $arguments += " -ApplyEnergyMode -EnergyModeGame $EnergyModeGame -EnergyModeTraining $EnergyModeTraining -EnergyModeIdle $EnergyModeIdle"
}

$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument $arguments
$trigger = New-ScheduledTaskTrigger -AtLogOn
$userId = (& whoami 2>$null)
if (-not $userId) {
    $domain = if ($env:UserDomain) { $env:UserDomain } else { $env:COMPUTERNAME }
    $userId = if ($domain) { "$domain\\$env:UserName" } else { $env:UserName }
}
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable

if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
}

$registered = $false
try {
    $principal = New-ScheduledTaskPrincipal -UserId $userId -LogonType Interactive -RunLevel Highest
    Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Description "hAFS game watch (pause/throttle training)" -ErrorAction Stop | Out-Null
    $registered = $true
} catch {
    $principal = New-ScheduledTaskPrincipal -UserId $userId -LogonType Interactive -RunLevel Limited
    Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Description "hAFS game watch (pause/throttle training)" -ErrorAction Stop | Out-Null
    $registered = $true
    Write-Output "Registered with limited run level."
}

if (-not $registered) {
    Write-Error "Failed to register task."
    exit 1
}

try {
    Start-ScheduledTask -TaskName $TaskName -ErrorAction Stop | Out-Null
    Write-Output "Installed task: $TaskName"
} catch {
    Write-Output "Installed task: $TaskName (failed to start: $($_.Exception.Message))"
}
