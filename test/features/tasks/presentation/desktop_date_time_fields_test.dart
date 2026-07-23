import 'package:busymax/src/app/busymax_design.dart';
import 'package:busymax/src/features/tasks/presentation/desktop_date_time_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../test_localized_app.dart';

void main() {
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
}

void _ignoreString(String value) {}

void _ignoreNullableString(String? value) {}
