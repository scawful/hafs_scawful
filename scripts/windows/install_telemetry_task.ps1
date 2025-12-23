param(
    [string]$TaskName = "hafs-telemetry-logger",
    [int]$IntervalSec = 10,
    [string]$OutputDir = "D:/hafs_training/logs/telemetry",
    [string]$PluginRoot = $env:HAFS_WINDOWS_PLUGIN_DIR
)

if (-not $PluginRoot) { $PluginRoot = "C:/hafs_scawful" }

$scriptPath = Join-Path $PluginRoot "scripts/windows/telemetry_logger.ps1"
if (-not (Test-Path $scriptPath)) {
    Write-Error "telemetry_logger.ps1 not found at $scriptPath"
    exit 1
}

$arguments = "-NoProfile -NoLogo -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$scriptPath`" -IntervalSec $IntervalSec -OutputDir `"$OutputDir`""
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument $arguments
$trigger = New-ScheduledTaskTrigger -AtStartup
$userId = (& whoami 2>$null)
if (-not $userId) {
    $domain = if ($env:UserDomain) { $env:UserDomain } else { $env:COMPUTERNAME }
    $userId = if ($domain) { "$domain\\$env:UserName" } else { $env:UserName }
}
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable

if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
}

try {
    $principal = New-ScheduledTaskPrincipal -UserId $userId -LogonType Interactive -RunLevel Highest
    Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Description "hAFS telemetry logger" -ErrorAction Stop | Out-Null
} catch {
    $principal = New-ScheduledTaskPrincipal -UserId $userId -LogonType Interactive -RunLevel Limited
    Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Description "hAFS telemetry logger" -ErrorAction Stop | Out-Null
    Write-Output "Registered with limited run level."
}

try {
    Start-ScheduledTask -TaskName $TaskName -ErrorAction Stop | Out-Null
    Write-Output "Installed task: $TaskName"
} catch {
    Write-Output "Installed task: $TaskName (failed to start: $($_.Exception.Message))"
}
