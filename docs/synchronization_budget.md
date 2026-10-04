# Synchronization policy and request-budget evidence

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
Calendar keeps its established incremental cursor/recovery behavior. User-owned
desktop projects still need this efficiency.

## Deterministic measurements

`test/features/sync/domain_sync_schedule_test.dart` counts actual HTTP requests
through GoogleTasksRestApiClient and SyncEngine, including checkpoints and durable
replay. These are reproducible synthetic workloads, not live quota telemetry.

| Workload | One eligible Tasks pull | Three intervening 15-minute wakes | Next eligible pull | Manual refresh |
|---|---:|---:|---:|---:|
| Quiet, 1 collection, one page each | 2 | 0 | 2 | 2 |
| Quiet, 5 collections, one page each | 6 | 0 | 6 | 6 |
| Quiet, 20 collections, one page each | 21 | 0 | 21 | 21 |
| Changed, 2 collection pages and 2 task pages | 4 | 0 when ineligible | 4 for that page pattern | preserves incremental overlap |
| One local task creation after a recent pull | 1 POST | no collection poll | independent of passive eligibility | durable replay remains responsible |

A quiet Tasks pull costs `collection-list pages + sum(task pages per collection)`.
`updatedMin` reduces response contents; it does not eliminate requests to each
collection. The two-minute Tasks checkpoint overlap, pagination, pending-edit
protections, deletion reconciliation and explicit full-sync behavior are retained.
Simultaneous background/foreground requests under the account gate consume one
freshness window. Restart retains eligibility; overdue wakes never resample jitter.
Clock reversal permits stale pulls, while explicit provider cooldowns remain held.
A Tasks quota failure is reported as a partial account failure and Calendar still
runs; cached reminders continue while Tasks is deferred.

## Android shared Google project quota request preparation

[Google Tasks limits](https://developers.google.com/workspace/tasks/limits) describes
a 50,000-query/day courtesy limit, notes that actual project limits vary, and permits
quota adjustment requests without guaranteeing approval. No quota change or
approval is claimed here. Google's native Android registration remains a shared
project dependency and must not be deleted with the desktop client.

For continuously enabled quiet background accounts, an upper bound without
jitter is 24 eligible pulls/day rather than 96 scheduler wakes/day. The measured
1/5/20-collection workloads therefore cost at most 48/144/504 Tasks reads per
account/day, compared with 192/576/2,016 at every 15-minute wake. At 50,000 queries,
the arithmetic ceilings are 1,041/347/99 such accounts before manual pulls,
foreground activity, pagination, writes, retries and other project usage. These
are budget estimates, not supported user counts. Hourly scheduling alone does not
resolve a shared project's scaling limits.

Collect production evidence before requesting an adjustment: actual project
quota, active Android account count, enabled collections/pages, quiet versus
changed pulls, foreground/manual frequency, local writes, retry/cooldown counts,
and simultaneous WorkManager/foreground behavior. Do not include account contents,
OAuth configurations, access/refresh tokens or signing private keys. Separate
Tasks from Calendar's project and per-user/project limits; see
[Calendar quota guidance](https://developers.google.com/workspace/calendar/api/guides/quota).
Two OAuth clients inside one project do not demonstrate project-quota isolation.
