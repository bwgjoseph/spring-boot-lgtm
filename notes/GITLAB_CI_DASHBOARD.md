# 🚀 GitLab CI Dashboard Integration: Pipeline Metrics & DORA

This document covers two levels of GitLab CI observability within the LGTM stack:
- **Option A — Pipeline Metrics:** CI pipeline duration, pass/fail rates, runner health via `gitlab-ci-pipelines-exporter`.
- **Option B — DORA Metrics:** Deployment Frequency, Lead Time for Changes, Change Failure Rate, Time to Restore via `dora-exporter` or GitLab native.

---

## 🏗️ Architecture Overview

```mermaid
flowchart TD
    subgraph GitLabCI ["GitLab CI/CD (Self-Hosted / gitlab.internal)"]
        PIPELINE["CI Pipelines & Jobs"]
        DEPLOY["Deployment Events"]
        INCIDENT["Incidents / MR Merges"]
    end

    subgraph Exporters ["Exporter Layer (monitoring namespace)"]
        PIPE_EXP["gitlab-ci-pipelines-exporter<br/><i>Polls GitLab API<br/>Port :8080 /metrics</i>"]
        DORA_EXP["dora-exporter<br/><i>Listens to GitLab Webhooks<br/>Port :8090 /metrics</i>"]
    end

    subgraph AlloyStack ["Grafana Alloy (Annotation-based Scrape)"]
        ALLOY["Grafana Alloy<br/><i>prometheus.io/scrape=true</i>"]
    end

    subgraph Storage ["Prometheus → Grafana"]
        PROM["Prometheus<br/><i>Stores pipeline & DORA metrics</i>"]
        GRAFANA["Grafana Dashboards<br/><i>Pipeline Status + DORA panel</i>"]
    end

    PIPELINE -->|"API Poll (token)"| PIPE_EXP
    DEPLOY -->|"Webhook events"| DORA_EXP
    INCIDENT -->|"Webhook events"| DORA_EXP
    PIPE_EXP -->|"Scrape /metrics"| ALLOY
    DORA_EXP -->|"Scrape /metrics"| ALLOY
    ALLOY -->|"Remote Write"| PROM
    PROM --> GRAFANA
```

---

## Option A: Pipeline Metrics (`gitlab-ci-pipelines-exporter`)

