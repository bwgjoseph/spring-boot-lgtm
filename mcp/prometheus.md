# Prometheus MCP Server Setup (`prometheus-mcp-server`)

The **`prometheus-mcp-server`** ([pab1it0/prometheus-mcp-server](https://github.com/pab1it0/prometheus-mcp-server)) enables Claude to execute PromQL expressions, list and inspect metric series, explore labels, and evaluate alert states directly from your Prometheus instance.

---

## 1. Prerequisites

1. **Port-forward Prometheus Server**:
   ```powershell
   task pf:prometheus
   ```
   Prometheus will be available at `http://localhost:9090`.

2. **Ensure `uvx` is available**:
   ```powershell
   uvx --version
   ```

---

## 2. Configuration in Claude Code

### Using the CLI (`claude mcp add`)
Run in your project root:

```powershell
claude mcp add --env PROMETHEUS_URL="http://localhost:9090" prometheus -- uvx prometheus-mcp-server
```

### Or using `.mcp.json`
Add the following entry under `mcpServers`:

```json
{
  "mcpServers": {
    "prometheus": {
      "command": "uvx",
      "args": ["prometheus-mcp-server"],
      "env": {
        "PROMETHEUS_URL": "http://localhost:9090"
      }
    }
  }
}
```

---

## 3. Alternative: Docker-based Execution

If you prefer running via Docker instead of Python `uvx`:

```json
{
  "mcpServers": {
    "prometheus": {
      "command": "docker",
      "args": [
        "run",
        "-i",
        "--rm",
        "-e",
        "PROMETHEUS_URL=http://host.docker.internal:9090",
        "ghcr.io/pab1it0/prometheus-mcp-server:latest"
      ]
    }
  }
}
```

---

## 4. Verification & Example Prompts

Verify connection:
```bash
claude mcp list
```

### Try these prompts in Claude Code:
- *"List all metric names matching `http_server_requests.*` in Prometheus."*
- *"Query the current 5-minute request rate per URI: `sum by (uri) (rate(http_server_requests_seconds_count[5m]))`."*
- *"Show me JVM heap memory usage: `jvm_memory_used_bytes{area=\"heap\"} / jvm_memory_max_bytes{area=\"heap\"}`."*
- *"Are there any active alerting rules firing in Prometheus right now?"*
- *"Find the latest Debezium CDC metrics scraped from our Spring Boot application."*

---

## 5. Troubleshooting

- **`Connection refused` on localhost**: Ensure port-forward is running (`task pf:prometheus`). You can verify by opening `http://localhost:9090` in your browser.
- **Docker `host.docker.internal` resolution**: If using the Docker runner on Windows/Linux, ensure your Docker Desktop allows host networking or `host.docker.internal` is mapped.
- **Empty PromQL Results**: Check if Alloy is actively scraping the application pod via `task verify:alloy` or `task pf:alloy`.
