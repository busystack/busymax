import 'dart:io';

import 'package:busymax/src/features/calendar/data/calendar_repository.dart';
import 'package:busymax/src/features/calendar/presentation/event_editor.dart';
import 'package:busymax/src/features/calendar/presentation/event_editor_draft.dart';
import 'package:busymax/src/app/busymax_design.dart';
import 'package:busymax/src/task_providers/task_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubuntu_widgets/ubuntu_widgets.dart';

import '../../../test_localized_app.dart';

void main() {
  testWidgets('header buttons use compact headerbar sizing', (tester) async {
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
            onCancel: () {},
            onSave: (_) {},
          ),
        ),
      ),
    );

    expect(
      tester.getSize(_headerButtonFinder('Cancel')).width,
      inInclusiveRange(100, 180),
    );
    expect(
      tester.getSize(_headerButtonFinder('Save')).width,
      inInclusiveRange(100, 180),
    );
    expect(
      tester.getSize(_headerButtonFinder('Cancel')).height,
      BusyMaxSizes.headerIconButton,
    );
    expect(
      tester.getSize(_headerButtonFinder('Save')).height,
      BusyMaxSizes.headerIconButton,
    );
    expect(
      find.ancestor(
        of: find.text('Cancel'),
        matching: find.byWidgetPredicate((widget) => widget is PushButton),
      ),
      findsOneWidget,
    );
    expect(
      find.ancestor(
        of: find.text('Save'),
        matching: find.byWidgetPredicate((widget) => widget is PushButton),
      ),
      findsOneWidget,
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
    expect(_plainTextFinder('All Day'), findsOneWidget);
    expect(_plainTextFinder('Time Slot'), findsOneWidget);
    expect(find.text('No conference'), findsNothing);
    expect(find.text('Delete Event'), findsNothing);
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

    final fieldFinder = _timeTextEntryFinder();
    final entry = tester.widget<TextFormField>(fieldFinder);
    expect(entry.controller?.text, '09:00');
    expect(
      tester
          .widgetList<EditableText>(find.byType(EditableText))
          .any((entry) => entry.controller.text.contains('09:00')),
      isTrue,
    );

    await tester.enterText(fieldFinder, '');
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(tester.widget<TextFormField>(fieldFinder).controller?.text, isEmpty);
  });

  testWidgets('event time popup accepts midnight input', (tester) async {
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
    await tester.enterText(_timeTextEntryFinder(), '00');
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
    expect(find.text('5 minutes before'), findsOneWidget);
  });

  testWidgets('Microsoft event categories can be selected from suggestions', (
    tester,
  ) async {
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
    await tester.enterText(find.byKey(const Key('event-category-input')), 'wo');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Work').last);
    await tester.pumpAndSettle();
    await tester.tap(_headerButtonFinder('Save'));

    expect(saved?.categories, ['Home', 'Work']);
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
      contains('barrierColor: busyMaxModalBarrierColor(context)'),
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
    expect(design, contains('BusyMaxHeaderPushButton.outlined'));
    expect(design, contains('BusyMaxHeaderPushButton.filled'));
    expect(
      design,
      contains('EdgeInsets.symmetric(horizontal: BusyMaxSpacing.xl)'),
    );
    expect(design, contains('textAlign: TextAlign.center'));
    expect(design, contains('textTheme.titleMedium'));
    expect(editor, isNot(contains('BusyMaxDialogCloseButton')));
  });

  test(
    'editor row hover uses subtle foreground overlay, not selected color',
    () {
      final design = File('lib/src/app/busymax_design.dart').readAsStringSync();
      final hoverStart = design.indexOf('Color busyMaxEditorRowHoverColor');
      final hoverEnd = design.indexOf('Color busyMaxPanelBorder');
      final hoverSource = design.substring(hoverStart, hoverEnd);

      expect(hoverSource, contains('surfaceColors.foreground.withValues'));
      expect(hoverSource, contains('Brightness.dark ? 0.045 : 0.055'));
      expect(hoverSource, isNot(contains('.controlHover')));
      expect(hoverSource, isNot(contains('Theme.of(context).hoverColor')));
      expect(hoverSource, isNot(contains('primaryContainer')));
      expect(hoverSource, isNot(contains('colorScheme.primary')));
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
      expect(editor, contains('menuItemBuilder: (context, value)'));
      expect(editor, contains('selectedBuilder: (context, value)'));
      expect(editor, contains('_calendarSourceSelectedChoice'));
      expect(editor, contains('mainAxisAlignment: MainAxisAlignment.end'));
      expect(editor, contains('textAlign: TextAlign.end'));
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

  test('event combo selected values are right aligned', () {
    final editor = File(
      'lib/src/features/calendar/presentation/event_editor.dart',
    ).readAsStringSync();

    expect(editor, contains('Widget _eventEditorSelectedValue'));
    expect(editor, contains('alignment: Alignment.centerRight'));
    expect(editor, contains('textAlign: TextAlign.end'));
    expect(
      '_eventEditorSelectedValue'.allMatches(editor).length,
      greaterThanOrEqualTo(4),
    );
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

  testWidgets('combo dropdown trigger is transparent in all states', (
    tester,
  ) async {
    late BuildContext capturedContext;
    await tester.pumpWidget(
      localizedTestApp(
        child: Builder(
          builder: (context) {
            capturedContext = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    final background = busyMaxDropdownButtonStyle(
      capturedContext,
    ).backgroundColor!;

    expect(background.resolve(const {}), Colors.transparent);
    expect(background.resolve({WidgetState.hovered}), Colors.transparent);
    expect(background.resolve({WidgetState.pressed}), Colors.transparent);
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

Finder _timeTextEntryFinder() {
  return find.byWidgetPredicate(
    (widget) => widget is TextFormField && widget.controller != null,
  );
}

Finder _plainTextFinder(String label) {
  return find.byWidgetPredicate(
    (widget) => widget is Text && widget.data == label,
  );
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
