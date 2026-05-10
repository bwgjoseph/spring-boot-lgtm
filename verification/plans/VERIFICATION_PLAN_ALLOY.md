# Smoke Test Plan: Grafana Alloy

## 1. Deployment Validation
- **Pod Status:** `kubectl rollout status daemonset/alloy -n monitoring --timeout=60s`
- **Pod Health:** `kubectl get pods -l app.kubernetes.io/name=alloy -n monitoring`

## 2. Configuration Audit
- **Node Locality:** Verify the `${HOSTNAME}` relabel rule: 
  `kubectl exec -n monitoring -l app.kubernetes.io/name=alloy -- grep '${HOSTNAME}' /var/lib/alloy/config.alloy`
- **RBAC:** Verify ClusterRole binding via `kubectl auth can-i list pods --as=system:serviceaccount:monitoring:alloy -n monitoring`.

## 3. Smoke-Test Traffic
- **Synthetic OTLP:** Inject a trace using `./verification/trigger-api.ps1`.

## 4. Backend/Storage Audit
- **Check Dropped Spans:** `kubectl exec -n monitoring -l app.kubernetes.io/name=alloy -- curl -s localhost:12345/metrics | grep otelcol_processor_batch_dropped_spans`
- **MinIO Integrity:** Use `mc ls minio/tempo` to verify recent trace blocks exist.
