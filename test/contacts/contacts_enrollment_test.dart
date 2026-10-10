import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';

import 'package:busystack_contacts/busystack_contacts.dart';
import 'package:busymax/src/contacts/busymax_contacts_controller.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/contacts_fixture.dart';

void main() {
  for (final provider in [BusyProvider.google, BusyProvider.microsoft]) {
    test(
      '$provider first enrollment, enabled upgrade and reconnect synchronize',
      () async {
        final fixture = ContactsFixture(AppDatabase.memoryForTests());
        addTearDown(fixture.close);
        await fixture.addParent(provider);
        await fixture.controller.enableLinkedContacts(provider.name);
        final id = BusyMaxContactsController.linkedContactAccountId(
          provider.name,
        );
        for (final writable in [false, true, true]) {
          await fixture.controller.enableLinkedContacts(
            provider.name,
            writable: writable,
          );
          await fixture.controller.synchronizeAccount(id);
          final account = await fixture.store.read((tx) => tx.account(id));
          expect(account!.enabled, isTrue);
          expect(
            (await fixture.controller.suggestAttendees(
              'ada',
              busyMaxAccountId: provider.name,
            )).single.email,
            'ada@example.test',
          );
        }
        final account = await fixture.store.read((tx) => tx.account(id));
        expect(account!.generation, 3);
        expect(
          account.grantedScopes,
          contains(
            provider == BusyProvider.google
                ? 'https://www.googleapis.com/auth/contacts'
                : 'Contacts.ReadWrite',
          ),
        );
        final before = account.toJson();
        fixture.authorizationFailure = StateError(
          'cancelled or invalid consent',
        );
        await expectLater(
          fixture.controller.enableLinkedContacts(
            provider.name,
            writable: true,
          ),
          throwsStateError,
        );
        expect(
          (await fixture.store.read((tx) => tx.account(id)))!.toJson(),
          before,
        );
        await fixture.controller.synchronizeAccount(id);
        expect(
          (await fixture.controller.suggestAttendees(
            'ada',
            busyMaxAccountId: provider.name,
          )),
          hasLength(1),
        );
      },
    );
  }
  test(
    'post-commit preference changes immediately change lookup eligibility',
    () async {
      final fixture = ContactsFixture(AppDatabase.memoryForTests());
      addTearDown(fixture.close);
      await fixture.addParent(BusyProvider.google);
      await fixture.controller.enableLinkedContacts('google');
      await fixture.controller.synchronizeAccount('contacts:google');
      final source = (await fixture.controller.sourceSettings()).single.source;
      final changed = fixture.controller.changes.first;
      await fixture.controller.setSourceEnabled(source.key, enabled: false);
      await changed;
      expect(
        (await fixture.controller.sourceSettings()).single.enabled,
        isFalse,
      );
      expect(
        await fixture.controller.suggestAttendees(
          'ada',
          busyMaxAccountId: 'google',
        ),
        isEmpty,
      );
      expect(
        (await fixture.store.read((tx) => tx.account('contacts:google')))!
            .enabled,
        isTrue,
      );
      expect(await fixture.store.read((tx) => tx.count()), 1);
    },
  );
  test(
    'manual failure remains awaitable and close drains failure safely',
    () async {
      final fixture = ContactsFixture(AppDatabase.memoryForTests());
      await fixture.addParent(BusyProvider.google);
      await fixture.controller.enableLinkedContacts('google');
      await fixture.controller.synchronizeAccount('contacts:google');
      fixture.offline = true;
      final failing = fixture.controller.synchronizeAccount('contacts:google');
      final assertion = expectLater(failing, throwsA(isA<ContactsException>()));
      await assertion;
      expect(
        (await fixture.store.read((tx) => tx.account('contacts:google')))!
            .errorCode,
        isNotNull,
      );
      await fixture.controller.close().timeout(const Duration(seconds: 3));
      expect(
        await fixture.database.customSelect('SELECT 1').getSingle(),
        isNotNull,
      );
      await fixture.database.close();
    },
  );
  for (final provider in [BusyProvider.google, BusyProvider.microsoft]) {
    for (final failure in ['identity', 'grant', 'persistence']) {
      test(
        '$provider $failure upgrade preserves enabled account, scopes and cache',
        () async {
          final f = ContactsFixture(AppDatabase.memoryForTests());
          addTearDown(f.close);
          await f.addParent(provider);
          await f.controller.enableLinkedContacts(provider.name);
          await f.controller.synchronizeAccount('contacts:${provider.name}');
          final before = (await f.store.read(
            (tx) => tx.account('contacts:${provider.name}'),
          ))!.toJson();
          final parentBefore = (await f.accounts.accountById(provider.name))!
              .grantedScopes;
          if (failure == 'identity') f.consentSubject = 'wrong-person';
          if (failure == 'grant') f.consentScopes = parentBefore;
          if (failure == 'persistence') {
            await f.database.customStatement(
              "CREATE TRIGGER reject_contacts_update BEFORE UPDATE ON bm_contact_accounts BEGIN SELECT RAISE(ABORT, 'fixture durable write rejected'); END",
            );
          }
          await expectLater(
            f.controller.enableLinkedContacts(provider.name, writable: true),
            throwsA(isA<Object>()),
          );
          if (failure == 'persistence') {
            await f.database.customStatement(
              'DROP TRIGGER reject_contacts_update',
            );
          }
          expect(
            (await f.store.read(
              (tx) => tx.account('contacts:${provider.name}'),
            ))!.toJson(),
            before,
          );
          expect(
            (await f.accounts.accountById(provider.name))!.grantedScopes,
            parentBefore,
          );
          await f.controller.synchronizeAccount('contacts:${provider.name}');
          expect(
            await f.controller.suggestAttendees(
              'ada',
              busyMaxAccountId: provider.name,
            ),
            hasLength(1),
          );
        },
      );
    }
    test(
      '$provider disk restart retains enabled upgraded account and source preference',
      () async {
        final profile = await Directory.systemTemp.createTemp(
          'busymax-enrollment-restart-',
        );
        addTearDown(() => profile.delete(recursive: true));
        ContactsFixture open() => ContactsFixture(
          AppDatabase(NativeDatabase(File('${profile.path}/app.db'))),
        );
        var f = open();
        await f.addParent(provider);
        await f.controller.enableLinkedContacts(provider.name, writable: true);
        await f.controller.synchronizeAccount('contacts:${provider.name}');
        final source = (await f.controller.sourceSettings()).single.source;
        await f.controller.setSourceEnabled(source.key, enabled: false);
        await f.close();
        f = open();
        addTearDown(f.close);
        await f.controller.start();
        await f.controller.synchronizeAccount('contacts:${provider.name}');
        expect(
          (await f.store.read((tx) => tx.account('contacts:${provider.name}')))!
              .enabled,
          isTrue,
        );
        expect(
          await f.controller.suggestAttendees(
            'ada',
            busyMaxAccountId: provider.name,
          ),
          isEmpty,
        );
        await f.controller.setSourceEnabled(source.key, enabled: true);
        expect(
          await f.controller.suggestAttendees(
            'ada',
            busyMaxAccountId: provider.name,
          ),
          hasLength(1),
        );
      },
    );
    test(
      '$provider close cancels consent and drains owned enrollment',
      () async {
        final f = ContactsFixture(AppDatabase.memoryForTests());
        await f.addParent(provider);
        f.consentPause = Completer<void>();
        final enrollment = f.controller.enableLinkedContacts(provider.name);
        final assertion = expectLater(
          enrollment,
          throwsA(isA<ContactsException>()),
        );
        await Future<void>.delayed(const Duration(milliseconds: 40));
        await f.controller.close().timeout(const Duration(seconds: 3));
        await assertion;
        expect(
          await f.database.customSelect('SELECT 1').getSingle(),
          isNotNull,
        );
        await f.database.close();
      },
    );
  }
  test(
    'scheduled failure is observed while another account synchronizes',
    () async {
      final uncaught = <Object>[];
      final completion = Completer<void>();
      runZonedGuarded(() async {
        try {
          final f = ContactsFixture(
            AppDatabase.memoryForTests(),
            syncInterval: const Duration(milliseconds: 20),
          );
          try {
            await f.addParent(BusyProvider.google);
            await f.addParent(BusyProvider.microsoft);
            await f.controller.enableLinkedContacts('google');
            await f.controller.enableLinkedContacts('microsoft');
            await f.controller.synchronizeAll();
            f.googleOffline = true;
            await Future<void>.delayed(const Duration(milliseconds: 1100));
            expect(
              (await f.store.read((tx) => tx.account('contacts:google')))!
                  .errorCode,
              isNotNull,
            );
            expect(
              (await f.store.read((tx) => tx.account('contacts:microsoft')))!
                  .errorCode,
              isNull,
            );
            expect(
              await f.controller.suggestAttendees(
                'ada',
                busyMaxAccountId: 'microsoft',
              ),
              hasLength(1),
            );
            await expectLater(
              f.controller.synchronizeAccount('contacts:google'),
              throwsA(isA<ContactsException>()),
            );
          } finally {
            await f.close();
          }
          completion.complete();
        } catch (e, s) {
          completion.completeError(e, s);
        }
      }, (e, s) => uncaught.add(e));
      await completion.future.timeout(const Duration(seconds: 5));
      expect(uncaught, isEmpty);
    },
  );
}
