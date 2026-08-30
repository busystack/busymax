import 'package:busymax/src/features/accounts/data/accounts_repository.dart';
import 'package:busymax/src/features/accounts/domain/account_collection_creation_capabilities.dart';
import 'package:busymax/src/features/connectivity/network_connectivity_service.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('provider matrix resolves distinct collection creation modes', () {
    expect(
      accountCollectionCreationModes(BusyProvider.google),
      _hasModes(
        CalendarCollectionCreationMode.cloudPendingOperation,
        TaskListCreationMode.cloudPendingOperation,
      ),
    );
    expect(
      accountCollectionCreationModes(BusyProvider.microsoft),
      _hasModes(
        CalendarCollectionCreationMode.cloudPendingOperation,
        TaskListCreationMode.cloudPendingOperation,
      ),
    );
    expect(
      accountCollectionCreationModes(BusyProvider.nextcloud),
      _hasModes(
        CalendarCollectionCreationMode.nextcloudDav,
        TaskListCreationMode.nextcloudDav,
      ),
    );
    for (final provider in [BusyProvider.appleICloud, BusyProvider.webCal]) {
      expect(
        accountCollectionCreationModes(provider),
        _hasModes(
          CalendarCollectionCreationMode.unavailable,
          TaskListCreationMode.unavailable,
        ),
      );
    }
  });

  test('account service switches omit their corresponding actions', () {
    final withoutCalendars = _resolve(
      _account(BusyProvider.google, calendarsEnabled: false),
    );
    final withoutTasks = _resolve(
      _account(BusyProvider.microsoft, tasksEnabled: false),
    );

    expect(
      withoutCalendars.calendarMode,
      CalendarCollectionCreationMode.unavailable,
    );
    expect(withoutCalendars.supportsTaskListCreation, isTrue);
    expect(withoutTasks.supportsCalendarCreation, isTrue);
    expect(withoutTasks.taskListMode, TaskListCreationMode.unavailable);
  });

  test('reconnect and disconnected states disable supported entries', () {
    for (final authState in [
      accountAuthStateReauthRequired,
      accountAuthStateTemporarilyUnavailable,
    ]) {
      final capabilities = _resolve(
        _account(BusyProvider.google, authState: authState),
      );
      expect(capabilities.supportsCalendarCreation, isTrue);
      expect(capabilities.supportsTaskListCreation, isTrue);
      expect(capabilities.calendarActionEnabled, isFalse);
      expect(capabilities.taskListActionEnabled, isFalse);
    }
  });

  test('offline behavior preserves cloud queueing and disables DAV', () {
    for (final provider in [BusyProvider.google, BusyProvider.microsoft]) {
      final capabilities = _resolve(
        _account(provider),
        network: NetworkAvailability.offline,
      );
      expect(capabilities.calendarActionEnabled, isTrue);
      expect(capabilities.taskListActionEnabled, isTrue);
    }

    final nextcloud = _resolve(
      _account(BusyProvider.nextcloud),
      network: NetworkAvailability.offline,
    );
    expect(nextcloud.calendarMode, CalendarCollectionCreationMode.nextcloudDav);
    expect(nextcloud.taskListMode, TaskListCreationMode.nextcloudDav);
    expect(nextcloud.calendarActionEnabled, isFalse);
    expect(nextcloud.taskListActionEnabled, isFalse);
  });

  test('running state disables only the matching creation action', () {
    final capabilities = AccountCollectionCreationCapabilities.resolve(
      account: _account(BusyProvider.google),
      networkAvailability: NetworkAvailability.online,
      calendarCreationRunning: true,
    );

    expect(capabilities.calendarActionEnabled, isFalse);
    expect(capabilities.taskListActionEnabled, isTrue);
  });
}

Matcher _hasModes(
  CalendarCollectionCreationMode calendarMode,
  TaskListCreationMode taskListMode,
) => isA<AccountCollectionCreationModes>()
    .having((value) => value.calendarMode, 'calendarMode', calendarMode)
    .having((value) => value.taskListMode, 'taskListMode', taskListMode);

AccountCollectionCreationCapabilities _resolve(
  AccountEntity account, {
  NetworkAvailability network = NetworkAvailability.online,
}) => AccountCollectionCreationCapabilities.resolve(
  account: account,
  networkAvailability: network,
);

AccountEntity _account(
  BusyProvider provider, {
  bool calendarsEnabled = true,
  bool tasksEnabled = true,
  String authState = accountAuthStateSignedIn,
}) => AccountEntity(
  id: provider.storageValue,
  provider: provider,
  authority: 'https://example.test',
  providerAccountId: 'account',
  authState: authState,
  calendarsEnabled: calendarsEnabled,
  tasksEnabled: tasksEnabled,
);
