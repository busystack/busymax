import '../../../support/desktop_registration_config.dart';
import 'dart:async';
import 'dart:io';

import 'package:busymax/l10n/generated/app_localizations.dart';
import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/app/busymax_design.dart';
import 'package:busymax/src/platform/native_menu_service.dart';
import 'package:busymax/src/app/busymax_yaru_theme.dart';
import 'package:busymax/src/config/build_config.dart';
import 'package:busymax/src/core/auth/oauth_registration.dart';
import 'package:busymax/src/core/auth/registration_staging.dart';
import 'package:busymax/src/features/auth/presentation/registration_setup_dialog.dart';
import 'package:busymax/src/google_tasks/api/google_tasks_api_surface.dart';
import 'package:busymax/src/l10n/registration_setup_content.dart';
import 'package:busymax/src/microsoft_todo/oauth/microsoft_oauth_service.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:busymax/src/ui/windows/windows_registration_setup_dialog.dart';
import 'package:file_selector/file_selector.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/native_registration_reader_fixture.dart';
import '../../../test_localized_app.dart';

const _clientId = '11223344-5566-7788-99aa-bbccddeeff00';
const _tenantId = 'aabbccdd-1122-3344-5566-77889900aabb';
const _launchChannel = MethodChannel('plugins.flutter.io/url_launcher');
Finder _key(String name) => find.byKey(ValueKey('registration-$name'));
VoidCallback? _callback(WidgetTester tester, String name) =>
    (tester.widget(_key(name)) as dynamic).onPressed as VoidCallback?;

