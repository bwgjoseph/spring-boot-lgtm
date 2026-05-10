# My Verification Plan

The idea is simple, I want to verify the `values-*.yaml` is configured correctly for each component. However, the way to go about performing the verification differs slightly between dev, prod-local, and prod setup.

Ideally, I can use `Taskfile` to assist in all the work, but manual commands could be possible to run some `kubectl` command for troubleshooting and what not.

## Dev

The starting state should be clean. Followed by starting the necessary infra and configuration to support the key components (LGTM stack).

1. **Preparation**
    - `task delete-namespace`
    - `task namespace`
    - `task secret`
    - `task configmap`

2. **Storage Foundation**
    - `task validate:minio`

3. **Observability Stack (LGTM)**
    - `task validate:prometheus`
    - `task validate:loki`
    - `task validate:tempo`
    - `task validate:grafana`
    - `task validate:alloy`

4. **Workload**
    - `task validate:app`

5. **End-to-End**
    - `task test:e2e`
    - Verify: `task pf:all` (Check UIs/Datasource health)
