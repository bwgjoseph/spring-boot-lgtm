# Spring Boot LGTM Observability Sandbox

This project is a production-ready template and sandbox for implementing the **Grafana LGTM stack** (Loki, Grafana, Tempo, Mimir/Prometheus) with **Grafana Alloy** as the central observability gateway.

It demonstrates a "Scrape & Push" architecture using Spring Boot 3.5+, Micrometer Tracing (OTEL Bridge), and W3C Trace Context.

## 🚀 Key Features (Day 2 Ready)

This sandbox goes beyond basic connectivity to include advanced observability patterns:

- **Exemplars:** Direct correlation from metric spikes in Prometheus to specific traces in Tempo.
- **Tail-based Sampling:** Intelligent trace reduction (currently 100% for testing, configurable to keep 100% errors and X% success).
- **Service Graph:** Automated dependency mapping generated from spans via Alloy's `service_graph` connector.
- **Manual Instrumentation:** Examples of using the Micrometer `Observation` API for business-specific metrics and traces.
- **Self-Monitoring:** Integrated scraping of Alloy's own health and performance metrics.
- **Correlation-ready Logs:** Robust log patterns configured to capture both `traceId` and `trace_id` variants, compatible with Loki.

## 🏗️ Architecture

- **Metrics:** Scraped by Alloy from `/actuator/prometheus` (Pull model).
- **Logs:** Collected by Alloy from pod stdout/stderr with Kubernetes metadata enrichment (Pull model).
- **Traces:** Pushed by the application to Alloy via OTLP/gRPC (Push model).
- **Correlation:** Data sources use standardized UIDs (`prometheus`, `loki`, `tempo`) to enable seamless cross-linking (Metric -> Trace -> Log).
- **Alloy:** Acts as the "Brain," processing traces (sampling, batching, service graphs) before forwarding to Tempo and Loki.

## 🛠️ Tech Stack & Versions

| Component | Role | Helm Chart | Version |
|-----------|------|------------|---------|
| **Spring Boot 3.5** | Application | - | - |
| **Grafana Alloy** | Collector/Gateway | `grafana/alloy` | `1.6.0` |
| **Grafana** | Visualization | `grafana-community/grafana` | `11.2.2` |
| **Loki** | Log Storage | `grafana/loki` | `6.53.0` |
| **Tempo** | Trace Storage | `grafana-community/tempo` | `1.26.5` |
| **Prometheus** | Metrics Storage | `prometheus-community/prometheus` | `28.13.0` |


## 🏁 Getting Started

The easiest way to deploy or upgrade the entire stack is using **Taskfile**. This automates the repository setup, namespace creation, and version-locking.

👉 **[Read the Full Installation & Upgrade Guide (INSTALL.md)](./deployment/INSTALL.md)**

### Quick Build & Deploy
```bash
# Install/Upgrade everything (Infra + App)
task all

# Or just the infrastructure (LGTM + Alloy)
task infra
```

## 🔍 Exploration

1. **Generate Traces:** Call the Pokemon API to see the distributed tracing in action.
   ```bash
   curl http://localhost:8080/pokemon/1
   ```
2. **Grafana Explore:** 
   - Search for `http_server_requests_seconds_bucket` to see **Exemplars** (clickable dots linking to traces).
   - Use the **Service Graph** tab in Tempo to see the automated architecture map.
   - Query Loki logs to see the `[service-name,traceId,spanId]` correlation pattern.

## ⚙️ Production Tuning

When moving from this sandbox to a real production environment, consider the following adjustments in `values-alloy.yaml`:

### Service Graph
The current settings are optimized for immediate feedback in a low-traffic sandbox:
- **`store.max_items`**: Increase to `10000+` to handle production request rates.
- **`store.ttl`**: Increase to `2m` to ensure spans from different services have time to be paired.
- **`store_expiration`**: Increase to `3m` to improve the accuracy of the dependency map for long-running traces.

### Tail-based Sampling
The sandbox captures 100% of traces. In production, you should dial back the `probabilistic` sampling percentage (e.g., `1%` to `10%`) for successful requests while keeping `sample-errors` at 100%.

