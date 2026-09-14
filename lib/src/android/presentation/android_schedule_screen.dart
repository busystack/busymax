import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:busymax_android_platform/busymax_android_platform.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/app_bootstrap.dart';
import '../../features/accounts/data/accounts_repository.dart';
import '../../features/calendar/data/calendar_repository.dart';
import '../../features/calendar/presentation/event_editor_draft.dart';
import '../../features/maps/application/external_location_launcher.dart';
import '../../features/schedule/application/saved_schedule_location.dart';
import '../../features/recurrence/domain/event_recurrence_codec.dart';
import '../../features/recurrence/domain/recurrence_rule.dart';
import '../../l10n/l10n.dart';
import '../../l10n/time_format_scope.dart';
import '../../providers/busy_provider.dart';
import '../../schedule/schedule_filters.dart';
import '../../schedule/schedule_item.dart';
import '../../schedule/schedule_range.dart';
import '../../schedule/schedule_view_mode.dart';
import 'android_settings_screen.dart';
import 'android_tasks_screen.dart';

final _androidScheduleItemsProvider = FutureProvider.autoDispose
    .family<
      List<ScheduleItem>,
      ({DateTime anchor, ScheduleViewMode mode, String query})
    >((ref, key) async {
      ref.watch(scheduleDataRevisionProvider);
      return ref
          .watch(scheduleRepositoryProvider)
          .listItems(
            range: _rangeFor(key.anchor, key.mode),
            filters: ScheduleFilters(
              query: key.query,
              showCompletedTasks: true,
              showNoDateTasks: key.mode == ScheduleViewMode.agenda,
            ),
          );
    });

class AndroidScheduleScreen extends ConsumerStatefulWidget {
  const AndroidScheduleScreen({super.key});

  @override
  ConsumerState<AndroidScheduleScreen> createState() =>
      _AndroidScheduleScreenState();
}

