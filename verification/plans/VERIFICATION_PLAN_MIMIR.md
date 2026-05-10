# Smoke Test Plan: Grafana Mimir

## 1. Deployment Validation
- **Pod Status:** `kubectl rollout status statefulset/mimir -n monitoring --timeout=60s`
- **Pod Health:** `kubectl get pods -l app=mimir -n monitoring`

## 2. Configuration Audit
- **Retention:** Verify 90-day retention in config: `kubectl get cm mimir-config -n monitoring -o yaml | grep block_retention`
- **Persistence:** Verify S3 backend is configured.

## 3. Smoke-Test Traffic
- **Synthetic Metric:** Ensure Prometheus is sending metrics to Mimir via Remote Write.

## 4. Backend/Storage Audit
- **MinIO Integrity:** Use `mc ls minio/mimir` to verify metric block creation.
- **Query Test:** Run a test query against Mimir endpoint to verify data retrieval.
