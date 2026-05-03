param([string]$testId)

$report = @"
# 🧪 E2E Observability Verification Report
**Overall Status:** {STATUS}
**Test ID:** $testId
**Timestamp:** $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

## 🏥 Component Health Status
| Component | Status | Details |
| :--- | :--- | :--- |
"@

$global:failed = $false

function Add-Result($table, $comp, $case, $res, $details) {
    $color = if ($res -eq "PASS") { "Green" } else { "Red" }
    if ($res -ne "PASS") { $global:failed = $true }
    
    if ($table -eq "health") {
        $global:report += "`n| $comp | $res | $details |"
    } else {
        $global:report += "`n| $comp | $case | $res | $details |"
    }
}

# 1. Health Checks
Write-Host "--- Performing Health Checks ---" -ForegroundColor Cyan
$namespace = "monitoring"
$resources = @{
    "spring-boot-app" = "app=spring-boot-app"
    "alloy" = "app.kubernetes.io/name=alloy"
    "prometheus" = "app.kubernetes.io/name=prometheus"
    "loki" = "app.kubernetes.io/instance=loki"
    "tempo" = "app.kubernetes.io/name=tempo"
    "mongodb" = "app.kubernetes.io/name=mongodb"
}

foreach ($key in $resources.Keys) {
    $selector = $resources[$key]
    $pod = kubectl get pods -n $namespace -l $selector -o jsonpath='{.items[0].status.phase}' 2>$null
    if ($pod -eq "Running") {
        Add-Result "health" $key "" "PASS" "Pod Running"
    } else {
        Add-Result "health" $key "" "FAIL" "Pod not Running"
    }
}

$global:report += "`n`n## 📊 E2E Data Pipeline Results`n| Component | Test Case | Result | Details |`n| :--- | :--- | :--- | :--- |"

# 2. Data Verification
$queryPod = kubectl get pods -n monitoring -l app=spring-boot-app -o jsonpath='{.items[0].metadata.name}'
$promSvc = "http://prometheus-server.monitoring.svc.cluster.local:80"
$lokiSvc = "http://loki-gateway.monitoring.svc.cluster.local:80"
$tempoSvc = "http://tempo.monitoring.svc.cluster.local:3200"

# Polling function
function Poll-Query($name, $url, $jqFilter) {
    Write-Host "--- Polling $name ---" -ForegroundColor Cyan
    Write-Host "URL: $url" -ForegroundColor Gray

    for ($i = 0; $i -lt 5; $i++) {
        Write-Host "Attempt $($i+1)/5: Querying $name..." -ForegroundColor Gray
        $res = kubectl exec $queryPod -n monitoring -- wget -qO- "$url" 2>$null | jq -r "$jqFilter"
        
        Write-Host "DEBUG: Raw response (jq filter '$jqFilter'):" -ForegroundColor DarkGray
        Write-Host $res -ForegroundColor DarkGray

        if ($res -and $res -ne "null" -and $res -ne "[]" -and $res -ne "0") { 
            Write-Host "Successfully retrieved data from $name." -ForegroundColor Green
            return $res 
        }

        Write-Host "Result empty or invalid, retrying in 10s..." -ForegroundColor Yellow
        Start-Sleep -Seconds 10
    }
    return 0
}


Write-Host "--- Starting Data Verification ---" -ForegroundColor Cyan
Start-Sleep -Seconds 30

# Metrics
$promRes = Poll-Query "Prometheus" "$promSvc/api/v1/query?query=debezium_total_number_of_events_seen{context='streaming'}" '.data.result[0].value[1]'
if ($promRes -gt 0) { Add-Result "data" "Prometheus" "Debezium CDC Metrics" "PASS" "Events: $promRes" } else { Add-Result "data" "Prometheus" "Debezium CDC Metrics" "FAIL" "No events" }

# Logs
$lokiRes = Poll-Query "Loki" "$lokiSvc/loki/api/v1/query_range?query=%7Bservice_name%3D%22spring-boot-app%22%7D%20%7C%3D%20%22$testId%22" '.data.result | length'
if ($lokiRes -gt 0) { Add-Result "data" "Loki" "Log Capture" "PASS" "Logs found" } else { Add-Result "data" "Loki" "Log Capture" "FAIL" "No logs" }

# Traces
$tempoRes = Poll-Query "Tempo" "$tempoSvc/api/search?tags=service.name=spring-boot-app&limit=1" '.traces | length'
if ($tempoRes -gt 0) { Add-Result "data" "Tempo" "Distributed Tracing" "PASS" "Traces found" } else { Add-Result "data" "Tempo" "Distributed Tracing" "FAIL" "No traces" }

$finalStatus = if ($global:failed) { "FAIL" } else { "PASS" }
$report = $report.Replace("{STATUS}", $finalStatus)
# Save Report
$global:report | Out-File -FilePath "verification/logs/VERIFICATION_REPORT.md" -Encoding utf8
Write-Host "`nReport generated: verification/logs/VERIFICATION_REPORT.md" -ForegroundColor Cyan

