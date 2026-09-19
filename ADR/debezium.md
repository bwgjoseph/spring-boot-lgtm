# ADR: Debezium Embedded CDC with MongoDB & JMX Observability Bridge

## Status
Accepted

## Context
The Spring Boot application must stream real-time database change events from MongoDB (Change Data Capture) and expose the health of the CDC pipeline as first-class observability data in Prometheus/Grafana. The implementation must handle transient MongoDB connectivity issues gracefully, avoid data duplication from offset management failures, and operate as an **embedded** engine (within the Spring Boot JVM process) rather than as a standalone Kafka Connect cluster.

---

## Architecture & Data Flow

### 1. Embedded Debezium CDC + Observability Pipeline
```mermaid
flowchart TD
    subgraph MongoDBCluster ["MongoDB ReplicaSet 'mgrs' (Port: 27017)"]
        PRIMARY["mongodb-0 (Primary)"]
        SECONDARY1["mongodb-1 (Secondary)"]
        SECONDARY2["mongodb-2 (Secondary, prod only)"]
        OPLOG[("Oplog / Change Stream")]

        PRIMARY --> OPLOG
        SECONDARY1 -.->|"Replicate"| PRIMARY
        SECONDARY2 -.->|"Replicate"| PRIMARY
    end

    subgraph SpringBootApp ["Spring Boot Application (Port: 8080)"]
        subgraph DebeziumEngine ["Debezium Embedded Engine (In-Process)"]
            CONNECTOR["MongoDbConnector<br/><i>io.debezium.connector.mongodb</i>"]
            OFFSET["FileOffsetBackingStore<br/><i>offsets.dat (flush: 60s)</i>"]
            CONNECTOR --> OFFSET
        end

        subgraph ObservabilityBridge ["JMX → Micrometer Bridge"]
            MBINDER["DebeziumMetricsBinder<br/><i>Dynamic MBean Discovery<br/>via NotificationListener</i>"]
            JMXMBEAN["debezium.* JMX MBeans<br/><i>Auto-discovered on registration</i>"]
            JOLOKIA["Jolokia HTTP Endpoint<br/><i>/actuator/jolokia</i>"]
        end

        JMXMBEAN --> MBINDER
        JMXMBEAN --> JOLOKIA
    end

    subgraph ObservabilityStack ["Observability Pipeline"]
        ALLOY["Grafana Alloy<br/><i>Scrape /actuator/prometheus</i>"]
        PROM["Prometheus Server"]
        GRAFANA["Grafana Dashboard"]
    end

    %% CDC Flow
    OPLOG -->|"Change Stream Events"| CONNECTOR
    CONNECTOR -->|"Consume Events (kx DB)"| CONNECTOR

    %% Metrics Flow
    MBINDER -->|"Register Micrometer Gauges"| ALLOY
    ALLOY -->|"Remote Write"| PROM
    PROM --> GRAFANA

    classDef mongo fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px;
    classDef engine fill:#fff3e0,stroke:#e65100,stroke-width:2px;
    classDef bridge fill:#e1f5fe,stroke:#0277bd,stroke-width:2px;
    classDef obs fill:#f3e5f5,stroke:#7b1fa2,stroke-width:1px;

    class PRIMARY,SECONDARY1,SECONDARY2,OPLOG mongo;
    class CONNECTOR,OFFSET engine;
    class MBINDER,JMXMBEAN,JOLOKIA bridge;
    class ALLOY,PROM,GRAFANA obs;
```

---

## Decision

1. **MongoDB ReplicaSet Architecture:**
   - MongoDB is deployed as a **ReplicaSet named `mgrs`** (3-node in `prod`, 2-node + Arbiter in `dev`) to expose the **Change Stream API** which Debezium requires for oplog-based CDC.
   - **Production:** 3 full data-bearing replicas (`replicas: 3`, `arbiter.enabled: false`) — maximises data durability and read availability.
   - **Dev:** 2 data nodes + 1 Arbiter (`replicas: 2`, `arbiter.enabled: true`) — reduces resource footprint while maintaining quorum.
   - Credentials managed via `existingSecret: mongodb` (key: `mongodb-root-password`).

2. **Embedded Debezium Engine (In-Process, No Kafka Connect Cluster):**
   - Debezium runs as an **embedded `EmbeddedEngine`** inside the Spring Boot JVM (no separate Kafka Connect deployment required).
   - Engine name: `sbd-mongodb-cdc`, connector class: `io.debezium.connector.mongodb.MongoDbConnector`.
   - Watches the `kx` database (`DATABASE_INCLUDE_LIST: "kx"`) via the MongoDB Change Stream API.
   - Connection string injected via environment variable `DEBEZIUM_MONGODB_CONNECTION_STRING` targeting all 3 pod hostnames in the headless service:
     ```
     mongodb://admin:password@mongodb-0.mongodb-headless.monitoring.svc.cluster.local:27017,
                               mongodb-1.mongodb-headless.monitoring.svc.cluster.local:27017,
                               mongodb-2.mongodb-headless.monitoring.svc.cluster.local:27017
                               /kx?authSource=admin&replicaSet=mgrs
     ```

