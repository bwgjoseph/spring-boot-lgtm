# 🧪 End-to-End (E2E) Observability Verification Plan

This document outlines the hardened automated end-to-end verification strategy for the Spring Boot LGTM observability sandbox. The plan ensures that the telemetry pipeline (Logs, Metrics, and Traces) is healthy, correlated, and enriched with Kubernetes metadata through deterministic, strict testing.

---

## 1. Verification Workflow
The verification suite is orchestrated via `Taskfile.yml` and executes a series of modular PowerShell scripts located in the `./verification/` directory.

### Execution
```powershell
task test:e2e
```

### Components
1.  **`k8s-health.ps1`**: Strictly waits for all critical stack pods to be in a `Ready` state before proceeding.
2.  **`traffic-gen.ps1`**: Generates synthetic activity, verifying the application is responsive before starting.
3.  **`data-verify.ps1`**: A polling-based verification engine that queries APIs until conditions are met or a timeout is reached.

---

## 2. Robust Test Phases

### Phase A: Strict Infrastructure Readiness
The suite uses `kubectl wait --for=condition=Ready` with a 120s timeout for all components.
*   **Target Components:** `spring-boot-app`, `alloy`, `prometheus-server`, `loki`, `tempo`, `mongodb`.
*   **Success Criterion:** If any pod fails to reach a "Ready" state, the test fails immediately (Fail-Fast).

### Phase B: Deterministic Traffic Generation
1.  **App Check:** Verifies the app is reachable via `curl` before triggering activity.
2.  **Traffic Gen:** Injects unique `test_id` via API and MongoDB CDC stream.
3.  **Success Criterion:** If the app is not responsive, the suite halts.

### Phase C: Data Pipeline Verification (Polling Engine)
The core logic now uses a back-off/retry strategy for all queries:
*   **Strategy:** Poll every 5s for up to 120s.
*   **Result:** A test only passes if the specific metric/log/trace count becomes `> 0`.
*   **Loki Gateway:** Uses a prioritized failover: Gateway -> Pod Direct.

| Verification Point | Metric/Query | Validation Method |
| :--- | :--- | :--- |
| **Infra Health** | `kubectl wait` | Ready status for all pods. |
| **Prometheus** | `debezium_total_number_of_events_seen` | Polling for positive integer. |
| **Loki** | `{service_name="spring-boot-app"} |= "$testId"` | Polling until result found. |
| **Tempo** | `api/search?tags=service.name=spring-boot-app` | Polling for trace count > 0. |
| **Alloy** | `k8s.pod.name` | Verify metadata in retrieved span. |

---

## 3. Reporting
*   **`VERIFICATION_REPORT.md`**: Includes an **Overall Status** header. If any phase or sub-test fails, the suite returns a non-zero exit code.
*   **Readability:** Results are presented in an aggregated table with per-component status.
