# Grafana Dashboards

This document inventories all Grafana dashboards provisioned into this project and details the provisioning architecture across components.

---

## Provisioning Architecture

Dashboards in this sandbox are provisioned exclusively through the dynamic **Grafana K8s Sidecar** (`sidecar.dashboards.enabled: true`). Static `dashboardProviders` blocks are omitted to avoid duplicate folder creation and case-sensitivity conflicts.

The sidecar watches for Kubernetes `ConfigMap` resources labeled `grafana_dashboard: "1"` across all namespaces and imports them into folders specified by the `grafana_folder` annotation:

1. **Helm Chart Bundled Provisioning (Native - Loki):**  
   The `grafana-community/loki` Helm chart includes built-in Grafana dashboard templates. Setting `monitoring.dashboards.enabled: true` in `values-loki.yaml` automatically renders 13 official Loki dashboard ConfigMaps stamped with `grafana_dashboard=1` and `grafana_folder=Loki`.
   > **Note on `monitoring.rules.enabled: false`:** While `monitoring.dashboards.enabled` is set to `true` (rendering standard Kubernetes ConfigMaps), `monitoring.rules.enabled` is explicitly set to `false`. Enabling `monitoring.rules` attempts to create `kind: PrometheusRule` CRDs which require Prometheus Operator (`kube-prometheus-stack`). Because this sandbox runs standard Prometheus (`prometheus-community/prometheus`) to stay lightweight, `monitoring.rules` must remain `false` to avoid missing CRD installation errors.

2. **Directory & Sidecar Sync (`task configmap:grafana-dashboard` - Tempo, K8s, Custom):**  
   The `grafana-community/tempo-distributed` Helm chart does **not** include built-in dashboard templates. For Tempo, Kubernetes cluster monitoring, and custom application metrics, dashboard JSON files are maintained in `deployment/common/dashboards/` and synced to labeled Kubernetes ConfigMaps (`grafana_dashboard=1`) with title-cased `grafana_folder` annotations via `task configmap:grafana-dashboard` (executing `verification/sync-dashboards.ps1`).

```
┌─────────────────────────────────────────────────────────────────┐
│ 1. Loki Helm Release (`grafana-community/loki`)                 │
│    `monitoring.dashboards.enabled: true` in values-loki.yaml    │
└──────────────────────────────┬──────────────────────────────────┘
                               │ Auto-renders 13 Loki dashboard ConfigMaps
                               │ (`grafana_folder: Loki`)
                               ▼
┌─────────────────────────────────────────────────────────────────┐
│ 2. Custom Directory (`deployment/common/dashboards/`)           │
│    `task configmap:grafana-dashboard` (syncs ConfigMaps)        │
│    - `k8s/`        -> `grafana_folder: K8s`        (11 dashboards)
│    - `kafka/`      -> `grafana_folder: Kafka`      (3 dashboards)
│    - `mongodb/`    -> `grafana_folder: MongoDB`    (1 dashboard) 
│    - `prometheus/` -> `grafana_folder: Prometheus` (1 dashboard) 
│    - `spring/`     -> `grafana_folder: Spring`     (4 dashboards)
│    - `tempo/`      -> `grafana_folder: Tempo`      (8 dashboards)
│    - `uptime/`     -> `grafana_folder: Uptime`     (1 dashboard) 
│    - Root          -> `grafana_folder: Default`    (3 dashboards)
└──────────────────────────────┬──────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────┐
│  Grafana Sidecar Container (watches `grafana_dashboard=1`)      │
│  Auto-provisions dashboards into 8 distinct folders:            │
│  📁 Default     📁 K8s       📁 Kafka      📁 Loki              │
│  📁 MongoDB     📁 Prometheus📁 Spring     📁 Tempo   📁 Uptime │
└─────────────────────────────────────────────────────────────────┘
```

---

## Dashboard Inventory

