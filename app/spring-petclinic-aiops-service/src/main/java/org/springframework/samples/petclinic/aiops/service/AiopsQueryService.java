package org.springframework.samples.petclinic.aiops.service;

import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Set;

import org.springframework.samples.petclinic.aiops.dto.AiopsQueryRequest;
import org.springframework.samples.petclinic.aiops.dto.AiopsQueryResponse;
import org.springframework.samples.petclinic.aiops.dto.EvidenceSection;
import org.springframework.samples.petclinic.aiops.tools.ServiceHealthAdapter;
import org.springframework.samples.petclinic.aiops.tools.LogsAdapter;
import org.springframework.samples.petclinic.aiops.tools.MetricsAdapter;
import org.springframework.stereotype.Service;

@Service
public class AiopsQueryService {

    private final ServiceHealthAdapter serviceHealthAdapter;
    private final LogsAdapter logsAdapter;
    private final MetricsAdapter metricsAdapter;
    private final BedrockReasoningService bedrockReasoningService;
    private boolean containsObservation(EvidenceSection evidenceSection, String text) {
    return evidenceSection.getObservations().stream()
        .anyMatch(observation -> observation != null && observation.contains(text));
    }


    public AiopsQueryService(ServiceHealthAdapter serviceHealthAdapter, LogsAdapter logsAdapter, MetricsAdapter metricsAdapter, BedrockReasoningService bedrockReasoningService) {
        this.serviceHealthAdapter = serviceHealthAdapter;
        this.logsAdapter = logsAdapter;
        this.metricsAdapter = metricsAdapter;
        this.bedrockReasoningService = bedrockReasoningService;
    }

