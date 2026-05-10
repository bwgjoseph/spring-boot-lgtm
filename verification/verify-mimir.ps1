param (
    [string]$Env = "dev",
    [string]$Mode = "full"
)

Write-Host "--- Verifying Mimir ($Env Mode: $Mode) ---"

# 1. Deployment Validation
Write-Host "[1/2] Checking Pod Status..."
kubectl rollout status statefulset/mimir-ingester -n monitoring --timeout=60s

# 2. Traffic Simulation
if ($Mode -eq "full") {
    Write-Host "[2/2] Triggering Traffic..."
    pwsh ./verification/trigger-api.ps1
}

Write-Host "Verification Complete."
