package com.bwgjoseph.observability.starter.resource;

import com.bwgjoseph.observability.starter.LgtmObservabilityProperties;
import io.opentelemetry.api.common.AttributeKey;
import io.opentelemetry.api.common.Attributes;
import io.opentelemetry.api.common.AttributesBuilder;
import io.opentelemetry.sdk.resources.Resource;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.boot.autoconfigure.AutoConfiguration;
import org.springframework.boot.autoconfigure.condition.ConditionalOnClass;
import org.springframework.boot.autoconfigure.condition.ConditionalOnMissingBean;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.boot.info.BuildProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.core.env.Environment;
import org.springframework.util.StringUtils;

/**
 * Auto-configuration for OpenTelemetry resource attributes.
 *
 * <p>Registers an OTel {@link Resource} bean that decorates traces with standard
 * service identity attributes consumed by Tempo and Grafana:
 * <ul>
 *   <li>{@code service.name} — resolved from {@code spring.application.name}.</li>
 *   <li>{@code service.version} — resolved from Maven {@link BuildProperties} (if available).</li>
 *   <li>{@code deployment.environment} — resolved from
 *       {@code lgtm.observability.resource.environment}, falling back to the
 *       {@code ENVIRONMENT} environment variable.</li>
 * </ul>
 *
 * <p>Activated when:
 * <ul>
 *   <li>The OpenTelemetry SDK ({@link Resource}) is on the classpath.</li>
 *   <li>{@code lgtm.observability.resource.enabled=true} (default).</li>
 * </ul>
 *
 * <p>The application can override the bean by declaring its own bean named
 * {@code lgtmOpenTelemetryResource}.
 */
@AutoConfiguration
@ConditionalOnClass(Resource.class)
@ConditionalOnProperty(prefix = "lgtm.observability.resource", name = "enabled", havingValue = "true", matchIfMissing = true)
@EnableConfigurationProperties(LgtmObservabilityProperties.class)
public class LgtmResourceAutoConfiguration {

    /**
     * Creates an OTel {@link Resource} populated with service identity attributes
     * derived from the Spring environment and Maven build metadata.
     *
     * <p>Attribute resolution order:
     * <ol>
     *   <li>{@code service.name} ← {@code spring.application.name} (omitted if blank).</li>
     *   <li>{@code service.version} ← {@link BuildProperties#getVersion()} (omitted if
     *       {@link BuildProperties} is not available or version is blank).</li>
     *   <li>{@code deployment.environment} ← {@code lgtm.observability.resource.environment},
     *       then {@code ENVIRONMENT} env variable (omitted if neither is set).</li>
     * </ol>
     *
     * @param environment            the Spring {@link Environment} for property resolution
     * @param properties             the LGTM observability configuration properties
     * @param buildPropertiesProvider optional provider of Maven build metadata
     * @return an OTel {@link Resource} with the resolved service attributes
     */
    @Bean
    @ConditionalOnMissingBean(name = "lgtmOpenTelemetryResource")
    public Resource lgtmOpenTelemetryResource(Environment environment,
                                              LgtmObservabilityProperties properties,
                                              ObjectProvider<BuildProperties> buildPropertiesProvider) {
        AttributesBuilder builder = Attributes.builder();

        String serviceName = environment.getProperty("spring.application.name");
        if (StringUtils.hasText(serviceName)) {
            builder.put(AttributeKey.stringKey("service.name"), serviceName);
        }

        BuildProperties buildProperties = buildPropertiesProvider.getIfAvailable();
        if (buildProperties != null && StringUtils.hasText(buildProperties.getVersion())) {
            builder.put(AttributeKey.stringKey("service.version"), buildProperties.getVersion());
        }

        String environmentName = properties.getResource().getEnvironment();
        if (!StringUtils.hasText(environmentName)) {
            environmentName = environment.getProperty("ENVIRONMENT");
        }
        if (StringUtils.hasText(environmentName)) {
            builder.put(AttributeKey.stringKey("deployment.environment"), environmentName);
        }

        return Resource.create(builder.build());
    }
}
