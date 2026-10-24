package com.bwgjoseph.observability.starter.security;

import com.bwgjoseph.observability.starter.LgtmObservabilityProperties;
import com.bwgjoseph.observability.starter.core.LgtmCoreAutoConfiguration;
import io.micrometer.observation.ObservationRegistry;
import io.micrometer.tracing.Tracer;
import org.springframework.boot.actuate.autoconfigure.observation.ObservationRegistryCustomizer;
import org.springframework.boot.autoconfigure.AutoConfiguration;
import org.springframework.boot.autoconfigure.AutoConfigureAfter;
import org.springframework.boot.autoconfigure.condition.ConditionalOnClass;
import org.springframework.boot.autoconfigure.condition.ConditionalOnMissingBean;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.security.core.context.SecurityContextHolder;

/**
 * Auto-configuration for Spring Security user-identity observation correlation.
 *
 * <p>This class is activated only when all of the following conditions are met:
 * <ul>
 *   <li>Spring Security ({@link SecurityContextHolder}) is on the classpath.</li>
 *   <li>Micrometer Tracing ({@link Tracer}) is on the classpath.</li>
 *   <li>A {@link Tracer} bean is present in the application context.</li>
 *   <li>{@code lgtm.observability.security.enabled=true} (default).</li>
 * </ul>
 *
 * <p>Registers a {@link SecurityObservationHandler} and an
 * {@link ObservationRegistryCustomizer} that installs it into the active
 * {@link ObservationRegistry}. Both beans can be overridden by the application.
 *
 * @see LgtmCoreAutoConfiguration
 */
@AutoConfiguration
@AutoConfigureAfter(LgtmCoreAutoConfiguration.class)
@ConditionalOnClass({ SecurityContextHolder.class, Tracer.class })
@org.springframework.boot.autoconfigure.condition.ConditionalOnBean(Tracer.class)
@ConditionalOnProperty(prefix = "lgtm.observability.security", name = "enabled", havingValue = "true", matchIfMissing = true)
@EnableConfigurationProperties(LgtmObservabilityProperties.class)
public class LgtmSecurityAutoConfiguration {

    /**
     * Registers the {@link SecurityObservationHandler} that extracts the authenticated
     * principal name and writes it to the active span and baggage.
     *
     * <p>Skipped if an application-defined {@code SecurityObservationHandler} bean
     * already exists.
     *
     * @param tracer     the active Micrometer tracer
     * @param properties the LGTM observability configuration properties
     * @return a configured {@link SecurityObservationHandler}
     */
    @Bean
    @ConditionalOnMissingBean
    public SecurityObservationHandler securityObservationHandler(Tracer tracer, LgtmObservabilityProperties properties) {
        return new SecurityObservationHandler(tracer, properties);
    }

    /**
     * Registers an {@link ObservationRegistryCustomizer} that installs the
     * {@link SecurityObservationHandler} into the {@link ObservationRegistry}.
     *
     * <p>Skipped if a bean named {@code lgtmSecurityObservationRegistryCustomizer}
     * already exists.
     *
     * @param securityObservationHandler the handler to install
     * @return a customizer that adds the handler to the registry's observation config
     */
    @Bean
    @ConditionalOnMissingBean(name = "lgtmSecurityObservationRegistryCustomizer")
    public ObservationRegistryCustomizer<ObservationRegistry> lgtmSecurityObservationRegistryCustomizer(SecurityObservationHandler securityObservationHandler) {
        return registry -> registry.observationConfig().observationHandler(securityObservationHandler);
    }
}