void main() {
  test('guide scope values match actual OAuth configuration', () {
    final l10n = lookupAppLocalizations(const Locale('en'));
    expect(
      l10n
          .registrationDesktopSteps(BusyProvider.google)
          .singleWhere((s) => s.copyAll)
          .values!
          .split('\n'),
      googleBusyMaxOAuthScopes,
    );
    final workspace = l10n.registrationDesktopSteps(
      BusyProvider.google,
      method: DesktopConnectionMethod.googleWorkspace,
    );
    expect(
      workspace.singleWhere((s) => s.copyAll).values!.split('\n'),
      googleBusyMaxOAuthScopes,
    );
    expect(workspace.map((s) => s.body).join(' '), isNot(contains('Testing')));
    expect(workspace, hasLength(5));
    final microsoft = l10n.registrationDesktopSteps(BusyProvider.microsoft);
    final scopes = microsoft[3].values!.split(RegExp(r'\s+'));
    expect(
      scopes.take(3).map((s) => 'https://graph.microsoft.com/$s'),
      microsoftTodoOAuthScopes.split(' ').skip(4),
    );
    expect(scopes.skip(3), microsoftTodoOAuthScopes.split(' ').take(4));
    expect(microsoft[2].values, 'http://localhost');
    for (final provider in [BusyProvider.google, BusyProvider.microsoft]) {
      final guide = l10n.registrationDesktopSteps(provider);
      expect(guide.length, provider == BusyProvider.google ? 7 : 5);
      expect(guide.where((step) => step.copyAll), hasLength(1));
      expect(guide.map((s) => s.body).join(' '), isNot(contains('Android')));
      expect(guide.map((s) => s.body).join(' '), isNot(contains('migration')));
    }
  });

  for (final windows in [false, true]) {
    group(windows ? 'Windows production dialog' : 'Linux production dialog', () {
      late RegistrationStaging staging;
      late _Harness harness;
      XFile? selection;
      setUp(() {
        selection = null;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('yaru_window'),
              (_) async => <String, Object?>{},
            );
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('yaru_window/events'),
              (_) async => null,
            );
        staging = RegistrationStaging(
          BuildConfig.fromEnvironment(),
          filePicker: () async => selection,
        );
        harness = _Harness(windows, staging);
        addTearDown(() => staging.dispose());
      });

      for (final provider in [BusyProvider.google, BusyProvider.microsoft]) {
        testWidgets(
          '$provider methods expose unavailable shared and usable custom paths',
          (tester) async {
            await harness.open(tester, provider, methods: true);
            expect(_key('authorize'), findsNothing);
            expect(_key('back'), findsNothing);
            expect(_callback(tester, 'busymax'), isNull);
            expect(_key('shared-unavailable'), findsOneWidget);
            await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
            await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
            await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
            await tester.pumpAndSettle();
            expect(_key('methods-dialog'), findsOneWidget);
            expect(harness.results, isEmpty);
            expect(
              _key('workspace'),
              provider == BusyProvider.google ? findsOneWidget : findsNothing,
            );
            if (provider == BusyProvider.google) {
              await tester.tap(_key('workspace'));
              await tester.pumpAndSettle();
              expect(
                find.text('Google Workspace organization'),
                findsOneWidget,
              );
              await tester.tap(_key('guide'));
              await tester.pumpAndSettle();
              expect(
                find.text('Google Workspace setup instructions'),
                findsOneWidget,
              );
              expect(
                find.byWidgetPredicate(
                  (w) => w is ModalBarrier && (w.color?.a ?? 0) > 0,
                ),
                findsOneWidget,
              );
              expect(_key('authorize'), findsNothing);
              await tester.tap(_key('back'));
              await tester.pumpAndSettle();
              await tester.tap(_key('back'));
              await tester.pumpAndSettle();
            }
            await tester.tap(_key('custom'));
            await tester.pumpAndSettle();
            expect(_key('authorize'), findsOneWidget);
            await tester.tap(_key('guide'));
            await tester.pumpAndSettle();
            await tester.tap(_key('close'));
            await tester.pumpAndSettle();
            expect(harness.results, [null]);
            expect(
              find.byWidgetPredicate(
                (w) => w is ModalBarrier && (w.color?.a ?? 0) > 0,
              ),
              findsNothing,
            );
            await tester.pumpWidget(const SizedBox.shrink());
          },
        );
        testWidgets(
          '$provider configured shared returns a managed handle without fields or import',
          (tester) async {
            staging.dispose();
            staging = RegistrationStaging(syntheticDesktopConfig());
            harness = _Harness(windows, staging);
            await harness.open(tester, provider, methods: true);
            expect(_key('shared-unavailable'), findsNothing);
            expect(_key('import'), findsNothing);
            expect(_key('client-id'), findsNothing);
            final connect = _callback(tester, 'busymax')!;
            connect();
            connect();
            await tester.pumpAndSettle();
            expect(harness.results, hasLength(1));
            expect(
              harness.results.single!.summary.origin,
              RegistrationOrigin.busyMaxManaged,
            );
            staging.consume(harness.results.single!);
            await tester.pumpWidget(const SizedBox.shrink());
          },
        );
      }

      testWidgets('native form hierarchy and inline validation', (
        tester,
      ) async {
        await harness.open(tester, BusyProvider.microsoft);
        expect(_key('validate'), findsNothing);
        expect(find.text('Official documentation'), findsNothing);
        expect(_callback(tester, 'authorize'), isNull);
        if (windows) {
          expect(tester.widget(_key('authorize')), isA<fluent.FilledButton>());
          expect(find.byType(TextField), findsNothing);
          expect(find.byType(fluent.InfoLabel), findsNWidgets(2));
        } else {
          expect(tester.widget(_key('authorize')), isA<ElevatedButton>());
          expect(find.byType(BusyMaxGroupedList), findsNWidgets(2));
          expect(
            find.byType(BusyMaxComboRow<MicrosoftAudience>),
            findsOneWidget,
          );
          expect(find.byType(DropdownButton<MicrosoftAudience>), findsNothing);
          final field = tester.widget<TextField>(_key('client-id'));
          expect(field.decoration!.border, InputBorder.none);
        }
        await tester.enterText(_key('client-id'), 'invalid');
        await tester.pumpAndSettle();
        expect(find.text('Enter a valid UUID.'), findsOneWidget);
        expect(_callback(tester, 'authorize'), isNull);
        await tester.enterText(_key('client-id'), _clientId);
        await tester.pumpAndSettle();
        expect(find.text('Enter a valid UUID.'), findsNothing);
        expect(_callback(tester, 'authorize'), isNotNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      });

      testWidgets(
        'audience and tenant stay synchronized across guide and hiding',
        (tester) async {
          await harness.open(tester, BusyProvider.microsoft);
          await tester.enterText(_key('client-id'), _clientId);
          await _audience(tester, windows, MicrosoftAudience.tenant);
          await tester.enterText(_key('tenant-id'), _tenantId);
          await tester.pumpAndSettle();
          expect(_callback(tester, 'authorize'), isNotNull);
          await _audience(tester, windows, MicrosoftAudience.tenant);
          expect(_fieldText(tester, windows, 'tenant-id'), _tenantId);
          await tester.tap(_key('guide'));
          await tester.pumpAndSettle();
          expect(_key('client-id'), findsNothing);
          expect(_key('authorize').hitTestable(), findsNothing);
          expect(
            find.descendant(
              of: _key('instructions-dialog'),
              matching: find.text('Cancel'),
            ),
            findsNothing,
          );
          expect(_key('back'), findsOneWidget);
          expect(
            find.descendant(
              of: _key('instructions-dialog'),
              matching: find.byType(SingleChildScrollView),
            ),
            findsOneWidget,
          );
          expect(find.text('1. Microsoft app registration'), findsOneWidget);
          await tester.tap(_key('back'));
          await tester.pumpAndSettle();
          expect(_fieldText(tester, windows, 'client-id'), _clientId);
          expect(_fieldText(tester, windows, 'tenant-id'), _tenantId);
          await _audience(tester, windows, MicrosoftAudience.personal);
          expect(_key('tenant-id'), findsNothing);
          expect(_callback(tester, 'authorize'), isNotNull);
          await _audience(tester, windows, MicrosoftAudience.tenant);
          expect(_fieldText(tester, windows, 'tenant-id'), isEmpty);
          expect(_callback(tester, 'authorize'), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
        },
      );

      if (!windows) {
        testWidgets(
          'audience selection delegates the four choices to the host menu',
          (tester) async {
            MethodCall? menu;
            final result = Completer<int?>();
            const channel = MethodChannel(nativeMenuChannelName);
            tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
              channel,
              (call) async {
                if (call.method == 'show') {
                  menu = call;
                  return result.future;
                }
                return true;
              },
            );
            addTearDown(
              () => tester.binding.defaultBinaryMessenger
                  .setMockMethodCallHandler(channel, null),
            );
            await harness.open(tester, BusyProvider.microsoft);
            await tester.tap(_key('audience'));
            await tester.pumpAndSettle();
            final entries = (menu!.arguments as Map)['entries'] as List;
            final anchor = (menu!.arguments as Map)['anchor'] as Map;
            expect(anchor['width'], greaterThan(400));
            expect(
              find.text('Personal and organizational accounts'),
              findsOneWidget,
            );
            expect(entries.map((entry) => entry['label']), [
              'Personal and organizational accounts',
              'Organizational accounts',
              'Personal accounts',
              'One organizational tenant',
            ]);
            expect(entries.every((entry) => entry['role'] == 'radio'), isTrue);
            expect(entries.first['selected'], isTrue);
            result.complete(3);
            await tester.pumpAndSettle();
            expect(_key('tenant-id'), findsOneWidget);
            expect(
              tester
                  .widget<BusyMaxComboRow<MicrosoftAudience>>(_key('audience'))
                  .selected,
              MicrosoftAudience.tenant,
            );
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pumpAndSettle();
          },
        );
      }

      testWidgets(
        'instructions keep header fixed, hide footer, copy scopes and navigate by keyboard',
        (tester) async {
          String? copied;
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            (call) async {
              if (call.method == 'Clipboard.setData') {
                copied = (call.arguments as Map)['text'] as String;
              }
              return null;
            },
          );
          addTearDown(
            () => tester.binding.defaultBinaryMessenger
                .setMockMethodCallHandler(SystemChannels.platform, null),
          );
          await harness.open(tester, BusyProvider.microsoft);
          await tester.enterText(_key('client-id'), _clientId);
          final clientController = windows
              ? tester.widget<fluent.TextBox>(_key('client-id')).controller
              : tester.widget<TextField>(_key('client-id')).controller;
          await tester.tap(_key('guide'));
          await tester.pumpAndSettle();
          expect(find.text('Microsoft setup instructions'), findsOneWidget);
          expect(_key('authorize').hitTestable(), findsNothing);
          expect(
            find.descendant(
              of: _key('instructions-dialog'),
              matching: find.text('Cancel'),
            ),
            findsNothing,
          );
          expect(_key('back'), findsOneWidget);
          if (windows) {
            expect(
              tester
                  .widget<fluent.ContentDialog>(_key('instructions-dialog'))
                  .actions,
              isNull,
            );
          }
          final headerPosition = tester.getTopLeft(_key('back'));
          await tester.ensureVisible(_key('copy-all'));
          await tester.pumpAndSettle();
          expect(tester.getTopLeft(_key('back')), headerPosition);
          await tester.tap(_key('copy-all'));
          await tester.pumpAndSettle();
          final steps = lookupAppLocalizations(
            const Locale('en'),
          ).registrationDesktopSteps(BusyProvider.microsoft);
          expect(copied, steps.singleWhere((step) => step.copyAll).values);
          // Back and its shortcut stay inside the one modal, preserving controllers.
          await tester.tap(_key('back'));
          await tester.pumpAndSettle();
          expect(_key('instructions-dialog'), findsNothing);
          expect(harness.results, isEmpty);
          expect(_fieldText(tester, windows, 'client-id'), _clientId);
          expect(
            windows
                ? tester.widget<fluent.TextBox>(_key('client-id')).controller
                : tester.widget<TextField>(_key('client-id')).controller,
            same(clientController),
          );
          await tester.tap(_key('guide'));
          await tester.pumpAndSettle();
          await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
          await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
          await tester.pumpAndSettle();
          expect(_key('instructions-dialog'), findsNothing);
          expect(harness.results, isEmpty);
          expect(_key('authorize').hitTestable(), findsOneWidget);
          expect(_key('client-id'), findsOneWidget);
          expect(_fieldText(tester, windows, 'client-id'), _clientId);
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
        },
      );

      testWidgets('instructions use one barrier and Back preserves setup', (
        tester,
      ) async {
        await harness.open(tester, BusyProvider.microsoft);
        await tester.enterText(_key('client-id'), _clientId);
        final openInstructions = windows
            ? tester.widget<fluent.ListTile>(_key('guide')).onPressed!
            : tester.widget<BusyMaxActionRow>(_key('guide')).onTap!;
        openInstructions();
        openInstructions();
        await tester.pumpAndSettle();
        expect(_key('instructions-dialog'), findsOneWidget);
        expect(
          find.byWidgetPredicate(
            (w) => w is ModalBarrier && (w.color?.a ?? 0) > 0,
          ),
          findsOneWidget,
        );
        expect(_key('back'), findsOneWidget);
        expect(harness.results, isEmpty);
        await tester.tap(_key('back'));
        await tester.pumpAndSettle();
        expect(_key('instructions-dialog'), findsNothing);
        expect(_fieldText(tester, windows, 'client-id'), _clientId);
        expect(harness.results, isEmpty);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(harness.results, [null]);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      });

      testWidgets('Connect prevents duplicate results', (tester) async {
        await harness.open(tester, BusyProvider.microsoft);
        await tester.enterText(_key('client-id'), _clientId);
        await tester.pumpAndSettle();
        final connect = _callback(tester, 'authorize')!;
        connect();
        connect();
        await tester.pumpAndSettle();
        expect(harness.results, hasLength(1));
        final registration =
            staging.consume(harness.results.single!)
                as MicrosoftPublicRegistration;
        expect(registration.clientId, _clientId);
        expect(registration.tenantId, isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });

      testWidgets(
        'Google imports, preserves replacements and form when instructions close',
        (tester) async {
          late File file;
          await tester.runAsync(() async {
            final directory = await Directory.systemTemp.createTemp(
              'busymax-dialog-',
            );
            addTearDown(() => directory.delete(recursive: true));
            file = File('${directory.path}/desktop.json');
            await file.writeAsString(
              await File(
                'test/fixtures/oauth/desktop_synthetic.json',
              ).readAsString(),
            );
            staging.dispose();
            staging = RegistrationStaging(
              BuildConfig.fromEnvironment(),
              filePicker: () async => selection,
              fileReader: await buildNativeRegistrationReader(),
            );
            harness = _Harness(windows, staging);
          });
          selection = XFile(file.path);
          await harness.open(tester, BusyProvider.google);
          expect(_callback(tester, 'authorize'), isNull);
          await tester.runAsync(() async {
            await (_callback(tester, 'import') as dynamic)();
          });
          await tester.pumpAndSettle();
          expect(_key('summary'), findsOneWidget);
          expect(_callback(tester, 'authorize'), isNotNull);
          expect(find.text('Replace…'), findsOneWidget);
          selection = null;
          await tester.tap(_key('import'));
          await tester.pumpAndSettle();
          expect(_key('error'), findsNothing);
          expect(_key('summary'), findsOneWidget);
          expect(_callback(tester, 'authorize'), isNotNull);
          selection = XFile(file.path);
          await tester.runAsync(() async {
            await file.writeAsString('{"web":{}}');
            await (_callback(tester, 'import') as dynamic)();
          });
          await tester.pumpAndSettle();
          expect(_key('error'), findsOneWidget);
          expect(_key('summary'), findsOneWidget);
          expect(_callback(tester, 'authorize'), isNotNull);
          await tester.tap(_key('guide'));
          await tester.pumpAndSettle();
          expect(_key('summary'), findsNothing);
          expect(find.text('1. Google Cloud project'), findsOneWidget);
          expect(
            find.descendant(
              of: _key('instructions-dialog'),
              matching: find.byType(SingleChildScrollView),
            ),
            findsOneWidget,
          );
          await tester.tap(_key('back'));
          await tester.pumpAndSettle();
          expect(_key('summary'), findsOneWidget);
          expect(_key('error'), findsOneWidget);
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
        },
      );

      testWidgets(
        'expired Google import disables Connect and requires re-import',
        (tester) async {
          late File file;
          await tester.runAsync(() async {
            final directory = await Directory.systemTemp.createTemp(
              'busymax-dialog-expiry-',
            );
            addTearDown(() => directory.delete(recursive: true));
            file = File('${directory.path}/desktop.json');
            await file.writeAsString(
              await File(
                'test/fixtures/oauth/desktop_synthetic.json',
              ).readAsString(),
            );
            staging.dispose();
            staging = RegistrationStaging(
              BuildConfig.fromEnvironment(),
              lifetime: const Duration(seconds: 1),
              filePicker: () async => selection,
              fileReader: await buildNativeRegistrationReader(),
            );
            harness = _Harness(windows, staging);
          });
          selection = XFile(file.path);
          await harness.open(tester, BusyProvider.google);
          await tester.runAsync(() async {
            await (_callback(tester, 'import') as dynamic)();
          });
          await tester.pumpAndSettle();
          expect(_callback(tester, 'authorize'), isNotNull);
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 1100)),
          );
          await tester.pumpAndSettle();
          expect(_callback(tester, 'authorize'), isNull);
          expect(_key('summary'), findsNothing);
          expect(
            find.textContaining('This configuration expired.'),
            findsOneWidget,
          );
          selection = null;
          await tester.tap(_key('import'));
          await tester.pumpAndSettle();
          expect(_callback(tester, 'authorize'), isNull);
          expect(
            find.textContaining('This configuration expired.'),
            findsOneWidget,
          );
          selection = XFile(file.path);
          await tester.runAsync(() async {
            await (_callback(tester, 'import') as dynamic)();
          });
          await tester.pumpAndSettle();
          expect(_callback(tester, 'authorize'), isNotNull);
          expect(_key('error'), findsNothing);
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
        },
      );

      testWidgets('expiry disables Microsoft Connect while help is open', (
        tester,
      ) async {
        staging.dispose();
        staging = RegistrationStaging(
          BuildConfig.fromEnvironment(),
          lifetime: const Duration(seconds: 3),
        );
        harness = _Harness(windows, staging);
        await harness.open(tester, BusyProvider.microsoft);
        await tester.enterText(_key('client-id'), _clientId);
        await tester.pump();
        await tester.tap(_key('guide'));
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 3));
        await tester.tap(_key('back'));
        await tester.pumpAndSettle();
        expect(_key('error'), findsOneWidget);
        expect(
          find.textContaining('This configuration expired.'),
          findsOneWidget,
        );
        expect(_callback(tester, 'authorize'), isNull);
        await tester.enterText(_key('client-id'), '');
        await tester.enterText(_key('client-id'), _clientId);
        await tester.pump();
        expect(_key('error'), findsNothing);
        expect(_callback(tester, 'authorize'), isNotNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      });

      for (final throws in [false, true]) {
        testWidgets(
          'link launch ${throws ? 'exception' : 'false'} shows localized error',
          (tester) async {
            tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
              _launchChannel,
              (_) async {
                if (throws) throw PlatformException(code: 'failed');
                return false;
              },
            );
            addTearDown(
              () => tester.binding.defaultBinaryMessenger
                  .setMockMethodCallHandler(_launchChannel, null),
            );
            await harness.open(tester, BusyProvider.google);
            await tester.tap(_key('guide'));
            await tester.pumpAndSettle();
            await tester.ensureVisible(find.text('Open Google Cloud Console'));
            await tester.tap(find.text('Open Google Cloud Console'));
            await tester.pumpAndSettle();
            expect(
              find.text(
                'Could not open the link. Check your browser and try again.',
              ),
              findsOneWidget,
            );
            await tester.ensureVisible(_key('back'));
            await tester.tap(_key('back'));
            await tester.pumpAndSettle();
            expect(_key('link-error'), findsNothing);
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pumpAndSettle();
          },
        );
      }

      for (final provider in [BusyProvider.google, BusyProvider.microsoft]) {
        testWidgets(
          '$provider link failure stays beside only the selected guide step',
          (tester) async {
            tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
              _launchChannel,
              (_) async => false,
            );
            addTearDown(
              () => tester.binding.defaultBinaryMessenger
                  .setMockMethodCallHandler(_launchChannel, null),
            );
            await harness.open(tester, provider);
            await tester.tap(_key('guide'));
            await tester.pumpAndSettle();
            final link = find.text(
              provider == BusyProvider.google
                  ? 'Open Google Auth Platform Clients'
                  : 'Open Entra app registrations for API permissions',
            );
            await tester.ensureVisible(link);
            await tester.tap(link);
            await tester.pumpAndSettle();
            expect(_key('link-error'), findsOneWidget);
            expect(_key('link-error').hitTestable(), findsOneWidget);
            await tester.tap(_key('back'));
            await tester.pumpAndSettle();
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pumpAndSettle();
          },
        );
      }

      testWidgets('late link completion cannot alter reopened guide', (
        tester,
      ) async {
        final launched = Completer<bool>();
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          _launchChannel,
          (_) => launched.future,
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            _launchChannel,
            null,
          ),
        );
        await harness.open(tester, BusyProvider.google);
        await tester.tap(_key('guide'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Open Google Cloud Console'));
        await tester.pump();
        await tester.tap(_key('back'));
        await tester.pumpAndSettle();
        await tester.tap(_key('guide'));
        await tester.pumpAndSettle();
        launched.complete(false);
        await tester.pumpAndSettle();
        expect(_key('link-error'), findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      });

      testWidgets('disposal during picker or link work ignores completions', (
        tester,
      ) async {
        final selected = Completer<XFile?>();
        staging.dispose();
        staging = RegistrationStaging(
          BuildConfig.fromEnvironment(),
          filePicker: () => selected.future,
        );
        harness = _Harness(windows, staging);
        await harness.open(tester, BusyProvider.google);
        await tester.tap(_key('import'));
        await tester.pump();
        expect(_callback(tester, 'import'), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        selected.complete(null);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final launched = Completer<bool>();
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          _launchChannel,
          (_) => launched.future,
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            _launchChannel,
            null,
          ),
        );
        await harness.open(tester, BusyProvider.microsoft);
        await tester.tap(_key('guide'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Open Microsoft Entra admin center'));
        await tester.pump();
        await tester.pumpWidget(const SizedBox.shrink());
        launched.complete(false);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    });
  }
}

