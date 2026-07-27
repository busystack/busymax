import 'dart:async';

import 'package:busymax/src/app/busymax_design.dart';
import 'package:busymax/src/features/tasks/presentation/desktop_date_time_fields.dart';
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

  testWidgets(
    'calendar values render populated contextual fields before focus',
    (tester) async {
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
        formatMaterialTime(timeContext, const TimeOfDay(hour: 9, minute: 30)),
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
      expect(find.byIcon(Icons.schedule), findsNothing);
      expect(find.byIcon(Icons.edit_outlined), findsNothing);
    },
  );

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

  testWidgets('fallback date picker follows the shared modal policy', (
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

    expect(find.byType(BusyMaxDialogShell), findsOneWidget);
    final barriers = tester.widgetList<ModalBarrier>(find.byType(ModalBarrier));
    expect(
      barriers.any(
        (barrier) => barrier.color == busyMaxModalBarrierColor(hostContext),
      ),
      isTrue,
    );

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(await result, isNull);
  });

  testWidgets(
    'fallback date entry is populated and contextual before receiving focus',
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
        initialDate: '2026-07-22',
      );
      await tester.pumpAndSettle();

      final entryFinder = find.descendant(
        of: find.byType(InputDatePickerFormField),
        matching: find.byType(TextFormField),
      );
      final entry = tester.widget<TextFormField>(entryFinder);
      final textField = tester.widget<TextField>(
        find.descendant(
          of: find.byType(InputDatePickerFormField),
          matching: find.byType(TextField),
        ),
      );
      final localizations = MaterialLocalizations.of(
        tester.element(find.byType(InputDatePickerFormField)),
      );

      expect(
        entry.controller?.text,
        localizations.formatCompactDate(DateTime(2026, 7, 22)),
      );
      expect(textField.decoration?.labelText, 'Due date');
      expect(textField.focusNode?.hasFocus ?? false, isFalse);
      expect(
        textField.decoration?.labelText,
        isNot(localizations.dateInputLabel),
      );
      expect(find.text(localizations.dateInputLabel), findsNothing);

      await tester.tap(find.text(localizations.cancelButtonLabel));
      await tester.pumpAndSettle();
      expect(await result, isNull);
    },
  );

  testWidgets('fallback date dialog submits a valid edited date', (
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

    final entryFinder = find.descendant(
      of: find.byType(InputDatePickerFormField),
      matching: find.byType(TextFormField),
    );
    final localizations = MaterialLocalizations.of(
      tester.element(find.byType(InputDatePickerFormField)),
    );
    await tester.enterText(
      entryFinder,
      localizations.formatCompactDate(DateTime(2027, 8, 14)),
    );
    await tester.tap(find.text(localizations.okButtonLabel));
    await tester.pumpAndSettle();

    expect(await result, '2027-08-14');
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

      final entry = tester.widget<TextFormField>(
        find.descendant(
          of: find.byType(InputDatePickerFormField),
          matching: find.byType(TextFormField),
        ),
      );
      final localizations = MaterialLocalizations.of(
        tester.element(find.byType(InputDatePickerFormField)),
      );
      expect(
        entry.controller?.text,
        localizations.formatCompactDate(DateTime(2100, 12, 31)),
      );
      expect(tester.takeException(), isNull);

      await tester.tap(find.text(localizations.cancelButtonLabel));
      await tester.pumpAndSettle();
      expect(await result, isNull);
    },
  );

  testWidgets('fallback date dialog rejects malformed and out-of-range dates', (
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

    final entryFinder = find.descendant(
      of: find.byType(InputDatePickerFormField),
      matching: find.byType(TextFormField),
    );
    final localizations = MaterialLocalizations.of(
      tester.element(find.byType(InputDatePickerFormField)),
    );

    await tester.enterText(entryFinder, 'not a date');
    await tester.tap(find.text(localizations.okButtonLabel));
    await tester.pumpAndSettle();
    expect(find.byType(BusyMaxDialogShell), findsOneWidget);
    expect(find.text(localizations.invalidDateFormatLabel), findsOneWidget);

    await tester.enterText(
      entryFinder,
      localizations.formatCompactDate(DateTime(1800, 1, 1)),
    );
    await tester.tap(find.text(localizations.okButtonLabel));
    await tester.pumpAndSettle();
    expect(find.byType(BusyMaxDialogShell), findsOneWidget);
    expect(find.text(localizations.dateOutOfRangeLabel), findsOneWidget);

    await tester.tap(find.text(localizations.cancelButtonLabel));
    await tester.pumpAndSettle();
    expect(await result, isNull);
  });

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