class _AndroidScheduleScreenState extends ConsumerState<AndroidScheduleScreen> {
  DateTime _anchor = DateTime.now();
  bool _searching = false;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsControllerProvider);
    final mode = settings.androidScheduleViewMode ?? ScheduleViewMode.agenda;
    final items = ref.watch(
      _androidScheduleItemsProvider((
        anchor: DateTime(_anchor.year, _anchor.month, _anchor.day),
        mode: mode,
        query: _query,
      )),
    );
    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                autofocus: true,
                decoration: InputDecoration(
                  hintText: context.l10n.windowsSearch,
                  border: InputBorder.none,
                ),
                onChanged: (value) => setState(() => _query = value),
              )
            : InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _selectDate,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(_periodLabel(context, _anchor, mode)),
                    ),
                  ),
                ),
              ),
        actions: [
          IconButton(
            tooltip: context.l10n.windowsSearch,
            onPressed: () => setState(() {
              _searching = !_searching;
              if (!_searching) _query = '';
            }),
            icon: Icon(_searching ? Icons.close : Icons.search),
          ),
          IconButton(
            tooltip: context.l10n.collectionSettings,
            onPressed: () => _showSources(context),
            icon: const Icon(Icons.tune),
          ),
          PopupMenuButton<ScheduleViewMode>(
            tooltip: context.l10n.scheduleDisplaySettings,
            initialValue: mode,
            onSelected: ref
                .read(appSettingsControllerProvider.notifier)
                .setAndroidScheduleViewMode,
            itemBuilder: (context) => [
              for (final candidate in ScheduleViewMode.values)
                PopupMenuItem(
                  value: candidate,
                  child: Text(_modeLabel(context, candidate)),
                ),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Row(
              children: [
                IconButton(
                  tooltip: context.l10n.shortcutPreviousPeriod,
                  onPressed: () =>
                      setState(() => _anchor = _move(_anchor, mode, -1)),
                  icon: const Icon(Icons.chevron_left),
                ),
                FilledButton.tonal(
                  onPressed: () => setState(() => _anchor = DateTime.now()),
                  child: Text(context.l10n.today),
                ),
                IconButton(
                  tooltip: context.l10n.shortcutNextPeriod,
                  onPressed: () =>
                      setState(() => _anchor = _move(_anchor, mode, 1)),
                  icon: const Icon(Icons.chevron_right),
                ),
                const Spacer(),
                Flexible(
                  child: Text(
                    _modeLabel(context, mode),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: items.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _Message(
          icon: Icons.error_outline,
          title: context.l10n.scheduleUnavailable,
          detail: '$error',
        ),
        data: (value) => value.isEmpty
            ? _Message(
                icon: _query.isEmpty ? Icons.event_busy : Icons.search_off,
                title: _query.isEmpty
                    ? context.l10n.scheduleNoSources
                    : context.l10n.scheduleNoSearchResults,
                detail: _query.isEmpty
                    ? context.l10n.scheduleNoSourcesDescription
                    : context.l10n.scheduleNoSearchResultsDescription,
              )
            : _ScheduleBody(
                anchor: _anchor,
                mode: mode,
                items: value,
                onSelectDate: (date) => setState(() => _anchor = date),
                onOpen: (item) => _showItem(context, item),
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _createItem(context),
        tooltip: context.l10n.create,
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _showSources(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final sources = ref.watch(calendarSourcesStreamProvider);
          final lists = ref.watch(scheduleTaskListsProvider);
          final settings = ref.watch(appSettingsControllerProvider);
          return SafeArea(
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height * .72,
              child: ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  ListTile(
                    title: Text(context.l10n.collectionSettings),
                    titleTextStyle: Theme.of(context).textTheme.titleLarge,
                  ),
                  ...(sources.valueOrNull ?? const <CalendarSourceEntity>[])
                      .map(
                        (source) => CheckboxListTile(
                          secondary: const Icon(Icons.calendar_month),
                          title: Text(source.summary),
                          subtitle: Text(source.provider.displayName),
                          value: source.selected,
                          onChanged: (selected) => ref
                              .read(calendarRepositoryProvider)
                              .setSourceSelected(source.id, selected == true),
                        ),
                      ),
                  ...(lists.valueOrNull ?? const []).map(
                    (list) => CheckboxListTile(
                      secondary: const Icon(Icons.checklist),
                      title: Text(list.title),
                      value: settings.isTaskListVisibleInSchedule(
                        list.accountId,
                        list.id,
                      ),
                      onChanged: (visible) => ref
                          .read(appSettingsControllerProvider.notifier)
                          .setTaskListVisibleInSchedule(
                            accountId: list.accountId,
                            taskListId: list.id,
                            visible: visible == true,
                          ),
                    ),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.settings_outlined),
                    title: Text(context.l10n.collectionSettings),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.of(this.context).push<void>(
                        MaterialPageRoute(
                          builder: (_) => const AndroidSettingsScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _selectDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _anchor,
      firstDate: DateTime(1900),
      lastDate: DateTime(2200),
    );
    if (selected != null && mounted) setState(() => _anchor = selected);
  }

  Future<void> _createItem(BuildContext context) async {
    final type = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.event_outlined),
              title: Text(context.l10n.newEvent),
              onTap: () => Navigator.pop(context, 'event'),
            ),
            ListTile(
              leading: const Icon(Icons.check_circle_outline),
              title: Text(context.l10n.newTask),
              onTap: () => Navigator.pop(context, 'task'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted || type == null) return;
    if (type == 'event') {
      await _createEvent(context);
      return;
    }
    final lists = ref.read(scheduleTaskListsProvider).valueOrNull ?? const [];
    if (lists.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.noTaskListsSynced)));
      return;
    }
    final accounts =
        ref.read(accountsStreamProvider).valueOrNull ?? const <AccountEntity>[];
    final list = await selectAndroidTaskList(
      context,
      lists,
      title: context.l10n.newTask,
    );
    if (list == null || !context.mounted) return;
    final account = accounts
        .where((value) => value.id == list.accountId)
        .firstOrNull;
    if (account == null) return;
    await showAndroidTaskEditor(
      context,
      ref,
      creationList: list,
      creationProvider: account.provider,
      initialDue: DateTime(_anchor.year, _anchor.month, _anchor.day),
    );
  }

  Future<void> _showItem(BuildContext context, ScheduleItem item) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                item.title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(item.sourceName ?? item.provider.displayName),
              if (item.start != null)
                Text(
                  formatClockDateTime(
                    context,
                    item.start!,
                    DateFormat.yMMMd().format(item.start!),
                  ),
                ),
              if (item case CalendarScheduleItem(
                :final location?,
              ) when location.isNotEmpty)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.place),
                  title: Text(location),
                  trailing: const Icon(Icons.open_in_new),
                  onTap: () => unawaited(
                    const ExternalLocationLauncher(
                      platform: _androidLocationPlatform,
                    ).open(projectedScheduleItemLocationDestination(item)),
                  ),
                ),
              if (item case TaskScheduleItem(
                :final notes?,
              ) when notes.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(notes),
                ),
              const SizedBox(height: 16),
              if (item.capabilities.canEdit)
                FilledButton.icon(
                  onPressed: () async {
                    Navigator.pop(sheetContext);
                    if (item is CalendarScheduleItem) {
                      await _editEvent(context, item);
                    } else if (item is TaskScheduleItem) {
                      await showAndroidTaskEditor(context, ref, task: item);
                    }
                  },
                  icon: const Icon(Icons.edit),
                  label: Text(
                    item is CalendarScheduleItem
                        ? context.l10n.editEvent
                        : context.l10n.editTask,
                  ),
                ),
              if (item.provider == BusyProvider.nextcloud) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _exportItem(sheetContext, item),
                  icon: const Icon(Icons.file_download_outlined),
                  label: Text(context.l10n.export),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _exportItem(BuildContext context, ScheduleItem item) async {
    try {
      final raw = item is CalendarScheduleItem
          ? await ref
                .read(calendarRepositoryProvider)
                .nativeEventExport(item.id)
          : item is TaskScheduleItem
          ? await ref
                .read(tasksRepositoryForAccountProvider(item.accountId))
                .nativeTaskExport(item.sourceId, item.id)
          : null;
      if (raw == null) return;
      final uri = await BusyMaxAndroidPlatform.instance.createDocument(
        suggestedName: item is TaskScheduleItem ? 'task.ics' : 'event.ics',
        mimeType: 'text/calendar',
        bytes: Uint8List.fromList(utf8.encode(raw)),
      );
      if (context.mounted && uri != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.exportedFile(uri))));
      }
    } on Object catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.exportFailed('$error'))),
        );
      }
    }
  }

  Future<void> _createEvent(BuildContext context) async {
    final sources =
        (ref.read(calendarSourcesStreamProvider).valueOrNull ??
                const <CalendarSourceEntity>[])
            .where((source) => source.capabilities.canCreateEvents)
            .toList();
    if (sources.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.noWritableCalendars)));
      return;
    }
    final source = sources.length == 1
        ? sources.single
        : await showModalBottomSheet<CalendarSourceEntity>(
            context: context,
            showDragHandle: true,
            builder: (sheetContext) => SafeArea(
              child: ListView(
                shrinkWrap: true,
                children: [
                  ListTile(title: Text(context.l10n.newEvent)),
                  for (final candidate in sources)
                    ListTile(
                      leading: const Icon(Icons.calendar_today_outlined),
                      title: Text(candidate.summary),
                      subtitle: Text(candidate.provider.displayName),
                      onTap: () => Navigator.pop(sheetContext, candidate),
                    ),
                ],
              ),
            ),
          );
    if (source == null || !context.mounted) return;
    final start = DateTime(_anchor.year, _anchor.month, _anchor.day, 9);
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => AndroidEventEditor(
          sources: sources,
          draft: EventEditorDraft.newEvent(
            accountId: source.accountId,
            sourceId: source.id,
            providerCalendarId: source.providerCalendarId,
            start: start,
            end: start.add(const Duration(hours: 1)),
          ),
        ),
      ),
    );
  }

  Future<void> _editEvent(
    BuildContext context,
    CalendarScheduleItem item,
  ) async {
    await showAndroidEventEditor(context, ref, eventId: item.id);
  }
}

