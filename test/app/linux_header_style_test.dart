import 'dart:convert';
import 'dart:ui' show SemanticsAction;

import 'package:busymax/src/app/app_theme.dart';
import 'package:busymax/src/app/busymax_design.dart';
import 'package:busymax/src/app/busymax_surface_colors.dart';
import 'package:busymax/src/app/linux/linux_header_style.dart';
import 'package:busymax/src/app/linux/linux_window_host.dart';
import 'package:busymax/src/platform/gtk_header_icon_service.dart';
import 'package:busymax/src/platform/gtk_window_preferences_service.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaru/yaru.dart';

void main() {
  group('absolute Linux header title centering', () {
    for (final testCase in const [
      _LayoutCase('small leading and large trailing', 34, 154, 0, 0, false),
      _LayoutCase('large leading and small trailing', 154, 34, 0, 0, false),
      _LayoutCase('system controls on the right', 68, 102, 0, 110, false),
      _LayoutCase('system controls on the left', 102, 68, 110, 0, false),
      _LayoutCase('partially presented sidebar', 102, 102, 42, 110, false),
      _LayoutCase('RTL', 68, 154, 93, 0, true),
    ]) {
      testWidgets(testCase.label, (tester) async {
        await _pumpLayout(tester, testCase);

        final header = tester.getRect(find.byKey(_headerKey));
        final title = tester.getRect(find.byKey(_titleKey));
        final leading = tester.getRect(find.byKey(_leadingKey));
        final trailing = tester.getRect(find.byKey(_trailingKey));
        expect(title.center.dx, closeTo(header.center.dx, .001));
        expect(title.overlaps(leading), isFalse);
        expect(title.overlaps(trailing), isFalse);

        final physicalLeft = testCase.rtl ? trailing : leading;
        final physicalRight = testCase.rtl ? leading : trailing;
        expect(
          physicalLeft.left,
          greaterThanOrEqualTo(
            testCase.leftObstruction + BusyMaxSpacing.headerInset,
          ),
        );
        expect(
          physicalRight.right,
          lessThanOrEqualTo(
            header.width -
                testCase.rightObstruction -
                BusyMaxSpacing.headerInset,
          ),
        );
      });
    }
  });

  testWidgets('title and brand use GTK body role with distinct emphasis', (
    tester,
  ) async {
    const bodyStyle = TextStyle(
      color: Color(0xFF284664),
      fontFamily: 'GTK body',
      fontSize: 14.25,
    );
    await tester.pumpWidget(
      _testApp(
        windowActive: true,
        theme: ThemeData(
          textTheme: const TextTheme(
            bodyMedium: bodyStyle,
            titleMedium: TextStyle(fontSize: 30, fontFamily: 'Wrong role'),
          ),
        ),
        child: const Row(
          children: [
            BusyMaxLinuxHeaderTitle('June 2026'),
            BusyMaxLinuxHeaderTitle('BusyMax', brand: true),
          ],
        ),
      ),
    );

    final title = tester.widget<Text>(find.text('June 2026'));
    final brand = tester.widget<Text>(find.text('BusyMax'));
    expect(title.style?.fontSize, bodyStyle.fontSize);
    expect(title.style?.fontFamily, bodyStyle.fontFamily);
    expect(title.style?.color, bodyStyle.color);
    expect(title.style?.fontWeight, FontWeight.bold);
    expect(brand.style?.fontSize, bodyStyle.fontSize);
    expect(brand.style?.fontFamily, bodyStyle.fontFamily);
    expect(brand.style?.color, bodyStyle.color);
    expect(brand.style?.fontWeight, FontWeight.w800);
  });

  testWidgets('active and inactive foreground metrics match native chrome', (
    tester,
  ) async {
    const bodyColor = Color(0xFF204060);
    Future<(Color?, Color?, Color?, Color?)> pump(bool active) async {
      await tester.pumpWidget(
        _testApp(
          windowActive: active,
          theme: ThemeData(
            textTheme: const TextTheme(bodyMedium: TextStyle(color: bodyColor)),
          ),
          child: const Column(
            children: [
              BusyMaxLinuxHeaderTitle('Title', key: ValueKey('title')),
              BusyMaxLinuxHeaderTitle(
                'Brand',
                key: ValueKey('brand'),
                brand: true,
              ),
              BusyMaxLinuxHeaderIconButton(
                key: ValueKey('enabled'),
                icon: BusyMaxLinuxHeaderIcon.search,
                tooltip: 'Enabled',
                onPressed: _noop,
              ),
              BusyMaxLinuxHeaderIconButton(
                key: ValueKey('disabled'),
                icon: BusyMaxLinuxHeaderIcon.create,
                tooltip: 'Disabled',
                onPressed: null,
              ),
            ],
          ),
        ),
      );
      final enabled = _iconButton(tester, const ValueKey('enabled'));
      final disabled = _iconButton(tester, const ValueKey('disabled'));
      return (
        tester.widget<Text>(find.text('Title')).style?.color,
        tester.widget<Text>(find.text('Brand')).style?.color,
        enabled.style?.foregroundColor?.resolve(const {}),
        disabled.style?.foregroundColor?.resolve(const {WidgetState.disabled}),
      );
    }

    final active = await pump(true);
    expect(active.$1, bodyColor);
    expect(active.$2, bodyColor);
    expect(active.$3?.a, 1);
    expect(active.$4?.a, .38);

    final inactive = await pump(false);
    expect(inactive.$1?.a, .50);
    expect(inactive.$2?.a, .50);
    expect(inactive.$3?.a, .50);
    expect(inactive.$4?.a, .19);
  });

  testWidgets('application control states use neutral current-color layers', (
    tester,
  ) async {
    late BuildContext testContext;
    await tester.pumpWidget(
      _testApp(
        windowActive: true,
        theme: ThemeData(colorSchemeSeed: const Color(0xFFFF00FF)),
        child: YaruTheme(
          data: const YaruThemeData(focusBorders: true),
          child: Builder(
            builder: (context) {
              testContext = context;
              return const BusyMaxLinuxHeaderIconButton(
                icon: BusyMaxLinuxHeaderIcon.mainMenu,
                tooltip: 'Menu',
                selected: true,
                onPressed: _noop,
              );
            },
          ),
        ),
      ),
    );

    final foreground = busyMaxLinuxHeaderForeground(testContext);
    final background = busyMaxLinuxHeaderControlBackground(testContext);
    Color? resolve(Set<WidgetState> states) => background.resolve(states);
    expect(resolve(const {}), Colors.transparent);
    expect(resolve(const {WidgetState.focused}), Colors.transparent);
    expect(resolve(const {WidgetState.disabled}), Colors.transparent);
    expect(
      resolve(const {WidgetState.hovered}),
      foreground.withValues(alpha: foreground.a * .07),
    );
    expect(
      resolve(const {WidgetState.pressed}),
      foreground.withValues(alpha: foreground.a * .16),
    );
    expect(
      resolve(const {WidgetState.selected}),
      foreground.withValues(alpha: foreground.a * .10),
    );
    expect(
      resolve(const {WidgetState.selected, WidgetState.hovered}),
      foreground.withValues(alpha: foreground.a * .13),
    );
    expect(
      resolve(const {WidgetState.selected, WidgetState.pressed}),
      foreground.withValues(alpha: foreground.a * .19),
    );

    final button = tester.widget<IconButton>(find.byType(IconButton));
    expect(button.style?.splashFactory, NoSplash.splashFactory);
    expect(
      button.style?.overlayColor?.resolve(const {WidgetState.pressed}),
      Colors.transparent,
    );
    expect(
      button.style?.foregroundColor?.resolve(const {WidgetState.selected}),
      isNot(Theme.of(testContext).colorScheme.primary),
    );
    final focusBorder = tester.widget<YaruFocusBorder>(
      find.byType(YaruFocusBorder),
    );
    expect(
      focusBorder.borderRadius,
      BorderRadius.circular(BusyMaxLinuxHeaderStyle.controlRadius),
    );
  });

  testWidgets('header Search owns GTK geometry, colors, and artwork', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final controller = TextEditingController(text: 'planning');
    addTearDown(controller.dispose);
    final png = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScL1WQAAAABJRU5ErkJggg==',
    );
    final service = GtkHeaderIconService.testing(
      initialCatalog: GtkHeaderIconCatalog({
        'search.ltr': GtkHeaderIconAsset(
          bytes: png,
          resolvedName: 'system-search-symbolic',
          scale: 1,
          pixelWidth: 16,
          pixelHeight: 16,
        ),
        'searchClear.ltr': GtkHeaderIconAsset(
          bytes: png,
          resolvedName: 'edit-clear-symbolic',
          scale: 1,
          pixelWidth: 16,
          pixelHeight: 16,
        ),
      }, revision: 1),
    );
    addTearDown(service.dispose);

    await tester.pumpWidget(
      GtkHeaderIconScope(
        service: service,
        child: _testApp(
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: _searchFocus,
              primary: _searchFocus,
            ),
            textTheme: const TextTheme(
              bodyMedium: TextStyle(fontFamily: 'GTK body', fontSize: 14.25),
            ),
            extensions: const [_searchColors],
          ),
          child: Align(
            child: SizedBox(
              width: 1000,
              child: Align(
                child: BusyMaxLinuxHeaderSearchField(
                  controller: controller,
                  focusRequest: 0,
                  semanticLabel: 'Search',
                  onChanged: (_) {},
                  onClear: controller.clear,
                  autofocus: false,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final field = find.byType(BusyMaxLinuxHeaderSearchField);
    expect(
      tester.getSize(field).height,
      BusyMaxLinuxHeaderStyle.searchEntryHeight,
    );
    expect(tester.getSize(field).width, lessThan(800));
    final textField = tester.widget<TextField>(
      find.descendant(of: field, matching: find.byType(TextField)),
    );
    expect(textField.decoration?.hintText, isNull);
    expect(textField.decoration?.filled, isFalse);
    expect(textField.decoration?.border, InputBorder.none);
    expect(textField.style?.fontFamily, 'GTK body');
    expect(textField.style?.fontSize, 14.25);
    expect(textField.style?.fontWeight, FontWeight.normal);
    expect(textField.style?.color, _searchColors.foreground);
    expect(textField.cursorColor, _searchFocus);
    expect(textField.cursorWidth, 1);

    final normalDecoration = _searchShellDecoration(tester);
    expect(normalDecoration.color, _searchColors.view);
    expect(
      normalDecoration.borderRadius,
      BorderRadius.circular(BusyMaxLinuxHeaderStyle.searchEntryRadius),
    );
    final normalBorderDecoration = _searchShellBorderDecoration(tester);
    expect(_border(normalBorderDecoration).top.color, _searchColors.border);
    expect(
      _border(normalBorderDecoration).top.width,
      BusyMaxLinuxHeaderStyle.searchEntryBorderWidth,
    );
    final icons = tester
        .widgetList<BusyMaxGtkHeaderIcon>(
          find.descendant(
            of: field,
            matching: find.byType(BusyMaxGtkHeaderIcon),
          ),
        )
        .toList();
    expect(
      icons.map((icon) => icon.icon),
      containsAll(const [
        BusyMaxLinuxHeaderIcon.search,
        BusyMaxLinuxHeaderIcon.searchClear,
      ]),
    );
    for (final icon in icons) {
      expect(
        tester.getSize(find.byWidget(icon)),
        const Size.square(BusyMaxLinuxHeaderStyle.symbolicIconSize),
      );
    }
    expect(
      find.descendant(of: field, matching: find.byType(Image)),
      findsNWidgets(2),
    );
    expect(
      find.descendant(of: field, matching: find.byType(Icon)),
      findsNothing,
    );
    expect(
      find.descendant(
        of: field,
        matching: find.byType(BusyMaxHeaderIconButton),
      ),
      findsNothing,
    );
    expect(
      find.descendant(of: field, matching: find.byType(IconButton)),
      findsNothing,
    );

    final searchIcon = find.byWidgetPredicate(
      (widget) =>
          widget is BusyMaxGtkHeaderIcon &&
          widget.icon == BusyMaxLinuxHeaderIcon.search,
    );
    final clearIcon = find.byWidgetPredicate(
      (widget) =>
          widget is BusyMaxGtkHeaderIcon &&
          widget.icon == BusyMaxLinuxHeaderIcon.searchClear,
    );
    final fieldRect = tester.getRect(field);
    final searchIconRect = tester.getRect(searchIcon);
    final textRect = tester.getRect(find.byType(TextField));
    final clearIconRect = tester.getRect(clearIcon);
    expect(
      searchIconRect.left - fieldRect.left,
      BusyMaxLinuxHeaderStyle.searchEntryHorizontalPadding,
    );
    expect(
      textRect.left - searchIconRect.right,
      BusyMaxLinuxHeaderStyle.searchEntryIconGap,
    );
    expect(
      clearIconRect.left - textRect.right,
      BusyMaxLinuxHeaderStyle.searchEntryIconGap,
    );
    expect(
      fieldRect.right - clearIconRect.right,
      BusyMaxLinuxHeaderStyle.searchEntryHorizontalPadding,
    );
    expect(_iconColor(tester, searchIcon), _searchColors.mutedForeground);
    expect(_iconColor(tester, clearIcon), _searchColors.mutedForeground);
    final clearTarget = find.byKey(BusyMaxLinuxHeaderSearchField.clearKey);
    final clearSemantics = tester.getSemantics(clearTarget).getSemanticsData();
    expect(
      clearSemantics.label,
      MaterialLocalizations.of(tester.element(clearTarget)).clearButtonTooltip,
    );
    expect(clearSemantics.flagsCollection.isButton, isTrue);
    expect(clearSemantics.hasAction(SemanticsAction.tap), isTrue);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(clearIcon));
    await tester.pump();
    expect(_iconColor(tester, clearIcon), _searchColors.foreground);
    await mouse.down(tester.getCenter(clearIcon));
    await tester.pump();
    expect(_iconColor(tester, clearIcon), _searchFocus);
    await mouse.up();
    await tester.pump();

    expect(controller.text, isEmpty);
    expect(find.byType(BusyMaxLinuxHeaderSearchField), findsOneWidget);
    expect(clearIcon, findsNothing);
    expect(find.text('Search'), findsNothing);
    expect(find.bySemanticsLabel('Search'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets(
    'header Search focus chrome and high contrast radius are native',
    (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      final theme = ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _searchFocus,
          primary: _searchFocus,
        ),
        extensions: const [_searchColors],
      );
      await tester.pumpWidget(
        _testApp(
          theme: theme,
          child: BusyMaxLinuxHeaderSearchField(
            controller: controller,
            focusRequest: 0,
            semanticLabel: 'Search',
            onChanged: (_) {},
            onClear: controller.clear,
            autofocus: false,
          ),
        ),
      );

      await tester.tap(find.byType(TextField));
      await tester.pump();
      final focusedDecoration = _searchShellBorderDecoration(tester);
      expect(_border(focusedDecoration).top.color, _searchFocus);
      expect(
        _border(focusedDecoration).top.width,
        BusyMaxLinuxHeaderStyle.searchEntryFocusedBorderWidth,
      );
      expect(
        tester
            .widget<AnimatedContainer>(
              find.byKey(BusyMaxLinuxHeaderSearchField.shellKey),
            )
            .duration,
        BusyMaxLinuxHeaderStyle.searchEntryFocusDuration,
      );

      await tester.pumpWidget(
        _testApp(
          theme: theme,
          child: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: BusyMaxLinuxHeaderSearchField(
              controller: controller,
              focusRequest: 0,
              semanticLabel: 'Search',
              onChanged: (_) {},
              onClear: controller.clear,
              autofocus: false,
            ),
          ),
        ),
      );
      await tester.tap(find.byType(TextField));
      await tester.pump();
      expect(
        tester
            .widget<AnimatedContainer>(
              find.byKey(BusyMaxLinuxHeaderSearchField.shellKey),
            )
            .duration,
        Duration.zero,
      );

      final highContrastTheme = buildBusyMaxTheme(
        brightness: Brightness.light,
        accentColor: _searchFocus,
        highContrast: true,
      );
      await tester.pumpWidget(
        _testApp(
          child: Theme(
            data: highContrastTheme,
            child: BusyMaxLinuxHeaderSearchField(
              controller: controller,
              focusRequest: 0,
              semanticLabel: 'Search',
              onChanged: (_) {},
              onClear: controller.clear,
              autofocus: false,
            ),
          ),
        ),
      );
      expect(
        _searchShellDecoration(tester).borderRadius,
        BorderRadius.circular(BusyMaxLinuxHeaderStyle.controlRadius),
      );
      final highContrastColors = highContrastTheme
          .extension<BusyMaxSurfaceColors>()!;
      expect(_searchShellDecoration(tester).color, highContrastColors.view);
      expect(
        _border(_searchShellBorderDecoration(tester)).top.color,
        highContrastColors.border,
      );
      final highContrastSearchIcon = find.byWidgetPredicate(
        (widget) =>
            widget is BusyMaxGtkHeaderIcon &&
            widget.icon == BusyMaxLinuxHeaderIcon.search,
      );
      expect(
        _iconColor(tester, highContrastSearchIcon),
        highContrastColors.mutedForeground,
      );
    },
  );

  testWidgets('header Search uses semantic view chrome in light and dark', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    for (final brightness in Brightness.values) {
      final theme = buildBusyMaxTheme(
        brightness: brightness,
        accentColor: _searchFocus,
      );
      final colors = theme.extension<BusyMaxSurfaceColors>()!;
      await tester.pumpWidget(
        _testApp(
          child: Theme(
            data: theme,
            child: BusyMaxLinuxHeaderSearchField(
              controller: controller,
              focusRequest: 0,
              semanticLabel: 'Search',
              onChanged: (_) {},
              onClear: controller.clear,
              autofocus: false,
            ),
          ),
        ),
      );

      expect(_searchShellDecoration(tester).color, colors.view);
      expect(
        _border(_searchShellBorderDecoration(tester)).top.color,
        colors.border,
      );
      expect(
        tester.widget<TextField>(find.byType(TextField)).style?.color,
        colors.foreground,
      );
      final searchIcon = find.byWidgetPredicate(
        (widget) =>
            widget is BusyMaxGtkHeaderIcon &&
            widget.icon == BusyMaxLinuxHeaderIcon.search,
      );
      expect(_iconColor(tester, searchIcon), colors.mutedForeground);
      expect(_searchShellDecoration(tester).color, isNot(colors.headerbar));
    }
  });

  testWidgets('header Search focus requests select all without rebuild churn', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'planning review');
    addTearDown(controller.dispose);

    Widget app(int focusRequest, Color surface) => _testApp(
      theme: ThemeData(scaffoldBackgroundColor: surface),
      child: BusyMaxLinuxHeaderSearchField(
        controller: controller,
        focusRequest: focusRequest,
        semanticLabel: 'Search',
        onChanged: (_) {},
        onClear: controller.clear,
      ),
    );

    await tester.pumpWidget(app(0, Colors.white));
    await tester.pump();
    var editable = tester.widget<EditableText>(find.byType(EditableText));
    final focusNode = editable.focusNode;
    expect(focusNode.hasFocus, isTrue);
    expect(
      controller.selection,
      const TextSelection(baseOffset: 0, extentOffset: 15),
    );

    controller.selection = const TextSelection(baseOffset: 2, extentOffset: 8);
    await tester.pumpWidget(app(0, Colors.grey));
    await tester.pump();
    editable = tester.widget<EditableText>(find.byType(EditableText));
    expect(editable.focusNode, same(focusNode));
    expect(
      controller.selection,
      const TextSelection(baseOffset: 2, extentOffset: 8),
    );

    await tester.pumpWidget(app(1, Colors.grey));
    await tester.pump();
    expect(
      controller.selection,
      const TextSelection(baseOffset: 0, extentOffset: 15),
    );
  });
}

