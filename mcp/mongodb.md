# MongoDB MCP Server Setup (`@modelcontextprotocol/server-mongodb`)

The **MongoDB MCP Server** connects Claude directly to your local MongoDB 3-node ReplicaSet (`mgrs`). This allows Claude to verify documents inserted by e2e tests, inspect collection schemas, and check replica set replication health relevant to Debezium CDC.

---

## 1. Prerequisites

1. **MongoDB ReplicaSet Deployed**:
   Ensure the MongoDB StatefulSets are healthy:
   ```powershell
   task verify:mongodb
   ```

2. **Port-forward MongoDB**:
   Forward the primary/router port to localhost:
   ```powershell
   kubectl port-forward service/mongodb 27017:27017 -n monitoring
   ```

3. **Database Credentials**:
   - **Host:** `localhost:27017`
   - **Username:** `admin`
   - **Password:** `password` (defined in `secret:mongodb`)
   - **ReplicaSet:** `mgrs`
   - **AuthSource:** `admin`

---

## 2. Configuration in Claude Code

### Using the CLI (`claude mcp add`)
```powershell
claude mcp add mongodb -- npx -y @modelcontextprotocol/server-mongodb "mongodb://admin:password@localhost:27017/?replicaSet=mgrs&authSource=admin"
```

### Or using `.mcp.json`
Add the following entry under `mcpServers`:

```json
{
  "mcpServers": {
    "mongodb": {
      "command": "npx",
      "args": [
        "-y",
        "@modelcontextprotocol/server-mongodb",
        "mongodb://admin:password@localhost:27017/?replicaSet=mgrs&authSource=admin"
      ]
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
- *"List all databases and collections in the local MongoDB instance."*
- *"Query the last 5 records from the `kx` database collection modified by our application."*
- *"Verify that documents generated during our E2E run are present."*
- *"Check the current replica set status (`rs.status()`)."*

---

## 4. Troubleshooting

- **ReplicaSet hostname mismatch (`mongodb-0.mongodb-headless` unreachable)**: When connecting from outside the K8s cluster to a replica set, the client driver might attempt to route directly to internal Kubernetes pod hostnames. If you encounter topology errors, connect using direct connection mode:
  ```text
  mongodb://admin:password@localhost:27017/admin?directConnection=true
  ```
