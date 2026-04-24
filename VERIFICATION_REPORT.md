# 🧪 E2E Observability Verification Report
**Test ID:** 50959d57
**Timestamp:** 2026-04-25 01:08:33

| Component | Test Case | Result | Details |
| :--- | :--- | :--- | :--- |
| Prometheus | Debezium CDC Metrics | PASS | Events seen: 13 |
| Loki | Log Capture & Correlation | FAIL | No logs found for TestID |
| Tempo | Distributed Tracing | PASS | Successfully captured recent traces |
| Alloy | K8s Infrastructure Enrichment | PASS | Pod metadata found: spring-boot-app-774df4b655-pxvld spring-boot-app-774df4b655-pxvld spring-boot-app-774df4b655-pxvld |
