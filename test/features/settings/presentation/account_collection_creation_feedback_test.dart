import 'dart:async';

import 'package:busymax/l10n/generated/app_localizations.dart';
import 'package:busymax/l10n/generated/app_localizations_en.dart';
import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/app/busymax_design.dart';
import 'package:busymax/src/dav/mutation/dav_collection_creation_failure.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/settings/presentation/account_collection_creation_feedback.dart';
import 'package:busymax/src/features/sync/account_sync_activity.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../test_localized_app.dart';

void main() {
  testWidgets(
    'stored rejection appears after restart while synchronization is offline',
    (tester) async {
      final db = AppDatabase.memoryForTests();
      addTearDown(db.close);
      await db
          .into(db.accounts)
          .insert(
            AccountsCompanion.insert(
              id: 'account',
              provider: 'caldav',
              providerAccountId: 'user',
              authority: 'https://example.test/',
              credentialKind: 'caldav_password',
              createdAtUtc: 'now',
              updatedAtUtc: 'now',
            ),
          );
      final failure = _failure(taskList: false);
      await db
          .into(db.davCollectionCreations)
          .insert(failure.operation.toCompanion(false));
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);
      final activity = container.read(accountSyncActivityProvider);
      await expectLater(
        activity.run('account', 'dav', () async => throw StateError('offline')),
        throwsStateError,
      );
      expect(activity.collectionCreationFailures('account'), isEmpty);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: localizedTestApp(
            child: Scaffold(
              body: AccountCollectionCreationFeedback(
                accountId: 'account',
                dismissButtonBuilder: (_, onPressed, label) =>
                    TextButton(onPressed: onPressed, child: Text(label)),
              ),
            ),
          ),
        ),
      );
      await tester.runAsync(() async {
        await container.read(
          storedDavCollectionCreationNoticesProvider('account').future,
        );
      });
      await tester.pumpAndSettle();
      expect(find.text('Requested collection'), findsOneWidget);
      await tester.tap(
        find.text(AppLocalizationsEn().notificationDismissAction),
      );
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 30));
      });
      await tester.pumpAndSettle();
      expect(find.text('Requested collection'), findsNothing);
      expect(
        (await db.select(db.davCollectionCreations).getSingle()).state,
        'rejected',
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final platform in ['linux', 'windows', 'android']) {
    for (final taskList in [false, true]) {
      testWidgets(
        '$platform account shows operation rejection while pull stays successful; tasks=$taskList',
        (tester) async {
          final activity = AccountSyncActivity();
          var acknowledgment = Completer<bool>();
          var acknowledgments = 0;
          final container = ProviderContainer(
            overrides: [
              storedDavCollectionCreationNoticesProvider.overrideWith(
                (ref, id) => Stream.value([]),
              ),
              accountSyncActivityProvider.overrideWith((ref) => activity),
              acknowledgeDavCollectionCreationNoticeProvider.overrideWithValue((
                accountId,
                operationId,
              ) async {
                expect(accountId, 'account');
                expect(operationId, 'creation');
                acknowledgments++;
                final saved = await acknowledgment.future;
                if (saved) {
                  activity.setCollectionCreationFailures(accountId, []);
                }
                return saved;
              }),
            ],
          );
          addTearDown(container.dispose);
          final l10n = AppLocalizationsEn();
          final content = AccountCollectionCreationFeedback(
            accountId: 'account',
            dismissButtonBuilder: (_, onPressed, label) => switch (platform) {
              'windows' => fluent.Button(
                onPressed: onPressed,
                child: Text(label),
              ),
              'linux' => BusyMaxPushButton.standard(
                onPressed: onPressed,
                child: Text(label),
              ),
              _ => TextButton(onPressed: onPressed, child: Text(label)),
            },
          );
          Widget host(Widget child) => platform == 'windows'
              ? fluent.FluentApp(
                  localizationsDelegates: const [AppLocalizations.delegate],
                  supportedLocales: AppLocalizations.supportedLocales,
                  home: fluent.ScaffoldPage(content: child),
                )
              : localizedTestApp(child: Scaffold(body: child));
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: host(content),
            ),
          );
          expect(find.text('Requested collection'), findsNothing);
          activity.setCollectionCreationFailures('account', [
            _failure(taskList: taskList),
          ]);
          await tester.pumpAndSettle();
          expect(find.text('Requested collection'), findsOneWidget);
          expect(
            find.text(
              taskList
                  ? l10n.taskListCreateFailed(l10n.davCollectionCreationDenied)
                  : l10n.calendarCreateFailed(l10n.davCollectionCreationDenied),
            ),
            findsOneWidget,
          );
          expect(find.text(l10n.syncFailureNotificationTitle), findsNothing);
          expect(find.textContaining('Nextcloud'), findsNothing);
          final dismiss = find.byKey(
            const ValueKey((
              'dismiss-collection-creation',
              'account',
              'creation',
            )),
          );
          expect(dismiss, findsOneWidget);
          await tester.tap(dismiss);
          await tester.pump();
          expect(acknowledgments, 1);
          expect(find.text('Requested collection'), findsOneWidget);
          acknowledgment.completeError(StateError('persistence unavailable'));
          await tester.pumpAndSettle();
          expect(find.text(l10n.operationFailed), findsOneWidget);
          expect(find.text('Requested collection'), findsOneWidget);
          acknowledgment = Completer<bool>();
          await tester.tap(dismiss);
          await tester.pump();
          acknowledgment.complete(true);
          await tester.pumpAndSettle();
          expect(acknowledgments, 2);
          expect(find.text('Requested collection'), findsNothing);
          activity.setCollectionCreationFailures('account', [
            _failure(taskList: taskList),
          ]);
          await tester.pumpAndSettle();
          await activity.run('account', 'dav', () async {});
          await tester.pump();
          expect(activity.failure('account', 'dav'), isNull);
          expect(find.text('Requested collection'), findsOneWidget);
          expect(activity.collectionCreationFailures('other-account'), isEmpty);
          activity.setCollectionCreationFailures('account', [
            _failure(taskList: taskList, pending: true),
          ]);
          await tester.pumpAndSettle();
          expect(find.text(l10n.davCollectionCreationPending), findsOneWidget);
          expect(dismiss, findsNothing);
          expect(find.textContaining('Could not create'), findsNothing);
          activity.setCollectionCreationFailures('account', []);
          await tester.pumpAndSettle();
          expect(find.text('Requested collection'), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}

DavCollectionCreationFailure _failure({
  required bool taskList,
  bool pending = false,
}) => DavCollectionCreationFailure.fromStored(
  DavCollectionCreation(
    id: 'creation',
    accountId: 'account',
    authority: 'https://example.test/',
    homeUri: 'https://example.test/home/',
    targetUri: 'https://example.test/home/creation/',
    displayName: 'Requested collection',
    componentsJson: taskList ? '["VTODO"]' : '["VEVENT"]',
    state: pending ? 'dispatched' : 'rejected',
    lastErrorKind: 'authorization',
    lastErrorCode: 'DavPermissionDenied',
    lastErrorStatus: 403,
    createdAtUtc: '2026-11-02T00:00:00Z',
  ),
);
