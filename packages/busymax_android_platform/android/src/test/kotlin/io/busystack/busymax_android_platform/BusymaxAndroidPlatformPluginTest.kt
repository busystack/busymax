package io.busystack.busymax_android_platform

import androidx.core.text.util.LocalePreferences
import com.microsoft.identity.client.exception.MsalClientException
import com.microsoft.identity.client.exception.MsalServiceException
import com.microsoft.identity.client.exception.MsalUiRequiredException
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.Locale
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertNotNull
import org.junit.jupiter.api.Test
import org.mockito.Mockito

internal class BusymaxAndroidPlatformPluginTest {
    @Test
    fun firstWeekday_convertsEveryAndroidxValueToDartNumbering() {
        val values = listOf(
            LocalePreferences.FirstDayOfWeek.MONDAY to 1,
            LocalePreferences.FirstDayOfWeek.TUESDAY to 2,
            LocalePreferences.FirstDayOfWeek.WEDNESDAY to 3,
            LocalePreferences.FirstDayOfWeek.THURSDAY to 4,
            LocalePreferences.FirstDayOfWeek.FRIDAY to 5,
            LocalePreferences.FirstDayOfWeek.SATURDAY to 6,
            LocalePreferences.FirstDayOfWeek.SUNDAY to 7,
        )
        values.forEach { (value, expected) ->
            assertEquals(expected, dartWeekday(value))
        }
        assertEquals(null, dartWeekday(null))
        assertEquals(null, dartWeekday("unexpected"))
    }

    @Test
    fun firstWeekday_readsUnicodeOverrideThroughAndroidx() {
        val original = Locale.getDefault()
        try {
            Locale.setDefault(Locale.forLanguageTag("en-US-u-fw-mon"))
            assertEquals(1, androidxFirstWeekday())

            Locale.setDefault(Locale.forLanguageTag("en-US-u-fw-thu"))
            assertEquals(4, androidxFirstWeekday())
        } finally {
            Locale.setDefault(original)
        }
    }

    @Test
    fun systemSettingsReceiver_detachesAndReattachesWithoutDuplicatesOrStaleListener() {
        var registrations = 0
        var unregistrations = 0
        var listenerActive = true
        val lifecycle = SystemSettingsReceiverLifecycle(
            register = { registrations++ },
            unregister = { unregistrations++ },
            clearListener = { listenerActive = false },
        )

        lifecycle.attach()
        lifecycle.attach()
        assertEquals(1, registrations)

        lifecycle.detach()
        lifecycle.detach()
        assertEquals(1, unregistrations)
        assertEquals(false, listenerActive)

        lifecycle.attach()
        assertEquals(2, registrations)
    }

    @Test
    fun activityRecreation_removesListenersBeforeReattachingThem() {
        val additions = mutableListOf<String>()
        val removals = mutableListOf<String>()
        val lifecycle = ActivityListenerLifecycle<String>(
            add = additions::add,
            remove = removals::add,
        )

        lifecycle.attach("first activity")
        lifecycle.detach()
        lifecycle.attach("recreated activity")
        lifecycle.detach()
        lifecycle.detach()

        assertEquals(listOf("first activity", "recreated activity"), additions)
        assertEquals(listOf("first activity", "recreated activity"), removals)
    }

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
