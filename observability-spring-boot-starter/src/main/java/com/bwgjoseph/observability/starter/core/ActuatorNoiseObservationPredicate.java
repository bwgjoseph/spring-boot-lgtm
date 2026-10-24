package com.bwgjoseph.observability.starter.core;

import com.bwgjoseph.observability.starter.LgtmObservabilityProperties;
import io.micrometer.observation.Observation;
import io.micrometer.observation.ObservationPredicate;
import org.springframework.http.server.observation.ServerRequestObservationContext;

import java.util.List;

/**
 * An {@link ObservationPredicate} that suppresses observations for noisy actuator
 * endpoints, preventing them from generating traces and inflating metrics.
 *
 * <p>By default the following paths are excluded:
 * <ul>
 *   <li>{@code /actuator/health}</li>
 *   <li>{@code /actuator/prometheus}</li>
 *   <li>{@code /actuator/jolokia}</li>
 *   <li>{@code /actuator/info}</li>
 * </ul>
 *
 * <p>The excluded path list is fully configurable via
 * {@code lgtm.observability.filter.actuator.excluded-paths} and can be supplemented
 * with arbitrary application paths through
 * {@code lgtm.observability.filter.custom-excluded-paths}.
 *
 * <p>The entire filter can be disabled by setting
 * {@code lgtm.observability.filter.actuator.enabled=false}.
 */
public class ActuatorNoiseObservationPredicate implements ObservationPredicate {

    private final LgtmObservabilityProperties properties;

    /**
     * Creates a new predicate using the supplied starter properties.
     *
     * @param properties the LGTM observability configuration properties
     */
    public ActuatorNoiseObservationPredicate(LgtmObservabilityProperties properties) {
        this.properties = properties;
    }

    /**
     * Returns {@code false} (suppress observation) when the request URI matches one of
     * the configured excluded paths, and {@code true} (allow observation) for everything
     * else.
     *
     * <p>Filtering is only applied to {@link ServerRequestObservationContext} instances;
     * all other context types pass through unconditionally.
     *
     * @param name    the name of the observation (e.g. {@code http.server.requests})
     * @param context the current observation context; examined for the request URI when
     *                it is a {@link ServerRequestObservationContext}
     * @return {@code true} if the observation should proceed, {@code false} to suppress it
     */
    @Override
    public boolean test(String name, Observation.Context context) {
        if (!properties.getFilter().getActuator().isEnabled()) {
            return true;
        }

        if (context instanceof ServerRequestObservationContext httpContext) {
            String uri = httpContext.getCarrier().getRequestURI();
            if (uri == null) {
                return true;
            }

            List<String> excluded = properties.getFilter().getActuator().getExcludedPaths();
            for (String path : excluded) {
                if (uri.startsWith(path)) {
                    return false;
                }
            }

            List<String> customExcluded = properties.getFilter().getCustomExcludedPaths();
            for (String customPath : customExcluded) {
                if (uri.startsWith(customPath)) {
                    return false;
                }
            }
        }

        return true;
    }
}
