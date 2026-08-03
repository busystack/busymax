import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/app/busymax_design.dart';
import 'package:busymax/src/app/busymax_yaru_theme.dart';
import 'package:busymax/src/core/time/time_zone_catalog.dart';
import 'package:busymax/src/features/accounts/data/accounts_repository.dart';
import 'package:busymax/src/features/task_lists/data/task_lists_repository.dart';
import 'package:busymax/src/features/tasks/data/tasks_repository.dart';
import 'package:busymax/src/features/tasks/presentation/desktop_date_time_fields.dart';
import 'package:busymax/src/features/tasks/presentation/task_details_editor.dart';
import 'package:busymax/src/features/tasks/presentation/task_details_pane.dart';
import 'package:busymax/src/platform/native_dialog_service.dart';
import 'package:busymax/src/platform/native_menu_service.dart';
import 'package:busymax/src/task_providers/task_provider.dart';
import 'package:yaru/yaru.dart';

import '../../../test_localized_app.dart';

const _nativePickerChannel = MethodChannel(nativeDateTimePickerChannelName);
const _nativeDialogChannel = MethodChannel(nativeDialogChannelName);
const _nativeMenuChannel = MethodChannel(nativeMenuChannelName);
final _vancouverTimeZoneCode = BusyMaxTimeZoneCatalog.location(
  'America/Vancouver',
).code;

String _withVancouverTimeZone(String time) {
  return '$time ($_vancouverTimeZoneCode)';
}

