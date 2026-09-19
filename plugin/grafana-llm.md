# Grafana LLM App Setup Guide (Airgapped & Self-Hosted)

This guide documents how to install, configure, and operate the **Grafana LLM App (`grafana-llm-app`)** plugin on an **airgapped or self-hosted Grafana instance**.

It covers connecting to a private cloud endpoint (such as **Azure OpenAI** or **AWS Bedrock** via private VPC endpoint/proxy), offline plugin delivery methods for Kubernetes/Helm, and enabling key features (PromQL/LogQL query generation, incident & alert summaries, and dashboard auto-descriptions).

---

## 1. Architecture Overview

In an airgapped or restricted environment, Grafana has no direct public internet access to `grafana.com` or public LLM endpoints.

```text
┌──────────────────────────────────────────────────────────────────────┐
│ Airgapped Private Network / Kubernetes VPC                           │
│                                                                      │
│   ┌─────────────────────┐             ┌──────────────────────────┐   │
│   │ Grafana Pod         │             │ Internal Repository      │   │
│   │                     │◄────────────┤ (Artifactory/Nexus or    │   │
│   │  ┌───────────────┐  │ (Offline zip│  PVC / Custom Image)     │   │
│   │  │grafana-llm-app│  │  delivery)  └──────────────────────────┘   │
│   │  └───────┬───────┘  │                                            │
│   └──────────┼──────────┘                                            │
│              │                                                       │
│              ▼ (Private Endpoint / VPC Link / Egress Proxy)          │
│   ┌──────────────────────────────────────────────────────────────┐   │
│   │ Private Cloud LLM Backend                                    │   │
│   │ - Azure OpenAI (Private Endpoint / VNet)                     │   │
│   │ - AWS Bedrock (VPC Endpoint + SigV4 Proxy)                   │   │
│   │ - Self-Hosted vLLM / Ollama                                  │   │
│   └──────────────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────────────┘
```

---

## 2. Delivering the Plugin in an Airgapped Environment

In standard Grafana, `plugins: ["grafana-llm-app"]` downloads from `grafana.com/api/plugins` on startup. In an airgapped cluster, this will fail. Choose one of the following workable methods:

### Option A: Internal Artifact Mirror via Helm `plugins` (Recommended if Nexus/Artifactory exists)
If your organization hosts an internal repository (Artifactory, Nexus, or an internal S3/HTTP server):
1. Download the plugin archive on an internet-connected workstation:
   ```bash
   # From Grafana's release or GitHub
   curl -LO https://storage.googleapis.com/integration-artifacts/grafana-llm-app/grafana-llm-app-latest.zip
   ```
2. Upload it to your internal repository:
   `https://nexus.internal.corp/repository/grafana-plugins/grafana-llm-app-latest.zip`
3. Update Helm values (`values-grafana.yaml`):
   ```yaml
   plugins:
     - "https://nexus.internal.corp/repository/grafana-plugins/grafana-llm-app-latest.zip;grafana-llm-app"
   ```

### Option B: Kubernetes `initContainer` with Pre-loaded Volume
If no internal HTTP mirror is available, mount an offline volume or ConfigMap/PVC preloaded with the unzipped plugin:
```yaml
extraInitContainers:
  - name: load-llm-plugin
    image: busybox:1.36
    command: ["sh", "-c", "cp -r /source-plugins/grafana-llm-app /var/lib/grafana/plugins/"]
    volumeMounts:
      - name: offline-plugin-volume
        mountPath: /source-plugins
      - name: storage
        mountPath: /var/lib/grafana
```

### Option C: Baked into Custom Docker Image
If using an internal container registry:
```dockerfile
FROM grafana/grafana:12.11.1
COPY grafana-llm-app /var/lib/grafana/plugins/grafana-llm-app
```
And set `plugins: []` in Helm values.

---

## 3. Configuring Grafana for Private Cloud Endpoints

### 3.1 Unsigned Plugin Allowance (If customized or internally signed)
If your enterprise repackages the plugin, allow it in `grafana.ini`:
```yaml
grafana.ini:
  plugins:
    allow_loading_unsigned_plugins: "grafana-llm-app"
```

### 3.2 Network Egress Proxy (If required to reach VPC Endpoint)
If requests from Grafana to the private cloud endpoint must traverse an internal proxy:
```yaml
extraEnv:
  - name: HTTP_PROXY
    value: "http://egress-proxy.internal.corp:3128"
  - name: HTTPS_PROXY
    value: "http://egress-proxy.internal.corp:3128"
  - name: NO_PROXY
    value: "localhost,127.0.0.1,.svc,.cluster.local"
```

