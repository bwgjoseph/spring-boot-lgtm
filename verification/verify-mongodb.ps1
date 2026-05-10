param (
    [string]$Env = "dev",
    [string]$Mode = "full"
)

Write-Host "--- Verifying MongoDB ($Env Mode: $Mode) ---"

# 1. Deployment Validation
Write-Host "[1/2] Checking Pod Status..."
kubectl rollout status statefulset/mongodb -n monitoring --timeout=180s
kubectl rollout status statefulset/mongodb-arbiter -n monitoring --timeout=180s

# Ensure pod is fully ready
Write-Host "Waiting for mongodb-0 pod to be ready..."
kubectl wait --for=condition=Ready pod/mongodb-0 -n monitoring --timeout=180s

# 2. Operational Health Check
Write-Host "[2/2] Verifying Replica Set Health..."
$mongoPod = "mongodb-0"
Write-Host "Checking health on $mongoPod..."

# Directly execute mongosh using absolute path
# We give it a moment to initialize
kubectl exec -n monitoring $mongoPod -c mongodb -- /opt/bitnami/mongodb/bin/mongosh admin -u admin -p password --quiet --eval 'db.adminCommand({ping: 1})'
if ($LASTEXITCODE -eq 0) {
    Write-Host "  - [✓] MongoDB Replica Set healthy."
} else {
    Write-Error "  - MongoDB Replica Set unhealthy or unreachable."
    exit 1
}

Write-Host "Verification Complete."
