# Agent Handoff & Migration Context: `MIGRATION_AGENT.md`

## 1. Overview & Handoff Purpose
This document provides a comprehensive state capture and handoff guide for any AI Coding Agent resuming the migration of the cluster telemetry collection layer from standalone `grafana/alloy` to the unified `grafana/k8s-monitoring` Helm chart (version **`4.3.2`**).

If conversation context is reset or a new agent takes over, **read this document alongside [`MIGRATION.md`](file:///D:/Development/workspace/github/bwgjoseph/spring-boot-lgtm/MIGRATION.md) and [`MIGRATION_TO_K8S_MONITORING_HELM.md`](file:///D:/Development/workspace/github/bwgjoseph/spring-boot-lgtm/MIGRATION_TO_K8S_MONITORING_HELM.md) to resume work seamlessly.**

---

## 2. Project & Environment Context
* **Repository:** `spring-boot-lgtm` (Spring Boot 3.5 / Java 25 Observability Sandbox)
* **OS & Shell:** Windows 11 with PowerShell (`pwsh`). Commands MUST use PowerShell syntax (e.g. `;` instead of `&&`, `.\mvnw`, `$env:VAR = "val"`).
* **Task Runner:** `Taskfile.yml` controls all build, deployment, linting, verification, and surgical swap tasks.
* **Observability Backends (Must NOT be reinstalled or modified during collection migration):**
  * **Loki:** Log storage (`loki-gateway.monitoring.svc.cluster.local:80`)
  * **Tempo:** Trace storage (`tempo.monitoring.svc.cluster.local:4317`)
  * **Prometheus / Mimir:** Metrics storage (`prometheus-server.monitoring.svc.cluster.local:80`)
  * **MinIO & MongoDB:** Backend object storage & CDC replica set

---

## 3. Key Architectural Decisions Agreed with User

1. **Helm Chart Version:** `grafana/k8s-monitoring` version `4.3.2`.
2. **Explicit Exclusions:**
   * `beyla.enabled: false` (No eBPF)
   * `costMetrics.enabled: false` (No OpenCost)
   * `kepler.enabled: false` (No Kepler energy metrics)
   * `prometheusOperatorObjects.enabled: false` (Stack uses standard Prometheus chart with `annotationAutodiscovery`, not Prometheus Operator CRDs)
3. **Unified Infrastructure Scraping:**
   * `k8s-monitoring` manages `kube-state-metrics` and `node-exporter` (`telemetryServices.kube-state-metrics.deploy: true`, `telemetryServices.node-exporter.deploy: true`, `hostMetrics.linuxHosts.enabled: true`, `clusterEvents.enabled: true`, `nodeLogs.enabled: true`).
   * `deployment/dev/values-prometheus.yaml` disables `kube-state-metrics` and `prometheus-node-exporter` to avoid duplicate scraping.
4. **Backend Destination Syntax:** Use map syntax (`destinations.prometheus`, `destinations.loki`, `destinations.tempo`).
5. **Tempo Destination Protocol:** `type: otlp`, `protocol: grpc`, `url: http://tempo.monitoring.svc.cluster.local:4317`, `traces.enabled: true`, `metrics.enabled: false`, `logs.enabled: false` (No `type: tempo`).
6. **Application gRPC Tracing Endpoint:**
   * `MANAGEMENT_OTLP_TRACING_ENDPOINT: http://k8s-monitoring-alloy-receiver.monitoring.svc.cluster.local:4317`
   * `MANAGEMENT_OTLP_TRACING_TRANSPORT: grpc` in `deployment/dev/app.yaml`.
7. **Log Regex Extraction & Structured Metadata:**
   * Enforces log processing via `podLogsViaLoki.enabled: true`.
   * Custom 3-stage regex parsing in `podLogs.extraLogProcessingStages` promoting `[app,traceId,spanId,userId]` to Loki structured metadata (`trace_id`, `span_id`, `user_id`). Safely handles blank/missing correlation IDs.
8. **Dashboard Provisioning:** `grafanaDashboards.enabled: true` provisioned via ConfigMaps matching Grafana sidecar label `grafana_dashboard=1`.
9. **Topology Strategy:**
   * **Dev (Phase A):** Single Monolithic Alloy DaemonSet collector to conserve local RAM (~128Mi-256Mi).
   * **Prod-Local / Prod (Phase B):** 4 Multi-Role Collector Workloads (`alloy-metrics` StatefulSet, `alloy-logs` DaemonSet, `alloy-receiver` Deployment, `alloy-singleton` Deployment).

---

## 4. Execution Roadmap & Target Files

### Phase 0: Backend Component Version Upgrades (Pre-Migration Baseline)
* **Goal:** Upgrade Grafana, Loki, Tempo, and Prometheus to latest stable versions before touching Alloy.
* **Files to edit:** `Taskfile.yml` (`VER_GRAFANA`, `VER_LOKI`, `VER_TEMPO`, `VER_PROMETHEUS`).
* **Commands to run:**
  * `task infra` (Upgrades Loki, Tempo, Prometheus, Grafana)
  * `task test:e2e` (Verifies existing standalone Alloy against upgraded backends)

### Phase A: Development Environment Migration (`dev`)
* **Target Files:**
  1. Create `deployment/dev/values-k8s-monitoring.yaml` (Monolithic single collector, map destinations, `linuxHosts`, `annotationAutodiscovery`, `podLogsViaLoki`, `extraLogProcessingStages`, `grafanaDashboards`).
  2. Modify `deployment/dev/values-prometheus.yaml` (Set `kube-state-metrics.enabled: false` and `prometheus-node-exporter.enabled: false`).
  3. Modify `deployment/dev/app.yaml` (Update `MANAGEMENT_OTLP_TRACING_ENDPOINT` to `http://k8s-monitoring-alloy-receiver.monitoring.svc.cluster.local:4317` and transport to `grpc`).
  4. Modify `Taskfile.yml` (Update `VER_K8S_MONITORING: "4.3.2"`, update `task alloy`, `lint:alloy`, `check:alloy`, `verify:alloy`, `pf:alloy`, `uninstall:alloy`).
  5. Modify `verification/check-alloy.ps1` and `verification/verify-alloy.ps1` (Support discovering pods with label `app.kubernetes.io/name=alloy` or `app.kubernetes.io/name=k8s-monitoring-alloy`).
* **Validation Commands:**
  * `task lint:alloy`
  * `task validate:prometheus`
  * `task validate:alloy`
  * `task validate:app`
  * `task test:e2e`

### Phase B: Production-Local & Production Migration (`prod-local` / `prod`)
* **Target Files:**
  1. Create `deployment/prod-local/values-k8s-monitoring.yaml` (Multi-role 4 collectors, clustering enabled, tail-sampling enabled).
  2. Create `deployment/prod/values-k8s-monitoring.yaml`.
* **Validation Commands:**
  * `task swap:alloy` (Surgical HA upgrade in `prod-local`)
  * `task verify:alloy ENV=prod-local`

---

## 5. Instructions for Resuming Agent

1. **Inspect Workspace State:** Run `git status` or inspect existing files to see if Phase 0, Phase A, or Phase B files have been partially created.
2. **Consult Core Files:**
   * [`MIGRATION.md`](file:///D:/Development/workspace/github/bwgjoseph/spring-boot-lgtm/MIGRATION.md) (Complete detailed migration plan)
   * [`sample-values.yaml`](file:///D:/Development/workspace/github/bwgjoseph/spring-boot-lgtm/sample-values.yaml) (Reference for multi-collector configuration syntax)
   * [`Taskfile.yml`](file:///D:/Development/workspace/github/bwgjoseph/spring-boot-lgtm/Taskfile.yml) (Central task runner)
3. **Execute Next Uncompleted Step:** Pick up sequentially from Phase 0 -> Phase A -> Phase B. Always run verification tasks (`task test:e2e`, `task validate:alloy`) after editing files.
