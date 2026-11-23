import '../features/accounts/data/accounts_repository.dart';
import '../features/calendar/data/calendar_repository.dart';
import '../providers/busy_provider.dart';

Uri? scheduleCalendarProviderWebUri(
  AccountEntity account,
  CalendarSourceEntity source,
) {
  if (source.accountId != account.id || source.provider != account.provider) {
    return null;
  }
  return switch (account.provider) {
    BusyProvider.google => Uri.https('calendar.google.com', '/calendar/u/0/r', {
      'cid': source.providerCalendarId,
    }),
    BusyProvider.microsoft => Uri.https(
      'outlook.live.com',
      '/calendar/0/view/month',
    ),
    BusyProvider.appleICloud => null,
    BusyProvider.nextcloud => _safeAccountWebUri(account.authority),
    BusyProvider.webCal => null,
    BusyProvider.caldav => null,
  };
}

Uri? scheduleTaskProviderWebUri(AccountEntity account) {
  return switch (account.provider) {
    BusyProvider.google => Uri.https('tasks.google.com', '/'),
    BusyProvider.microsoft => Uri.https('to-do.office.com', '/tasks/'),
    BusyProvider.appleICloud => null,
    BusyProvider.nextcloud => _safeAccountWebUri(account.authority),
    BusyProvider.webCal => null,
    BusyProvider.caldav => null,
  };
}

Uri? _safeAccountWebUri(String authority) {
  final uri = Uri.tryParse(authority.trim());
  if (uri == null ||
      uri.scheme.toLowerCase() != 'https' ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment) {
    return null;
  }
  return uri;
}
