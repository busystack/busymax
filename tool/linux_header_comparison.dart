import 'dart:io';
import 'dart:ui' as ui;

import 'package:busymax/l10n/generated/app_localizations.dart';
import 'package:busymax/src/app/app_theme.dart';
import 'package:busymax/src/app/busymax_design.dart';
import 'package:busymax/src/app/busymax_surface_colors.dart';
import 'package:busymax/src/app/linux/linux_header_style.dart';
import 'package:busymax/src/app/linux/linux_page_frame.dart';
import 'package:busymax/src/app/linux/linux_window_host.dart';
import 'package:busymax/src/features/schedule/presentation/schedule_toolbar.dart';
import 'package:busymax/src/platform/gtk_window_preferences_service.dart';
import 'package:busymax/src/platform/linux_window_service.dart';
import 'package:busymax/src/schedule/schedule_range.dart';
import 'package:busymax/src/schedule/schedule_view_mode.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:ubuntu_localizations/ubuntu_localizations.dart';
import 'package:yaru/yaru.dart';

const _referenceAccent = Color(0xFFE95464);
const _systemControlsWidth = 120.0;
const _screenshotPath = String.fromEnvironment('BUSYMAX_HEADER_SCREENSHOT');
final _comparisonBoundaryKey = GlobalKey();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FocusManager.instance.highlightStrategy =
      FocusHighlightStrategy.alwaysTraditional;
  runApp(const LinuxHeaderComparisonFixture());
  await WidgetsBinding.instance.endOfFrame;
  await const LinuxWindowService().showWindow();
  if (_screenshotPath.isNotEmpty) {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    final boundary =
        _comparisonBoundaryKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
    if (boundary == null) {
      throw StateError('Header comparison boundary is not mounted.');
    }
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) {
      throw StateError('Could not encode the header comparison image.');
    }
    await File(_screenshotPath).writeAsBytes(bytes.buffer.asUint8List());
  }
}

/// Focused visual fixture for the production Linux application-header pieces.
class LinuxHeaderComparisonFixture extends StatefulWidget {
  const LinuxHeaderComparisonFixture({super.key});

  @override
  State<LinuxHeaderComparisonFixture> createState() =>
      _LinuxHeaderComparisonFixtureState();
}

