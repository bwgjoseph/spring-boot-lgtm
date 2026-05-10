# Smoke Test Plan: Grafana Tempo

## 1. Deployment Validation
- **Pod Status:** `kubectl rollout status statefulset/tempo -n monitoring --timeout=60s`
- **Pod Health:** `kubectl get pods -l app=tempo -n monitoring`

## 2. Configuration Audit
- **Persistence:** Verify SSD WAL mount: `kubectl exec -n monitoring -l app=tempo -- df -h /var/tempo/wal`
- **Search Logic:** Verify `search_finished_blocks` is enabled in config: `kubectl get cm tempo -n monitoring -o yaml | grep search_finished_blocks`

## 3. Smoke-Test Traffic
- **Synthetic Trace:** Inject a trace using `./verification/trigger-api.ps1`.

## 4. Backend/Storage Audit
- **MinIO Integrity:** Use `mc ls minio/tempo` to verify recent trace blocks exist.
- **Service Graph:** Query Prometheus for `traces_service_graph_request_total`.
