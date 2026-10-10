import 'dart:async';
import 'dart:convert';

import 'package:busystack_contacts/google.dart';
import 'package:busystack_contacts/microsoft.dart';
import 'package:busystack_graph/busystack_graph.dart';
import 'package:busymax/src/contacts/busymax_contacts_controller.dart';
import 'package:busymax/src/contacts/busymax_contacts_store.dart';
import 'package:busymax/src/core/auth/account_token_broker.dart';
import 'package:busymax/src/core/auth/authorization_attempt.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/accounts/data/accounts_repository.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

final class ContactsFixture implements ContactsAuthorizationBroker {
  ContactsFixture(
    this.database, {
    Duration syncInterval = const Duration(days: 1),
    bool realDav = false,
  }) : accounts = AccountsRepository(database: database),
       store = BusyMaxContactsStore(database) {
    controller = BusyMaxContactsController(
      store: store,
      accounts: accounts,
      authorization: this,
      httpClient: MockClient(respond),
      readDavSecret: (id) async => davSecrets[id],
      writeDavSecret: (id, value) async {
        davSecrets[id] = value;
      },
      deleteDavSecret: (id) async {
        davSecrets.remove(id);
      },
      readLinkedDavCredential: (_) async => null,
      launchBrowser: (_) async => true,
      syncInterval: syncInterval,
      providerFactory: realDav ? null : provider,
    );
  }
  final AppDatabase database;
  final AccountsRepository accounts;
  final BusyMaxContactsStore store;
  late final BusyMaxContactsController controller;
  final davSecrets = <String, String>{};
  Future<http.Response> Function(http.Request)? respondDav;
  Object? authorizationFailure;
  bool offline = false;
  bool googleOffline = false;
  String? consentSubject, consentScopes;
  Completer<void>? consentPause;
  Future<void> addParent(BusyProvider provider) =>
      accounts.upsertSignedInAccount(
        id: provider.name,
        provider: provider,
        providerAccountId: 'owner',
        displayName: 'Fixture ${provider.name}',
        grantedScopes: provider == BusyProvider.google
            ? 'calendar tasks'
            : 'Calendars.ReadWrite Tasks.ReadWrite',
      );
  @override
  Future<void> authorizeContacts(
    BusyProvider provider,
    String accountId, {
    required bool writable,
    AuthorizationCancellation? cancellation,
    Future<void> Function()? persistContacts,
  }) async {
    if (consentPause != null) {
      await Future.any<void>([
        consentPause!.future,
        if (cancellation != null)
          cancellation.signal.then(
            (_) => throw const ContactsException(
              ContactsFailure.cancelled,
              'consent-cancelled',
            ),
          ),
      ]);
    }
    if (cancellation?.isCancelled == true) {
      throw const ContactsException(
        ContactsFailure.cancelled,
        'consent-cancelled',
      );
    }
    if (authorizationFailure != null) throw authorizationFailure!;
    final previous = await accounts.accountById(accountId);
    final contactScope = provider == BusyProvider.google
        ? writable
              ? 'https://www.googleapis.com/auth/contacts'
              : 'https://www.googleapis.com/auth/contacts.readonly'
        : writable
        ? 'Contacts.ReadWrite'
        : 'Contacts.Read';
    await database.transaction(() async {
      await accounts.upsertSignedInAccount(
        id: accountId,
        provider: provider,
        providerAccountId: consentSubject ?? 'owner',
        displayName: previous!.displayName,
        grantedScopes:
            consentScopes ?? '${previous.grantedScopes} $contactScope',
      );
      await persistContacts?.call();
    });
  }

  @override
  Future<String> contactsAuthorizationHeader(
    BusyProvider provider,
    String accountId, {
    required bool writable,
    String? claims,
  }) async => 'Bearer fixture';

  ContactsProvider provider(ContactAccount account) =>
      account.provider == ContactProviderKind.google
      ? GoogleContactsProvider(
          accountId: account.id,
          grantedScopes: account.grantedScopes,
          authorizedClient: MockClient(respond),
        )
      : MicrosoftContactsProvider(
          accountId: account.id,
          grantedScopes: account.grantedScopes,
          personalAccount: true,
          graph: GraphClient(
            httpClient: MockClient(respond),
            tokenProvider: ({claims}) async => GraphAuthorization(
              'fixture',
              grantedScopes: account.grantedScopes,
            ),
          ),
        );
  Future<http.Response> respond(http.Request request) async {
    if (offline ||
        googleOffline && request.url.host == 'people.googleapis.com') {
      throw http.ClientException('fixture offline');
    }
    if (request.url.host == 'people.googleapis.com') {
      return http.Response(
        jsonEncode({
          'connections': [
            {
              'resourceName': 'people/ada',
              'metadata': {
                'sources': [
                  {'type': 'CONTACT', 'id': 'ada', 'etag': 'one'},
                ],
              },
              'names': [
                {'displayName': 'Ada Fixture'},
              ],
              'emailAddresses': [
                {'value': 'ada@example.test', 'type': 'work'},
              ],
            },
          ],
          'nextSyncToken': 'complete',
          'contactGroups': [],
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    if (request.url.host != 'graph.microsoft.com' && respondDav != null) {
      return respondDav!(request);
    }
    final contact = {
      'id': 'ada',
      'changeKey': 'one',
      'displayName': 'Ada Fixture',
      'emailAddresses': [
        {'address': 'ada@example.test', 'name': 'Ada'},
      ],
    };
    return http.Response(
      jsonEncode(
        request.url.path.endsWith('/ada')
            ? contact
            : {
                'value': request.url.path.contains('contactFolders')
                    ? []
                    : [contact],
              },
      ),
      200,
    );
  }

  Future<void> close() async {
    await controller.close();
    await database.close();
  }
}
