# 🗄️ Object Storage Evaluation: MinIO vs. RustFS vs. VaultS3

This document provides a comprehensive evaluation of **MinIO**, **RustFS**, and **VaultS3** as the underlying object storage backend for the **Grafana LGTM stack** (Loki, Tempo, Pyroscope, and Prometheus/Mimir) within the `spring-boot-lgtm` project.

It covers both deployment scopes:
1. **Local Sandbox Environment:** Resource-constrained Docker Desktop / KinD clusters on developer workstations (8GB–16GB total host RAM).
2. **Self-Hosted Production Environment:** On-premises or private cloud Kubernetes clusters requiring High Availability (HA), resilience, and enterprise compliance.

---

## 1. 📊 Comprehensive Evaluation Matrix

| Criterion | MinIO (Baseline) | RustFS (`rustfs/rustfs`) | VaultS3 (`Kodiqa-Solutions/VaultS3`) |
| :--- | :--- | :--- | :--- |
| **Language & Runtime** | Go (Garbage Collected runtime) | **Rust** (Tokio async, zero GC overhead) | **Go** (Single static binary, embedded UI) |
| **Idle Memory (Dev / Single-Pod)** | ~250 MiB – 350+ MiB | **~80 MiB – 120 MiB** (saves ~65%) | **~15 MiB – 30 MiB** (saves ~90%) 🏆 |
| **Active Load Memory (Prod)** | 512 MiB – 2+ GiB (Go GC spikes) | **150 MiB – 300 MiB** (predictable, no GC jitter) | **60 MiB – 150 MiB** (serializes on BoltDB lock) |
| **S3 API Compatibility** | ⭐⭐⭐⭐⭐ De facto standard | ⭐⭐⭐⭐⭐ Full SigV4, multipart, ranges, OTLP | ⭐⭐⭐⭐ 80+ APIs, `aws-chunked`, ranges, seekable |
| **HA & Clustering Architecture** | Distributed Erasure Coding ($N$-node) | **Distributed Reed-Solomon EC** (MinIO `xl.meta` format compatible) | ⚠️ **Single-node EC only** (Multi-node Raft is **BETA**) |
| **Kubernetes Readiness** | Mature Helm Chart & Operator | **Official Helm Chart + Rust K8s Operator** | **Official Helm Chart** (`./deploy/helm/vaults3`) |
| **Web UI / Console** | Port 9001 (legacy Go templates) | **Port 9001** (Next.js, React, Tailwind, shadcn) | **Port 9000** (React + Vite embedded single-port) 🏆 |
| **Keycloak / OIDC SSO** | Supported (commercial push) | **OIDC Auth Code Flow with PKCE (`S256`)** | **OIDC Auth Code Flow + STS token exchange** |
| **Event Notifications** | Kafka, Webhook, Redis, NATS, AMQP, Postgres, MQTT | **Webhook, Kafka, NATS, Redis, MQTT, AMQP, Pulsar, MySQL/Postgres** | **Webhook, Kafka, NATS, Redis, AMQP, Postgres, Elasticsearch, Lambda** |
| **Anti-SSRF Webhook Guards** | Basic | Standard | **Enforced by default** (blocks private/loopback/metadata IPs) |
| **Versioning Capabilities** | Standard AWS S3 (Enabled / Suspended) | **Standard AWS S3** (Object Lock, delete markers) | **Standard AWS S3 + Git/lakeFS Commit Snapshots** |
| **Replication** | Multi-site Active-Active / Active-Passive | **Cross-Bucket & Cross-Cluster Asynchronous** | **Active-Active Bidirectional (Vector Clocks)** + Push |
| **Dedicated First-Party CLI** | `mc` (MinIO Client) | **`rc`** (RustFS Client in pure Rust) | **`vaults3-cli`** (bundled Go utility in container) |
| **Ecosystem CLI Interop** | `aws-cli`, `rclone`, Terraform | `aws-cli`, `rclone`, `mc` (Drop-in) | `aws-cli`, `rclone`, `mc` (Drop-in) |
| **Open Source License** | ⚠️ **GNU AGPLv3** (Aggressive enforcement) | 🏆 **Apache 2.0** (Zero enterprise legal friction) | ⚠️ **GNU AGPLv3** (Same license as MinIO) |
| **Community & Traction** | ~48k stars, venture backed | **~35,300+ stars**, 1.6k forks, active releases | ~1,620 stars, 93 forks |
| **Bus Factor & Backing** | MinIO Inc. (Commercial support) | Founding team (ex-MinIO book author), NVIDIA/MiraclePlus backed | **Bus Factor = 1** (Single maintainer `@eniz1806`) |

