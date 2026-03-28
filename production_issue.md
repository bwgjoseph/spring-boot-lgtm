# 🩺 Post-Mortem: Simple Scalable Migration Issues

This document summarizes the challenges and learnings from the attempt to migrate the Loki/Tempo stack from Monolithic to Simple Scalable mode in a local (Docker Desktop) environment.

---

## 1. Resource Constraints (The "Pending" Pod Problem)
*   **The Issue:** Moving to Simple Scalable mode increased the pod count from ~3 to ~10. On a single-node local cluster (Docker Desktop), this exceeded the default CPU/Memory allocations.
*   **Symptoms:** Critical pods like `loki-gateway` and `loki-write` stayed in a `Pending` state indefinitely.
*   **Learning:** Production architectures are resource-heavy. For local sandboxes, resource `requests` and `limits` must be set to absolute minimums (e.g., 10m CPU, 64Mi RAM) to ensure scheduling.

## 2. Configuration Schema Mismatches (Tempo)
*   **The Issue:** The `grafana-community/tempo` chart (Single Binary) and the `grafana/tempo-distributed` / `grafana-community/tempo-distributed` charts have wildly different YAML structures.
*   **S3 Parameter Hell:**
    *   One chart expects `s3_force_path_style`.
    *   Another expects `force_path_style`.
    *   The Tempo 2.0 binary itself often expects `s3forcepathstyle`.
*   **Result:** Persistent `CrashLoopBackOff` due to "unmarshal errors" where fields were not recognized by the internal parser.
*   **Learning:** Helm charts are "wrappers." Sometimes the wrapper doesn't support the latest binary's flags. Using a manual `config: |` block is the only way to bypass these chart limitations.

## 3. Storage Complexity (MinIO)
*   **The Issue:** Simple Scalable mode **requires** shared storage (S3). Running MinIO on-prem adds another layer of complexity.
*   **Registry Issues:** Bitnami MinIO images had "manifest unknown" errors, requiring a switch to official MinIO images.
*   **Security Probes:** Bitnami charts block "non-standard" images by default, requiring `global.security.allowInsecureImages: true`.
*   **Protocol Mismatch:** Tempo tried to connect via HTTPS to an HTTP MinIO service, causing "server gave HTTP response to HTTPS client" errors.

## 4. Immutable Field Constraints
*   **The Issue:** Switching from Monolithic to Scalable changed the `StatefulSet` selectors and volume claim templates.
*   **Error:** `Forbidden: updates to statefulset spec for fields other than 'replicas'... are forbidden`.
*   **Learning:** You cannot "live-upgrade" a Monolithic installation to a Scalable one. The old release must be completely uninstalled before the new architecture is applied.

---

## 🚀 Recommended Path Forward
1.  **Start Clean:** Completely uninstall the old release before trying a new architecture.
2.  **Explicit Config:** Use the `config` string block in Helm values to avoid "hidden" logic in the chart templates.
3.  **Local vs. Prod:** Accept that "Simple Scalable" is for multi-node clusters. For local dev, **Single Binary with S3 storage** is the best "Hybrid" mode—it uses the production storage pattern but keeps the pod footprint small.
