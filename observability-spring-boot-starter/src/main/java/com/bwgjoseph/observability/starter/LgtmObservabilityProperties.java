package com.bwgjoseph.observability.starter;

import org.springframework.boot.context.properties.ConfigurationProperties;

import java.time.Duration;
import java.util.ArrayList;
import java.util.List;

/**
 * Root configuration properties for the LGTM Observability Starter.
 *
 * <p>All properties are bound under the {@code lgtm.observability} prefix. Each
 * feature area (filtering, security, metrics, resource, logging, Debezium) is
 * encapsulated in its own nested configuration class, enabling fine-grained
 * opt-in/opt-out control.
 *
 * <p>Example {@code application.yaml}:
 * <pre>{@code
 * lgtm:
 *   observability:
 *     enabled: true
 *     filter:
 *       actuator:
 *         enabled: true
 *         excluded-paths:
 *           - /actuator/health
 *     security:
 *       enabled: true
 *     metrics:
 *       histograms:
 *         enabled: true
 * }</pre>
 *
 * @see <a href="../notes/OBSERVABILITY_STARTER.md">OBSERVABILITY_STARTER.md</a>
 */
@ConfigurationProperties(prefix = "lgtm.observability")
public class LgtmObservabilityProperties {

    /** Whether the entire LGTM observability starter is enabled. Defaults to {@code true}. */
    private boolean enabled = true;
    private final Filter filter = new Filter();
    private final Security security = new Security();
    private final Metrics metrics = new Metrics();
    private final Resource resource = new Resource();
    private final Logging logging = new Logging();
    private final Debezium debezium = new Debezium();

    /**
     * Returns whether the entire LGTM observability starter is active.
     *
     * @return {@code true} if the starter is enabled
     */
    public boolean isEnabled() {
        return enabled;
    }

    /**
     * Enables or disables the entire LGTM observability starter.
     *
     * @param enabled {@code true} to activate the starter (default)
     */
    public void setEnabled(boolean enabled) {
        this.enabled = enabled;
    }

    /** Returns the observation filter configuration. */
    public Filter getFilter() {
        return filter;
    }

    /** Returns the Spring Security correlation configuration. */
    public Security getSecurity() {
        return security;
    }

    /** Returns the metrics histogram configuration. */
    public Metrics getMetrics() {
        return metrics;
    }

    /** Returns the OpenTelemetry resource configuration. */
    public Resource getResource() {
        return resource;
    }

    /** Returns the logging correlation configuration. */
    public Logging getLogging() {
        return logging;
    }

    /** Returns the Debezium JMX metrics configuration. */
    public Debezium getDebezium() {
        return debezium;
    }

    /**
     * Configuration for observation filtering.
     *
     * <p>Controls which HTTP paths are excluded from tracing and metrics to reduce
     * observability noise from high-frequency polling endpoints.
     */
    public static class Filter {
        private final Actuator actuator = new Actuator();
        private List<String> customExcludedPaths = new ArrayList<>();

        /** Returns the actuator endpoint filter configuration. */
        public Actuator getActuator() {
            return actuator;
        }

        /**
         * Returns additional application-defined paths to exclude from observations.
         *
         * @return mutable list of path prefixes; never {@code null}
         */
        public List<String> getCustomExcludedPaths() {
            return customExcludedPaths;
        }

        /**
         * Sets additional application-defined paths to exclude from observations.
         *
         * @param customExcludedPaths list of URI prefixes to suppress
         */
        public void setCustomExcludedPaths(List<String> customExcludedPaths) {
            this.customExcludedPaths = customExcludedPaths;
        }

        /**
         * Configuration for suppressing observations on Spring Boot Actuator endpoints.
         *
         * <p>Default excluded paths: {@code /actuator/health}, {@code /actuator/prometheus},
         * {@code /actuator/jolokia}, {@code /actuator/info}.
         */
        public static class Actuator {
            /** Whether actuator path filtering is enabled. Defaults to {@code true}. */
            private boolean enabled = true;
            private List<String> excludedPaths = new ArrayList<>(List.of(
                    "/actuator/health",
                    "/actuator/prometheus",
                    "/actuator/jolokia",
                    "/actuator/info"
            ));

            /**
             * Returns whether actuator endpoint filtering is active.
             *
             * @return {@code true} if filtering is enabled
             */
            public boolean isEnabled() {
                return enabled;
            }

            /**
             * Enables or disables actuator endpoint filtering.
             *
             * @param enabled {@code true} to suppress actuator observations (default)
             */
            public void setEnabled(boolean enabled) {
                this.enabled = enabled;
            }

            /**
             * Returns the list of actuator URI prefixes that will be suppressed.
             *
             * @return mutable list of path prefixes; never {@code null}
             */
            public List<String> getExcludedPaths() {
                return excludedPaths;
            }

