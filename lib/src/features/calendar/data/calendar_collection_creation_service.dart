import '../../../dav/mutation/dav_calendar_collection_mutation_service.dart';
import '../../accounts/data/accounts_repository.dart';
import '../../accounts/domain/account_collection_creation_capabilities.dart';
import 'calendar_repository.dart';

enum CalendarCollectionCreationOutcome {
  queued,
  created,
  createdRefreshPending,
}

final class CalendarCollectionCreationResult {
  const CalendarCollectionCreationResult({
    required this.outcome,
    this.localSourceId,
  });

  final CalendarCollectionCreationOutcome outcome;
  final String? localSourceId;
}

final class CalendarCollectionCreationException implements Exception {
  const CalendarCollectionCreationException(this.safeMessage);

  final String safeMessage;

  @override
  String toString() => safeMessage;
}

typedef DavCalendarMutationClientForAccount =
    DavCalendarCollectionMutationClient Function(String accountId);

abstract interface class CalendarCollectionCreator {
  Future<CalendarCollectionCreationResult> createCalendar({
    required String accountId,
    required String title,
  });
}

/// Routes account-level calendar creation without mixing cloud pending
/// operations with DAV collection mutations.
final class CalendarCollectionCreationService
    implements CalendarCollectionCreator {
  CalendarCollectionCreationService({
    required AccountsRepository accountsRepository,
    required CalendarRepository calendarRepository,
    required DavCalendarMutationClientForAccount davClientForAccount,
    required void Function(String accountId) requestCloudSynchronization,
  }) : _accountsRepository = accountsRepository,
       _calendarRepository = calendarRepository,
       _davClientForAccount = davClientForAccount,
       _requestCloudSynchronization = requestCloudSynchronization;

  final AccountsRepository _accountsRepository;
  final CalendarRepository _calendarRepository;
  final DavCalendarMutationClientForAccount _davClientForAccount;
  final void Function(String accountId) _requestCloudSynchronization;

  @override
  Future<CalendarCollectionCreationResult> createCalendar({
    required String accountId,
    required String title,
  }) async {
    final trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty) {
      throw ArgumentError.value(title, 'title', 'A calendar name is required.');
    }
    final account = await _accountsRepository.accountById(accountId);
    if (account == null || !account.calendarsEnabled || !account.isSignedIn) {
      throw const CalendarCollectionCreationException(
        'Calendar creation is unavailable for this account.',
      );
    }
    final mode = accountCollectionCreationModes(account.provider).calendarMode;
    return switch (mode) {
      CalendarCollectionCreationMode.cloudPendingOperation =>
        _createCloudCalendar(accountId, trimmedTitle),
      CalendarCollectionCreationMode.nextcloudDav => _createNextcloudCalendar(
        accountId,
        trimmedTitle,
      ),
      CalendarCollectionCreationMode.unavailable =>
        throw const CalendarCollectionCreationException(
          'This provider does not support calendar creation.',
        ),
    };
  }

  Future<CalendarCollectionCreationResult> _createCloudCalendar(
    String accountId,
    String title,
  ) async {
    final sourceId = await _calendarRepository.createLocalSource(
      accountId: accountId,
      summary: title,
    );
    _requestCloudSynchronization(accountId);
    return CalendarCollectionCreationResult(
      outcome: CalendarCollectionCreationOutcome.queued,
      localSourceId: sourceId,
    );
  }

  Future<CalendarCollectionCreationResult> _createNextcloudCalendar(
    String accountId,
    String title,
  ) async {
    final result = await _davClientForAccount(
      accountId,
    ).createEventCalendar(title);
    return CalendarCollectionCreationResult(
      outcome: result.refreshPending
          ? CalendarCollectionCreationOutcome.createdRefreshPending
          : CalendarCollectionCreationOutcome.created,
    );
  }
}
