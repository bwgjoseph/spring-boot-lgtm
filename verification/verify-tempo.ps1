param (
    [string]$Env = "dev",
    [string]$Mode = "full"
)

Write-Host "--- Verifying Tempo ($Env Mode: $Mode) ---" -ForegroundColor Cyan

# Detection
# In the current dev setup, the statefulset is named 'tempo'. 
# In scalable mode, we expect separate read/write components.
$isScalable = (kubectl get deployment -n monitoring -l app.kubernetes.io/component=query-frontend -o name).Length -gt 0
$mode = if ($isScalable) { "scalable-monolithic" } else { "single-binary" }

Write-Host "  - Detected Topology: $mode"

# 1. Health
$comp = if ($isScalable) { "deployment/tempo-query-frontend" } else { "statefulset/tempo" }
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
    $ring = kubectl exec -n monitoring $pod -- curl -s http://localhost:3200/ring | Select-String "HEALTHY"
    if ($ring) { Write-Host "  - [✓] Memberlist Ring: Healthy." } else { Write-Warning "  - Memberlist Ring: Unhealthy." }
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
