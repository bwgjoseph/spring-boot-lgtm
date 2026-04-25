package com.bwgjoseph.observability.debezium;

import io.micrometer.core.instrument.Gauge;
import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.core.instrument.Tag;
import io.micrometer.core.instrument.binder.MeterBinder;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import javax.management.AttributeList;
import javax.management.MBeanAttributeInfo;
import javax.management.MBeanInfo;
import javax.management.MBeanServer;
import javax.management.ObjectName;
import java.lang.management.ManagementFactory;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;

/**
 * A Dynamic MeterBinder that discovers all Debezium JMX MBeans and exposes 
 * their numeric attributes as Micrometer Gauges.
 */
@Slf4j
@Component
public class DebeziumMetricsBinder implements MeterBinder {

    private final MBeanServer mBeanServer = ManagementFactory.getPlatformMBeanServer();
    private final Set<String> registeredMeters = ConcurrentHashMap.newKeySet();
    private MeterRegistry registry;

    @Override
    public void bindTo(MeterRegistry registry) {
        this.registry = registry;
        // Initial scan
        scanAndRegister();
    }

    /**
     * Periodically scan for new Debezium MBeans (e.g., when a connector starts)
     */
    @Scheduled(fixedDelay = 30000)
    public void scanAndRegister() {
        if (this.registry == null) return;

        log.debug("Scanning MBean server for Debezium metrics...");
        try {
            // Find all MBeans in the debezium domain
            ObjectName pattern = new ObjectName("debezium.*:*");
            Set<ObjectName> mBeans = mBeanServer.queryNames(pattern, null);

            if (mBeans.isEmpty()) {
                log.warn("No Debezium MBeans found. Available domains: {}", (Object) mBeanServer.getDomains());
            }

            for (ObjectName mBeanName : mBeans) {
                registerMBean(mBeanName);
            }
        } catch (Exception e) {
            log.warn("Error during Debezium MBean discovery: {}", e.getMessage());
        }
    }

    private void registerMBean(ObjectName name) {
        try {
            MBeanInfo info = mBeanServer.getMBeanInfo(name);
            MBeanAttributeInfo[] attributes = info.getAttributes();

            // Extract tags from the ObjectName properties (e.g., type, context, server)
            List<Tag> tags = new ArrayList<>();
            name.getKeyPropertyList().forEach((k, v) -> tags.add(Tag.of(k, v)));

            // Extract database type from domain (e.g., debezium.mongodb -> mongodb)
            String domain = name.getDomain();
            if (domain.contains(".")) {
                tags.add(Tag.of("db_type", domain.substring(domain.lastIndexOf(".") + 1)));
            }

            for (MBeanAttributeInfo attr : attributes) {
                String metricName = "debezium." + attr.getName().replaceAll("([a-z])([A-Z])", "$1_$2").toLowerCase();
                String meterKey = name.getCanonicalName() + ":" + attr.getName();

                // Avoid duplicates
                if (attr.isReadable() && !registeredMeters.contains(meterKey)) {
                    Object value = tryGetAttribute(name, attr.getName());

                    if (value instanceof Number) {
                        registerNumericGauge(metricName, name, attr, tags);
                        registeredMeters.add(meterKey);
                    } else if (value instanceof Boolean) {
                        registerBooleanGauge(metricName, name, attr, tags);
                        registeredMeters.add(meterKey);
                    } else if (value instanceof String || value instanceof String[]) {
                        if (registerStringInfo(metricName, name, attr, tags)) {
                            registeredMeters.add(meterKey);
                        }
                    }
                }
            }
        } catch (Exception e) {
            log.debug("Could not register MBean {}: {}", name, e.getMessage());
        }
    }

    private void registerNumericGauge(String metricName, ObjectName name, MBeanAttributeInfo attr, List<Tag> tags) {
        log.info("Registering Debezium numeric metric: {} with tags {}", metricName, tags);
        Gauge.builder(metricName, mBeanServer, s -> {
            Object val = tryGetAttribute(name, attr.getName());
            return (val instanceof Number n) ? n.doubleValue() : 0.0;
        })
        .tags(tags)
        .description(attr.getDescription())
        .register(registry);
    }

    private void registerBooleanGauge(String metricName, ObjectName name, MBeanAttributeInfo attr, List<Tag> tags) {
        log.info("Registering Debezium boolean metric: {} with tags {}", metricName, tags);
        Gauge.builder(metricName, mBeanServer, s -> {
            Object val = tryGetAttribute(name, attr.getName());
            if (val instanceof Boolean b) return b ? 1.0 : 0.0;
            return 0.0;
        })
        .tags(tags)
        .description(attr.getDescription())
        .register(registry);
    }

    /**
     * Registers a string info metric. 
     * returns true if registration was successful (value was not empty), false otherwise.
     */
    private boolean registerStringInfo(String metricName, ObjectName name, MBeanAttributeInfo attr, List<Tag> tags) {
        String formattedValue = formatValue(tryGetAttribute(name, attr.getName()));

        // If the value is empty or null, we skip registration for this scan.
        // This allows a future scan to register it once the data is actually available.
        if (formattedValue == null || formattedValue.trim().isEmpty() || formattedValue.equals("[]")) {
            log.debug("Skipping registration for {} because value is currently empty", metricName);
            return false;
        }

        log.info("Registering Debezium info metric: {} with value: {}", metricName, formattedValue);
        
        Gauge.builder(metricName, mBeanServer, s -> 1.0)
        .tags(tags)
        .tags("value", formattedValue)
        .description(attr.getDescription())
        .register(registry);

        return true;
    }

    private String formatValue(Object value) {
        if (value instanceof String[] array) {
            return String.join(",", array);
        }
        return String.valueOf(value);
    }

    private Object tryGetAttribute(ObjectName name, String attribute) {
        try {
            return mBeanServer.getAttribute(name, attribute);
        } catch (Exception e) {
            return null;
        }
    }
}
