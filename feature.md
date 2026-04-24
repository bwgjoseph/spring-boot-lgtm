# 🚀 Observability Stack: Feature Guide

Welcome to the Spring Boot LGTM Sandbox! This guide explains the high-level features of this observability setup. If you're new to the "Grafana Stack" (Loki, Grafana, Tempo, Mimir/Prometheus), this page will help you understand what's happening "under the hood."

---

## 1. The Three Pillars of Observability

This setup integrates the three core types of data you need to understand a running system:

### 📈 Metrics (Prometheus)
*   **What it is:** Numeric data over time (e.g., "CPU usage is 45%").
*   **In this setup:** We use **Micrometer** to export Spring Boot metrics and **Node Exporter/KSM** for Kubernetes health.
*   **Feature:** You can see how many requests your app is handling and if it's running out of memory.

### 📜 Logs (Loki)
*   **What it is:** The text output from your application (`log.info(...)`).
*   **In this setup:** **Grafana Alloy** automatically scrapes logs from every container and adds metadata like `pod_name` and `namespace`.
*   **Feature:** Logs are "index-free," making them extremely fast to search and cheap to store.

### 🕸️ Traces (Tempo)
*   **What it is:** A "receipt" for a single request as it travels through your code.
*   **In this setup:** Every time you call `/pokemon/{id}`, a **Trace ID** is generated. It tracks every method call and database query.
*   **Feature:** You can see exactly which line of code is slow or where an error originated.

---

## 2. Visualizing Your Architecture

One of the most powerful aspects of this stack is its ability to automatically map your system without you drawing a single line.

### 🗺️ Service Graph (The "System" View)
Tempo's `metricsGenerator` scans your traces and automatically draws a map of how services interact.
*   **What it shows:** Arrows between services (e.g., `spring-boot-app` -> `pokeapi`), request rates, and error percentages.
*   **The Benefit:** You can instantly see if a downstream API is failing or causing a bottleneck for your entire system.
*   **Where to find it:** In Grafana, go to **Explore -> Tempo** and select the **Service Graph** tab.

### 🌐 Node Graph (The "Request" View)
While Service Graphs show the *whole system*, the Node Graph focuses on a **single request**.
*   **What it shows:** A visual flowchart of every "span" (step) within a specific trace.
*   **The Benefit:** It makes complex, deeply nested traces much easier to read than a standard timeline view. You can see precisely where time is being spent in a visual hierarchy.
*   **Where to find it:** Inside any Trace view in Tempo, click the **Node Graph** toggle at the top.

---

## 3. "Advanced" Features (Day 2 Ready)

This sandbox goes beyond basic connectivity to include advanced observability patterns:

### 🎯 Exemplars (The "Magic" Link)
In the Prometheus metrics graphs, you'll see small dots. These are **Exemplars**.
*   **The Benefit:** If you see a spike in latency, you can click a dot to jump **directly** to the specific Trace that caused that spike. No more searching for "what happened at 2 PM."

### 🔗 Log-Trace Correlation
*   **Trace-to-Log:** While looking at a Trace in Tempo, click "Logs for this span" to see every log message written *during that specific request*.
*   **Log-to-Trace:** While looking at a Log in Loki, click the "View Trace" button next to the Trace ID to see the full execution timeline of that request.
*   **Deeper Dive:** See [learning_trace_to_log.md](./learning_trace_to_log.md) for detailed troubleshooting of this feature.

### 📊 Dynamic Debezium Monitoring
The sandbox includes an advanced **Dynamic JMX-to-Micrometer Bridge** for Debezium Embedded.
*   **The Benefit:** It automatically discovers all Debezium MBeans and exposes them as Prometheus metrics with rich contextual tags.
*   **Full Spectrum:** Unlike basic bridges, this implementation captures **Numeric** gauges (Lag, Throughput), **Boolean** flags (Connected, Snapshot Status), and **String/Array** metadata (Captured Collections, Last Event Position) as "Info" metrics.
*   **Zero Configuration:** New connectors or collections are detected and monitored automatically without code changes.

### 🔔 Integrated Alerting (Alertmanager)
The sandbox includes a pre-configured **Alertmanager** to handle system and application health alerts.
*   **Local-first:** In sandbox mode, alerts are visible directly in the **Alertmanager Web UI** (port 9093).
*   **Production-ready:** Configured with advanced **Grouping** (`alertname`, `cluster`, `service`, `namespace`) to prevent alert fatigue.
*   **The Benefit:** Real-time notification of issues like high CPU, memory leaks, or service downtime.

---

## 4. Kubernetes Cluster Monitoring

We've enabled full visibility into the cluster itself, not just your Java app:
- **Cluster/Node Health:** CPU, RAM, and Disk usage for the underlying machines.
- **Pod Resources:** See exactly how much memory each container is using compared to its limit.
- **Auto-Discovery:** As soon as you deploy a new pod, it is automatically detected and monitored by **Grafana Alloy**.

---

## 4. How to use it as a Developer

### Instrumenting your Code
You don't need to learn complex OpenTelemetry APIs. We use the **Micrometer Observation API**:
1.  **Annotation:** Just add `@Observed` to a method.
2.  **MDC:** Your logs automatically include `[traceId, spanId, userId]` (idiomatic Java camelCase).
3.  **Snake_case in Grafana:** These are automatically mapped to `trace_id`, `span_id`, and `user_id` in Loki and Tempo for standard observability compliance.
4.  **Manual:** Use `Observation.createNotStarted(...)` for complex business logic.

### Exploration Workflow
1.  Open **Grafana** (localhost:3000).
2.  Go to **Explore**.
3.  Switch between **Loki**, **Prometheus**, and **Tempo** to see the different data types.
4.  Check the **Dashboards** folder for pre-built views of your cluster health.

---

## 🏗️ The "Brain": Grafana Alloy
This setup uses **Grafana Alloy** as the central traffic controller. It:
- Scrapes metrics from `/actuator/prometheus`.
- Collects logs from Kubernetes.
- Receives traces from your app.
- Performs **Tail-based Sampling** (e.g., "Keep 100% of errors, but only 10% of successful requests to save space").