3. **Offset Management:**
   - Uses `FileOffsetBackingStore` writing to `offsets.dat` with a 60-second flush interval (`OFFSET_FLUSH_INTERVAL_MS: 60000`).
   - For production resilience, the offset file should reside in a **PVC-backed path** (not the ephemeral pod filesystem) to prevent duplicate event replay after pod restarts.

4. **JMX → Micrometer Observability Bridge (`DebeziumMetricsBinder`):**
   - Debezium Embedded exposes operational metrics exclusively through **JMX MBeans** in the `debezium.*` domain.
   - `DebeziumMetricsBinder` bridges these JMX beans to Micrometer **dynamically** using `MBeanServerNotificationListener` — it auto-discovers any newly registered `debezium.*` MBean at runtime without requiring code changes.
   - Supported metric types: **Numeric** (Gauge), **Boolean** (0.0/1.0 Gauge), and **String** (info Gauge with value label).
   - MBean key-value properties are automatically added as **Micrometer tags** (e.g., `type=connector-metrics`, `context=streaming`).
   - Metric names are normalized: `MilliSecondsBehindSource` → `debezium.milli_seconds_behind_source`.

5. **Jolokia Raw JMX Access:**
   - The application exposes `jolokia-support-spring` on `/actuator/jolokia` for direct raw JMX inspection of Debezium MBeans without connecting to the JMX port directly.

6. **Conditional Activation:**
   - Debezium can be enabled/disabled at the application level via `debezium.enabled` property (defaults to `true`).
   - In local dev without MongoDB, set `DEBEZIUM_ENABLED=false` to disable the engine and prevent startup errors.

---

## Technical Specification & Implementation Mapping

| Component / Config Key | Value / Logic | Purpose | Architectural Role |
| :--- | :--- | :--- | :--- |
| `architecture` | `replicaset` | Enables Change Stream API on MongoDB. | MongoDB HA |
| `replicaCount` | `3` (prod) / `2` (dev) | HA quorum with full data nodes. | MongoDB HA |
| `replicaSetName` | `mgrs` | Identifies the MongoDB replica set. | CDC Connection |
| `arbiter.enabled` | `false` (prod) / `true` (dev) | Quorum node without data in dev. | Resource Optimization |
| `auth.existingSecret` | `mongodb` (key: `mongodb-root-password`) | Stable credential injection. | Security |
| `persistence.size` | `20Gi` (prod) / disabled (dev) | Persistent data volume for replica set nodes. | Durability |
| `ENGINE_NAME` | `sbd-mongodb-cdc` | Unique embedded engine identifier. | Engine Config |
| `OFFSET_STORAGE` | `FileOffsetBackingStore` | Persistent CDC event offset tracking. | Reliability |
| `OFFSET_FLUSH_INTERVAL_MS` | `60000` (60s) | Offset durability window before flush. | Reliability |
| `DATABASE_INCLUDE_LIST` | `kx` | Limits CDC scope to the application database. | Scope / Safety |
| `DEBEZIUM_MONGODB_CONNECTION_STRING` | All 3 headless pod hostnames + `replicaSet=mgrs` | Resilient multi-node connection with replica set discovery. | Connectivity |
| `DebeziumMetricsBinder` | Dynamic `debezium.*` MBean scanning | Bridges JMX metrics to Micrometer Gauges. | Observability |
| `debezium.enabled` | `true` (default) | Toggle to disable CDC engine without code changes. | Operational Control |
| `/actuator/jolokia` | Jolokia HTTP bridge | Direct JMX MBean introspection via HTTP. | Diagnostics |

---

## Consequences

- **Positive:**
  - No additional Kafka Connect infrastructure required — CDC runs in-process at zero additional operational overhead.
  - Real-time CDC pipeline health visibility in Grafana via Prometheus (e.g., lag, snapshot status, error counts).
  - Dynamic metric discovery adapts automatically when Debezium registers new MBeans without code deployment.
- **Negative:**
  - Embedded engine shares JVM memory and CPU with the Spring Boot application.
  - File-based offset store in `offsets.dat` requires PVC backing in production to survive pod restarts.
- **Risk:**
  - If the Spring Boot pod restarts and the offset file is on an ephemeral volume, duplicate change events may be replayed until the compacted offset matches the current oplog position.