            /**
             * Overrides the default actuator excluded paths list.
             *
             * @param excludedPaths URI prefixes to suppress
             */
            public void setExcludedPaths(List<String> excludedPaths) {
                this.excludedPaths = excludedPaths;
            }
        }
    }

    /**
     * Configuration for Spring Security user-identity correlation.
     *
     * <p>When enabled, the authenticated principal name is added to the active span as a
     * high-cardinality attribute and propagated via W3C Baggage so that it appears in MDC
     * and log records.
     */
    public static class Security {
        /** Whether security correlation is enabled. Defaults to {@code true}. */
        private boolean enabled = true;
        private String attributeName = "user_id";
        private String baggageField = "userId";
        private boolean includeAnonymous = false;

        /**
         * Returns whether security-based user correlation is active.
         *
         * @return {@code true} if security correlation is enabled
         */
        public boolean isEnabled() {
            return enabled;
        }

        /**
         * Enables or disables security-based user correlation.
         *
         * @param enabled {@code true} to activate (default)
         */
        public void setEnabled(boolean enabled) {
            this.enabled = enabled;
        }

        /**
         * Returns the span attribute name used to store the authenticated username.
         * Defaults to {@code "user_id"}.
         *
         * @return span attribute key
         */
        public String getAttributeName() {
            return attributeName;
        }

        /**
         * Sets the span attribute name for the authenticated username.
         *
         * @param attributeName the attribute key (e.g. {@code "user_id"})
         */
        public void setAttributeName(String attributeName) {
            this.attributeName = attributeName;
        }

        /**
         * Returns the W3C Baggage field name used to propagate the username to MDC.
         * Defaults to {@code "userId"}.
         *
         * @return baggage field name
         */
        public String getBaggageField() {
            return baggageField;
        }

        /**
         * Sets the W3C Baggage field name for username propagation.
         *
         * @param baggageField the baggage key (e.g. {@code "userId"})
         */
        public void setBaggageField(String baggageField) {
            this.baggageField = baggageField;
        }

        /**
         * Returns whether the {@code anonymousUser} principal should be correlated.
         * Defaults to {@code false}.
         *
         * @return {@code true} if anonymous requests are tagged
         */
        public boolean isIncludeAnonymous() {
            return includeAnonymous;
        }

        /**
         * Sets whether to include anonymous authentications in span attributes.
         *
         * @param includeAnonymous {@code true} to tag anonymous requests
         */
        public void setIncludeAnonymous(boolean includeAnonymous) {
            this.includeAnonymous = includeAnonymous;
        }
    }

    /**
     * Configuration for Micrometer metrics customisation.
     *
     * <p>Currently provides histogram/SLO configuration for specific meter names.
     */
    public static class Metrics {
        private final Histograms histograms = new Histograms();

        /** Returns the histogram (percentile / SLO bucket) configuration. */
        public Histograms getHistograms() {
            return histograms;
        }

        /**
         * Configuration for enabling percentile histograms and SLO buckets on
         * selected meters.
         *
         * <p>Default targets: {@code http.server.requests}, {@code mongodb.command},
         * {@code http.client.requests}.
         */
        public static class Histograms {
            /** Whether histogram configuration is applied. Defaults to {@code true}. */
            private boolean enabled = true;
            private List<String> targets = new ArrayList<>(List.of(
                    "http.server.requests",
                    "mongodb.command",
                    "http.client.requests"
            ));
            private List<Duration> slaBuckets = new ArrayList<>(List.of(
                    Duration.ofMillis(5),
                    Duration.ofMillis(10),
                    Duration.ofMillis(25),
                    Duration.ofMillis(50),
                    Duration.ofMillis(100),
                    Duration.ofMillis(250),
                    Duration.ofMillis(500),
                    Duration.ofSeconds(1),
                    Duration.ofSeconds(2),
                    Duration.ofSeconds(5)
            ));

            /**
             * Returns whether histogram configuration is active.
             *
             * @return {@code true} if histograms are enabled
             */
            public boolean isEnabled() {
                return enabled;
            }

            /**
             * Enables or disables histogram configuration.
             *
             * @param enabled {@code true} to apply SLO buckets (default)
             */
            public void setEnabled(boolean enabled) {
                this.enabled = enabled;
            }

            /**
             * Returns the meter name prefixes that will receive histogram configuration.
             *
             * @return mutable list of meter name prefixes; never {@code null}
             */
            public List<String> getTargets() {
                return targets;
            }

            /**
             * Sets the meter name prefixes that will receive histogram configuration.
             *
             * @param targets list of meter name prefixes
             */
            public void setTargets(List<String> targets) {
                this.targets = targets;
            }

