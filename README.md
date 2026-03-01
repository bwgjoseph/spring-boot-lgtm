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
- **Correlation-ready Logs:** Log patterns configured for `traceId` and `spanId` injection, compatible with Loki.

## 🏗️ Architecture

- **Metrics:** Scraped by Alloy from `/actuator/prometheus` (Pull model).
- **Logs:** Collected by Alloy from pod stdout/stderr with Kubernetes metadata enrichment (Pull model).
- **Traces:** Pushed by the application to Alloy via OTLP/gRPC (Push model).
- **Alloy:** Acts as the "Brain," processing traces (sampling, batching, service graphs) before forwarding to Tempo and Loki.

## 🛠️ Tech Stack & Versions

| Component | Role | Helm Chart | Version |
|-----------|------|------------|---------|
| **Spring Boot 3.5** | Application | - | - |
| **Grafana Alloy** | Collector/Gateway | `grafana/alloy` | `0.6.1` |
| **Grafana** | Visualization | `grafana-community/grafana` | `8.5.12` |
| **Loki** | Log Storage | `grafana/loki` | `6.16.0` |
| **Tempo** | Trace Storage | `grafana-community/tempo` | `1.10.15` |
| **Prometheus** | Metrics Storage | `prometheus-community/prometheus` | `25.27.0` |


## 🏁 Getting Started

Detailed installation, upgrade, and port-forwarding instructions can be found in the deployment guide:

👉 **[Read the Installation & Upgrade Guide (INSTALL.md)](./deployment/INSTALL.md)**

### Quick Build
```bash
# Build the app container using Jib
./mvnw clean compile jib:dockerBuild
```

### Quick Deploy
```bash
# Deploy/Upgrade the application
kubectl apply -f deployment/deployment.yaml

# Deploy/Upgrade Alloy configuration
helm upgrade --install alloy grafana/alloy -n monitoring -f deployment/values-alloy.yaml
```

## 🔍 Exploration

1. **Pokemon API:** Use the `/pokemon/{id}` endpoint to generate traces.
2. **Grafana Explore:** 
   - Search for `http_server_requests_seconds_bucket` to see **Exemplars** (clickable dots linking to traces).
   - Use the **Service Graph** tab in Tempo to see the automated architecture map.
   - Query Loki logs to see the `[service-name,traceId,spanId]` correlation pattern.
