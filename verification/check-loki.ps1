# Validates the Loki configuration
# Supports both SimpleScalable (loki-write) and SingleBinary (loki) topologies
$isSimpleScalable = (kubectl get statefulset -n monitoring -l app.kubernetes.io/component=write -o name).Length -gt 0
$podSelector = if ($isSimpleScalable) { "app.kubernetes.io/component=write" } else { "app.kubernetes.io/name=loki" }

$podNames = [string[]](kubectl get pods -n monitoring -l $podSelector -o name)
if ($null -eq $podNames -or $podNames.Length -eq 0) {
    Write-Error "Could not find Loki pod with selector: $podSelector"
    exit 1
}

$lokiPod = $podNames[0].Split('/')[-1]

Write-Host "Waiting for Loki pod '$lokiPod' to be ready..."
kubectl wait --for=condition=Ready pod/$lokiPod -n monitoring --timeout=120s

Write-Host "Validating Loki config in pod: $lokiPod"
# Path to config in loki charts is standard
kubectl exec -n monitoring $lokiPod -- /usr/bin/loki --config.file=/etc/loki/config/config.yaml --verify-config
if ($LASTEXITCODE -eq 0) { Write-Host "Loki configuration valid." } else { Write-Error "Loki configuration invalid."; exit 1 }
