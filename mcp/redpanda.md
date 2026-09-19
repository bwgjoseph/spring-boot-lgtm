# Redpanda / Kafka MCP Server Setup (`kafka-mcp-server`)

The **Kafka MCP Server** connects Claude to **Redpanda**, the high-performance streaming buffer used in this sandbox for **Tempo trace ingestion** (`tempo-traces` topic). It enables inspecting topic configuration, partition assignments, consumer lag, and raw trace message payloads.

---

## 1. Prerequisites

1. **Port-forward Redpanda Kafka Port (9093)**:
   While `task pf:redpanda` exposes the Web Console on port 8081, we need the Kafka API port:
   ```powershell
   kubectl port-forward service/redpanda 9093:9093 -n monitoring
   ```

2. **Verify Redpanda Health**:
   Check that Redpanda is running:
   ```powershell
   kubectl get pods -n monitoring -l app.kubernetes.io/name=redpanda
   ```

---

## 2. Configuration in Claude Code

### Using the CLI (`claude mcp add`)
```powershell
claude mcp add --env KAFKA_BOOTSTRAP_SERVERS="localhost:9093" redpanda -- uvx kafka-mcp-server
```

### Or using `.mcp.json`
Add the following entry under `mcpServers`:

```json
{
  "mcpServers": {
    "redpanda": {
      "command": "uvx",
      "args": ["kafka-mcp-server"],
      "env": {
        "KAFKA_BOOTSTRAP_SERVERS": "localhost:9093"
      }
    }
  }
}
```

---

## 3. Verification & Example Prompts

Verify connection:
```bash
claude mcp list
```

### Try these prompts in Claude Code:
- *"List all Kafka topics in Redpanda."*
- *"Check the partitions and replication factor for the `tempo-traces` topic."*
- *"Inspect the consumer group `tempo-block-builder` to see if there is any consumer lag."*
- *"Peek at the latest messages published to `tempo-traces`."*

---

## 4. Troubleshooting

- **Connection timeout to `localhost:9093`**: Ensure the port-forward command (`kubectl port-forward service/redpanda 9093:9093 -n monitoring`) is active in a background terminal.
- **Redpanda Console UI**: You can cross-verify topics and consumers in your browser by opening `http://localhost:8081` (`task pf:redpanda`).
