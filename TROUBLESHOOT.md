# Troubleshooting Guide

This guide documents known issues and resolutions encountered while developing and deploying the Spring Boot LGTM stack.

## 🚀 Image Pull Issues (KinD / Docker / Rancher Desktop)

### Symptom
The application pod stays in `ImagePullBackOff` or `ErrImagePull` state, even though the image was successfully built locally using `.\mvnw jib:dockerBuild`.

```text
Events:
  Type     Reason     Age                From               Message
  ----     ------     ----               ----               -------
  Warning  Failed     9s (x2 over 25s)   kubelet            spec.containers{app}: Failed to pull image "spring-boot-app:demo": failed to pull and unpack image "docker.io/library/spring-boot-app:demo": failed to resolve reference "docker.io/library/spring-boot-app:demo": pull access denied
```

### Root Cause
1.  **KinD / Isolated Runtime:** If your Kubernetes cluster uses an internal container runtime (like `containerd` inside a Docker container) that is isolated from your host's Docker daemon, the image must be explicitly "sideloaded".
2.  **Rancher/Docker Desktop (Moby):** If you use the Docker (moby) engine, the daemon is usually shared, and sideloading is automatic. However, if the node hostname doesn't match the expected Docker container name, manual `docker cp` commands will fail.

### Resolution
The project includes a smart sideloading script that automatically detects your environment.

**Run the automated task:**
```powershell
task app:load
```

This task calls `verification/sideload-image.ps1`, which:
- Checks if the Kubernetes node is a Docker container (like `kind-control-plane`).
- If yes: Saves, copies, and imports the image using `ctr`.
- If no (shared daemon like Rancher Desktop): Skips sideloading as the image is already available.

### Manual Verification
Verify that the image is visible to the cluster:
```powershell
# For containerized nodes (kind)
docker exec <node-container-name> crictl images | Select-String "spring-boot-app"

# For shared daemon nodes (Rancher/Docker Desktop)
docker images spring-boot-app:demo
```

## 🔍 General Connectivity

### Port-Forwarding Fails
If `task port-forward` fails or the UIs are unreachable:
1.  Check if the pods are actually `Running` and `Ready`: `kubectl get pods -n monitoring`.
2.  Ensure no other process is using the ports (3000, 8080, 9090).
3.  Try restarting the port-forward task.

### Grafana Login Issues
If you cannot login to Grafana:
1.  Retrieve the password again: `task password`.
2.  Note that the default username is always `admin`.

## 📈 Observability Issues

### Loki: "No data found in 'loki' bucket" (Verification Warning)
**Symptom:** `task verify:loki` reports `WARNING: - No data found in 'loki' bucket`.
**Cause:** Loki buffers logs in memory/WAL and only flushes to S3 every 30m-2h by default. In a dev environment, the verification script (waiting 60s) finishes before the flush occurs.
**Resolution:**
1.  Ensure `deployment/dev/values-loki.yaml` has aggressive ingester settings for dev:
    ```yaml
    ingester:
      chunk_idle_period: 30s
      max_chunk_age: 1m
    ```
2.  Restart Loki after applying: `kubectl rollout restart statefulset/loki -n monitoring`.
3.  **Path Note:** The script searches the **root** of the bucket (looking for the `fake/` tenant prefix) because TSDB schema with authentication disabled does not use a `chunks/` subfolder.

### Alloy: "Logs: No log processing detected" (Verification Warning)
**Symptom:** `task verify:alloy` reports `WARNING: - Logs: No log processing detected`.
**Cause:** This usually means Alloy is not successfully tailing files or is failing to push them to Loki.
**Resolution:**
1.  **Check Metrics:** The project uses `loki_write_sent_entries_total` to verify the log pipeline. Verify this metric in the Alloy UI (`localhost:12345`).
2.  **Check Logs:** Confirm Alloy is discoverying and tailing pods: `kubectl logs -l app.kubernetes.io/name=alloy -n monitoring`.
3.  **Check RBAC:** Ensure Alloy has `get`, `list`, and `watch` permissions for `pods` and `namespaces` (handled by the Helm chart, but verify if using custom RBAC).