### What It Provides
The [`mvisonneau/gitlab-ci-pipelines-exporter`](https://github.com/mvisonneau/gitlab-ci-pipelines-exporter) polls the GitLab API at configurable intervals and exposes Prometheus metrics:

| Metric | Description |
| :--- | :--- |
| `gitlab_ci_pipeline_last_run_duration_seconds` | Duration of the last pipeline run per project + branch |
| `gitlab_ci_pipeline_status` | Status per pipeline (running / success / failed / canceled) |
| `gitlab_ci_pipeline_coverage` | Code coverage percentage from the last pipeline |
| `gitlab_ci_job_last_run_duration_seconds` | Duration of individual jobs (e.g., `build`, `test`, `deploy`) |
| `gitlab_ci_runner_description` | Runner info labels |

### Deployment on Kubernetes

**1. Helm Values (`deployment/dev/values-gitlab-ci-exporter.yaml`)**

```yaml
# Helm chart: mvisonneau/gitlab-ci-pipelines-exporter
config:
  gitlab:
    url: http://gitlab.internal.corp   # Self-hosted GitLab URL
    token: ""                          # Reference via existingSecret instead!
  projects:
    - name: "observability/spring-boot-lgtm"
      pull:
        refs:
          regexp: "^(main|develop)$"   # Only watch main & develop branches
  wildcards:
    - owner:
        name: "observability"
        kind: group                    # Monitor all projects in the group

# Expose /metrics for Alloy annotation-based scraping
podAnnotations:
  prometheus.io/scrape: "true"
  prometheus.io/port: "8080"
  prometheus.io/path: "/metrics"

# Credentials from a pre-created Kubernetes Secret
existingSecret: gitlab-ci-exporter-token
# Secret format: kubectl create secret generic gitlab-ci-exporter-token \
#   --from-literal=token=<glpat-xxxx> -n monitoring
```

**2. Deploy using Taskfile:**

```powershell
# Step 1: Create the GitLab PAT secret (needs read_api scope)
$env:GITLAB_TOKEN = "glpat-xxxxxxxxxxxxxxxxxxxx"
task secret:gitlab

# Step 2: Deploy the exporter
task gitlab-ci-exporter

# Step 3: (Optional) Override for prod env
task gitlab-ci-exporter ENV=prod
```

**3. Grafana Dashboards Pre-Packaged:**

The exporter's official Grafana dashboards are downloaded into [`deployment/common/dashboards/gitlab/`](../deployment/common/dashboards/gitlab/):
- `dashboard_pipelines.json` (ID 10620 — GitLab CI Pipelines Overview)
- `dashboard_jobs.json` (GitLab CI Jobs Overview)
- `dashboard_environments.json` (GitLab Environments & Deployments)

These dashboards are automatically synced to Grafana under a **GitLab** folder whenever you run:
```powershell
task configmap:grafana-dashboard
# or the full configmap sync:
task configmap
```

### Key Configuration Notes
- The GitLab Personal Access Token (PAT) needs the `read_api` scope only.
- `pull.refs.regexp` limits which branches are monitored — avoid monitoring all branches or you'll hit GitLab API rate limits.
- Set `pull.projects.interval: 300` (default) to poll every 5 minutes — reduce for faster updates but be mindful of API rate limits in self-hosted GitLab.

---

## Option B: DORA Metrics

The four DORA metrics and their GitLab data sources:

| Metric | Measures | GitLab Data Source |
| :--- | :--- | :--- |
| **Deployment Frequency** | How often code reaches production | Deployment events (when CI pipeline deploys to `production` environment) |
| **Lead Time for Changes** | Commit → production deployment time | Merge Request `merged_at` → Deployment `created_at` delta |
| **Change Failure Rate** | % deployments that cause incidents | Incidents associated with deployments / total deployments |
| **Time to Restore Service** | Incident open → resolved duration | Incident `created_at` → `resolved_at` delta |

### Option B1: Native GitLab DORA (Requires Ultimate tier)

GitLab Ultimate/Premium includes a built-in DORA analytics dashboard at:
```
Your GitLab → Group/Project → Analyze → Analytics Dashboards → DORA Metrics
```

**Limitations for export to Grafana:**
- Native DORA data is read-only via the GitLab GraphQL/REST API.
- No built-in Prometheus exporter — you'd need a custom poller or webhook bridge.

### Option B2: `dora-exporter` (Self-Hosted, API-based, Recommended)

The [`mprokopov/dora-exporter`](https://github.com/mprokopov/dora-exporter) listens for GitLab deployment and incident webhooks, calculates DORA metrics, and exposes them as Prometheus metrics.

**Setup:**

**1. Kubernetes Deployment (`deployment/dev/dora-exporter.yaml`):**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: dora-exporter
  namespace: monitoring
spec:
  replicas: 1
  selector:
    matchLabels:
      app: dora-exporter
  template:
    metadata:
      labels:
        app: dora-exporter
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "8090"
        prometheus.io/path: "/metrics"
    spec:
      containers:
        - name: dora-exporter
          image: mprokopov/dora-exporter:latest
          ports:
            - containerPort: 8090
          env:
            - name: GITLAB_TOKEN
              valueFrom:
                secretKeyRef:
                  name: gitlab-dora-token
                  key: token
            - name: GITLAB_URL
              value: "http://gitlab.internal.corp"
```

**2. Configure GitLab Webhooks:**

In GitLab (per project or group): `Settings → Webhooks → Add new webhook`
- **URL:** `http://dora-exporter.monitoring.svc:8090/webhook`
- **Trigger events:** ✅ Deployment events, ✅ Merge request events, ✅ Issues events (for incidents)

**3. Grafana DORA Dashboard Queries:**

```promql
# Deployment Frequency (deployments per day in last 30 days)
sum(increase(dora_deployments_total{environment="production"}[30d])) / 30

# Lead Time for Changes (average hours)
avg(dora_lead_time_seconds{environment="production"}) / 3600

# Change Failure Rate (%)
sum(dora_failed_deployments_total{environment="production"}) /
  sum(dora_deployments_total{environment="production"}) * 100

# Time to Restore Service (average hours)
avg(dora_time_to_restore_seconds) / 3600
```

### Option B3: Pipeline-Driven Push via Prometheus Pushgateway

If full event-based DORA is overkill, calculate metrics at deploy time directly in `.gitlab-ci.yml` and push to Prometheus Pushgateway:

```yaml
deploy:
  stage: deploy
  script:
    - ./scripts/deploy.sh
    - |
      # Push deployment frequency metric
      echo "deployment_total{env=\"production\",project=\"spring-boot-app\"} 1" | \
        curl --data-binary @- http://prometheus-pushgateway.monitoring.svc:9091/metrics/job/deploy
```

> **Note:** Pushgateway is not installed in this stack by default (`prometheus-pushgateway.enabled: false` in `values-prometheus.yaml`). Enable it if choosing this path.

---

## 📊 DORA Performance Benchmarks (Google / DORA Research 2024)

| DORA Level | Deployment Frequency | Lead Time | Change Failure Rate | Time to Restore |
| :--- | :--- | :--- | :--- | :--- |
| **Elite** | On-demand (multiple/day) | < 1 hour | 0–5% | < 1 hour |
| **High** | 1/week – 1/day | 1 day – 1 week | 5–10% | < 1 day |
| **Medium** | 1/month – 1/week | 1 week – 1 month | 10–15% | 1–7 days |
| **Low** | Fewer than 1/month | 1–6 months | 15–64% | > 6 months |

---

## 🔑 Implementation Decision for This Stack

| Approach | Effort | Value | Recommendation |
| :--- | :--- | :--- | :--- |
| `gitlab-ci-pipelines-exporter` (Option A) | Low | High | ✅ Start here — single Helm chart, immediate pipeline visibility |
| Native GitLab DORA analytics | None | Medium | ℹ️ Use for quick visibility if on Ultimate tier |
| `dora-exporter` webhooks (Option B2) | Medium | High | ✅ Adopt after Option A is stable |
| Pipeline push via Pushgateway (Option B3) | Medium | Low | ⚠️ Avoid — brittle, metric gaps on pipeline skips |

**Suggested order:**
1. Deploy `gitlab-ci-pipelines-exporter` → import Grafana dashboard ID 10620.
2. Validate token, project scope, and Alloy scraping.
3. Add `dora-exporter` webhook listener for full DORA panel in Grafana.
