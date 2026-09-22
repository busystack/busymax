import 'package:busymax/src/app/busymax_design.dart';
import 'package:busymax/src/app/busymax_yaru_theme.dart';
import 'package:busymax/src/features/calendar/data/calendar_repository.dart';
import 'package:busymax/src/features/calendar/presentation/ical_import_flow.dart';
import 'package:busymax/src/ical/ical_import_service.dart';
import 'package:busymax/src/ical/ical_ingestion.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaru/yaru.dart';

import '../../../test_localized_app.dart';

void main() {
  testWidgets('Nextcloud import copies uses the Yaru checkbox selection', (
    tester,
  ) async {
    late BuildContext hostContext;
    await tester.pumpWidget(
      localizedTestApp(
        theme: BusyMaxYaruTheme.build(
          brightness: Brightness.dark,
          accentColor: YaruColors.orange,
        ),
        child: Builder(
          builder: (context) {
            hostContext = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    const destination = CalendarSourceEntity(
      id: 'source',
      accountId: 'account',
      provider: BusyProvider.nextcloud,
      providerCalendarId: 'calendar',
      summary: 'Work',
      selected: true,
      hidden: false,
      readOnly: false,
      isDeleted: false,
    );
    final result = showIcalImportPreviewDialog(
      hostContext,
      preview: _preview(),
      destinations: const [destination],
      accountLabels: const {'account': 'Nextcloud'},
    );
    await tester.pumpAndSettle();

    expect(find.byType(BusyMaxDialogShell), findsOneWidget);
    expect(find.byType(CheckboxListTile), findsNothing);
    final checkboxFinder = find.byKey(
      const ValueKey('nextcloud-import-copies'),
    );
    expect(checkboxFinder, findsOneWidget);
    expect(tester.widget<YaruCheckboxListTile>(checkboxFinder).value, isFalse);

    await tester.tap(checkboxFinder);
    await tester.pump();
    expect(tester.widget<YaruCheckboxListTile>(checkboxFinder).value, isTrue);
    await tester.tap(find.byKey(const ValueKey('confirm-ics-import')));
    await tester.pumpAndSettle();

    final selection = await result;
    expect(selection?.destination, same(destination));
    expect(selection?.newCopies, isTrue);
  });

  testWidgets('import copies remains Nextcloud-only and cancellation is null', (
    tester,
  ) async {
    late BuildContext hostContext;
    await tester.pumpWidget(
      localizedTestApp(
        child: Builder(
          builder: (context) {
            hostContext = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    const destination = CalendarSourceEntity(
      id: 'source',
      accountId: 'account',
      provider: BusyProvider.google,
      providerCalendarId: 'calendar',
      summary: 'Work',
      selected: true,
      hidden: false,
      readOnly: false,
      isDeleted: false,
    );
    final result = showIcalImportPreviewDialog(
      hostContext,
      preview: _preview(),
      destinations: const [destination],
      accountLabels: const {'account': 'Google'},
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('nextcloud-import-copies')), findsNothing);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(await result, isNull);
  });
}

IcalImportPreview _preview() {
  final ingestion = IcalIngestion.parseString('''BEGIN:VCALENDAR\r
VERSION:2.0\r
PRODID:-//BusyMax Test//EN\r
BEGIN:VEVENT\r
UID:import-preview-event\r
DTSTART:20260920T160000Z\r
DTEND:20260920T170000Z\r
SUMMARY:Imported event\r
END:VEVENT\r
END:VCALENDAR\r
''', policy: IcalIngestionPolicy.fileImport);
  return IcalImportPreview(
    ingestion: ingestion,
    eventCount: 1,
    invalidEventCount: 0,
    fieldsThatWillBeOmitted: const {},
  );
}
