package org.springframework.samples.petclinic.aiops.tools.impl;

import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.List;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.samples.petclinic.aiops.dto.AiopsQueryRequest;
import org.springframework.samples.petclinic.aiops.dto.EvidenceSection;
import org.springframework.samples.petclinic.aiops.tools.LogsAdapter;
import org.springframework.stereotype.Component;

import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.cloudwatchlogs.CloudWatchLogsClient;
import software.amazon.awssdk.services.cloudwatchlogs.model.FilterLogEventsRequest;
import software.amazon.awssdk.services.cloudwatchlogs.model.FilteredLogEvent;

@Component
public class CloudWatchLogsAdapter implements LogsAdapter {

    private final String logGroupName;
    private final Region region;

    public CloudWatchLogsAdapter(
        @Value("${aiops.cloudwatch-application-log-group}") String logGroupName,
        @Value("${aiops.aws-region}") String awsRegion
    ) {
        this.logGroupName = logGroupName;
        this.region = Region.of(awsRegion);
    }

    @Override
    public EvidenceSection fetchLogs(AiopsQueryRequest request) {
        List<String> observations = new ArrayList<>();
        long startTime = Instant.now()
            .minus(request.getTimeRangeMinutes(), ChronoUnit.MINUTES)
            .toEpochMilli();

        try (CloudWatchLogsClient client = CloudWatchLogsClient.builder()
            .region(region)
            .build()) {

            FilterLogEventsRequest logsRequest = FilterLogEventsRequest.builder()
                .logGroupName(logGroupName)
                .startTime(startTime)
                .limit(100)
                .build();

            List<FilteredLogEvent> events = client.filterLogEvents(logsRequest).events();

            String serviceName = request.getService();
            List<FilteredLogEvent> matchingEvents = events.stream()
                .filter(event -> matchesService(event, serviceName))
                .limit(20)
                .toList();

            if (matchingEvents.isEmpty()) {
                observations.add("No matching CloudWatch log events found.");
                observations.add("Log group: " + logGroupName);
                observations.add("Service filter: " + serviceName);
                observations.add("This may mean the service produced no logs in the selected window, or the filter does not match the actual workload name.");
                return new EvidenceSection("cloudwatch", observations);
            }

            observations.add("CloudWatch log group: " + logGroupName);
            observations.add("Matched log events: " + matchingEvents.size());

            for (FilteredLogEvent event : matchingEvents) {
                observations.add(formatEvent(event));
            }
        } catch (Exception ex) {
            observations.add("Failed to query CloudWatch Logs.");
            observations.add("Log group: " + logGroupName);
            observations.add("This may indicate the environment is not currently running or the configured log group is unavailable.");
            observations.add("Error: " + ex.getMessage());
        }

        return new EvidenceSection("cloudwatch", observations);
    }

    private boolean matchesService(FilteredLogEvent event, String serviceName) {
        if (serviceName == null || serviceName.isBlank()) {
            return true;
        }

        String normalizedService = serviceName.toLowerCase();
        String message = event.message() == null ? "" : event.message();
        String logStreamName = event.logStreamName() == null ? "" : event.logStreamName();

        return message.contains(normalizedService) || logStreamName.contains(normalizedService);
    }

    private String formatEvent(FilteredLogEvent event) {
        String message = event.message() == null ? "" : event.message().replace('\n', ' ').trim();
        if (message.length() > 240) {
            message = message.substring(0, 240) + "...";
        }
        
        String timestamp = event.timestamp() == null
            ? "unknown-time"
            : Instant.ofEpochMilli(event.timestamp()).toString();
        return "[" + event.timestamp() + "] " + message;
    }
}
