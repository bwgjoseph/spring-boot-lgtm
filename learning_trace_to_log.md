# 🧠 Learnings: Trace-to-Log Correlation

This document summarizes the investigation and troubleshooting of the **Trace-to-Log** correlation feature within the Spring Boot LGTM stack.

## ✅ What is Working
1.  **Log-to-Trace:** The "View Trace" button in Loki correctly extracts the `traceId` from the Spring Boot log format `[service,traceId,spanId,userId]` and links to Tempo.
2.  **Data Presence:** We verified via the Loki API that logs are searchable using the query: `{service_name="spring-boot-app"} | trace_id="<trace_id>"` (Structured Metadata).
3.  **App Alignment:** The `spring.application.name` in the Java app is aligned with the `service_name` label applied by Grafana Alloy (`spring-boot-app`).
4.  **MDC Population:** The `traceId` and `spanId` are correctly appearing in the application logs using idiomatic camelCase.
5.  **Metadata Extraction & Cleanup:** Grafana Alloy is now configured with a `loki.process` stage to extract camelCase IDs, promote them to **snake_case Structured Metadata**, and then **drop** the internal labels to keep Loki clean.

## 🔍 Root Cause Analysis

### 1. Label vs. Structured Metadata
Loki distinguishes between **Labels** (metadata like `service_name`) and **Structured Metadata** (searchable key-value pairs attached to the line).
*   By promoting IDs to Structured Metadata, we enable the "Trace" button in the Grafana UI without the performance cost of high-cardinality indexing.
*   We use the `| json` or `| logfmt` pattern internally, or simple metadata filtering: `| trace_id="xxx"`.

### 2. Case Sensitivity
*   **Java/MDC:** Uses `traceId`, `spanId`, `userId` (Standard Java).
*   **Alloy Transformation:** Acts as the bridge, capturing camelCase and saving as snake_case (`trace_id`, `span_id`, `user_id`) for LGTM ecosystem compatibility.

## 🛠️ Verified Manual Queries
If you want to verify the data manually in the Grafana "Explore" tab, use these formats:

| Type | Query |
| :--- | :--- |
| **Loki (Structured Metadata)** | `{service_name="spring-boot-app"} \| trace_id="trace_id_here"` |
| **Tempo (TraceQL)** | `{resource.service.name="spring-boot-app" && .trace_id="trace_id_here"}` |
