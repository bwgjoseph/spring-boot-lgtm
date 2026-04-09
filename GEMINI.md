# GEMINI.md - Project Instructions

## Project Overview
This project is a **Spring Boot 3.5 (Java 25) Observability Sandbox** designed to demonstrate the **Grafana LGTM stack** (Loki, Grafana, Tempo, Mimir/Prometheus) using **Grafana Alloy** as the central collector. It follows a "Scrape & Push" architecture.

### Tech Stack
- **Framework:** Spring Boot 3.5.x
- **Language:** Java 25
- **Observability:** 
  - **Micrometer Tracing (OTEL Bridge):** For traces (OpenTelemetry SDK version 1.59.0).
  - **Micrometer Observation API:** For manual instrumentation and context propagation.
  - **Micrometer Prometheus Registry:** For metric scraping via `/actuator/prometheus`.
  - **Grafana Alloy:** Collector/Gateway (`1.6.1`). Features `loki.process` for structured metadata extraction and `otelcol.processor.k8sattributes` for span enrichment.
- **Storage:** 
  - **Loki:** Log Storage (`6.53.0`, Simple Scalable mode).
  - **Tempo:** Trace Storage and Service Graph generation (`2.0.0`).
  - **Prometheus:** Metrics Storage (`28.13.0`, scraped from Alloy).
  - **MinIO:** Internal Object Storage (`5.4.0`).
  - **MongoDB:** Enabled and instrumented for Change Data Capture (CDC) via Debezium.
- **Build & Deployment:** 
  - **Maven:** Build system with BOM management for OTEL and Debezium.
  - **Jib:** Builds Docker images (`jib-maven-plugin`).
  - **Helm:** Kubernetes deployments (`deployment/`).
  - **Taskfile:** Orchestration for infrastructure and app deployment.

## Development Environment
- **Operating System:** Windows
- **Shell:** PowerShell (pwsh)
- **Docker Desktop:** Special configurations applied for hardware limits. See [DOCKER_DESKTOP.md](./DOCKER_DESKTOP.md).
- **Command Syntax:** Always use PowerShell syntax for shell commands. 
  - Use `;` instead of `&&` for command chaining.
  - Use `$env:VAR = "val"` for environment variables.
  - Use `.\mvnw` instead of `./mvnw`.

## Building and Running
The project uses `Taskfile` to simplify complex operations.

| Task | Command | Description |
|------|---------|-------------|
| **Full Setup** | `task all` | Builds the app and deploys the entire LGTM stack + App to K8s. |
| **Infra Only** | `task infra` | Deploys Prometheus, Loki, Tempo, Grafana, Alertmanager, and Alloy. |
| **App Build** | `task app:build` | Builds the Spring Boot app and Docker image using Jib. |
| **App Deploy** | `task app:deploy` | Deploys the application to the `monitoring` namespace. |
| **Dashboards** | `task dashboards` | Syncs local dashboards from `deployment/dashboards/` to K8s. |
| **Port Forward** | `task port-forward` | Forwards Grafana (3000), Prometheus (9090), Alloy (12345), and App (8080). |
| **Get Password** | `task password` | Retrieves the Grafana admin password. |

## Development Conventions

### Instrumentation
- **Micrometer Observation API:** Use `@Observed` annotation or `Observation.createNotStarted(...)` for manual instrumentation.
- **Security Correlation:** `SecurityObservationHandler` automatically extracts `userId` from Spring Security and injects it into observations and baggage.
- **MDC Correlation:** Trace IDs and Span IDs are included in logs via the pattern defined in `application.yaml`: `[${spring.application.name:},%X{traceId:-},%X{spanId:-},%X{userId:-}]`.
- **Trace-to-Log Correlation:** 
  - App logs use camelCase (`traceId`, `spanId`).
  - Grafana Alloy extracts these via regex and maps them to snake_case (`trace_id`, `span_id`) in Loki Structured Metadata.

### Observability Patterns
- **Exemplars:** Enabled via `management.prometheus.metrics.export.exemplars.enabled: true`. This allows linking Prometheus metric spikes directly to Tempo traces in Grafana.
- **Baggage Propagation:** Custom attributes like `userId` travel across service boundaries using W3C Baggage.
- **JMX Bridge:** Debezium Embedded metrics are bridged from JMX MBeans to Micrometer Gauges via a custom `MeterBinder` (`DebeziumMetricsBinder`).
- **K8s Enrichment:** Grafana Alloy automatically enriches traces with Pod and Node metadata based on the source IP.

### Kubernetes Deployment
- All components are deployed to the `monitoring` namespace.
- Deployment manifests and Helm values are located in the `deployment/` directory.

## Key Files
- `Taskfile.yml`: Central task runner for all operations.
- `pom.xml`: Maven configuration with version alignment for OTEL (1.59.0) and MongoDB (5.6.2).
- `src/main/resources/application.yaml`: Spring Boot application configuration.
- `deployment/values-alloy.yaml`: Configuration for Grafana Alloy enrichment and log processing.
- `JMX_METRICS.md`: Documentation for Debezium monitoring.
- `CUSTOM_ATTRIBUTES.md`: Documentation for cross-stack attribute mapping.
