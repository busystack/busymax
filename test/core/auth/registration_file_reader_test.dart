import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:busymax/src/config/build_config.dart';
import 'package:busymax/src/core/auth/authorization_attempt.dart';
import 'package:busymax/src/core/auth/oauth_models.dart';
import 'package:busymax/src/core/auth/registration_staging.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../support/native_registration_reader_fixture.dart';

void main() {
  test(
    'native reader bounds bytes, rejects actual directories and invalid text, and handles disappearance',
    () async {
      final reader = await buildNativeRegistrationReader();
      final directory = await Directory.systemTemp.createTemp(
        'busymax-reader-input-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/selected.json');
      Future<Uint8List> read(String path) => reader.read(
        path,
        maximumBytes: 65536,
        cancellation: Completer<void>().future,
      );
      await file.writeAsBytes(List.filled(65536, 32));
      expect((await read(file.path)).length, 65536);
      await file.writeAsBytes(List.filled(65537, 32));
      await expectLater(
        read(file.path),
        throwsA(
          isA<OAuthException>().having(
            (e) => e.code,
            'bounded',
            'OAuthConfigurationTooLarge',
          ),
        ),
      );
      await expectLater(
        read(directory.path),
        throwsA(
          isA<OAuthException>().having(
            (e) => e.code,
            'actual handle type',
            'OAuthUnsupportedFileSource',
          ),
        ),
      );
      await file.delete();
      await expectLater(
        read(file.path),
        throwsA(
          isA<OAuthException>().having(
            (e) => e.code,
            'disappeared',
            'OAuthConfigurationUnreadable',
          ),
        ),
      );
      final staging = RegistrationStaging(
        BuildConfig.fromEnvironment(),
        fileReader: reader,
      );
      addTearDown(staging.dispose);
      for (final bytes in [
        [255, 254],
        [123, 125],
      ]) {
        await file.writeAsBytes(bytes);
        await expectLater(
          staging.importGoogle(XFile(file.path)),
          throwsA(isA<OAuthException>()),
        );
      }
    },
  );
  test(
    'cancellation during preparation and a stale completion cannot stage over a newer import',
    () async {
      final reader = await buildNativeRegistrationReader();
      final directory = await Directory.systemTemp.createTemp(
        'busymax-reader-cancel-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/selected.json');
      await file.writeAsString(
        await File('test/fixtures/oauth/desktop_synthetic.json').readAsString(),
      );
      final entered = Completer<void>(), release = Completer<void>();
      var opening = 0;
      final staging = RegistrationStaging(
        BuildConfig.fromEnvironment(),
        fileReader: reader,
        beforeConfigurationOpen: () async {
          if (++opening == 1) {
            entered.complete();
            await release.future;
          }
        },
      );
      addTearDown(staging.dispose);
      final cancellation = AuthorizationCancellation();
      final old = staging.importGoogle(
        XFile(file.path),
        cancellation: cancellation,
      );
      final failed = expectLater(
        old,
        throwsA(
          isA<OAuthException>().having(
            (e) => e.classification,
            'cancelled',
            OAuthFailureKind.cancelled,
          ),
        ),
      );
      await entered.future;
      cancellation.cancel();
      await failed;
      final fresh = await staging.importGoogle(XFile(file.path));
      release.complete();
      expect(staging.consume(fresh).clientId, fresh.summary.clientId);
      expect(() => staging.consume(fresh), throwsA(isA<OAuthException>()));
    },
  );
  test(
    'native read cancellation and deadline return safely without staging late bytes',
    () async {
      final reader = await buildNativeRegistrationReader();
      final directory = await Directory.systemTemp.createTemp(
        'busymax-reader-deadline-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/selected.json');
      await file.writeAsBytes(List.filled(65536, 32));
      await expectLater(
        reader.read(
          file.path,
          maximumBytes: 65536,
          cancellation: Future.value(),
        ),
        throwsA(
          isA<OAuthException>().having(
            (e) => e.classification,
            'cancelled',
            OAuthFailureKind.cancelled,
          ),
        ),
      );
      await expectLater(
        reader.read(
          file.path,
          maximumBytes: 65536,
          cancellation: Completer<void>().future,
          timeout: Duration.zero,
        ),
        throwsA(
          isA<OAuthException>().having(
            (e) => e.classification,
            'deadline',
            OAuthFailureKind.timeout,
          ),
        ),
      );
    },
  );
}
