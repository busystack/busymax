package io.busystack.busymax_android_platform

import java.util.UUID

/** Public registration settings; native caches and tokens remain owned by MSAL. */
internal data class MicrosoftRegistration(val clientId: String, val tenant: String = "common") {
    init {
        require(UUID.fromString(clientId).toString().equals(clientId, ignoreCase = true))
        require(tenant in setOf("common", "organizations", "consumers") ||
            UUID.fromString(tenant).toString().equals(tenant, ignoreCase = true))
    }
    val key: String get() = "${clientId.lowercase()}:${tenant.lowercase()}"
    val audienceType: String get() = when (tenant) {
        "common" -> "AzureADandPersonalMicrosoftAccount"
        "organizations" -> "AzureADMultipleOrgs"
        "consumers" -> "PersonalMicrosoftAccount"
        else -> "AzureADMyOrg"
    }
}

internal class MicrosoftRegistrationClients<T> {
    private val clients = mutableMapOf<String, T>()
    @Synchronized
    fun getOrCreate(registration: MicrosoftRegistration?, create: () -> T): T =
        clients.getOrPut(registration?.key ?: "original-native-registration", create)
}