const _searchFocus = Color(0xFF2468AC);
const _searchColors = BusyMaxSurfaceColors(
  window: Color(0xFFF0F0F0),
  view: Color(0xFFFAFBFC),
  sidebar: Color(0xFFE0E0E0),
  secondarySidebar: Color(0xFFE8E8E8),
  headerbar: Color(0xFFF0F0F0),
  headerbarFlat: Color(0xFFF0F0F0),
  card: Color(0xFFFFFFFF),
  groupedSurface: Color(0xFFFFFFFF),
  dialog: Color(0xFFFFFFFF),
  popover: Color(0xFFFFFFFF),
  control: Color(0xFFD0D0D0),
  controlHover: Color(0xFFC0C0C0),
  controlActive: Color(0xFFB0B0B0),
  activeToggle: Color(0xFFFFFFFF),
  foreground: Color(0xFF182838),
  mutedForeground: Color(0xFF607080),
  disabledForeground: Color(0xFF909090),
  disabledControl: Color(0xFFE0E0E0),
  border: Color(0xFF8192A3),
  divider: Color(0xFFC0C0C0),
  cardShade: Color(0xFFD0D0D0),
  dialogOutline: Color(0xFFC0C0C0),
  floatingBorder: Color(0xFFB0B0B0),
  sidebarBorder: Color(0xFFA0A0A0),
  shade: Color(0x22000000),
);