---

## 2. 🔬 Deep-Dive Analysis by Key Criteria

### 2.1 Resource Footprint & Latency Profile
* **VaultS3:** Unbeatable for local laptops. With an idle footprint of **~17 MiB**, it allows developers on 8GB–16GB workstations to run the full observability stack without Docker Desktop memory exhaustion.
* **RustFS:** Eliminates **Garbage Collection (GC) jitter**. Under high-concurrency trace ingestion from Tempo or log flushes from Loki, Go-based object stores (MinIO/VaultS3) experience GC sweep cycles leading to tail latency (p99) spikes. RustFS uses deterministic memory management via Tokio, providing consistent sub-millisecond I/O response times.
* **MinIO:** Heaviest baseline (~250MB–1GB+). Memory usage scales unpredictably due to internal crawler routines, background healing scanners, and Go runtime heap pacing.

### 2.2 Observability S3 API Compatibility (Loki, Tempo, Pyroscope)
All three systems support the core endpoints required by the LGTM stack:
1. **Path-Style Addressing:** `s3forcepathstyle: true` is fully supported across all three (essential for internal Kubernetes service DNS like `http://minio.monitoring.svc:9000`).
2. **Multipart Uploads:** Required when Loki and Tempo compactors merge small chunks into multi-megabyte blocks.
3. **HTTP Range Reads:** Critical for Tempo Parquet block reading and Pyroscope flamegraph extraction. Tempo queriers first read the Parquet footer (last few kilobytes), then fetch specific column chunks via byte-range headers (`Range: bytes=start-end`). Both RustFS and VaultS3 implement seekable range reads.
4. **Metadata Locking Under High Concurrency:**
   * **RustFS & MinIO:** Distribute metadata alongside object chunks on disk (`xl.meta`), avoiding single-database contention.
   * **VaultS3:** Stores all object metadata in an embedded **BoltDB (`bbolt`)** file (`metadata.db`). Because BoltDB uses a single write mutex, simultaneous flushes from Loki ingesters, Tempo live stores, and Pyroscope agents will serialize on metadata transactions.
5. **⚠️ Critical Observability Guardrail (Versioning):**
   * Buckets for Loki, Tempo, Mimir, and Pyroscope **MUST NOT have versioning enabled**.
   * Compactors continuously delete temporary chunks via batch `DeleteObjects`. In a versioned bucket, this only writes delete markers; disk space will never be reclaimed until non-current lifecycle rules run, quickly exhausting PVC storage.

### 2.3 High Availability & Clustering
* **RustFS:** Implements true **distributed Reed-Solomon Erasure Coding** ($N$ nodes / $M$ drives) without requiring external consensus clusters (no Raft, ZooKeeper, or etcd). Operations use drive quorums ($N/2 + 1$ writes, $N - M$ reads). Crucially, its disk layout is **compatible with MinIO's `xl.meta` format**, allowing seamless migration of existing MinIO storage volumes.
* **VaultS3:** Its multi-node clustering uses Raft consensus for metadata and consistent hash rings for data. However, multi-node clustering is officially marked **BETA**, and its Reed-Solomon erasure coding is strictly **single-node, multi-disk**. It does not provide cross-node distributed erasure coding.
* **MinIO:** Fully battle-tested multi-node distributed erasure coding, but requires commercial licenses for enterprise subnet support.

### 2.4 Event Notifications & Triggers
* **RustFS:** Supports AWS S3 standard `PutBucketNotificationConfiguration` and targets **Webhooks**, Kafka, NATS, Redis, MQTT, AMQP, and Pulsar. Managed via the Web UI, environment variables, or the CLI (`rc event`). Includes `rc watch` for streaming live bucket events in the terminal.
* **VaultS3:** Supports notifications to Webhooks, Kafka, NATS, Redis, AMQP, Postgres, Elasticsearch, and Lambda functions. Features built-in **anti-SSRF validation** to prevent notifications from probing cloud metadata endpoints (`169.254.169.254`) or internal loopback services.
* **MinIO:** Comprehensive event notification subsystem, well-proven across major message brokers.

### 2.5 Data Versioning & Replication
* **Versioning:**
  * **RustFS & MinIO:** AWS S3 standard versioning (`Enabled`/`Suspended`), Version IDs, delete markers, and Object Lock (WORM).
  * **VaultS3:** Standard S3 versioning plus **Git-like / lakeFS-style snapshot commits** (`commit`, `diff`, and instant rollback).
