package org.springframework.samples.petclinic.aiops.service;

import java.util.List;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.samples.petclinic.aiops.dto.AiopsQueryRequest;
import org.springframework.stereotype.Service;

import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.bedrockruntime.BedrockRuntimeClient;
import software.amazon.awssdk.services.bedrockruntime.model.ContentBlock;
import software.amazon.awssdk.services.bedrockruntime.model.ConversationRole;
import software.amazon.awssdk.services.bedrockruntime.model.ConverseRequest;
import software.amazon.awssdk.services.bedrockruntime.model.ConverseResponse;
import software.amazon.awssdk.services.bedrockruntime.model.InferenceConfiguration;
import software.amazon.awssdk.services.bedrockruntime.model.Message;

@Service
public class BedrockReasoningService {

    private final Region region;
    private final String modelId;
    private final Integer maxTokens;
    private final Float temperature;

    public BedrockReasoningService(
        @Value("${aiops.aws-region}") String awsRegion,
        @Value("${aiops.bedrock-model-id}") String modelId,
        @Value("${aiops.bedrock-max-tokens}") Integer maxTokens,
        @Value("${aiops.bedrock-temperature}") Float temperature
    ) {
        this.region = Region.of(awsRegion);
        this.modelId = modelId;
        this.maxTokens = maxTokens;
        this.temperature = temperature;
    }

    public String summarize(AiopsQueryRequest request, List<String> evidence) {
        String prompt = buildPrompt(request, evidence);

        try (BedrockRuntimeClient client = BedrockRuntimeClient.builder()
            .region(region)
            .build()) {

            Message userMessage = Message.builder()
                .role(ConversationRole.USER)
                .content(ContentBlock.fromText(prompt))
                .build();

            ConverseRequest converseRequest = ConverseRequest.builder()
                .modelId(modelId)
                .messages(userMessage)
                .inferenceConfig(InferenceConfiguration.builder()
                    .maxTokens(maxTokens)
                    .temperature(temperature)
                    .build())
                .build();

            ConverseResponse response = client.converse(converseRequest);

            if (response.output() == null
                || response.output().message() == null
                || response.output().message().content() == null
                || response.output().message().content().isEmpty()) {
                return "Bedrock returned an empty response.";
            }

            return response.output().message().content().get(0).text();
        } catch (Exception ex) {
            return "Bedrock reasoning failed: " + ex.getMessage();
        }
    }

    private String buildPrompt(AiopsQueryRequest request, List<String> evidence) {
        StringBuilder prompt = new StringBuilder();
        prompt.append("You are an AIOps incident assistant.\n");
        prompt.append("Use only the supplied evidence. Do not invent facts.\n");
        prompt.append("If the evidence mainly shows unavailable telemetry or missing infrastructure, say that clearly.\n");
        prompt.append("Do not confuse missing observability data with an application bug.\n");
        prompt.append("Return one concise probable root cause sentence.\n\n");
        prompt.append("Question: ").append(request.getQuestion()).append("\n");
        prompt.append("Service: ").append(request.getService()).append("\n");
        prompt.append("Namespace: ").append(request.getNamespace()).append("\n\n");
        prompt.append("Evidence:\n");

        for (String line : evidence) {
            prompt.append("- ").append(line).append("\n");
        }

        return prompt.toString();
    }
}
