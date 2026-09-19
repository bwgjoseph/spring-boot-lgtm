# Model Context Protocol (MCP) Integration Hub

This directory contains setup and operational guides for connecting **Claude Code**, **Claude Desktop**, and other MCP-compatible AI agents directly into the **Spring Boot LGTM Observability Sandbox**.

With these MCP servers configured, an AI assistant can inspect cluster state, query PromQL metrics, investigate Loki logs and Tempo traces, check Redpanda Kafka streams, verify MongoDB CDC data, and inspect MinIO object storage without leaving the terminal.

---

## 🧭 Available MCP Server Guides

| Server | Guide | Target Component | Protocol / Runner | Key Capabilities |
| :--- | :--- | :--- | :--- | :--- |
| **Grafana** | [grafana.md](./grafana.md) | Grafana (3000) | `uvx mcp-grafana` | Dashboards, datasources, Loki logs, Tempo traces |
| **Prometheus** | [prometheus.md](./prometheus.md) | Prometheus (9090) | `uvx prometheus-mcp-server` | PromQL execution, metric discovery, alerts inspection |
| **Kubernetes** | [kubernetes.md](./kubernetes.md) | K8s API (`monitoring` ns) | `uvx kubernetes-mcp-server` | Pod status, crash loops, service discovery, rollout logs |
| **MongoDB** | [mongodb.md](./mongodb.md) | MongoDB ReplicaSet (27017) | `npx -y @modelcontextprotocol/server-mongodb` | Replica status (`mgrs`), collection queries, CDC verification |
| **Redpanda / Kafka**| [redpanda.md](./redpanda.md) | Redpanda (9093) | `uvx kafka-mcp-server` | `tempo-traces` topic inspection, consumer lag |
| **MinIO / S3** | [minio.md](./minio.md) | MinIO API (9000) | `uvx s3-mcp-server` | Bucket inspection (`loki`, `tempo`, `mimir`), blocks |

---

## ⚡ Global Prerequisites

### 1. Port-Forwarding
Ensure your local Kubernetes stack is running and port-forwards are established:
```powershell
# Forward all UIs (Grafana:3000, Prom:9090, MinIO:9000/9001, Redpanda:8081, App:8080)
task pf:all

# Or forward specific services individually
task pf:grafana
task pf:prometheus
task pf:minio
task pf:redpanda
```

For MongoDB access:
```powershell
kubectl port-forward service/mongodb 27017:27017 -n monitoring
```

### 2. Package Runners (`uvx` and `npx`)
- **`uv` / `uvx`** (Python package runner):
  ```powershell
  # Check installation
  uvx --version

  # Install if missing (Windows PowerShell)
  powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
  ```
- **`npx`** (Node.js package runner, included with Node.js / npm):
  ```powershell
  npx --version
  ```

---

## 🛠️ Complete `.mcp.json` (All-in-One Template)

Save this file as `.mcp.json` in the root of the project to enable all MCP servers in **Claude Code**:

```json
{
  "mcpServers": {
    "grafana": {
      "command": "uvx",
      "args": ["mcp-grafana"],
      "env": {
        "GRAFANA_URL": "http://localhost:3000",
        "GRAFANA_SERVICE_ACCOUNT_TOKEN": "YOUR_GRAFANA_SERVICE_ACCOUNT_TOKEN"
      }
    },
    "prometheus": {
      "command": "uvx",
      "args": ["prometheus-mcp-server"],
      "env": {
        "PROMETHEUS_URL": "http://localhost:9090"
      }
    },
    "kubernetes": {
      "command": "uvx",
      "args": ["kubernetes-mcp-server"]
    },
    "mongodb": {
      "command": "npx",
      "args": [
        "-y",
        "@modelcontextprotocol/server-mongodb",
        "mongodb://admin:password@localhost:27017/?replicaSet=mgrs&authSource=admin"
      ]
    },
    "redpanda": {
      "command": "uvx",
      "args": ["kafka-mcp-server"],
      "env": {
        "KAFKA_BOOTSTRAP_SERVERS": "localhost:9093"
      }
    },
    "minio": {
      "command": "uvx",
      "args": ["s3-mcp-server"],
      "env": {
        "AWS_ENDPOINT_URL": "http://localhost:9000",
        "AWS_ACCESS_KEY_ID": "admin",
        "AWS_SECRET_ACCESS_KEY": "password123",
        "AWS_REGION": "us-east-1"
      }
    }
  }
}
```

> ⚠️ **Security Reminder:** Do not commit actual tokens or production secrets to Git. Keep `.mcp.json` in your local environment or add it to `.gitignore`.

---

## 🔍 Verifying in Claude Code

From your terminal in the project directory, run:
```bash
claude mcp list
```

All registered servers will appear with their connection status.
