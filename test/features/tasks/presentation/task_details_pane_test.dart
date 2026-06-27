import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/app/busymax_design.dart';
import 'package:busymax/src/features/accounts/data/accounts_repository.dart';
import 'package:busymax/src/features/task_lists/data/task_lists_repository.dart';
import 'package:busymax/src/features/tasks/data/tasks_repository.dart';
import 'package:busymax/src/features/tasks/presentation/desktop_date_time_fields.dart';
import 'package:busymax/src/features/tasks/presentation/task_details_editor.dart';
import 'package:busymax/src/features/tasks/presentation/task_details_pane.dart';
import 'package:busymax/src/task_providers/task_provider.dart';
import 'package:ubuntu_widgets/ubuntu_widgets.dart';
import 'package:yaru/yaru.dart';

import '../../../test_localized_app.dart';

const _nativePickerChannel = MethodChannel(nativeDateTimePickerChannelName);

void main() {
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_nativePickerChannel, (_) async {
          throw MissingPluginException();
        });
  });

  testWidgets('Task Details header shows Cancel and Save', (tester) async {
    await _pumpDetails(tester, microsoftTaskProviderCapabilities);

    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Edit Task'), findsOneWidget);
    expect(find.text('Task details'), findsNothing);
    expect(find.text('Save'), findsOneWidget);
  });

  testWidgets('Cancel and Save are compact PushButtons', (tester) async {
    await _pumpDetails(tester, microsoftTaskProviderCapabilities);

    expect(
      find.ancestor(
        of: find.text('Cancel'),
        matching: find.byWidgetPredicate((widget) => widget is PushButton),
      ),
      findsOneWidget,
    );
    expect(
      find.ancestor(
        of: find.text('Save'),
        matching: find.byWidgetPredicate((widget) => widget is PushButton),
      ),
      findsOneWidget,
    );
  });

  testWidgets('header buttons use compact headerbar sizing', (tester) async {
    await _pumpDetails(tester, microsoftTaskProviderCapabilities);

    expect(
      tester.getSize(_headerButtonFinder(tester, 'Cancel')).width,
      inInclusiveRange(100, 180),
    );
    expect(
      tester.getSize(_headerButtonFinder(tester, 'Save')).width,
      inInclusiveRange(100, 180),
    );
    expect(
      tester.getSize(_headerButtonFinder(tester, 'Cancel')).height,
      BusyMaxSizes.headerIconButton,
    );
    expect(
      tester.getSize(_headerButtonFinder(tester, 'Save')).height,
      BusyMaxSizes.headerIconButton,
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

  testWidgets('status controls are absent from Task Details', (tester) async {
    await _pumpDetails(tester, microsoftTaskProviderCapabilities);

    expect(find.text('Open'), findsNothing);
    expect(find.text('Done'), findsNothing);
    expect(find.byType(SegmentedButton<bool>), findsNothing);
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

    expect(find.text('Jun 6, 2026'), findsOneWidget);
    expect(find.text('14:30'), findsOneWidget);
    expect(find.byType(YaruDateTimeEntry), findsNothing);
    expect(find.byType(YaruTimeEntry), findsNothing);
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

    expect(find.text('2:30 PM'), findsOneWidget);
    expect(find.text('Jun 4, 2026'), findsOneWidget);
    expect(find.byType(YaruDateTimeEntry), findsNothing);
    expect(find.byType(YaruTimeEntry), findsNothing);
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

    expect(find.byType(YaruDateTimeEntry), findsNothing);
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

    expect(find.byType(YaruDateTimeEntry), findsNothing);
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

    expect(find.byType(YaruDateTimeEntry), findsNothing);
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
    expect(find.text('Due date'), findsOneWidget);
    expect(find.text('All Day'), findsNothing);
    expect(find.text('Time Slot'), findsNothing);
    expect(find.text('Due time'), findsNothing);
    expect(find.text('Start'), findsNothing);
    expect(find.text('Start date'), findsNothing);
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

  testWidgets('unsupported provider text is not rendered for Google', (
    tester,
  ) async {
    await _pumpDetails(tester, googleTaskProviderCapabilities);

    expect(find.text('Provider features'), findsNothing);
    expect(find.text('Not supported by Google Tasks.'), findsNothing);
    expect(find.text('Start date'), findsNothing);
    expect(find.text('Start time'), findsNothing);
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
      expect(find.text('Repeat'), findsNWidgets(2));
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

    expect(find.text('Home'), findsOneWidget);

    await tester.tap(find.text('Add category'));
    await tester.pump();
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

  testWidgets('Microsoft category suggestions can be selected', (tester) async {
    final repository = _FakeTasksRepository(
      categorySuggestions: const ['Home', 'Work'],
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
    expect(field.decoration?.border, InputBorder.none);
    expect(field.decoration?.focusedBorder, InputBorder.none);
    expect(
      tester.getTopLeft(find.text('Work').last).dy,
      greaterThanOrEqualTo(tester.getBottomLeft(input).dy - 1),
    );
    await tester.tap(find.text('Work').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repository.patches.single.fields['categories'], ['Home', 'Work']);
  });

  testWidgets('Due group appears before separate Start group', (tester) async {
    await _pumpDetails(tester, microsoftTaskProviderCapabilities);

    final dueTop = tester.getTopLeft(find.text('Due')).dy;
    final startTop = tester.getTopLeft(find.text('Start')).dy;
    final dueDateTop = tester.getTopLeft(find.text('Due date')).dy;
    final startDateTop = tester.getTopLeft(find.text('Start date')).dy;

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

    expect(find.text('Reminder date'), findsOneWidget);
    expect(find.text('Reminder time'), findsOneWidget);
    expect(find.text('Jun 5, 2026'), findsOneWidget);
    expect(find.text('09:15'), findsOneWidget);
    expect(find.byType(YaruDateTimeEntry), findsNothing);
    expect(find.byType(YaruTimeEntry), findsNothing);
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

  testWidgets('due date uses native platform picker channel', (tester) async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_nativePickerChannel, (call) async {
          calls.add(call);
          expect(call.method, 'pickDate');
          expect(call.arguments, containsPair('initialDate', '2026-06-06'));
          expect(call.arguments, containsPair('cancelLabel', 'Cancel'));
          expect(call.arguments, containsPair('okLabel', 'OK'));
          return '2026-06-15';
        });
    await _pumpDetails(tester, microsoftTaskProviderCapabilities);

    await _openRowMenu(tester, 'Due date');

    expect(tester.takeException(), isNull);
    expect(calls, hasLength(1));
    expect(find.text('June 2026'), findsNothing);
    expect(find.text('Jun 15, 2026'), findsOneWidget);
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

    await _openRowMenu(tester, 'Due date');

    expect(find.byType(YaruDateTimeEntry), findsOneWidget);
    expect(find.byType(CalendarDatePicker), findsNothing);

    await tester.tap(find.text('OK'));
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

    await _openRowMenu(tester, 'Due date');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(changed, today);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'due time uses in-app time entry instead of custom picker channel',
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

      expect(_timeTextEntryFinder(), findsNothing);
      await _openRowMenu(tester, 'Due time');

      expect(_timeTextEntryFinder(), findsOneWidget);

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
    expect(find.text('All Day'), findsOneWidget);
    expect(find.text('Time Slot'), findsOneWidget);
    expect(find.text('Due time'), findsOneWidget);
    expect(find.text('Start time'), findsOneWidget);

    await tester.tap(find.text('All Day'));
    await tester.pumpAndSettle();

    expect(find.text('Due time'), findsNothing);
    expect(find.text('Start time'), findsNothing);

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
      expect(find.text('Due time'), findsNothing);
      expect(find.text('Start time'), findsNothing);

      await tester.tap(find.text('Time Slot'));
      await tester.pumpAndSettle();

      expect(find.text('Due time'), findsWidgets);
      expect(find.text('Start time'), findsOneWidget);

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
    expect(find.text('Due time'), findsOneWidget);
    expect(find.text('Start time'), findsOneWidget);
    expect(find.text('All Day'), findsOneWidget);
    expect(find.text('Time Slot'), findsOneWidget);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repository.patches, isEmpty);
  });

  testWidgets('time entries do not show redundant internal input label', (
    tester,
  ) async {
    await _pumpDetails(tester, microsoftTaskProviderCapabilities);
    await _openRowMenu(tester, 'Due time');

    final entryContext = tester.element(_timeTextEntryFinder().first);
    final decorationTheme = Theme.of(entryContext).inputDecorationTheme;

    expect(decorationTheme.floatingLabelBehavior, FloatingLabelBehavior.never);
    expect(decorationTheme.labelStyle?.fontSize, 0);
    expect(decorationTheme.floatingLabelStyle?.fontSize, 0);
  });

  testWidgets(
    'empty time field uses time placeholder instead of None subtitle',
    (tester) async {
      await tester.pumpWidget(
        localizedTestApp(
          child: Scaffold(
            body: DesktopTimeField(
              label: 'Due time',
              time: null,
              onChanged: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Due time'), findsWidgets);
      expect(find.text('None'), findsNothing);
      final entry = tester.widget<TextFormField>(_timeTextEntryFinder());
      expect(entry.controller?.text, isEmpty);
      expect(find.text('--:--'), findsOneWidget);
    },
  );

  testWidgets('time field accepts midnight input', (tester) async {
    String? changed;
    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: DesktopTimeField(
            label: 'Due time',
            time: '09:30',
            onChanged: (time) => changed = time,
          ),
        ),
      ),
    );

    await tester.enterText(_timeTextEntryFinder(), '00:00');
    await tester.pump();

    expect(changed, '00:00');
    expect(tester.takeException(), isNull);
  });

  testWidgets('time field formats compact numeric input', (tester) async {
    String? changed;
    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: DesktopTimeField(
            label: 'Due time',
            time: null,
            onChanged: (time) => changed = time,
          ),
        ),
      ),
    );

    await tester.enterText(_timeTextEntryFinder(), '0517');
    await tester.pump();

    final entry = tester.widget<TextFormField>(_timeTextEntryFinder());
    expect(entry.controller?.text, '05:17');
    expect(changed, '05:17');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Microsoft payload still includes time zone on Save', (
    tester,
  ) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_nativePickerChannel, (call) async {
          expect(call.method, 'pickDate');
          return '2026-06-15';
        });
    final repository = _FakeTasksRepository();
    await _pumpDetails(
      tester,
      microsoftTaskProviderCapabilities,
      alwaysUse24HourFormat: true,
      repository: repository,
    );

    await _openRowMenu(tester, 'Due date');
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
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_nativePickerChannel, (call) async {
          calls.add(call);
          return null;
        });
    await _pumpDetails(tester, microsoftTaskProviderCapabilities);

    await _openRowMenu(tester, 'Due date');

    expect(calls.single.method, 'pickDate');
    expect(find.text('June 2026'), findsNothing);
    expect(find.byType(CalendarDatePicker), findsNothing);
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
          return Stream.value([
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
        child: Scaffold(
          body: TaskDetailsPane(
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

Future<void> _openRowMenu(WidgetTester tester, String label) async {
  final row = find
      .ancestor(
        of: find.text(label).first,
        matching: find.byType(BusyMaxCalendarValueRow),
      )
      .first;
  await tester.ensureVisible(row);
  await tester.pumpAndSettle();
  await tester.tap(row);
  await tester.pumpAndSettle();
}

Finder _timeTextEntryFinder() {
  return find.byWidgetPredicate(
    (widget) => widget is TextFormField && widget.controller != null,
  );
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
