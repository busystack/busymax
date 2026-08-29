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

  test('owned Google secondary calendar permits global rename and delete', () {
    const source = CalendarSourceEntity(
      id: 'owned-calendar',
      accountId: 'google-account',
      provider: BusyProvider.google,
      providerCalendarId: 'owned@example.com',
      summary: 'Owned',
      selected: true,
      hidden: false,
      readOnly: false,
      isDeleted: false,
      dataOwner: 'owner@example.com',
      authenticatedAccountEmail: 'OWNER@example.com',
    );

    expect(source.capabilities.renameMode, CalendarRenameMode.global);
    expect(source.capabilities.removalMode, CalendarRemovalMode.delete);
    expect(source.capabilities.canDeleteCalendar, isTrue);
  });

  test(
    'shared read-only Google calendar permits personal name, color, and removal',
    () {
      const source = CalendarSourceEntity(
        id: 'shared-calendar',
        accountId: 'google-account',
        provider: BusyProvider.google,
        providerCalendarId: 'shared@example.com',
        summary: 'Shared',
        selected: true,
        hidden: false,
        readOnly: true,
        isDeleted: false,
        dataOwner: 'other@example.com',
        authenticatedAccountEmail: 'me@example.com',
      );

      expect(source.capabilities.canCreateEvents, isFalse);
      expect(source.capabilities.renameMode, CalendarRenameMode.personal);
      expect(
        source.capabilities.removalMode,
        CalendarRemovalMode.removeFromList,
      );
      expect(source.capabilities.canDeleteCalendar, isFalse);
      expect(source.capabilities.canRemoveCalendar, isTrue);
      expect(source.capabilities.canChangeCalendarColor, isTrue);
    },
  );

  test('Microsoft deletion follows isRemovable rather than canEdit', () {
    const removableReadOnly = CalendarSourceEntity(
      id: 'shared-outlook',
      accountId: 'microsoft-account',
      provider: BusyProvider.microsoft,
      providerCalendarId: 'shared',
      summary: 'Shared',
      selected: true,
      hidden: false,
      readOnly: true,
      isDeleted: false,
      isRemovable: true,
    );
    const editableNotRemovable = CalendarSourceEntity(
      id: 'owned-outlook',
      accountId: 'microsoft-account',
      provider: BusyProvider.microsoft,
      providerCalendarId: 'owned',
      summary: 'Owned',
      selected: true,
      hidden: false,
      readOnly: false,
      isDeleted: false,
      isRemovable: false,
    );

    expect(
      removableReadOnly.capabilities.removalMode,
      CalendarRemovalMode.delete,
    );
    expect(editableNotRemovable.capabilities.canRemoveCalendar, isFalse);
  });

  test('pending cloud calendar creation can be renamed and cancelled', () {
    for (final provider in [BusyProvider.google, BusyProvider.microsoft]) {
      final source = CalendarSourceEntity(
        id: '${provider.storageValue}-pending',
        accountId: '${provider.storageValue}-account',
        provider: provider,
        providerCalendarId: 'local:pending',
        summary: 'New calendar',
        selected: true,
        hidden: false,
        readOnly: false,
        isDeleted: false,
        pendingCreate: true,
      );

      expect(source.capabilities.renameMode, CalendarRenameMode.global);
      expect(source.capabilities.removalMode, CalendarRemovalMode.delete);
      expect(source.capabilities.canRenameCalendar, isTrue);
      expect(source.capabilities.canRemoveCalendar, isTrue);
    }
  });
}