### Loki 502 Bad Gateway / OOMKilled
**Symptom:** Grafana shows a `502 Bad Gateway` when querying Loki logs.
**Cause:** Default memory limits (128Mi) are too low for query processing, or the "Simple Scalable" mode is over-committing the node.
**Resolution:** 
1.  Increase memory limits in `deployment/prod/values-loki.yaml`.
2.  **Recommended for Sandbox:** Use the **Loki Single Binary** mode in `deployment/dev/values-loki.yaml`. Consolidates all services into one pod.

### Application Crashes during Startup
**Symptom:** Pod status is `CrashLoopBackOff` or `Running` but never `Ready`.
**Cause:** The application initialization (Spring + Debezium + Jolokia) requires significant headroom and time.
**Resolution:**
1.  Ensure the memory limit is at least **1Gi** in `deployment/dev/app.yaml`.
2.  Ensure `initialDelaySeconds` for liveness/readiness probes is at least **120s**.
3.  Set `timeoutSeconds: 5` for liveness/readiness probes to allow the JVM more time to respond during high-load startup sequences.

### Jolokia 404/401 Errors
**Symptom:** `http://localhost:8080/actuator/jolokia` returns 404 or 401.
**Resolution:**
1.  **404:** Ensure `jolokia-support-spring` is in `pom.xml`.
2.  **401:** Jolokia is protected by Spring Security. Use Basic Auth with `user:password`.

### Grafana cannot reach Loki (Connection Refused)
**Symptom:** Grafana logs show `dial tcp ...:80: connect: connection refused` when querying Loki.
**Cause:** 
1.  The `loki-gateway` pod is stuck in `Pending` due to pod anti-affinity rules on a single-node cluster.
2.  The `loki-gateway` service is targeting the wrong port or the Nginx configuration is not listening on the expected port.
**Resolution:**
1.  Verify the `loki-gateway` pod is `Running`. If `Pending`, manually delete old gateway pods to break anti-affinity deadlocks.
2.  Ensure `gateway.podAntiAffinity.enabled` is set to `false` in `values-loki-scalable.yaml`.
3.  Ensure the `gateway`, `read`, `write`, and `backend` blocks are correctly nested under the `loki:` key in `values-loki-scalable.yaml`.

### Grafana cannot reach Tempo (Connection Refused)
**Symptom:** Grafana shows `dial tcp ...:3200: connect: connection refused` when querying traces.
**Cause:** 
1.  Tempo pod is in `CrashLoopBackOff` due to OOM (Exit Code 137) or liveness probe failures.
2.  Default memory limits (256Mi) may be too low during WAL replay on startup.
**Resolution:**
1.  Increase memory limits in `values-tempo.yaml` to at least `1Gi`.
2.  Increase `livenessProbe` and `readinessProbe` `initialDelaySeconds` and `timeoutSeconds` to account for slow startups in local environments.

### Trace-to-Log: No results found (Zero-width time range)
**Symptom:** In Tempo, clicking "Logs for this span" results in "No results found" even though the query is correct.
**Cause:** The logs search time range exactly matches the span start/end times. If logs were ingested with a slight delay or clock drift exists, they may fall outside this exact window.
**Resolution:**
1.  In `deployment/datasources.yaml`, ensure `spanStartTimeShift` is set to a negative value (e.g., `-5s`) and `spanEndTimeShift` is set to a positive value (e.g., `5s`).
2.  This expands the search window around the span, increasing the chance of finding correlated logs.

