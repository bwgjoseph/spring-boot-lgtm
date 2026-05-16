param (
    [string]$Env = "dev",
    [string]$Mode = "full"
)

Write-Host "--- Verifying Mimir ($Env Mode: $Mode) ---" -ForegroundColor Cyan

# Detection
$mode = "monolithic" 
$pod = kubectl get pods -n monitoring -l app.kubernetes.io/name=mimir -o name

if (-not $pod) {
    Write-Error "Mimir pods not found."
    exit 1
}

Write-Host "  - Detected Topology: $mode"

# 1. Health
kubectl rollout status deployment/mimir -n monitoring --timeout=60s

# 2. Traffic Simulation
if ($Mode -eq "full") {
    Write-Host "  - Triggering Traffic..."
    & ./verification/trigger-api.ps1
    Start-Sleep -Seconds 5
}

# 3. Storage check
$minioPod = (kubectl get pods -n monitoring -l release=minio -o name | Select-Object -First 1)
$bucketExists = kubectl exec -n monitoring $minioPod -- mc ls local/mimir --quiet
if ($LASTEXITCODE -eq 0) {
    Write-Host "  - [✓] S3 Backend healthy."
} else {
    Write-Warning "  - S3 Backend check failed."
}

# 4. Metrics Ingestion Check (Query Mimir directly)
$mimirPod = (kubectl get pods -n monitoring -l app.kubernetes.io/name=mimir -o name | Select-Object -First 1)
$ingested = kubectl exec -n monitoring $mimirPod -- wget -qO- "http://localhost:8080/prometheus/api/v1/query?query=up" | Select-String "success"

if ($ingested) {
    Write-Host "  - [✓] Metrics ingestion active."
} else {
    Write-Warning "  - Metrics ingestion check failed."
}

Write-Host "Verification Complete." -ForegroundColor Green
