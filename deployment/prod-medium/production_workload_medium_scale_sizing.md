# 🏗️ Observability Stack Production Workload Sizing & Capacity Planning

This document defines the **Production Workload Sizing, Capacity Matrix, and Resource Allocation Strategy** for the **Grafana LGTM Observability Stack** (Loki, Grafana, Tempo, Mimir/Prometheus, Redpanda, MinIO, Alloy). 

*Note: Application workloads (`spring-boot-app`) and application databases (`mongodb`) are excluded from this sizing analysis and managed on separate application worker pools.*

---

## 1. 🎯 Baseline Assumptions & Observability Workload Profile

The sizing decisions in this document are based on an interactive capacity review for a **Medium-Scale High-Availability (HA) Observability Infrastructure**.

| Dimension | Observability Target Parameter | Notes & Rationale |
| :--- | :--- | :--- |
| **Telemetry Ingestion Traffic** | **500 – 2,000 RPS** (avg ~1,000 RPS) | Medium enterprise application scale |
| **Log Ingestion Volume** | **~150 GB / day** uncompressed (50–250 GB range) | ~1,500 – 2,500 log lines / second |
| **Trace Ingestion Volume** | **~2,000 spans / sec** (100% Full Ingestion) | Retain all error and latency trace contexts |
| **Active Metric Series** | **~250,000 active time series** | 15s scrape interval across pods & infra |
| **Query Pattern** | **Moderate Query Load** | Standard Grafana dashboards + operational triage |
| **Safety Buffer Margin** | **+30% Capacity Headroom** | Applied to all calculated PVC & RAM limits |

---

## 2. ⏳ Data Retention Policy

| Telemetry Type | Target Retention | Storage Layer | Estimated Data Size (with +30% Buffer) |
| :--- | :---: | :--- | :--- |
| **Loki Logs** | **30 Days** | MinIO / Cloud S3 Object Storage | **1.2 TB** (Compressed ~5:1 ratio) |
| **Tempo Traces** | **7 Days** | MinIO / Cloud S3 Object Storage | **400 GB** (Compressed ~4:1 ratio) |
| **Prometheus Metrics** | **30 Days** | Persistent Local SSD PVC (TSDB) | **120 GB per instance** |
| **Redpanda Kafka Buffer** | **24 Hours** | High-Speed NVMe/SSD PVC | **350 GB per broker** (Total: 1.05 TB) |

---

## 3. 📊 Observability Component Sizing & Resource Allocation Matrix

The table below specifies the recommended **Replicas, CPU/Memory Requests & Limits, and PVC Disk Sizes** for each component of the LGTM observability stack in a 3-Zone Multi-AZ High-Availability topology.

