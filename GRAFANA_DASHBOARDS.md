# Grafana Dashboards

This document inventories all Grafana dashboards provisioned into this project and details the provisioning architecture across components.

---

## Provisioning Architecture

Dashboards in this sandbox are provisioned using two complementary mechanisms based on Helm chart capabilities:

1. **Helm Chart Bundled Provisioning (Native - Loki):**  
   The `grafana-community/loki` Helm chart includes built-in Grafana dashboard templates. Setting `monitoring.dashboards.enabled: true` in `values-loki.yaml` automatically renders 13 official Loki dashboard ConfigMaps stamped with `grafana_dashboard=1` and `grafana_folder=Loki`.
   > **Note on `monitoring.rules.enabled: false`:** While `monitoring.dashboards.enabled` is set to `true` (rendering standard Kubernetes ConfigMaps), `monitoring.rules.enabled` is explicitly set to `false`. Enabling `monitoring.rules` attempts to create `kind: PrometheusRule` CRDs which require Prometheus Operator (`kube-prometheus-stack`). Because this sandbox runs standard Prometheus (`prometheus-community/prometheus`) to stay lightweight, `monitoring.rules` must remain `false` to avoid missing CRD installation errors.

2. **Directory & Sidecar Sync (`task sync:dashboards` - Tempo, K8s, Custom):**  
   The `grafana-community/tempo-distributed` Helm chart does **not** include built-in dashboard templates. For Tempo, Kubernetes cluster monitoring, and custom application metrics, dashboard JSON files are maintained in `deployment/common/dashboards/` and synced to labeled Kubernetes ConfigMaps (`grafana_dashboard=1`) via `task sync:dashboards`.

```
┌─────────────────────────────────────────────────────────────┐
│ 1. Loki Helm Release (`grafana-community/loki`)             │
│    `monitoring.dashboards.enabled: true` in values-loki.yaml│
└──────────────────────────────┬──────────────────────────────┘
                               │ Auto-renders 13 Loki dashboard ConfigMaps
                               ▼
┌─────────────────────────────────────────────────────────────┐
│ 2. Custom Directory (`deployment/common/dashboards/`)       │
│    `task sync:dashboards` (creates ConfigMaps per subfolder)│
│    - `tempo/` (8 Tempo mixin dashboards)                    │
│    - `k8s/`   (11 K8s dashboards from dotdc & Grafana.com)  │
│    - Root     (Debezium, Node Exporter, RED Metrics)        │
└──────────────────────────────┬──────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│  Grafana Sidecar Container (watches `grafana_dashboard=1`)  │
│  Auto-imports dashboards into folders: `Loki`, `K8s`, `Tempo`│
└─────────────────────────────────────────────────────────────┘
```

---

## Dashboard Inventory

