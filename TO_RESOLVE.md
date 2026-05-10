# Issues to Resolve

- [ ] **Prometheus Alerting Rules Loading:** Current alerting rules (`alerting_rules.yml`) in Prometheus are appearing empty (`{}`) even after configuration changes. Requires further investigation into how `prometheus-community/prometheus` Helm chart processes `serverFiles` vs `extraConfigmapMounts`.
- [ ] **Alloy Configuration Syntax (v1.16.0):** Persistent `CrashLoopBackOff` due to schema-incompliant `.alloy` configuration.
    - **Filter Processor:** `otelcol.processor.filter` is failing with OTTL syntax errors. Specifically, `unexpected token "matches"` when trying to filter by `resource.attributes["k8s.namespace.name"]`.
    - **Loadbalancing Exporter:** Conflicting errors between `endpoint` being an unrecognized attribute in `client` and `grpc` being an unrecognized block. Requires definitive schema verification for how OTLP loadbalancing targets are defined.
    - **Log Tailing:** `loki.source.kubernetes` is not discovering targets even when `/var/log/pods` is mounted. Likely requires a specialized relabeling or path-matching strategy for local container runtimes.