---

## 4. Provider Configuration

Once the plugin is loaded and Grafana restarts, navigate to:
**Administration** → **Plugins and data** → **Plugins** → **LLM App**.

### 4.1 Azure OpenAI (Private Endpoint / VNet)
Azure OpenAI provides an OpenAI-compatible REST API through your private endpoint URL:

1. Select Provider: **OpenAI** (or **Custom / OpenAI-compatible** depending on plugin version).
2. Configure settings:
   - **URL / Endpoint:** `https://<your-private-endpoint>.openai.azure.com/openai/deployments/<deployment-name>`
   - **API Key / Token:** Your Azure OpenAI resource API key (or managed identity token).
   - **API Version:** e.g. `2024-02-15-preview`.
   - **Model Mapping:** Map chat completions to your deployed model (e.g. `gpt-4o` or `gpt-4-turbo`).

### 4.2 AWS Bedrock (via Private Endpoint or SigV4 Proxy)
AWS Bedrock uses AWS Signature Version 4 (SigV4) headers rather than a standard OpenAI bearer token. 
1. **Using LiteLLM / Internal Gateway (Standard Practice):**
   Deploy a lightweight internal proxy (e.g. `LiteLLM` running inside the cluster) that translates OpenAI format to AWS Bedrock:
   - **Provider:** **OpenAI-compatible / Custom API**
   - **URL:** `http://litellm-proxy.monitoring.svc:4000/v1`
   - **API Key:** Custom bearer token configured in LiteLLM.
   - LiteLLM assumes the AWS IAM Role / IRSA to interact with Bedrock (e.g. `anthropic.claude-3-5-sonnet`).

---

## 5. Feature Configuration & Activation

The `grafana-llm-app` exposes several sub-capabilities that can be toggled on in the plugin settings:

### 1. PromQL / LogQL Query Generation & Explanation
- **Where it appears:** Explore page (Prometheus, Loki, and Tempo datasources).
- **What it does:** Allows users to write natural language prompts (e.g. *"Show HTTP 5xx errors per service over the last 15 minutes"*) and automatically generates the corresponding PromQL or LogQL query.
- **Flame graph & Trace Explanations:** Explains complex Tempo spans and flame graphs.

### 2. Dashboard & Panel Descriptions
- **Where it appears:** Dashboard editing and panel configuration.
- **What it does:** Generates informative titles, descriptions, and Markdown documentation based on the queries in each panel.

### 3. Incident & Alert Summaries
- **Where it appears:** Grafana Alerting rules and firing alert views.
- **What it does:** Summarizes firing alerts, groups related incidents, and provides initial troubleshooting guidance based on labels and annotations.

---

## 6. Verification Checklist

1. **Verify Plugin Loaded:**
   Check Grafana server logs after startup:
   ```powershell
   kubectl logs -l app.kubernetes.io/name=grafana -n monitoring | Select-String "grafana-llm-app"
   ```
   Should show: `Plugin registered: grafana-llm-app`.

2. **Test Endpoint Connectivity:**
   From inside the Grafana container, test connectivity to the private cloud endpoint:
   ```powershell
   kubectl exec -it deployment/grafana -n monitoring -- curl -k -v https://<your-private-llm-endpoint>/health
   ```

3. **Validate in UI:**
   - Open **Explore** → Select **Prometheus** or **Loki**.
   - Look for the AI Sparkle icon (✨) in the query editor.
   - Enter a query generation prompt to verify token generation.

---

## 7. Troubleshooting

| Issue | Root Cause | Solution |
| :--- | :--- | :--- |
| `Plugin not found` on startup | Airgapped Grafana attempted download from `grafana.com` | Use Option A (internal mirror URL) or Option B (pre-loaded PVC/image). |
| `Signature verification failed` | Modified or self-packaged plugin archive | Add `allow_loading_unsigned_plugins: "grafana-llm-app"` in `grafana.ini`. |
| `Connection timed out` to LLM | Missing network route, egress firewall, or DNS resolution | Verify VNet peering / Private Link endpoint and cluster DNS configuration. |
| `401 Unauthorized` | Invalid Azure OpenAI key or expired AWS credentials | Update API key in the LLM App configuration page. |
