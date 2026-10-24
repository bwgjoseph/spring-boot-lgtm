package com.bwgjoseph.observability.starter.logging;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.env.EnvironmentPostProcessor;
import org.springframework.core.Ordered;
import org.springframework.core.env.ConfigurableEnvironment;
import org.springframework.core.env.MapPropertySource;

import java.util.HashMap;
import java.util.Map;

/**
 * An {@link EnvironmentPostProcessor} that injects a sensible default
 * {@code logging.pattern.correlation} when one has not been explicitly configured.
 *
 * <p>The default pattern is:
 * <pre>{@code [${spring.application.name:},%X{traceId:-},%X{spanId:-},%X{userId:-}]}</pre>
 *
 * <p>This pattern ensures that log records emitted by the application include the
 * service name, trace ID, span ID, and user ID in a format that Grafana Alloy can
 * parse and map to Loki Structured Metadata for log-to-trace correlation.
 *
 * <p>The property source is added at {@link Ordered#LOWEST_PRECEDENCE} so that any
 * value declared in {@code application.yaml}, profile YAML, or system properties takes
 * precedence and overrides the starter default.
 *
 * <p>The feature can be disabled entirely via
 * {@code lgtm.observability.logging.correlation.enabled=false}.
 */
public class LgtmLoggingEnvironmentPostProcessor implements EnvironmentPostProcessor, Ordered {

    private static final String PROPERTY_NAME = "logging.pattern.correlation";
    private static final String DEFAULT_CORRELATION_PATTERN = "[${spring.application.name:},%X{traceId:-},%X{spanId:-},%X{userId:-}]";

    /**
     * Injects the default {@code logging.pattern.correlation} property when it has not
     * already been set by the application.
     *
     * <p>If {@code lgtm.observability.logging.correlation.enabled} is {@code false} this
     * method returns immediately without modifying the environment.
     *
     * @param environment the Spring {@link ConfigurableEnvironment} to post-process
     * @param application the Spring application being started
     */
    @Override
    public void postProcessEnvironment(ConfigurableEnvironment environment, SpringApplication application) {
        Boolean enabled = environment.getProperty("lgtm.observability.logging.correlation.enabled", Boolean.class, Boolean.TRUE);
        if (!enabled) {
            return;
        }

        // Only supply if not explicitly set by the application
        if (!environment.containsProperty(PROPERTY_NAME)) {
            Map<String, Object> props = new HashMap<>();
            props.put(PROPERTY_NAME, DEFAULT_CORRELATION_PATTERN);
            // Add as lowest priority so application.yaml / profile yaml takes precedence
            environment.getPropertySources().addLast(new MapPropertySource("lgtmLoggingDefaults", props));
        }
    }

    /**
     * Returns {@link Ordered#LOWEST_PRECEDENCE} so that this post-processor runs last
     * and application-defined property sources can override the default pattern.
     *
     * @return {@link Ordered#LOWEST_PRECEDENCE}
     */
    @Override
    public int getOrder() {
        return Ordered.LOWEST_PRECEDENCE;
    }
}
