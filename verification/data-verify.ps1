param([string]$testId)

$report = @"
# 🧪 E2E Observability Verification Report
**Test ID:** $testId
**Timestamp:** $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

| Component | Test Case | Result | Details |
| :--- | :--- | :--- | :--- |
"@

function Add-Result($comp, $case, $res, $details) {
    $color = if ($res -eq "PASS") { "Green" } else { "Red" }
    Write-Host "[$res] ${comp}: $case" -ForegroundColor $color
    $global:report += "`n| $comp | $case | $res | $details |"
}

Write-Host "`n--- Starting Data Verification (TestID: $testId) ---" -ForegroundColor Cyan

# Use the app pod as it has wget
$queryPod = kubectl get pods -n monitoring -l app=spring-boot-app -o jsonpath='{.items[0].metadata.name}'

# Fully Qualified Domain Names for reliability
$promSvc = "http://prometheus-server.monitoring.svc.cluster.local"
$lokiSvc = "http://loki-gateway.monitoring.svc.cluster.local"
$tempoSvc = "http://tempo.monitoring.svc.cluster.local:3200"

# Wait for ingestion (30s)
Write-Host "Waiting 30 seconds for data ingestion..."
Start-Sleep -Seconds 30

# 1. Verify Metrics (Prometheus)
Write-Host "Verifying Metrics..."
$promResult = kubectl exec $queryPod -n monitoring -- wget -qO- "$promSvc/api/v1/query?query=debezium_total_number_of_events_seen" | jq -r '.data.result[0].value[1]'
if ($promResult -and $promResult -ne "null" -and $promResult -gt 0) {
    Add-Result "Prometheus" "Debezium CDC Metrics" "PASS" "Events seen: $promResult"
} else {
    Add-Result "Prometheus" "Debezium CDC Metrics" "FAIL" "No events found"
}

# 2. Verify Logs (Loki)
Write-Host "Verifying Logs..."
$lokiQuery = '{service_name="spring-boot-app"} |= "$testId"'
$lokiResult = kubectl exec $queryPod -n monitoring -- wget -qO- "$lokiSvc/loki/api/v1/query_range?query=$([uri]::EscapeDataString($lokiQuery))" | jq -r '.data.result | length'
if ($lokiResult -and $lokiResult -ne "null" -and $lokiResult -gt 0) {
    Add-Result "Loki" "Log Capture & Correlation" "PASS" "Found $lokiResult logs with TestID"
} else {
    Add-Result "Loki" "Log Capture & Correlation" "FAIL" "No logs found for TestID"
}

# 3. Verify Traces (Tempo)
Write-Host "Verifying Traces..."
# We search for any trace from the app in the last 5 mins
$tempoResult = kubectl exec $queryPod -n monitoring -- wget -qO- "$tempoSvc/api/search?tags=service.name=spring-boot-app&limit=1" | jq -r '.traces | length'
if ($tempoResult -and $tempoResult -ne "null" -and $tempoResult -gt 0) {
    Add-Result "Tempo" "Distributed Tracing" "PASS" "Successfully captured recent traces"
} else {
    Add-Result "Tempo" "Distributed Tracing" "FAIL" "No traces found"
}

# 4. Verify Enrichment (k8s metadata)
Write-Host "Verifying Enrichment..."
$traceId = kubectl exec $queryPod -n monitoring -- wget -qO- "$tempoSvc/api/search?tags=service.name=spring-boot-app&limit=1" | jq -r '.traces[0].traceID'
if ($traceId -and $traceId -ne "null") {
    $enrichment = kubectl exec $queryPod -n monitoring -- wget -qO- "$tempoSvc/api/traces/$traceId" | jq -r '.. | select(.key? == "k8s.pod.name") | .value.stringValue'
    if ($enrichment -and $enrichment -ne "null") {
        Add-Result "Alloy" "K8s Infrastructure Enrichment" "PASS" "Pod metadata found: $enrichment"
    } else {
        Add-Result "Alloy" "K8s Infrastructure Enrichment" "FAIL" "k8s attributes missing in spans"
    }
} else {
     Add-Result "Alloy" "K8s Infrastructure Enrichment" "FAIL" "Could not find a trace ID to check enrichment"
}

# Save Report
$global:report | Out-File -FilePath "VERIFICATION_REPORT.md" -Encoding utf8
Write-Host "`nReport generated: VERIFICATION_REPORT.md" -ForegroundColor Cyan
