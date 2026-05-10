param (
    [string]$Env = "dev",
    [string]$Mode = "full"
)

Write-Host "--- Verifying Tempo ($Env Mode: $Mode) ---"

# 1. Deployment Validation
Write-Host "[1/3] Checking Pod Status..."
kubectl rollout status statefulset/tempo -n monitoring --timeout=120s

# 2. Traffic Simulation
if ($Mode -eq "full") {
    Write-Host "[2/3] Triggering Traffic..."
    pwsh ./verification/trigger-api.ps1
    Write-Host "  - Waiting 60s for trace flush to S3..."
    Start-Sleep -Seconds 60
}

# 3. Backend/Storage Audit
Write-Host "[3/3] Verifying MinIO persistence..."
$minioPod = (kubectl get pods -n monitoring -l release=minio -o jsonpath='{.items[0].metadata.name}')
if (-not $minioPod) {
    Write-Host "  - Skipping Storage Audit (MinIO pod not found)."
} else {
    Write-Host "  - MinIO detected (pod/$minioPod). Checking S3 blocks in-cluster..."
    $mcOutput = kubectl exec -n monitoring $minioPod -- mc ls local/tempo --recursive --json | ConvertFrom-Json -ErrorAction SilentlyContinue
    
    if ($mcOutput -and $mcOutput.Count -gt 0) { 
        Write-Host "  - [✓] S3 Blocks found ($($mcOutput.Count) items)." 
    } else { 
        Write-Warning "  - No S3 blocks found in 'tempo' bucket." 
    }
}

Write-Host "Verification Complete."