    public AiopsQueryResponse query(AiopsQueryRequest request) {
        EvidenceSection healthEvidence = serviceHealthAdapter.fetchServiceHealth(request);
        EvidenceSection logsEvidence = logsAdapter.fetchLogs(request);
        EvidenceSection metricsEvidence = metricsAdapter.fetchMetrics(request);



        AiopsQueryResponse response = new AiopsQueryResponse();

        List<String> evidence = new ArrayList<>();
        evidence.add("Received question: " + request.getQuestion());
        evidence.addAll(healthEvidence.getObservations());
        evidence.addAll(logsEvidence.getObservations());
        evidence.addAll(metricsEvidence.getObservations());
        response.setEvidenceCollected(evidence);

        String bedrockSummary = bedrockReasoningService.summarize(request, evidence);
        


        response.setImpactedServices(
            request.getService() == null || request.getService().isBlank()
                ? deriveImpactedServices(healthEvidence)
                : List.of(request.getService())
        );
        boolean healthFailed = containsObservation(healthEvidence, "Failed to query Kubernetes service health.");
        boolean logsFailed = containsObservation(logsEvidence, "Failed to query CloudWatch Logs.");
        boolean metricsFailed = containsObservation(metricsEvidence, "Failed to query Prometheus metrics.");
        boolean deploymentMissing = containsObservation(healthEvidence, "Deployment not found:");
        boolean noLogsFound = containsObservation(logsEvidence, "No matching CloudWatch log events found.");
        boolean noMetricsData = containsObservation(metricsEvidence, "no data");
        

    if (healthFailed && logsFailed && metricsFailed) {
        response.setProbableRootCause("Unable to determine root cause because Kubernetes health, CloudWatch logs, and Prometheus metrics are all unavailable.");
        response.setConfidence("low");
        response.setRecommendedFix(List.of(
            "Verify kubeconfig or in-cluster Kubernetes access.",
            "Verify the configured CloudWatch log group exists in the target AWS account and region.",
            "Verify the Prometheus base URL and connectivity.",
            "Confirm the service name and namespace are correct."
        ));
        response.setUnknowns(List.of(
            "Deployment health could not be confirmed.",
            "Application logs could not be retrieved.",
            "Prometheus metrics could not be retrieved."
        ));
    } else if (healthFailed && logsFailed) {
        response.setProbableRootCause("Kubernetes health and CloudWatch logs are unavailable, so only partial telemetry is available.");
        response.setConfidence("low");
        response.setRecommendedFix(List.of(
            "Verify cluster connectivity and credentials.",
            "Verify the configured CloudWatch log group exists.",
            "Use Prometheus metrics as the remaining evidence source."
        ));
        response.setUnknowns(List.of(
            "Deployment health could not be confirmed.",
            "Application log evidence is unavailable."
        ));
    } else if (healthFailed && metricsFailed) {
        response.setProbableRootCause("Kubernetes health and Prometheus metrics are unavailable, so service state cannot be confirmed.");
        response.setConfidence("low");
        response.setRecommendedFix(List.of(
            "Verify Kubernetes API access.",
            "Verify Prometheus connectivity and configuration.",
            "Use CloudWatch log evidence as the remaining evidence source."
        ));
        response.setUnknowns(List.of(
            "Deployment health could not be confirmed.",
            "Metrics evidence is unavailable."
        ));
    } else if (logsFailed && metricsFailed) {
        response.setProbableRootCause("CloudWatch logs and Prometheus metrics are unavailable, so application telemetry is incomplete.");
        response.setConfidence("low");
        response.setRecommendedFix(List.of(
            "Verify the configured CloudWatch log group exists.",
            "Verify Prometheus connectivity and configuration.",
            "Use Kubernetes health evidence as the remaining evidence source."
        ));
        response.setUnknowns(List.of(
            "Application log evidence is unavailable.",
            "Metrics evidence is unavailable."
        ));
    } else if (deploymentMissing) {
        response.setProbableRootCause("The requested Kubernetes deployment was not found.");
        response.setConfidence("medium");
        response.setRecommendedFix(List.of(
            "Verify the deployment name matches the workload name in Kubernetes.",
            "Confirm the namespace is correct.",
            "Check whether the workload is deployed in the current cluster."
        ));
        response.setUnknowns(List.of(
            "Pod health could not be confirmed because the deployment lookup failed."
        ));
    } else if (healthFailed) {
        response.setProbableRootCause("Kubernetes health inspection failed, so the service state could not be confirmed.");
        response.setConfidence("low");
        response.setRecommendedFix(List.of(
            "Verify Kubernetes API access from the AIOps service.",
            "Check cluster connectivity and credentials.",
            "Use logs and metrics as secondary evidence."
        ));
        response.setUnknowns(List.of(
            "Deployment and pod health status are unknown."
        ));
    } else if (logsFailed) {
        response.setProbableRootCause("CloudWatch log retrieval failed, so application-level log evidence is unavailable.");
        response.setConfidence("low");
        response.setRecommendedFix(List.of(
            "Verify the configured CloudWatch log group exists.",
            "Check AWS region and credentials.",
            "Use Kubernetes health and metrics while logs are unavailable."
        ));
        response.setUnknowns(List.of(
            "Recent application log evidence is unavailable."
        ));
    } else if (metricsFailed) {
        response.setProbableRootCause("Prometheus metrics retrieval failed, so performance and error-rate evidence is unavailable.");
        response.setConfidence("low");
        response.setRecommendedFix(List.of(
            "Verify the Prometheus base URL and network connectivity.",
            "Check metric exposure and Prometheus availability.",
            "Use health and log evidence while metrics are unavailable."
        ));
        response.setUnknowns(List.of(
            "Metrics evidence is unavailable."
        ));
    } else if (noLogsFound && noMetricsData) {
        response.setProbableRootCause("No matching logs or Prometheus metrics were found for the requested service and time range.");
        response.setConfidence("medium");
        response.setRecommendedFix(List.of(
            "Increase the time range.",
            "Verify the service name filter matches the actual workload and metric labels.",
            "Check Kubernetes health for additional context."
        ));
        response.setUnknowns(List.of(
            "The issue may not have produced logs or matching metrics in the selected time window."
        ));
    } else if (noLogsFound) {
        response.setProbableRootCause("No matching log evidence was found in the requested time range.");
        response.setConfidence("medium");
        response.setRecommendedFix(List.of(
            "Increase the time range for log search.",
            "Verify the service name filter matches the actual workload name.",
            "Check health and metrics for additional evidence."
        ));
        response.setUnknowns(List.of(
            "The issue may not have produced logs in the selected time window."
        ));
    } else if (noMetricsData) {
        response.setProbableRootCause("No matching Prometheus metrics were found for the requested service.");
        response.setConfidence("medium");
        response.setRecommendedFix(List.of(
            "Verify the service name matches the Prometheus metric labels.",
            "Increase the time range or review traffic assumptions.",
            "Use health and logs for additional evidence."
        ));
        response.setUnknowns(List.of(
            "The service may not have emitted matching metrics in the selected window."
        ));
    } else {
        response.setProbableRootCause("Telemetry was retrieved, but deeper correlation and root-cause reasoning are not implemented yet.");
        response.setConfidence("medium");
        response.setRecommendedFix(List.of(
            "Review the collected health, log, and metric evidence.",
            "Add Bedrock reasoning for stronger incident diagnosis."
        ));
        response.setUnknowns(List.of(
            "Cross-source incident correlation is not implemented yet."
        ));
    }

    response.setProbableRootCause(bedrockSummary);
    return response;
}

    private List<String> deriveImpactedServices(EvidenceSection healthEvidence) {
        Set<String> impactedServices = new LinkedHashSet<>();

        for (String observation : healthEvidence.getObservations()) {
            if (observation == null) {
                continue;
            }

            if (observation.startsWith("Deployment ")) {
                int deploymentNameStart = "Deployment ".length();
                int delimiterIndex = observation.indexOf(':', deploymentNameStart);
                if (delimiterIndex > deploymentNameStart) {
                    impactedServices.add(observation.substring(deploymentNameStart, delimiterIndex).trim());
                }
            } else if (observation.startsWith("Deployment found: ")) {
                impactedServices.add(observation.substring("Deployment found: ".length()).trim());
            }
        }

        if (impactedServices.isEmpty()) {
            return List.of("unknown");
        }

        return List.copyOf(impactedServices);
    }
}
