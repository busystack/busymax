import 'dart:convert';
import 'dart:io';

import 'package:busymax/l10n/generated/app_localizations.dart';
import 'package:busymax/src/android/presentation/android_nextcloud_certificate_dialog.dart';
import 'package:busymax/src/core/secrets/secret_store.dart';
import 'package:busymax/src/dav/trust/nextcloud_certificate.dart';
import 'package:busymax/src/dav/trust/nextcloud_http_client_factory.dart';
import 'package:busymax/src/dav/trust/nextcloud_trust_policy.dart';
import 'package:busymax/src/ui/common/nextcloud_certificate_review.dart';
import 'package:busymax/src/ui/windows/windows_nextcloud_certificate_dialog.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';

/// Actual Android/native Flutter sockets and secure-storage plugin. Synthetic
/// host peers run separately; no HttpOverrides, mocked responses or TLS bypass.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const encoded = String.fromEnvironment('BUSYMAX_NATIVE_TLS_FIXTURE');
  if (encoded.isEmpty) {
    test(
      'requires disposable native TLS peer',
      () {},
      skip:
          'Run tool/nextcloud_native_tls_host.dart and supply its define file.',
    );
    return;
  }
  final fixture = (jsonDecode(utf8.decode(base64.decode(encoded))) as Map)
      .cast<String, dynamic>();
  final pinEndpoint = Uri.parse(fixture['pin'] as String);
  final caEndpoint = Uri.parse(fixture['ca'] as String);
  final factory = NextcloudHttpClientFactory(requireNetwork: () async {});
  final control = http.Client();
  NextcloudCertificate cert(String name) => NextcloudCertificate.import(
    utf8.encode((fixture['certificates'] as Map)[name] as String),
  ).single;
  NextcloudTrustPolicy policy(
    String owner,
    String name,
    Uri endpoint,
    NextcloudTrustMode mode,
  ) => NextcloudTrustPolicy.approve(
    owner: owner,
    installation: endpoint,
    mode: mode,
    certificates: [cert(name)],
    generation: name,
  );
  Future<Map<String, dynamic>> command(
    String path, [
    Map<String, String> parameters = const {},
  ]) async {
    final response = await control.get(
      Uri.parse(fixture['control'] as String).replace(
        path: path,
        queryParameters: {'nonce': fixture['nonce'] as String, ...parameters},
      ),
    );
    expect(response.statusCode, 200);
    return (jsonDecode(response.body) as Map).cast<String, dynamic>();
  }

  Future<void> change(String slot, String certificate) async {
    await command('/change', {'slot': slot, 'certificate': certificate});
  }

  Future<void> rejects(http.Client client, Uri endpoint, String slot) async {
    final before = (await command('/counts'))[slot];
    await expectLater(
      client.get(
        endpoint,
        headers: {'authorization': 'Basic c3ludGhldGljOnN5bnRoZXRpYw=='},
      ),
      throwsA(isA<NextcloudCertificateException>()),
    );
    expect(
      (await command('/counts'))[slot],
      before,
      reason: 'Rejected TLS must receive no HTTP headers or body.',
    );
  }

  setUp(() async {
    await change('pin', 'self');
    await change('ca', 'leaf');
  });
  tearDownAll(() {
    control.close();
    factory.close();
  });

  test(
    'unapproved Android/native connections send no application request',
    () async {
      final client = factory.create(
        owner: 'unapproved',
        authority: pinEndpoint,
      );
      addTearDown(client.close);
      final before = (await command('/counts'))['pin'];
      await expectLater(
        client.get(pinEndpoint),
        throwsA(
          isA<NextcloudCertificateException>()
              .having(
                (e) => e.failure,
                'failure',
                NextcloudCertificateFailure.approvalRequired,
              )
              .having(
                (e) => e.observed?.fingerprint,
                'observed DER',
                cert('self').fingerprint,
              ),
        ),
      );
      expect((await command('/counts'))['pin'], before);
    },
  );
  test(
    'approved CA permits valid renewal and rejects another identity',
    () async {
      final client = factory.create(
        owner: 'ca-owner',
        authority: caEndpoint,
        policy: policy(
          'ca-owner',
          'ca',
          caEndpoint,
          NextcloudTrustMode.privateCa,
        ),
      );
      addTearDown(client.close);
      expect((await client.get(caEndpoint)).statusCode, 200);
      await change('ca', 'renewed');
      expect((await client.get(caEndpoint)).statusCode, 200);
      await change('ca', 'self');
      await rejects(client, caEndpoint, 'ca');
      await change('ca', 'wrong-leaf');
      await rejects(client, caEndpoint, 'ca');
    },
  );
  test(
    'pin rejects changed DER using same key and requires explicit replacement',
    () async {
      final accepted = policy(
        'pin-owner',
        'self',
        pinEndpoint,
        NextcloudTrustMode.pinnedLeaf,
      );
      final client = factory.create(
        owner: 'pin-owner',
        authority: pinEndpoint,
        policy: accepted,
      );
      addTearDown(client.close);
      expect((await client.get(pinEndpoint)).statusCode, 200);
      await change('pin', 'self-renewed');
      await rejects(client, pinEndpoint, 'pin');
      final replacement = factory.create(
        owner: 'replacement',
        authority: pinEndpoint,
        policy: policy(
          'replacement',
          'self-renewed',
          pinEndpoint,
          NextcloudTrustMode.pinnedLeaf,
        ),
      );
      addTearDown(replacement.close);
      expect((await replacement.get(pinEndpoint)).statusCode, 200);
      await change('pin', 'leaf');
      await rejects(replacement, pinEndpoint, 'pin');
    },
  );
  test(
    'owners cannot inherit approval and closing one does not close another',
    () async {
      final accepted = policy(
        'owner-a',
        'self',
        pinEndpoint,
        NextcloudTrustMode.pinnedLeaf,
      );
      expect(
        () => factory.create(
          owner: 'owner-b',
          authority: pinEndpoint,
          policy: accepted,
        ),
        throwsA(isA<NextcloudCertificateException>()),
      );
      final a = factory.create(
        owner: 'owner-a',
        authority: pinEndpoint,
        policy: accepted,
      );
      final b = factory.create(
        owner: 'owner-b',
        authority: pinEndpoint,
        policy: policy(
          'owner-b',
          'self',
          pinEndpoint,
          NextcloudTrustMode.pinnedLeaf,
        ),
      );
      addTearDown(b.close);
      factory.invalidate('owner-a');
      expect((await b.get(pinEndpoint)).statusCode, 200);
      a.close();
    },
  );
  test(
    'native encrypted storage retains the typed policy across reopening',
    () async {
      const storage = FlutterSecureStorage(
        aOptions: AndroidOptions(resetOnError: false),
      );
      final first = SecureSecretStore(storage);
      const id = 'native-certificate-acceptance';
      final saved = policy(
        id,
        'self',
        pinEndpoint,
        NextcloudTrustMode.pinnedLeaf,
      );
      await first.saveCredential(
        id,
        NextcloudSecretRecord(
          canonicalServer: pinEndpoint,
          loginName: 'synthetic',
          appPassword: 'synthetic',
          trustPolicy: saved,
        ),
      );
      final reopened = await SecureSecretStore(
        storage,
      ).readCredential(id) as NextcloudSecretRecord;
      expect(reopened.trustPolicy!.toJson(), saved.toJson());
      final client = factory.create(
        owner: id,
        authority: pinEndpoint,
        policy: reopened.trustPolicy,
      );
      addTearDown(client.close);
      expect((await client.get(pinEndpoint)).statusCode, 200);
      await first.deleteCredential(id);
    },
  );
  testWidgets(
    'Native certificate management displays identity and requires deliberate actions',
    (tester) async {
      CertificateReviewAction? selected;
      final open = Builder(
        builder: (context) => GestureDetector(
          onTap: () async {
            final data = NextcloudCertificateReviewData(
              endpoint: pinEndpoint,
              certificates: [cert('self')],
              canApprove: true,
            );
            selected = Platform.isWindows
                ? await showWindowsNextcloudCertificate(context, data)
                : await showAndroidNextcloudCertificate(context, data);
          },
          child: const Text('Review synthetic certificate'),
        ),
      );
      await tester.pumpWidget(
        Platform.isWindows
            ? fluent.FluentApp(
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: fluent.NavigationView(content: open),
              )
            : MaterialApp(
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Scaffold(body: open),
              ),
      );
      await tester.tap(find.text('Review synthetic certificate'));
      await tester.pumpAndSettle();
      expect(find.byType(SelectableText), findsWidgets);
      expect(find.textContaining(cert('self').fingerprint), findsOneWidget);
      final l10n = AppLocalizations.of(
        tester.element(find.byType(SelectableText).first),
      );
      await tester.tap(find.text(l10n.certificateReject));
      await tester.pumpAndSettle();
      expect(selected, CertificateReviewAction.reject);
      await tester.tap(find.text('Review synthetic certificate'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.certificateApprove));
      await tester.pumpAndSettle();
      expect(selected, CertificateReviewAction.approve);
    },
  );
  testWidgets(
    'Android native CA file picker reviews rejection and explicit approval',
    (tester) async {
      const owner = 'native-file-import';
      final policies = <NextcloudTrustPolicy?>[];
      final client = factory.create(owner: owner, authority: pinEndpoint);
      addTearDown(client.close);
      NextcloudCertificateException? challenge;
      try {
        await client.get(pinEndpoint);
      } on NextcloudCertificateException catch (error) {
        challenge = error;
      }
      expect(challenge, isNotNull);
      final before = (await command('/counts'))['pin'];
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async => policies.add(
                  await reviewNextcloudCertificate(
                    challenge!,
                    owner,
                    (data) => showAndroidNextcloudCertificate(context, data),
                  ),
                ),
                child: const Text('Import disposable QA CA'),
              ),
            ),
          ),
        ),
      );
      final l10n = AppLocalizations.of(
        tester.element(find.text('Import disposable QA CA')),
      );
      for (var attempt = 0; attempt < 2; attempt++) {
        await tester.tap(find.text('Import disposable QA CA'));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.certificateImportCa));
        // The host chooses only BusyMax-certificate-QA.crt through the actual
        // Android DocumentsUI. No file-selector platform interface is mocked.
        final deadline = DateTime.now().add(const Duration(seconds: 45));
        while (find.textContaining(cert('ca').fingerprint).evaluate().isEmpty) {
          if (DateTime.now().isAfter(deadline)) {
            fail(
              'The native CA picker did not return the disposable certificate.',
            );
          }
          await tester.pump(const Duration(milliseconds: 200));
        }
        await tester.pumpAndSettle();
        await tester.tap(
          find.text(
            attempt == 0 ? l10n.certificateReject : l10n.certificateApprove,
          ),
        );
        await tester.pumpAndSettle();
        expect((await command('/counts'))['pin'], before);
      }
      expect(policies.first, isNull);
      final imported = policies.last!;
      expect(imported.mode, NextcloudTrustMode.privateCa);
      expect(imported.certificates.single.fingerprint, cert('ca').fingerprint);
      await change('pin', 'leaf');
      final accepted = factory.create(
        owner: owner,
        authority: pinEndpoint,
        policy: imported,
      );
      addTearDown(accepted.close);
      expect((await accepted.get(pinEndpoint)).statusCode, 200);
    },
    skip:
        !Platform.isAndroid ||
        !const bool.fromEnvironment('BUSYMAX_NATIVE_CA_PICKER'),
  );
}
