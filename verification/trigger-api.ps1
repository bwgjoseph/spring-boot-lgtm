param([string]$testId)
$namespace = "monitoring"

function Log-Action($Message, $Color = "Gray") {
    Write-Host $Message -ForegroundColor $Color
    if ($env:LOG_FILE) { Add-Content -Path $env:LOG_FILE -Value $Message }
}

Log-Action "Step 1: Triggering App request via spring-boot-app..." "Gray"
$appPod = kubectl get pods -n $namespace -l app=spring-boot-app -o jsonpath='{.items[0].metadata.name}'
$auth = [Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes('user:password'))
$appResponse = kubectl exec $appPod -n $namespace -- wget -qO- --header "Authorization: Basic $auth" "http://localhost:8080/pokemon/1?test_id=$testId" 2>$null
if ($LASTEXITCODE -eq 0) {
    Log-Action "   -> App request successful." "Green"
} else {
    Log-Action "   -> App request failed." "Red"
}
