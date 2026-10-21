import 'dart:convert';
import 'dart:io';

import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busystack_contacts/busystack_contacts.dart';
import 'package:busymax/src/app/busymax_yaru_theme.dart';
import 'package:busymax/src/app/busymax_design.dart';
import 'package:busymax/src/app/linux/linux_window_host.dart';
import 'package:busymax/l10n/generated/app_localizations.dart';
import 'package:busymax/src/core/secrets/secret_store.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/demo/demo_profile.dart';
import 'package:busymax/src/features/calendar/data/calendar_repository.dart';
import 'package:busymax/src/calendar_providers/calendar_sync_dto.dart';
import 'package:busymax/src/features/settings/presentation/settings_screen.dart';
import 'package:busymax/src/platform/gtk_font_service.dart';
import 'package:busymax/src/platform/gtk_header_icon_service.dart';
import 'package:busymax/src/platform/gtk_window_preferences_service.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:busymax/src/microsoft_calendar/microsoft_shared_calendar_address.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:yaru/yaru.dart';
import 'package:ubuntu_localizations/ubuntu_localizations.dart';

import '../test/support/contacts_fixture.dart';
import '../test/support/desktop_registration_config.dart';

// Explicit opt-in. Every account, provider response, secret and database below
// is synthetic; the owner's profile, keyring and providers are never opened.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final output = Platform.environment['BUSYMAX_ACCEPTANCE_ROOT'];
  testWidgets(
    'native Accounts supports multiple identities, themes, narrow windows, keyboard and safe confirmation',
    (tester) async {
      expect(Platform.environment['XDG_DATA_HOME'], '$output/data');
      final semantics = tester.ensureSemantics();
      await tester.runAsync(YaruWindowTitleBar.ensureInitialized);
      final f = ContactsFixture(AppDatabase.memoryForTests());
      final secrets = InMemorySecretStore();
      final icons = GtkHeaderIconService();
      await tester.runAsync(icons.initialize);
      final windowPreferences = await tester.runAsync(
        () => const GtkWindowPreferencesService().load(),
      );
      await tester.runAsync(() async {
        for (final provider in [
          BusyProvider.google,
          BusyProvider.microsoft,
          BusyProvider.nextcloud,
        ]) {
          for (var number = 1; number <= 2; number++) {
            final id = '${provider.name}:qa-$number';
            await f.accounts.upsertSignedInAccount(
              id: id,
              provider: provider,
              authority: provider == BusyProvider.nextcloud
                  ? 'https://cloud$number.example.test/team'
                  : null,
              providerAccountId: provider == BusyProvider.nextcloud
                  ? 'qa-user'
                  : 'qa-$number',
              displayName:
                  'Quality Assurance $number — a deliberately long synthetic account identity',
              email: provider == BusyProvider.nextcloud
                  ? null
                  : 'qa-$number@example.test',
              grantedScopes: '',
            );
            if (provider != BusyProvider.nextcloud) {
              await f.database.customStatement(
                'INSERT INTO domain_sync_schedules(account_id,domain,last_successful_pull_utc) VALUES (?, ?, ?)',
                [id, 'tasks', '2026-10-19T12:00:00Z'],
              );
            }
            if (provider == BusyProvider.nextcloud) {
              await f.database
                  .into(f.database.davCollections)
                  .insert(
                    DavCollectionsCompanion.insert(
                      id: '$id:collection',
                      accountId: id,
                      hrefKey: '/team/calendar/',
                      requestUri:
                          'https://cloud$number.example.test/team/calendar/',
                      displayName: 'Team events and tasks $number',
                      resourceTypesJson: const Value(
                        '["{DAV:}collection","{urn:ietf:params:xml:ns:caldav}calendar"]',
                      ),
                      supportedComponentMask: const Value(3),
                      eventProjectionEnabled: const Value(true),
                      taskProjectionEnabled: const Value(true),
                      currentUserPrivilegesJson: const Value(
                        '["{DAV:}read","{DAV:}write-properties"]',
                      ),
                      createdAtUtc: '2026-10-19T12:00:00Z',
                      updatedAtUtc: '2026-10-19T12:00:00Z',
                    ),
                  );
            } else {
              await CalendarRepository(database: f.database).upsertSource(
                accountId: id,
                source: CalendarSourceDto(
                  provider: provider,
                  providerCalendarId: provider == BusyProvider.microsoft
                      ? MicrosoftSharedPrimaryCalendarAddress(
                          owner: 'owner-$number@example.test',
                          graphCalendarId: 'qa',
                        ).sourceCalendarId
                      : 'qa-$number',
                  summary: provider == BusyProvider.google
                      ? 'QA calendar $number'
                      : 'Shared primary QA calendar $number',
                  primaryCalendar:
                      provider == BusyProvider.google && number == 1,
                  readOnly: provider == BusyProvider.microsoft,
                  accessRole: provider == BusyProvider.microsoft
                      ? 'unavailable'
                      : 'owner',
                  rawJson: const {'hidden': false},
                ),
              );
              if (provider == BusyProvider.google && number == 2) {
                await CalendarRepository(database: f.database)
                    .setSourceProviderHidden(
                      CalendarRepository.sourceId(
                        accountId: id,
                        provider: provider,
                        providerCalendarId: 'qa-$number',
                      ),
                      true,
                    );
              }
            }
          }
        }
        f.davSecrets['independent-qa'] = jsonEncode({
          'version': 1,
          'server': 'https://contacts.example.test',
          'username': 'independent-qa',
          'password': 'synthetic-only',
          'readOnly': true,
        });
        await f.store.write(
          (tx) => tx.putAccount(
            const ContactAccount(
              id: 'independent-qa',
              provider: ContactProviderKind.carddav,
              displayName: 'Independent QA address book',
              subject: 'independent-qa',
              enabled: false,
              grantedScopes: {'carddav:read'},
            ),
          ),
        );
      });
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(f.database),
          gtkHeaderIconServiceProvider.overrideWithValue(icons),
          initialGtkWindowPreferencesProvider.overrideWithValue(
            windowPreferences,
          ),
          secretStoreProvider.overrideWithValue(secrets),
          busyMaxContactsStoreProvider.overrideWithValue(f.store),
          busyMaxContactsControllerProvider.overrideWithValue(f.controller),
          localSettingsStoreProvider.overrideWithValue(
            InMemoryLocalSettingsStore(),
          ),
          buildConfigProvider.overrideWithValue(syntheticDesktopConfig()),
          selectedAccountIdProvider.overrideWith((ref) => 'google:qa-1'),
          signedInSyncRunnerProvider.overrideWithValue((_, _) async {}),
        ],
      );
      final font = await tester.runAsync(
        () => const GtkFontService().getGtkFont(),
      );
      for (final brightness in [Brightness.light, Brightness.dark]) {
        await tester.runAsync(
          () => const GtkThemeService().setPreferDark(
            brightness == Brightness.dark,
          ),
        );
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              locale: const Locale('en'),
              localizationsDelegates: const [
                ...AppLocalizations.localizationsDelegates,
                ...GlobalUbuntuLocalizations.delegates,
              ],
              supportedLocales: AppLocalizations.supportedLocales,
              theme: BusyMaxYaruTheme.build(
                brightness: brightness,
                accentColor: YaruColors.orange,
                gtkFontFamily: font?.family,
                gtkFontSize: font?.size,
              ),
              builder: (context, child) => GtkHeaderIconScope(
                service: icons,
                child: LinuxWindowHost(child: child!),
              ),
              home: const SettingsScreen(initialPage: SettingsPage.accounts),
            ),
          ),
        );
        await _resize(tester, 1200, 1000);
        await tester.pumpAndSettle();
        final theme = brightness.name;
        await tester.ensureVisible(find.text('Add Nextcloud account'));
        await _capture(tester, '$output/$theme-accounts-top.png');
        for (final label in [
          'Add Google account',
          'Add Microsoft account',
          'Add Nextcloud account',
        ]) {
          expect(find.text(label), findsOneWidget);
        }
        await tester.ensureVisible(find.text('QA calendar 1'));
        await _capture(tester, '$output/$theme-google.png');
        await tester.ensureVisible(find.text('QA calendar 2'));
        await _capture(tester, '$output/$theme-google-pending.png');
        expect(find.text('Google visibility change pending'), findsOneWidget);
        await tester.ensureVisible(find.text('Shared primary QA calendar 1'));
        await _capture(tester, '$output/$theme-microsoft-cached-error.png');
        await tester.ensureVisible(
          find.byKey(
            const ValueKey('dav-collection-nextcloud:qa-1:collection'),
          ),
        );
        await _capture(tester, '$output/$theme-nextcloud.png');
        expect(
          tester
              .getSemantics(
                find.descendant(
                  of: find.byKey(
                    const ValueKey(
                      'dav-collection-settings-nextcloud:qa-1:collection',
                    ),
                  ),
                  matching: find.byType(IconButton),
                ),
              )
              .label,
          contains('Team events and tasks 1'),
        );
        await tester.ensureVisible(find.text('Independent QA address book'));
        await _capture(tester, '$output/$theme-independent-contacts.png');
        await _resize(tester, 640, 900);
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.byKey(const ValueKey('settings-account-heading-nextcloud:qa-2')),
        );
        await _capture(tester, '$output/$theme-narrow-nextcloud-identity.png');
        await tester.ensureVisible(
          find.byKey(
            const ValueKey('dav-collection-nextcloud:qa-2:collection'),
          ),
        );
        await _capture(tester, '$output/$theme-narrow-nextcloud.png');
        await tester.ensureVisible(find.text('Add Nextcloud account'));
        await tester.pumpAndSettle();
        Focus.of(tester.element(find.text('Add Nextcloud account')))
            .requestFocus();
        await tester.pumpAndSettle();
        expect(
          FocusManager.instance.primaryFocus!.context!
              .findAncestorWidgetOfExactType<BusyMaxActionRow>()
              ?.title,
          'Add Nextcloud account',
        );
        final visited = <String>{'Add Nextcloud account'};
        const additions = {
          'Add Google account',
          'Add Microsoft account',
          'Add Nextcloud account',
        };
        // Native header/menu controls participate in traversal as well.
        // Verify reachability without imposing a replacement traversal policy.
        for (
          var step = 0;
          step < 20 && !visited.containsAll(additions);
          step++
        ) {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pumpAndSettle();
          final title = FocusManager.instance.primaryFocus?.context
              ?.findAncestorWidgetOfExactType<BusyMaxActionRow>()
              ?.title;
          if (title != null) visited.add(title);
        }
        await _capture(tester, '$output/$theme-keyboard-focus.png');
        expect(visited, containsAll(additions));
        final remove = find.byKey(const ValueKey('remove-account-google:qa-1'));
        await tester.ensureVisible(remove);
        await tester.tap(remove);
        await tester.pumpAndSettle();
        await _capture(tester, '$output/$theme-remove-confirmation.png');
        await tester.tap(find.text('Cancel').last);
        await tester.pumpAndSettle();
        expect(
          (await tester.runAsync(f.accounts.listVisibleAccounts))!,
          hasLength(6),
        );
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      container.dispose();
      icons.dispose();
      semantics.dispose();
      await tester.runAsync(f.close);
    },
    skip: output == null,
  );
}

