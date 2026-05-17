# 📊 Debezium Embedded Metrics (Dynamic JMX Bridge)

This project demonstrates how to monitor **Debezium Embedded** by dynamically bridging its native JMX MBeans into the Spring Boot **Micrometer** registry.

## 🚀 The Approach: Dynamic JMX Bridge

Instead of hardcoding specific metrics, we use a custom `DebeziumMetricsBinder` that automatically discovers all MBeans under the `debezium.*` domain and registers their attributes as Micrometer Gauges.

### 1. Key Features
*   **Auto-Discovery:** Automatically finds new MBeans as connectors start or stop.
*   **Domain Search:** Scans `debezium.*` to capture all native Debezium metrics.
*   **Tag Mapping:** Converts JMX ObjectName properties (e.g., `context=streaming`, `type=connector-metrics`) into Micrometer **Tags**.
*   **Database Identification:** Automatically extracts the database type (e.g., `mongodb`) from the JMX domain and adds it as a `db_type` tag.
*   **Normalized Names:** Converts PascalCase JMX attributes into standard Prometheus-friendly snake_case names (e.g., `MilliSecondsBehindSource` becomes `debezium.milli_seconds_behind_source`).
*   **Self-Healing:** Periodic scans ensure that metrics are registered even if Debezium starts after the application context.

### 2. Implementation
The `DebeziumMetricsBinder.java` performs a periodic scan (every 30 seconds) of the MBean server. This requires **`@EnableScheduling`** to be present in your `@SpringBootApplication` class.

```java
// Patterns used for discovery
ObjectName debeziumPattern = new ObjectName("debezium.*:*");
```

### 3. Dependencies
We added the following to `pom.xml`:
- `io.debezium:debezium-bom:3.5.0.Final`
- `io.debezium:debezium-connector-mongodb`
- `org.jolokia:jolokia-support-spring:2.1.2` (JMX-to-HTTP bridge)
- `lombok` (For logging and concurrent collection helpers)

---

## 🧠 Learnings

### Why a Dynamic Bridge?
1.  **Zero Maintenance:** If Debezium adds new metrics in a future version, they will automatically appear in your Prometheus endpoint without any code changes.
2.  **Rich Context:** By mapping JMX properties to tags, you can easily filter metrics in Grafana by connector name, task ID, or context (e.g., `{context="streaming"}`).
3.  **Unified Scraping:** All metrics are served from the standard `/actuator/prometheus` endpoint.

### The "Lazy Registration" Pattern
Debezium Embedded starts in a background thread. String-based metrics (like `CapturedTables`) may be empty `[]` during the first few seconds of startup. 
*   **The Issue:** Micrometer Tags are **immutable**. If we register a metric with an empty `value` tag, it will stay empty forever.
*   **The Solution:** The `DebeziumMetricsBinder` implements a **Lazy Registration** check. It skips registration for string metrics if the value is currently empty, allowing a future 30-second scan to catch and register the populated value.

---

## 🔍 Verification & Debugging

### 1. Prometheus Metrics (Production Monitoring)
Used for Grafana dashboards and historical alerting.
*   **Endpoint:** `http://localhost:8080/actuator/prometheus`
*   **Usage:** Search for `debezium_` to see time-series data.

### 2. Jolokia REST API (Ad-hoc Debugging)
Used as a "Developer Tool" to inspect the **Ground Truth** of all MBeans without needing JConsole or a debugger.
*   **Endpoint:** `http://localhost:8080/actuator/jolokia`
*   **Authentication:** Requires Basic Auth (`user:password`).

**Useful Debugging Queries:**
*   **List all MBeans:**
    `GET /actuator/jolokia/list/debezium.mongodb`
*   **Read Captured Tables (Streaming):**
    `GET /actuator/jolokia/read/debezium.mongodb:context=streaming,server=kx-connector,task=0,type=connector-metrics/CapturedTables`
*   **Inspect Last Event Position:**
    `GET /actuator/jolokia/read/debezium.mongodb:context=streaming,server=kx-connector,task=0,type=connector-metrics/LastEvent`

---

## 📖 Metric Reference

Metrics are categorized by their JMX `context` tag: `snapshot` (initial data load) and `streaming` (real-time change capture). The `DebeziumMetricsBinder` automatically converts the PascalCase JMX attributes into snake_case Prometheus names.

### 1. Performance & Health (Numeric Gauges)

| Prometheus Metric Name | JMX Attribute Name | Type | Description |
| :--- | :--- | :--- | :--- |
| `debezium_milli_seconds_behind_source` | `MilliSecondsBehindSource` | **Lag** | The "freshness" of your data. The time (ms) between the DB change and Debezium processing. |
| `debezium_milli_seconds_since_last_event` | `MilliSecondsSinceLastEvent` | **Idleness** | Time elapsed since the connector last saw a change. |
| `debezium_total_number_of_events_seen` | `TotalNumberOfEventsSeen` | **Count** | Total documents processed since startup. |
| `debezium_total_number_of_create_events_seen` | `TotalNumberOfCreateEventsSeen` | **Count** | Documents inserted since startup. |
| `debezium_total_number_of_update_events_seen` | `TotalNumberOfUpdateEventsSeen` | **Count** | Documents updated since startup. |
| `debezium_total_number_of_delete_events_seen` | `TotalNumberOfDeleteEventsSeen` | **Count** | Documents deleted since startup. |
| `debezium_queue_remaining_capacity` | `QueueRemainingCapacity` | **Buffer** | Shows if the internal buffer is filling up. |

### 2. Status & Flags (Boolean Gauges)
Mapped to `1.0` (True) and `0.0` (False).

| Prometheus Metric Name | JMX Attribute Name | Description |
| :--- | :--- | :--- |
| `debezium_connected` | `Connected` | Indicates if the connector is currently connected to the MongoDB ReplicaSet. |
| `debezium_snapshot_completed` | `SnapshotCompleted` | Indicates if the initial snapshot phase has finished. |
| `debezium_snapshot_running` | `SnapshotRunning` | Indicates if Debezium is currently performing a bulk load of existing data. |

### 3. Metadata & Context (Info Metrics)
Strings and Arrays are mapped to a Gauge with a constant value of `1.0`, with the metadata stored in a `value` tag.

| Prometheus Metric Name | JMX Attribute Name | Tag: `value` Content |
| :--- | :--- | :--- |
| `debezium_last_event_info` | `LastEvent` | Contains the **SourceEventPosition** (Oplog offset) and the Primary Key of the last document. |
| `debezium_captured_tables_info` | `CapturedTables` | A comma-separated list of the collections/tables currently being watched. |
| `debezium_source_info_struct_maker_info` | `SourceInfoStructMaker` | Details about the plugin used to generate the source metadata. |

**Example:**
`debezium_last_event_info{value="position: {ord: 1}, key: {\"id\": \"...\"}"} 1.0`
*Interpretation: Provides a "high-water mark" pointer for where the connector would resume after a restart.*

---

## 🛠 Troubleshooting

*   **Metric shows `-1.0`**: This is common for `MilliSecondsBehindSource` if the connector has not yet processed a single event in that context.
*   **Missing Tags**: If `db_type` is missing, check that the connector is properly initialized.
*   **Immutable Tags**: Note that info metrics (`_info`) use labels for string data. Because Prometheus labels are immutable, these strings typically represent the *initial* value seen during the first scrape of that metric instance.
