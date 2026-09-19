# ADR: Grafana Tempo Distributed Tracing (Tempo 3.x Architecture)

## Status
Accepted

## Context
Distributed tracing is the foundational pillar for microservice dependency mapping, latency troubleshooting, and error diagnosis. High cardinality and trace volume make storage and ingestion challenging. We require an architecture that:
- **Highly Available & Horizontally Scalable:** Capable of decoupling ingest spikes from object storage flush delays.
- **Cost-Effective & Columnar:** Long-term storage using S3-compatible object storage backed by Parquet format.
- **High-Performance:** Sub-second TraceQL queries and automated Service Graph generation.
- **Zero-Lag Searchability:** Making active in-flight traces queryable before S3 block compaction.

---

## Architecture & Streaming Data Flow

### 1. Tempo 3.x Microservices & Redpanda Pipeline Diagram
Tempo 3.x utilizes a streaming log architecture where incoming OTLP spans are buffered in **Redpanda (Kafka)** before being packaged into columnar Parquet blocks:

```mermaid
flowchart TD
    subgraph IngestionSource ["Trace Ingestion"]
        ALLOY["Grafana Alloy<br/><i>(OTLP gRPC :4317)</i>"]
    end

    subgraph TempoIngress ["Ingress & Buffer Tier"]
        DISTRIBUTOR["tempo-distributor (Replicas: 2)<br/><i>OTLP gRPC Receiver :4317</i>"]
        REDPANDA["Redpanda Streaming Cluster<br/><i>Topic: 'tempo-traces' (3 Partitions)</i>"]
    end

    subgraph TempoProcessors ["Tempo 3.x Processing Tier"]
        BLOCK_BUILDER["tempo-block-builder (Replicas: 3)<br/><i>Consumer Group: 'tempo-block-builder'</i>"]
        LIVE_STORE["tempo-live-store (Replicas: 3)<br/><i>In-Memory Active Span Store</i>"]
        METRICS_GEN["tempo-metrics-generator (Replicas: 2)<br/><i>5Gi WAL Persistence | Native Histograms</i>"]
    end

    subgraph StorageTier ["Durable Object Storage"]
        MINIO["MinIO S3 Backend (Port 9000)<br/><i>Bucket: 'tempo' (Parquet Blocks)</i>"]
    end

    subgraph QueryTier ["Query & Analysis Tier"]
        QF["tempo-query-frontend (Replicas: 2)<br/><i>streamOverHTTPEnabled: true</i>"]
        QUERIER["tempo-querier (Replicas: 2)<br/><i>TraceQL Query Engine</i>"]
        PROM["Prometheus Server (Port 9090)<br/><i>Remote Write Sink for Service Graphs</i>"]
        GRAFANA["Grafana (Port 3000)<br/><i>Service Map & TraceQL Explorer</i>"]
    end

    %% Ingest Flow
    ALLOY -->|"1. OTLP gRPC (:4317)"| DISTRIBUTOR
    DISTRIBUTOR -->|"2. Produce Spans"| REDPANDA

    %% Streaming Ingestion to Storage & Live Store
    REDPANDA -->|"Consume (3 Partitions)"| BLOCK_BUILDER
    REDPANDA -->|"Consume (Recent Spans)"| LIVE_STORE
    BLOCK_BUILDER -->|"3. Flush Parquet Blocks"| MINIO

    %% Metrics Generation
    DISTRIBUTOR -.->|"Fan-out Spans"| METRICS_GEN
    METRICS_GEN -->|"4. Remote Write (Service Graphs & Span Metrics)"| PROM

    %% Query Flow
    GRAFANA -->|"TraceQL Query"| QF
    QF --> QUERIER
    QUERIER -->|"Search In-Flight Traces"| LIVE_STORE
    QUERIER -->|"Search Historical Parquet Blocks"| MINIO
    GRAFANA -.->|"Query Service Graph Metrics"| PROM

    classDef ingress fill:#fff3e0,stroke:#e65100,stroke-width:2px;
    classDef buffer fill:#ffebee,stroke:#c62828,stroke-width:2px;
    classDef proc fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px;
    classDef storage fill:#ede7f6,stroke:#4527a0,stroke-width:2px;
    classDef query fill:#e1f5fe,stroke:#0277bd,stroke-width:2px;

    class DISTRIBUTOR ingress;
    class REDPANDA buffer;
    class BLOCK_BUILDER,LIVE_STORE,METRICS_GEN proc;
    class MINIO storage;
    class QF,QUERIER,PROM,GRAFANA query;
```

---

## Decision

1. **Deployment Mode (Tempo 3.x Microservices):**
   - Deploy via `grafana-community/tempo-distributed` (Chart 3.0.6) utilizing the **Tempo 3.x microservices model**.
   - Decouple ingestion from block construction via **Redpanda** as a streaming log buffer.

