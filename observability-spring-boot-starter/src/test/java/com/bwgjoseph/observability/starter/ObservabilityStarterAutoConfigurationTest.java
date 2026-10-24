package com.bwgjoseph.observability.starter;

import com.bwgjoseph.observability.starter.core.ActuatorNoiseObservationPredicate;
import com.bwgjoseph.observability.starter.core.LgtmCoreAutoConfiguration;
import com.bwgjoseph.observability.starter.metrics.LgtmMetricsAutoConfiguration;
import com.bwgjoseph.observability.starter.security.LgtmSecurityAutoConfiguration;
import com.bwgjoseph.observability.starter.security.SecurityObservationHandler;
import io.micrometer.core.instrument.config.MeterFilter;
import io.micrometer.observation.ObservationPredicate;
import io.micrometer.tracing.Tracer;
import org.junit.jupiter.api.Test;
import org.springframework.boot.autoconfigure.AutoConfigurations;
import org.springframework.boot.test.context.FilteredClassLoader;
import org.springframework.boot.test.context.runner.ApplicationContextRunner;
import org.springframework.security.core.context.SecurityContextHolder;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;

class ObservabilityStarterAutoConfigurationTest {

    private final ApplicationContextRunner contextRunner = new ApplicationContextRunner()
            .withConfiguration(AutoConfigurations.of(
                    LgtmCoreAutoConfiguration.class,
                    LgtmSecurityAutoConfiguration.class,
                    LgtmMetricsAutoConfiguration.class
            ));

    @Test
    void coreBeansAreLoadedByDefault() {
        contextRunner.run(context -> {
            assertThat(context).hasSingleBean(LgtmObservabilityProperties.class);
            assertThat(context).hasSingleBean(ObservationPredicate.class);
            assertThat(context).hasBean("lgtmActuatorNoiseObservationPredicate");
        });
    }

    @Test
    void coreBeansBackOffWhenDisabled() {
        contextRunner
                .withPropertyValues("lgtm.observability.enabled=false")
                .run(context -> {
                    assertThat(context).doesNotHaveBean(ObservationPredicate.class);
                });
    }

    @Test
    void securityBeansLoadWhenClassAndTracerPresent() {
        contextRunner
                .withBean(Tracer.class, () -> mock(Tracer.class))
                .run(context -> {
                    assertThat(context).hasSingleBean(SecurityObservationHandler.class);
                });
    }

    @Test
    void securityBeansBackOffWhenSecurityContextHolderAbsent() {
        contextRunner
                .withClassLoader(new FilteredClassLoader(SecurityContextHolder.class))
                .withBean(Tracer.class, () -> mock(Tracer.class))
                .run(context -> {
                    assertThat(context).doesNotHaveBean(SecurityObservationHandler.class);
                });
    }

    @Test
    void securityBeansBackOffWhenExplicitlyDisabled() {
        contextRunner
                .withPropertyValues("lgtm.observability.security.enabled=false")
                .withBean(Tracer.class, () -> mock(Tracer.class))
                .run(context -> {
                    assertThat(context).doesNotHaveBean(SecurityObservationHandler.class);
                });
    }

    @Test
    void metricFilterIsRegisteredByDefault() {
        contextRunner.run(context -> {
            assertThat(context).hasBean("lgtmHistogramMeterFilter");
        });
    }

    @Test
    void metricFilterBacksOffWhenDisabled() {
        contextRunner
                .withPropertyValues("lgtm.observability.metrics.histograms.enabled=false")
                .run(context -> {
                    assertThat(context).doesNotHaveBean(MeterFilter.class);
                });
    }
}
