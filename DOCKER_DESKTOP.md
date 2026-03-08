# 🐳 Docker Desktop Configuration Guide

This project contains specific configurations to ensure the Grafana LGTM stack runs smoothly on **Docker Desktop (Windows/macOS)**. These settings bypass certain hardware-level restrictions inherent in the Docker Desktop virtualization layer.

## 🛠️ Docker Desktop Specifics

### 1. Node Exporter: `hostRootFsMount`
*   **Location:** `deployment/values-prometheus.yaml`
*   **Setting:** `prometheus-node-exporter.hostRootFsMount.enabled: false`
*   **Why?** Node Exporter typically tries to mount the host's root file system (`/`) to monitor disk usage. It requires "shared" mount propagation. Docker Desktop's virtual machine does not support this type of propagation for the root path, causing the pod to crash with `ContainerCannotRun`.
*   **Production Move:** Set this back to `true` on Linux-based Kubernetes clusters (EKS, GKE, Bare Metal) to get full disk monitoring.

### 2. Alloy: `insecure_skip_verify` for Kubelet
*   **Location:** `deployment/values-alloy.yaml`
*   **Setting:** `insecure_skip_verify: true` (under `prometheus.scrape "cadvisor"` and `"kubelet"`)
*   **Why?** The Kubelet on Docker Desktop serves metrics over HTTPS using a self-signed certificate that is usually bound to an internal IP or hostname that doesn't match the discovery target.
*   **Production Move:** On production clusters, you should ideally use the internal Cluster CA (`/var/run/secrets/kubernetes.io/serviceaccount/ca.crt`) and verify the hostname if the infrastructure provides stable DNS for nodes.

### 3. Resource Allocation
Running the full LGTM stack (Prometheus, Loki, Tempo, Grafana) plus Alloy and a Spring Boot app can be resource-intensive.
*   **Recommendation:** Ensure Docker Desktop is allocated at least **8GB of RAM** and **4 CPUs**.
*   **Symptoms of Low Memory:** Alloy pods may enter `OOMKilled` state or Prometheus may experience "Write Ahead Log" (WAL) corruption.

## 🚀 Transitioning to Production

When moving away from Docker Desktop to a standard Kubernetes environment, search for the `DOCKER-DESKTOP` comments in the following files:
1. `deployment/values-prometheus.yaml`
2. `deployment/values-alloy.yaml`

Follow the instructions in those comments to re-enable full hardware monitoring and strict security verification.
