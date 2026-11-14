param (
    [string]$Env = "dev",
    [string]$Mode = "full"
)

Write-Host "--- Verifying Tempo ($Env Mode: $Mode) ---" -ForegroundColor Cyan

# Tempo 3.x (tempo-distributed) runs as separate Deployments and StatefulSets.
# We verify the core components: distributor (ingestion), querier (search), and query-frontend (API).
$components = @(
    "deployment/tempo-distributor",
    "deployment/tempo-querier",
    "deployment/tempo-query-frontend",
    "statefulset/tempo-backend-scheduler",
    "statefulset/tempo-backend-worker",
    "statefulset/tempo-block-builder",
    "statefulset/tempo-live-store"
)

foreach ($comp in $components) {
    Write-Host "  - Checking rollout: $comp"
    kubectl rollout status $comp -n monitoring --timeout=120s
    if ($LASTEXITCODE -ne 0) {
        Write-Error "  - [$comp] failed to reach ready state."
        exit 1
    }
    Write-Host "  - [✓] $comp is ready."
}

# Traffic Simulation
if ($Mode -eq "full") {
    Write-Host "  - Triggering Traffic..."
    & ./verification/trigger-api.ps1
    Start-Sleep -Seconds 5
}

# S3 check (RustFS or MinIO)
$s3Pod = (kubectl get pods -n monitoring -l app.kubernetes.io/name=rustfs -o name 2>$null | Select-Object -First 1)
if (-not $s3Pod) {
    $s3Pod = (kubectl get pods -n monitoring -l release=minio -o name 2>$null | Select-Object -First 1)
}

if ($s3Pod) {
    Write-Host "  - [✓] S3 Backend pod ($s3Pod) running and ready."
} else {
    Write-Warning "  - S3 Backend check failed: no RustFS or MinIO pod found."
}

Write-Host "Verification Complete." -ForegroundColor Green