Future<void> showAndroidEventEditor(
  BuildContext context,
  WidgetRef ref, {
  required String eventId,
}) async {
  final detail = await ref
      .read(calendarRepositoryProvider)
      .loadEventDetail(eventId);
  if (!context.mounted || detail == null) return;
  final sources =
      (ref.read(calendarSourcesStreamProvider).valueOrNull ??
              const <CalendarSourceEntity>[])
          .where((source) => source.capabilities.canCreateEvents)
          .toList();
  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => AndroidEventEditor(
        sources: sources,
        draft: EventEditorDraft.fromEventDetail(detail),
      ),
    ),
  );
}

ExternalLocationPlatform _androidLocationPlatform() =>
    ExternalLocationPlatform.android;

class _ScheduleBody extends StatelessWidget {
  const _ScheduleBody({
    required this.anchor,
    required this.mode,
    required this.items,
    required this.onSelectDate,
    required this.onOpen,
  });
  final DateTime anchor;
  final ScheduleViewMode mode;
  final List<ScheduleItem> items;
  final ValueChanged<DateTime> onSelectDate;
  final ValueChanged<ScheduleItem> onOpen;

  @override
  Widget build(BuildContext context) => switch (mode) {
    ScheduleViewMode.month => _MonthView(
      anchor: anchor,
      items: items,
      onSelectDate: onSelectDate,
      onOpen: onOpen,
    ),
    ScheduleViewMode.year => _YearView(
      anchor: anchor,
      items: items,
      onSelectDate: onSelectDate,
    ),
    ScheduleViewMode.week => _WeekView(
      anchor: anchor,
      items: items,
      onOpen: onOpen,
    ),
    ScheduleViewMode.day => _AgendaList(
      items: items
          .where((item) => item.start != null && _sameDay(item.start!, anchor))
          .toList(),
      onOpen: onOpen,
    ),
    ScheduleViewMode.agenda => _AgendaList(items: items, onOpen: onOpen),
  };
}

