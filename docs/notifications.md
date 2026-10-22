# Notification delivery policy

BusyMax uses the existing desktop timer/tray runtime and Android's native alarms
and WorkManager refill. Saving a provider reminder, creating a schedule row,
native submission, a visible post, and user acknowledgement are distinct states.
BusyMax does not claim a notification was seen merely because submission succeeded.

The [audit and acceptance record](notification-validation.md) lists confirmed
repairs, automated results and the native checks still requiring another OS or
package environment.

## Reminders

Provider/event/task projections feed `NotificationScheduleService`, which retains
the alarm's original instant and identity. Desktop `NotificationScheduler` checks
source eligibility, conditionally claims a generation, submits through
`DesktopNotificationService`, validates the source again, and conditionally records
submission. Android reconciles those same rows with durable integer identities,
pending alarms and active native posts, validating around native registration.

The catch-up rules apply equally to first discovery and an existing unsent row:

* A pre-event reminder remains relevant through the occurrence's end. Without an
  end, its start is the reference boundary. All-day ends remain exclusive.
* End-relative, absolute and repeating alarms retain their actual trigger. A
  trigger at or after the occurrence boundary gets ten minutes of registration
  grace. This allows a native operation or ordinary scheduler tick to cross a
  trigger; event start is never a universal expiry rule.
* An open-task reminder remains relevant through its trigger's local calendar
  day, with the same ten-minute minimum grace across midnight. Old task reminder
  data is preserved; several days of historical alarms are not replayed.
* Multiple overdue offsets/repetitions for one source occurrence consolidate to
  its latest overdue trigger. Future offsets/repetitions remain scheduled.
* Quiet hours defer eligible alarms to the local end of quiet hours. They do not
  make an ended occurrence or an old task alarm relevant again. Desktop deferral
  survives restart. Android never registers a quiet-hours release beyond expiry.
* An explicit Snooze retains its original alarm identity and persists a new
  generation ten minutes ahead. It may extend beyond event start/end. A missed
  snooze has ten minutes of catch-up grace; it cannot replay indefinitely.
  Its deadline is a fixed UTC instant: a timezone change does not add another
  delay, and a clock jump applies the same expiry policy to that instant.

Expiry and consolidation are terminal delivery decisions, persisted separately
from Dismiss. Neither changes, deletes nor completes the source. Terminal
identities remain non-deliverable through ordinary rebuilding; obsolete terminal
rows lose their copied display text. A changed future source alarm can establish
a new generation. Source/account/collection eligibility and conditional writes
remain authoritative.

Already submitted reminders retain Open/Snooze/Dismiss while their source alarm
is valid. Android records an active post before evaluating unsent expiry. Known
past registrations absent from pending and active native state are consumed,
not recreated. When active-state inspection is unavailable, BusyMax preserves
known identity and suppresses speculative redelivery. Privacy still withdraws
known identities. Absence alone cannot prove whether an OS-blocked post was
displayed or dismissed while the app was stopped; BusyMax chooses not to revive
a possibly dismissed alert.

Native delivery is observed before withdrawing an ineligible account's
registrations. Reconnecting that account cannot recreate a post already
displayed during the eligibility transition. A consumed Android body click may
still open the same valid source; Open never clears its delivery history.

## Editing

Adding a reminder evaluates the current clock. A due-day 09:00 default is used
only while future; otherwise the default is ten minutes ahead. Absolute reminder
pickers also start in the future. A newly enabled or edited reminder in an older
minute receives localized validation. The current minute is accepted, including
a save crossing its trigger. Unchanged saved/imported historical reminders are
not moved or rejected when unrelated fields are edited. Provider-zoned values
are interpreted with their saved zone.

## Privacy, categories and localization

