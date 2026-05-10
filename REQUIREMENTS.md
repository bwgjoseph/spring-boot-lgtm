# Production Observability Requirements (Platform)

This document outlines the high-level goals for the **Spring Boot LGTM Stack** in a single-cluster production environment.

---

## 🎯 1. Reliability & Durability Goals

### 1.1 Zero Data Loss
- **Persistence:** All telemetry data (Metrics, Logs, Traces) must be stored in S3-compatible object storage to decouple compute from storage.
- **Resilience:** The ingestion pipeline must survive the failure of any single node or pod without data loss.

### 1.2 High Availability (HA)
- **Minimum Replicas:** All core components must run with a minimum of **3 replicas**.
- **Redundancy:** Pod anti-affinity must ensure replicas are distributed across different physical nodes.

---

## 💾 2. Master Data Retention Standards

| Data Type | Hot Storage (SSD/WAL) | Cold Storage (S3) | Total Retention | Rationale |
| :--- | :--- | :--- | :--- | :--- |
| **Metrics** | 6 Hours | 90 Days | **90 Days** | Quarterly capacity and trend analysis. |
| **Logs** | 24 Hours | 30 Days | **30 Days** | Incident post-mortems and basic auditing. |
| **Traces** | 1 Hour | 7 Days | **7 Days** | Active incident response; value decays rapidly. |

---

## 📊 3. Performance & Scaling

### 3.1 Design for Growth
- The architecture must support a **3x increase** in current telemetry volume without requiring a fundamental re-architecture.

### 3.2 Dashboard Latency
- **Target:** Standard RED metrics and high-level health dashboards should render within **2 seconds** for 24-hour time ranges.

### 3.3 Telemetry Processing Model
To optimize network efficiency and ensure sampling accuracy, the ingestion layer must follow a hybrid collection model:
- **Local-Only Path (Logs & Metrics):** Data is collected or scraped from pods residing on the same physical node as the collector. This data moves directly to the egress sinks without leaving the node, minimizing cross-node network traffic.
- **Clustered Path (Traces):** Traces are received from local pods but must be load-balanced across the collector cluster to ensure all spans of a single `trace_id` land on the same instance. This "Trace Affinity" is mandatory for accurate tail-based sampling decisions.

---

## 🔔 4. Alerting & SRE Standards
- **Channel:** All critical alerts must be delivered to **Mattermost**.
- **Availability:** Alert if any production service is `down` or in `CrashLoopBackOff` for > 1 minute.
- **Latency:** Alert if the 99th percentile (P99) latency exceeds thresholds for > 5 minutes.
- **Errors:** Alert if the HTTP 5xx error rate exceeds 1% of total traffic.
- **Design:** These standards provide the baseline for future SLI/SLO and Error Budget management.

---
## 🛡️ 5. Security & Infrastructure
- **Ingress & TLS:** TLS termination is mandatory at the Ingress controller level. Use **Cert-Manager** for automated certificate rotation.
- **Network Policies:** Implement strict `NetworkPolicy` to restrict traffic between observability components.
- **Secret Management:** Sensitive credentials (S3 keys, Database passwords) must be managed strictly via Kubernetes Secrets.

## 🌉 6. Gateway & Forwarding
- **External Egress Gateway:** The collector layer (Alloy) must act as a central egress point, capable of selectively mirroring or forwarding telemetry data (logs, metrics, traces) to external gateways managed by central platform or security teams.

---

## 🕵️ 7. Technical Unknowns & Investigations
- **RWX Support:** Investigation required for **ReadWriteMany** storage (See `PRODUCTION_FOLLOW_UP.md`).
- **S3 Performance:** Confirm managed vs. self-hosted S3 performance for high-throughput ingesters.

## 🔗 Component Specific Requirements
- [Alloy: Ingestion & Forwarding](./requirements/alloy.md)
- [Loki: Log Integrity & Queries](./requirements/loki.md)
- [Tempo: Trace Durability](./requirements/tempo.md)
- [Mimir: Metric Scalability](./requirements/mimir.md)
- [Debezium: CDC Requirements](./requirements/debezium.md)
- [Grafana: Visualization & Alerting](./requirements/grafana.md)
- [Alertmanager: Alert Routing](./requirements/alertmanager.md)
- [MinIO: Object Storage](./requirements/minio.md)
