package org.springframework.samples.petclinic.aiops.tools.impl;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Objects;

import io.fabric8.kubernetes.api.model.Pod;
import io.fabric8.kubernetes.api.model.PodCondition;
import io.fabric8.kubernetes.api.model.apps.Deployment;
import io.fabric8.kubernetes.client.KubernetesClient;
import io.fabric8.kubernetes.client.KubernetesClientBuilder;
import org.springframework.samples.petclinic.aiops.dto.AiopsQueryRequest;
import org.springframework.samples.petclinic.aiops.dto.EvidenceSection;
import org.springframework.samples.petclinic.aiops.tools.ServiceHealthAdapter;
import org.springframework.stereotype.Component;

@Component
public class KubernetesServiceHealthAdapter implements ServiceHealthAdapter {

    @Override
    public EvidenceSection fetchServiceHealth(AiopsQueryRequest request) {
        String namespace = request.getNamespace() == null || request.getNamespace().isBlank()
            ? "petclinic"
            : request.getNamespace();

        String serviceName = request.getService();
        List<String> observations = new ArrayList<>();

        try (KubernetesClient client = new KubernetesClientBuilder().build()) {
            if (serviceName == null || serviceName.isBlank()) {
                collectNamespaceHealth(client, namespace, observations);
                return new EvidenceSection("kubernetes", observations);
            }

            Deployment deployment = client.apps()
                .deployments()
                .inNamespace(namespace)
                .withName(serviceName)
                .get();

            if (deployment == null) {
                observations.add("Deployment not found: " + serviceName);
                return new EvidenceSection("kubernetes", observations);
            }

            Integer desiredReplicas = deployment.getSpec() != null && deployment.getSpec().getReplicas() != null
                ? deployment.getSpec().getReplicas()
                : 0;

            Integer readyReplicas = deployment.getStatus() != null && deployment.getStatus().getReadyReplicas() != null
                ? deployment.getStatus().getReadyReplicas()
                : 0;

            Integer availableReplicas = deployment.getStatus() != null && deployment.getStatus().getAvailableReplicas() != null
                ? deployment.getStatus().getAvailableReplicas()
                : 0;

            Integer unavailableReplicas = deployment.getStatus() != null && deployment.getStatus().getUnavailableReplicas() != null
                ? deployment.getStatus().getUnavailableReplicas()
                : 0;

            observations.add("Deployment found: " + serviceName);
            observations.add("Desired replicas: " + desiredReplicas);
            observations.add("Ready replicas: " + readyReplicas);
            observations.add("Available replicas: " + availableReplicas);
            observations.add("Unavailable replicas: " + unavailableReplicas);

            List<Pod> pods = client.pods()
                .inNamespace(namespace)
                .withLabel("app.kubernetes.io/name", serviceName)
                .list()
                .getItems();

            if (pods.isEmpty()) {
                observations.add("No pods found with label app.kubernetes.io/name=" + serviceName);
            }
            else {
                observations.add("Pod count: " + pods.size());

                for (Pod pod : pods) {
                    String podName = pod.getMetadata() != null ? pod.getMetadata().getName() : "unknown-pod";
                    String phase = pod.getStatus() != null ? pod.getStatus().getPhase() : "unknown";
                    boolean ready = isPodReady(pod);
                    int restartCount = getRestartCount(pod);

                    observations.add("Pod " + podName + ": phase=" + phase + ", ready=" + ready + ", restarts=" + restartCount);
                }
            }
        }
        catch (Exception ex) {
                observations.add("Failed to query Kubernetes service health.");
                observations.add("Namespace: " + namespace);
                observations.add("Service: " + (serviceName == null || serviceName.isBlank() ? "unknown" : serviceName));
                observations.add("This may indicate the cluster is not running or is not reachable from the current environment.");
                observations.add("Error: " + ex.getMessage());
        }

        return new EvidenceSection("kubernetes", observations);
    }

    private void collectNamespaceHealth(KubernetesClient client, String namespace, List<String> observations) {
        observations.add("No specific service was provided for Kubernetes health inspection.");
        observations.add("Running namespace-wide Kubernetes health inspection.");
        observations.add("Requested namespace: " + namespace);

        List<Deployment> deployments = client.apps()
            .deployments()
            .inNamespace(namespace)
            .list()
            .getItems();

        observations.add("Deployments found: " + deployments.size());

        if (deployments.isEmpty()) {
            observations.add("No deployments found in namespace " + namespace + ".");
            return;
        }

        deployments.stream()
            .sorted(Comparator.comparing(deployment -> deployment.getMetadata() == null
                ? ""
                : Objects.toString(deployment.getMetadata().getName(), "")))
            .forEach(deployment -> {
                String deploymentName = deployment.getMetadata() != null
                    ? deployment.getMetadata().getName()
                    : "unknown-deployment";

                Integer desiredReplicas = deployment.getSpec() != null && deployment.getSpec().getReplicas() != null
                    ? deployment.getSpec().getReplicas()
                    : 0;

                Integer readyReplicas = deployment.getStatus() != null && deployment.getStatus().getReadyReplicas() != null
                    ? deployment.getStatus().getReadyReplicas()
                    : 0;

                Integer availableReplicas = deployment.getStatus() != null && deployment.getStatus().getAvailableReplicas() != null
                    ? deployment.getStatus().getAvailableReplicas()
                    : 0;

                Integer unavailableReplicas = deployment.getStatus() != null && deployment.getStatus().getUnavailableReplicas() != null
                    ? deployment.getStatus().getUnavailableReplicas()
                    : 0;

                observations.add("Deployment " + deploymentName
                    + ": desired=" + desiredReplicas
                    + ", ready=" + readyReplicas
                    + ", available=" + availableReplicas
                    + ", unavailable=" + unavailableReplicas);
            });
    }

    private boolean isPodReady(Pod pod) {
        if (pod.getStatus() == null || pod.getStatus().getConditions() == null) {
            return false;
        }

        for (PodCondition condition : pod.getStatus().getConditions()) {
            if ("Ready".equals(condition.getType()) && "True".equals(condition.getStatus())) {
                return true;
            }
        }

        return false;
    }

    private int getRestartCount(Pod pod) {
        if (pod.getStatus() == null || pod.getStatus().getContainerStatuses() == null) {
            return 0;
        }

        return pod.getStatus().getContainerStatuses().stream()
            .mapToInt(status -> status.getRestartCount() == null ? 0 : status.getRestartCount())
            .sum();
    }
}