Private notifications contain controlled localized text, never source titles,
locations, notes, account labels or exception bodies. Desktop privacy changes
withdraw existing detailed posts, including delivery already awaiting a native
operation. Android withdraws detailed reminder posts and silently updates visible
summaries using the same native identity. Pending registrations refresh their
content and action labels. Failed cleanup retains identity and retry state.
Switching back to normal details never recreates a consumed post.

Disabling a category withdraws its visible posts and pending registrations.
Re-enabling allows only still-relevant, unconsumed reminders. It does not revive
a previously visible withdrawn post. This is separate from privacy handling.

All Android contexts, including a terminated-process Snooze callback, resolve the
saved app locale (or the supported system locale) through
`AndroidNotificationStrings.forSettings`. Snooze labels state ten minutes.
Pending locale changes update registration fingerprints. A visible native post
is not re-alerted solely to translate its actions; desktop may withdraw it.

User-authored display text is not log-redacted. Reminder content uses absolute
local timing with a UTC offset, location and collection/account context instead
of long notes or relative phrases that become false in notification history.
Linux body markup is escaped only when the server advertises markup support.
Diagnostic redaction remains unchanged.

## Daily summaries

Summaries are optional and off by default. Their scope is all eligible accounts
and non-deleted/non-missing lists, independent of current browsing filters. Open,
visible, non-canceled tasks must have a real deadline on that local date; a DAV
DTSTART fallback is not DUE. Count, localized scope, history and destination use
this same set.

The default is 09:00 local time on every platform. Notification settings expose a
local summary time. A day with no due tasks does not consume the opportunity.
If tasks arrive, synchronization finishes, permission returns, or the feature is
enabled later that day, one relevant summary may still alert. Quiet hours defer
within that date; yesterday's summary is not newly delivered the next morning.

Submission/consumption history is durable. Count changes never create another
audible/head-up summary. Android updates a still-visible summary silently; an
absent/consumed post stays absent. Zero withdraws a visible summary without
reopening the day's opportunity. Desktop retains the submitted snapshot until
withdrawal, zero, or the next date; it does not call native Show to change counts.
History also prevents duplicate days after timezone/clock movement.

Open carries the summary's original local date and shows that date's actual due
results in the existing task/schedule composition, without ordinary search,
account or list selections. Closing this temporary destination preserves normal
browsing state. Opening a delayed summary on another day shows its original date,
not an unrelated current Tasks view.

## Operational issues and recovery

`OperationalNotificationCoordinator` scans durable unresolved replay/conflict
state shared by Google, Microsoft and DAV. Callback and scan delivery share
per-account, per-issue deduplication. Quiet hours defer unresolved issues. Native
submission failure retains a one-minute retry opportunity; recovery/resolution or
account removal withdraws the post and clears obsolete work. Successful
submission is recorded only after the backend succeeds. Successful sync permits
a genuinely later failure to notify again.
Account issue revisions also carry the existing durable authorization generation.
Explicit reconnection invalidates pending/visible issues from the replaced
authorization without waiting for another successful network sync. Late failures
and native sends from that authorization cannot recreate its alert. Ordinary
token refresh leaves the generation unchanged.

Android and desktop use `syncFailureNotificationDisposition`: ordinary transport
errors, timeouts, cooldowns and retryable provider conditions are suppressed.
Actionable reconnection/permission/provider failures use controlled localized
messages and bounded account routes. Conflict routes open the existing account's
resolution/blocked-operation interface; notifications never resolve competing
edits themselves.

Windows body/Open activation passes the same route-specific Dart/native schema
through running, cold and secondary-process paths. Only the central activation
router executes actions. Snooze and Dismiss do not raise the window. Native
identities survive source deletion so later cleanup can still cancel them;
Linux identity persistence is scoped to both bus ID and notification-server
owner to avoid canceling another app's reused ID after a server restart.

## Readiness and platform contracts

