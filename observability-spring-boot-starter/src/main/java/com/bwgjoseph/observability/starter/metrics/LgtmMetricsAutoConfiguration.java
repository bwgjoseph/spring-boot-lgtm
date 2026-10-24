package com.bwgjoseph.observability.starter.metrics;

import com.bwgjoseph.observability.starter.LgtmObservabilityProperties;
import io.micrometer.core.instrument.config.MeterFilter;
import io.micrometer.core.instrument.distribution.DistributionStatisticConfig;
import org.springframework.boot.autoconfigure.AutoConfiguration;
import org.springframework.boot.autoconfigure.condition.ConditionalOnClass;
import org.springframework.boot.autoconfigure.condition.ConditionalOnMissingBean;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Bean;

import java.time.Duration;
import java.util.List;

/**
 * Auto-configuration for Micrometer histogram and SLO bucket configuration.
 *
 * <p>Registers a {@link MeterFilter} that enables percentile histograms and configures
 * SLO (Service-Level Objective) bucket boundaries for a set of target meter names.
 * This is required for Grafana to render accurate latency heatmaps and percentile
 * panels backed by Prometheus native histograms.
 *
 * <p>Activated when:
 * <ul>
 *   <li>Micrometer ({@link MeterFilter}) is on the classpath.</li>
 *   <li>{@code lgtm.observability.metrics.histograms.enabled=true} (default).</li>
 * </ul>
 *
 * <p>Default target meters: {@code http.server.requests}, {@code mongodb.command},
 * {@code http.client.requests}. Configure via
 * {@code lgtm.observability.metrics.histograms.targets} and
 * {@code lgtm.observability.metrics.histograms.sla-buckets}.
 */
@AutoConfiguration
@ConditionalOnClass(MeterFilter.class)
@ConditionalOnProperty(prefix = "lgtm.observability.metrics.histograms", name = "enabled", havingValue = "true", matchIfMissing = true)
@EnableConfigurationProperties(LgtmObservabilityProperties.class)
public class LgtmMetricsAutoConfiguration {

    /**
     * Creates a {@link MeterFilter} that applies percentile histogram configuration to
     * meters whose names match any of the configured target prefixes.
     *
     * <p>For each matching meter the filter enables:
     * <ul>
     *   <li>Prometheus native histogram ({@code percentilesHistogram=true}).</li>
     *   <li>Explicit SLO bucket boundaries (converted from {@link Duration} to seconds).</li>
     * </ul>
     *
     * <p>Skipped if a bean named {@code lgtmHistogramMeterFilter} already exists,
     * allowing the application to provide a fully custom implementation.
     *
     * @param properties the LGTM observability configuration properties
     * @return a {@link MeterFilter} configured with the target meters and SLO buckets
     */
    @Bean
    @ConditionalOnMissingBean(name = "lgtmHistogramMeterFilter")
    public MeterFilter lgtmHistogramMeterFilter(LgtmObservabilityProperties properties) {
        List<String> targets = properties.getMetrics().getHistograms().getTargets();
        List<Duration> slaBuckets = properties.getMetrics().getHistograms().getSlaBuckets();
        double[] serviceLevelObjectives = slaBuckets.stream()
                .mapToDouble(d -> d.toNanos() / 1_000_000_000.0)
                .toArray();

        return new MeterFilter() {
            @Override
            public DistributionStatisticConfig configure(io.micrometer.core.instrument.Meter.Id id, DistributionStatisticConfig config) {
                for (String target : targets) {
                    if (id.getName().startsWith(target)) {
                        return DistributionStatisticConfig.builder()
                                .percentilesHistogram(true)
                                .serviceLevelObjectives(serviceLevelObjectives)
                                .build()
                                .merge(config);
                    }
                }
                return config;
            }
        };
    }
}
