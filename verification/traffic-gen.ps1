$testId = [guid]::NewGuid().ToString().Substring(0,8)
$namespace = "monitoring"

function Log-Action($Message, $Color = "Gray") {
    Write-Host $Message -ForegroundColor $Color
    Add-Content -Path $env:LOG_FILE -Value $Message
}

Log-Action "--- Generating Test Traffic (TestID: $testId) ---" "Cyan"

# 1. Trigger Application Request (Traces + Logs)
$appPod = kubectl get pods -n $namespace -l app=spring-boot-app -o jsonpath='{.items[0].metadata.name}'
Log-Action "Step 1: Triggering App request via $appPod..." "Gray"
$auth = [Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes('user:password'))
$appResponse = kubectl exec $appPod -n $namespace -- wget -qO- --header "Authorization: Basic $auth" "http://localhost:8080/pokemon/1?test_id=$testId" 2>$null
if ($LASTEXITCODE -eq 0) {
    Log-Action "   -> App request successful." "Green"
} else {
    Log-Action "   -> App request failed." "Red"
}

# 2. Trigger Database Change (CDC Metrics)
Log-Action "Step 2: Triggering MongoDB change..." "Gray"
$mongoCmd = "db.getSiblingDB('kx').pokemon.updateOne({name: 'Pikachu'}, {`$set: {last_test_id: '$testId'}})"
kubectl exec mongodb-0 -n $namespace -- mongosh admin -u admin -p password --eval "$mongoCmd" > $null
if ($LASTEXITCODE -eq 0) {
    Log-Action "   -> MongoDB update successful." "Green"
} else {
    Log-Action "   -> MongoDB update failed." "Red"
}

Write-Output $testId
