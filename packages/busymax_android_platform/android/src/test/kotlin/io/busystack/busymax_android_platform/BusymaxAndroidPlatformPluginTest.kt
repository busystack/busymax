package io.busystack.busymax_android_platform

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
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
}
