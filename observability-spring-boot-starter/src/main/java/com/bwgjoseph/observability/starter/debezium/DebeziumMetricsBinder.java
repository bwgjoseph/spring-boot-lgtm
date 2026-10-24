package com.bwgjoseph.observability.starter.debezium;

import io.micrometer.core.instrument.FunctionCounter;
import io.micrometer.core.instrument.Gauge;
import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.core.instrument.binder.MeterBinder;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import javax.management.*;
import java.lang.management.ManagementFactory;
import java.util.HashSet;
import java.util.Set;

/**
 * A Micrometer {@link MeterBinder} that dynamically discovers and registers Debezium
 * connector metrics exposed via JMX.
 *
 * <p>At startup, this binder:
 * <ol>
 *   <li>Attaches a JMX notification listener to the {@code MBeanServerDelegate} to
 *       detect any MBeans registered <em>after</em> startup (e.g. when a Debezium
 *       connector initialises asynchronously).</li>
 *   <li>Scans for MBeans already registered under {@code debezium.*} at the time
 *       {@link #bindTo(MeterRegistry)} is called.</li>
 * </ol>
 *
 * <p>For each discovered numeric MBean attribute, a Micrometer meter is registered:
 * <ul>
 *   <li>{@link io.micrometer.core.instrument.FunctionCounter} for attributes whose
 *       names contain {@code Total} or {@code Count}.</li>
 *   <li>{@link io.micrometer.core.instrument.Gauge} for all other numeric attributes.</li>
 * </ul>
 *
 * <p>Meter names follow the pattern {@code <prefix>.<snake_case_attribute_name>}, where
 * the prefix defaults to {@code "debezium"} and is configurable via
 * {@link LgtmObservabilityProperties.Debezium.Jmx#getPrefix()}.
 *
 * <p>Auto-configured by {@link LgtmDebeziumAutoConfiguration} when
 * {@code io.debezium.embedded.EmbeddedEngine} is present on the classpath.
 */
public class DebeziumMetricsBinder implements MeterBinder {

    private static final Logger log = LoggerFactory.getLogger(DebeziumMetricsBinder.class);

    private final MBeanServer mBeanServer;
    private final String prefix;
    private final Set<String> registeredMeters = new HashSet<>();

    /**
     * Creates a binder using the platform {@link MBeanServer} and the specified prefix.
     *
     * @param prefix the Micrometer meter name prefix (e.g. {@code "debezium"})
     */
    public DebeziumMetricsBinder(String prefix) {
        this.mBeanServer = ManagementFactory.getPlatformMBeanServer();
        this.prefix = prefix;
    }

    /**
     * Creates a binder with an explicit {@link MBeanServer}, useful for testing.
     *
     * @param mBeanServer the JMX MBean server to query
     * @param prefix      the Micrometer meter name prefix (e.g. {@code "debezium"})
     */
    public DebeziumMetricsBinder(MBeanServer mBeanServer, String prefix) {
        this.mBeanServer = mBeanServer;
        this.prefix = prefix;
    }

    /**
     * Attaches a JMX notification listener to discover dynamically registered Debezium
     * MBeans and also registers any MBeans already present at the time of invocation.
     *
     * <p>For each discovered numeric attribute a {@link io.micrometer.core.instrument.FunctionCounter}
     * or {@link io.micrometer.core.instrument.Gauge} is registered in the supplied
     * {@link MeterRegistry}.
     *
     * @param registry the Micrometer registry to bind meters to
     */
    @Override
    public void bindTo(MeterRegistry registry) {
        try {
            // Listen for any new MBeans registered dynamically under debezium or kafka.connect
            this.mBeanServer.addNotificationListener(
                    new ObjectName("JMImplementation:type=MBeanServerDelegate"),
                    (notification, handback) -> {
                        if (notification instanceof MBeanServerNotification mbsn) {
                            if (MBeanServerNotification.REGISTRATION_NOTIFICATION.equals(mbsn.getType())) {
                                registerMBeans(registry, mbsn.getMBeanName());
                            }
                        }
                    },
                    null,
                    null
            );

            // Also register any MBeans already present at startup
            Set<ObjectName> existing = this.mBeanServer.queryNames(new ObjectName("debezium.*:*"), null);
            for (ObjectName name : existing) {
                registerMBeans(registry, name);
            }
        } catch (MalformedObjectNameException | InstanceNotFoundException e) {
            log.warn("Failed to initialize DebeziumMetricsBinder listener: {}", e.getMessage());
        }
    }

