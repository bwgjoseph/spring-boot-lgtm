# Migration Plan: Standalone Grafana Alloy to `grafana/k8s-monitoring` Helm Chart

## 1. Context & Objective
This document details the migration of the cluster telemetry collection layer from a standalone `grafana/alloy` deployment to the unified `grafana/k8s-monitoring` Helm chart (version **`4.3.2`**).

The new `k8s-monitoring` chart acts as the single unified collection layer for **logs**, **traces**, **cluster events**, **node system logs**, and **infrastructure metrics** (`kube-state-metrics` and `prometheus-node-exporter`), remote-writing/forwarding to existing backend services (**Loki**, **Tempo**, **Prometheus**, **Mimir**, **MongoDB**, **MinIO**). Existing storage and visualization infrastructure MUST NOT be reinstalled or modified.

---

## 2. Architectural Decisions & Scope

### Unified Infrastructure Scraping & Host Metrics
To consolidate telemetry collection into `k8s-monitoring` and simplify `prometheus-server` into a pure TSDB storage engine:
* **`k8s-monitoring` Chart:**
  * `telemetryServices.kube-state-metrics.deploy: true`
  * `telemetryServices.node-exporter.deploy: true`
  * `hostMetrics.enabled: true`
  * `hostMetrics.linuxHosts.enabled: true`
  * `clusterEvents.enabled: true` (Kubernetes warning/info events -> Loki)
  * `nodeLogs.enabled: true` (Host journald system logs -> Loki)
  * `podLogsViaLoki.enabled: true` (Pod log collection -> Loki)
  * `grafanaDashboards.enabled: true` (Auto-provisions pre-built K8s cluster & Alloy dashboards to Grafana)
  * `prometheusOperatorObjects.enabled: false` (Current setup uses standard Prometheus chart with `annotationAutodiscovery`; not using Prometheus Operator CRDs)
* **`prometheus` Chart (`deployment/dev/values-prometheus.yaml`):**
  * `kube-state-metrics.enabled: false`
  * `prometheus-node-exporter.enabled: false`

### Topology Strategy: Monolithic (Dev) vs. Multi-Collector Roles (Prod)
* **Phase A (`dev`):** Single Monolithic Alloy DaemonSet collector handling metrics, logs, and traces all-in-one to conserve local memory (~128Mi-256Mi RAM).
* **Phase B (`prod-local` / `prod`):** Multi-Role Collector Architecture (4 specialized workloads):
  * `alloy-metrics` (StatefulSet): Dedicated to metrics scraping and target sharing.
  * `alloy-logs` (DaemonSet): Dedicated to reading filesystem pod and node logs.
  * `alloy-receiver` (Deployment): Dedicated to receiving OTLP gRPC app traces.
  * `alloy-singleton` (Deployment): Dedicated to single-replica cluster event watching.

### Feature Exclusions
To prevent unnecessary resource bloat:
* **Beyla:** `beyla.enabled: false` (No eBPF auto-instrumentation)
* **OpenCost:** `costMetrics.enabled: false` or `opencost.enabled: false` (No cost metrics)
* **Kepler:** `kepler.enabled: false` (No energy usage metrics)

### Backend Destinations (Map Syntax)
```yaml
destinations:
  prometheus:
    type: prometheus
    url: http://prometheus-server.monitoring.svc.cluster.local:80/api/v1/write
    metrics:
      sendExemplars: true

  loki:
    type: loki
    url: http://loki-gateway.monitoring.svc.cluster.local:80/loki/api/v1/push

  tempo:
    type: otlp
    protocol: grpc
    url: http://tempo.monitoring.svc.cluster.local:4317
    tls:
      insecure: true
    traces:
      enabled: true
    metrics:
      enabled: false
    logs:
      enabled: false
```

### Application gRPC OTLP Ingestion
Spring Boot 3.5 application emits OTLP traces directly via gRPC to port `4317`. `receivers.otlp.grpc` will be enabled on port `4317`. Environment variables in `deployment/dev/app.yaml` will be set to:
```yaml
- name: MANAGEMENT_OTLP_TRACING_ENDPOINT
  value: "http://k8s-monitoring-alloy-receiver.monitoring.svc.cluster.local:4317"
- name: MANAGEMENT_OTLP_TRACING_TRANSPORT
  value: "grpc"
```

---

## 3. Preservation of Custom Alloy Capabilities & Prebuilt Dashboards

### Prebuilt Grafana Dashboards (`grafanaDashboards`)
The `grafana/k8s-monitoring` chart provides prebuilt dashboards for Kubernetes cluster metrics, node health, and Alloy collector self-monitoring. These are provisioned directly to Grafana via ConfigMaps matching the Grafana sidecar label:

```yaml
grafanaDashboards:
  enabled: true
  label: grafana_dashboard
  labelValue: "1"
  folder: "Kubernetes Monitoring"
```

---

### Annotation-Based Pod Scraping (Simplified)
#### Background & Problem Statement
In Kubernetes, applications (like Spring Boot) self-declare metrics scraping configuration using standard `prometheus.io/*` annotations on the Pod template (`deployment/dev/app.yaml`):