Future<void> _resize(WidgetTester tester, int width, int height) async {
  await tester.runAsync(() async {
    final result = await Process.run('/usr/bin/python3', [
      '-c',
      r'''import ctypes, re, subprocess, sys
x = ctypes.CDLL('libX11.so.6')
x.XOpenDisplay.argtypes = [ctypes.c_char_p]
x.XOpenDisplay.restype = ctypes.c_void_p
x.XResizeWindow.argtypes = [ctypes.c_void_p, ctypes.c_ulong, ctypes.c_uint, ctypes.c_uint]
x.XFlush.argtypes = [ctypes.c_void_p]
x.XCloseDisplay.argtypes = [ctypes.c_void_p]
tree = subprocess.check_output(['/usr/bin/xwininfo', '-root', '-tree'], text=True)
windows = re.findall(r'^\s*(0x[0-9a-f]+) "BusyMax":.*? (\d+)x(\d+)[+-]', tree, re.MULTILINE)
main = [item for item in windows if int(item[1]) > 300 and int(item[2]) > 300]
assert len(main) == 1, 'Expected one BusyMax window on the isolated display'
connection = x.XOpenDisplay(None)
x.XResizeWindow(connection, int(main[0][0], 16), int(sys.argv[1]), int(sys.argv[2]))
x.XFlush(connection)
x.XCloseDisplay(connection)
''',
      '$width',
      '$height',
    ]);
    expect(result.exitCode, 0, reason: result.stderr.toString());
  });
  await tester.pumpAndSettle();
}