            /**
             * Returns the SLO bucket durations used to define histogram boundaries.
             *
             * @return mutable list of durations; never {@code null}
             */
            public List<Duration> getSlaBuckets() {
                return slaBuckets;
            }

            /**
             * Overrides the default SLO bucket durations.
             *
             * @param slaBuckets list of bucket boundary durations
             */
            public void setSlaBuckets(List<Duration> slaBuckets) {
                this.slaBuckets = slaBuckets;
            }
        }
    }

    /**
     * Configuration for OpenTelemetry resource attributes.
     *
     * <p>These attributes identify the service in Tempo and Grafana dashboards
     * (e.g. {@code service.name}, {@code service.version}, {@code deployment.environment}).
     */
    public static class Resource {
        /** Whether OTel resource attribute configuration is enabled. Defaults to {@code true}. */
        private boolean enabled = true;
        private String environment;

        /**
         * Returns whether OTel resource attribute configuration is active.
         *
         * @return {@code true} if resource attributes are applied
         */
        public boolean isEnabled() {
            return enabled;
        }

        /**
         * Enables or disables OTel resource attribute configuration.
         *
         * @param enabled {@code true} to apply resource attributes (default)
         */
        public void setEnabled(boolean enabled) {
            this.enabled = enabled;
        }

        /**
         * Returns the deployment environment name (e.g. {@code dev}, {@code staging},
         * {@code production}) that is set on the {@code deployment.environment} OTel attribute.
         *
         * <p>Falls back to the {@code ENVIRONMENT} system/environment variable when not set here.
         *
         * @return environment name, or {@code null} if not configured
         */
        public String getEnvironment() {
            return environment;
        }

        /**
         * Sets the deployment environment name for the {@code deployment.environment} attribute.
         *
         * @param environment environment name (e.g. {@code "staging"})
         */
        public void setEnvironment(String environment) {
            this.environment = environment;
        }
    }

    /**
     * Configuration for structured logging correlation.
     *
     * <p>Controls whether the default MDC-based log correlation pattern
     * ({@code [appName,traceId,spanId,userId]}) is applied via
     * {@code logging.pattern.correlation}.
     */
    public static class Logging {
        private final Correlation correlation = new Correlation();

        /** Returns the log correlation pattern configuration. */
        public Correlation getCorrelation() {
            return correlation;
        }

        /**
         * Controls whether the starter injects a default {@code logging.pattern.correlation}
         * that includes trace/span/user IDs.
         */
        public static class Correlation {
            /** Whether the default log correlation pattern is applied. Defaults to {@code true}. */
            private boolean enabled = true;

            /**
             * Returns whether the default log correlation pattern injection is active.
             *
             * @return {@code true} if the default pattern will be applied
             */
            public boolean isEnabled() {
                return enabled;
            }

            /**
             * Enables or disables the default log correlation pattern injection.
             *
             * @param enabled {@code true} to inject the default pattern (default)
             */
            public void setEnabled(boolean enabled) {
                this.enabled = enabled;
            }
        }
    }

    /**
     * Configuration for Debezium JMX metrics bridging.
     *
     * <p>When enabled, Debezium connector metrics exposed via JMX are dynamically
     * discovered and bound to Micrometer as gauges and counters.
     */
    public static class Debezium {
        private final Jmx jmx = new Jmx();

        /** Returns the JMX metrics bridging configuration. */
        public Jmx getJmx() {
            return jmx;
        }

        /**
         * Configuration for the Debezium JMX-to-Micrometer bridge.
         *
         * <p>Metrics are discovered dynamically from MBeans registered under the
         * {@code debezium.*} and {@code kafka.connect.*} domains.
         */
        public static class Jmx {
            /** Whether JMX metrics bridging is enabled. Defaults to {@code true}. */
            private boolean enabled = true;
            private String prefix = "debezium";

            /**
             * Returns whether Debezium JMX metrics bridging is active.
             *
             * @return {@code true} if JMX bridging is enabled
             */
            public boolean isEnabled() {
                return enabled;
            }

            /**
             * Enables or disables Debezium JMX metrics bridging.
             *
             * @param enabled {@code true} to activate bridging (default)
             */
            public void setEnabled(boolean enabled) {
                this.enabled = enabled;
            }

            /**
             * Returns the Micrometer meter name prefix for all Debezium JMX metrics.
             * Defaults to {@code "debezium"}.
             *
             * @return meter name prefix
             */
            public String getPrefix() {
                return prefix;
            }

            /**
             * Sets the Micrometer meter name prefix for Debezium JMX metrics.
             *
             * @param prefix the prefix to prepend (e.g. {@code "debezium"})
             */
            public void setPrefix(String prefix) {
                this.prefix = prefix;
            }
        }
    }
}
