# 🧠 Learnings: Trace-to-Log Correlation

This document summarizes the investigation and troubleshooting of the **Trace-to-Log** correlation feature within the Spring Boot LGTM stack.

## ✅ What is Working
1.  **Log-to-Trace:** The "View Trace" button in Loki correctly extracts the `traceId` from the Spring Boot log format `[service,trace_id,span_id]` and links to Tempo.
2.  **Data Presence:** We verified via the Loki API that logs are searchable using the query: `{service_name="spring-boot-app"} |= "<trace_id>"`.
3.  **App Alignment:** The `spring.application.name` in the Java app is now aligned with the `service_name` label applied by Grafana Alloy (`spring-boot-app`).
4.  **MDC Population:** The `trace_id` and `span_id` are correctly appearing in the application logs after adding the `TracingObservationHandler` and `spring-boot-starter-aop`.
5.  **Metadata Extraction:** Grafana Alloy is now configured with a `loki.process` stage to extract `trace_id` and `span_id` from the log line and promote them to **Structured Metadata**.

## ❌ What is NOT Working
1.  **Tempo UI Button:** The "Logs for this span" button in the Tempo UI (managed by `tracesToLogsV2`) fails to return results, even when the generated query looks correct. This may be because it expects a **Label** rather than **Structured Metadata**.
2.  **UI DataLinks:** Manual `dataLinks` configured in the Tempo datasource did not appear in the span details panel as expected.

## 🔍 Root Cause Analysis

### 1. Label vs. Text Search
Loki distinguishes between **Labels** (metadata like `service_name`) and **Log Content** (the actual text line). 
*   In this setup, `trace_id` is **NOT** a Loki label; it is part of the log string.
*   Therefore, the correlation **must** use the `|=` (line filter) operator.
*   Grafana's automatic Trace-to-Log mechanism often tries to use `trace_id` as a label, which fails in our setup.

### 2. Variable Scoping in Grafana
Accessing tags in Trace-to-Log `customQuery` templates is highly sensitive:
*   Standard Span Tags: `${__span.tags["key"]}`
*   Resource Attributes: `${__span.resource["service.name"]}` (This is where OTEL usually puts service metadata).
*   Trace Context: `${__trace.traceId}`

### 3. Provisioning Sensitivity
We learned that the Grafana datasource API/UI is sensitive to:
*   **Casing:** Use `filterByTraceID` (capital ID) for V2 configuration.
*   **Structure:** The `datasources.yaml` must be a map under the `datasources` key in the Helm `values.yaml`.

## 🛠️ Verified Manual Queries
If you want to verify the data manually in the Grafana "Explore" tab, use these formats:

| Type | Query |
| :--- | :--- |
| **Loki (Search by Trace ID)** | `{service_name="spring-boot-app"} \|= "trace_id_here"` |
| **Loki (Raw Labels check)** | `{service_name="spring-boot-app"}` |
| **Tempo (TraceQL)** | `{resource.service.name="spring-boot-app" && .traceId="trace_id_here"}` |

## 🚀 Next Steps for Resolution
*   **Refine the `customQuery`:** Continue experimenting with `${__span.resource["service.name"]}` versus `${__span.tags["service.name"]}` once you return.
*   **Labeling at the Source:** Consider updating the Grafana Alloy configuration to extract the `trace_id` from the log line and promote it to a **Loki Label**. This would allow the "standard" automatic filtering to work without complex custom queries.
