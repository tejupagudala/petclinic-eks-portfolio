package org.springframework.samples.petclinic.aiops.dto;

import java.util.ArrayList;
import java.util.List;

public class AiopsQueryResponse {

    private String probableRootCause;
    private List<String> evidenceCollected = new ArrayList<>();
    private List<String> impactedServices = new ArrayList<>();
    private List<String> recommendedFix = new ArrayList<>();
    private String confidence;
    private List<String> unknowns = new ArrayList<>();

    public String getProbableRootCause() {
        return probableRootCause;
    }

    public void setProbableRootCause(String probableRootCause) {
        this.probableRootCause = probableRootCause;
    }

    public List<String> getEvidenceCollected() {
        return evidenceCollected;
    }

    public void setEvidenceCollected(List<String> evidenceCollected) {
        this.evidenceCollected = evidenceCollected;
    }

    public List<String> getImpactedServices() {
        return impactedServices;
    }

    public void setImpactedServices(List<String> impactedServices) {
        this.impactedServices = impactedServices;
    }

    public List<String> getRecommendedFix() {
        return recommendedFix;
    }

    public void setRecommendedFix(List<String> recommendedFix) {
        this.recommendedFix = recommendedFix;
    }

    public String getConfidence() {
        return confidence;
    }

    public void setConfidence(String confidence) {
        this.confidence = confidence;
    }

    public List<String> getUnknowns() {
        return unknowns;
    }

    public void setUnknowns(List<String> unknowns) {
        this.unknowns = unknowns;
    }
}
