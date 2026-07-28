import 'dart:async';

import 'package:busymax/src/app/busymax_design.dart';
import 'package:busymax/src/core/time/time_zone_catalog.dart';
import 'package:busymax/src/features/tasks/presentation/desktop_date_time_fields.dart';
import 'package:busymax/src/features/schedule/presentation/mini_calendar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaru/yaru.dart';

import '../../../test_localized_app.dart';

void main() {
  test('provider time parsing accepts only exact HH:mm values', () {
    expect(parseTimeOfDay('00:00'), const TimeOfDay(hour: 0, minute: 0));
    expect(parseTimeOfDay('09:30'), const TimeOfDay(hour: 9, minute: 30));
    expect(parseTimeOfDay('23:59'), const TimeOfDay(hour: 23, minute: 59));

    expect(parseTimeOfDay('9:30'), isNull);
    expect(parseTimeOfDay('09:3'), isNull);
    expect(parseTimeOfDay('09x30'), isNull);
    expect(parseTimeOfDay('09:30 UTC'), isNull);
  });

  testWidgets('localized time parsing is strict and encodes provider time', (
    tester,
  ) async {
    late BuildContext parserContext;
    await tester.pumpWidget(
      localizedTestApp(
        locale: const Locale('en'),
        alwaysUse24HourFormat: false,
        child: Builder(
          builder: (context) {
            parserContext = context;
            return const SizedBox();
          },
        ),
      ),
    );

    expect(
      encodeTimeOfDay(parseDesktopTimeInput(parserContext, '01:30 PM')!),
      '13:30',
    );
    expect(parseDesktopTimeInput(parserContext, '09x30'), isNull);
    expect(
      parseDesktopTimeInput(parserContext, '09:30 trailing garbage'),
      isNull,
    );
  });

  testWidgets('calendar values render populated contextual fields before focus', (
    tester,
  ) async {
    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: Column(
            children: [
              DesktopDateValueRow(
                label: 'Start date',
                date: '2026-07-22',
                onChanged: _ignoreString,
              ),
              DesktopTimeValueRow(
                label: 'Start time',
                time: '09:30',
                timeZone: 'America/Vancouver',
                onChanged: _ignoreNullableString,
              ),
            ],
          ),
        ),
      ),
    );

    final dateTextField = tester.widget<TextField>(
      find
          .descendant(
            of: find.byType(DesktopDateValueRow),
            matching: find.byType(TextField),
          )
          .first,
    );
    final timeTextField = tester.widget<TextField>(
      find
          .descendant(
            of: find.byType(DesktopTimeValueRow),
            matching: find.byType(TextField),
          )
          .first,
    );
    final dateContext = tester.element(find.byType(DesktopDateValueRow));
    final timeContext = tester.element(find.byType(DesktopTimeValueRow));

    expect(
      dateTextField.controller?.text,
      formatDesktopDate(dateContext, '2026-07-22'),
    );
    expect(
      timeTextField.controller?.text,
      '${formatMaterialTime(timeContext, const TimeOfDay(hour: 9, minute: 30))} '
      '(${BusyMaxTimeZoneCatalog.location('America/Vancouver').code})',
    );
    expect(dateTextField.decoration?.labelText, 'Start date');
    expect(timeTextField.decoration?.labelText, 'Start time');
    expect(
      dateTextField.decoration?.floatingLabelBehavior,
      FloatingLabelBehavior.auto,
    );
    expect(
      timeTextField.decoration?.floatingLabelBehavior,
      FloatingLabelBehavior.auto,
    );
    expect(find.text('Enter date'), findsNothing);
    expect(find.text('Enter time'), findsNothing);
    expect(find.byIcon(YaruIcons.calendar), findsOneWidget);
    expect(find.byIcon(YaruIcons.clock), findsOneWidget);
    expect(find.byIcon(Icons.edit_outlined), findsNothing);
  });

  testWidgets('disabled date and time entries cannot receive focus', (
    tester,
  ) async {
    await tester.pumpWidget(
      localizedTestApp(
        child: const Scaffold(
          body: Column(
            children: [
              DesktopDateField(
                label: 'Due date',
                date: '2026-07-22',
                enabled: false,
                onChanged: _ignoreString,
              ),
              DesktopTimeField(
                label: 'Due time',
                time: '09:30',
                enabled: false,
                onChanged: _ignoreNullableString,
              ),
            ],
          ),
        ),
      ),
    );

    final dateEntries = tester.widgetList<EditableText>(
      find.descendant(
        of: find.byType(DesktopDateField),
        matching: find.byType(EditableText),
      ),
    );
    final timeEntries = tester.widgetList<EditableText>(
      find.descendant(
        of: find.byType(DesktopTimeField),
        matching: find.byType(EditableText),
      ),
    );

    expect(dateEntries, isNotEmpty);
    expect(timeEntries, isNotEmpty);
    expect(
      [
        ...dateEntries,
        ...timeEntries,
      ].every((entry) => !entry.focusNode.canRequestFocus),
      isTrue,
    );

    await tester.tap(find.byType(EditableText).first, warnIfMissed: false);
    await tester.pump();
    expect(
      [
        ...dateEntries,
        ...timeEntries,
      ].every((entry) => !entry.focusNode.hasFocus),
      isTrue,
    );
  });

  testWidgets('disposing a date field safely ignores an in-flight picker', (
    tester,
  ) async {
    const channel = MethodChannel(nativeDateTimePickerChannelName);
    final response = Completer<String?>();
    final changes = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) => response.future);
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: DesktopDateField(
            label: 'Due date',
            date: '2026-07-22',
            onChanged: changes.add,
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(YaruIcons.calendar));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());

    response.complete('2026-07-23');
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(changes, isEmpty);
  });

  testWidgets('time row uses native time picker channel', (tester) async {
    const channel = MethodChannel(nativeDateTimePickerChannelName);
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          expect(call.method, 'pickTime');
          expect(call.arguments, containsPair('initialTime', '09:30'));
          return Future.value('10:45');
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    String? pickedTime;
    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: DesktopTimeValueRow(
            label: 'Due time',
            time: '09:30',
            useNativePicker: true,
            onChanged: (value) => pickedTime = value,
            onValidityChanged: (_) {},
          ),
        ),
      ),
    );

    expect(find.byType(YaruIconButton), findsOneWidget);
    await tester.tap(find.byType(YaruIconButton).first);
    await tester.pumpAndSettle();
    expect(calls, hasLength(1));
    expect(pickedTime, '10:45');
    expect(calls, hasLength(1));
    expect(find.byType(BusyMaxDialogShell), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('fallback time picker opens as tooltip-style controls', (
    tester,
  ) async {
    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: DesktopTimeValueRow(
            label: 'Due time',
            time: '09:30',
            onChanged: (_) {},
            onValidityChanged: (_) {},
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(YaruIcons.clock));
    await tester.pumpAndSettle();

    expect(find.byType(BusyMaxContentPopoverSurface), findsOneWidget);
    expect(find.byType(BusyMaxDialogShell), findsNothing);
    expect(find.byIcon(Icons.add), findsNWidgets(2));
    expect(find.byIcon(Icons.remove), findsNWidgets(2));
    expect(find.text(':'), findsOneWidget);
    expect(find.byIcon(Icons.public), findsOneWidget);

    final picker = find.byType(BusyMaxContentPopoverSurface);
    final componentFields = find.descendant(
      of: picker,
      matching: find.byType(TextFormField),
    );
    final editableFields = find.descendant(
      of: picker,
      matching: find.byType(EditableText),
    );
    expect(componentFields, findsNWidgets(2));
    expect(editableFields, findsNWidgets(2));
    expect(
      tester
          .widgetList<EditableText>(editableFields)
          .map((field) => field.controller.text),
      <String>['09', '30'],
    );
    for (final field in tester.widgetList<EditableText>(editableFields)) {
      expect(field.textAlign, TextAlign.center);
      expect(field.style.fontWeight, FontWeight.normal);
    }
    for (final element in componentFields.evaluate()) {
      final size = tester.getSize(
        find.byElementPredicate((candidate) {
          return identical(candidate, element);
        }),
      );
      expect(size.width, inInclusiveRange(36, 38));
      expect(size.height, BusyMaxSizes.popoverActionButton);
    }

    final timezoneButton = find.ancestor(
      of: find.byIcon(Icons.public),
      matching: find.byType(FilledButton),
    );
    expect(timezoneButton, findsOneWidget);
    expect(tester.widget<FilledButton>(timezoneButton).style, isNull);
    expect(tester.getSize(timezoneButton).width, greaterThan(100));
    expect(tester.takeException(), isNull);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
  });

  testWidgets('time picker searches and selects real timezone locations', (
    tester,
  ) async {
    String? selectedTimeZone;
    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: DesktopTimeValueRow(
            label: 'Due time',
            time: '09:30',
            timeZone: 'Etc/UTC',
            onChanged: (_) {},
            onTimeZoneChanged: (value) => selectedTimeZone = value,
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(YaruIcons.clock));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.public));
    await tester.pumpAndSettle();

    expect(find.text('Select Timezone'), findsOneWidget);
    final title = tester.widget<Text>(find.text('Select Timezone'));
    expect(title.textAlign, isNull);
    expect(title.style?.fontWeight, FontWeight.w600);
    expect(find.byType(BusyMaxDialogTitleBar), findsOneWidget);
    expect(
      tester
          .widget<BusyMaxDialogTitleBar>(find.byType(BusyMaxDialogTitleBar))
          .centerTitle,
      isTrue,
    );

    final searchField = find.widgetWithText(TextField, 'Search locations');
    expect(searchField, findsOneWidget);
    await tester.enterText(searchField, 'Vancouver');
    await tester.pumpAndSettle();

    expect(find.text('America'), findsOneWidget);
    expect(find.textContaining('Vancouver ('), findsOneWidget);
    expect(find.text('America/Vancouver'), findsOneWidget);

    await tester.tap(find.textContaining('Vancouver ('));
    await tester.pumpAndSettle();

    expect(selectedTimeZone, 'America/Vancouver');
    expect(find.text('Select Timezone'), findsNothing);
    expect(find.textContaining('America/Vancouver ('), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('fallback time picker closes when clicking outside', (
    tester,
  ) async {
    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: Center(
            child: DesktopTimeValueRow(
              label: 'Due time',
              time: '09:30',
              onChanged: (_) {},
              onValidityChanged: (_) {},
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(YaruIcons.clock));
    await tester.pumpAndSettle();
    expect(find.byType(BusyMaxContentPopoverSurface), findsOneWidget);

    final bodySize = tester.getSize(find.byType(Scaffold));
    await tester.tapAt(Offset(bodySize.width - 1, bodySize.height - 1));
    await tester.pumpAndSettle();

    expect(find.byType(BusyMaxContentPopoverSurface), findsNothing);
  });

  testWidgets('fallback date picker opens as an anchored popover', (
    tester,
  ) async {
    late BuildContext hostContext;
    await tester.pumpWidget(
      localizedTestApp(
        child: Builder(
          builder: (context) {
            hostContext = context;
            return const Scaffold(body: SizedBox());
          },
        ),
      ),
    );

    final result = showBusyMaxDateValueDialog(
      hostContext,
      label: 'Due date',
      initialDate: '2026-07-22',
    );
    await tester.pumpAndSettle();

    expect(find.byType(BusyMaxContentPopoverSurface), findsOneWidget);
    expect(find.byType(ModalBarrier), findsAtLeastNWidgets(1));

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(await result, isNull);
  });

  testWidgets('fallback date picker is positioned from the trigger', (
    tester,
  ) async {
    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: Center(
            child: DesktopDateValueRow(
              label: 'Due date',
              date: '2026-07-22',
              onChanged: _ignoreString,
            ),
          ),
        ),
      ),
    );

    final trigger = find.byType(YaruIconButton).first;
    final triggerRect = tester.getRect(trigger);
    await tester.tap(trigger);
    await tester.pumpAndSettle();

    final popoverRect = tester.getRect(
      find.byType(BusyMaxContentPopoverSurface).first,
    );
    expect(popoverRect.topLeft.dx, greaterThan(0));
    expect(popoverRect.topLeft.dy, greaterThan(0));
    expect(
      (triggerRect.center.dx - popoverRect.center.dx).abs(),
      lessThan(popoverRect.width / 2 + 10),
    );
    expect(
      (triggerRect.center.dy - popoverRect.center.dy).abs(),
      greaterThan(0),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
  });

  testWidgets('fallback date picker closes when tapping outside', (
    tester,
  ) async {
    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: Center(
            child: DesktopDateValueRow(
              label: 'Due date',
              date: '2026-07-22',
              onChanged: _ignoreString,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(YaruIcons.calendar));
    await tester.pumpAndSettle();
    expect(find.byType(BusyMaxContentPopoverSurface), findsOneWidget);

    final bodySize = tester.getSize(find.byType(Scaffold));
    await tester.tapAt(Offset(bodySize.width - 1, bodySize.height - 1));
    await tester.pumpAndSettle();

    expect(find.byType(BusyMaxContentPopoverSurface), findsNothing);
  });

  testWidgets('fallback date picker uses mini calendar and labels', (
    tester,
  ) async {
    late BuildContext hostContext;
    await tester.pumpWidget(
      localizedTestApp(
        child: Builder(
          builder: (context) {
            hostContext = context;
            return const Scaffold(body: SizedBox());
          },
        ),
      ),
    );

    final result = showBusyMaxDateValueDialog(
      hostContext,
      label: 'Due date',
      initialDate: '2026-07-22',
    );
    await tester.pumpAndSettle();

    expect(find.byType(MiniCalendar), findsOneWidget);
    expect(find.text('July'), findsOneWidget);
    expect(find.text('2026'), findsOneWidget);
    expect(find.byTooltip('Wednesday, July 22, 2026'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(await result, isNull);
  });

  testWidgets('fallback date picker month and year headers are display-only', (
    tester,
  ) async {
    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: Center(
            child: DesktopDateValueRow(
              label: 'Due date',
              date: '2026-07-22',
              onChanged: _ignoreString,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(YaruIcons.calendar));
    await tester.pumpAndSettle();
    expect(find.byType(MiniCalendar), findsOneWidget);
    expect(find.text('July'), findsOneWidget);
    expect(find.text('2026'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(MiniCalendar),
        matching: find.byType(TextButton),
      ),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('fallback date picker stays open while paging months', (
    tester,
  ) async {
    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: DesktopDateValueRow(
            label: 'Due date',
            date: '2026-07-22',
            onChanged: _ignoreString,
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(YaruIcons.calendar));
    await tester.pumpAndSettle();
    expect(find.byType(BusyMaxContentPopoverSurface), findsOneWidget);

    await tester.tap(find.byIcon(YaruIcons.pan_start).at(0));
    await tester.pumpAndSettle();
    expect(find.byType(BusyMaxContentPopoverSurface), findsOneWidget);

    await tester.tap(find.byIcon(YaruIcons.pan_end).at(0));
    await tester.pumpAndSettle();
    expect(find.byType(BusyMaxContentPopoverSurface), findsOneWidget);
  });

  testWidgets('fallback date picker stays open while paging years', (
    tester,
  ) async {
    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: DesktopDateValueRow(
            label: 'Due date',
            date: '2026-07-22',
            onChanged: _ignoreString,
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(YaruIcons.calendar));
    await tester.pumpAndSettle();
    expect(find.byType(BusyMaxContentPopoverSurface), findsOneWidget);

    await tester.tap(find.byIcon(YaruIcons.pan_start).at(1));
    await tester.pumpAndSettle();
    expect(find.byType(BusyMaxContentPopoverSurface), findsOneWidget);

    await tester.tap(find.byIcon(YaruIcons.pan_end).at(1));
    await tester.pumpAndSettle();
    expect(find.byType(BusyMaxContentPopoverSurface), findsOneWidget);
  });

  testWidgets('fallback date dialog submits a selected date', (tester) async {
    String? picked;
    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: Builder(
            builder: (context) {
              return Center(
                child: DesktopDateValueRow(
                  label: 'Due date',
                  date: '2026-07-22',
                  onChanged: (date) => picked = date,
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(YaruIcons.calendar));
    await tester.pumpAndSettle();
    final dayCell = find.text('14');
    expect(dayCell, findsOneWidget);
    await tester.tap(dayCell.first);
    await tester.pumpAndSettle();

    expect(picked, '2026-07-14');
  });

  testWidgets(
    'fallback date dialog safely bounds an unsupported initial date',
    (tester) async {
      late BuildContext hostContext;
      await tester.pumpWidget(
        localizedTestApp(
          child: Builder(
            builder: (context) {
              hostContext = context;
              return const Scaffold(body: SizedBox());
            },
          ),
        ),
      );

      final result = showBusyMaxDateValueDialog(
        hostContext,
        label: 'Due date',
        initialDate: '2200-01-01',
      );
      await tester.pumpAndSettle();

      expect(find.byTooltip('Friday, December 31, 2100'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(await result, isNull);
    },
  );

  testWidgets('invalid time reports validity and uses the native error label', (
    tester,
  ) async {
    final changes = <String?>[];
    final validityChanges = <bool>[];
    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: DesktopTimeField(
            label: 'Due time',
            time: '09:30',
            onChanged: changes.add,
            onValidityChanged: validityChanges.add,
          ),
        ),
      ),
    );
    validityChanges.clear();

    final entryFinder = find.descendant(
      of: find.byType(DesktopTimeField),
      matching: find.byType(TextFormField),
    );
    final localizations = MaterialLocalizations.of(
      tester.element(find.byType(DesktopTimeField)),
    );

    await tester.enterText(entryFinder, '09x30');
    await tester.pump();
    expect(find.text(localizations.invalidTimeLabel), findsOneWidget);
    expect(validityChanges, <bool>[false]);
    expect(changes, isEmpty);

    await tester.enterText(entryFinder, '10:45');
    await tester.pump();
    expect(find.text(localizations.invalidTimeLabel), findsNothing);
    expect(validityChanges, <bool>[false, true]);
    expect(changes, <String?>['10:45']);
  });

  testWidgets(
    'external time update replaces focused text without echoing the value',
    (tester) async {
      late StateSetter updateHost;
      var suppliedTime = '09:30';
      final changes = <String?>[];
      await tester.pumpWidget(
        localizedTestApp(
          child: StatefulBuilder(
            builder: (context, setState) {
              updateHost = setState;
              return Scaffold(
                body: DesktopTimeField(
                  label: 'Due time',
                  time: suppliedTime,
                  onChanged: changes.add,
                ),
              );
            },
          ),
        ),
      );

      final entryFinder = find.descendant(
        of: find.byType(DesktopTimeField),
        matching: find.byType(TextFormField),
      );
      await tester.tap(entryFinder);
      await tester.pump();
      await tester.enterText(entryFinder, 'stale invalid text');
      await tester.pump();
      changes.clear();

      updateHost(() {
        suppliedTime = '18:45';
      });
      await tester.pump();

      final entry = tester.widget<TextFormField>(entryFinder);
      final editableText = tester.widget<EditableText>(
        find.descendant(
          of: find.byType(DesktopTimeField),
          matching: find.byType(EditableText),
        ),
      );
      final fieldContext = tester.element(find.byType(DesktopTimeField));
      expect(
        entry.controller?.text,
        formatMaterialTime(fieldContext, const TimeOfDay(hour: 18, minute: 45)),
      );
      expect(editableText.focusNode.hasFocus, isTrue);
      expect(changes, isEmpty);
      expect(
        find.text(MaterialLocalizations.of(fieldContext).invalidTimeLabel),
        findsNothing,
      );
      editableText.focusNode.unfocus();
      await tester.pump();
      expect(changes, isEmpty);
      expect(
        tester.widget<TextFormField>(entryFinder).controller?.text,
        formatMaterialTime(fieldContext, const TimeOfDay(hour: 18, minute: 45)),
      );
    },
  );

  testWidgets(
    'rejected controlled time restores the authoritative value on blur',
    (tester) async {
      final changes = <String?>[];
      await tester.pumpWidget(
        localizedTestApp(
          alwaysUse24HourFormat: true,
          child: Scaffold(
            body: DesktopTimeField(
              label: 'Quiet hours start',
              time: '09:30',
              onChanged: changes.add,
            ),
          ),
        ),
      );

      final fieldFinder = find.descendant(
        of: find.byType(DesktopTimeField),
        matching: find.byType(TextFormField),
      );
      final editableText = tester.widget<EditableText>(
        find.descendant(
          of: find.byType(DesktopTimeField),
          matching: find.byType(EditableText),
        ),
      );

      await tester.tap(fieldFinder);
      await tester.enterText(fieldFinder, '10:45');
      await tester.pump();
      expect(changes, <String?>['10:45']);
      expect(
        tester.widget<TextFormField>(fieldFinder).controller?.text,
        '10:45',
      );

      editableText.focusNode.unfocus();
      await tester.pump();

      expect(changes, <String?>['10:45']);
      expect(
        tester.widget<TextFormField>(fieldFinder).controller?.text,
        '09:30',
      );
    },
  );

  testWidgets('disabling a time field discards transient invalid input', (
    tester,
  ) async {
    late StateSetter updateHost;
    var enabled = true;
    final changes = <String?>[];
    final validityChanges = <bool>[];
    await tester.pumpWidget(
      localizedTestApp(
        alwaysUse24HourFormat: true,
        child: StatefulBuilder(
          builder: (context, setState) {
            updateHost = setState;
            return Scaffold(
              body: DesktopTimeField(
                label: 'Quiet hours start',
                time: '09:30',
                enabled: enabled,
                allowEmpty: false,
                onChanged: changes.add,
                onValidityChanged: validityChanges.add,
              ),
            );
          },
        ),
      ),
    );
    validityChanges.clear();

    final entryFinder = find.descendant(
      of: find.byType(DesktopTimeField),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(entryFinder, 'invalid');
    await tester.pump();
    expect(validityChanges, <bool>[false]);

    updateHost(() => enabled = false);
    await tester.pump();

    final entry = tester.widget<TextFormField>(entryFinder);
    final fieldContext = tester.element(find.byType(DesktopTimeField));
    expect(entry.controller?.text, '09:30');
    expect(
      find.text(MaterialLocalizations.of(fieldContext).invalidTimeLabel),
      findsNothing,
    );
    expect(validityChanges, <bool>[false, true]);
    expect(changes, isEmpty);
  });

  testWidgets('malformed stored time is blank instead of becoming midnight', (
    tester,
  ) async {
    final changes = <String?>[];
    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: DesktopTimeField(
            label: 'Due time',
            time: 'not-a-provider-time',
            onChanged: changes.add,
          ),
        ),
      ),
    );

    final entry = tester.widget<TextFormField>(
      find.descendant(
        of: find.byType(DesktopTimeField),
        matching: find.byType(TextFormField),
      ),
    );
    expect(entry.controller?.text, isEmpty);
    expect(changes, isEmpty);
  });

  testWidgets(
    'same time field state follows locale and 24-hour preference changes',
    (tester) async {
      final changes = <String?>[];

      Future<void> pumpEntry({
        required Locale locale,
        required bool alwaysUse24HourFormat,
      }) async {
        await tester.pumpWidget(
          localizedTestApp(
            locale: locale,
            alwaysUse24HourFormat: alwaysUse24HourFormat,
            child: Scaffold(
              body: DesktopTimeField(
                label: 'Due time',
                time: '14:30',
                onChanged: changes.add,
              ),
            ),
          ),
        );
        await tester.pump();
      }

      String visibleText() =>
          tester
              .widget<TextFormField>(
                find.descendant(
                  of: find.byType(DesktopTimeField),
                  matching: find.byType(TextFormField),
                ),
              )
              .controller
              ?.text ??
          '';

      await pumpEntry(locale: const Locale('en'), alwaysUse24HourFormat: false);
      final originalState = tester.state(find.byType(DesktopTimeField));
      expect(visibleText(), '2:30 PM');

      await pumpEntry(locale: const Locale('de'), alwaysUse24HourFormat: false);
      expect(tester.state(find.byType(DesktopTimeField)), same(originalState));
      expect(visibleText(), '14:30');

      await pumpEntry(locale: const Locale('en'), alwaysUse24HourFormat: false);
      expect(tester.state(find.byType(DesktopTimeField)), same(originalState));
      expect(visibleText(), '2:30 PM');

      await pumpEntry(locale: const Locale('en'), alwaysUse24HourFormat: true);
      expect(tester.state(find.byType(DesktopTimeField)), same(originalState));
      expect(visibleText(), '14:30');
      expect(changes, isEmpty);
    },
  );
}

void _ignoreString(String value) {}

void _ignoreNullableString(String? value) {}
