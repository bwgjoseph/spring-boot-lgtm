# Loki: Log Integrity & Query Requirements

## 1. Role & Responsibility (The "Job")
Loki is the **High-Volume Log Aggregator** for the production cluster. Its primary "job" is to provide cost-effective, durable, and highly-performant storage for all cluster logs, facilitating near-instant correlation with traces via structured metadata.

## 2. Physical Integrity
- **Physical Enforcement:** Retention policies must be physically enforced on S3 via the **Loki Compactor** to ensure predictable storage growth and prevent S3 cost runaway.
- **Write Durability:** Use **Replication Factor 3** to ensure logs are stored on multiple pods before being flushed to S3.

## 3. Query Performance
- **Caching:** 90% of common log queries must be served from memory cache (Memcached) rather than object storage.
- **Index Efficiency:** Must use the **v13 (TSDB)** schema to minimize index size and query latency.
- **Chunk Tuning:** Set `chunk_target_size: 1.5MiB` to optimize S3 API performance and cost-per-query.

## 4. Stability Guardrails
- **Cardinality Firewall:** Use Alloy to **Whitelist** specific namespaces and services. Dynamic high-cardinality data (e.g., unique order IDs) must NOT be ingested as Loki labels.
- **Complexity Limits:** Enforce system-wide limits on query parallelism (max 32), log line size (max 256kb), and search time ranges to prevent "Runaway Queries" from impacting cluster stability.
- **Gateway HA:** Mandatory 3 replicas for Loki Gateway with Pod Anti-Affinity to ensure the ingress path is highly available.
