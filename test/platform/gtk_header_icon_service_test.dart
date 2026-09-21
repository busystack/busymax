import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:busymax/src/app/linux/linux_header_style.dart';
import 'package:busymax/src/platform/gtk_header_icon_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('semantic catalog uses the exact native GTK icon names', () {
    expect(BusyMaxLinuxHeaderIcon.back.gtkNames, const [
      'go-previous-symbolic',
    ]);
    expect(BusyMaxLinuxHeaderIcon.sidebar.gtkNames, const [
      'sidebar-show-symbolic',
    ]);
    expect(BusyMaxLinuxHeaderIcon.today.gtkNames, const [
      'today-symbolic',
      'x-office-calendar-symbolic',
    ]);
    expect(BusyMaxLinuxHeaderIcon.previous.gtkNames, const [
      'go-previous-symbolic',
    ]);
    expect(BusyMaxLinuxHeaderIcon.next.gtkNames, const ['go-next-symbolic']);
    expect(BusyMaxLinuxHeaderIcon.search.gtkNames, const [
      'system-search-symbolic',
    ]);
    expect(BusyMaxLinuxHeaderIcon.searchClear.gtkNames, const [
      'edit-clear-symbolic',
    ]);
    expect(BusyMaxLinuxHeaderIcon.mainMenu.gtkNames, const [
      'open-menu-symbolic',
    ]);
    expect(BusyMaxLinuxHeaderIcon.create.gtkNames, const ['list-add-symbolic']);
    expect(BusyMaxLinuxHeaderIcon.refresh.gtkNames, const [
      'view-refresh-symbolic',
    ]);
    expect(BusyMaxLinuxHeaderIcon.viewDay.gtkNames, const [
      'view-continuous-symbolic',
    ]);
    expect(BusyMaxLinuxHeaderIcon.viewWeek.gtkNames, const [
      'calendar-week-symbolic',
      'x-office-calendar-symbolic',
    ]);
    expect(BusyMaxLinuxHeaderIcon.viewMonth.gtkNames, const [
      'calendar-month-symbolic',
      'x-office-calendar-symbolic',
    ]);
    expect(BusyMaxLinuxHeaderIcon.viewYear.gtkNames, const [
      'view-app-grid-symbolic',
    ]);
    expect(BusyMaxLinuxHeaderIcon.viewAgenda.gtkNames, const [
      'view-list-symbolic',
    ]);
    expect(BusyMaxLinuxHeaderIcon.viewMenuArrow.gtkNames, const [
      'pan-down-symbolic',
    ]);
    expect(BusyMaxLinuxHeaderIcon.filter.gtkNames, const [
      'view-filter-symbolic',
    ]);
    expect(BusyMaxLinuxHeaderIcon.close.gtkNames, const [
      'window-close-symbolic',
    ]);
  });

  test(
    'initial load batches direction variants and preserves candidate order',
    () async {
      late List<Map<String, Object>> observedRequests;
      final service = GtkHeaderIconService.testing(
        loadBatch: (requests) async {
          observedRequests = requests;
          return _responseFor(requests, _pngA, scale: 1);
        },
      );
      addTearDown(service.dispose);

      expect(await service.initialize(), isTrue);
      expect(service.reloadCount, 1);
      expect(service.catalog.scale, 1);

      final today = observedRequests.singleWhere(
        (request) => request['key'] == 'today.ltr',
      );
      expect(today['names'], const [
        'today-symbolic',
        'x-office-calendar-symbolic',
      ]);
      expect(today['direction'], 'ltr');
      expect(today['allowMissing'], isFalse);

      final filter = observedRequests.singleWhere(
        (request) => request['key'] == 'filter.ltr',
      );
      expect(filter['allowMissing'], isTrue);
      expect(
        observedRequests
            .where((request) => request['key'] != 'filter.ltr')
            .every((request) => request['allowMissing'] == false),
        isTrue,
      );

      for (final icon in const [
        BusyMaxLinuxHeaderIcon.back,
        BusyMaxLinuxHeaderIcon.sidebar,
        BusyMaxLinuxHeaderIcon.previous,
        BusyMaxLinuxHeaderIcon.next,
      ]) {
        expect(
          observedRequests.where(
            (request) => (request['key'] as String).startsWith('${icon.name}.'),
          ),
          hasLength(2),
        );
      }
      expect(
        observedRequests.where(
          (request) => (request['key'] as String).startsWith('viewWeek.'),
        ),
        hasLength(1),
      );
    },
  );

  testWidgets(
    'theme and scale invalidation atomically replaces one cached catalog',
    (tester) async {
      final invalidations = StreamController<Object?>.broadcast(sync: true);
      final replacement = Completer<Object?>();
      var calls = 0;
      final service = GtkHeaderIconService.testing(
        changedEvents: invalidations.stream,
        loadBatch: (requests) {
          calls += 1;
          if (calls == 1) {
            return Future.value(_responseFor(requests, _pngA, scale: 1));
          }
          return replacement.future;
        },
      );
      addTearDown(() async {
        service.dispose();
        await invalidations.close();
      });
      expect(await service.initialize(), isTrue);
      final originalCatalog = service.catalog;

      await tester.pumpWidget(
        GtkHeaderIconScope(
          service: service,
          child: const MaterialApp(
            home: Center(
              child: BusyMaxGtkHeaderIcon(BusyMaxLinuxHeaderIcon.search),
            ),
          ),
        ),
      );
      expect(
        tester.getSize(find.byType(BusyMaxGtkHeaderIcon)),
        const Size.square(BusyMaxLinuxHeaderStyle.symbolicIconSize),
      );
      expect(_renderedBytes(tester), _pngA);
      expect(_fallbackPaint(), findsNothing);

      invalidations.add(const {'revision': 1, 'scale': 2});
      invalidations.add(const {'revision': 1, 'scale': 2});
      await tester.pump();
      expect(service.reloadCount, 2);
      expect(identical(service.catalog, originalCatalog), isTrue);
      expect(_renderedBytes(tester), _pngA);
      expect(_fallbackPaint(), findsNothing);

      replacement.complete(
        _responseFor(_allRequestsFrom(originalCatalog), _pngB, scale: 2),
      );
      await tester.pump();
      await tester.pump();

      expect(service.reloadCount, 2);
      expect(identical(service.catalog, originalCatalog), isFalse);
      expect(service.catalog.revision, 1);
      expect(service.catalog.scale, 2);
      expect(_renderedBytes(tester), _pngB);
      expect(
        tester.getSize(find.byType(BusyMaxGtkHeaderIcon)),
        const Size.square(BusyMaxLinuxHeaderStyle.symbolicIconSize),
      );
      expect(_fallbackPaint(), findsNothing);
    },
  );
}

List<Map<String, Object>> _lastRequests = const [];

Map<String, Object?> _responseFor(
  List<Map<String, Object>> requests,
  Uint8List bytes, {
  required int scale,
}) {
  _lastRequests = requests;
  return {
    for (final request in requests)
      request['key']! as String: {
        'bytes': bytes,
        'resolvedName': (request['names']! as List<String>).first,
        'scale': scale,
        'pixelWidth': 16 * scale,
        'pixelHeight': 16 * scale,
      },
  };
}

List<Map<String, Object>> _allRequestsFrom(GtkHeaderIconCatalog _) =>
    _lastRequests;

Uint8List _renderedBytes(WidgetTester tester) {
  final image = tester.widget<Image>(find.byType(Image));
  return (image.image as MemoryImage).bytes;
}

Finder _fallbackPaint() => find.descendant(
  of: find.byType(BusyMaxGtkHeaderIcon),
  matching: find.byType(CustomPaint),
);

final _pngA = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScL1WQAAAABJRU5ErkJggg==',
);
final _pngB = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4////fwAJ+wP+4Xz8WQAAAABJRU5ErkJggg==',
);
