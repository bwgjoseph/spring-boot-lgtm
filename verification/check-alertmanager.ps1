# Validates the Alertmanager configuration
$amPod = (kubectl get pods -n monitoring -l app.kubernetes.io/name=alertmanager,app.kubernetes.io/instance=prometheus -o name | Select-Object -First 1).Split('/')[-1]
if (-not $amPod) {
    Write-Error "Could not find Alertmanager pod."
    exit 1
}

Write-Host "Validating Alertmanager config in pod: $amPod"
# The config file is located at /etc/alertmanager/alertmanager.yml
kubectl exec -n monitoring $amPod -c alertmanager -- /bin/amtool check-config /etc/alertmanager/alertmanager.yml
if ($LASTEXITCODE -eq 0) { Write-Host "Alertmanager configuration valid." } else { Write-Error "Alertmanager configuration invalid."; exit 1 }