```yaml
metadata:
  annotations:
    prometheus.io/scrape: "true"               # Signal: "Scrape metrics from this pod"
    prometheus.io/path: "/actuator/prometheus" # Endpoint: Target metrics path
    prometheus.io/port: "8080"                 # Port: Target container port
```

#### Legacy River Configuration vs. `k8s-monitoring`
Previously, standalone Alloy required ~40 lines of manual River syntax (`discovery.kubernetes`, `discovery.relabel`, and `prometheus.scrape`) to parse these annotations and rewrite scrape targets.

With `grafana/k8s-monitoring`, manual River rules are replaced by a single declarative toggle in `values.yaml`:

```yaml
annotationAutodiscovery:
  enabled: true
```

---

### Log Processing & Structured Metadata Extraction

#### Feature Toggle vs. Custom Pipeline Stages
* `podLogsViaLoki.enabled: true`: The explicit chart feature toggle that enables pod log file collection from `/var/log/pods` into Loki.
* `podLogs.extraLogProcessingStages`: The custom engine tuning block containing our 3-stage regex parsing pipeline:

```yaml
podLogsViaLoki:
  enabled: true

podLogs:
  extraLogProcessingStages: |-
    stage.regex {
      expression = ".*\\[(?P<app>[^,]*),(?P<traceId>[^,]*),(?P<spanId>[^,]*),(?P<userId>[^,]*)\\].*"
    }
    stage.structured_metadata {
      values = {
        "trace_id" = "traceId",
        "span_id"  = "spanId",
        "user_id"  = "userId",
      }
    }
    stage.label_drop {
      values = ["app", "traceId", "spanId", "userId"]
    }
```

---

## 4. Future Enhancements

### Future Note 1: Enabling Grafana Faro (Frontend Web RUM Telemetry)
If web frontend SPAs (React/Vue/Angular) are added to this stack in the future and require Real User Monitoring (RUM), perform the following steps:

1. **Expose Faro Port in Alloy Receiver:**
   Add port `12347` under `collectors.alloy-receiver.alloy.extraPorts`:
   ```yaml
   extraPorts:
     - name: faro
       port: 12347
       targetPort: 12347
       protocol: TCP
   ```
2. **Add Faro Receiver Block in `extraConfig`:**
   Inject the `faro.receiver "frontend"` and `loki.process "faro_labels"` pipeline snippets into `collectors.alloy-receiver.extraConfig`.
3. **Gateway Exposure:**
   Expose port `12347` via an Ingress or Gateway resource to allow browser clients to post telemetry to `http://<faro-domain>/collect`.

### Future Note 2: Switching to Prometheus Operator (`kube-prometheus-stack` & CRDs)
If the cluster evolves to require enterprise self-service metric filtering, custom per-app scrape intervals, or distributed `PrometheusRule` CRDs:

1. **Enable CRD Discovery in `k8s-monitoring`:**
   Set `prometheusOperatorObjects.enabled: true` in `values-k8s-monitoring.yaml` to instruct Alloy to watch and scrape `ServiceMonitor`, `PodMonitor`, and `Probe` CRDs.
2. **Replace Pod Annotations with `PodMonitor` / `ServiceMonitor` Manifests:**
   Replace `prometheus.io/*` pod annotations in application manifests with declarative `PodMonitor` CRDs:
   ```yaml
   apiVersion: monitoring.coreos.com/v1
   kind: PodMonitor
   metadata:
     name: spring-boot-app
     namespace: monitoring
   spec:
     selector:
       matchLabels:
         app: spring-boot-app
     podMetricsEndpoints:
       - port: http
         path: /actuator/prometheus
         interval: 15s
   ```
3. **Alert Rule Migration:**
   Migrate static alerting ConfigMaps (`prometheus-alerting-rules.yaml`) into declarative `PrometheusRule` CRDs.

---

## 5. Migration Execution Phases

To ensure strict isolation of variables and a guaranteed zero-downtime transition, the migration is structured into three sequential phases:

```
┌─────────────────────────────────────────────────────────────────────────┐
│ PHASE 0: Backend Component Version Upgrades (Pre-Migration Baseline)    │
│ 1. Update chart versions in Taskfile.yml (Loki, Tempo, Prom, Grafana)   │
│ 2. Run task infra to upgrade backend storage & visualization engines     │
│ 3. Run task test:e2e against current Alloy to establish clean baseline  │
└─────────────────────────────────────────────────────────────────────────┘
                                     │
                                     ▼ (All E2E tests pass on new backends)
┌─────────────────────────────────────────────────────────────────────────┐
│ PHASE A: Development Environment Migration (dev)                        │
│ 1. Manifest Creation (deployment/dev/values-k8s-monitoring.yaml)        │
│ 2. Disable KSM/NodeExporter in deployment/dev/values-prometheus.yaml   │
│ 3. Update app.yaml OTLP gRPC endpoint                                  │
│ 4. Update Taskfile.yml & Verification Scripts                           │
│ 5. Validate via task validate:dev & task test:e2e                       │
└─────────────────────────────────────────────────────────────────────────┘
                                     │
                                     ▼ (All DEV tests pass)
┌─────────────────────────────────────────────────────────────────────────┐
│ PHASE B: Production-Local & Production Migration (prod-local / prod)    │
│ 1. Manifest Creation (deployment/prod-local/values-k8s-monitoring.yaml) │
│ 2. Multi-Role Collector Topology (4 workloads) & Tail-Sampling          │
│ 3. Execute task swap:alloy for HA validation in prod-local               │
│ 4. Sync production configs & promote verified manifests to deployment/prod│
└─────────────────────────────────────────────────────────────────────────┘
```

