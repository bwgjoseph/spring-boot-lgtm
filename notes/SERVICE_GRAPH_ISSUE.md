# ISSUE: Service Graph Not Appearing in Grafana (Tempo)

This document summarizes the investigation and fixes applied to restore the Service Graph functionality in the Spring Boot Observability Sandbox.

## Symptom
The **Service Graph** tab in the Tempo datasource in Grafana was empty, even when traces were successfully being ingested and the **Node Graph** (trace-local) was visible.

---

## Issue 1: Loki OOMKilled (502 Bad Gateway)
**Cause:** Loki components (`read`, `backend`, `write`) had very low memory limits (128Mi), causing them to be terminated by Kubernetes when processing queries. This led to a `502 Bad Gateway` error in Grafana when searching for logs.
**Fix:** 
- Increased memory limits: `read` and `backend` to **512Mi**, `write` to **256Mi**.
- Adjusted resource requests for better stability.
**File:** `deployment/values-loki-scalable.yaml`

## Issue 2: Incorrect Prometheus Port (Port 9090 vs 80)
**Cause:** Tempo's `metricsGenerator.remoteWriteUrl` was pointing to `http://prometheus-server.monitoring.svc:9090`. In this setup, the Prometheus service is exposed on port **80**.
**Fix:** Updated the URL to `http://prometheus-server.monitoring.svc:80/api/v1/write`.
**File:** `deployment/values-tempo.yaml`

## Issue 3: Prometheus Remote Write Loop
**Cause:** `values-prometheus.yaml` contained an incorrect `remote_write` block that was trying to push metrics back to Tempo, which is circular and incorrect.
**Fix:** Removed the `remote_write` block and ensured `remoteWriteReceiver: true` was enabled via `extraArgs` to allow Tempo to push metrics into Prometheus.
**File:** `deployment/values-prometheus.yaml`

## Issue 4: Tempo Helm Values Structure Misalignment
**Cause:** The `metricsGenerator` configuration in `values-tempo.yaml` did not match the structure expected by the `tempo-2.0.0` Helm chart. The `remoteWriteUrl` was being ignored by the chart template.
**Fix:** Re-aligned the configuration to the flat structure required by the chart:
```yaml
metricsGenerator:
  enabled: true
  storage:
    remote_write:
      - url: "http://prometheus-server.monitoring.svc:80/api/v1/write"
  processor:
    service_graphs:
      enabled: true
    span_metrics:
      enabled: true
```
**File:** `deployment/values-tempo.yaml`

## Issue 5: Tempo WAL Segment Corruption
**Cause:** Tempo logs showed `ERROR ... msg="error tailing WAL" ... err="failed to find segment for index"`. This prevented the Metrics Generator from processing current spans.
**Fix:** Restarted the Tempo pod (`kubectl delete pod tempo-0 -n monitoring`) to force a reset of the Write-Ahead Log (WAL).
**Verification:** Checked logs after restart to confirm no new WAL errors appeared.

---

## Current Status
- Traces are flowing: **OK**
- Metrics Generator is active: **OK**
- Prometheus is receiving remote write: **OK**
- **Node Graph** shows: **OK**
- **Service Graph** (Global): **Aggregating** (May require 5-10 minutes of consistent traffic to build nodes).

## Next Steps for Future Troubleshooting
If the Service Graph still does not appear after 10 minutes:
1. Run `kubectl logs tempo-0 -n monitoring` and look for `remote_write` errors.
2. Query Prometheus directly for `traces_service_graph_request_total`.
3. Verify that the Tempo datasource in Grafana still has the `Service Map` datasource set to `Prometheus`.
