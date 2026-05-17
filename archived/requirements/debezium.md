# Debezium: Change Data Capture (CDC) Requirements

## 1. Role & Responsibility (The "Job")
Debezium provides Change Data Capture (CDC) to stream database changes into the observability pipeline. Its "job" is to ensure reliable, ordered streaming of MongoDB events for downstream analysis.

## 2. Reliability & Persistence
- **Offset Persistence:** Must use a persistent, distributed store (e.g., Redis or PVC-backed file store) for offsets. Local file stores like `/tmp/offsets.dat` are prohibited in production.
- **Monitoring:** Must expose critical metrics (e.g., `milli_seconds_behind_source`, `total_number_of_events_seen`) via Micrometer/Prometheus.

## 3. Database Architecture
- **HA Deployment:** MongoDB must be deployed as a **ReplicaSet** (Min 3 nodes: Primary, Secondary, Arbiter) to enable the Change Stream API.
- **Persistence:** `persistence.enabled: true` is mandatory for all MongoDB data nodes.

## 4. Operational Resilience
- **Error Handling:** Robust retry policies (`errors.retry.delay.initial.ms`) are required to handle transient database connectivity issues without stalling the stream.
