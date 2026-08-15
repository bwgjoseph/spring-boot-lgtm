# 📦 Container Image Inventory

This document tracks all container images currently deployed in the `monitoring` namespace, including primary services, sidecars, and init containers, to provide a clear Software Bill of Materials (SBOM).

| Component | Container Name | Full Image String |
| :--- | :--- | :--- |
| **Spring Boot App** | `spring-boot-app` | `spring-boot-app:demo` |
| **Grafana Alloy** | `alloy` | `docker.io/grafana/alloy:v1.16.0` |
| **Alloy Config Reloader** | `config-reloader` | `quay.io/prometheus-operator/prometheus-config-reloader:v0.81.0` |
| **Loki** | `loki` | `docker.io/grafana/loki:3.7.2` |
| **Loki Canary** | `loki-canary` | `docker.io/grafana/loki-canary:3.7.2` |
| **Loki Gateway** | `nginx` | `docker.io/nginxinc/nginx-unprivileged:1.30-alpine` |
| **Loki Cache** | `memcached` | `docker.io/library/memcached:1.6.29-alpine` |
| **Loki Access Log** | `access-log-exporter` | `ghcr.io/jkroepke/access-log-exporter:0.3.11` |
| **Redpanda Broker** | `redpanda` | `docker.io/redpandadata/redpanda:v26.2.1` |
| **Redpanda Console** | `console` | `docker.io/redpandadata/console:v3.9.0` |
| **Redpanda Operator** | `redpanda-operator` | `docker.io/redpandadata/redpanda-operator:v26.2.1` |
| **Tempo Distributor** | `tempo` | `docker.io/grafana/tempo:3.0.2` |
| **Tempo Block Builder** | `tempo` | `docker.io/grafana/tempo:3.0.2` |
| **Tempo Live Store** | `tempo` | `docker.io/grafana/tempo:3.0.2` |
| **Tempo Querier** | `tempo` | `docker.io/grafana/tempo:3.0.2` |
| **Tempo Query Frontend** | `tempo` | `docker.io/grafana/tempo:3.0.2` |
| **Tempo Backend Scheduler** | `tempo` | `docker.io/grafana/tempo:3.0.2` |
| **Tempo Backend Worker** | `tempo` | `docker.io/grafana/tempo:3.0.2` |
| **Tempo Metrics Generator** | `tempo` | `docker.io/grafana/tempo:3.0.2` |
| **Prometheus** | `prometheus` | `quay.io/prometheus/prometheus:v3.11.2` |
| **Alertmanager** | `alertmanager` | `quay.io/prometheus/alertmanager:v0.32.0` |
| **Kube-State-Metrics** | `kube-state-metrics` | `registry.k8s.io/kube-state-metrics/kube-state-metrics:v2.18.0` |
| **Node Exporter** | `node-exporter` | `quay.io/prometheus/node-exporter:v1.11.1` |
| **MongoDB** | `mongodb` | `registry-1.docker.io/bitnamicharts/mongodb:8.2.7` |
| **MinIO** | `minio` | `quay.io/minio/minio:RELEASE.2024-12-18T13-15-44Z` |
