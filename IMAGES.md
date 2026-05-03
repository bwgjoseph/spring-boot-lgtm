# 📦 Container Image Inventory

This document tracks all container images currently deployed in the `monitoring` namespace, including primary services, sidecars, and init containers, to provide a clear Software Bill of Materials (SBOM).

| Component | Container Name | Full Image String |
| :--- | :--- | :--- |
| **Spring Boot App** | `spring-boot-app` | `spring-boot-app:demo` |
| **Grafana Alloy** | `alloy` | `docker.io/grafana/alloy:v1.16.0` |
| **Alloy Config Reloader** | `config-reloader` | `quay.io/prometheus-operator/prometheus-config-reloader:v0.81.0` |
| **Loki** | `loki` | `docker.io/grafana/loki:3.7.1` |
| **Loki Canary** | `loki-canary` | `docker.io/grafana/loki-canary:3.7.1` |
| **Loki Gateway** | `nginx` | `docker.io/nginxinc/nginx-unprivileged:1.30-alpine` |
| **Loki Access Log** | `access-log-exporter` | `ghcr.io/jkroepke/access-log-exporter:0.3.11` |
| **Tempo** | `tempo` | `docker.io/grafana/tempo:2.10.1` |
| **Prometheus** | `prometheus` | `quay.io/prometheus/prometheus:v3.11.2` |
| **Alertmanager** | `alertmanager` | `quay.io/prometheus/alertmanager:v0.32.0` |
| **Kube-State-Metrics** | `kube-state-metrics` | `registry.k8s.io/kube-state-metrics/kube-state-metrics:v2.18.0` |
| **Node Exporter** | `node-exporter` | `quay.io/prometheus/node-exporter:v1.11.1` |
| **MongoDB** | `mongodb` | `registry-1.docker.io/bitnamicharts/mongodb:8.2.7` |
| **MinIO** | `minio` | `quay.io/minio/minio:RELEASE.2025-07-23...` |
