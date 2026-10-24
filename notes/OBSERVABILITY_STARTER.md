# 🚀 Observability Spring Boot Starter Guide

`observability-spring-boot-starter` is an unopinionated, modular Spring Boot starter designed for applications deploying into a **Grafana LGTM stack** (Loki, Grafana, Tempo, Mimir/Prometheus) using **Grafana Alloy** as the telemetry gateway.

It standardizes observability concerns into a single reusable dependency with **safe defaults, zero forced classpath assumptions, and complete overridability**.

---

## 📦 1. Installation

Add the starter to your Maven `pom.xml`:

```xml
<dependency>
    <groupId>com.bwgjoseph</groupId>
    <artifactId>observability-spring-boot-starter</artifactId>
    <version>${project.version}</version>
</dependency>
```

---

## ⚙️ 2. Core Capabilities & Defaults

| Feature | Default Behavior | Overriding / Customization |
| :--- | :--- | :--- |
| **Actuator Noise Filter** | Suppresses tracing and metric observations on `/actuator/health`, `/actuator/prometheus`, `/actuator/jolokia`, `/actuator/info`. | Add custom paths via `lgtm.observability.filter.custom-excluded-paths` or declare a custom `@Bean ObservationPredicate`. |
| **@Observed Support** | Auto-configures `ObservedAspect` when AspectJ is on the classpath. | Declare a custom `@Bean ObservedAspect`. |
| **Security User Correlation** | If Spring Security & a `Tracer` bean are present, automatically injects `user_id` as a high-cardinality span attribute and `userId` as W3C baggage (synced to MDC). Anonymous principals are skipped by default. | Disable with `lgtm.observability.security.enabled=false` or declare a custom `@Bean SecurityObservationHandler`. |
| **Metric Percentile Histograms** | Auto-configures `percentilesHistogram(true)` and default SLA buckets (5ms–5s) for `http.server.requests`, `mongodb.command`, and `http.client.requests`. | Customize targets / buckets in `lgtm.observability.metrics.histograms.*` or declare a custom `@Bean MeterFilter`. |
| **Logging Correlation Format** | Injects default `logging.pattern.correlation: "[${spring.application.name:},%X{traceId:-},%X{spanId:-},%X{userId:-}]"` (matching Grafana Alloy `stage.regex`). | Override `logging.pattern.correlation` in your `application.yaml` or set `lgtm.observability.logging.correlation.enabled: false`. |
| **OTel Resource Attributes** | Auto-configures OpenTelemetry `Resource` containing `service.name`, `service.version` (from `BuildProperties`), and `deployment.environment`. | Declare a custom `@Bean Resource` or set `lgtm.observability.resource.enabled: false`. |
| **Debezium JMX Binding** | If Debezium's EmbeddedEngine is on the classpath, dynamically discovers and binds JMX MBeans to Micrometer meters (`debezium.*`). | Disable with `lgtm.observability.debezium.jmx.enabled=false` or declare a custom `@Bean DebeziumMetricsBinder`. |

---

## 🛠️ 3. Configuration Properties Reference

All properties reside under the `lgtm.observability` prefix:

```yaml
lgtm:
  observability:
    # Master switch
    enabled: true

    # Actuator & endpoint noise filtering
    filter:
      actuator:
        enabled: true
        excluded-paths:
          - /actuator/health
          - /actuator/prometheus
          - /actuator/jolokia
          - /actuator/info
      custom-excluded-paths:
        - /favicon.ico
        - /internal/heartbeat

    # Spring Security context propagation
    security:
      enabled: true
      attribute-name: user_id     # Span tag name (Tempo)
      baggage-field: userId       # W3C baggage & MDC field name
      include-anonymous: false

    # Prometheus metric percentile distributions & SLAs
    metrics:
      histograms:
        enabled: true
        targets:
          - http.server.requests
          - mongodb.command
          - http.client.requests
        sla-buckets:
          - 5ms
          - 10ms
          - 25ms
          - 50ms
          - 100ms
          - 250ms
          - 500ms
          - 1s
          - 2s
          - 5s

    # OpenTelemetry Resource metadata
    resource:
      enabled: true
      environment: production    # Fallback reads $ENVIRONMENT

    # MDC log correlation
    logging:
      correlation:
        enabled: true            # Injects [app,traceId,spanId,userId]

    # Debezium JMX MBean metric bridge
    debezium:
      jmx:
        enabled: true
        prefix: debezium
```

---

## 🧩 4. Extension & Customization Recipes

### Recipe A: Custom Security Claim Extraction (e.g. JWT Tenant ID)
To customize or replace the default `SecurityObservationHandler`:
```java
@Configuration
public class MyObservabilityCustomizer {

    @Bean
    public SecurityObservationHandler mySecurityObservationHandler(Tracer tracer, LgtmObservabilityProperties properties) {
        return new SecurityObservationHandler(tracer, properties) {
            @Override
            public void onStart(Observation.Context context) {
                super.onStart(context);
                // Custom extraction logic for tenant / organization:
                Authentication auth = SecurityContextHolder.getContext().getAuthentication();
                if (auth instanceof JwtAuthenticationToken jwt) {
                    String tenant = jwt.getToken().getClaimAsString("tenant_id");
                    context.addHighCardinalityKeyValue(KeyValue.of("tenant_id", tenant));
                }
            }
        };
    }
}
```

### Recipe B: Overriding the Actuator Filter for a Custom Admin Endpoint
```yaml
lgtm:
  observability:
    filter:
      custom-excluded-paths:
        - /private/ping
        - /internal/readiness
```

### Recipe C: Customizing Latency SLA Buckets for Fast Microservices
```yaml
lgtm:
  observability:
    metrics:
      histograms:
        sla-buckets:
          - 1ms
          - 2ms
          - 5ms
          - 10ms
          - 20ms
```

---

## 🔍 5. Auto-Configuration Activation Reference

Each auto-configuration has its own set of activation conditions. This table summarises what is required for each feature to be active:

| Auto-Configuration | Classpath Required | Bean Required | Property (default) |
| :--- | :--- | :--- | :--- |
| `LgtmCoreAutoConfiguration` | — | — | `lgtm.observability.enabled=true` |
| `ObservedAspect` bean | `org.aspectj.lang.ProceedingJoinPoint` | `ObservationRegistry` | *(inherits core)* |
| `ActuatorNoiseObservationPredicate` bean | `ServerRequestObservationContext` | — | *(inherits core)* |
| `LgtmSecurityAutoConfiguration` | `SecurityContextHolder`, `Tracer` | `Tracer` | `lgtm.observability.security.enabled=true` |
| `LgtmMetricsAutoConfiguration` | `MeterFilter` | — | `lgtm.observability.metrics.histograms.enabled=true` |
| `LgtmResourceAutoConfiguration` | `io.opentelemetry.sdk.resources.Resource` | — | `lgtm.observability.resource.enabled=true` |
| `LgtmDebeziumAutoConfiguration` | `io.debezium.embedded.EmbeddedEngine` | — | `lgtm.observability.debezium.jmx.enabled=true` |
| `LgtmLoggingEnvironmentPostProcessor` | — | — | `lgtm.observability.logging.correlation.enabled=true` |

> [!NOTE]
> Security auto-configuration requires **both** `spring-security-core` on the classpath **and** a `Tracer` bean to be present. If you use Micrometer Tracing with a no-op tracer (e.g. in integration tests), the security correlation will be inactive unless a real `Tracer` is provided.
