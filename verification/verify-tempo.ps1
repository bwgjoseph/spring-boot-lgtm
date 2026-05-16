param (
    [string]$Env = "dev",
    [string]$Mode = "full"
)

Write-Host "--- Verifying Tempo ($Env Mode: $Mode) ---" -ForegroundColor Cyan

# Detection
# In the current dev setup, the statefulset is named 'tempo'. 
# In scalable mode, we expect separate read/write components.
# Detection
$tempoPods = kubectl get pods -n monitoring -l app.kubernetes.io/name=tempo -o name
$isScalable = ($tempoPods.Length -gt 1)
$mode = if ($isScalable) { "scalable-monolithic" } else { "single-binary" }

Write-Host "  - Detected Topology: $mode"

# 1. Health
$comp = if ($isScalable) { "statefulset/tempo" } else { "statefulset/tempo" }
kubectl rollout status $comp -n monitoring --timeout=60s

# 2. Traffic Simulation
if ($Mode -eq "full") {
    Write-Host "  - Triggering Traffic..."
    & ./verification/trigger-api.ps1
    Start-Sleep -Seconds 5
}

# 3. Memberlist / Ring check
if ($isScalable) {
    $pod = kubectl get pods -n monitoring -l app.kubernetes.io/name=tempo -o name | Select-Object -First 1
    # Check ring status using wget if available, or just check pod readiness
    $ring = kubectl exec -n monitoring $pod -- wget -qO- http://localhost:3200/ring 2>$null | Select-String "HEALTHY"
    if ($ring) { Write-Host "  - [✓] Memberlist Ring: Healthy." } else { Write-Warning "  - Memberlist Ring: Unhealthy (check manually)." }
}

# 4. S3 check
$minioPod = (kubectl get pods -n monitoring -l release=minio -o name | Select-Object -First 1)
$bucketExists = kubectl exec -n monitoring $minioPod -- mc ls local/tempo --quiet
if ($LASTEXITCODE -eq 0) {
    Write-Host "  - [✓] S3 Backend healthy."
} else {
    Write-Warning "  - S3 Backend check failed."
}

Write-Host "Verification Complete." -ForegroundColor Green
