import 'dart:io';

import 'package:busymax/src/app/linux/linux_header_style.dart';
import 'package:busymax/src/platform/gtk_header_icon_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Linux resolves the live GTK header-icon catalog', (
    tester,
  ) async {
    if (!Platform.isLinux) return;
    final service = GtkHeaderIconService();
    addTearDown(service.dispose);

    expect(await service.initialize(), isTrue);
    final catalog = service.catalog;
    expect(catalog.scale, greaterThanOrEqualTo(1));
    for (final icon in const [
      BusyMaxLinuxHeaderIcon.back,
      BusyMaxLinuxHeaderIcon.previous,
      BusyMaxLinuxHeaderIcon.next,
      BusyMaxLinuxHeaderIcon.search,
      BusyMaxLinuxHeaderIcon.searchClear,
      BusyMaxLinuxHeaderIcon.mainMenu,
      BusyMaxLinuxHeaderIcon.create,
      BusyMaxLinuxHeaderIcon.refresh,
      BusyMaxLinuxHeaderIcon.viewDay,
      BusyMaxLinuxHeaderIcon.viewWeek,
      BusyMaxLinuxHeaderIcon.viewMonth,
      BusyMaxLinuxHeaderIcon.viewYear,
      BusyMaxLinuxHeaderIcon.viewAgenda,
      BusyMaxLinuxHeaderIcon.viewMenuArrow,
      BusyMaxLinuxHeaderIcon.close,
    ]) {
      final asset = catalog.assetFor(icon, TextDirection.ltr);
      expect(asset, isNotNull, reason: 'GTK did not resolve ${icon.gtkNames}');
      expect(asset!.bytes, isNotEmpty);
      expect(asset.pixelWidth, greaterThan(0));
      expect(asset.pixelHeight, greaterThan(0));
      expect(asset.scale, catalog.scale);
    }
    expect(
      catalog
          .assetFor(BusyMaxLinuxHeaderIcon.today, TextDirection.ltr)!
          .resolvedName,
      anyOf('today-symbolic', 'x-office-calendar-symbolic'),
    );
    for (final icon in const [
      BusyMaxLinuxHeaderIcon.viewWeek,
      BusyMaxLinuxHeaderIcon.viewMonth,
    ]) {
      expect(
        catalog.assetFor(icon, TextDirection.ltr)!.resolvedName,
        isIn(icon.gtkNames),
      );
    }
    debugPrint(
      'GTK header icon catalog: '
      '${{
        for (final icon in const [BusyMaxLinuxHeaderIcon.viewDay, BusyMaxLinuxHeaderIcon.viewWeek, BusyMaxLinuxHeaderIcon.viewMonth, BusyMaxLinuxHeaderIcon.viewYear, BusyMaxLinuxHeaderIcon.viewAgenda, BusyMaxLinuxHeaderIcon.filter]) icon.name: catalog.assetFor(icon, TextDirection.ltr)?.resolvedName ?? 'missing-optional',
      }}',
    );

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
    expect(find.byType(Image), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(BusyMaxGtkHeaderIcon),
        matching: find.byType(CustomPaint),
      ),
      findsNothing,
    );
  });
}
