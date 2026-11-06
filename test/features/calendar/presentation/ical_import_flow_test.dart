import 'package:busymax/l10n/generated/app_localizations_en.dart';
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
  testWidgets('CalDAV attendee import needs consent before confirmation', (
    tester,
  ) async {
    late BuildContext host;
    await tester.pumpWidget(
      localizedTestApp(
        child: Builder(
          builder: (context) {
            host = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    const destination = CalendarSourceEntity(
      id: 'source',
      accountId: 'account',
      provider: BusyProvider.caldav,
      providerCalendarId: 'calendar',
      summary: 'Work',
      selected: true,
      hidden: false,
      readOnly: false,
      isDeleted: false,
    );
    final preview = IcalImportPreview(
      ingestion: IcalIngestion.parseBytes(
        'BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//BusyMax//QA//EN\r\nBEGIN:VEVENT\r\nUID:meeting\r\nDTSTART:20261103T120000Z\r\nORGANIZER:mailto:qa@example.test\r\nATTENDEE:mailto:guest@example.test\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n'
            .codeUnits,
        policy: IcalIngestionPolicy.fileImport,
      ),
      eventCount: 1,
      invalidEventCount: 0,
      fieldsThatWillBeOmitted: const {},
    );
    final result = showIcalImportPreviewDialog(
      host,
      preview: preview,
      destinations: const [destination],
      accountLabels: const {},
    );
    await tester.pumpAndSettle();
    expect(find.text(AppLocalizationsEn().caldavNativeImport), findsOneWidget);
    expect(find.text(AppLocalizationsEn().nextcloudNativeImport), findsNothing);
    expect(
      find.text(AppLocalizationsEn().caldavImportSchedulingWarning),
      findsOneWidget,
    );
    final confirm = find.byKey(const ValueKey('confirm-ics-import'));
    expect(tester.widget<ElevatedButton>(confirm).onPressed, isNull);
    await tester.tap(
      find.byKey(const ValueKey('caldav-import-scheduling-consent')),
    );
    await tester.pump();
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect((await result)?.allowScheduling, isTrue);
  });

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
    expect(
      find.text(AppLocalizationsEn().nextcloudNativeImport),
      findsOneWidget,
    );
    expect(find.text(AppLocalizationsEn().caldavNativeImport), findsNothing);
    expect(
      find.byKey(const ValueKey('caldav-import-scheduling-consent')),
      findsNothing,
    );
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
