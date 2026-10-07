# Synchronization policy and request cost

Periodic account wakeups remain at 15 minutes, including Android WorkManager.
Eligibility is persisted separately for each account and Tasks/Calendar domain,
and checked inside AccountSyncCoordinator and the cross-engine account gate.

Tasks passive pulls run after one hour plus one sampled 0–10% jitter. Calendar
passive pulls run after 15 minutes plus the same bounded jitter. Foreground/resume
pulls domains whose last successful pull is at least 15 minutes old. Manual
refresh promptly requests each enabled domain without resetting incremental
cursors. A local mutation dispatches that domain's due durable writes and cached
reminder maintenance without forcing a collection poll or advancing pull state.
Provider cooldowns override all triggers, including manual/full refresh. Deferred
remote work still maintains reminders from cached eligible data.

The hourly Tasks policy is an explicit freshness tradeoff: Tasks become eligible
60–66 minutes after a successful pull. A 15-minute scheduler can add up to
another 15 minutes before consuming that window; operating-system deferral,
offline periods and provider cooldowns can add further delay. Calendar becomes
eligible after 15–16.5 minutes and has the same wakeup granularity. Opening or
resuming the app checks 15-minute freshness, and local edits dispatch immediately.
Calendar keeps its established incremental cursor/recovery behavior.

## Request costs

A quiet Tasks pull costs `collection-list pages + sum(task pages per collection)`.
`updatedMin` reduces response contents; it does not eliminate requests to each
collection. The two-minute Tasks checkpoint overlap, pagination, pending-edit
protections, deletion reconciliation and explicit full-sync behavior are retained.
Simultaneous background/foreground requests under the account gate consume one
freshness window. Restart retains eligibility; overdue wakes never resample jitter.
Clock reversal permits stale pulls, while explicit provider cooldowns remain held.
A Tasks quota failure is reported as a partial account failure and Calendar still
runs; cached reminders continue while Tasks is deferred.

The [domain scheduling tests](../test/features/sync/domain_sync_schedule_test.dart)
exercise request counts, freshness checkpoints, and durable replay with synthetic
workloads. They do not measure production quota usage.

## Provider quotas

Actual [Google Tasks limits](https://developers.google.com/workspace/tasks/limits)
depend on the project; quota adjustments require provider approval. Android's
native Google registration uses a shared project, whose capacity also depends
on manual pulls, foreground activity, pagination, writes, retries, and other
project usage. Hourly scheduling alone does not resolve shared-project limits.

Collect production evidence before requesting an adjustment: actual project
quota, active Android account count, enabled collections/pages, quiet versus
changed pulls, foreground/manual frequency, local writes, retry/cooldown counts,
and simultaneous WorkManager/foreground behavior. Do not include account contents,
OAuth configurations, access/refresh tokens or signing private keys. Separate
Tasks from Calendar's project and per-user/project limits; see
[Calendar quota guidance](https://developers.google.com/workspace/calendar/api/guides/quota).
Two OAuth clients inside one project do not demonstrate project-quota isolation.
