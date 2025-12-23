param(
    [string[]]$ProcessNames,
    [int]$PollSeconds = 10,
    [ValidateSet("pause", "priority", "both")][string]$Mode = "pause",
    [switch]$ApplyGpuLimits,
    [int]$GpuPower = 150,
    [string]$GpuClock,
    [switch]$ResetGpuOnResume = $true,
    [string]$NvidiaSmiPath = $env:HAFS_NVIDIA_SMI,
    [string]$TrainingPython = $env:HAFS_WINDOWS_PYTHON,
    [string]$TrainingRoot = $env:HAFS_WINDOWS_TRAINING,
    [switch]$ApplyEnergyMode,
    [string]$EnergyModeGame = "gaming",
    [string]$EnergyModeTraining = "training",
    [string]$EnergyModeIdle = "balanced",
    [string[]]$TrainingProcessNames,
    [string[]]$TrainingMarkers
)

if (-not $TrainingRoot) { $TrainingRoot = "D:/hafs_training" }
if (-not $TrainingPython) { $TrainingPython = "D:/pytorch_env/Scripts/python.exe" }
if (-not $NvidiaSmiPath) { $NvidiaSmiPath = "nvidia-smi" }

if (-not $ProcessNames -or $ProcessNames.Count -eq 0) {
    if ($env:HAFS_GAME_PROCESS_NAMES) {
        $ProcessNames = $env:HAFS_GAME_PROCESS_NAMES -split "[;,]"
    }
}

if ($ProcessNames -and $ProcessNames.Count -eq 1) {
    $raw = $ProcessNames[0]
    if ($raw -match "[;,]") {
        $ProcessNames = $raw -split "[;,]"
    }
}

if ($ProcessNames) {
    $ProcessNames = $ProcessNames | ForEach-Object { $_.Trim() } | Where-Object { $_ }
}

if (-not $ProcessNames -or $ProcessNames.Count -eq 0) {
    Write-Error "Set -ProcessNames or HAFS_GAME_PROCESS_NAMES (comma or semicolon separated)."
    exit 1
}

$controlDir = Join-Path $TrainingRoot "control"
$pauseFlag = Join-Path $controlDir "pause.flag"
$gameFlag = Join-Path $controlDir "game_mode.flag"
$null = New-Item -ItemType Directory -Force -Path $controlDir

Write-Output "Watching for games: $($ProcessNames -join ', ')"
Write-Output "Mode: $Mode"
if ($ApplyGpuLimits) {
    Write-Output "GPU limits: Power=$GpuPower Clock=$GpuClock ResetOnResume=$ResetGpuOnResume"
}
if ($ApplyEnergyMode) {
    Write-Output "Energy modes: game=$EnergyModeGame training=$EnergyModeTraining idle=$EnergyModeIdle"
}

$gpuLimited = $false
$energyState = $null

function Get-TrainingProcess {
    param([string[]]$Names, [string[]]$Markers)
    if (-not $Names -or $Names.Count -eq 0) {
        $Names = @("python.exe", "python")
    }
    $filters = $Names | ForEach-Object { "Name='$_'" }
    $filter = $filters -join " OR "
    $procs = Get-CimInstance Win32_Process -Filter $filter -ErrorAction SilentlyContinue
    if (-not $procs) {
        return @()
    }
    if (-not $Markers -or $Markers.Count -eq 0) {
        return $procs
    }
    $lowerMarkers = $Markers | ForEach-Object { $_.ToLower() }
    return $procs | Where-Object {
        $cmd = $_.CommandLine
        if (-not $cmd) { return $false }
        $cmdLower = $cmd.ToLower()
        foreach ($marker in $lowerMarkers) {
            if ($cmdLower -like "*$marker*") { return $true }
        }
        return $false
    }
}

