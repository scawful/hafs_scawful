param(
    [Parameter(Mandatory = $true)][string]$Profile,
    [string]$ProfilePath,
    [string]$PluginRoot = $env:HAFS_WINDOWS_PLUGIN_DIR,
    [string]$ConfigPath,
    [string]$ExePath
)

if (-not $PluginRoot) { $PluginRoot = "C:/hafs_scawful" }

if (-not $ProfilePath) {
    $ProfilePath = Join-Path $PluginRoot "config/fancontrol/$Profile.json"
}

if (-not (Test-Path $ProfilePath)) {
    Write-Error "Profile not found: $ProfilePath"
    exit 1
}

if (-not $ConfigPath) {
    $configCandidates = @(
        Join-Path $env:APPDATA "FanControl\\FanControl.json",
        Join-Path $env:LOCALAPPDATA "FanControl\\FanControl.json",
        "C:/ProgramData/FanControl/FanControl.json"
    )
    $ConfigPath = $configCandidates | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
    if (-not $ConfigPath) {
        $ConfigPath = Join-Path $env:APPDATA "FanControl\\FanControl.json"
    }
}

$configDir = Split-Path -Parent $ConfigPath
New-Item -ItemType Directory -Force -Path $configDir | Out-Null

Copy-Item -Path $ProfilePath -Destination $ConfigPath -Force

$exeCandidates = @(
    (Get-Command FanControl -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source),
    "$env:LOCALAPPDATA\\Programs\\FanControl\\FanControl.exe",
    "$env:ProgramFiles\\FanControl\\FanControl.exe",
    "$env:ProgramFiles(x86)\\FanControl\\FanControl.exe"
) | Where-Object { $_ -and (Test-Path $_) }

if (-not $ExePath) {
    $ExePath = $exeCandidates | Select-Object -First 1
}

Get-Process -Name FanControl -ErrorAction SilentlyContinue | Stop-Process -Force

if ($ExePath) {
    Start-Process -FilePath $ExePath -WorkingDirectory (Split-Path -Parent $ExePath) | Out-Null
    Write-Output "FanControl restarted with profile: $Profile"
} else {
    Write-Output "FanControl config updated, but executable not found on PATH."
}