class _AgendaList extends StatelessWidget {
  const _AgendaList({required this.items, required this.onOpen});
  final List<ScheduleItem> items;
  final ValueChanged<ScheduleItem> onOpen;
  @override
  Widget build(BuildContext context) => ListView.separated(
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
    itemCount: items.length,
    separatorBuilder: (_, _) => const SizedBox(height: 6),
    itemBuilder: (context, index) {
      final item = items[index];
      final time = item.start == null
          ? context.l10n.noDate
          : item.allDay
          ? context.l10n.allDay
          : BusyMaxTimeFormatScope.of(context).format(item.start!);
      return Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (index == 0 ||
                (item.start == null && items[index - 1].start != null) ||
                (item.start != null &&
                    (items[index - 1].start == null ||
                        !_sameDay(item.start!, items[index - 1].start!))))
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Text(
                  item.start == null
                      ? context.l10n.noDate
                      : DateFormat.yMMMMEEEEd().format(item.start!),
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
            ListTile(
              minVerticalPadding: 12,
              leading: item is TaskScheduleItem
                  ? Icon(
                      item.completed
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                    )
                  : const Icon(Icons.event),
              title: Text(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                '$time · ${item.sourceName ?? item.provider.displayName}',
              ),
              onTap: () => onOpen(item),
            ),
          ],
        ),
      );
    },
  );
}

