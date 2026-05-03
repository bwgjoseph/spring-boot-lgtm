# 🚀 Manual Installation Guide (Wipe & Restore)

This guide provides the step-by-step commands to deploy the entire Spring Boot LGTM stack from a clean slate without using the Taskfile. These instructions are designed for manual execution or integration into a **GitLab CI/CD** pipeline.

---

## 1. Prerequisites
Ensure the following tools are installed:
*   **Kubernetes Cluster** (Docker Desktop, KinD, or On-Prem)
*   **Helm v3.x**
*   **kubectl** & **pwsh** (PowerShell)
*   **jq** (for verification scripts)
*   **Java 25** & **Maven 3.9+** (for building the app)

---

## 2. Infrastructure Setup (Phase 1)

### A. Add Helm Repositories
The easiest way to configure the required Helm repositories is using the Taskfile:

```powershell
task repos
```

*Note: For manual environments, refer to the `repos` task in `Taskfile.yml` for the full list of repository URLs.*

### B. Create Namespace & Secrets
1. **Create Namespace:**
   ```powershell
   task namespace
   ```

2. **Create Secrets:**
   ```powershell
   task secret
   ```

---

## 3. Common Configurations (Phase 2)
These resources are shared across all environments (Dev/Prod). The easiest way to deploy them is using the Taskfile:

```powershell
task configmap
```

*Note: This single command handles **prometheus-alert-rules**, **grafana-datasources**, and the automated individual ConfigMap creation for each dashboard with the **grafana-dash-** prefix.*

---

## 4. Deploy Components (Phase 3)
The easiest way to deploy or upgrade individual components is using the Taskfile. By default, these commands target the **dev** environment.

```powershell
# 1. Storage Layer
task minio
task mongodb

# 2. Backends
task prometheus
task loki
task tempo

# 3. Visualization & Collection
task grafana
task alloy
```

*Pro-Tip: To target production blueprints, append `ENV=prod` to any command (e.g., `task loki ENV=prod`).*

---

## 5. Application Deployment (Phase 4)

### A. Build and Load Image
The easiest way to build the application and sideload it into your local Kubernetes cluster (Docker Desktop/KinD) is using the Taskfile:

```powershell
task app:load
```

*Note: For GitLab CI, you would manually run `.\mvnw clean compile jib:dockerBuild`, followed by `docker save` and `ctr images import` commands.*

### B. Deploy to Kubernetes
```bash
task app:deploy
```

### C. Bootstrap Database (Debezium CDC requirement)
Debezium requires the database and collection to exist to capture changes:
```powershell
kubectl exec mongodb-0 -n monitoring -- mongosh admin -u admin -p password --eval "db.getSiblingDB('kx').createCollection('pokemon')"
```

---

## 6. Accessing User Interfaces

To access the various dashboards from your local machine, use the Taskfile:

*   **All UIs:** `task pf:all`
*   **Grafana only:** `task pf:grafana` (http://localhost:3000)
*   **Alertmanager only:** `task pf:alertmanager` (http://localhost:9093)
*   **Application only:** `task pf:spring-app` (http://localhost:8080/actuator/health)

### Stopping Port-Forwards
Since these run in the background, you can stop them individually or all at once:
*   **Specific Port:** `task pf:kill PORT=3000`
*   **All Port-forwards:** `task pf:kill-all`

### Get Grafana Admin Password
```powershell
# PowerShell
$pass = kubectl get secret --namespace monitoring grafana-admin-credentials -o jsonpath="{.data.admin-password}"
[System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($pass))

# Bash
kubectl get secret --namespace monitoring grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo ""
```

---

## 7. Verification
Once all pods are `1/1 Running`, run the deterministic E2E verification suite:
```powershell
task test:e2e
```
The report will be available at `./verification/logs/VERIFICATION_REPORT.md`.

---

## 🌟 Summary of "Day 2" Features
This sandbox is pre-configured with advanced observability patterns:
- **Exemplars:** Direct correlation from metric spikes in Prometheus to specific traces in Tempo.
- **K8s Metadata Enrichment:** Alloy automatically injects pod/node info into traces based on Source IP.
- **CDC Monitoring:** Native Micrometer integration for Debezium Embedded (JMX-to-Prometheus).
- **Service Graph:** Automated system-wide dependency mapping generated natively by Tempo.
- **Trace-to-Log:** Modernized links between Tempo spans and Loki logs using Structured Metadata.

---

## ⚡ Pro-Tip: Automation with Taskfile
While the steps above are manual, you can perform all these actions (including repository management, namespace creation, and version-locking) using the included `Taskfile.yml`:

*   `task all`: Full install/upgrade (Infra + App).
*   `task infra`: Just the LGTM stack + Alloy + Dashboards.
*   `task port-forward`: Quick access to all observability UIs.
*   `task clean`: Wipe all configurations and the namespace.
*   `task scale-down`: Save resources by pausing the stack (Keeps storage/DB alive).

## 🆘 Need Help?
Refer to the **[Troubleshooting Guide (./TROUBLESHOOT.md)](./TROUBLESHOOT.md)**.
