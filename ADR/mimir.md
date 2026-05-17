# ADR: Grafana Mimir Metrics & Scalability

## Status
Proposed

## Context
A production environment requires metric storage that can handle long-term retention (90+ days) and high availability. Standalone Prometheus is limited by local disk size and lacks a native horizontal scaling story for high-cardinality data. Requirements include:
- **S3-Native Storage:** To support long-term retention without local disk constraints.
- **Horizontal Scaling:** Support for horizontal scaling of the query and ingestion paths via a monolithic or scalable deployment mode.
- **Remote Write Compatibility:** Mandatory support for the Prometheus Remote Write protocol for ingestion from Alloy and Tempo.
- **Exemplars:** Support for OTEL exemplars to facilitate Metric-to-Trace navigation.
- **Hash Ring Consistency:** Maintenance of a consistent hash ring for data distribution across multiple Mimir replicas to ensure HA.

## Decision
1.  **Deployment Mode:** Use **Monolithic Mode** (running all Mimir components in a single process/pod).
2.  **Architecture:**
    *   **Backend:** Use S3-compatible object storage for all metric blocks and indexes.
    *   **High Availability:** Run **2 replicas** (optimized for HA validation) of the Mimir monolithic pod.
    *   **Cluster Coordination:** Maintain a consistent hash ring for data distribution.
3.  **Ingestion Protocol:** Enable the **Remote Write** receiver to allow Prometheus, Alloy, and Tempo to push metrics directly to Mimir.
4.  **Retention:** Implement a **90-day** retention policy via Mimir's compactor.

## Rationale
- **S3-Native Advantage:** Unlike Prometheus, which stores metrics on local disk, Mimir pushes "blocks" of metrics to S3. This allows for virtually unlimited retention and easy backups.
- **Monolithic for Manageability:** While Mimir can run as 10+ microservices, the Monolithic mode provides the same durability and HA benefits with much lower operational complexity for a single-cluster setup.
- **Horizontal Scaling:** By running multiple replicas of the monolithic pod and using a hash ring (via `memberlist`), Mimir can distribute the ingestion and query load across all pods.
- **Unified Sink:** Acts as the central long-term storage for all metrics in the cluster, including application metrics from Alloy and derived metrics from Tempo.

## Implementation Source of Truth
- **Scaling Config:** `target: monolithic`
- **Storage Config:** `mimir.structuredConfig.common.storage.backend: s3`
- **Replicas:** `2`

## Consequences
- **Positive:** Virtually unlimited metric retention and easier management than standalone Prometheus with sharding.
- **Negative:** Increased complexity in configuring the Gossip protocol (`memberlist`) for pod-to-pod communication.
- **Risk:** High dependency on S3 availability for both writing and querying historical metrics.
