# Troubleshooting Guide

This guide documents known issues and resolutions encountered while developing and deploying the Spring Boot LGTM stack.

## 🚀 Image Pull Issues (KinD / Docker / Rancher Desktop)

### Symptom
The application pod stays in `ImagePullBackOff` or `ErrImagePull` state, even though the image was successfully built locally using `.\mvnw jib:dockerBuild`.

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

---

## 🔍 General Connectivity

### Alloy: Gossip Memberlist Failure (Connection Refused 12345)
**Symptom:** Alloy logs show `failed to connect to peers; bootstrapping a new cluster` with `dial tcp ...:12345: connect: connection refused`.
**Cause:** The Gossip cluster coordination requires both the Gossip port (7946) and the gRPC transport port (12345) to be open and correctly targeted.
**Resolution:**
1.  **Prefer `extraPorts`:** Use the `extraPorts` block in `values-alloy.yaml` to expose `4317` (OTLP) and `12345` (Cluster gRPC).
2.  **Verify Headless Service:** Ensure the `alloy-cluster` headless service exists and its endpoints list all Alloy pod IPs.

### Port-Forwarding Fails
If `task port-forward` fails or the UIs are unreachable:
1.  Check if the pods are actually `Running` and `Ready`: `kubectl get pods -n monitoring`.
2.  Ensure no other process is using the ports (3000, 8080, 9090).
3.  Try restarting the port-forward task.

### Grafana Login Issues
If you cannot login to Grafana:
1.  Retrieve the password again: `task password:grafana`.
2.  Note that the default username is always `admin`.

---

## 📈 Observability Issues

### Loki: Transitional Mode (SimpleScalable<->Distributed)
**Symptom:** `helm upgrade` fails with `You have more than zero replicas configured for scalable targets... change the deploymentMode to the transitional 'SimpleScalable<->Distributed' mode`.
**Cause:** In Loki v15+, enabling "Distributed" components like the **Index Gateway** while using "SimpleScalable" targets (Read/Write/Backend) requires an explicit transitional mode.
**Resolution:** Set `deploymentMode: 'SimpleScalable<->Distributed'` in `values-loki.yaml`.

### Loki: Index Gateway "must supply both Access Key ID and Secret Access Key"
**Symptom:** `loki-index-gateway` pods are in `CrashLoopBackOff`. Logs show `must supply both an Access Key ID and Secret Access Key or neither`.
**Cause:** The Index Gateway is a separate deployment component and does not automatically inherit the `extraEnv` defined under the main `loki:` block.
**Resolution:** Add the `extraEnv` block explicitly to the top-level `indexGateway:` section in `values-loki.yaml`.

### Loki: "No data found in 'loki' bucket" (Verification Warning)
**Symptom:** `task verify:loki` reports `WARNING: - No data found in 'loki' bucket`.
**Cause:** Loki buffers logs in memory and only flushes to S3 every 30m-2h by default. In a dev environment, the verification script finishes before the flush occurs.
**Resolution:** Ensure `deployment/dev/values-loki.yaml` has aggressive ingester settings (`chunk_idle_period: 30s`).

### Loki 502 Bad Gateway / OOMKilled
**Symptom:** Grafana shows a `502 Bad Gateway` when querying Loki logs.
**Cause:** Default memory limits (128Mi) are too low for query processing in SimpleScalable mode.
**Resolution:** Increase memory limits for `read` and `write` pods in `values-loki.yaml`.

### Grafana cannot reach Loki (Connection Refused)
**Symptom:** Grafana logs show `dial tcp ...:80: connect: connection refused` when querying Loki.
**Cause:** The `loki-gateway` pod may be stuck in `Pending` due to pod anti-affinity rules on a single-node cluster.
**Resolution:** Verify the `loki-gateway` pod is `Running`. If `Pending`, manually delete old gateway pods to break anti-affinity deadlocks.

### Tempo: "Field not found" Schema Errors
**Symptom:** Pods crash with `failed parsing config... field not found in type ...`.
**Cause:** Tempo 2.x enforces a strict configuration schema. Legacy fields have been removed or relocated.
**Resolution:** Check pod logs to identify the exact field causing the unmarshal error and remove it using the latest [Tempo Config Reference](https://grafana.com/docs/tempo/latest/configuration/).

### Service Graph is Empty
**Symptom:** The Service Graph tab in Tempo is empty.
**Resolution:**
1.  Verify Tempo `remote_write` is pointing to Prometheus on port **80**.
2.  Check for WAL errors in Tempo logs.
3.  Ensure `remoteWriteReceiver: true` is enabled in Prometheus `values-prometheus.yaml`.

### Trace-to-Log: No results found (Zero-width time range)
**Symptom:** In Tempo, clicking "Logs for this span" results in "No results found" even though the query is correct.
**Cause:** The logs search time range exactly matches the span start/end times.
**Resolution:** In `deployment/datasources.yaml`, set `spanStartTimeShift` to `-5s` and `spanEndTimeShift` to `5s` to expand the search window.

---

## ☕ Application Issues

### Application Crashes during Startup
**Symptom:** Pod status is `CrashLoopBackOff` or `Running` but never `Ready`.
**Cause:** The application initialization (Spring + Debezium + Jolokia) requires significant headroom and time.
**Resolution:**
1.  Ensure the memory limit is at least **1Gi** in `deployment/dev/app.yaml`.
2.  Ensure `initialDelaySeconds` for liveness/readiness probes is at least **120s**.

### Jolokia 404/401 Errors
**Symptom:** `http://localhost:8080/actuator/jolokia` returns 404 or 401.
**Resolution:**
1.  **404:** Ensure `jolokia-support-spring` is in `pom.xml`.
2.  **401:** Jolokia is protected by Spring Security. Use Basic Auth with `user:password`.

---

## 🍃 MongoDB & Debezium Issues

### MongoDB Pods Stuck in "Pending" (Insufficient memory)
**Symptom:** `kubectl get pods` shows `mongodb-0` as `Pending`. `kubectl describe pod` shows `Insufficient memory`.
**Resolution:** Lower the `requests` and `limits` in `deployment/dev/values-mongodb.yaml` and ensure `global.resourcesPreset` is set to `"none"`.

### MongoDB Pods "OOMKilled"
**Symptom:** Pod status is `CrashLoopBackOff`, and `describe pod` shows `Reason: OOMKilled`.
**Cause:** MongoDB 8.x requires at least 256MB-512MB of RAM to start.
**Resolution:** Increase the `limits.memory` in `values-mongodb.yaml` to at least `512Mi`.

### Debezium Not Capturing Changes
**Symptom:** Logs show `After applying the include/exclude list filters, no changes will be captured`.
**Cause:** Debezium requires the database and collection to exist *before* the connector initializes.
**Resolution:** Bootstrap the database using `db.getSiblingDB('kx').createCollection('pokemon')`.