void main() {
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_nativeDialogChannel, (_) async => null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          _nativeMenuChannel,
          (_) async => throw MissingPluginException(),
        );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_nativePickerChannel, (_) async {
          throw MissingPluginException();
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_nativeDialogChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_nativeMenuChannel, null);
  });

  testWidgets('Task Details header shows Cancel and Save', (tester) async {
    await _pumpDetails(tester, microsoftTaskProviderCapabilities);

    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Edit Task'), findsOneWidget);
    expect(find.text('Task details'), findsNothing);
    expect(find.text('Save'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(TaskDetailsEditor),
        matching: find.byType(YaruScrollViewUndershoot),
      ),
      findsOneWidget,
    );
  });

  testWidgets('Cancel and Save use natural-width themed controls', (
    tester,
  ) async {
    await _pumpDetails(tester, microsoftTaskProviderCapabilities);

    expect(
      find.ancestor(
        of: find.text('Cancel'),
        matching: find.byType(FilledButton),
      ),
      findsOneWidget,
    );
    expect(
      find.ancestor(
        of: find.text('Save'),
        matching: find.byType(ElevatedButton),
      ),
      findsOneWidget,
    );
    final cancelButton = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('Cancel'),
        matching: find.byType(FilledButton),
      ),
    );
    final saveButton = tester.widget<ElevatedButton>(
      find.ancestor(
        of: find.text('Save'),
        matching: find.byType(ElevatedButton),
      ),
    );
    expect(cancelButton.style?.fixedSize, isNull);
    expect(cancelButton.style?.minimumSize, isNull);
    expect(saveButton.style?.fixedSize, isNull);
    expect(saveButton.style?.minimumSize, isNull);
  });

  testWidgets('task editor groups use the contextual semantic card layer', (
    tester,
  ) async {
    final theme = BusyMaxYaruTheme.build(
      brightness: Brightness.dark,
      accentColor: const Color(0xFF3584E4),
    );
    final colors = theme.extension<BusyMaxSurfaceColors>()!;

    await _pumpDetails(
      tester,
      microsoftTaskProviderCapabilities,
      theme: theme,
      modalEditorSurface: true,
    );

    final groupedMaterials = tester.widgetList<Material>(
      find.descendant(
        of: find.byType(BusyMaxGroupedSurface),
        matching: find.byWidgetPredicate(
          (widget) => widget is Material && widget.color == colors.card,
        ),
      ),
    );
    expect(groupedMaterials, isNotEmpty);
    expect(colors.groupedSurface.a, lessThan(1));
    expect(colors.card.a, 1);
    expect(
      groupedMaterials.every((material) => material.color?.a == 1),
      isTrue,
    );
    expect(
      Color.alphaBlend(colors.groupedSurface, colors.window).toARGB32(),
      colors.card.toARGB32(),
    );
  });

  testWidgets('task selectors use native combo-row triggers', (tester) async {
    final theme = BusyMaxYaruTheme.build(
      brightness: Brightness.dark,
      accentColor: const Color(0xFF3584E4),
    );
    final colors = theme.extension<BusyMaxSurfaceColors>()!;
    await _pumpDetails(
      tester,
      microsoftTaskProviderCapabilities,
      theme: theme,
      modalEditorSurface: true,
    );

    final comboRows = find.byType(BusyMaxComboRow<String>);
    final comboCount = comboRows.evaluate().length;
    expect(comboCount, greaterThanOrEqualTo(2));
    expect(
      find.descendant(
        of: comboRows,
        matching: find.byType(BusyMaxMenuButton<String>),
      ),
      findsNWidgets(comboCount),
    );
    expect(
      find.descendant(
        of: comboRows,
        matching: find.byWidgetPredicate(
          (widget) => widget is ButtonStyleButton && widget is! IconButton,
        ),
      ),
      findsNothing,
    );
    expect(
      find.descendant(of: comboRows, matching: find.byType(OutlinedButton)),
      findsNothing,
    );
    expect(
      find.descendant(
        of: comboRows,
        matching: find.byType(YaruPopupMenuButton),
      ),
      findsNothing,
    );
    final triggers = find.descendant(
      of: comboRows,
      matching: find.byWidgetPredicate(
        (widget) => widget is YaruListTile && widget.focusNode != null,
      ),
    );
    expect(triggers, findsNWidgets(comboCount));
    for (var index = 0; index < comboCount; index += 1) {
      final triggerFinder = triggers.at(index);
      final trigger = tester.widget<YaruListTile>(triggerFinder);
      expect(trigger.onTap, isNotNull);
      expect(
        trigger.hoverColor,
        busyMaxRowHoverColor(tester.element(triggerFinder)),
      );
      final restingSurface = tester.widget<Material>(
        find
            .descendant(of: triggerFinder, matching: find.byType(Material))
            .first,
      );
      expect(restingSurface.type, MaterialType.canvas);
      expect(restingSurface.color, Colors.transparent);
      expect(restingSurface.color, isNot(colors.control));
    }
  });

  test('task selector content mirrors with text direction', () {
    final source = File(
      'lib/src/features/tasks/presentation/task_details_editor.dart',
    ).readAsStringSync();

    expect(source, isNot(contains('_taskEditorSelectedValue')));
    expect(source, isNot(contains('_TaskEditorAccountIdentity')));
    expect(source, isNot(contains('alignment: Alignment.centerRight')));
    expect(source, isNot(contains('alignment: Alignment.centerLeft')));
  });

  testWidgets('editor actions keep native height without forced width', (
    tester,
  ) async {
    await _pumpDetails(
      tester,
      microsoftTaskProviderCapabilities,
      theme: BusyMaxYaruTheme.build(
        brightness: Brightness.light,
        accentColor: const Color(0xFF3584E4),
      ),
    );

    expect(
      tester.getSize(_headerButtonFinder(tester, 'Cancel')).height,
      kYaruButtonHeight,
    );
    expect(
      tester.getSize(_headerButtonFinder(tester, 'Save')).height,
      kYaruButtonHeight,
    );
  });

  testWidgets('header places Cancel before centered title and Save after', (
    tester,
  ) async {
    await _pumpDetails(tester, microsoftTaskProviderCapabilities);

    final cancelLeft = tester.getTopLeft(find.text('Cancel')).dx;
    final titleCenter = tester.getCenter(find.text('Edit Task')).dx;
    final saveLeft = tester.getTopLeft(find.text('Save')).dx;
    final paneCenter = tester.getSize(find.byType(TaskDetailsPane)).width / 2;

    expect(cancelLeft, lessThan(titleCenter));
    expect(titleCenter, closeTo(paneCenter, 24));
    expect(saveLeft, greaterThan(titleCenter));
  });

  testWidgets('Save is disabled with unchanged valid draft', (tester) async {
    final repository = _FakeTasksRepository();
    await _pumpDetails(
      tester,
      microsoftTaskProviderCapabilities,
      repository: repository,
    );

    expect(_headerButtonOnPressed(tester, 'Save'), isNull);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repository.patches, isEmpty);
  });

  testWidgets('editing title enables Save', (tester) async {
    await _pumpDetails(tester, microsoftTaskProviderCapabilities);

    await tester.enterText(find.byType(TextField).first, 'Renamed task');
    await tester.pump();

    expect(_headerButtonOnPressed(tester, 'Save'), isNotNull);
  });

  testWidgets('Cancel discards draft without patching', (tester) async {
    final repository = _FakeTasksRepository();
    await _pumpDetails(
      tester,
      microsoftTaskProviderCapabilities,
      repository: repository,
    );

    await tester.enterText(find.byType(TextField).first, 'Unsaved task');
    await tester.pump();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();

    expect(repository.patches, isEmpty);
  });

  testWidgets('Save sends patch with changed fields only', (tester) async {
    final repository = _FakeTasksRepository();
    await _pumpDetails(
      tester,
      microsoftTaskProviderCapabilities,
      repository: repository,
    );

    await tester.enterText(find.byType(TextField).first, 'Renamed task');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repository.patches, hasLength(1));
    expect(repository.patches.single.fields, {'title': 'Renamed task'});
  });

  testWidgets('Ctrl+S saves a dirty task editor', (tester) async {
    final repository = _FakeTasksRepository();
    await _pumpDetails(
      tester,
      microsoftTaskProviderCapabilities,
      repository: repository,
    );

    await tester.enterText(find.byType(TextField).first, 'Renamed task');
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();

    expect(repository.patches, hasLength(1));
    expect(repository.patches.single.fields, {'title': 'Renamed task'});
  });

  testWidgets(
    'invalid visible due time disables Save and Ctrl+S and makes Cancel confirm',
    (tester) async {
      final repository = _FakeTasksRepository();
      var closed = false;
      await _pumpDetails(
        tester,
        microsoftTaskProviderCapabilities,
        repository: repository,
        onClose: () => closed = true,
      );

      final dueTime = _labeledTextFormFieldFinder('Due time');
      await tester.enterText(dueTime, 'not a time');
      await tester.pump();

      expect(_headerButtonOnPressed(tester, 'Save'), isNull);
      expect(
        find.text(
          MaterialLocalizations.of(tester.element(dueTime)).invalidTimeLabel,
        ),
        findsOneWidget,
      );

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      expect(repository.patches, isEmpty);
      expect(closed, isFalse);

      await tester.tap(_headerButtonFinder(tester, 'Cancel'));
      await tester.pumpAndSettle();

      expect(closed, isFalse);
      expect(find.text('Discard changes?'), findsOneWidget);

      await tester.tap(_confirmDialogButton('Discard'));
      await tester.pumpAndSettle();

      expect(closed, isTrue);
      expect(repository.patches, isEmpty);
    },
  );

  testWidgets('Save closes editor after successful save', (tester) async {
    final repository = _FakeTasksRepository();
    var closed = false;
    await _pumpDetails(
      tester,
      microsoftTaskProviderCapabilities,
      repository: repository,
      onClose: () {
        closed = true;
      },
    );

    await tester.enterText(find.byType(TextField).first, 'Renamed task');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repository.patches, hasLength(1));
    expect(closed, isTrue);
  });

  testWidgets('after Save, edited title remains visible and Save is disabled', (
    tester,
  ) async {
    final repository = _FakeTasksRepository();
    await _pumpDetails(
      tester,
      microsoftTaskProviderCapabilities,
      repository: repository,
    );

    await tester.enterText(find.byType(TextField).first, 'Renamed task');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repository.patches, hasLength(1));
    expect(_firstTextFieldText(tester), 'Renamed task');
    expect(_headerButtonOnPressed(tester, 'Save'), isNull);
  });

  testWidgets('same task stream update reloads editor when draft is clean', (
    tester,
  ) async {
    final repository = _SwitchingTasksRepository();
    addTearDown(repository.dispose);
    await _pumpSwitchingDetails(tester, repository, taskId: 'task-1');
    repository.emit(_switchTask('task-1', 'Old task'));
    await tester.pumpAndSettle();

    repository.emit(_switchTask('task-1', 'Updated task'));
    await tester.pumpAndSettle();

    expect(_firstTextFieldText(tester), 'Updated task');
  });

  testWidgets('same task stream update does not overwrite unsaved draft', (
    tester,
  ) async {
    final repository = _SwitchingTasksRepository();
    addTearDown(repository.dispose);
    await _pumpSwitchingDetails(tester, repository, taskId: 'task-1');
    repository.emit(_switchTask('task-1', 'Old task'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Unsaved task');
    await tester.pump();
    repository.emit(_switchTask('task-1', 'Repository update'));
    await tester.pumpAndSettle();

    expect(_firstTextFieldText(tester), 'Unsaved task');
  });

  testWidgets('dirty task switch prompts discard and cancel keeps old draft', (
    tester,
  ) async {
    final repository = _SwitchingTasksRepository();
    addTearDown(repository.dispose);
    TaskEntity? restoredTask;
    await _pumpSwitchingDetails(
      tester,
      repository,
      taskId: 'task-1',
      onTaskSwitchCancelled: (task) => restoredTask = task,
    );
    repository.emit(_switchTask('task-1', 'Old task'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Unsaved task');
    await tester.pump();

    await _pumpSwitchingDetails(
      tester,
      repository,
      taskId: 'task-2',
      onTaskSwitchCancelled: (task) => restoredTask = task,
    );
    repository.emit(_switchTask('task-2', 'New task'));
    await tester.pumpAndSettle();

    expect(find.text('Discard changes?'), findsOneWidget);
    await tester.tap(_confirmDialogButton('Cancel'));
    await tester.pumpAndSettle();

    expect(restoredTask?.id, 'task-1');
    expect(_firstTextFieldText(tester), 'Unsaved task');
  });

  testWidgets('dirty task switch confirms discard and loads new task', (
    tester,
  ) async {
    final repository = _SwitchingTasksRepository();
    addTearDown(repository.dispose);
    await _pumpSwitchingDetails(tester, repository, taskId: 'task-1');
    repository.emit(_switchTask('task-1', 'Old task'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Unsaved task');
    await tester.pump();

    await _pumpSwitchingDetails(tester, repository, taskId: 'task-2');
    repository.emit(_switchTask('task-2', 'New task'));
    await tester.pumpAndSettle();

    expect(find.text('Discard changes?'), findsOneWidget);
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();

    expect(_firstTextFieldText(tester), 'New task');
  });

  testWidgets('invalid visible due time makes a task switch confirm discard', (
    tester,
  ) async {
    final repository = _SwitchingTasksRepository();
    addTearDown(repository.dispose);
    TaskEntity? restoredTask;
    await _pumpSwitchingDetails(
      tester,
      repository,
      taskId: 'task-1',
      onTaskSwitchCancelled: (task) => restoredTask = task,
    );
    repository.emit(_switchTimedTask('task-1', 'Old task'));
    await tester.pumpAndSettle();

    await tester.enterText(
      _labeledTextFormFieldFinder('Due time'),
      'not a time',
    );
    await tester.pump();

    await _pumpSwitchingDetails(
      tester,
      repository,
      taskId: 'task-2',
      onTaskSwitchCancelled: (task) => restoredTask = task,
    );
    repository.emit(_switchTimedTask('task-2', 'New task'));
    await tester.pumpAndSettle();

    expect(find.text('Discard changes?'), findsOneWidget);
    await tester.tap(_confirmDialogButton('Cancel'));
    await tester.pumpAndSettle();

    expect(restoredTask?.id, 'task-1');
    expect(_labeledFieldText(tester, 'Due time'), 'not a time');
  });

  testWidgets('status controls are absent from Task Details', (tester) async {
    await _pumpDetails(tester, microsoftTaskProviderCapabilities);

    expect(find.text('Open'), findsNothing);
    expect(find.text('Done'), findsNothing);
  });

  testWidgets('no visible timezone helper text or UTC appears', (tester) async {
    await _pumpDetails(tester, microsoftTaskProviderCapabilities);

    expect(find.textContaining('Time zone:'), findsNothing);
    expect(find.text('UTC'), findsNothing);
    expect(find.textContaining('2026-06-04T07:00:00.0000000'), findsNothing);
  });

  testWidgets('Task Details uses BusyMax grouped rows without section blocks', (
    tester,
  ) async {
    await _pumpDetails(tester, microsoftTaskProviderCapabilities);

    expect(find.byType(Dialog), findsNothing);
    expect(find.byType(TaskDetailsPane), findsOneWidget);
    expect(find.byType(YaruDialogTitleBar), findsNothing);
    expect(find.byType(YaruTitleBar), findsNothing);
    expect(find.byType(YaruSection), findsNothing);
    expect(find.byType(BusyMaxGroupedList), findsWidgets);
    expect(find.byType(BusyMaxActionRow), findsWidgets);
    expect(find.byType(BusyMaxCalendarValueRow), findsWidgets);
    expect(find.byType(YaruListTile), findsWidgets);
  });

  testWidgets('Task Details section labels use shared section typography', (
    tester,
  ) async {
    await _pumpDetails(tester, microsoftTaskProviderCapabilities);

    final dueText = tester.widget<Text>(find.text('Due'));
    final context = tester.element(find.text('Due'));

    expect(dueText.style, busyMaxSectionHeaderStyle(context));
  });

  test('Task Details pane does not add custom pane chrome', () {
    final source = File(
      'lib/src/features/tasks/presentation/task_details_pane.dart',
    ).readAsStringSync();

    expect(source, isNot(contains('BusyMaxSizes')));
    expect(source, isNot(contains('ConstrainedBox(')));
    expect(source, isNot(contains('Material(')));
  });

  testWidgets('missing task closes pane without placeholder flash', (
    tester,
  ) async {
    var closed = false;
    await _pumpDetails(
      tester,
      microsoftTaskProviderCapabilities,
      repository: _FakeTasksRepository(missingTask: true),
      onClose: () {
        closed = true;
      },
    );

    expect(find.byType(YaruInfoBox), findsNothing);
    expect(find.byType(TaskDetailsEditor), findsNothing);
    expect(closed, isTrue);
  });

  testWidgets('stale task data is hidden while switching selection', (
    tester,
  ) async {
    final repository = _SwitchingTasksRepository();
    addTearDown(repository.dispose);
    await _pumpSwitchingDetails(tester, repository, taskId: 'task-1');
    repository.emit(
      TaskEntity(
        accountId: 'microsoft:m',
        taskListId: 'list-1',
        id: 'task-1',
        title: 'Old task',
        localDirty: false,
        pendingDelete: false,
        pendingMove: false,
        rawJson: '{}',
        updatedLocalAtUtc: '2026-06-04T00:00:00.000Z',
        status: 'needsAction',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Old task'), findsOneWidget);

    await _pumpSwitchingDetails(tester, repository, taskId: 'task-2');
    await tester.pump();

    expect(find.text('Old task'), findsNothing);
    expect(find.byType(TaskDetailsEditor), findsNothing);
  });

  testWidgets('English 24-hour setting displays localized 24-hour time', (
    tester,
  ) async {
    await _pumpDetails(
      tester,
      microsoftTaskProviderCapabilities,
      alwaysUse24HourFormat: true,
    );

    expect(_labeledFieldText(tester, 'Due date'), 'Jun 6, 2026');
    expect(_labeledFieldText(tester, 'Start date'), 'Jun 4, 2026');
    expect(
      _labeledFieldText(tester, 'Due time'),
      _withVancouverTimeZone('14:30'),
    );
    expect(_labeledTextFormFieldFinder('Due date'), findsOneWidget);
    expect(_labeledTextFormFieldFinder('Due time'), findsOneWidget);
    expect(find.text('14:30:00'), findsNothing);
  });

  testWidgets('English 12-hour setting displays localized AM/PM time', (
    tester,
  ) async {
    await _pumpDetails(
      tester,
      microsoftTaskProviderCapabilities,
      alwaysUse24HourFormat: false,
    );

    expect(_labeledFieldText(tester, 'Start date'), 'Jun 4, 2026');
    expect(
      _labeledFieldText(tester, 'Due time'),
      _withVancouverTimeZone('2:30 PM'),
    );
    expect(_labeledTextFormFieldFinder('Start date'), findsOneWidget);
    expect(_labeledTextFormFieldFinder('Due time'), findsOneWidget);
    expect(find.text('Jun 4, 2026 · 7:00 AM'), findsNothing);
  });

  testWidgets('German locale does not display English month names', (
    tester,
  ) async {
    await _pumpDetails(
      tester,
      microsoftTaskProviderCapabilities,
      locale: const Locale('de'),
      alwaysUse24HourFormat: true,
    );

    expect(_renderedDateFieldTexts(tester), ['6. Juni 2026', '4. Juni 2026']);
    expect(find.textContaining('June'), findsNothing);
    expect(find.textContaining('Jun 4'), findsNothing);
  });

  testWidgets('French locale does not display English month names', (
    tester,
  ) async {
    await _pumpDetails(
      tester,
      microsoftTaskProviderCapabilities,
      locale: const Locale('fr'),
      alwaysUse24HourFormat: true,
    );

    expect(_renderedDateFieldTexts(tester), ['6 juin 2026', '4 juin 2026']);
    expect(find.textContaining('June'), findsNothing);
    expect(find.textContaining('Jun 4'), findsNothing);
  });

  testWidgets('Spanish locale does not display English month names', (
    tester,
  ) async {
    await _pumpDetails(
      tester,
      microsoftTaskProviderCapabilities,
      locale: const Locale('es'),
      alwaysUse24HourFormat: true,
    );

    expect(_renderedDateFieldTexts(tester), ['6 jun 2026', '4 jun 2026']);
    expect(find.textContaining('June'), findsNothing);
    expect(find.textContaining('Jun 4'), findsNothing);
  });

  testWidgets('dateTimeDisplay comes from localization resources', (
    tester,
  ) async {
    await tester.pumpWidget(
      localizedTestApp(
        locale: const Locale('fr'),
        alwaysUse24HourFormat: true,
        child: Builder(
          builder: (context) {
            return Text(
              formatDesktopDateTime(context, '2026-06-04T07:00:00.0000000'),
            );
          },
        ),
      ),
    );

    expect(find.text('4 juin 2026 à 07:00'), findsOneWidget);
    expect(find.text('4 juin 2026 · 07:00'), findsNothing);
  });

  testWidgets('Google keeps unsupported fields out of main editor by default', (
    tester,
  ) async {
    await _pumpDetails(tester, googleTaskProviderCapabilities);

    expect(find.text('Due'), findsOneWidget);
    expect(_dateRowFinder('Due date'), findsOneWidget);
    expect(find.text('All day'), findsNothing);
    expect(find.text('Time slot'), findsNothing);
    expect(_timeRowFinder('Due time'), findsNothing);
    expect(find.text('Start'), findsNothing);
    expect(_dateRowFinder('Start date'), findsNothing);
    expect(find.text('Reminder'), findsNothing);
    expect(find.text('Repeat'), findsNothing);
    expect(find.text('Organization'), findsNothing);
    expect(find.text('Provider features'), findsNothing);
    expect(
      find.text('Some fields are not supported by this provider.'),
      findsNothing,
    );
  });

  testWidgets('Google generated account id is not shown in editor', (
    tester,
  ) async {
    await _pumpDetails(
      tester,
      googleTaskProviderCapabilities,
      accountIdOverride: 'google-generated-local-id',
      includeAccountIdentity: false,
    );

    expect(find.textContaining('google-'), findsNothing);
    expect(find.text('Google Tasks'), findsWidgets);
  });

  testWidgets(
    'opaque Microsoft account id waits for and preserves stored provider',
    (tester) async {
      final accounts = StreamController<List<AccountEntity>>();
      addTearDown(accounts.close);
      const accountId = 'opaque-account-id';

      await _pumpDetails(
        tester,
        microsoftTaskProviderCapabilities,
        accountIdOverride: accountId,
        accountsStream: accounts.stream,
      );

      expect(find.byType(TaskDetailsEditor), findsNothing);

      accounts.add([
        const AccountEntity(
          id: accountId,
          provider: TaskProvider.microsoft,
          authState: 'signed_in',
          displayName: 'Microsoft User',
          email: 'microsoft@example.com',
        ),
      ]);
      await tester.pumpAndSettle();

      expect(find.text('Start'), findsOneWidget);
      expect(find.text('Reminder'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'Unsaved task');
      await tester.pump();
      accounts.add(const []);
      await tester.pumpAndSettle();

      expect(find.text('Unsaved task'), findsOneWidget);
      expect(find.text('Start'), findsOneWidget);
      expect(find.text('Reminder'), findsOneWidget);
    },
  );

  testWidgets(
    'account stream errors preserve the pane and definitive removal closes it',
    (tester) async {
      final accounts = StreamController<List<AccountEntity>>();
      addTearDown(accounts.close);
      const accountId = 'opaque-account-id';
      var closeCalls = 0;

      await _pumpDetails(
        tester,
        microsoftTaskProviderCapabilities,
        accountIdOverride: accountId,
        accountsStream: accounts.stream,
        onClose: () => closeCalls += 1,
      );

      expect(closeCalls, 0);
      accounts.add([
        const AccountEntity(
          id: accountId,
          provider: TaskProvider.microsoft,
          authState: 'signed_in',
          displayName: 'Microsoft User',
          email: 'microsoft@example.com',
        ),
      ]);
      await tester.pumpAndSettle();
      expect(find.byType(TaskDetailsEditor), findsOneWidget);

      accounts.addError(StateError('temporary account stream failure'));
      await tester.pumpAndSettle();
      expect(find.byType(TaskDetailsEditor), findsOneWidget);
      expect(closeCalls, 0);

      accounts.add(const []);
      await tester.pumpAndSettle();
      expect(closeCalls, 1);
      expect(find.byType(TaskDetailsEditor), findsNothing);
    },
  );

  testWidgets('unsupported provider text is not rendered for Google', (
    tester,
  ) async {
    await _pumpDetails(tester, googleTaskProviderCapabilities);

    expect(find.text('Provider features'), findsNothing);
    expect(find.text('Not supported by Google Tasks.'), findsNothing);
    expect(_dateRowFinder('Start date'), findsNothing);
    expect(_timeRowFinder('Start time'), findsNothing);
    expect(find.text('Add Reminder'), findsNothing);
    expect(find.text('Importance'), findsNothing);
    expect(find.text('Categories'), findsNothing);
  });

  testWidgets(
    'Microsoft shows Due, Start, Reminder, Repeat, and Organization',
    (tester) async {
      await _pumpDetails(tester, microsoftTaskProviderCapabilities);

      expect(find.text('Due'), findsOneWidget);
      expect(find.text('Start'), findsOneWidget);
      expect(find.text('Reminder'), findsOneWidget);
      expect(find.text('Repeat'), findsOneWidget);
      expect(find.text('Organization'), findsOneWidget);
      expect(find.text('Provider features'), findsNothing);
    },
  );

  testWidgets('Microsoft categories can be added and removed as tags', (
    tester,
  ) async {
    final repository = _FakeTasksRepository();
    await _pumpDetails(
      tester,
      microsoftTaskProviderCapabilities,
      repository: repository,
    );

    expect(find.widgetWithText(InputChip, 'Home'), findsOneWidget);
    expect(find.widgetWithText(ActionChip, 'Add category'), findsOneWidget);

    await tester.tap(find.text('Add category'));
    await tester.pump();
    expect(find.byType(YaruAutocomplete<String>), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('task-category-input')),
      'Work',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(find.text('Work'), findsOneWidget);

    await tester.tap(find.byTooltip('Delete Home'));
    await tester.pump();

    expect(find.text('Home'), findsNothing);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repository.patches, hasLength(1));
    expect(repository.patches.single.fields['categories'], ['Work']);
  });

  testWidgets('Microsoft category suggestions use Yaru autocomplete', (
    tester,
  ) async {
    final repository = _FakeTasksRepository(
      categorySuggestions: const ['Home', 'Work', 'Workshop'],
    );
    await _pumpDetails(
      tester,
      microsoftTaskProviderCapabilities,
      repository: repository,
    );

    await tester.tap(find.text('Add category'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('task-category-input')), 'wo');
    await tester.pumpAndSettle();
    final input = find.byKey(const Key('task-category-input'));
    final field = tester.widget<TextField>(input);
    expect(find.byType(YaruAutocomplete<String>), findsOneWidget);
    expect(field.decoration?.border, isNull);
    expect(field.decoration?.focusedBorder, isNull);
    expect(
      tester.getTopLeft(find.text('Work').last).dy,
      greaterThanOrEqualTo(tester.getBottomLeft(input).dy - 1),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repository.patches.single.fields['categories'], [
      'Home',
      'Workshop',
    ]);
  });

  testWidgets('Due group appears before separate Start group', (tester) async {
    await _pumpDetails(tester, microsoftTaskProviderCapabilities);

    final dueTop = tester.getTopLeft(find.text('Due')).dy;
    final startTop = tester.getTopLeft(find.text('Start')).dy;
    final dueDateTop = tester.getTopLeft(_dateRowFinder('Due date')).dy;
    final startDateTop = tester.getTopLeft(_dateRowFinder('Start date')).dy;

    expect(dueTop, lessThan(dueDateTop));
    expect(dueDateTop, lessThan(startTop));
    expect(startTop, lessThan(startDateTop));
  });

  testWidgets('Reminder absent state shows centered Add Reminder', (
    tester,
  ) async {
    await _pumpDetails(tester, microsoftTaskProviderCapabilities);

    expect(find.text('Add Reminder'), findsOneWidget);
    expect(
      find.ancestor(
        of: find.text('Add Reminder'),
        matching: find.byType(Center),
      ),
      findsOneWidget,
    );
    expect(find.byType(YaruSwitch), findsNothing);
  });

  testWidgets('reminder uses date and time rows when enabled', (tester) async {
    await _pumpDetails(
      tester,
      microsoftTaskProviderCapabilities,
      reminderOn: true,
      alwaysUse24HourFormat: true,
    );

    expect(_dateRowFinder('Reminder date'), findsOneWidget);
    expect(_timeRowFinder('Reminder time'), findsOneWidget);
    expect(_labeledFieldText(tester, 'Reminder date'), 'Jun 5, 2026');
    expect(
      _labeledFieldText(tester, 'Reminder time'),
      _withVancouverTimeZone('09:15'),
    );
    expect(_labeledTextFormFieldFinder('Reminder date'), findsOneWidget);
    expect(_labeledTextFormFieldFinder('Reminder time'), findsOneWidget);
    expect(find.textContaining('Time zone:'), findsNothing);
    expect(find.text('UTC'), findsNothing);
  });

  testWidgets('delete action is separated and destructive', (tester) async {
    await _pumpDetails(tester, microsoftTaskProviderCapabilities);

    await tester.scrollUntilVisible(
      find.text('Delete Task'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    final deleteRow = tester.widget<BusyMaxActionRow>(
      find
          .ancestor(
            of: find.text('Delete Task'),
            matching: find.byType(BusyMaxActionRow),
          )
          .first,
    );
    expect(deleteRow.onTap, isNotNull);
  });

  testWidgets('Delete prompts and deletes the current task', (tester) async {
    final repository = _FakeTasksRepository();
    await _pumpDetails(
      tester,
      microsoftTaskProviderCapabilities,
      repository: repository,
    );

    _focusEditorShortcuts(tester);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pumpAndSettle();

    expect(find.byType(BusyMaxConfirmDialog), findsOneWidget);
    await tester.tap(_confirmDialogButton('Delete'));
    await tester.pumpAndSettle();

    expect(repository.deleteCalls, 1);
  });

  testWidgets('Backspace in a task text field does not prompt delete', (
    tester,
  ) async {
    final repository = _FakeTasksRepository();
    await _pumpDetails(
      tester,
      microsoftTaskProviderCapabilities,
      repository: repository,
    );

    await tester.tap(find.byType(TextField).first);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pumpAndSettle();

    expect(find.byType(BusyMaxConfirmDialog), findsNothing);
    expect(repository.deleteCalls, 0);
  });

  testWidgets('metadata is not shown in Edit Task', (tester) async {
    await _pumpDetails(tester, microsoftTaskProviderCapabilities);

    expect(find.text('Metadata'), findsNothing);
    expect(find.text('task-1'), findsNothing);
    expect(find.text('etag'), findsNothing);
  });

  testWidgets('list move unsupported explanation is not rendered', (
    tester,
  ) async {
    await _pumpDetails(tester, microsoftTaskProviderCapabilities);

    expect(
      find.text(
        'Moving between lists is not supported for Microsoft To Do accounts in this version.',
      ),
      findsNothing,
    );

    final listRow = find
        .ancestor(
          of: find.text('List'),
          matching: find.byType(BusyMaxActionRow),
        )
        .first;
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer();
    addTearDown(gesture.removePointer);
    await gesture.moveTo(tester.getCenter(listRow));
    await tester.pump(const Duration(seconds: 1));

    expect(
      find.text(
        'Moving between lists is not supported for Microsoft To Do accounts in this version.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('due date opens in-window date picker', (tester) async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_nativePickerChannel, (call) async {
          calls.add(call);
          return null;
        });
    await _pumpDetails(tester, microsoftTaskProviderCapabilities);

    await _openDatePicker(tester, 'Due date');

    expect(tester.takeException(), isNull);
    expect(calls, isEmpty);
    expect(find.byType(BusyMaxContentPopoverSurface), findsOneWidget);
    expect(find.byType(CalendarDatePicker), findsNothing);
    expect(find.text('June'), findsOneWidget);
    expect(_labeledFieldText(tester, 'Due date'), 'Jun 6, 2026');
  });

  testWidgets('date value row can use in-window picker', (tester) async {
    String? changed;

    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: DesktopDateValueRow(
            label: 'Due date',
            date: '2026-06-06',
            useNativePicker: false,
            onChanged: (date) => changed = date,
          ),
        ),
      ),
    );

    await _openDatePicker(tester, 'Due date');

    expect(find.byType(BusyMaxContentPopoverSurface), findsOneWidget);
    expect(find.byType(CalendarDatePicker), findsNothing);
    expect(_labeledFieldText(tester, 'Due date'), 'Jun 6, 2026');

    await tester.tap(
      find
          .descendant(
            of: find.byType(BusyMaxContentPopoverSurface),
            matching: find.text('6'),
          )
          .first,
    );
    await tester.pumpAndSettle();

    expect(changed, '2026-06-06');
    expect(tester.takeException(), isNull);
  });

  testWidgets('in-window date picker opens empty date on today', (
    tester,
  ) async {
    String? changed;
    final now = DateTime.now();
    final today =
        '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';

    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: DesktopDateValueRow(
            label: 'Due date',
            date: null,
            useNativePicker: false,
            onChanged: (date) => changed = date,
          ),
        ),
      ),
    );

    await _openDatePicker(tester, 'Due date');
    final todayTooltip = DateFormat('EEEE, MMMM d, yyyy').format(now);
    await tester.tap(find.byTooltip(todayTooltip));
    await tester.pumpAndSettle();

    expect(changed, today);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'due time uses an inline labeled field without a picker channel',
    (tester) async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_nativePickerChannel, (call) async {
            calls.add(call);
            return null;
          });
      await _pumpDetails(
        tester,
        microsoftTaskProviderCapabilities,
        alwaysUse24HourFormat: false,
      );

      expect(_labeledTextFormFieldFinder('Due time'), findsOneWidget);
      expect(
        _labeledFieldText(tester, 'Due time'),
        _withVancouverTimeZone('2:30 PM'),
      );
      expect(find.byType(BusyMaxContentPopoverSurface), findsNothing);

      expect(tester.takeException(), isNull);
      expect(calls, isEmpty);
    },
  );

  testWidgets('Microsoft task scheduled mode can be switched to all-day', (
    tester,
  ) async {
    final repository = _FakeTasksRepository();
    await _pumpDetails(
      tester,
      microsoftTaskProviderCapabilities,
      repository: repository,
    );

    expect(find.byType(BusyMaxTimeModeRow), findsOneWidget);
    expect(find.text('All day'), findsOneWidget);
    expect(find.text('Time slot'), findsOneWidget);
    expect(_timeRowFinder('Due time'), findsOneWidget);
    expect(_timeRowFinder('Start time'), findsOneWidget);

    await tester.tap(find.text('All day'));
    await tester.pumpAndSettle();

    expect(_timeRowFinder('Due time'), findsNothing);
    expect(_timeRowFinder('Start time'), findsNothing);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repository.patches, hasLength(1));
    final fields = repository.patches.single.fields;
    expect(fields.containsKey('due'), isFalse);
    expect(fields['microsoftDueDateTime'], {
      'dateTime': '2026-06-06',
      'timeZone': 'America/Vancouver',
    });
    expect(fields['microsoftStartDateTime'], {
      'dateTime': '2026-06-04',
      'timeZone': 'UTC',
    });
  });

  testWidgets('all-day mode clears stale invalid scheduled-time state', (
    tester,
  ) async {
    final repository = _FakeTasksRepository();
    await _pumpDetails(
      tester,
      microsoftTaskProviderCapabilities,
      repository: repository,
    );

    await tester.enterText(
      _labeledTextFormFieldFinder('Due time'),
      'not a time',
    );
    await tester.pump();
    expect(_headerButtonOnPressed(tester, 'Save'), isNull);

    await tester.tap(find.text('All day'));
    await tester.pumpAndSettle();

    expect(_timeRowFinder('Due time'), findsNothing);
    expect(_timeRowFinder('Start time'), findsNothing);
    expect(_headerButtonOnPressed(tester, 'Save'), isNotNull);

    await tester.tap(_headerButtonFinder(tester, 'Save'));
    await tester.pumpAndSettle();

    expect(repository.patches, hasLength(1));
  });

  testWidgets(
    'Microsoft all-day scheduled tasks can be switched to time slot',
    (tester) async {
      final repository = _FakeTasksRepository(
        microsoftDueDateTime: '2026-06-06',
        microsoftStartDateTime: '2026-06-04',
      );
      await _pumpDetails(
        tester,
        microsoftTaskProviderCapabilities,
        repository: repository,
      );

      expect(find.byType(BusyMaxTimeModeRow), findsOneWidget);
      expect(_timeRowFinder('Due time'), findsNothing);
      expect(_timeRowFinder('Start time'), findsNothing);

      await tester.tap(find.text('Time slot'));
      await tester.pumpAndSettle();

      expect(_timeRowFinder('Due time'), findsOneWidget);
      expect(_timeRowFinder('Start time'), findsOneWidget);

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(repository.patches, hasLength(1));
      expect(repository.patches.single.fields['microsoftDueDateTime'], {
        'dateTime': '2026-06-06T09:00:00',
        'timeZone': 'America/Vancouver',
      });
      expect(repository.patches.single.fields['microsoftStartDateTime'], {
        'dateTime': '2026-06-04T09:00:00',
        'timeZone': 'UTC',
      });
    },
  );

  testWidgets('Microsoft midnight task stays in time slot mode', (
    tester,
  ) async {
    final repository = _FakeTasksRepository(
      microsoftDueDateTime: '2026-06-06T00:00:00',
      microsoftStartDateTime: '2026-06-04T00:00:00',
    );
    await _pumpDetails(
      tester,
      microsoftTaskProviderCapabilities,
      repository: repository,
    );

    expect(find.byType(BusyMaxTimeModeRow), findsOneWidget);
    expect(_timeRowFinder('Due time'), findsOneWidget);
    expect(_timeRowFinder('Start time'), findsOneWidget);
    expect(find.text('All day'), findsOneWidget);
    expect(find.text('Time slot'), findsOneWidget);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repository.patches, isEmpty);
  });

  testWidgets('populated time field renders its floating label and value', (
    tester,
  ) async {
    await _pumpDetails(tester, microsoftTaskProviderCapabilities);
    final field = _labeledTextFormFieldFinder('Due time');
    final label = find.text('Due time');

    expect(field, findsOneWidget);
    expect(label, findsOneWidget);
    expect(
      _labeledFieldText(tester, 'Due time'),
      _withVancouverTimeZone('2:30 PM'),
    );
    expect(tester.getCenter(label).dy, lessThan(tester.getCenter(field).dy));
  });

  testWidgets(
    'empty time field stays empty and floats its label when focused',
    (tester) async {
      await tester.pumpWidget(
        localizedTestApp(
          alwaysUse24HourFormat: true,
          child: Scaffold(
            body: DesktopTimeField(
              label: 'Due time',
              time: null,
              onChanged: (_) {},
            ),
          ),
        ),
      );

      expect(find.byType(DesktopTimeField), findsOneWidget);
      expect(find.text('None'), findsNothing);
      final field = _labeledTextFormFieldFinder('Due time');
      final label = find.text('Due time');
      final restingLabelTop = tester.getTopLeft(label).dy;

      expect(_labeledFieldText(tester, 'Due time'), isEmpty);

      await tester.tap(field);
      await tester.pumpAndSettle();

      expect(_labeledFieldText(tester, 'Due time'), isEmpty);
      expect(tester.getTopLeft(label).dy, lessThan(restingLabelTop));
    },
  );

  testWidgets('time field accepts midnight input', (tester) async {
    String? changed;
    await tester.pumpWidget(
      localizedTestApp(
        alwaysUse24HourFormat: true,
        child: Scaffold(
          body: _ControlledTimeField(
            label: 'Due time',
            initialTime: '09:30',
            onChanged: (time) => changed = time,
          ),
        ),
      ),
    );

    await _enterTime(tester, label: 'Due time', value: '00:00');

    expect(changed, '00:00');
    expect(_labeledFieldText(tester, 'Due time'), '00:00');
    expect(tester.takeException(), isNull);
  });

  testWidgets('time field accepts a complete localized time value', (
    tester,
  ) async {
    String? changed;
    await tester.pumpWidget(
      localizedTestApp(
        alwaysUse24HourFormat: true,
        child: Scaffold(
          body: _ControlledTimeField(
            label: 'Due time',
            initialTime: null,
            onChanged: (time) => changed = time,
          ),
        ),
      ),
    );

    await _enterTime(tester, label: 'Due time', value: '05:17');

    expect(changed, '05:17');
    expect(_labeledFieldText(tester, 'Due time'), '05:17');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Microsoft payload still includes time zone on Save', (
    tester,
  ) async {
    final repository = _FakeTasksRepository();
    await _pumpDetails(
      tester,
      microsoftTaskProviderCapabilities,
      alwaysUse24HourFormat: true,
      repository: repository,
    );

    await _openDatePicker(tester, 'Due date');
    await tester.tap(
      find
          .descendant(
            of: find.byType(BusyMaxContentPopoverSurface),
            matching: find.text('15'),
          )
          .first,
    );
    await tester.pumpAndSettle();

    expect(repository.patches, isEmpty);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repository.patches, hasLength(1));
    expect(
      repository.patches.single.fields['microsoftDueTimeZone'],
      'America/Vancouver',
    );
  });

  testWidgets('date field does not render a Flutter calendar grid', (
    tester,
  ) async {
    await _pumpDetails(tester, microsoftTaskProviderCapabilities);

    await _openDatePicker(tester, 'Due date');

    expect(find.byType(CalendarDatePicker), findsNothing);
    expect(find.text('June 2026'), findsNothing);
    expect(find.byType(BusyMaxContentPopoverSurface), findsOneWidget);
  });
}

