param (
    [string]$Env = "dev",
    [string]$Mode = "full"
)

Write-Host "--- Verifying Loki ($Env Mode: $Mode) ---"

# 1. Detect Topology & Resources
$lokiComponents = @("write", "read", "backend")
$isSimpleScalable = (kubectl get deployment -n monitoring -l app.kubernetes.io/component=read 2>$null).Length -gt 0 -or (kubectl get statefulset -n monitoring -l app.kubernetes.io/component=read 2>$null).Length -gt 0

Write-Host "  - Detected Topology: $(if ($isSimpleScalable) { 'SimpleScalable' } else { 'SingleBinary' })"

# 2. Deployment/StatefulSet Validation
Write-Host "[1/4] Checking Pod Status..."
if ($isSimpleScalable) {
    foreach ($comp in $lokiComponents) {
        # Check deployment first
        $resource = kubectl get deployment -n monitoring -l app.kubernetes.io/component=$comp -o name 2>$null
        
        # If not found, check statefulset
        if (-not $resource) {
            $resource = kubectl get statefulset -n monitoring -l app.kubernetes.io/component=$comp -o name 2>$null
        }
        
        if ($resource) {
            Write-Host "  - Validating $resource..."
            kubectl rollout status $resource -n monitoring --timeout=60s
        } else {
            Write-Warning "  - Could not find Loki component: $comp"
        }
    }
} else {
    kubectl rollout status statefulset/loki -n monitoring --timeout=60s
}

# 3. Configuration Audit
Write-Host "[2/4] Auditing Configuration..."
try {
    $configMapName = "loki"
    $configCheck = kubectl get cm $configMapName -n monitoring -o yaml | Select-String "retention_period"
    Write-Host "  - Retention Config found: $($configCheck.Matches.Value)"
} catch {
    Write-Warning "  - Could not find retention configuration in ConfigMap: $configMapName"
}

# 4. Traffic Simulation
if ($Mode -eq "full") {
    Write-Host "[3/4] Triggering Traffic..."
    pwsh ./verification/trigger-api.ps1
    Write-Host "  - Waiting 60s for log flush to S3..."
    Start-Sleep -Seconds 60
}

# 5. Backend/Storage Audit
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