### Phase 0: Backend Component Version Upgrades (Pre-Migration Baseline)

1. **Update Chart Versions in `Taskfile.yml`:**
   Update `VER_GRAFANA`, `VER_LOKI`, `VER_TEMPO`, and `VER_PROMETHEUS` to their latest stable Helm chart versions.
2. **Deploy Backend Upgrades:**
   Run `task infra` (or individual `task loki`, `task tempo`, `task prometheus`, `task grafana`) to upgrade backend storage engines.
3. **Verify Baseline with Existing Collector:**
   Run `task test:e2e` against the existing standalone Alloy collector. Confirm that logs, traces, and metrics are ingested into the upgraded backend versions cleanly before making collector pipeline changes.

### Phase A: Development Environment (`dev`)

1. **Manifest Creation:**
   Create `deployment/dev/values-k8s-monitoring.yaml` targeting dev standalone single-collector setup with map syntax for destinations, `linuxHosts.enabled: true`, `clusterEvents: true`, `nodeLogs: true`, `podLogsViaLoki: true`, `grafanaDashboards.enabled: true`, and `annotationAutodiscovery: true`.
2. **Infrastructure Update:**
   Update `deployment/dev/values-prometheus.yaml` to disable `kube-state-metrics` and `prometheus-node-exporter`.
3. **Application Manifest Update:**
   Update `deployment/dev/app.yaml` OTLP endpoint to `http://k8s-monitoring-alloy-receiver.monitoring.svc.cluster.local:4317` with gRPC transport.
4. **Taskfile & Script Alignment:**
   - Update `Taskfile.yml` variable `VER_K8S_MONITORING: "4.3.2"`.
   - Update tasks `alloy`, `lint:alloy`, `check:alloy`, `verify:alloy`, `pf:alloy`, and `uninstall:alloy`.
   - Update PowerShell scripts `verification/check-alloy.ps1` and `verification/verify-alloy.ps1`.
5. **Verification & E2E Test:**
   - Run `task lint:alloy` to check Helm template rendering.
   - Run `task validate:prometheus` to redeploy Prometheus.
   - Run `task validate:alloy` and `task validate:app`.
   - Run `task test:e2e` to verify complete log, trace, and metric pipeline flow.

### Phase B: Production-Local & Production (`prod-local` / `prod`)

1. **Manifest Creation:**
   Create `deployment/prod-local/values-k8s-monitoring.yaml` and `deployment/prod/values-k8s-monitoring.yaml` utilizing the 4 multi-role collectors (`alloy-metrics`, `alloy-logs`, `alloy-receiver`, `alloy-singleton`).
2. **Clustered HA & Tail-Sampling Setup:**
   Enable Alloy clustering (gossip protocol) and trace tail-sampling (preserving ERROR spans + 10% probabilistic sampling) in `prod-local` values.
3. **Surgical Swap Task:**
   Execute `task swap:alloy` to uninstall old standalone Alloy and deploy `grafana/k8s-monitoring` in HA mode for surgical validation.
4. **Production Promotion:**
   Verify `prod-local` metrics/logs flow into Mimir, Loki, and Tempo, then sync verified keys to `deployment/prod`.

---

## 6. Verification & Validation Protocol

1. **Phase 0 (Pre-Migration Baseline Validation):**
   - `task infra` — Upgrade Grafana, Loki, Tempo, Prometheus.
   - `task test:e2e` — Verify data pipeline against upgraded storage backends using existing standalone Alloy.

2. **Phase A (Dev Migration Validation):**
   - `task lint:alloy` — Verify template syntax for `values-k8s-monitoring.yaml`.
   - `task validate:prometheus` — Redeploy Prometheus with sub-charts disabled.
   - `task validate:alloy` — Verify `k8s-monitoring` pod readiness and pipeline metrics.
   - `task validate:app` — Rebuild and redeploy application with updated OTLP gRPC endpoint.
   - `task test:e2e` — End-to-end data verification across Spring Boot app, Loki, Tempo, and Prometheus.

3. **Phase B (Prod-Local & HA Validation):**
   - `task swap:alloy` — Surgical HA swap in `prod-local`.
   - `task verify:alloy ENV=prod-local` — Verify clustering members and tail-sampling metrics.
