import '../../schedule/schedule_filters.dart';
import '../../features/schedule/presentation/schedule_item_exporter.dart';
import 'android_time_zone_picker.dart';
import '../../features/tasks/presentation/task_alarm_label.dart';
import 'android_recurrence_dialog.dart';
import '../../features/recurrence/presentation/recurrence_summary.dart';

import 'package:busymax/src/core/auth/authorization_attempt.dart';

import 'android_dav_attachments_section.dart';

import 'dart:async';
import 'dart:convert';

import 'package:busymax_android_platform/busymax_android_platform.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_bootstrap.dart';
import '../../dav/ical/ical_task_alarm.dart';
import '../../dav/dav_errors.dart';
import '../../features/task_lists/data/task_lists_repository.dart';
import '../../features/tasks/data/tasks_repository.dart';
import '../../features/tasks/domain/task_capabilities.dart';
import '../../features/tasks/domain/task_source_links.dart';
import '../../features/tasks/presentation/task_details_draft.dart';
import '../../features/tasks/presentation/task_recurrence.dart';
import '../../features/recurrence/domain/event_recurrence_codec.dart';
import '../../features/recurrence/domain/recurrence_rule.dart';
import '../../features/schedule/presentation/schedule_event_details_format.dart';
import '../../features/schedule/presentation/attachment_download.dart';
import '../../features/schedule/presentation/attachment_upload_coordinator.dart';
import '../../microsoft_todo/api/microsoft_todo_api_client.dart';
import '../../microsoft_todo/api/microsoft_todo_api_models.dart';
import '../../microsoft_calendar/microsoft_calendar_models.dart';
import '../../l10n/l10n.dart';
import '../../providers/busy_provider.dart';
import '../../schedule/schedule_item.dart';
import '../android_notifications.dart';
import 'android_date_picker.dart';
import 'android_task_motion.dart';

enum AndroidTaskEditorAction { created, updated, deleted, moved }

class AndroidTaskEditorResult {
  const AndroidTaskEditorResult({
    required this.action,
    required this.accountId,
    required this.taskListId,
    required this.taskId,
    this.previousTaskListId,
    this.completed,
    this.occurrenceKey,
  });

  final AndroidTaskEditorAction action;
  final String accountId;
  final String taskListId;
  final String taskId;
  final String? previousTaskListId;
  final bool? completed;
  final String? occurrenceKey;
}

Future<TaskListEntity?> selectAndroidTaskList(
  BuildContext context,
  List<TaskListEntity> lists, {
  required String title,
  Map<String, String> accountLabels = const {},
  bool alwaysPrompt = false,
}) {
  if (lists.length == 1 && !alwaysPrompt) return Future.value(lists.single);
  return showModalBottomSheet<TaskListEntity>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          ListTile(title: Text(title)),
          for (final list in lists)
            ListTile(
              leading: const Icon(Icons.checklist_outlined),
              title: Text(list.title),
              subtitle: Text(accountLabels[list.accountId] ?? list.accountId),
              onTap: () => Navigator.pop(sheetContext, list),
            ),
        ],
      ),
    ),
  );
}

final _taskEditorNavigators = Expando<_TaskEditorNavigator>();

String _taskEditorKey(String accountId, String taskListId, String taskId) =>
    '$accountId\u0000$taskListId\u0000$taskId';

String _taskRecoveryKey(String accountId, String taskListId, String taskId) =>
    'busymax.android.task-draft.v2.'
    '${base64Url.encode(utf8.encode(jsonEncode([accountId, taskListId, taskId])))}';

String _taskCreationIntentKey(
  String accountId,
  String taskListId,
  BusyProvider provider,
  DateTime? initialDue,
) => jsonEncode([
  accountId,
  taskListId,
  provider.name,
  initialDue?.toIso8601String(),
]);

class _TaskEditorOpen {
  _TaskEditorOpen(this.order, {this.creationIntentKey});
  final int order;
  final String? creationIntentKey;
  Future<AndroidTaskEditorResult?>? result;
  TaskEntity? task;
}

class _TaskEditorNavigator {
  var generation = 0;
  final openings = <String, _TaskEditorOpen>{};
  final editors = <_AndroidTaskEditorState>[];
}

_TaskEditorNavigator _taskEditorNavigator(NavigatorState navigator) =>
    _taskEditorNavigators[navigator] ??= _TaskEditorNavigator();

Future<AndroidTaskEditorResult?> _reuseTaskEditor(
  _TaskEditorNavigator sessions,
  _TaskEditorOpen opening,
  TaskScheduleItem? task,
) async {
  final target = sessions.editors.where((editor) {
    if (task == null) {
      return editor.mounted &&
          !editor._allowPop &&
          editor.widget.task == null &&
          editor._creationIntentKey == opening.creationIntentKey;
    }
    final existing = editor._observedTask ?? editor.widget.task;
    return opening.task != null
        ? editor._matchesTask(opening.task!) && !editor._allowPop
        : editor.mounted &&
              !editor._allowPop &&
              existing != null &&
              editor.widget.accountId == task.accountId &&
              editor._draft.taskListId == task.sourceId &&
              existing.matchesIdentity(task.id);
  }).firstOrNull;
  if (target != null) await _revealTaskEditor(sessions, target);
  return opening.result!;
}

Future<void> _revealTaskEditor(
  _TaskEditorNavigator sessions,
  _AndroidTaskEditorState target,
) async {
  final current = sessions.editors
      .where(
        (editor) =>
            editor.mounted && ModalRoute.of(editor.context)?.isCurrent == true,
      )
      .lastOrNull;
  if (current != null && current._hierarchyAncestors.contains(target)) {
    await current._returnToEditor(target);
  }
}

Future<_AndroidTaskEditorState?> _findTaskEditor(
  _TaskEditorNavigator sessions,
  TaskEntity task,
) async {
  final exact = sessions.editors
      .where((editor) => editor._matchesTask(task) && !editor._allowPop)
      .firstOrNull;
  if (exact != null) return exact;
  for (final editor in List.of(sessions.editors)) {
    final observed = editor._observedTask ?? editor.widget.task;
    final oldListId = editor._draft.taskListId;
    if (!editor.mounted ||
        editor._allowPop ||
        editor._saving ||
        observed == null ||
        editor.widget.accountId != task.accountId ||
        !task.previousTaskListIds.contains(oldListId) ||
        !(task.matchesIdentity(observed.id) ||
            observed.matchesIdentity(task.id))) {
      continue;
    }
    final repository = editor.ref.read(
      tasksRepositoryForAccountProvider(task.accountId),
    );
    final source = await repository.readTask(oldListId, observed.id);
    final current = await repository.readTask(task.taskListId, task.id);
    if (source != null ||
        current == null ||
        !current.previousTaskListIds.contains(oldListId) ||
        !current.matchesIdentity(observed.id) ||
        !editor.mounted ||
        editor._allowPop ||
        editor._saving) {
      continue;
    }
    editor._rebindMovedTask(current);
    return editor;
  }
  return null;
}

bool androidTaskEditorIsActive(BuildContext context) {
  final sessions = _taskEditorNavigator(Navigator.of(context));
  return sessions.openings.isNotEmpty ||
      sessions.editors.any((editor) => editor.mounted && !editor._allowPop);
}

Future<AndroidTaskEditorResult?> showAndroidTaskEditor(
  BuildContext context,
  WidgetRef ref, {
  TaskScheduleItem? task,
  TaskListEntity? creationList,
  BusyProvider? creationProvider,
  DateTime? initialDue,
  ValueChanged<AndroidTaskEditorResult>? onMutationStarted,
  ValueChanged<AndroidTaskEditorResult>? onMutationCommitted,
  VoidCallback? onMutationFailed,
}) {
  final sessions = _taskEditorNavigator(Navigator.of(context));
  final creationIntentKey = task == null && creationList != null
      ? _taskCreationIntentKey(
          creationList.accountId,
          creationList.id,
          creationProvider!,
          initialDue,
        )
      : null;
  final key = task == null
      ? 'new\u0000$creationIntentKey'
      : _taskEditorKey(task.accountId, task.sourceId, task.id);
  final active = sessions.openings[key];
  if (active != null) return _reuseTaskEditor(sessions, active, task);
  final opening = _TaskEditorOpen(
    ++sessions.generation,
    creationIntentKey: creationIntentKey,
  );
  sessions.openings[key] = opening;
  final result =
      _showAndroidTaskEditor(
        context,
        ref,
        task: task,
        creationList: creationList,
        creationProvider: creationProvider,
        initialDue: initialDue,
        onMutationStarted: onMutationStarted,
        onMutationCommitted: onMutationCommitted,
        onMutationFailed: onMutationFailed,
        sessions: sessions,
        opening: opening,
      ).whenComplete(() {
        sessions.openings.removeWhere(
          (_, candidate) => identical(candidate, opening),
        );
      });
  opening.result = result;
  return result;
}

Future<AndroidTaskEditorResult?> _showAndroidTaskEditor(
  BuildContext context,
  WidgetRef ref, {
  TaskScheduleItem? task,
  TaskListEntity? creationList,
  BusyProvider? creationProvider,
  DateTime? initialDue,
  ValueChanged<AndroidTaskEditorResult>? onMutationStarted,
  ValueChanged<AndroidTaskEditorResult>? onMutationCommitted,
  VoidCallback? onMutationFailed,
  required _TaskEditorNavigator sessions,
  required _TaskEditorOpen opening,
}) async {
  TaskEntity? entity;
  TaskListEntity? selectedList = creationList;
  if (task != null) {
    entity = await ref
        .read(tasksRepositoryForAccountProvider(task.accountId))
        .watchTask(task.sourceId, task.id)
        .first;
    if (!context.mounted || entity == null) return null;
    opening.task = entity;
    final keys = entity.identityIds
        .map((id) => _taskEditorKey(entity!.accountId, entity.taskListId, id))
        .toList();
    final older =
        keys
            .map((key) => sessions.openings[key])
            .nonNulls
            .where((candidate) => candidate.order < opening.order)
            .toList()
          ..sort((a, b) => a.order.compareTo(b.order));
    if (older.isNotEmpty) {
      final owner = older.first..task = entity;
      for (final key in keys) {
        sessions.openings[key] = owner;
      }
      return _reuseTaskEditor(sessions, owner, task);
    }
    for (final key in keys) {
      sessions.openings[key] = opening;
    }
    final active = await _findTaskEditor(sessions, entity);
    if (!context.mounted) return null;
    if (active != null) {
      await _revealTaskEditor(sessions, active);
      if (!active.mounted) return null;
      final result = await ModalRoute.of(active.context)!.popped;
      return result is AndroidTaskEditorResult ? result : null;
    }
    selectedList =
        (await ref
                .read(taskListsRepositoryForAccountProvider(task.accountId))
                .listTaskLists())
            .where((list) => list.id == task.sourceId)
            .firstOrNull;
  }
  final account = await ref
      .read(accountsRepositoryProvider)
      .accountById(task?.accountId ?? creationList!.accountId);
  if (!context.mounted) return null;
  if (entity != null) {
    // A hierarchy editor may have claimed this task while the list/account
    // reads were in flight. Its reservation exists before its route builds.
    final currentTask = entity;
    _TaskEditorOpen? otherOwner() => currentTask.identityIds
        .map(
          (id) =>
              sessions.openings[_taskEditorKey(
                currentTask.accountId,
                currentTask.taskListId,
                id,
              )],
        )
        .nonNulls
        .where((candidate) => !identical(candidate, opening))
        .firstOrNull;
    final owner = otherOwner();
    if (owner != null) return _reuseTaskEditor(sessions, owner, task);
    final active = await _findTaskEditor(sessions, entity);
    if (!context.mounted) return null;
    if (active != null) {
      await _revealTaskEditor(sessions, active);
      if (!active.mounted) return null;
      final result = await ModalRoute.of(active.context)!.popped;
      return result is AndroidTaskEditorResult ? result : null;
    }
    final claimedWhileReading = otherOwner();
    if (claimedWhileReading != null) {
      return _reuseTaskEditor(sessions, claimedWhileReading, task);
    }
  }
  final currentEditor = sessions.editors
      .where(
        (editor) =>
            editor.mounted && ModalRoute.of(editor.context)?.isCurrent == true,
      )
      .lastOrNull;
  return Navigator.of(context).push<AndroidTaskEditorResult>(
    MaterialPageRoute<AndroidTaskEditorResult>(
      fullscreenDialog: true,
      builder: (_) => _TaskHierarchyEditors(
        editors: currentEditor == null
            ? const []
            : [...currentEditor._hierarchyAncestors, currentEditor],
        child: AndroidTaskEditor(
          accountId: task?.accountId ?? creationList!.accountId,
          provider: task?.provider ?? creationProvider!,
          task: entity,
          creationList: creationList,
          initialDue: initialDue,
          accountLabel: account?.displayLabel,
          listLabel: selectedList?.title,
          onMutationStarted: onMutationStarted,
          onMutationCommitted: onMutationCommitted,
          onMutationFailed: onMutationFailed,
        ),
      ),
    ),
  );
}

class AndroidTaskEditor extends ConsumerStatefulWidget {
  const AndroidTaskEditor({
    super.key,
    required this.accountId,
    required this.provider,
    this.task,
    this.creationList,
    this.initialDue,
    this.accountLabel,
    this.listLabel,
    this.onMutationStarted,
    this.onMutationCommitted,
    this.onMutationFailed,
  });
  final String accountId;
  final BusyProvider provider;
  final TaskEntity? task;
  final TaskListEntity? creationList;
  final DateTime? initialDue;
  final String? accountLabel;
  final String? listLabel;
  final ValueChanged<AndroidTaskEditorResult>? onMutationStarted;
  final ValueChanged<AndroidTaskEditorResult>? onMutationCommitted;
  final VoidCallback? onMutationFailed;
  @override
  ConsumerState<AndroidTaskEditor> createState() => _AndroidTaskEditorState();
}

class _TaskHierarchyEditors extends InheritedWidget {
  const _TaskHierarchyEditors({required this.editors, required super.child});

  final List<_AndroidTaskEditorState> editors;

  @override
  bool updateShouldNotify(_TaskHierarchyEditors oldWidget) => false;
}

class _AndroidTaskEditorState extends ConsumerState<AndroidTaskEditor> {
  late String _creationAccountId = widget.accountId;
  late BusyProvider _creationProvider = widget.provider;
  String get _accountId =>
      widget.task == null ? _creationAccountId : widget.accountId;
  BusyProvider get _provider =>
      widget.task == null ? _creationProvider : widget.provider;
  AuthorizationCancellation? _consentCancellation;

