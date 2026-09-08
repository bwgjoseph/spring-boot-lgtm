# 🏗️ Small-Scale & Long-Term Compliance Workload Sizing

This document defines the **Production Workload Sizing, Capacity Matrix, and Resource Allocation Strategy** for the **Grafana LGTM Observability Stack** configured for a **Small-Scale Deployment with Extended/Long-Term Compliance Data Retention Requirements**.

*Note: Application workloads (`spring-boot-app`) and application databases (`mongodb`) are excluded from this sizing analysis and managed on separate application worker pools.*

---

## 1. 🎯 Baseline Assumptions & Workload Profile

The sizing decisions in this document target a **Small-Scale Enterprise Environment** requiring **Long-Term Compliance & Regulatory Data Retention**.

| Dimension | Small-Scale Compliance Target | Notes & Rationale |
| :--- | :--- | :--- |
| **Telemetry Ingestion Traffic** | **100 – 500 RPS** (avg ~250 RPS) | Small enterprise application scale |
| **Log Ingestion Volume** | **~25 GB / day** uncompressed (10–50 GB range) | ~250 – 500 log lines / second |
| **Trace Ingestion Volume** | **~500 spans / sec** (100% Full Ingestion) | Retain all error and latency trace contexts |
| **Active Metric Series** | **~50,000 active time series** | 15s scrape interval across pods & infra |
| **Query Pattern** | **Light to Moderate Query Load** | Routine operational triage & auditing |
| **Safety Buffer Margin** | **+30% Capacity Headroom** | Applied to all calculated PVC & RAM limits |

---

## 2. ⏳ Long-Term Compliance Retention Policy

| Telemetry Type | Target Retention | Storage Layer | Estimated Data Size (with +30% Buffer) |
| :--- | :---: | :--- | :--- |
| **Loki Logs** | **90 Days** | MinIO / Cloud S3 Object Storage | **600 GB** (Compressed ~5:1 ratio) |
| **Tempo Traces** | **14 Days** | MinIO / Cloud S3 Object Storage | **200 GB** (Compressed ~4:1 ratio) |
| **Prometheus Metrics** | **90 Days** | Persistent Local SSD PVC (TSDB) | **70 GB per instance** |
| **Redpanda Kafka Buffer** | **48 Hours** | High-Speed NVMe/SSD PVC | **170 GB per broker** (Total: 510 GB) |

---

## 3. 📊 Small-Scale Compliance Resource Allocation Matrix

The table below specifies the recommended **Replicas, CPU/Memory Requests & Limits, and PVC Disk Sizes** for a Small-Scale Compliance LGTM observability stack in a 3-Zone Multi-AZ High-Availability topology.

| Component / Service | Microservice Role | Replicas / Topology | CPU Request | CPU Limit | RAM Request | RAM Limit | PVC Size (per pod) | Storage Type |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: | :---: | :--- |
| **redpanda** | Kafka Event Stream | 3 Brokers | 500m | 2.0 | 2.0 Gi | 2.0 Gi | 170 Gi | NVMe / SSD PVC |
| **loki-distributor** | Log Ingestion Gateway | 2 | 100m | 500m | 256 Mi | 512 Mi | N/A | Ephemeral |
| **loki-ingester** | Log Chunk Builder | 3 | 250m | 1.0 | 1.0 Gi | 2.0 Gi | 15 Gi | Local SSD PVC (WAL) |
| **loki-querier** | Log Query Engine | 2 | 250m | 1.0 | 512 Mi | 1.5 Gi | N/A | Ephemeral |
| **loki-query-frontend** | Query Splitter & Cache | 2 | 100m | 500m | 256 Mi | 512 Mi | N/A | Ephemeral |
| **loki-compactor** | Index/Chunk Retention | 1 (Active/Standby) | 100m | 500m | 512 Mi | 1.0 Gi | 15 Gi | SSD PVC |
| **loki-index-gateway** | Index Query Router | 2 | 100m | 500m | 256 Mi | 512 Mi | 10 Gi | SSD PVC |
| **tempo-distributor** | Trace Receiver | 2 | 100m | 500m | 256 Mi | 512 Mi | N/A | Ephemeral |
| **tempo-block-builder** | Ingestion & Block Building | 3 | 150m | 1.0 | 512 Mi | 1.0 Gi | 10 Gi | SSD PVC (WAL) |
| **tempo-live-store** | Recent Trace Storage | 3 | 150m | 1.0 | 512 Mi | 1.0 Gi | 10 Gi | SSD PVC |
| **tempo-querier** | Trace Search Engine | 2 | 150m | 1.0 | 256 Mi | 1.0 Gi | N/A | Ephemeral |
| **tempo-query-frontend** | Trace Query Caching | 2 | 100m | 500m | 128 Mi | 256 Mi | N/A | Ephemeral |
| **tempo-metrics-generator**| Span-Metrics Generator | 2 | 150m | 500m | 256 Mi | 512 Mi | 5 Gi | SSD PVC |
| **prometheus-server** | Metrics Storage TSDB | 2 (HA Pair) | 500m | 2.0 | 2.0 Gi | 4.0 Gi | 70 Gi | High-Speed SSD PVC |
| **grafana** | Visualization UI | 2 | 100m | 500m | 256 Mi | 512 Mi | 10 Gi | SSD PVC |
| **alloy-receiver** | OTLP Ingestion Gateway | 2 | 150m | 1.0 | 256 Mi | 512 Mi | N/A | Ephemeral |
| **alloy-agent** | DaemonSet Scraper | 1 / Node (~3) | 100m | 500m | 128 Mi | 256 Mi | N/A | Ephemeral HostPath |
| **minio / S3 Storage** | Internal Object Storage | 4 | 250m | 1.0 | 1.0 Gi | 2.0 Gi | 250 Gi | MinIO S3 PVC |

---

## 4. 🧮 Dedicated Small-Scale Compliance Capacity Summary

| Resource Metric | Minimum Guaranteed (Requests) | Maximum Allowed (Limits) | Recommended Dedicated Node Footprint |
| :--- | :---: | :---: | :--- |
| **Total CPU Cores** | **~8.2 Cores** | **~25.5 Cores** | **3x 8-Core Worker Nodes** (24 vCPU total) |
| **Total Memory (RAM)** | **~24.5 GiB** | **~45.0 GiB** | **3x 16GB RAM Nodes** (48 GB RAM total) |
| **Total Persistent Storage (PVC)** | — | — | **~1.9 TB High-Speed NVMe/SSD Storage** |

---

## 5. ⚙️ Small-Scale Compliance Tradeoffs & Sizing Rationale

### 1. 90-Day Log Retention Strategy
- Compressing 25 GB/day uncompressed logs produces ~5 GB/day stored in Loki TSDB format.
- 90-day retention totals **450 GB**, buffered with +30% headroom to **600 GB** object storage.

### 2. 48-Hour Redpanda Buffer
- Extended 48-hour Kafka stream retention guarantees payload durability during long holiday weekends or major downstream maintenance windows without losing trace/log events.

### 3. Resource Cost Optimization
- Reduced replica counts for query-frontends, distributors, and OTLP receivers from 3 to 2, while maintaining full 3-node HA for stateful ingesters and streaming brokers.
- Reduced node footprint to **3x 8-Core / 16GB RAM** nodes, cutting cloud compute costs by over 50% compared to the medium-scale production profile.
