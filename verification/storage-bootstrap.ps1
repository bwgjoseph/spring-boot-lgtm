param(
    [string]$minioUrl = "http://minio.monitoring.svc:9000"
)

# Wait for MinIO pod to be ready
Write-Host "Waiting for MinIO pods to be ready..." -ForegroundColor Cyan
kubectl wait --for=condition=Ready pod -l release=minio -n monitoring --timeout=120s

# Get the first MinIO pod name
$minioPod = (kubectl get pods -n monitoring -l release=minio -o jsonpath='{.items[0].metadata.name}')
if (-not $minioPod) {
    Write-Error "No MinIO pods found with label release=minio"
    exit 1
}

# Get credentials
# $user = (pwsh -File ./verification/get-secret.ps1 -secretName minio -keyName rootUser).Trim().Replace("`r", "").Replace("`n", "")
# $pass = (pwsh -File ./verification/get-secret.ps1 -secretName minio -keyName rootPassword).Trim().Replace("`r", "").Replace("`n", "")
$user = "admin"
$pass = "password123"

Write-Host "--- Bootstrapping MinIO Storage Buckets via pod/$minioPod ---" -ForegroundColor Cyan

# 1. Set alias
kubectl exec -n monitoring "pod/$minioPod" -- mc alias set local "$minioUrl" "$user" "$pass"

# 2. Create buckets
$buckets = @("loki", "tempo")
foreach ($b in $buckets) {
    Write-Host "Ensuring bucket '$b' exists..." -NoNewline
    kubectl exec -n monitoring "pod/$minioPod" -- mc mb local/$b --ignore-existing
    Write-Host " [OK]" -ForegroundColor Green
}


Write-Host "Storage bootstrap complete." -ForegroundColor Green
