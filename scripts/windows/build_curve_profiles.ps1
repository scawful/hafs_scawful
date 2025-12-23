param(
    [string]$BasePath = "C:/Program Files (x86)/FanControl/Configurations/curve.json",
    [string]$PluginRoot = $env:HAFS_WINDOWS_PLUGIN_DIR,
    [switch]$EnableAioPump
)

if (-not $PluginRoot) { $PluginRoot = "C:/hafs_scawful" }

if (-not (Test-Path $BasePath)) {
    throw "Base config not found: $BasePath"
}

function Clone-Object {
    param([object]$InputObject)
    return ($InputObject | ConvertTo-Json -Depth 30 | ConvertFrom-Json)
}

$profiles = @{
    "curve-quiet"       = @{ Idle = 35; Min = 35; Max = 70; Load = 75; Step = 3; Deadband = 4; Response = 3 }
    "curve-balanced"    = @{ Idle = 35; Min = 45; Max = 85; Load = 72; Step = 2; Deadband = 3; Response = 2 }
    "curve-performance" = @{ Idle = 30; Min = 55; Max = 100; Load = 68; Step = 1; Deadband = 2; Response = 1 }
}

$base = Get-Content -Raw $BasePath | ConvertFrom-Json
$cpuBase = $base.Main.FanCurves | Where-Object { $_.Name -eq "CPU" } | Select-Object -First 1
$gpuBase = $base.Main.FanCurves | Where-Object { $_.Name -eq "GPU" } | Select-Object -First 1

if (-not $cpuBase -or -not $gpuBase) {
    throw "CPU/GPU curves not found in base config."
}

$destDirs = @(
    (Join-Path $PluginRoot "config/fancontrol")
)
if (Test-Path "C:/Program Files (x86)/FanControl/Configurations") {
    $destDirs += "C:/Program Files (x86)/FanControl/Configurations"
}

foreach ($dir in $destDirs) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
    }
}

$written = @()
foreach ($profileName in $profiles.Keys) {
    $cfg = Clone-Object $base
    $settings = $profiles[$profileName]

    $cpuCurve = Clone-Object $cpuBase
    $cpuCurve.Name = "CPU $profileName"
    $cpuCurve.IdleTemperature = $settings.Idle
    $cpuCurve.MinFanSpeed = $settings.Min
    $cpuCurve.MaxFanSpeed = $settings.Max
    $cpuCurve.LoadTemperature = $settings.Load
    $cpuCurve.Step = $settings.Step
    $cpuCurve.Deadband = $settings.Deadband
    $cpuCurve.SelectedResponseTime = $settings.Response

    $gpuCurve = Clone-Object $gpuBase
    $gpuCurve.Name = "GPU $profileName"
    $gpuCurve.IdleTemperature = $settings.Idle
    $gpuCurve.MinFanSpeed = $settings.Min
    $gpuCurve.MaxFanSpeed = $settings.Max
    $gpuCurve.LoadTemperature = $settings.Load
    $gpuCurve.Step = $settings.Step
    $gpuCurve.Deadband = $settings.Deadband
    $gpuCurve.SelectedResponseTime = $settings.Response

    $cfg.Main.FanCurves = @($cpuCurve, $gpuCurve)

    foreach ($control in $cfg.Main.Controls) {
        switch -Wildcard ($control.Name) {
            "Control 1 - NVIDIA GeForce RTX 5060 Ti" {
                $control.Enable = $true
                $control.ManualControl = $false
                $control.SelectedFanCurve = [pscustomobject]@{ Name = $gpuCurve.Name }
            }
            "CPU Fan" {
                $control.Enable = $true
                $control.ManualControl = $false
                $control.SelectedFanCurve = [pscustomobject]@{ Name = $cpuCurve.Name }
            }
            "CPU Optional Fan" {
                $control.Enable = $true
                $control.ManualControl = $false
                $control.SelectedFanCurve = [pscustomobject]@{ Name = $cpuCurve.Name }
            }
            "Chassis Fan #*" {
                $control.Enable = $true
                $control.ManualControl = $false
                $control.SelectedFanCurve = [pscustomobject]@{ Name = $cpuCurve.Name }
            }
            "Chipset Fan" {
                $control.Enable = $true
                $control.ManualControl = $false
                $control.SelectedFanCurve = [pscustomobject]@{ Name = $cpuCurve.Name }
            }
            "AIO Pump" {
                if ($EnableAioPump) {
                    $control.Enable = $true
                    $control.ManualControl = $false
                    $control.SelectedFanCurve = [pscustomobject]@{ Name = $cpuCurve.Name }
                }
            }
        }
    }

    foreach ($dir in $destDirs) {
        $outPath = Join-Path $dir ("{0}.json" -f $profileName)
        $cfg | ConvertTo-Json -Depth 30 | Set-Content -Path $outPath -Encoding UTF8
        $written += $outPath
    }
}

$written | ForEach-Object { Write-Output $_ }
