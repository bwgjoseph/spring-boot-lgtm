# System Architecture: Spring Boot LGTM Stack

This document serves as the high-level roadmap for the production observability stack, explaining how the components interact and where to find detailed decision rationales.

## 1. Stack Overview
We follow a **"Decoupled Ingestion & Storage"** pattern. Data enters through a decentralized **Alloy** layer, is processed for correlation (metadata enrichment) and cost management (tail-sampling), and is then routed to specialized backend stores.

## 1. Environment Architecture

### A. Development Sandbox (Dev)
Optimized for resource efficiency and rapid feedback loops.
- **Loki:** `SingleBinary` mode. No caching, minimal resource footprint.
- **Tempo:** `Microservices` mode (distributor, querier, query-frontend, block-builder, live-store, backend-scheduler, backend-worker) backed by **Redpanda** Kafka streaming buffer. gRPC-only OTLP ingestion.
- **Mimir:** Standalone Prometheus instance (metrics).
- **Alloy:** Standalone deployment.
- **Persistence:** Local SSD PVCs (MinIO).

### B. Production / HA (Prod)
Optimized for durability, high-availability, and long-term retention.
- **Loki:** `SimpleScalable` mode. Distributed read/write/backend components, Memcached caching for queries/chunks, and replication factor of 2 (Optimized for HA validation).
- **Tempo:** `Microservices` mode (tempo-distributed, Tempo 3.x) with 2 replicas per component (distributor, querier, query-frontend), Memberlist gossip coordination, gRPC-only OTLP ingestion. **Redpanda** (3 replicas, 3 partitions) as the Kafka-compatible streaming buffer for `blockBuilder` and `liveStore`.
- **Mimir:** Monolithic HA-ready deployment (2 replicas) using S3 block storage.
- **Alloy:** Clustered Deployment (2 replicas) with Gossip protocol and Tail-based sampling enabled for trace affinity.
- **Persistence:** S3-native object storage (MinIO/AWS S3) with compactor-enforced physical retention.

## 2. Integrated Data Flow

### A. Development Sandbox (Dev)
```mermaid
graph TD
    subgraph Apps [Application Layer]
        App1[Spring Boot App Pods]
    end

    subgraph Collection [Collection Layer]
        AlloyDev[Alloy - Standalone]
    end

    subgraph Storage [Storage Layer]
        LokiDev[Loki - Single Binary]
        RedpandaDev[Redpanda - Single Node]
        TempoDev["Tempo 3.x - Microservices\n(distributor / querier / query-frontend\nblock-builder x3 / live-store x3\nbackend-scheduler / backend-worker)"]
        MimirDev[Prometheus - Standalone]
    end

    subgraph Backends [Backends]
        S3[S3 Object Storage]
        PVC[Local PVC]
    end

    App1 -- "OTLP/gRPC (Push)" --> AlloyDev
    AlloyDev -- "Scrape (Pull)" --> App1
    
    AlloyDev -- "Forwarding" --> LokiDev
    AlloyDev -- "OTLP/gRPC" --> TempoDev
    AlloyDev -- "Scrape" --> MimirDev

    TempoDev -- "Produce" --> RedpandaDev
    RedpandaDev -- "Consume" --> TempoDev

    LokiDev --> S3
    TempoDev --> S3
    MimirDev --> PVC

    style AlloyDev fill:#eee,stroke:#333
    style RedpandaDev fill:#ffecb3,stroke:#f9a825
    style S3 fill:#bbf,stroke:#333,stroke-dasharray: 5 5
    style PVC fill:#ddd,stroke:#333,stroke-dasharray: 3 3
```

### B. Production / HA (Prod)
```mermaid
graph TD
    subgraph Apps [Application Layer]
        App1[Spring Boot App Pods]
    end

    subgraph Collection [Collection Layer]
        AlloyProd[Alloy - Clustered Deployment]
        AlloyProd <--> |"Gossip (7946)"| AlloyProd
    end

    subgraph Storage [Storage Layer - HA/Scalable]
        LokiProd[Loki - SimpleScalable]
        TempoProd["Tempo 3.x - Microservices HA\n(distributor x2 / querier x2\nquery-frontend x2 / backend-scheduler / backend-worker)"]
        MimirProd[Mimir - Monolithic HA]
    end

    subgraph Backends [Backends]
        S3[S3 Object Storage]
        Mem[Memcached]
    end

    App1 -- "OTLP (Push)" --> AlloyProd
    App1 -- "Metrics (Pull)" --> AlloyProd
    
    AlloyProd -- "Log/Metrics/Trace Forwarding" --> LokiProd & TempoProd & MimirProd

    LokiProd --> S3
    TempoProd --> S3
    MimirProd --> S3

    LokiProd & TempoProd <--> Mem

    style AlloyProd fill:#f9f,stroke:#333,stroke-width:2px
    style S3 fill:#bbf,stroke:#333,stroke-dasharray: 5 5
    style Mem fill:#ddd,stroke:#333,stroke-dasharray: 3 3
```

## 3. Reference Documentation (The ADR Library)
This stack is governed by individual Architectural Decision Records (ADRs). Use these to understand the "Why" behind specific configuration settings:

| Component | Architecture Focus | ADR Link |
| :--- | :--- | :--- |
| **Grafana Alloy** | Collection, Enrichment, & Sampling | [alloy.md](./ADR/alloy.md) |
| **Grafana Loki** | Log Aggregation & Persistence | [loki.md](./ADR/loki.md) |
| **Grafana Tempo** | Distributed Traces & Metrics | [tempo.md](./ADR/tempo.md) |
| **Grafana Mimir** | Metrics Scalability | [mimir.md](./ADR/mimir.md) |

## 4. Operational Principles
- **Standardized Ingestion:** All components prioritize S3-native storage to separate compute from durability.
- **Trace Correlation:** Cross-stack navigation is enabled via mandatory `trace_id` promotion to Structured Metadata (Loki) and Exemplars (Mimir).
- **Production Guardrails:** Each component is locked to mandatory resource/cardinality limits defined in its respective ADR to prevent cluster instability.
- **Developer Lifecycle:** Local sandbox environments use optimized flush intervals (e.g., `chunk_idle_period: 30s` for Loki) to ensure data appears in verification scripts without production-scale wait times.
