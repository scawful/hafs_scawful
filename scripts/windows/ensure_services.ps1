param(
    [switch]$Fix
)

$services = @(
    @{ Name = "sshd"; Display = "OpenSSH Server" },
    @{ Name = "ssh-agent"; Display = "OpenSSH Authentication Agent" },
    @{ Name = "Tailscale"; Display = "Tailscale" }
)

foreach ($svcInfo in $services) {
    $svc = Get-Service -Name $svcInfo.Name -ErrorAction SilentlyContinue
    if (-not $svc) {
        Write-Output "$($svcInfo.Display): missing"
        continue
    }

    if ($Fix) {
        try {
            Set-Service -Name $svcInfo.Name -StartupType Automatic -ErrorAction Stop
        } catch {
            Write-Output "$($svcInfo.Display): failed to set startup type ($($_.Exception.Message))"
        }

        if ($svc.Status -ne "Running") {
            try {
                Start-Service -Name $svcInfo.Name -ErrorAction Stop
            } catch {
                Write-Output "$($svcInfo.Display): failed to start ($($_.Exception.Message))"
            }
        }
    }

    $svc = Get-Service -Name $svcInfo.Name -ErrorAction SilentlyContinue
    Write-Output ("{0}: {1} (Startup={2})" -f $svcInfo.Display, $svc.Status, $svc.StartType)
}
