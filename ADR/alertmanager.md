# ADR: Alertmanager Dispatch, Grouping & Notification

## Status
Accepted

## Context
Alertmanager is the centralized notification dispatcher for the production cluster, handling all alerts fired by Prometheus. It must perform intelligent deduplication, grouping, and silencing to prevent notification fatigue during cascading failures, and route resolved alerts for clear incident closure visibility.

---

## Architecture & Alert Flow

### 1. Alert Pipeline Diagram
```mermaid
flowchart TD
    subgraph RulesSource ["Alert Rules (ConfigMap)"]
        CM["prometheus-alert-rules ConfigMap<br/><i>Mounted at /etc/config/rules/*.yaml</i>"]
    end

    subgraph PrometheusServer ["Prometheus Server"]
        PROM["Prometheus<br/><i>Evaluates rules every 1m</i>"]
        CM -->|"extraVolumes + extraVolumeMounts"| PROM
    end

    subgraph AlertManagerDiscovery ["Alertmanager Discovery (Kubernetes SD)"]
        K8S_SD["kubernetes_sd_configs (role: pod)<br/><i>namespace=monitoring<br/>label=alertmanager<br/>port=9093</i>"]
    end

    subgraph AlertManager ["Alertmanager (Port: 9093)"]
        ROUTE["Route Engine<br/><i>group_by: [alertname, cluster, service, namespace]<br/>group_wait: 30s | group_interval: 5m<br/>repeat_interval: 4h | resolve_timeout: 5m</i>"]
        NULL_RCV["null-receiver<br/><i>(Current placeholder - no outbound notification)</i>"]
        MATTER["Mattermost Webhook<br/><i>(Target configuration - pending webhook URL)</i>"]
        PV[("PersistentVolume<br/><i>10Gi - Silences & Notification State</i>")]

        ROUTE --> NULL_RCV
        ROUTE -.->|"Planned"| MATTER
        ROUTE <--> PV
    end

    PROM -->|"Fire Alerts (HTTP)"| K8S_SD
    K8S_SD -->|"Dynamic Discovery"| AlertManager

    classDef prom fill:#fff3e0,stroke:#e65100,stroke-width:2px;
    classDef am fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px;
    classDef sink fill:#e1f5fe,stroke:#0277bd,stroke-width:1px;
    classDef pending stroke-dasharray:5 5;

    class PROM prom;
    class ROUTE,NULL_RCV am;
    class MATTER sink;
```

---

## Decision

1. **Deployment:** Alertmanager is deployed as part of the **`prometheus-community/prometheus`** Helm chart (`alertmanager.enabled: true`) rather than as a standalone component, co-located with the Prometheus server in the `monitoring` namespace.

2. **Alertmanager Discovery (Kubernetes SD):**
   Prometheus uses **Kubernetes pod service discovery** to dynamically locate the Alertmanager endpoint without hardcoding pod IPs:
   ```yaml
   kubernetes_sd_configs:
     - role: pod
   relabel_configs:
     - source_labels: [__meta_kubernetes_namespace]
       regex: monitoring
     - source_labels: [__meta_kubernetes_pod_label_app_kubernetes_io_name]
       regex: alertmanager
     - source_labels: [__meta_kubernetes_pod_container_port_number]
       regex: "9093"
   ```

3. **Alert Rules Delivery (ConfigMap Mount):**
   Alerting rule files are stored in a shared Kubernetes ConfigMap (`prometheus-alert-rules`) and mounted into the Prometheus pod at `/etc/config/rules/*.yaml` via `extraVolumes` and `extraVolumeMounts`. This enables GitOps-style rule management without Prometheus server restarts.

4. **Grouping & Deduplication:**
   - **Group by:** `['alertname', 'cluster', 'service', 'namespace']` — ensures related alerts in the same scope are batched into a single notification.
   - **`group_wait: 30s`** — buffer time to collect all alert instances before sending the first notification.
   - **`group_interval: 5m`** — minimum time between follow-up notifications for the same group.
   - **`repeat_interval: 4h`** — suppression window for repeated notifications of the same ongoing alert.
   - **`resolve_timeout: 5m`** — time before an alert transitions to resolved if no longer firing.

5. **Notification Receiver & Webhook Dispatch:**
   - **Implemented:** Dynamic webhook receiver (`webhook-notifications`) with `send_resolved: true` targeting internal or external incident webhooks (Mattermost/Slack/Discord) injected via Kubernetes secrets (`alertmanager-secrets`).
   - Alerts with `severity: critical` and `severity: warning` route to `webhook-notifications` with fallback to `null-receiver` if disabled.

6. **Inhibition Rules (Alert Storm Suppression):**
   - **Root Cause Suppression:** When `ServiceDown`, `InstanceDown`, or `InstanceAbsent` fires, Alertmanager automatically inhibits cascading symptom alerts (`HighHttpErrorRate`, `HighHttpLatencyP99`, `PokemonApiHighErrorRate`, `PokemonApiHighLatency`, `HikariPoolStarvation`, `HighCpuUsage`) for that service.
   - **Container Failure Suppression:** When `ContainerOomKilled` fires, it inhibits generic `PodCrashLooping` alerts for the same pod.

