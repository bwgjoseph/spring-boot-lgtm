param([string]$testId)
$namespace = "monitoring"

function Log-Action($Message, $Color = "Gray") {
    Write-Host $Message -ForegroundColor $Color
    if ($env:LOG_FILE) { Add-Content -Path $env:LOG_FILE -Value $Message }
}

Log-Action "Step 2: Triggering 5 MongoDB changes in 'kx' database..." "Gray"
for ($i = 1; $i -le 5; $i++) {
    # Ensure database 'kx' and collection 'pokemon' exist
    $mongoCmd = "db.getSiblingDB('kx').pokemon.updateOne({name: 'Pikachu'}, {`$set: {last_test_id: '$testId-$i'}}, {upsert: true})"
    kubectl exec mongodb-0 -n $namespace -c mongodb -- /opt/bitnami/mongodb/bin/mongosh admin -u admin -p password --quiet --eval "$mongoCmd" > $null
    if ($LASTEXITCODE -eq 0) {
        Log-Action "   -> MongoDB update $i successful." "Green"
    } else {
        Log-Action "   -> MongoDB update $i failed." "Red"
    }
}
