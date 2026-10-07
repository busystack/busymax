package io.busystack.busymax_android_platform

import org.junit.jupiter.api.Assertions.*
import org.junit.jupiter.api.Test

internal class MicrosoftRegistrationTest {
    private val a = "11111111-1111-1111-1111-111111111111"
    private val b = "22222222-2222-2222-2222-222222222222"
    @Test fun warmedOriginalCannotSelectOrReplaceUserOwnedClients() {
        val clients = MicrosoftRegistrationClients<Any>()
        val original = clients.getOrCreate(null) { Any() }
        val ownA = clients.getOrCreate(MicrosoftRegistration(a)) { Any() }
        val ownB = clients.getOrCreate(MicrosoftRegistration(b)) { Any() }
        assertNotSame(original, ownA)
        assertNotSame(ownA, ownB)
        assertSame(ownA, clients.getOrCreate(MicrosoftRegistration(a)) { fail("Client must be reused") })
        assertSame(original, clients.getOrCreate(null) { fail("Original client must remain") })
        val tenantA = clients.getOrCreate(MicrosoftRegistration(a, b)) { Any() }
        assertNotSame(ownA, tenantA)
    }
    @Test fun supportedAudiencesAreDistinctFromAuthenticatedTenant() {
        assertEquals("AzureADandPersonalMicrosoftAccount", MicrosoftRegistration(a).audienceType)
        assertEquals("AzureADMultipleOrgs", MicrosoftRegistration(a, "organizations").audienceType)
        assertEquals("PersonalMicrosoftAccount", MicrosoftRegistration(a, "consumers").audienceType)
        assertEquals("AzureADMyOrg", MicrosoftRegistration(a, b).audienceType)
    }
    @Test fun arbitraryAuthoritiesAndMalformedClientsAreRejected() {
        assertThrows(IllegalArgumentException::class.java) { MicrosoftRegistration("not-a-client") }
        assertThrows(IllegalArgumentException::class.java) { MicrosoftRegistration(a, "https://attacker.example") }
        assertThrows(IllegalArgumentException::class.java) { MicrosoftRegistration(a, "1-2-3-4-5") }
    }
}
