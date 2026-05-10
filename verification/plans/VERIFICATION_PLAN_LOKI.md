# Smoke Test Plan: Grafana Loki

## 1. Deployment Validation
- **Pod Status:** `kubectl rollout status statefulset/loki-write -n monitoring --timeout=60s`
- **Pod Health:** `kubectl get pods -l app=loki,component=write -n monitoring`

## 2. Configuration Audit
- **Retention:** Verify `retention_period` is set in config: `kubectl get cm loki-config -n monitoring -o yaml | grep retention_period`
- **Compactor:** Verify compactor is active: `kubectl logs -l app=loki,component=backend -n monitoring | grep compactor`

## 3. Smoke-Test Traffic
- **Synthetic Log:** Inject a log line using `./verification/trigger-api.ps1`.

## 4. Backend/Storage Audit
- **MinIO Integrity:** Use `mc ls minio/loki/chunks` to verify new log chunks appear after 10m.
- **Cache Health:** If Memcached is enabled, check connection stats via logs.
