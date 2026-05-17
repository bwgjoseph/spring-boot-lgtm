# ADR: Grafana Loki Log Aggregation & Durability

## Status
Proposed

## Context
Log data represents the highest volume of telemetry in the production cluster. We require a solution that is:
- **Highly Available & Durable:** Capable of surviving pod/node failures without data loss.
- **Cost-Effective:** Supporting 30-day retention with S3-native storage.
- **High-Performance:** Providing fast correlation with traces via structured metadata.
- **Stable:** Immune to runaway queries and high-cardinality label bloat.

## Decision
1.  **Deployment Mode:** Use **SimpleScalable** mode (separating Read, Write, and Backend components).
2.  **Physical Integrity:**
    *   **Backend:** Use S3-compatible object storage (MinIO/S3) for all chunks and indexes.
    *   **Replication:** Set `replication_factor: 2` (optimized for sandbox HA validation while maintaining durability).
    *   **Retention:** Enable and configure the **Loki Compactor** to physically prune expired log chunks from S3 after 30 days.
3.  **Performance Layer:**
    *   **Memcached:** Deploy clusters for `chunks_cache` and `results_cache` to serve 90% of frequent queries from memory.
    *   **Index Gateway:** Deploy the **Index Gateway** (ring mode) to cache TSDB index segments locally for 14-day search performance.
4.  **Stability Guardrails:** 
    *   **Cardinality Firewall:** Enforce namespace/service whitelisting in Alloy; drop high-cardinality labels (e.g., random UUIDs) at the collector layer to prevent index bloat.
    *   **Complexity Limits:** Enforce system-wide limits (e.g., `max_query_parallelism`, `max_line_size`, `max_streams`) to prevent resource exhaustion from runaway queries.
5.  **Schema:** Use the **v13 (TSDB)** index schema with native support for **Structured Metadata** to facilitate Trace-to-Log correlation.

## Rationale
- **SimpleScalable:** Allows independent scaling of the write path (Ingesters) and the read path (Queriers).
- **Physical Enforcement:** Without the Compactor, S3 storage would grow indefinitely despite retention settings in the query layer.
- **Caching Strategy:** Logs are high-volume; fetching raw chunks from S3 for every dashboard refresh is slow and expensive. Memcached provides the necessary performance tier.
- **Index Gateway:** Caching index segments locally significantly reduces S3 API calls and improves query startup time for large time ranges.
- **Guardrails:** Prevents a single complex query (e.g., regex search over a large time range) from exhausting pod memory and impacting other users.
- **Structured Metadata:** Enables fast correlation without the high memory cost of indexing high-cardinality labels.

## Implementation Source of Truth
- **Replication:** `loki.commonConfig.replication_factor: 2`
- **Retention:** `loki.compactor.retention_enabled: true`
- **Caching:** Enable `results_cache` and `chunks_cache` sub-charts.
- **Limits:** `loki.limits_config` block.

## Technical Specification & Mapping
This table maps the production implementation in `deployment/prod/values-loki.yaml` to the architectural decisions and requirements.

| YAML Path | Logic / Value | Purpose | Requirement Link |
| :--- | :--- | :--- | :--- |
| `deploymentMode` | `SimpleScalable` | Decouples read/write paths. | `req/loki.md` Sec 1.0 |
| `replication_factor` | `2` | HA; ensures data survives pod failure. | `REQUIREMENTS` Sec 1.1 |
| `indexGateway` | `enabled: true` | Caches TSDB index for fast history search. | `ADR` Sec 4 |
| `compactor` | `retention_enabled: true` | **Critical:** Physically prunes S3 logs. | `req/loki.md` Sec 2.0 |
| `gateway.replicas` | `2` | HA; ensures ingress availability. | `req/loki.md` Sec 4.0 |
| `chunk_target_size` | `1.5MiB` | Balance S3 API cost and query performance. | `req/loki.md` Sec 3.0 |
| `limits_config` | `max_line_size: 256kb` | Prevents OOM crashes from large log lines. | `req/loki.md` Sec 4.0 |
| `schemaConfig` | `v13 (TSDB)` | Optimizes index size & query speed. | `req/loki.md` Sec 3.0 |

## Consequences
- **Positive:** Predictable storage costs, high durability, and snappy query performance.
- **Negative:** Increased cluster complexity due to additional Memcached pods.
- **Dependency:** Heavily relies on S3 backend performance and consistency.
