import 'package:busymax/l10n/generated/app_localizations.dart';
import 'package:busymax/l10n/generated/app_localizations_en.dart';
import 'package:busymax/src/app/app_bootstrap.dart';
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
  for (final platform in ['linux', 'windows', 'android']) {
    for (final taskList in [false, true]) {
      testWidgets(
        '$platform account shows operation rejection while pull stays successful; tasks=$taskList',
        (tester) async {
          final activity = AccountSyncActivity();
          final container = ProviderContainer(
            overrides: [
              accountSyncActivityProvider.overrideWith((ref) => activity),
            ],
          );
          addTearDown(container.dispose);
          final l10n = AppLocalizationsEn();
          const content = AccountCollectionCreationFeedback(
            accountId: 'account',
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
