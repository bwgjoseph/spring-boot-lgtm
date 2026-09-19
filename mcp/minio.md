# MinIO / S3 MCP Server Setup (`s3-mcp-server`)

The **S3 MCP Server** connects Claude to your local **MinIO** object store. MinIO houses the persistent object storage backend for:
- **Loki:** `loki` bucket (TSDB index and chunks)
- **Tempo:** `tempo` bucket (compacted trace blocks)
- **Mimir:** `mimir` bucket (metrics long-term storage)

---

## 1. Prerequisites

1. **Port-forward MinIO S3 API (9000)**:
   ```powershell
   task pf:minio
   ```
   MinIO S3 API will be reachable at `http://localhost:9000` (and Console at `http://localhost:9001`).

2. **Retrieve MinIO Credentials**:
   - **Access Key / User:** `admin`
   - **Secret Key / Password:** `password123` (or check via `task password:minio`)

---

## 2. Configuration in Claude Code

### Using the CLI (`claude mcp add`)
```powershell
claude mcp add --env AWS_ENDPOINT_URL="http://localhost:9000" --env AWS_ACCESS_KEY_ID="admin" --env AWS_SECRET_ACCESS_KEY="password123" --env AWS_REGION="us-east-1" minio -- uvx s3-mcp-server
```

### Or using `.mcp.json`
Add the following entry under `mcpServers`:

```json
{
  "mcpServers": {
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

---

## 3. Verification & Example Prompts

Verify connection:
```bash
claude mcp list
```

### Try these prompts in Claude Code:
- *"List all buckets in our MinIO object storage."*
- *"Check the contents and object prefixes of the `tempo` bucket."*
- *"Are Loki TSDB indexes and chunks being actively written to the `loki` bucket?"*
- *"Inspect whether block compaction has produced any meta.json files in Tempo storage."*

---

## 4. Troubleshooting

- **Signature / Path style errors**: MinIO uses path-style access. Ensure the client does not attempt virtual host bucket resolution (e.g. `bucket.localhost:9000`).
- **Connection refused**: Confirm that `task pf:minio` is actively running. Test with `curl http://localhost:9000/minio/health/live`.
