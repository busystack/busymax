import 'package:busymax/src/calendar_providers/calendar_provider_capabilities.dart';
import 'package:busymax/src/features/calendar/data/calendar_repository.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Google and Microsoft expose cloud calendar management', () {
    for (final provider in [BusyProvider.google, BusyProvider.microsoft]) {
      final capabilities = calendarManagementCapabilities(provider);
      expect(capabilities.supportsCreate, isTrue);
      expect(capabilities.supportsRename, isTrue);
      expect(capabilities.supportsDelete, isTrue);
      expect(capabilities.supportsColor, isTrue);
    }
  });

  test('DAV calendar collection management is disabled', () {
    for (final provider in [BusyProvider.appleICloud, BusyProvider.nextcloud]) {
      final capabilities = calendarManagementCapabilities(provider);
      expect(capabilities.supportsCreate, isFalse);
      expect(capabilities.supportsRename, isFalse);
      expect(capabilities.supportsDelete, isFalse);
      expect(capabilities.supportsColor, isFalse);
    }
  });

  test(
    'DAV source actions remain disabled even when the source is writable',
    () {
      const source = CalendarSourceEntity(
        id: 'dav-calendar',
        accountId: 'nextcloud-account',
        provider: BusyProvider.nextcloud,
        providerCalendarId: '/calendars/user/work/',
        summary: 'Work',
        selected: true,
        hidden: false,
        readOnly: false,
        isDeleted: false,
      );

      expect(source.capabilities.canCreateEvents, isTrue);
      expect(source.capabilities.canRenameCalendar, isFalse);
      expect(source.capabilities.canDeleteCalendar, isFalse);
      expect(source.capabilities.canChangeCalendarColor, isFalse);
    },
  );

  test('primary cloud calendar cannot be deleted', () {
    const source = CalendarSourceEntity(
      id: 'primary-calendar',
      accountId: 'google-account',
      provider: BusyProvider.google,
      providerCalendarId: 'primary',
      summary: 'Primary',
      selected: true,
      hidden: false,
      readOnly: false,
      isDeleted: false,
      primaryCalendar: true,
    );

    expect(source.capabilities.canRenameCalendar, isTrue);
    expect(source.capabilities.canDeleteCalendar, isFalse);
    expect(source.capabilities.canChangeCalendarColor, isTrue);
  });
}
