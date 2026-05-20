package org.springframework.samples.petclinic.aiops.web;

import java.util.List;

import jakarta.validation.Valid;
import org.springframework.http.MediaType;
import org.springframework.samples.petclinic.aiops.dto.AiopsQueryRequest;
import org.springframework.samples.petclinic.aiops.dto.AiopsQueryResponse;
import org.springframework.samples.petclinic.aiops.service.AiopsQueryService;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping(path = "/", produces = MediaType.APPLICATION_JSON_VALUE)
public class AiopsQueryController {

    private final AiopsQueryService aiopsQueryService;

    public AiopsQueryController(AiopsQueryService aiopsQueryService) {
        this.aiopsQueryService = aiopsQueryService;
    }

    @PostMapping(path = "/query", consumes = MediaType.APPLICATION_JSON_VALUE)
    public AiopsQueryResponse query(@Valid @RequestBody AiopsQueryRequest request) {
        return aiopsQueryService.query(request);
    }
}

