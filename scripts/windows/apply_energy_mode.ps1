param(
    [Parameter(Mandatory = $true)][string]$Mode,
    [string]$FanProfile,
    [string]$PowerPlan,
    [int]$GpuPower,
    [switch]$SkipFan,
    [switch]$SkipPower,
    [switch]$SkipGpu,
    [switch]$ResetGpu,
    [switch]$PauseTraining,
    [switch]$ResumeTraining
)

$modeKey = $Mode.ToLower()
$defaults = @{
    "gaming"    = @{ Fan = "curve-gaming";     Power = "gaming";      Gpu = 170 }
    "training"  = @{ Fan = "curve-training";   Power = "training";    Gpu = 150 }
    "balanced"  = @{ Fan = "curve-balanced";   Power = "balanced";    Gpu = 140 }
    "overnight" = @{ Fan = "curve-overnight";  Power = "power_saver"; Gpu = 110 }
    "away"      = @{ Fan = "curve-away";       Power = "power_saver"; Gpu = 90 }
}

if (-not $defaults.ContainsKey($modeKey)) {
    Write-Error "Unknown mode '$Mode'. Valid: $($defaults.Keys -join ', ')"
    exit 1
}

$gpuPowerSet = $PSBoundParameters.ContainsKey("GpuPower")

if (-not $FanProfile) { $FanProfile = $defaults[$modeKey].Fan }
if (-not $PowerPlan) { $PowerPlan = $defaults[$modeKey].Power }
if (-not $gpuPowerSet) { $GpuPower = $defaults[$modeKey].Gpu }

if ($PauseTraining -and $ResumeTraining) {
    Write-Error "Choose either -PauseTraining or -ResumeTraining."
    exit 1
}

if (-not $SkipPower -and $PowerPlan) {
    & "$PSScriptRoot/set_power_profile.ps1" -Mode $PowerPlan
}

if (-not $SkipGpu) {
    if ($ResetGpu) {
        & "$PSScriptRoot/set_gpu_limit.ps1" -Reset
    } elseif ($GpuPower -gt 0) {
        & "$PSScriptRoot/set_gpu_limit.ps1" -Power $GpuPower
    }
}

if (-not $SkipFan -and $FanProfile) {
    & "$PSScriptRoot/fancontrol_switch.ps1" -Profile $FanProfile
}

if ($PauseTraining) {
    & "$PSScriptRoot/pause_training.ps1"
} elseif ($ResumeTraining) {
    & "$PSScriptRoot/resume_training.ps1"
}

Write-Output "Mode applied: $Mode (fan=$FanProfile power=$PowerPlan gpu=$GpuPower)"
