param(
    [string]$Name,
    [string]$Contains,
    [int]$Top = 20
)

$procs = Get-Process

if ($Name) {
    $procs = Get-Process -Name $Name -ErrorAction SilentlyContinue
}

if ($Contains) {
    $needle = $Contains.ToLower()
    $procs = $procs | Where-Object {
        $_.ProcessName.ToLower().Contains($needle) -or
        ($_.Path -and $_.Path.ToLower().Contains($needle)) -or
        ($_.MainWindowTitle -and $_.MainWindowTitle.ToLower().Contains($needle))
    }
}

$procs | Sort-Object CPU -Descending |
    Select-Object -First $Top Id,ProcessName,CPU,WorkingSet,Path |
    Format-Table -AutoSize
