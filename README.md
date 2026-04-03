# Spring Boot LGTM Observability Sandbox

This project is a production-ready template and sandbox for implementing the **Grafana LGTM stack** (Loki, Grafana, Tempo, Mimir/Prometheus) with **Grafana Alloy** as the central observability gateway.

It demonstrates a "Scrape & Push" architecture using Spring Boot 3.5+, Micrometer Tracing (OTEL Bridge), and W3C Trace Context.

👉 **[Detailed Feature Guide (feature.md)](./feature.md)**
👉 **[Troubleshooting Guide (TROUBLESHOOT.md)](./TROUBLESHOOT.md)**

## 🚀 Key Features (Day 2 Ready)

This sandbox goes beyond basic connectivity to include advanced observability patterns:

- **Exemplars:** Direct correlation from metric spikes in Prometheus to specific traces in Tempo.
- **Tail-based Sampling:** Intelligent trace reduction (currently 100% for testing, configurable to keep 100% errors and X% success).
- **Service Graph:** Automated system-wide dependency mapping generated natively by Tempo.
- **Node Graph:** Visual request-level flowchart for deep-diving into complex traces.
- **Manual Instrumentation:** Examples of using the Micrometer `Observation` API for business-specific metrics and traces.
- **Self-Monitoring:** Integrated scraping of Alloy's own health and performance metrics.
- **Correlation-ready Logs:** Robust log patterns configured to capture both `traceId` and `trace_id` variants, compatible with Loki.

## 🏗️ Architecture

- **Metrics:** Scraped by Alloy from `/actuator/prometheus` (Pull model).
- **Logs:** Collected by Alloy from pod stdout/stderr with Kubernetes metadata enrichment (Pull model).
- **Traces:** Pushed by the application to Alloy via OTLP/gRPC (Push model).
- **Correlation:** Data sources use standardized UIDs (`prometheus`, `loki`, `tempo`) to enable seamless cross-linking (Metric -> Trace -> Log).
- **Alloy:** Acts as the entry point, processing traces (sampling, batching) and extracting structured metadata before forwarding to Tempo and Loki.
- **Service Graph:** Generated natively by Tempo's internal `metricsGenerator` and pushed to Prometheus.
- **Scalability:** Loki runs in **Simple Scalable Mode** (separating read/write paths). Tempo runs as a Single Binary for simplicity.
- **Storage:** A local **MinIO** instance provides S3-compatible shared storage for **Loki**, while **Tempo** uses local Persistent Volumes (PVC) for simplicity and stability in this sandbox environment.

## 🛠️ Tech Stack & Versions

| Component | Role | Helm Chart | Version |
|-----------|------|------------|---------|
| **Spring Boot 3.5** | Application | - | - |
| **Grafana Alloy** | Collector/Gateway | `grafana/alloy` | `1.6.1` |
| **Grafana** | Visualization | `grafana-community/grafana` | `11.3.0` |
| **Loki** | Log Storage | `grafana-community/loki` | `9.3.4` |
| **Tempo** | Trace Storage | `grafana-community/tempo` | `2.0.0` |
| **Prometheus** | Metrics Storage | `prometheus-community/prometheus` | `28.13.0` |
| **MinIO** | Object Storage | `minio/minio` | `5.4.0` |


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

## 🐳 Docker Desktop Notes

This project contains specialized configurations to handle hardware and mount propagation limits in Docker Desktop. 

👉 **[Read the Docker Desktop Configuration Guide (DOCKER_DESKTOP.md)](./DOCKER_DESKTOP.md)**

## 🔍 Exploration

1. **Generate Traces:** Call the Pokemon API to see the distributed tracing in action.
   ```bash
   curl http://localhost:8080/pokemon/1
   ```
2. **Grafana Explore:** 
   - Search for `http_server_requests_seconds_bucket` to see **Exemplars** (clickable dots linking to traces).
   - Use the **Service Graph** tab in Tempo to see the automated architecture map.
   - Query Loki logs to see the `[service-name,traceId,spanId]` correlation pattern.
3. **Cluster Health:**
   - Search for the **"Kubernetes / Compute Resources / Cluster"** dashboard to see overall CPU/Memory usage.
   - Use the **"Namespace (Pods)"** dashboard to drill down into the Spring Boot app's resource consumption.

## ⚙️ Production Tuning

When moving from this sandbox to a real production environment, consider the following adjustments:

### Service Graph (values-tempo.yaml)
The current settings are optimized for immediate feedback in a low-traffic sandbox. In production, Tempo's `metricsGenerator` ring should be backed by a persistent store like Etcd or memberlist.

### Tail-based Sampling (values-alloy.yaml)
The sandbox captures 100% of traces. In production, you should dial back the `probabilistic` sampling percentage (e.g., `1%` to `10%`) for successful requests while keeping `sample-errors` at 100%.

