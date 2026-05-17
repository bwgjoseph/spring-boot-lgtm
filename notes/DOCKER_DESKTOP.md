# 🐳 Docker & Rancher Desktop Configuration Guide

This project contains specific configurations to ensure the Grafana LGTM stack runs smoothly on **Docker Desktop** or **Rancher Desktop** (Windows/macOS). These settings bypass certain hardware-level restrictions or architectural differences in local Kubernetes distributions.

## 🛠️ Local Engine Specifics

### 1. Image Sideloading (The `app:load` task)
Depending on your local engine, images built by the host may or may not be available to Kubernetes:
- **Rancher Desktop (with Docker/Moby):** The Docker daemon is shared. Images are available immediately.
- **Docker Desktop (WSL2):** Usually shares the daemon. Images are available immediately.
- **KinD / Isolated Runtimes:** Images must be explicitly sideloaded into the node.

**The Solution:** Use `task app:load`. It calls a smart script (`verification/sideload-image.ps1`) that detects your cluster type and only performs a sideload if necessary.

### 2. Node Exporter: `hostRootFsMount`
*   **Location:** `deployment/values-prometheus.yaml`
*   **Setting:** `prometheus-node-exporter.hostRootFsMount.enabled: false`
*   **Why?** Node Exporter typically tries to mount the host's root file system (`/`) to monitor disk usage. Docker Desktop's virtual machine does not support this type of propagation for the root path, causing the pod to crash with `ContainerCannotRun`.
*   **Production Move:** Set this back to `true` on standard Linux clusters (EKS, GKE, Bare Metal).

### 3. Alloy: `insecure_skip_verify` for Kubelet
*   **Location:** `deployment/values-alloy.yaml`
*   **Setting:** `insecure_skip_verify: true`
*   **Why?** The Kubelet on local clusters often serves metrics over HTTPS using self-signed certificates that don't match the internal hostname.
*   **Production Move:** Use the internal Cluster CA for verification.

## 🚀 Resource Allocation
...
*   **Recommendation:** Ensure Docker Desktop is allocated at least **8GB of RAM** and **4 CPUs**.
*   **Symptoms of Low Memory:** Alloy pods may enter `OOMKilled` state or Prometheus may experience "Write Ahead Log" (WAL) corruption.

## 🚀 Transitioning to Production

When moving away from Docker Desktop to a standard Kubernetes environment, search for the `DOCKER-DESKTOP` comments in the following files:
1. `deployment/values-prometheus.yaml`
2. `deployment/values-alloy.yaml`

Follow the instructions in those comments to re-enable full hardware monitoring and strict security verification.
