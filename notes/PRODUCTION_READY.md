# Production Readiness: LGTM Observability Stack (On-Prem)

This document outlines production requirements for the LGTM observability stack (Loki, Grafana, Tempo, Mimir/Prometheus). It details configurations for high availability, scalability, storage, retention, and security.

---

## II. Core Components & Production Configuration

### Grafana Alloy
Grafana Alloy acts as the central observability gateway. 
*   **Topology:** Clustered Deployment (2+ replicas) for HA.
*   **Cardinality Firewall:** Mandatory implementation of relabeling rules in `discovery.relabel` to drop ephemeral metadata (e.g., `pod_template_hash`) and protect Loki/Mimir indexes.
*   **Self-Observability:** Mandatory `prometheus.exporter.self` to monitor pod health/dropped data.
*   **RBAC:** Requires `ClusterRole` with `get`, `watch`, and `list` for `pods`, `namespaces`, and `nodes`.

### Loki
Loki is the log aggregation engine.
*   **Scaling Mode:** `SimpleScalable` separating Read, Write, and Backend.
*   **Index Gateway:** Mandatory component for TSDB schema performance; must be configured in `ring` mode.
*   **Query Sharding:** `tsdb_max_query_parallelism: 128` is required to handle 14-day search windows.
*   **Storage Strategy:** MinIO with dedicated buckets for `chunks`, `ruler`, and `admin`.

### Tempo
Tempo is the trace repository.
*   **Scaling Mode:** Scalable Monolithic (Replicas 2+).
*   **Performance:** WAL **must** be hosted on high-performance SSD/NVMe (20Gi).
*   **Columnar Search:** Must use `vParquet4` and enabled vertical compaction to maintain search speed at scale.

### Grafana
*   **High Availability (HA):** For 3+ replicas, an **external PostgreSQL database** is mandatory to persist user sessions and dashboard states; SQLite is strictly prohibited.
*   **Dashboard Provisioning:** Sidecar pattern with `grafana_dashboard=1` labels is the mandatory deployment pattern.

### Mimir
*   **Ruler Evaluation:** Mimir's Ruler must use **Remote Evaluation** (query-frontend) to prevent OOMs during rule bursts.
*   **Ingestion:** Remote Write protocol from Prometheus/Alloy instances.

---

## III. General Production Considerations

### S3 Backend (MinIO / AWS S3)
- **Isolation:** Each component (Loki, Tempo, Mimir) **must** have its own bucket or unique prefix to avoid rate-limiting.
- **Security:** Static credentials via `existingSecret` are mandatory.

### Persistence
- **WAL Durability:** All components with WAL (Loki Ingester, Tempo Ingester) require SSD storage to handle the I/O demand of high-frequency flushes.

### Ingress & Security
- **TLS Termination:** Always performed at the Ingress controller level.
- **Network Policies:** Strict egress/ingress isolation between observability pods and external services.
