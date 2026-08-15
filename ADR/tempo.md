# ADR: Grafana Tempo Distributed Tracing

## Status
Accepted

## Context
Traces are critical for debugging latency and understanding service dependencies. High cardinality and high volume make trace storage challenging. We require a setup that:
- **Highly Available & Durable:** Capable of surviving pod/node failures without data loss.
- **Cost-Effective:** Balancing trace retention with S3 storage costs.
- **High-Performance:** Providing near-instant search via TraceQL and automatic Service Graph generation.
- **Stable:** Immune to resource exhaustion from runaway services.

## Decision
1.  **Deployment Mode:** Use **Tempo 3.x Microservices Architecture** (via `grafana-community/tempo-distributed` chart 3.0.6) with **Redpanda** (Kafka-compatible) as the streaming ingestion log.
2.  **Streaming Ingestion:** `tempo-distributor` ingests OTLP traces and writes to Redpanda topic (`tempo-traces`). `tempo-block-builder` (3 replicas) consumes from Redpanda and flushes Parquet blocks to MinIO S3 object storage. `tempo-live-store` (3 replicas) serves low-latency recent trace queries.
3.  **Cluster Coordination:** Use **Memberlist (Gossip)** for ring store distribution across microservices.
4.  **Storage Architecture:**
    *   **Backend:** Use S3-compatible object storage (MinIO/S3) for long-term trace blocks.
    *   **WAL Persistence:** Use high-performance Local SSD storage for Write-Ahead Log (WAL).
5.  **Data Format:** Explicitly use **Parquet** for backend trace blocks to ensure high-performance columnar searching.
6.  **Metrics-from-Traces:**
    *   Enable the **Metrics Generator** for `service-graphs` and `span-metrics`.
    *   Export these metrics via **Prometheus Remote Write** to the central metrics sink.
7.  **Retention:** Maintain a **7-day** retention period on S3 to balance debugging utility with storage costs.
7.  **Ingestion Guardrails:** Implement mandatory limits of **10MB** and **20,000 spans** per trace to protect cluster memory.
8.  **Hot Data Discovery:** Configure the querier to search the active WAL to make traces searchable within seconds of ingestion.
9.  **Graceful Termination:** Configured with a minimum **60s termination grace period** to ensure the WAL is flushed to S3.

## Rationale
- **Microservices Architecture:** Provides fine-grained horizontal scaling per component (distributor, block-builder, live-store) without requiring a monolithic ingester cluster.
- **Kafka Streaming Buffer (Redpanda):** Decouples ingestion from storage. The `distributor` writes to Redpanda topic `tempo-traces` (3 partitions), allowing `block-builder` to consume and flush Parquet blocks to MinIO asynchronously without back-pressure on the ingestion path.
- **Memberlist Resilience:** Unlike in-memory rings, Memberlist ensures that the cluster state is shared and stable across the replicas even during rolling updates.
- **WAL Durability:** As documented in `SERVICE_GRAPH_ISSUE.md`, a stable WAL is essential for the Metrics Generator to consistently produce Service Graphs. SSD storage ensures the high IOPS required for concurrent ingestion and metrics processing.
- **Parquet Performance:** Parquet is the modern standard for Tempo, allowing much faster TraceQL queries and smaller storage footprint compared to older formats.
- **Guardrails:** Prevents a single misconfigured service from exhausting the memory of the ingester cluster by rejecting overly large traces.
- **Live Searchability:** Ensuring that "hot" data in the WAL is searchable eliminates the delay typically caused by S3 compaction cycles.

## Implementation Source of Truth
- **Kafka Ingest:** `ingest.kafka.address: redpanda.monitoring.svc.cluster.local:9093`, `topic: tempo-traces`
- **Partitions:** `auto_create_topic_default_partitions: 3` (matches `blockBuilder.replicas` and `liveStore.replicas`)
- **blockBuilder Replicas:** `replicas: 3`
- **liveStore Replicas:** `replicas: 3`
- **Gossip:** `memberlist` kvstore across all microservice components
- **WAL Mount:** `/var/tempo/wal`
- **Graceful Termination:** `terminationGracePeriodSeconds: 60`
- **Search Logic:** `querier.search_finished_blocks: true`
- **Env Expansion:** `extraArgs: ["-config.expand-env=true"]` on all components (required for MinIO S3 credentials)

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