2. **Streaming Ingestion Tier (Redpanda + Block Builder):**
   - **Distributor (2 replicas):** Receives OTLP gRPC traffic on port `4317` and immediately streams spans to Redpanda.
   - **Kafka Topic:** Topic `tempo-traces` with **3 partitions** (`auto_create_topic_default_partitions: 3`).
   - **Block Builder (3 replicas):** Matches the 3 Kafka partitions. Operates under consumer group `tempo-block-builder` to continuously aggregate spans and flush columnar **Parquet** blocks to MinIO S3.
   - **Live Store (3 replicas):** Consumes recent spans from Redpanda to serve in-memory queries for active in-flight traces with zero latency. *(In resource-constrained `dev`, live-store can be scaled down or disabled to conserve single-node memory).*

3. **Storage Architecture & Columnar Parquet Format:**
   - **Backend:** MinIO S3 (`bucket: tempo`) with path-style access enabled.
   - **Columnar Format:** Exclusively build and store blocks in **Parquet** format, optimizing TraceQL search execution and compression.
   - **Credential Management:** Injected globally via `globalExtraEnv` referencing secret `minio` (`rootPassword` as `S3_SECRET_KEY`) with `-config.expand-env=true` passed to all components.

4. **Metrics-from-Traces (Service Graphs & Span Metrics):**
   - Deploy **`metricsGenerator` (2 replicas)** with dedicated **5Gi SSD persistence** for its local Write-Ahead Log (`/var/tempo/generator/wal`).
   - Enable processors: `service_graphs`, `span_metrics`, and `local_blocks`.
   - Export generated metrics via **Prometheus Remote Write** with `send_exemplars: true`.
   - Enable Prometheus native histograms (`generate_native_histograms: both`).

5. **Query Performance & Memory Optimization:**
   - Enable **`streamOverHTTPEnabled: true`** to stream trace search results over HTTP, preventing queryFrontend OOM crashes on large trace payloads.
   - Deploy **`queryFrontend` (2 replicas)** and **`querier` (2 replicas)** for high-throughput TraceQL query execution.

6. **Retention & Guardrails:**
   - Maintain a **14-day** retention policy on S3 object storage for production (7 days in sandbox).
   - Enforce a 60-second termination grace period (`terminationGracePeriodSeconds: 60`) on block-builder and metrics-generator to ensure unflushed WAL segments are committed to object storage prior to shutdown.

---

## Technical Specification & Implementation Mapping

This table maps the production implementation in `deployment/prod/values-tempo.yaml` and `deployment/prod-local/values-tempo.yaml` to the architectural decisions:

| Key / Component | Value / Configuration | Purpose | Architectural Role |
| :--- | :--- | :--- | :--- |
| `streamOverHTTPEnabled` | `true` | Lowers queryFrontend memory footprint via HTTP streaming. | Query Performance |
| `ingest.kafka.address` | `redpanda.monitoring.svc:9093` | Decouples OTLP ingest from block construction. | Buffer / Streaming |
| `ingest.kafka.topic` | `tempo-traces` (3 partitions) | Partitioned trace streaming buffer. | Ingestion Pipeline |
| `ingest.kafka.consumer_group`| `tempo-block-builder` | Durable Kafka consumer group offset tracking. | Ingestion Pipeline |
| `blockBuilder.replicas` | `3` | Exactly matches 3 Kafka partitions for balanced consumption. | Block Packaging |
| `liveStore.replicas` | `3` | Serves hot in-memory trace lookups without S3 polling lag. | Low-Latency Search |
| `distributor.replicas` | `2` (`receivers.otlp.grpc: 4317`)| High-availability OTLP trace reception. | Ingress |
| `querier.replicas` | `2` | Parallelized TraceQL query execution. | Query Tier |
| `queryFrontend.replicas` | `2` | Query scheduling, splitting, and result caching. | Query Tier |
| `storage.trace.backend` | `s3` (`bucket: tempo`) | Columnar Parquet long-term block persistence. | Durability |
| `metricsGenerator.enabled` | `true` (`replicas: 2`, `WAL: 5Gi`) | Automatic Service Graph and Span Metric derivation. | Observability |
| `metricsGenerator.remote_write`| Targets Prometheus with Exemplars | Pushes service dependency metrics to Prometheus. | Correlation |
| `overrides.generate_native_histograms`| `both` | Produces Prometheus sparse native histograms. | Metrics Efficiency |
| `globalExtraEnv` | `secretKeyRef: minio -> rootPassword` | Secure S3 credential expansion across all pods. | Security |

---

## Consequences

- **Positive:**
  - Redpanda streaming buffer prevents trace ingestion loss during sudden traffic bursts or MinIO latency spikes.
  - Automatic, real-time Service Graph generation in Grafana without manual instrumentation.
  - Parquet format delivers 5x–10x faster TraceQL query speeds compared to legacy formats.
  - Zero-lag queryability of hot spans via `liveStore`.
- **Negative:**
  - Higher operational footprint requiring Redpanda Kafka broker and consumer coordination.
  - Metrics generator requires local SSD WAL persistence (`5Gi`) to prevent metric loss during restarts.
- **Risk:**
  - Partition skew if traces are unevenly distributed across the 3 Kafka partitions.
