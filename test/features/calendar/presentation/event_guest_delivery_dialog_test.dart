import 'package:busymax/src/app/busymax_design.dart';
import 'package:busymax/src/calendar_providers/calendar_mutation.dart';
import 'package:busymax/src/features/calendar/data/calendar_repository.dart';
import 'package:busymax/src/features/calendar/presentation/event_editor.dart';
import 'package:busymax/src/features/calendar/presentation/event_editor_draft.dart';
import 'package:busymax/src/features/calendar/presentation/event_guest_delivery_dialog.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../test_localized_app.dart';

void main() {
  testWidgets('event editor returns the selected Google delivery policy', (
    tester,
  ) async {
    Future<EventEditorDialogResult?>? result;
    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () {
                result = showBusyMaxEventEditorDialog(
                  context,
                  initialDraft:
                      EventEditorDraft.newEvent(
                        accountId: 'google-account',
                        sourceId: 'calendar-1',
                        providerCalendarId: 'calendar-1',
                        start: DateTime.utc(2026, 6, 8, 9),
                        end: DateTime.utc(2026, 6, 8, 10),
                      ).copyWith(
                        title: 'Planning',
                        attendees: const [
                          EventAttendeeDraft(email: 'guest@example.com'),
                        ],
                      ),
                  sources: const [
                    CalendarSourceEntity(
                      id: 'calendar-1',
                      accountId: 'google-account',
                      provider: BusyProvider.google,
                      providerCalendarId: 'calendar-1',
                      summary: 'Work',
                      selected: true,
                      hidden: false,
                      readOnly: false,
                      isDeleted: false,
                    ),
                  ],
                  accounts: const [],
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).first,
      'Updated planning',
    );
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Notify guests?'), findsOneWidget);
    await tester.tap(find.text('Don’t send'));
    await tester.tap(find.text('Save').last);
    await tester.pumpAndSettle();

    final editorResult = await result;
    expect(
      editorResult?.guestUpdatePolicy,
      CalendarGuestUpdatePolicy.doNotSend,
    );
  });

  testWidgets('Google save asks whether guest updates should be sent', (
    tester,
  ) async {
    Future<CalendarGuestUpdatePolicy?>? result;
    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () {
                result = showCalendarGuestDeliveryDialog(
                  context,
                  provider: BusyProvider.google,
                  action: CalendarGuestDeliveryAction.save,
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Notify guests?'), findsOneWidget);
    expect(find.text('Send updates'), findsOneWidget);
    expect(find.text('Don’t send'), findsOneWidget);
    await tester.tap(find.text('Don’t send'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(await result, CalendarGuestUpdatePolicy.doNotSend);
  });

  testWidgets('copy-delete move explains the provider boundary before saving', (
    tester,
  ) async {
    Future<EventEditorDialogResult?>? result;
    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () {
                result = showBusyMaxEventEditorDialog(
                  context,
                  initialDraft: EventEditorDraft.existing(
                    eventId: 'event-1',
                    accountId: 'microsoft-account',
                    sourceId: 'calendar-1',
                    providerCalendarId: 'provider-calendar-1',
                    title: 'Planning',
                    allDay: false,
                    start: DateTime.utc(2026, 6, 8, 9),
                    end: DateTime.utc(2026, 6, 8, 10),
                  ),
                  sources: const [
                    CalendarSourceEntity(
                      id: 'calendar-1',
                      accountId: 'microsoft-account',
                      provider: BusyProvider.microsoft,
                      providerCalendarId: 'provider-calendar-1',
                      summary: 'Work',
                      selected: true,
                      hidden: false,
                      readOnly: false,
                      isDeleted: false,
                    ),
                    CalendarSourceEntity(
                      id: 'calendar-2',
                      accountId: 'microsoft-account',
                      provider: BusyProvider.microsoft,
                      providerCalendarId: 'provider-calendar-2',
                      summary: 'Personal',
                      selected: true,
                      hidden: false,
                      readOnly: false,
                      isDeleted: false,
                    ),
                  ],
                  accounts: const [],
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    final calendarRow = tester.widget<BusyMaxComboRow<String>>(
      find.byWidgetPredicate(
        (widget) =>
            widget is BusyMaxComboRow<String> && widget.title == 'Calendar',
      ),
    );
    calendarRow.onSelected('calendar-2');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Copy event and delete original?'), findsOneWidget);
    expect(find.textContaining('Microsoft · Work'), findsOneWidget);
    expect(find.textContaining('Microsoft · Personal'), findsOneWidget);
    expect(find.textContaining('only after the copy succeeds'), findsOneWidget);
    await tester.tap(find.text('Copy and delete'));
    await tester.pumpAndSettle();

    final editorResult = await result;
    expect(editorResult?.draft?.sourceId, 'calendar-2');
  });

  testWidgets('Microsoft delete explains that a cancellation will be sent', (
    tester,
  ) async {
    Future<CalendarGuestUpdatePolicy?>? result;
    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () {
                result = showCalendarGuestDeliveryDialog(
                  context,
                  provider: BusyProvider.microsoft,
                  action: CalendarGuestDeliveryAction.delete,
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Delete meeting?'), findsOneWidget);
    expect(
      find.text('Microsoft will send a cancellation to guests.'),
      findsOneWidget,
    );
    expect(find.text('Don’t send'), findsNothing);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(await result, CalendarGuestUpdatePolicy.send);
  });
}
