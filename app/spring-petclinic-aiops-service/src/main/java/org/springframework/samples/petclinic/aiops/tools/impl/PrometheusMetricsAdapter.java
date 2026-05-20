package org.springframework.samples.petclinic.aiops.tools.impl;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.samples.petclinic.aiops.dto.AiopsQueryRequest;
import org.springframework.samples.petclinic.aiops.dto.EvidenceSection;
import org.springframework.samples.petclinic.aiops.tools.MetricsAdapter;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;

@Component
public class PrometheusMetricsAdapter implements MetricsAdapter {
    private final String prometheusBaseUrl;
    private final RestClient restClient;

    public PrometheusMetricsAdapter(@Value("${aiops.prometheus-base-url}") String prometheusBaseUrl) {
        this.prometheusBaseUrl = prometheusBaseUrl;
        this.restClient = RestClient.builder()
            .baseUrl(prometheusBaseUrl)
            .build();
    }

    @Override
    public EvidenceSection fetchMetrics(AiopsQueryRequest request) {
        List<String> observations = new ArrayList<>();
        String serviceName = request.getService();

        if (serviceName == null || serviceName.isBlank()) {
            observations.add("No specific service provided for metrics lookup.");
            observations.add("Service-specific Prometheus queries require a workload name.");
            return new EvidenceSection("prometheus", observations);
        }

        try {
            String errorRateQuery =
                "sum(rate(http_server_requests_seconds_count{application=\"" + serviceName + "\",status=~\"5..\"}[5m]))";

            String latencyQuery =
                "histogram_quantile(0.95, sum(rate(http_server_requests_seconds_bucket{application=\"" + serviceName + "\"}[5m])) by (le))";

            String requestRateQuery =
                "sum(rate(http_server_requests_seconds_count{application=\"" + serviceName + "\"}[5m]))";

            observations.add("Prometheus service: " + serviceName);
            observations.add("5xx rate: " + executeInstantQuery(errorRateQuery));
            observations.add("P95 latency: " + executeInstantQuery(latencyQuery));
            observations.add("Request rate: " + executeInstantQuery(requestRateQuery));
        } catch (Exception ex) {
            observations.add("Failed to query Prometheus metrics.");
            observations.add("Prometheus base URL: " + prometheusBaseUrl);
            observations.add("This may indicate Prometheus is unreachable, the environment is not running, or the metric labels do not match the requested service.");
            observations.add("Service: " + serviceName);
            observations.add("Error: " + ex.getMessage());
        }

        return new EvidenceSection("prometheus", observations);
    }

@SuppressWarnings("unchecked")
private String executeInstantQuery(String query) {
    String encodedQuery = URLEncoder.encode(query, StandardCharsets.UTF_8);

    Map<String, Object> response = restClient.get()
        .uri("/api/v1/query?query=" + encodedQuery)
        .retrieve()
        .body(Map.class);

    if (response == null) {
        return "no response";
    }

    Object dataObj = response.get("data");
    if (!(dataObj instanceof Map<?, ?> data)) {
        return "unexpected response format";
    }

    Object resultObj = data.get("result");
    if (!(resultObj instanceof List<?> resultList) || resultList.isEmpty()) {
        return "no data";
    }

    Object firstObj = resultList.get(0);
    if (!(firstObj instanceof Map<?, ?> first)) {
        return "unexpected result format";
    }

    Object valueObj = first.get("value");
    if (!(valueObj instanceof List<?> valueList) || valueList.size() < 2) {
        return "missing value";
    }

    Object metricValue = valueList.get(1);
    return metricValue == null ? "null" : metricValue.toString();
}

}