| Folder | Name / File | Dashboard Title | Provisioning Mechanism & Source |
| :--- | :--- | :--- | :--- |
| **Default** | `debezium-monitoring.json` | Debezium Connector Monitoring | `sync:dashboards` — Custom (project-specific) |
| **Default** | `node-exporter.json` | Node Exporter Full | `sync:dashboards` — [Grafana.com #1860](https://grafana.com/grafana/dashboards/1860) |
| **Default** | `red-metrics-dashboard.json` | Pokemon API RED Metrics | `sync:dashboards` — Custom (project-specific) |
| **K8s** | `14623-kubernetes-monitoring-overview.json` | Kubernetes Monitoring Overview | `sync:dashboards` — [Grafana.com #14623](https://grafana.com/grafana/dashboards/14623) |
| **K8s** | `k8s-addons-prometheus.json` | Prometheus | `sync:dashboards` — [dotdc/grafana-dashboards-kubernetes](https://github.com/dotdc/grafana-dashboards-kubernetes) |
| **K8s** | `k8s-addons-trivy-operator.json` | Prometheus (Trivy Operator) | `sync:dashboards` — [dotdc/grafana-dashboards-kubernetes](https://github.com/dotdc/grafana-dashboards-kubernetes) |
| **K8s** | `k8s-cluster.json` | Kubernetes / Compute Resources / Cluster | `sync:dashboards` — [dotdc/grafana-dashboards-kubernetes](https://github.com/dotdc/grafana-dashboards-kubernetes) |
| **K8s** | `k8s-namespace.json` | Kubernetes / Compute Resources / Namespace | `sync:dashboards` — [dotdc/grafana-dashboards-kubernetes](https://github.com/dotdc/grafana-dashboards-kubernetes) |
| **K8s** | `k8s-system-api-server.json` | Kubernetes / System / API Server | `sync:dashboards` — [dotdc/grafana-dashboards-kubernetes](https://github.com/dotdc/grafana-dashboards-kubernetes) |
| **K8s** | `k8s-system-coredns.json` | Kubernetes / System / CoreDNS | `sync:dashboards` — [dotdc/grafana-dashboards-kubernetes](https://github.com/dotdc/grafana-dashboards-kubernetes) |
| **K8s** | `k8s-views-global.json` | Kubernetes / Views / Global | `sync:dashboards` — [dotdc/grafana-dashboards-kubernetes](https://github.com/dotdc/grafana-dashboards-kubernetes) |
| **K8s** | `k8s-views-namespaces.json` | Kubernetes / Views / Namespaces | `sync:dashboards` — [dotdc/grafana-dashboards-kubernetes](https://github.com/dotdc/grafana-dashboards-kubernetes) |
| **K8s** | `k8s-views-nodes.json` | Kubernetes / Views / Nodes | `sync:dashboards` — [dotdc/grafana-dashboards-kubernetes](https://github.com/dotdc/grafana-dashboards-kubernetes) |
| **K8s** | `k8s-views-pods.json` | Kubernetes / Views / Pods | `sync:dashboards` — [dotdc/grafana-dashboards-kubernetes](https://github.com/dotdc/grafana-dashboards-kubernetes) |
| **Loki** | `loki-bloom-build` | Loki / Bloom Build | **Helm Chart Bundled** (`grafana-community/loki`) |
| **Loki** | `loki-bloom-gateway` | Loki / Bloom Gateway | **Helm Chart Bundled** (`grafana-community/loki`) |
| **Loki** | `loki-chunks` | Loki / Chunks | **Helm Chart Bundled** (`grafana-community/loki`) |
| **Loki** | `loki-deletion` | Loki / Deletion | **Helm Chart Bundled** (`grafana-community/loki`) |
| **Loki** | `loki-logs` | Loki / Logs | **Helm Chart Bundled** (`grafana-community/loki`) |
| **Loki** | `loki-mixin-recording-rules` | Loki / Recording Rules | **Helm Chart Bundled** (`grafana-community/loki`) |
| **Loki** | `loki-operational` | Loki / Operational | **Helm Chart Bundled** (`grafana-community/loki`) |
| **Loki** | `loki-reads` | Loki / Reads | **Helm Chart Bundled** (`grafana-community/loki`) |
| **Loki** | `loki-reads-resources` | Loki / Reads Resources | **Helm Chart Bundled** (`grafana-community/loki`) |
| **Loki** | `loki-retention` | Loki / Retention | **Helm Chart Bundled** (`grafana-community/loki`) |
| **Loki** | `loki-thanos-object-storage` | Loki / Object Store Thanos | **Helm Chart Bundled** (`grafana-community/loki`) |
| **Loki** | `loki-writes` | Loki / Writes | **Helm Chart Bundled** (`grafana-community/loki`) |
| **Loki** | `loki-writes-resources` | Loki / Writes Resources | **Helm Chart Bundled** (`grafana-community/loki`) |
| **Tempo** | `tempo-backendwork.json` | Tempo - Backend Work | `sync:dashboards` — `tempo-distributed` mixin |
| **Tempo** | `tempo-block-builder.json` | Tempo / Block Builder | `sync:dashboards` — `tempo-distributed` mixin |
| **Tempo** | `tempo-operational.json` | Tempo Operational | `sync:dashboards` — `tempo-distributed` mixin |
| **Tempo** | `tempo-reads.json` | Tempo / Reads | `sync:dashboards` — `tempo-distributed` mixin |
| **Tempo** | `tempo-resources.json` | Tempo / Resources | `sync:dashboards` — `tempo-distributed` mixin |
| **Tempo** | `tempo-rollout-progress.json` | Rollout Progress | `sync:dashboards` — `tempo-distributed` mixin |
| **Tempo** | `tempo-tenants.json` | Tempo / Tenants | `sync:dashboards` — `tempo-distributed` mixin |
| **Tempo** | `tempo-writes.json` | Tempo / Writes | `sync:dashboards` — `tempo-distributed` mixin |

---

## Summary by Provisioning Source

| Provisioning Mechanism | Count | Target Components |
| :--- | :---: | :--- |
| **Helm Chart Bundled (`grafana-community/loki`)** | 13 | Loki log engine, operational, and storage dashboards |
| **Directory Sync (`deployment/common/dashboards/`)** | 22 | K8s dashboards from `dotdc/grafana-dashboards-kubernetes` (10), Tempo mixins (8), Grafana.com community (2), Custom (2) |
| **Total** | **35** | |
