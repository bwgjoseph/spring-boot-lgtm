# Installation & Upgrade Guide

This guide provides instructions for deploying and updating the Spring Boot Observability stack on a local Kubernetes cluster (Docker Desktop).

## Prerequisites
Ensure the following tools are installed:
- **Docker Desktop** (with Kubernetes enabled)
- **kubectl**
- **Helm**
- **Java 25** (for local development)
- **Maven**

---

## 1. Initial Infrastructure Setup
If you are on a fresh machine, you must first install the LGTM stack (Loki, Grafana, Tempo, Mimir/Prometheus).

### Create Namespace
```bash
kubectl create namespace monitoring
```

### Install Grafana Stack (via Helm)
Follow the specific instructions in each `values-*.yaml` file if present, or use the standard Helm repos:

```bash
# Add Grafana Helm repo
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add grafana-community https://grafana-community.github.io/helm-charts
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Install or Upgrade Prometheus (Metrics)
# NOTE: Uses --version 28.13.0 and requires remoteWriteReceiver enabled in values
helm upgrade --install prometheus prometheus-community/prometheus -n monitoring -f deployment/values-prometheus.yaml --version 28.13.0

# Install or Upgrade Loki (Logs)
helm upgrade --install loki grafana/loki -n monitoring -f deployment/values-loki.yaml --version 6.53.0

# Install or Upgrade Tempo (Traces)
helm upgrade --install tempo grafana-community/tempo -n monitoring --version 1.26.5

# Install or Upgrade Grafana (Visualization)
helm upgrade --install grafana grafana-community/grafana -n monitoring -f deployment/values-grafana.yaml --version 11.2.2
```

---

## 2. Deploying/Upgrading Grafana Alloy
Alloy acts as the central gateway for all observability data. It is installed **last** to ensure its outbound connections to Prometheus, Loki, and Tempo are ready.

### Fresh Install or Upgrade
```bash
helm upgrade --install alloy grafana/alloy -n monitoring -f deployment/values-alloy.yaml --version 1.6.0
```

---

## 3. Building & Deploying the Application

### Step A: Build the Image
We use Jib to build the container image directly to your local Docker daemon.

```bash
./mvnw clean compile jib:dockerBuild
```

### Step B: Deploy or Upgrade
Apply the Kubernetes manifests. If the deployment already exists, Kubernetes will perform a rolling update.

```bash
kubectl apply -f deployment/deployment.yaml
```

### Step C: Force a Restart (Optional)
If you've updated the image but the tag remains `demo`, you may need to force a rollout to pull the "new" version of the image:

```bash
kubectl rollout restart deployment spring-boot-app -n monitoring
```

## 4. Accessing User Interfaces (Port-Forwarding)
To access the various dashboards and UIs from your local machine, run these commands in separate terminal windows:

### Grafana (Main Dashboard)
**URL:** `http://localhost:3000`
```bash
kubectl port-forward service/grafana 3000:80 -n monitoring
```
*Note: See section 5 for the admin password.*

---

## 5. "Warming Up" the Service Map
The Service Graph is generated from active traces. Run this command to generate data:

```powershell
# PowerShell
1..10 | ForEach-Object { curl http://localhost:8080/pokemon/$_; Start-Sleep -Seconds 1 }
```

After about 30-60 seconds, navigate to **Tempo -> Service Graph** in Grafana to see the dependency map.

---

## 6. Verification & Credentials
**URL:** `http://localhost:9090`
```bash
kubectl port-forward service/prometheus-server 9090:80 -n monitoring
```

### Grafana Alloy (Debug UI)
Useful for inspecting the pipeline and sampling logic.
**URL:** `http://localhost:12345`
```bash
kubectl port-forward daemonset/alloy 12345:12345 -n monitoring
```

### Spring Boot Application (Swagger/Health)
**URL:** `http://localhost:8080/actuator/health`
```bash
kubectl port-forward service/spring-boot-app-svc 8080:8080 -n monitoring
```

---

## 5. Verification & Credentials
Once deployed, verify the status of the pods:

```bash
kubectl get pods -n monitoring
```

### Get Grafana Admin Password
```bash
kubectl get secret --namespace monitoring grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo
```

---

## 5. Summary of "Day 2" Features Enabled
- **Exemplars:** TraceIDs are linked in Prometheus metrics (visible in Grafana Explore).
- **Tail-Sampling:** Configured in `values-alloy.yaml` (currently 100% sampling).
- **Service Graph & Node Graph:** Automated dependency mapping generated in the Tempo "Service Graph" tab.
- **Trace-to-Log / Trace-to-Metric:** Modernized links between all three pillars (Loki, Tempo, Prometheus).
- **Self-Monitoring:** Alloy metrics are visible in Prometheus.

---

## 6. Pro-Tip: Automation with Taskfile
While the steps above are manual, you can perform all these actions (including repo setup, namespace creation, and version-locking) using the included `Taskfile.yml`:

*   `task all`: Full install/upgrade (Infra + App).
*   `task infra`: Just the LGTM stack + Alloy.
*   `task port-forward`: Quick access to Grafana.
*   `task password`: Retrieve admin credentials.

