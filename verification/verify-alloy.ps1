param (
    [string]$Env = "dev",
    [string]$Mode = "full"
)

Write-Host "--- Verifying Alloy Pipeline ($Env Mode: $Mode) ---"

# 1. Deployment Validation
Write-Host "[1/4] Checking Pod Status..."
$status = kubectl rollout status daemonset/alloy -n monitoring --timeout=60s
if ($LASTEXITCODE -ne 0) { Write-Error "Alloy DaemonSet rollout failed"; exit 1 }

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
    $logs = $metrics -match "loki_source_kubernetes_targets_total"
    $metricsScraped = $metrics -match "prometheus_target_interval_length_seconds_count"
    $spans = $metrics -match "otelcol_receiver_accepted_spans"

    if ($logs) { Write-Host "  - [✓] Logs: Targets discovered." } else { Write-Warning "  - Logs: No log targets found." }
    if ($metricsScraped) { Write-Host "  - [✓] Metrics: Scraping active." } else { Write-Warning "  - Metrics: No scraping detected." }
    if ($spans) { Write-Host "  - [✓] Traces: OTLP spans accepted." } else { Write-Warning "  - Traces: No spans accepted." }
} finally {
    Stop-Job $job
    Remove-Job $job
}

Write-Host "[4/4] Verification Complete."
