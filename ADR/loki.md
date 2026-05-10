# ADR: Grafana Loki Log Aggregation & Durability

## Status
Proposed

## Context
Log data represents the highest volume of telemetry in the production cluster. We require a solution that is highly available, cost-effective for 30-day retention, and supports seamless correlation with traces.

## Decision
1.  **Deployment Mode:** Use **SimpleScalable** mode (separating Read, Write, and Backend components).
2.  **Storage Architecture:**
    *   **Backend:** Use S3-compatible object storage (MinIO/S3) for all chunks and indexes.
    *   **Replication:** Set `replication_factor: 3` to ensure log durability across pod/node failures.
3.  **Physical Retention:** Enable and configure the **Loki Compactor** to physically prune expired log chunks from S3 after 30 days.
4.  **Performance Layer:** Deploy **Memcached** clusters for `chunks_cache`, `results_cache`, and `index-queries-cache` to minimize S3 API latency.
5.  **Query Guardrails:** Enforce system-wide limits (e.g., `max_query_parallelism`, `max_line_size`) to protect the cluster from resource-intensive queries.
6.  **Schema:** Use the **v13 (TSDB)** index schema with native support for **Structured Metadata** to facilitate Trace-to-Log correlation.

## Rationale
- **SimpleScalable:** Allows independent scaling of the write path (Ingesters) and the read path (Queriers).
- **Physical Enforcement:** Without the Compactor, S3 storage would grow indefinitely despite retention settings in the query layer.
- **Caching Strategy:** Logs are high-volume; fetching raw chunks from S3 for every dashboard refresh is slow and expensive. Memcached provides the necessary performance tier.
- **Guardrails:** Prevents a single complex query (e.g., regex search over a large time range) from exhausting pod memory and impacting other users.
- **Structured Metadata:** Enables fast correlation without the high memory cost of indexing high-cardinality labels.

## Implementation Source of Truth
- **Replication:** `loki.commonConfig.replication_factor: 3`
- **Retention:** `loki.compactor.retention_enabled: true`
- **Caching:** Enable `results_cache` and `chunks_cache` sub-charts.
- **Limits:** `loki.limits_config` block.

## Technical Specification & Mapping
This table maps the production implementation in `deployment/prod/values-loki.yaml` to the architectural decisions and requirements.

| YAML Path | Logic / Value | Purpose | Requirement Link |
| :--- | :--- | :--- | :--- |
| `deploymentMode` | `SimpleScalable` | Decouples read/write paths. | `req/loki.md` Sec 1.0 |
| `replication_factor` | `3` | HA; ensures data survives pod failure. | `REQUIREMENTS` Sec 1.1 |
| `compactor` | `retention_enabled: true` | **Critical:** Physically prunes S3 logs. | `req/loki.md` Sec 2.0 |
| `gateway.replicas` | `3` | HA; ensures ingress availability. | `req/loki.md` Sec 4.0 |
| `chunk_target_size` | `1.5MiB` | Balance S3 API cost and query performance. | `req/loki.md` Sec 3.0 |
| `limits_config` | `max_line_size: 256kb` | Prevents OOM crashes from large log lines. | `req/loki.md` Sec 4.0 |
| `schemaConfig` | `v13 (TSDB)` | Optimizes index size & query speed. | `req/loki.md` Sec 3.0 |

## Consequences
- **Positive:** Predictable storage costs, high durability, and snappy query performance.
- **Negative:** Increased cluster complexity due to additional Memcached pods.
- **Dependency:** Heavily relies on S3 backend performance and consistency.
