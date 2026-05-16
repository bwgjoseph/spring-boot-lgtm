# System Architecture: Spring Boot LGTM Stack

This document serves as the high-level roadmap for the production observability stack, explaining how the components interact and where to find detailed decision rationales.

## 1. Stack Overview
We follow a **"Decoupled Ingestion & Storage"** pattern. Data enters through a decentralized **Alloy DaemonSet** layer, is processed for correlation (metadata enrichment) and cost management (tail-sampling), and is then routed to specialized backend stores (Loki/Tempo/Mimir).

## 2. Integrated Data Flow
```mermaid
graph TD
    subgraph Apps [Application Layer]
        App1[Spring Boot App Pods]
    end

    subgraph Collection [Collection Layer - Alloy DaemonSet]
        Alloy[Alloy DaemonSet]
    end

    subgraph Storage [Storage & Analysis Layer]
        Loki[Loki - Logs]
        Tempo[Tempo - Traces]
        Mimir[Mimir - Metrics]
    end

    subgraph Backends [Durable Backends]
        S3[S3 Object Storage]
        Mattermost[Alerting: Mattermost]
    end

    App1 -- "OTLP/gRPC (OTEL)" --> Alloy
    App1 -- "Scrape (Metrics)" --> Alloy
    
    Alloy -- "Forwarding" --> Loki
    Alloy -- "Forwarding" --> Tempo
    Alloy -- "Forwarding" --> Mimir

    Loki --> S3
    Tempo --> S3
    Mimir --> S3

    Mimir -- "Alerts" --> Mattermost

    style Alloy fill:#f9f,stroke:#333,stroke-width:2px
    style S3 fill:#eee,stroke:#333,stroke-dasharray: 5 5
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
