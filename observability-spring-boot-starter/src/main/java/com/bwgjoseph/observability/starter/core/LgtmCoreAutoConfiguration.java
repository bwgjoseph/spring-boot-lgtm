package com.bwgjoseph.observability.starter.core;

import com.bwgjoseph.observability.starter.LgtmObservabilityProperties;
import io.micrometer.observation.ObservationPredicate;
import io.micrometer.observation.ObservationRegistry;
import io.micrometer.observation.aop.ObservedAspect;
import org.aspectj.lang.ProceedingJoinPoint;
import org.springframework.boot.autoconfigure.AutoConfiguration;
import org.springframework.boot.autoconfigure.condition.ConditionalOnClass;
import org.springframework.boot.autoconfigure.condition.ConditionalOnMissingBean;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.http.server.observation.ServerRequestObservationContext;

/**
 * Core auto-configuration for the LGTM Observability Starter.
 *
 * <p>This class is activated when {@code lgtm.observability.enabled=true} (default) and
 * registers the following beans:
 *
 * <ul>
 *   <li>{@link ObservedAspect} — enables {@code @Observed} AOP support for annotated methods,
 *       conditional on AspectJ ({@link ProceedingJoinPoint}) and an active
 *       {@link ObservationRegistry} bean being present.</li>
 *   <li>{@code lgtmActuatorNoiseObservationPredicate} — suppresses observations for
 *       noisy actuator endpoints, conditional on Spring Web MVC being on the classpath.</li>
 * </ul>
 *
 * <p>Configuration is bound via {@link LgtmObservabilityProperties}.
 */
@AutoConfiguration
@ConditionalOnProperty(prefix = "lgtm.observability", name = "enabled", havingValue = "true", matchIfMissing = true)
@EnableConfigurationProperties(LgtmObservabilityProperties.class)
public class LgtmCoreAutoConfiguration {

    /**
     * Registers an {@link ObservedAspect} that drives {@code @Observed} annotation
     * support via AspectJ AOP.
     *
     * <p>Only created when:
     * <ul>
     *   <li>AspectJ ({@code org.aspectj.lang.ProceedingJoinPoint}) is on the classpath.</li>
     *   <li>An {@link ObservationRegistry} bean is already present in the context.</li>
     *   <li>No other {@code ObservedAspect} bean has been defined by the application.</li>
     * </ul>
     *
     * @param observationRegistry the active Micrometer observation registry
     * @return a configured {@link ObservedAspect}
     */
    @Bean
    @ConditionalOnMissingBean
    @ConditionalOnClass(ProceedingJoinPoint.class)
    @org.springframework.boot.autoconfigure.condition.ConditionalOnBean(ObservationRegistry.class)
    public ObservedAspect observedAspect(ObservationRegistry observationRegistry) {
        return new ObservedAspect(observationRegistry);
    }

    /**
     * Registers an {@link ObservationPredicate} that suppresses observations for
     * configured actuator and custom paths.
     *
     * <p>Only created when Spring Web MVC ({@link ServerRequestObservationContext}) is
     * on the classpath and no bean named {@code lgtmActuatorNoiseObservationPredicate}
     * has been defined by the application.
     *
     * @param properties the LGTM observability configuration properties
     * @return a configured {@link ActuatorNoiseObservationPredicate}
     */
    @Bean
    @ConditionalOnMissingBean(name = "lgtmActuatorNoiseObservationPredicate")
    @ConditionalOnClass(ServerRequestObservationContext.class)
    public ObservationPredicate lgtmActuatorNoiseObservationPredicate(LgtmObservabilityProperties properties) {
        return new ActuatorNoiseObservationPredicate(properties);
    }
}
