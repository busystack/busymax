import 'dart:async';

import 'package:busymax/l10n/generated/app_localizations.dart';
import 'package:busymax/src/l10n/week_preferences_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('all preferences resolve with explicit choices taking precedence', () {
    for (final preference in BusyMaxFirstDayOfWeekPreference.values.skip(1)) {
      expect(
        resolveBusyMaxFirstWeekday(
          preference: preference,
          systemWeekday: DateTime.sunday,
          platformLocaleTag: 'en-US',
        ),
        preference.weekday,
      );
    }
    expect(
      resolveBusyMaxFirstWeekday(
        preference: BusyMaxFirstDayOfWeekPreference.system,
        systemWeekday: DateTime.wednesday,
        platformLocaleTag: 'en-US',
      ),
      DateTime.wednesday,
    );
  });

  test('locale fallback preserves region and Unicode fw overrides', () {
    expect(busyMaxFirstWeekdayFromLocale('en-US'), DateTime.sunday);
    expect(busyMaxFirstWeekdayFromLocale('de-DE'), DateTime.monday);
    for (final entry in const {
      'mon': DateTime.monday,
      'tue': DateTime.tuesday,
      'wed': DateTime.wednesday,
      'thu': DateTime.thursday,
      'fri': DateTime.friday,
      'sat': DateTime.saturday,
      'sun': DateTime.sunday,
    }.entries) {
      expect(
        busyMaxFirstWeekdayFromLocale('en-US-u-fw-${entry.key}'),
        entry.value,
      );
    }
    expect(
      resolveBusyMaxFirstWeekday(
        preference: BusyMaxFirstDayOfWeekPreference.system,
        systemWeekday: null,
        platformLocaleTag: 'unknown',
      ),
      DateTime.monday,
    );
  });

  testWidgets('refresh ignores stale reads and changes after disposal', (
    tester,
  ) async {
    final source = _ControlledSource();
    final controller = BusyMaxSystemFirstWeekdayController(source);
    final first = source.reads.single;
    source.notify();
    await tester.pump();
    final second = source.reads.last;
    first.complete(DateTime.tuesday);
    await tester.pump();
    expect(controller.value, isNull);
    second.complete(DateTime.saturday);
    await tester.pump();
    expect(controller.value, DateTime.saturday);

    source.notify();
    await tester.pump();
    final afterDispose = source.reads.last;
    controller.dispose();
    afterDispose.complete(DateTime.friday);
    await tester.pump();
    expect(source.disposed, isTrue);
  });

  testWidgets('resume and locale changes refresh one application owner', (
    tester,
  ) async {
    final source = _ImmediateSource(DateTime.monday);
    final controller = BusyMaxSystemFirstWeekdayController(source);
    await tester.pump();
    expect(source.readCount, 1);
    source.value = DateTime.thursday;
    controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await tester.pump();
    expect(controller.value, DateTime.thursday);
    controller.didChangeLocales(const [Locale('fr', 'CA')]);
    await tester.pump();
    expect(source.readCount, 3);
    controller.dispose();
  });

  testWidgets('automatic label uses UI language and system region separately', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('de'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('de')],
        builder: (context, child) => BusyMaxWeekPreferencesScope(
          preference: BusyMaxFirstDayOfWeekPreference.system,
          systemWeekday: DateTime.sunday,
          platformLocaleTag: 'en-US',
          child: child!,
        ),
        home: Builder(
          builder: (context) => Text(
            busyMaxFirstDayOfWeekPreferenceLabel(
              context,
              BusyMaxFirstDayOfWeekPreference.system,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Systemstandard (Sonntag)'), findsOneWidget);
  });
}

class _ControlledSource implements BusyMaxSystemFirstWeekdaySource {
  final events = StreamController<void>.broadcast(sync: true);
  final reads = <Completer<int?>>[];
  bool disposed = false;

  void notify() => events.add(null);

  @override
  Stream<void> get changes => events.stream;

  @override
  Future<int?> read() {
    final result = Completer<int?>();
    reads.add(result);
    return result.future;
  }

  @override
  void dispose() {
    disposed = true;
    unawaited(events.close());
  }
}

class _ImmediateSource implements BusyMaxSystemFirstWeekdaySource {
  _ImmediateSource(this.value);

  int? value;
  int readCount = 0;

  @override
  Stream<void> get changes => const Stream.empty();

  @override
  Future<int?> read() async {
    readCount++;
    return value;
  }

  @override
  void dispose() {}
}
