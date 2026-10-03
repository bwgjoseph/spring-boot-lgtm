# 🚨 Commonly Used Prometheus Alerting Rules Guide

This document catalogs standard, high-impact alerting rules curated from production best practices and [`awesome-prometheus-alerts`](https://samber.github.io/awesome-prometheus-alerts/) tailored specifically for our **Spring Boot 3.5 + LGTM** observability sandbox and production workloads.

---

## 🎯 Alerting Architecture in This Stack

1. **Rule Engine:** Evaluated by Prometheus Server (`prometheus-community/prometheus`).
2. **Rule Injection Method:** 
   - Chart-native `serverFiles.alerting_rules.yml` in `values-prometheus.yaml` (automatically monitored by `configmap-reload`).
   - GitOps-managed ConfigMap file: `deployment/common/alerts/prometheus-alerting-rules.yaml`.
3. **Dispatcher:** Dispatched to Alertmanager on port `:9093` via dynamic Kubernetes Pod Discovery (`role: pod`, `app=alertmanager`).
4. **Current Receiver:** `null-receiver` (Mattermost webhook target planned).

---

## 📂 Alert Rules by Domain

### 1. JVM & Spring Boot Runtime Alerts

Spring Boot Micrometer exports standard JVM metrics to `/actuator/prometheus`. These alerts catch runtime degradation before it causes catastrophic OutOfMemory (OOM) crashes.

```yaml
groups:
  - name: jvm_alerts
    rules:
      # --- JVM Heap Memory Exhaustion (> 85%) ---
      - alert: JvmHeapUsageHigh
        expr: (sum(jvm_memory_used_bytes{area="heap"}) by (pod, namespace) / sum(jvm_memory_max_bytes{area="heap"}) by (pod, namespace)) * 100 > 85
        for: 3m
        labels:
          severity: warning
        annotations:
          summary: "JVM Heap usage > 85% on {{ $labels.pod }}"
          description: "Pod {{ $labels.pod }} JVM heap usage is {{ $value | printf \"%.1f\" }}% of max allocated memory."

      # --- Metaspace Near Capacity (> 90%) ---
      - alert: JvmMetaspaceUsageHigh
        expr: (sum(jvm_memory_used_bytes{id="Metaspace"}) by (pod, namespace) / sum(jvm_memory_max_bytes{id="Metaspace"}) by (pod, namespace)) * 100 > 90
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "JVM Metaspace > 90% on {{ $labels.pod }}"
          description: "Metaspace is filling up rapidly; risk of java.lang.OutOfMemoryError: Metaspace."

      # --- Excessive Garbage Collection Pause Time ---
      - alert: JvmGarbageCollectionSlow
        expr: sum(rate(jvm_gc_pause_seconds_sum[1m])) by (pod, action) > 0.3
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "High GC overhead on {{ $labels.pod }}"
          description: "GC pauses are consuming more than 300ms/second (30% of application runtime) over the last minute."

      # --- Thread Deadlock / Thread Saturation ---
      - alert: JvmThreadCountHigh
        expr: jvm_threads_live_threads{service_name="spring-boot-app"} > 250
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High JVM active thread count on {{ $labels.pod }}"
          description: "Live threads ({{ $value }}) exceeded threshold; check for thread leaks or connection pool starvation."
```

---

### 2. HTTP & API Service Level Objectives (SLOs)

Using Golden Signals / RED (Rate, Errors, Duration) metrics exported by Micrometer's `http.server.requests`:

```yaml
  - name: api_slo_alerts
    rules:
      # --- HTTP 5xx Server Error Rate Spike (> 5%) ---
      - alert: Http5xxRateHigh
        expr: |
          (
            sum(rate(http_server_requests_seconds_count{status=~"5.."}[5m]))
            /
            sum(rate(http_server_requests_seconds_count[5m]))
          ) * 100 > 5
        for: 3m
        labels:
          severity: critical
        annotations:
          summary: "High HTTP 5xx error rate on {{ $labels.service_name }}"
          description: "Server error rate is {{ $value | printf \"%.1f\" }}% over the last 5 minutes."

      # --- High P99 Request Latency (> 1000ms) ---
      - alert: HttpLatencyP99High
        expr: |
          histogram_quantile(0.99,
            sum(rate(http_server_requests_seconds_bucket[5m])) by (le, uri)
          ) * 1000 > 1000
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "P99 latency > 1000ms for {{ $labels.uri }}"
          description: "Endpoint {{ $labels.uri }} has P99 latency of {{ $value | printf \"%.0f\" }}ms."
```

---

### 3. Debezium CDC Engine Alerts

Debezium embedded metrics are bridged to Micrometer via our `DebeziumMetricsBinder`:

```yaml
  - name: debezium_alerts
    rules:
      # --- Debezium Streaming Queue Congestion ---
      - alert: DebeziumQueueSaturation
        expr: (debezium_queue_remaining_capacity == 0)
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "Debezium queue saturated on {{ $labels.pod }}"
          description: "Debezium buffer queue has 0 remaining capacity; downstream consumer cannot keep pace with change log."

      # --- Debezium Connection / Snapshot Errors ---
      - alert: DebeziumConnectorStatusDown
        expr: debezium_connected{status="false"} == 1
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Debezium CDC connector disconnected"
          description: "Debezium connector is disconnected from MongoDB replica set."
```

---

### 4. Kubernetes Node & Container Infrastructure Alerts

Exported by `prometheus-node-exporter` and `kube-state-metrics`:

```yaml
  - name: infrastructure_alerts
    rules:
      # --- Node Disk Space Filling Up (Will fill within 4 hours) ---
      - alert: DiskWillFillIn4Hours
        expr: (node_filesystem_free_bytes / node_filesystem_size_bytes < 0.15) and (predict_linear(node_filesystem_free_bytes[1h], 4 * 3600) < 0)
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Disk volume {{ $labels.mountpoint }} will fill in < 4h on {{ $labels.instance }}"
          description: "Filesystem on {{ $labels.mountpoint }} is below 15% and predicted to run out of space within 4 hours."

      # --- Pod CrashLooping ---
      - alert: PodCrashLooping
        expr: rate(kube_pod_container_status_restarts_total[15m]) * 60 * 5 > 0
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Pod {{ $labels.pod }} is crashlooping"
          description: "Pod {{ $labels.pod }} restarted {{ $value | printf \"%.0f\" }} times in the last 5 minutes."

      # --- Container Memory Limit Throttling / OOMKilled ---
      - alert: ContainerOOMKilled
        expr: (kube_pod_container_status_terminated_reason{reason="OOMKilled"} > 0)
        for: 0m
        labels:
          severity: critical
        annotations:
          summary: "Container {{ $labels.container }} in pod {{ $labels.pod }} OOMKilled"
          description: "Container was terminated by kernel out-of-memory killer."
```

---

### 5. Kafka / Redpanda Streaming Alerts

Metrics collected from Redpanda native endpoints (`:9644`) or Alloy's `prometheus.exporter.kafka`:

```yaml
  - name: kafka_redpanda_alerts
    rules:
      # --- Kafka Consumer Group Lag High ---
      - alert: KafkaHighConsumerLag
        expr: sum(kafka_consumergroup_lag) by (consumergroup, topic) > 1000
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Consumer lag high for group {{ $labels.consumergroup }}"
          description: "Consumer group {{ $labels.consumergroup }} on topic {{ $labels.topic }} has lag of {{ $value }} messages."

      # --- Redpanda Under-Replicated Partitions ---
      - alert: RedpandaUnderReplicatedPartitions
        expr: redpanda_kafka_under_replicated_replicas > 0
        for: 3m
        labels:
          severity: critical
        annotations:
          summary: "Redpanda under-replicated partitions detected"
          description: "{{ $value }} partitions in Redpanda are under-replicated; replica fault in cluster."
```

---

### 6. LGTM Backend Storage Alerts (Loki & Tempo)

Already present in `deployment/dev/values-prometheus.yaml`:

| Alert Name | Expression | Severity | Meaning |
| :--- | :--- | :--- | :--- |
| `LokiRequestErrors` | `loki_request_duration_seconds_count{status_code=~"5.."}` > 10% | critical | Loki 5xx push/query failures |
| `LokiIngesterUnhealthy` | `loki_ring_members{state="Unhealthy", name="ingester"} > 0` | critical | Ingester pod failure in gossip ring |
| `LokiCompactorUnhealthy` | `increase(loki_compactor_runs_failed_total[1h]) > 2` | critical | Retention/compaction table cleanup failed |
| `TempoMetricsGeneratorUnhealthy` | `tempo_ring_members{state="Unhealthy", name="metrics-generator"} > 0` | critical | Metrics-from-traces processor down |
| `TempoCompactionsFailing` | `increase(tempodb_compaction_errors_total[1h]) > 2` | critical | Trace block compaction errors |

---

## 🛠️ How to Add New Rules to the Stack

### Option 1: Via GitOps ConfigMap (`Taskfile.yml`)
1. Edit [`deployment/common/alerts/prometheus-alerting-rules.yaml`](../deployment/common/alerts/prometheus-alerting-rules.yaml).
2. Sync the ConfigMap:
   ```powershell
   task configmap:prometheus-alert
   ```
3. Prometheus `configmap-reload` sidecar will automatically detect changes within 30–60 seconds.

### Option 2: Via Helm Values (`values-prometheus.yaml`)
1. Add the group under `serverFiles.alerting_rules.yml.groups`.
2. Upgrade Prometheus:
   ```powershell
   task prometheus
   ```
