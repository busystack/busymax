import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubuntu_widgets/ubuntu_widgets.dart';
import 'package:yaru/yaru.dart';

import '../../../app/app_bootstrap.dart';
import '../../../app/busymax_design.dart';
import '../../../app/busymax_dialogs.dart';
import '../../../l10n/l10n.dart';
import '../../../platform/linux_header_bar_service.dart';
import '../../../task_providers/task_provider.dart';
import '../../accounts/data/accounts_repository.dart';
import '../../task_lists/data/task_lists_repository.dart';

class NewTaskDraft {
  const NewTaskDraft({
    required this.title,
    required this.accountId,
    required this.taskListId,
    this.dueUtc,
    this.categories = const [],
  });

  final String title;
  final String accountId;
  final String taskListId;
  final DateTime? dueUtc;
  final List<String> categories;
}

Future<NewTaskDraft?> showBusyMaxNewTaskDialog(
  BuildContext context, {
  required WidgetRef ref,
  required List<AccountEntity> accounts,
  required String? initialAccountId,
  required String? initialListId,
  DateTime? initialDueUtc,
  LinuxHeaderBarService? headerBarService,
}) {
  return showBusyMaxModalEditorDialog<NewTaskDraft>(
    context,
    headerBarService: headerBarService,
    maxWidth: 460,
    maxHeight: 560,
    builder: (dialogContext) => UncontrolledProviderScope(
      container: ProviderScope.containerOf(context),
      child: _NewTaskDialog(
        accounts: accounts,
        initialAccountId: initialAccountId,
        initialListId: initialListId,
        initialDueUtc: initialDueUtc,
      ),
    ),
  );
}

class _NewTaskDialog extends ConsumerStatefulWidget {
  const _NewTaskDialog({
    required this.accounts,
    this.initialAccountId,
    this.initialListId,
    this.initialDueUtc,
  });

  final List<AccountEntity> accounts;
  final String? initialAccountId;
  final String? initialListId;
  final DateTime? initialDueUtc;

  @override
  ConsumerState<_NewTaskDialog> createState() => _NewTaskDialogState();
}

class _NewTaskDialogState extends ConsumerState<_NewTaskDialog> {
  final _categoryController = TextEditingController();
  var _title = '';
  String? _accountId;
  String? _taskListId;
  var _addingCategory = false;
  var _categories = const <String>[];

  @override
  void initState() {
    super.initState();
    _accountId =
        widget.accounts.any((account) => account.id == widget.initialAccountId)
        ? widget.initialAccountId
        : widget.accounts.first.id;
    _taskListId = widget.initialListId;
  }

