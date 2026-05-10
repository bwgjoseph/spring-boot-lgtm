# MinIO: Object Storage Requirements

## 1. Role & Responsibility (The "Job")
MinIO is the **Production Object Storage Backend** for on-premise deployments. Its "job" is to provide an S3-compatible API for long-term storage of logs (Loki), traces (Tempo), and metric blocks (Mimir), decoupling data persistence from ephemeral compute pods.

## 2. Durability & High Availability
- **On-Prem Persistence:** Must use **high-performance SSD/NVMe storage classes** to avoid I/O bottlenecks during compactor and ingestion flushes.
- **Resource Sizing:** Allocate a minimum of **2Gi-4Gi RAM** to ensure adequate metadata caching for high-cardinality telemetry objects.

## 3. Security
- **Credential Pinning:** **Root credentials must be managed via static Kubernetes Secrets.** Hardcoded passwords or dynamic chart-generated secrets are strictly prohibited to prevent data lockout.
- **Network Isolation:** Network policies must restrict access to MinIO to only authorized observability components (Loki, Tempo, Mimir).

## 4. Future Considerations (v2+)
- **Distributed Mode:** Transition to a **4-node distributed deployment** with erasure coding to eliminate the standalone single-node failure risk as storage volume grows.
