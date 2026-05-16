# Issues to Resolve

- [ ] **Prometheus Alerting Rules Loading:** Current alerting rules (`alerting_rules.yml`) in Prometheus are appearing empty (`{}`) even after configuration changes. Requires further investigation into how `prometheus-community/prometheus` Helm chart processes `serverFiles` vs `extraConfigmapMounts`.
- [ ] **Loki HA Caching Resource Mapping:** Memcached sub-charts for Loki are currently disabled in `prod-local` due to incorrectly mapped high-resource defaults. Requires proper sub-chart resource configuration to enable in resource-constrained sandboxes.
