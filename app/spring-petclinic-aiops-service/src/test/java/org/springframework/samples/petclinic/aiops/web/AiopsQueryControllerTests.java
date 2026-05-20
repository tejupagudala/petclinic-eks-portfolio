package org.springframework.samples.petclinic.aiops.web;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.samples.petclinic.aiops.AiopsServiceApplication;
import org.springframework.test.web.servlet.MockMvc;

@SpringBootTest(classes = AiopsServiceApplication.class)
@AutoConfigureMockMvc
class AiopsQueryControllerTests {

    @Autowired
    private MockMvc mockMvc;

    @Test
    void queryReturnsStructuredResponse() throws Exception {
        mockMvc.perform(post("/query")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""
                    {
                      "question": "Why is api-gateway failing?",
                      "service": "api-gateway",
                      "namespace": "petclinic",
                      "timeRangeMinutes": 30
                    }
                    """))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.probableRootCause").exists())
            .andExpect(jsonPath("$.evidenceCollected").isArray())
            .andExpect(jsonPath("$.impactedServices[0]").value("api-gateway"))
            .andExpect(jsonPath("$.recommendedFix").isArray())
            .andExpect(jsonPath("$.confidence").value("low"))
            .andExpect(jsonPath("$.unknowns").isArray());
    }
}