Finder _confirmDialogButton(String label) {
  return find.descendant(
    of: find.byType(BusyMaxConfirmDialog),
    matching: find.text(label),
  );
}

Future<void> _pumpDetails(
  WidgetTester tester,
  TaskProviderCapabilities capabilities, {
  Locale locale = const Locale('en'),
  bool? alwaysUse24HourFormat,
  bool reminderOn = false,
  _FakeTasksRepository? repository,
  VoidCallback? onClose,
  String? accountIdOverride,
  bool includeAccountIdentity = true,
  String? displayName,
  String? email,
  Stream<List<AccountEntity>>? accountsStream,
  ThemeData? theme,
  bool modalEditorSurface = false,
}) async {
  final accountId =
      accountIdOverride ??
      (capabilities.supportsDueTime ? 'microsoft:m' : 'google:g');
  final provider = capabilities.supportsDueTime
      ? TaskProvider.microsoft
      : TaskProvider.google;
  final accountDisplayName = includeAccountIdentity
      ? displayName ??
            (capabilities.supportsDueTime ? 'Microsoft User' : 'Google User')
      : displayName;
  final accountEmail = includeAccountIdentity
      ? email ??
            (capabilities.supportsDueTime
                ? 'microsoft@example.com'
                : 'google@example.com')
      : email;
  tester.view.physicalSize = const Size(1000, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        selectedAccountProvider.overrideWithValue(
          AccountEntity(
            id: accountId,
            provider: provider,
            authState: 'signed_in',
            displayName: accountDisplayName,
            email: accountEmail,
          ),
        ),
        selectedAccountCapabilitiesProvider.overrideWithValue(capabilities),
        localTimeZoneProvider.overrideWithValue('UTC'),
        accountsStreamProvider.overrideWith((ref) {
          return accountsStream ??
              Stream.value([
                AccountEntity(
                  id: accountId,
                  provider: provider,
                  authState: 'signed_in',
                  displayName: accountDisplayName,
                  email: accountEmail,
                ),
              ]);
        }),
        tasksRepositoryForAccountProvider.overrideWith((ref, requestedId) {
          expect(requestedId, accountId);
          return repository ??
              _FakeTasksRepository(
                accountId: requestedId,
                reminderOn: reminderOn,
              );
        }),
        taskListsRepositoryForAccountProvider.overrideWith((ref, requestedId) {
          expect(requestedId, accountId);
          return _FakeTaskListsRepository(accountId: requestedId);
        }),
      ],
      child: localizedTestApp(
        locale: locale,
        alwaysUse24HourFormat: alwaysUse24HourFormat,
        theme: theme,
        child: Scaffold(
          body: modalEditorSurface
              ? BusyMaxModalEditorSurface(
                  maxWidth: 640,
                  maxHeight: 1000,
                  child: TaskDetailsPane(
                    accountId: accountId,
                    taskListId: 'list-1',
                    taskId: 'task-1',
                    onClose: onClose,
                  ),
                )
              : TaskDetailsPane(
                  accountId: accountId,
                  taskListId: 'list-1',
                  taskId: 'task-1',
                  onClose: onClose,
                ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpSwitchingDetails(
  WidgetTester tester,
  _SwitchingTasksRepository repository, {
  required String taskId,
  ValueChanged<TaskEntity>? onTaskSwitchCancelled,
}) async {
  tester.view.physicalSize = const Size(1000, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        localTimeZoneProvider.overrideWithValue('UTC'),
        accountsStreamProvider.overrideWith((ref) {
          return Stream.value([
            const AccountEntity(
              id: 'microsoft:m',
              provider: TaskProvider.microsoft,
              authState: 'signed_in',
              displayName: 'Microsoft User',
              email: 'microsoft@example.com',
            ),
          ]);
        }),
        tasksRepositoryForAccountProvider.overrideWith((ref, requestedId) {
          expect(requestedId, 'microsoft:m');
          return repository;
        }),
        taskListsRepositoryForAccountProvider.overrideWith((ref, requestedId) {
          expect(requestedId, 'microsoft:m');
          return const _FakeTaskListsRepository(accountId: 'microsoft:m');
        }),
      ],
      child: localizedTestApp(
        child: Scaffold(
          body: TaskDetailsPane(
            accountId: 'microsoft:m',
            taskListId: 'list-1',
            taskId: taskId,
            onTaskSwitchCancelled: onTaskSwitchCancelled,
          ),
        ),
      ),
    ),
  );
}

Object? _headerButtonOnPressed(WidgetTester tester, String label) {
  final button = tester.widget<ButtonStyleButton>(
    _headerButtonFinder(tester, label),
  );
  return button.onPressed;
}

Finder _headerButtonFinder(WidgetTester tester, String label) {
  return find
      .ancestor(
        of: find.text(label),
        matching: find.byWidgetPredicate(
          (widget) => widget is ButtonStyleButton,
        ),
      )
      .first;
}

String? _firstTextFieldText(WidgetTester tester) {
  return tester
      .widget<TextField>(find.byType(TextField).first)
      .controller
      ?.text;
}

void _focusEditorShortcuts(WidgetTester tester) {
  final focusFinder = find.descendant(
    of: find.byType(TaskDetailsEditor),
    matching: find.byWidgetPredicate(
      (widget) =>
          widget is Focus &&
          widget.focusNode?.debugLabel == 'Task editor shortcuts',
    ),
  );
  final focusWidget = tester.widget<Focus>(focusFinder);
  focusWidget.focusNode!.requestFocus();
}

Finder _dateRowFinder(String label) {
  return find.byWidgetPredicate(
    (widget) => widget is DesktopDateValueRow && widget.label == label,
  );
}

Finder _timeRowFinder(String label) {
  return find.byWidgetPredicate(
    (widget) => widget is DesktopTimeValueRow && widget.label == label,
  );
}

Finder _labeledTextFormFieldFinder(String label) {
  return find.ancestor(
    of: find.text(label),
    matching: find.byType(TextFormField),
  );
}

String _labeledFieldText(WidgetTester tester, String label) {
  return tester
          .widget<TextFormField>(_labeledTextFormFieldFinder(label).first)
          .controller
          ?.text ??
      '';
}

List<String> _renderedDateFieldTexts(WidgetTester tester) {
  final fields = find.descendant(
    of: find.byType(DesktopDateField),
    matching: find.byType(TextFormField),
  );
  return [
    for (final field in tester.widgetList<TextFormField>(fields))
      field.controller?.text ?? '',
  ];
}

Future<void> _openDatePicker(WidgetTester tester, String label) async {
  final row = _dateRowFinder(label);
  await tester.ensureVisible(row);
  await tester.pumpAndSettle();
  final calendarIcon = find.descendant(
    of: row,
    matching: find.byIcon(YaruIcons.calendar),
  );
  final button = tester.widget<YaruIconButton>(
    find.ancestor(of: calendarIcon, matching: find.byType(YaruIconButton)),
  );
  button.onPressed?.call();
  await tester.pumpAndSettle();
}

Future<void> _enterTime(
  WidgetTester tester, {
  required String label,
  required String value,
}) async {
  final field = _labeledTextFormFieldFinder(label);
  await tester.tap(field);
  await tester.enterText(field, value);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pump();
}

class _ControlledTimeField extends StatefulWidget {
  const _ControlledTimeField({
    required this.label,
    required this.initialTime,
    required this.onChanged,
  });

  final String label;
  final String? initialTime;
  final ValueChanged<String?> onChanged;

  @override
  State<_ControlledTimeField> createState() => _ControlledTimeFieldState();
}

class _ControlledTimeFieldState extends State<_ControlledTimeField> {
  late String? _time = widget.initialTime;

  @override
  Widget build(BuildContext context) {
    return DesktopTimeField(
      label: widget.label,
      time: _time,
      onChanged: (value) {
        setState(() => _time = value);
        widget.onChanged(value);
      },
    );
  }
}

class _FakeTasksRepository implements TasksRepository {
  _FakeTasksRepository({
    this.accountId = 'microsoft:m',
    this.reminderOn = false,
    this.missingTask = false,
    this.microsoftDueDateTime = '2026-06-06T14:30:00',
    this.microsoftStartDateTime = '2026-06-04T07:00:00.0000000',
    this.categorySuggestions = const [],
  });

  final String accountId;
  final bool reminderOn;
  final bool missingTask;
  final String microsoftDueDateTime;
  final String? microsoftStartDateTime;
  final List<String> categorySuggestions;
  final List<TaskPatchInput> patches = [];
  final List<TaskMoveInput> moves = [];
  var deleteCalls = 0;

  @override
  Stream<TaskEntity?> watchTask(String taskListId, String taskId) {
    if (missingTask) {
      return Stream.value(null);
    }
    return Stream.value(
      TaskEntity(
        accountId: accountId,
        taskListId: 'list-1',
        id: 'task-1',
        title: 'Task',
        localDirty: false,
        pendingDelete: false,
        pendingMove: false,
        rawJson: '{}',
        updatedLocalAtUtc: '2026-06-04T00:00:00.000Z',
        status: 'needsAction',
        dueUtc: '2026-06-06',
        microsoftDueDateTime: microsoftDueDateTime,
        microsoftDueTimeZone: 'America/Vancouver',
        microsoftStartDateTime: microsoftStartDateTime,
        microsoftStartTimeZone: 'UTC',
        microsoftIsReminderOn: reminderOn,
        microsoftReminderDateTime: reminderOn ? '2026-06-05T09:15:00' : null,
        microsoftReminderTimeZone: 'America/Vancouver',
        importance: 'high',
        categoriesJson: '["Home"]',
      ),
    );
  }

  @override
  Stream<List<String>> watchCategorySuggestions() {
    return Stream.value(categorySuggestions);
  }

  @override
  Future<void> patchTask(
    String taskListId,
    String taskId,
    TaskPatchInput input,
  ) async {
    patches.add(input);
  }

  @override
  Future<void> moveTask(TaskMoveInput input) async {
    moves.add(input);
  }

  @override
  Future<void> deleteTask(String taskListId, String taskId) async {
    deleteCalls += 1;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SwitchingTasksRepository implements TasksRepository {
  final _controllers = <String, StreamController<TaskEntity?>>{};
  final _latest = <String, TaskEntity>{};

  void emit(TaskEntity task) {
    _latest[task.id] = task;
    _controllers
        .putIfAbsent(task.id, () => StreamController<TaskEntity?>.broadcast())
        .add(task);
  }

  void dispose() {
    for (final controller in _controllers.values) {
      unawaited(controller.close());
    }
  }

  @override
  Stream<TaskEntity?> watchTask(String taskListId, String taskId) async* {
    final latest = _latest[taskId];
    if (latest != null) {
      yield latest;
    }
    yield* _controllers
        .putIfAbsent(taskId, () => StreamController<TaskEntity?>.broadcast())
        .stream;
  }

  @override
  Stream<List<String>> watchCategorySuggestions() {
    return Stream.value(const []);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

TaskEntity _switchTask(String id, String title) {
  return TaskEntity(
    accountId: 'microsoft:m',
    taskListId: 'list-1',
    id: id,
    title: title,
    localDirty: false,
    pendingDelete: false,
    pendingMove: false,
    rawJson: '{}',
    updatedLocalAtUtc: '2026-06-04T00:00:00.000Z',
    status: 'needsAction',
  );
}

TaskEntity _switchTimedTask(String id, String title) {
  return TaskEntity(
    accountId: 'microsoft:m',
    taskListId: 'list-1',
    id: id,
    title: title,
    localDirty: false,
    pendingDelete: false,
    pendingMove: false,
    rawJson: '{}',
    updatedLocalAtUtc: '2026-06-04T00:00:00.000Z',
    status: 'needsAction',
    dueUtc: '2026-06-06',
    microsoftDueDateTime: '2026-06-06T14:30:00',
    microsoftDueTimeZone: 'America/Vancouver',
    microsoftStartDateTime: '2026-06-04T07:00:00',
    microsoftStartTimeZone: 'UTC',
  );
}

class _FakeTaskListsRepository implements TaskListsRepository {
  const _FakeTaskListsRepository({this.accountId = 'microsoft:m'});

  final String accountId;

  @override
  Stream<List<TaskListEntity>> watchTaskLists() {
    return Stream.value([
      TaskListEntity(
        accountId: accountId,
        id: 'list-1',
        title: 'Tasks',
        localDirty: false,
        pendingDelete: false,
        rawJson: '{}',
      ),
      TaskListEntity(
        accountId: 'microsoft:m',
        id: 'list-2',
        title: 'Other',
        localDirty: false,
        pendingDelete: false,
        rawJson: '{}',
      ),
    ]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
