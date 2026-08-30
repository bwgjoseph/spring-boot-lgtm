param([string]$dashboardsDir = "deployment/common/dashboards")
$namespace = "monitoring"

Write-Host "--- Syncing Dashboard Folders to K8s ---" -ForegroundColor Cyan

# 1. Process subdirectories (folders)
Get-ChildItem -Path "$dashboardsDir" -Directory | ForEach-Object {
    $folderName = $_.Name
    $displayFolder = switch ($folderName.ToLower()) {
        "k8s"   { "K8s" }
        "tempo" { "Tempo" }
        default { (Get-Culture).TextInfo.ToTitleCase($folderName) }
    }
    $cmName = "grafana-dash-" + $folderName.ToLower().Replace(" ", "-")
    
    Write-Host "Syncing folder: $folderName ($displayFolder) to ConfigMap: $cmName..." -NoNewline
    
    kubectl create configmap $cmName --from-file=$($_.FullName) -n $namespace --dry-run=client -o yaml | kubectl apply -f - --server-side --force-conflicts | Out-Null
    kubectl label configmap $cmName grafana_dashboard=1 -n $namespace --overwrite | Out-Null
    
    # Annotate for sidecar to create the folder
    kubectl annotate configmap $cmName grafana_folder=$displayFolder -n $namespace --overwrite | Out-Null
    
    Write-Host " [PASS]" -ForegroundColor Green
}

# 2. Handle files in the root folder
$rootFiles = Get-ChildItem -Path "$dashboardsDir" -File -Filter *.json
if ($rootFiles.Count -gt 0) {
    Write-Host "Syncing root dashboard files to ConfigMap: grafana-dash-default..." -NoNewline
    $cmName = "grafana-dash-default"
    
    $fromFileArgs = $rootFiles | ForEach-Object { "--from-file=" + $_.FullName }
    kubectl create configmap $cmName $fromFileArgs -n $namespace --dry-run=client -o yaml | kubectl apply -f - --server-side --force-conflicts | Out-Null
    kubectl label configmap $cmName grafana_dashboard=1 -n $namespace --overwrite | Out-Null
    kubectl annotate configmap $cmName grafana_folder=Default -n $namespace --overwrite | Out-Null
    
    Write-Host " [PASS]" -ForegroundColor Green
}
