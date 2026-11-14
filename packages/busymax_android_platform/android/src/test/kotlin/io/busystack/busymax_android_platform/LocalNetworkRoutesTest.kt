package io.busystack.busymax_android_platform

import java.net.InetAddress
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Test

internal class LocalNetworkRoutesTest {
    @Test
    fun cgnatBoundariesAndVpnCellularExclusion() {
        for ((host, expected) in mapOf("100.63.255.255" to false, "100.64.0.0" to true,
            "100.127.255.255" to true, "100.128.0.0" to false, "192.168.1.1" to true,
            "169.254.0.1" to true, "224.0.0.1" to true, "255.255.255.255" to true,
            "203.0.113.1" to false, "127.0.0.1" to false)) {
            val address = InetAddress.getByName(host)
            assertEquals(expected, localNetworkAddress(address, true, emptyList()), host)
            assertEquals(false, localNetworkAddress(address, false, emptyList()), "VPN/cellular: $host")
        }
    }

    @Test
    fun ipv6RequiresAnApplicableRouteRatherThanEveryGlobalAddress() {
        val route = LocalNetworkRoute(InetAddress.getByName("2001:db8:1::").address, 64)
        for ((host, expected) in mapOf("2001:db8:1::20" to true, "2001:db8:2::20" to false,
            "fe80::1" to true, "ff02::1" to true, "::1" to false)) {
            val address = InetAddress.getByName(host)
            assertEquals(expected, localNetworkAddress(address, true, listOf(route)), host)
            assertEquals(false, localNetworkAddress(address, false, listOf(route)), "VPN/cellular: $host")
        }
        assertEquals(false, localNetworkAddress(InetAddress.getByName("2001:db8:1::20"), true,
            listOf(LocalNetworkRoute(InetAddress.getByName("::").address, 0))), "default internet route")
    }
}
