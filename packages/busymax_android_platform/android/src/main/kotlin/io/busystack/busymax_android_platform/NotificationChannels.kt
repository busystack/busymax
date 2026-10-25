package io.busystack.busymax_android_platform

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build

/** A single, targeted split of the existing reminders category. */
internal fun prepareBusyMaxNotificationChannels(
    manager: NotificationManager,
    reminders: String,
    summaries: String,
    status: String,
    create: (String, String, Int) -> NotificationChannel = { id, name, importance ->
        NotificationChannel(id, name, importance)
    },
    importanceChosenByUser: (NotificationChannel) -> Boolean = { channel ->
        // Older supported Android versions cannot distinguish a user choice
        // from the app's original importance. Preserve it under uncertainty.
        Build.VERSION.SDK_INT < Build.VERSION_CODES.Q || channel.hasUserSetImportance()
    },
) {
    val old = manager.getNotificationChannel("busymax_reminders_v1")
    val existingSummary = manager.getNotificationChannel("busymax_summaries_v1")
    val summaryImportance = if (old != null && importanceChosenByUser(old)) old.importance
        else minOf(old?.importance ?: NotificationManager.IMPORTANCE_DEFAULT,
            NotificationManager.IMPORTANCE_DEFAULT)
    val summary = existingSummary ?: create("busymax_summaries_v1", summaries,
        summaryImportance).also { channel ->
        if (old != null) {
            channel.setSound(old.sound, old.audioAttributes)
            channel.vibrationPattern = old.vibrationPattern
            // setVibrationPattern itself enables vibration for a non-empty
            // pattern. Apply the user's enablement after copying that pattern.
            channel.enableVibration(old.shouldVibrate())
            channel.enableLights(old.shouldShowLights())
            channel.lightColor = old.lightColor
            channel.lockscreenVisibility = old.lockscreenVisibility
            channel.setShowBadge(old.canShowBadge())
        }
    }
    summary.name = summaries
    manager.createNotificationChannel(summary)
    val reminder = old ?: create("busymax_reminders_v1", reminders, NotificationManager.IMPORTANCE_HIGH)
    reminder.name = reminders
    manager.createNotificationChannel(reminder)
    val statusChannel = manager.getNotificationChannel("busymax_status_v1") ?:
        create("busymax_status_v1", status, NotificationManager.IMPORTANCE_DEFAULT)
    statusChannel.name = status
    manager.createNotificationChannel(statusChannel)
}
