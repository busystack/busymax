package io.busystack.busymax_android_platform

import android.app.NotificationChannel
import android.app.NotificationManager
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Test
import org.mockito.Mockito.*

class NotificationChannelsTest {
    @Test
    fun `creation order never changes reminder or summary importance`() {
        for (summaryFirst in listOf(true, false)) {
            val manager = mock(NotificationManager::class.java)
            val channels = mutableMapOf<String, NotificationChannel>()
            val importance = mutableMapOf<String, Int>()
            val factory = { id: String, _: String, level: Int ->
                mock(NotificationChannel::class.java).also {
                    channels[id] = it
                    importance[id] = level
                    `when`(it.importance).thenReturn(level)
                }
            }
            `when`(manager.getNotificationChannel(anyString())).thenAnswer { channels[it.getArgument<String>(0)] }
            if (summaryFirst) factory("busymax_summaries_v1", "Summary", NotificationManager.IMPORTANCE_DEFAULT)
            else factory("busymax_reminders_v1", "Reminders", NotificationManager.IMPORTANCE_HIGH)
            prepareBusyMaxNotificationChannels(manager, "Reminders", "Summary", "Status", factory, { false })
            assertEquals(NotificationManager.IMPORTANCE_HIGH, importance["busymax_reminders_v1"])
            assertEquals(NotificationManager.IMPORTANCE_DEFAULT, importance["busymax_summaries_v1"])
        }
    }

    @Test
    fun `existing choices are copied once and independently retained`() {
        val manager = mock(NotificationManager::class.java)
        val old = mock(NotificationChannel::class.java)
        val summary = mock(NotificationChannel::class.java)
        `when`(manager.getNotificationChannel("busymax_reminders_v1")).thenReturn(old)
        `when`(old.importance).thenReturn(NotificationManager.IMPORTANCE_NONE)
        `when`(old.shouldVibrate()).thenReturn(false)
        val pattern = longArrayOf(0, 200, 100, 200)
        `when`(old.vibrationPattern).thenReturn(pattern)
        `when`(old.lockscreenVisibility).thenReturn(-1)
        val created = mutableListOf<Pair<String, Int>>()
        val factory = { id: String, _: String, level: Int ->
            created.add(id to level)
            if (id == "busymax_summaries_v1") summary else mock(NotificationChannel::class.java)
        }
        prepareBusyMaxNotificationChannels(manager, "Reminders", "Summary", "Status", factory)
        assertEquals(NotificationManager.IMPORTANCE_NONE, created.single { it.first == "busymax_summaries_v1" }.second)
        verify(summary).enableVibration(false)
        val order = inOrder(summary)
        order.verify(summary).setVibrationPattern(pattern)
        order.verify(summary).enableVibration(false)
        verify(summary).setLockscreenVisibility(-1)
        verify(summary).setSound(old.sound, old.audioAttributes)
        verify(manager).createNotificationChannel(old)
        `when`(manager.getNotificationChannel("busymax_summaries_v1")).thenReturn(summary)
        clearInvocations(summary)
        prepareBusyMaxNotificationChannels(manager, "Erinnerungen", "Übersicht", "Status", factory)
        verify(summary, never()).enableVibration(anyBoolean())
        assertEquals(1, created.count { it.first == "busymax_summaries_v1" })
    }

    @Test
    fun `explicit user importance survives the one-time split`() {
        val manager = mock(NotificationManager::class.java)
        val old = mock(NotificationChannel::class.java)
        `when`(manager.getNotificationChannel("busymax_reminders_v1")).thenReturn(old)
        `when`(old.importance).thenReturn(NotificationManager.IMPORTANCE_HIGH)
        val levels = mutableMapOf<String, Int>()
        val factory = { id: String, _: String, level: Int ->
            levels[id] = level
            mock(NotificationChannel::class.java)
        }
        prepareBusyMaxNotificationChannels(manager, "Reminders", "Summary", "Status", factory, { true })
        assertEquals(NotificationManager.IMPORTANCE_HIGH, levels["busymax_summaries_v1"])
        verify(manager).createNotificationChannel(old)
    }
}