    /**
     * Attempts to register Micrometer meters for all numeric attributes of the given
     * MBean. Only MBeans from the {@code debezium.*} and {@code kafka.connect.*} domains
     * are processed; all others are silently ignored.
     *
     * <p>Meters that have already been registered (tracked by {@code registeredMeters})
     * are skipped to avoid duplicate registration.
     *
     * @param registry   the Micrometer registry to bind meters to
     * @param objectName the JMX {@link ObjectName} of the newly registered MBean
     */
    private void registerMBeans(MeterRegistry registry, ObjectName objectName) {
        String domain = objectName.getDomain();
        if (!domain.startsWith("debezium") && !domain.startsWith("kafka.connect")) {
            return;
        }

        try {
            MBeanInfo info = this.mBeanServer.getMBeanInfo(objectName);
            for (MBeanAttributeInfo attr : info.getAttributes()) {
                String attrName = attr.getName();
                String meterKey = objectName.getCanonicalName() + ":" + attrName;
                if (registeredMeters.contains(meterKey)) {
                    continue;
                }

                String type = attr.getType();
                if ("long".equals(type) || "int".equals(type) || "double".equals(type) ||
                        "java.lang.Long".equals(type) || "java.lang.Integer".equals(type) || "java.lang.Double".equals(type)) {

                    String meterName = prefix + "." + camelToSnake(attrName).replace('_', '.');

                    if (attrName.contains("Total") || attrName.contains("Count")) {
                        FunctionCounter.builder(meterName, objectName, obj -> getAttributeValue(obj, attrName))
                                .description(attr.getDescription())
                                .tag("context", objectName.getKeyProperty("context") != null ? objectName.getKeyProperty("context") : "unknown")
                                .register(registry);
                    } else {
                        Gauge.builder(meterName, objectName, obj -> getAttributeValue(obj, attrName))
                                .description(attr.getDescription())
                                .tag("context", objectName.getKeyProperty("context") != null ? objectName.getKeyProperty("context") : "unknown")
                                .register(registry);
                    }
                    registeredMeters.add(meterKey);
                }
            }
        } catch (Exception e) {
            log.trace("Could not read MBean {}: {}", objectName, e.getMessage());
        }
    }

    /**
     * Reads a numeric JMX attribute value from the given MBean and converts it to
     * a {@code double} suitable for Micrometer.
     *
     * <p>{@link Boolean} values are mapped to {@code 1.0} (true) or {@code 0.0} (false).
     * Returns {@link Double#NaN} when the attribute cannot be read.
     *
     * @param objectName the JMX {@link ObjectName} of the MBean
     * @param attribute  the attribute name to read
     * @return the attribute value as a {@code double}, or {@link Double#NaN} on failure
     */
    private double getAttributeValue(ObjectName objectName, String attribute) {
        try {
            Object val = this.mBeanServer.getAttribute(objectName, attribute);
            if (val instanceof Number n) {
                return n.doubleValue();
            }
            if (val instanceof Boolean b) {
                return b ? 1.0 : 0.0;
            }
        } catch (Exception ignored) {
        }
        return Double.NaN;
    }

    /**
     * Converts a camelCase string to snake_case.
     *
     * <p>For example, {@code "MilliSecondsBehindSource"} becomes
     * {@code "milli_seconds_behind_source"}.
     *
     * @param str the camelCase input string
     * @return the snake_case equivalent, lower-cased
     */
    private String camelToSnake(String str) {
        return str.replaceAll("([a-z])([A-Z]+)", "$1_$2").toLowerCase();
    }
}
