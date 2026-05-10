param([string]$testId)
$namespace = "monitoring"

function Log-Action($Message, $Color = "Gray") {
    Write-Host $Message -ForegroundColor $Color
    if ($env:LOG_FILE) { Add-Content -Path $env:LOG_FILE -Value $Message }
}

Log-Action "Step 1: Triggering App request loop via spring-boot-app..." "Gray"

# Get app pod using standard labels from app.yaml
$appPod = kubectl get pods -n $namespace -l app=spring-boot-app -o jsonpath='{.items[0].metadata.name}'
if (-not $appPod) {
    Log-Action "   -> Pod not found. Checking deployments..." "Red"
    kubectl get pods -n $namespace
    exit 1
}

$auth = [Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes('user:password'))

# Trigger a burst of 10 requests to generate enough logs for Loki flush
for ($i = 1; $i -le 10; $i++) {
    $appResponse = kubectl exec $appPod -n $namespace -- wget -qO- --header "Authorization: Basic $auth" "http://localhost:8080/pokemon/1?test_id=$testId" 2>$null
    if ($LASTEXITCODE -eq 0) {
        # Success, keep silent to reduce noise
    } else {
        Log-Action "   -> App request #$i failed." "Red"
        exit 1
    }
}
Log-Action "   -> 10 requests completed successfully." "Green"
