import 'dart:io';

import 'package:busymax/src/calendar_providers/calendar_mutation.dart';
import 'package:busymax/src/features/calendar/data/calendar_repository.dart';
import 'package:busymax/src/features/calendar/presentation/event_editor.dart';
import 'package:busymax/src/features/calendar/presentation/event_editor_draft.dart';
import 'package:busymax/src/features/tasks/presentation/desktop_date_time_fields.dart';
import 'package:busymax/src/app/busymax_design.dart';
import 'package:busymax/src/app/busymax_yaru_theme.dart';
import 'package:busymax/src/microsoft_calendar/microsoft_calendar_mapper.dart';
import 'package:busymax/src/platform/native_dialog_service.dart';
import 'package:busymax/src/platform/native_menu_service.dart';
import 'package:busymax/src/task_providers/task_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaru/yaru.dart';

import '../../../test_localized_app.dart';

const _nativeDialogChannel = MethodChannel(nativeDialogChannelName);
const _nativeMenuChannel = MethodChannel(nativeMenuChannelName);

void main() {
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_nativeDialogChannel, (_) async => null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          _nativeMenuChannel,
          (_) async => throw MissingPluginException(),
        );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_nativeDialogChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_nativeMenuChannel, null);
  });

  testWidgets('editor actions use natural-width themed controls', (
    tester,
  ) async {
    await tester.pumpWidget(
      localizedTestApp(
        theme: BusyMaxYaruTheme.build(
          brightness: Brightness.light,
          accentColor: const Color(0xFF3584E4),
        ),
        child: Scaffold(
          body: EventEditor(
            initialDraft: EventEditorDraft.newEvent(
              accountId: 'account',
              sourceId: 'source',
              providerCalendarId: 'cal-1',
              start: DateTime.utc(2026, 6, 8),
              end: DateTime.utc(2026, 6, 8, 1),
            ),
            sources: _sources,
            onCancel: () {},
            onSave: (_) {},
          ),
        ),
      ),
    );

    expect(
      tester.getSize(_headerButtonFinder('Cancel')).height,
      kYaruButtonHeight,
    );
    expect(
      tester.getSize(_headerButtonFinder('Save')).height,
      kYaruButtonHeight,
    );
    expect(
      find.ancestor(
        of: find.text('Cancel'),
        matching: find.byType(FilledButton),
      ),
      findsOneWidget,
    );
    expect(
      find.ancestor(
        of: find.text('Save'),
        matching: find.byType(ElevatedButton),
      ),
      findsOneWidget,
    );
    final cancelButton = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('Cancel'),
        matching: find.byType(FilledButton),
      ),
    );
    final saveButton = tester.widget<ElevatedButton>(
      find.ancestor(
        of: find.text('Save'),
        matching: find.byType(ElevatedButton),
      ),
    );
    expect(cancelButton.style?.fixedSize, isNull);
    expect(cancelButton.style?.minimumSize, isNull);
    expect(saveButton.style?.fixedSize, isNull);
    expect(saveButton.style?.minimumSize, isNull);
    final cancelContext = tester.element(find.text('Cancel'));
    expect(
      cancelButton.style?.textStyle?.resolve(const {})?.fontWeight,
      Theme.of(cancelContext).textTheme.titleSmall?.fontWeight,
    );
  });

  testWidgets('all-day event hides time rows and conference placeholder', (
    tester,
  ) async {
    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: EventEditor(
            initialDraft: EventEditorDraft.newEvent(
              accountId: 'account',
              sourceId: 'source',
              providerCalendarId: 'cal-1',
              start: DateTime.utc(2026, 6, 8),
              end: DateTime.utc(2026, 6, 9),
            ).copyWith(title: 'All day', allDay: true),
            sources: _sources,
            onCancel: () {},
            onSave: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Start time'), findsNothing);
    expect(find.text('End Time'), findsNothing);
    expect(_plainTextFinder('All day'), findsOneWidget);
    expect(_plainTextFinder('Time slot'), findsOneWidget);
    expect(find.text('No conference'), findsNothing);
    expect(find.text('Delete Event'), findsNothing);
  });

  testWidgets('converting a same-day timed event uses next-day all-day end', (
    tester,
  ) async {
    EventEditorDraft? saved;
    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: EventEditor(
            initialDraft: EventEditorDraft.existing(
              eventId: 'event-1',
              accountId: 'account',
              sourceId: 'source',
              providerCalendarId: 'cal-1',
              title: 'Planning',
              allDay: false,
              start: DateTime.utc(2026, 6, 8, 9),
              end: DateTime.utc(2026, 6, 8, 10),
            ),
            sources: _sources,
            onCancel: () {},
            onSave: (draft) => saved = draft,
          ),
        ),
      ),
    );

    await tester.tap(_plainTextFinder('All day'));
    await tester.pump();
    await tester.tap(_headerButtonFinder('Save'));

    expect(saved?.allDay, isTrue);
    expect(
      (saved?.start?.year, saved?.start?.month, saved?.start?.day),
      (2026, 6, 8),
    );
    expect(
      (saved?.end?.year, saved?.end?.month, saved?.end?.day),
      (2026, 6, 9),
    );
  });

  testWidgets('timed event shows separated end date and end time labels', (
    tester,
  ) async {
    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: EventEditor(
            initialDraft: EventEditorDraft.newEvent(
              accountId: 'account',
              sourceId: 'source',
              providerCalendarId: 'cal-1',
              start: DateTime.utc(2026, 6, 8, 9),
              end: DateTime.utc(2026, 6, 8, 10),
            ).copyWith(title: 'Planning', allDay: false),
            sources: _sources,
            onCancel: () {},
            onSave: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Start date'), findsOneWidget);
    expect(find.text('Start time'), findsOneWidget);
    expect(find.text('End Date'), findsOneWidget);
    expect(find.text('End Time'), findsOneWidget);
    expect(find.text('End date/time'), findsNothing);
  });

  testWidgets('event time popup opens with current time and requires a value', (
    tester,
  ) async {
    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: EventEditor(
            initialDraft: EventEditorDraft.newEvent(
              accountId: 'account',
              sourceId: 'source',
              providerCalendarId: 'cal-1',
              start: DateTime.utc(2026, 6, 8, 9),
              end: DateTime.utc(2026, 6, 8, 10),
            ).copyWith(title: 'Planning', allDay: false),
            sources: _sources,
            onCancel: () {},
            onSave: (_) {},
          ),
        ),
      ),
    );

    await tester.ensureVisible(find.text('Start time'));
    await tester.tap(find.text('Start time'));
    await tester.pumpAndSettle();

    final fieldFinder = _timeEntryFinder();
    final entry = tester.widget<YaruTimeEntry>(fieldFinder);
    expect(entry.controller?.timeOfDay, const TimeOfDay(hour: 9, minute: 0));

    await tester.tap(find.byIcon(YaruIcons.edit_clear));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(entry.controller?.timeOfDay, isNull);
    expect(
      tester
          .widget<ButtonStyleButton>(
            find
                .ancestor(
                  of: find.text('OK'),
                  matching: find.byWidgetPredicate(
                    (widget) => widget is ButtonStyleButton,
                  ),
                )
                .first,
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('event time popup accepts midnight input', (tester) async {
    EventEditorDraft? saved;
    await tester.pumpWidget(
      localizedTestApp(
        alwaysUse24HourFormat: true,
        child: Scaffold(
          body: EventEditor(
            initialDraft: EventEditorDraft.newEvent(
              accountId: 'account',
              sourceId: 'source',
              providerCalendarId: 'cal-1',
              start: DateTime.utc(2026, 6, 8, 9),
              end: DateTime.utc(2026, 6, 8, 10),
            ).copyWith(title: 'Planning', allDay: false),
            sources: _sources,
            onCancel: () {},
            onSave: (draft) => saved = draft,
          ),
        ),
      ),
    );

    await tester.ensureVisible(find.text('Start time'));
    await tester.tap(find.text('Start time'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(YaruIcons.edit_clear));
    await _enterTime(tester, hour: '00', minute: '00');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await tester.tap(_headerButtonFinder('Save'));

    expect(saved?.start?.year, 2026);
    expect(saved?.start?.month, 6);
    expect(saved?.start?.day, 8);
    expect(saved?.start?.hour, 0);
    expect(saved?.start?.minute, 0);
    expect(saved?.end?.hour, 10);
  });

  testWidgets('Ctrl+S saves a dirty event editor', (tester) async {
    EventEditorDraft? saved;
    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: EventEditor(
            initialDraft: EventEditorDraft.newEvent(
              accountId: 'account',
              sourceId: 'source',
              providerCalendarId: 'cal-1',
              start: DateTime.utc(2026, 6, 8, 9),
              end: DateTime.utc(2026, 6, 8, 10),
            ),
            sources: _sources,
            onCancel: () {},
            onSave: (draft) => saved = draft,
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextFormField).first, 'Planning');
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);

    expect(saved?.title, 'Planning');
  });

  testWidgets('Delete removes an existing event when not editing text', (
    tester,
  ) async {
    String? deletedEventId;
    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: EventEditor(
            initialDraft: EventEditorDraft.existing(
              eventId: 'event-1',
              accountId: 'account',
              sourceId: 'source',
              providerCalendarId: 'cal-1',
              title: 'Planning',
              allDay: false,
              start: DateTime.utc(2026, 6, 8, 9),
              end: DateTime.utc(2026, 6, 8, 10),
            ),
            sources: _sources,
            onCancel: () {},
            onSave: (_) {},
            onDelete: (eventId) => deletedEventId = eventId,
          ),
        ),
      ),
    );

    _focusEditorShortcuts(tester);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.delete);

    expect(deletedEventId, 'event-1');
  });

  testWidgets('Backspace in an event text field does not delete the event', (
    tester,
  ) async {
    String? deletedEventId;
    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: EventEditor(
            initialDraft: EventEditorDraft.existing(
              eventId: 'event-1',
              accountId: 'account',
              sourceId: 'source',
              providerCalendarId: 'cal-1',
              title: 'Planning',
              allDay: false,
              start: DateTime.utc(2026, 6, 8, 9),
              end: DateTime.utc(2026, 6, 8, 10),
            ),
            sources: _sources,
            onCancel: () {},
            onSave: (_) {},
            onDelete: (eventId) => deletedEventId = eventId,
          ),
        ),
      ),
    );

    await tester.tap(find.byType(TextFormField).first);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);

    expect(deletedEventId, isNull);
  });

  test('event draft requires end after start', () {
    final draft = EventEditorDraft.existing(
      eventId: 'event-1',
      accountId: 'account',
      sourceId: 'source',
      providerCalendarId: 'cal-1',
      title: 'Planning',
      allDay: false,
      start: DateTime.utc(2026, 6, 8, 10),
      end: DateTime.utc(2026, 6, 8, 9),
    );

    expect(draft.canSave, isFalse);
  });

  test('all-day draft requires an exclusive end on a later date', () {
    final sameDate = EventEditorDraft.existing(
      eventId: 'event-1',
      accountId: 'account',
      sourceId: 'source',
      providerCalendarId: 'cal-1',
      title: 'Planning',
      allDay: true,
      start: DateTime.utc(2026, 6, 8, 9),
      end: DateTime.utc(2026, 6, 8, 10),
    );
    final nextDate = sameDate.copyWith(end: DateTime.utc(2026, 6, 9, 9));

    expect(sameDate.canSave, isFalse);
    expect(nextDate.canSave, isTrue);
  });

  test('Microsoft attendee JSON hydrates nested email details', () {
    final attendee = EventAttendeeDraft.fromJson({
      'emailAddress': {'address': 'guest@example.com', 'name': 'Guest'},
      'type': 'optional',
    });

    expect(attendee.email, 'guest@example.com');
    expect(attendee.displayName, 'Guest');
    expect(attendee.optional, isTrue);
  });

  for (final recurrenceCase in _microsoftRecurrenceCases.entries) {
    testWidgets(
      'Microsoft ${recurrenceCase.key} recurrence emits required Graph fields',
      (tester) async {
        EventEditorDraft? saved;
        await tester.pumpWidget(
          localizedTestApp(
            child: Scaffold(
              body: EventEditor(
                initialDraft: EventEditorDraft.newEvent(
                  accountId: 'microsoft-account',
                  sourceId: 'microsoft-source',
                  providerCalendarId: 'ms-cal-1',
                  start: DateTime.utc(2026, 6, 10, 9),
                  end: DateTime.utc(2026, 6, 10, 10),
                ).copyWith(title: 'Planning'),
                sources: _microsoftSources,
                onCancel: () {},
                onSave: (draft) => saved = draft,
              ),
            ),
          ),
        );

        final repeatRow = tester.widget<BusyMaxComboRow<String>>(
          find.byWidgetPredicate(
            (widget) =>
                widget is BusyMaxComboRow<String> && widget.title == 'Repeat',
          ),
        );
        repeatRow.onSelected(recurrenceCase.key);
        await tester.pump();
        await tester.tap(_headerButtonFinder('Save'));

        final expectedRecurrence = <String, Object?>{
          'pattern': recurrenceCase.value,
          'range': const {'type': 'noEnd', 'startDate': '2026-06-10'},
        };
        final body = microsoftEventMutationToJson(
          CalendarEventMutation(recurrence: saved?.recurrence),
        );

        expect(saved, isNotNull);
        expect(body, {'recurrence': expectedRecurrence});
      },
    );
  }

  for (final recurrenceCase in _microsoftReanchoredRecurrenceCases.entries) {
    testWidgets(
      'Microsoft ${recurrenceCase.key} recurrence follows a changed start date',
      (tester) async {
        EventEditorDraft? saved;
        await tester.pumpWidget(
          localizedTestApp(
            child: Scaffold(
              body: EventEditor(
                initialDraft: EventEditorDraft.newEvent(
                  accountId: 'microsoft-account',
                  sourceId: 'microsoft-source',
                  providerCalendarId: 'ms-cal-1',
                  start: DateTime.utc(2026, 6, 10, 9),
                  end: DateTime.utc(2026, 6, 10, 10),
                ).copyWith(title: 'Planning'),
                sources: _microsoftSources,
                onCancel: () {},
                onSave: (draft) => saved = draft,
              ),
            ),
          ),
        );

        final repeatRow = tester.widget<BusyMaxComboRow<String>>(
          find.byWidgetPredicate(
            (widget) =>
                widget is BusyMaxComboRow<String> && widget.title == 'Repeat',
          ),
        );
        repeatRow.onSelected(recurrenceCase.key);
        await tester.pump();

        final startDateRow = tester.widget<DesktopDateValueRow>(
          find.byWidgetPredicate(
            (widget) =>
                widget is DesktopDateValueRow && widget.label == 'Start date',
          ),
        );
        startDateRow.onChanged('2026-07-11');
        await tester.pump();
        await tester.tap(_headerButtonFinder('Save'));

        expect(saved?.recurrence, {
          'pattern': recurrenceCase.value,
          'range': const {'type': 'noEnd', 'startDate': '2026-07-11'},
        });
      },
    );
  }

  testWidgets(
    'new event converts Google recurrence when Microsoft calendar is selected',
    (tester) async {
      EventEditorDraft? saved;
      await tester.pumpWidget(
        localizedTestApp(
          child: Scaffold(
            body: EventEditor(
              initialDraft: EventEditorDraft.newEvent(
                accountId: 'account',
                sourceId: 'source',
                providerCalendarId: 'cal-1',
                start: DateTime.utc(2026, 6, 10, 9),
                end: DateTime.utc(2026, 6, 10, 10),
              ).copyWith(title: 'Planning'),
              sources: _mixedProviderSources,
              onCancel: () {},
              onSave: (draft) => saved = draft,
            ),
          ),
        ),
      );

      _comboRow(tester, 'Repeat').onSelected('weekly');
      await tester.pump();
      _comboRow(tester, 'Calendar').onSelected('microsoft-source');
      await tester.pump();
      await tester.tap(_headerButtonFinder('Save'));

      expect(saved?.recurrence, {
        'pattern': _microsoftRecurrenceCases['weekly'],
        'range': const {'type': 'noEnd', 'startDate': '2026-06-10'},
      });
    },
  );

  testWidgets(
    'new event converts Microsoft recurrence when Google calendar is selected',
    (tester) async {
      EventEditorDraft? saved;
      await tester.pumpWidget(
        localizedTestApp(
          child: Scaffold(
            body: EventEditor(
              initialDraft: EventEditorDraft.newEvent(
                accountId: 'microsoft-account',
                sourceId: 'microsoft-source',
                providerCalendarId: 'ms-cal-1',
                start: DateTime.utc(2026, 6, 10, 9),
                end: DateTime.utc(2026, 6, 10, 10),
              ).copyWith(title: 'Planning'),
              sources: _mixedProviderSources,
              onCancel: () {},
              onSave: (draft) => saved = draft,
            ),
          ),
        ),
      );

      _comboRow(tester, 'Repeat').onSelected('weekly');
      await tester.pump();
      _comboRow(tester, 'Calendar').onSelected('source');
      await tester.pump();
      await tester.tap(_headerButtonFinder('Save'));

      expect(saved?.recurrence, ['RRULE:FREQ=WEEKLY;INTERVAL=1']);
    },
  );

  testWidgets('recurring occurrence hides series recurrence control', (
    tester,
  ) async {
    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: EventEditor(
            initialDraft: EventEditorDraft.existing(
              eventId: 'occurrence-1',
              providerRecurringEventId: 'series-master',
              accountId: 'account',
              sourceId: 'source',
              providerCalendarId: 'cal-1',
              title: 'Weekly planning',
              allDay: false,
              start: DateTime.utc(2026, 6, 8, 9),
              end: DateTime.utc(2026, 6, 8, 10),
            ),
            sources: _sources,
            onCancel: () {},
            onSave: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Repeat'), findsNothing);
  });

  testWidgets('event editor does not show metadata fields', (tester) async {
    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: EventEditor(
            initialDraft: EventEditorDraft.existing(
              eventId: 'event-1',
              accountId: 'account',
              sourceId: 'source',
              providerCalendarId: 'cal-1',
              title: 'Planning',
              allDay: false,
              start: DateTime.utc(2026, 6, 8, 9),
              end: DateTime.utc(2026, 6, 8, 10),
            ),
            sources: _sources,
            onCancel: () {},
            onSave: (_) {},
            onDelete: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Metadata'), findsNothing);
    expect(find.text('Provider calendar'), findsNothing);
    expect(find.text('event-1'), findsNothing);
    expect(find.text('cal-1'), findsNothing);
  });

  testWidgets('existing event shows delete action', (tester) async {
    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: EventEditor(
            initialDraft: EventEditorDraft.existing(
              eventId: 'event-1',
              accountId: 'account',
              sourceId: 'source',
              providerCalendarId: 'cal-1',
              title: 'Planning',
              allDay: false,
              start: DateTime.utc(2026, 6, 8, 9),
              end: DateTime.utc(2026, 6, 8, 10),
            ),
            sources: _sources,
            onCancel: () {},
            onSave: (_) {},
            onDelete: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Delete Event'), findsOneWidget);
    expect(
      find.ancestor(
        of: find.text('Delete Event'),
        matching: find.byType(Center),
      ),
      findsOneWidget,
    );
  });

  testWidgets('existing event only exposes its original calendar', (
    tester,
  ) async {
    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: EventEditor(
            initialDraft: EventEditorDraft.existing(
              eventId: 'event-1',
              accountId: 'account',
              sourceId: 'source',
              providerCalendarId: 'cal-1',
              title: 'Planning',
              allDay: false,
              start: DateTime.utc(2026, 6, 8, 9),
              end: DateTime.utc(2026, 6, 8, 10),
            ),
            sources: _multipleSources,
            onCancel: () {},
            onSave: (_) {},
            onDelete: (_) {},
          ),
        ),
      ),
    );

    final calendarRow = tester.widget<BusyMaxComboRow<String>>(
      find.byWidgetPredicate(
        (widget) =>
            widget is BusyMaxComboRow<String> && widget.title == 'Calendar',
      ),
    );

    expect(calendarRow.selected, 'source');
    expect(calendarRow.values, ['source']);
    expect(calendarRow.enabled, isFalse);
  });

  testWidgets('new event can still select any visible calendar', (
    tester,
  ) async {
    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: EventEditor(
            initialDraft: EventEditorDraft.newEvent(
              accountId: 'account',
              sourceId: 'source',
              providerCalendarId: 'cal-1',
              start: DateTime.utc(2026, 6, 8, 9),
              end: DateTime.utc(2026, 6, 8, 10),
            ).copyWith(title: 'Planning'),
            sources: _multipleSources,
            onCancel: () {},
            onSave: (_) {},
          ),
        ),
      ),
    );

    final calendarRow = tester.widget<BusyMaxComboRow<String>>(
      find.byWidgetPredicate(
        (widget) =>
            widget is BusyMaxComboRow<String> && widget.title == 'Calendar',
      ),
    );

    expect(calendarRow.values, ['source', 'destination-source']);
    expect(calendarRow.enabled, isTrue);
  });

  testWidgets('Google event editor saves multiple reminder overrides', (
    tester,
  ) async {
    EventEditorDraft? saved;
    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: EventEditor(
            initialDraft: EventEditorDraft.newEvent(
              accountId: 'account',
              sourceId: 'source',
              providerCalendarId: 'cal-1',
              start: DateTime.utc(2026, 6, 8, 9),
              end: DateTime.utc(2026, 6, 8, 10),
            ).copyWith(title: 'Planning'),
            sources: _sources,
            onCancel: () {},
            onSave: (draft) => saved = draft,
          ),
        ),
      ),
    );

    await tester.ensureVisible(find.text('Add Reminder'));
    await tester.tap(find.text('Add Reminder'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Add Reminder'));
    await tester.tap(find.text('Add Reminder'));
    await tester.pumpAndSettle();

    await tester.tap(_headerButtonFinder('Save'));

    final reminders = saved?.reminders as Map<Object?, Object?>?;
    expect(reminders?['useDefault'], isFalse);
    final overrides = reminders?['overrides'] as List<Object?>?;
    expect(overrides, hasLength(2));
    expect(overrides?[0], {'method': 'popup', 'minutes': 5});
    expect(overrides?[1], {'method': 'popup', 'minutes': 10});
  });

  testWidgets('add reminder action is centered in the reminder group', (
    tester,
  ) async {
    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: EventEditor(
            initialDraft: EventEditorDraft.newEvent(
              accountId: 'account',
              sourceId: 'source',
              providerCalendarId: 'cal-1',
              start: DateTime.utc(2026, 6, 8, 9),
              end: DateTime.utc(2026, 6, 8, 10),
            ).copyWith(title: 'Planning'),
            sources: _sources,
            onCancel: () {},
            onSave: (_) {},
          ),
        ),
      ),
    );

    await tester.ensureVisible(find.text('Add Reminder'));

    expect(
      find.ancestor(
        of: find.text('Add Reminder'),
        matching: find.byType(Center),
      ),
      findsOneWidget,
    );
  });

  testWidgets('add guest email starts as a centered action row', (
    tester,
  ) async {
    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: EventEditor(
            initialDraft: EventEditorDraft.newEvent(
              accountId: 'account',
              sourceId: 'source',
              providerCalendarId: 'cal-1',
              start: DateTime.utc(2026, 6, 8, 9),
              end: DateTime.utc(2026, 6, 8, 10),
            ).copyWith(title: 'Planning'),
            sources: _sources,
            onCancel: () {},
            onSave: (_) {},
          ),
        ),
      ),
    );

    await tester.ensureVisible(find.text('Add Guest'));

    expect(
      find.ancestor(of: find.text('Add Guest'), matching: find.byType(Center)),
      findsOneWidget,
    );

    await tester.tap(find.text('Add Guest'));
    await tester.pumpAndSettle();

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.labelText == 'Add guest email',
      ),
      findsOneWidget,
    );
  });

  testWidgets('removing the only Google event reminder disables reminders', (
    tester,
  ) async {
    EventEditorDraft? saved;
    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: EventEditor(
            initialDraft: EventEditorDraft.existing(
              eventId: 'event-1',
              accountId: 'account',
              sourceId: 'source',
              providerCalendarId: 'cal-1',
              title: 'Planning',
              allDay: false,
              start: DateTime.utc(2026, 6, 8, 9),
              end: DateTime.utc(2026, 6, 8, 10),
              reminders: {
                'useDefault': false,
                'overrides': [
                  {'method': 'popup', 'minutes': 10},
                ],
              },
            ),
            sources: _sources,
            onCancel: () {},
            onSave: (draft) => saved = draft,
          ),
        ),
      ),
    );

    await tester.ensureVisible(find.byTooltip('Remove reminder'));
    await tester.tap(find.byTooltip('Remove reminder'));
    await tester.pumpAndSettle();
    await tester.tap(_headerButtonFinder('Save'));

    expect(saved?.reminders, {'useDefault': false, 'overrides': const []});
  });

  testWidgets('Microsoft event editor limits reminders to one provider value', (
    tester,
  ) async {
    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: EventEditor(
            initialDraft: EventEditorDraft.newEvent(
              accountId: 'microsoft-account',
              sourceId: 'microsoft-source',
              providerCalendarId: 'ms-cal-1',
              start: DateTime.utc(2026, 6, 8, 9),
              end: DateTime.utc(2026, 6, 8, 10),
            ).copyWith(title: 'Planning'),
            sources: _microsoftSources,
            onCancel: () {},
            onSave: (_) {},
          ),
        ),
      ),
    );

    await tester.ensureVisible(find.text('Add Reminder'));
    await tester.tap(find.text('Add Reminder'));
    await tester.pumpAndSettle();

    expect(find.text('Add Reminder'), findsNothing);
    expect(
      find.descendant(
        of: find.byType(BusyMaxComboBox<int>),
        matching: find.text('5 minutes before'),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'Microsoft event categories use Yaru autocomplete keyboard selection',
    (tester) async {
      EventEditorDraft? saved;
      await tester.pumpWidget(
        localizedTestApp(
          child: Scaffold(
            body: EventEditor(
              initialDraft: EventEditorDraft.existing(
                eventId: 'event-1',
                accountId: 'microsoft-account',
                sourceId: 'microsoft-source',
                providerCalendarId: 'ms-cal-1',
                title: 'Planning',
                allDay: false,
                start: DateTime.utc(2026, 6, 8, 9),
                end: DateTime.utc(2026, 6, 8, 10),
                categories: const ['Home'],
              ),
              sources: _microsoftSources,
              categorySuggestionsByAccount: const {
                'microsoft-account': ['Home', 'Work'],
              },
              onCancel: () {},
              onSave: (draft) => saved = draft,
            ),
          ),
        ),
      );

      await tester.ensureVisible(find.text('Add category'));
      expect(find.text('Home'), findsOneWidget);

      await tester.tap(find.text('Add category'));
      await tester.pumpAndSettle();
      expect(find.byType(YaruAutocomplete<String>), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('event-category-input')),
        'work',
      );
      await tester.pumpAndSettle();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      await tester.tap(_headerButtonFinder('Save'));

      expect(saved?.categories, ['Home', 'Work']);
    },
  );

  testWidgets('Escape cancels category entry without closing event editor', (
    tester,
  ) async {
    var editorCancelled = false;
    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: EventEditor(
            initialDraft: EventEditorDraft.existing(
              eventId: 'event-1',
              accountId: 'microsoft-account',
              sourceId: 'microsoft-source',
              providerCalendarId: 'ms-cal-1',
              title: 'Planning',
              allDay: false,
              start: DateTime.utc(2026, 6, 8, 9),
              end: DateTime.utc(2026, 6, 8, 10),
            ),
            sources: _microsoftSources,
            onCancel: () => editorCancelled = true,
            onSave: (_) {},
          ),
        ),
      ),
    );

    await tester.ensureVisible(find.text('Add category'));
    await tester.tap(find.text('Add category'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('event-category-input')), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('event-category-input')))
          .focusNode
          ?.hasFocus,
      isTrue,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('event-category-input')), findsNothing);
    expect(find.widgetWithText(ActionChip, 'Add category'), findsOneWidget);
    expect(editorCancelled, isFalse);
  });

  testWidgets('Google event editor does not show categories', (tester) async {
    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: EventEditor(
            initialDraft: EventEditorDraft.newEvent(
              accountId: 'account',
              sourceId: 'source',
              providerCalendarId: 'cal-1',
              start: DateTime.utc(2026, 6, 8, 9),
              end: DateTime.utc(2026, 6, 8, 10),
            ).copyWith(title: 'Planning'),
            sources: _sources,
            onCancel: () {},
            onSave: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Categories'), findsNothing);
  });

  testWidgets(
    'removing a Microsoft event reminder disables provider reminder',
    (tester) async {
      EventEditorDraft? saved;
      await tester.pumpWidget(
        localizedTestApp(
          child: Scaffold(
            body: EventEditor(
              initialDraft: EventEditorDraft.existing(
                eventId: 'event-1',
                accountId: 'microsoft-account',
                sourceId: 'microsoft-source',
                providerCalendarId: 'ms-cal-1',
                title: 'Planning',
                allDay: false,
                start: DateTime.utc(2026, 6, 8, 9),
                end: DateTime.utc(2026, 6, 8, 10),
                reminders: {
                  'isReminderOn': true,
                  'reminderMinutesBeforeStart': 30,
                },
              ),
              sources: _microsoftSources,
              onCancel: () {},
              onSave: (draft) => saved = draft,
            ),
          ),
        ),
      );

      await tester.ensureVisible(find.byTooltip('Remove reminder'));
      await tester.tap(find.byTooltip('Remove reminder'));
      await tester.pumpAndSettle();
      await tester.tap(_headerButtonFinder('Save'));

      expect(saved?.reminders, {'isReminderOn': false});
    },
  );

  testWidgets('Escape routes dirty event cancellation through confirmation', (
    tester,
  ) async {
    var cancelled = false;
    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: EventEditor(
            initialDraft: EventEditorDraft.newEvent(
              accountId: 'account',
              sourceId: 'source',
              providerCalendarId: 'cal-1',
              start: DateTime.utc(2026, 6, 8),
              end: DateTime.utc(2026, 6, 8, 1),
            ),
            sources: _sources,
            onCancel: () => cancelled = true,
            onSave: (_) {},
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextFormField).first, 'Changed event');
    _focusEditorShortcuts(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(cancelled, isFalse);
    expect(find.text('Discard changes?'), findsOneWidget);

    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(cancelled, isTrue);
  });

  test('event editor is opened through the shared BusyMax dialog route', () {
    final editor = File(
      'lib/src/features/calendar/presentation/event_editor.dart',
    ).readAsStringSync();
    final dialogs = File('lib/src/app/busymax_dialogs.dart').readAsStringSync();
    final workspace = File(
      'lib/src/features/schedule/presentation/schedule_workspace.dart',
    ).readAsStringSync();

    expect(editor, contains('showBusyMaxEventEditorDialog'));
    expect(editor, contains('showBusyMaxModalEditorDialog'));
    expect(editor, isNot(contains('showDialog<EventEditorDialogResult>')));
    expect(dialogs, contains('setModalBarrierVisible(true)'));
    expect(
      dialogs,
      contains('barrierColor ?? busyMaxModalBarrierColor(context)'),
    );
    expect(dialogs, contains('BusyMaxModalEditorSurface'));
    expect(workspace, contains('showBusyMaxEventEditorDialog'));
    expect(workspace, isNot(contains('ScheduleEditorOverlay')));
  });

  test('event editor actions are in the top dialog header', () {
    final editor = File(
      'lib/src/features/calendar/presentation/event_editor.dart',
    ).readAsStringSync();
    final design = File('lib/src/app/busymax_design.dart').readAsStringSync();

    expect(editor, contains('BusyMaxModalEditorScaffold('));
    expect(design, contains('class BusyMaxModalEditorScaffold'));
    expect(design, contains('BusyMaxEditorHeader('));
    expect(design, contains('SingleChildScrollView'));
    final headerStart = design.indexOf('class BusyMaxEditorHeader');
    final headerEnd = design.indexOf('class BusyMaxModeSwitcher');
    final header = design.substring(headerStart, headerEnd);
    expect(header, contains('child: Row('));
    expect(header, contains('AlignmentDirectional.centerStart'));
    expect(header, contains('child: BusyMaxPushButton.standard('));
    expect(header, contains('AlignmentDirectional.centerEnd'));
    expect(header, contains('child: BusyMaxPushButton.suggested('));
    expect(header, contains('heightFactor: 1'));
    expect(header, contains('textTheme.titleSmall'));
    expect(header, isNot(contains('child: FilledButton(')));
    expect(header, isNot(contains('child: ElevatedButton(')));
    expect(header, isNot(contains('NavigationToolbar(')));
    expect(header, isNot(contains('ConstrainedBox(')));
    expect(header, isNot(contains('kPushButtonSize')));
    expect(header, isNot(contains('kYaruButtonHeight')));
    expect(design, isNot(contains('BusyMaxHeaderPushButton')));
    expect(design, contains('textAlign: TextAlign.center'));
    expect(design, contains('textTheme.titleMedium'));
    expect(editor, isNot(contains('BusyMaxDialogCloseButton')));
  });

  test('editor rows reuse the shared Yaru hover role, not a control fill', () {
    final design = File('lib/src/app/busymax_design.dart').readAsStringSync();
    final hoverStart = design.indexOf('Color busyMaxRowHoverColor');
    final hoverEnd = design.indexOf('Color busyMaxPanelBorder');
    final hoverSource = design.substring(hoverStart, hoverEnd);

    expect(hoverSource, contains('return Theme.of(context).hoverColor'));
    expect(hoverSource, contains('return busyMaxRowHoverColor(context)'));
    expect(hoverSource, isNot(contains('.controlHover')));
    expect(hoverSource, isNot(contains('primaryContainer')));
    expect(hoverSource, isNot(contains('colorScheme.primary')));
  });

  test('event editor text fields do not render duplicate section labels', () {
    final editor = File(
      'lib/src/features/calendar/presentation/event_editor.dart',
    ).readAsStringSync();

    expect(editor, isNot(contains('title: l10n.title')));
    expect(editor, isNot(contains('title: l10n.location')));
    expect(editor, isNot(contains('title: l10n.description')));
    expect(editor, contains('labelText: l10n.title'));
    expect(editor, isNot(contains('labelText: l10n.eventTitle')));
  });

  test('event title and location fields share one grouped block', () {
    final editor = File(
      'lib/src/features/calendar/presentation/event_editor.dart',
    ).readAsStringSync();
    final titleLabelIndex = editor.indexOf('labelText: l10n.title');
    final locationLabelIndex = editor.indexOf('labelText: l10n.location');
    final calendarGroupIndex = editor.indexOf(
      'BusyMaxGroupedList(filled: true, children: [_calendarRow()])',
    );

    expect(titleLabelIndex, isNonNegative);
    expect(locationLabelIndex, greaterThan(titleLabelIndex));
    expect(calendarGroupIndex, greaterThan(locationLabelIndex));
  });

  test('event dropdown fields do not render duplicate section labels', () {
    final editor = File(
      'lib/src/features/calendar/presentation/event_editor.dart',
    ).readAsStringSync();

    expect(
      editor,
      isNot(
        contains('BusyMaxGroupedList(\n                    title: l10n.repeat'),
      ),
    );
    expect(
      editor,
      isNot(
        contains(
          'BusyMaxGroupedList(\n                    title: l10n.availabilityShowAs',
        ),
      ),
    );
    expect(
      editor,
      isNot(
        contains(
          'BusyMaxGroupedList(\n                    title: l10n.visibility',
        ),
      ),
    );
  });

  test('event editor text fields use plain borderless decoration', () {
    final editor = File(
      'lib/src/features/calendar/presentation/event_editor.dart',
    ).readAsStringSync();

    expect(editor, contains('_plainEventFieldDecoration'));
    expect(editor, contains('filled: false'));
    expect(editor, contains('fillColor: Colors.transparent'));
    expect(editor, contains('hoverColor: Colors.transparent'));
    expect(editor, contains('labelText: labelText'));
    expect(editor, contains('labelStyle: labelStyle'));
    expect(editor, contains('floatingLabelStyle: labelStyle'));
    expect(
      editor,
      contains('floatingLabelBehavior: FloatingLabelBehavior.auto'),
    );
    expect(editor, contains('enabledBorder: InputBorder.none'));
    expect(editor, contains('focusedBorder: InputBorder.none'));
    expect(editor, contains('errorBorder: InputBorder.none'));
    expect(editor, contains('focusedErrorBorder: InputBorder.none'));
  });

  test(
    'calendar field uses the same combo row pattern as repeat and reminder',
    () {
      final editor = File(
        'lib/src/features/calendar/presentation/event_editor.dart',
      ).readAsStringSync();

      expect(editor, contains('Widget _calendarRow()'));
      expect(editor, contains('return BusyMaxComboRow<String>'));
      expect(editor, contains('title: context.l10n.calendar'));
      expect(editor, contains('leading: const Icon(YaruIcons.calendar)'));
      expect(editor, contains('selectorLeadingBuilder: (context, value)'));
      expect(editor, isNot(contains('menuItemBuilder:')));
      expect(editor, isNot(contains('selectedBuilder:')));
      expect(editor, isNot(contains('_calendarSourceSelectedChoice')));
      expect(editor, contains('class _CalendarSourceDot'));
      expect(editor, contains('source.backgroundColor'));
      expect(editor, contains('ScheduleProjection.deterministicSourceColor'));
      expect(editor, isNot(contains('SourcePicker(')));
      expect(editor, isNot(contains('labelText: l10n.calendar')));
    },
  );

  test('event editor separates time mode, start fields, and end fields', () {
    final editor = File(
      'lib/src/features/calendar/presentation/event_editor.dart',
    ).readAsStringSync();

    final modeIndex = editor.indexOf('BusyMaxTimeModeRow(');
    final startDateIndex = editor.indexOf('label: l10n.startDate');
    final startTimeIndex = editor.indexOf('label: l10n.startTime');
    final endDateIndex = editor.indexOf('label: l10n.endDate');
    final endTimeIndex = editor.indexOf('label: l10n.endTime');

    expect(modeIndex, isNonNegative);
    expect(startDateIndex, greaterThan(modeIndex));
    expect(startTimeIndex, greaterThan(startDateIndex));
    expect(endDateIndex, greaterThan(startTimeIndex));
    expect(endTimeIndex, greaterThan(endDateIndex));
    expect(editor, isNot(contains('BusyMaxSwitchRow(')));
    expect(editor, isNot(contains('label: l10n.endDateTime')));
  });

  test('event editor source does not include metadata panel', () {
    final editor = File(
      'lib/src/features/calendar/presentation/event_editor.dart',
    ).readAsStringSync();

    expect(editor, isNot(contains('l10n.metadata')));
    expect(editor, isNot(contains('l10n.providerCalendar')));
    expect(editor, isNot(contains('YaruExpansionPanel')));
  });

  test('event delete action is centered and event-specific', () {
    final editor = File(
      'lib/src/features/calendar/presentation/event_editor.dart',
    ).readAsStringSync();

    expect(editor, contains('title: l10n.deleteEvent'));
    expect(editor, contains('titleWidget: Center('));
    expect(editor, contains('fontWeight: FontWeight.w700'));
    expect(editor, contains('const SizedBox(height: BusyMaxSpacing.md)'));
    expect(editor, isNot(contains('title: l10n.delete,')));
  });

  test('event combos do not overlay custom selected-value rendering', () {
    final editor = File(
      'lib/src/features/calendar/presentation/event_editor.dart',
    ).readAsStringSync();

    expect(editor, isNot(contains('_eventEditorSelectedValue')));
    expect(editor, isNot(contains('selectedBuilder:')));
    expect(editor, contains('selectorLeadingBuilder:'));
  });

  test('event editor prominent actions use semibold action style', () {
    final editor = File(
      'lib/src/features/calendar/presentation/event_editor.dart',
    ).readAsStringSync();

    expect(editor, contains('_eventEditorProminentActionStyle'));
    expect(editor, contains('FontWeight fontWeight = FontWeight.w600'));
    expect(editor, contains('l10n.addReminder'));
    expect(editor, contains('l10n.addGuest'));
    expect(editor, contains('l10n.deleteEvent'));
  });

  testWidgets('combo selector uses the shared Yaru button trigger', (
    tester,
  ) async {
    final theme = BusyMaxYaruTheme.build(
      brightness: Brightness.light,
      accentColor: const Color(0xFF3584E4),
    );
    final colors = theme.extension<BusyMaxSurfaceColors>()!;
    await tester.pumpWidget(
      localizedTestApp(
        child: Theme(
          data: theme,
          child: SizedBox(
            width: 480,
            child: BusyMaxComboRow<String>(
              title: 'Calendar',
              values: const ['Personal', 'Work'],
              selected: 'Personal',
              labelFor: (value) => value,
              onSelected: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(find.byType(BusyMaxComboBox<String>), findsOneWidget);
    final triggerFinder = find.descendant(
      of: find.byType(BusyMaxComboBox<String>),
      matching: find.byWidgetPredicate(
        (widget) => widget is ButtonStyleButton && widget is! IconButton,
      ),
    );
    final trigger = tester.widget<ButtonStyleButton>(triggerFinder);
    expect(trigger.style, isNull);
    expect(trigger.onPressed, isNotNull);
    expect(tester.getSize(triggerFinder).height, kYaruButtonHeight);
    final restingSurface = tester.widget<Material>(
      find.descendant(of: triggerFinder, matching: find.byType(Material)).first,
    );
    expect(restingSurface.type, MaterialType.button);
    expect(restingSurface.color, colors.control);
    expect(restingSurface.color, isNot(Colors.transparent));
  });
}

Finder _headerButtonFinder(String label) {
  return find
      .ancestor(
        of: find.text(label),
        matching: find.byWidgetPredicate(
          (widget) => widget is ButtonStyleButton,
        ),
      )
      .first;
}

BusyMaxComboRow<String> _comboRow(WidgetTester tester, String title) {
  return tester.widget<BusyMaxComboRow<String>>(
    find.byWidgetPredicate(
      (widget) => widget is BusyMaxComboRow<String> && widget.title == title,
    ),
  );
}

Finder _timeEntryFinder() => find.byType(YaruTimeEntry);

Future<void> _enterTime(
  WidgetTester tester, {
  required String hour,
  required String minute,
}) async {
  final entry = _timeEntryFinder();
  await tester.tap(entry);
  await tester.enterText(entry, hour);
  await tester.pump();
  await tester.enterText(entry, minute);
  await tester.pump();
}

Finder _plainTextFinder(String label) {
  return find.byWidgetPredicate(
    (widget) => widget is Text && widget.data == label,
  );
}

void _focusEditorShortcuts(WidgetTester tester) {
  final focusFinder = find.descendant(
    of: find.byType(EventEditor),
    matching: find.byWidgetPredicate(
      (widget) =>
          widget is Focus &&
          widget.focusNode?.debugLabel == 'Event editor shortcuts',
    ),
  );
  final focusWidget = tester.widget<Focus>(focusFinder);
  focusWidget.focusNode!.requestFocus();
}

const _sources = [
  CalendarSourceEntity(
    id: 'source',
    accountId: 'account',
    provider: TaskProvider.google,
    providerCalendarId: 'cal-1',
    summary: 'Work',
    selected: true,
    hidden: false,
    readOnly: false,
    isDeleted: false,
    backgroundColor: '#3584e4',
  ),
];

const _multipleSources = [
  ..._sources,
  CalendarSourceEntity(
    id: 'destination-source',
    accountId: 'account',
    provider: TaskProvider.google,
    providerCalendarId: 'cal-2',
    summary: 'Personal',
    selected: true,
    hidden: false,
    readOnly: false,
    isDeleted: false,
    backgroundColor: '#33d17a',
  ),
];

const _microsoftSources = [
  CalendarSourceEntity(
    id: 'microsoft-source',
    accountId: 'microsoft-account',
    provider: TaskProvider.microsoft,
    providerCalendarId: 'ms-cal-1',
    summary: 'Outlook',
    selected: true,
    hidden: false,
    readOnly: false,
    isDeleted: false,
    backgroundColor: '#9141ac',
  ),
];

const _mixedProviderSources = [..._sources, ..._microsoftSources];

const _microsoftRecurrenceCases = <String, Map<String, Object?>>{
  'daily': {'type': 'daily', 'interval': 1},
  'weekly': {
    'type': 'weekly',
    'interval': 1,
    'daysOfWeek': ['wednesday'],
    'firstDayOfWeek': 'sunday',
  },
  'monthly': {'type': 'absoluteMonthly', 'interval': 1, 'dayOfMonth': 10},
  'yearly': {
    'type': 'absoluteYearly',
    'interval': 1,
    'dayOfMonth': 10,
    'month': 6,
  },
};

const _microsoftReanchoredRecurrenceCases = <String, Map<String, Object?>>{
  'daily': {'type': 'daily', 'interval': 1},
  'weekly': {
    'type': 'weekly',
    'interval': 1,
    'daysOfWeek': ['saturday'],
    'firstDayOfWeek': 'sunday',
  },
  'monthly': {'type': 'absoluteMonthly', 'interval': 1, 'dayOfMonth': 11},
  'yearly': {
    'type': 'absoluteYearly',
    'interval': 1,
    'dayOfMonth': 11,
    'month': 7,
  },
};
