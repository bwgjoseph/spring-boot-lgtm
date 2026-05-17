# ADR: Alertmanager Dispatch & Notification

## Status
Proposed

## Context
Alertmanager is the notification dispatcher for the production cluster, handling alert routing, grouping, and deduplication for all metrics and infrastructure events.

## Decision
1.  **Dispatch Engine:** Centralized via the standalone Alertmanager service (or bundled Prometheus-community chart deployment).
2.  **Routing:** All critical alerts must be routed to **Mattermost**.
3.  **Deduplication:** Alerts must be grouped by `['alertname', 'cluster', 'service', 'namespace']`.
4.  **Delivery Efficiency:** Set `group_wait: 30s` and `group_interval: 5m`.
5.  **Resolution Visibility:** `send_resolved: true` is mandatory.

## Rationale
- **Consolidation:** Grouping by essential labels prevents notification fatigue during infrastructure-wide outages.
- **Durable Notification:** Mattermost provides a persistent channel for incident response.
- **Visibility:** Enabling `send_resolved` prevents "zombie alerts" and provides clear closure for incident management.

## Implementation Source of Truth
- **Config Path:** `prometheus-alert-rules` ConfigMap (Prometheus/Mimir) + Alertmanager routing configuration.
- **Routing:** `group_by: ['alertname', 'cluster', 'service', 'namespace']`

## Consequences
- **Positive:** Reduces noise through intelligent grouping.
- **Negative:** Dependent on external notification channel (Mattermost) availability.
