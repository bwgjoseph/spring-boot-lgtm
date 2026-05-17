# ADR: Application Telemetry & Operations

## Status
Proposed

## Context
The Spring Boot application is the primary telemetry generator. It must provide consistent, verifiable OTLP data that can be traced end-to-end to ensure the reliability of the observability stack.

## Decision
1.  **OTLP Connectivity:** Applications must target node-local Alloy instances for OTLP traffic to avoid gRPC load-balancing "stickiness" issues.
2.  **Downward API:** Use the Kubernetes Downward API to inject `status.hostIP` for node-aware OTLP targeting (`OTEL_EXPORTER_OTLP_ENDPOINT=http://$(NODE_IP):4317`).
3.  **Deployment Environment:** Applications must include standard `OTEL_RESOURCE_ATTRIBUTES` (e.g., `deployment.environment`) to allow storage backends (Loki/Mimir) to segment data.
4.  **Verification Strategy:** Automated E2E verification depends on scripted traffic generation (`trigger-api.ps1`) and an active MongoDB ReplicaSet for CDC pipelines.

## Rationale
- **OTLP Load Balancing:** Targeting local Alloy instances ensures stable, low-latency gRPC connections, bypassing standard K8s service load-balancer limitations.
- **Environment Segmentation:** Consistent labeling via `OTEL_RESOURCE_ATTRIBUTES` is required for production-readiness and logical separation between dev/prod buckets.
- **Verification Integrity:** Deterministic traffic generation allows for continuous verification of the entire pipeline, from application start to backend visibility.

## Implementation Source of Truth
- **OTEL Ingestion:** OTLP gRPC/HTTP via local Node IP.
- **Env Attributes:** `OTEL_RESOURCE_ATTRIBUTES` injection.
- **Test Scripts:** `verification/` scripts for traffic and CDC validation.

## Consequences
- **Positive:** Reliable, high-throughput telemetry; consistent environment segmentation.
- **Negative:** Requires application manifests to be "Kubernetes-aware" (Downward API dependency).
- **Risk:** Trace correlation fails if Downward API is not configured.
