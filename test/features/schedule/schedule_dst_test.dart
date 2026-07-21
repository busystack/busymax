import 'dart:ffi';
import 'dart:io';

import 'package:busymax/src/features/schedule/presentation/schedule_month_view.dart';
import 'package:busymax/src/schedule/schedule_range.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_localized_app.dart';

void main() {
  final supportsPosixTimeZones = Platform.isLinux || Platform.isMacOS;

  group(
    'calendar ranges across daylight-saving transitions',
    skip: supportsPosixTimeZones
        ? false
        : 'This regression test requires POSIX setenv and tzset.',
    () {
      late _ProcessTimeZone processTimeZone;

      setUpAll(() {
        processTimeZone = _ProcessTimeZone();
        processTimeZone.set('America/Vancouver');
      });

      tearDownAll(() {
        processTimeZone.restore();
      });

      test('day ranges end at the next local midnight', () {
        final springForward = ScheduleRange.day(DateTime(2025, 3, 9));
        final fallBack = ScheduleRange.day(DateTime(2025, 11, 2));

        expect(springForward.start, DateTime(2025, 3, 9));
        expect(springForward.end, DateTime(2025, 3, 10));
        expect(springForward.end.difference(springForward.start).inHours, 23);

        expect(fallBack.start, DateTime(2025, 11, 2));
        expect(fallBack.end, DateTime(2025, 11, 3));
        expect(fallBack.end.difference(fallBack.start).inHours, 25);
      });

      test('week ranges retain civil midnights at both boundaries', () {
        final springForward = ScheduleRange.week(
          DateTime(2025, 3, 10),
          firstWeekday: DateTime.sunday,
        );
        final fallBack = ScheduleRange.week(
          DateTime(2025, 11, 3),
          firstWeekday: DateTime.sunday,
        );

        expect(springForward.start, DateTime(2025, 3, 9));
        expect(springForward.end, DateTime(2025, 3, 16));
        expect(springForward.end.difference(springForward.start).inHours, 167);

        expect(fallBack.start, DateTime(2025, 11, 2));
        expect(fallBack.end, DateTime(2025, 11, 9));
        expect(fallBack.end.difference(fallBack.start).inHours, 169);
      });

      test('month range retains civil midnight across its trailing days', () {
        final range = ScheduleRange.month(DateTime(2025, 10, 15));

        expect(range.start, DateTime(2025, 9, 29));
        expect(range.end, DateTime(2025, 11, 3));
      });

      testWidgets('month view emits every civil date exactly once', (
        tester,
      ) async {
        final selectedDays = <DateTime>[];

        await tester.pumpWidget(
          localizedTestApp(
            child: Scaffold(
              body: SizedBox(
                width: 1000,
                height: 720,
                child: ScheduleMonthView(
                  range: ScheduleRange(
                    start: DateTime(2025, 10, 27),
                    end: DateTime(2025, 11, 10),
                  ),
                  selectedDate: DateTime(2025, 11, 15),
                  items: const [],
                  firstWeekday: DateTime.monday,
                  onDaySelected: selectedDays.add,
                  onCreateAtDay: (_) {},
                  onItemSelected: (_, _, [_]) {},
                  onTaskCompletionChanged: (_, _) {},
                ),
              ),
            ),
          ),
        );

        final dayCells = tester
            .widgetList<InkWell>(
              find.descendant(
                of: find.byType(ScheduleMonthView),
                matching: find.byType(InkWell),
              ),
            )
            .where((cell) => cell.onDoubleTap != null);
        for (final cell in dayCells) {
          cell.onTap!();
        }

        expect(
          selectedDays,
          List<DateTime>.generate(
            14,
            (index) => DateTime(2025, 10, 27 + index),
          ),
        );
      });
    },
  );
}

typedef _MallocNative = Pointer<Void> Function(IntPtr size);
typedef _MallocDart = Pointer<Void> Function(int size);
typedef _FreeNative = Void Function(Pointer<Void> pointer);
typedef _FreeDart = void Function(Pointer<Void> pointer);
typedef _SetEnvNative =
    Int32 Function(Pointer<Char> name, Pointer<Char> value, Int32 overwrite);
typedef _SetEnvDart =
    int Function(Pointer<Char> name, Pointer<Char> value, int overwrite);
typedef _UnsetEnvNative = Int32 Function(Pointer<Char> name);
typedef _UnsetEnvDart = int Function(Pointer<Char> name);
typedef _TimeZoneSetNative = Void Function();
typedef _TimeZoneSetDart = void Function();

final class _ProcessTimeZone {
  _ProcessTimeZone()
    : _previous = Platform.environment['TZ'],
      _malloc = DynamicLibrary.process()
          .lookupFunction<_MallocNative, _MallocDart>('malloc'),
      _free = DynamicLibrary.process().lookupFunction<_FreeNative, _FreeDart>(
        'free',
      ),
      _setEnv = DynamicLibrary.process()
          .lookupFunction<_SetEnvNative, _SetEnvDart>('setenv'),
      _unsetEnv = DynamicLibrary.process()
          .lookupFunction<_UnsetEnvNative, _UnsetEnvDart>('unsetenv'),
      _timeZoneSet = DynamicLibrary.process()
          .lookupFunction<_TimeZoneSetNative, _TimeZoneSetDart>('tzset');

  final String? _previous;
  final _MallocDart _malloc;
  final _FreeDart _free;
  final _SetEnvDart _setEnv;
  final _UnsetEnvDart _unsetEnv;
  final _TimeZoneSetDart _timeZoneSet;

  void set(String value) {
    final namePointer = _allocateString('TZ');
    final valuePointer = _allocateString(value);
    try {
      if (_setEnv(namePointer, valuePointer, 1) != 0) {
        throw StateError('Unable to set the process time zone.');
      }
      _timeZoneSet();
    } finally {
      _free(namePointer.cast<Void>());
      _free(valuePointer.cast<Void>());
    }
  }

  void restore() {
    if (_previous case final previous?) {
      set(previous);
      return;
    }

    final namePointer = _allocateString('TZ');
    try {
      if (_unsetEnv(namePointer) != 0) {
        throw StateError('Unable to restore the process time zone.');
      }
      _timeZoneSet();
    } finally {
      _free(namePointer.cast<Void>());
    }
  }

  Pointer<Char> _allocateString(String value) {
    final units = value.codeUnits;
    final pointer = _malloc(units.length + 1).cast<Uint8>();
    for (var index = 0; index < units.length; index++) {
      pointer[index] = units[index];
    }
    pointer[units.length] = 0;
    return pointer.cast<Char>();
  }
}
