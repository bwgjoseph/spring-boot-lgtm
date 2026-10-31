# 🚨 Comprehensive Alerting & Service Health Architecture Guide

This document catalogs the enterprise-grade alerting architecture, PromQL & LogQL alert rules, Alertmanager routing and inhibition policies, and Grafana dashboard integration implemented for our **Spring Boot 3.5 + LGTM** observability stack.

---

## 🎯 Architecture Overview

```
               ┌────────────────────────────────────────────────────────┐
               │         Kubernetes & Bare-Metal Applications          │
               │  (Spring Boot 3.5, JVM, HikariCP, Debezium, RustFS)    │
               └──────────────────────────┬─────────────────────────────┘
                                          │ Scraped / Pushed
                                          ▼
                               ┌─────────────────────┐
                               │    Grafana Alloy    │
                               │  (Central Collector)│
                               └──────────┬──────────┘
                                          │
                  ┌───────────────────────┴───────────────────────┐
                  ▼                                               ▼
      ┌───────────────────────┐                       ┌───────────────────────┐
      │   Prometheus Server   │                       │      Loki Ingest      │
      │  (PromQL Rule Engine) │                       │ (LogQL Anomaly Rules) │
      └───────────┬───────────┘                       └───────────┬───────────┘
                  │ Firing Alerts                                 │ Log Anomaly
                  ▼                                               │
      ┌────────────────────────────────────────────────────────┐  │
      │                  Alertmanager (:9093)                  │◄─┘
      │  - Route tree: critical & warning severity             │
      │  - Cascade Inhibition: InstanceDown inhibits symptoms  │
      │  - OOM Inhibition: ContainerOomKilled inhibits crash   │
      └───────────────────────────┬────────────────────────────┘
                                  │ Webhook Dispatch
                                  ▼
      ┌────────────────────────────────────────────────────────┐
      │              Webhook Receiver / On-Call Sink           │
      │           (Mattermost, Slack, Discord, PagerDuty)      │
      └────────────────────────────────────────────────────────┘
```

1. **Rule Engine:** Evaluated by Prometheus Server (`prometheus-community/prometheus`) and Loki Ruler.
2. **Rule Injection Method:** 
   - Chart-native `serverFiles.alerting_rules.yml` in `deployment/{env}/values-prometheus.yaml` (automatically watched and reloaded by `configmap-reload`).
   - GitOps-managed ConfigMap file: `deployment/common/alerts/prometheus-alerting-rules.yaml` (synced via `task configmap:prometheus-alert`).
   - LogQL rule file: `deployment/common/alerts/loki-alerting-rules.yaml`.
3. **Dispatcher:** Dispatched to Alertmanager on port `:9093` via dynamic Kubernetes Pod Discovery (`role: pod`, `app=alertmanager`).
4. **Dispatcher Receivers:** `webhook-notifications` with automatic `send_resolved: true` and fallback `null-receiver`. Webhook URLs are securely injected from the Kubernetes secret `alertmanager-secrets` (generated via `task secret:alertmanager`).
5. **Dashboard Correlation:** Every alert includes a `runbook_url` pointing directly to the unified **Service Health & Alerting Overview** Grafana dashboard (`UID: service-health-and-alerts`).

---

## 📂 Prometheus Alert Rules Catalog (28 Rules Across 5 Domains)

### 1. Spring Boot & Application RED Alerts (`spring_boot_red_alerts`)

| Alert Name | Expression / Condition | Severity | Tier | Description / Action |
| :--- | :--- | :--- | :--- | :--- |
| `InstanceAbsent` | `absent(up{service_name="spring-boot-app"})` | `critical` | Application | Dead-man switch: no metrics received for service. |
| `InstanceDown` | `up{service_name="spring-boot-app"} == 0` | `critical` | Application | Scrape target failing or endpoint returning errors. |
| `ServiceDown` | `absent(up{...}) or up{...} == 0` | `critical` | Application | Root-cause alert used to inhibit downstream symptom alerts. |
| `HighHttpErrorRate` | HTTP 5xx rate > 5% over 5m | `critical` | Application | Server error surge affecting end users. |
| `HighHttpLatencyP99` | P99 latency > 2000ms over 5m | `warning` | Application | Breach of user experience SLA. Links to Tempo Exemplars. |
| `HttpTrafficSpike` | HTTP rate > 100 req/sec over 2m | `warning` | Application | Unexpected traffic surge or denial-of-service attempt. |
| `HttpTrafficDrop` | Rate drops near 0 after active traffic | `warning` | Application | Silent failure, upstream proxy failure, or DNS stall. |
| `PokemonApiHighErrorRate` | Pokemon controller error rate > 5% | `critical` | Business | Specific business API endpoint failure. |
| `PokemonApiHighLatency` | Pokemon controller P99 latency > 2000ms | `warning` | Business | Specific business API degradation. |
| `HighCpuUsage` | Container CPU rate > 80% quota over 2m | `warning` | Resource | CPU saturation leading to potential response throttling. |

