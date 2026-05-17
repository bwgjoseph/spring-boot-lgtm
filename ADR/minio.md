# ADR: MinIO Object Storage Backend

## Status
Proposed

## Context
For on-premise deployments of the LGTM stack, we require an S3-compatible object storage backend. This provides a scalable, durable, and cost-effective home for long-term telemetry data that is independent of the ephemeral compute pods. Key requirements include:
- **S3 Compatibility:** To serve as a standardized backend for Loki, Tempo, and Mimir.
- **HA Standards:** Performance and reliability despite the decoupling from compute layers.
- **Security:** Strict credential and network management to prevent unauthorized access or lockout.

## Decision
1.  **Deployment Mode:** **Standalone** (relying on underlying high-performance SSD infrastructure for durability).
2.  **Persistence:** Mandatory use of **SSD/NVMe-backed Persistent Volumes** to avoid I/O bottlenecks.
3.  **Credential Management:** Use **static Kubernetes Secrets** injected into the Helm chart as an `existingSecret`.
4.  **Network Isolation:** Network policies must restrict MinIO access to only authorized observability components.
5.  **Resource Allocation:** Allocate a minimum of **2Gi-4Gi RAM** to optimize S3 metadata caching for high-cardinality telemetry.

## Rationale
- **Standalone Efficiency:** Reduces management overhead compared to distributed mode, while SSD-backed storage provides the necessary I/O throughput to support high-frequency log/trace flushes.
- **Credential Stability:** Using static Kubernetes secrets prevents data lockout scenarios that would otherwise occur if passwords were regenerated during Helm upgrades.
- **Caching Performance:** MinIO relies on RAM for object listing; sizing this adequately prevents timeouts during compaction and index maintenance jobs in Loki/Tempo.
- **Network Security:** Minimizing exposure via Network Policies ensures only authorized services can interact with the object storage backend.

## Implementation Source of Truth
- **Persistence:** `persistence.size: 50Gi` (minimum recommendation) on SSD storage class.
- **Credential Strategy:** `existingSecret: minio-secret`.
- **Resources:** `requests: 1Gi, limits: 4Gi`.

## Technical Specification & Mapping
This table maps the production implementation in `deployment/prod/values-minio.yaml` to the architectural decisions and requirements.

| YAML Path | Logic / Value | Purpose | Requirement Link |
| :--- | :--- | :--- | :--- |
| `mode` | `standalone` | Simplifies operations on-prem. | `ADR` Sec 1.0 |
| `persistence` | `enabled: true` | Ensures data survival on restart. | `ADR` Sec 2.0 |
| `resources` | `1Gi / 4Gi` | Ensures sufficient metadata caching memory. | `ADR` Sec 5.0 |
| `existingSecret` | `minio-secret` | Prevents password rotation lockout. | `ADR` Sec 3.0 |

## Consequences
- **Positive:** High performance and operational simplicity.
- **Negative:** Hardware failure on the node hosting MinIO requires manual recovery procedures.
- **Risk:** High dependency on the SSD performance for all telemetry writes/reads.
- **Future Considerations:** Transition to a **4-node distributed deployment** with erasure coding as storage volume grows to eliminate single-node failure risk.
