package org.springframework.samples.petclinic.aiops.dto;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;

public class AiopsQueryRequest {

    @NotBlank
    private String question;

    private String service;

    private String namespace;

    @Min(1)
    @Max(1440)
    private Integer timeRangeMinutes = 30;

    public String getQuestion() {
        return question;
    }

    public void setQuestion(String question) {
        this.question = question;
    }

    public String getService() {
        return service;
    }

    public void setService(String service) {
        this.service = service;
    }

    public String getNamespace() {
        return namespace;
    }

    public void setNamespace(String namespace) {
        this.namespace = namespace;
    }

    public Integer getTimeRangeMinutes() {
        return timeRangeMinutes;
    }

    public void setTimeRangeMinutes(Integer timeRangeMinutes) {
        this.timeRangeMinutes = timeRangeMinutes;
    }
}
