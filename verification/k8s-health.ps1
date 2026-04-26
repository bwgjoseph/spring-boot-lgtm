$namespace = "monitoring"
$resources = @{
    "deployment/spring-boot-app" = "app=spring-boot-app"
    "daemonset/alloy"            = "app.kubernetes.io/name=alloy"
    "deployment/prometheus-server" = "app.kubernetes.io/name=prometheus"
    "deployment/loki-gateway"    = "app.kubernetes.io/component=gateway"
    "statefulset/tempo"          = "app.kubernetes.io/name=tempo"
    "statefulset/mongodb"        = "app.kubernetes.io/name=mongodb"
}

function Log-Result($msg, $color) {
    Write-Host $msg -ForegroundColor $color
    Add-Content -Path $env:LOG_FILE -Value $msg
}

Log-Result "--- Checking Kubernetes Infrastructure Health (Strict) ---" "Cyan"

foreach ($res in $resources.Keys) {
    $selector = $resources[$res]
    Write-Host "Validating $res with selector '$selector'..." -NoNewline

    # Check for pods
    $podJson = kubectl get pods -n $namespace -l $selector -o json
    $pod = $podJson | jq -r '.items[0]'

    $isReady = $pod | jq -r '.status.containerStatuses[0].ready'
    $restarts = $pod | jq -r '.status.containerStatuses[0].restartCount'

    if ($isReady -eq "true" -and [int]$restarts -lt 20) {
        Log-Result " [PASS]" "Green"
        Add-Content -Path $env:LOG_FILE -Value "   -> Pod Ready, Restarts: $restarts."
    } else {
        Log-Result " [FAIL]" "Red"
        Add-Content -Path $env:LOG_FILE -Value "   -> Pod not Ready (Ready: $isReady, Restarts: $restarts)."
        exit 1
    }
}

