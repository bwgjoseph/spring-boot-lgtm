# ADR: Debezium Change Data Capture (CDC)

## Status
Proposed

## Context
Debezium is required to stream database changes (MongoDB) into the observability pipeline. This provides real-time visibility into database state changes for downstream analysis and debugging.

## Decision
1.  **HA Database Architecture:** MongoDB must be deployed as a **ReplicaSet** (Min 3 nodes: Primary, Secondary, Arbiter) to expose the Change Stream API.
2.  **Persistence:** Mandatory `persistence.enabled: true` for all MongoDB data nodes to ensure event log persistence during restarts.
3.  **Offset Management:** CDC offsets must be stored in a persistent, distributed store (e.g., Redis or PVC-backed) rather than local `/tmp` files.
4.  **Observability:** Expose internal CDC metrics (e.g., `milli_seconds_behind_source`) via Prometheus/Micrometer.
5.  **Resilience:** Implement robust retry policies (`errors.retry.delay.initial.ms`) to handle transient database connectivity issues without stalling the stream.

## Rationale
- **ReplicaSet API:** Change Data Capture relies on the MongoDB Oplog, which is only effectively managed and available across all replicas in a cluster configuration.
- **Durable Offsets:** Storing offsets in a file on the Debezium pod risks data duplication or loss upon pod migration or restart.
- **Operational Stability:** Configuring retry policies ensures that transient network issues do not stall the streaming pipeline, maintaining event order and stream health.

## Implementation Source of Truth
- **Persistence:** MongoDB `ReplicaSet` + PVC-backed offset store.
- **CDC Metrics:** Exposed via Prometheus/Micrometer.
- **Error Handling:** Configured via connector-level retry parameters.

## Consequences
- **Positive:** Reliable, ordered database event streaming for observability.
- **Negative:** Significant increase in cluster resource footprint for running MongoDB HA.
- **Risk:** Stalled event streams if connectivity issues are not managed by retries.
