# Project Context: Spring Boot LGTM Observability Sandbox

## Project Goal
To maintain a production-hardened observability sandbox using the Grafana LGTM stack (Loki, Grafana, Tempo, Mimir/Prometheus) with Grafana Alloy.

## Current Architecture
- **Alloy:** DaemonSet topology for node-local ingestion, tail-based sampling, and multi-exporter gateway. Uses 10-20Gi SSD for WAL durability.
- **Loki:** SimpleScalable mode, S3 persistence, Replication Factor 3, TSDB schema (v13), with 30-day compactor retention.
- **Tempo:** Scalable Monolithic mode (3 replicas), S3 backend, Persistent 20Gi SSD WAL, and Metrics-Generator enabled.
- **MinIO:** Standalone mode on SSD storage, serving as the S3-compatible backend.
- **Grafana:** Single-instance "Scale-Ready" (Postgres + Sidecar Provisioning).
- **Application:** Spring Boot 3.5 using OTLP/gRPC to point to node-local Alloy via ClusterIP.

## Documentation Strategy
- **`README.md`**: Entry point with architecture diagram and lifecycle commands (`task alloy`, `task verify:alloy`, `task uninstall:alloy`).
- **`ARCHITECTURE.md`**: High-level system map and visual overview.
- **`ADR/`**: Individual Architectural Decision Records with traceability matrices.
- **`requirements/`**: Component-specific technical standards.
- **`verification/`**: Modular smoke-test plans (`VERIFICATION_PLAN_*.md`) and PowerShell scripts (`verify-*.ps1`).

## Key Operational Patterns
- **Local vs. Clustered Data Flow:**
    - Local (Logs/Metrics): Node-local collection to minimize network hops.
    - Clustered (Traces): TraceID affinity load-balancing for accurate tail-based sampling.
- **Resilience:** WAL persistence (SSD) and graceful shutdown (60s) for all storage components.
- **Security:** Kubernetes RBAC mandatory for metadata enrichment; secrets for S3/DB access.

## Pending Tasks / Roadmap
- [ ] **Mimir (Metrics Scalability):** Final deep-dive into cardinality guardrails and remote-write ingestion.
- [ ] **External Gateway Integration:** Future-proofed via multi-exporter config in Alloy.
- [ ] **OIDC/Keycloak:** Future requirement for centralized auth.
- [ ] **Storage Infrastructure:** Verify RWX vs RWO capabilities (via `kubectl get sc`).
