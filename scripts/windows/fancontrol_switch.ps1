param(
    [Parameter(Mandatory = $true)][string]$Profile,
    [string]$ProfilePath,
    [string]$PluginRoot = $env:HAFS_WINDOWS_PLUGIN_DIR,
    [string]$ConfigPath,
    [string]$ExePath
)

if (-not $PluginRoot) { $PluginRoot = "C:/hafs_scawful" }

$exeCandidates = @(
    (Get-Command FanControl -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source),
    "$env:LOCALAPPDATA\\Programs\\FanControl\\FanControl.exe",
    "$env:ProgramFiles\\FanControl\\FanControl.exe",
    "$env:ProgramFiles(x86)\\FanControl\\FanControl.exe"
) | Where-Object { $_ -and (Test-Path $_) }

if (-not $ExePath) {
    $ExePath = $exeCandidates | Select-Object -First 1
}

if (-not $ProfilePath) {
    $ProfilePath = Join-Path $PluginRoot "config/fancontrol/$Profile.json"
}

if (-not (Test-Path $ProfilePath)) {
    Write-Error "Profile not found: $ProfilePath"
    exit 1
}

$portableDir = $null
if ($ConfigPath -and (Test-Path $ConfigPath -PathType Container)) {
    $portableDir = $ConfigPath
    $ConfigPath = $null
}

if (-not $ConfigPath) {
    $portableCandidates = @()
    if ($ExePath) {
        $portableCandidates += Join-Path (Split-Path -Parent $ExePath) "Configurations"
    }
    $portableCandidates += @(
        "C:/Program Files/FanControl/Configurations",
        "C:/Program Files (x86)/FanControl/Configurations"
    )
    $portableDir = $portableCandidates | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
}

if ($portableDir) {
    $destPath = Join-Path $portableDir "$Profile.json"
    Copy-Item -Path $ProfilePath -Destination $destPath -Force
    $cachePath = Join-Path $portableDir "CACHE"
    if (Test-Path $cachePath) {
        $cache = Get-Content -Raw $cachePath | ConvertFrom-Json
    } else {
        $cache = [pscustomobject]@{}
    }
    $cache.CurrentConfigFileName = "$Profile.json"
    $cache | ConvertTo-Json -Depth 10 | Set-Content -Path $cachePath -Encoding UTF8
} else {
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
}

Get-Process -Name FanControl -ErrorAction SilentlyContinue | Stop-Process -Force

if ($ExePath) {
    Start-Process -FilePath $ExePath -WorkingDirectory (Split-Path -Parent $ExePath) | Out-Null
    Write-Output "FanControl restarted with profile: $Profile"
} else {
    Write-Output "FanControl config updated, but executable not found on PATH."
}
