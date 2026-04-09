# Proposal: Custom Span and Resource Attributes

This document outlines the strategy for implementing custom metadata (Resource Attributes) and request-specific data (Span Attributes) within the Spring Boot LGTM stack.

## 1. Resource Attributes (Static Metadata)
Resource attributes describe the service itself. These are set once at startup and appear on every Trace, Metric, and Log.

### Recommended Metadata
*   `deployment.environment`: `production`, `staging`, `sandbox`
*   `service.version`: The build version (e.g., `1.0.4`)
*   `service.namespace`: The K8s namespace (`monitoring`)
*   `team.owner`: The team responsible for the service.

### Implementation: Kubernetes Env Vars
Update `deployment/deployment.yaml` (or production values):
```yaml
env:
  - name: OTEL_RESOURCE_ATTRIBUTES
    value: "deployment.environment=sandbox,service.version=1.0.0,team.owner=platform"
```

---

## 2. Dynamic Attributes (Request Level)
Dynamic attributes change based on the specific transaction (e.g., `userId`, `orderId`).

### Strategy A: Method-Specific via `@Observed`
To add dynamic attributes to an annotated method, we use an `ObservationConvention`. This allows you to "intercept" the observation and add data from the method's context.

**1. Define a Context-aware Logic:**
```java
@Component
public class PokemonObservationConvention extends DefaultServerRequestObservationConvention {
    @Override
    public KeyValues getHighCardinalityKeyValues(ServerRequestObservationContext context) {
        // High Cardinality = Span Attributes (Tempo)
        return KeyValues.of("http.userId", context.getRequest().getHeader("X-User-Id"));
    }
}
```

### Strategy B: Global MDC Correlation (`userId`)
Since you already have `userId` in MDC for logs, we want to ensure it also appears in **Tempo Spans** and becomes a searchable **Loki Label**.

**1. Application Code (MDC to Span):**
In your `ObservabilityConfig.java`, add a `PropagatingReceiverTracingObservationHandler`. This ensures that when you set a value in the MDC, it is also added to the current Span.

**2. Grafana Alloy (Log to Label):**
Update `loki.process` in `values-alloy.yaml` to extract the `userId` from the log line (using your existing MDC pattern) and promote it.

```hcl
loki.process "extract_metadata" {
  stage.regex {
    // Matches: [spring-boot-app,trace_id,span_id,userId]
    expression = ".*\\[(?P<app>.+?),(?P<trace_id>\\w*),(?P<span_id>\\w*),(?P<userId>\\w*)\\].*"
  }
  stage.labels {
    values = { "userId" = "" } // Promotes userId to a searchable label
  }
}
```

---

## 3. Implementation Example: Manual Observation
For the highest precision in business logic where `@Observed` is too rigid:

```java
public Pokemon getPokemon(String pokemonId, String userId) {
    Observation observation = Observation.createNotStarted("pokemon.lookup", observationRegistry)
        .contextualName("fetch-pokemon-for-user")
        .lowCardinalityKeyValue("pokemon.id", pokemonId) // Added to Metrics
        .highCardinalityKeyValue("user.id", userId)      // Added to Spans (Tempo)
        .start();

    try (Observation.Scope scope = observation.openScope()) {
        return restClient.get().uri("/{id}", pokemonId).retrieve().body(Pokemon.class);
    } catch (Exception e) {
        observation.error(e);
        throw e;
    } finally {
        observation.stop();
    }
}
```

## Summary Recommendation
1.  **Static:** Use `OTEL_RESOURCE_ATTRIBUTES` in your deployment manifests.
2.  **UserId:** Use a custom `TracingObservationHandler` to sync MDC to Spans, and Alloy regex to sync MDC to Loki Labels.
3.  **Business Logic:** Use manual `Observation` blocks for complex dynamic data, and `@Observed` for simple execution timing.
