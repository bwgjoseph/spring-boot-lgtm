# GEMINI.md - Project Instructions

## Project Overview
This project is a **Spring Boot 3.5 (Java 25) Observability Sandbox** designed to demonstrate the **Grafana LGTM stack** (Loki, Grafana, Tempo, Mimir/Prometheus) using **Grafana Alloy** as the central collector. It follows a "Scrape & Push" architecture.

### Tech Stack
- **Framework:** Spring Boot 3.5.x
- **Language:** Java 25
- **Observability:** 
  - **Micrometer Tracing (OTEL Bridge):** For traces.
  - **Micrometer Observation API:** For manual instrumentation (e.g., `PokemonAPI.java`).
  - **Micrometer Prometheus Registry:** For metric scraping via `/actuator/prometheus`.
  - **Grafana Alloy:** Collector/Gateway (`1.6.1`, configured via `values-alloy.yaml`).
- **Storage:** 
  - **Loki:** Log Storage (`6.53.0`, scraped from stdout/stderr).
  - **Tempo:** Trace Storage (`2.0.0`, pushed via OTLP/gRPC).
  - **Prometheus:** Metrics Storage (`28.13.0`, scraped from Alloy).
  - **MongoDB:** (Currently disabled in `application.yaml`).
- **Build & Deployment:** 
  - **Maven:** Build system.
  - **Jib:** Builds Docker images (`jib-maven-plugin`).
  - **Helm:** Kubernetes deployments (`deployment/`).
  - **Taskfile:** Orchestration for infrastructure and app deployment.
## Development Environment
- **Operating System:** Windows
- **Shell:** PowerShell (pwsh)
- **Docker Desktop:** Special configurations applied for hardware limits. See [DOCKER_DESKTOP.md](./DOCKER_DESKTOP.md).
- **Command Syntax:** Always use PowerShell syntax for shell commands. 
...
  - Use `;` instead of `&&` for command chaining.
  - Use `$env:VAR = "val"` for environment variables.
  - Use `.\mvnw` instead of `./mvnw`.

## Building and Running
The project uses `Taskfile` to simplify complex operations.

| Task | Command | Description |
|------|---------|-------------|
| **Full Setup** | `task all` | Builds the app and deploys the entire LGTM stack + App to K8s. |
| **Infra Only** | `task infra` | Deploys Prometheus, Loki, Tempo, Grafana, and Alloy. |
| **App Build** | `task app:build` | Builds the Spring Boot app and Docker image using Jib. |
| **App Deploy** | `task app:deploy` | Deploys the application to the `monitoring` namespace. |
| **Dashboards** | `task dashboards` | Syncs local dashboards from `deployment/dashboards/` to K8s. |
| **Port Forward** | `task port-forward` | Forwards Grafana (3000), Prometheus (9090), Alloy (12345), and App (8080). |
| **Get Password** | `task password` | Retrieves the Grafana admin password. |

### Manual Maven Commands
- **Compile:** `./mvnw clean compile`
- **Build Image:** `./mvnw clean compile jib:dockerBuild`
- **Run Tests:** `./mvnw test`

## Development Conventions

### Instrumentation
- **Micrometer Observation API:** Use `Observation.createNotStarted(...)` for manual instrumentation of business logic. Refer to `PokemonAPI.java` for an example.
- **MDC Correlation:** Trace IDs and Span IDs are automatically included in logs via the pattern defined in `application.yaml`: `[${spring.application.name:},%X{traceId:-},%X{spanId:-}]`.

### Observability Patterns
- **Exemplars:** Enabled via `management.prometheus.metrics.export.exemplars.enabled: true`. This allows linking Prometheus metric spikes directly to Tempo traces in Grafana.
- **Trace Propagation:** Uses the **W3C Trace Context** standard.
- **Sampling:** 100% trace sampling is enabled in the app (`management.tracing.sampling.probability: 1.0`). Production-level tail-based sampling is handled in Alloy's configuration.

### Kubernetes Deployment
- All components are deployed to the `monitoring` namespace.
- Deployment manifests and Helm values are located in the `deployment/` directory.

## Key Files
- `Taskfile.yml`: Central task runner for all operations.
- `pom.xml`: Maven configuration and dependencies.
- `src/main/resources/application.yaml`: Spring Boot application configuration.
- `deployment/values-alloy.yaml`: Configuration for Grafana Alloy (the "brain" of the stack).
- `src/main/java/com/bwgjoseph/observability/api/PokemonAPI.java`: Example of manual Micrometer instrumentation.
