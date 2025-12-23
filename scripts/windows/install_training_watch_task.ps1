param(
    [string]$TaskName = "hafs-training-watch",
    [string]$ProcessNames = $env:HAFS_TRAINING_PROCESS_NAMES,
    [int]$PollSeconds = 15,
    [int]$MinSamples = 2,
    [string]$ModeActive = "training",
    [string]$ModeIdle = "balanced",
    [string]$PluginRoot = $env:HAFS_WINDOWS_PLUGIN_DIR
)

if (-not $PluginRoot) { $PluginRoot = "C:/hafs_scawful" }

$scriptPath = Join-Path $PluginRoot "scripts/windows/watch_training_mode.ps1"
if (-not (Test-Path $scriptPath)) {
    Write-Error "watch_training_mode.ps1 not found at $scriptPath"
    exit 1
}

$arguments = "-NoProfile -NoLogo -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$scriptPath`" -PollSeconds $PollSeconds -MinSamples $MinSamples -ModeActive $ModeActive -ModeIdle $ModeIdle"
if ($ProcessNames) {
    $procList = $ProcessNames -split "[;,]" | ForEach-Object { $_.Trim() } | Where-Object { $_ }
    if ($procList) {
        $procArgs = ($procList | ForEach-Object { "'$_'" }) -join ","
        $arguments += " -ProcessNames $procArgs"
    }
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

try {
    $principal = New-ScheduledTaskPrincipal -UserId $userId -LogonType Interactive -RunLevel Highest
    Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Description "hAFS training watch (auto energy mode)" -ErrorAction Stop | Out-Null
} catch {
    $principal = New-ScheduledTaskPrincipal -UserId $userId -LogonType Interactive -RunLevel Limited
    Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Description "hAFS training watch (auto energy mode)" -ErrorAction Stop | Out-Null
    Write-Output "Registered with limited run level."
}

try {
    Start-ScheduledTask -TaskName $TaskName -ErrorAction Stop | Out-Null
    Write-Output "Installed task: $TaskName"
} catch {
    Write-Output "Installed task: $TaskName (failed to start: $($_.Exception.Message))"
}
