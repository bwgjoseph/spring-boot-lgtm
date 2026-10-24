package com.bwgjoseph.observability.starter.debezium;

import com.bwgjoseph.observability.starter.LgtmObservabilityProperties;
import org.springframework.boot.autoconfigure.AutoConfiguration;
import org.springframework.boot.autoconfigure.condition.ConditionalOnClass;
import org.springframework.boot.autoconfigure.condition.ConditionalOnMissingBean;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Bean;

/**
 * Auto-configuration for Debezium JMX metrics bridging.
 *
 * <p>Registers a {@link DebeziumMetricsBinder} that dynamically discovers Debezium
 * connector metrics from JMX and exposes them to Micrometer (and subsequently to
 * Prometheus / Grafana).
 *
 * <p>Activated when:
 * <ul>
 *   <li>{@code io.debezium.embedded.EmbeddedEngine} is on the classpath, indicating
 *       that Debezium Embedded is in use.</li>
 *   <li>{@code lgtm.observability.debezium.jmx.enabled=true} (default).</li>
 * </ul>
 *
 * <p>The application can replace the binder entirely by declaring its own
 * {@code DebeziumMetricsBinder} bean.
 */
@AutoConfiguration
@ConditionalOnClass(name = "io.debezium.embedded.EmbeddedEngine")
@ConditionalOnProperty(prefix = "lgtm.observability.debezium.jmx", name = "enabled", havingValue = "true", matchIfMissing = true)
@EnableConfigurationProperties(LgtmObservabilityProperties.class)
public class LgtmDebeziumAutoConfiguration {

    /**
     * Creates a {@link DebeziumMetricsBinder} using the configured meter name prefix.
     *
     * <p>Skipped if a {@code DebeziumMetricsBinder} bean already exists in the context.
     *
     * @param properties the LGTM observability configuration properties
     * @return a binder that bridges Debezium JMX attributes to Micrometer
     */
    @Bean
    @ConditionalOnMissingBean
    public DebeziumMetricsBinder debeziumMetricsBinder(LgtmObservabilityProperties properties) {
        return new DebeziumMetricsBinder(properties.getDebezium().getJmx().getPrefix());
    }
}
