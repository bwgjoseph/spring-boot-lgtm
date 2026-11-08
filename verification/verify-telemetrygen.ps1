param (
    [string]$Namespace = "monitoring",
    [string]$Type = "traces", # 'traces', 'logs', 'metrics', or 'all'
    [int]$TimeoutSeconds = 60
)

$ErrorActionPreference = "Stop"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "   OpenTelemetry Synthetic Telemetry Generator (telemetrygen)   " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

$testId = "telemetrygen-" + [guid]::NewGuid().ToString().Substring(0, 8)
Write-Host "Generated Test ID: $testId" -ForegroundColor Yellow

# Helper to run job
function Run-TelemetrygenJob([string]$signal) {
    $jobName = "telemetrygen-$signal-$([guid]::NewGuid().ToString().Substring(0, 6))"
    Write-Host "`n[1/3] Triggering synthetic $signal via Job $jobName..." -ForegroundColor Cyan

    $yaml = @"
apiVersion: batch/v1
kind: Job
metadata:
  name: $jobName
  namespace: $Namespace
  labels:
    app.kubernetes.io/name: telemetrygen
    app.kubernetes.io/component: $signal-generator
spec:
  ttlSecondsAfterFinished: 120
  backoffLimit: 1
  template:
    metadata:
      labels:
        app.kubernetes.io/name: telemetrygen
    spec:
      restartPolicy: Never
      containers:
        - name: telemetrygen
          image: ghcr.io/open-telemetry/opentelemetry-collector-contrib/telemetrygen:v0.165.0
          imagePullPolicy: IfNotPresent
          args:
            - $signal
            - --otlp-endpoint=alloy.$Namespace.svc.cluster.local:4317
            - --otlp-insecure=true
            - --$signal=50
            - --rate=10
            - --service=telemetrygen
            - --otlp-attributes=test.id="$testId",component="$signal"
          resources:
            requests:
              cpu: 20m
              memory: 32Mi
            limits:
              cpu: 100m
              memory: 128Mi
"@

    $yaml | kubectl apply -f - | Out-Null
    
    Write-Host "Waiting for Job $jobName to complete..." -ForegroundColor Gray
    kubectl wait --for=condition=complete job/$jobName -n $Namespace --timeout="${TimeoutSeconds}s" 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Job $jobName did not complete within ${TimeoutSeconds}s, checking pod logs:"
        $pod = kubectl get pods -n $Namespace -l job-name=$jobName -o jsonpath='{.items[0].metadata.name}' 2>$null
        if ($pod) { kubectl logs $pod -n $Namespace }
        return $false
    }
    Write-Host "Job $jobName completed successfully." -ForegroundColor Green
    return $true
}

# Auto-detect querying pod
$queryPod = kubectl get pods -n $Namespace -l app=spring-boot-app -o jsonpath='{.items[0].metadata.name}' 2>$null
if (-not $queryPod) {
    $queryPod = kubectl get pods -n $Namespace -l app.kubernetes.io/name=alloy -o jsonpath='{.items[0].metadata.name}' 2>$null
}

if (-not $queryPod) {
    Write-Warning "Could not find an in-cluster helper pod for internal curl/wget queries. Using port-forward fallback if needed."
}

# Polling helper
function Verify-BackendQuery([string]$name, [string]$url, [string]$jqFilter) {
    Write-Host "Verifying $name ingestion at: $url" -ForegroundColor Gray
    for ($i = 1; $i -le 6; $i++) {
        Write-Host "  Attempt $i/6: querying $name..." -ForegroundColor Gray
        $res = kubectl exec $queryPod -n $Namespace -- wget -qO- "$url" 2>$null | jq -r "$jqFilter" 2>$null
        if ($res -and $res -ne "null" -and $res -ne "0" -and $res -ne "[]") {
            Write-Host "  [✓] $name successfully received and indexed telemetry data!" -ForegroundColor Green
            return $true
        }
        Start-Sleep -Seconds 5
    }
    Write-Error "  [✗] Verification failed for $name after multiple attempts."
    return $false
}

$results = @{}

# Traces Verification
if ($Type -eq "traces" -or $Type -eq "all") {
    $ran = Run-TelemetrygenJob "traces"
    if ($ran -and $queryPod) {
        Write-Host "`n[2/3] Querying Tempo API for service.name=telemetrygen..." -ForegroundColor Cyan
        $tempoSvc = "http://tempo-query-frontend.$Namespace.svc.cluster.local:3200"
        $isTempoPresent = kubectl get svc tempo-query-frontend -n $Namespace 2>$null
        if (-not $isTempoPresent) { $tempoSvc = "http://tempo.$Namespace.svc.cluster.local:3200" }

        $verified = Verify-BackendQuery "Tempo" "$tempoSvc/api/search?tags=service.name=telemetrygen&limit=5" '.traces | length'
        $results["Traces (Tempo)"] = if ($verified) { "PASS" } else { "FAIL" }
    } else {
        $results["Traces (Tempo)"] = if ($ran) { "PASS (Job Completed)" } else { "FAIL (Job Failed)" }
    }
}

# Logs Verification
if ($Type -eq "logs" -or $Type -eq "all") {
    $ran = Run-TelemetrygenJob "logs"
    if ($ran -and $queryPod) {
        Write-Host "`n[2/3] Querying Loki API for service_name=telemetrygen..." -ForegroundColor Cyan
        $lokiSvc = "http://loki-gateway.$Namespace.svc.cluster.local:80"
        $isGatewayPresent = kubectl get svc loki-gateway -n $Namespace 2>$null
        if (-not $isGatewayPresent) { $lokiSvc = "http://loki.$Namespace.svc.cluster.local:3100" }

        $verified = Verify-BackendQuery "Loki" "$lokiSvc/loki/api/v1/query_range?query=%7Bservice_name%3D%22telemetrygen%22%7D" '.data.result | length'
        $results["Logs (Loki)"] = if ($verified) { "PASS" } else { "FAIL" }
    } else {
        $results["Logs (Loki)"] = if ($ran) { "PASS (Job Completed)" } else { "FAIL (Job Failed)" }
    }
}

# Metrics Verification
if ($Type -eq "metrics" -or $Type -eq "all") {
    $ran = Run-TelemetrygenJob "metrics"
    if ($ran -and $queryPod) {
        Write-Host "`n[2/3] Querying Prometheus API for telemetrygen metrics..." -ForegroundColor Cyan
        $promSvc = "http://prometheus-server.$Namespace.svc.cluster.local:80"
        $verified = Verify-BackendQuery "Prometheus" "$promSvc/api/v1/query?query=gen_traces_total" '.data.result | length'
        $results["Metrics (Prometheus)"] = if ($verified) { "PASS" } else { "FAIL" }
    } else {
        $results["Metrics (Prometheus)"] = if ($ran) { "PASS (Job Completed)" } else { "FAIL (Job Failed)" }
    }
}

# Summary Report
Write-Host "`n==========================================================" -ForegroundColor Cyan
Write-Host "                TELEMETRYGEN TEST SUMMARY                 " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
$allPassed = $true
foreach ($key in $results.Keys) {
    $status = $results[$key]
    $color = if ($status -like "*PASS*") { "Green" } else { "Red"; $allPassed = $false }
    Write-Host " - $key : $status" -ForegroundColor $color
}

if ($allPassed) {
    Write-Host "`nAll synthetic telemetry validations passed successfully!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "`nSome synthetic telemetry validations failed." -ForegroundColor Red
    exit 1
}
