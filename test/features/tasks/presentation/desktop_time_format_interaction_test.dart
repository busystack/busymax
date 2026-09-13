import 'package:busymax/l10n/generated/app_localizations.dart';
import 'package:busymax/src/app/busymax_design.dart';
import 'package:busymax/src/app/busymax_yaru_theme.dart';
import 'package:busymax/src/features/tasks/presentation/desktop_date_time_fields.dart';
import 'package:busymax/src/l10n/time_format_scope.dart';
import 'package:busymax/src/platform/native_menu_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaru/yaru.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const menuChannel = MethodChannel(nativeMenuChannelName);
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          menuChannel,
          (_) async => throw MissingPluginException(),
        );
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(menuChannel, null);
  });

  testWidgets('period uses a compact shared menu aligned with clock inputs', (
    tester,
  ) async {
    final format = ValueNotifier(false);
    addTearDown(format.dispose);
    final changes = <String?>[];
    await _pump(tester, format, '02:30', changes);
    await _open(tester);
    final selector = find.byKey(const ValueKey('time-period-selector'));
    expect(tester.widget(selector), isA<BusyMaxMenuButton<bool>>());
    expect(find.byType(DropdownButton<bool>), findsNothing);
    final input = find.byKey(const ValueKey(('time-input', 'Hour')));
    final triggerSize = tester.getSize(selector);
    final inputSize = tester.getSize(input);
    expect(triggerSize.height, inputSize.height);
    expect(triggerSize.width, lessThanOrEqualTo(inputSize.width * 2));
    expect(tester.getCenter(selector).dy, tester.getCenter(input).dy);
    final periodText = find.descendant(of: selector, matching: find.text('AM'));
    expect(
      DefaultTextStyle.of(tester.element(periodText)).style.fontSize,
      tester.widget<EditableText>(_inputs.first).style.fontSize,
    );
    await tester.tap(selector);
    await tester.pumpAndSettle();
    expect(changes, isEmpty);
    await tester.tap(find.text('PM').last);
    await tester.pumpAndSettle();
    expect(changes, ['14:30']);
    expect(_components(tester), ['2', '30']);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'hour steps preserve an incomplete minute and clearing stays nullable',
    (tester) async {
      final format = ValueNotifier(false);
      addTearDown(format.dispose);
      final changes = <String?>[];
      await _pump(tester, format, '11:30', changes);
      await _open(tester);
      await tester.enterText(_inputs.last, '');
      await tester.tap(find.byIcon(Icons.add).first);
      await tester.pumpAndSettle();
      expect(_components(tester), ['12', '']);
      expect(changes, isEmpty);
      await tester.enterText(_inputs.first, '');
      await tester.pumpAndSettle();
      expect(changes, [null]);
      format.value = true;
      await tester.pumpAndSettle();
      expect(_components(tester), ['', '']);
      expect(changes, [null]);
    },
  );
  for (final hour in [11, 23]) {
    testWidgets('12-hour stepping from $hour crosses the period once', (
      tester,
    ) async {
      final format = ValueNotifier(false);
      addTearDown(format.dispose);
      final changes = <String?>[];
      await _pump(tester, format, '$hour:30', changes);
      await _open(tester);
      expect(_components(tester), ['11', '30']);
      await tester.tap(find.byIcon(Icons.add).first);
      await tester.pumpAndSettle();
      expect(changes, [hour == 11 ? '12:30' : '00:30']);
      expect(_components(tester), ['12', '30']);
      expect(
        tester
            .widget<BusyMaxMenuButton<bool>>(
              find.byKey(const ValueKey('time-period-selector')),
            )
            .entries
            .singleWhere((entry) => entry.selected)
            .value,
        hour == 11,
      );
      await tester.tap(find.byIcon(Icons.add).last);
      await tester.pumpAndSettle();
      expect(changes.length, 2);
      expect(changes.last, hour == 11 ? '12:31' : '00:31');
      format.value = true;
      await tester.pumpAndSettle();
      expect(_components(tester), [hour == 11 ? '12' : '00', '31']);
      expect(find.byKey(const ValueKey('time-period-selector')), findsNothing);
      expect(changes.length, 2);
      format.value = false;
      await tester.pumpAndSettle();
      expect(_components(tester), ['12', '31']);
      expect(changes.length, 2);
    });
  }

  testWidgets(
    'period control is keyboard accessible and preserves components',
    (tester) async {
      final format = ValueNotifier(false);
      addTearDown(format.dispose);
      final changes = <String?>[];
      await _pump(tester, format, '00:05', changes);
      await _open(tester);
      final selector = find.byKey(const ValueKey('time-period-selector'));
      final trigger = find.descendant(
        of: selector,
        matching: find.byType(FilledButton),
      );
      tester.widget<FilledButton>(trigger).focusNode!.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(changes, ['12:05']);
      expect(_components(tester), ['12', '05']);
    },
  );

  testWidgets(
    'incomplete component retains parsing mode across a format change',
    (tester) async {
      final format = ValueNotifier(false);
      addTearDown(format.dispose);
      final changes = <String?>[];
      final validity = <bool>[];
      await _pump(tester, format, '14:30', changes, validity: validity);
      await _open(tester);
      await tester.enterText(_inputs.first, '');
      await tester.pump();
      expect(validity.last, false);
      format.value = true;
      await tester.pumpAndSettle();
      expect(_components(tester), ['', '30']);
      expect(changes, isEmpty);
      await tester.enterText(_inputs.first, '13');
      await tester.pump();
      expect(changes, isEmpty);
      await tester.enterText(_inputs.first, '3');
      await tester.pump();
      expect(changes, ['15:30']);
      expect(validity.last, true);
      tester.testTextInput.hide();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      expect(_components(tester), ['15', '30']);
    },
  );

  testWidgets(
    'focused malformed AM/PM entry survives rebuild and never emits',
    (tester) async {
      final format = ValueNotifier(false);
      addTearDown(format.dispose);
      final changes = <String?>[];
      final validity = <bool>[];
      await _pump(tester, format, '14:30', changes, validity: validity);
      await tester.enterText(find.byType(TextFormField), '13:30 AM');
      await tester.pump();
      format.value = true;
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField))
            .controller!
            .text,
        '13:30 AM',
      );
      expect(validity.last, false);
      expect(changes, isEmpty);
      await tester.enterText(find.byType(TextFormField), '2:30');
      await tester.pump();
      expect(changes, ['02:30']);
    },
  );

  testWidgets(
    'Arabic digit components and a scaled RTL popover remain usable',
    (tester) async {
      final format = ValueNotifier(false);
      addTearDown(format.dispose);
      final changes = <String?>[];
      await _pump(tester, format, '14:30', changes, locale: 'ar', scale: 1.5);
      await _open(tester);
      await tester.enterText(_inputs.first, '٣');
      await tester.pumpAndSettle();
      expect(changes, ['15:30']);
      expect(tester.takeException(), isNull);
    },
  );
}

