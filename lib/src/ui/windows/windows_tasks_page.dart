import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../app/app_bootstrap.dart';
import '../../app/busymax_shortcuts.dart';
import '../../schedule/schedule_filters.dart';
import '../../schedule/schedule_item.dart';
import '../common/busymax_glyph.dart';
import 'windows_busymax_glyphs.dart';
import 'windows_task_details_dialog.dart';
import 'windows_task_editor_dialog.dart';

class WindowsTasksPage extends ConsumerStatefulWidget {
  const WindowsTasksPage({super.key});

  @override
  ConsumerState<WindowsTasksPage> createState() => _WindowsTasksPageState();
}

class _WindowsTasksPageState extends ConsumerState<WindowsTasksPage> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  late Future<List<TaskScheduleItem>> _tasks = _load();
  var _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<List<TaskScheduleItem>> _load() async {
    final repository = ref.read(scheduleRepositoryProvider);
    final filters = ScheduleFilters(
      query: _query,
      includeCalendarEvents: false,
      includeTasks: true,
      showCompletedTasks: true,
      showNoDateTasks: true,
    );
    return repository.listAllTasks(filters: filters);
  }

  void _reload() => setState(() => _tasks = _load());

  Future<void> _createTask() async {
    final changed = await showWindowsTaskEditorDialog(context, ref);
    if (changed && mounted) _reload();
  }

  void _dismissSearch() {
    if (!_searchFocusNode.hasFocus && _query.isEmpty) return;
    _searchController.clear();
    _query = '';
    _searchFocusNode.unfocus();
    _reload();
  }

  void _createTaskFromShortcut() {
    final focusContext = FocusManager.instance.primaryFocus?.context;
    if (focusContext != null &&
        (focusContext.widget is EditableText ||
            focusContext.findAncestorWidgetOfExactType<EditableText>() !=
                null)) {
      return;
    }
    unawaited(_createTask());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    return CallbackShortcuts(
      bindings: {
        BusyMaxShortcutActivators.search: _searchFocusNode.requestFocus,
        BusyMaxShortcutActivators.dismiss: _dismissSearch,
        const SingleActivator(LogicalKeyboardKey.keyT): _createTaskFromShortcut,
      },
      child: ScaffoldPage(
        header: PageHeader(
          title: Text(l10n.tasks),
          commandBar: CommandBar(
            primaryItems: [
              CommandBarButton(
                icon: Icon(windowsBusyMaxGlyph(BusyMaxGlyph.add)),
                label: Text(l10n.newTask),
                onPressed: () => unawaited(_createTask()),
              ),
              CommandBarButton(
                icon: Icon(windowsBusyMaxGlyph(BusyMaxGlyph.refresh)),
                label: Text(l10n.refresh),
                onPressed: _reload,
              ),
            ],
          ),
        ),
        content: Column(
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(24, 0, 24, 12),
              child: TextBox(
                controller: _searchController,
                focusNode: _searchFocusNode,
                placeholder: l10n.windowsSearch,
                prefix: Padding(
                  padding: const EdgeInsetsDirectional.only(start: 10),
                  child: Icon(windowsBusyMaxGlyph(BusyMaxGlyph.search)),
                ),
                onChanged: (value) {
                  _query = value;
                  _reload();
                },
              ),
            ),
            Expanded(
              child: FutureBuilder<List<TaskScheduleItem>>(
                future: _tasks,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: ProgressRing());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: InfoBar(
                        title: Text(l10n.scheduleUnavailable),
                        severity: InfoBarSeverity.error,
                        action: Button(
                          onPressed: _reload,
                          child: Text(l10n.retry),
                        ),
                      ),
                    );
                  }
                  final tasks = snapshot.data ?? const [];
                  if (tasks.isEmpty) {
                    return Center(
                      child: Text(
                        _query.isEmpty
                            ? l10n.signInToViewTasks
                            : l10n.scheduleNoSearchResults,
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      24,
                      0,
                      24,
                      24,
                    ),
                    itemCount: tasks.length,
                    itemBuilder: (context, index) {
                      final task = tasks[index];
                      final due = task.start == null
                          ? ''
                          : DateFormat.yMMMd(locale).format(task.start!);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Card(
                          child: ListTile(
                            leading: Icon(
                              windowsBusyMaxGlyph(
                                task.completed
                                    ? BusyMaxGlyph.check
                                    : BusyMaxGlyph.task,
                              ),
                            ),
                            title: Text(
                              task.title,
                              style: task.completed
                                  ? const TextStyle(
                                      decoration: TextDecoration.lineThrough,
                                    )
                                  : null,
                            ),
                            subtitle: Text(
                              [
                                due,
                                ?task.sourceName,
                              ].where((value) => value.isNotEmpty).join(' · '),
                            ),
                            onPressed: () => unawaited(
                              showWindowsTaskDetailsDialog(
                                context,
                                ref,
                                task,
                              ).then((changed) {
                                if (changed) _reload();
                              }),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
