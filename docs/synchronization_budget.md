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

Generic CalDAV uses the existing DAV account gate and engine. Discovery and
complete collection inventory precede baseline changes. RFC 6578
sync-collection is used when advertised, with ETag inventory/multiget fallback
otherwise. Invalid tokens cause a safe rebaseline; interrupted or incomplete
results retain committed objects and cursors. An unsuccessful inventory never
establishes remote deletion. Offline mutations keep exact remote resource
identity and ETags, and uncertain committed writes are read back before replay.
Permission or authorization failures retain queued work and cached content.
After a complete authenticated discovery, a permission-blocked intent can resume
only when newly advertised privileges explicitly authorize every required
operation and collection. Unknown ACLs never clear a previous authoritative
denial, and this path cannot clear an authentication block. Sync reports use
HTTP Depth: 0 with sync-level 1. Bounded pages and collection-level 507 continue
through opaque tokens; the complete inventory alone advances the stable baseline.
Account removal and credential replacement share the authorization lease and
generation checks with active requests. See the [CalDAV qualification record](caldav_qualification.md)
for measured live recovery scenarios; this policy is not itself runtime evidence.

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

## Explicit refresh scopes and completion

Refresh calendar and Refresh list use the account and local collection identity.
For Google and Microsoft calendars, the engine uses the stored source's
provider identity and its normal baseline cursor or snapshot. Calendar
inventory discovery stays in the account-wide path. The displayed schedule can
independently request month snapshots using separate source/month cursors. The
coverage control retries the current range and filters without waiting for the
repository's automatic failure throttle. It joins an in-flight check and can
reuse fresh, verified months. Cached items remain visible during the check.

A selected task list uses an authoritative, paginated snapshot. List metadata
can exist without a task baseline, and the Google Tasks domain checkpoint is
shared by all lists. Targeted reads leave that checkpoint and the passive
schedule untouched. Only a completed authoritative list snapshot reconciles
missing tasks. Checklists are retrieved through the existing Microsoft client.

DAV sync uses one remote collection and one cursor per physical collection.
Selecting either projection of a mixed VEVENT/VTODO collection pulls that
collection once and updates both projections where enabled. Required discovery
continues to commit complete account inventory. Due writes are selected from the
durable queues, including moves that touch the target and required predecessors.
A dependency that cannot run remains queued. DAV readback also checks
collections changed by a successful mutation. The readable Nextcloud scheduling
inbox remains available for scheduling-related checks.

Explicit subscription refresh bypasses ordinary due time and local failure
backoff. It keeps validators bound to their origin, and a valid HTTP 304 counts
as a successful check. A skipped check or missing credential has a separate
outcome. Full recovery rebaselines supported Calendar, Tasks and DAV content and
checks subscriptions using their regular HTTP validation.

Requested scope, origin and recovery strategy are independent. The same
in-process request joins while it is queued or executing. A different source,
origin or strategy retains its own completion future and shares the same
account and cross-engine locks. Account-wide completion is stored in the
synchronization schedule table under an independent history key. Historical
provider account fields are excluded from this value. Disabled domains are
excluded from the required scope, and deferred work cannot record account-wide
success. A narrow task import preserves a prior incomplete account import
marker until a covering import succeeds. Successful downloads, unresolved
failures and pending writes have distinct presentation state.

Android publishes executing scopes through the existing platform channel.
The native plugin owns each engine's activity in memory and drops it on detach
or worker cleanup. The visible engine reconciles that snapshot and invalidates
external database state on resume.
