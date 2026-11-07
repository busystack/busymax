package io.busystack.busymax_android_platform

import java.net.InetAddress

internal data class LocalNetworkRoute(val destination: ByteArray, val prefixLength: Int) {
    fun matches(address: ByteArray): Boolean {
        if (destination.size != address.size || prefixLength !in 1..address.size * 8) return false
        return (0 until prefixLength).all { bit ->
            val mask = 1 shl (7 - bit % 8)
            (destination[bit / 8].toInt() and mask) == (address[bit / 8].toInt() and mask)
        }
    }
}

/** Route evidence complements address hints; VPN and cellular are excluded. */
internal fun localNetworkAddress(address: InetAddress, applicableInterface: Boolean, routes: List<LocalNetworkRoute>): Boolean {
    if (!applicableInterface || address.isLoopbackAddress || address.isAnyLocalAddress) return false
    val bytes = address.address.map { it.toInt() and 255 }
    if (bytes.size == 4) return bytes[0] == 10 ||
        bytes[0] == 172 && bytes[1] in 16..31 ||
        bytes[0] == 192 && bytes[1] == 168 ||
        bytes[0] == 169 && bytes[1] == 254 ||
        bytes[0] == 100 && bytes[1] in 64..127 ||
        bytes[0] in 224..239 || bytes.all { it == 255 }
    return address.isLinkLocalAddress || address.isMulticastAddress || routes.any { it.matches(address.address) }
}
