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
*   **Scaling Mode:** Microservices Mode (tempo-distributed) with Redpanda streaming buffer.
*   **Performance:** WAL **must** be hosted on high-performance SSD/NVMe (20Gi).
*   **Columnar Search:** Must use `vParquet4` and enabled vertical compaction to maintain search speed at scale.

### Grafana
*   **High Availability (HA):** For 3+ replicas, an **external PostgreSQL database** is mandatory to persist user sessions and dashboard states; SQLite is strictly prohibited.
*   **Dashboard Provisioning:** Sidecar pattern with `grafana_dashboard=1` labels is the mandatory deployment pattern.

### Mimir / Prometheus & Alertmanager
*   **Prometheus & Alertmanager:** High Availability pair with PersistentVolumes for TSDB (120Gi) and Alertmanager silence/notification state (10Gi).
*   **Alert Routing & Inhibition:** Cascade inhibition rules (`ServiceDown` suppresses downstream symptom alerts; `ContainerOomKilled` suppresses crashloop alerts) and webhook dispatch with Kubernetes secret injection (`alertmanager-secrets`).
*   **Ruler Evaluation:** When migrating to Mimir, Mimir's Ruler must use **Remote Evaluation** (query-frontend) to prevent OOMs during rule bursts.
*   **Ingestion:** Remote Write protocol from Prometheus/Alloy instances.

---

## III. General Production Considerations

### S3 Backend (RustFS / MinIO / AWS S3)
- **Isolation:** Each component (Loki, Tempo, Mimir, Pyroscope) **must** have its own bucket or unique prefix to avoid rate-limiting.
- **Security:** Static credentials via `existingSecret` are mandatory. RustFS 1.0.3 provides Apache 2.0 distributed Reed-Solomon EC:2 storage across production nodes.

### Persistence & StorageClasses
- **Access Mode Policy (RWO vs RWX):** All stateful observability components (Alloy WAL, Prometheus TSDB, Redpanda, RustFS, Grafana) strictly use **RWO (ReadWriteOnce)** volumes bound to dedicated pods. **RWX (ReadWriteMany / NFS) is strictly prohibited** for TSDB and WAL paths due to file-locking and I/O latency bottlenecks. Shared data access across multiple query/read replicas is handled entirely by the S3 object storage layer (RustFS).
- **High-Performance SSD/NVMe Classes:** Production clusters must map persistent volume claims to dedicated SSD/NVMe storage classes (`fast-nvme`, `gp3-io2`, `premium-rwo`) with minimum 3,000 IOPS / 125 MB/s baseline throughput:
  - **Alloy WAL (100Gi):** Absorbs high-throughput trace and log bursts during downstream network partitioning.
  - **Prometheus TSDB (120Gi):** Ensures sub-second query latency across 50,000+ active series over 30–90 days.
  - **Redpanda Stream Buffer (170Gi x 3):** Sustains real-time trace streaming at zero drop rate.
  - **RustFS Cluster Drives (125Gi x 8):** Drives 1TB raw erasure-coded (EC:2) distributed object storage.

### Ingress & External Telemetry Ingestion (gRPC & HTTP)
External microservices and bare-metal VMs outside the Kubernetes cluster push OTLP telemetry directly to Grafana Alloy via Kubernetes Ingress.
- **OTLP gRPC (Port 4317):** Requires HTTP/2 end-to-end support with backend protocol set to GRPC.
  - **Ingress-Nginx Annotation:** `nginx.ingress.kubernetes.io/backend-protocol: "GRPC"`
  - **Traefik IngressRoute:** Use `h2c` scheme to forward cleartext HTTP/2 to Alloy after ingress TLS termination.
- **OTLP HTTP (Port 4318):** Standard HTTPS ingress with client payload limits tuned (`client_max_body_size: 50m`).
- **Security & Mutual Auth:** Ingress controllers should enforce TLS 1.3 termination, IP whitelisting, and optional Bearer token or mTLS validation before passing payloads to Alloy.

### Network Policies & DNS
- **DNS Reliability:** Alloy, Loki, and Tempo rely heavily on headless Kubernetes service DNS (`cluster.local`) for HashRing and Gossip memberlist coordination. CoreDNS caching must be tuned to prevent lookup timeouts under high connection churn.
- **Network Policies:** Strict egress/ingress isolation between observability pods and external services. Only Alloy OTLP and Grafana Web UI should be exposed externally.

---

## IV. Operational Hardening & Lessons Learned

### 1. Local vs Production Resource Constraints
- Local sandboxes (dev, prod-local) must constrain requests/limits (10m CPU / 64Mi RAM) to prevent Docker Desktop scheduling deadlocks.
- Production (prod) uses dedicated 3-node worker topologies with explicit reservations (e.g. 100Gi Alloy WAL, 120Gi TSDB).

### 2. High Availability & Anti-Affinity Rules
- Production enables strict `podAntiAffinity` across Kubernetes zones (`topology.kubernetes.io/zone`).
- Dev and single-node validation environments must set `podAntiAffinity` to `soft` (preferred) or `disabled` to allow multi-replica components to co-exist on a single node.

### 3. Cluster Service Discovery (Memberlist / Gossip Ring)
- Loki and Tempo microservices must always discover ring peers via headless cluster service DNS (`loki-memberlist.monitoring.svc.cluster.local`, `tempo-memberlist.monitoring.svc.cluster.local`) rather than hardcoded pod IPs or stateful pod hostnames.

### 4. Configuration Schema Consistency
- Use explicit `config: |` blocks in Helm values files to bypass chart-template version-mismatch issues for Tempo/Loki configuration sections.

### 5. S3 Storage Credentials Inheritance
- In distributed Helm deployments, components (Ingester, Querier, Index Gateway, Compactor) run as independent deployments/StatefulSets. S3 credentials must be explicitly configured via `extraEnv` or `existingSecret` on every stateful sub-component because they do not inherit from the global Helm scope.

### 6. Workload Capacity & Volume Estimates
- Detailed daily log/trace/series metrics and capacity planning for small-scale compliance workloads are documented in `deployment/prod/production_workload_small_scale_sizing.md` (25 GB/day logs, 500 spans/sec, 50,000 active series, 1.9TB total storage footprint).