App preferences, OS permission, channel blocking, exact-alarm capability and
backend failure are separate. Android denial keeps reminder data and preferences,
shows recovery through system notification settings, and refreshes effective
status on resume. Alarm precision has its own status and recovery control.
Reminder editors also check effective reminder-channel/backend status after
requesting app permission. A granted app permission cannot hide a blocked
reminder channel or an unavailable delivery status; saving still preserves data.
Startup performs no contextual permission request. Windows queries packaged
`ToastNotifier.Setting`; unknown is not reported as allowed. Freedesktop exposes
submission/capabilities, not a reliable per-app permission or Do Not Disturb
query. Linux explains that delivery status cannot be established from those APIs.

Android retains `busymax_reminders_v1` for timed reminders (high importance on new
installations) and adds only `busymax_summaries_v1` for summaries (default
importance). A pre-existing reminder channel is never recreated or promoted. The
new summary channel inherits its existing restrictions, sound, vibration, lights,
badge and lock-screen visibility once. It caps app-selected importance at default,
preserves explicitly user-selected importance, and conservatively preserves
importance where the OS cannot distinguish that choice. Later
choices are independent. Existing installations whose reminder channel was
originally created at default importance keep that choice; changing it belongs
to the user in system settings.

Desktop reminders require the process to run. Close-to-tray and launch-at-login
can keep that runtime available; full Quit stops delivery. Android force-stop,
OS suppression, inexact scheduling and device power policy remain system-owned.
BusyMax does not bypass Do Not Disturb or introduce another background service.
Floating/date-only schedules are recalculated before native rescheduling after
relevant local-zone changes; fixed instants and provider/custom-zone projections
retain their meaning. Lifecycle state is preserved during that recalculation.

Contract references: [Android permission](https://developer.android.com/develop/ui/compose/notifications/notification-permission),
[channels](https://developer.android.com/develop/ui/compose/notifications/channels),
[notification updates](https://developer.android.com/develop/ui/compose/notifications/create-notification),
[Windows toast permission](https://learn.microsoft.com/en-us/uwp/api/windows.ui.notifications.toastnotifier.setting?view=winrt-26100),
[Windows notification UX](https://learn.microsoft.com/en-us/windows/apps/develop/notifications/app-notifications/app-notifications-ux-guidance),
[GNOME notifications](https://developer.gnome.org/hig/patterns/feedback/notifications.html),
and [freedesktop protocol](https://specifications.freedesktop.org/notification/latest/protocol.html).
Implementation is checked against the locked `flutter_local_notifications` 22.3.0
(Windows adapter 3.1.1), `desktop_notifications` 0.6.3 and `dbus` 0.7.15 sources.

## Native acceptance driver

`tool/linux_notification_acceptance.dart` posts real production reminders from a
marked synthetic profile. Supply `BUSYMAX_NOTIFICATION_QA_PROFILE` as a Dart
define. Commands in its `commands/` directory drive event/task creation, privacy,
locale, a controlled clock advance, snapshots and Quit. Native submission/action
receipts and captures belong under ignored `build/`, never in the user profile.
This driver is a test control surface, not a notification mockup or product UI.

`tool/android_notification_acceptance.dart` requires the separate
`io.busystack.busymax.notificationqa` application ID and refuses the production
profile. It runs the real Material application, native adapter, headless runtime
and terminated-process action entry point. Its `notification-qa/commands/`
directory accepts synthetic event/task, privacy, locale, summary, permission,
account-issue and conflict commands; `events.jsonl` records results. Root-scoped
transport overrides keep synthetic accounts offline without changing the
device's network settings. Use a separate test package/manifest overlay when building this
entry point; do not change the production application ID or use a real account
profile. Keep device captures, profiles and build overlays under ignored
`build/`.

Portable native parsing and fake-backend regressions do not establish packaged
Windows forwarding, Android shade/lock-screen presentation, heads-up/sound,
terminated-process actions, or device permission recovery. Those require the
actual supported OS/package/device. Record precisely which native journeys ran
and leave unavailable journeys explicitly unvalidated.
