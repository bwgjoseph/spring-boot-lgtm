# 🧪 Verification Guide: Alerting & Service Health Pipeline

This guide outlines step-by-step procedures to deploy, validate, and test the alerting rules, Alertmanager cascade inhibition, and unified Grafana dashboard locally in the sandbox environment.

---

## 📋 Prerequisites

Ensure your local Kubernetes cluster and monitoring components are running:

```powershell
# Verify monitoring namespace pods are healthy
kubectl get pods -n monitoring
```

---

## 🚀 Step 1: Synchronize ConfigMaps & Dashboards

Apply the new alerting rules and unified dashboard to the cluster:

```powershell
# 1. Sync Prometheus alerting rules into ConfigMap
task configmap:prometheus-alert

# 2. Sync Grafana dashboards (includes service-health-and-alerts.json)
task configmap:grafana-dashboard
```

---

## ⚙️ Step 2: Upgrade Prometheus & Alertmanager

Deploy the updated Prometheus configuration containing the 28-rule catalog, Alertmanager inhibition rules, and webhook dispatcher:

```powershell
# Upgrade Prometheus release in the current environment (dev)
task prometheus
```

Validate configuration syntax inside the running pods:

```powershell
# Validate Prometheus server rule evaluation syntax
task check:prometheus

# Validate Alertmanager routing and inhibition configuration
task check:alertmanager
```

---

## 🔍 Step 3: Access UIs

Launch port-forwarding for Alertmanager, Prometheus, and Grafana:

```powershell
# Port-forward Alertmanager (http://localhost:9093)
task pf:alertmanager

# Port-forward Prometheus UI (http://localhost:9090)
task pf:prometheus

# Port-forward Grafana (http://localhost:3000)
task pf:grafana
```

---

## ⚡ Step 4: Test Alert Firing & Cascade Inhibition

This test confirms that:
1. `ServiceDown` / `InstanceAbsent` alerts fire when an outage occurs.
2. Alertmanager **inhibition rules** suppress cascading downstream symptom alerts (e.g. `HighHttpErrorRate`, `HikariPoolStarvation`, `HighCpuUsage`) to prevent alert fatigue.

### 4.1 Trigger Outage (Scale to 0)

Simulate application downtime by scaling `spring-boot-app` to 0 replicas:

```powershell
kubectl scale deployment spring-boot-app -n monitoring --replicas=0
```

### 4.2 Observe Firing Alerts & Suppression

1. Open **Alertmanager UI** at [http://localhost:9093/#/alerts](http://localhost:9093/#/alerts).
2. Within 1–2 minutes, verify:
   - `InstanceAbsent` and/or `ServiceDown` transitions to **Firing** (severity: `critical`).
3. Check the **Inhibition** behavior:
   - Notice that symptom alerts such as `HighHttpErrorRate`, `PokemonApiHighErrorRate`, and `HikariPoolStarvation` do **not** flood the notification queue because they match the inhibition source `ServiceDown|InstanceDown|InstanceAbsent`.
4. Open **Prometheus Alerts UI** at [http://localhost:9090/alerts](http://localhost:9090/alerts):
   - Review rule evaluation states across all 5 groups (`spring_boot_red_alerts`, `jvm_and_database_alerts`, `debezium_cdc_alerts`, `kubernetes_and_storage_alerts`, `rustfs_storage_alerts`).

---

## 🔄 Step 5: Test Resolution & Recovery

Restore the application instance:

```powershell
kubectl scale deployment spring-boot-app -n monitoring --replicas=1
```

Watch the recovery:
1. In Alertmanager UI, verify `InstanceAbsent` and `ServiceDown` transition to **Resolved**.
2. If webhooks are configured, verify that a resolution notification (`send_resolved: true`) is dispatched.

---

## 📊 Step 6: Verify Unified "Service Health & Alerting" Dashboard

1. Open **Grafana** at [http://localhost:3000](http://localhost:3000) (Default login: `admin` / `admin`).
2. Navigate to **Dashboards** $\rightarrow$ **Default** (or search for `Service Health & Alerting Overview`, UID: `service-health-and-alerts`).
3. Confirm panel rendering:
   - **Executive Health Row:** Verify the `Service Status` badge displays **UP** (green) and active alert counts show `0`.
   - **Active Alert Feed:** Built-in `alertlist` panel shows recent alerts with clickable `runbook_url` links.
   - **RED Method Row:** Displays HTTP Request Rate, 5xx Error Rate %, and P50/P90/P99 latencies.
   - **JVM & DB Runtime (USE):** Displays Heap & Metaspace memory utilization, GC pause overhead %, and HikariCP active/pending connections.
   - **CDC & Real-Time Logs:** Displays Debezium replication lag and live Loki error stream.
   - **Template Filters:** Test switching the `$namespace` and `$service` dropdowns to verify panel scoping.

---

## 🛡️ Step 7: (Optional) Test Webhook Secret Injection

If you wish to test outbound notifications to a target webhook (Slack, Mattermost, Discord, or webhook tester like webhook.site):

```powershell
# 1. Set the target webhook URL environment variable
$env:ALERT_WEBHOOK_URL = "https://your-webhook-endpoint.com/alerts"

# 2. Deploy/update the secret
task secret:alertmanager

# 3. Restart Alertmanager to pick up secret changes if mounted
kubectl rollout restart statefulset prometheus-alertmanager -n monitoring
```