  Future<List<TaskSourceLink>>? _linkedResourcesFuture;
  Future<List<MicrosoftTodoAttachmentDto>>? _attachmentsFuture;
  bool _attachmentBusy = false;
  late TaskDetailsDraft _draft = widget.task == null
      ? TaskDetailsDraft.forCreation(
          taskListId: widget.creationList!.id,
          provider: _provider,
          timeZone: ref.read(localTimeZoneProvider),
          due: widget.initialDue,
          scheduledAllDay:
              widget.initialDue == null ||
              (widget.initialDue!.hour == 0 && widget.initialDue!.minute == 0),
        )
      : TaskDetailsDraft.fromTask(
          widget.task!,
          ref.read(localTimeZoneProvider),
        );
  late final TextEditingController _title = TextEditingController(
    text: _draft.title,
  );
  late final TextEditingController _notes = TextEditingController(
    text: _draft.notes,
  );
  late final TextEditingController _location = TextEditingController(
    text: _draft.location,
  );
  late final TextEditingController _url = TextEditingController(
    text: _draft.taskUrl,
  );
  late final TextEditingController _categories = TextEditingController(
    text: _draft.categories.join(', '),
  );
  late bool _scheduledAllDay =
      _draft.microsoftDueTime == null && _draft.microsoftStartTime == null;
  bool _saving = false;
  bool _showValidation = false;
  final _titleFocus = FocusNode();
  final _formScroll = ScrollController();
  final _titleFieldKey = GlobalKey();
  final _urlFieldKey = GlobalKey();
  var _validationGeneration = 0;
  final _urlFocus = FocusNode();
  final _timingFeedbackKey = GlobalKey();
  late TaskEntity? _observedTask = widget.task;
  TaskEntity? _recoveryComparisonTask;
  bool _recoveryBaselineUnavailable = false;
  String? _recoveryOriginalBaseTitle;
  bool _allowPop = false;
  bool _recoveryLoaded = false;
  String? _recoverySourceKey;
  String? _pendingMoveDestinationId;
  List<_AndroidTaskEditorState> _hierarchyAncestors = const [];
  _TaskEditorNavigator? _editorNavigator;
  bool _hierarchyNavigationPending = false;
  bool _recoveryWritesBlocked = false;
  Future<void> _recoveryIo = Future.value();
  Timer? _recoveryTimer;
  late TaskDetailsDraft _initialDraft = _draft;
  late RecurrenceFrequency _recurrenceFrequency = _taskRecurrence().frequency;

  TaskCollectionCapabilities get _capabilities => switch (_provider) {
    BusyProvider.appleICloud || BusyProvider.nextcloud || BusyProvider.caldav =>
      ref
              .read(
                davTaskCollectionCapabilitiesProvider((
                  accountId: _accountId,
                  taskListId: _draft.taskListId,
                )),
              )
              .valueOrNull ??
          noTaskCollectionCapabilities,
    BusyProvider.google ||
    BusyProvider.microsoft => adapterDefaultTaskCapabilities(_provider),
    BusyProvider.webCal => noTaskCollectionCapabilities,
  };

  bool get _canWrite =>
      !_saving &&
      !_hierarchyNavigationPending &&
      _recoveryLoaded &&
      (widget.task == null
          ? _capabilities.canCreateTasks
          : _capabilities.canUpdateTasks);

  bool get _canNavigateHierarchy =>
      !_saving &&
      !_hierarchyNavigationPending &&
      _recoveryLoaded &&
      ModalRoute.of(context)?.isCurrent != false;

  bool get _hasDraftEdits => !_draft.hasSameValues(_initialDraft);

  bool get _hasPendingEdits =>
      _hasDraftEdits || _pendingMoveDestinationId != null;

  String get _recoveryKey => widget.task == null
      ? 'busymax.android.task-draft.v2.new.'
            '${base64Url.encode(utf8.encode(_creationIntentKey))}'
      : _taskRecoveryKey(_accountId, _initialDraft.taskListId, widget.task!.id);

  String get _creationIntentKey => _taskCreationIntentKey(
    widget.accountId,
    widget.creationList?.id ?? _initialDraft.taskListId,
    widget.provider,
    widget.initialDue,
  );

  @override
  void initState() {
    super.initState();
    unawaited(_restoreRecovery());
    _recoveryTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => unawaited(_persistRecovery()),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final sessions = _taskEditorNavigator(Navigator.of(context));
    if (!identical(_editorNavigator, sessions)) {
      _editorNavigator?.editors.remove(this);
      _editorNavigator = sessions;
      sessions.editors.add(this);
    }
    _hierarchyAncestors =
        context
            .dependOnInheritedWidgetOfExactType<_TaskHierarchyEditors>()
            ?.editors ??
        const [];
  }

