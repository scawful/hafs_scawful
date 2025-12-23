param(
    [string]$OutputDir = "D:/hafs_training/logs/telemetry",
    [int]$IntervalSec = 10,
    [string]$FilePrefix = "telemetry",
    [switch]$Once
)

function Get-GpuTelemetry {
    $nvidiaSmi = Get-Command nvidia-smi -ErrorAction SilentlyContinue
    if (-not $nvidiaSmi) {
        return $null
    }
    try {
        $line = & $nvidiaSmi.Source "--query-gpu=timestamp,name,utilization.gpu,utilization.memory,power.draw,power.limit,temperature.gpu,clocks.sm,fan.speed,memory.used,memory.total" "--format=csv,noheader,nounits" |
            Select-Object -First 1
        if (-not $line) {
            return $null
        }
        $parts = $line -split ",\\s*"
        return $parts
    } catch {
        return $null
    }
}

if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
}

$totalMemMb = $null
try {
    $totalMemBytes = (Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory
    if ($totalMemBytes) {
        $totalMemMb = [math]::Round($totalMemBytes / 1MB, 2)
    }
} catch {
    $totalMemMb = $null
}

$dateTag = Get-Date -Format "yyyyMMdd"
$filePath = Join-Path $OutputDir ("{0}-{1}.csv" -f $FilePrefix, $dateTag)
if (-not (Test-Path $filePath)) {
    "timestamp,cpu_percent,mem_used_gb,mem_free_gb,mem_total_gb,gpu_name,gpu_util,gpu_mem_util,gpu_power_w,gpu_power_limit_w,gpu_temp_c,gpu_clock_mhz,gpu_fan_pct,gpu_mem_used_gb,gpu_mem_total_gb" |
        Set-Content -Path $filePath -Encoding UTF8
}

do {
    $now = Get-Date -Format "s"
    $cpu = (Get-Counter "\\Processor(_Total)\\% Processor Time").CounterSamples[0].CookedValue
    $freeMb = (Get-Counter "\\Memory\\Available MBytes").CounterSamples[0].CookedValue
    $memTotalGb = if ($totalMemMb) { [math]::Round($totalMemMb / 1024, 2) } else { $null }
    $memFreeGb = [math]::Round($freeMb / 1024, 2)
    $memUsedGb = if ($totalMemMb) { [math]::Round(($totalMemMb - $freeMb) / 1024, 2) } else { $null }

    $gpu = Get-GpuTelemetry
    if ($gpu) {
        $gpuName = $gpu[1]
        $gpuUtil = $gpu[2]
        $gpuMemUtil = $gpu[3]
        $gpuPower = $gpu[4]
        $gpuPowerLimit = $gpu[5]
        $gpuTemp = $gpu[6]
        $gpuClock = $gpu[7]
        $gpuFan = $gpu[8]
        $gpuMemUsedGb = [math]::Round([double]$gpu[9] / 1024, 2)
        $gpuMemTotalGb = [math]::Round([double]$gpu[10] / 1024, 2)
    } else {
        $gpuName = ""
        $gpuUtil = ""
        $gpuMemUtil = ""
        $gpuPower = ""
        $gpuPowerLimit = ""
        $gpuTemp = ""
        $gpuClock = ""
        $gpuFan = ""
        $gpuMemUsedGb = ""
        $gpuMemTotalGb = ""
    }

    $line = "$now,$([math]::Round($cpu,1)),$memUsedGb,$memFreeGb,$memTotalGb,$gpuName,$gpuUtil,$gpuMemUtil,$gpuPower,$gpuPowerLimit,$gpuTemp,$gpuClock,$gpuFan,$gpuMemUsedGb,$gpuMemTotalGb"
    Add-Content -Path $filePath -Value $line

    if (-not $Once) {
        Start-Sleep -Seconds $IntervalSec
    }
} while (-not $Once)
