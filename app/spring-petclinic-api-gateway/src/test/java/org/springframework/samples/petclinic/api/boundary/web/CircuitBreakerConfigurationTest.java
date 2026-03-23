package org.springframework.samples.petclinic.api.boundary.web;

import io.github.resilience4j.bulkhead.BulkheadRegistry;
import io.github.resilience4j.circuitbreaker.CircuitBreakerRegistry;
import io.github.resilience4j.timelimiter.TimeLimiterRegistry;
import org.junit.jupiter.api.Test;
import org.springframework.cloud.circuitbreaker.resilience4j.Resilience4JConfigurationProperties;

import static org.junit.jupiter.api.Assertions.assertNotNull;

class CircuitBreakerConfigurationTest {

    private final CircuitBreakerConfiguration configuration = new CircuitBreakerConfiguration();

    @Test
    void createsCircuitBreakerRegistry() {
        CircuitBreakerRegistry registry = configuration.circuitBreakerRegistry();
        assertNotNull(registry);
    }

    @Test
    void createsTimeLimiterRegistry() {
        TimeLimiterRegistry registry = configuration.timeLimiterRegistry();
        assertNotNull(registry);
    }

    @Test
    void createsBulkheadRegistry() {
        BulkheadRegistry registry = configuration.bulkheadRegistry();
        assertNotNull(registry);
    }

    @Test
    void createsResilience4JConfigurationProperties() {
        Resilience4JConfigurationProperties properties = configuration.resilience4JConfigurationProperties();
        assertNotNull(properties);
    }
}
