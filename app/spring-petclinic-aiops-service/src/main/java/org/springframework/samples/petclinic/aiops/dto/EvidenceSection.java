package org.springframework.samples.petclinic.aiops.dto;

import java.util.ArrayList;
import java.util.List;

public class EvidenceSection {

    private String source;
    private List<String> observations = new ArrayList<>();

    public EvidenceSection() {
    }

    public EvidenceSection(String source, List<String> observations) {
        this.source = source;
        this.observations = observations;
    }

    public String getSource() {
        return source;
    }

    public void setSource(String source) {
        this.source = source;
    }

    public List<String> getObservations() {
        return observations;
    }

    public void setObservations(List<String> observations) {
        this.observations = observations;
    }
}
