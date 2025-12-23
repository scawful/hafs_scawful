param(
    [string[]]$ProcessNames,
    [int]$PollSeconds = 15,
    [string]$ModeActive = "training",
    [string]$ModeIdle = "balanced",
    [int]$MinSamples = 2,
    [string[]]$TrainingMarkers,
    [string[]]$GameProcessNames,
    [string]$TrainingRoot = $env:HAFS_WINDOWS_TRAINING,
    [string]$LogPath
)

if (-not $TrainingRoot) { $TrainingRoot = "D:/hafs_training" }

if (-not $ProcessNames -or $ProcessNames.Count -eq 0) {
    if ($env:HAFS_TRAINING_PROCESS_NAMES) {
        $ProcessNames = $env:HAFS_TRAINING_PROCESS_NAMES -split "[;,]"
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
    $ProcessNames = @("python.exe", "python")
}

if (-not $TrainingMarkers -or $TrainingMarkers.Count -eq 0) {
    $TrainingMarkers = @(
        "train_model_windows",
        "generate_campaign",
        "hafs_scawful",
        $TrainingRoot
    ) | Where-Object { $_ }
}

if (-not $GameProcessNames -or $GameProcessNames.Count -eq 0) {
    if ($env:HAFS_GAME_PROCESS_NAMES) {
        $GameProcessNames = $env:HAFS_GAME_PROCESS_NAMES -split "[;,]"
    }
}

if ($GameProcessNames -and $GameProcessNames.Count -eq 1) {
    $raw = $GameProcessNames[0]
    if ($raw -match "[;,]") {
        $GameProcessNames = $raw -split "[;,]"
    }
}

if ($GameProcessNames) {
    $GameProcessNames = $GameProcessNames | ForEach-Object { $_.Trim() } | Where-Object { $_ }
}

function Write-Log {
    param([string]$Message)
    $line = "$(Get-Date -Format s) $Message"
    Write-Output $line
    if ($LogPath) {
        Add-Content -Path $LogPath -Value $line
    }
}

function Get-TrainingProcess {
    param([string[]]$Names, [string[]]$Markers)
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

$controlDir = Join-Path $TrainingRoot "control"
$gameFlag = Join-Path $controlDir "game_mode.flag"
$null = New-Item -ItemType Directory -Force -Path $controlDir

$state = "idle"
$activeCount = 0
$idleCount = 0

Write-Log "Watching for training processes: $($ProcessNames -join ', ')"
Write-Log "Markers: $($TrainingMarkers -join ', ')"
Write-Log "Mode active: $ModeActive, idle: $ModeIdle"

while ($true) {
    $gameRunning = $false
    if ($GameProcessNames -and $GameProcessNames.Count -gt 0) {
        $game = Get-Process -Name $GameProcessNames -ErrorAction SilentlyContinue
        $gameRunning = $null -ne $game
    }
    if (Test-Path $gameFlag) {
        $gameRunning = $true
    }

    if ($gameRunning) {
        if ($state -ne "game") {
            $state = "game"
            Write-Log "Game detected, holding training mode changes."
        }
        Start-Sleep -Seconds $PollSeconds
        continue
    }

    $matches = Get-TrainingProcess -Names $ProcessNames -Markers $TrainingMarkers
    $isTraining = $matches.Count -gt 0

    if ($isTraining) {
        $activeCount += 1
        $idleCount = 0
        if ($state -ne "active" -and $activeCount -ge $MinSamples) {
            & "$PSScriptRoot/apply_energy_mode.ps1" -Mode $ModeActive
            $state = "active"
            Write-Log "Training detected, applied mode: $ModeActive"
        }
    } else {
        $idleCount += 1
        $activeCount = 0
        if ($state -ne "idle" -and $idleCount -ge $MinSamples) {
            & "$PSScriptRoot/apply_energy_mode.ps1" -Mode $ModeIdle
            $state = "idle"
            Write-Log "Training idle, applied mode: $ModeIdle"
        }
    }

    Start-Sleep -Seconds $PollSeconds
}
