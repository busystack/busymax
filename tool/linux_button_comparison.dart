import 'dart:io';
import 'dart:ui' as ui;

import 'package:busymax/src/app/app_theme.dart';
import 'package:busymax/src/app/busymax_design.dart';
import 'package:busymax/src/app/busymax_surface_colors.dart';
import 'package:busymax/src/platform/linux_window_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

const _referenceAccent = Color(0xFFC061CB);
const _screenshotPath = String.fromEnvironment('BUSYMAX_BUTTON_SCREENSHOT');
final _comparisonBoundaryKey = GlobalKey();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FocusManager.instance.highlightStrategy =
      FocusHighlightStrategy.alwaysTraditional;
  runApp(const LinuxButtonComparisonFixture());
  await WidgetsBinding.instance.endOfFrame;
  await const LinuxWindowService().showWindow();
  if (_screenshotPath.isNotEmpty) {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    final boundary =
        _comparisonBoundaryKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
    if (boundary == null) {
      throw StateError('Button comparison boundary is not mounted.');
    }
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) {
      throw StateError('Could not encode the button comparison image.');
    }
    await File(_screenshotPath).writeAsBytes(bytes.buffer.asUint8List());
  }
}

/// Development-only visual fixture for comparing production BusyMax buttons
/// with native Ubuntu controls. No button style is defined in this fixture.
class LinuxButtonComparisonFixture extends StatefulWidget {
  const LinuxButtonComparisonFixture({super.key});

  @override
  State<LinuxButtonComparisonFixture> createState() =>
      _LinuxButtonComparisonFixtureState();
}

class _LinuxButtonComparisonFixtureState
    extends State<LinuxButtonComparisonFixture> {
  var _brightness = Brightness.dark;
  var _highContrast = false;

  @override
  Widget build(BuildContext context) {
    final theme = buildBusyMaxTheme(
      brightness: _brightness,
      accentColor: _referenceAccent,
      gtkFontFamily: 'Ubuntu Sans',
      gtkFontSize: 11,
      highContrast: _highContrast,
    );
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme,
      home: RepaintBoundary(
        key: _comparisonBoundaryKey,
        child: Scaffold(
          body: Builder(
            builder: (context) {
              final colors = BusyMaxSurfaceColors.of(context);
              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'BusyMax Ubuntu button comparison',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      const Text('High contrast'),
                      Switch(
                        value: _highContrast,
                        onChanged: (value) =>
                            setState(() => _highContrast = value),
                      ),
                      const SizedBox(width: 12),
                      const Text('Dark'),
                      Switch(
                        value: _brightness == Brightness.dark,
                        onChanged: (value) => setState(
                          () => _brightness = value
                              ? Brightness.dark
                              : Brightness.light,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Material(
                    color: colors.window,
                    child: const Padding(
                      padding: EdgeInsets.all(20),
                      child: _ButtonStateTable(surfaceLabel: 'Window surface'),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Material(
                    color: colors.dialog,
                    shape: Theme.of(context).dialogTheme.shape,
                    child: const Padding(
                      padding: EdgeInsets.all(20),
                      child: _ButtonStateTable(surfaceLabel: 'Dialog surface'),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Material(
                    color: colors.popover,
                    child: const Padding(
                      padding: EdgeInsets.all(20),
                      child: _ButtonStateTable(surfaceLabel: 'Popover surface'),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Material(
                    child: BusyMaxEditorHeader(
                      title: 'Editor header',
                      cancelLabel: 'Cancel',
                      saveLabel: 'Save',
                      onCancel: _noop,
                      onSave: _noop,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

void _noop() {}

enum _FixtureButtonRole { standard, suggested, destructive }

class _ButtonStateTable extends StatelessWidget {
  const _ButtonStateTable({required this.surfaceLabel});

  final String surfaceLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(surfaceLabel, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        const Row(
          children: [
            SizedBox(width: 96),
            Expanded(child: Center(child: Text('Standard'))),
            Expanded(child: Center(child: Text('Suggested'))),
            Expanded(child: Center(child: Text('Destructive'))),
          ],
        ),
        for (final state in const [
          (<WidgetState>{}, 'Resting'),
          (<WidgetState>{WidgetState.hovered}, 'Hovered'),
          (<WidgetState>{WidgetState.pressed}, 'Pressed'),
          (<WidgetState>{WidgetState.focused}, 'Focused'),
          (<WidgetState>{WidgetState.disabled}, 'Disabled'),
        ])
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              children: [
                SizedBox(width: 96, child: Text(state.$2)),
                for (final role in _FixtureButtonRole.values)
                  Expanded(
                    child: Center(
                      child: _FixtureButton(role: role, states: state.$1),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _FixtureButton extends StatefulWidget {
  const _FixtureButton({required this.role, required this.states});

  final _FixtureButtonRole role;
  final Set<WidgetState> states;

  @override
  State<_FixtureButton> createState() => _FixtureButtonState();
}

class _FixtureButtonState extends State<_FixtureButton> {
  late final WidgetStatesController _statesController;

  @override
  void initState() {
    super.initState();
    _statesController = WidgetStatesController({...widget.states});
  }

  @override
  void didUpdateWidget(covariant _FixtureButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    _statesController.value = {...widget.states};
  }

  @override
  void dispose() {
    _statesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = !widget.states.contains(WidgetState.disabled);
    const child = Text('Action');
    return switch (widget.role) {
      _FixtureButtonRole.standard => BusyMaxPushButton.standard(
        onPressed: enabled ? _noop : null,
        statesController: _statesController,
        child: child,
      ),
      _FixtureButtonRole.suggested => BusyMaxPushButton.suggested(
        onPressed: enabled ? _noop : null,
        statesController: _statesController,
        child: child,
      ),
      _FixtureButtonRole.destructive => BusyMaxPushButton.destructive(
        context: context,
        onPressed: enabled ? _noop : null,
        statesController: _statesController,
        child: child,
      ),
    };
  }
}
