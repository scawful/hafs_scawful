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
    "curve-quiet" = @{
        CPU = @{ Idle = 35; Min = 35; Max = 75; Load = 78; Step = 3; Deadband = 4; Response = 3 }
        GPU = @{ Idle = 35; Min = 35; Max = 80; Load = 78; Step = 3; Deadband = 4; Response = 3 }
    }
    "curve-balanced" = @{
        CPU = @{ Idle = 35; Min = 45; Max = 85; Load = 76; Step = 2; Deadband = 3; Response = 2 }
        GPU = @{ Idle = 35; Min = 45; Max = 90; Load = 75; Step = 2; Deadband = 3; Response = 2 }
    }
    "curve-performance" = @{
        CPU = @{ Idle = 30; Min = 55; Max = 100; Load = 68; Step = 1; Deadband = 2; Response = 1 }
        GPU = @{ Idle = 30; Min = 60; Max = 100; Load = 65; Step = 1; Deadband = 2; Response = 1 }
    }
    "curve-training" = @{
        CPU = @{ Idle = 35; Min = 50; Max = 100; Load = 72; Step = 1; Deadband = 2; Response = 1 }
        GPU = @{ Idle = 35; Min = 70; Max = 100; Load = 65; Step = 1; Deadband = 2; Response = 1 }
    }
    "curve-gaming" = @{
        CPU = @{ Idle = 35; Min = 45; Max = 90; Load = 72; Step = 2; Deadband = 2; Response = 1 }
        GPU = @{ Idle = 30; Min = 60; Max = 100; Load = 63; Step = 1; Deadband = 1; Response = 1 }
    }
    "curve-overnight" = @{
        CPU = @{ Idle = 35; Min = 35; Max = 65; Load = 82; Step = 4; Deadband = 5; Response = 4 }
        GPU = @{ Idle = 35; Min = 35; Max = 70; Load = 82; Step = 4; Deadband = 5; Response = 4 }
    }
    "curve-away" = @{
        CPU = @{ Idle = 35; Min = 35; Max = 60; Load = 84; Step = 5; Deadband = 6; Response = 5 }
        GPU = @{ Idle = 35; Min = 35; Max = 65; Load = 84; Step = 5; Deadband = 6; Response = 5 }
    }
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
    $cpuSettings = if ($settings.CPU) { $settings.CPU } else { $settings }
    $gpuSettings = if ($settings.GPU) { $settings.GPU } else { $settings }

    $cpuCurve = Clone-Object $cpuBase
    $cpuCurve.Name = "CPU $profileName"
    $cpuCurve.IdleTemperature = $cpuSettings.Idle
    $cpuCurve.MinFanSpeed = $cpuSettings.Min
    $cpuCurve.MaxFanSpeed = $cpuSettings.Max
    $cpuCurve.LoadTemperature = $cpuSettings.Load
    $cpuCurve.Step = $cpuSettings.Step
    $cpuCurve.Deadband = $cpuSettings.Deadband
    $cpuCurve.SelectedResponseTime = $cpuSettings.Response

    $gpuCurve = Clone-Object $gpuBase
    $gpuCurve.Name = "GPU $profileName"
    $gpuCurve.IdleTemperature = $gpuSettings.Idle
    $gpuCurve.MinFanSpeed = $gpuSettings.Min
    $gpuCurve.MaxFanSpeed = $gpuSettings.Max
    $gpuCurve.LoadTemperature = $gpuSettings.Load
    $gpuCurve.Step = $gpuSettings.Step
    $gpuCurve.Deadband = $gpuSettings.Deadband
    $gpuCurve.SelectedResponseTime = $gpuSettings.Response

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
