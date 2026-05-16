param (
    [string]$Env = "dev",
    [string]$Mode = "full"
)

Write-Host "--- Verifying Loki ($Env Mode: $Mode) ---"

# Detect Topology
$isSimpleScalable = (kubectl get deployment -n monitoring -l app.kubernetes.io/component=write -o name).Length -gt 0
$mainComponent = if ($isSimpleScalable) { "deployment/loki-write" } else { "statefulset/loki" }
$configMapName = if ($isSimpleScalable) { "loki-config" } else { "loki" }

Write-Host "  - Detected Topology: $(if ($isSimpleScalable) { 'SimpleScalable' } else { 'SingleBinary' })"

# 1. Deployment Validation
Write-Host "[1/4] Checking Pod Status..."
if ($isSimpleScalable) {
    kubectl rollout status deployment/loki-write -n monitoring --timeout=60s
    kubectl rollout status deployment/loki-read -n monitoring --timeout=60s
    kubectl rollout status deployment/loki-backend -n monitoring --timeout=60s
} else {
    kubectl rollout status statefulset/loki -n monitoring --timeout=60s
}

# 2. Configuration Audit
Write-Host "[2/4] Auditing Configuration..."
try {
    $configCheck = kubectl get cm $configMapName -n monitoring -o yaml | Select-String "retention_period"
    Write-Host "  - Retention Config found: $($configCheck.Matches.Value)"
} catch {
    Write-Warning "  - Could not find retention configuration in ConfigMap: $configMapName"
}

# 3. Traffic Simulation
if ($Mode -eq "full") {
    Write-Host "[3/4] Triggering Traffic..."
    pwsh ./verification/trigger-api.ps1
    Write-Host "  - Waiting 60s for log flush to S3..."
    Start-Sleep -Seconds 60
}

# 4. Backend/Storage Audit
Write-Host "[4/4] Verifying Backend Persistence..."
$minioPod = (kubectl get pods -n monitoring -l release=minio -o jsonpath='{.items[0].metadata.name}')
if (-not $minioPod) {
    Write-Host "  - Skipping Storage Audit (MinIO pod not found)."
} else {
    Write-Host "  - MinIO detected (pod/$minioPod). Checking S3 chunks in-cluster..."
    
    # Run mc ls inside the MinIO pod
    # We check the root of the loki bucket because with TSDB and no-auth, 
    # Loki stores objects under the 'fake/' prefix, not a 'chunks/' folder.
    $mcOutput = kubectl exec -n monitoring $minioPod -- mc ls local/loki --recursive --json | ConvertFrom-Json -ErrorAction SilentlyContinue
    
    if ($mcOutput -and $mcOutput.Count -gt 0) { 
        Write-Host "  - [✓] S3 Data found ($($mcOutput.Count) items)." 
    } else { 
        Write-Warning "  - No data found in 'loki' bucket." 
    }
}

Write-Host "Verification Complete."