  @override
  void dispose() {
    _categoryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final accountId = _accountId ?? widget.accounts.first.id;
    final repository = ref.watch(
      taskListsRepositoryForAccountProvider(accountId),
    );
    final tasksRepository = ref.watch(
      tasksRepositoryForAccountProvider(accountId),
    );
    final account = _accountForId(accountId);
    final capabilities = capabilitiesForProvider(
      account?.provider ?? TaskProvider.google,
    );

    return StreamBuilder<List<String>>(
      stream: tasksRepository.watchCategorySuggestions(),
      builder: (context, categorySnapshot) {
        final categorySuggestions = categorySnapshot.data ?? const <String>[];
        return StreamBuilder<List<TaskListEntity>>(
          stream: repository.watchTaskLists(),
          builder: (context, snapshot) {
            final taskLists = snapshot.data ?? const <TaskListEntity>[];
            final effectiveListId =
                taskLists.any((list) => list.id == _taskListId)
                ? _taskListId
                : taskLists.isEmpty
                ? null
                : taskLists.first.id;
            final canCreate =
                _title.trim().isNotEmpty && effectiveListId != null;

            return BusyMaxModalEditorScaffold(
              title: l10n.newTask,
              cancelLabel: l10n.cancel,
              saveLabel: l10n.create,
              onCancel: () => Navigator.of(context).pop(),
              onSave: canCreate ? () => _submit(effectiveListId) : null,
              contentMaxWidth: 460,
              children: [
                ValidatedFormField(
                  autofocus: true,
                  labelText: l10n.title,
                  onChanged: (value) {
                    setState(() {
                      _title = value;
                    });
                  },
                  onEditingComplete: () => _submit(effectiveListId),
                ),
                BusyMaxGroupedList(
                  children: [
                    BusyMaxComboRow<String>(
                      title: l10n.account,
                      leading: const Icon(YaruIcons.user),
                      values: widget.accounts
                          .map((account) => account.id)
                          .toList(),
                      selected: accountId,
                      labelFor: _accountLabel,
                      onSelected: (value) {
                        if (value == _accountId) {
                          return;
                        }
                        setState(() {
                          _accountId = value;
                          _taskListId = null;
                          if (!capabilitiesForProvider(
                            _accountForId(value)?.provider ??
                                TaskProvider.google,
                          ).supportsCategories) {
                            _categories = const [];
                            _addingCategory = false;
                            _categoryController.clear();
                          }
                        });
                      },
                    ),
                    if (effectiveListId == null)
                      BusyMaxActionRow(
                        title: l10n.list,
                        leading: const Icon(Icons.list_alt_outlined),
                        enabled: false,
                      )
                    else
                      BusyMaxComboRow<String>(
                        key: ValueKey('task-list-$accountId'),
                        title: l10n.list,
                        leading: const Icon(Icons.list_alt_outlined),
                        values: taskLists.map((list) => list.id).toList(),
                        selected: effectiveListId,
                        labelFor: (value) => _listLabel(taskLists, value),
                        onSelected: (value) {
                          setState(() {
                            _taskListId = value;
                          });
                        },
                      ),
                  ],
                ),
                if (widget.initialDueUtc != null)
                  BusyMaxGroupedList(
                    title: l10n.scheduleSection,
                    children: [
                      BusyMaxActionRow(
                        title: l10n.dueDate,
                        leading: const Icon(YaruIcons.calendar),
                        subtitle: MaterialLocalizations.of(
                          context,
                        ).formatFullDate(widget.initialDueUtc!),
                      ),
                    ],
                  ),
                if (capabilities.supportsCategories)
                  BusyMaxGroupedList(
                    title: l10n.organizationSection,
                    children: [
                      BusyMaxCategoryEditorRow(
                        title: l10n.categories,
                        addLabel: l10n.addCategory,
                        categories: _categories,
                        suggestions: categorySuggestions,
                        adding: _addingCategory,
                        controller: _categoryController,
                        inputKey: const Key('new-task-category-input'),
                        onAddPressed: () {
                          setState(() {
                            _addingCategory = true;
                          });
                        },
                        onSubmitted: _addCategory,
                        onCancelAdding: () {
                          _categoryController.clear();
                          setState(() {
                            _addingCategory = false;
                          });
                        },
                        onDeleted: _removeCategory,
                      ),
                    ],
                  ),
                const SizedBox(height: BusyMaxSpacing.lg),
              ],
            );
          },
        );
      },
    );
  }

  String _accountLabel(String accountId) {
    return widget.accounts
        .firstWhere((account) => account.id == accountId)
        .displayLabel;
  }

  String _listLabel(List<TaskListEntity> taskLists, String taskListId) {
    return taskLists.firstWhere((list) => list.id == taskListId).title;
  }

  AccountEntity? _accountForId(String accountId) {
    for (final account in widget.accounts) {
      if (account.id == accountId) {
        return account;
      }
    }
    return null;
  }

  void _addCategory(String value) {
    final category = value.trim();
    if (category.isEmpty || _categories.contains(category)) {
      return;
    }
    _categoryController.clear();
    setState(() {
      _addingCategory = false;
      _categories = [..._categories, category];
    });
  }

  void _removeCategory(String category) {
    setState(() {
      _categories = [
        for (final value in _categories)
          if (value != category) value,
      ];
    });
  }

  void _submit(String? effectiveListId) {
    final title = _title.trim();
    final accountId = _accountId;
    if (title.isEmpty || accountId == null || effectiveListId == null) {
      return;
    }
    Navigator.of(context).pop(
      NewTaskDraft(
        title: title,
        accountId: accountId,
        taskListId: effectiveListId,
        dueUtc: widget.initialDueUtc,
        categories: _categories,
      ),
    );
  }
}
