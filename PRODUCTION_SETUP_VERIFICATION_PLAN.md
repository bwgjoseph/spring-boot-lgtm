# 🚀 Production Setup Verification Plan (Scalable Components)

This plan outlines the component-by-component verification of the production-grade scalable blueprints. We will switch each component from "Dev" (Single Binary) to "Prod" (Distributed) mode, verify its health and data integrity, and then revert before moving to the next.

## 🛠️ Phase 0: Groundwork
- [x] **Storage Bootstrap:** Confirmed `loki` and `tempo` buckets exist in MinIO.
- [x] **E2E Smart Detection:** Updated `verification/data-verify.ps1` to resolve service URLs automatically.
- [x] **Health Check Refinement:** Updated `Taskfile.yml` and `verify:*` tasks.

---

## ❄️ Phase 1: Loki Simple Scalable
**Goal:** Verify Loki microservices with S3 (MinIO) backend.
1. [x] **Refine Prod Values:** Finalize `deployment/prod/values-loki-local.yaml` (Disabled hard anti-affinity).
2. [x] **Wipe Dev:** Performed full namespace purge (`kubectl delete namespace monitoring`).
3. [x] **Deploy Prod:** `task loki ENV=prod LOKI_VALUES=deployment/prod/values-loki-local.yaml`.
4. [x] **Verification:** Confirmed 2x replicas for read/write/backend and successful log push via `loki-gateway`.
5. [ ] **Extract Image:** Extract all the images required to run and update `IMAGES.md`
6. [ ] **Revert:** `task uninstall:loki` followed by `task loki`. (Pending: Current state is active for user inspection).

---

## ⚡ Phase 2: Tempo Scalable Monolithic
**Goal:** Verify Tempo scalable monolithic mode with S3 (MinIO) backend.
1. [x] **Refine Prod Values:** Finalize `deployment/prod/values-tempo-local.yaml` (Fixed nesting + enabled env expansion).
2. [x] **Wipe Dev:** Performed `task uninstall:tempo`.
3. [x] **Deploy Prod:** `task tempo ENV=prod TEMPO_VALUES=deployment/prod/values-tempo-local.yaml`.
4. [x] **Verification:** Confirmed 2x replicas and **verified files in MinIO** (`single-tenant/` directory created after flush).
5. [ ] **Extract Image:** Extract all the images required to run and update `IMAGES.md`
6. [ ] **Revert:** `task uninstall:tempo` followed by `task tempo`.

---

## 🔗 Phase 3: Alloy Clustered Gateway
**Goal:** Verify Alloy running as a clustered Deployment for HA ingestion.
1. [ ] **Refine Prod Values:** Finalize `deployment/prod/values-alloy.yaml`.
2. [ ] **Wipe Dev:** `task uninstall:alloy`.
3. [ ] **Deploy Prod:** `task alloy ENV=prod`.
4. [ ] **Verification:** Run `task verify:alloy` and `task test:e2e`.
5. [ ] **Extract Image:** Extract all the images required to run and update `IMAGES.md`
6. [ ] **Revert:** `task uninstall:alloy` followed by `task alloy`.

---

## ✅ Execution Protocol
1.  Gemini will perform the **Phase 0** groundwork.
2.  **STOP:** Wait for User greenlight before initiating Phase 1.
3.  Gemini will execute the deployment/test for the phase.
4.  **STOP:** Wait for User greenlight before initiating the next phase.
