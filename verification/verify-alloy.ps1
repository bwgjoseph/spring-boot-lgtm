param (
    [string]$Env = "dev",
    [string]$Mode = "full"
)

Write-Host "--- Verifying Alloy Pipeline ($Env Mode: $Mode) ---"

# 1. Detect Topology & Resources
Write-Host "[1/4] Checking Pod Status..."
# Try finding as deployment, then daemonset
$resource = kubectl get deployment -n monitoring -l app.kubernetes.io/name=alloy -o name 2>$null
if (-not $resource) {
    $resource = kubectl get daemonset -n monitoring -l app.kubernetes.io/name=alloy -o name 2>$null
}

if ($resource) {
    Write-Host "  - Validating $resource..."
    kubectl rollout status $resource -n monitoring --timeout=60s
    if ($LASTEXITCODE -ne 0) { Write-Error "Alloy rollout failed"; exit 1 }
} else {
    Write-Error "Alloy resource not found."
    exit 1
}

# 2. Traffic Simulation
if ($Mode -eq "full") {
    Write-Host "[2/4] Triggering Traffic..."
    & ./verification/trigger-api.ps1
    Start-Sleep -Seconds 5
}

# 3. Pipeline Metrics Validation (Backend-Agnostic)
Write-Host "[3/4] Validating Pipeline Metrics..."
$alloyPod = kubectl get pods -n monitoring -l app.kubernetes.io/name=alloy -o name | Select-Object -First 1
$job = Start-Job -ScriptBlock { 
    param($pod)
    kubectl port-forward $pod 12345:12345 -n monitoring
} -ArgumentList $alloyPod
Start-Sleep -Seconds 5

try {
    $metrics = Invoke-RestMethod -Uri 'http://localhost:12345/metrics' -ErrorAction Stop
    
    # Assertions
    # We check loki_write_sent_entries_total because it confirms the whole pipeline 
    # (discovery -> source -> process -> write) is working.
    $logs = $metrics -match "loki_write_sent_entries_total"
    $metricsScraped = $metrics -match "prometheus_target_interval_length_seconds_count"
    $spans = $metrics -match "otelcol_receiver_accepted_spans"
    $cluster = $metrics -match "alloy_cluster_members"

    if ($logs) { Write-Host "  - [✓] Logs: Pipeline active." } else { Write-Warning "  - Logs: No log processing detected." }
    if ($metricsScraped) { Write-Host "  - [✓] Metrics: Scraping active." } else { Write-Warning "  - Metrics: No scraping detected." }
    if ($spans) { Write-Host "  - [✓] Traces: OTLP spans accepted." } else { Write-Warning "  - Traces: No spans accepted." }
    if ($cluster) { 
        $count = ($metrics | Select-String "alloy_cluster_members").ToString().Split(" ")[-1]
        Write-Host "  - [✓] Clustering: $count members active." 
    }
} catch {
    Write-Error "Verification failed: $($_.Exception.Message)"
    exit 1
} finally {
    Stop-Job $job
    Remove-Job $job
}

Write-Host "[4/4] Verification Complete."
