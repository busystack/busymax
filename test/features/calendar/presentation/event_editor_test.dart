import 'dart:io';

import 'package:busymax/src/features/accounts/data/accounts_repository.dart';
import 'package:busymax/src/features/calendar/data/calendar_repository.dart';
import 'package:busymax/src/features/calendar/presentation/event_editor.dart';
import 'package:busymax/src/features/calendar/presentation/event_editor_draft.dart';
import 'package:busymax/src/features/recurrence/domain/recurrence_rule.dart';
import 'package:busymax/src/features/recurrence/presentation/recurrence_editor.dart';
import 'package:busymax/src/features/tasks/presentation/desktop_date_time_fields.dart';
import 'package:busymax/src/app/busymax_design.dart';
import 'package:busymax/src/app/busymax_yaru_theme.dart';
import 'package:busymax/src/platform/native_dialog_service.dart';
import 'package:busymax/src/platform/native_menu_service.dart';
import 'package:busymax/src/providers/busy_provider.dart';
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

  testWidgets(
    'missing calendar source is surfaced without a provider fallback',
    (tester) async {
      EventEditorDraft? saved;
      await tester.pumpWidget(
        localizedTestApp(
          child: Scaffold(
            body: EventEditor(
              initialDraft: EventEditorDraft.newEvent(
                accountId: 'missing-account',
                sourceId: 'missing-source',
                providerCalendarId: 'missing-calendar',
                start: DateTime.utc(2026, 6, 8),
                end: DateTime.utc(2026, 6, 8, 1),
              ),
              sources: const [],
              onCancel: () {},
              onSave: (draft) => saved = draft,
            ),
          ),
        ),
      );

      expect(find.text('No calendars synced yet.'), findsOneWidget);
      expect(_headerButton(tester, 'Save').onPressed, isNull);
      expect(saved, isNull);
    },
  );

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

  testWidgets('event editor groups use the contextual semantic card layer', (
    tester,
  ) async {
    final theme = BusyMaxYaruTheme.build(
      brightness: Brightness.dark,
      accentColor: const Color(0xFF3584E4),
    );
    final colors = theme.extension<BusyMaxSurfaceColors>()!;
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      localizedTestApp(
        theme: theme,
        child: Scaffold(
          body: BusyMaxModalEditorSurface(
            maxWidth: 640,
            maxHeight: 720,
            child: EventEditor(
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
      ),
    );

    final groupedMaterials = tester.widgetList<Material>(
      find.descendant(
        of: find.byType(BusyMaxGroupedSurface),
        matching: find.byWidgetPredicate(
          (widget) => widget is Material && widget.color == colors.card,
        ),
      ),
    );
    expect(groupedMaterials, isNotEmpty);
    expect(colors.groupedSurface.a, lessThan(1));
    expect(colors.card.a, 1);
    expect(
      groupedMaterials.every((material) => material.color?.a == 1),
      isTrue,
    );
    expect(
      Color.alphaBlend(colors.groupedSurface, colors.window).toARGB32(),
      colors.card.toARGB32(),
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

    expect(_timeRowFinder('Start time'), findsNothing);
    expect(_timeRowFinder('End Time'), findsNothing);
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

  testWidgets('timed event gives date and time fields contextual labels', (
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

    expect(find.text('Start date/time'), findsOneWidget);
    expect(find.text('End date/time'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is DesktopDateValueRow && widget.label == 'Start date',
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is DesktopTimeValueRow && widget.label == 'Start time',
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) => widget is DesktopDateValueRow && widget.label == 'End Date',
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) => widget is DesktopTimeValueRow && widget.label == 'End Time',
      ),
      findsOneWidget,
    );
  });

  testWidgets('existing timed event renders all date and time values', (
    tester,
  ) async {
    await tester.pumpWidget(
      localizedTestApp(
        alwaysUse24HourFormat: true,
        child: Scaffold(
          body: EventEditor(
            initialDraft: EventEditorDraft.existing(
              eventId: 'event-1',
              accountId: 'account',
              sourceId: 'source',
              providerCalendarId: 'cal-1',
              title: 'Planning',
              allDay: false,
              start: DateTime(2026, 6, 8, 9, 15),
              end: DateTime(2026, 6, 8, 10, 45),
            ),
            sources: _sources,
            onCancel: () {},
            onSave: (_) {},
          ),
        ),
      ),
    );

    final startDate = _dateTextField(tester, 'Start date');
    final startTime = _timeTextField(tester, 'Start time');
    final endDate = _dateTextField(tester, 'End Date');
    final endTime = _timeTextField(tester, 'End Time');

    expect(startDate.controller?.text, isNotEmpty);
    expect(startTime.controller?.text, '09:15');
    expect(endDate.controller?.text, isNotEmpty);
    expect(endTime.controller?.text, '10:45');
    expect(startDate.decoration?.labelText, 'Start date');
    expect(startTime.decoration?.labelText, 'Start time');
    expect(endDate.decoration?.labelText, 'End Date');
    expect(endTime.decoration?.labelText, 'End Time');
    expect(find.text('Enter date'), findsNothing);
    expect(find.text('Enter time'), findsNothing);
  });

  testWidgets('event time entry reports an empty required value', (
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

    final fieldFinder = _timeEntryFinder('Start time');
    await tester.ensureVisible(fieldFinder);
    var entry = tester.widget<TextFormField>(fieldFinder);
    expect(
      parseDesktopTimeInput(
        tester.element(fieldFinder),
        entry.controller?.text ?? '',
      ),
      const TimeOfDay(hour: 9, minute: 0),
      reason: 'visible value: ${entry.controller?.text}',
    );

    await tester.tap(fieldFinder);
    await tester.pump();
    await _clearTimeEntry(tester, 'Start time');

    expect(tester.takeException(), isNull);
    entry = tester.widget<TextFormField>(fieldFinder);
    expect(entry.controller?.text, isEmpty);
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    entry = tester.widget<TextFormField>(fieldFinder);
    expect(entry.controller?.text, isEmpty);
    expect(
      find.text(
        MaterialLocalizations.of(tester.element(fieldFinder)).invalidTimeLabel,
      ),
      findsOneWidget,
    );
    expect(find.text('OK'), findsNothing);
  });

  testWidgets(
    'invalid visible start time disables Save and Ctrl+S and makes Cancel confirm',
    (tester) async {
      var saveCalls = 0;
      var cancelled = false;
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
              onCancel: () => cancelled = true,
              onSave: (_) => saveCalls += 1,
            ),
          ),
        ),
      );

      final startTime = _timeEntryFinder('Start time');
      await tester.enterText(startTime, 'not a time');
      await tester.pump();

      final saveButton = tester.widget<ButtonStyleButton>(
        _headerButtonFinder('Save'),
      );
      expect(saveButton.onPressed, isNull);
      expect(
        find.text(
          MaterialLocalizations.of(tester.element(startTime)).invalidTimeLabel,
        ),
        findsOneWidget,
      );

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();

      expect(saveCalls, 0);

      await tester.tap(_headerButtonFinder('Cancel'));
      await tester.pumpAndSettle();

      expect(cancelled, isFalse);
      expect(find.text('Discard changes?'), findsOneWidget);

      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();

      expect(cancelled, isTrue);
      expect(saveCalls, 0);
    },
  );

  testWidgets('switching an invalid timed event to all-day clears validity', (
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

    await tester.enterText(_timeEntryFinder('Start time'), 'not a time');
    await tester.pump();
    expect(
      tester.widget<ButtonStyleButton>(_headerButtonFinder('Save')).onPressed,
      isNull,
    );

    await tester.tap(_plainTextFinder('All day'));
    await tester.pumpAndSettle();

    expect(_timeRowFinder('Start time'), findsNothing);
    expect(_timeRowFinder('End Time'), findsNothing);
    expect(
      tester.widget<ButtonStyleButton>(_headerButtonFinder('Save')).onPressed,
      isNotNull,
    );

    await tester.tap(_headerButtonFinder('Save'));
    await tester.pump();

    expect(saved?.allDay, isTrue);
  });

  testWidgets('event time field accepts midnight input', (tester) async {
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

    final fieldFinder = _timeEntryFinder('Start time');
    await tester.ensureVisible(fieldFinder);
    await tester.tap(fieldFinder);
    await tester.pump();
    await _clearTimeEntry(tester, 'Start time');
    await _enterTime(tester, label: 'Start time', hour: '00', minute: '00');

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
            onDelete: (eventId, _) => deletedEventId = eventId,
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
            onDelete: (eventId, _) => deletedEventId = eventId,
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

  testWidgets('recurrence editor creates a biweekly weekday schedule', (
    tester,
  ) async {
    EventEditorDraft? saved;
    final initial =
        EventEditorDraft.newEvent(
          accountId: 'account',
          sourceId: 'source',
          providerCalendarId: 'cal-1',
          start: DateTime(2026, 6, 10, 9),
          end: DateTime(2026, 6, 10, 10),
        ).copyWith(
          title: 'Planning',
          recurrence: const ['RRULE:FREQ=DAILY;INTERVAL=1;COUNT=10'],
        );
    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: EventEditor(
            initialDraft: initial,
            sources: _sources,
            onCancel: () {},
            onSave: (draft) => saved = draft,
          ),
        ),
      ),
    );

    _actionRow(tester, 'Repeat').onTap!();
    await tester.pumpAndSettle();
    final dialog = find.byType(RecurrenceEditorDialog);
    expect(dialog, findsOneWidget);
    tester
        .widget<BusyMaxComboRow<RecurrenceFrequency>>(
          find.descendant(
            of: dialog,
            matching: find.byType(BusyMaxComboRow<RecurrenceFrequency>),
          ),
        )
        .onSelected(RecurrenceFrequency.weekly);
    await tester.pump();

    final fields = find.descendant(
      of: dialog,
      matching: find.byType(TextField),
    );
    await tester.enterText(fields.at(0), '2');
    await tester.enterText(fields.at(1), '9');
    var weekdays = tester.widget<YaruChoiceChipBar>(
      find.descendant(of: dialog, matching: find.byType(YaruChoiceChipBar)),
    );
    weekdays.onSelected!(0);
    await tester.pump();
    weekdays = tester.widget<YaruChoiceChipBar>(
      find.descendant(of: dialog, matching: find.byType(YaruChoiceChipBar)),
    );
    weekdays.onSelected!(4);
    await tester.pump();

    await tester.tap(
      find.descendant(
        of: dialog,
        matching: find.widgetWithText(ElevatedButton, 'Save'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Every 2 weeks'), findsOneWidget);
    await tester.tap(_headerButtonFinder('Save'));

    expect(saved?.recurrence, const [
      'RRULE:FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,WE,FR;WKST=MO;COUNT=9',
    ]);
  });

  testWidgets('Microsoft recurrence range follows a changed start date', (
    tester,
  ) async {
    EventEditorDraft? saved;
    final initial =
        EventEditorDraft.newEvent(
          accountId: 'microsoft-account',
          sourceId: 'microsoft-source',
          providerCalendarId: 'ms-cal-1',
          start: DateTime(2026, 6, 9, 9),
          end: DateTime(2026, 6, 9, 10),
        ).copyWith(
          title: 'Planning',
          recurrence: const {
            'pattern': {
              'type': 'relativeMonthly',
              'interval': 1,
              'daysOfWeek': ['tuesday'],
              'index': 'second',
            },
            'range': {
              'type': 'endDate',
              'startDate': '2026-06-09',
              'endDate': '2026-12-31',
            },
          },
        );
    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: EventEditor(
            initialDraft: initial,
            sources: _microsoftSources,
            onCancel: () {},
            onSave: (draft) => saved = draft,
          ),
        ),
      ),
    );

    tester
        .widget<DesktopDateValueRow>(
          find.byWidgetPredicate(
            (widget) =>
                widget is DesktopDateValueRow && widget.label == 'Start date',
          ),
        )
        .onChanged('2026-07-14');
    await tester.pump();
    await tester.tap(_headerButtonFinder('Save'));

    expect(saved?.recurrence, const {
      'pattern': {
        'type': 'relativeMonthly',
        'interval': 1,
        'daysOfWeek': ['tuesday'],
        'index': 'second',
      },
      'range': {
        'type': 'endDate',
        'startDate': '2026-07-14',
        'endDate': '2026-12-31',
      },
    });
  });

  testWidgets('new event converts rich recurrence when provider changes', (
    tester,
  ) async {
    EventEditorDraft? saved;
    final initial =
        EventEditorDraft.newEvent(
          accountId: 'account',
          sourceId: 'source',
          providerCalendarId: 'cal-1',
          start: DateTime(2026, 6, 10, 9),
          end: DateTime(2026, 6, 10, 10),
        ).copyWith(
          title: 'Planning',
          recurrence: const [
            'RRULE:FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,WE,FR;WKST=MO;COUNT=9',
          ],
        );
    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: EventEditor(
            initialDraft: initial,
            sources: _mixedProviderSources,
            onCancel: () {},
            onSave: (draft) => saved = draft,
          ),
        ),
      ),
    );

    _comboRow(tester, 'Account').onSelected('microsoft-account');
    await tester.pump();
    await tester.tap(_headerButtonFinder('Save'));

    expect(saved?.recurrence, const {
      'pattern': {
        'type': 'weekly',
        'interval': 2,
        'daysOfWeek': ['monday', 'wednesday', 'friday'],
        'firstDayOfWeek': 'monday',
      },
      'range': {
        'type': 'numbered',
        'startDate': '2026-06-10',
        'numberOfOccurrences': 9,
      },
    });
  });

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

  testWidgets('DAV recurring event exposes every RFC-supported scope', (
    tester,
  ) async {
    EventEditorDraft? saved;
    String? deletedId;
    RecurringEventMutationScope? deletedScope;
    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: EventEditor(
            initialDraft: EventEditorDraft.existing(
              eventId: 'dav-occurrence',
              providerRecurringEventId: 'dav-series',
              accountId: 'nextcloud-account',
              sourceId: 'nextcloud-source',
              providerCalendarId: '/calendars/work/',
              title: 'Weekly planning',
              allDay: false,
              start: DateTime.utc(2026, 6, 8, 9),
              end: DateTime.utc(2026, 6, 8, 10),
            ),
            sources: _nextcloudSources,
            onCancel: () {},
            onSave: (draft) => saved = draft,
            onDelete: (eventId, scope) {
              deletedId = eventId;
              deletedScope = scope;
            },
          ),
        ),
      ),
    );

    expect(find.text('Recurring event scope'), findsOneWidget);
    expect(find.text('Entire series'), findsOneWidget);
    expect(find.text('This event'), findsOneWidget);
    expect(find.text('This and following events'), findsOneWidget);
    expect(find.text('Not supported by this provider.'), findsNothing);
    expect(_headerButton(tester, 'Save').onPressed, isNull);
    expect(_actionRow(tester, 'Delete Event').onTap, isNull);
    expect(_actionRow(tester, 'This and following events').enabled, isTrue);

    await tester.ensureVisible(find.text('This and following events'));
    await tester.tap(find.text('This and following events'));
    await tester.pump();
    expect(_headerButton(tester, 'Save').onPressed, isNull);
    await tester.enterText(
      find.byType(TextFormField).first,
      'Changed following events',
    );
    await tester.pump();
    expect(_headerButton(tester, 'Save').onPressed, isNotNull);
    expect(_actionRow(tester, 'Delete Event').onTap, isNotNull);
    await tester.tap(_headerButtonFinder('Save'));
    expect(
      saved?.recurringMutationScope,
      RecurringEventMutationScope.thisAndFuture,
    );

    await tester.ensureVisible(find.text('This event'));
    await tester.tap(find.text('This event'));
    await tester.pump();
    await tester.ensureVisible(find.text('Delete Event'));
    await tester.tap(find.text('Delete Event'));
    expect(deletedId, 'dav-occurrence');
    expect(deletedScope, RecurringEventMutationScope.singleOccurrence);
  });

  testWidgets('Google recurring event exposes this-and-following scope', (
    tester,
  ) async {
    EventEditorDraft? saved;
    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: EventEditor(
            initialDraft: EventEditorDraft.existing(
              eventId: 'google-occurrence',
              providerRecurringEventId: 'google-series',
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
            onSave: (draft) => saved = draft,
          ),
        ),
      ),
    );

    expect(_actionRow(tester, 'This and following events').enabled, isTrue);
    await tester.ensureVisible(find.text('This and following events'));
    await tester.tap(find.text('This and following events'));
    await tester.pump();
    expect(_headerButton(tester, 'Save').onPressed, isNull);
    await tester.enterText(
      find.byType(TextFormField).first,
      'Changed following events',
    );
    await tester.pump();
    await tester.tap(_headerButtonFinder('Save'));

    expect(
      saved?.recurringMutationScope,
      RecurringEventMutationScope.thisAndFuture,
    );
  });

  testWidgets(
    'Microsoft recurring event disables undocumented following scope',
    (tester) async {
      await tester.pumpWidget(
        localizedTestApp(
          child: Scaffold(
            body: EventEditor(
              initialDraft: EventEditorDraft.existing(
                eventId: 'microsoft-occurrence',
                providerRecurringEventId: 'microsoft-series',
                accountId: 'microsoft-account',
                sourceId: 'microsoft-source',
                providerCalendarId: 'ms-cal-1',
                title: 'Weekly planning',
                allDay: false,
                start: DateTime.utc(2026, 6, 8, 9),
                end: DateTime.utc(2026, 6, 8, 10),
              ),
              sources: _microsoftSources,
              onCancel: () {},
              onSave: (_) {},
            ),
          ),
        ),
      );

      expect(_actionRow(tester, 'This and following events').enabled, isFalse);
      expect(find.text('Not supported by this provider.'), findsOneWidget);
    },
  );

  testWidgets('moving a Google series natively allows the entire series', (
    tester,
  ) async {
    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: EventEditor(
            initialDraft: EventEditorDraft.existing(
              eventId: 'google-occurrence',
              providerRecurringEventId: 'google-series',
              accountId: 'account',
              sourceId: 'source',
              providerCalendarId: 'cal-1',
              title: 'Weekly planning',
              allDay: false,
              start: DateTime.utc(2026, 6, 8, 9),
              end: DateTime.utc(2026, 6, 8, 10),
            ),
            sources: _multipleSources,
            onCancel: () {},
            onSave: (_) {},
          ),
        ),
      ),
    );

    _comboRow(tester, 'Calendar').onSelected('destination-source');
    await tester.pump();

    expect(_actionRow(tester, 'This event').enabled, isTrue);
    expect(_actionRow(tester, 'This and following events').enabled, isFalse);
    expect(_actionRow(tester, 'Entire series').enabled, isTrue);
    expect(
      find.text(
        'This and following events cannot be moved safely. '
        'Choose this event or the entire series.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('native Google move preserves an unsupported recurrence rule', (
    tester,
  ) async {
    EventEditorDraft? saved;
    const recurrence = ['RRULE:FREQ=WEEKLY;BYHOUR=9'];
    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: EventEditor(
            initialDraft: EventEditorDraft.existing(
              eventId: 'google-occurrence',
              providerRecurringEventId: 'google-series',
              accountId: 'account',
              sourceId: 'source',
              providerCalendarId: 'cal-1',
              title: 'Weekly planning',
              allDay: false,
              start: DateTime.utc(2026, 6, 8, 9),
              end: DateTime.utc(2026, 6, 8, 10),
              recurrence: recurrence,
            ),
            sources: _multipleSources,
            onCancel: () {},
            onSave: (draft) => saved = draft,
          ),
        ),
      ),
    );

    _comboRow(tester, 'Calendar').onSelected('destination-source');
    await tester.pump();
    await tester.ensureVisible(find.text('Entire series'));
    await tester.tap(find.text('Entire series'));
    await tester.pump();
    await tester.enterText(
      find.byType(TextFormField).first,
      'Moved weekly planning',
    );
    await tester.pump();
    await tester.tap(_headerButtonFinder('Save'));

    expect(saved?.recurrence, recurrence);
    expect(saved?.recurrenceChanged, isFalse);
    expect(
      saved?.recurringMutationScope,
      RecurringEventMutationScope.entireSeries,
    );
  });

  testWidgets('copying a series requires a locally available recurrence rule', (
    tester,
  ) async {
    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: EventEditor(
            initialDraft: EventEditorDraft.existing(
              eventId: 'google-occurrence',
              providerRecurringEventId: 'google-series',
              accountId: 'google-account',
              sourceId: 'google-work',
              providerCalendarId: 'google-work-calendar',
              title: 'Weekly planning',
              allDay: false,
              start: DateTime.utc(2026, 6, 8, 9),
              end: DateTime.utc(2026, 6, 8, 10),
            ),
            sources: _sameNamedCrossAccountSources,
            accounts: _eventAccounts,
            onCancel: () {},
            onSave: (_) {},
          ),
        ),
      ),
    );

    _comboRow(tester, 'Account').onSelected('microsoft-account');
    await tester.pump();

    expect(_actionRow(tester, 'This event').enabled, isTrue);
    expect(_actionRow(tester, 'This and following events').enabled, isFalse);
    expect(_actionRow(tester, 'Entire series').enabled, isFalse);
    expect(
      find.text(
        'The recurrence rule is not available locally. '
        'Move this event instead.',
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'an occurrence with unsupported recurrence can move as one event',
    (tester) async {
      EventEditorDraft? saved;
      const recurrence = ['RRULE:FREQ=WEEKLY;BYHOUR=9'];
      await tester.pumpWidget(
        localizedTestApp(
          child: Scaffold(
            body: EventEditor(
              initialDraft: EventEditorDraft.existing(
                eventId: 'google-occurrence',
                providerRecurringEventId: 'google-series',
                accountId: 'google-account',
                sourceId: 'google-work',
                providerCalendarId: 'google-work-calendar',
                title: 'Weekly planning',
                allDay: false,
                start: DateTime.utc(2026, 6, 8, 9),
                end: DateTime.utc(2026, 6, 8, 10),
                recurrence: recurrence,
              ),
              sources: _sameNamedCrossAccountSources,
              accounts: _eventAccounts,
              onCancel: () {},
              onSave: (draft) => saved = draft,
            ),
          ),
        ),
      );

      _comboRow(tester, 'Account').onSelected('microsoft-account');
      await tester.pump();

      expect(_comboRow(tester, 'Account').selected, 'microsoft-account');
      expect(_actionRow(tester, 'This event').enabled, isTrue);
      expect(_actionRow(tester, 'Entire series').enabled, isFalse);
      await tester.ensureVisible(find.text('This event'));
      await tester.tap(find.text('This event'));
      await tester.pump();
      await tester.enterText(
        find.byType(TextFormField).first,
        'Moved occurrence',
      );
      await tester.pump();
      await tester.tap(_headerButtonFinder('Save'));

      expect(saved?.sourceId, 'microsoft-work');
      expect(saved?.recurrence, recurrence);
      expect(
        saved?.recurringMutationScope,
        RecurringEventMutationScope.singleOccurrence,
      );
    },
  );

  testWidgets(
    'DAV event keeps guests display-only and exposes categories and alarms',
    (tester) async {
      await tester.pumpWidget(
        localizedTestApp(
          child: Scaffold(
            body: EventEditor(
              initialDraft: EventEditorDraft.existing(
                eventId: 'dav-event',
                accountId: 'nextcloud-account',
                sourceId: 'nextcloud-source',
                providerCalendarId: '/calendars/work/',
                title: 'Planning',
                allDay: false,
                start: DateTime.utc(2026, 6, 8, 9),
                end: DateTime.utc(2026, 6, 8, 10),
                attendees: const [
                  EventAttendeeDraft(
                    email: 'guest@example.test',
                    displayName: 'Guest',
                  ),
                ],
                categories: const ['Work'],
                reminders: const {
                  'useDefault': false,
                  'overrides': [
                    {'method': 'popup', 'minutes': 10},
                    {'method': 'popup', 'minutes': 30},
                  ],
                },
                showAs: 'transparent',
                visibilityOrSensitivity: 'confidential',
              ),
              sources: _nextcloudSources,
              onCancel: () {},
              onSave: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('guest@example.test'), findsOneWidget);
      expect(find.text('Guest'), findsOneWidget);
      expect(find.text('Add guest email'), findsNothing);
      expect(find.text('Add guest'), findsNothing);
      expect(find.text('Work'), findsWidgets);
      expect(find.byType(BusyMaxComboRow<int>), findsNWidgets(2));
      expect(
        _comboRow(tester, 'Availability / Show as').selected,
        'transparent',
      );
      expect(_comboRow(tester, 'Visibility').selected, 'confidential');
    },
  );

  testWidgets('Nextcloud recurrence editor preserves a rich RFC rule', (
    tester,
  ) async {
    EventEditorDraft? saved;
    final initial =
        EventEditorDraft.newEvent(
          accountId: 'nextcloud-account',
          sourceId: 'nextcloud-source',
          providerCalendarId: '/calendars/work/',
          start: DateTime(2026, 6, 9, 9),
          end: DateTime(2026, 6, 9, 10),
        ).copyWith(
          title: 'Planning',
          recurrence: const {
            'rules': ['FREQ=MONTHLY;INTERVAL=1;BYDAY=TU;BYSETPOS=2;COUNT=6'],
            'dates': <String>[],
            'excludedDates': <String>[],
          },
        );
    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: EventEditor(
            initialDraft: initial,
            sources: _nextcloudSources,
            onCancel: () {},
            onSave: (draft) => saved = draft,
          ),
        ),
      ),
    );

    _actionRow(tester, 'Repeat').onTap!();
    await tester.pumpAndSettle();
    final dialog = find.byType(RecurrenceEditorDialog);
    expect(find.text('Second'), findsWidgets);
    expect(find.text('Tuesday'), findsWidgets);
    await tester.tap(
      find.descendant(
        of: dialog,
        matching: find.widgetWithText(ElevatedButton, 'Save'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(_headerButtonFinder('Save'));

    expect(saved?.recurrence, const {
      'rules': ['FREQ=MONTHLY;INTERVAL=1;BYDAY=TU;BYSETPOS=2;COUNT=6'],
      'dates': <String>[],
      'excludedDates': <String>[],
    });
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
            onDelete: (_, _) {},
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
            onDelete: (_, _) {},
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

  testWidgets('existing event exposes writable destination calendars', (
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
            onDelete: (_, _) {},
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
    expect(calendarRow.values, ['destination-source', 'source']);
    expect(calendarRow.enabled, isTrue);
    final accountRow = _comboRow(tester, 'Account');
    expect(accountRow.selected, 'account');
    expect(accountRow.values, ['account']);
    expect(accountRow.enabled, isFalse);
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

    expect(calendarRow.values, ['destination-source', 'source']);
    expect(calendarRow.enabled, isTrue);
  });

  testWidgets(
    'new event selects an account before choosing among its calendars',
    (tester) async {
      EventEditorDraft? saved;
      await tester.pumpWidget(
        localizedTestApp(
          child: Scaffold(
            body: EventEditor(
              initialDraft: EventEditorDraft.newEvent(
                accountId: 'google-account',
                sourceId: 'google-work',
                providerCalendarId: 'google-work-calendar',
                start: DateTime.utc(2026, 6, 8, 9),
                end: DateTime.utc(2026, 6, 8, 10),
              ).copyWith(title: 'Planning'),
              sources: _sameNamedCrossAccountSources,
              accounts: _eventAccounts,
              onCancel: () {},
              onSave: (draft) => saved = draft,
            ),
          ),
        ),
      );

      var accountRow = _comboRow(tester, 'Account');
      var calendarRow = _comboRow(tester, 'Calendar');
      expect(accountRow.values, ['google-account', 'microsoft-account']);
      expect(accountRow.selected, 'google-account');
      expect(
        accountRow.labelFor('google-account'),
        'Google · personal@example.test',
      );
      expect(
        accountRow.labelFor('microsoft-account'),
        'Microsoft · work@example.test',
      );
      expect(calendarRow.values, ['google-work']);
      expect(calendarRow.labelFor('google-work'), 'Work');

      final accountSemantics = tester.widget<Semantics>(
        find.descendant(
          of: find.byType(BusyMaxComboRow<String>),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Semantics && widget.properties.label == 'Account',
          ),
        ),
      );
      expect(
        accountSemantics.properties.value,
        'Google · personal@example.test',
      );

      accountRow.onSelected('microsoft-account');
      await tester.pump();

      accountRow = _comboRow(tester, 'Account');
      calendarRow = _comboRow(tester, 'Calendar');
      expect(accountRow.selected, 'microsoft-account');
      expect(calendarRow.values, ['microsoft-work']);
      expect(calendarRow.selected, 'microsoft-work');
      expect(calendarRow.labelFor('microsoft-work'), 'Work');

      await tester.tap(_headerButtonFinder('Save'));
      expect(saved?.accountId, 'microsoft-account');
      expect(saved?.sourceId, 'microsoft-work');
      expect(saved?.providerCalendarId, 'microsoft-work-calendar');
    },
  );

  testWidgets('changing event account selects its primary writable calendar', (
    tester,
  ) async {
    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: EventEditor(
            initialDraft: EventEditorDraft.newEvent(
              accountId: 'google-account',
              sourceId: 'google-work',
              providerCalendarId: 'google-work-calendar',
              start: DateTime.utc(2026, 6, 8, 9),
              end: DateTime.utc(2026, 6, 8, 10),
            ),
            sources: _sourcesWithMicrosoftPrimary,
            accounts: _eventAccounts,
            onCancel: () {},
            onSave: (_) {},
          ),
        ),
      ),
    );

    _comboRow(tester, 'Account').onSelected('microsoft-account');
    await tester.pump();

    final calendarRow = _comboRow(tester, 'Calendar');
    expect(calendarRow.values, ['microsoft-primary', 'microsoft-work']);
    expect(calendarRow.selected, 'microsoft-primary');
    expect(calendarRow.labelFor(calendarRow.selected), 'Calendar');
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

  testWidgets('guest requirement can be changed to optional', (tester) async {
    EventEditorDraft? saved;
    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: EventEditor(
            initialDraft:
                EventEditorDraft.newEvent(
                  accountId: 'account',
                  sourceId: 'source',
                  providerCalendarId: 'cal-1',
                  start: DateTime.utc(2026, 6, 8, 9),
                  end: DateTime.utc(2026, 6, 8, 10),
                ).copyWith(
                  title: 'Planning',
                  attendees: const [
                    EventAttendeeDraft(email: 'guest@example.com'),
                  ],
                ),
            sources: _sources,
            onCancel: () {},
            onSave: (draft) => saved = draft,
          ),
        ),
      ),
    );

    final guestRow = tester.widget<BusyMaxComboRow<bool>>(
      find.byWidgetPredicate(
        (widget) =>
            widget is BusyMaxComboRow<bool> &&
            widget.title == 'guest@example.com',
      ),
    );
    expect(guestRow.selected, isFalse);
    guestRow.onSelected(true);
    await tester.pump();
    await tester.tap(_headerButtonFinder('Save'));

    expect(saved?.attendees.single.optional, isTrue);
  });

  testWidgets('Google editor exposes Meet and guest visibility controls', (
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

    _switchRow(tester, 'Add Google Meet').onChanged(true);
    _switchRow(tester, 'Hide guest list').onChanged(true);
    await tester.pump();
    await tester.tap(_headerButtonFinder('Save'));

    expect(saved?.createConference, isTrue);
    expect(saved?.hideAttendees, isTrue);
  });

  testWidgets('Google editor only offers Meet on supported calendars', (
    tester,
  ) async {
    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: EventEditor(
            initialDraft: EventEditorDraft.newEvent(
              accountId: 'google-account',
              sourceId: 'google-work',
              providerCalendarId: 'google-work-calendar',
              start: DateTime.utc(2026, 6, 8, 9),
              end: DateTime.utc(2026, 6, 8, 10),
            ).copyWith(title: 'Planning'),
            sources: _sameNamedCrossAccountSources,
            onCancel: () {},
            onSave: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Add Google Meet'), findsNothing);
    expect(find.text('Hide guest list'), findsOneWidget);
  });

  testWidgets('Microsoft editor exposes supported meeting options', (
    tester,
  ) async {
    EventEditorDraft? saved;
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
            onSave: (draft) => saved = draft,
          ),
        ),
      ),
    );

    _switchRow(tester, 'Add Microsoft Teams meeting').onChanged(true);
    _switchRow(tester, 'Request responses').onChanged(false);
    _switchRow(tester, 'Hide guest list').onChanged(true);
    _switchRow(tester, 'Allow new time proposals').onChanged(false);
    _comboRow(tester, 'Importance').onSelected('high');
    await tester.pump();
    await tester.tap(_headerButtonFinder('Save'));

    expect(saved?.createConference, isTrue);
    expect(saved?.responseRequested, isFalse);
    expect(saved?.hideAttendees, isTrue);
    expect(saved?.allowNewTimeProposals, isFalse);
    expect(saved?.importance, 'high');
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
        of: find.byType(BusyMaxComboRow<int>),
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
    expect(dialogs, contains('await acquireBusyMaxModalBarrier('));
    expect(dialogs, contains('await releaseBusyMaxModalBarrier('));
    expect(dialogs, contains('shadesHeader: shadesHeader'));
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

  test(
    'editor rows reuse the shared native hover role, not a control fill',
    () {
      final design = File('lib/src/app/busymax_design.dart').readAsStringSync();
      final editor = File(
        'lib/src/features/calendar/presentation/event_editor.dart',
      ).readAsStringSync();
      final hoverStart = design.indexOf('Color busyMaxRowHoverColor');
      final hoverEnd = design.indexOf('Color busyMaxPanelBorder');
      final hoverSource = design.substring(hoverStart, hoverEnd);

      expect(hoverSource, contains('final theme = Theme.of(context)'));
      expect(hoverSource, contains('final hover = theme.hoverColor'));
      expect(
        hoverSource,
        contains('BusyMaxAlpha.groupedRowLightHoverStrength'),
      );
      expect(design, contains('groupedRowLightHoverStrength = 0.50'));
      expect(
        hoverSource,
        contains('theme.colorScheme.brightness == Brightness.dark'),
      );
      expect(hoverSource, isNot(contains('.controlHover')));
      expect(hoverSource, isNot(contains('primaryContainer')));
      expect(hoverSource, isNot(contains('colorScheme.primary')));
      expect(editor, isNot(contains('hoverColor:')));
    },
  );

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
    final destinationGroupIndex = editor.indexOf(
      'children: [_accountRow(), _calendarRow()]',
    );

    expect(titleLabelIndex, isNonNegative);
    expect(locationLabelIndex, greaterThan(titleLabelIndex));
    expect(destinationGroupIndex, greaterThan(locationLabelIndex));
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

  test('event editor text fields use shared grouped-row decoration', () {
    final editor = File(
      'lib/src/features/calendar/presentation/event_editor.dart',
    ).readAsStringSync();
    final design = File('lib/src/app/busymax_design.dart').readAsStringSync();

    expect(editor, contains('busyMaxGroupedTextFieldDecoration'));
    expect(editor, isNot(contains('_plainEventFieldDecoration')));
    expect(design, contains('filled: false'));
    expect(design, contains('fillColor: Colors.transparent'));
    expect(design, contains('hoverColor: Colors.transparent'));
    expect(design, contains('labelText: labelText'));
    expect(design, contains('labelStyle: labelStyle'));
    expect(design, contains('floatingLabelStyle: labelStyle'));
    expect(
      design,
      contains('floatingLabelBehavior: FloatingLabelBehavior.auto'),
    );
    expect(design, contains('enabledBorder: InputBorder.none'));
    expect(design, contains('focusedBorder: InputBorder.none'));
    expect(design, contains('errorBorder: InputBorder.none'));
    expect(design, contains('focusedErrorBorder: InputBorder.none'));
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
    expect(editor, contains('BusyMaxTimeModeRow('));
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

  testWidgets('combo selector uses a flat native-style row trigger', (
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

    expect(find.byType(BusyMaxMenuButton<String>), findsOneWidget);
    final triggerFinder = find.descendant(
      of: find.byType(BusyMaxComboRow<String>),
      matching: find.byWidgetPredicate(
        (widget) => widget is YaruListTile && widget.focusNode != null,
      ),
    );
    final trigger = tester.widget<YaruListTile>(triggerFinder);
    expect(trigger.onTap, isNotNull);
    expect(
      tester.getSize(triggerFinder).height,
      greaterThan(kYaruButtonHeight),
    );
    expect(
      find.descendant(
        of: find.byType(BusyMaxComboRow<String>),
        matching: find.byWidgetPredicate(
          (widget) => widget is ButtonStyleButton && widget is! IconButton,
        ),
      ),
      findsNothing,
    );
    final restingSurface = tester.widget<Material>(
      find.descendant(of: triggerFinder, matching: find.byType(Material)).first,
    );
    expect(restingSurface.type, MaterialType.canvas);
    expect(restingSurface.color, Colors.transparent);
    expect(restingSurface.color, isNot(colors.control));
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

ElevatedButton _headerButton(WidgetTester tester, String label) =>
    tester.widget<ElevatedButton>(_headerButtonFinder(label));

BusyMaxActionRow _actionRow(WidgetTester tester, String title) {
  return tester.widget<BusyMaxActionRow>(
    find.byWidgetPredicate(
      (widget) => widget is BusyMaxActionRow && widget.title == title,
    ),
  );
}

BusyMaxComboRow<String> _comboRow(WidgetTester tester, String title) {
  return tester.widget<BusyMaxComboRow<String>>(
    find.byWidgetPredicate(
      (widget) => widget is BusyMaxComboRow<String> && widget.title == title,
    ),
  );
}

BusyMaxSwitchRow _switchRow(WidgetTester tester, String title) {
  return tester.widget<BusyMaxSwitchRow>(
    find.byWidgetPredicate(
      (widget) => widget is BusyMaxSwitchRow && widget.title == title,
    ),
  );
}

Finder _timeRowFinder(String label) {
  return find.byWidgetPredicate(
    (widget) => widget is DesktopTimeValueRow && widget.label == label,
  );
}

TextField _dateTextField(WidgetTester tester, String label) {
  final row = find.byWidgetPredicate(
    (widget) => widget is DesktopDateValueRow && widget.label == label,
  );
  return tester.widget<TextField>(
    find.descendant(of: row, matching: find.byType(TextField)),
  );
}

TextField _timeTextField(WidgetTester tester, String label) {
  return tester.widget<TextField>(
    find.descendant(
      of: _timeRowFinder(label),
      matching: find.byType(TextField),
    ),
  );
}

Finder _timeEntryFinder(String label) {
  return find.descendant(
    of: _timeRowFinder(label),
    matching: find.byType(TextFormField),
  );
}

Future<void> _clearTimeEntry(WidgetTester tester, String label) async {
  await tester.enterText(_timeEntryFinder(label), '');
  await tester.pump();
}

Future<void> _enterTime(
  WidgetTester tester, {
  required String label,
  required String hour,
  required String minute,
}) async {
  final entry = _timeEntryFinder(label);
  await tester.enterText(entry, '$hour:$minute');
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

const _eventAccounts = [
  AccountEntity(
    id: 'google-account',
    provider: BusyProvider.google,
    authority: 'https://accounts.google.com',
    providerAccountId: 'google-user',
    authState: accountAuthStateSignedIn,
    displayName: 'Personal account',
    email: 'personal@example.test',
  ),
  AccountEntity(
    id: 'microsoft-account',
    provider: BusyProvider.microsoft,
    authority: 'https://login.microsoftonline.com/common',
    providerAccountId: 'microsoft-user',
    authState: accountAuthStateSignedIn,
    displayName: 'Work account',
    email: 'work@example.test',
  ),
];

const _sameNamedCrossAccountSources = [
  CalendarSourceEntity(
    id: 'google-work',
    accountId: 'google-account',
    provider: BusyProvider.google,
    providerCalendarId: 'google-work-calendar',
    summary: 'Work',
    selected: true,
    hidden: false,
    readOnly: false,
    isDeleted: false,
    backgroundColor: '#3584e4',
  ),
  CalendarSourceEntity(
    id: 'microsoft-work',
    accountId: 'microsoft-account',
    provider: BusyProvider.microsoft,
    providerCalendarId: 'microsoft-work-calendar',
    summary: 'Work',
    selected: true,
    hidden: false,
    readOnly: false,
    isDeleted: false,
    backgroundColor: '#9141ac',
  ),
];

const _sourcesWithMicrosoftPrimary = [
  ..._sameNamedCrossAccountSources,
  CalendarSourceEntity(
    id: 'microsoft-primary',
    accountId: 'microsoft-account',
    provider: BusyProvider.microsoft,
    providerCalendarId: 'microsoft-primary-calendar',
    summary: 'Calendar',
    selected: true,
    hidden: false,
    readOnly: false,
    isDeleted: false,
    primaryCalendar: true,
    backgroundColor: '#e01b24',
  ),
];

const _sources = [
  CalendarSourceEntity(
    id: 'source',
    accountId: 'account',
    provider: BusyProvider.google,
    providerCalendarId: 'cal-1',
    summary: 'Work',
    selected: true,
    hidden: false,
    readOnly: false,
    isDeleted: false,
    backgroundColor: '#3584e4',
    allowedConferenceSolutions: ['hangoutsMeet'],
  ),
];

const _multipleSources = [
  ..._sources,
  CalendarSourceEntity(
    id: 'destination-source',
    accountId: 'account',
    provider: BusyProvider.google,
    providerCalendarId: 'cal-2',
    summary: 'Personal',
    selected: true,
    hidden: false,
    readOnly: false,
    isDeleted: false,
    backgroundColor: '#33d17a',
  ),
];

const _nextcloudSources = [
  CalendarSourceEntity(
    id: 'nextcloud-source',
    accountId: 'nextcloud-account',
    provider: BusyProvider.nextcloud,
    providerCalendarId: '/calendars/work/',
    davCollectionId: 'nextcloud-collection',
    summary: 'Nextcloud Work',
    selected: true,
    hidden: false,
    readOnly: false,
    isDeleted: false,
    backgroundColor: '#0082c9',
  ),
];

const _microsoftSources = [
  CalendarSourceEntity(
    id: 'microsoft-source',
    accountId: 'microsoft-account',
    provider: BusyProvider.microsoft,
    providerCalendarId: 'ms-cal-1',
    summary: 'Outlook',
    selected: true,
    hidden: false,
    readOnly: false,
    isDeleted: false,
    backgroundColor: '#9141ac',
    allowedConferenceSolutions: ['teamsForBusiness'],
  ),
];

const _mixedProviderSources = [..._sources, ..._microsoftSources];