| Component / Service | Microservice Role | Replicas / Topology | CPU Request | CPU Limit | RAM Request | RAM Limit | PVC Size (per pod) | Storage Type |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: | :---: | :--- |
| **redpanda** | Kafka Event Stream | 3 Brokers | 1.0 | 4.0 | 4.0 Gi | 4.0 Gi | 350 Gi | NVMe / SSD PVC |
| **loki-distributor** | Log Ingestion Gateway | 3 | 200m | 1.0 | 512 Mi | 1.0 Gi | N/A | Ephemeral |
| **loki-ingester** | Log Chunk Builder | 3 | 500m | 2.0 | 2.0 Gi | 4.0 Gi | 30 Gi | Local SSD PVC (WAL) |
| **loki-querier** | Log Query Engine | 2 | 500m | 2.0 | 1.0 Gi | 3.0 Gi | N/A | Ephemeral |
| **loki-query-frontend** | Query Splitter & Cache | 2 | 200m | 1.0 | 512 Mi | 1.0 Gi | N/A | Ephemeral |
| **loki-compactor** | Index/Chunk Retention | 1 (Active/Standby) | 200m | 1.0 | 1.0 Gi | 2.0 Gi | 20 Gi | SSD PVC |
| **loki-index-gateway** | Index Query Router | 2 | 200m | 1.0 | 512 Mi | 1.0 Gi | 10 Gi | SSD PVC |
| **tempo-distributor** | Trace Receiver | 3 | 200m | 1.0 | 512 Mi | 1.0 Gi | N/A | Ephemeral |
| **tempo-block-builder** | Ingestion & Block Building | 3 | 300m | 1.5 | 1.0 Gi | 2.0 Gi | 20 Gi | SSD PVC (WAL) |
| **tempo-live-store** | Recent Trace Storage | 3 | 300m | 1.5 | 1.0 Gi | 2.0 Gi | 20 Gi | SSD PVC |
| **tempo-querier** | Trace Search Engine | 2 | 300m | 1.5 | 512 Mi | 1.5 Gi | N/A | Ephemeral |
| **tempo-query-frontend** | Trace Query Caching | 2 | 200m | 1.0 | 256 Mi | 512 Mi | N/A | Ephemeral |
| **tempo-metrics-generator**| Span-Metrics Generator | 2 | 300m | 1.0 | 512 Mi | 1.0 Gi | 10 Gi | SSD PVC |
| **prometheus-server** | Metrics Storage TSDB | 2 (HA Pair) | 1.0 | 4.0 | 4.0 Gi | 8.0 Gi | 120 Gi | High-Speed SSD PVC |
| **grafana** | Visualization UI | 2 | 200m | 1.0 | 512 Mi | 1.0 Gi | 10 Gi | SSD PVC |
| **alloy-receiver** | OTLP Ingestion Gateway | 3 | 300m | 1.5 | 512 Mi | 1.0 Gi | N/A | Ephemeral |
| **alloy-agent** | DaemonSet Scraper | 1 / Node (~5) | 200m | 1.0 | 256 Mi | 512 Mi | N/A | Ephemeral HostPath |
| **minio / S3 Storage** | Internal Object Storage | 4 | 500m | 2.0 | 2.0 Gi | 4.0 Gi | 500 Gi | MinIO S3 PVC |

---

## 4. 🧮 Dedicated Observability Cluster Capacity Summary

| Resource Metric | Minimum Guaranteed (Requests) | Maximum Allowed (Limits) | Recommended Dedicated Node Footprint |
| :--- | :---: | :---: | :--- |
| **Total CPU Cores** | **~15.4 Cores** | **~44.5 Cores** | **3x 16-Core Worker Nodes** (48 vCPU total) |
| **Total Memory (RAM)** | **~54.3 GiB** | **~101.5 GiB** | **3x 32GB or 2x 64GB RAM Nodes** (96–128 GB RAM) |
| **Total Persistent Storage (PVC)** | — | — | **~3.6 TB High-Speed NVMe/SSD Storage** |

---

## 5. ⚙️ Observability Architectural Justifications

### 1. Redpanda Kafka Streaming Layer
- **Seastar Memory Model**: Redpanda allocates `--memory` (80% of container limit) + `--reserve-memory` at boot. Setting a 4.0 GiB container limit ensures ~3.2 GB is dedicated to the Seastar engine without OOM risk.
- **Storage Calculation**: 24h retention @ 3 MB/sec streaming $\times$ 3x HA replication factor + 30% safety buffer = **350 GB SSD per broker node**.

### 2. Loki Microservices Mode
- **Ingester Isolation**: 3 Ingesters configured with WAL persistent volume (`30GB PVC` each) to ensure zero log loss during pod restarts or node rollouts.
- **Compactor Safety**: Single compactor instance (Active/Standby) to prevent concurrent index mutation conflicts.

### 3. Tempo Distributed Mode
- **Streaming Ingestion**: BlockBuilder & LiveStore split across 3 replicas matching Redpanda partition count (3 partitions).
- **WAL Persistence**: Each BlockBuilder uses a 20GB PVC for temporary block assembly before flushing to object storage.

### 4. Prometheus Metrics Engine
- **HA Pair Deduplication**: 2 Prometheus instances scraping identical targets. Grafana deduplicates queries using `prometheus` datasource HA grouping.
- **Exemplar Storage**: Configured `storage.tsdb.max-exemplars: "1000000"` with 120 GB PVC to support high trace-to-metric correlation.
