# 🧪 Resource-Constrained Isolated Verification Plan (<4GB RAM)

## 1. Overview & Strategy

This document outlines the **Pillar-Based Isolated Verification (Modular Testing)** architecture for the Spring Boot 3.5 (Java 25) LGTM Observability Sandbox. 

Due to local hardware limits (~4.0 GB host RAM allocated to Docker Desktop / WSL2), running the entire LGTM stack simultaneously with distributed tracing (Tempo microservices + Redpanda), log storage (Loki), metrics long-term storage, continuous profiling (Pyroscope), MongoDB ReplicaSets, and the Spring Boot application exceeds memory limits and causes `OOMKilled` or `CrashLoopBackOff` failures.

To solve this, testing is partitioned into **5 serial lanes**. Each lane spins up only its required dependency graph, executes deterministic assertions against real services, logs verification evidence, and tears down before the next lane begins.

```
       TOTAL WSL2/K8S HOST RAM CEILING: ~4.0 GB MAX
+-------------------------------------------------------------+
| Resident Anchor: Grafana Alloy (~150 MiB)                   |
+-------------------------------------------------------------+
  |
  +---> [LANE 1: App + MongoDB CDC + Starter Contract] (~2.3 GB)
  |     - Up: MongoDB RS (3 pods) + SpringBootApp + Alloy
  |     - Test: Actuator Health, Debezium CDC stream, baggage, MDC logs
  |     - Teardown: SpringBootApp -> 0, MongoDB -> 0
  |
  +---> [LANE 2: Distributed Tempo 3.x + Redpanda + S3] (~3.0 GB)
  |     - Up: MinIO + Redpanda + Tempo Distributed (Kafka ingest)
  |     - Test: OTLP gRPC 4317 -> Alloy -> Tempo Distributor -> Redpanda 
  |             -> BlockBuilder -> S3 & Querier HTTP Trace search
  |     - Teardown: Tempo -> 0, Redpanda -> 0
  |
  +---> [LANE 3: Log Ingestion & Structured Metadata: Loki + S3] (~1.2 GB)
  |     - Up: MinIO + Loki (Single-Binary with S3)
  |     - Test: Pod log tailing -> regex parser -> Structured Metadata index
  |             (trace_id, span_id, user_id) verified via Loki LogQL API
  |     - Teardown: Loki -> 0, MinIO -> 0
  |
  +---> [LANE 4: Metrics & Prometheus Scrape / Histograms] (~900 MiB)
  |     - Up: Prometheus Server
  |     - Test: Scrape configs, HTTP requests histograms, native buckets
  |     - Teardown: Prometheus -> 0
  |
  +---> [LANE 5: Continuous Profiling: Pyroscope] (~800 MiB)
  |     - Up: Pyroscope (Filesystem mode)
  |     - Test: JFR profiling HTTP 9999 -> Alloy -> Pyroscope push (200 OK)
  |     - Teardown: Pyroscope -> 0
  |
  v
[FINAL STAGE: HTML Report Generation & Launch]
  - Compiles results into a self-contained `verification-report.html`
```

---

## 2. Lane Specifications

### Lane 1: Spring Boot Application Core & CDC Engine
* **Purpose:** Validates the newly extracted `observability-spring-boot-starter`, Tomcat web container, Spring Security correlation, and MongoDB change stream extraction via embedded Debezium.
* **Active Pods:** `mongodb-0`, `mongodb-1`, `mongodb-arbiter-0`, `spring-boot-app`, `alloy`.
* **Peak Estimated RAM:** ~2.3 GB.
* **Deterministic Checks:**
  1. `/actuator/health/liveness` returns `{"status":"UP"}`.
  2. `/actuator/health/readiness` returns `{"status":"UP"}`.
  3. REST API `/pokemon/1` executes with Basic Auth and returns expected JSON payload.
  4. MongoDB document mutation on `kx.pokemon` triggers Debezium CDC connector.
  5. Log stream inspection verifies MDC correlation pattern: `[spring-boot-app,traceId,spanId,userId]`.
* **Teardown:** Scales `spring-boot-app`, `mongodb`, and `mongodb-arbiter` to 0 replicas.

---

### Lane 2: Distributed Tempo 3.x & Redpanda Kafka Pipeline
* **Purpose:** Proves that the production-grade distributed tracing architecture functions end-to-end, including high-throughput Kafka ingest buffering and S3 persistence.
* **Active Pods:** `minio`, `redpanda-0`, `tempo-distributor`, `tempo-block-builder`, `tempo-live-store`, `tempo-query-frontend`, `tempo-querier`, `tempo-backend-worker`, `alloy`.
* **Peak Estimated RAM:** ~3.0 GB.
* **Deterministic Checks:**
  1. `rpk topic list` verifies the Kafka topic `tempo-traces` is active and healthy on the Redpanda broker.
  2. MinIO S3 bucket `local/tempo` is initialized and reachable.
  3. OTLP gRPC telemetry batch injected on Alloy port `4317` traverses:
     `Alloy -> Tempo Distributor -> Redpanda Kafka Topic -> Tempo Block Builder -> S3 Storage`.
  4. Querying Tempo HTTP API `/api/search?tags=service.name=telemetrygen` confirms trace indexing.
