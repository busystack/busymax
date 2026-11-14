// Drives the normal Android application. No transport, certificate, credential,
// database, settings or native-storage providers are overridden.
import 'dart:convert';

import 'package:busymax/src/android/android_app.dart';
import 'package:busymax/src/android/android_background.dart';
import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/core/secrets/secret_store.dart';
import 'package:busymax/src/dav/trust/nextcloud_trust_policy.dart';
import 'package:busymax/src/ui/common/nextcloud_certificate_review.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

Future<void> until(
  WidgetTester tester,
  Future<bool> Function() ready,
  String stage,
) async {
  final end = DateTime.now().add(const Duration(seconds: 20));
  while (true) {
    if (await tester.runAsync(ready) == true) return;
    if (DateTime.now().isAfter(end)) {
      debugPrint('PRIVATE_CERT_TIMEOUT $stage');
      debugPrint(
        find
            .byType(Text)
            .evaluate()
            .map((e) => (e.widget as Text).data)
            .toList()
            .toString(),
      );
      fail(stage);
    }
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'normal Android CalDAV private certificate onboarding and secure persistence',
    (tester) async {
      expect(
        (await tester.runAsync(PackageInfo.fromPlatform))!.packageName,
        'io.busystack.busymax.caldavqa',
      );
      final runtime = (await tester.runAsync(AndroidHeadlessRuntime.create))!;
      await tester.runAsync(configureBusyMaxWorkmanager);
      final c = runtime.container;
      tester.testTextInput.register();
      addTearDown(tester.testTextInput.unregister);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: const AndroidBusyMaxApp(),
        ),
      );
      final config = jsonDecode(
        utf8.decode(
          base64Decode(
            const String.fromEnvironment('BUSYMAX_CALDAV_NATIVE_FIXTURE'),
          ),
        ),
      ) as Map;
      final entries = {
        'Radicale 3.9.0': 'https://localhost:25443/',
        'Baikal 0.13.0': 'https://localhost:25444/dav.php/',
        'BusyStack 0.2.0': 'https://localhost:22448/dav/',
      };
      Future<void> tap(String text) async {
        final matches = find.text(text);
        final finder = matches.last;
        await until(tester, () async => matches.evaluate().isNotEmpty, text);
        await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
        await tester.pump();
        await tester.tap(finder);
        await tester.pump(const Duration(milliseconds: 200));
      }

      await tap('Settings');
      final initial = (await tester.runAsync(
        () => runtime.database.select(runtime.database.accounts).get(),
      ))!;
      // A rerun first proves normal removal and secure cleanup of this run's
      // accounts. Never clear app data or inject a replacement database.
      for (final account in initial) {
        final countBefore = (await tester.runAsync(
          () => runtime.database.select(runtime.database.accounts).get(),
        ))!.length;
        expect(entries.values, contains(account.authority));
        expect(account.providerAccountId, 'bob');
        final menus = find.byType(PopupMenuButton<String>);
        await until(
          tester,
          () async => menus.evaluate().isNotEmpty,
          'owned account menu',
        );
        await Scrollable.ensureVisible(
          tester.element(menus.first),
          alignment: 0.5,
        );
        await tester.pump();
        await tester.tap(menus.first);
        await tap('Remove account…');
        await tap('Remove account');
        await until(
          tester,
          () async =>
              (await runtime.database.select(runtime.database.accounts).get())
                  .length ==
              countBefore - 1,
          'normal account removal',
        );
      }
      expect(
        (await tester.runAsync(
          () => runtime.database.select(runtime.database.accounts).get(),
        ))!,
        isEmpty,
      );
      for (final account in initial) {
        expect(
          await tester.runAsync(
            () => c
                .read(authorizationPersistenceProvider)
                .readCurrentCredential(account.id),
          ),
          isNull,
        );
      }
      for (final entry in entries.entries) {
        final before = (await tester.runAsync(
          () => runtime.database.select(runtime.database.accounts).get(),
        ))!.length;
        final credentials =
            config[entry.key.startsWith('BusyStack')
                    ? 'busystackCredentials'
                    : 'credentials']
                as Map;
        Future<void> wizard() async {
          await tap('Add CalDAV account');
          await until(
            tester,
            () async => find
                .byKey(const Key('caldav-password-field'))
                .evaluate()
                .isNotEmpty,
            'credential wizard',
          );
          await tester.enterText(
            find.byKey(const Key('caldav-server-field')),
            entry.value,
          );
          await tester.enterText(
            find.byKey(const Key('caldav-username-field')),
            'bob',
          );
          await tester.enterText(
            find.byKey(const Key('caldav-password-field')),
            credentials['bob'] as String,
          );
          await tap('Connect');
          await until(
            tester,
            () async => find
                .byType(NextcloudCertificateReviewContent)
                .evaluate()
                .isNotEmpty,
            'real TLS challenge',
          );
          final review = tester.widget<NextcloudCertificateReviewContent>(
            find.byType(NextcloudCertificateReviewContent),
          );
          expect(review.data.endpoint, Uri.parse(entry.value));
          expect(review.data.certificates, isNotEmpty);
          debugPrint(
            'PRIVATE_CERT_OBSERVED ${entry.key} ${review.data.certificates.single.fingerprint}',
          );
        }

        await wizard();
        await tap('Reject');
        await until(
          tester,
          () async =>
              find.byType(NextcloudCertificateReviewContent).evaluate().isEmpty,
          'rejection',
        );
        expect(
          (await tester.runAsync(
            () => runtime.database.select(runtime.database.accounts).get(),
          ))!.length,
          before,
        );
        await wizard();
        // The host observer selects the task-owned CA through Android's normal
        // document picker. It never writes a policy or a credential to app data.
        debugPrint('PRIVATE_CERT_PICKER_REQUEST ${entry.key}');
        await tap('Import private CA');
        await until(
          tester,
          () async => find
              .byType(NextcloudCertificateReviewContent)
              .evaluate()
              .any(
                (e) =>
                    (e.widget as NextcloudCertificateReviewContent).data.mode ==
                    NextcloudTrustMode.privateCa,
              ),
          'CA file selected and reviewed',
        );
        final review = tester.widget<NextcloudCertificateReviewContent>(
          find.byType(NextcloudCertificateReviewContent),
        );
        expect(review.data.canApprove, isTrue);
        expect(
          review.data.certificates.single.fingerprint,
          config['caFingerprint'],
        );
        debugPrint(
          'PRIVATE_CA_REVIEW ${entry.key} ${review.data.certificates.single.fingerprint}',
        );
        await tap('Approve this certificate policy');
        await until(
          tester,
          () async =>
              (await runtime.database.select(runtime.database.accounts).get())
                  .length ==
              before + 1,
          'approved account persisted',
        );
        final account = (await tester.runAsync(
          () => runtime.database.select(runtime.database.accounts).get(),
        ))!.singleWhere((a) => a.authority == entry.value);
        final stored =
            (await tester.runAsync(
                  () => c
                      .read(authorizationPersistenceProvider)
                      .readCurrentCredential(account.id),
                ))!
                as CalDavSecretRecord;
        expect(stored.password, credentials['bob']);
        stored.trustPolicy!.requireScope(account.id, Uri.parse(entry.value));
        expect(stored.trustPolicy!.mode, NextcloudTrustMode.privateCa);
        expect(stored.trustPolicy!.caldavService, isTrue);
        await until(
          tester,
          () async =>
              (await runtime.database
                      .select(runtime.database.davCollections)
                      .get())
                  .any((v) => v.accountId == account.id),
          'calendar/task discovery',
        );
        await until(
          tester,
          () async =>
              (await runtime.database.select(runtime.database.accounts).get())
                  .singleWhere((a) => a.id == account.id)
                  .lastSuccessfulSyncAtUtc !=
              null,
          'initial production synchronization',
        );
        debugPrint(
          'PRIVATE_CALDAV_NORMAL_ONBOARDING_PASS ${entry.key} ${account.id}',
        );
      }
      debugPrint('PRIVATE_CALDAV_NORMAL_THREE_SERVER_PASS');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(runtime.dispose);
    },
  );
}
