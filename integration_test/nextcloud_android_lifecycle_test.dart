// Run twice on a disposable Android app profile with the same QA define file.
// Force-stop the package between runs. Only the test-created accounts are used;
// transport, persistence, Android gates and WorkManager remain production code.
// This functional probe cleans jobs between phases. Retained-work startup
// acceptance is separate: android_retained_startup_test.dart.
import 'dart:convert';
import 'dart:io';

import 'package:busymax/l10n/generated/app_localizations.dart';
import 'package:busymax/src/android/android_app.dart';
import 'package:busymax/src/android/android_background.dart';
import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/core/secrets/secret_store.dart';
import 'package:busymax/src/core/http/request_dispatch_exception.dart';
import 'package:busymax/src/dav/dav_provider_profile.dart';
import 'package:busymax/src/dav/discovery/dav_discovery_repository.dart';
import 'package:busymax/src/dav/discovery/dav_discovery_service.dart';
import 'package:busymax/src/dav/http/dav_http_transport.dart';
import 'package:busymax/src/dav/ical/ical_document.dart';
import 'package:busymax/src/dav/nextcloud/nextcloud_native_import.dart';
import 'package:busymax/src/dav/trust/nextcloud_certificate.dart';
import 'package:busymax/src/dav/trust/nextcloud_trust_policy.dart';
import 'package:busymax/src/features/accounts/data/accounts_repository.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:workmanager/workmanager.dart';
import 'package:busymax_android_platform/busymax_android_platform.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const encoded = String.fromEnvironment('BUSYMAX_NEXTCLOUD_ANDROID_QA');
  testWidgets('native Nextcloud background synchronization and process recovery', (
    tester,
  ) async {
    expect(Platform.isAndroid, isTrue);
    final config = jsonDecode(utf8.decode(base64Decode(encoded))) as Map;
    final accounts = (config['accounts'] as List).cast<Map>();
    final phase = File(
      '${(await getApplicationSupportDirectory()).path}/nextcloud-qa-${config['runId']}.json',
    );
    final prepared = await phase.exists();
    final runtime = await AndroidHeadlessRuntime.create();
    final container = runtime.container;
    final database = runtime.database;
    final persistence = container.read(authorizationPersistenceProvider);
    final secrets = container.read(secretStoreProvider);
    final clients = container.read(nextcloudHttpClientFactoryProvider);
    final controlClient = http.Client();
    Future<Map> control(
      Map account,
      String action, [
      String? certificate,
    ]) async {
      final uri = Uri.parse(account['control'] as String).replace(
        path: '/$action',
        queryParameters: {
          'nonce': account['nonce'] as String,
          if (certificate != null) 'certificate': certificate,
        },
      );
      final response = await controlClient.get(uri);
      expect(response.statusCode, 200);
      return jsonDecode(response.body) as Map;
    }

    NextcloudTrustPolicy approve(Map account, String material) =>
        NextcloudTrustPolicy.approve(
          owner: account['id'] as String,
          installation: Uri.parse(account['authority'] as String),
          mode: account['mode'] == 'private_ca'
              ? NextcloudTrustMode.privateCa
              : NextcloudTrustMode.pinnedLeaf,
          certificates: NextcloudCertificate.import(
            utf8.encode(account[material] as String),
          ),
          generation: 'native-${DateTime.now().microsecondsSinceEpoch}',
        );
    Future<String?> success(Map account) async =>
        (await (database.select(database.accounts)
                  ..where((row) => row.id.equals(account['id'] as String)))
                .getSingle())
            .lastSuccessfulSyncAtUtc;
    Future<void> until(Future<bool> Function() condition) async {
      final deadline = DateTime.now().add(const Duration(seconds: 45));
      while (!await condition()) {
        if (DateTime.now().isAfter(deadline)) {
          fail('Native background worker did not reach its durable outcome.');
        }
        await tester.pump(const Duration(milliseconds: 200));
      }
    }

    Future<void> background(List<Map> expected) async {
      final before = {for (final a in expected) a['id']: await success(a)};
      var completed = false;
      final subscription = BusyMaxAndroidPlatform.instance.events.listen((
        event,
      ) {
        if (event.type == 'dataChanged') completed = true;
      });
      try {
        await enqueueImmediateBusyMaxSync();
        // Observe the production cross-engine completion event. Reading the
        // SQLite file while a worker opens/commits it bypasses that protocol.
        await until(() async => completed);
      } finally {
        await subscription.cancel();
      }
      for (final a in expected) {
        expect(await success(a), isNot(before[a['id']]));
      }
    }

    var appMounted = false;
    Future<void> management(String mode) async {
      if (!appMounted) {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const AndroidBusyMaxApp(),
          ),
        );
        appMounted = true;
        await tester.pumpAndSettle();
      }
      final settings = find.byIcon(Icons.settings_outlined);
      if (settings.evaluate().isNotEmpty) {
        await tester.tap(settings);
        await tester.pumpAndSettle();
      }
      final row = find.byWidgetPredicate(
        (widget) =>
            widget is ListTile &&
            widget.title is Text &&
            widget.subtitle is Text &&
            (widget.title! as Text).data == 'Private server certificates' &&
            (widget.subtitle! as Text).data == 'Certificate QA $mode',
      );
      await tester.scrollUntilVisible(
        row,
        350,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 50,
      );
      await tester.pumpAndSettle();
      expect(row, findsOneWidget);
      await tester.tap(row);
      await until(
        () async => find.byType(SelectableText).evaluate().isNotEmpty,
      );
      await tester.pumpAndSettle();
      expect(find.byType(SelectableText), findsWidgets);
    }

    Object? primaryFailure;
    try {
      await configureBusyMaxWorkmanager();
      if (!prepared) {
        final existing = await database.select(database.accounts).get();
        if (existing.isNotEmpty) {
          // Resume only this exact QA account set after an OS-deferred wake.
          expect(
            existing.map((r) => r.id),
            unorderedEquals(accounts.map((a) => a['id'])),
          );
          for (final a in accounts) {
            final saved = await secrets.readCredential(
              a['id'] as String,
            ) as NextcloudSecretRecord;
            expect(saved.trustPolicy!.owner, a['id']);
            expect(
              saved.trustPolicy!.installation,
              Uri.parse(a['authority'] as String),
            );
            expect(
              saved.trustPolicy!.certificates.map((c) => c.fingerprint),
              NextcloudCertificate.import(
                utf8.encode(a['certificate'] as String),
              ).map((c) => c.fingerprint),
            );
          }
        }
        for (final a in existing.isEmpty ? accounts : <Map>[]) {
          final id = a['id'] as String;
          final authority = Uri.parse(a['authority'] as String);
          final record = NextcloudSecretRecord(
            canonicalServer: authority,
            loginName: a['username'] as String,
            appPassword: a['password'] as String,
            trustPolicy: approve(a, 'certificate'),
          );
          final client = clients.create(
            owner: id,
            authority: authority,
            policy: record.trustPolicy,
          );
          final profile = davProviderProfile(
            BusyProvider.nextcloud,
            nextcloudServer: authority,
          );
          try {
            final discovery = await DavDiscoveryService(
              transport: DavHttpTransport(
                client: client,
                profile: profile,
                accountAuthority: authority,
              ),
              profile: profile,
              accountAuthority: authority,
              accountId: id,
              credential: DavBasicCredential(
                username: record.loginName,
                password: record.appPassword,
              ),
            ).discover(correlationId: 'native-android-enrollment');
            await persistence.commit(
              accountId: id,
              expectedGeneration: 0,
              candidate: record,
              persistAccount: () async {
                await AccountsRepository(database: database)
                    .upsertSignedInAccount(
                      id: id,
                      provider: BusyProvider.nextcloud,
                      providerAccountId: record.loginName,
                      authority: authority.toString(),
                      credentialKind: record.kind,
                      displayName: 'Certificate QA ${a['mode']}',
                      grantedScopes: '',
                    );
                await DavDiscoveryRepository(database: database)
                    .commitSuccessfulInventory(discovery);
              },
            );
          } finally {
            client.close();
          }
        }
        await container.read(allAccountsSyncRunnerProvider)();
        await background(accounts);
      } else {
        expect(jsonDecode(await phase.readAsString())['pid'], isNot(pid));
        final ca = accounts.singleWhere((a) => a['mode'] == 'private_ca');
        final pin = accounts.singleWhere((a) => a['mode'] == 'pinned_leaf');
        final current = await secrets.readCredential(
          pin['id'] as String,
        ) as NextcloudSecretRecord;
        final originalFingerprint = NextcloudCertificate.import(
          utf8.encode(pin['certificate'] as String),
        ).single.fingerprint;
        final replacementFingerprint = NextcloudCertificate.import(
          utf8.encode(pin['replacement'] as String),
        ).single.fingerprint;
        final acceptedFingerprint =
            current.trustPolicy!.certificates.single.fingerprint;
        expect(
          acceptedFingerprint,
          anyOf(originalFingerprint, replacementFingerprint),
        );
        final originalAccepted = acceptedFingerprint == originalFingerprint;
        final targetCertificate = originalAccepted ? 'self-renewed' : 'self';
        final targetMaterial =
            pin[originalAccepted ? 'replacement' : 'certificate'] as String;
        // Restore the fixture's server to the exact already accepted identity,
        // then deliberately present the other leaf. Never change client trust
        // just to restart a probe interrupted during its replacement phase.
        await control(
          pin,
          'change',
          originalAccepted ? 'self' : 'self-renewed',
        );
        await control(ca, 'change', 'leaf');
        for (final a in accounts) {
          final saved = await secrets.readCredential(
            a['id'] as String,
          ) as NextcloudSecretRecord;
          expect(
            saved.trustPolicy!.mode.name,
            a['mode'] == 'private_ca' ? 'privateCa' : 'pinnedLeaf',
          );
          await container
              .read(davAccountOnboardingServiceProvider)
              .revalidateAccount(a['id'] as String);
        }
        await background(accounts);
        await control(ca, 'change', 'renewed');
        await background(accounts);
        final before = (await control(pin, 'counts'))['appRequests'];
        await control(pin, 'change', targetCertificate);
        final target =
            (await (database.select(
                  database.davCollections,
                )..where((r) => r.accountId.equals(pin['id'] as String))).get())
                .firstWhere(
                  (r) =>
                      !r.readOnly &&
                      !r.deleted &&
                      !r.serverMissing &&
                      r.eventProjectionEnabled &&
                      r.supportedComponentMask & 1 != 0,
                );
        final imported = await NextcloudNativeImportService(database).import(
          accountId: pin['id'] as String,
          collectionId: target.id,
          preview: NextcloudNativeImportPreview.parse(
            IcalDocument.parse(
              'BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//BusyMax QA//EN\r\nBEGIN:VEVENT\r\nUID:native-${config['runId']}-${DateTime.now().microsecondsSinceEpoch}@example.invalid\r\nDTSTAMP:20261031T000000Z\r\nDTSTART:20261101T120000Z\r\nDTEND:20261101T130000Z\r\nSUMMARY:Disposable native certificate QA\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n',
            ),
          ),
        );
        expect(imported.single.status, NativeImportItemStatus.queued);
        final cached = await database.select(database.davObjects).get();
        final pending = await database.select(database.pendingOps).get();
        expect(pending, isNotEmpty);
        await background([ca]);
        final certificateState = await (database.select(
          database.davAccountServices,
        )..where((r) => r.accountId.equals(pin['id'] as String))).getSingle();
        expect(
          certificateState.lastDiscoveryErrorCode,
          'NextcloudCertificatepinMismatch',
        );
        expect((await control(pin, 'counts'))['appRequests'], before);
        expect(
          (await database.select(database.davObjects).get()).map((r) => r.id),
          cached.map((r) => r.id),
        );
        expect(
          (await database.select(database.pendingOps).get()).map((r) => r.id),
          pending.map((r) => r.id),
        );
        await background([ca]);
        expect((await control(pin, 'counts'))['appRequests'], before);
        final pinId = pin['id'] as String;
        final oldGeneration = await persistence.generation(pinId);
        final old =
            await secrets.readCredential(pinId) as NextcloudSecretRecord;
        final nextFingerprint = NextcloudCertificate.import(
          utf8.encode(targetMaterial),
        ).single.fingerprint;
        for (var attempt = 0; attempt < 2; attempt++) {
          await management('pinned_leaf');
          final l10n = AppLocalizations.of(
            tester.element(find.byType(SelectableText).first),
          );
          expect(
            find.textContaining(
              old.trustPolicy!.certificates.single.fingerprint,
            ),
            findsWidgets,
          );
          await tester.tap(find.text(l10n.certificateReplacePin));
          await until(
            () async =>
                find.text(l10n.certificateApprove).evaluate().isNotEmpty,
          );
          await tester.pumpAndSettle();
          expect(find.textContaining(nextFingerprint), findsWidgets);
          await tester.tap(
            find.text(
              attempt == 0 ? l10n.certificateReject : l10n.certificateApprove,
            ),
          );
          await tester.pumpAndSettle();
          if (attempt == 0) {
            expect(await persistence.generation(pinId), oldGeneration);
            expect((await control(pin, 'counts'))['appRequests'], before);
          }
        }
        await until(
          () async => await persistence.generation(pinId) > oldGeneration,
        );
        expect(
          (await secrets.readCredential(pinId) as NextcloudSecretRecord)
              .trustPolicy!
              .certificates
              .single
              .fingerprint,
          nextFingerprint,
        );
        await background(accounts);
        expect(await database.select(database.pendingOps).get(), isEmpty);
        final secret = await secrets.readCredential(pin['id'] as String);
        await control(pin, 'offline');
        await background([ca]);
        final networkState = await (database.select(
          database.davAccountServices,
        )..where((r) => r.accountId.equals(pin['id'] as String))).getSingle();
        expect(networkState.lastDiscoveryErrorCode, isNotNull);
        expect(
          networkState.lastDiscoveryErrorCode,
          isNot(startsWith('NextcloudCertificate')),
        );
        await background([ca]);
        expect(await secrets.readCredential(pin['id'] as String), isNotNull);
        await control(pin, 'online');
        await container.read(allAccountsSyncRunnerProvider)();
        expect(
          (await secrets.readCredential(pin['id'] as String))!.kind,
          secret!.kind,
        );
      }
      await management('private_ca');
      final l10n = AppLocalizations.of(
        tester.element(find.byType(SelectableText).first),
      );
      await tester.tap(find.text(l10n.certificateReject));
      await tester.pumpAndSettle();
      if (prepared) {
        for (final a in accounts) {
          final captured = await secrets.readCredential(
            a['id'] as String,
          ) as NextcloudSecretRecord;
          final removed = await container
              .read(davAccountOnboardingServiceProvider)
              .removeAccount(a['id'] as String);
          expect(removed.remoteRevocationSucceeded, isTrue);
          expect(await secrets.readCredential(a['id'] as String), isNull);
          final probe = clients.create(
            owner: a['id'] as String,
            authority: captured.canonicalServer,
            policy: captured.trustPolicy,
          );
          try {
            expect(
              (await probe.get(
                captured.canonicalServer.resolve('/remote.php/dav/'),
                headers: {
                  'authorization':
                      'Basic ${base64Encode(utf8.encode('${captured.loginName}:${captured.appPassword}'))}',
                },
              )).statusCode,
              401,
            );
          } finally {
            probe.close();
          }
        }
        expect(await database.select(database.accounts).get(), isEmpty);
        expect(
          await database.select(database.authorizationCommits).get(),
          isEmpty,
        );
      }
      if (!prepared) {
        await phase.writeAsString(jsonEncode({'pid': pid}), flush: true);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    } catch (error) {
      primaryFailure = error;
      rethrow;
    } finally {
      await Workmanager().cancelAll();
      if (appMounted) {
        await tester.pumpWidget(const SizedBox.shrink());
        // The app starts an asynchronous foreground refresh. Drain that same
        // account/notification work before closing its database in this probe.
        try {
          await container.read(allAccountsSyncRunnerProvider)();
        } on AuthorizationScopedFailure {
          // A failed assertion may deliberately leave a changed pin paused.
          // Preserve that primary test failure while draining the UI refresh.
          if (primaryFailure == null) rethrow;
        }
        await runtime.notifications.synchronize(() async {});
        await container
            .read(operationalNotificationCoordinatorProvider)
            .reconcile();
        await runtime.notifications.synchronize(() async {});
      }
      controlClient.close();
      await runtime.dispose();
    }
  }, skip: encoded.isEmpty);
}