  @override
  void dispose() {
    _editorNavigator?.editors.remove(this);
    _consentCancellation?.cancel();
    _recoveryTimer?.cancel();
    if (_recoveryLoaded && _hasPendingEdits && !_allowPop) {
      unawaited(_persistRecovery());
    }
    _formScroll.dispose();
    _titleFocus.dispose();
    _urlFocus.dispose();
    _title.dispose();
    _notes.dispose();
    _location.dispose();
    _url.dispose();
    _categories.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_provider.isDav) {
      ref.watch(
        davTaskCollectionCapabilitiesProvider((
          accountId: _accountId,
          taskListId: _draft.taskListId,
        )),
      );
    }
    final capabilities = _capabilities;
    final canWrite = _canWrite;
    ref.watch(scheduleTaskListsProvider);
    return PopScope<void>(
      canPop: _allowPop || (!_saving && !_hasPendingEdits),
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || _saving || _allowPop) return;
        if (await _confirmDiscardChanges() && mounted) {
          await _clearRecovery(finalCleanup: true);
          if (!mounted) return;
          setState(() => _allowPop = true);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) Navigator.pop(context);
          });
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            onPressed: _saving ? null : _requestClose,
            icon: const Icon(Icons.close),
          ),
          title: Text(
            widget.task == null ? context.l10n.newTask : context.l10n.editTask,
          ),
          actions: [
            TextButton(
              onPressed: _saving || !canWrite ? null : _save,
              child: Text(context.l10n.save),
            ),
          ],
        ),
        body: ListView(
          controller: _formScroll,
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.account_circle_outlined),
                title: Text(_taskListLabel(_draft.taskListId)),
                subtitle: Text(
                  (ref.watch(accountsStreamProvider).valueOrNull ?? [])
                          .where((a) => a.id == _accountId)
                          .firstOrNull
                          ?.selectorLabel ??
                      widget.accountLabel ??
                      _accountId,
                ),
                trailing: widget.task == null
                    ? const Icon(Icons.expand_more)
                    : null,
                onTap: widget.task == null && !_saving && _recoveryLoaded
                    ? _selectCreationDestination
                    : null,
              ),
            ),
            if (_provider == BusyProvider.google && widget.task != null)
              for (final link in widget.task!.googleSourceLinks)
                ListTile(
                  leading: const Icon(Icons.open_in_new),
                  title: Text(
                    link.label?.isNotEmpty == true
                        ? link.label!
                        : context.l10n.openInProvider,
                  ),
                  subtitle: Text(link.url),
                  onTap: () async {
                    if (!await openScheduleWebLink(link.url) &&
                        context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(context.l10n.eventLinkOpenFailed),
                        ),
                      );
                    }
                  },
                ),
            if (_provider.isDav &&
                widget.task != null &&
                (_observedTask ?? widget.task!).icalUid != null &&
                (_observedTask ?? widget.task!).davCollectionId != null)
              AndroidDavAttachmentsSection.task(
                target: (
                  accountId: _accountId,
                  taskListId: (_observedTask ?? widget.task!).taskListId,
                  taskId: (_observedTask ?? widget.task!).id,
                ),
              ),
            if (_provider == BusyProvider.microsoft && widget.task != null)
              Column(
                children: [
                  TextButton(
                    onPressed: () => setState(() {
                      final key = (
                        accountId: _accountId,
                        taskListId: _draft.taskListId,
                        taskId: (_observedTask?.id ?? widget.task!.id),
                      );
                      ref.invalidate(microsoftTaskLinkedResourcesProvider(key));
                      _linkedResourcesFuture = ref.read(
                        microsoftTaskLinkedResourcesProvider(key).future,
                      );
                    }),
                    child: Text(context.l10n.linkedResources),
                  ),
                  if (_linkedResourcesFuture case final future?)
                    FutureBuilder<List<TaskSourceLink>>(
                      future: future,
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Text(context.l10n.operationFailed);
                        }
                        if (!snapshot.hasData) {
                          return const LinearProgressIndicator();
                        }
                        if (snapshot.data!.isEmpty) {
                          return Text(context.l10n.noLinkedResources);
                        }
                        return Column(
                          children: [
                            for (final link in snapshot.data!)
                              ListTile(
                                leading: const Icon(Icons.open_in_new),
                                title: Text(
                                  link.label?.isNotEmpty == true
                                      ? link.label!
                                      : context.l10n.openInProvider,
                                ),
                                subtitle: Text(link.url),
                                onTap: () async {
                                  if (!await openScheduleWebLink(link.url) &&
                                      context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          context.l10n.eventLinkOpenFailed,
                                        ),
                                      ),
                                    );
                                  }
                                },
                              ),
                          ],
                        );
                      },
                    ),
                ],
              ),
            if (_provider == BusyProvider.microsoft && widget.task != null)
              Column(
                children: [
                  TextButton(
                    key: const Key('task-attachments-load'),
                    onPressed: () => setState(() {
                      final key = (
                        accountId: _accountId,
                        taskListId: _draft.taskListId,
                        taskId: (_observedTask?.id ?? widget.task!.id),
                      );
                      ref.invalidate(microsoftTaskAttachmentsProvider(key));
                      _attachmentsFuture = ref.read(
                        microsoftTaskAttachmentsProvider(key).future,
                      );
                    }),
                    child: Text(context.l10n.attachments),
                  ),
                  if (canWrite &&
                      !widget.task!.pendingDelete &&
                      !(_observedTask?.id ?? widget.task!.id).startsWith(
                        'local-task-',
                      ))
                    TextButton.icon(
                      onPressed:
                          _attachmentBusy ||
                              !ref
                                  .watch(attachmentUploadCoordinatorProvider)
                                  .canSubmit(
                                    AttachmentUploadCoordinator.taskKey(
                                      _accountId,
                                      _draft.taskListId,
                                      (_observedTask?.id ?? widget.task!.id),
                                    ),
                                  )
                          ? null
                          : _uploadTaskAttachment,
                      icon: const Icon(Icons.add),
                      label: Text(context.l10n.attachments),
                    ),
                  if (ref
                          .watch(attachmentUploadCoordinatorProvider)
                          .retryAfter(
                            AttachmentUploadCoordinator.taskKey(
                              _accountId,
                              _draft.taskListId,
                              (_observedTask?.id ?? widget.task!.id),
                            ),
                          ) !=
                      null)
                    Text(context.l10n.attachmentUploadRateLimited),
                  if (ref
                      .watch(attachmentUploadCoordinatorProvider)
                      .needsReconciliation(
                        AttachmentUploadCoordinator.taskKey(
                          _accountId,
                          _draft.taskListId,
                          (_observedTask?.id ?? widget.task!.id),
                        ),
                      )) ...[
                    Text(
                      ref
                                  .watch(attachmentUploadCoordinatorProvider)
                                  .confirmedId(
                                    AttachmentUploadCoordinator.taskKey(
                                      _accountId,
                                      _draft.taskListId,
                                      (_observedTask?.id ?? widget.task!.id),
                                    ),
                                  ) ==
                              null
                          ? context.l10n.attachmentUploadUnresolved
                          : context.l10n.completed,
                    ),
                    TextButton(
                      onPressed: _attachmentBusy ? null : _reconcileTaskUpload,
                      child: Text(context.l10n.refresh),
                    ),
                    if (ref
                        .watch(attachmentUploadCoordinatorProvider)
                        .hasResumableSession(
                          AttachmentUploadCoordinator.taskKey(
                            _accountId,
                            _draft.taskListId,
                            (_observedTask?.id ?? widget.task!.id),
                          ),
                        ))
                      TextButton(
                        onPressed: _attachmentBusy ? null : _cancelTaskUpload,
                        child: Text(context.l10n.cancel),
                      ),
                    if (ref
                        .watch(attachmentUploadCoordinatorProvider)
                        .canResolveManually(
                          AttachmentUploadCoordinator.taskKey(
                            _accountId,
                            _draft.taskListId,
                            (_observedTask?.id ?? widget.task!.id),
                          ),
                        )) ...[
                      TextButton(
                        onPressed: _attachmentBusy
                            ? null
                            : () => _resolveTaskUpload(exists: true),
                        child: Text(context.l10n.completed),
                      ),
                      TextButton(
                        onPressed: _attachmentBusy
                            ? null
                            : () => _resolveTaskUpload(exists: false),
                        child: Text(context.l10n.retry),
                      ),
                    ],
                  ],
                  if (_attachmentsFuture case final future?)
                    FutureBuilder<List<MicrosoftTodoAttachmentDto>>(
                      future: future,
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Text(context.l10n.attachmentsNotLoaded);
                        }
                        if (!snapshot.hasData) {
                          return const LinearProgressIndicator();
                        }
                        if (snapshot.data!.isEmpty) {
                          return Text(context.l10n.noneValue);
                        }
                        return Column(
                          children: [
                            for (final attachment in snapshot.data!)
                              ListTile(
                                leading: const Icon(Icons.attach_file),
                                title: Text(attachment.name),
                                subtitle: attachment.size == null
                                    ? null
                                    : Text('${attachment.size} B'),
                                trailing:
                                    canWrite &&
                                        !widget.task!.pendingDelete &&
                                        !(_observedTask?.id ?? widget.task!.id)
                                            .startsWith('local-task-')
                                    ? IconButton(
                                        tooltip: context.l10n.delete,
                                        onPressed: _attachmentBusy
                                            ? null
                                            : () => _deleteTaskAttachment(
                                                attachment,
                                              ),
                                        icon: const Icon(Icons.delete_outline),
                                      )
                                    : null,
                                onTap: attachment.isFile
                                    ? () => _downloadTaskAttachment(attachment)
                                    : null,
                              ),
                          ],
                        );
                      },
                    ),
                ],
              ),
            const SizedBox(height: 12),
            TextField(
              key: _titleFieldKey,
              controller: _title,
              focusNode: _titleFocus,
              enabled: canWrite,
              autofocus: widget.task == null,
              decoration: InputDecoration(
                labelText: context.l10n.title,
                errorText: _showValidation && _draft.title.trim().isEmpty
                    ? context.l10n.invalidCollectionValue
                    : null,
              ),
              onChanged: (v) =>
                  setState(() => _draft = _draft.copyWith(title: v)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notes,
              enabled:
                  canWrite &&
                  !(widget.task?.googleAssignment.isFromDocument ?? false),
              minLines: 3,
              maxLines: 8,
              decoration: InputDecoration(labelText: context.l10n.notes),
              onChanged: (v) =>
                  setState(() => _draft = _draft.copyWith(notes: v)),
            ),
            if (_showValidation &&
                _draft.scheduleIssueFor(capabilities) != TaskScheduleIssue.none)
              Padding(
                key: _timingFeedbackKey,
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  _draft.scheduleIssueFor(capabilities) ==
                          TaskScheduleIssue.dueBeforeStart
                      ? context.l10n.taskDueBeforeStart
                      : context.l10n.taskStartDueTimeModeMismatch,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (capabilities.supportsDueTime ||
                capabilities.supportsStartDateTime)
              SwitchListTile(
                title: Text(context.l10n.allDay),
                value: _scheduledAllDay,
                onChanged: !canWrite
                    ? null
                    : (allDay) => setState(() {
                        _scheduledAllDay = allDay;
                        _draft = _draft.copyWith(
                          microsoftDueTime: allDay
                              ? null
                              : _draft.dueDate == null
                              ? null
                              : _draft.microsoftDueTime ?? '09:00',
                          microsoftStartTime: allDay
                              ? null
                              : _draft.microsoftStartDate == null
                              ? null
                              : _draft.microsoftStartTime ?? '09:00',
                        );
                      }),
              ),
            if (capabilities.supportsDueDate)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event),
                title: Text(context.l10n.dueDate),
                subtitle: Text(_draft.dueDate ?? context.l10n.noDate),
                trailing: _draft.dueDate == null
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: !canWrite
                            ? null
                            : () => _clearScheduledDate(due: true),
                      ),
                enabled: canWrite,
                onTap: canWrite ? _pickDue : null,
              ),
            if (capabilities.supportsDueTime &&
                _draft.dueDate != null &&
                !_scheduledAllDay)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.schedule),
                title: Text(context.l10n.endTime),
                subtitle: Text(_draft.microsoftDueTime ?? context.l10n.allDay),
                enabled: canWrite,
                onTap: canWrite ? _pickDueTime : null,
              ),
            if (_draft.dueDate != null && _draft.microsoftDueTime != null)
              ListTile(
                leading: const Icon(Icons.public),
                title: Text(context.l10n.selectTimeZone),
                subtitle: Text(
                  _draft.microsoftDueTimeZone ??
                      ref.read(localTimeZoneProvider),
                ),
                onTap: !canWrite
                    ? null
                    : () async {
                        final zone = await showAndroidTimeZonePicker(
                          context,
                          _draft.microsoftDueTimeZone,
                        );
                        if (zone != null && mounted) {
                          setState(
                            () => _draft = _draft.copyWith(
                              microsoftDueTimeZone: zone,
                            ),
                          );
                        }
                      },
              ),
            if (capabilities.supportsStartDateTime)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.play_arrow_outlined),
                title: Text(context.l10n.startDate),
                subtitle: Text(
                  _draft.microsoftStartDate ?? context.l10n.noDate,
                ),
                trailing: _draft.microsoftStartDate == null
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: !canWrite
                            ? null
                            : () => _clearScheduledDate(due: false),
                      ),
                enabled: canWrite,
                onTap: canWrite ? _pickStartDate : null,
              ),
            if (capabilities.supportsStartDateTime &&
                _draft.microsoftStartDate != null &&
                !_scheduledAllDay)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.schedule),
                title: Text(context.l10n.startTime),
                subtitle: Text(
                  _draft.microsoftStartTime ?? context.l10n.allDay,
                ),
                enabled: canWrite,
                onTap: canWrite ? _pickStartTime : null,
              ),
            if (_draft.microsoftStartDate != null &&
                _draft.microsoftStartTime != null)
              ListTile(
                leading: const Icon(Icons.public),
                title: Text(context.l10n.selectTimeZone),
                subtitle: Text(
                  _draft.microsoftStartTimeZone ??
                      ref.read(localTimeZoneProvider),
                ),
                onTap: !canWrite
                    ? null
                    : () async {
                        final zone = await showAndroidTimeZonePicker(
                          context,
                          _draft.microsoftStartTimeZone,
                        );
                        if (zone != null && mounted) {
                          setState(
                            () => _draft = _draft.copyWith(
                              microsoftStartTimeZone: zone,
                            ),
                          );
                        }
                      },
              ),
            if (capabilities.supportsReminderDateTime &&
                !capabilities.supportsMultipleReminders)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(context.l10n.reminder),
                value: _draft.microsoftReminderEnabled,
                onChanged: !canWrite
                    ? null
                    : (value) => _setReminderEnabled(value),
              ),
            if (capabilities.supportsReminderDateTime &&
                !capabilities.supportsMultipleReminders &&
                _draft.microsoftReminderEnabled) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_outlined),
                title: Text(context.l10n.reminderDate),
                subtitle: Text(
                  _draft.microsoftReminderDate ?? context.l10n.noDate,
                ),
                enabled: canWrite,
                onTap: canWrite ? _pickReminderDate : null,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.alarm_outlined),
                title: Text(context.l10n.reminderTime),
                subtitle: Text(
                  _draft.microsoftReminderTime ?? context.l10n.noDate,
                ),
                enabled: canWrite,
                onTap: canWrite ? _pickReminderTime : null,
              ),
            ],
            if (capabilities.supportsReminderDateTime &&
                !capabilities.supportsMultipleReminders &&
                _draft.microsoftReminderEnabled)
              ListTile(
                leading: const Icon(Icons.public),
                title: Text(context.l10n.selectTimeZone),
                subtitle: Text(
                  _draft.microsoftReminderTimeZone ??
                      ref.read(localTimeZoneProvider),
                ),
                onTap: !canWrite
                    ? null
                    : () async {
                        final zone = await showAndroidTimeZonePicker(
                          context,
                          _draft.microsoftReminderTimeZone,
                        );
                        if (zone != null && mounted) {
                          setState(
                            () => _draft = _draft.copyWith(
                              microsoftReminderTimeZone: zone,
                            ),
                          );
                        }
                      },
              ),
            if (capabilities.supportsImportance &&
                !capabilities.supportsIcalPriority)
              DropdownButtonFormField<String>(
                initialValue: _draft.importance,
                decoration: InputDecoration(labelText: context.l10n.importance),
                items: [
                  DropdownMenuItem(
                    value: 'low',
                    child: Text(context.l10n.importanceLow),
                  ),
                  DropdownMenuItem(
                    value: 'normal',
                    child: Text(context.l10n.importanceNormal),
                  ),
                  DropdownMenuItem(
                    value: 'high',
                    child: Text(context.l10n.importanceHigh),
                  ),
                ],
                onChanged: !canWrite
                    ? null
                    : (v) => setState(
                        () => _draft = _draft.copyWith(importance: v),
                      ),
              ),
            if (capabilities.supportsIcalPriority)
              DropdownButtonFormField<int>(
                initialValue: _draft.icalPriority,
                decoration: InputDecoration(labelText: context.l10n.priority),
                items: [
                  for (var value = 0; value <= 9; value++)
                    DropdownMenuItem(
                      value: value,
                      child: Text(value == 0 ? '0 · —' : '$value'),
                    ),
                ],
                onChanged: !canWrite
                    ? null
                    : (value) => setState(
                        () => _draft = _draft.copyWith(icalPriority: value),
                      ),
              ),
            if (capabilities.supportsTaskStatus)
              DropdownButtonFormField<String?>(
                initialValue: _draft.taskStatus,
                decoration: InputDecoration(labelText: context.l10n.taskStatus),
                items: [
                  DropdownMenuItem(
                    value: null,
                    child: Text(context.l10n.repeatNone),
                  ),
                  DropdownMenuItem(
                    value: 'NEEDS-ACTION',
                    child: Text(context.l10n.taskStatusNeedsAction),
                  ),
                  DropdownMenuItem(
                    value: 'IN-PROCESS',
                    child: Text(context.l10n.taskStatusInProcess),
                  ),
                  DropdownMenuItem(
                    value: 'COMPLETED',
                    child: Text(context.l10n.taskStatusCompleted),
                  ),
                  DropdownMenuItem(
                    value: 'CANCELLED',
                    child: Text(context.l10n.taskStatusCancelled),
                  ),
                ],
                onChanged: !canWrite ? null : (value) => _setTaskStatus(value),
              ),
            if (capabilities.supportsRecurrence) ...[
              const SizedBox(height: 12),
              if (capabilities.supportsAdvancedRecurrence)
                ListTile(
                  key: const ValueKey('android-task-advanced-recurrence'),
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.repeat),
                  title: Text(context.l10n.repeat),
                  subtitle: Text(
                    _taskRecurrence().isSupported
                        ? recurrenceRuleSummary(
                            context,
                            _taskRecurrence(),
                            timeZone: _recurrenceReference?.timeZone,
                          )
                        : context.l10n.unsupportedRecurrencePreserved,
                  ),
                  trailing: Icon(
                    _taskRecurrence().isSupported
                        ? Icons.chevron_right
                        : Icons.lock_outline,
                  ),
                  enabled: canWrite && _taskRecurrence().isSupported,
                  onTap: canWrite && _taskRecurrence().isSupported
                      ? _editAdvancedRecurrence
                      : null,
                )
              else
                DropdownButtonFormField<RecurrenceFrequency>(
                  initialValue: _recurrenceFrequency,
                  decoration: InputDecoration(labelText: context.l10n.repeat),
                  items: [
                    for (final frequency in RecurrenceFrequency.values)
                      DropdownMenuItem(
                        value: frequency,
                        child: Text(_recurrenceLabel(context, frequency)),
                      ),
                  ],
                  onChanged: canWrite ? _setRecurrence : null,
                ),
            ],
            if (capabilities.supportsCategories) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _categories,
                enabled: canWrite,
                decoration: InputDecoration(labelText: context.l10n.categories),
                onChanged: (v) => setState(
                  () => _draft = _draft.copyWith(
                    categories: v
                        .split(',')
                        .map((e) => e.trim())
                        .where((e) => e.isNotEmpty)
                        .toList(),
                  ),
                ),
              ),
              if (_provider == BusyProvider.microsoft)
                _microsoftCategories(canWrite),
            ],
            if (capabilities.supportsLocation) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _location,
                enabled: canWrite,
                decoration: InputDecoration(labelText: context.l10n.location),
                onChanged: (v) =>
                    setState(() => _draft = _draft.copyWith(location: v)),
              ),
            ],
            if (capabilities.supportsUrl) ...[
              const SizedBox(height: 12),
              TextField(
                key: _urlFieldKey,
                controller: _url,
                focusNode: _urlFocus,
                enabled: canWrite,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  labelText: context.l10n.taskUrl,
                  errorText:
                      _showValidation &&
                          !_draft.hasValidTaskUrlFor(capabilities)
                      ? context.l10n.invalidTaskUrl
                      : null,
                ),
                onChanged: (value) =>
                    setState(() => _draft = _draft.copyWith(taskUrl: value)),
              ),
            ],
            if (capabilities.supportsClassification)
              DropdownButtonFormField<String>(
                initialValue: _draft.classification,
                decoration: InputDecoration(
                  labelText: context.l10n.classification,
                ),
                items: [
                  DropdownMenuItem(
                    value: 'PUBLIC',
                    child: Text(context.l10n.classificationPublic),
                  ),
                  DropdownMenuItem(
                    value: 'CONFIDENTIAL',
                    child: Text(context.l10n.classificationConfidential),
                  ),
                  DropdownMenuItem(
                    value: 'PRIVATE',
                    child: Text(context.l10n.classificationPrivate),
                  ),
                ],
                onChanged: !canWrite || !capabilities.canUpdateClassification
                    ? null
                    : (value) => setState(
                        () => _draft = _draft.copyWith(classification: value),
                      ),
              ),
            if (capabilities.supportsPinning)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(context.l10n.pinTask),
                value: _draft.pinned,
                onChanged: !canWrite
                    ? null
                    : (value) => setState(
                        () => _draft = _draft.copyWith(pinned: value),
                      ),
              ),
            if (capabilities.supportsSubtaskVisibility) ...[
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(context.l10n.hideSubtasks),
                value: _draft.hideSubtasks,
                onChanged: !canWrite
                    ? null
                    : (value) => setState(
                        () => _draft = _draft.copyWith(hideSubtasks: value),
                      ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(context.l10n.hideClosedSubtasks),
                value: _draft.hideCompletedSubtasks,
                onChanged: !canWrite
                    ? null
                    : (value) => setState(
                        () => _draft = _draft.copyWith(
                          hideCompletedSubtasks: value,
                        ),
                      ),
              ),
            ],
            if (capabilities.supportsMultipleReminders) ...[
              const Divider(height: 32),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.notifications_outlined),
                title: Text(context.l10n.reminderGroup),
                trailing: IconButton(
                  tooltip: context.l10n.addReminder,
                  onPressed: canWrite ? _addAlarm : null,
                  icon: const Icon(Icons.add),
                ),
              ),
              for (var index = 0; index < _draft.alarms.length; index++)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(_alarmLabel(_draft.alarms[index])),
                  onTap: canWrite && _canEditAlarm(_draft.alarms[index])
                      ? () => _addAlarm(index: index)
                      : null,
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: !canWrite
                        ? null
                        : () => setState(
                            () => _draft = _draft.copyWith(
                              alarms: [
                                for (var i = 0; i < _draft.alarms.length; i++)
                                  if (i != index) _draft.alarms[i],
                              ],
                            ),
                          ),
                  ),
                ),
            ],
            if (widget.task != null && capabilities.supportsDuplicate)
              OutlinedButton.icon(
                onPressed: _saving || !capabilities.canCreateTasks
                    ? null
                    : _duplicate,
                icon: const Icon(Icons.copy_outlined),
                label: Text(context.l10n.duplicateTask),
              ),
            if (widget.task != null && capabilities.supportsCrossListMove)
              OutlinedButton.icon(
                onPressed: _saving || !capabilities.canUpdateTasks
                    ? null
                    : _moveToList,
                icon: const Icon(Icons.drive_file_move_outline),
                label: Text(context.l10n.list),
              ),
            if (widget.task != null)
              OutlinedButton.icon(
                onPressed: _saving ? null : _export,
                icon: const Icon(Icons.file_download_outlined),
                label: Text(context.l10n.export),
              ),
            if (capabilities.supportsPercentComplete)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.l10n.completionPercent(_draft.percentComplete)),
                  Slider(
                    value: _draft.percentComplete.toDouble(),
                    max: 100,
                    divisions: 100,
                    onChanged: !canWrite
                        ? null
                        : (v) => _setTaskProgress(v.round()),
                  ),
                ],
              ),
            if (capabilities.supportsCompletedDateTime &&
                (_draft.taskStatus == 'COMPLETED' ||
                    _draft.percentComplete == 100 ||
                    _draft.completedDate != null)) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_available_outlined),
                title: Text(context.l10n.completionDate),
                subtitle: Text(_draft.completedDate ?? context.l10n.noDate),
                trailing: _draft.completedDate == null
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: canWrite ? _clearCompletionDate : null,
                      ),
                enabled: canWrite,
                onTap: canWrite ? _pickCompletionDate : null,
              ),
              if (_draft.completedDate != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.schedule),
                  title: Text(context.l10n.completed),
                  subtitle: Text(_draft.completedTime ?? context.l10n.noDate),
                  enabled: canWrite,
                  onTap: canWrite ? _pickCompletionTime : null,
                ),
            ],
            if (widget.task != null && capabilities.supportsTaskHierarchy) ...[
              const Divider(height: 32),
              StreamBuilder<TaskHierarchySnapshot>(
                stream: ref
                    .read(tasksRepositoryForAccountProvider(_accountId))
                    .watchTaskHierarchy(
                      _draft.taskListId,
                      (_observedTask?.id ?? widget.task!.id),
                    ),
                builder: (context, snapshot) => _taskHierarchySection(
                  snapshot.data ??
                      const TaskHierarchySnapshot(parent: null, subtasks: []),
                  capabilities,
                ),
              ),
            ],
            if (widget.task != null && capabilities.supportsTaskReparenting)
              OutlinedButton.icon(
                onPressed: _saving || !capabilities.canUpdateTasks
                    ? null
                    : _moveToTop,
                icon: const Icon(Icons.vertical_align_top),
                label: Text(context.l10n.moveToTop),
              ),
            if (widget.task != null && capabilities.canDeleteTasks) ...[
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: _saving ? null : _delete,
                icon: const Icon(Icons.delete_outline),
                label: Text(context.l10n.deleteTask),
              ),
            ],
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Future<void> _selectCreationDestination() async {
    final lists = await ref.read(scheduleTaskListsProvider.future);
    final accounts = await ref.read(accountsStreamProvider.future);
    if (!mounted) return;
    final allowed = <TaskListEntity>[];
    for (final list in lists) {
      final account = accounts.where((a) => a.id == list.accountId).firstOrNull;
      if (account == null) continue;
      final capabilities = account.provider.isDav
          ? await ref.read(
              davTaskCollectionCapabilitiesProvider((
                accountId: account.id,
                taskListId: list.id,
              )).future,
            )
          : adapterDefaultTaskCapabilities(account.provider);
      if (capabilities?.canCreateTasks == true) allowed.add(list);
    }
    if (!mounted) return;
    final selected = await selectAndroidTaskList(
      context,
      allowed,
      title: context.l10n.newTask,
      accountLabels: {
        for (final account in accounts) account.id: account.selectorLabel,
      },
    );
    if (selected == null || !mounted) return;
    final provider = accounts
        .firstWhere((a) => a.id == selected.accountId)
        .provider;
    setState(() {
      _creationAccountId = selected.accountId;
      _creationProvider = provider;
      _draft = _draft.copyWith(
        taskListId: selected.id,
        creationRecurrence: (provider: provider, rule: _taskRecurrence()),
      );
    });
    await _persistRecovery();
  }

  Future<void> _clearScheduledDate({required bool due}) async {
    final indexes = <int>{
      for (var i = 0; i < _draft.alarms.length; i++)
        if (_draft.alarms[i].relativeOffset != null &&
            _draft.alarms[i].isRelatedToDue == due)
          i,
    };
    var alarms = _draft.alarms;
    if (indexes.isNotEmpty) {
      final reference = _draft.reminderReferenceUtc(
        due: due,
        localTimeZone: ref.read(localTimeZoneProvider),
      );
      final keep = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Text(context.l10n.relatedRemindersTitle),
          content: Text(
            context.l10n.relatedRemindersDescription(indexes.length),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.l10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.l10n.discardRelatedReminders),
            ),
            FilledButton(
              onPressed: reference == null
                  ? null
                  : () => Navigator.pop(context, true),
              child: Text(context.l10n.keepRelatedReminders),
            ),
          ],
        ),
      );
      if (keep == null || !mounted) return;
      alarms = [
        for (var i = 0; i < alarms.length; i++)
          if (!indexes.contains(i))
            alarms[i]
          else if (keep)
            alarms[i].withAbsoluteTrigger(
              reference!.add(alarms[i].relativeOffset!),
            ),
      ];
    }
    final noOtherDate = due
        ? _draft.microsoftStartDate == null
        : _draft.dueDate == null;
    setState(
      () => _draft = due
          ? _draft.copyWith(
              dueDate: null,
              microsoftDueTime: null,
              recurrenceJson: noOtherDate ? null : _draft.recurrenceJson,
              creationRecurrence: noOtherDate
                  ? (provider: _provider, rule: const RecurrenceRule.none())
                  : _draft.creationRecurrence,
              alarms: alarms,
            )
          : _draft.copyWith(
              microsoftStartDate: null,
              microsoftStartTime: null,
              recurrenceJson: noOtherDate ? null : _draft.recurrenceJson,
              creationRecurrence: noOtherDate
                  ? (provider: _provider, rule: const RecurrenceRule.none())
                  : _draft.creationRecurrence,
              alarms: alarms,
            ),
    );
  }

  Future<void> _pickDue() async {
    if (!_canWrite) return;
    final current = DateTime.tryParse(_draft.dueDate ?? '') ?? DateTime.now();
    final value = await showBusyMaxDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(1970),
      lastDate: DateTime(2200),
    );
    if (value != null && mounted && _canWrite) {
      setState(
        () => _draft = _draft.copyWith(
          dueDate: _date(value),
          microsoftDueTime: !_scheduledAllDay && _capabilities.supportsDueTime
              ? _draft.microsoftDueTime ?? '09:00'
              : null,
        ),
      );
    }
  }

  Widget _taskHierarchySection(
    TaskHierarchySnapshot hierarchy,
    TaskCollectionCapabilities capabilities,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        context.l10n.subtasks,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      if (hierarchy.parent case final parent?)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.account_tree_outlined),
          title: Text(parent.title),
          subtitle: Text(context.l10n.parent),
          onTap: _canNavigateHierarchy
              ? () => _openHierarchyTask(parent)
              : null,
        ),
      for (final subtask in hierarchy.subtasks)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: IconButton(
            onPressed: _canWrite && capabilities.canUpdateTasks
                ? () => _toggleSubtask(subtask)
                : null,
            icon: AndroidTaskCompletionIcon(completed: subtask.completed),
          ),
          title: Text(subtask.title),
          trailing: subtask.kind == TaskSubtaskKind.checklistItem
              ? PopupMenuButton<String>(
                  key: ValueKey('android-checklist-actions-${subtask.id}'),
                  enabled: _canWrite && capabilities.canUpdateTasks,
                  onSelected: (action) {
                    if (action == 'edit') {
                      unawaited(_editChecklistSubtask(subtask));
                    }
                    if (action == 'delete') {
                      unawaited(_deleteChecklistSubtask(subtask));
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Text(context.l10n.rename),
                    ),
                    if (capabilities.canDeleteTasks)
                      PopupMenuItem(
                        value: 'delete',
                        child: Text(context.l10n.delete),
                      ),
                  ],
                )
              : subtask.hasChildren
              ? const Icon(Icons.account_tree_outlined)
              : null,
          onTap: !_canNavigateHierarchy || subtask.task == null
              ? null
              : () => _openHierarchyTask(subtask.task!),
        ),
      OutlinedButton.icon(
        onPressed:
            _canWrite &&
                capabilities.canCreateTasks &&
                !(widget.task?.googleAssignment.isAssigned ?? false)
            ? _createSubtask
            : null,
        icon: const Icon(Icons.add_task),
        label: Text(context.l10n.createSubtask),
      ),
    ],
  );

  bool _matchesTask(TaskEntity task) {
    final existing = _observedTask ?? widget.task;
    return mounted &&
        existing != null &&
        _accountId == task.accountId &&
        _draft.taskListId == task.taskListId &&
        (existing.matchesIdentity(task.id) ||
            task.matchesIdentity(existing.id));
  }

  String _taskListLabel(String taskListId) {
    final current = ref
        .read(scheduleTaskListsProvider)
        .valueOrNull
        ?.where((list) => list.accountId == _accountId && list.id == taskListId)
        .firstOrNull;
    if (current != null) return current.title;
    final originalListId = widget.task?.taskListId ?? widget.creationList?.id;
    return (taskListId == originalListId ? widget.listLabel : null) ??
        taskListId;
  }

  void _rebindMovedTask(TaskEntity task) {
    final oldRecoveryKey = _recoveryKey;
    final observed = _observedTask ?? widget.task!;
    final observedMetadata = observed.providerMetadataJson == null
        ? <String, Object?>{}
        : (jsonDecode(observed.providerMetadataJson!) as Map)
              .cast<String, Object?>();
    // Movement verifies identity and location, not a newer recurrence baseline.
    // Keep the dates/opaque metadata the user observed for their pending edit.
    final reboundMetadata = {
      ...observedMetadata,
      '_busymaxTaskIdAliases': {
        ...observed.identityIds,
        ...task.identityIds,
      }.where((id) => id != task.id).toList(),
      '_busymaxTaskPreviousListIds': {
        ...observed.previousTaskListIds,
        ...task.previousTaskListIds,
      }.toList(),
    };
    final rebound = TaskEntity.fromDraftBaselineJson({
      ...observed.toDraftBaselineJson(),
      'taskListId': task.taskListId,
      'id': task.id,
      'providerMetadataJson': jsonEncode(reboundMetadata),
    });
    setState(() {
      _observedTask = rebound;
      _draft = _draft.copyWith(
        taskListId: task.taskListId,
        taskId: task.id,
        observedTask: rebound,
      );
      _initialDraft = _initialDraft.copyWith(
        taskListId: task.taskListId,
        taskId: task.id,
      );
      _recoverySourceKey ??= oldRecoveryKey;
    });
    unawaited(_persistRecovery());
  }

  Future<void> _returnToEditor(_AndroidTaskEditorState target) async {
    if (!_canNavigateHierarchy) return;
    final editors = [..._hierarchyAncestors, this];
    final existingIndex = editors.indexOf(target);
    if (existingIndex < 0) return;
    final closing = editors.skip(existingIndex + 1).toList().reversed;
    if (closing.any((editor) => editor._saving || !editor._recoveryLoaded)) {
      return;
    }
    setState(() => _hierarchyNavigationPending = true);
    try {
      for (final editor in closing) {
        if (editor._hasPendingEdits && !await editor._confirmDiscardChanges()) {
          return;
        }
        if (!mounted || !editor.mounted || !target.mounted) return;
      }
      for (final editor in closing) {
        await editor._clearRecovery(finalCleanup: true);
        if (!mounted || !editor.mounted || !target.mounted) return;
        editor.setState(() => editor._allowPop = true);
      }
      if (!mounted || !target.mounted) return;
      final targetRoute = ModalRoute.of(target.context);
      Navigator.of(context).popUntil((route) => route == targetRoute);
    } finally {
      if (mounted) setState(() => _hierarchyNavigationPending = false);
    }
  }

  Future<void> _openHierarchyTask(TaskEntity task) async {
    if (!_canNavigateHierarchy) return;
    final editors = [..._hierarchyAncestors, this];
    final existing = editors
        .where((editor) => editor._matchesTask(task))
        .firstOrNull;
    if (existing != null) {
      await _returnToEditor(existing);
      return;
    }
    final sessions = _taskEditorNavigator(Navigator.of(context));
    final active = await _findTaskEditor(sessions, task);
    if (!mounted || !_canNavigateHierarchy) return;
    if (active != null) {
      await _revealTaskEditor(sessions, active);
      return;
    }
    setState(() => _hierarchyNavigationPending = true);
    final opening = _TaskEditorOpen(++sessions.generation)..task = task;
    for (final id in task.identityIds) {
      sessions.openings[_taskEditorKey(task.accountId, task.taskListId, id)] =
          opening;
    }
    try {
      final result = Navigator.of(context).push<AndroidTaskEditorResult>(
        MaterialPageRoute<AndroidTaskEditorResult>(
          fullscreenDialog: true,
          builder: (_) => _TaskHierarchyEditors(
            editors: editors,
            child: AndroidTaskEditor(
              accountId: _accountId,
              provider: _provider,
              task: task,
              accountLabel: widget.accountLabel,
              listLabel: _taskListLabel(task.taskListId),
              onMutationStarted: widget.onMutationStarted,
              onMutationCommitted: widget.onMutationCommitted,
              onMutationFailed: widget.onMutationFailed,
            ),
          ),
        ),
      );
      opening.result = result;
      await result;
    } finally {
      sessions.openings.removeWhere(
        (_, candidate) => identical(candidate, opening),
      );
      if (mounted) setState(() => _hierarchyNavigationPending = false);
    }
  }

  Future<void> _toggleSubtask(TaskSubtaskEntity subtask) async {
    if (!_canWrite) return;
    setState(() => _saving = true);
    try {
      final repository = ref.read(
        tasksRepositoryForAccountProvider(_accountId),
      );
      if (subtask.kind == TaskSubtaskKind.checklistItem) {
        await repository.patchChecklistSubtask(
          taskListId: _draft.taskListId,
          parentTaskId: (_observedTask?.id ?? widget.task!.id),
          checklistItemId: subtask.id,
          observedItem: subtask.checklistItem,
          completed: !subtask.completed,
        );
      } else {
        await repository.patchTask(
          _draft.taskListId,
          subtask.id,
          TaskPatchInput.completion(
            !subtask.completed,
            includeCompletedTimestamp: false,
            observedOccurrenceKey: subtask.task?.occurrenceKey,
          ),
        );
      }
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is TaskOccurrenceChangedException
                  ? context.l10n.taskDraftConflict
                  : '$error',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _editChecklistSubtask(TaskSubtaskEntity subtask) async {
    if (!_canWrite) return;
    final controller = TextEditingController(text: subtask.title);
    var busy = false;
    String? error;
    final route = DialogRoute<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> save() async {
            if (busy) return;
            final title = controller.text.trim();
            if (title.isEmpty) {
              setDialogState(() => error = context.l10n.invalidCollectionValue);
              return;
            }
            setDialogState(() {
              busy = true;
              error = null;
            });
            setState(() => _saving = true);
            try {
              await ref
                  .read(tasksRepositoryForAccountProvider(_accountId))
                  .patchChecklistSubtask(
                    taskListId: _draft.taskListId,
                    parentTaskId: _observedTask?.id ?? widget.task!.id,
                    checklistItemId: subtask.id,
                    observedItem: subtask.checklistItem,
                    title: title,
                  );
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            } on Object catch (failure) {
              if (dialogContext.mounted) {
                setDialogState(() {
                  busy = false;
                  error = '$failure';
                });
              }
            } finally {
              if (mounted) setState(() => _saving = false);
            }
          }

          return PopScope<void>(
            canPop: !busy,
            child: AlertDialog(
              title: Text(context.l10n.rename),
              content: TextField(
                key: const ValueKey('android-checklist-title'),
                controller: controller,
                autofocus: true,
                enabled: !busy,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: context.l10n.title,
                  errorText: error,
                ),
                onSubmitted: (_) => unawaited(save()),
              ),
              actions: [
                TextButton(
                  onPressed: busy ? null : () => Navigator.pop(dialogContext),
                  child: Text(context.l10n.cancel),
                ),
                FilledButton(
                  onPressed: busy ? null : save,
                  child: Text(context.l10n.save),
                ),
              ],
            ),
          );
        },
      ),
    );
    await Navigator.of(context, rootNavigator: true).push(route);
    await route.completed;
    controller.dispose();
  }

  Future<void> _deleteChecklistSubtask(TaskSubtaskEntity subtask) async {
    if (!_canWrite) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.delete),
        content: Text(context.l10n.deleteTaskConfirmation(subtask.title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || !_canWrite) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(tasksRepositoryForAccountProvider(_accountId))
          .deleteChecklistSubtask(
            taskListId: _draft.taskListId,
            parentTaskId: _observedTask?.id ?? widget.task!.id,
            checklistItemId: subtask.id,
            observedItem: subtask.checklistItem,
          );
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _createSubtask() async {
    if (!_canWrite) return;
    if (widget.task?.googleAssignment.isAssigned ?? false) return;
    final controller = TextEditingController();
    final route = DialogRoute<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.createSubtask),
        content: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(labelText: context.l10n.title),
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) Navigator.pop(dialogContext, value);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(dialogContext, controller.text);
              }
            },
            child: Text(context.l10n.create),
          ),
        ],
      ),
    );
    final title = await Navigator.of(context, rootNavigator: true).push(route);
    await route.completed;
    controller.dispose();
    if (title == null || !mounted || !_canWrite) return;
    try {
      await ref
          .read(tasksRepositoryForAccountProvider(_accountId))
          .createSubtask(
            taskListId: _draft.taskListId,
            parentTaskId: (_observedTask?.id ?? widget.task!.id),
            title: title,
          );
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  Future<void> _pickDueTime() async {
    if (!_canWrite) return;
    final parts = (_draft.microsoftDueTime ?? '09:00').split(':');
    final value = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      ),
    );
    if (value != null && mounted && _canWrite) {
      setState(
        () => _draft = _draft.copyWith(
          microsoftDueTime:
              '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}',
        ),
      );
    }
  }

  Future<void> _pickStartDate() async {
    if (!_canWrite) return;
    final current =
        DateTime.tryParse(_draft.microsoftStartDate ?? '') ?? DateTime.now();
    final value = await showBusyMaxDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(1970),
      lastDate: DateTime(2200),
    );
    if (value != null && mounted && _canWrite) {
      setState(
        () => _draft = _draft.copyWith(
          microsoftStartDate: _date(value),
          microsoftStartTime: _scheduledAllDay
              ? null
              : _draft.microsoftStartTime ?? '09:00',
        ),
      );
    }
  }

  Future<void> _pickStartTime() async {
    if (!_canWrite) return;
    final value = await _pickTime(_draft.microsoftStartTime);
    if (value != null && mounted && _canWrite) {
      setState(() => _draft = _draft.copyWith(microsoftStartTime: value));
    }
  }

  void _setReminderEnabled(bool enabled) {
    final String zone =
        _draft.microsoftReminderTimeZone ?? ref.read(localTimeZoneProvider);
    final value = TaskDetailsDraft.newReminderDefault(
      dueDate: _draft.dueDate,
      timeZone: zone,
      now: DateTime.now(),
    );
    setState(
      () => _draft = _draft.copyWith(
        microsoftReminderEnabled: enabled,
        microsoftReminderDate: enabled ? _date(value) : null,
        microsoftReminderTime: enabled ? _clock(value) : null,
        microsoftReminderTimeZone: zone,
      ),
    );
  }

  Future<void> _pickReminderDate() async {
    if (!_canWrite) return;
    final current =
        DateTime.tryParse(_draft.microsoftReminderDate ?? '') ?? DateTime.now();
    final value = await showBusyMaxDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(1970),
      lastDate: DateTime(2200),
    );
    if (value != null && mounted && _canWrite) {
      setState(
        () => _draft = _draft.copyWith(microsoftReminderDate: _date(value)),
      );
    }
  }

  Future<void> _pickReminderTime() async {
    if (!_canWrite) return;
    final value = await _pickTime(_draft.microsoftReminderTime);
    if (value != null && mounted && _canWrite) {
      setState(() => _draft = _draft.copyWith(microsoftReminderTime: value));
    }
  }

  Future<String?> _pickTime(String? current) async {
    final parts = (current ?? '09:00').split(':');
    final value = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.tryParse(parts.first) ?? 9,
        minute: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
      ),
    );
    return value == null
        ? null
        : '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  }

  void _setTaskStatus(String? status) {
    final now = DateTime.now();
    setState(() {
      _draft = switch (status) {
        'COMPLETED' => _draft.copyWith(
          taskStatus: status,
          percentComplete: 100,
          completedDate: _draft.completedDate ?? _date(now),
          completedTime: _draft.completedTime ?? _clock(now),
        ),
        'IN-PROCESS' => _draft.copyWith(
          taskStatus: status,
          percentComplete: _draft.percentComplete == 0
              ? 1
              : _draft.percentComplete == 100
              ? 99
              : _draft.percentComplete,
          completedDate: null,
          completedTime: null,
        ),
        'NEEDS-ACTION' || null => _draft.copyWith(
          taskStatus: status,
          percentComplete: _draft.percentComplete == 100
              ? 99
              : _draft.percentComplete,
          completedDate: null,
          completedTime: null,
        ),
        'CANCELLED' => _draft.copyWith(taskStatus: status),
        _ => _draft,
      };
    });
  }

  void _setTaskProgress(int percent) {
    final now = DateTime.now();
    setState(() {
      _draft = switch (percent.clamp(0, 100)) {
        100 => _draft.copyWith(
          percentComplete: 100,
          taskStatus: 'COMPLETED',
          completedDate: _draft.completedDate ?? _date(now),
          completedTime: _draft.completedTime ?? _clock(now),
        ),
        0 => _draft.copyWith(
          percentComplete: 0,
          taskStatus: 'NEEDS-ACTION',
          completedDate: null,
          completedTime: null,
        ),
        final value => _draft.copyWith(
          percentComplete: value,
          taskStatus: 'IN-PROCESS',
          completedDate: null,
          completedTime: null,
        ),
      };
    });
  }

  Future<void> _pickCompletionDate() async {
    if (!_canWrite) return;
    final current =
        DateTime.tryParse(_draft.completedDate ?? '') ?? DateTime.now();
    final value = await showBusyMaxDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(1970),
      lastDate: DateTime(2200),
    );
    if (value == null || !mounted || !_canWrite) return;
    setState(
      () => _draft = _draft.copyWith(
        completedDate: _date(value),
        completedTime: _draft.completedTime ?? _clock(DateTime.now()),
        percentComplete: 100,
        taskStatus: 'COMPLETED',
      ),
    );
  }

  Future<void> _pickCompletionTime() async {
    if (!_canWrite) return;
    final value = await _pickTime(_draft.completedTime);
    if (value != null && mounted && _canWrite) {
      setState(() => _draft = _draft.copyWith(completedTime: value));
    }
  }

  void _clearCompletionDate() => setState(
    () => _draft = _draft.copyWith(
      completedDate: null,
      completedTime: null,
      percentComplete: _draft.percentComplete == 100
          ? 99
          : _draft.percentComplete,
      taskStatus: _draft.percentComplete == 100
          ? 'IN-PROCESS'
          : _draft.taskStatus,
    ),
  );

  Future<void> _addAlarm({int? index}) async {
    if (!_canWrite) return;
    final initialAlarm = index == null ? null : _draft.alarms[index];
    final mode = initialAlarm != null
        ? initialAlarm.absoluteUtc != null
              ? 'absolute'
              : initialAlarm.isRelatedToDue
              ? 'due'
              : 'start'
        : await showModalBottomSheet<String>(
            context: context,
            showDragHandle: true,
            builder: (sheetContext) => SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.event_outlined),
                    title: Text(context.l10n.absoluteReminder),
                    onTap: () => Navigator.pop(sheetContext, 'absolute'),
                  ),
                  if (_draft.microsoftStartDate != null)
                    ListTile(
                      leading: const Icon(Icons.play_arrow_outlined),
                      title: Text(context.l10n.beforeTaskStarts),
                      onTap: () => Navigator.pop(sheetContext, 'start'),
                    ),
                  if (_draft.dueDate != null)
                    ListTile(
                      leading: const Icon(Icons.flag_outlined),
                      title: Text(context.l10n.beforeTaskDue),
                      onTap: () => Navigator.pop(sheetContext, 'due'),
                    ),
                ],
              ),
            ),
          );
    if (mode == null || !mounted || !_canWrite) return;
    IcalTaskAlarm? alarm;
    if (mode == 'absolute') {
      final initial =
          initialAlarm?.absoluteUtc?.toLocal() ??
          DateTime.now().add(const Duration(minutes: 10));
      final date = await showBusyMaxDatePicker(
        context: context,
        initialDate: initial,
        firstDate: DateTime(1970),
        lastDate: DateTime(2200),
      );
      if (date == null || !mounted || !_canWrite) return;
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(initial),
      );
      if (time == null || !mounted || !_canWrite) return;
      alarm = IcalTaskAlarm.displayAbsolute(
        DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        ).toUtc(),
      );
    } else {
      final allDay =
          _draft.microsoftDueTime == null && _draft.microsoftStartTime == null;
      final selection =
          await showDialog<({int amount, String unit, TimeOfDay? time})>(
            context: context,
            builder: (_) => _AndroidRelativeAlarmDialog(
              allDay: allDay,
              initialOffset: initialAlarm?.relativeOffset,
            ),
          );
      if (selection == null || !mounted || !_canWrite) return;
      final duration = allDay
          ? IcalAllDayAlarmOffset(
              amount: selection.amount,
              unit: selection.unit == 'weeks'
                  ? IcalAllDayAlarmUnit.weeks
                  : IcalAllDayAlarmUnit.days,
              hour: selection.time?.hour ?? 9,
              minute: selection.time?.minute ?? 0,
            ).toDuration()
          : -switch (selection.unit) {
              'weeks' => Duration(days: selection.amount * 7),
              'days' => Duration(days: selection.amount),
              'hours' => Duration(hours: selection.amount),
              _ => Duration(minutes: selection.amount),
            };
      alarm = IcalTaskAlarm.displayRelative(
        duration,
        relatedToDue: mode == 'due',
      );
    }
    setState(
      () => _draft = _draft.copyWith(
        alarms: index == null
            ? [..._draft.alarms, alarm!]
            : [
                for (var i = 0; i < _draft.alarms.length; i++)
                  i == index
                      ? (alarm!.absoluteUtc != null
                            ? _draft.alarms[i].withAbsoluteTrigger(
                                alarm.absoluteUtc!,
                              )
                            : _draft.alarms[i].withRelativeTrigger(
                                alarm.relativeOffset!,
                                relatedToDue: alarm.isRelatedToDue,
                              ))
                      : _draft.alarms[i],
              ],
      ),
    );
  }

  bool _canEditAlarm(IcalTaskAlarm alarm) =>
      alarm.absoluteUtc != null ||
      (alarm.relativeOffset != null &&
          alarm.relativeOffset! <=
              (_scheduledAllDay ? const Duration(days: 1) : Duration.zero));

  String _alarmLabel(IcalTaskAlarm alarm) => taskAlarmLabel(context, alarm);

  Widget _microsoftCategories(bool canWrite) {
    final catalog = ref.watch(microsoftMasterCategoriesProvider(_accountId));
    return catalog.when(
      loading: () => const LinearProgressIndicator(),
      error: (_, _) => TextButton(
        onPressed: () async {
          _consentCancellation?.cancel();
          final consent = AuthorizationCancellation();
          _consentCancellation = consent;
          try {
            try {
              await ref
                  .read(microsoftCategoryAuthorizationProvider)
                  ?.authorizeCategoryAccess(_accountId, cancellation: consent);
              if (!mounted || consent.isCancelled) return;
              if (mounted) {
                ref.invalidate(microsoftMasterCategoriesProvider(_accountId));
              }
            } on Object {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(context.l10n.outlookCategoriesUnavailable),
                  ),
                );
              }
            }
          } finally {
            consent.cancel();
            if (identical(_consentCancellation, consent)) {
              _consentCancellation = null;
            }
          }
        },
        child: Text(context.l10n.loadOutlookCategories),
      ),
      data: (categories) => Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          for (final category in categories)
            FilterChip(
              label: Text(category.displayName),
              avatar: microsoftCategorySwatchArgb(category.color) == null
                  ? null
                  : CircleAvatar(
                      backgroundColor: Color(
                        microsoftCategorySwatchArgb(category.color)!,
                      ),
                      radius: 7,
                    ),
              selected: _draft.categories.contains(category.displayName),
              onSelected: !canWrite
                  ? null
                  : (selected) {
                      final values = [..._draft.categories];
                      if (selected) {
                        if (!values.contains(category.displayName)) {
                          values.add(category.displayName);
                        }
                      } else {
                        values.remove(category.displayName);
                      }
                      setState(() {
                        _categories.text = values.join(', ');
                        _draft = _draft.copyWith(categories: values);
                      });
                    },
            ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (!_canWrite) return;
    if (_pendingMoveDestinationId != null) {
      await _moveToList(retryPending: true);
      return;
    }
    if (_draft.hasNewPastReminder(
      original: widget.task,
      capabilities: _capabilities,
      localTimeZone: ref.read(localTimeZoneProvider),
      now: DateTime.now(),
    )) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.reminderTimeInPast)));
      return;
    }
    setState(_syncDraftFromControllers);
    if (!_validateDraft()) return;
    if (_recoveryBaselineUnavailable && _hasDraftEdits) {
      _showRecoveryBaselineReview();
      return;
    }
    setState(() => _saving = true);
    final existing = widget.task;
    final pendingResult = existing == null
        ? null
        : AndroidTaskEditorResult(
            action: AndroidTaskEditorAction.updated,
            accountId: _accountId,
            taskListId: _draft.taskListId,
            taskId: existing.id,
            completed: _draftCompletion,
            occurrenceKey: _observedTask?.occurrenceKey,
          );
    if (pendingResult != null) {
      widget.onMutationStarted?.call(pendingResult);
    }
    var mutationPersisted = false;
    try {
      final taskId = await _persistTaskDraft();
      mutationPersisted = true;
      final result = AndroidTaskEditorResult(
        action: pendingResult?.action ?? AndroidTaskEditorAction.created,
        accountId: _accountId,
        taskListId: _draft.taskListId,
        taskId: taskId,
        completed: pendingResult?.completed,
        occurrenceKey: pendingResult?.occurrenceKey,
      );
      widget.onMutationCommitted?.call(result);
      if (mounted) {
        await _clearRecovery(finalCleanup: true);
        if (!mounted) return;
        setState(() => _allowPop = true);
        Navigator.pop(context, result);
      }
    } on Object catch (error) {
      if (pendingResult != null && !mutationPersisted) {
        widget.onMutationFailed?.call();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_taskMutationError(error)),
            action:
                error is TaskDraftConflictException && !error.current.localDirty
                ? SnackBarAction(
                    label: context.l10n.keepServerVersion,
                    onPressed: () => unawaited(_useLatestTask()),
                  )
                : null,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showRecoveryBaselineReview() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.taskDraftConflict),
        action: SnackBarAction(
          label: context.l10n.keepServerVersion,
          onPressed: () => unawaited(_useLatestTask()),
        ),
      ),
    );
  }

  Future<void> _useLatestTask() async {
    if (!_canWrite ||
        !await _confirmDiscardChanges() ||
        !mounted ||
        !_canWrite) {
      return;
    }
    setState(() => _saving = true);
    try {
      final latest = await ref
          .read(tasksRepositoryForAccountProvider(_accountId))
          .readTask(_draft.taskListId, _draft.taskId);
      if (!mounted) return;
      if (latest == null || latest.localDirty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              latest == null
                  ? context.l10n.taskUnavailableDraftRetained
                  : context.l10n.taskDraftConflict,
            ),
          ),
        );
        return;
      }
      setState(() {
        _observedTask = latest;
        _recoveryComparisonTask = null;
        _recoveryBaselineUnavailable = false;
        _recoveryOriginalBaseTitle = null;
        _draft = TaskDetailsDraft.fromTask(
          latest,
          ref.read(localTimeZoneProvider),
        );
        _initialDraft = _draft;
        _pendingMoveDestinationId = null;
        _showValidation = false;
        _recurrenceFrequency = _taskRecurrence().frequency;
        _syncControllersFromDraft();
      });
      await _clearRecovery();
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_taskMutationError(error))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _taskMutationError(Object error) => switch (error) {
    TaskDraftConflictException() ||
    TaskOccurrenceChangedException() => context.l10n.taskDraftConflict,
    DavException(code: 'DavTaskDurationRequiresStart') =>
      context.l10n.taskDurationRequiresStart,
    _ => '$error',
  };

  bool? get _draftCompletion {
    final original = widget.task;
    if (original == null) return null;
    final originalCompleted =
        original.status?.toLowerCase() == 'completed' ||
        original.status?.toUpperCase() == 'COMPLETED' ||
        original.percentComplete == 100;
    final completed =
        _draft.taskStatus?.toUpperCase() == 'COMPLETED' ||
        _draft.percentComplete == 100;
    return completed == originalCompleted ? null : completed;
  }

  void _syncControllersFromDraft() {
    _title.text = _draft.title;
    _notes.text = _draft.notes;
    _location.text = _draft.location;
    _url.text = _draft.taskUrl;
    _categories.text = _draft.categories.join(', ');
  }

  void _syncDraftFromControllers() {
    _draft = _draft.copyWith(
      title: _title.text,
      notes: _notes.text,
      location: _location.text,
      taskUrl: _url.text,
      // Keep category values containing commas when their display is unchanged.
      categories: _categories.text == _draft.categories.join(', ')
          ? _draft.categories
          : _categories.text
                .split(',')
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .toList(),
    );
  }

  bool get _draftIsValid =>
      _draft.title.trim().isNotEmpty &&
      _draft.hasValidTaskUrlFor(_capabilities) &&
      _draft.scheduleIssueFor(_capabilities) == TaskScheduleIssue.none;

  bool _validateDraft() {
    if (_draftIsValid) return true;
    setState(() => _showValidation = true);
    if (_draft.title.trim().isEmpty) {
      unawaited(_revealInvalidField(_titleFieldKey, _titleFocus));
    } else if (!_draft.hasValidTaskUrlFor(_capabilities)) {
      unawaited(_revealInvalidField(_urlFieldKey, _urlFocus));
    } else {
      unawaited(_revealInvalidField(_timingFeedbackKey, null));
    }
    return false;
  }

  Future<void> _revealInvalidField(GlobalKey key, FocusNode? focus) async {
    final generation = ++_validationGeneration;
    bool active() => mounted && !_saving && generation == _validationGeneration;
    await WidgetsBinding.instance.endOfFrame;
    if (!active() || !_formScroll.hasClients) return;
    if (key.currentContext == null) {
      _formScroll.jumpTo(0);
      await WidgetsBinding.instance.endOfFrame;
    }
    // The form lazily builds its fields. Walk the bounded editor until the
    // invalid field is mounted, then use its real geometry to reveal it.
    for (
      var attempt = 0;
      attempt < 40 && active() && key.currentContext == null;
      attempt++
    ) {
      final position = _formScroll.position;
      final next = (position.pixels + 400)
          .clamp(0, position.maxScrollExtent)
          .toDouble();
      if (next <= position.pixels) break;
      _formScroll.jumpTo(next);
      await WidgetsBinding.instance.endOfFrame;
    }
    if (!active()) return;
    final field = key.currentContext;
    if (field != null && field.mounted) {
      await Scrollable.ensureVisible(
        field,
        alignment: 0.1,
        duration: const Duration(milliseconds: 150),
      );
      if (active()) focus?.requestFocus();
    }
  }

  Future<String> _persistTaskDraft() async {
    final changed = widget.task == null
        ? null
        : _draft.toPatch(
            _observedTask!,
            _capabilities,
            localTimeZone: ref.read(localTimeZoneProvider),
          );
    if ((_draft.microsoftReminderEnabled || _draft.alarms.isNotEmpty) &&
        (changed == null ||
            changed.containsKey('microsoftReminderDateTime') ||
            changed.containsKey('taskAlarmsJson'))) {
      final notifications = ref.read(androidNotificationServiceProvider);
      final granted = await notifications.requestNotificationPermission();
      final readiness = notifications.readiness.value;
      if ((!granted || !readiness.remindersReady) && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              !granted ||
                      readiness.notificationsAllowed == false ||
                      readiness.remindersAllowed == false
                  ? context.l10n.notificationsBlocked
                  : context.l10n.notificationsUnknown,
            ),
            action: SnackBarAction(
              label: context.l10n.settingsSystem,
              onPressed: () =>
                  BusyMaxAndroidPlatform.instance.openNotificationSettings(),
            ),
          ),
        );
      }
    }
    final repository = ref.read(tasksRepositoryForAccountProvider(_accountId));
    if (widget.task == null) {
      final id = await repository.createTask(
        _draft.taskListId,
        _draft.toCreateInput(
          _capabilities,
          localTimeZone: ref.read(localTimeZoneProvider),
        ),
      );
      unawaited(
        ref
            .read(appSettingsControllerProvider.notifier)
            .rememberTaskList(
              CreationDestination(accountId: _accountId, id: _draft.taskListId),
            ),
      );
      return id;
    }
    await repository.patchTask(
      _draft.taskListId,
      _draft.taskId,
      TaskPatchInput(
        _draft.toPatch(
          _observedTask!,
          _capabilities,
          localTimeZone: ref.read(localTimeZoneProvider),
        ),
        observedTask: _observedTask,
        observedOccurrenceKey:
            changed!.keys.any(
              const {
                'status',
                'completed',
                'taskStatus',
                'percentComplete',
                'completedAtUtc',
              }.contains,
            )
            ? _observedTask?.occurrenceKey
            : null,
      ),
    );
    final committed = await repository.readTask(
      _draft.taskListId,
      _draft.taskId,
    );
    if (committed != null) {
      _observedTask = committed;
      _draft = TaskDetailsDraft.fromTask(
        committed,
        ref.read(localTimeZoneProvider),
      );
      _syncControllersFromDraft();
      _recoveryComparisonTask = null;
      _recoveryBaselineUnavailable = false;
      _recoveryOriginalBaseTitle = null;
      _initialDraft = _draft;
    }
    return committed?.id ?? (_observedTask?.id ?? widget.task!.id);
  }

  RecurrenceRule _taskRecurrence() {
    final creation = _draft.creationRecurrence;
    if (creation != null) return creation.rule;
    final raw = _draft.recurrenceJson;
    if (raw == null) return const RecurrenceRule.none();
    try {
      return EventRecurrenceCodec.decode(
        _provider,
        jsonDecode(raw),
        baseDate: _provider.isDav
            ? _recurrenceReference?.dateTime
            : DateTime.tryParse(_draft.dueDate ?? ''),
      );
    } on Object {
      return const RecurrenceRule.none();
    }
  }

  void _setRecurrence(RecurrenceFrequency? frequency) {
    if (frequency == null) return;
    final base = DateTime.tryParse(_draft.dueDate ?? '') ?? DateTime.now();
    final rule = _simpleTaskRecurrenceRule(frequency, base);
    _applyRecurrence(rule, base);
  }

  TaskRecurrenceReference? get _recurrenceReference =>
      taskDraftRecurrenceReference(
        _draft,
        localTimeZone: ref.read(localTimeZoneProvider),
      );

  Future<void> _editAdvancedRecurrence() async {
    if (!_canWrite) return;
    final initial = _taskRecurrence();
    if (!initial.isSupported) return;
    final reference = _recurrenceReference;
    final base = reference?.dateTime ?? DateTime.now();
    final result = await showAndroidRecurrenceDialog(
      context,
      initial: initial,
      baseDate: base,
      allDay: reference?.allDay ?? true,
      floating: reference?.floating ?? false,
      timeZone: reference?.timeZone,
      limits: EventRecurrenceCodec.limitsFor(_provider),
      providerLabel: _provider.displayName,
    );
    if (result != null &&
        mounted &&
        _canWrite &&
        result.toJsonString() != initial.toJsonString()) {
      _applyRecurrence(result, base);
    }
  }

  void _applyRecurrence(RecurrenceRule rule, DateTime base) {
    setState(() {
      _recurrenceFrequency = rule.frequency;
      if (widget.task == null) {
        _draft = _draft.copyWith(
          creationRecurrence: (provider: _provider, rule: rule),
        );
      } else {
        final encoded = rule.repeats
            ? EventRecurrenceCodec.encode(
                _provider,
                rule,
                baseDate: base,
                allDay: _recurrenceReference?.allDay ?? true,
                timeZone: _recurrenceReference?.timeZone,
                original: _draft.recurrenceJson == null
                    ? null
                    : jsonDecode(_draft.recurrenceJson!),
              )
            : null;
        _draft = _draft.copyWith(
          recurrenceJson: encoded == null ? null : jsonEncode(encoded),
        );
      }
    });
  }

  Future<void> _delete() async {
    if (!_canWrite) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.deleteTask),
        content: Text(
          widget.task!.googleAssignment.isAssigned
              ? '${context.l10n.deleteTaskConfirmation(widget.task!.title)}\n\n${context.l10n.deleteAssignedTaskWarning}'
              : context.l10n.deleteTaskConfirmation(widget.task!.title),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || !_canWrite) return;
    setState(() => _saving = true);
    final result = AndroidTaskEditorResult(
      action: AndroidTaskEditorAction.deleted,
      accountId: _accountId,
      taskListId: _draft.taskListId,
      taskId: (_observedTask?.id ?? widget.task!.id),
    );
    widget.onMutationStarted?.call(result);
    var mutationPersisted = false;
    try {
      await ref
          .read(tasksRepositoryForAccountProvider(_accountId))
          .deleteTask(
            _draft.taskListId,
            (_observedTask?.id ?? widget.task!.id),
            confirmedAssignedSourceDeletion:
                widget.task!.googleAssignment.isAssigned,
          );
      mutationPersisted = true;
      widget.onMutationCommitted?.call(result);
      if (mounted) {
        await _clearRecovery(finalCleanup: true);
        if (!mounted) return;
        setState(() => _allowPop = true);
        Navigator.pop(context, result);
      }
    } on Object catch (error) {
      if (!mutationPersisted) widget.onMutationFailed?.call();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _duplicate() async {
    if (!_canWrite) return;
    setState(() => _saving = true);
    try {
      final repository = ref.read(
        tasksRepositoryForAccountProvider(_accountId),
      );
      final taskId = _observedTask?.id ?? widget.task!.id;
      final needsConsent = await repository
          .taskDuplicationRequiresSchedulingConsent(_draft.taskListId, taskId);
      if (!mounted) return;
      final allowed =
          !needsConsent ||
          await showDialog<bool>(
                context: context,
                builder: (dialog) => AlertDialog(
                  title: Text(context.l10n.duplicateTask),
                  content: Text(
                    context.l10n.caldavTaskDuplicationSchedulingWarning,
                  ),
                  actions: [
                    TextButton(
                      autofocus: true,
                      onPressed: () => Navigator.pop(dialog, false),
                      child: Text(context.l10n.cancel),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(dialog, true),
                      child: Text(context.l10n.duplicateTask),
                    ),
                  ],
                ),
              ) ==
              true;
      if (!allowed ||
          !mounted ||
          !_capabilities.canCreateTasks ||
          !_recoveryLoaded ||
          _hierarchyNavigationPending ||
          taskId != (_observedTask?.id ?? widget.task!.id)) {
        return;
      }
      final duplicateId = await ref
          .read(tasksRepositoryForAccountProvider(_accountId))
          .duplicateTask(
            _draft.taskListId,
            (_observedTask?.id ?? widget.task!.id),
            allowScheduling: needsConsent && allowed,
          );
      widget.onMutationCommitted?.call(
        AndroidTaskEditorResult(
          action: AndroidTaskEditorAction.created,
          accountId: _accountId,
          taskListId: _draft.taskListId,
          taskId: duplicateId,
        ),
      );
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.l10n.duplicateTask)));
      }
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _moveToList({bool retryPending = false}) async {
    if (!_canWrite) return;
    late final List<TaskListEntity> lists;
    try {
      lists =
          (await ref
                  .read(taskListsRepositoryForAccountProvider(_accountId))
                  .listTaskLists())
              .where(
                (list) =>
                    list.id != _draft.taskListId ||
                    (!retryPending && _pendingMoveDestinationId != null),
              )
              .toList();
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
      }
      return;
    }
    if (!mounted || !_canWrite || lists.isEmpty) return;
    final previousDestination = lists
        .where((list) => list.id == _pendingMoveDestinationId)
        .firstOrNull;
    final destination =
        (retryPending ? previousDestination : null) ??
        await selectAndroidTaskList(
          context,
          lists,
          title: context.l10n.list,
          alwaysPrompt: !retryPending && _pendingMoveDestinationId != null,
          accountLabels: {_accountId: widget.accountLabel ?? _accountId},
        );
    if (destination == null || !mounted || !_canWrite) return;
    if (destination.id == _draft.taskListId) {
      setState(() => _pendingMoveDestinationId = null);
      if (_hasDraftEdits) {
        await _persistRecovery();
      } else {
        await _clearRecovery();
      }
      return;
    }
    setState(_syncDraftFromControllers);
    var saveEdits = false;
    if (_hasDraftEdits) {
      final decision = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: Text(context.l10n.discardChanges),
          content: Text(context.l10n.discardChangesConfirmation),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(context.l10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(context.l10n.discardChangesAction),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(context.l10n.save),
            ),
          ],
        ),
      );
      if (decision == null || !mounted) return;
      saveEdits = decision;
      if (saveEdits && !_validateDraft()) return;
      if (saveEdits && _recoveryBaselineUnavailable) {
        _showRecoveryBaselineReview();
        return;
      }
    }
    setState(() {
      _pendingMoveDestinationId = destination.id;
      _saving = true;
    });
    final result = AndroidTaskEditorResult(
      action: AndroidTaskEditorAction.moved,
      accountId: _accountId,
      taskListId: destination.id,
      taskId: (_observedTask?.id ?? widget.task!.id),
      previousTaskListId: _draft.taskListId,
    );
    widget.onMutationStarted?.call(result);
    var mutationPersisted = false;
    var patchPersisted = false;
    try {
      final repository = ref.read(
        tasksRepositoryForAccountProvider(_accountId),
      );
      if (saveEdits) {
        await _persistTaskDraft();
        patchPersisted = true;
        await _persistRecovery();
      }
      await repository.moveTask(
        TaskMoveInput(
          sourceTaskListId: _draft.taskListId,
          destinationTaskListId: destination.id,
          taskId: (_observedTask?.id ?? widget.task!.id),
        ),
      );
      mutationPersisted = true;
      final committedResult = AndroidTaskEditorResult(
        action: result.action,
        accountId: result.accountId,
        taskListId: result.taskListId,
        taskId: _observedTask?.id ?? result.taskId,
        previousTaskListId: result.previousTaskListId,
      );
      widget.onMutationCommitted?.call(committedResult);
      await _clearRecovery(finalCleanup: true);
      if (!mounted) return;
      setState(() => _allowPop = true);
      Navigator.pop(context, committedResult);
    } on Object catch (error) {
      if (!mutationPersisted) widget.onMutationFailed?.call();
      await _persistRecovery();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              patchPersisted
                  ? context.l10n.taskMoveAfterSaveFailed
                  : _taskMutationError(error),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _moveToTop() async {
    if (!_canWrite) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(tasksRepositoryForAccountProvider(_accountId))
          .moveTask(
            TaskMoveInput(
              sourceTaskListId: _draft.taskListId,
              taskId: (_observedTask?.id ?? widget.task!.id),
            ),
          );
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.l10n.moveToTop)));
      }
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _uploadTaskAttachment() async {
    final task = widget.task;
    if (task == null ||
        task.pendingDelete ||
        task.id.startsWith('local-task-')) {
      return;
    }
    final document = await BusyMaxAndroidPlatform.instance.openDocument(
      mimeTypes: const ['*/*'],
      maximumBytes: 25 * 1024 * 1024,
    );
    if (document == null || !mounted) return;
    final name = safeAttachmentFileName(document.name ?? '');
    if (name == null) {
      _attachmentError(const FormatException('Invalid attachment name.'));
      return;
    }
    setState(() => _attachmentBusy = true);
    try {
      final client = ref.read(
        microsoftTodoApiClientForAccountProvider(_accountId),
      );
      if (client is! MicrosoftTodoAttachmentsApiClient) {
        throw StateError('Microsoft task attachments are unavailable.');
      }
      await ref
          .read(attachmentUploadCoordinatorProvider)
          .uploadTask(
            client: client as MicrosoftTodoAttachmentsApiClient,
            accountId: _accountId,
            taskListId: task.taskListId,
            taskId: task.id,
            name: name,
            contentType: document.mimeType ?? 'application/octet-stream',
            bytes: document.bytes,
          );
      _reloadTaskAttachments();
    } on Object catch (error) {
      _reloadTaskAttachments();
      _attachmentError(error);
    } finally {
      if (mounted) setState(() => _attachmentBusy = false);
    }
  }

  Future<void> _reconcileTaskUpload() async {
    final task = widget.task;
    if (task == null) return;
    setState(() => _attachmentBusy = true);
    try {
      final client = ref.read(
        microsoftTodoApiClientForAccountProvider(_accountId),
      );
      if (client is! MicrosoftTodoAttachmentsApiClient) return;
      await ref
          .read(attachmentUploadCoordinatorProvider)
          .reconcileTask(
            client: client as MicrosoftTodoAttachmentsApiClient,
            accountId: _accountId,
            taskListId: task.taskListId,
            taskId: task.id,
          );
      _reloadTaskAttachments();
    } on Object catch (error) {
      _attachmentError(error);
    } finally {
      if (mounted) setState(() => _attachmentBusy = false);
    }
  }

  Future<void> _cancelTaskUpload() async {
    final task = widget.task;
    if (task == null) return;
    setState(() => _attachmentBusy = true);
    try {
      final client = ref.read(
        microsoftTodoApiClientForAccountProvider(_accountId),
      );
      if (client is! MicrosoftTodoAttachmentsApiClient) return;
      await ref
          .read(attachmentUploadCoordinatorProvider)
          .cancelTask(
            client: client as MicrosoftTodoAttachmentsApiClient,
            accountId: _accountId,
            taskListId: task.taskListId,
            taskId: task.id,
          );
      _reloadTaskAttachments();
    } on Object catch (error) {
      _attachmentError(error);
    } finally {
      if (mounted) setState(() => _attachmentBusy = false);
    }
  }

  Future<void> _resolveTaskUpload({required bool exists}) async {
    final task = widget.task;
    if (task == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(exists ? context.l10n.completed : context.l10n.retry),
        content: Text(context.l10n.attachmentUploadUnresolved),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(exists ? context.l10n.completed : context.l10n.retry),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    ref
        .read(attachmentUploadCoordinatorProvider)
        .resolveUncertainManually(
          AttachmentUploadCoordinator.taskKey(
            _accountId,
            task.taskListId,
            task.id,
          ),
          exists: exists,
        );
    _reloadTaskAttachments();
  }

  Future<void> _deleteTaskAttachment(
    MicrosoftTodoAttachmentDto attachment,
  ) async {
    final task = widget.task;
    if (task == null ||
        task.pendingDelete ||
        task.id.startsWith('local-task-')) {
      return;
    }
    setState(() => _attachmentBusy = true);
    try {
      final client = ref.read(
        microsoftTodoApiClientForAccountProvider(_accountId),
      );
      if (client is! MicrosoftTodoAttachmentsApiClient) {
        throw StateError('Microsoft task attachments are unavailable.');
      }
      await (client as MicrosoftTodoAttachmentsApiClient).deleteTaskAttachment(
        taskListId: task.taskListId,
        taskId: task.id,
        attachmentId: attachment.id,
      );
      ref
          .read(attachmentUploadCoordinatorProvider)
          .attachmentRemoved(
            AttachmentUploadCoordinator.taskKey(
              _accountId,
              task.taskListId,
              task.id,
            ),
            attachment.id,
          );
      _reloadTaskAttachments();
    } on Object catch (error) {
      _attachmentError(error);
    } finally {
      if (mounted) setState(() => _attachmentBusy = false);
    }
  }

  void _reloadTaskAttachments() {
    final task = widget.task;
    if (task == null) return;
    final key = (
      accountId: _accountId,
      taskListId: task.taskListId,
      taskId: task.id,
    );
    ref.invalidate(microsoftTaskAttachmentsProvider(key));
    final future = ref.read(microsoftTaskAttachmentsProvider(key).future);
    if (mounted) {
      setState(() {
        _attachmentsFuture = future;
      });
    }
  }

  void _attachmentError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.exportFailed('$error'))),
    );
  }

  Future<void> _downloadTaskAttachment(
    MicrosoftTodoAttachmentDto attachment,
  ) async {
    final task = widget.task;
    final name = safeAttachmentFileName(attachment.name);
    if (task == null || !attachment.isFile || name == null) return;
    try {
      final client = ref.read(
        microsoftTodoApiClientForAccountProvider(_accountId),
      );
      if (client is! MicrosoftTodoAttachmentsApiClient) {
        throw StateError('Microsoft task attachments are unavailable.');
      }
      final bytes = await (client as MicrosoftTodoAttachmentsApiClient)
          .downloadTaskAttachment(
            taskListId: task.taskListId,
            taskId: task.id,
            attachmentId: attachment.id,
          );
      await BusyMaxAndroidPlatform.instance.createDocument(
        suggestedName: name,
        mimeType: attachment.contentType ?? 'application/octet-stream',
        bytes: Uint8List.fromList(bytes),
      );
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.exportFailed('$error'))),
        );
      }
    }
  }

  Future<void> _export() async {
    try {
      var raw = await ref
          .read(tasksRepositoryForAccountProvider(_accountId))
          .nativeTaskExport(
            _draft.taskListId,
            (_observedTask?.id ?? widget.task!.id),
          );
      if (raw == null) {
        final tasks = await ref
            .read(scheduleRepositoryProvider)
            .listAllTasks(
              filters: ScheduleFilters(
                accountIds: {_accountId},
                includeCalendarEvents: false,
                taskCompletion: ScheduleTaskCompletion.all,
              ),
            );
        final item = tasks
            .where(
              (t) =>
                  t.id == (_observedTask?.id ?? widget.task!.id) &&
                  t.sourceId == _draft.taskListId,
            )
            .firstOrNull;
        if (item == null) return;
        raw = scheduleItemToICalendar(item, nowUtc: DateTime.now().toUtc());
      }
      await BusyMaxAndroidPlatform.instance.createDocument(
        suggestedName: 'task.ics',
        mimeType: 'text/calendar',
        bytes: Uint8List.fromList(utf8.encode(raw)),
      );
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.exportFailed('$error'))),
        );
      }
    }
  }

  Future<void> _requestClose() async {
    if (_saving) return;
    if (!_hasPendingEdits || await _confirmDiscardChanges()) {
      if (!mounted) return;
      await _clearRecovery(finalCleanup: true);
      if (!mounted) return;
      setState(() => _allowPop = true);
      Navigator.pop(context);
    }
  }

  Future<bool> _confirmDiscardChanges() async =>
      await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: Text(context.l10n.discardChanges),
          content: Text(context.l10n.discardChangesConfirmation),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(context.l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(context.l10n.discardChangesAction),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _restoreRecovery() async {
    try {
      final storage = ref.read(secureStorageProvider);
      String? raw;
      String? recoverySourceKey;
      final keys = <String>{_recoveryKey};
      final task = widget.task;
      if (task != null) {
        for (final listId in [task.taskListId, ...task.previousTaskListIds]) {
          for (final identity in task.identityIds) {
            keys.add(_taskRecoveryKey(_accountId, listId, identity));
          }
        }
        // Existing v2 records used an account/task key. Their payload still
        // has the list scope, so only a verified scope may claim that record.
        for (final identity in task.identityIds) {
          keys.add('busymax.android.task-draft.$_accountId.$identity');
        }
      } else if (widget.initialDue == null) {
        keys.add(
          'busymax.android.task-draft.$_accountId.'
          'new-${_initialDraft.taskListId}',
        );
      }
      for (final key in keys) {
        final candidate = await storage.read(key: key);
        if (candidate == null) continue;
        final Object? value;
        try {
          value = jsonDecode(candidate);
        } on FormatException {
          continue;
        }
        if (value is! Map) continue;
        final listId = value['taskListId'];
        final scopeMatches = task == null
            ? listId == _initialDraft.taskListId
            : listId == task.taskListId ||
                  task.previousTaskListIds.contains(listId);
        if (value['accountId'] != _accountId ||
            !scopeMatches ||
            (task != null &&
                value['taskId'] != null &&
                !task.matchesIdentity(value['taskId'].toString()))) {
          // Another list may legitimately contain the same provider ID. It
          // keeps both its draft and ownership of its original recovery key.
          continue;
        }
        if (task != null && listId != task.taskListId && listId is String) {
          final source = await ref
              .read(tasksRepositoryForAccountProvider(_accountId))
              .readTask(listId, value['taskId']?.toString() ?? task.id);
          if (source != null) continue;
        }
        if (candidate.isNotEmpty) {
          raw = candidate;
          recoverySourceKey = key;
          break;
        }
      }
      if (raw == null) return;
      final value = jsonDecode(raw);
      if (value is! Map) return;
      final map = value.cast<String, Object?>();
      final savedAt = DateTime.tryParse(map['savedAt']?.toString() ?? '');
      if (savedAt == null ||
          DateTime.now().difference(savedAt).abs() > const Duration(days: 14) ||
          map['v'] != 2 ||
          map['accountId'] != _accountId ||
          (widget.task == null &&
              map['taskListId'] != _initialDraft.taskListId) ||
          (widget.task != null &&
              map['taskId'] != null &&
              !widget.task!.matchesIdentity(map['taskId'].toString()))) {
        await _clearRecovery(sourceKey: recoverySourceKey);
        return;
      }
      TaskEntity? recoveredObserved;
      final rawObserved = map['observedTask'];
      final recoveryBaselineUnavailable =
          widget.task != null && rawObserved is! Map;
      final recoveryOriginalBaseTitle = map['baseTitle'] as String?;
      if (widget.task != null && rawObserved is Map) {
        recoveredObserved = TaskEntity.fromDraftBaselineJson(
          rawObserved.cast<String, Object?>(),
        );
        if (recoveredObserved.accountId != _accountId ||
            !widget.task!.matchesIdentity(recoveredObserved.id)) {
          await _clearRecovery(sourceKey: recoverySourceKey);
          return;
        }
      }
      final rawComparison = map['originalObservedTask'];
      final recoveryComparisonTask = rawComparison is Map
          ? TaskEntity.fromDraftBaselineJson(
              rawComparison.cast<String, Object?>(),
            )
          : recoveredObserved;
      final currentValues = _recoveryValues(_draft);
      final baselineValues = recoveredObserved == null
          ? {...currentValues, 'title': map['baseTitle']}
          : _recoveryValues(
              TaskDetailsDraft.fromTask(
                recoveredObserved,
                ref.read(localTimeZoneProvider),
              ),
            );
      final restoredValues = <String, Object?>{...currentValues};
      for (final key in currentValues.keys) {
        if (map.containsKey(key) &&
            jsonEncode(map[key]) != jsonEncode(baselineValues[key])) {
          restoredValues[key] = map[key];
        }
      }
      if (recoveredObserved != null && widget.task != null) {
        final original = recoveredObserved.toDraftBaselineJson();
        final composed = widget.task!.toDraftBaselineJson();
        for (final field in ['rawJson', 'etag', 'updatedUtc']) {
          composed[field] = original[field];
        }
        const groups = <String, List<String>>{
          'title': ['title'],
          'notes': ['notes', 'bodyContent', 'bodyContentType'],
          'dueDate': ['dueUtc', 'microsoftDueDateTime', 'microsoftDueTimeZone'],
          'dueTime': ['dueUtc', 'microsoftDueDateTime', 'microsoftDueTimeZone'],
          'dueTimeZone': [
            'dueUtc',
            'microsoftDueDateTime',
            'microsoftDueTimeZone',
          ],
          'startDate': ['microsoftStartDateTime', 'microsoftStartTimeZone'],
          'startTime': ['microsoftStartDateTime', 'microsoftStartTimeZone'],
          'startTimeZone': ['microsoftStartDateTime', 'microsoftStartTimeZone'],
          'reminderEnabled': [
            'microsoftIsReminderOn',
            'microsoftReminderDateTime',
            'microsoftReminderTimeZone',
          ],
          'reminderDate': [
            'microsoftIsReminderOn',
            'microsoftReminderDateTime',
            'microsoftReminderTimeZone',
          ],
          'reminderTime': [
            'microsoftIsReminderOn',
            'microsoftReminderDateTime',
            'microsoftReminderTimeZone',
          ],
          'reminderTimeZone': [
            'microsoftIsReminderOn',
            'microsoftReminderDateTime',
            'microsoftReminderTimeZone',
          ],
          'recurrenceJson': ['recurrenceJson'],
          'importance': ['importance'],
          'categories': ['categoriesJson'],
          'icalPriority': ['icalPriority'],
          'percentComplete': [
            'percentComplete',
            'providerStatus',
            'status',
            'completedUtc',
          ],
          'taskStatus': [
            'percentComplete',
            'providerStatus',
            'status',
            'completedUtc',
          ],
          'completedDate': [
            'percentComplete',
            'providerStatus',
            'status',
            'completedUtc',
          ],
          'completedTime': [
            'percentComplete',
            'providerStatus',
            'status',
            'completedUtc',
          ],
          'location': ['taskLocation', 'locationLatitude', 'locationLongitude'],
          'taskUrl': ['taskUrl'],
          'classification': ['taskClassification'],
          'pinned': ['taskPinned'],
          'hideSubtasks': ['taskHideSubtasks'],
          'hideCompletedSubtasks': ['taskHideCompletedSubtasks'],
          'alarms': ['taskAlarmsJson'],
        };
        for (final entry in groups.entries) {
          if (map.containsKey(entry.key) &&
              jsonEncode(map[entry.key]) !=
                  jsonEncode(baselineValues[entry.key])) {
            for (final field in entry.value) {
              composed[field] = original[field];
            }
          }
        }
        recoveredObserved = TaskEntity.fromDraftBaselineJson(composed);
      }
      final recoveredConcurrentState =
          widget.task != null &&
          (map['baseTitle'] != _initialDraft.title ||
              map['taskListId'] != _initialDraft.taskListId ||
              (recoveredObserved != null &&
                  jsonEncode(baselineValues) != jsonEncode(currentValues)));
      final values = widget.task == null ? map : restoredValues;
      final alarms = <IcalTaskAlarm>[];
      for (final rawAlarm in values['alarms'] as List? ?? const []) {
        if (rawAlarm is Map) {
          alarms.add(IcalTaskAlarm.fromJson(rawAlarm.cast<String, Object?>()));
        }
      }
      final recoveredAccountId = widget.task == null
          ? map['destinationAccountId']?.toString() ?? widget.accountId
          : _accountId;
      final recoveredProvider = widget.task == null
          ? BusyProvider.values
                    .where((p) => p.name == map['destinationProvider'])
                    .firstOrNull ??
                widget.provider
          : _provider;
      var recovered = _draft.copyWith(
        taskListId: widget.task == null
            ? map['destinationTaskListId']?.toString() ??
                  _initialDraft.taskListId
            : _draft.taskListId,
        observedTask: recoveredObserved ?? _observedTask,
        title: values['title']?.toString() ?? _draft.title,
        notes: values['notes']?.toString() ?? _draft.notes,
        dueDate: values['dueDate'],
        microsoftDueTime: values['dueTime'],
        microsoftDueTimeZone: values['dueTimeZone']?.toString(),
        microsoftStartDate: values['startDate'],
        microsoftStartTime: values['startTime'],
        microsoftStartTimeZone: values['startTimeZone']?.toString(),
        microsoftReminderEnabled:
            values['reminderEnabled'] as bool? ??
            _draft.microsoftReminderEnabled,
        microsoftReminderDate: values['reminderDate'],
        microsoftReminderTime: values['reminderTime'],
        microsoftReminderTimeZone: values['reminderTimeZone']?.toString(),
        recurrenceJson: values['recurrenceJson'],
        importance: values['importance']?.toString(),
        categories: (values['categories'] as List? ?? const [])
            .map((value) => value.toString())
            .toList(),
        icalPriority: values['icalPriority'] as int?,
        percentComplete: values['percentComplete'] as int?,
        taskStatus: values['taskStatus'],
        completedDate: values['completedDate'],
        completedTime: values['completedTime'],
        location: values['location']?.toString(),
        taskUrl: values['taskUrl']?.toString(),
        classification: values['classification']?.toString(),
        pinned: values['pinned'] as bool?,
        hideSubtasks: values['hideSubtasks'] as bool?,
        hideCompletedSubtasks: values['hideCompletedSubtasks'] as bool?,
        alarms: alarms,
      );
      RecurrenceRule? creationRule;
      final rawCreationRecurrence = map['creationRecurrence'];
      if (widget.task == null && rawCreationRecurrence is Map) {
        final raw = rawCreationRecurrence;
        final creation = raw.cast<String, Object?>();
        final provider = BusyProvider.values
            .where((value) => value.name == creation['provider'])
            .firstOrNull;
        final base =
            DateTime.tryParse(recovered.dueDate ?? '') ?? DateTime.now();
        creationRule = RecurrenceRule.fromJson(
          creation['rule']?.toString(),
          baseDate: base,
        );
        if (provider != recoveredProvider || !creationRule.isSupported) {
          await _clearRecovery(sourceKey: recoverySourceKey);
          return;
        }
        recovered = recovered.copyWith(
          creationRecurrence: (provider: provider!, rule: creationRule),
        );
      }
      if (!mounted) return;
      final pendingMoveDestinationId =
          map['pendingMoveDestinationId'] as String?;
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      final recover = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: Text(context.l10n.discardChanges),
          content: Text(
            recoveredConcurrentState
                ? context.l10n.taskDraftConflict
                : context.l10n.discardChangesConfirmation,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(context.l10n.discardChangesAction),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(context.l10n.nextcloudRestore),
            ),
          ],
        ),
      );
      if (recover != true) {
        await _clearRecovery(sourceKey: recoverySourceKey);
        return;
      }
      if (!mounted) return;
      setState(() {
        _creationAccountId = recoveredAccountId;
        _creationProvider = recoveredProvider;
        _recoverySourceKey = recoverySourceKey;
        _recoveryBaselineUnavailable = recoveryBaselineUnavailable;
        _recoveryOriginalBaseTitle = recoveryOriginalBaseTitle;
        _recoveryComparisonTask = recoveryComparisonTask;
        _observedTask = recoveredObserved ?? _observedTask;
        _pendingMoveDestinationId = pendingMoveDestinationId;
        if (_pendingMoveDestinationId == recovered.taskListId) {
          _pendingMoveDestinationId = null;
        }
        _draft = recovered;
        _scheduledAllDay =
            map['scheduledAllDay'] as bool? ??
            (recovered.microsoftDueTime == null &&
                recovered.microsoftStartTime == null);
        _recurrenceFrequency =
            creationRule?.frequency ?? _taskRecurrence().frequency;
        _syncControllersFromDraft();
      });
    } on Object {
      // A malformed/locked recovery entry must never block the editor.
    } finally {
      if (mounted) {
        setState(() => _recoveryLoaded = true);
      } else {
        _recoveryLoaded = true;
      }
    }
  }

  Map<String, Object?> _recoveryValues(TaskDetailsDraft draft) => {
    'title': draft.title,
    'notes': draft.notes,
    'dueDate': draft.dueDate,
    'dueTime': draft.microsoftDueTime,
    'dueTimeZone': draft.microsoftDueTimeZone,
    'startDate': draft.microsoftStartDate,
    'startTime': draft.microsoftStartTime,
    'startTimeZone': draft.microsoftStartTimeZone,
    'reminderEnabled': draft.microsoftReminderEnabled,
    'reminderDate': draft.microsoftReminderDate,
    'reminderTime': draft.microsoftReminderTime,
    'reminderTimeZone': draft.microsoftReminderTimeZone,
    'recurrenceJson': draft.recurrenceJson,
    'importance': draft.importance,
    'categories': draft.categories,
    'icalPriority': draft.icalPriority,
    'percentComplete': draft.percentComplete,
    'taskStatus': draft.taskStatus,
    'completedDate': draft.completedDate,
    'completedTime': draft.completedTime,
    'location': draft.location,
    'taskUrl': draft.taskUrl,
    'classification': draft.classification,
    'pinned': draft.pinned,
    'hideSubtasks': draft.hideSubtasks,
    'hideCompletedSubtasks': draft.hideCompletedSubtasks,
    'alarms': [for (final alarm in draft.alarms) alarm.toJson()],
  };

  Future<void> _persistRecovery() async {
    if (!_recoveryLoaded ||
        !_hasPendingEdits ||
        _allowPop ||
        _recoveryWritesBlocked) {
      return;
    }
    final creationRecurrence = _draft.creationRecurrence;
    final recoveryKey = _recoveryKey;
    final recoverySourceKey = _recoverySourceKey;
    final payload = jsonEncode({
      'v': 2,
      'scheduledAllDay': _scheduledAllDay,
      'savedAt': DateTime.now().toIso8601String(),
      'baseTitle': _recoveryBaselineUnavailable
          ? _recoveryOriginalBaseTitle ?? _initialDraft.title
          : _observedTask?.title ?? _initialDraft.title,
      'accountId': widget.task == null ? widget.accountId : _accountId,
      'taskListId': widget.task == null
          ? _initialDraft.taskListId
          : _draft.taskListId,
      if (widget.task == null) ...{
        'destinationAccountId': _accountId,
        'destinationProvider': _provider.name,
        'destinationTaskListId': _draft.taskListId,
      },
      if (_pendingMoveDestinationId != null)
        'pendingMoveDestinationId': _pendingMoveDestinationId,
      ..._recoveryValues(_draft),
      if (creationRecurrence != null)
        'creationRecurrence': {
          'provider': creationRecurrence.provider.name,
          'rule': creationRecurrence.rule.toJsonString(),
        },
      if (_observedTask != null && !_recoveryBaselineUnavailable)
        'observedTask': _observedTask!.toDraftBaselineJson(),
      if (_recoveryComparisonTask != null)
        'originalObservedTask': _recoveryComparisonTask!.toDraftBaselineJson(),
      if (widget.task != null) 'taskId': _observedTask?.id ?? widget.task!.id,
    });
    await _enqueueRecovery(() async {
      if (_recoveryWritesBlocked) return;
      await ref
          .read(secureStorageProvider)
          .write(key: recoveryKey, value: payload);
      if (recoverySourceKey != null && recoverySourceKey != recoveryKey) {
        await ref.read(secureStorageProvider).delete(key: recoverySourceKey);
      }
    });
  }

  Future<void> _clearRecovery({bool finalCleanup = false, String? sourceKey}) {
    final recoveryKey = _recoveryKey;
    final recoverySourceKey = sourceKey ?? _recoverySourceKey;
    if (finalCleanup) {
      _recoveryWritesBlocked = true;
      _recoveryTimer?.cancel();
    }
    return _enqueueRecovery(() async {
      await ref.read(secureStorageProvider).delete(key: recoveryKey);
      if (recoverySourceKey != null && recoverySourceKey != recoveryKey) {
        await ref.read(secureStorageProvider).delete(key: recoverySourceKey);
      }
    });
  }

  Future<void> _enqueueRecovery(Future<void> Function() operation) {
    final result = _recoveryIo.then((_) => operation());
    _recoveryIo = result.catchError((_) {});
    return result.catchError((_) {});
  }
}

