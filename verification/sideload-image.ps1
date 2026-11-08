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
# This covers standard KinD clusters where nodes run as Docker containers.
$container = (docker ps --filter "name=$node" --format "{{.Names}}")

if ($container) {
    # --- Standard KinD (node is a Docker container) ---
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
    # No matching Docker container — check the node's providerID to distinguish
    # Docker Desktop KinD (WSL2 VM containerd) from Rancher Desktop (shared daemon).
    $providerID = (kubectl get node $node -o jsonpath='{.spec.providerID}')

    if ($providerID -match "kind://docker") {
        # --- Docker Desktop KinD (node runs inside WSL2 VM, not as a Docker container) ---
        # The k8s containerd (k8s.io namespace) is isolated from the Docker daemon.
        # We must nsenter into the containerd process inside the docker-desktop WSL distro.
        Write-Host "  - Docker Desktop KinD node detected (providerID: $providerID)"
        Write-Host "  - Sideloading image via WSL2 nsenter: $ImageName"

        # Resolve the Windows Temp path to its WSL-accessible equivalent
        $winTemp = $env:TEMP
        $tarPath = Join-Path $winTemp $TarFile
        # Map C:\Users\... -> /tmp/docker-desktop-root/run/desktop/mnt/host/c/Users/...
        $wslTarPath = $tarPath -replace '^([A-Za-z]):\\', { "/tmp/docker-desktop-root/run/desktop/mnt/host/$($_.Groups[1].Value.ToLower())/" }
        $wslTarPath = $wslTarPath -replace '\\', '/'

        try {
            Write-Host "  - Saving image to $tarPath..."
            docker save $ImageName -o $tarPath

            Write-Host "  - Finding containerd PID in docker-desktop distro..."
            $containerdPID = (wsl -d docker-desktop -u root sh -c "pgrep -f '/usr/local/bin/containerd$'").Trim()
            if (-not $containerdPID) {
                Write-Error "Could not find containerd PID in docker-desktop WSL distro."
                exit 1
            }
            Write-Host "  - Containerd PID: $containerdPID"

            Write-Host "  - Importing image into k8s.io containerd namespace..."
            wsl -d docker-desktop -u root sh -c "cat '$wslTarPath' | nsenter -t $containerdPID -m -u -i -n -p ctr -n k8s.io images import -"

            Write-Host "  - Verifying image import..."
            $imported = wsl -d docker-desktop -u root sh -c "nsenter -t $containerdPID -m -u -i -n -p ctr -n k8s.io images ls" | Select-String $ImageName
            if ($imported) {
                Write-Host "  - [✓] Image confirmed in k8s containerd: $imported"
            } else {
                Write-Warning "Image may not have imported correctly. Check with: wsl -d docker-desktop -u root sh -c `"nsenter -t $containerdPID -m -u -i -n -p ctr -n k8s.io images ls`""
            }
        }
        catch {
            Write-Error "Failed to sideload image via nsenter: $($_.Exception.Message)"
            exit 1
        }
        finally {
            if (Test-Path $tarPath) {
                Write-Host "  - Cleaning up local $tarPath..."
                Remove-Item $tarPath -Force
            }
        }
        Write-Host "--- [✓] Sideloading complete ---"

    } else {
        # --- Rancher Desktop or other shared-daemon architecture ---
        Write-Host "  - Node '$node' is not running as a Docker container (providerID: $providerID)."
        Write-Host "  - Assuming shared Docker daemon architecture (Rancher Desktop)."
        Write-Host "  - Image '$ImageName' is already available to the cluster."
        Write-Host "--- [✓] Skipping sideloading ---"
    }
}
