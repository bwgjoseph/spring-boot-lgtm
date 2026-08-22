# Migration to `grafana/k8s-monitoring` Helm Chart

## 1. Overview & Objectives
This document details the strategy, architectural changes, and execution roadmap for migrating the telemetry collection layer from standalone **Grafana Alloy** (`grafana/alloy`) to the unified **`grafana/k8s-monitoring`** Helm chart (target version: **`4.4.0`**).

The goal of this migration is to simplify and standardize the collection of logs, metrics, traces, and Kubernetes cluster telemetry into a single declarative chart while retaining the existing LGTM backends (**Loki**, **Tempo**, **Prometheus/Mimir**, and **MinIO**).

---

## 2. What `grafana/k8s-monitoring` Replaces in the Current Setup

| Current Component / Mechanism | Replaced By `grafana/k8s-monitoring` | Benefits & Architecture Improvements |
| :--- | :--- | :--- |
| **Standalone `grafana/alloy` Chart** | Unified `k8s-monitoring` collector management | Eliminates hundreds of lines of hand-crafted River DSL configurations (`configMap.content`). |
| **Manual River Pipeline Wiring** | Declarative `destinations` syntax (`prometheus`, `loki`, `tempo`) | Native routing, batching, and exporter creation directly from simple YAML keys. |
| **Prometheus Sub-charts (`kube-state-metrics`, `node-exporter`)** | `k8s-monitoring` integrated telemetry services | Standardizes K8s metrics scraping (cluster events, node metrics, pod states) without duplicate scrapers. |
| **Manual K8s Dashboard ConfigMaps** | `grafanaDashboards.enabled: true` | Automatically provisions official Grafana dashboards for K8s nodes, pods, and workloads into Grafana via sidecar. |
| **Manual Log Relabeling & Regex Pipelines** | `podLogsViaLoki` + `extraLogProcessingStages` | Declarative log ingestion with regex promotion for trace correlation (`trace_id`, `span_id`, `user_id` in Loki structured metadata). |

> **What does NOT change:**
> Backend storage engines (**Loki**, **Tempo**, **Prometheus/Mimir**, and **MinIO**) remain completely intact as destinations.

---

## 3. Key Architectural Decisions

1. **Helm Chart:** `grafana/k8s-monitoring` (Version: `4.4.0`).
2. **Explicit Exclusions (Resource & Scope Control):**
   - `beyla.enabled: false` (No eBPF overhead)
   - `costMetrics.enabled: false` (No OpenCost)
   - `kepler.enabled: false` (No Kepler energy metrics)
   - `prometheusOperatorObjects.enabled: false` (Stack uses standard Prometheus chart with `annotationAutodiscovery`, not Prometheus Operator CRDs)
3. **Backend Destination Mapping:**
   - **Prometheus:** `destinations.prometheus` targeting `http://prometheus-server.monitoring.svc.cluster.local:80/api/v1/write`
   - **Loki:** `destinations.loki` targeting `http://loki-gateway.monitoring.svc.cluster.local:80/loki/api/v1/push`
   - **Tempo:** `destinations.tempo` with `type: otlp`, `protocol: grpc`, `url: http://tempo.monitoring.svc.cluster.local:4317`, `traces.enabled: true`, `metrics.enabled: false`, `logs.enabled: false`
4. **Application Tracing Ingestion:**
   - Application sends OTLP traces to `http://k8s-monitoring-alloy-receiver.monitoring.svc.cluster.local:4317` with `grpc` transport.
5. **Log Processing & Structured Metadata:**
   - Extract `[app,traceId,spanId,userId]` format via `podLogs.extraLogProcessingStages` into Loki structured metadata (`trace_id`, `span_id`, `user_id`).
6. **Topology Strategy by Environment:**
   - **Dev (`dev`):** Single Monolithic Alloy DaemonSet collector to conserve local RAM (~128Mi-256Mi).
   - **Prod-Local / Prod (`prod-local`, `prod`):** Multi-Role architecture with 4 specialized collector workloads (`alloy-metrics` StatefulSet, `alloy-logs` DaemonSet, `alloy-receiver` Deployment, `alloy-singleton` Deployment) with tail-sampling.

---

## 4. Execution Roadmap

### Phase A: Development Environment (`dev`)
1. **Create `deployment/dev/values-k8s-monitoring.yaml`:**
   - Single monolithic collector DaemonSet.
   - Configure destinations for Prometheus, Loki, and Tempo.
   - Configure annotation-based scraping (`annotationAutodiscovery`), host metrics (`linuxHosts`), pod logs (`podLogsViaLoki`), and structured metadata extraction.
   - Enable `grafanaDashboards.enabled: true`.
2. **Update `deployment/dev/values-prometheus.yaml`:**
   - Set `kube-state-metrics.enabled: false` and `prometheus-node-exporter.enabled: false` to avoid duplicate scrapers.
