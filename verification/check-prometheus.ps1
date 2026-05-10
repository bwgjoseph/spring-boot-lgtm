# Validates the Prometheus Server configuration
# Standardized label selector for prometheus-community/prometheus chart
$selector = "app.kubernetes.io/name=prometheus,app.kubernetes.io/instance=prometheus"
$podNames = [string[]](kubectl get pods -n monitoring -l $selector -o name)
if ($null -eq $podNames -or $podNames.Length -eq 0) {
    # Fallback for old/custom labels
    $podNames = [string[]](kubectl get pods -n monitoring -l app=prometheus-server -o name)
}

if ($null -eq $podNames -or $podNames.Length -eq 0) {
    Write-Error "Could not find Prometheus server pod with selectors: $selector"
    exit 1
}

$promPod = $podNames[0].Split('/')[-1]

Write-Host "Waiting for Prometheus pod '$promPod' to be ready..."
kubectl wait --for=condition=Ready pod/$promPod -n monitoring --timeout=120s

Write-Host "Validating Prometheus config in pod: $promPod"
# Explicitly target the prometheus-server container
kubectl exec -n monitoring $promPod -c prometheus-server -- /bin/promtool check config /etc/config/prometheus.yml
if ($LASTEXITCODE -eq 0) { Write-Host "Prometheus configuration valid." } else { Write-Error "Prometheus configuration invalid."; exit 1 }
