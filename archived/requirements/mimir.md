# Mimir: Metric Scalability Requirements

## 1. Storage Architecture
- **S3-Native:** All metric blocks must be stored in S3-compatible object storage to support long-term retention without local disk constraints.
- **Horizontal Scaling:** Support for horizontal scaling of the query and ingestion paths via a monolithic or simple-scalable deployment mode.

## 2. Ingestion & Interoperability
- **Remote Write:** Mandatory support for the Prometheus Remote Write protocol to ingest metrics from Alloy, Tempo, and other sources.
- **Exemplars:** Support for OTEL exemplars to facilitate Metric-to-Trace navigation.

## 3. High Availability
- **Hash Ring:** Maintenance of a consistent hash ring for data distribution across multiple Mimir replicas.