3. **Update `deployment/dev/app.yaml`:**
   - Update `MANAGEMENT_OTLP_TRACING_ENDPOINT` to `http://k8s-monitoring-alloy-receiver.monitoring.svc.cluster.local:4317` and transport to `grpc`.
4. **Update `Taskfile.yml`:**
   - Add `VER_K8S_MONITORING: "4.4.0"`.
   - Update `task alloy`, `lint:alloy`, `check:alloy`, `verify:alloy`, `pf:alloy`, and `uninstall:alloy` to use the `k8s-monitoring` chart.
5. **Update Verification Scripts:**
   - Update `check-alloy.ps1` and `verify-alloy.ps1` to detect `app.kubernetes.io/name=k8s-monitoring-alloy`.
6. **Validate & Test:**
   - `task lint:alloy`
   - `task validate:prometheus`
   - `task validate:alloy`
   - `task validate:app`
   - `task test:e2e`

### Phase B: Production-Local & Production (`prod-local` / `prod`)
1. **Create `deployment/prod-local/values-k8s-monitoring.yaml`:** ✅
   - Multi-role architecture: 4 specialized collectors with clustering enabled.
2. **Create `deployment/prod/values-k8s-monitoring.yaml`:** ✅
   - Production HA resource specifications (CPU/RAM limits) and multi-role collector configuration.
3. **Taskfile Zero-Friction Switcher:** ✅
   - Implemented `task use:k8s-monitoring` and `task use:alloy` for instant toggling.
   - Maintained universal `service/alloy` ExternalName alias pointing to `k8s-monitoring-alloy-singleton.monitoring.svc.cluster.local:4317`.
4. **Validate & Test:** ✅
   - Verified `task lint:alloy` dry-runs clean across all 3 environment value files.
   - Updated `verification/check-alloy.ps1` and `verify-alloy.ps1` to detect both standalone Alloy and `k8s-monitoring` pods.

---

## 5. Migration Safety & Verification Strategy

- **Step-by-Step Isolation:** Migrate and fully verify `dev` first before touching `prod-local` or `prod`.
- **Deterministic Linting:** Run `task lint:alloy` to validate Helm template generation prior to cluster deployments.
- **Automated Verification:** Run `task test:e2e` to verify the complete telemetry pipeline (metrics in Prometheus, logs with `trace_id` metadata in Loki, traces in Tempo).
- **Zero Backend Disruption:** Telemetry backend engines remain unchanged, eliminating the risk of data loss.

---

## 6. Detailed TODO Checklist & Watch-outs (Project-Specific)

The following items are derived from the **current actual configuration** in this project and must be addressed during the migration.

| # | Area | File | Current State | Required Action | Priority | Status |
| :---: | :--- | :--- | :--- | :--- | :---: | :---: |
| 1 | **OTLP Tracing Endpoint** | `deployment/common/alias-alloy-service.yaml` | Service Alias `service/alloy` created | Maintain `http://alloy.monitoring.svc.cluster.local:4317` pointing via ExternalName | 🔴 Must do | ✅ Done |
| 2 | **Disable `prometheus-node-exporter`** | `deployment/dev/values-prometheus.yaml` | Handled via toggle task | `use:k8s-monitoring` disables duplicate scrapers dynamically | 🔴 Must do | ✅ Done |
| 3 | **Disable `kube-state-metrics`** | `deployment/dev/values-prometheus.yaml` | Handled via toggle task | `use:k8s-monitoring` disables duplicate scrapers dynamically | 🔴 Must do | ✅ Done |
| 4 | **Prometheus Remote Write flags** | `deployment/dev/values-prometheus.yaml` L3-L11 | `remoteWriteReceiver: true` | Retained as-is for Remote Write ingestion | ✅ No change | ✅ Done |
| 5 | **Pod annotation scraping** | `deployment/dev/app.yaml` | `prometheus.io/scrape: "true"` | Retained — `annotationAutodiscovery` reads annotations | ✅ No change | ✅ Done |
| 6 | **Log extraction pipeline** | `deployment/dev/values-k8s-monitoring.yaml` | Re-expressed in YAML | Configured `podLogs.extraLogProcessingStages` for `trace_id`, `span_id`, `user_id` | 🟡 Migration step | ✅ Done |
| 7 | **Alloy service / pod selectors in Taskfile** | `Taskfile.yml` | Updated with `use:k8s-monitoring` & `use:alloy` | Multi-label support added for `pf:alloy` and `lint:alloy` | 🟡 Migration step | ✅ Done |
| 8 | **Verification scripts pod discovery** | `verification/check-alloy.ps1`, `verify-alloy.ps1` | Multi-label search | Updated to search `app.kubernetes.io/name in (alloy, k8s-monitoring-alloy)` | 🟡 Migration step | ✅ Done |
| 9 | **Tempo destination protocol** | `deployment/*/values-k8s-monitoring.yaml` | Configured `type: otlp`, `protocol: grpc` | Points to `http://tempo-distributor.monitoring.svc.cluster.local:4317` | 🟡 Migration step | ✅ Done |
| 10 | **Grafana dashboards** | `deployment/*/values-k8s-monitoring.yaml` | `grafanaDashboards.enabled: true` | Auto-provisions official K8s dashboards into Grafana | 🟢 Net gain | ✅ Done |

