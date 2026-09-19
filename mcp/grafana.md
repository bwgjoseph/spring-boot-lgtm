# Grafana MCP Server Setup (`mcp-grafana`)

The **`mcp-grafana`** server ([grafana/mcp-grafana](https://github.com/grafana/mcp-grafana)) connects Claude directly to your local Grafana instance. It enables the assistant to list dashboards, inspect configured datasources, query Loki logs, and look up Tempo traces.

---

## 1. Prerequisites

1. **Port-forward Grafana**:
   ```powershell
   task pf:grafana
   ```
   Grafana will be reachable at `http://localhost:3000`.

2. **Obtain Admin Password**:
   ```powershell
   task password:grafana
   ```
   Default username is `admin`.

---

## 2. Generate Grafana Service Account & Token

`mcp-grafana` requires a Service Account Token with permissions to query datasources.

### Method A: Via Grafana Web UI
1. Open **http://localhost:3000** in your browser and log in as `admin`.
2. In the left navigation, go to **Administration** (gear icon) → **Users and access** → **Service accounts**.
3. Click **Add service account**.
   - **Display name:** `claude-code-mcp`
   - **Role:** `Viewer` (or `Editor` if you want Claude to manage annotations or dashboards)
4. Click **Create**.
5. Inside the new service account page, click **Add service account token**.
   - **Display name:** `claude-token`
   - **Expiration:** Select preferred duration (or *No expiration* for local sandbox).
6. Click **Generate token**.
7. **Copy and securely store the token** (`glsa_...`). *It will only be shown once.*

### Method B: Automated PowerShell Script
You can generate the token automatically using Grafana's HTTP API:

```powershell
# 1. Fetch admin password from k8s secret
$adminPassword = (kubectl get secret grafana-admin-credentials -n monitoring -o jsonpath="{.data.admin-password}" | [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)))
$headers = @{
    Authorization = "Basic " + [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes("admin:$adminPassword"))
    "Content-Type" = "application/json"
}

# 2. Create Service Account
$saBody = @{ name = "claude-code-mcp"; role = "Viewer" } | ConvertTo-Json
$saResponse = Invoke-RestMethod -Uri "http://localhost:3000/api/serviceaccounts" -Method Post -Headers $headers -Body $saBody

# 3. Create Service Account Token
$tokenBody = @{ name = "claude-token" } | ConvertTo-Json
$tokenResponse = Invoke-RestMethod -Uri "http://localhost:3000/api/serviceaccounts/$($saResponse.id)/tokens" -Method Post -Headers $headers -Body $tokenBody

$token = $tokenResponse.key
Write-Host "Generated Grafana Token: $token"
```

---

## 3. Configuration in Claude Code

### Using the CLI (`claude mcp add`)
Run in your project root:

```powershell
claude mcp add --env GRAFANA_URL="http://localhost:3000" --env GRAFANA_SERVICE_ACCOUNT_TOKEN="YOUR_GRAFANA_TOKEN" grafana -- uvx mcp-grafana
```

### Or using `.mcp.json`
Add the following entry under `mcpServers`:

```json
{
  "mcpServers": {
    "grafana": {
      "command": "uvx",
      "args": ["mcp-grafana"],
      "env": {
        "GRAFANA_URL": "http://localhost:3000",
        "GRAFANA_SERVICE_ACCOUNT_TOKEN": "YOUR_GRAFANA_TOKEN"
      }
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
- *"List all dashboards currently provisioned in Grafana."*
- *"What datasources are available in Grafana?"*
- *"Query Loki via Grafana for log lines containing 'ERROR' in the last 15 minutes."*
- *"Search for traces in Tempo with status code error."*

---

## 5. Troubleshooting

- **`401 Unauthorized`**: Check that the token has the `glsa_` prefix, has not expired, and belongs to an active service account.
- **`Connection refused`**: Ensure the port-forward is running (`task pf:grafana`). Check `http://localhost:3000/api/health`.
- **`uvx ENOENT`**: Ensure `uv` is installed and added to your `PATH`. Test with `uvx --version`.
