package org.springframework.samples.petclinic.aiops.tools;

import org.springframework.samples.petclinic.aiops.dto.AiopsQueryRequest;
import org.springframework.samples.petclinic.aiops.dto.EvidenceSection;

public interface LogsAdapter {

    EvidenceSection fetchLogs(AiopsQueryRequest request);
}
