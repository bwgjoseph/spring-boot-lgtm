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

### Tempo: "error querying live-stores in Querier.SearchTags: error finding partition ring replicas: empty ring"
**Symptom:** Grafana Trace search or TraceQL query fails with `error querying live-stores in Querier.SearchTags: error finding partition ring replicas: empty ring`.
**Cause:** In Tempo 3.x microservices (`tempo-distributed`), the `querier` attempts to query recent in-memory trace spans from `liveStore` pods via the `live-store` hash ring. When `liveStore` pods are `Pending` (or failing due to memory constraints on single-node local clusters), the `live-store` ring has 0 active replicas.
**Resolution:**
- **Development (`dev`):** Set `liveStore.enabled: false` in `deployment/dev/values-tempo.yaml`. In dev mode, `blockBuilder` consumes trace streams from Redpanda Kafka (`tempo-traces`) and flushes blocks straight to MinIO S3 storage, while `querier` reads blocks from S3. Disabling `liveStore` in dev eliminates the live-store ring lookup, frees node RAM, and resolves the error.
- **Production (`prod-local` / `prod`):** Ensure sufficient cluster RAM is allocated so `tempo-live-store` pods reach `Running` and `Ready` status.

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

## 🔴 Redpanda Issues

### Redpanda: Helm Schema Error — `additional properties 'redpanda' not allowed`
**Symptom:** `helm upgrade --install redpanda ... --version 26.2.1` fails with:
```
Error: values don't meet the specifications of the schema(s) in the following chart(s):
redpanda:
- at '/config': additional properties 'redpanda' not allowed
```
**Cause:** In Redpanda chart `26.2.1`, the cluster configuration structure was renamed. In older chart versions (5.x), cluster properties were under `config.redpanda`. In `26.x`, they moved to `config.cluster`.
**Resolution:** Update your values file:
```yaml
# ❌ Old schema (chart 5.x)
config:
  redpanda:
    auto_create_topics_enabled: true

# ✅ New schema (chart 26.x)
config:
  cluster:
    auto_create_topics_enabled: true
```

### Redpanda: `redpanda-0` CrashLoopBackOff — `insufficient physical memory`
**Symptom:** `redpanda-0` crashes repeatedly. Logs show:
```
Could not initialize seastar: std::runtime_error (insufficient physical memory: needed 858783744 available 838860800)
```
**Cause:** Redpanda's Seastar runtime requires `--memory` (80% of container limit) plus `--reserve-memory`. With a `1Gi` container limit, only ~800MB is physically available after OS overhead, but Seastar needs ~858MB minimum. This is a hard failure, not an OOMKill.
**Resolution:** Set the container limit to `2Gi` and explicitly pin Redpanda's internal memory values:
```yaml
resources:
  memory:
    container:
      max: 2Gi
    redpanda:
      memory: 1536M
      reserveMemory: 200M
```

### Redpanda: `redpanda-configuration` Job keeps failing — `Bad Request`
**Symptom:** Multiple `redpanda-configuration-*` pods appear in `Error` state. Logs show:
```
request PUT http://redpanda-0....:9644/v1/cluster_config failed: Bad Request
```
With API response: `{"disallowed": "developer_mode"}`.
**Cause:** `developer_mode` is a **node-level bootstrap property** (set via `redpanda.yaml` at startup), not a cluster configuration property. The chart's post-install Job uses the Admin API `/v1/cluster_config` to push `config.cluster` settings, and the API explicitly rejects `developer_mode`.
**Resolution:** Remove `developer_mode` from `config.cluster`. The chart automatically handles overprovisioning by injecting `--overprovisioned` at startup when `resources.cpu.cores < 1`:
```yaml
# ❌ Wrong — causes 400 Bad Request
config:
  cluster:
    developer_mode: true

# ✅ Correct — just omit it
config:
  cluster:
    auto_create_topics_enabled: true
```

### Redpanda Console: Pulling from `docker.redpanda.com` instead of Docker Hub
**Symptom:** The `redpanda-console` deployment pulls `docker.redpanda.com/redpandadata/console:vX.Y.Z` instead of Docker Hub.
**Cause:** The Redpanda chart uses a separate `image.registry` key for the embedded Console sub-chart. Setting `console.image.repository` alone does not override the registry — the registry prefix must be set explicitly.
**Resolution:**
```yaml
console:
  enabled: true
  image:
    registry: docker.io          # ← must be set explicitly
    repository: redpandadata/console
```

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
