# TODO

- [x] In tempo, able to click and zoom into logs (trace-to-log) - see [Trace-to-Log: No results found (Zero-width time range)](./TROUBLESHOOT.md#trace-to-log-no-results-found-zero-width-time-range)
- [x] Review https://grafana.com/docs/loki/latest/send-data/k8s-monitoring-helm/
- [ ] Enable alerting
- [ ] RED metrics
- [x] Migrate loki (Effective March 16, 2026, the Grafana Loki Helm chart will be forked to a new repository . The chart in the Loki repository will continue to be maintained for GEL users only. See https://github.com/grafana/loki/issues/20705 for details.)
- [ ] Update configuration to be production ready
    - [ ] Ensure retention period is 1 month
- [ ] Setup grafana-mcp
- [x] Service graph is not working (See [SERVICE_GRAPH_ISSUE](SERVICE_GRAPH_ISSUE.md))
- [ ] How to integrate and scape JMX metrics (See https://blog.frankel.ch/tip-opentelemetry-projects/)
- [ ] Integrate with Pyroscope
- [ ] Figure out how to publish data from alloy to different sources