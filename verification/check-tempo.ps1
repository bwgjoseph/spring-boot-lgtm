# Validates the Tempo distributor pod readiness using K8s native probes
$tempoPod = (kubectl get pods -n monitoring -l app.kubernetes.io/instance=tempo,app.kubernetes.io/component=distributor -o name | Select-Object -First 1).Split('/')[-1]
if (-not $tempoPod) {
    # Fallback to any tempo instance pod
    $tempoPod = (kubectl get pods -n monitoring -l app.kubernetes.io/instance=tempo -o name | Select-Object -First 1).Split('/')[-1]
}
if (-not $tempoPod) {
    Write-Error "Could not find Tempo pod."
    exit 1
}

Write-Host "Waiting for Tempo pod '$tempoPod' to reach Ready state..."
kubectl wait --for=condition=Ready pod/$tempoPod -n monitoring --timeout=120s

if ($LASTEXITCODE -eq 0) { 
    Write-Host "Tempo pod is ready." 
} else { 
    Write-Error "Tempo pod failed to reach Ready state."; exit 1 
}
