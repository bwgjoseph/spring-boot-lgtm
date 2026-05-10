# Alloy: Ingestion, Processing & Gateway Requirements

## 1. Role & Responsibility (The "Job")
Alloy is the **Single Entry Point** for all telemetry in the production cluster. Its primary "job" is to abstract the backend storage from the application layer by providing a unified ingestion interface, performing mandatory processing, and routing data to the appropriate internal and external sinks.

## 2. Ingestion Standards
- **Unified Protocol:** Mandatory support for **OTLP/gRPC** for Traces and Metrics to ensure a standardized, high-performance ingestion path.
- **Node-Local Collection:** Mandatory "pull-based" collection of logs from `stdout` (via disk) and scraping of metrics from local pod endpoints.

---

## 3. Log Processing Standards
- **Local Persistence:** Logs must be trailed directly from node-local `/var/log/pods` (via HostPath mount) to ensure reliability during network partitions.
- **Structured Metadata Promotion:** Alloy must extract high-cardinality fields (e.g., `trace_id`, `span_id`, `user_id`) from raw log text and promote them to **Loki Structured Metadata**.
- **Rationale:** Enables seamless Trace-to-Log correlation in Grafana without the memory cost of indexing these fields as labels.

## 4. Trace Processing Standards
- **Trace Affinity:** Traces must be load-balanced across the collector cluster to ensure all spans of a single `trace_id` land on the same instance.
- **Tail-Based Sampling (TBS):** Alloy is the authoritative "Decision Point" for trace storage. It must keep 100% of error traces and high-latency outliers, while sampling routine successful traffic.
- **Automatic K8s Enrichment:** All spans must be enriched with Kubernetes metadata (Pod Name, Namespace, Node, UID) by querying the local Kubelet.

## 5. Metrics Processing Standards
- **Node-Locality Filtering:** Alloy must only scrape metrics for pods residing on its own physical node (using `${HOSTNAME}` filter) to prevent massive data duplication.
- **Unified Remote Write:** All scraped metrics must be formatted and exported using the **Prometheus Remote Write** protocol.
- **Exemplars:** Alloy must preserve and export exemplars to facilitate Metric-to-Trace navigation.

---

## 6. Operational Resilience & Reliability
- **Local Persistence (WAL):** Alloy must use node-local **SSD storage (10Gi - 20Gi PVC)** for its internal Write-Ahead Log.
- **Graceful Shutdown:** Configured with a **60s termination grace period** to ensure tail-sampling windows are completed.
- **Self-Observability:** Mandatory alerting on `dropped_data` or `failed_refreshes`.

## 7. Infrastructure & Security (RBAC)
- **K8s API Access:** The Alloy ServiceAccount must have `get`, `watch`, and `list` permissions for `pods`, `namespaces`, and `nodes`.

## 8. Future Considerations (v2+)
- **Security & Trust:** Implement mTLS for internal cluster ingestion.
- **Data Privacy:** Capability to redact, mask, or scrub PII from logs and spans at the edge.
- **External Forwarding:** Selectively mirror telemetry to external gateways.
- **Topology Evolution:** Evaluate transitioning from a **DaemonSet** (Node-local efficiency) to a **Deployment** (Centralized Management).
    - *Rationale:* Centralizing Alloy into a Deployment reduces the total pod count (6 vs 3) and simplifies upgrade management, at the cost of losing direct log-file access (requiring K8s API "pulling") and introducing extra network hops for every log/metric event. It also eliminates the need for brittle Downward API (`NODE_IP`) injection in application deployments.
