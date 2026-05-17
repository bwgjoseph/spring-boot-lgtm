# 🛡️ Production Hardening Proposal (2026 Standards)

This document outlines the explicit technical configurations required to transition the **Spring Boot LGTM Sandbox** from a validated HA setup to a high-scale, cost-optimized production environment.

## 1. Objectives
- **Cost Optimization:** Reduce S3 API costs and storage bloat via advanced compaction and cardinality filtering.
- **Query Performance:** Target sub-second response times for queries spanning up to 14 days.
- **Operational Stability:** Decouple compute-heavy tasks (like alerting math) from ingestion paths.

---

## 2. Component-Specific Hardening

### A. Grafana Alloy: The "Cardinality Firewall"
To prevent Loki and Mimir from crashing due to label-bloat, Alloy must act as a filter.

**Proposed Changes (`values-alloy.yaml`):**
1.  **Centralized Deployment:** Formalize `controller.type: deployment` with 2+ replicas.
2.  **Cardinality Relabeling:** Add explicit drop rules for ephemeral Kubernetes metadata.
    ```hcl
    discovery.relabel "filtered_pods" {
      // ... existing rules ...
      // DROP high-cardinality labels before they hit storage
      rule {
        source_labels = ["__meta_kubernetes_pod_label_pod_template_hash", "container_id", "instance"]
        action = "labeldrop"
      }
    }
    ```
3.  **Self-Observability:** Scrape Alloy's internal metrics to monitor memory usage during clustering.

### B. Grafana Loki: The 14-Day Query Pass
Loki's performance on 2-week windows depends on keeping the index "hot" and parallelized.

**Proposed Changes (`values-loki.yaml`):**
1.  **Enable Index Gateway:** Mandatory for SSD mode. It caches index files locally.
    ```yaml
    loki:
      index_gateway:
        enabled: true
        replication_factor: 2 # Ensure HA for index searches
    ```
2.  **TSDB Parallelism:** Increase the number of concurrent chunks processed per query.
    ```yaml
    loki:
      limits_config:
        tsdb_max_query_parallelism: 128
        max_query_parallelism: 32
    ```
3.  **Bloom Filters (Loki 3.x+):** Enable for "needle in haystack" searches (e.g., searching for a specific UUID).
    ```yaml
    loki:
      storage:
        bloom_filter:
          enabled: true
    ```

### C. Grafana Tempo: Parquet & Compaction
Optimizing the backend format for TraceQL and reducing S3 object count.

**Proposed Changes (`values-tempo.yaml`):**
1.  **Vertical Compaction:** Merge multiple small blocks into single large Parquet files.
    ```yaml
    config: |
      compactor:
        compaction:
          vertical_compact: true
          max_block_bytes: 524288000 # 500MB target for TraceQL performance
    ```
2.  **SSD/NVMe for WAL:** Ensure the 20Gi volume is explicitly pinned to a high-IOPS storage class.

### D. Grafana Mimir: Ruler Offloading
Prevent the Ruler from becoming a bottleneck during high-alert periods.

**Proposed Changes (`values-mimir.yaml`):**
1.  **Remote Evaluation:** Force the Ruler to use the Query-Frontend for rule math.
    ```yaml
    mimir:
      structuredConfig:
        ruler:
          enable_api: true
          query_frontend_address: mimir-query-frontend.monitoring.svc.cluster.local:8080
    ```
2.  **Sub-Query Sharding:** Split complex dashboard queries into multiple parallel tasks.
    ```yaml
    mimir:
      structuredConfig:
        query_frontend:
          sharding_enabled: true
          max_outstanding_per_tenant: 2048
    ```

---

## 3. Infrastructure Standards

### S3 Backend (MinIO / AWS S3)
- **Bucket Isolation:** Each component (Loki, Tempo, Mimir) **must** have its own bucket or unique root prefix to avoid S3 rate-limiting collisions.
- **Static Keys:** Credentials must be injected via `${S3_SECRET_KEY}` from a Kubernetes Secret (Verified pattern).

### Persistence (WSL2 / Local SSD)
- **WAL Durability:** For production, use `ReadWriteOnce` with a high-performance SSD class. The WAL is the only part of the stack that is truly I/O bound.

---

## 4. Implementation Checklist
- [ ] Apply **Alloy** firewall rules to `prod-local`.
- [ ] Deploy **Loki** Index Gateways.
- [ ] Configure **Tempo** Vertical Compaction.
- [ ] Set **Mimir** Ruler to Remote Evaluation.
- [ ] Perform a final `task sync:prod` for all components.
