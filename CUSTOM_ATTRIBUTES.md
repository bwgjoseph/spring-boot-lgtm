# 🏷️ Custom Attributes & Metadata Guide

This document tracks how custom infrastructure (Resource) and business (Span) attributes are mapped across the LGTM stack.

## 🏗️ Infrastructure Attributes (Resource Attributes)
These are added to every Trace/Span.

| Attribute Name | Source | Visible In |
|----------------|--------|------------|
| `deployment.environment` | `OTEL_RESOURCE_ATTRIBUTES` (Env Var) | Tempo |
| `service.version` | `OTEL_RESOURCE_ATTRIBUTES` (Env Var) | Tempo |
| `k8s.pod.name` | **Grafana Alloy Enrichment** (Source IP lookup) | Tempo |
| `k8s.namespace.name` | **Grafana Alloy Enrichment** (Source IP lookup) | Tempo |
| `k8s.node.name` | **Grafana Alloy Enrichment** (Source IP lookup) | Tempo |

### 🔄 Enrichment Flow: K8s Metadata
1. **App:** Sends OTLP trace via gRPC to Alloy.
2. **Alloy:** `otelcol.processor.k8sattributes` detects the source IP of the pod.
3. **Alloy:** Queries K8s API (cached) to find the Pod name, Namespace, and Node.
4. **Alloy:** Injects these as Resource Attributes into the Span before sending to Tempo.

---

## 👤 Security & Business Attributes
We follow a "Best of Both Worlds" approach: **camelCase in Java/Logs** and **snake_case in LGTM/Grafana**.

| Java/Log Attribute | LGTM/Metadata Attribute | Source | Correlation Strategy |
|--------------------|-------------------------|--------|----------------------|
| `userId` | `user_id` | `SecurityContext` | **Baggage (Remote)** + **MDC Sync** |
| `traceId` | `trace_id` | Micrometer Tracing | Native MDC + Regex Mapping |
| `spanId` | `span_id` | Micrometer Tracing | Native MDC + Regex Mapping |

### 🔄 Data Flow: `userId` -> `user_id`
1. **Spring Security:** Authentication provides the username.
2. **ObservationHandler:** Adds `user_id` to the Observation context (Span Attribute for Tempo).
3. **Micrometer Tracing:** 
   - Syncs `userId` to **SLF4J MDC** (configured in `application.yaml`).
   - Propagates `userId` via HTTP headers (Baggage).
4. **Log Pattern:** `[%X{userId:-}]` ensures the ID is printed in logs.
5. **Grafana Alloy:** `loki.process` regex extracts `userId` from the log and promotes it to **Loki Structured Metadata** as `user_id`. A `stage.label_drop` then removes the redundant `userId` capture group.

---

## 🔍 How to Filter/Search

### In Loki (Grafana Logs)
Look at the **Structured Metadata** panel or query directly:
```logql
{service_name="spring-boot-app"} | user_id="user"
```

### In Tempo (Grafana Traces)
Search by tag in the Trace Explorer:
```
user_id="user"
deployment.environment="staging"
```

---

## 🛠️ Configuration Checklist
- [x] `pom.xml`: Dependencies for security and tracing are included.
- [x] `application.yaml`: `management.tracing.baggage` and MDC correlation configured with idiomatic Java camelCase (`userId`, `traceId`, `spanId`).
- [x] `deployment.yaml`: `OTEL_RESOURCE_ATTRIBUTES` set for static metadata.
- [x] `values-alloy.yaml`: `loki.process` regex captures camelCase IDs and maps them to standard observability snake_case (`user_id`, `trace_id`, `span_id`).
- [x] `values-alloy.yaml`: `stage.label_drop` removes redundant internal capture groups.
