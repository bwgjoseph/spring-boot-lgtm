# Issues to Resolve

- [ ] **Prometheus Alerting Rules Loading:** Current alerting rules (`alerting_rules.yml`) in Prometheus are appearing empty (`{}`) even after configuration changes. Requires further investigation into how `prometheus-community/prometheus` Helm chart processes `serverFiles` vs `extraConfigmapMounts`.
