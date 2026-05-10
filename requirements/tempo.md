# Tempo: Trace Durability & Visualization Requirements

## 1. Role & Responsibility (The "Job")
Tempo is the **High-Cardinality Trace Repository** and **Observability Engine** for the production cluster. Its primary "job" is to store 100% of the "interesting" traces decided by Alloy, provide near-instant search capabilities via TraceQL, and automatically generate system-wide Service Graphs and RED metrics from live span data.

## 2. Trace Ingestion & Reliability
- **Protocol:** Mandatory **OTLP/gRPC** support (port 4317) for high-throughput ingestion from Alloy.
- **Replication:** Mandatory **Replication Factor 3** at the ingester level to ensure zero data loss during single-pod or node failures.
- **State Management:** Must use **Memberlist (Gossip)** for the hash ring store to ensure cluster state survives total pod restarts.

## 2. Storage & Durability Standard
- **Write-Ahead Log (WAL):** Mandatory persistence of the WAL on high-performance **SSD storage (20Gi minimum)**.
- **Backend Persistence:** Long-term trace blocks must be persisted to S3-compatible object storage (MinIO/AWS S3).
- **Block Format:** Use **Parquet** format for trace blocks to optimize backend search speeds and columnar data access.

## 3. Visualization & Analysis Standard
- **Service Graphs:** Automated generation of service-to-service dependency maps from live traces.
- **Span Metrics:** Automatic generation of RED metrics (Request, Error, Duration) from spans.
- **Trace-to-Log Correlation:** Must ensure `trace_id` is propagated and searchable in Loki via structured metadata.

## 4. Operational Resilience & Guardrails
- **Ingestion Guardrails:** Mandatory limits of **10MB per trace** and **20,000 spans per trace** to prevent resource exhaustion by runaway services.
- **Live-Data Search:** The system must search active ingesters and the WAL to ensure traces are searchable within **< 1 minute** of ingestion.
- **Graceful Flush:** Configured with a minimum **60s termination grace period** to ensure the WAL is flushed to S3.
- **Remote Write:** Generated metrics must be pushed to a central Prometheus or Mimir cluster.

## 5. Future Considerations
- **Query Caching:** Implement Redis-based caching for search results if attribute-search latency exceeds 10s.
- **Multi-Tenancy:** Enable `X-Scope-OrgID` support if multi-department isolation is required.