class _LinuxHeaderComparisonFixtureState
    extends State<LinuxHeaderComparisonFixture> {
  late final TextEditingController _searchController = TextEditingController(
    text: 'planning',
  );

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = buildBusyMaxTheme(
      brightness: Brightness.dark,
      accentColor: _referenceAccent,
      gtkFontFamily: 'Ubuntu Sans',
      gtkFontSize: 11,
    );
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme,
      locale: const Locale('en'),
      localizationsDelegates: const [
        ...AppLocalizations.localizationsDelegates,
        ...GlobalUbuntuLocalizations.delegates,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: LinuxWindowMetricsScope(
        leftControlInset: 0,
        rightControlInset: _systemControlsWidth,
        windowActive: true,
        preferences: GtkWindowPreferences.defaults(),
        child: Builder(
          builder: (context) {
            final colors = BusyMaxSurfaceColors.of(context);
            return RepaintBoundary(
              key: _comparisonBoundaryKey,
              child: Scaffold(
                backgroundColor: colors.window,
                body: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Column(
                    children: [
                      _scheduleHeader(colors),
                      const SizedBox(height: 20),
                      _settingsHeader(colors),
                      const SizedBox(height: 20),
                      _inactiveHeader(colors),
                      const SizedBox(height: 20),
                      _searchHeader(colors),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _scheduleHeader(BusyMaxSurfaceColors colors) {
    return SizedBox(
      height: BusyMaxSizes.toolbarHeight,
      child: Stack(
        children: [
          Row(
            children: [
              SizedBox(
                width: 280,
                child: ColoredBox(
                  color: colors.sidebar,
                  child: const BusyMaxLinuxBrandHeader(),
                ),
              ),
              Expanded(
                child: ColoredBox(
                  color: colors.window,
                  child: const LinuxPageHeaderInsetsScope(
                    leftObstruction: 0,
                    rightObstruction: _systemControlsWidth,
                    child: _ReviewedScheduleHeader(),
                  ),
                ),
              ),
            ],
          ),
          const Positioned(right: 0, top: 0, child: _SystemControls()),
        ],
      ),
    );
  }

  Widget _settingsHeader(BusyMaxSurfaceColors colors) {
    return ColoredBox(
      color: colors.window,
      child: BusyMaxLinuxHeaderLayout(
        leading: const BusyMaxLinuxHeaderControlGroup(
          children: [
            BusyMaxLinuxHeaderIconButton(
              icon: Icon(YaruIcons.go_previous),
              tooltip: 'Back',
              onPressed: _noop,
            ),
          ],
        ),
        title: const BusyMaxLinuxHeaderTitle('Settings'),
        trailing: const BusyMaxLinuxHeaderControlGroup(
          children: [
            BusyMaxLinuxHeaderIconButton(
              key: ValueKey('reviewed-open-menu'),
              icon: Icon(YaruIcons.view_more),
              tooltip: 'Open menu',
              selected: true,
              onPressed: _noop,
            ),
          ],
        ),
      ),
    );
  }

  Widget _inactiveHeader(BusyMaxSurfaceColors colors) {
    return LinuxWindowMetricsScope(
      leftControlInset: 0,
      rightControlInset: 0,
      windowActive: false,
      preferences: GtkWindowPreferences.defaults(),
      child: ColoredBox(
        color: colors.window,
        child: const BusyMaxLinuxHeaderLayout(
          leading: BusyMaxLinuxHeaderControlGroup(
            children: [
              BusyMaxLinuxHeaderIconButton(
                icon: Icon(YaruIcons.sidebar),
                tooltip: 'Sidebar',
                onPressed: _noop,
              ),
              BusyMaxLinuxHeaderIconButton(
                icon: Icon(YaruIcons.calendar),
                tooltip: 'Today',
                onPressed: _noop,
              ),
            ],
          ),
          title: BusyMaxLinuxHeaderTitle('Inactive window'),
          trailing: BusyMaxLinuxHeaderControlGroup(
            children: [
              BusyMaxLinuxHeaderIconButton(
                icon: Icon(YaruIcons.plus),
                tooltip: 'Disabled create',
                onPressed: null,
              ),
              BusyMaxLinuxHeaderIconButton(
                icon: Icon(YaruIcons.search),
                tooltip: 'Search',
                onPressed: _noop,
              ),
              BusyMaxLinuxHeaderIconButton(
                icon: Icon(YaruIcons.view_more),
                tooltip: 'Menu',
                onPressed: _noop,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _searchHeader(BusyMaxSurfaceColors colors) {
    return SizedBox(
      height: BusyMaxSizes.toolbarHeight,
      child: ColoredBox(
        color: colors.window,
        child: Padding(
          padding: const EdgeInsets.all(BusyMaxSpacing.headerInset),
          child: Row(
            children: [
              Expanded(
                child: BusyMaxSearchField(
                  controller: _searchController,
                  hintText: 'Search',
                  onChanged: (_) {},
                  onClear: _searchController.clear,
                ),
              ),
              const SizedBox(width: BusyMaxSpacing.headerInset),
              const BusyMaxLinuxHeaderControlGroup(
                children: [
                  SizedBox.square(dimension: BusyMaxSizes.headerIconButton),
                  BusyMaxLinuxHeaderIconButton(
                    icon: Icon(Icons.filter_list),
                    tooltip: 'Filters',
                    onPressed: _noop,
                  ),
                  BusyMaxLinuxHeaderIconButton(
                    icon: Icon(YaruIcons.window_close),
                    tooltip: 'Close',
                    onPressed: _noop,
                  ),
                  BusyMaxLinuxHeaderIconButton(
                    icon: Icon(YaruIcons.view_more),
                    tooltip: 'Menu',
                    onPressed: _noop,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReviewedScheduleHeader extends StatelessWidget {
  const _ReviewedScheduleHeader();

  @override
  Widget build(BuildContext context) {
    return ScheduleToolbar(
      mode: ScheduleViewMode.month,
      range: ScheduleRange.month(
        DateTime(2026, 6, 1),
        firstWeekday: DateTime.monday,
      ),
      selectedDate: DateTime(2026, 6, 11),
      onToday: _noop,
      onPrevious: _noop,
      onNext: _noop,
      onModeChanged: (_) {},
      canCreateEvent: false,
      canCreateTask: false,
      onCreateEvent: _noop,
      onCreateTask: _noop,
      onRefresh: _noop,
      canShowSidebar: true,
      sidebarVisible: true,
      onToggleSidebar: _noop,
      onSearch: _noop,
      onMenuSelected: (_) {},
    );
  }
}

class _SystemControls extends StatelessWidget {
  const _SystemControls();

  @override
  Widget build(BuildContext context) {
    final foreground = BusyMaxSurfaceColors.of(context).foreground;
    return SizedBox(
      height: BusyMaxSizes.toolbarHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: BusyMaxLinuxWindowMetrics.controlHorizontalPadding,
        ),
        child: Row(
          textDirection: TextDirection.ltr,
          mainAxisSize: MainAxisSize.min,
          children: [
            YaruWindowControl(
              iconColor: WidgetStatePropertyAll(foreground),
              type: YaruWindowControlType.minimize,
              onTap: _noop,
            ),
            const SizedBox(width: BusyMaxLinuxWindowMetrics.controlSpacing),
            YaruWindowControl(
              iconColor: WidgetStatePropertyAll(foreground),
              type: YaruWindowControlType.maximize,
              onTap: _noop,
            ),
            const SizedBox(width: BusyMaxLinuxWindowMetrics.controlSpacing),
            YaruWindowControl(
              iconColor: WidgetStatePropertyAll(foreground),
              type: YaruWindowControlType.close,
              onTap: _noop,
            ),
          ],
        ),
      ),
    );
  }
}

void _noop() {}
