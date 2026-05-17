# Production Investigation Tasks

To finalize the production-grade deployment based on the ADRs, the following information must be gathered from the production Kubernetes cluster:

## 1. Storage Capabilities (Critical)
- [ ] **RWX Support:** Run `kubectl get storageclass` and check for classes supporting `ReadWriteMany`.
    - *Task:* Identify if an NFS-backed StorageClass (e.g., `nfs-client`) exists for shared indices.
- [ ] **Alloy SSD PVCs:** Can the cluster provision **6x 10Gi - 20Gi Local SSD PVCs** (RWO) for the Alloy DaemonSet WAL?
- [ ] **Storage Class Performance:** What high-performance (SSD/NVMe) storage classes are available for the Tempo/Loki WAL?

## 2. Infrastructure Services
- [ ] **S3 Backend:** Will we use a managed cloud S3 service (e.g., AWS S3, GCS) or a self-hosted MinIO instance within the cluster?
- [ ] **Mattermost Webhook:** Obtain the production Mattermost incoming webhook URL for Alertmanager integration.

## 3. Network Configuration
- [ ] **Ingress Controller:** Which Ingress controller is used in production (Nginx, Traefik, etc.)?
    - *Task:* Verify gRPC support for OTLP traffic from Alloy to Tempo/Mimir.
- [ ] **Internal DNS:** Confirm that internal cluster DNS resolution (e.g., `loki-gateway.monitoring.svc.cluster.local`) is stable and performing well.

## 4. Workload Estimates
- [ ] **Initial Log Volume:** Estimated daily log ingestion in GB.
- [ ] **Initial Trace Volume:** Estimated spans per second.
- [ ] **Active Time Series:** Estimated number of active Prometheus series.
