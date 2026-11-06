import 'dart:io';

import 'package:busymax/l10n/generated/app_localizations.dart';
import 'package:busymax/src/android/presentation/android_nextcloud_certificate_dialog.dart';
import 'package:busymax/src/dav/trust/nextcloud_certificate.dart';
import 'package:busymax/src/dav/trust/nextcloud_http_client_factory.dart';
import 'package:busymax/src/ui/common/nextcloud_certificate_review.dart';
import 'package:busymax/src/ui/linux/nextcloud_certificate_dialog.dart';
import 'package:busymax/src/ui/windows/windows_nextcloud_certificate_dialog.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/nextcloud_tls_fixture.dart';
import '../../test_localized_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late NextcloudTlsFixture tls;
  late NextcloudCertificate certificate;
  setUpAll(() async {
    tls = await NextcloudTlsFixture.create();
    certificate = NextcloudCertificate.import(
      File(tls.path('self.pem')).readAsBytesSync(),
    ).single;
  });
  tearDownAll(() => tls.dispose());
  test(
    'foreground CA import preserves certificate failure classification',
    () async {
      final previous = FileSelectorPlatform.instance;
      addTearDown(() => FileSelectorPlatform.instance = previous);
      for (final file in ['server.key', 'self.pem', 'critical-ca.pem']) {
        FileSelectorPlatform.instance = _CertificateSelector(tls.path(file));
        await expectLater(
          reviewNextcloudCertificate(
            NextcloudCertificateException(
              NextcloudCertificateFailure.approvalRequired,
              endpoint: Uri.parse('https://localhost:8443/nextcloud'),
              observed: certificate,
            ),
            'temporary-onboarding',
            (_) async => CertificateReviewAction.importCa,
          ),
          throwsA(
            isA<NextcloudCertificateException>().having(
              (error) => error.failure,
              'failure',
              NextcloudCertificateFailure.invalidPolicy,
            ),
          ),
        );
      }
    },
  );
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('yaru_window'),
          (call) async => call.method == 'state' ? <String, Object?>{} : null,
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('yaru_window/events'),
          (_) async => null,
        );
  });
  for (final platform in ['Linux', 'Windows', 'Android']) {
    for (final narrow in [false, true]) {
      for (final management in [false, true]) {
        testWidgets(
          '$platform review is selectable and Enter rejects; narrow=$narrow management=$management',
          (tester) async {
            tester.view.physicalSize = narrow
                ? const Size(390, 844)
                : const Size(1000, 900);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            CertificateReviewAction? result;
            final data = NextcloudCertificateReviewData(
              endpoint: Uri.parse('https://localhost:8443/nextcloud'),
              certificates: [certificate],
              canApprove: !management,
              management: management,
            );
            final button = Builder(
              builder: (context) => GestureDetector(
                onTap: () async {
                  result = await switch (platform) {
                    'Windows' => showWindowsNextcloudCertificate(context, data),
                    'Android' => showAndroidNextcloudCertificate(context, data),
                    _ => showLinuxNextcloudCertificate(context, data),
                  };
                },
                child: const Text('open-synthetic-review'),
              ),
            );
            await tester.pumpWidget(
              platform == 'Windows'
                  ? fluent.FluentApp(
                      localizationsDelegates:
                          AppLocalizations.localizationsDelegates,
                      supportedLocales: AppLocalizations.supportedLocales,
                      home: fluent.NavigationView(content: button),
                    )
                  : localizedTestApp(
                      child: Scaffold(body: button),
                      textScaler: narrow ? const TextScaler.linear(1.4) : null,
                    ),
            );
            await tester.tap(find.text('open-synthetic-review'));
            await tester.pumpAndSettle();
            expect(find.byType(SelectableText), findsWidgets);
            expect(
              find.textContaining(certificate.fingerprint),
              findsOneWidget,
            );
            expect(tester.takeException(), isNull);
            await tester.sendKeyEvent(LogicalKeyboardKey.enter);
            await tester.pumpAndSettle();
            expect(result, CertificateReviewAction.reject);
            await tester.pumpWidget(const SizedBox.shrink());
          },
        );
      }
    }
  }
  test(
    'certificate display strips controls and bidi overrides and bounds text',
    () {
      final raw = '${'a' * 600}\n\u001b\u202eevil';
      expect(NextcloudCertificate.safeText(raw).length, 512);
      expect(NextcloudCertificate.safeText('a\n\u202eb'), 'ab');
    },
  );
}

final class _CertificateSelector extends FileSelectorPlatform {
  _CertificateSelector(this.path);
  final String path;
  @override
  Future<XFile?> openFile({
    List<XTypeGroup>? acceptedTypeGroups,
    String? initialDirectory,
    String? confirmButtonText,
  }) async => XFile(path);
}
