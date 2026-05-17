# ADR: Grafana Visualization & Alerting

## Status
Proposed

## Context
Grafana serves as the central control plane for the LGTM stack. It must provide high-availability visualization, seamless cross-telemetry correlation, and reliable alerting while ensuring dashboard definitions are version-controlled and resistant to pod-level volatility.

## Decision
1.  **Deployment:** Baseline set to 1 replica, designed for horizontal scaling to 3+ replicas.
2.  **Dashboard Management:** Use the **Grafana Sidecar** pattern to provision dashboards as code from ConfigMaps, ensuring reproducibility.
3.  **State Management:** Use an **external, HA-capable database (PostgreSQL)** for user sessions, preferences, and dashboard state to ensure survival across pod restarts.
4.  **Alerting:** 
    *   **Dispatch:** Centralized via **Alertmanager**, routing to Mattermost.
    *   **Logic:** Alerting rules must use `absent()` to detect missing metrics (service dead-man switch).
5.  **Correlation:** All dashboards must support "drill-down" (Metric -> Trace -> Log) navigation using **Structured Metadata**.

## Rationale
- **Resilient Single-Instance Pattern:** Externalizing state to PostgreSQL and using Sidecar provisioning provides HA-like data persistence without the operational overhead of replica synchronization.
- **Service Graphs:** Automates dependency mapping, a key requirement for debugging microservice latency.
- **Reliable Alerting:** Using Alertmanager and `absent()` logic ensures the stack remains actionable even when components are entirely offline.

## Implementation Source of Truth
- **Provisioning:** `sidecar.dashboards.enabled: true`
- **Database:** `grafana.ini [database] type = postgres`
- **Dashboard Label:** `grafana_dashboard=1`

## Technical Specification & Mapping

| YAML Path / Component | Logic / Value | Purpose | Requirement Link |
| :--- | :--- | :--- | :--- |
| `replicas` | `1` | Efficient baseline; scale-ready. | `req/grafana.md` Sec 2.0 |
| `sidecar.dashboards` | `enabled: true` | Automates dashboard deployment via Git/CMs. | `req/grafana.md` Sec 3.0 |
| `database.type` | `postgres` | Persists user state across pod restarts. | `req/grafana.md` Sec 2.0 |
| `alerting` | `Alertmanager` | Centralized notification hub. | `req/grafana.md` Sec 4.0 |

## Consequences
- **Positive:** GitOps-ready dashboard management and consistent user state.
- **Negative:** Requires external managed database (e.g., Cloud SQL or K8s Postgres Operator).
- **Risk:** Grafana performance is dependent on the latency to the PostgreSQL database.
