import 'dart:io';

import 'package:busymax/src/app/busymax_about_dialog.dart';
import 'package:busymax/src/app/busymax_design.dart';
import 'package:busymax/src/app/busymax_dialog_identity.dart';
import 'package:busymax/src/app/busymax_dialogs.dart';
import 'package:busymax/src/app/busymax_yaru_theme.dart';
import 'package:busymax/src/platform/linux_header_bar_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:yaru/yaru.dart';

import '../test_localized_app.dart';

void main() {
  setUp(() {
    _setPackageInfo(version: '1.2.3', buildNumber: '45');
  });

  testWidgets('about dialog shows app identity and app links', (tester) async {
    await tester.pumpWidget(
      localizedTestApp(child: const BusyMaxAboutDialog()),
    );
    await tester.pumpAndSettle();

    expect(find.text('BusyMax'), findsOneWidget);
    expect(find.text('ToDo and Calendar'), findsOneWidget);
    expect(find.text('Website'), findsOneWidget);
    expect(find.text('Send feedback'), findsOneWidget);
    expect(find.text('Report an issue'), findsOneWidget);
    expect(find.text('v1.2.3+45'), findsOneWidget);
    expect(find.byType(YaruDialogTitleBar), findsOneWidget);
    expect(find.byType(YaruWindowControl), findsOneWidget);
    expect(find.text('Close'), findsNothing);

    final identity = find.byType(BusyMaxDialogIdentity);
    final title = tester.widget<Text>(
      find.descendant(of: identity, matching: find.text('BusyMax')),
    );
    expect(identity, findsOneWidget);
    expect(
      tester.getSize(
        find.descendant(of: identity, matching: find.byType(Image)),
      ),
      const Size.square(BusyMaxDialogIdentity.visualExtent),
    );
    expect(title.style?.fontWeight, BusyMaxDialogIdentity.titleWeight);

    final titleBar = tester.widget<YaruDialogTitleBar>(
      find.byType(YaruDialogTitleBar),
    );
    final closeButton = tester.widget<YaruWindowControl>(
      find.byType(YaruWindowControl),
    );
    expect(titleBar.isActive, isTrue);
    expect(titleBar.border, BorderSide.none);
    expect(closeButton.type, YaruWindowControlType.close);
    expect(
      tester.getSize(find.byType(YaruWindowControl)),
      const Size.square(kYaruWindowControlSize),
    );
  });

  testWidgets(
    'informational titlebar retains its semantic high-contrast divider',
    (tester) async {
      final theme = BusyMaxYaruTheme.build(
        brightness: Brightness.light,
        accentColor: Colors.black,
        highContrast: true,
      );

      await tester.pumpWidget(
        localizedTestApp(theme: theme, child: const BusyMaxAboutDialog()),
      );
      await tester.pumpAndSettle();

      final titleBar = tester.widget<YaruDialogTitleBar>(
        find.byType(YaruDialogTitleBar),
      );
      final colors = theme.extension<BusyMaxSurfaceColors>()!;
      expect(titleBar.border, BorderSide(color: colors.divider));
    },
  );

  for (final textScale in [1.0, 2.0]) {
    testWidgets(
      'about dialog remains scrollable in a short window at ${textScale}x text',
      (tester) async {
        tester.view
          ..devicePixelRatio = 1
          ..physicalSize = const Size(480, 320);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          localizedTestApp(
            textScaler: TextScaler.linear(textScale),
            child: const BusyMaxAboutDialog(),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        final scrollView = find.byType(SingleChildScrollView);
        final closeButton = find.byType(YaruWindowControl);
        expect(scrollView, findsOneWidget);
        expect(closeButton.hitTestable(), findsOneWidget);
        final closePosition = tester.getTopLeft(closeButton);

        await tester.drag(scrollView, const Offset(0, -400));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Report an issue').hitTestable(), findsOneWidget);
        expect(closeButton.hitTestable(), findsOneWidget);
        expect(tester.getTopLeft(closeButton), closePosition);
      },
    );
  }

  testWidgets(
    'about modal route stays responsive and restores the native barrier',
    (tester) async {
      const channel = MethodChannel('busymax_test/about_modal_route');
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return call.method == 'initialize' ? true : null;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });
      final service = LinuxHeaderBarService(channel: channel, isLinux: true);
      addTearDown(service.dispose);
      await service.initialize();

      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(480, 320);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      late BuildContext hostContext;
      await tester.pumpWidget(
        localizedTestApp(
          textScaler: const TextScaler.linear(2),
          child: Builder(
            builder: (context) {
              hostContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      late BuildContext dialogContext;
      final result = showBusyMaxModalDialog<void>(
        hostContext,
        headerBarService: service,
        builder: (context) {
          dialogContext = context;
          return const BusyMaxAboutDialog();
        },
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(BusyMaxAboutDialog), findsOneWidget);
      expect(MediaQuery.textScalerOf(dialogContext).scale(10), 20);
      expect(
        tester.widget<Dialog>(find.byType(Dialog)).clipBehavior,
        Clip.antiAlias,
      );
      expect(
        tester
            .state<ScrollableState>(
              find.descendant(
                of: find.byType(BusyMaxAboutDialog),
                matching: find.byType(Scrollable),
              ),
            )
            .position
            .maxScrollExtent,
        greaterThan(0),
      );
      expect(
        calls
            .where((call) => call.method == 'setModalBarrierVisible')
            .single
            .arguments,
        isTrue,
      );

      await tester.tap(find.byType(YaruWindowControl));
      await tester.pumpAndSettle();

      await result;
      expect(find.byType(BusyMaxAboutDialog), findsNothing);
      final barrierCalls = calls
          .where((call) => call.method == 'setModalBarrierVisible')
          .toList();
      expect(barrierCalls, hasLength(2));
      expect(barrierCalls.last.arguments, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  for (final brightness in Brightness.values) {
    testWidgets(
      'about version badge keeps accent identity and readable text in '
      '$brightness',
      (tester) async {
        const accent = Color(0xFF3584E4);
        _setPackageInfo(version: '1.2.3', buildNumber: '');
        final theme = BusyMaxYaruTheme.build(
          brightness: brightness,
          accentColor: accent,
        );

        await tester.pumpWidget(
          localizedTestApp(theme: theme, child: const BusyMaxAboutDialog()),
        );
        await tester.pumpAndSettle();

        expect(find.text('v1.2.3'), findsOneWidget);
        expect(find.text('v1.2.3+'), findsNothing);
        final badge = tester.widget<YaruTranslucentContainer>(
          find.byType(YaruTranslucentContainer),
        );
        expect(badge.color, theme.colorScheme.primary);
        expect(badge.opacity, 1);
        expect((badge.border! as Border).dimensions, EdgeInsets.zero);
        final versionText = tester.widget<Text>(find.text('v1.2.3'));
        final textColor = versionText.style!.color!;
        expect(textColor, theme.colorScheme.onPrimary);
        expect(versionText.style?.fontWeight, FontWeight.w600);
      },
    );
  }

  for (final (brightness, dialogColor, popoverColor) in const [
    (Brightness.light, Color(0xFFFAFAFA), Color(0xFFFAFAFA)),
    (Brightness.dark, Color(0xFF3E3E3E), Color(0xFF3E3E3E)),
  ]) {
    testWidgets('about dialog keeps grouped content distinct in $brightness', (
      tester,
    ) async {
      final theme = BusyMaxYaruTheme.build(
        brightness: brightness,
        accentColor: const Color(0xFF3584E4),
      );
      final colors = theme.extension<BusyMaxSurfaceColors>()!;

      await tester.pumpWidget(
        localizedTestApp(theme: theme, child: const BusyMaxAboutDialog()),
      );

      final dialogMaterials = tester.widgetList<Material>(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.byType(Material),
        ),
      );
      final expectedGroupedColor = Color.alphaBlend(
        colors.groupedSurface,
        colors.dialog,
      );
      final groupedMaterial = tester.widget<Material>(
        find.descendant(
          of: find.byType(BusyMaxGroupedSurface),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Material &&
                widget.color?.toARGB32() == expectedGroupedColor.toARGB32(),
          ),
        ),
      );
      expect(colors.dialog, dialogColor);
      expect(colors.popover, popoverColor);
      expect(colors.dialog, isNot(colors.sidebar));
      expect(
        dialogMaterials.any((material) => material.color == dialogColor),
        isTrue,
      );
      expect(
        groupedMaterial.color?.toARGB32(),
        expectedGroupedColor.toARGB32(),
      );
      expect(groupedMaterial.elevation, theme.cardTheme.elevation);
      expect(
        find.descendant(
          of: find.byType(BusyMaxGroupedSurface),
          matching: find.byType(Card),
        ),
        findsOneWidget,
      );
      expect(groupedMaterial.color, isNot(dialogColor));
      if (brightness == Brightness.dark) {
        expect(
          groupedMaterial.color?.toARGB32(),
          isNot(colors.card.toARGB32()),
        );
        expect(
          groupedMaterial.color!.computeLuminance(),
          greaterThan(colors.dialog.computeLuminance()),
        );
      }
    });
  }

  test('about links point to BusyStack repository', () {
    final source = File(
      'lib/src/app/busymax_about_dialog.dart',
    ).readAsStringSync();

    expect(source, contains('https://github.com/busystack/busymax'));
    expect(source, contains('https://github.com/busystack/busymax/issues'));
    expect(source, isNot(contains('https://github.com/albertgee/busymax')));
  });

  test(
    'about dialog uses native headerbar dimming and shared close adapter',
    () {
      final source = File(
        'lib/src/app/busymax_about_dialog.dart',
      ).readAsStringSync();
      final dialogs = File(
        'lib/src/app/busymax_dialogs.dart',
      ).readAsStringSync();

      expect(source, contains('showBusyMaxModalDialog'));
      expect(source, contains('headerBarService: headerBarService'));
      expect(dialogs, contains('acquireBusyMaxModalBarrier'));
      expect(dialogs, contains('releaseBusyMaxModalBarrier'));
      expect(
        dialogs,
        contains('await acquireBusyMaxModalBarrier(headerBarService)'),
      );
      expect(
        dialogs,
        contains('await releaseBusyMaxModalBarrier(headerBarService)'),
      );
      expect(source, isNot(contains('barrierColor: Colors.transparent')));
      expect(source, contains('BusyMaxInformationalDialog('));
      expect(source, isNot(contains('BusyMaxPopoverIconButton(')));
      expect(source, isNot(contains('BusyMaxDialogCloseButton')));
    },
  );

  test('about logo renders the PNG asset, not the launcher SVG', () {
    final source = File(
      'lib/src/app/busymax_about_dialog.dart',
    ).readAsStringSync();
    final pubspec = File('pubspec.yaml').readAsStringSync();

    expect(source, contains('Image.asset'));
    expect(source, contains('assets/branding/busymax-logo.png'));
    expect(source, isNot(contains('assets/branding/busymax-logo.svg')));
    expect(source, isNot(contains('Image.memory')));
    expect(pubspec, contains('assets/branding/busymax-logo.png'));
    expect(source, isNot(contains('YaruIcons.calendar')));
  });
}

void _setPackageInfo({required String version, required String buildNumber}) {
  PackageInfo.setMockInitialValues(
    appName: 'BusyMax',
    packageName: 'com.busystack.busymax',
    version: version,
    buildNumber: buildNumber,
    buildSignature: '',
  );
}
