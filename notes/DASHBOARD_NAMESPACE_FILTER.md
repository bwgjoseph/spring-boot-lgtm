# 🏷️ Adding Namespace Filter Variables to Grafana Dashboards

This guide explains how to add a `$namespace` (and optionally `$pod`) template variable to Grafana dashboards so panels can be scoped to a specific Kubernetes namespace. This applies to both Prometheus metric queries and Loki log queries.

---

## 📚 Why Namespace Filtering Matters

In this stack, all workloads run in the **`monitoring`** namespace — so today a single namespace is sufficient. However, as the stack evolves (multi-tenant, multi-service), namespace filtering becomes critical to:
- Avoid metrics from unrelated workloads bleeding into dashboards.
- Reuse the same dashboard across environments (dev / prod-local / prod) by switching the `$namespace` dropdown.

> **Note:** This is a best-practice documentation guide, not a mandatory migration. Our current dashboards are intentionally scoped to `service_name="spring-boot-app"` labels for simplicity.

---

## 🔑 Concepts: Namespace Label Availability

| Data Source | Namespace Label Name | Where It Comes From |
| :--- | :--- | :--- |
| **Prometheus** | `namespace` | kube-state-metrics / Alloy `prometheus.scrape` relabelling injects `__meta_kubernetes_namespace` |
| **Loki** | `namespace` | Alloy `loki.source.kubernetes` adds `namespace` as a Loki stream label |
| **Tempo** | `k8s.namespace.name` | Alloy `otelcol.processor.k8sattributes` enriches traces with this resource attribute |

---

## ⚙️ Pattern 1: Template Variable in Dashboard JSON

The canonical Grafana way is to add a `templating.list` entry of type `query` that fetches all distinct namespace label values from Prometheus:

```json
"templating": {
  "list": [
    {
      "name": "namespace",
      "label": "Namespace",
      "type": "query",
      "datasource": {
        "type": "prometheus",
        "uid": "prometheus"
      },
      "query": {
        "query": "label_values(kube_namespace_labels, namespace)",
        "refId": "A"
      },
      "includeAll": true,
      "allValue": ".*",
      "multi": false,
      "sort": 1,
      "refresh": 2,
      "hide": 0
    }
  ]
}
```

Then update panel queries to inject the variable as a label matcher:

```json
"expr": "sum(rate(pokemon_controller_seconds_count{namespace=~\"$namespace\"}[1m]))"
```

---

## ⚙️ Pattern 2: Variable for Prometheus Metrics (Full JSON Block)

Below is a ready-to-paste `templating.list` block with both `$namespace` and `$pod` chained variables (pod dropdown filters to only pods within the selected namespace):

```json
"templating": {
  "list": [
    {
      "name": "namespace",
      "label": "Namespace",
      "type": "query",
      "datasource": { "type": "prometheus", "uid": "prometheus" },
      "query": {
        "query": "label_values(kube_pod_info, namespace)",
        "refId": "A"
      },
      "current": { "text": "monitoring", "value": "monitoring" },
      "includeAll": true,
      "allValue": ".*",
      "multi": false,
      "sort": 1,
      "refresh": 2,
      "hide": 0,
      "regex": ""
    },
    {
      "name": "pod",
      "label": "Pod",
      "type": "query",
      "datasource": { "type": "prometheus", "uid": "prometheus" },
      "query": {
        "query": "label_values(kube_pod_info{namespace=~\"$namespace\"}, pod)",
        "refId": "A"
      },
      "includeAll": true,
      "allValue": ".*",
      "multi": true,
      "sort": 1,
      "refresh": 2,
      "hide": 0
    }
  ]
}
```

---

## ⚙️ Pattern 3: Applying to Each Data Source

### Prometheus Queries

Inject `namespace=~"$namespace"` into any metric selector that carries the `namespace` label:

```promql
# Before
sum(rate(pokemon_controller_seconds_count[1m]))

# After
sum(rate(pokemon_controller_seconds_count{namespace=~"$namespace"}[1m]))
```

```promql
# RED Metrics P99 - scoped by namespace
histogram_quantile(0.99,
  sum(rate(pokemon_controller_seconds_bucket{namespace=~"$namespace"}[1m])) by (le)
) * 1000
```

> **Tip:** Use `=~` (regex match) instead of `=` to support the `includeAll=true` wildcard `.*`.

### Loki Log Queries

Loki stream labels support namespace filtering natively:

```logql
# All logs from pods in a specific namespace
{namespace="$namespace", service_name="spring-boot-app"}

# With user filter via Structured Metadata
{namespace="$namespace"} | user_id="ash.ketchum"
```

For a Loki template variable (not backed by Prometheus):
```json
{
  "name": "namespace",
  "type": "query",
  "datasource": { "type": "loki", "uid": "loki" },
  "query": "label_values(namespace)"
}
```

### Tempo / TraceQL Queries

Tempo's datasource variables use `label_values` from the resource attributes. Namespace filters in TraceQL use the resource attribute syntax:

```traceql
{ resource.k8s.namespace.name = "$namespace" && span.user_id = "ash.ketchum" }
```

---

## 🔄 Pattern 4: Single Namespace Variable Across All Datasources

For dashboards that combine Prometheus + Loki + Tempo panels, define the `$namespace` variable once from Prometheus and reference `$namespace` in each panel regardless of its datasource:

```
Prometheus: {namespace=~"$namespace"}
Loki:       {namespace="$namespace"}
Tempo:      { resource.k8s.namespace.name = "$namespace" }
```

---

## 📋 Applying to Custom Dashboards in This Stack

| Dashboard File | Variable Needed | Query to Update |
| :--- | :--- | :--- |
| [`red-metrics-dashboard.json`](../deployment/common/dashboards/red-metrics-dashboard.json) | `$namespace` | `pokemon_controller_seconds_count`, `pokemon_controller_seconds_bucket` |
| [`debezium-monitoring.json`](../deployment/common/dashboards/debezium-monitoring.json) | `$namespace` | All `debezium.*` metric selectors |
| [`node-exporter.json`](../deployment/common/dashboards/node-exporter.json) | `$namespace`, `$node` | Node-level metrics |

### Step-by-step for `red-metrics-dashboard.json`:
1. Add the `$namespace` templating block (from Pattern 2 above) to the `templating.list` array.
2. Update each `expr` field: `pokemon_controller_seconds_count` → `pokemon_controller_seconds_count{namespace=~"$namespace"}`.
3. Reload the dashboard via the Grafana UI or re-apply the ConfigMap: `kubectl rollout restart deployment/grafana -n monitoring`.

---

## 🏆 Best Practice Summary

| Best Practice | Detail |
| :--- | :--- |
| Always use `=~` (regex) | Allows `$namespace` = `.*` to mean "all namespaces" without breaking single-select. |
| Default to `monitoring` | Set `current.value = "monitoring"` so the dashboard is useful immediately without a selection. |
| Chain `$pod` after `$namespace` | Use `kube_pod_info{namespace=~"$namespace"}` as the pod variable query so it auto-narrows. |
| Add `refresh: 2` | Refreshes label values on every dashboard load to pick up new namespaces dynamically. |
| For community dashboards | Most community dashboards from Grafana.com already include `$namespace`; import them as-is and check the variable datasource UIDs match (`prometheus`, `loki`). |
