# 🧪 E2E Observability Verification Report
**Test ID:** bf3c8770
**Timestamp:** 2026-04-26 15:38:30

| Component | Test Case | Result | Details |
| :--- | :--- | :--- | :--- |
| Prometheus | Debezium CDC Metrics | PASS | Events seen: 13 |
| Loki | Log Capture & Correlation | FAIL | No logs found for TestID |
| Tempo | Distributed Tracing | PASS | Successfully captured recent traces |
| Alloy | K8s Infrastructure Enrichment | PASS | Pod metadata found: spring-boot-app-6768bdfb85-jnbzv spring-boot-app-6768bdfb85-jnbzv spring-boot-app-6768bdfb85-jnbzv spring-boot-app-6768bdfb85-jnbzv spring-boot-app-6768bdfb85-jnbzv spring-boot-app-6768bdfb85-jnbzv spring-boot-app-6768bdfb85-jnbzv spring-boot-app-6768bdfb85-jnbzv |
