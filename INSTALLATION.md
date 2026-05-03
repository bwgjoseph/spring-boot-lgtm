# 🚀 Manual Installation & CI/CD Guide

This guide provides the step-by-step commands to deploy the entire Spring Boot LGTM stack without using `task`. These instructions are designed for manual execution or integration into a **GitLab CI/CD** pipeline.

---

## 1. Prerequisites
*   **Kubernetes Cluster** (Docker Desktop, KinD, or On-Prem)
*   **Helm v3.x**
*   **kubectl**
*   **Maven 3.9+** (or use `./mvnw`)
*   **Docker** (for building/loading images)

---

## 2. Infrastructure Setup (Phase 1)

### A. Add Helm Repositories
```bash
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add grafana-community https://grafana-community.github.io/helm-charts
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add minio https://charts.min.io/
helm repo update
```

### B. Create Namespace & Secrets
```bash
# Create Namespace
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply --server-side -f -

# Create MongoDB Secret (Root credentials)
kubectl create secret generic mongodb \
  --from-literal=mongodb-root-password=password \
  --from-literal=mongodb-replica-set-key=12345678901234567890 \
  -n monitoring
```

### C. Deploy Storage (MinIO & MongoDB)
```bash
# MinIO
helm upgrade --install minio minio/minio -n monitoring \
  --version 5.4.0 \
  -f deployment/values-minio.yaml

# MongoDB (Bitnami OCI)
helm upgrade --install mongodb oci://registry-1.docker.io/bitnamicharts/mongodb -n monitoring \
  --version 18.6.31 \
  -f deployment/values-mongodb.yaml
```

---

## 3. Observability Backends (Phase 2)

### A. Deploy Prometheus (v29+)
First, create the alerting rules ConfigMap:
```bash
kubectl create configmap prometheus-rules \
  --from-file=deployment/prometheus-alerting-rules.yaml \
  -n monitoring --dry-run=client -o yaml | kubectl apply -f -
```
Deploy the server:
```bash
helm upgrade --install prometheus prometheus-community/prometheus -n monitoring \
  --version 29.2.1 \
  -f deployment/values-prometheus.yaml
```

### B. Deploy Tempo & Loki
```bash
# Tempo
helm upgrade --install tempo grafana-community/tempo -n monitoring \
  --version 2.0.0 \
  -f deployment/values-tempo.yaml

# Loki (Single Binary)
helm upgrade --install loki grafana-community/loki -n monitoring \
  --version 13.2.3 \
  -f deployment/values-loki-singlebinary.yaml
```

---

## 4. Visualization & Collection (Phase 3)

### A. Deploy Grafana
```bash
# Deploy Datasources
kubectl create configmap local-datasources \
  --from-file=deployment/datasources.yaml \
  -n monitoring --dry-run=client -o yaml | kubectl apply -f -
kubectl label configmap local-datasources grafana_datasource=1 -n monitoring --overwrite

# Deploy Dashboards (Individual ConfigMaps)
# GitLab CI script example:
for file in deployment/dashboards/*.json; do
  name="dash-$(basename "$file" .json | tr '[:upper:]' '[:lower:]')"
  kubectl create configmap "$name" --from-file="$file" -n monitoring --dry-run=client -o yaml | kubectl apply -f -
  kubectl label configmap "$name" grafana_dashboard=1 -n monitoring --overwrite
done

# Install Grafana
helm upgrade --install grafana grafana-community/grafana -n monitoring \
  --version 12.1.1 \
  -f deployment/values-grafana.yaml
```

### B. Deploy Grafana Alloy
```bash
helm upgrade --install alloy grafana/alloy -n monitoring \
  --version 1.8.0 \
  -f deployment/values-alloy.yaml
```

---

## 5. Application Deployment (Phase 4)

### A. Build and Load Image
```bash
./mvnw clean compile jib:dockerBuild
docker save spring-boot-app:demo -o spring-boot-app.tar

# For local development (Docker Desktop/KinD):
docker cp spring-boot-app.tar desktop-control-plane:/spring-boot-app.tar
docker exec desktop-control-plane ctr -n k8s.io images import /spring-boot-app.tar
```

### B. Deploy to K8s
```bash
kubectl apply -f deployment/deployment.yaml
kubectl rollout restart deployment spring-boot-app -n monitoring
```

---

## 6. Verification
Run the E2E verification suite:
```bash
pwsh -File ./verification/run-all.ps1
```
The report will be available at `./verification/logs/VERIFICATION_REPORT.md`.
