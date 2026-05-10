param (
    [string]$Env = "dev",
    [string]$Mode = "full"
)

Write-Host "--- Verifying Prometheus ($Env Mode: $Mode) ---"

# 1. Deployment Validation
Write-Host "[1/4] Checking Pod Status..."
$selector = "app.kubernetes.io/name=prometheus,app.kubernetes.io/instance=prometheus"

# Detect if it's a StatefulSet or Deployment
$statefulSet = kubectl get statefulset -n monitoring -l $selector -o name
$deployment = kubectl get deployment -n monitoring -l $selector -o name

$promComponent = ""
if ($statefulSet) {
    $promComponent = $statefulSet
} elseif ($deployment) {
    $promComponent = $deployment
} else {
    Write-Error "Could not find Prometheus server controller (neither StatefulSet nor Deployment)."
    exit 1
}

kubectl rollout status $promComponent -n monitoring --timeout=180s

# 2. Configuration Audit
Write-Host "[2/4] Auditing Scrape Configuration..."
try {
    $configCheck = kubectl get cm prometheus-server -n monitoring -o yaml | Select-String "scrape_configs"
    if ($configCheck) {
        Write-Host "  - Prometheus scrape_configs found."
    } else {
        Write-Warning "  - Could not verify scrape_configs in prometheus-server ConfigMap."
    }
} catch {
    Write-Warning "  - Could not find Prometheus configuration."
}

# 3. Alerting Rules Audit
Write-Host "[3/4] Auditing Alerting Rules..."
$alertRules = kubectl get cm prometheus-alert-rules -n monitoring -o yaml | Select-String "sandbox_alerts"
if ($alertRules) {
    Write-Host "  - [✓] Alerting rules found in prometheus-alert-rules ConfigMap."
} else {
    Write-Warning "  - Alerting rules not found in prometheus-alert-rules ConfigMap."
}

# 4. Backend/Storage Audit
Write-Host "[4/4] Verifying TSDB Persistence..."
$podNames = [string[]](kubectl get pods -n monitoring -l $selector -o name)
if ($null -eq $podNames -or $podNames.Length -eq 0) {
    $podNames = [string[]](kubectl get pods -n monitoring -l app=prometheus-server -o name)
}

if ($podNames) {
    $promPod = $podNames[0].Split('/')[-1]
    $tsdbCheck = kubectl exec -n monitoring $promPod -c prometheus-server -- ls /data/wal 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  - [✓] Prometheus TSDB WAL found."
    } else {
        Write-Warning "  - Prometheus TSDB WAL not accessible (may be empty)."
    }
} else {
    Write-Warning "  - Could not identify Prometheus pod for storage audit."
}

Write-Host "Verification Complete."
