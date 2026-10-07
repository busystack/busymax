import 'package:busymax/src/dav/discovery/dav_discovery_models.dart';
import 'package:busymax/src/dav/discovery/dav_discovery_repository.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:busymax/src/providers/provider_capabilities.dart';
import 'package:drift/drift.dart';

/// Persists controlled discovery inventories through the production repository.
class DavTaskInventoryFixture {
  DavTaskInventoryFixture(this.database) {
    discovery = DavDiscoveryRepository(
      database: database,
      idFactory: () => 'collection-${++_nextId}',
    );
  }

  final AppDatabase database;
  late final DavDiscoveryRepository discovery;
  var _nextId = 0;
  static const accountId = 'nextcloud:account';
  static const timestamp = '2026-10-04T00:00:00Z';

  Future<void> seedAccount({String id = accountId}) => database
      .into(database.accounts)
      .insert(
        AccountsCompanion.insert(
          id: id,
          provider: 'nextcloud',
          authority: 'https://cloud.example.test/',
          providerAccountId: id,
          credentialKind: 'nextcloud_app_password',
          authState: const Value('signed_in'),
          createdAtUtc: timestamp,
          updatedAtUtc: timestamp,
        ),
      );

  Future<void> commit({
    required bool writable,
    String account = accountId,
    bool missing = false,
  }) async {
    final principal = Uri.parse(
      'https://cloud.example.test/principals/fixture/',
    );
    final home = Uri.parse('https://cloud.example.test/calendars/fixture/');
    final privileges = <String>{'{DAV:}read', if (writable) '{DAV:}write'};
    await discovery.commitSuccessfulInventory(
      DavDiscoveryResult(
        accountId: account,
        provider: BusyProvider.nextcloud,
        service: DavServiceDiscovery(
          canonicalServiceUri: Uri.parse('https://cloud.example.test/'),
          canonicalOrigin: Uri.parse('https://cloud.example.test'),
          principalHref: principal,
          calendarHomeHref: home,
          calendarUserAddresses: const [],
          scheduleInboxHref: null,
          scheduleOutboxHref: null,
          capabilities: AccountServiceCapabilities(
            hasPrincipal: true,
            hasCalendarHome: true,
          ),
          discoveredAtUtc: DateTime.parse(timestamp),
          lastValidatedAtUtc: DateTime.parse(timestamp),
          providerProfileVersion: 1,
        ),
        collections: [
          if (!missing)
            DavCollectionDiscovery(
              hrefKey: '${home.path}tasks/',
              requestUri: home.resolve('tasks/'),
              displayName: 'DAV tasks',
              description: null,
              resourceTypes: const {
                '{DAV:}collection',
                '{urn:ietf:params:xml:ns:caldav}calendar',
              },
              supportedComponentMask: davComponentTodo,
              supportedCalendarData: const [
                {'contentType': 'text/calendar', 'version': '2.0'},
              ],
              supportedReports: const {},
              currentUserPrivileges: privileges,
              ownerHref: principal.toString(),
              safeDisplayMetadata: const {},
              color: null,
              sortOrder: null,
              calendarTimeZone: null,
              calendarTimeZoneId: null,
              scheduleTransparency: null,
              maximumResourceSize: null,
              maximumInstances: null,
              syncToken: null,
              ctag: null,
              capabilities: CollectionCapabilities(
                canRead: true,
                canWriteContent: writable,
                canWriteProperties: writable,
                canAddMembers: writable,
                canDeleteMembers: writable,
                supportsTasks: true,
              ),
              kind: writable
                  ? DavCollectionKind.writableTaskList
                  : DavCollectionKind.readOnlyTaskList,
              eventProjectionEnabled: false,
              taskProjectionEnabled: true,
            ),
        ],
      ),
    );
  }
}