Future<void> _capture(WidgetTester tester, String path) async {
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    // Capture the isolated application window, including its modal overlays.
    final result = await Process.run('/usr/bin/python3', [
      '-c',
      r'''import sys, gi, re, subprocess
gi.require_version('Gdk', '3.0')
from gi.repository import Gdk
tree = subprocess.check_output(['/usr/bin/xwininfo', '-root', '-tree'], text=True)
windows = re.findall(r'^\s*(0x[0-9a-f]+) "BusyMax":.*? (\d+)x(\d+)[+-]', tree, re.MULTILINE)
main = [item for item in windows if int(item[1]) > 300 and int(item[2]) > 300]
assert len(main) == 1, 'Expected one isolated BusyMax application window'
info = subprocess.check_output(['/usr/bin/xwininfo', '-id', main[0][0]], text=True)
def field(name):
    return int(re.search(name + r':\s*(-?\d+)', info).group(1))
window = Gdk.get_default_root_window()
pixbuf = Gdk.pixbuf_get_from_window(window, field('Absolute upper-left X'), field('Absolute upper-left Y'), field('Width'), field('Height'))
pixbuf.savev(sys.argv[1], 'png', [], [])
''',
      path,
    ]);
    expect(result.exitCode, 0, reason: result.stderr.toString());
  });
}
