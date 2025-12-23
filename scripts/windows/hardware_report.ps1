param(
    [switch]$Json
)

function Get-TotalMemoryGB {
    $modules = Get-CimInstance Win32_PhysicalMemory -ErrorAction SilentlyContinue
    if (-not $modules) {
        return $null
    }
    $total = ($modules | Measure-Object -Property Capacity -Sum).Sum
    if (-not $total) {
        return $null
    }
    return [math]::Round($total / 1GB, 2)
}

$cpu = Get-CimInstance Win32_Processor | Select-Object -First 1 Name,NumberOfCores,NumberOfLogicalProcessors,MaxClockSpeed
$gpu = Get-CimInstance Win32_VideoController | Select-Object Name,AdapterRAM,DriverVersion
$os = Get-CimInstance Win32_OperatingSystem | Select-Object Caption,Version,BuildNumber,OSArchitecture
$board = Get-CimInstance Win32_BaseBoard | Select-Object Manufacturer,Product
$bios = Get-CimInstance Win32_BIOS | Select-Object SMBIOSBIOSVersion,ReleaseDate
$disks = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" | Select-Object DeviceID,Size,FreeSpace
$memoryGb = Get-TotalMemoryGB
$powerPlan = (powercfg /getactivescheme) -join " "

$nvidiaSmi = Get-Command nvidia-smi -ErrorAction SilentlyContinue
$gpuTelemetry = $null
if ($nvidiaSmi) {
    try {
        $gpuTelemetry = & $nvidiaSmi.Source "--query-gpu=name,power.limit,power.default_limit,clocks.current.graphics,temperature.gpu" "--format=csv,noheader"
    } catch {
        $gpuTelemetry = $null
    }
}

$report = [pscustomobject]@{
    OS = $os
    CPU = $cpu
    GPU = $gpu
    Motherboard = $board
    BIOS = $bios
    MemoryGB = $memoryGb
    Disks = $disks
    PowerPlan = $powerPlan
    GpuTelemetry = $gpuTelemetry
    PSU = "Not detectable via standard Windows tools"
}

if ($Json) {
    $report | ConvertTo-Json -Depth 6
    exit 0
}

Write-Output "== Hardware Report =="
Write-Output ""
Write-Output "OS:"
$os | Format-List | Out-String | Write-Output
Write-Output "CPU:"
$cpu | Format-List | Out-String | Write-Output
Write-Output "GPU:"
$gpu | Format-Table -AutoSize | Out-String | Write-Output
Write-Output "Motherboard:"
$board | Format-List | Out-String | Write-Output
Write-Output "BIOS:"
$bios | Format-List | Out-String | Write-Output
Write-Output "Memory:"
if ($memoryGb) {
    Write-Output ("Total Memory (GB): {0}" -f $memoryGb)
} else {
    Write-Output "Total Memory (GB): unknown"
}
Write-Output ""
Write-Output "Disks:"
$disks | Select-Object DeviceID,@{Name="SizeGB";Expression={[math]::Round($_.Size/1GB,1)}},@{Name="FreeGB";Expression={[math]::Round($_.FreeSpace/1GB,1)}} |
    Format-Table -AutoSize | Out-String | Write-Output
Write-Output "Power plan:"
Write-Output $powerPlan
if ($gpuTelemetry) {
    Write-Output "GPU telemetry (nvidia-smi):"
    $gpuTelemetry | Write-Output
}
Write-Output "PSU:"
Write-Output $report.PSU
