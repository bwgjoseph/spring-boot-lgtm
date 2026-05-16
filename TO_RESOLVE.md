# Issues to Resolve

- [ ] **Prometheus Alerting Rules Loading:** Current alerting rules (`alerting_rules.yml`) in Prometheus are appearing empty (`{}`) even after configuration changes. Requires further investigation into how `prometheus-community/prometheus` Helm chart processes `serverFiles` vs `extraConfigmapMounts`.
- [ ] **Loki HA Caching Resource Mapping:** Memcached sub-charts for Loki are currently disabled in `prod-local` due to incorrectly mapped high-resource defaults. Requires proper sub-chart resource configuration to enable in resource-constrained sandboxes.
- [ ] **Mimir Migration Strategy:** Implement `swap:mimir` to replace local Prometheus storage with Mimir (Monolithic HA-ready mode).
- [ ] **Prometheus Remote Write Configuration:** Configure existing Prometheus Helm release to act as a pass-through by enabling `remoteWrite` to the Mimir endpoint.
- [ ] **Grafana Datasource Migration:** Update Grafana to transition from `Prometheus` datasource to `Mimir` datasource upon completion of the Mimir swap.
- [ ] **Alerting Rules Migration:** Migrate alerting rules from Prometheus `serverFiles` to Mimir's `ruler` configuration.
- [ ] **Alloy High-Cardinality Firewall:** Implement formal filtering/drop rules for high-cardinality labels to protect Loki and Mimir indexes.
- [ ] **Alloy External Forwarding (Gateway Pattern):** Configure Alloy to mirror trace/log telemetry to external gateways for cross-team data sharing.
