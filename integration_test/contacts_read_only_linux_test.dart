import 'dart:io';
import 'dart:ui' as ui;

import 'package:busystack_contacts/busystack_contacts.dart';
import 'package:busymax/main_linux.dart' as app;
import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/features/schedule/presentation/schedule_workspace.dart';
import 'package:busymax/src/features/settings/presentation/settings_screen.dart';
import 'package:yaru/yaru.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final output = Platform.environment['BUSYMAX_ACCEPTANCE_ROOT'];
  testWidgets(
    'isolated native Linux Settings exposes cached read-only contacts and source selection',
    (tester) async {
      expect(Platform.environment['XDG_DATA_HOME'], '$output/data');
      await tester.runAsync(() => app.main(const []));
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(ScheduleWorkspace)),
      );
      final controller = container.read(busyMaxContactsControllerProvider);
      await tester.runAsync(() async {
        await controller.start();
        // Synthetic local cache only. No account tokens, provider registrations,
        // external requests or owner's application data are used in this session.
        const source = ContactSource(
          accountId: 'isolated-cache',
          id: 'book',
          provider: ContactProviderKind.carddav,
          kind: ContactSourceKind.carddavAddressBook,
          name: 'Isolated cached source',
          remotePath: 'https://fixture.invalid/book/',
          capabilities: ContactCapabilities(
            create: true,
            update: true,
            delete: true,
            photoWrite: true,
          ),
          canRename: true,
          canRemove: true,
        );
        const identity = ContactIdentity(
          accountId: 'isolated-cache',
          provider: ContactProviderKind.carddav,
          sourceId: 'book',
          remoteId: 'ada.vcf',
        );
        final vcard = newVcard(
          const ContactPatch(
            name: FieldEdit.set(ContactName(display: 'Ada Isolated')),
            emails: FieldEdit.set([ContactValue('ada@example.test')]),
          ),
          uid: 'fixture',
        );
        await controller.store.write((tx) async {
          await tx.putAccount(
            const ContactAccount(
              id: 'isolated-cache',
              provider: ContactProviderKind.carddav,
              displayName: 'Isolated attendee cache',
              subject: 'fixture',
              grantedScopes: {'carddav:write'},
            ),
          );
          await tx.putSource(source);
          for (var index = 0; index < 200; index++) {
            final id = ContactIdentity(
              accountId: source.accountId,
              provider: source.provider,
              sourceId: source.id,
              remoteId: 'no-email-$index.vcf',
            );
            final card = newVcard(
              ContactPatch(
                name: FieldEdit.set(ContactName(display: 'Ada $index')),
              ),
              uid: 'no-email-$index',
            );
            await tx.putContact(
              CardDavContactRecord(
                identity: id,
                vcard: card,
                revision: '"cached"',
                projection: projectVcard(id, card),
              ),
            );
          }
          await tx.putContact(
            CardDavContactRecord(
              identity: identity,
              vcard: vcard,
              revision: '"cached"',
              projection: projectVcard(identity, vcard),
            ),
          );
        });
        expect(
          (await controller.sourceSettings()).single.source.capabilities.update,
          isFalse,
        );
        expect(
          (await controller.suggestAttendees('ada')).single.email,
          'ada@example.test',
        );
      });
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);
      final accounts = find.text('Accounts');
      if (accounts.evaluate().isNotEmpty) {
        await tester.tap(accounts.first);
        await tester.pumpAndSettle();
      }
      final addContacts = find.byKey(const ValueKey('add-carddav-contacts'));
      await tester.ensureVisible(addContacts);
      await tester.tap(addContacts);
      await tester.pumpAndSettle();
      expect(find.text('Enable contact editing'), findsNothing);
      expect(find.text('Read and write access'), findsNothing);
      expect(
        find.text('Read-only contacts for attendee suggestions'),
        findsWidgets,
      );
      await tester.tap(find.text('Cancel').last);
      await tester.pumpAndSettle();
      final accountEntry = find.byKey(
        const ValueKey('contact-account-entry-isolated-cache'),
      );
      await tester.ensureVisible(accountEntry);
      await tester.tap(accountEntry);
      await tester.pumpAndSettle();
      expect(find.text('Enable contact editing'), findsNothing);
      expect(find.text('Read and write access'), findsNothing);
      final setting = (await tester.runAsync(controller.sourceSettings))!
          .single;
      final toggle = find.byKey(
        ValueKey('contact-source-${setting.source.key}'),
      );
      await tester.ensureVisible(toggle);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(tester.widget<YaruSwitch>(toggle).value, isFalse);
      await tester.runAsync(() async {
        expect(await controller.suggestAttendees('ada'), isEmpty);
      });
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        expect(
          (await controller.suggestAttendees('ada')).single.email,
          'ada@example.test',
        );
      });
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await tester.pumpAndSettle();
      expect(accountEntry, findsOneWidget);
      await tester.ensureVisible(addContacts);
      await tester.tap(find.byKey(const ValueKey('add-carddav-contacts')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('carddav-contacts-label')),
        findsOneWidget,
      );
      expect(find.byType(SwitchListTile), findsNothing);
      expect(
        find.text('Read-only contacts for attendee suggestions'),
        findsWidgets,
      );
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byType(RepaintBoundary).first,
      );
      final picture = await boundary.toImage();
      try {
        final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
        await File('$output/contacts-read-only-settings.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
      } finally {
        picture.dispose();
      }
      await tester.tap(find.text('Cancel').last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    skip: output == null,
  );
}
