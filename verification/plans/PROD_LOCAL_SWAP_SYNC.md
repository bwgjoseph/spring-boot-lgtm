# Implementation Plan: Surgical Swap & Sync for Production-Local Verification

This plan outlines the strategy to verify High Availability (HA) and distributed configurations on a local sandbox by swapping components one at a time.

## Objective
Verify that the `prod-local` (and by extension `prod`) values files are architecturally sound, support clustering/replication, and integrate correctly with the rest of the LGTM stack, without exceeding local resource limits.

## Key Files & Context
- `deployment/prod-local/`: Target configuration files.
- `Taskfile.yml`: Reusable tasks for swapping and sync.
- `verification/*.ps1`: Topology-aware health and data verification scripts.

## Implementation Steps

### 1. Architectural Standardization (prod-local)
Update existing and create new `prod-local` values to use a "Minimum HA" footprint (2 replicas where applicable) and full FQDNs.

- **Alloy (`values-alloy.yaml`):** 
    - Switch `controller.type` to `deployment`.
    - Set `replicas: 2`.
    - Ensure clustering (gossip) is enabled on port 7946.
- **Loki (`values-loki.yaml`):**
    - Set `replication_factor: 2`.
    - Set `read.replicas: 2`, `write.replicas: 2`, `backend.replicas: 2`.
    - Ensure endpoints use `.monitoring.svc.cluster.local`.
- **Tempo (`values-tempo.yaml`):**
    - Set `replicas: 2`.
    - Ensure memberlist (gossip) is configured.
- **Mimir (`values-mimir.yaml`):**
    - Create a new Monolithic mode configuration with S3 persistence and 1 pod (HA-ready).

### 2. Topology-Aware Verification Scripts
Modify existing and create new scripts that **autonomously detect** the current deployment mode (e.g., via resource types or names) and adapt their assertions accordingly.

- **`verify-loki.ps1`**: Detects `SimpleScalable` vs `SingleBinary`. Verifies all sub-deployments (read/write/backend) and ensures data persistence in MinIO.
- **`verify-alloy.ps1`**: Detects `DaemonSet` vs `Deployment`. Verifies clustering metrics only when in `prod-local` (HA) mode.
- **`verify-mimir.ps1` (New)**: Detects monolithic vs distributed. Verifies S3 ingestion and memberlist ring health.
- **`verify-tempo.ps1` (New)**: Detects scalable monolithic mode. Verifies internal ring status and S3 block persistence.

### 3. Dynamic Datasource Management
Create `deployment/prod-local/datasources-prod-local.yaml`. The `swap` tasks will apply this ConfigMap to Grafana during the test to ensure it targets the HA endpoints (using full FQDNs).

### 4. Swap Logic in Taskfile.yml
Implement `swap:<component>` tasks with `FROM` and `TO` variables.

```yaml
  swap:loki:
    vars:
      FROM: '{{.FROM | default "dev"}}'
      TO: '{{.TO | default "prod-local"}}'
    cmds:
      - task: uninstall:loki ENV={{.FROM}}
      - pwsh ./verification/storage-bootstrap.ps1 -wipe loki
      - task: loki ENV={{.TO}}
      - task: verify:loki ENV={{.TO}}
```

### 5. Sync Logic
Create `verification/sync-prod-values.ps1` to perform a surgical merge of architectural keys (replicas, deploymentMode, clustering) from `prod-local` to `prod`, while preserving production secrets.

## Verification & Testing
1. **Initial State:** Assume the infrastructure is already running in `dev` mode.
2. **Swap Test:** Execute `task swap:loki FROM=dev TO=prod-local`.
3. **Automated Verification:** The task will run `verify:loki`, which must detect the new HA topology and pass.
4. **Data Integrity:** Run `task test:e2e` to ensure the rest of the stack still functions with the swapped component.
5. **Revert:** Execute `task swap:loki FROM=prod-local TO=dev` to restore the resource baseline.
6. **Sync:** Once verified, run `task sync:loki` to merge verified architecture to `prod/values-loki.yaml`.
