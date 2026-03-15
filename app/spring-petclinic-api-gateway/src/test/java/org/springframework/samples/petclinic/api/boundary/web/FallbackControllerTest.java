package org.springframework.samples.petclinic.api.boundary.web;

import org.junit.jupiter.api.Test;
import org.springframework.http.ResponseEntity;

import static org.junit.jupiter.api.Assertions.assertEquals;

class FallbackControllerTest {

    @Test
    void fallbackReturnsServiceUnavailableWithExpectedMessage() {
        FallbackController controller = new FallbackController();

        ResponseEntity<String> response = controller.fallback();

        assertEquals(503, response.getStatusCode().value());
        assertEquals("Chat is currently unavailable. Please try again later.", response.getBody());
    }
}
