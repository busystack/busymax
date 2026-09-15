package io.busystack.busymax_android_platform

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import com.microsoft.identity.client.exception.MsalClientException
import com.microsoft.identity.client.exception.MsalServiceException
import com.microsoft.identity.client.exception.MsalUiRequiredException
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertNotNull
import org.junit.jupiter.api.Test
import org.mockito.Mockito

internal class BusymaxAndroidPlatformPluginTest {
    @Test
    fun unknownMethod_isReportedAsNotImplemented() {
        val plugin = BusymaxAndroidPlatformPlugin()
        val call = MethodCall("unsupported", null)
        val mockResult: MethodChannel.Result = Mockito.mock(MethodChannel.Result::class.java)
        plugin.onMethodCall(call, mockResult)
        Mockito.verify(mockResult).notImplemented()
    }

    @Test
    fun releasingEngineOwnedLeases_unblocksAnotherEngine() {
        val first = EngineOwnedAccountGateRegistry.acquire("account", "engine-1", 1)
        assertNotNull(first)

        EngineOwnedAccountGateRegistry.releaseOwned("engine-1")

        val second = EngineOwnedAccountGateRegistry.acquire("account", "engine-2", 1)
        assertNotNull(second)
        EngineOwnedAccountGateRegistry.releaseOwned("engine-2")
    }

    @Test
    fun microsoftSilentFailures_preserveAuthenticationForTransientErrors() {
        assertEquals(
            "android/auth-interaction-required",
            classifyMicrosoftSilentFailure(MicrosoftAccountMissingException()).code,
        )
        assertEquals(
            "android/auth-interaction-required",
            classifyMicrosoftSilentFailure(
                MsalUiRequiredException(MsalUiRequiredException.NO_TOKENS_FOUND, "No token"),
            ).code,
        )
        assertEquals(
            "android/auth-temporary-failure",
            classifyMicrosoftSilentFailure(
                MsalServiceException(MsalServiceException.SERVICE_NOT_AVAILABLE, "Unavailable", null),
            ).code,
        )
        assertEquals(
            "android/auth-temporary-failure",
            classifyMicrosoftSilentFailure(
                MsalClientException(MsalClientException.DEVICE_NETWORK_NOT_AVAILABLE, "Offline"),
            ).code,
        )
        assertEquals(
            "android/microsoft-not-configured",
            classifyMicrosoftSilentFailure(
                MsalClientException(MsalClientException.REDIRECT_URI_VALIDATION_ERROR, "Bad redirect"),
            ).code,
        )
    }
}
