# 📦 Container Image Inventory

This document tracks all container images currently deployed in the `monitoring` namespace to provide a clear view of the software bill of materials (SBOM) and container registry sources.

| Component | Container Name | Image:Tag | Registry Source |
| :--- | :--- | :--- | :--- |
| **Spring Boot App** | `spring-boot-app` | `spring-boot-app:demo` | Local (Jib) |
| **Grafana Alloy** | `alloy` | `grafana/alloy:v1.16.0` | `docker.io` |
| **Grafana** | `grafana` | `grafana/grafana:13.0.1` | `docker.io` |
| **Loki** | `loki` | `grafana/loki:3.7.1` | `docker.io` |
| **Loki Gateway** | `nginx` | `nginxinc/nginx-unprivileged:1.30-alpine` | `docker.io` |
| **Tempo** | `tempo` | `grafana/tempo:2.10.1` | `docker.io` |
| **Prometheus** | `prometheus` | `prometheus/prometheus:v3.11.2` | `quay.io` |
| **Alertmanager** | `alertmanager` | `prometheus/alertmanager:v0.32.0` | `quay.io` |
| **MongoDB** | `mongodb` | `bitnami/mongodb:latest` | `registry-1.docker.io` |
| **MinIO** | `minio` | `minio/minio:RELEASE...` | `quay.io` |
| **Node Exporter** | `node-exporter` | `prometheus/node-exporter:v1.11.1` | `quay.io` |
