import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../app/app_bootstrap.dart';
import '../../dav/dav_errors.dart';
import '../../dav/ical/ical_document.dart';
import '../../dav/ical/dav_native_import.dart';
import '../../dav/mutation/dav_mutation_patch.dart';
import '../../dav/storage/dav_collection_capabilities.dart';
import '../../db/app_database.dart';
import '../../features/sync/sync_request.dart';
import '../../providers/busy_provider.dart';
import '../journal_repository.dart';

typedef JournalChoice = ({String id, String label});

final class JournalFileActions {
  const JournalFileActions({required this.read, required this.export});

  final Future<List<int>?> Function() read;
  final Future<void> Function(String raw) export;
}

abstract interface class JournalControls {
  Widget input(
    String label, {
    TextEditingController? controller,
    ValueChanged<String>? onChanged,
    int lines = 1,
  });
  Widget choose(
    String label,
    String selected,
    List<JournalChoice> choices,
    ValueChanged<String> change,
  );
  Widget button(String label, VoidCallback? action, {bool primary = false});
}

final _journalRepository = Provider(
  (ref) => JournalRepository(ref.watch(databaseProvider)),
);
final _journalSources = StreamProvider.autoDispose(
  (ref) => ref.watch(_journalRepository).watchSources(),
);
final _journalEntries = StreamProvider.autoDispose
    .family<List<DavJournalEntry>, (String, String, JournalDateFilter, int)>(
      (ref, filter) => ref
          .watch(_journalRepository)
          .watchEntries(
            collectionId: filter.$1.isEmpty ? null : filter.$1,
            search: filter.$2,
            dateFilter: filter.$3,
            offset: filter.$4,
          ),
    );
final _pending = StreamProvider.autoDispose.family<PendingOp?, String>(
  (ref, id) => ref.watch(_journalRepository).watchPending(id),
);

class JournalWorkspace extends ConsumerStatefulWidget {
  const JournalWorkspace({required this.controls, this.files, super.key});

  final JournalControls controls;
  final JournalFileActions? files;

  @override
  ConsumerState<JournalWorkspace> createState() => _JournalWorkspaceState();
}

class _JournalWorkspaceState extends ConsumerState<JournalWorkspace> {
  String _source = '';
  String _query = '';
  JournalDateFilter _dates = JournalDateFilter.all;
  int _offset = 0;
  String? _error;
  JournalSnapshot? _open;
  DavCollection? _create;
  bool _busy = false;
  bool _createCollection = false;
  NextcloudNativeImportPreview? _import;
  String? _notice;
  String _accountId = '';
  final _collectionName = TextEditingController();

