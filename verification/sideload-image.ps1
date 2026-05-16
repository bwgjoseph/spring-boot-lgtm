param (
    [Parameter(Mandatory=$true)]
    [string]$ImageName,
    [string]$TarFile = "image.tar"
)

Write-Host "--- Checking Kubernetes Environment for Sideloading ---"

# Get the first node name
$node = (kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
if (-not $node) {
    Write-Error "No Kubernetes nodes found. Is your cluster running?"
    exit 1
}

# Check if a Docker container exists with a name matching the node (e.g., kind-control-plane)
# We use a broad filter because some setups might have slightly different naming (e.g., k3d-server-0)
$container = (docker ps --filter "name=$node" --format "{{.Names}}")

if ($container) {
    Write-Host "  - Container node detected: $container"
    Write-Host "  - Sideloading image: $ImageName"
    
    try {
        Write-Host "  - Exporting image to $TarFile..."
        docker save $ImageName -o $TarFile
        
        Write-Host "  - Copying $TarFile to container..."
        docker cp $TarFile "${container}:/$TarFile"
        
        Write-Host "  - Importing into cluster (containerd)..."
        docker exec $container ctr -n k8s.io images import "/$TarFile"
        
        Write-Host "  - Cleaning up inside container..."
        docker exec $container rm "/$TarFile"
    }
    catch {
        Write-Error "Failed to sideload image: $($_.Exception.Message)"
        exit 1
    }
    finally {
        if (Test-Path $TarFile) {
            Write-Host "  - Cleaning up local $TarFile..."
            Remove-Item $TarFile -Force
        }
    }
    Write-Host "--- [✓] Sideloading complete ---"
} else {
    Write-Host "  - Node '$node' is not running as a Docker container."
    Write-Host "  - Assuming shared Docker daemon architecture (Rancher Desktop or Docker Desktop)."
    Write-Host "  - Image '$ImageName' is already available to the cluster."
    Write-Host "--- [✓] Skipping sideloading ---"
}