String _fieldText(WidgetTester tester, bool windows, String field) => windows
    ? tester.widget<fluent.TextBox>(_key(field)).controller!.text
    : tester.widget<TextField>(_key(field)).controller!.text;

Future<void> _audience(
  WidgetTester tester,
  bool windows,
  MicrosoftAudience value,
) async {
  if (windows) {
    tester
        .widget<fluent.ComboBox<MicrosoftAudience>>(_key('audience'))
        .onChanged!(value);
  } else {
    tester
        .widget<BusyMaxComboRow<MicrosoftAudience>>(_key('audience'))
        .onSelected(value);
  }
  await tester.pumpAndSettle();
}

class _Harness {
  _Harness(this.windows, this.staging);
  final bool windows;
  final RegistrationStaging staging;
  final results = <RegistrationHandle?>[];

  Future<void> open(
    WidgetTester tester,
    BusyProvider provider, {
    bool methods = false,
  }) async {
    tester.view.physicalSize = const Size(1100, 950);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final trigger = Consumer(
      builder: (context, ref, _) {
        void open() {
          final result = windows
              ? showWindowsRegistrationSetup(context, ref, provider)
              : showRegistrationSetup(context, ref, provider);
          unawaited(result.then(results.add));
        }

        return windows
            ? fluent.Button(onPressed: open, child: const Text('Open'))
            : TextButton(onPressed: open, child: const Text('Open'));
      },
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [registrationStagingProvider.overrideWithValue(staging)],
        child: windows
            ? fluent.FluentApp(
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: fluent.ScaffoldPage(content: trigger),
              )
            : localizedTestApp(
                theme: BusyMaxYaruTheme.build(
                  brightness: Brightness.light,
                  accentColor: const Color(0xffe95420),
                ),
                child: Scaffold(body: trigger),
              ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    if (!methods) {
      await tester.tap(_key('custom'));
      await tester.pumpAndSettle();
    }
  }
}
