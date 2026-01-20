# Spring Boot LGTM Observability

This demo setup Grafana LGTM stack with Alloy to showcase how to set up the entire stack using Helm Chart, and the necessary setup in Spring Boot application to integrate with it.

As part of the setup, I do prefer to "Scrape & Push" rather than having the application to publish as it's more resilient, and does not impact application's memory or performance (lesser overhead).

## Grafana LGTM stack w/ Alloy

- Alloy acts as a Prometheus Scraper for metrics while remaining as an OTLP receiver for logs and traces
  - This way, we eliminate the need to deploy Prometheus
- Alloy also acts as a Logs Scraper for logs that scrapes directly from application pod, and then enrich with pod metadata before pushing to Loki

---

- Metrics: Scraped by Alloy via `/actuator/prometheus`
- Logs: Scraped by Alloy from container log files on disk
- Traces: Pushed by application to Alloy via OTLP

### The "Magic" of Correlation

The real power of this stack is Trace-to-Log-to-Metric navigation.

- Metrics to Traces: In Grafana, configure Mimir "Exemplars". When there's spike in latency in a Prometheus graph, one can click a dot to jump directly to the specific Trace in Tempo.
- Traces to Logs: Configure Tempo "Derived Fields" to link `trace_id` to a Loki search query

## Deployment Strategy

| Component | Helm Chart                      | Version | Configuration                      | Remarks                                                                        |
|-----------|---------------------------------|---------|------------------------------------|--------------------------------------------------------------------------------|
| Grafana   | grafana/grafana                 |         |                                    | Visualization layer connecting all three with "Derived Fields" for correlation |
| Alloy     | grafana/alloy                   |         |                                    | Acts as the local collector/gateway                                            |
| Mimir     | grafana/mimir-distributed       |         |                                    | Scalable Prometheus-compatible storage                                         |
| Mimir     | prometheus-community/prometheus |         |                                    | Simpler setup and maintainence compared to Mimir                               |
| Loki      | grafana/loki                    |         | Set `deploymentMode: SingleBinary` | Metadata-indexed log storage                                                   |
| Tempo     | grafana/tempo                   |         |                                    | High-scale distributed tracing backend                                         |

The distributed charts are much more complicated to set up, manage, and uses much more resources (CPU/RAM). On top of that, upgrading would also be easier. For storage, can just use PVC rather than S3.

### Installation

#### Loki

```bash
helm install loki grafana/loki
```

```yaml
loki:
  auth_enabled: false
  commonConfig:
    replication_factor: 1
  storage:
    type: 'filesystem' # Simple PVC storage instead of S3
deploymentMode: SingleBinary
singleBinary:
  replicas: 1
```

#### Tempo

```bash
helm install tempo grafana/tempo
```

```yaml
tempo:
  replicas: 1
  storage:
    trace:
      backend: local
      local:
        path: /var/tempo/traces
```

#### Alloy

```
// ============================================================================
// 1. METRICS PILLAR (Scrape + Push)
// ============================================================================

// Scrape the Spring Boot Actuator endpoint
prometheus.scrape "spring_app_metrics" {
  targets = [
    {"__address__" = "my-spring-service:8080"}, // Replace with your K8s service name
  ]
  metrics_path = "/actuator/prometheus"
  scrape_interval = "15s"
  forward_to = [prometheus.remote_write.local_prometheus.receiver]
}

// Push to Prometheus (Standard remote_write)
prometheus.remote_write "local_prometheus" {
  endpoint {
    url = "http://prometheus-server.monitoring.svc:80/api/v1/write"
  }
}

// ============================================================================
// 2. LOGS PILLAR (Scrape Files)
// ============================================================================

// Discover pods to get metadata (labels, namespace, etc.)
discovery.kubernetes "pods" {
  role = "pod"
}

// Read the container log files from the node disk
loki.source.kubernetes "container_logs" {
  targets    = discovery.kubernetes.pods.targets
  forward_to = [loki.write.local_loki.receiver]
}

// Push to Loki (Single Binary)
loki.write "local_loki" {
  endpoint {
    url = "http://loki.monitoring.svc:3100/loki/api/v1/push"
  }
}

// ============================================================================
// 3. TRACES PILLAR (Receive OTLP Push)
// ============================================================================

// Open gRPC and HTTP ports for Spring Boot to push traces
otelcol.receiver.otlp "spring_traces" {
  grpc { endpoint = "0.0.0.0:4317" }
  http { endpoint = "0.0.0.0:4318" }

  output {
    traces = [otelcol.processor.batch.default.input]
  }
}

// Batch traces for better network efficiency
otelcol.processor.batch "default" {
  output {
    traces = [otelcol.exporter.otlp.local_tempo.input]
  }
}

// Push to Tempo (Single Binary)
otelcol.exporter.otlp "local_tempo" {
  client {
    endpoint = "tempo.monitoring.svc:4317"
    tls { insecure = true }
  }
}
```