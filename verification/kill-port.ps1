param([int]$port)

$p = (Get-NetTCPConnection -LocalPort $port -ErrorAction SilentlyContinue).OwningProcess
if ($p) {
    try {
        Stop-Process -Id $p -Force
        Write-Host "Successfully killed process (PID: $p) on port $port" -ForegroundColor Green
    } catch {
        Write-Host "Failed to kill process on port $port" -ForegroundColor Red
    }
} else {
    Write-Host "No active port-forward found on port $port" -ForegroundColor Gray
}
