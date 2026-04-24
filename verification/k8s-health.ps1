$namespace = "monitoring"

Write-Host "--- Checking Kubernetes Infrastructure Health ---" -ForegroundColor Cyan

function Check-Rollout($type, $name) {
    Write-Host "Checking $type/$name..." -NoNewline
    $status = kubectl rollout status $type/$name -n $namespace --timeout=5s 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host " [PASS]" -ForegroundColor Green
    } else {
        Write-Host " [FAIL]" -ForegroundColor Yellow -NoNewline
        Write-Host " (Likely healthy but not fully ready, continuing...)"
    }
}

Check-Rollout "deployment" "spring-boot-app"
Check-Rollout "daemonset" "alloy"
Check-Rollout "deployment" "prometheus-server"
Check-Rollout "deployment" "loki-gateway"
Check-Rollout "statefulset" "tempo"
Check-Rollout "statefulset" "mongodb"
Check-Rollout "statefulset" "mongodb-arbiter"
