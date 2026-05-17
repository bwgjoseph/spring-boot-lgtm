# ADR: Grafana Tempo Distributed Tracing

## Status
Proposed

## Context
Traces are critical for debugging latency and understanding service dependencies. High cardinality and high volume make trace storage challenging. We require a setup that:
- **Highly Available & Durable:** Capable of surviving pod/node failures without data loss.
- **Cost-Effective:** Balancing trace retention with S3 storage costs.
- **High-Performance:** Providing near-instant search via TraceQL and automatic Service Graph generation.
- **Stable:** Immune to resource exhaustion from runaway services.

## Decision
1.  **Deployment Mode:** Use **Scalable Monolithic** (via the Single Binary chart with replicas=2).
2.  **Cluster Coordination:** Use **Memberlist (Gossip)** for the hash ring store (switching from in-memory) to ensure consistent data distribution that survives restarts.
3.  **Storage Architecture:**
    *   **Backend:** Use S3-compatible object storage (MinIO/S3) for long-term trace blocks.
    *   **WAL Persistence:** Use high-performance **Local SSD (20Gi)** for the Write-Ahead Log (WAL) to prevent data loss or corruption during pod restarts.
4.  **Data Format:** Explicitly use **Parquet** for backend trace blocks to ensure high-performance columnar searching.
5.  **Metrics-from-Traces:**
    *   Enable the **Metrics Generator** for `service-graphs` and `span-metrics`.
    *   Export these metrics via **Prometheus Remote Write** to the central metrics sink.
6.  **Retention:** Maintain a **7-day** retention period on S3 to balance debugging utility with storage costs.
7.  **Ingestion Guardrails:** Implement mandatory limits of **10MB** and **20,000 spans** per trace to protect cluster memory.
8.  **Hot Data Discovery:** Configure the querier to search the active WAL to make traces searchable within seconds of ingestion.
9.  **Graceful Termination:** Configured with a minimum **60s termination grace period** to ensure the WAL is flushed to S3.

## Rationale
- **Scalable Monolithic:** Provides High Availability (HA) without the operational complexity of the full Microservices architecture.
- **Memberlist Resilience:** Unlike in-memory rings, Memberlist ensures that the cluster state is shared and stable across the replicas even during rolling updates.
- **WAL Durability:** As documented in `SERVICE_GRAPH_ISSUE.md`, a stable WAL is essential for the Metrics Generator to consistently produce Service Graphs. SSD storage ensures the high IOPS required for concurrent ingestion and metrics processing.
- **Parquet Performance:** Parquet is the modern standard for Tempo, allowing much faster TraceQL queries and smaller storage footprint compared to older formats.
- **Guardrails:** Prevents a single misconfigured service from exhausting the memory of the ingester cluster by rejecting overly large traces.
- **Live Searchability:** Ensuring that "hot" data in the WAL is searchable eliminates the delay typically caused by S3 compaction cycles.

## Implementation Source of Truth
- **Replicas:** `replicas: 2`
- **Gossip:** `ingester.lifecycler.ring.kvstore.store: memberlist`
- **Replication:** `ingester.lifecycler.ring.replication_factor: 2`
- **WAL Mount:** `/var/tempo/wal`
- **Graceful Termination:** `terminationGracePeriodSeconds: 60`
- **Search Logic:** `querier.search_finished_blocks: true`

## Technical Specification & Mapping
This table maps the production implementation in `deployment/prod/values-tempo.yaml` to the architectural decisions and requirements.

| YAML Path / Component | Logic / Value | Functional Purpose | Requirement / ADR Link |
| :--- | :--- | :--- | :--- |
| `replicas` | `2` | High Availability for ingestion and querying. | `req/tempo.md` Sec 1.0 |
| `kvstore.store` | `memberlist` | Resilient hash ring coordination across replicas. | `ADR` Sec 2 / `req` Sec 1 |
| `replication_factor` | `2` | **Critical:** Ensure data survives pod failure. | `REQUIREMENTS` Sec 1.1 |
| `trace.backend` | `s3` | S3-native long-term persistence. | `req/tempo.md` Sec 2.0 |
| `persistence.size` | `20Gi SSD` | High-IOPS WAL for ingestion & metrics gen. | `ADR` Sec 3 / `req` Sec 2 |
| `max_bytes_per_trace` | `10485760` (10MB) | **Guardrail:** Protects against OOM. | `ADR` Sec 7 / `req` Sec 4 |
| `search_finished_blocks`| `true` | Makes traces searchable within seconds. | `ADR` Sec 8 / `req` Sec 4 |
| `metrics_generator` | `enabled` | Automatic Service Graph generation. | `req/tempo.md` Sec 3.0 |
| `block_retention` | `168h (7d)` | Balance between debugging and S3 costs. | `REQUIREMENTS` Sec 2.0 |
| `terminationGracePeriod`| `60s` | Ensure WAL flush to S3 before pod exit. | `ADR` Sec 3 / `req` Sec 4 |

## Consequences
- **Positive:** Robust Service Graphs, high durability, and columnar search performance.
- **Negative:** Metrics generation increases pod CPU and Memory footprint.
- **Risk:** Heavily reliant on S3 performance for query latency.
