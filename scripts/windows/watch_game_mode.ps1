param(
    [string[]]$ProcessNames,
    [int]$PollSeconds = 10,
    [ValidateSet("pause", "priority", "both")][string]$Mode = "pause",
    [string]$TrainingPython = $env:HAFS_WINDOWS_PYTHON,
    [string]$TrainingRoot = $env:HAFS_WINDOWS_TRAINING
)

if (-not $TrainingRoot) { $TrainingRoot = "D:/hafs_training" }
if (-not $TrainingPython) { $TrainingPython = "D:/pytorch_env/Scripts/python.exe" }

if (-not $ProcessNames -or $ProcessNames.Count -eq 0) {
    if ($env:HAFS_GAME_PROCESS_NAMES) {
        $ProcessNames = $env:HAFS_GAME_PROCESS_NAMES -split "[;,]"
    }
}

if (-not $ProcessNames -or $ProcessNames.Count -eq 0) {
    Write-Error "Set -ProcessNames or HAFS_GAME_PROCESS_NAMES (comma or semicolon separated)."
    exit 1
}

$controlDir = Join-Path $TrainingRoot "control"
$pauseFlag = Join-Path $controlDir "pause.flag"
$null = New-Item -ItemType Directory -Force -Path $controlDir

Write-Output "Watching for games: $($ProcessNames -join ', ')"
Write-Output "Mode: $Mode"

while ($true) {
    $game = Get-Process -Name $ProcessNames -ErrorAction SilentlyContinue
    $isGameRunning = $null -ne $game

    if ($isGameRunning) {
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
    } else {
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
    }

    Start-Sleep -Seconds $PollSeconds
}
