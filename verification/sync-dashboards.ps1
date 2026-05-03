$namespace = "monitoring"
$deployDir = "deployment"

Write-Host "--- Syncing Dashboards to K8s ---" -ForegroundColor Cyan

Get-ChildItem -Path "$deployDir/dashboards" -Filter *.json | ForEach-Object {
    $name = "dash-" + $_.BaseName.ToLower().Replace(" ", "-")
    Write-Host "Syncing dashboard: $name..." -NoNewline
    
    kubectl create configmap $name --from-file=$($_.FullName) -n $namespace --dry-run=client -o yaml | kubectl apply -f - | Out-Null
    kubectl label configmap $name grafana_dashboard=1 -n $namespace --overwrite | Out-Null
    
    Write-Host " [PASS]" -ForegroundColor Green
}
