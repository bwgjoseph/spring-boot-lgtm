# Production Readiness: LGTM Observability Stack (On-Prem)

This document outlines production considerations for the LGTM observability stack (Loki, Grafana, Tempo, Mimir/Prometheus) when deployed on-premises, with Grafana Alloy as the central collector. It details configurations for high availability, scalability, storage, retention, and security.

---

## II. Core Components & Production Configuration

### Grafana Alloy

Grafana Alloy acts as the central observability gateway, collecting, processing, and exporting telemetry data. In production, focus on:

*   **High Availability (HA):** Deploying multiple replicas of Alloy behind a load balancer to ensure no single point of failure.
*   **Configuration Management:** Managing `values-alloy.yaml` through a robust CI/CD pipeline.
*   **Remote Write Targets:** Ensuring reliable connections to Prometheus (for metrics), Loki (for logs), and Tempo (for traces).
*   **Processor Tuning:** Optimizing `loki.process` or other processors for efficient log structuring and metadata extraction.
*   **Kubernetes Enrichment (RBAC):** When using `otelcol.processor.k8sattributes`, Alloy requires specific permissions to query the Kubernetes API to map source IPs to Pod metadata.
    *   **Required Permissions:** `get`, `watch`, and `list` for `pods`, `namespaces`, `nodes`, and `apps/replicasets`.
    *   **Verification:** Use `kubectl auth can-i list pods --as=system:serviceaccount:monitoring:alloy -n monitoring`. If it returns `yes`, enrichment will work. If `no`, update the ClusterRole associated with the Alloy ServiceAccount.

### Tempo

Tempo is responsible for storing and querying traces. Production considerations include:

*   **High Availability (HA):** Deploying Tempo with sufficient replicas. For robust HA, consider Kubernetes deployment strategies and appropriate resource allocation. While the sandbox uses local PVCs due to chart complexities, production should leverage MinIO.
*   **Storage Strategy:**
    *   **MinIO Recommendation:** For long-term trace storage, MinIO is highly recommended. It provides S3-compatible object storage, offering better scalability, cost-effectiveness, and durability than local PVCs for large trace volumes.
*   **Retention Policies:**
    *   **Production Recommendation:** **7-14 days**. Traces are high-cardinality and can consume significant storage. Shorter retention balances utility for debugging recent issues with storage costs. Longer retention can be considered for specific compliance needs.
*   **Scaling Mode:**
    *   **Simple Scalable Mode:** Recommended for most on-prem deployments. It simplifies management with fewer distinct services while still enabling scaling of read/write paths.

### Loki

Loki is designed for log aggregation. Production configurations should focus on:

*   **High Availability (HA):** Employing Kubernetes deployment strategies (e.g., multiple replicas, anti-affinity rules) for `loki-read`, `loki-write`, and `loki-backend` components.
*   **Storage Strategy:**
    *   **MinIO Recommendation:** MinIO is the preferred backend for long-term log storage due to its scalability and cost-effectiveness for large data volumes.
*   **Retention Policies:**
    *   **Production Recommendation:** **30-90 days**. Logs are typically the largest data volume. Retaining logs for 1-3 months allows for sufficient historical debugging and compliance needs. MinIO is well-suited for this scale.
*   **Scaling Mode:**
    *   **Simple Scalable Mode:** Recommended for its balance of performance and manageability, separating read/write paths.
*   **Logging Strategy:**
    *   **Labels:** Use indexed labels (e.g., `service_name`, `namespace`) for fast filtering of large log volumes.
    *   **Structured Metadata:** Leverage structured fields (e.g., `trace_id`, `span_id`) for efficient correlation without high indexing costs. Alloy can be configured to extract these.
    *   **Log Line:** The raw text for human readability.

### MinIO

MinIO serves as the S3-compatible object storage backend, crucial for scalable and cost-effective retention of logs and metrics.

*   **Production Setup:**
    *   **High Availability (HA):** Deploy MinIO in a distributed mode (e.g., erasure coding) across multiple nodes for resilience.
    *   **Security:** Secure MinIO access with strong credentials, TLS, and network policies. Restrict access to only necessary components.
    *   **Storage Class:** Use high-performance SSD/NVMe storage classes for MinIO's backing PVCs to ensure optimal performance.
*   **Retention Policies:**
    *   **General Principle:** Object storage is ideal for cost-effective long-term storage.
    *   **Prometheus (Metrics):** **30-90 days**. MinIO can efficiently store this volume, allowing for robust historical analysis.
    *   **Loki (Logs):** **30-90 days**. MinIO's scalability makes it suitable for retaining large log volumes for compliance and debugging.
    *   **Tempo (Traces):** **7-14 days**. While MinIO can store traces long-term, shorter retention is generally preferred due to their high cardinality and cost. Longer retention might be considered for specific compliance needs, but for general use, 7-14 days is a good balance between utility and cost.

### Prometheus

Prometheus is responsible for collecting and storing metrics. Production considerations include:

*   **High Availability (HA):** Deploy multiple Prometheus instances (federated or clustered) to avoid single points of failure.
*   **Retention Policies:**
    *   **Recommended Production:** **30-90 days**. Metrics are relatively compact. Longer retention aids in historical analysis, trend identification, and anomaly detection over periods. MinIO can handle this volume cost-effectively.
    *   **Configuration:** Managed via `server.retention` in Helm values.