if (-not $TrainingProcessNames -or $TrainingProcessNames.Count -eq 0) {
    if ($env:HAFS_TRAINING_PROCESS_NAMES) {
        $TrainingProcessNames = $env:HAFS_TRAINING_PROCESS_NAMES -split "[;,]"
    }
}

if ($TrainingProcessNames -and $TrainingProcessNames.Count -eq 1) {
    $raw = $TrainingProcessNames[0]
    if ($raw -match "[;,]") {
        $TrainingProcessNames = $raw -split "[;,]"
    }
}

if ($TrainingProcessNames) {
    $TrainingProcessNames = $TrainingProcessNames | ForEach-Object { $_.Trim() } | Where-Object { $_ }
}

if (-not $TrainingMarkers -or $TrainingMarkers.Count -eq 0) {
    $TrainingMarkers = @(
        "train_model_windows",
        "generate_campaign",
        "hafs_scawful",
        $TrainingRoot
    ) | Where-Object { $_ }
}

while ($true) {
    $game = Get-Process -Name $ProcessNames -ErrorAction SilentlyContinue
    $isGameRunning = $null -ne $game

    if ($isGameRunning) {
        if (-not (Test-Path $gameFlag)) {
            Set-Content -Path $gameFlag -Value "game $(Get-Date -Format s)"
        }
        if ($Mode -eq "pause" -or $Mode -eq "both") {
            if (-not (Test-Path $pauseFlag)) {
                Set-Content -Path $pauseFlag -Value "paused $(Get-Date -Format s)"
                Write-Output "Paused training via flag."
            }
        }

        if ($Mode -eq "priority" -or $Mode -eq "both") {
            Get-Process -Name python -ErrorAction SilentlyContinue |
                Where-Object { $_.Path -eq $TrainingPython } |
                ForEach-Object { $_.PriorityClass = "BelowNormal" }
        }

        if ($ApplyGpuLimits -and -not $gpuLimited) {
            & "$PSScriptRoot/set_gpu_limit.ps1" -Power $GpuPower -Clock $GpuClock -NvidiaSmiPath $NvidiaSmiPath | Out-Null
            $gpuLimited = $true
        }

        if ($ApplyEnergyMode -and $energyState -ne "game") {
            & "$PSScriptRoot/apply_energy_mode.ps1" -Mode $EnergyModeGame | Out-Null
            $energyState = "game"
        }
    } else {
        if (Test-Path $gameFlag) {
            Remove-Item -Path $gameFlag -ErrorAction SilentlyContinue
        }
        if ($Mode -eq "pause" -or $Mode -eq "both") {
            if (Test-Path $pauseFlag) {
                Remove-Item -Path $pauseFlag -ErrorAction SilentlyContinue
                Write-Output "Resumed training via flag."
            }
        }

        if ($Mode -eq "priority" -or $Mode -eq "both") {
            Get-Process -Name python -ErrorAction SilentlyContinue |
                Where-Object { $_.Path -eq $TrainingPython } |
                ForEach-Object { $_.PriorityClass = "Normal" }
        }

        if ($ApplyGpuLimits -and $gpuLimited -and $ResetGpuOnResume) {
            & "$PSScriptRoot/set_gpu_limit.ps1" -Reset -NvidiaSmiPath $NvidiaSmiPath | Out-Null
            $gpuLimited = $false
        }

        if ($ApplyEnergyMode) {
            $trainingProcs = Get-TrainingProcess -Names $TrainingProcessNames -Markers $TrainingMarkers
            if ($trainingProcs.Count -gt 0) {
                if ($energyState -ne "training") {
                    & "$PSScriptRoot/apply_energy_mode.ps1" -Mode $EnergyModeTraining | Out-Null
                    $energyState = "training"
                }
            } else {
                if ($energyState -ne "idle") {
                    & "$PSScriptRoot/apply_energy_mode.ps1" -Mode $EnergyModeIdle | Out-Null
                    $energyState = "idle"
                }
            }
        }
    }

    Start-Sleep -Seconds $PollSeconds
}
