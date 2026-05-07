package com.bwgjoseph.observability.debezium;

import java.lang.management.ManagementFactory;
import java.util.ArrayList;
import java.util.List;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;

import javax.management.InstanceNotFoundException;
import javax.management.MBeanAttributeInfo;
import javax.management.MBeanInfo;
import javax.management.MBeanServer;
import javax.management.MalformedObjectNameException;
import javax.management.Notification;
import javax.management.NotificationListener;
import javax.management.ObjectName;

import org.springframework.beans.factory.InitializingBean;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

import io.micrometer.core.instrument.Gauge;
import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.core.instrument.Tag;
import io.micrometer.core.instrument.binder.MeterBinder;
import lombok.extern.slf4j.Slf4j;

/**
 * A Dynamic MeterBinder that uses NotificationListener for reactive Debezium MBean discovery.
 */
@Slf4j
@Component
@ConditionalOnProperty(name = "debezium.enabled", havingValue = "true", matchIfMissing = true)
public class DebeziumMetricsBinder implements MeterBinder, NotificationListener, InitializingBean {

    private final MBeanServer mBeanServer = ManagementFactory.getPlatformMBeanServer();
    private final Set<String> registeredMeters = ConcurrentHashMap.newKeySet();
    private MeterRegistry registry;

    @Override
    public void bindTo(MeterRegistry registry) {
        this.registry = registry;
        try {
            scanInitialMBeans();
        } catch (Exception e) {
            log.error("Failed to scan Debezium MBeans during bindTo", e);
        }
    }

    @Override
    public void afterPropertiesSet() throws Exception {
        try {
            // Subscribe to MBean registration/unregistration notifications
            ObjectName delegate = new ObjectName("JMImplementation:type=MBeanServerDelegate");
            mBeanServer.addNotificationListener(delegate, this, null, null);
        } catch (InstanceNotFoundException | MalformedObjectNameException e) {
            log.error("Failed to initialize Debezium MBean listener", e);
        }
    }

    private void scanInitialMBeans() throws Exception {
        if (this.registry == null) return;
        ObjectName pattern = new ObjectName("debezium.*:*");
        Set<ObjectName> mBeans = mBeanServer.queryNames(pattern, null);
        for (ObjectName mBeanName : mBeans) {
            registerMBean(mBeanName);
        }
    }

    @Override
    public void handleNotification(Notification notification, Object handback) {
        if (notification instanceof javax.management.MBeanServerNotification) {
            javax.management.MBeanServerNotification mbsn = (javax.management.MBeanServerNotification) notification;
            ObjectName mBeanName = mbsn.getMBeanName();

            if (mBeanName.getDomain().startsWith("debezium")) {
                if (notification.getType().equals(javax.management.MBeanServerNotification.REGISTRATION_NOTIFICATION)) {
                    log.info("New Debezium MBean registered: {}", mBeanName);
                    registerMBean(mBeanName);
                }
            }
        }
    }

    private void registerMBean(ObjectName name) {
        if (this.registry == null) {
            return;
        }
        try {
            MBeanInfo info = mBeanServer.getMBeanInfo(name);
            MBeanAttributeInfo[] attributes = info.getAttributes();

            List<Tag> tags = new ArrayList<>();
            name.getKeyPropertyList().forEach((k, v) -> tags.add(Tag.of(k, v)));
            String domain = name.getDomain();
            if (domain.contains(".")) {
                tags.add(Tag.of("db_type", domain.substring(domain.lastIndexOf(".") + 1)));
            }

            for (MBeanAttributeInfo attr : attributes) {
                String metricName = "debezium." + attr.getName().replaceAll("([a-z])([A-Z])", "$1_$2").toLowerCase();
                String meterKey = name.getCanonicalName() + ":" + attr.getName();

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

    private boolean registerStringInfo(String metricName, ObjectName name, MBeanAttributeInfo attr, List<Tag> tags) {
        String formattedValue = formatValue(tryGetAttribute(name, attr.getName()));
        if (formattedValue == null || formattedValue.trim().isEmpty() || formattedValue.equals("[]")) {
            return false;
        }

        Gauge.builder(metricName, mBeanServer, s -> 1.0)
        .tags(tags)
        .tags("value", formattedValue)
        .description(attr.getDescription())
        .register(registry);
        return true;
    }

    private String formatValue(Object value) {
        if (value instanceof String[] array) return String.join(",", array);
        return String.valueOf(value);
    }

    private Object tryGetAttribute(ObjectName name, String attribute) {
        try { return mBeanServer.getAttribute(name, attribute); } catch (Exception e) { return null; }
    }
}