---

### 2. JVM Runtime & Database Connection Pool Alerts (`jvm_and_database_alerts`)

| Alert Name | Expression / Condition | Severity | Tier | Description / Action |
| :--- | :--- | :--- | :--- | :--- |
| `JvmHeapUsageHigh` | Heap used / max > 85% for 3m | `critical` | Runtime | Impending OutOfMemoryError. Check memory leaks / heap dumps. |
| `JvmMetaspaceUsageHigh` | Metaspace used / max > 90% for 5m | `critical` | Runtime | Metaspace exhaustion from classloader leaks. |
| `JvmHighGcOverhead` | GC pause time rate > 0.15s/s (15%) | `warning` | Runtime | Excessive GC pauses consuming >15% of application runtime. |
| `JvmThreadCountHigh` | Live thread count > 250 for 5m | `warning` | Runtime | Unbounded thread creation or thread pool leaks. |
| `JvmThreadContention` | Blocked threads > 10 for 2m | `warning` | Runtime | Severe monitor contention or database transaction deadlocks. |
| `HikariPoolStarvation` | Pending connections > 0 for 1m | `critical` | Database | Threads blocked waiting for database connections. |
| `HikariConnectionTimeoutErrors`| `rate(connections_timeout_total) > 0` | `critical` | Database | Requests timed out waiting for connection acquire. |
| `HikariConnectionAcquireLatencyHigh` | P99 acquire time > 250ms for 3m | `warning` | Database | Database pool saturation or database server latency. |

---

### 3. Debezium CDC Streaming Alerts (`debezium_cdc_alerts`)

| Alert Name | Expression / Condition | Severity | Tier | Description / Action |
| :--- | :--- | :--- | :--- | :--- |
| `DebeziumDisconnected` | `debezium_connected == 0` for 1m | `critical` | CDC | CDC engine disconnected from MongoDB replica set oplog. |
| `DebeziumReplicationLagHigh` | Milliseconds behind source > 30000 | `warning` | CDC | Replication lag > 30s. Downstream data out of sync. |
| `DebeziumQueueSaturated` | Remaining queue capacity < 10% | `critical` | CDC | Internal event buffer near exhaustion; risk of event drop. |

---

### 4. Kubernetes Infrastructure & Storage Alerts (`kubernetes_and_storage_alerts`)

| Alert Name | Expression / Condition | Severity | Tier | Description / Action |
| :--- | :--- | :--- | :--- | :--- |
| `PodCrashLooping` | Restarts > 0 over last 5m | `critical` | Infrastructure | Pod repeatedly crashing. |
| `ContainerOomKilled` | Terminated reason is `OOMKilled` | `critical` | Infrastructure | Kernel OOM killer terminated container (cgroup memory breached). |
| `KubernetesCpuThrottlingHigh` | CFS throttled periods > 25% | `warning` | Infrastructure | CFS quota throttling CPU cycles; app throughput restricted. |
| `PvcStoragePredictiveExhaustion` | `predict_linear` predicts full in < 4h | `critical` | Storage | PVC disk growth indicates volume full within 4 hours. |
| `HostDiskFillingFast` | Root filesystem free < 10% | `critical` | Host | Node disk space nearly exhausted. |

---

### 5. RustFS S3 Object Storage Alerts (`rustfs_storage_alerts`)

| Alert Name | Expression / Condition | Severity | Tier | Description / Action |
| :--- | :--- | :--- | :--- | :--- |
| `RustFsStorageErrorRateHigh` | RustFS S3 5xx errors > 5% over 3m | `critical` | Storage | S3 storage backend failing to serve Loki/Tempo object requests. |
| `RustFsDriveUnhealthy` | Disk status != healthy or nodes offline | `critical` | Storage | Hardware or node fault in RustFS distributed storage cluster. |

