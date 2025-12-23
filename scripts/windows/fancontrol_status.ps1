param(
    [string]$PluginRoot = $env:HAFS_WINDOWS_PLUGIN_DIR
)

if (-not $PluginRoot) { $PluginRoot = "C:/hafs_scawful" }

$configCandidates = @(
    (Join-Path $env:APPDATA "FanControl\\FanControl.json"),
    (Join-Path $env:LOCALAPPDATA "FanControl\\FanControl.json"),
    "C:/ProgramData/FanControl/FanControl.json"
)
$configPath = $configCandidates | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
$portableCandidates = @(
    "C:/Program Files/FanControl/Configurations",
    "C:/Program Files (x86)/FanControl/Configurations"
)
$portableDir = $portableCandidates | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1

$proc = Get-Process -Name FanControl -ErrorAction SilentlyContinue
if ($proc) {
    Write-Output "FanControl: running (PID $($proc.Id))"
} else {
    Write-Output "FanControl: not running"
}

if ($portableDir) {
    Write-Output "Config: portable ($portableDir)"
    $cachePath = Join-Path $portableDir "CACHE"
    if (Test-Path $cachePath) {
        try {
            $cache = Get-Content -Raw $cachePath | ConvertFrom-Json
            if ($cache.CurrentConfigFileName) {
                Write-Output "Active profile: $($cache.CurrentConfigFileName)"
            }
        } catch {
            Write-Output "Active profile: unknown (cache unreadable)"
        }
    }
} elseif ($configPath) {
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
