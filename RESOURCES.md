# 🖥️ Resource Allocation & Sizing

This document tracks the CPU and Memory resources allocated to each component in the observability stack. These values are optimized for a **local sandbox environment** (Docker Desktop/KinD) with approximately 8GB-16GB of host RAM.

---

## 📊 Deployment Resource Table

The following table lists the `requests` (guaranteed) and `limits` (maximum) for each deployment as configured in the cluster.

| Deployment / Pod | CPU Request | CPU Limit | RAM Request | RAM Limit | Config File |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **spring-boot-app** | 100m | 500m | 512Mi | 1Gi | `deployment.yaml` |
| **loki** (Single Binary) | 100m | 500m | 256Mi | 512Mi | `values-loki-singlebinary.yaml` |
| **mongodb** (Node x2) | 100m | 500m | 256Mi | 512Mi | `values-mongodb.yaml` |
| **mongodb-arbiter** | 100m | 100m | 128Mi | 256Mi | `values-mongodb.yaml` |
| **tempo** | 10m | 500m | 256Mi | 1Gi | `values-tempo.yaml` |
| **minio** | 100m | Unset | 256Mi | Unset | `values-minio.yaml` |
| **alloy** (DaemonSet) | Unset | Unset | Unset | Unset | `values-alloy.yaml` |
| **prometheus-server** | Unset | Unset | Unset | Unset | `values-prometheus.yaml` |
| **grafana** | Unset | Unset | Unset | Unset | `values-grafana.yaml` |

*Note: **"Unset"** indicates that the component has no defined resource boundaries in its Helm chart defaults. Kubernetes treats these as **Best Effort** pods.*

---

## 💡 Notes on Sizing

### 1. The "Sandbox" Constraint
On local machines, we prioritize **scheduling** over **performance**. We use lower `requests` to ensure all pods can be placed on a single node, even if the node is nearly full. 

### 2. Best Effort Scheduling (Unset Values)
Components like Alloy, Prometheus, and Grafana are running without specific limits. 
*   **Pros:** They can scale their usage up to the full capacity of the host if needed.
*   **Cons:** In a high-load scenario, they might starve other critical components like the Spring Boot app or MongoDB. If the cluster becomes unstable, consider adding explicit limits to these files.

### 3. OOM (Out of Memory) Handling
If you see a pod with the status `CrashLoopBackOff` and a reason of `OOMKilled`, it means the process tried to use more than its **Limit**.
*   **Fix:** Increase the `limits.memory` in the corresponding `values-xxx.yaml` file.
*   **Startup Headroom:** Spring Boot and MongoDB 8.x require significant memory during the JVM/Engine startup phase. We recommend at least **1Gi** for the application pod.

### 4. CPU Throttling
If CPU usage hits the **Limit**, Kubernetes will "throttle" the pod (slow it down) rather than killing it. If the application feels sluggish or health checks time out, consider increasing the `limits.cpu`.