7. **State Persistence:**
   - Production Alertmanager uses a **10Gi PersistentVolume** (`alertmanager.persistentVolume.enabled: true, size: 10Gi`) to durably store silence definitions and notification state across pod restarts.
   - Dev uses ephemeral in-memory storage suitable for local sandboxes.

---

## Implemented Alert Rules Catalog

| Alert Domain | Alert Name | Expression Summary | Severity | Purpose & Target |
| :--- | :--- | :--- | :--- | :--- |
| **App RED** | `InstanceAbsent` | `absent(up{service_name="spring-boot-app"})` | critical | Dead-man switch: pod absent or collector unreachable. |
| **App RED** | `InstanceDown` | `up{service_name="spring-boot-app"} == 0` | critical | Scrape failure on running pod. |
| **App RED** | `HighHttpErrorRate` | 5xx error rate > 5% over 5m | critical | General application HTTP SLA breach. |
| **App RED** | `HighHttpLatencyP99` | P99 latency > 2000ms over 5m | warning | High latency SLA breach; links to Tempo Exemplars. |
| **Business RED**| `PokemonApiHighErrorRate` | Controller 5xx rate > 5% | critical | Core domain business API failure. |
| **Business RED**| `PokemonApiHighLatency` | Controller P99 latency > 2000ms | warning | Core domain business API degradation. |
| **JVM USE** | `JvmHeapUsageHigh` | Heap usage > 85% | critical | Immediate risk of OutOfMemoryError. |
| **JVM USE** | `JvmMetaspaceUsageHigh` | Metaspace > 90% | critical | Classloader leak or metaspace exhaustion. |
| **JVM USE** | `JvmHighGcOverhead` | GC pauses > 15% CPU time | warning | Excessive garbage collection latency. |
| **Database** | `HikariPoolStarvation` | Pending connections > 0 for 1m | critical | Database pool exhaustion and caller thread blocking. |
| **Database** | `HikariConnectionAcquireLatencyHigh` | Acquire P99 > 250ms | warning | Slow database connection acquisition. |
| **CDC Stream** | `DebeziumDisconnected` | `debezium_connected == 0` | critical | CDC stream severed from MongoDB oplog. |
| **CDC Stream** | `DebeziumReplicationLagHigh` | Lag > 30000ms | warning | Change data capture falling behind source DB. |
| **CDC Stream** | `DebeziumQueueSaturated` | Remaining buffer < 10% | critical | Imminent event drop in CDC memory queue. |
| **K8s & Host** | `PodCrashLooping` | Restarts > 0 over 5m | critical | Repeated container crashing. |
| **K8s & Host** | `ContainerOomKilled` | OOMKilled == 1 | critical | Linux cgroup memory limit termination. |
| **Storage** | `PvcStoragePredictiveExhaustion` | Linear projection full in < 4h | critical | Automated predictive volume exhaustion warning. |

---

## Technical Specification & Implementation Mapping

| Key / Config Path | Value / Setting | Purpose | Environment |
| :--- | :--- | :--- | :--- |
| `alertmanager.enabled` | `true` | Deploy Alertmanager alongside Prometheus. | dev, prod |
| `alertmanager.persistentVolume` | `enabled: true, size: 10Gi` | Persist silence rules and notification state. | prod only |
| `config.alerting.alertmanagers` | Kubernetes SD (namespace=monitoring, port=9093) | Dynamic Alertmanager pod discovery. | dev, prod |
| `server.config.rule_files` | `/etc/config/rules/*.yaml` | Loads alert rules from mounted ConfigMap. | dev, prod |
| `extraVolumes / extraVolumeMounts` | ConfigMap: `prometheus-alert-rules` | GitOps-managed alert rule delivery. | dev, prod |
| `route.group_by` | `['alertname', 'cluster', 'service', 'namespace']` | Deduplication and notification consolidation. | dev, prod |
| `route.group_wait` | `30s` | Buffer time before initial notification. | dev, prod |
| `route.group_interval` | `5m` | Minimum time between follow-up notifications. | dev, prod |
| `route.repeat_interval` | `4h` | Suppression window for ongoing alert re-notification. | dev, prod |
| `route.receiver` | `webhook-notifications` | Active webhook notification dispatcher. | dev, prod |
| `inhibit_rules` | ServiceDown/InstanceDown/OOMKilled suppression | Prevents cascading alert storms. | dev, prod |

---

## Consequences

- **Positive:**
  - Kubernetes SD ensures Alertmanager is always discovered dynamically, surviving pod rescheduling without config changes.
  - Comprehensive RED and USE alert catalog covers application, JVM, database, CDC, and host infrastructure.
  - Inhibition rules eliminate noise by silencing symptom alerts when root cause failure occurs.
  - All alerts link directly to the unified **Service Health & Alerting** dashboard in Grafana.
  - Webhook dispatch with secret reference enables zero-plaintext GitOps incident notification.
- **Negative:**
  - Highly dynamic environments require tuning prediction windows on `PvcStoragePredictiveExhaustion` to avoid false positives during burst data loads.
- **Risk:**
  - If the ConfigMap `prometheus-alert-rules` is deleted or malformed, Prometheus will load no alerting rules and fire no alerts until corrected.
