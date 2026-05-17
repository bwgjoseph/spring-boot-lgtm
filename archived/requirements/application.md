# Application: Operational Prerequisites

## 1. Role & Responsibility (The "Job")
The Spring Boot application acts as the primary traffic generator for the observability stack. Its "job" is to generate valid OTLP telemetry (logs, metrics, traces) and business data (via Pokemon API) that can be verified end-to-end.

## 2. Telemetry Connectivity
- **OTLP Endpoint:** The application must be configured to point to the **node-local Alloy instance**.
- **Downward API:** The pod must inject the host node's IP using the Downward API (`status.hostIP`).
- **Configuration:** The `MANAGEMENT_OTLP_TRACING_ENDPOINT` environment variable is the primary mechanism for directing trace traffic. If this is misconfigured, traces will not correlate correctly or will suffer from gRPC "stickiness."

## 3. Verification Dependencies
- **Traffic Generation:** End-to-end verification depends on the `verification/trigger-api.ps1` script to stimulate the application's endpoints.
- **CDC Pipeline:** The application requires an active MongoDB ReplicaSet to demonstrate Debezium CDC functionality.

## 4. Operational Guardrails
- **Environment Context:** Must include `OTEL_RESOURCE_ATTRIBUTES` (e.g., `deployment.environment`) to allow Alloy and backend sinks to distinguish between production and dev data.
