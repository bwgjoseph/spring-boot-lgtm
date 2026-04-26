# 🧪 End-to-End (E2E) Observability Verification Plan

This document outlines the automated end-to-end verification strategy for the Spring Boot LGTM observability sandbox. The plan ensures that the telemetry pipeline (Logs, Metrics, and Traces) is healthy, correlated, and enriched with Kubernetes metadata.

---

## 1. Verification Workflow
The verification suite is orchestrated via `Taskfile.yml` and executes a series of modular PowerShell scripts located in the `./verification/` directory.

### Execution
```powershell
task test:e2e
```

### Components
1.  **`k8s-health.ps1`**: Validates the deployment status of all critical stack components.
2.  **`traffic-gen.ps1`**: Generates synthetic activity in both the application and the database.
3.  **`data-verify.ps1`**: Queries the internal service APIs to validate data ingestion and correlation.

---

## 2. Logical Test Phases

### Phase A: Infrastructure Readiness
The suite uses `kubectl rollout status` to verify that all components are operational.
*   **Target Components:** `spring-boot-app`, `alloy`, `prometheus-server`, `loki-gateway`, `tempo`, `mongodb` (ReplicaSet), and `mongodb-arbiter`.
*   **Success Criterion:** All components reach a "Ready" state within the defined timeout (default: 5s per component).

### Phase B: Traffic Generation
To ensure realistic data capture, the suite performs active operations:
1.  **Application Activity:** Calls the `/pokemon/1` endpoint with a unique `test_id` parameter to generate application traces and logs.
2.  **Database Activity:** Performs a `updateOne` operation on the `kx.pokemon` collection in MongoDB to trigger a Debezium CDC event.

### Phase C: Data Pipeline Verification
The verification script queries the backend APIs directly from within the Kubernetes cluster. The `spring-boot-app` pod is utilized as the query proxy because it includes the necessary `wget` utility.

| Verification Point | Query Type | Purpose |
| :--- | :--- | :--- |
| **Metrics (Prometheus)** | `debezium_total_number_of_events_seen` | Confirms CDC events are captured and bridged via JMX. |
| **Logs (Loki)** | Query logs for the generated `test_id` | Verifies log ingestion, structured metadata, and correlation ID mapping. |
| **Traces (Tempo)** | Search by `service.name=spring-boot-app` | Confirms OTLP trace ingestion and backend storage. |
| **Enrichment (Alloy)** | Inspect `k8s.pod.name` in trace spans | Validates that Alloy is successfully enriching traces with cluster metadata. |

---

## 3. Reporting
Upon completion, the suite generates a comprehensive report:
*   **`VERIFICATION_REPORT.md`**: A summary table indicating the pass/fail status of each verification pillar (Metrics, Logs, Traces, Enrichment) and the `test_id` used for that run.

---

## 🛠️ Operational Notes
*   **Time Sensitivity:** The suite includes a 30-second `Start-Sleep` interval after traffic generation to account for Alloy batching and Prometheus/Loki ingestion cycles.
*   **Environment:** The suite relies on `jq` for JSON processing of API responses.
*   **Resource Constraints:** On local clusters (Docker Desktop/KinD), components like Loki may occasionally show 502 errors if memory pressure is high. Verification results should be interpreted in the context of cluster capacity.