BoxDecoration _searchShellDecoration(WidgetTester tester) =>
    tester
            .widget<AnimatedContainer>(
              find.byKey(BusyMaxLinuxHeaderSearchField.shellKey),
            )
            .decoration!
        as BoxDecoration;

BoxDecoration _searchShellBorderDecoration(WidgetTester tester) =>
    tester
            .widget<AnimatedContainer>(
              find.byKey(BusyMaxLinuxHeaderSearchField.shellKey),
            )
            .foregroundDecoration!
        as BoxDecoration;

Border _border(BoxDecoration decoration) => decoration.border! as Border;

Color? _iconColor(WidgetTester tester, Finder icon) =>
    IconTheme.of(tester.element(icon)).color;

const _headerKey = ValueKey('header');
const _titleKey = ValueKey('title');
const _leadingKey = ValueKey('leading');
const _trailingKey = ValueKey('trailing');

void _noop() {}

IconButton _iconButton(WidgetTester tester, Key key) {
  return tester.widget<IconButton>(
    find.descendant(of: find.byKey(key), matching: find.byType(IconButton)),
  );
}

Future<void> _pumpLayout(WidgetTester tester, _LayoutCase testCase) async {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = const Size(1000, 200);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    _testApp(
      direction: testCase.rtl ? TextDirection.rtl : TextDirection.ltr,
      child: LinuxPageHeaderInsetsScope(
        leftObstruction: testCase.leftObstruction,
        rightObstruction: testCase.rightObstruction,
        child: SizedBox(
          key: _headerKey,
          width: 1000,
          child: BusyMaxLinuxHeaderLayout(
            leading: SizedBox(
              key: _leadingKey,
              width: testCase.leadingWidth,
              height: BusyMaxSizes.headerIconButton,
            ),
            title: const BusyMaxLinuxHeaderTitle(
              'Centered title',
              key: _titleKey,
            ),
            trailing: SizedBox(
              key: _trailingKey,
              width: testCase.trailingWidth,
              height: BusyMaxSizes.headerIconButton,
            ),
          ),
        ),
      ),
    ),
  );
}

Widget _testApp({
  required Widget child,
  bool windowActive = true,
  TextDirection direction = TextDirection.ltr,
  ThemeData? theme,
}) {
  return MaterialApp(
    theme: theme,
    home: LinuxWindowMetricsScope(
      leftControlInset: 0,
      rightControlInset: 0,
      windowActive: windowActive,
      preferences: GtkWindowPreferences.defaults(),
      child: Directionality(
        textDirection: direction,
        child: Scaffold(body: child),
      ),
    ),
  );
}

class _LayoutCase {
  const _LayoutCase(
    this.label,
    this.leadingWidth,
    this.trailingWidth,
    this.leftObstruction,
    this.rightObstruction,
    this.rtl,
  );

  final String label;
  final double leadingWidth;
  final double trailingWidth;
  final double leftObstruction;
  final double rightObstruction;
  final bool rtl;
}
