# GEMINI.md - Project Instructions

## Project Overview
This project is a **Spring Boot 3.5 (Java 25) Observability Sandbox** designed to demonstrate the **Grafana LGTM stack** (Loki, Grafana, Tempo, Mimir/Prometheus) using **Grafana Alloy** as the central collector. It follows a "Scrape & Push" architecture optimized for High Availability (HA).

### Tech Stack
- **Framework:** Spring Boot 3.5.x
- **Language:** Java 25
- **Observability:** 
  - **Micrometer Tracing (OTEL Bridge):** OpenTelemetry SDK version 1.59.0.
  - **Micrometer Observation API:** For manual instrumentation and context propagation.
  - **Micrometer Prometheus Registry:** For metric scraping via `/actuator/prometheus`.
  - **Jolokia support-spring:** For raw JMX access via `/actuator/jolokia`.
  - **Grafana Alloy (1.8.1):** Features `loki.process` metadata extraction and `otelcol.processor.tail_sampling`.
- **Storage:** 
  - **Loki (15.0.1):** Log Storage (SimpleScalable mode with Index Gateway).
  - **Tempo (3.0.6):** Trace Storage and Service Graph generation (tempo-distributed / Tempo 3.x microservices mode).
  - **Redpanda (26.2.1):** High-performance Kafka-compatible streaming log for Tempo trace ingestion.
  - **Prometheus (29.7.0):** Metrics scraper and Alerting engine.
  - **Mimir (6.0.6):** Metrics Long-term Storage (Monolithic HA mode).
  - **MinIO (5.4.0):** Internal Object Storage for Loki, Tempo, and Mimir.
  - **MongoDB (18.6.31):** 3-node ReplicaSet instrumented for CDC via Debezium.
- **Build & Deployment:** 
  - **Maven:** Build system with BOM management.
  - **Jib:** Container image building (`jib-maven-plugin`).
  - **Helm:** Kubernetes deployment orchestration.
  - **Taskfile:** Automation of infrastructure and application lifecycles.

## Development Environment
- **Operating System:** Windows
- **Shell:** PowerShell (pwsh)
- **Docker Desktop:** Special configurations applied for hardware limits. See [DOCKER_DESKTOP.md](./DOCKER_DESKTOP.md).
- **Command Syntax:** Always use PowerShell syntax for shell commands. 
  - Use `;` instead of `&&` for command chaining.
  - Use `$env:VAR = "val"` for environment variables.
  - Use `.\mvnw` instead of `./mvnw`.

## Building and Running
The project uses `Taskfile` to simplify complex operations across environments (`dev`, `prod-local`).

| Category | Task | Description |
| :--- | :--- | :--- |
| **Setup** | `task all` | Builds the app and deploys the entire LGTM stack + App. |
| **Infrastructure** | `task infra` | Deploys Prometheus, Loki, Tempo, Grafana, and Alloy. |
| **Application** | `task app:load` | Builds and sideloads the image into local K8s. |
| **Application** | `task app:deploy` | Deploys the application to the `monitoring` namespace. |
| **Verification** | `task verify` | Runs automated health checks for all components. |
| **E2E Test** | `task test:e2e` | Runs deterministic data-pipeline verification. |
| **Surgical Swap** | `task swap:loki` | Upgrades Loki from Dev to Prod-Local HA for validation. |
| **Surgical Swap** | `task swap:tempo`| Upgrades Tempo from Dev to Prod-Local HA for validation. |
| **Surgical Swap** | `task swap:alloy`| Upgrades Alloy from Dev to Prod-Local HA for validation. |
| **Surgical Swap** | `task swap:mimir`| Swaps Prometheus for Mimir Monolithic HA. |
| **Config Sync** | `task sync:loki` | Promotes verified `prod-local` architectural keys to `prod`. |
| **Utilities** | `task pf:redpanda`| Port-forwards Redpanda Console UI (http://localhost:8081). |
| **Utilities** | `task pf:all` | Forwards all UIs (Grafana, Prom, Redpanda, Alloy, App). |
| **Cleanup** | `task clean` | Wipes all ConfigMaps and the monitoring namespace. |

## Development Conventions

### Instrumentation
- **Micrometer Observation API:** Use `@Observed` annotation or `Observation.createNotStarted(...)`.
- **Security Correlation:** `SecurityObservationHandler` extracts `userId` and injects it into baggage.
- **MDC Correlation:** Trace IDs and Span IDs are included in logs via the pattern: `[${spring.application.name:},%X{traceId:-},%X{spanId:-},%X{userId:-}]`.
- **Trace-to-Log Correlation:** App logs use camelCase (`traceId`); Grafana Alloy maps these to snake_case (`trace_id`) in Loki Structured Metadata.

### Observability Patterns
- **Exemplars:** Enabled via `management.prometheus.metrics.export.exemplars.enabled: true`.
- **Baggage Propagation:** Custom attributes travel via W3C Baggage headers.
- **JMX Bridge:** Debezium Embedded metrics are bridged to Micrometer via `DebeziumMetricsBinder`.
- **K8s Enrichment:** Grafana Alloy enriches traces with Pod/Node metadata based on source IP.

## Key Files
- `Taskfile.yml`: Central task runner for all operations.
- `ARCHITECTURE.md`: High-level roadmap and logical data flow diagrams.
- `RESOURCES.md`: Detailed CPU and Memory allocation for all deployments.
- `IMAGES.md`: Software Bill of Materials (SBOM) and container image inventory.
- `TROUBLESHOOT.md`: Known issues and resolutions for the local HA stack.
- `CUSTOM_ATTRIBUTES.md`: Documentation for cross-stack attribute mapping.