Finder get _inputs => find.descendant(
  of: find.byType(BusyMaxContentPopoverSurface),
  matching: find.byType(EditableText),
);
List<String> _components(WidgetTester tester) => tester
    .widgetList<EditableText>(_inputs)
    .map((field) => field.controller.text)
    .toList();
Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.byIcon(YaruIcons.clock));
  await tester.pumpAndSettle();
}

Future<void> _pump(
  WidgetTester tester,
  ValueNotifier<bool> format,
  String initial,
  List<String?> changes, {
  List<bool>? validity,
  String locale = 'en',
  double scale = 1,
}) async {
  String? time = initial;
  await tester.pumpWidget(
    MaterialApp(
      theme: BusyMaxYaruTheme.build(
        brightness: Brightness.light,
        accentColor: YaruColors.orange,
      ),
      locale: Locale(locale),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => ValueListenableBuilder<bool>(
        valueListenable: format,
        builder: (context, use24, _) => BusyMaxTimeFormatScope(
          formatter: BusyMaxTimeFormatter(locale: locale, use24Hour: use24),
          child: MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
        ),
      ),
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) => DesktopTimeField(
            label: 'Time',
            time: time,
            timeZone: 'UTC',
            onChanged: (value) {
              changes.add(value);
              setState(() => time = value);
            },
            onValidityChanged: validity?.add,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
