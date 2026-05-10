# ADR: Grafana Visualization & Alerting

## Status
Proposed

## Context
Grafana serves as the central control plane for the LGTM stack. It must provide high-availability visualization while ensuring that dashboard definitions are version-controlled and resistant to pod-level volatility.
## Decision
1.  **Deployment:** Single replica (for efficiency), designed to be scale-ready to 3+ replicas.
2.  **Dashboard Management:** Use the **Grafana Sidecar** pattern to provision dashboards as code from Git.
3.  **State Management:** Use an **external PostgreSQL database** to persist user state, alert definitions, and folder structures.
4.  **Alerting:** Rely on external **Alertmanager** for alert dispatching and Mattermost routing.

## Rationale
- **Resilient Single-Instance Pattern:** By using PostgreSQL and Sidecar provisioning, we gain 99% of HA benefits (no data loss) without the operational tax of replica synchronization and locking management. 
- **Scale-Ready:** Moving to 3 replicas is a simple configuration change (as all state is externalized to Postgres/Sidecar) when team traffic increases.

...

## Technical Specification & Mapping
This table maps the production implementation in `deployment/prod/values-grafana.yaml` to the architectural decisions and requirements.

| YAML Path / Component | Logic / Value | Purpose | Requirement Link |
| :--- | :--- | :--- | :--- |
| `replicas` | `1` | Efficient baseline; scale-ready. | `req/grafana.md` Sec 2.0 |
| `sidecar.dashboards` | `enabled: true` | Automates dashboard deployment via Git/CMs. | `req/grafana.md` Sec 3.0 |
| `database.type` | `postgres` | Persists user state across pod restarts. | `req/grafana.md` Sec 2.0 |

## Consequences
- **Positive:** GitOps-ready dashboard management and consistent user state.
- **Negative:** Requires external managed database (e.g., Cloud SQL or K8s Postgres Operator).
- **Risk:** Grafana performance is dependent on the latency to the PostgreSQL database.