class _AndroidRelativeAlarmDialog extends StatefulWidget {
  const _AndroidRelativeAlarmDialog({required this.allDay, this.initialOffset});

  final bool allDay;
  final Duration? initialOffset;

  @override
  State<_AndroidRelativeAlarmDialog> createState() =>
      _AndroidRelativeAlarmDialogState();
}

class _AndroidRelativeAlarmDialogState
    extends State<_AndroidRelativeAlarmDialog> {
  final _amount = TextEditingController(text: '10');
  late String _unit = widget.allDay ? 'days' : 'minutes';
  TimeOfDay _time = const TimeOfDay(hour: 9, minute: 0);

  @override
  void initState() {
    super.initState();
    final offset = widget.initialOffset;
    if (offset == null) return;
    if (widget.allDay) {
      final value = IcalAllDayAlarmOffset.fromDuration(offset);
      _amount.text = '${value.amount}';
      _unit = value.unit == IcalAllDayAlarmUnit.weeks ? 'weeks' : 'days';
      _time = TimeOfDay(hour: value.hour, minute: value.minute);
    } else {
      final minutes = offset.inMinutes.abs();
      if (minutes % (7 * 1440) == 0 && minutes > 0) {
        _unit = 'weeks';
        _amount.text = '${minutes ~/ (7 * 1440)}';
      } else if (minutes % 1440 == 0 && minutes > 0) {
        _unit = 'days';
        _amount.text = '${minutes ~/ 1440}';
      } else if (minutes % 60 == 0 && minutes > 0) {
        _unit = 'hours';
        _amount.text = '${minutes ~/ 60}';
      } else {
        _unit = 'minutes';
        _amount.text = '$minutes';
      }
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final units = widget.allDay
        ? const ['days', 'weeks']
        : const ['minutes', 'hours', 'days', 'weeks'];
    return AlertDialog(
      title: Text(context.l10n.addReminder),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _amount,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(labelText: context.l10n.reminderAmount),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _unit,
            decoration: InputDecoration(labelText: context.l10n.reminderUnit),
            items: [
              for (final unit in units)
                DropdownMenuItem(
                  value: unit,
                  child: Text(switch (unit) {
                    'weeks' => context.l10n.reminderUnitWeeks,
                    'days' => context.l10n.reminderUnitDays,
                    'hours' => context.l10n.reminderUnitHours,
                    _ => context.l10n.reminderUnitMinutes,
                  }),
                ),
            ],
            onChanged: (value) => setState(() => _unit = value ?? _unit),
          ),
          if (widget.allDay)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.schedule),
              title: Text(context.l10n.reminderTimeOfDay),
              subtitle: Text(_time.format(context)),
              onTap: () async {
                final value = await showTimePicker(
                  context: context,
                  initialTime: _time,
                );
                if (value != null) setState(() => _time = value);
              },
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          onPressed: switch (int.tryParse(_amount.text)) {
            final value? when value >= 0 && value <= 3600 =>
              () => Navigator.pop(context, (
                amount: value,
                unit: _unit,
                time: widget.allDay ? _time : null,
              )),
            _ => null,
          },
          child: Text(context.l10n.save),
        ),
      ],
    );
  }
}

RecurrenceRule _simpleTaskRecurrenceRule(
  RecurrenceFrequency frequency,
  DateTime base,
) {
  final weekday = const [
    'MO',
    'TU',
    'WE',
    'TH',
    'FR',
    'SA',
    'SU',
  ][base.weekday - 1];
  return const RecurrenceRule.none().copyWith(
    frequency: frequency,
    byDay: frequency == RecurrenceFrequency.weekly ? [weekday] : const [],
    byMonthDay:
        frequency == RecurrenceFrequency.monthly ||
            frequency == RecurrenceFrequency.yearly
        ? [base.day]
        : const [],
    byMonth: frequency == RecurrenceFrequency.yearly ? [base.month] : const [],
  );
}

String _date(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
String _clock(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

String _recurrenceLabel(BuildContext context, RecurrenceFrequency frequency) =>
    switch (frequency) {
      RecurrenceFrequency.none => context.l10n.repeatNone,
      RecurrenceFrequency.daily => context.l10n.repeatDaily,
      RecurrenceFrequency.weekly => context.l10n.repeatWeekly,
      RecurrenceFrequency.monthly => context.l10n.repeatMonthly,
      RecurrenceFrequency.yearly => context.l10n.repeatYearly,
    };
