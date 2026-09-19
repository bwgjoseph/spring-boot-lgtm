# Kubernetes MCP Server Setup (`kubernetes-mcp-server`)

The **Kubernetes MCP Server** connects Claude to your active Kubernetes cluster context. It allows the assistant to inspect pod life-cycles, detect crash loops, examine warning events, review ConfigMaps, and view container logs in the `monitoring` namespace without requiring manual `kubectl` shell commands.

---

## 1. Prerequisites

1. **Active Local Cluster**:
   Ensure your local Kubernetes cluster (Docker Desktop, k3d, Minikube, or Kind) is running and your current kubeconfig context points to it:
   ```powershell
   kubectl cluster-info
   kubectl get nodes
   ```

2. **Access to `monitoring` Namespace**:
   ```powershell
   kubectl get pods -n monitoring
   ```

---

## 2. Configuration in Claude Code

### Using `uvx`
```powershell
claude mcp add kubernetes -- uvx kubernetes-mcp-server
```

### Alternative using `npx` (Official MCP Server)
```powershell
claude mcp add kubernetes -- npx -y @modelcontextprotocol/server-kubernetes
```

### Or using `.mcp.json`
Add the following entry under `mcpServers`:

```json
{
  "mcpServers": {
    "kubernetes": {
      "command": "uvx",
      "args": ["kubernetes-mcp-server"]
    }
  }
}
```

> **Note:** The server uses the standard `~/.kube/config` file in your user home directory automatically.

---

## 3. Verification & Example Prompts

Verify connection:
```bash
claude mcp list
```

### Try these prompts in Claude Code:
- *"Check the status of all pods in the `monitoring` namespace."*
- *"Are there any pods in CrashLoopBackOff or with high restart counts?"*
- *"Inspect recent Warning events in the `monitoring` namespace."*
- *"Show the resource limits and requests for the Alloy daemonset/deployment."*
- *"Check if the `prometheus-alert-rules` ConfigMap is mounted properly."*

---

## 4. Troubleshooting

- **`Unauthorized` or cluster unreachable**: Verify that your `kubectl` context is currently active:
  ```powershell
  kubectl config current-context
  ```
- **Windows kubeconfig path**: If the server fails to locate `KUBECONFIG`, explicitly set the environment variable:
  ```json
  "env": {
    "KUBECONFIG": "C:\\Users\\<USER>\\.kube\\config"
  }
  ```
