$namespace = "monitoring"

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

Log-Result "--- Checking Kubernetes Infrastructure Health (Deterministic) ---" "Cyan"

foreach ($res in $resources.Keys) {
    $selector = $resources[$res]
    Write-Host "Validating $res with selector '$selector'..." -NoNewline

    $podList = kubectl get pods -n $namespace -l $selector -o json
    $runningPods = $podList | jq -r '.items[] | select(.status.phase == "Running")'

    if ($runningPods) {
        Log-Result " [PASS]" "Green"
        Add-Content -Path $env:LOG_FILE -Value "   -> Found active pod(s)."
    } else {
        Log-Result " [FAIL]" "Red"
        Add-Content -Path $env:LOG_FILE -Value "   -> No Running pods found."
        exit 1
    }
}

