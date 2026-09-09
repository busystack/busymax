# Nextcloud implementation and verification record

## Reference baseline

The implementation targets the version-tagged Nextcloud Server 34.0.3 source
and Tasks 0.18.1. Server 35 development documentation was not used as the stable
contract. No live Nextcloud Server, Calendar or Tasks installation has been
exercised in this implementation environment; their **tested versions are
unrecorded, not assumed to equal the reference versions**.

Stable protocol references:

- [Webcal caching plugin, v34.0.3](https://github.com/nextcloud/server/blob/v34.0.3/apps/dav/lib/CalDAV/WebcalCaching/Plugin.php)
- [Scheduling plugin, v34.0.3](https://github.com/nextcloud/server/blob/v34.0.3/apps/dav/lib/CalDAV/Schedule/Plugin.php)
- [Deleted object permissions, v34.0.3](https://github.com/nextcloud/server/blob/v34.0.3/apps/dav/lib/CalDAV/Trashbin/DeletedCalendarObject.php)
- [Restore target, v34.0.3](https://github.com/nextcloud/server/blob/v34.0.3/apps/dav/lib/CalDAV/Trashbin/RestoreTarget.php)
- [Calendar home inventory, v34.0.3](https://github.com/nextcloud/server/blob/v34.0.3/apps/dav/lib/CalDAV/CalendarHome.php)
- [Sabre scheduling limitations](https://sabre.io/dav/scheduling/)
- [CalDAV scheduling, RFC 6638](https://www.rfc-editor.org/rfc/rfc6638.html),
  [iTIP, RFC 5546](https://www.rfc-editor.org/rfc/rfc5546.html),
  [CalDAV, RFC 4791](https://www.rfc-editor.org/rfc/rfc4791.html),
  [WebDAV sync, RFC 6578](https://www.rfc-editor.org/rfc/rfc6578.html).

## Code ownership

| Area | Main implementation |
| --- | --- |
| Effective capabilities, typed collections, contexts | `lib/src/dav/storage/dav_collection_capabilities.dart`, `lib/src/dav/discovery/` |
| Metadata, shares, publishing, trash | `lib/src/dav/nextcloud/nextcloud_{collection,sharing,trash}_service.dart` |
| Scheduling identities and raw mutations | `lib/src/dav/nextcloud/nextcloud_{scheduling_policy,scheduling_mutations,meeting_mutations}.dart` |
| Free/busy, inbox and shared state | `lib/src/dav/nextcloud/nextcloud_scheduling_{service,controller}.dart` |
| Raw import/export | `lib/src/dav/nextcloud/nextcloud_native_{import,export}.dart` |
| Offline replay and canonical refetch | `lib/src/dav/mutation/`, `lib/src/dav/sync/dav_account_sync_engine.dart` |
| Event/task projection and repositories | `lib/src/dav/storage/dav_object_repository.dart`, `lib/src/features/calendar/data/calendar_repository.dart`, existing tasks repository |
| Linux controls | `lib/src/dav/presentation/`, existing event editor, schedule workspace and sidebar |
| Windows controls | `lib/src/ui/windows/windows_nextcloud*_dialog*.dart`, event editor, schedule/task pages and source pane |
| Composition and strings | `lib/src/app/app_bootstrap.dart`, `lib/l10n/` |

No new Nextcloud database or provider stack was introduced. Delegated principal
contexts and advertised metadata use the existing DAV service/collection JSON.
Discovery and projection versions trigger reprojection of cached resources.
The workspace already contains the separate locations migration **13 → 14**;
this Nextcloud work adds no additional SQL schema migration. Existing accounts,
raw resources, pending operations and conflicts are retained.

## Automated evidence

The scheduling commit `eb3ca3c` passed 591 tests across `test/dav`, calendar
presentation, schedule, shared schedule and Windows suites, with 10 explicitly
skipped live tests. Static analysis and platform boundaries passed at that
commit. Subsequent restoration/sharing safety changes passed 24 focused
administration/native-import/native-dialog tests. Final regression results are
recorded below after the final run; an earlier pass is not proof of later edits.

Fake transport tests cover exact ETags, per-property multistatus failures,
read-only content with writable metadata, delegated discovery failure, cached
subscriptions, occurrence mutation coalescing, server scheduling canonicalization,
offline intent, recipient free/busy failures, inbox acknowledgement isolation,
native import/export and restoration of returned event/task/calendar hrefs.
They do not prove a real server's invitation delivery, federation, retention,
Calendar app rendering or Tasks recurring-completion interoperability.

For the 2026-09-09 release candidate, the complete Linux test run passed 1,940
tests with zero failures. Ten live-provider tests were explicitly skipped
because the opt-in credentials and disposable server configuration were not
present. Focused administration coverage confirms that unresolved incoming
calendar and task moves block deletion of their destination and source across
pending, retry, failed, authentication-blocked, and conflict states, without a
remote `DELETE`; unrelated accounts/collections remain removable and supported
discard permits deletion afterward.

## Live versions and result for this candidate

| Component | Actually installed/tested version | Result |
| --- | --- | --- |
| Nextcloud Server | Not available in this environment | Not run |
| Nextcloud Calendar | Not available in this environment | Not run |
| Nextcloud Tasks | Not available in this environment | Not run |

The source tags in the reference baseline are protocol references only. They
must not be reported as tested versions. This candidate is not live-provider
verified until the versioned results below are completed on the designated QA
installation.

## Release verification gates

Use disposable QA accounts and the configuration in
[live_provider_testing.md](live_provider_testing.md). Record Server, Calendar
and Tasks versions, source revision, OS, commands and results. Required live
checks remain: root/subdirectory authentication and reconnect, all owner/shared/
delegated/federated/subscription roles, permission changes while queued, actual
invitation/reply/cancellation delivery without duplicates, free/busy, repeating
task completion and subtree moves in Tasks, silent imports, and object/collection
trash restoration including collisions and retention expiry.

Run Linux and Windows native builds and desktop interaction on their respective
hosts. Linux widget tests of Fluent controls are **not** Windows build or desktop
evidence. Check keyboard navigation, small windows, light/dark/high-contrast
themes, browser launch and 100%, 125%, 150%, 200% scaling. Windows-native and
live-server verification are external release dependencies, not passed tests.