class _WeekView extends StatelessWidget {
  const _WeekView({
    required this.anchor,
    required this.items,
    required this.onOpen,
  });
  final DateTime anchor;
  final List<ScheduleItem> items;
  final ValueChanged<ScheduleItem> onOpen;
  @override
  Widget build(BuildContext context) {
    final start = ScheduleRange.week(anchor).start;
    return LayoutBuilder(
      builder: (context, constraints) {
        final shown = constraints.maxWidth >= 700 ? 7 : 3;
        final offset = constraints.maxWidth >= 700
            ? 0
            : (anchor.difference(start).inDays).clamp(0, 4);
        return Row(
          children: [
            for (var index = offset; index < offset + shown; index++)
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(color: Theme.of(context).dividerColor),
                    ),
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          DateFormat.E().add_d().format(
                            start.add(Duration(days: index)),
                          ),
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      Expanded(
                        child: _AgendaList(
                          items: items
                              .where(
                                (item) =>
                                    item.start != null &&
                                    _sameDay(
                                      item.start!,
                                      start.add(Duration(days: index)),
                                    ),
                              )
                              .toList(),
                          onOpen: onOpen,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _MonthView extends StatelessWidget {
  const _MonthView({
    required this.anchor,
    required this.items,
    required this.onSelectDate,
    required this.onOpen,
  });
  final DateTime anchor;
  final List<ScheduleItem> items;
  final ValueChanged<DateTime> onSelectDate;
  final ValueChanged<ScheduleItem> onOpen;
  @override
  Widget build(BuildContext context) {
    final range = ScheduleRange.month(anchor);
    final days = range.end.difference(range.start).inDays;
    return LayoutBuilder(
      builder: (context, constraints) {
        final gridHeight = constraints.maxHeight * .58;
        return Column(
          children: [
            SizedBox(
              height: gridHeight,
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                ),
                itemCount: days,
                itemBuilder: (context, index) {
                  final day = range.start.add(Duration(days: index));
                  final count = items
                      .where(
                        (item) =>
                            item.start != null && _sameDay(item.start!, day),
                      )
                      .length;
                  final selected = _sameDay(day, anchor);
                  return InkWell(
                    onTap: () => onSelectDate(day),
                    child: Container(
                      decoration: BoxDecoration(
                        color: selected
                            ? Theme.of(context).colorScheme.secondaryContainer
                            : null,
                        border: Border.all(
                          color: Theme.of(context).dividerColor,
                          width: .4,
                        ),
                      ),
                      padding: const EdgeInsets.all(4),
                      child: Column(
                        children: [
                          Text(
                            '${day.day}',
                            style: TextStyle(
                              color: day.month == anchor.month
                                  ? null
                                  : Theme.of(context).disabledColor,
                            ),
                          ),
                          if (count > 0)
                            Text(
                              '•' * count.clamp(1, 3),
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Expanded(
              child: _AgendaList(
                items: items
                    .where(
                      (item) =>
                          item.start != null && _sameDay(item.start!, anchor),
                    )
                    .toList(),
                onOpen: onOpen,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _YearView extends StatelessWidget {
  const _YearView({
    required this.anchor,
    required this.items,
    required this.onSelectDate,
  });
  final DateTime anchor;
  final List<ScheduleItem> items;
  final ValueChanged<DateTime> onSelectDate;
  @override
  Widget build(BuildContext context) => GridView.builder(
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: MediaQuery.sizeOf(context).width >= 700 ? 3 : 2,
      childAspectRatio: 1.2,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
    ),
    itemCount: 12,
    itemBuilder: (context, index) {
      final month = index + 1;
      final count = items.where((item) => item.start?.month == month).length;
      return Card(
        child: InkWell(
          onTap: () => onSelectDate(DateTime(anchor.year, month, 1)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat.MMMM().format(DateTime(anchor.year, month)),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                Text(
                  context.l10n.scheduleItemCount(count),
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class AndroidEventEditor extends ConsumerStatefulWidget {
  const AndroidEventEditor({
    super.key,
    required this.sources,
    required this.draft,
  });
  final List<CalendarSourceEntity> sources;
  final EventEditorDraft draft;
  @override
  ConsumerState<AndroidEventEditor> createState() => _AndroidEventEditorState();
}

class _AndroidEventEditorState extends ConsumerState<AndroidEventEditor> {
  late EventEditorDraft _draft = widget.draft;
  late final TextEditingController _title = TextEditingController(
    text: _draft.title,
  );
  late final TextEditingController _location = TextEditingController(
    text: _draft.location,
  );
  late final TextEditingController _description = TextEditingController(
    text: _draft.description,
  );
  late final TextEditingController _guests = TextEditingController(
    text: _draft.attendees
        .where((a) => !a.self && !a.organizer)
        .map((a) => a.email)
        .join(', '),
  );
  late final TextEditingController _categories = TextEditingController(
    text: _draft.categories.join(', '),
  );
  int? _reminderMinutes;
  late RecurrenceFrequency _frequency = EventRecurrenceCodec.decode(
    _source.provider,
    _draft.recurrence,
    baseDate: _draft.start,
  ).frequency;
  bool _recurrenceChanged = false;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _location.dispose();
    _description.dispose();
    _guests.dispose();
    _categories.dispose();
    super.dispose();
  }

  CalendarSourceEntity get _source => widget.sources.firstWhere(
    (source) => source.id == _draft.sourceId,
    orElse: () => widget.sources.first,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const CloseButton(),
        title: Text(
          _draft.eventId == null
              ? context.l10n.newEvent
              : context.l10n.editEvent,
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text(context.l10n.save),
          ),
        ],
      ),
      body: Form(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _title,
              decoration: InputDecoration(labelText: context.l10n.title),
              autofocus: _draft.eventId == null,
              onChanged: (v) =>
                  setState(() => _draft = _draft.copyWith(title: v)),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _draft.sourceId,
              decoration: InputDecoration(labelText: context.l10n.calendar),
              items: [
                for (final source in widget.sources)
                  DropdownMenuItem(
                    value: source.id,
                    child: Text(source.summary),
                  ),
              ],
              onChanged: _draft.eventId != null
                  ? null
                  : (id) {
                      final source = widget.sources.firstWhere(
                        (s) => s.id == id,
                      );
                      setState(
                        () => _draft = _draft.copyWith(
                          accountId: source.accountId,
                          sourceId: source.id,
                          providerCalendarId: source.providerCalendarId,
                        ),
                      );
                    },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(context.l10n.allDay),
              value: _draft.allDay,
              onChanged: (value) =>
                  setState(() => _draft = _draft.copyWith(allDay: value)),
            ),
            _DateTimeTile(
              label: context.l10n.startDateTime,
              value: _draft.start!,
              allDay: _draft.allDay,
              onChanged: (value) =>
                  setState(() => _draft = _draft.copyWith(start: value)),
            ),
            _DateTimeTile(
              label: context.l10n.endDateTime,
              value: _draft.end!,
              allDay: _draft.allDay,
              onChanged: (value) =>
                  setState(() => _draft = _draft.copyWith(end: value)),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _location,
              decoration: InputDecoration(
                labelText: context.l10n.location,
                prefixIcon: const Icon(Icons.place_outlined),
              ),
              onChanged: (v) => _draft = _draft.copyWith(location: v),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              minLines: 3,
              maxLines: 7,
              decoration: InputDecoration(labelText: context.l10n.description),
              onChanged: (v) => _draft = _draft.copyWith(description: v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<RecurrenceFrequency>(
              initialValue: _frequency,
              decoration: InputDecoration(labelText: context.l10n.repeat),
              items: [
                DropdownMenuItem(
                  value: RecurrenceFrequency.none,
                  child: Text(context.l10n.repeatNone),
                ),
                DropdownMenuItem(
                  value: RecurrenceFrequency.daily,
                  child: Text(context.l10n.repeatDaily),
                ),
                DropdownMenuItem(
                  value: RecurrenceFrequency.weekly,
                  child: Text(context.l10n.repeatWeekly),
                ),
                DropdownMenuItem(
                  value: RecurrenceFrequency.monthly,
                  child: Text(context.l10n.repeatMonthly),
                ),
                DropdownMenuItem(
                  value: RecurrenceFrequency.yearly,
                  child: Text(context.l10n.repeatYearly),
                ),
              ],
              onChanged: (value) => setState(() {
                _frequency = value ?? RecurrenceFrequency.none;
                _recurrenceChanged = true;
              }),
            ),
            if (_draft.providerRecurringEventId != null) ...[
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.call_split),
                title: Text(context.l10n.chooseRecurringEventScope),
                subtitle: _draft.recurringMutationScope == null
                    ? null
                    : Text(
                        _scopeLabel(context, _draft.recurringMutationScope!),
                      ),
                onTap: _selectRecurringScope,
              ),
            ],
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _reminderMinutes,
              decoration: InputDecoration(labelText: context.l10n.reminder),
              items: [
                DropdownMenuItem(
                  value: 0,
                  child: Text(context.l10n.repeatNone),
                ),
                for (final value in const [5, 10, 30, 60, 1440])
                  DropdownMenuItem(
                    value: value,
                    child: Text(context.l10n.reminderMinutesBefore(value)),
                  ),
              ],
              onChanged: (value) => setState(() => _reminderMinutes = value),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _guests,
              enabled: _draft.canManageAttendees,
              decoration: InputDecoration(labelText: context.l10n.guests),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _categories,
              decoration: InputDecoration(labelText: context.l10n.categories),
            ),
            if (_draft.eventId != null) ...[
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: _saving ? null : _delete,
                icon: const Icon(Icons.delete_outline),
                label: Text(context.l10n.deleteEvent),
              ),
            ],
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final start = _draft.start;
    if (_title.text.trim().isEmpty || start == null) return;
    var draft = _draft.copyWith(
      title: _title.text.trim(),
      location: _location.text.trim(),
      description: _description.text.trim(),
      attendees: [
        for (final address in _guests.text.split(','))
          if (address.trim().isNotEmpty)
            EventAttendeeDraft(email: address.trim()),
      ],
      attendeesChanged:
          _guests.text.trim().isNotEmpty || _draft.attendees.isNotEmpty,
      categories: _categories.text
          .split(',')
          .map((v) => v.trim())
          .where((v) => v.isNotEmpty)
          .toList(),
      categoriesChanged: true,
    );
    if (_reminderMinutes != null) {
      final value = _reminderMinutes!;
      draft = draft.copyWith(
        reminders: _eventReminders(_source.provider, value),
        remindersChanged: true,
        clearReminders: value == 0,
      );
    }
    if (_recurrenceChanged) {
      final rule = _simpleRecurrenceRule(_frequency, start);
      draft = draft.copyWith(
        recurrence: rule.repeats
            ? EventRecurrenceCodec.encode(
                _source.provider,
                rule,
                baseDate: start,
                allDay: draft.allDay,
                timeZone: draft.startTimeZone,
              )
            : null,
        recurrenceChanged: true,
        clearRecurrence: !rule.repeats,
      );
    }
    if (!draft.canSave) return;
    if (draft.providerRecurringEventId != null &&
        draft.recurringMutationScope == null) {
      final scope = await _selectRecurringScope();
      if (scope == null) return;
      draft = draft.copyWith(recurringMutationScope: scope);
    }
    setState(() => _saving = true);
    try {
      if (draft.eventId == null) {
        await ref.read(calendarRepositoryProvider).createLocalEvent(draft);
      } else {
        await ref.read(calendarRepositoryProvider).updateLocalEvent(draft);
      }
      if (mounted) Navigator.pop(context);
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    var draft = _draft;
    if (draft.providerRecurringEventId != null &&
        draft.recurringMutationScope == null) {
      final scope = await _selectRecurringScope();
      if (scope == null) return;
      draft = draft.copyWith(recurringMutationScope: scope);
    }
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.deleteEvent),
        content: Text(draft.title),
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
    if (confirmed != true || _draft.eventId == null) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(calendarRepositoryProvider)
          .deleteLocalEvent(
            _draft.eventId!,
            recurringScope: draft.recurringMutationScope,
          );
      if (mounted) Navigator.pop(context);
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<RecurringEventMutationScope?> _selectRecurringScope() async {
    final scope = await showModalBottomSheet<RecurringEventMutationScope>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: Text(context.l10n.chooseRecurringEventScope)),
            for (final value in RecurringEventMutationScope.values)
              if (value != RecurringEventMutationScope.thisAndFuture ||
                  supportsThisAndFollowingEventMutation(_source.provider))
                ListTile(
                  leading: Icon(
                    _draft.recurringMutationScope == value
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                  ),
                  title: Text(_scopeLabel(context, value)),
                  onTap: () => Navigator.pop(context, value),
                ),
          ],
        ),
      ),
    );
    if (scope != null && mounted) {
      setState(() => _draft = _draft.copyWith(recurringMutationScope: scope));
    }
    return scope;
  }
}

String _scopeLabel(BuildContext context, RecurringEventMutationScope scope) =>
    switch (scope) {
      RecurringEventMutationScope.entireSeries => context.l10n.entireSeries,
      RecurringEventMutationScope.singleOccurrence =>
        context.l10n.singleOccurrence,
      RecurringEventMutationScope.thisAndFuture =>
        context.l10n.thisAndFollowingEvents,
    };

RecurrenceRule _simpleRecurrenceRule(
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

class _DateTimeTile extends StatelessWidget {
  const _DateTimeTile({
    required this.label,
    required this.value,
    required this.allDay,
    required this.onChanged,
  });
  final String label;
  final DateTime value;
  final bool allDay;
  final ValueChanged<DateTime> onChanged;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: const Icon(Icons.schedule),
    title: Text(label),
    subtitle: Text(
      allDay
          ? DateFormat.yMMMd().format(value)
          : formatClockDateTime(
              context,
              value,
              DateFormat.yMMMd().format(value),
            ),
    ),
    onTap: () async {
      final date = await showDatePicker(
        context: context,
        initialDate: value,
        firstDate: DateTime(1970),
        lastDate: DateTime(2200),
      );
      if (date == null || !context.mounted) return;
      if (allDay) return onChanged(date);
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(value),
      );
      if (time != null) {
        onChanged(
          DateTime(date.year, date.month, date.day, time.hour, time.minute),
        );
      }
    },
  );
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.detail,
  });
  final IconData icon;
  final String title;
  final String detail;
  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 52),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(detail, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

ScheduleRange _rangeFor(DateTime anchor, ScheduleViewMode mode) =>
    switch (mode) {
      ScheduleViewMode.day => ScheduleRange.day(anchor),
      ScheduleViewMode.week => ScheduleRange.week(anchor),
      ScheduleViewMode.month => ScheduleRange.month(anchor),
      ScheduleViewMode.year => ScheduleRange.year(anchor),
      ScheduleViewMode.agenda => ScheduleRange(
        start: DateTime(anchor.year, anchor.month, anchor.day - 30),
        end: DateTime(anchor.year, anchor.month, anchor.day + 91),
      ),
    };

DateTime _move(DateTime date, ScheduleViewMode mode, int amount) =>
    switch (mode) {
      ScheduleViewMode.day || ScheduleViewMode.agenda => DateTime(
        date.year,
        date.month,
        date.day + amount,
      ),
      ScheduleViewMode.week => DateTime(
        date.year,
        date.month,
        date.day + 7 * amount,
      ),
      ScheduleViewMode.month => DateTime(date.year, date.month + amount, 1),
      ScheduleViewMode.year => DateTime(date.year + amount, date.month, 1),
    };

String _periodLabel(
  BuildContext context,
  DateTime date,
  ScheduleViewMode mode,
) => switch (mode) {
  ScheduleViewMode.day ||
  ScheduleViewMode.agenda => DateFormat.yMMMMd().format(date),
  ScheduleViewMode.week =>
    '${DateFormat.MMMd().format(ScheduleRange.week(date).start)} – ${DateFormat.MMMd().format(ScheduleRange.week(date).end.subtract(const Duration(days: 1)))}',
  ScheduleViewMode.month => DateFormat.yMMMM().format(date),
  ScheduleViewMode.year => '${date.year}',
};

String _modeLabel(BuildContext context, ScheduleViewMode mode) =>
    switch (mode) {
      ScheduleViewMode.day => context.l10n.viewDay,
      ScheduleViewMode.week => context.l10n.viewWeek,
      ScheduleViewMode.month => context.l10n.viewMonth,
      ScheduleViewMode.year => context.l10n.viewYear,
      ScheduleViewMode.agenda => context.l10n.viewAgenda,
    };

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
Object? _eventReminders(BusyProvider provider, int minutes) {
  if (minutes <= 0) return null;
  return provider == BusyProvider.microsoft
      ? {'isReminderOn': true, 'reminderMinutesBeforeStart': minutes}
      : {
          'useDefault': false,
          'overrides': [
            {'method': 'popup', 'minutes': minutes},
          ],
        };
}
