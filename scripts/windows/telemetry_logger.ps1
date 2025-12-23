param(
    [string]$OutputDir = "D:/hafs_training/logs/telemetry",
    [int]$IntervalSec = 10,
    [string]$FilePrefix = "telemetry-v2",
    [switch]$Once,
    [string]$LibreHardwareMonitorDll = $env:HAFS_LHM_DLL
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

function Get-HardwareMonitorSensors {
    if (-not $script:LhmComputer) {
        if (-not $LibreHardwareMonitorDll) {
            $candidates = @()
            $candidates += $env:HAFS_LHM_DLL
            $candidates += (Get-ChildItem -Path "$env:LOCALAPPDATA\\Microsoft\\WinGet\\Packages" -Recurse -Filter "LibreHardwareMonitorLib.dll" -ErrorAction SilentlyContinue |
                Select-Object -First 1 -ExpandProperty FullName)
            $LibreHardwareMonitorDll = $candidates | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
        }

        if ($LibreHardwareMonitorDll -and (Test-Path $LibreHardwareMonitorDll)) {
            try {
                Add-Type -Path $LibreHardwareMonitorDll -ErrorAction Stop
                $computer = New-Object LibreHardwareMonitor.Hardware.Computer
                $computer.IsCpuEnabled = $true
                $computer.IsGpuEnabled = $true
                $computer.IsMotherboardEnabled = $true
                $computer.IsControllerEnabled = $true
                $computer.Open()
                $script:LhmComputer = $computer
            } catch {
                $script:LhmComputer = $null
            }
        }
    }

    if ($script:LhmComputer) {
        foreach ($hw in $script:LhmComputer.Hardware) {
            $hw.Update()
            foreach ($sub in $hw.SubHardware) { $sub.Update() }
        }
        $sensors = foreach ($hw in $script:LhmComputer.Hardware) {
            $hw.Sensors
            foreach ($sub in $hw.SubHardware) { $sub.Sensors }
        }
        return $sensors
    }

    $namespaces = @("root/LibreHardwareMonitor", "root/OpenHardwareMonitor")
    foreach ($ns in $namespaces) {
        try {
            $sensors = Get-CimInstance -Namespace $ns -ClassName Sensor -ErrorAction Stop
            if ($sensors) {
                return $sensors
            }
        } catch {
        }
    }

    return @()
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
    "timestamp,cpu_percent,mem_used_gb,mem_free_gb,mem_total_gb,gpu_name,gpu_util,gpu_mem_util,gpu_power_w,gpu_power_limit_w,gpu_temp_c,gpu_clock_mhz,gpu_fan_pct,gpu_mem_used_gb,gpu_mem_total_gb,cpu_temp_c,cpu_temp_max_c,cpu_fan_rpm,fan_rpm_max,fan_rpm_avg,gpu_fan_rpm" |
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

    $sensors = Get-HardwareMonitorSensors
    $cpuTemp = ""
    $cpuTempMax = ""
    $cpuFanRpm = ""
    $fanRpmMax = ""
    $fanRpmAvg = ""
    $gpuFanRpm = ""
    if ($sensors.Count -gt 0) {
        $cpuTemps = $sensors | Where-Object { $_.SensorType -eq "Temperature" -and $_.Name -match "CPU|Tctl|Tdie|CCD" }
        if ($cpuTemps) {
            $cpuTempMax = [math]::Round(($cpuTemps | Measure-Object -Property Value -Maximum).Maximum, 1)
            $primary = $cpuTemps | Where-Object { $_.Name -match "Package|Tctl|Tdie" } | Select-Object -First 1
            $cpuTemp = if ($primary) { [math]::Round($primary.Value, 1) } else { $cpuTempMax }
        }

        $fanSensors = $sensors | Where-Object { $_.SensorType -eq "Fan" }
        if ($fanSensors) {
            $fanRpmMax = [math]::Round(($fanSensors | Measure-Object -Property Value -Maximum).Maximum, 0)
            $fanRpmAvg = [math]::Round(($fanSensors | Measure-Object -Property Value -Average).Average, 0)
            $cpuFan = $fanSensors | Where-Object { $_.Name -match "CPU Fan" } | Select-Object -First 1
            if (-not $cpuFan) {
                $cpuFan = $fanSensors | Where-Object { $_.Name -match "AIO" } | Select-Object -First 1
            }
            if ($cpuFan) {
                $cpuFanRpm = [math]::Round($cpuFan.Value, 0)
            }

            $gpuFanSensor = $fanSensors | Where-Object { $_.Name -match "GPU" } | Select-Object -First 1
            if ($gpuFanSensor) {
                $gpuFanRpm = [math]::Round($gpuFanSensor.Value, 0)
            }
        }
    }

    $line = "$now,$([math]::Round($cpu,1)),$memUsedGb,$memFreeGb,$memTotalGb,$gpuName,$gpuUtil,$gpuMemUtil,$gpuPower,$gpuPowerLimit,$gpuTemp,$gpuClock,$gpuFan,$gpuMemUsedGb,$gpuMemTotalGb,$cpuTemp,$cpuTempMax,$cpuFanRpm,$fanRpmMax,$fanRpmAvg,$gpuFanRpm"
    Add-Content -Path $filePath -Value $line

    if (-not $Once) {
        Start-Sleep -Seconds $IntervalSec
    }
} while (-not $Once)
