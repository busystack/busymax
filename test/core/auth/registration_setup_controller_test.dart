import '../../support/desktop_registration_config.dart';
import 'dart:async';
import 'dart:io';

import 'package:busymax/src/config/build_config.dart';
import 'package:busymax/src/core/auth/oauth_models.dart';
import 'package:busymax/src/core/auth/oauth_registration.dart';
import 'package:busymax/src/core/auth/registration_setup_controller.dart';
import 'package:busymax/src/core/auth/registration_staging.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:fake_async/fake_async.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/native_registration_reader_fixture.dart';

const clientId = '11223344-5566-7788-99aa-bbccddeeff00';
const tenantId = 'aabbccdd-1122-3344-5566-77889900aabb';

void main() {
  for (final provider in [BusyProvider.google, BusyProvider.microsoft]) {
    test('$provider shared connection is explicit, validated and single use', () {
      final staging = RegistrationStaging(syntheticDesktopConfig());
      final setup = RegistrationSetupController(staging, provider);
      addTearDown(() {
        setup.dispose();
        staging.dispose();
      });
      // Remembered retired IDs cannot relabel an explicitly active registration.
      staging.rememberRetiringClient(
        provider == BusyProvider.google
            ? staging.config.busyMaxGoogleOAuthClientId
            : staging.config.busyMaxMicrosoftOAuthClientId,
      );
      final selected = setup.connectWithBusyMax()!;
      expect(selected.summary.origin, RegistrationOrigin.busyMaxManaged);
      expect(selected.summary.showRetirementNotice, isFalse);
      expect(setup.connectWithBusyMax(), isNull);
      final registration = staging.consume(selected);
      expect(registration.summary().origin, RegistrationOrigin.busyMaxManaged);
      expect(() => staging.consume(selected), throwsA(isA<OAuthException>()));
    });
    test('$provider originals do not make shared authorization available', () {
      final staging = RegistrationStaging(
        syntheticDesktopConfig(managed: false),
      );
      final setup = RegistrationSetupController(staging, provider);
      addTearDown(() {
        setup.dispose();
        staging.dispose();
      });
      expect(setup.connectWithBusyMax(), isNull);
      expect(setup.errorCode, 'OAuthSharedUnavailable');
      expect(setup.handle, isNull);
      expect(setup.canConnect, isFalse);
    });
  }

  group('Google configuration replacement', () {
    late RegistrationStaging staging;
    late RegistrationSetupController setup;
    late File file;
    XFile? selection;
    setUp(() async {
      final directory = await Directory.systemTemp.createTemp('busymax-setup-');
      addTearDown(() => directory.delete(recursive: true));
      file = File('${directory.path}/desktop.json');
      await file.writeAsString(
        await File('test/fixtures/oauth/desktop_synthetic.json').readAsString(),
      );
      selection = XFile(file.path);
      staging = RegistrationStaging(
        BuildConfig.fromEnvironment(),
        filePicker: () async => selection,
        fileReader: await buildNativeRegistrationReader(),
      );
      setup = RegistrationSetupController(staging, BusyProvider.google);
      addTearDown(() {
        setup.dispose();
        staging.dispose();
      });
    });

    test(
      'successful import exposes only safe summary and is single use',
      () async {
        await setup.validate();
        expect(setup.canConnect, isTrue);
        expect(setup.errorCode, isNull);
        final selected = setup.accept()!;
        expect(selected.summary.projectId, isNotEmpty);
        expect(
          selected.summary.clientId,
          endsWith('.apps.googleusercontent.com'),
        );
        expect(staging.consume(selected), isA<GoogleDesktopRegistration>());
        expect(() => staging.consume(selected), throwsA(isA<OAuthException>()));
      },
    );

    test(
      'cancelled replacement keeps the previous usable configuration',
      () async {
        await setup.validate();
        final old = setup.handle!;
        selection = null;
        await setup.validate();
        expect(setup.handle, same(old));
        expect(staging.isAvailable(old), isTrue);
        expect(setup.canConnect, isTrue);
        expect(setup.errorCode, isNull);
      },
    );

    test(
      'invalid replacement keeps the previous usable configuration',
      () async {
        await setup.validate();
        final old = setup.handle!;
        await file.writeAsString('{"web":{}}');
        await setup.validate();
        expect(setup.handle, same(old));
        expect(setup.errorCode, 'OAuthWrongClientType');
        expect(setup.canConnect, isTrue);
        expect(staging.consume(old), isA<GoogleDesktopRegistration>());
      },
    );

    test('successful replacement invalidates the old handle', () async {
      await setup.validate();
      final old = setup.handle!;
      await setup.validate();
      expect(setup.handle!.id, isNot(old.id));
      expect(staging.isAvailable(old), isFalse);
      expect(setup.canConnect, isTrue);
    });

    test(
      'disposal during native import preparation cannot stage late data',
      () async {
        final entered = Completer<void>();
        final release = Completer<void>();
        final importer = RegistrationStaging(
          BuildConfig.fromEnvironment(),
          filePicker: () async => XFile(file.path),
          fileReader: staging.fileReader,
          beforeConfigurationOpen: () async {
            entered.complete();
            await release.future;
          },
        );
        addTearDown(importer.dispose);
        final controller = RegistrationSetupController(
          importer,
          BusyProvider.google,
        );
        final pending = controller.validate();
        await entered.future;
        controller.dispose();
        await pending;
        release.complete();
        await Future<void>.delayed(Duration.zero);
        expect(controller.handle, isNull);
        expect(controller.error, isNull);
      },
    );

    test(
      'retiring registration replacement preserves previous configuration',
      () async {
        await setup.validate();
        final old = setup.handle!;
        staging.rememberRetiringClient(old.summary.clientId);
        await setup.validate();
        expect(setup.handle, same(old));
        expect(setup.errorCode, 'OAuthRetiringRegistration');
        expect(setup.canConnect, isTrue);
      },
    );
  });

  test(
    'expired Google staging disables Connect and requires a new selection',
    () {
      fakeAsync((time) {
        final staging = RegistrationStaging(
          BuildConfig.fromEnvironment(),
          lifetime: const Duration(seconds: 1),
        );
        final setup = RegistrationSetupController(staging, BusyProvider.google);
        final selected = staging.stage(
          const GoogleDesktopRegistration(
            clientId: 'synthetic.apps.googleusercontent.com',
            projectId: 'synthetic-project',
          ),
        );
        setup.handle = selected;
        var notifications = 0;
        setup.addListener(() => notifications++);
        expect(setup.canConnect, isTrue);
        time.elapse(const Duration(seconds: 1));
        expect(setup.expired, isTrue);
        expect(setup.canConnect, isFalse);
        expect(setup.accept(), isNull);
        expect(notifications, 1);
        expect(() => staging.consume(selected), throwsA(isA<OAuthException>()));
        setup.dispose();
        staging.dispose();
      });
    },
  );

  test('expiry is checked even before its timer fires', () {
    var now = DateTime.utc(2026);
    final staging = RegistrationStaging(
      BuildConfig.fromEnvironment(),
      nowUtc: () => now,
    );
    final setup = RegistrationSetupController(staging, BusyProvider.microsoft);
    setup.updateClientId(clientId);
    now = now.add(staging.lifetime);
    expect(setup.canConnect, isFalse);
    expect(setup.accept(), isNull);
    expect(setup.expired, isTrue);
    setup.dispose();
    staging.dispose();
  });

  group('Microsoft inline validation', () {
    late RegistrationStaging staging;
    late RegistrationSetupController setup;
    setUp(() {
      staging = RegistrationStaging(BuildConfig.fromEnvironment());
      setup = RegistrationSetupController(staging, BusyProvider.microsoft);
      addTearDown(() {
        setup.dispose();
        staging.dispose();
      });
    });

    test('recomputes errors and stages only valid input', () {
      setup.updateClientId('invalid');
      expect(setup.invalidClientId, isTrue);
      expect(setup.canConnect, isFalse);
      setup.updateClientId(clientId);
      expect(setup.invalidClientId, isFalse);
      expect(setup.canConnect, isTrue);
      setup.updateClientId('');
      expect(setup.invalidClientId, isTrue);
      expect(setup.canConnect, isFalse);
    });

    test(
      'audience changes clear tenant and never submit hidden stale data',
      () {
        setup.updateClientId(clientId);
        setup.updateAudience(MicrosoftAudience.tenant);
        expect(setup.canConnect, isFalse);
        setup.updateTenantId('invalid');
        expect(setup.invalidTenantId, isTrue);
        setup.updateTenantId(tenantId);
        expect(setup.canConnect, isTrue);
        for (final audience in [
          MicrosoftAudience.personal,
          MicrosoftAudience.organizations,
          MicrosoftAudience.personalAndOrganizations,
        ]) {
          setup.updateAudience(audience);
          expect(setup.tenantId, isEmpty);
          expect(setup.invalidTenantId, isFalse);
          expect(setup.canConnect, isTrue);
        }
        setup.updateAudience(MicrosoftAudience.tenant);
        expect(setup.tenantId, isEmpty);
        expect(setup.canConnect, isFalse);
      },
    );

    test('Connect repeats validation without refreshing staged expiry', () {
      setup.updateClientId(clientId);
      setup.clientId =
          'invalid'; // Legacy callers can still set input directly.
      expect(setup.accept(), isNull);
      expect(setup.invalidClientId, isTrue);
      expect(setup.handle, isNull);
    });

    test('editing clears an obsolete registration rejection', () {
      staging.rememberRetiringClient(clientId);
      setup.updateClientId(clientId);
      expect(setup.errorCode, 'OAuthRetiringRegistration');
      expect(setup.canConnect, isFalse);
      setup.updateClientId(tenantId);
      expect(setup.errorCode, isNull);
      expect(setup.error, isNull);
      expect(setup.canConnect, isTrue);
    });

    test('duplicate Connect returns the registration only once', () {
      setup.updateClientId(clientId);
      expect(setup.accept(), isNotNull);
      expect(setup.canConnect, isFalse);
      expect(setup.accept(), isNull);
    });

    test('expired Microsoft selection requires an edit before connecting', () {
      setup.updateClientId(clientId);
      staging.discard(setup.handle!.id);
      expect(setup.expired, isTrue);
      expect(setup.canConnect, isFalse);
      setup.updateClientId('');
      expect(setup.expired, isFalse);
      setup.updateClientId(clientId);
      expect(setup.canConnect, isTrue);
    });
  });

  test(
    'duplicate import and disposal during picker ignore late completion',
    () async {
      final selection = Completer<XFile?>();
      var opened = 0;
      final staging = RegistrationStaging(
        BuildConfig.fromEnvironment(),
        filePicker: () {
          opened++;
          return selection.future;
        },
      );
      final setup = RegistrationSetupController(staging, BusyProvider.google);
      final pending = setup.validate();
      await setup.validate();
      expect(opened, 1);
      setup.dispose();
      await pending;
      selection.complete(XFile('/tmp/unused.json'));
      await Future<void>.delayed(Duration.zero);
      expect(setup.handle, isNull);
      staging.dispose();
    },
  );
}