*   **Scaling:** Ensure sufficient resources (`requests` and `limits`) for Prometheus server pods, especially with a large number of targets and long retention periods.

### Debezium Embedded (CDC)

Debezium Embedded provides Change Data Capture (CDC) capabilities within the Spring Boot application. Production considerations include:

*   **Offset Storage Persistence:** Use a persistent, distributed store for Debezium offsets (e.g., Redis, or a PVC-backed file store) to ensure the connector can resume from the last processed position after a restart. The sandbox uses a local file `/tmp/offsets.dat`, which is not suitable for multi-node production deployments.
*   **Monitoring (Micrometer):** The custom `DebeziumMetricsBinder` bridges JMX MBeans to Micrometer Gauges. Ensure critical metrics like `milli_seconds_behind_source` and `total_number_of_events_seen` are monitored for connector health and throughput.
*   **MongoDB Architecture:** Deploy MongoDB as a **ReplicaSet** (minimum 3 nodes: Primary, Secondary, Arbiter) to ensure high availability and enable the Change Stream API required by Debezium.
*   **MongoDB Security:** Use production-grade MongoDB credentials with the least-privilege principle. Secure the connection with TLS and appropriate network policies.
*   **Persistence:** Ensure `persistence.enabled: true` is set in the MongoDB Helm chart to prevent data loss on pod restarts.
*   **Error Handling:** Configure robust error-handling and retry policies (`errors.retry.delay.initial.ms`, `errors.retry.delay.max.ms`) to handle transient database connectivity issues.

### Alertmanager

Alertmanager is configured to handle alerts generated by Prometheus. It provides crucial functionality for alert management, including deduplication, grouping, silencing, and routing to notification channels.

*   **Alerting Rules:** Note that the actual alert rules (conditions for firing alerts, e.g., CPU > 90%) are typically defined separately in Prometheus's configuration (e.g., via additional ConfigMaps or Prometheus Operator CRDs).
    *   **Robustness Tip:** For critical services, use the `absent()` function (e.g., `absent(up{service_name="app"})`) to ensure alerts fire even if the service is scaled to 0 and its metrics disappear from Prometheus.
*   **Grouping Strategy:** Alerts are grouped by `['alertname', 'cluster', 'service', 'namespace']` to consolidate related issues into single notifications.
*   **Notification Buffering:** `group_wait` is set to `30s` and `group_interval` to `5m` for efficient notification delivery.
*   **Receiver Configuration:** Alerts are routed to a single Mattermost webhook receiver (`mattermost-receiver`). A placeholder URL is configured; this must be replaced with your actual Mattermost incoming webhook URL. `send_resolved: true` is enabled to notify when alerts are resolved.
*   **Security:** As per general production considerations, ensure Kubernetes Network Policies restrict access to the Alertmanager service.

### Grafana

Grafana provides the visualization layer. Production configurations focus on:

*   **High Availability (HA):** Running Grafana in multiple replicas is essential. This requires an external database like PostgreSQL to store users, dashboard definitions, and alert states, as SQLite is not suitable for clustered deployments.
*   **Ingress Configuration:** Expose Grafana via an NGINX Ingress controller, configured for TLS termination and potentially rate limiting.
*   **Security:** Secure Grafana access with strong admin passwords, consider OAuth integration, and restrict network access to Grafana pods.

---

## III. General Production Considerations

### Scaling Modes: Simple Scalable vs. Microservices

*   **Simple Scalable Mode:** Recommended for most on-prem deployments (e.g., up to ~100 services). It simplifies management with fewer distinct services (e.g., read/write paths are scaled independently but within a single conceptual deployment) and is well-suited for typical enterprise observability needs.
*   **Full Microservices:** Designed for massive scale (thousands of services, e.g., Netflix/Uber). It involves managing many individual components (Ingester, Querier, Distributor, etc.) and requires significant orchestration expertise (e.g., Jsonnet, Tanka).

### Storage Strategy

*   **MinIO Recommendation:** For production environments with long-term data retention requirements for logs, metrics, and traces, **MinIO** is the recommended object storage solution.
    *   **Benefits:** Offers excellent scalability, cost-effectiveness for bulk data, and durability. It presents an S3-compatible API, which Loki and Tempo are designed to use.
    *   **Architecture:** Observability components (Loki, Tempo, Prometheus remote-write) push data to MinIO. MinIO itself can be backed by persistent volumes (PVCs) for its data, allowing for high-performance object storage on top of standard Kubernetes storage.
*   **PVC Considerations:** While easier for initial setup, relying solely on RWO PVCs for Loki and Tempo in a distributed (Simple Scalable) mode is not recommended due to limitations in sharing data across pods. RWX volumes (NFS, Ceph) are an alternative but often come with performance and complexity trade-offs compared to MinIO.

### Ingress & Security

*   **Ingress Controller:** Use an NGINX Ingress controller (or similar) to manage external access to Grafana, Prometheus, and potentially other UIs.
*   **TLS Termination:** Configure TLS termination at the Ingress level.
*   **Cert-Manager:** Integrate Cert-Manager for automated certificate management to secure your endpoints.
*   **Network Policies:** Implement Kubernetes Network Policies to restrict network access between observability components and from external sources. Only necessary ports and services should be exposed.
*   **Secrets Management:** Use Kubernetes Secrets for sensitive information like database passwords (for Grafana), MinIO credentials, etc.
