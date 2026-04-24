$testId = [guid]::NewGuid().ToString().Substring(0,8)
$namespace = "monitoring"

Write-Host "--- Generating Test Traffic (TestID: $testId) ---" -ForegroundColor Cyan

# 1. Trigger Application Request (Traces + Logs)
$appPod = kubectl get pods -n $namespace -l app=spring-boot-app -o jsonpath='{.items[0].metadata.name}'
Write-Host "Triggering App request via $appPod..."
$auth = [Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes('user:password'))
kubectl exec $appPod -n $namespace -- wget -qO- --header "Authorization: Basic $auth" "http://localhost:8080/pokemon/1?test_id=$testId" > $null

# 2. Trigger Database Change (CDC Metrics)
Write-Host "Triggering MongoDB change..."
$mongoCmd = "db.getSiblingDB('kx').pokemon.updateOne({name: 'Pikachu'}, {`$set: {last_test_id: '$testId'}})"
kubectl exec mongodb-0 -n $namespace -- mongosh admin -u admin -p password --eval "$mongoCmd" > $null

Write-Output $testId
