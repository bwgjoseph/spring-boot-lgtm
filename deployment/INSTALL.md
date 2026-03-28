# Installation & Upgrade Guide

This guide provides instructions for deploying and updating the Spring Boot Observability stack on a local Kubernetes cluster (Docker Desktop).

## Prerequisites
Ensure the following tools are installed:
- **Docker Desktop** (with Kubernetes enabled)
- **kubectl**
- **Helm**
- **Java 25** (for local development)
- **Maven**
- **Taskfile** (Recommended for automation)

---

## 1. Initial Infrastructure Setup
If you are on a fresh machine, you must first install the LGTM stack (Loki, Grafana, Tempo, Prometheus).

### Create Namespace
```powershell
kubectl create namespace monitoring
```

### Install Grafana Stack (via Helm)
```powershell
# Add Helm repos
helm repo add grafana https://grafana.github.io/helm-charts; helm repo add grafana-community https://grafana-community.github.io/helm-charts; helm repo add prometheus-community https://prometheus-community.github.io/helm-charts; helm repo update

# Install or Upgrade MinIO (Internal Object Storage)
helm upgrade --install minio minio/minio -n monitoring -f deployment/values-minio.yaml --version 5.4.0

# Install or Upgrade Prometheus (Metrics, Node Exporter, KSM)
helm upgrade --install prometheus prometheus-community/prometheus -n monitoring -f deployment/values-prometheus.yaml --version 28.13.0

# Install or Upgrade Loki (Logs)
helm upgrade --install loki grafana/loki -n monitoring -f deployment/values-loki-scalable.yaml --version 6.53.0

# Install or Upgrade Tempo (Traces)
helm upgrade --install tempo grafana-community/tempo -n monitoring -f deployment/values-tempo-scalable.yaml --version 2.0.0

# Install or Upgrade Grafana (Visualization)
helm upgrade --install grafana grafana-community/grafana -n monitoring -f deployment/values-grafana.yaml --version 11.3.0

# Deploy Local Dashboards (Required for K8s Monitoring views)
kubectl create configmap local-dashboards --from-file=deployment/dashboards -n monitoring --dry-run=client -o yaml | kubectl apply -f -; kubectl label configmap local-dashboards grafana_dashboard=1 -n monitoring --overwrite
```

---

## 2. Deploying/Upgrading Grafana Alloy
Alloy acts as the central gateway for all observability data. It is installed **last** to ensure its outbound connections to Prometheus, Loki, and Tempo are ready.

### Fresh Install or Upgrade
```powershell
helm upgrade --install alloy grafana/alloy -n monitoring -f deployment/values-alloy.yaml --version 1.6.1
```

---

## 3. Building & Deploying the Application

### Step A: Build the Image
We use Jib to build the container image directly to your local Docker daemon.

```powershell
.\mvnw clean compile jib:dockerBuild
```

### Step B: Deploy or Upgrade
Apply the Kubernetes manifests. If the deployment already exists, Kubernetes will perform a rolling update.

```powershell
kubectl apply -f deployment/deployment.yaml; kubectl rollout restart deployment spring-boot-app -n monitoring
```

---

## 4. Accessing User Interfaces (Port-Forwarding)
To access the various dashboards and UIs from your local machine, run these commands in separate terminal windows:

### Grafana (Main Dashboard)
**URL:** `http://localhost:3000`
```powershell
kubectl port-forward service/grafana 3000:80 -n monitoring
```
*Note: Default credentials are `admin` / (use `task password` to retrieve).*

### Spring Boot Application (Swagger/Health)
**URL:** `http://localhost:8080/actuator/health`
```powershell
kubectl port-forward service/spring-boot-app-svc 8080:8080 -n monitoring
```

---

## 5. Verification & Credentials

### Get Grafana Admin Password
```powershell
kubectl get secret --namespace monitoring grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo ""
```

---

## 6. Summary of "Day 2" Features Enabled
- **Exemplars:** TraceIDs are linked in Prometheus metrics (visible in Grafana Explore).
- **K8s Monitoring:** Dedicated dashboards for Cluster, Node, and Pod resource usage.
- **Tail-Sampling:** Configured in `values-alloy.yaml` (currently 100% sampling).
- **Service Graph & Node Graph:** Automated dependency mapping generated in the Tempo "Service Graph" tab.
- **Trace-to-Log / Trace-to-Metric:** Modernized links between Loki, Tempo, and Prometheus.
  - See [learning_trace_to_log.md](../learning_trace_to_log.md) for troubleshooting details.

---

## 7. Pro-Tip: Automation with Taskfile
While the steps above are manual, you can perform all these actions (including repo setup, namespace creation, and version-locking) using the included `Taskfile.yml`:

*   `task all`: Full install/upgrade (Infra + App).
*   `task infra`: Just the LGTM stack + Alloy + Dashboards.
*   `task port-forward`: Quick access to Grafana and the App.
*   `task password`: Retrieve admin credentials.

## 🆘 Need Help?
If you encounter any issues (such as `ImagePullBackOff` on KinD/Docker Desktop), refer to the **[Troubleshooting Guide (../TROUBLESHOOT.md)](../TROUBLESHOOT.md)**.
