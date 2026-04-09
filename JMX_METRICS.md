# 📊 Debezium Embedded Metrics (Dynamic JMX Bridge)

This project demonstrates how to monitor **Debezium Embedded** by dynamically bridging its native JMX MBeans into the Spring Boot **Micrometer** registry.

## 🚀 The Approach: Dynamic JMX Bridge

Instead of hardcoding specific metrics, we use a custom `DebeziumMetricsBinder` that automatically discovers all MBeans under the `debezium.*` domain and registers their numeric attributes as Micrometer Gauges.

### 1. Key Features
*   **Auto-Discovery:** Automatically finds new MBeans as connectors start or stop.
*   **Tag Mapping:** Converts JMX ObjectName properties (e.g., `context=streaming`, `type=connector-metrics`) into Micrometer **Tags**.
*   **Normalized Names:** Converts PascalCase JMX attributes into standard Prometheus-friendly snake_case names (e.g., `MilliSecondsBehindSource` becomes `debezium.milli_seconds_behind_source`).
*   **Self-Healing:** Periodic scans ensure that metrics are registered even if Debezium starts after the application context.

### 2. Implementation
The `DebeziumMetricsBinder.java` performs a periodic scan (every 30 seconds) of the MBean server. This requires **`@EnableScheduling`** to be present in your `@SpringBootApplication` class.

```java
// Pattern used for discovery
ObjectName pattern = new ObjectName("debezium.*:*");

// Example of dynamic gauge registration
Gauge.builder(metricName, mBeanServer, s -> {
    Object val = tryGetAttribute(name, attr.getName());
    return (val instanceof Number n) ? n.doubleValue() : 0.0;
})
.tags(tags) // Captured from JMX properties
.register(registry);
```

### 3. Dependencies
We added the following to `pom.xml`:
- `io.debezium:debezium-bom:3.5.0.Final`
- `io.debezium:debezium-connector-mongodb`
- `lombok` (For logging and concurrent collection helpers)

---

## 🧠 Learnings

### Why a Dynamic Bridge?
1.  **Zero Maintenance:** If Debezium adds new metrics in a future version, they will automatically appear in your Prometheus endpoint without any code changes.
2.  **Rich Context:** By mapping JMX properties to tags, you can easily filter metrics in Grafana by connector name, task ID, or context (e.g., `{context="streaming"}`).
3.  **Unified Scraping:** All metrics are served from the standard `/actuator/prometheus` endpoint.

### The "Race Condition" Solution
Debezium Embedded starts in a background thread and takes time to connect to MongoDB. It does **not** register JMX MBeans until the connection is established. By using a **Scheduled Scan** every 30 seconds, we ensure the bridge eventually "sees" and registers the metrics without failing at startup.

## 🔍 Verification

### 1. Check the Prometheus Endpoint
Visit `http://localhost:8080/actuator/prometheus` while the app is running.

### 2. Search for Debezium Metrics
```powershell
curl -s http://localhost:8080/actuator/prometheus | Select-String "debezium"
```
