# 📡 Synthetic Observability Generation with telemetrygen

`telemetrygen` is an official OpenTelemetry test utility (part of `opentelemetry-collector-contrib`) used to generate deterministic synthetic traces, metrics, and logs via the OpenTelemetry Protocol (OTLP).

---

## 🎯 Why Use `telemetrygen`?

1. **Independent Pipeline Validation**: Validates Grafana Alloy, Tempo, Loki, and Prometheus pipelines without deploying or executing business logic in the Spring Boot application.
2. **Deterministic Stress & Sampling Testing**: Generates controlled bursts of traces (e.g., 500 traces/sec) to verify Alloy tail-sampling (`otelcol.processor.tail_sampling`), batching, and Tempo live-store throughput.
3. **Trace-to-Log & Attribute Verification**: Injects specific baggage and span attributes (e.g., `service.name=telemetrygen`, `test.id=xyz`) to verify Grafana search indexes and cross-correlation.

---

## 🚀 Running via Taskfile

We provide pre-wired automation in `Taskfile.yml`:

```powershell
# 1. Run trace generation and verify Tempo API automatically
task test:telemetrygen:traces

# 2. Run log generation and verify Loki API automatically
task test:telemetrygen:logs

# 3. Run metric generation and verify Prometheus API automatically
task test:telemetrygen:metrics

# 4. Run all three signals sequentially with full end-to-end report
task test:telemetrygen
```

---

## 🛠️ Manual CLI / Ad-hoc Kubernetes Execution

If you wish to test custom rates or run directly via `kubectl`:

### Traces
```powershell
kubectl run telemetrygen-traces -n monitoring --rm -i --tty \
  --image=ghcr.io/open-telemetry/opentelemetry-collector-contrib/telemetrygen:v0.165.0 --restart=Never -- \
  traces --otlp-endpoint=alloy.monitoring.svc.cluster.local:4317 --otlp-insecure=true --traces=100 --rate=10 --service=telemetrygen
```

### Logs
```powershell
kubectl run telemetrygen-logs -n monitoring --rm -i --tty \
  --image=ghcr.io/open-telemetry/opentelemetry-collector-contrib/telemetrygen:v0.165.0 --restart=Never -- \
  logs --otlp-endpoint=alloy.monitoring.svc.cluster.local:4317 --otlp-insecure=true --logs=100 --rate=10 --service=telemetrygen
```

### Metrics
```powershell
kubectl run telemetrygen-metrics -n monitoring --rm -i --tty \
  --image=ghcr.io/open-telemetry/opentelemetry-collector-contrib/telemetrygen:v0.165.0 --restart=Never -- \
  metrics --otlp-endpoint=alloy.monitoring.svc.cluster.local:4317 --otlp-insecure=true --metrics=100 --rate=10 --service=telemetrygen
```

---

## 🔍 Grafana UI Verification

1. **Tempo**: Navigate to **Explore -> Tempo**, select **Search**, and filter by:
   - `Service Name`: `telemetrygen`
   - Spans will appear instantly showing the synthetic duration and generated attributes.
2. **Loki**: Navigate to **Explore -> Loki**, enter LogQL:
   ```logql
   {service_name="telemetrygen"}
   ```
3. **Prometheus**: Navigate to **Explore -> Prometheus**, enter PromQL:
   ```promql
   gen_traces_total or rate(telemetrygen_requests_total[5m])
   ```
