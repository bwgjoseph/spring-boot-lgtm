# AGENT TASK: Migrate Standalone Grafana Alloy to `grafana/k8s-monitoring` Helm Chart

Write down the migration plan in detailed in MIGRATION.md. Ask clarifying question before starting to plan, and propose.

## 1. Context & Objective
You are migrating the cluster telemetry collection layer from a standalone `grafana/alloy` (v1.8.0) chart deployment to the unified `grafana/k8s-monitoring` Helm chart (`grafana/k8s-monitoring`).

Existing storage, application, and visualization backends MUST NOT be reinstalled or modified. The new `k8s-monitoring` chart will act solely as the collection and forwarding layer to the existing backend services.

---

## 2. Explicit Feature Exclusions & Inclusions

### EXCLUSIONS (Must be explicitly disabled in values.yaml):
* **Beyla** (`beyla.enabled: false`) - No eBPF auto-instrumentation required.
* **OpenCost** (`costMetrics.enabled: false` or `opencost.enabled: false`) - No cost calculation metrics.
* **Kepler** (`kepler.enabled: false`) - No energy usage metrics.

---

## 3. Point to existing backend

The move to grafana/k8s-monitoring should ensure that the data is setup to pipe to existing backend such as loki, tempo, prometheus, etc

---

## 4. Validation

Work out a plan to verify and validate everything is working as is, and the integration points are all good after migration.

---

## Key Technical Notes & Watch-outs for the Migration

### 1. Tempo Destination Protocol (No `type: tempo`)
The `k8s-monitoring` chart does **not** have a destination type called `tempo`. Because Tempo natively speaks OpenTelemetry Protocol (OTLP), you must configure the destination using `type: otlp` and set `signals: ["traces"]` pointing to Tempo's gRPC port (`4317`) or HTTP port (`4318`).

### 2. Duplicate `kube-state-metrics` or `node-exporter`
If your current setup already has `kube-state-metrics` or `prometheus-node-exporter` running as standalone Helm releases in the cluster, set `kube-state-metrics.enabled: false` and `prometheus-node-exporter.enabled: false` inside the `values.yaml` to avoid port collisions and duplicate metric scraping.

### 3. Spring Boot 3.5 OTLP Endpoint Target
Spring Boot 3.5 apps emitting OTLP telemetry (via Micrometer / OpenTelemetry Javaagent) should update their `MANAGEMENT_OTLP_TRACING_ENDPOINT` or `OTEL_EXPORTER_OTLP_ENDPOINT` to target the newly created `k8s-monitoring-alloy-receiver` service endpoint on port `4317` (gRPC) or `4318` (HTTP).

### 4. Custom Scraping (MongoDB Exporter / Actuator)
If your previous standalone Alloy River configuration had custom `prometheus.scrape` blocks (such as MongoDB Exporter metrics or custom Spring Boot `/actuator/prometheus` endpoints), pass those extra River blocks into the `extraConfig` parameter in your `values.yaml`.

### 5. Lookout for current alloy configuration
Check and ensure that any custom alloy configuration in the existing setup is being flagged, and highlight if it can be migrated/supported by k8s-monitoring.