---

## 🪵 Loki LogQL Anomaly Alerts (`loki-alerting-rules.yaml`)

| Alert Name | LogQL Expression | Severity | Description |
| :--- | :--- | :--- | :--- |
| `HighSeverityLogSpike` | `sum(rate({namespace="monitoring"} \|= "ERROR" [5m])) > 10` | `warning` | High volume of ERROR logs (> 10/s) across services. |
| `JavaOutOfMemoryErrorLogged` | `count_over_time({service_name="spring-boot-app"} \|= "java.lang.OutOfMemoryError" [5m]) > 0` | `critical` | Instant alert upon `OutOfMemoryError` logged by JVM. |
| `UnhandledExceptionSpike` | `sum(rate({service_name="spring-boot-app"} \|= "Exception" [5m])) > 5` | `warning` | Spike in unhandled exception stack traces. |
| `LokiRequestErrors` | `loki_request_duration_seconds_count{status_code=~"5.."}` > 10% | `critical` | Loki backend 5xx push/query failures. |
| `LokiIngesterUnhealthy` | `loki_ring_members{state="Unhealthy", name="ingester"} > 0` | `critical` | Ingester pod failure in gossip ring. |
| `LokiCompactorUnhealthy`| `increase(loki_compactor_runs_failed_total[1h]) > 2` | `critical` | Table compaction / retention cleanup failure. |
| `LokiPanics` | `increase(loki_panic_total[10m]) > 0` | `critical` | Fatal Go panic in Loki process. |

---

## 🛡️ Alertmanager Hardening: Inhibition Rules

To avoid catastrophic **alert storms** when foundational components fail, Alertmanager is configured with cascading inhibition rules:

```yaml
inhibit_rules:
  # 1. When an entire service or instance is DOWN, suppress symptoms like latency, errors, and pool starvation
  - source_matchers:
      - alertname =~ "ServiceDown|InstanceDown|InstanceAbsent"
    target_matchers:
      - alertname =~ "HighHttpErrorRate|HighHttpLatencyP99|PokemonApiHighErrorRate|PokemonApiHighLatency|HikariPoolStarvation|HighCpuUsage"
    equal: ['service_name', 'namespace']

  # 2. When a container is OOMKilled, suppress the generic CrashLooping alert to pinpoint root cause immediately
  - source_matchers:
      - alertname = "ContainerOomKilled"
    target_matchers:
      - alertname = "PodCrashLooping"
    equal: ['pod', 'namespace']
```

---

## 📊 Unified "Service Health & Alerting" Grafana Dashboard

- **UID:** `service-health-and-alerts`
- **Location:** `deployment/common/dashboards/service-health-and-alerts.json`
- **Sidecar Provisioning:** Synced automatically via `task configmap:grafana-dashboard`.
- **Key Visual Rows:**
  1. **Executive Health & Alert Summary:** Live UP/DOWN stat badge, Active Critical & Warning counters, 5xx Server Error % gauge.
  2. **Active Alert Feed:** Built-in `alertlist` panel showing live firing/pending alerts with direct runbook links.
  3. **RED Method Row:** Request throughput (req/s), HTTP 5xx error rate (threshold line at 5%), and P50/P90/P99 latency with **Tempo Exemplar diamonds** for 1-click trace drill-down.
  4. **JVM & Database Runtime (USE Row):** Heap & Metaspace memory utilization vs. max, GC pause overhead (%), live thread counts, and HikariCP connection pool states.
  5. **CDC & Real-Time Logs Row:** Debezium replication lag (ms), queue capacity, and live Loki error stream pre-filtered for the service.
  6. **Namespace Filter:** Includes `$namespace` template variable for multi-tenant and multi-environment filtering.

---

## 🛠️ Verification & Operations Commands

```powershell
# 1. Validate Prometheus & Alertmanager configs
task check:prometheus
task check:alertmanager

# 2. Push updated dashboards & alert rules
task configmap:grafana-dashboard
task configmap:prometheus-alert

# 3. Port-forward Alertmanager & Grafana
task pf:alertmanager   # http://localhost:9093
task pf:grafana        # http://localhost:3000
```