  @override
  void dispose() {
    _collectionName.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() operation) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await operation();
    } on DavException catch (error) {
      if (mounted) setState(() => _error = error.safeMessage);
    } on Object {
      if (mounted) {
        setState(
          () => _error = AppLocalizations.of(context).journalOperationFailed,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _closeEntry() => setState(() {
    _open = null;
    _create = null;
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ui = widget.controls;
    final repository = ref.watch(_journalRepository);
    final sourcesState = ref.watch(_journalSources);
    final sources = sourcesState.valueOrNull ?? const [];
    final filteredSource = sources.where((s) => s.id == _source).firstOrNull;
    final current = _open;
    final editorSource = current == null
        ? _create
        : sources.where((s) => s.id == current.collection.id).firstOrNull;
    final caps = editorSource == null
        ? null
        : collectionCapabilitiesFromStored(editorSource);
    final pending = current == null
        ? null
        : ref.watch(_pending(current.entry.davObjectId)).valueOrNull;
    final authoringOffline =
        pending?.operationType == 'dav.create' &&
        pending?.state == 'pending' &&
        pending?.attemptCount == 0;
    final writable = current == null
        ? caps?.canAttemptCreateJournal ?? false
        : (authoringOffline ||
                  editorSource?.journalInventoryComplete == true) &&
              caps?.canAttemptUpdateJournal == true;
    final filterSource = filteredSource?.id ?? '';
    final entries = ref.watch(
      _journalEntries((filterSource, _query, _dates, _offset)),
    );
    final accountChoices =
        (ref.watch(accountsStreamProvider).valueOrNull ?? const [])
            .where(
              (account) =>
                  account.journalsEnabled &&
                  (account.provider == BusyProvider.caldav ||
                      account.provider == BusyProvider.nextcloud),
            )
            .map(
              (account) => (
                id: account.id,
                label: account.displayName ?? account.providerAccountId,
              ),
            )
            .toList();
    final selectedAccount =
        accountChoices
            .where((account) => account.id == _accountId)
            .firstOrNull ??
        accountChoices.firstOrNull;

    if (current != null && editorSource == null) {
      return Align(
        alignment: Alignment.topCenter,
        child: ui.button(l10n.close, _closeEntry),
      );
    }
    if (current != null || _create != null) {
      return _JournalEditor(
        key: ValueKey(current?.entry.componentId ?? _create?.id),
        ui: ui,
        snapshot: current,
        source: editorSource,
        writable: writable,
        busy: _busy,
        error: _error,
        close: _closeEntry,
        export: current == null || widget.files == null
            ? null
            : () => _run(() => widget.files!.export(current.effectiveRawIcs)),
        save: (title, start, status, descriptions) => _run(() async {
          if (current == null) {
            await repository.create(
              _create!,
              title: title,
              start: start,
              status: status,
              descriptions: descriptions,
            );
          } else {
            final original = current.component;
            final before = original.component.firstProperty('DTSTART');
            await repository.edit(current, [
              if (title != original.title)
                DavPatchOperation.setText('SUMMARY', title),
              if (status != original.status)
                DavPatchOperation.setRaw('STATUS', status),
              if (start?.serializeLogicalLine() !=
                  before?.serializeLogicalLine())
                DavPatchOperation.setRaw(
                  'DTSTART',
                  start?.rawValue,
                  parameters: start?.parameters ?? const [],
                ),
              if (!_sameDescriptions(original.descriptions, descriptions))
                DavPatchOperation.replaceRepeatedRaw(
                  'DESCRIPTION',
                  descriptions,
                ),
            ]);
          }
          if (mounted) {
            _closeEntry();
          }
        }),
        duplicate: current != null && caps?.canAttemptCreateJournal == true
            ? () => _run(() async {
                await repository.duplicate(current);
                if (mounted) {
                  _closeEntry();
                }
              })
            : null,
        delete:
            current != null &&
                caps?.canAttemptDeleteJournal == true &&
                (editorSource?.journalInventoryComplete == true ||
                    authoringOffline)
            ? () => _run(() async {
                await repository.deleteResource(current);
                if (mounted) {
                  _closeEntry();
                }
              })
            : null,
      );
    }

    final newSource = (filteredSource == null ? sources : [filteredSource])
        .where(
          (src) =>
              collectionCapabilitiesFromStored(src).canAttemptCreateJournal,
        )
        .firstOrNull;
    final pendingImport = _import;
    if (pendingImport != null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(l10n.importIcsFile),
          if (newSource != null) Text(newSource.displayName),
          if (_error != null) Text(_error!),
          for (final entry in pendingImport.resources.take(100))
            Text(
              IcalDocument.parse(entry.rawIcs).calendarComponents.first
                      .firstProperty('SUMMARY')
                      ?.decodedTextValue ??
                  l10n.untitledJournal,
            ),
          if (pendingImport.rejected.isNotEmpty ||
              pendingImport.schedulingMethod != null)
            Text(l10n.journalOperationFailed),
          Wrap(
            spacing: 8,
            children: [
              ui.button(
                l10n.save,
                _busy ||
                        newSource == null ||
                        pendingImport.resources.isEmpty ||
                        pendingImport.schedulingMethod != null
                    ? null
                    : () => _run(() async {
                        final results =
                            await DavNativeImportService(
                              ref.read(databaseProvider),
                            ).import(
                              accountId: newSource.accountId,
                              collectionId: newSource.id,
                              preview: pendingImport,
                            );
                        if (mounted) {
                          setState(() {
                            _import = null;
                            _notice = l10n.importQueued(
                              results
                                  .where(
                                    (result) =>
                                        result.status ==
                                        NativeImportItemStatus.queued,
                                  )
                                  .length,
                            );
                          });
                        }
                      }),
                primary: true,
              ),
              ui.button(
                l10n.cancel,
                _busy ? null : () => setState(() => _import = null),
              ),
            ],
          ),
        ],
      );
    }
    final results = entries.valueOrNull ?? const [];
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ui.button(
                l10n.newJournal,
                !_busy && newSource != null
                    ? () => setState(() {
                        _error = null;
                        _create = newSource;
                      })
                    : null,
                primary: true,
              ),
              ui.button(
                l10n.newJournalCollection,
                !_busy && accountChoices.isNotEmpty
                    ? () =>
                          setState(() => _createCollection = !_createCollection)
                    : null,
              ),
              if (widget.files != null)
                ui.button(
                  l10n.importIcsFile,
                  _busy || newSource == null
                      ? null
                      : () => _run(() async {
                          final bytes = await widget.files!.read();
                          if (bytes == null || !mounted) return;
                          final preview = ref
                              .read(icalImportServiceProvider)
                              .parsePreview(bytes)
                              .nativePreview;
                          setState(() {
                            _notice = null;
                            _import = NextcloudNativeImportPreview(
                              preview.resources
                                  .where(
                                    (resource) =>
                                        resource.componentType == 'VJOURNAL',
                                  )
                                  .toList(),
                              preview.rejected,
                              preview.schedulingMethod,
                            );
                          });
                        }),
                ),
              ui.button(
                l10n.refresh,
                _busy
                    ? null
                    : () => _run(() async {
                        final result = await ref.read(manualSyncRunnerProvider)(
                          filteredSource == null
                              ? allSyncScope
                              : davCollectionSyncScope(
                                  filteredSource.accountId,
                                  filteredSource.id,
                                ),
                        );
                        if (result.needsAttention && mounted) {
                          setState(() => _error = l10n.journalOperationFailed);
                        }
                      }),
              ),
            ],
          ),
          if (_createCollection && selectedAccount != null) ...[
            ui.choose(
              l10n.accounts,
              selectedAccount.id,
              accountChoices,
              (value) => setState(() => _accountId = value),
            ),
            ui.input(l10n.title, controller: _collectionName),
            ui.button(
              l10n.save,
              _busy
                  ? null
                  : () => _run(() async {
                      await ref
                          .read(
                            davCalendarCollectionMutationServiceForAccountProvider(
                              selectedAccount.id,
                            ),
                          )
                          .createJournalCollection(_collectionName.text);
                      if (mounted) {
                        _collectionName.clear();
                        setState(() => _createCollection = false);
                      }
                    }),
            ),
          ],
          if (_error != null) Semantics(liveRegion: true, child: Text(_error!)),
          if (_notice != null)
            Semantics(liveRegion: true, child: Text(_notice!)),
          const SizedBox(height: 12),
          ui.input(
            l10n.windowsSearch,
            onChanged: (value) => setState(() {
              _query = value;
              _offset = 0;
            }),
          ),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              ui.choose(
                l10n.journalCollection,
                filterSource,
                [
                  (id: '', label: l10n.all),
                  for (final source in sources)
                    (id: source.id, label: source.displayName),
                ],
                (value) => setState(() {
                  _source = value;
                  _offset = 0;
                }),
              ),
              ui.choose(
                l10n.journalDate,
                _dates.name,
                [
                  (id: JournalDateFilter.all.name, label: l10n.all),
                  (id: JournalDateFilter.dated.name, label: l10n.journalDated),
                  (id: JournalDateFilter.undated.name, label: l10n.noDate),
                ],
                (value) => setState(() {
                  _dates = JournalDateFilter.values.byName(value);
                  _offset = 0;
                }),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: results.isEmpty
                ? Center(
                    child: Text(
                      entries.hasError || sourcesState.hasError
                          ? l10n.journalOperationFailed
                          : entries.isLoading || sourcesState.isLoading
                          ? l10n.scheduleLoading
                          : l10n.journalNoEntries,
                    ),
                  )
                : ListView.builder(
                    itemCount: results.length,
                    itemBuilder: (_, index) {
                      final item = results[index];
                      final source = sources
                          .where((s) => s.id == item.collectionId)
                          .firstOrNull;
                      return Consumer(
                        builder: (_, itemRef, _) {
                          final pending = itemRef
                              .watch(_pending(item.davObjectId))
                              .valueOrNull;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: ui.button(
                              [
                                item.title ?? l10n.untitledJournal,
                                source?.displayName,
                                item.startValue ?? l10n.noDate,
                                item.status,
                                if (pending != null)
                                  pending.state == 'pending' ||
                                          pending.state == 'in_progress'
                                      ? l10n.pendingSync
                                      : l10n.journalOperationFailed,
                              ].nonNulls.join(' · '),
                              _busy
                                  ? null
                                  : () => _run(() async {
                                      final snapshot = await repository.read(
                                        item,
                                      );
                                      if (mounted) {
                                        setState(() => _open = snapshot);
                                      }
                                    }),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
          if (_offset > 0 || results.length == 100)
            Wrap(
              spacing: 8,
              children: [
                ui.button(
                  '‹',
                  _offset > 0 ? () => setState(() => _offset -= 100) : null,
                ),
                ui.button(
                  '›',
                  results.length == 100
                      ? () => setState(() => _offset += 100)
                      : null,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

typedef _JournalSave = Future<void> Function(
  String? title,
  IcalProperty? start,
  String? status,
  List<DavRawPropertyValue> descriptions,
);

class _JournalEditor extends StatefulWidget {
  const _JournalEditor({
    super.key,
    required this.ui,
    required this.snapshot,
    required this.source,
    required this.writable,
    required this.busy,
    required this.error,
    required this.close,
    required this.save,
    this.delete,
    this.duplicate,
    this.export,
  });

  final JournalControls ui;
  final JournalSnapshot? snapshot;
  final DavCollection? source;
  final bool writable;
  final bool busy;
  final String? error;
  final VoidCallback close;
  final _JournalSave save;
  final VoidCallback? delete;
  final VoidCallback? duplicate;
  final VoidCallback? export;

  @override
  State<_JournalEditor> createState() => _JournalEditorState();
}

class _DescriptionDraft {
  _DescriptionDraft([this.original])
    : text = TextEditingController(text: original?.decodedTextValue),
      language = TextEditingController(
        text: original?.parameterValue('LANGUAGE'),
      ),
      alternate = TextEditingController(
        text: original?.parameterValue('ALTREP'),
      );
  final IcalProperty? original;
  final TextEditingController text;
  final TextEditingController language;
  final TextEditingController alternate;

  bool get derived =>
      original?.parameterValue('DERIVED')?.toUpperCase() == 'TRUE';

  DavRawPropertyValue toRaw() {
    final parameters = [...?original?.parameters];
    for (final (name, value) in [
      ('LANGUAGE', language.text),
      ('ALTREP', alternate.text),
    ]) {
      if (value == (original?.parameterValue(name) ?? '')) continue;
      parameters.removeWhere((p) => p.name == name);
      if (value.isNotEmpty) {
        parameters.add(
          IcalParameter(
            name: name,
            values: [value],
            wasQuoted: name == 'ALTREP',
          ),
        );
      }
    }
    return DavRawPropertyValue(
      value: text.text == original?.decodedTextValue
          ? original!.rawValue
          : encodeIcalText(text.text),
      parameters: parameters,
    );
  }

  void dispose() {
    text.dispose();
    language.dispose();
    alternate.dispose();
  }
}

class _JournalEditorState extends State<_JournalEditor> {
  late final _title = TextEditingController(
    text: widget.snapshot?.component.title,
  );
  late final _original = widget.snapshot?.component.component.firstProperty(
    'DTSTART',
  );
  late final _date = TextEditingController(text: _original?.rawValue);
  late final _zone = TextEditingController(
    text: _original?.parameterValue('TZID'),
  );
  late String _status = widget.snapshot?.component.status ?? '';
  late String _mode = widget.snapshot?.component.start?.kind.name ?? '';
  late final _descriptions = [
    for (final property
        in widget.snapshot?.component.descriptions ?? const <IcalProperty>[])
      _DescriptionDraft(property),
  ];
  bool _confirmDelete = false;

  @override
  void dispose() {
    _title.dispose();
    _date.dispose();
    _zone.dispose();
    for (final description in _descriptions) {
      description.dispose();
    }
    super.dispose();
  }

  IcalProperty? _start() {
    if (_mode.isEmpty) return null;
    final input = _date.text
        .trim()
        .replaceAll('-', '')
        .replaceAll(':', '')
        .toUpperCase();
    final body = input.endsWith('Z')
        ? input.substring(0, input.length - 1)
        : input;
    final value = _mode == 'utcDateTime' ? '${body}Z' : body;
    if (value == _original?.rawValue &&
        _mode == widget.snapshot?.component.start?.kind.name &&
        _zone.text == (_original?.parameterValue('TZID') ?? '')) {
      return _original;
    }
    return IcalProperty(
      group: null,
      name: 'DTSTART',
      parameters: [
        if (_mode == 'date')
          const IcalParameter(
            name: 'VALUE',
            values: ['DATE'],
            wasQuoted: false,
          ),
        if (_mode == 'tzidDateTime')
          IcalParameter(
            name: 'TZID',
            values: [_zone.text.trim()],
            wasQuoted: false,
          ),
        for (final p in _original?.parameters ?? const <IcalParameter>[])
          if (p.name != 'VALUE' && p.name != 'TZID') p,
      ],
      rawValue: value,
      originalPhysicalLines: const [],
      isDirty: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ui = widget.ui;
    final canEdit = widget.writable || widget.snapshot == null;
    final snapshot = widget.snapshot;
    final knownStatuses = ['', 'DRAFT', 'FINAL', 'CANCELLED'];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          widget.source?.displayName ?? snapshot?.collection.displayName ?? '',
        ),
        if (widget.error != null)
          Semantics(liveRegion: true, child: Text(widget.error!)),
        if (canEdit) ...[
          ui.input(l10n.title, controller: _title),
          ui.choose(l10n.journalDate, _mode, [
            (id: '', label: l10n.noDate),
            (id: 'date', label: l10n.journalDate),
            (id: 'floatingDateTime', label: l10n.journalFloatingTime),
            (id: 'utcDateTime', label: '${l10n.journalDate} (UTC)'),
            (id: 'tzidDateTime', label: l10n.journalZonedTime),
          ], (value) => setState(() => _mode = value)),
          if (_mode.isNotEmpty)
            ui.input(
              _mode == 'date' ? 'YYYY-MM-DD' : 'YYYY-MM-DDTHH:MM:SS',
              controller: _date,
            ),
          if (_mode == 'tzidDateTime') ui.input('TZID', controller: _zone),
          ui.choose(l10n.journalStatus, _status, [
            for (final status in {...knownStatuses, _status})
              (id: status, label: status.isEmpty ? '—' : status),
          ], (value) => setState(() => _status = value)),
          for (final draft in _descriptions) ...[
            const SizedBox(height: 12),
            KeyedSubtree(
              key: ObjectKey(draft),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (draft.derived)
                    Text(draft.original!.serializeLogicalLine())
                  else ...[
                    ui.input(
                      l10n.description,
                      controller: draft.text,
                      lines: 4,
                    ),
                    ui.input('LANGUAGE', controller: draft.language),
                    ui.input('ALTREP', controller: draft.alternate),
                    ui.button(
                      l10n.journalRemoveDescription,
                      () => setState(() {
                        _descriptions.remove(draft);
                        WidgetsBinding.instance.addPostFrameCallback(
                          (_) => draft.dispose(),
                        );
                      }),
                    ),
                  ],
                ],
              ),
            ),
          ],
          ui.button(
            l10n.journalAddDescription,
            () => setState(() => _descriptions.add(_DescriptionDraft())),
          ),
        ] else if (snapshot != null) ...[
          Text(snapshot.component.title ?? l10n.untitledJournal),
          Text(snapshot.component.start?.rawValue ?? l10n.noDate),
          if (snapshot.component.status case final status?) Text(status),
          for (final property in snapshot.component.descriptions)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(property.decodedTextValue),
            ),
        ],
        if (snapshot != null) ...[
          for (final property in snapshot.component.component.properties)
            if (!const {
                  'SUMMARY',
                  'DESCRIPTION',
                  'DTSTART',
                  'STATUS',
                }.contains(property.name) &&
                property.name != 'ATTACH')
              Text(property.serializeLogicalLine()),
        ],
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (canEdit)
              ui.button(
                l10n.save,
                widget.busy
                    ? null
                    : () {
                        widget.save(
                          _title.text.isEmpty ? null : _title.text,
                          _start(),
                          _status.isEmpty ? null : _status,
                          _descriptions.map((d) => d.toRaw()).toList(),
                        );
                      },
                primary: true,
              ),
            if (widget.export != null)
              ui.button(l10n.export, widget.busy ? null : widget.export),
            if (widget.duplicate != null)
              ui.button(
                l10n.journalDuplicate,
                widget.busy ? null : widget.duplicate,
              ),
            if (widget.delete != null)
              ui.button(
                _confirmDelete ? l10n.journalDeleteSeries : l10n.delete,
                widget.busy
                    ? null
                    : _confirmDelete
                    ? widget.delete
                    : () => setState(() => _confirmDelete = true),
              ),
            ui.button(
              canEdit ? l10n.cancel : l10n.close,
              widget.busy ? null : widget.close,
            ),
          ],
        ),
      ],
    );
  }
}

bool _sameDescriptions(
  List<IcalProperty> current,
  List<DavRawPropertyValue> values,
) {
  if (current.length != values.length) return false;
  for (var index = 0; index < current.length; index++) {
    final value = values[index];
    final before = current[index];
    final after = IcalProperty(
      group: before.group,
      name: before.name,
      parameters: value.parameters,
      rawValue: value.value,
      originalPhysicalLines: const [],
    );
    if (before.serializeLogicalLine() != after.serializeLogicalLine()) {
      return false;
    }
  }
  return true;
}