* **Teardown:** Helm uninstalls `tempo` and `redpanda`.

---

### Lane 3: Loki Log Ingestion & Structured Metadata Pipeline
* **Purpose:** Validates log tailing from `/var/log/pods`, regex promotion of baggage/trace IDs into structured metadata, and S3 chunks storage.
* **Active Pods:** `minio`, `loki-0` (or `loki-gateway`), `alloy`.
* **Peak Estimated RAM:** ~1.2 GB.
* **Deterministic Checks:**
  1. Loki `/ready` gateway endpoint responds with HTTP 200 / `ready`.
  2. Synthetic log injection via `telemetrygen` job.
  3. Querying Loki LogQL API (`/loki/api/v1/query_range`) verifies logs are indexed and queryable with structured metadata tags.
* **Teardown:** Helm uninstalls `loki` and scales `minio` to 0 replicas.

---

### Lane 4: Prometheus Metrics Engine & Scraping
* **Purpose:** Validates that Prometheus is scraping endpoints discovered via pod annotations (`k8s.grafana.com/scrape: "true"`), storing timeseries histograms, and supporting PromQL queries.
* **Active Pods:** `prometheus-server`, `alloy`.
* **Peak Estimated RAM:** ~900 MiB.
* **Deterministic Checks:**
  1. Prometheus server `/-/ready` endpoint responds ready.
  2. PromQL query `/api/v1/query?query=up` returns active scrape targets with status `success`.
* **Teardown:** Scales `prometheus-server` deployment to 0 replicas.

---

### Lane 5: Continuous Profiling Engine (Pyroscope)
* **Purpose:** Validates continuous profiling collection without external S3 overhead using ephemeral local filesystem storage.
* **Active Pods:** `pyroscope-0`, `alloy`.
* **Peak Estimated RAM:** ~800 MiB.
* **Deterministic Checks:**
  1. Pyroscope HTTP `/ready` endpoint responds on port `4040`.
  2. Profiles pushed via Alloy HTTP listener on port `9999` are accepted (`msg="profile accepted"` in distributor log).
  3. JFR symbolication and compaction work properly on local disk storage.
* **Teardown:** Scales `pyroscope` statefulset to 0 replicas.

---

## 3. Automation & Reporting

### Taskfile Target
Run the full isolated verification pipeline with a single command:
```powershell
task test:isolated
```

### Script Architecture
* **Orchestrator:** [`verification/run-isolated-lanes.ps1`](file:///C:/Users/bwgjoseph/workspace/spring-boot-lgtm/verification/run-isolated-lanes.ps1)
  - Controls rollout sequencing and teardowns.
  - Measures memory request metrics dynamically from the Kubernetes API.
  - Aggregates test check results into a structured payload.
* **HTML Generator:** [`verification/generate-html-report.ps1`](file:///C:/Users/bwgjoseph/workspace/spring-boot-lgtm/verification/generate-html-report.ps1)
  - Compiles execution results into a dark-themed HTML report.
  - Includes KPI summary cards (Total Passed/Failed, Peak RAM observed, Budget headroom).
  - Generates evidence tables with code blocks showing raw API and log responses.
  - Outputs to `verification/reports/verification-report-<timestamp>.html` and symlinks/copies to `latest-report.html`.
  - Automatically launches the report in your browser upon completion.

---

## 4. Failure Triage Guide

| Symptom | Likely Cause | Recommended Resolution |
| :--- | :--- | :--- |
| **Lane 1 Pod Pending** | Node memory exhausted before lane teardown | Run `task scale-down` before starting the test suite. |
| **Lane 2 Redpanda Crash** | Docker Desktop WSL2 memory limit hit | Check `.wslconfig` memory limit (ensure >= 4GB); verify `resources.memory.container.max: 2Gi` in `values-redpanda.yaml`. |
| **Lane 2 Tempo Block Builder Not Ready** | S3 bucket not accessible | Ensure MinIO secret exists (`task secret:minio`) and `minio` deployment is running. |
| **Lane 3 Loki Ingestion Timeout** | Gateway service DNS lookup failure | Verify `alias-alloy-service.yaml` and `values-k8s-monitoring.yaml` endpoint URLs match `loki-gateway.monitoring.svc.cluster.local`. |
| **Lane 5 Port 9999 Connection Refused** | Alloy config missing `profilesReceiver` | Ensure `values-k8s-monitoring.yaml` has `profilesReceiver.enabled: true` and `port: 9999` exposed under `extraPorts`. |
