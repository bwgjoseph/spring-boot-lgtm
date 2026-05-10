# Validates MongoDB connectivity and status
$mongoPod = (kubectl get pods -n monitoring -l app.kubernetes.io/instance=mongodb -o name | Select-Object -First 1).Split('/')[-1]
if (-not $mongoPod) {
    Write-Error "Could not find MongoDB pod."
    exit 1
}

Write-Host "Waiting for MongoDB pod '$mongoPod' to be ready..."
kubectl wait --for=condition=Ready pod/$mongoPod -n monitoring --timeout=120s

Write-Host "Validating MongoDB health in pod: $mongoPod with retries..."
$maxRetries = 10
$retryCount = 0
$success = $false

while ($retryCount -lt $maxRetries) {
    # Explicitly use absolute path and target the 'mongodb' container
    # We use localhost but allow for startup delay
    kubectl exec -n monitoring $mongoPod -c mongodb -- /opt/bitnami/mongodb/bin/mongosh admin -u admin -p password --quiet --eval "db.adminCommand({ping: 1})" 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "MongoDB is healthy."
        $success = $true
        break
    } else {
        $retryCount++
        Write-Host "MongoDB not accepting connections yet... retrying ($retryCount/$maxRetries)"
        Start-Sleep -Seconds 5
    }
}

if (-not $success) {
    Write-Error "MongoDB health check failed after $maxRetries retries."
    exit 1
}