### Tempo: "Field not found" Schema Errors
**Symptom:** Pods crash with `failed parsing config... field not found in type ...`.
**Cause:** Tempo 2.x enforces a strict configuration schema. Legacy fields (e.g., `search_finished_blocks`, `max_spans_per_trace`) have been removed or relocated to prevent OOM errors and configuration drift.
**Resolution:**
1.  Check pod logs (`kubectl logs <pod-name> -c tempo`) to identify the exact field causing the `unmarshal error`.
2.  Remove or move the invalid field. Use the official [Tempo Configuration Reference](https://grafana.com/docs/tempo/latest/configuration/) to verify the correct schema.
3.  Force restart the pod to trigger a fresh ConfigMap mount: `kubectl delete pod <pod-name> --force --grace-period=0`.

### Tempo: "CrashLoopBackOff" on Config Change
**Symptom:** Pod fails to start after updating `values-tempo.yaml`.
**Cause:** Kubernetes ConfigMap volume mounts are not immediately refreshed when the ConfigMap is updated. The pod may be holding a stale volume snapshot.
**Resolution:**
1.  Verify the ConfigMap content: `kubectl get cm tempo -o yaml`.
2.  If the ConfigMap is correct but the pod is still failing, manually delete the pod to force a re-mount: `kubectl delete pod <pod-name> --force --grace-period=0`.

### TraceQL metrics not configured / local-blocks processor not found
**Symptom:** Grafana Traces Drilldown page shows "TraceQL metrics not configured" or "localblocks processor not found".
**Cause:** The `local-blocks` processor is not enabled in the Tempo `metrics_generator` configuration. This processor is required for the Traces Drilldown feature.
**Resolution:**
1.  Add `local-blocks` to the `metrics_generator_processors` list in `values-tempo.yaml`.
2.  Redeploy Tempo and restart the pod.

### Service Graph is Empty
**Symptom:** The Service Graph tab in Tempo is empty.
**Resolution:**
1.  Verify Tempo `remote_write` is pointing to Prometheus on port **80**.
2.  Check for WAL errors in Tempo logs (`kubectl logs tempo-0 -n monitoring`). If "failed to find segment" errors exist, restart the pod.
3.  Ensure `remoteWriteReceiver: true` is enabled in Prometheus `values-prometheus.yaml`.
4.  See [SERVICE_GRAPH_ISSUE.md](SERVICE_GRAPH_ISSUE.md) for a detailed post-mortem.

## 🍃 MongoDB & Debezium Issues

### MongoDB Pods Stuck in "Pending" (Insufficient memory)
**Symptom:** `kubectl get pods` shows `mongodb-arbiter-0` or `mongodb-0` as `Pending`. `kubectl describe pod` shows `Insufficient memory`.
**Cause:** The Bitnami chart's default resource requests are too high for a local Docker Desktop/KinD node.
**Resolution:** 
1.  Lower the `requests` and `limits` in `deployment/dev/values-mongodb.yaml`.
2.  Example: Set `memory` requests to `128Mi` or `256Mi`.
3.  Ensure the `global.resourcesPreset` is set to `"none"`.

### MongoDB Pods "OOMKilled"
**Symptom:** Pod status is `CrashLoopBackOff`, and `describe pod` shows `Reason: OOMKilled`.
**Cause:** MongoDB 8.x requires at least 256MB-512MB of RAM to start the engine and JVM-based helpers.
**Resolution:** 
1.  Increase the `limits.memory` in `values-mongodb.yaml` to at least `512Mi`.
2.  If the node is full, lower the memory requests of other pods (like the `spring-boot-app`) to make room.

### Debezium Metrics Show -1.0
**Symptom:** `debezium_milli_seconds_behind_source` or `debezium_total_number_of_events_seen` shows `-1.0`.
**Cause:** Debezium initializes these metrics with `-1.0` until the first event is processed in that specific context (`snapshot` vs `streaming`).
**Resolution:** Generate some activity in the database (e.g., `db.collection.insertOne(...)`). The metrics will update on the next scrape.

### Debezium Not Capturing Changes
**Symptom:** Logs show `After applying the include/exclude list filters, no changes will be captured`, and CDC metrics remain at 0 or empty.
**Cause:** Debezium requires the database and collection to exist *before* the connector initializes, and it only captures *changes* (events). If the collection doesn't exist, it has nothing to watch; if it exists but is empty, updates won't generate Oplog entries.
**Resolution:**
1.  **Bootstrap the Database:** Ensure the target database (`kx`) and collection (`pokemon`) exist.
    ```javascript
    db.getSiblingDB('kx').createCollection('pokemon');
    db.getSiblingDB('kx').pokemon.insertOne({name: 'Pikachu'});
    ```
2.  **Trigger a Change:** Debezium monitors the Oplog for operations (`insert`, `update`, `replace`, `delete`). A simple `updateOne` on an existing document is the most reliable way to verify the event pipeline.
3.  **Verify Metrics:** Monitor `debezium_total_number_of_events_seen` in Prometheus.

### Verifying ReplicaSet Status
If the app cannot connect to MongoDB, verify the cluster health manually:
```powershell
kubectl exec -it mongodb-0 -n monitoring -- mongosh admin -u admin -p password --eval "rs.status()"
```
Look for `stateStr: 'PRIMARY'` and ensure at least one other member is `SECONDARY`.
