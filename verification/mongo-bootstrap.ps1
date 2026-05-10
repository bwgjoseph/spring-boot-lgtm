# Initializes the MongoDB database and collection for Debezium CDC
$mongoPod = "mongodb-0"

Write-Host "Waiting for MongoDB pod '$mongoPod' to be ready..."
kubectl wait --for=condition=Ready pod/$mongoPod -n monitoring --timeout=180s

Write-Host "Initializing MongoDB database 'kx' and collection 'pokemon'..."

# Add sleep to allow replica set election
Start-Sleep -Seconds 30

# Use the full FQDN service address for reliability
$fqdn = "mongodb-0.mongodb-headless.monitoring.svc.cluster.local:27017"

$initCmd = "db.getSiblingDB('kx').pokemon.updateOne({name: 'init'}, {`$set: {status: 'ready'}}, {upsert: true})"
kubectl exec -n monitoring $mongoPod -c mongodb -- /opt/bitnami/mongodb/bin/mongosh --host $fqdn admin -u admin -p password --quiet --eval "$initCmd"

if ($LASTEXITCODE -eq 0) {
    Write-Host "  - [✓] MongoDB initialization complete."
} else {
    Write-Error "  - MongoDB initialization failed."
    exit 1
}