---

### 6.1 Key Watch-outs in Detail

#### 🔴 #1 — OTLP Tracing Endpoint (`app.yaml`)
Without this change, Spring Boot traces will continue targeting the old standalone Alloy service (`alloy.monitoring.svc`), which will be uninstalled. Traces will drop completely.

#### 🔴 #2 & #3 — Duplicate Scrapers (`values-prometheus.yaml`)
`k8s-monitoring` deploys its own managed `node-exporter` DaemonSet and `kube-state-metrics` Deployment. Running a second set from the Prometheus chart causes:
- Port binding conflicts on the same DaemonSet nodes.
- Duplicate metric streams in Prometheus TSDB, polluting dashboards and alert thresholds.

#### 🟡 #6 — Log Extraction Pipeline
The existing River DSL in `values-alloy.yaml`:
```alloy
stage.regex {
  expression = ".*\\[(?P<app>[^,]*),(?P<traceId>[^,]*),(?P<spanId>[^,]*),(?P<userId>[^,]*)\\].*"
}
stage.structured_metadata {
  values = { "trace_id" = "traceId", "span_id" = "spanId", "user_id" = "userId" }
}
stage.label_drop { values = ["app", "traceId", "spanId", "userId"] }
```
Must be re-expressed under `podLogs.extraLogProcessingStages` in the new `values-k8s-monitoring.yaml`. The regex pattern and stage order remain identical.

#### 🟡 #9 — Tempo Destination (No `type: tempo`)
`grafana/k8s-monitoring` does not have a native `tempo` destination type. Configure Tempo as an OTLP destination:
```yaml
destinations:
  - name: tempo
    type: otlp
    url: http://tempo-distributor.monitoring.svc.cluster.local:4317
    protocol: grpc
    signals: ["traces"]
```

---

## 7. Zero-Friction Collector Toggle Architecture (Parallel / Dual Mode)

To allow benchmarking and switching between **Standalone Alloy** and **`k8s-monitoring`** without manual file edits or breaking dependent workloads, we implement a **Surgical Toggle Pattern** modeled after the existing `task swap:*` tasks.

### 7.1 Architecture & Design

```
                     ┌────────────────────────┐
                     │    Spring Boot App     │
                     │ (OTLP: http://alloy)   │
                     └───────────┬────────────┘
                                 │ :4317
                                 ▼
                     ┌────────────────────────┐
                     │ Service Alias: `alloy` │
                     └───────────┬────────────┘
                                 │
                 ┌───────────────┴───────────────┐
                 ▼ (When standalone active)       ▼ (When k8s-monitoring active)
      ┌─────────────────────┐         ┌─────────────────────────────────┐
      │  Standalone Alloy   │         │  k8s-monitoring Collector Layer │
      │  (River configMap)  │         │  (k8s-monitoring-alloy-*)       │
      └──────────┬──────────┘         └────────────────┬────────────────┘
                 │                                     │
                 └───────────────┬─────────────────────┘
                                 ▼
                   [ Loki | Tempo | Prometheus ]
```

### 7.2 The 3 Friction-Reduction Techniques

1. **Universal Service Alias (`service/alloy`):**
   - When deploying `k8s-monitoring`, an additional Service alias named `alloy` is maintained (or selector-mapped to the receiver pod).
   - **Benefit:** `app.yaml` remains pointing to `http://alloy.monitoring.svc.cluster.local:4317` **permanently**. No app configuration edits or pod restarts are needed when toggling.

2. **Dynamic Sub-chart Control:**
   - Standalone Prometheus chart retains its default values.
   - When switching to `k8s-monitoring`, the toggle task dynamically disables Prometheus sub-charts (`--set kube-state-metrics.enabled=false --set prometheus-node-exporter.enabled=false`) to prevent duplicates.

3. **Multi-Label Test Discovery:**
   - Verification scripts (`verify-alloy.ps1`, `check-alloy.ps1`) use combined label discovery:
     `app.kubernetes.io/name in (alloy, k8s-monitoring-alloy)`
   - **Benefit:** `task test:e2e` and `task verify:alloy` automatically test whichever collector is currently active.

### 7.3 Toggle Commands (Taskfile)

```powershell
# 1. Switch to k8s-monitoring (uninstalls standalone Alloy, applies k8s-monitoring + alias)
task use:k8s-monitoring

# 2. Switch back to Standalone Alloy (uninstalls k8s-monitoring, applies standalone Alloy)
task use:alloy

# 3. Deterministic verification for whichever collector is active
task test:e2e
```
