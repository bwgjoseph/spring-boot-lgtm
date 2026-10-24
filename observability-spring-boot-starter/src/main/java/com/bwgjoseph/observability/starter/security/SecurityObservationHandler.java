package com.bwgjoseph.observability.starter.security;

import com.bwgjoseph.observability.starter.LgtmObservabilityProperties;
import io.micrometer.common.KeyValue;
import io.micrometer.observation.Observation;
import io.micrometer.tracing.Baggage;
import io.micrometer.tracing.Tracer;
import io.micrometer.tracing.handler.TracingObservationHandler;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;

/**
 * A {@link TracingObservationHandler} that correlates the authenticated Spring Security
 * principal with the active trace.
 *
 * <p>On each observation start, this handler:
 * <ol>
 *   <li>Reads the current {@link Authentication} from
 *       {@link SecurityContextHolder}.</li>
 *   <li>Adds the principal name as a high-cardinality span attribute (e.g.
 *       {@code user_id=alice}) so that it appears in Tempo.</li>
 *   <li>Writes the value into W3C Baggage (e.g. {@code userId}) so that it is
 *       automatically synchronized to MDC and included in log records.</li>
 * </ol>
 *
 * <p>The span attribute key and baggage field name are configurable via
 * {@link LgtmObservabilityProperties.Security}. Anonymous principals are skipped by
 * default and can be included via {@code lgtm.observability.security.include-anonymous=true}.
 *
 * <p>Auto-configured by {@link LgtmSecurityAutoConfiguration} when Spring Security
 * and Micrometer Tracing are both present on the classpath.
 */
public class SecurityObservationHandler implements TracingObservationHandler<Observation.Context> {

    private final Tracer tracer;
    private final LgtmObservabilityProperties properties;

    /**
     * Creates a new handler with the given tracer and configuration.
     *
     * @param tracer     the Micrometer {@link Tracer} used to write baggage entries
     * @param properties the LGTM observability configuration properties
     */
    public SecurityObservationHandler(Tracer tracer, LgtmObservabilityProperties properties) {
        this.tracer = tracer;
        this.properties = properties;
    }

    /**
     * Called when an observation starts. Extracts the authenticated principal name and:
     * <ul>
     *   <li>Adds it as a high-cardinality span attribute (key from
     *       {@link LgtmObservabilityProperties.Security#getAttributeName()}).</li>
     *   <li>Propagates it via W3C Baggage (field from
     *       {@link LgtmObservabilityProperties.Security#getBaggageField()}) so that the
     *       value is automatically synchronized to MDC for log correlation.</li>
     * </ul>
     *
     * <p>Anonymous principals ({@code "anonymousUser"}) are skipped unless
     * {@code lgtm.observability.security.include-anonymous=true}.
     *
     * @param context the current observation context
     */
    @Override
    public void onStart(Observation.Context context) {
        Authentication authentication = SecurityContextHolder.getContext().getAuthentication();
        if (authentication != null && authentication.isAuthenticated()) {
            boolean isAnonymous = "anonymousUser".equalsIgnoreCase(authentication.getName());
            if (isAnonymous && !properties.getSecurity().isIncludeAnonymous()) {
                return;
            }

            String username = authentication.getName();
            // 1. Add user_id tag to observation (Span Attribute for Tempo)
            context.addHighCardinalityKeyValue(KeyValue.of(properties.getSecurity().getAttributeName(), username));

            // 2. Set userId as Baggage (Synchronized to MDC for logs)
            if (this.tracer != null) {
                Baggage baggage = this.tracer.getBaggage(properties.getSecurity().getBaggageField());
                if (baggage != null) {
                    baggage.makeCurrent(username);
                }
            }
        }
    }

    /**
     * Returns {@code true} for all observation contexts. Security correlation is
     * applied universally; the principal availability check is deferred to
     * {@link #onStart(Observation.Context)}.
     *
     * @param context the observation context to evaluate
     * @return always {@code true}
     */
    @Override
    public boolean supportsContext(Observation.Context context) {
        return true;
    }

    /**
     * Returns the configured {@link Tracer} instance.
     *
     * @return the tracer used to read and write baggage entries
     */
    @Override
    public Tracer getTracer() {
        return this.tracer;
    }
}
