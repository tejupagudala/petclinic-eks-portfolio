package org.springframework.samples.petclinic.api.application;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.samples.petclinic.api.dto.OwnerDetails;
import org.springframework.samples.petclinic.api.dto.PetDetails;
import org.springframework.web.reactive.function.client.WebClient;
import reactor.core.publisher.Mono;

import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class CustomersServiceClientTest {

    @Mock
    private WebClient.Builder webClientBuilder;
    @Mock
    private WebClient webClient;
    @Mock
    private WebClient.RequestHeadersUriSpec<?> requestHeadersUriSpec;
    @Mock
    private WebClient.RequestHeadersSpec<?> requestHeadersSpec;
    @Mock
    private WebClient.ResponseSpec responseSpec;

    @Test
    @SuppressWarnings("unchecked")
    void getOwnerBuildsExpectedRequestAndReturnsOwner() {
        int ownerId = 7;
        OwnerDetails owner = new OwnerDetails(
            ownerId,
            "Sam",
            "Peterson",
            "Street 1",
            "Austin",
            "1111111111",
            List.of(PetDetails.PetDetailsBuilder.aPetDetails().id(2).name("Leo").build())
        );

        when(webClientBuilder.build()).thenReturn(webClient);
        when(webClient.get()).thenReturn((WebClient.RequestHeadersUriSpec) requestHeadersUriSpec);
        when(requestHeadersUriSpec.uri(anyString(), anyInt())).thenReturn((WebClient.RequestHeadersSpec) requestHeadersSpec);
        when(requestHeadersSpec.retrieve()).thenReturn(responseSpec);
        when(responseSpec.bodyToMono(eq(OwnerDetails.class))).thenReturn(Mono.just(owner));

        CustomersServiceClient client = new CustomersServiceClient(webClientBuilder);
        OwnerDetails result = client.getOwner(ownerId).block();

        assertEquals(ownerId, result.id());
        assertEquals("Sam", result.firstName());
        verify(requestHeadersUriSpec).uri("http://customers-service/owners/{ownerId}", ownerId);
    }
}
