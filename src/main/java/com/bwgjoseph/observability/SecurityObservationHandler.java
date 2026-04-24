package com.bwgjoseph.observability;

import io.micrometer.common.KeyValue;
import io.micrometer.observation.Observation;
import io.micrometer.tracing.Tracer;
import io.micrometer.tracing.handler.TracingObservationHandler;
import org.springframework.http.server.observation.ServerRequestObservationContext;
import org.springframework.security.authentication.AuthenticationObservationContext;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;

import java.util.Objects;

@Component
public class SecurityObservationHandler implements TracingObservationHandler<Observation.Context> {

    private final Tracer tracer;

    public SecurityObservationHandler(Tracer tracer) {
        this.tracer = tracer;
    }

    @Override
    public void onStart(Observation.Context context) {
        Authentication authentication = SecurityContextHolder.getContext().getAuthentication();
        if (authentication != null && authentication.isAuthenticated()) {
            String username = authentication.getName();
            // 1. Add user_id tag to observation (Span Attribute for Tempo)
            context.addHighCardinalityKeyValue(KeyValue.of("user_id", username));

            // 2. Set userId as Baggage (Synchronized to MDC for logs)
            // Note: We use 'userId' here to match the application.yaml correlation field
            if (this.tracer != null) {
                Objects.requireNonNull(this.tracer.getBaggage("userId")).makeCurrent(username);
            }
        }
    }

    // or the predicate to ignore can be set locally
    @Override
    public boolean supportsContext(Observation.Context context) {
        // supports only http request, and not from /actuator endpoint
//        if (context instanceof ServerRequestObservationContext httpContext) {
//            return !httpContext.getCarrier().getRequestURI().contains("/actuator");
//        }
//
//        return false;
        // looks like when integrating with Spring Security, this seem to not work, need to figure out
//        return context instanceof ServerRequestObservationContext || context instanceof AuthenticationObservationContext;
        return true;
    }

    @Override
    public Tracer getTracer() {
        return this.tracer;
    }
}
