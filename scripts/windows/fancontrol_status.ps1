param(
    [string]$PluginRoot = $env:HAFS_WINDOWS_PLUGIN_DIR
)

if (-not $PluginRoot) { $PluginRoot = "C:/hafs_scawful" }

$configCandidates = @(
    Join-Path $env:APPDATA "FanControl\\FanControl.json",
    Join-Path $env:LOCALAPPDATA "FanControl\\FanControl.json",
    "C:/ProgramData/FanControl/FanControl.json"
)
$configPath = $configCandidates | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1

$proc = Get-Process -Name FanControl -ErrorAction SilentlyContinue
if ($proc) {
    Write-Output "FanControl: running (PID $($proc.Id))"
} else {
    Write-Output "FanControl: not running"
}

if ($configPath) {
    Write-Output "Config: $configPath"
} else {
    Write-Output "Config: not found (expected under %APPDATA% or %LOCALAPPDATA%)"
}

$profileDir = Join-Path $PluginRoot "config/fancontrol"
if (Test-Path $profileDir) {
    Write-Output "Profiles: $profileDir"
    Get-ChildItem -Path $profileDir -Filter "*.json" -ErrorAction SilentlyContinue |
        Select-Object Name,LastWriteTime | Format-Table -AutoSize
} else {
    Write-Output "Profiles: $profileDir (missing)"
}
