import '../../../core/auth/authorization_attempt.dart';
import '../../../microsoft_calendar/microsoft_calendar_api_client.dart';
import '../../../microsoft_todo/oauth/microsoft_oauth_service.dart';
import '../../../providers/busy_provider.dart';
import '../../sync/calendar_sync_engine.dart';
import 'calendar_repository.dart';

enum MicrosoftSharedCalendarOpenOutcome { ready, rangeUnavailable }

final class MicrosoftSharedCalendarOpenResult {
  const MicrosoftSharedCalendarOpenResult({
    required this.sourceId,
    required this.outcome,
  });

  final String sourceId;
  final MicrosoftSharedCalendarOpenOutcome outcome;
}

/// User-initiated consent and owner-context discovery. A successful discovery
/// remains persisted even if the initial event range cannot be downloaded.
final class MicrosoftSharedCalendarService {
  const MicrosoftSharedCalendarService({
    required this.authorization,
    required this.clientForAccount,
    required this.repository,
    required this.retrieveMonth,
    required this.now,
  });

  final MicrosoftSharedCalendarAuthorization authorization;
  final MicrosoftCalendarApiClient Function(String) clientForAccount;
  final CalendarRepository repository;
  final CalendarMonthRetriever retrieveMonth;
  final DateTime Function() now;

  Future<MicrosoftSharedCalendarOpenResult> openPrimaryCalendar({
    required String accountId,
    required String owner,
    AuthorizationCancellation? cancellation,
  }) async {
    await authorization.authorizeSharedCalendarAccess(
      accountId,
      cancellation: cancellation,
    );
    final source = await clientForAccount(
      accountId,
    ).getSharedPrimaryCalendar(owner);
    await repository.upsertSource(
      accountId: accountId,
      source: source,
      reopenLocallyRemovedOwner: true,
    );
    final sourceId = CalendarRepository.sourceId(
      accountId: accountId,
      provider: BusyProvider.microsoft,
      providerCalendarId: source.providerCalendarId,
    );
    try {
      await retrieveMonth(
        accountId,
        BusyProvider.microsoft,
        now(),
        sourceIds: {sourceId},
      );
      return MicrosoftSharedCalendarOpenResult(
        sourceId: sourceId,
        outcome: MicrosoftSharedCalendarOpenOutcome.ready,
      );
    } on Object {
      return MicrosoftSharedCalendarOpenResult(
        sourceId: sourceId,
        outcome: MicrosoftSharedCalendarOpenOutcome.rangeUnavailable,
      );
    }
  }
}
