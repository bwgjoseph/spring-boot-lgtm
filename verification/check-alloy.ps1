$alloyPod = (kubectl get pods -n monitoring -l "app.kubernetes.io/name in (alloy, k8s-monitoring-alloy)" -o name 2>$null | Select-Object -First 1)
if (-not $alloyPod) {
    # Fallback to checking any pod with alloy in name
    $alloyPod = (kubectl get pods -n monitoring -o name | Select-String "alloy" | Select-Object -First 1)
}
if ($alloyPod) { $alloyPod = $alloyPod.Split('/')[-1] }
if (-not $alloyPod) {
    Write-Error "Could not find Alloy pod."
    exit 1
}

Write-Host "Waiting for Alloy pod '$alloyPod' to be ready..."
kubectl wait --for=condition=Ready pod/$alloyPod -n monitoring --timeout=120s

Write-Host "Validating Alloy config in pod: $alloyPod"

# Explicitly target the 'alloy' container
# Using a small retry loop for the exec command to handle transient "container not found" errors
$maxRetries = 5
$retryCount = 0
$success = $false

while ($retryCount -lt $maxRetries) {
    kubectl exec -n monitoring $alloyPod -c alloy -- /usr/bin/alloy validate /etc/alloy/config.alloy
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Alloy configuration is valid."
        $success = $true
        break
    } else {
        $retryCount++
        Write-Host "Alloy check failed or container not ready... retrying ($retryCount/$maxRetries)"
        Start-Sleep -Seconds 5
    }
}

if (-not $success) {
    Write-Error "Alloy configuration is INVALID or container unreachable."
    exit 1
}
