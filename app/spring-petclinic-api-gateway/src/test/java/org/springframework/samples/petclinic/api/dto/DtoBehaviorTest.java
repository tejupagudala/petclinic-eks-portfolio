package org.springframework.samples.petclinic.api.dto;

import org.junit.jupiter.api.Test;

import java.util.ArrayList;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

class DtoBehaviorTest {

    @Test
    void ownerBuilderAndGetPetIdsWorkAsExpected() {
        PetDetails pet1 = PetDetails.PetDetailsBuilder.aPetDetails()
            .id(10)
            .name("Lucky")
            .birthDate("2020-01-01")
            .type(new PetType("dog"))
            .visits(new ArrayList<>())
            .build();

        // This pet intentionally leaves visits unset to validate null-safe record behavior.
        PetDetails pet2 = PetDetails.PetDetailsBuilder.aPetDetails()
            .id(11)
            .name("Milo")
            .build();

        OwnerDetails owner = OwnerDetails.OwnerDetailsBuilder.anOwnerDetails()
            .id(1)
            .firstName("Teju")
            .lastName("P")
            .address("street")
            .city("Austin")
            .telephone("1111111111")
            .pets(List.of(pet1, pet2))
            .build();

        assertEquals(List.of(10, 11), owner.getPetIds());
        assertNotNull(pet2.visits());
        assertTrue(pet2.visits().isEmpty());
    }

    @Test
    void visitsDefaultConstructorCreatesEmptyList() {
        Visits visits = new Visits();
        assertNotNull(visits.items());
        assertTrue(visits.items().isEmpty());
    }
}
