package com.bwgjoseph.observability;

import io.micrometer.observation.ObservationPredicate;
import io.micrometer.observation.ObservationRegistry;
import io.micrometer.observation.aop.ObservedAspect;
import org.springframework.boot.actuate.autoconfigure.observation.ObservationRegistryCustomizer;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.server.observation.ServerRequestObservationContext;

@Configuration
public class ObservabilityConfig {

    @Bean
    ObservedAspect observedAspect(ObservationRegistry observationRegistry) {
        return new ObservedAspect(observationRegistry);
    }

    @Bean
    public ObservationRegistryCustomizer<ObservationRegistry> customizer(SecurityObservationHandler securityObservationHandler) {
        return registry -> registry.observationConfig().observationHandler(securityObservationHandler);
    }

    // we can globally provide a predicate to ignore observation
    @Bean
    public ObservationPredicate noActuatorObservations() {
        return (name, context) -> {
            if (context instanceof ServerRequestObservationContext httpContext) {
                return !httpContext.getCarrier().getRequestURI().contains("/actuator");
            }

            return true;
        };
    }
}
