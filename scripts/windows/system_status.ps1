param(
    [string]$TrainingRoot = $env:HAFS_WINDOWS_TRAINING,
    [int]$TopProcesses = 8
)

if (-not $TrainingRoot) { $TrainingRoot = "D:/hafs_training" }

$os = Get-CimInstance Win32_OperatingSystem
$cpuInfo = Get-CimInstance Win32_Processor | Select-Object -First 1
$cpuUsage = (Get-Counter '\\Processor(_Total)\\% Processor Time').CounterSamples[0].CookedValue
$totalMemGb = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
$freeMemGb = [math]::Round($os.FreePhysicalMemory / 1MB, 2)

Write-Output "=== System ==="
Write-Output ("CPU: {0} ({1:N1}% used)" -f $cpuInfo.Name, $cpuUsage)
Write-Output ("Memory: {0:N2} GB total, {1:N2} GB free" -f $totalMemGb, $freeMemGb)

Write-Output ""
Write-Output "=== Disks ==="
Get-PSDrive -PSProvider FileSystem | Select-Object Name,Free,Used | Format-Table -AutoSize

Write-Output ""
Write-Output "=== GPU ==="
if (Get-Command nvidia-smi -ErrorAction SilentlyContinue) {
    nvidia-smi --query-gpu=name,temperature.gpu,utilization.gpu,memory.used,memory.total,power.draw --format=csv,noheader,nounits
} else {
    Write-Output "nvidia-smi not available."
}

$controlDir = Join-Path $TrainingRoot "control"
$pauseFlag = Join-Path $controlDir "pause.flag"
$logDir = Join-Path $TrainingRoot "logs"

Write-Output ""
Write-Output "=== Training ==="
if (Test-Path $pauseFlag) {
    Write-Output "Pause flag: PRESENT"
} else {
    Write-Output "Pause flag: not set"
}

if (Test-Path $controlDir) {
    $pidFiles = Get-ChildItem -Path $controlDir -Filter "*.pid" -ErrorAction SilentlyContinue
    if ($pidFiles) {
        foreach ($pidFile in $pidFiles) {
            $pid = (Get-Content -Path $pidFile.FullName -ErrorAction SilentlyContinue | Select-Object -First 1)
            if ($pid) {
                $proc = Get-Process -Id $pid -ErrorAction SilentlyContinue
                if ($proc) {
                    Write-Output ("{0}: PID {1} ({2})" -f $pidFile.BaseName, $pid, $proc.ProcessName)
                } else {
                    Write-Output ("{0}: PID {1} (not running)" -f $pidFile.BaseName, $pid)
                }
            }
        }
    } else {
        Write-Output "No pid files in control directory."
    }
} else {
    Write-Output "Control directory not found."
}

if (Test-Path $logDir) {
    $latestLog = Get-ChildItem -Path $logDir -Filter "*.log" -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
    if ($latestLog) {
        Write-Output ("Latest log: {0} ({1})" -f $latestLog.Name, $latestLog.LastWriteTime)
    }
}

Write-Output ""
Write-Output "=== Top Processes (CPU) ==="
Get-Process | Sort-Object CPU -Descending | Select-Object -First $TopProcesses Id,ProcessName,CPU,WorkingSet |
    Format-Table -AutoSize