| Folder         | Name / File                                 | Dashboard Title                                    | Provisioning Mechanism & Source                                                                                               |
|:---------------|:--------------------------------------------|:---------------------------------------------------|:------------------------------------------------------------------------------------------------------------------------------|
| **Default**    | `debezium-monitoring.json`                  | Debezium Connector Monitoring                      | `configmap:grafana-dashboard` — Custom (project-specific)                                                                     |
| **Default**    | `node-exporter.json`                        | Node Exporter Full                                 | `configmap:grafana-dashboard` — [Grafana.com #1860](https://grafana.com/grafana/dashboards/1860)                              |
| **Default**    | `red-metrics-dashboard.json`                | Pokemon API RED Metrics                            | `configmap:grafana-dashboard` — Custom (project-specific)                                                                     |
| **K8s**        | `14623-kubernetes-monitoring-overview.json` | Kubernetes Monitoring Overview                     | `configmap:grafana-dashboard` — [Grafana.com #14623](https://grafana.com/grafana/dashboards/14623)                            |
| **K8s**        | `k8s-addons-prometheus.json`                | Prometheus                                         | `configmap:grafana-dashboard` — [dotdc/grafana-dashboards-kubernetes](https://github.com/dotdc/grafana-dashboards-kubernetes) |
| **K8s**        | `k8s-addons-trivy-operator.json`            | Prometheus (Trivy Operator)                        | `configmap:grafana-dashboard` — [dotdc/grafana-dashboards-kubernetes](https://github.com/dotdc/grafana-dashboards-kubernetes) |
| **K8s**        | `k8s-cluster.json`                          | Kubernetes / Compute Resources / Cluster           | `configmap:grafana-dashboard` — [dotdc/grafana-dashboards-kubernetes](https://github.com/dotdc/grafana-dashboards-kubernetes) |
| **K8s**        | `k8s-namespace.json`                        | Kubernetes / Compute Resources / Namespace         | `configmap:grafana-dashboard` — [dotdc/grafana-dashboards-kubernetes](https://github.com/dotdc/grafana-dashboards-kubernetes) |
| **K8s**        | `k8s-system-api-server.json`                | Kubernetes / System / API Server                   | `configmap:grafana-dashboard` — [dotdc/grafana-dashboards-kubernetes](https://github.com/dotdc/grafana-dashboards-kubernetes) |
| **K8s**        | `k8s-system-coredns.json`                   | Kubernetes / System / CoreDNS                      | `configmap:grafana-dashboard` — [dotdc/grafana-dashboards-kubernetes](https://github.com/dotdc/grafana-dashboards-kubernetes) |
| **K8s**        | `k8s-views-global.json`                     | Kubernetes / Views / Global                        | `configmap:grafana-dashboard` — [dotdc/grafana-dashboards-kubernetes](https://github.com/dotdc/grafana-dashboards-kubernetes) |
| **K8s**        | `k8s-views-namespaces.json`                 | Kubernetes / Views / Namespaces                    | `configmap:grafana-dashboard` — [dotdc/grafana-dashboards-kubernetes](https://github.com/dotdc/grafana-dashboards-kubernetes) |
| **K8s**        | `k8s-views-nodes.json`                      | Kubernetes / Views / Nodes                         | `configmap:grafana-dashboard` — [dotdc/grafana-dashboards-kubernetes](https://github.com/dotdc/grafana-dashboards-kubernetes) |
| **K8s**        | `k8s-views-pods.json`                       | Kubernetes / Views / Pods                          | `configmap:grafana-dashboard` — [dotdc/grafana-dashboards-kubernetes](https://github.com/dotdc/grafana-dashboards-kubernetes) |
| **Kafka**      | `24626_rev1.json`                           | Kafka Dashboard                                    | `configmap:grafana-dashboard` — [Grafana.com #24626](https://grafana.com/grafana/dashboards/24626)                            |
| **Kafka**      | `25379_rev1.json`                           | Klag - Kafka Lag Monitoring                        | `configmap:grafana-dashboard` — [Grafana.com #25379](https://grafana.com/grafana/dashboards/25379)                            |
| **Kafka**      | `25462_rev1.json`                           | Kafka Exporter Overview                            | `configmap:grafana-dashboard` — [Grafana.com #25462](https://grafana.com/grafana/dashboards/25462)                            |
| **Loki**       | `loki-bloom-build`                          | Loki / Bloom Build                                 | **Helm Chart Bundled** (`grafana-community/loki`)                                                                             |
| **Loki**       | `loki-bloom-gateway`                        | Loki / Bloom Gateway                               | **Helm Chart Bundled** (`grafana-community/loki`)                                                                             |
| **Loki**       | `loki-chunks`                               | Loki / Chunks                                      | **Helm Chart Bundled** (`grafana-community/loki`)                                                                             |
| **Loki**       | `loki-deletion`                             | Loki / Deletion                                    | **Helm Chart Bundled** (`grafana-community/loki`)                                                                             |
| **Loki**       | `loki-logs`                                 | Loki / Logs                                        | **Helm Chart Bundled** (`grafana-community/loki`)                                                                             |
| **Loki**       | `loki-mixin-recording-rules`                | Loki / Recording Rules                             | **Helm Chart Bundled** (`grafana-community/loki`)                                                                             |
| **Loki**       | `loki-operational`                          | Loki / Operational                                 | **Helm Chart Bundled** (`grafana-community/loki`)                                                                             |
| **Loki**       | `loki-reads`                                | Loki / Reads                                       | **Helm Chart Bundled** (`grafana-community/loki`)                                                                             |
| **Loki**       | `loki-reads-resources`                      | Loki / Reads Resources                             | **Helm Chart Bundled** (`grafana-community/loki`)                                                                             |
| **Loki**       | `loki-retention`                            | Loki / Retention                                   | **Helm Chart Bundled** (`grafana-community/loki`)                                                                             |
| **Loki**       | `loki-thanos-object-storage`                | Loki / Object Store Thanos                         | **Helm Chart Bundled** (`grafana-community/loki`)                                                                             |
| **Loki**       | `loki-writes`                               | Loki / Writes                                      | **Helm Chart Bundled** (`grafana-community/loki`)                                                                             |
| **Loki**       | `loki-writes-resources`                     | Loki / Writes Resources                            | **Helm Chart Bundled** (`grafana-community/loki`)                                                                             |
| **MongoDB**    | `25227_rev1.json`                           | MongoDB — Prod Overview                            | `configmap:grafana-dashboard` — [Grafana.com #25227](https://grafana.com/grafana/dashboards/25227)                            |
| **Prometheus** | `25537_rev1.json`                           | Prometheus Self-Monitoring                         | `configmap:grafana-dashboard` — [Grafana.com #25537](https://grafana.com/grafana/dashboards/25537)                            |
| **Spring**     | `24539_rev1.json`                           | Spring Data Repository Performance Dashboard       | `configmap:grafana-dashboard` — [Grafana.com #24539](https://grafana.com/grafana/dashboards/24539)                            |
| **Spring**     | `25359_rev2.json`                           | Spring Boot Observability                          | `configmap:grafana-dashboard` — [Grafana.com #25359](https://grafana.com/grafana/dashboards/25359)                            |
| **Spring**     | `25697_rev1.json`                           | Spring Boot HTTP Server Performance Analyzer       | `configmap:grafana-dashboard` — [Grafana.com #25697](https://grafana.com/grafana/dashboards/25697)                            |
| **Spring**     | `25698_rev1.json`                           | Spring Boot HTTP Client Performance Analyzer       | `configmap:grafana-dashboard` — [Grafana.com #25698](https://grafana.com/grafana/dashboards/25698)                            |
| **Tempo**      | `tempo-backendwork.json`                    | Tempo - Backend Work                               | `configmap:grafana-dashboard` — `tempo-distributed` mixin                                                                     |
| **Tempo**      | `tempo-block-builder.json`                  | Tempo / Block Builder                              | `configmap:grafana-dashboard` — `tempo-distributed` mixin                                                                     |
| **Tempo**      | `tempo-operational.json`                    | Tempo Operational                                  | `configmap:grafana-dashboard` — `tempo-distributed` mixin                                                                     |
| **Tempo**      | `tempo-reads.json`                          | Tempo / Reads                                      | `configmap:grafana-dashboard` — `tempo-distributed` mixin                                                                     |
| **Tempo**      | `tempo-resources.json`                      | Tempo / Resources                                  | `configmap:grafana-dashboard` — `tempo-distributed` mixin                                                                     |
| **Tempo**      | `tempo-rollout-progress.json`               | Rollout Progress                                   | `configmap:grafana-dashboard` — `tempo-distributed` mixin                                                                     |
| **Tempo**      | `tempo-tenants.json`                        | Tempo / Tenants                                    | `configmap:grafana-dashboard` — `tempo-distributed` mixin                                                                     |
| **Tempo**      | `tempo-writes.json`                         | Tempo / Writes                                     | `configmap:grafana-dashboard` — `tempo-distributed` mixin                                                                     |
| **Uptime**     | `25062_rev4.json`                           | Uptime Monitor                                     | `configmap:grafana-dashboard` — [Grafana.com #25062](https://grafana.com/grafana/dashboards/25062)                            |

---

## Summary by Provisioning Source

| Provisioning Mechanism                               | Count  | Target Components                                                                                                 |
|:-----------------------------------------------------|:------:|:------------------------------------------------------------------------------------------------------------------|
| **Helm Chart Bundled (`grafana-community/loki`)**    |   13   | Loki log engine, operational, and storage dashboards                                                              |
| **Directory Sync (`deployment/common/dashboards/`)** |   32   | K8s (11), Tempo (8), Spring (4), Kafka (3), Custom/RED/Debezium/Node (3), MongoDB (1), Prometheus (1), Uptime (1) |
| **Total**                                            | **45** |                                                                                                                   |