* **Replication:**
  * **RustFS:** Asynchronous cross-bucket and cross-cluster replication (replicates versions, delete markers, or historical objects to remote S3 targets).
  * **VaultS3:** Bidirectional active-active replication using vector clocks and conflict resolution.

### 2.6 CLI Tooling & Ecosystem Interoperability
* **First-Party Tools:**
  * **RustFS:** Ships **`rc`** (RustFS Client), a high-speed CLI written in Rust that mirrors MinIO's `mc` commands (`rc alias set`, `rc mb`, `rc cp`, `rc event`, `rc watch`).
  * **VaultS3:** Bundles **`vaults3-cli`** directly inside its container image for container/pod administration (`docker exec vaults3 vaults3-cli user create`).
* **Universal Compatibility:**
  * Both RustFS and VaultS3 are fully compatible with standard **`aws-cli`** (`aws --endpoint-url http://... s3 ls`), **`rclone`**, and the MinIO client **`mc`**.

### 2.7 Licensing & Legal Risk (The AGPL Barrier)
* **MinIO (AGPLv3):** MinIO transitioned from Apache 2.0 to GNU AGPLv3 and aggressively enforces commercial licensing audits on enterprise adopters.
* **VaultS3 (AGPLv3):** VaultS3 is also released under **GNU AGPLv3**. While it has no aggressive commercial sales enforcement arm, it **does not solve the legal problem** if an organization's Open Source Program Office (OSPO) strictly blacklists AGPLv3 code.
* **RustFS (Apache 2.0):** **100% permissive Apache 2.0 license.** Completely unencumbered by copyleft restrictions, making it universally permissible across corporate enterprises.

---

## 3. ⚖️ Comparative Verdict

| Aspect | Winner | Key Deciding Factor |
| :--- | :---: | :--- |
| **Local Sandbox (Dev / Laptop)** | **VaultS3** | Ultra-lightweight footprint (~17MB idle, <80MB load) saves precious laptop RAM. |
| **Self-Hosted Production (HA)** | 🏆 **RustFS** | True distributed multi-node erasure coding, `xl.meta` compatibility, and no Raft single-write lock bottleneck. |
| **Corporate Legal Compliance** | 🏆 **RustFS** | **Apache 2.0** vs AGPLv3 copyleft in both MinIO and VaultS3. |
| **Ecosystem Maturity & Stars** | 🏆 **RustFS** | ~35,300+ stars, active releases, venture backed vs VaultS3's single-maintainer bus factor. |
| **Console UX & Port Efficiency** | **VaultS3** | Single-port design (port 9000 for both S3 API & React UI) vs two separate ports. |

---

## 4. 🚀 Proposed Strategic Decision Framework (For ADR)

### Strategy Option A: "Dual-Engine Strategy" (Best of Both Worlds)
* **Dev Sandbox (`deployment/dev/`):** Deploy **VaultS3** for the ultimate lightweight footprint (reducing MinIO's ~350MB memory footprint down to ~20MB).
* **Prod-Local / Production (`deployment/prod/`):** Deploy **RustFS** (or retain MinIO) for distributed multi-node HA, Apache 2.0 compliance, and heavy telemetry throughput without BoltDB write locks.

### Strategy Option B: "Unified RustFS Migration" (Recommended)
* Standardize on **RustFS** across **both dev and prod**.
  - **In Dev:** Replaces MinIO, saving ~200MB RAM per node, with fast sub-second startup.
  - **In Prod:** Provides enterprise distributed erasure coding, MinIO disk format compatibility, Keycloak OIDC/PKCE, and complete freedom from AGPLv3 licensing.
  - **Operational Consistency:** One unified Helm chart, identical CLI tooling (`rc`), and uniform S3 configuration across environments.

---

## 5. Next Steps
1. Review and approve the preferred strategy (Option B Unified RustFS vs. Option A Dual-Engine).
2. Author the formal Architectural Decision Record: [`ADR/object-storage.md`](../ADR/object-storage.md) (or update [`ADR/minio.md`](../ADR/minio.md)).
3. Prepare Helm values: `deployment/dev/values-rustfs.yaml` and `deployment/prod/values-rustfs.yaml`.
4. Update `Taskfile.yml` deployment tasks and verify end-to-end pipeline ingestion with `task test:e2e`.
