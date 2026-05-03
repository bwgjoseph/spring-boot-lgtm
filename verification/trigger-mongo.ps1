param([string]$testId)
$namespace = "monitoring"

function Log-Action($Message, $Color = "Gray") {
    Write-Host $Message -ForegroundColor $Color
    if ($env:LOG_FILE) { Add-Content -Path $env:LOG_FILE -Value $Message }
}

Log-Action "Step 2: Triggering 5 MongoDB changes..." "Gray"
for ($i = 1; $i -le 5; $i++) {
    $mongoCmd = "db.getSiblingDB('kx').pokemon.updateOne({name: 'Pikachu'}, {`$set: {last_test_id: '$testId-$i'}})"
    kubectl exec mongodb-0 -n $namespace -- mongosh admin -u admin -p password --eval "$mongoCmd" > $null
    if ($LASTEXITCODE -eq 0) {
        Log-Action "   -> MongoDB update $i successful." "Green"
    } else {
        Log-Action "   -> MongoDB update $i failed." "Red"
    }
}
