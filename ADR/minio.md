# ADR: MinIO Object Storage Backend

## Status
Proposed

## Context
For on-premise deployments of the LGTM stack, we require an S3-compatible object storage backend. This provides a scalable, durable, and cost-effective home for long-term telemetry data that is independent of the ephemeral compute pods.

## Decision
1.  **Deployment Mode:** **Standalone** (relying on underlying high-performance SSD infrastructure for durability).
2.  **Persistence:** Mandatory use of **SSD/NVMe-backed Persistent Volumes**.
3.  **Credential Management:** Use **static Kubernetes Secrets** injected into the Helm chart as an `existingSecret`.
4.  **Resource Allocation:** Allocate **2Gi-4Gi RAM** for MinIO pods to optimize S3 metadata caching.

## Rationale
- **Standalone Efficiency:** Reduces management overhead compared to distributed mode, while SSD-backed storage provides the necessary I/O throughput to support high-frequency log/trace flushes.
- **Credential Stability:** Using static Kubernetes secrets prevents data lockout scenarios that would otherwise occur if passwords were regenerated during Helm upgrades.
- **Caching performance:** MinIO relies on RAM for object listing; sizing this adequately prevents timeouts during compaction and index maintenance jobs in Loki/Tempo.

## Implementation Source of Truth
- **Persistence:** `persistence.size: 50Gi` (minimum recommendation) on SSD storage class.
- **Credential Strategy:** `existingSecret: minio-secret`.
- **Resources:** `requests: 1Gi, limits: 4Gi`.

## Technical Specification & Mapping
This table maps the production implementation in `deployment/prod/values-minio.yaml` to the architectural decisions and requirements.

| YAML Path | Logic / Value | Purpose | Requirement Link |
| :--- | :--- | :--- | :--- |
| `mode` | `standalone` | Simplifies operations on-prem. | `req/minio.md` Sec 1.0 |
| `persistence` | `enabled: true` | Ensures data survival on restart. | `REQUIREMENTS` Sec 1.1 |
| `resources` | `1Gi / 4Gi` | Ensures sufficient metadata caching memory. | `req/minio.md` Sec 2.0 |
| `existingSecret` | `minio-secret` | Prevents password rotation lockout. | `req/minio.md` Sec 3.0 |

## Consequences
- **Positive:** High performance and operational simplicity.
- **Negative:** Hardware failure on the node hosting MinIO requires manual recovery procedures.
- **Risk:** High dependency on the SSD performance for all telemetry writes/reads.
