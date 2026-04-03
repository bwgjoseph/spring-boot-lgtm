# 🏗️ Roadmap to Production: LGTM Observability Stack (On-Prem)

This document details the transition from sandbox to production for an on-prem environment running ~10 Spring Boot services (~50 total replicas).

---

## 1. Storage: PVC vs. Object Storage (MinIO)
While PVCs are easier to start with, Loki and Tempo are designed as **cloud-native** databases that prefer object storage.

*   **Downsides of PVC-only storage:**
    *   **Scalability:** PVCs are bound to a specific size. Expanding them often requires downtime or complex storage-class operations. MinIO is "infinitely" scalable.
    *   **High Availability:** Sharing a single PVC across multiple "Read" and "Write" pods requires a ReadWriteMany (RWM) volume (like NFS), which is significantly slower and prone to file-locking issues.
    *   **Cost/Performance:** Object storage allows Loki to store "chunks" of data very cheaply while keeping a tiny index. Disk-based storage for logs becomes very expensive as you move from 7 days to 30+ days of retention.
*   **Recommendation:** Use **MinIO** for the long-term data store and small, fast SSD-backed PVCs for "Write Ahead Logs" (WAL) and local caching.
*   **Sandbox Note:** In this repository, **Tempo** was reverted to local PVC storage due to configuration schema complexities between the `grafana-community/tempo` chart and S3 settings. **Loki** continues to use MinIO.

## 2. Grafana HA with PostgreSQL
*   **The Problem:** By default, Grafana uses a local SQLite file to store users, dashboard definitions, and alert states. You cannot run 2+ replicas of Grafana using the same SQLite file.
*   **The PostgreSQL Solution:** By pointing Grafana to your PostgreSQL instance, you enable **Horizontal Scaling**. You can run 3 Grafana pods behind your NGINX Ingress. If one pod dies, the others continue serving, and no data (dashboards/users) is lost.

## 3. Scaling Modes: Simple Scalable vs. Microservices
For a cluster of your size (~50 pods), the choice is clear:

| Feature | **Simple Scalable** (Recommended) | **Full Microservices** |
| :--- | :--- | :--- |
| **Complexity** | Low (3 main components) | High (10+ components) |
| **Scaling** | Scales "Read" and "Write" paths | Scales every sub-component (Ingester, Querier, etc.) |
| **Management** | Managed via standard Helm chart | Requires heavy orchestration/Jsonnet/Tanka |
| **Suitability** | Perfect for 10-100 services | Designed for thousands of services (Uber/Netflix scale) |

*   **Recommendation:** Use **Simple Scalable Mode**. It provides the HA you need without the massive operational overhead of full microservices.

## 4. Logging Strategy: Labels vs. Text vs. Structured Metadata
Loki 3.0+ introduced a new way to store data that solves the "Trace ID Problem."

### The Three Tiers of Log Data

| Tier | Storage Type | Example | Best For... |
| :--- | :--- | :--- | :--- |
| **Labels** | Indexed (Highly searchable) | `service_name`, `env` | Filtering large volumes of logs quickly. |
| **Structured Metadata** | Non-indexed Fields | `trace_id`, `span_id` | Fast correlation without crashing Loki's memory. |
| **Log Line** | Raw Text | The actual message | Human reading and regex grep. |

### Why Structured Metadata?
In your sandbox, the `trace_id` is just text. To find it, Loki must "grep" every line. 
With **Structured Metadata**, Alloy extracts the `trace_id` and attaches it as a field. 
*   **Advantage:** You get the speed of a label search without the memory cost of indexing unique IDs (High Cardinality).
*   **UI Benefit:** Grafana can automatically find these fields, making the "Trace to Log" button work without custom regex.

## 5. Storage Strategy: MinIO-backed PVCs (Recommended)
Since the cluster primarily supports **ReadWriteOnce (RWO)** PVCs, we will use **MinIO** as a middle layer.
*   **Architecture:** `Loki/Tempo (S3 API) -> MinIO (Pod) -> PVC (Disk)`.
*   **Benefit:** This provides the "Shared Storage" needed for Simple Scalable mode without requiring a cluster-wide RWX filesystem.
*   **Performance:** MinIO should be backed by a high-performance StorageClass (SSD/NVMe).

## 6. Coordination: Memberlist (Gossip)
Simple Scalable mode uses the **Memberlist** protocol for internal coordination.
*   **How it works:** Pods "gossip" with each other to maintain a shared "Hash Ring." This ring tracks which pod is responsible for which logs or traces.
*   **On-Prem Note:** This requires open gossip ports (usually 7946) between all observability pods. It eliminates the need for an external coordinator like Etcd.

## 7. The Scalable Storage Constraint (RWO vs. RWX)
Moving to Simple Scalable mode while staying on PVCs requires a specific storage capability:
*   **ReadWriteOnce (RWO):** Standard disks. Cannot be shared. This will **NOT** work for Simple Scalable mode because "Read" pods cannot see the data written by "Write" pods.
*   **ReadWriteMany (RWX):** Shared filesystems (NFS, Ceph). Required if you insist on avoiding MinIO.
*   **The "Cloud-Native" Recommendation:** Even on-prem, use **MinIO**. It turns your RWO PVCs into an S3-compatible API that Loki and Tempo can share perfectly.

## 8. Ingress & Security
*   **Current Path:** NGINX Ingress + Cert-Manager is the correct production pattern.
*   **Next Step:** Configure the Ingress to point to the Grafana service and ensure the `Simple Scalable` Loki/Tempo components are only accessible internally via the cluster network.
