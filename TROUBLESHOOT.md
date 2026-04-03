# Troubleshooting Guide

This guide documents known issues and resolutions encountered while developing and deploying the Spring Boot LGTM stack.

## 🚀 Image Pull Issues (KinD / Docker Desktop)

### Symptom
The application pod stays in `ImagePullBackOff` or `ErrImagePull` state, even though the image was successfully built locally using `.\mvnw jib:dockerBuild`.

```text
Events:
  Type     Reason     Age                From               Message
  ----     ------     ----               ----               -------
  Warning  Failed     9s (x2 over 25s)   kubelet            spec.containers{app}: Failed to pull image "spring-boot-app:demo": failed to pull and unpack image "docker.io/library/spring-boot-app:demo": failed to resolve reference "docker.io/library/spring-boot-app:demo": pull access denied
```

### Root Cause
If your Kubernetes cluster is running as a **KinD (Kubernetes in Docker)** node (e.g., node name is `desktop-control-plane`), it uses an internal container runtime (`containerd`) that is isolated from your host's Docker daemon. 

Even if you are using the `docker-desktop` context, newer versions of Docker Desktop may run a KinD-like architecture where images built to the host daemon are not automatically available to the Kubernetes nodes.

### Resolution

#### Option A: Using `kind` CLI (Preferred)
If you have the `kind` binary installed, run:
```powershell
kind load docker-image spring-boot-app:demo --name kind
```

#### Option B: Manual Load (If `kind` is missing)
If `kind` is not available, follow these manual steps to bridge the host daemon and the node runtime:

1.  **Save the image to a tarball:**
    ```powershell
    docker save spring-boot-app:demo -o spring-boot-app.tar
    ```

2.  **Copy the tarball into the node container:**
    ```powershell
    docker cp spring-boot-app.tar desktop-control-plane:/spring-boot-app.tar
    ```

3.  **Import the image into the node's `containerd` runtime:**
    ```powershell
    docker exec desktop-control-plane ctr -n k8s.io images import /spring-boot-app.tar
    ```

4.  **Clean up:**
    ```powershell
    rm spring-boot-app.tar
    docker exec desktop-control-plane rm /spring-boot-app.tar
    ```

### Verification
Verify that the image is now visible to the cluster:
```powershell
docker exec desktop-control-plane crictl images | Select-String "spring-boot-app"
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

### Loki 502 Bad Gateway / OOMKilled
**Symptom:** Grafana shows a `502 Bad Gateway` when querying Loki logs. `kubectl get pods -n monitoring` shows `loki-read` or `loki-backend` with a `Terminated: OOMKilled` status.
**Cause:** Default memory limits (128Mi) are too low for query processing.
**Resolution:** Increase memory limits in `deployment/values-loki-scalable.yaml`. Recommended: `512Mi` for `read`/`backend` and `256Mi` for `write`.

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
1.  In `values-grafana.yaml`, ensure `spanStartTimeShift` is set to a negative value (e.g., `-5s`) and `spanEndTimeShift` is set to a positive value (e.g., `5s`).
2.  This expands the search window around the span, increasing the chance of finding correlated logs.

### TraceQL metrics not configured / local-blocks processor not found
...
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

