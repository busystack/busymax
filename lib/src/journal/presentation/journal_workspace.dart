import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../app/app_bootstrap.dart';
import '../../app/busymax_window_close.dart';
import '../../dav/dav_errors.dart';
import '../../dav/ical/ical_attachments.dart';
import '../../dav/ical/ical_document.dart';
import '../../dav/ical/ical_recurrence.dart';
import '../../dav/ical/ical_semantics.dart';
import '../../dav/ical/dav_native_import.dart';
import '../../dav/ical/dav_native_export.dart';
import '../../dav/mutation/dav_conflict_repository.dart';
import '../../dav/mutation/dav_mutation_patch.dart';
import '../../dav/storage/dav_collection_capabilities.dart';
import '../../dav/xml/dav_xml.dart';
import '../../db/app_database.dart';
import '../../features/attachments/presentation/dav_attachment_file_name.dart';
import '../../features/schedule/presentation/schedule_event_details_format.dart';
import '../../features/sync/sync_request.dart';
import '../../providers/busy_provider.dart';
import '../journal_component.dart';
import '../journal_repository.dart';
import '../journal_subscription_repository.dart';

import 'journal_controls.dart';
import 'journal_component_editor.dart';
import 'journal_property_editor.dart';

export 'journal_controls.dart';

final _journalRepository = Provider(
  (ref) => JournalRepository(ref.watch(databaseProvider)),
);
final _journalSources = StreamProvider.autoDispose(
  (ref) => ref.watch(_journalRepository).watchSources(),
);
final _subscriptionJournals = StreamProvider.autoDispose(
  (ref) => watchJournalSubscriptions(ref.watch(databaseProvider)),
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
final _journalConflict = StreamProvider.autoDispose
    .family<DavConflictSnapshot?, String>(
      (ref, id) => ref.watch(_journalRepository).watchConflict(id),
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
  final _search = TextEditingController();
  JournalDateFilter _dates = JournalDateFilter.all;
  int _offset = 0;
  String? _error;
  JournalSnapshot? _open;
  JournalSubscriptionEntry? _subscriptionEntry;
  JournalOccurrenceDraft? _occurrenceEdit;
  DavCollection? _create;
  bool _busy = false;
  bool _createCollection = false;
  bool _renameCollection = false;
  bool _confirmCollectionRemoval = false;
  NextcloudNativeImportPreview? _import;
  String? _importSource;
  String? _moveSource;
  String? _notice;
  String _accountId = '';
  final _collectionName = TextEditingController();
  final _rename = TextEditingController();

  @override
  void dispose() {
    _collectionName.dispose();
    _rename.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() operation) async {
    if (_busy) return;
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
    _occurrenceEdit = null;
    _moveSource = null;
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ui = widget.controls;
    final repository = ref.watch(_journalRepository);
    final sourcesState = ref.watch(_journalSources);
    final sources = sourcesState.valueOrNull ?? const [];
    final subscriptions =
        ref.watch(_subscriptionJournals).valueOrNull ??
        const <JournalSubscriptionEntry>[];
    final subscriptionSources = {
      for (final entry in subscriptions)
        'webcal:${entry.source.id}': entry.source,
    };
    final subscriptionSource = subscriptionSources.containsKey(_source)
        ? _source
        : null;
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
    final conflictId = pending?.conflictSnapshotId;
    final conflict = conflictId == null
        ? null
        : ref.watch(_journalConflict(conflictId)).valueOrNull;
    final resolution = conflict == null
        ? null
        : ref
              .watch(davConflictsStreamProvider)
              .valueOrNull
              ?.where((item) => item.id == conflict.id)
              .firstOrNull;
    final authoringOffline =
        pending?.operationType == 'dav.create' &&
        pending?.state == 'pending' &&
        pending?.attemptCount == 0;
    final writable = current == null
        ? caps?.canAttemptCreateJournal ?? false
        : (authoringOffline ||
                  editorSource?.journalInventoryComplete == true) &&
              caps?.canAttemptUpdateJournal == true &&
              pending?.state != 'conflict';
    final filterSource = subscriptionSource ?? filteredSource?.id ?? '';
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

    if (_subscriptionEntry case final entry?) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(entry.source.summary),
          Text(l10n.readOnlySharedCollection),
          Text(entry.journal.title ?? l10n.untitledJournal),
          Text(entry.journal.start?.rawValue ?? l10n.noDate),
          if (entry.journal.status case final status?) Text(status),
          for (final body in entry.journal.descriptions)
            Text(body.decodedTextValue),
          if (_error != null) Text(_error!),
          if (widget.files != null)
            ui.button(
              l10n.export,
              _busy
                  ? null
                  : () => _run(() => widget.files!.export(entry.resource())),
            ),
          ui.button(
            l10n.close,
            _busy ? null : () => setState(() => _subscriptionEntry = null),
          ),
        ],
      );
    }

    if (current != null || _create != null) {
      final occurrence = _occurrenceEdit;
      final editing = occurrence?.component ?? current;
      final draftId = current == null
          ? 'new:${_create!.id}'
          : occurrence == null
          ? 'entry:${current.entry.componentId}'
          : 'instance:${current.entry.componentId}:${editing!.entry.recurrenceIdKey}:${occurrence.thisAndFuture}';
      final moveSources =
          current == null ||
              occurrence != null ||
              !writable ||
              caps?.supportsMove != true ||
              caps?.canAttemptDeleteJournal != true ||
              authoringOffline
          ? const <DavCollection>[]
          : sources
                .where(
                  (source) =>
                      source.accountId == current.entry.accountId &&
                      source.id != current.entry.collectionId &&
                      collectionCapabilitiesFromStored(source)
                          .canAttemptCreateJournal,
                )
                .toList();
      return _JournalEditor(
        key: ValueKey(draftId),
        repository: repository,
        draftId: draftId,
        ui: ui,
        snapshot: editing,
        source: editorSource,
        writable: writable,
        busy: _busy,
        error: _error,
        conflict: conflict == null || resolution == null
            ? null
            : _JournalConflict(
                snapshot: conflict,
                capabilities: resolution,
                ui: ui,
                busy: _busy,
                resolve: (choice) => _run(() async {
                  await ref
                      .read(davConflictResolutionServiceProvider)
                      .resolve(conflict.id, choice);
                  if (mounted) _closeEntry();
                }),
              ),
        close: _closeEntry,
        occurrences:
            current == null ||
                occurrence != null ||
                !current.component.component.properties.any(
                  (property) => const {
                    'RRULE',
                    'RDATE',
                    'RECURRENCE-ID',
                  }.contains(property.name),
                )
            ? null
            : (month) => repository.occurrences(current, month),
        openOccurrence: current == null || occurrence != null || !writable
            ? null
            : (selected, future) => _run(() async {
                final next = repository.inspectOccurrence(
                  current,
                  selected,
                  thisAndFuture: future,
                );
                if (mounted) setState(() => _occurrenceEdit = next);
              }),
        occurrenceScope: occurrence?.thisAndFuture,
        changeOccurrenceStatus: occurrence == null || !writable
            ? null
            : () => _run(() async {
                if (occurrence.thisAndFuture) {
                  await repository.deleteOccurrenceRange(occurrence);
                } else {
                  await repository.deleteOccurrence(occurrence);
                }
                if (mounted) _closeEntry();
              }),
        cancelRange: occurrence?.thisAndFuture != true || !writable
            ? null
            : () => _run(() async {
                await repository.cancelOccurrenceRange(occurrence!);
                if (mounted) _closeEntry();
              }),
        move: moveSources.isEmpty
            ? null
            : Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ui.choose(l10n.journalMove, _moveSource ?? '', [
                    (id: '', label: l10n.journalCollection),
                    for (final source in moveSources)
                      (id: source.id, label: source.displayName),
                  ], (value) => setState(() => _moveSource = value)),
                  ui.button(
                    l10n.journalMove,
                    moveSources.any((s) => s.id == _moveSource)
                        ? () => _run(() async {
                            await repository.move(
                              current!,
                              moveSources.singleWhere(
                                (s) => s.id == _moveSource,
                              ),
                            );
                            if (mounted) _closeEntry();
                          })
                        : null,
                  ),
                ],
              ),
        files: widget.files,
        run: _run,
        export: current == null || widget.files == null
            ? null
            : () => _run(() => widget.files!.export(current.effectiveRawIcs)),
        save:
            (
              title,
              start,
              status,
              descriptions,
              attachments,
              frequency,
              details,
              children,
            ) => _run(() async {
              await repository.database.transaction(() async {
                if (current == null) {
                  await repository.create(
                    _create!,
                    title: title,
                    start: start,
                    status: status,
                    descriptions: descriptions,
                    attachments: attachments,
                    frequency: frequency,
                    details: details,
                    children: children,
                  );
                } else {
                  final original = editing!.component;
                  final before = original.component.firstProperty('DTSTART');
                  final operations = [
                    ...journalDetailsOperations(original.component, details),
                    if (IcalDocument.create(
                          components: original.component.components.toList(),
                        ).serialize() !=
                        IcalDocument.create(components: children).serialize())
                      DavPatchOperation.replaceJournalChildren(children),
                    if (title != original.title)
                      DavPatchOperation.setText('SUMMARY', title),
                    if (status != original.status)
                      DavPatchOperation.setRaw(
                        'STATUS',
                        status,
                        preserveParameters: true,
                      ),
                    if (start?.serializeLogicalLine() !=
                        before?.serializeLogicalLine())
                      DavPatchOperation.setRaw(
                        'DTSTART',
                        start?.rawValue,
                        parameters: start?.parameters ?? const [],
                      ),
                    if (!_sameProperties(original.descriptions, descriptions))
                      DavPatchOperation.replaceRepeatedRaw(
                        'DESCRIPTION',
                        descriptions,
                      ),
                    if (!_sameProperties(
                      original.component.propertiesNamed('ATTACH').toList(),
                      attachments,
                    ))
                      DavPatchOperation.replaceRepeatedRaw(
                        'ATTACH',
                        attachments,
                      ),
                  ];
                  if (occurrence == null) {
                    await repository.edit(current, operations);
                  } else {
                    await repository.editOccurrence(occurrence, operations);
                  }
                }
                await repository.discardDraft(draftId);
              });
              if (mounted) {
                _closeEntry();
              }
            }),
        duplicate:
            current != null &&
                occurrence == null &&
                caps?.canAttemptCreateJournal == true &&
                pending?.state != 'conflict'
            ? () => _run(() async {
                await repository.duplicate(current);
                if (mounted) {
                  _closeEntry();
                }
              })
            : null,
        delete:
            current != null &&
                occurrence == null &&
                caps?.canAttemptDeleteJournal == true &&
                pending?.state != 'conflict' &&
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

    final newSource =
        (subscriptionSource != null
                ? const <DavCollection>[]
                : filteredSource == null
                ? sources
                : [filteredSource])
            .where(
              (src) =>
                  collectionCapabilitiesFromStored(src).canAttemptCreateJournal,
            )
            .firstOrNull;
    final pendingImport = _import;
    if (pendingImport != null) {
      final destinations = sources.where((source) {
        final caps = collectionCapabilitiesFromStored(source);
        return caps.canAttemptCreateJournal ||
            (pendingImport.isJournalMessage && caps.canAttemptUpdateJournal);
      }).toList();
      final destination =
          destinations
              .where(
                (source) => source.id == (_importSource ?? filteredSource?.id),
              )
              .firstOrNull ??
          destinations.firstOrNull;
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(l10n.importIcsFile),
          if (destination != null)
            ui.choose(l10n.journalCollection, destination.id, [
              for (final source in destinations)
                (id: source.id, label: source.displayName),
            ], (value) => setState(() => _importSource = value)),
          if (pendingImport.isJournalMessage)
            Text(pendingImport.schedulingMethod!),
          if (_error != null) Text(_error!),
          for (final entry in pendingImport.resources.take(100))
            Text(
              IcalDocument.parse(entry.rawIcs).calendarComponents.first
                      .firstProperty('SUMMARY')
                      ?.decodedTextValue ??
                  l10n.untitledJournal,
            ),
          if (pendingImport.rejected.isNotEmpty ||
              (pendingImport.schedulingMethod != null &&
                  !pendingImport.isJournalMessage))
            Text(l10n.journalOperationFailed),
          Wrap(
            spacing: 8,
            children: [
              ui.button(
                l10n.save,
                _busy ||
                        destination == null ||
                        pendingImport.resources.isEmpty ||
                        (pendingImport.schedulingMethod != null &&
                            !pendingImport.isJournalMessage)
                    ? null
                    : () => _run(() async {
                        final results =
                            await DavNativeImportService(
                              ref.read(databaseProvider),
                            ).import(
                              accountId: destination.accountId,
                              collectionId: destination.id,
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
    final subscriptionResults =
        (filterSource.isNotEmpty && subscriptionSource == null
                ? const <JournalSubscriptionEntry>[]
                : subscriptions)
            .where((entry) {
              if (subscriptionSource != null &&
                  subscriptionSource != 'webcal:${entry.source.id}') {
                return false;
              }
              final dated = entry.journal.start != null;
              return (_dates == JournalDateFilter.all ||
                      dated == (_dates == JournalDateFilter.dated)) &&
                  entry.journal.searchText.contains(
                    _query.trim().toLowerCase(),
                  );
            })
            .skip(_offset)
            .take(100)
            .toList();
    final settings = filteredSource == null
        ? null
        : ref
              .watch(davCollectionsStreamProvider)
              .valueOrNull
              ?.where((collection) => collection.id == filteredSource.id)
              .firstOrNull;
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
              if (filteredSource != null &&
                  widget.files?.exportCollection != null)
                ui.button(
                  l10n.journalExportCollection,
                  _busy
                      ? null
                      : () => _run(() async {
                          final resources =
                              await DavNativeExportService(repository.database)
                                  .collection(
                                    filteredSource.accountId,
                                    filteredSource.id,
                                  );
                          final path = await widget.files!.exportCollection!(
                            resources
                                .where(
                                  (item) => item.componentType == 'VJOURNAL',
                                )
                                .toList(),
                          );
                          if (mounted && path != null) {
                            setState(() => _notice = l10n.exportedFile(path));
                          }
                        }),
                ),
              if (settings?.capabilities.canMutateCollection == true &&
                  filteredSource != null)
                ui.button(
                  l10n.rename,
                  _busy
                      ? null
                      : () => setState(() {
                          _rename.text = filteredSource.displayName;
                          _renameCollection = !_renameCollection;
                          _confirmCollectionRemoval = false;
                        }),
                ),
              if (settings?.canRemoveCollection == true &&
                  filteredSource != null)
                ui.button(
                  l10n.journalDeleteCollection,
                  _busy
                      ? null
                      : () => setState(() {
                          _confirmCollectionRemoval =
                              !_confirmCollectionRemoval;
                          _renameCollection = false;
                        }),
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
                          subscriptionSource != null
                              ? calendarSyncScope(
                                  subscriptionSources[subscriptionSource]!
                                      .accountId,
                                  subscriptionSources[subscriptionSource]!.id,
                                )
                              : filteredSource == null
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
                      final name = _collectionName.text.trim();
                      final result = await ref
                          .read(
                            davCalendarCollectionMutationServiceForAccountProvider(
                              selectedAccount.id,
                            ),
                          )
                          .createJournalCollection(name);
                      final created = (await repository.watchSources().first)
                          .where(
                            (source) =>
                                source.accountId == selectedAccount.id &&
                                Uri.parse(source.requestUri) ==
                                    result.memberUri,
                          )
                          .firstOrNull;
                      if (mounted) {
                        _collectionName.clear();
                        setState(() {
                          _createCollection = false;
                          if (created != null) {
                            _source = created.id;
                            _offset = 0;
                          }
                          if (result.refreshPending) {
                            _notice = l10n.pendingSync;
                          }
                        });
                      }
                    }),
            ),
          ],
          if (_renameCollection &&
              filteredSource != null &&
              settings != null) ...[
            ui.input(l10n.title, controller: _rename),
            ui.button(
              l10n.save,
              _busy
                  ? null
                  : () => _run(() async {
                      final value = _rename.text.trim();
                      if (value.isEmpty) {
                        throw const FormatException(
                          'A collection name is required.',
                        );
                      }
                      final changes = {
                        const DavPropertyName(davNamespace, 'displayname'):
                            value,
                      };
                      if (settings.provider == BusyProvider.nextcloud) {
                        await ref
                            .read(
                              nextcloudCollectionServiceProvider(
                                filteredSource.accountId,
                              ),
                            )
                            .update(filteredSource.id, changes);
                      } else {
                        await ref
                            .read(
                              davCollectionAdministrationProvider(
                                filteredSource.accountId,
                              ),
                            )
                            .update(filteredSource.id, changes);
                      }
                      if (mounted) setState(() => _renameCollection = false);
                    }),
              primary: true,
            ),
          ],
          if (_confirmCollectionRemoval &&
              filteredSource != null &&
              settings != null) ...[
            Text(l10n.journalDeleteCollectionConfirmation),
            ui.button(
              l10n.delete,
              _busy
                  ? null
                  : () => _run(() async {
                      if (await repository.hasDrafts(filteredSource.id)) {
                        throw DavException(
                          kind: DavErrorKind.conflict,
                          code: 'DavJournalDraftsRemain',
                          safeMessage: l10n.journalCollectionHasDrafts,
                        );
                      }
                      if (settings.provider == BusyProvider.nextcloud) {
                        await ref
                            .read(
                              nextcloudCollectionServiceProvider(
                                filteredSource.accountId,
                              ),
                            )
                            .remove(filteredSource.id);
                      } else {
                        await ref
                            .read(
                              davCollectionAdministrationProvider(
                                filteredSource.accountId,
                              ),
                            )
                            .remove(filteredSource.id);
                      }
                      if (mounted) {
                        setState(() {
                          _source = '';
                          _confirmCollectionRemoval = false;
                          _offset = 0;
                        });
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
            controller: _search,
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
                  for (final source in subscriptionSources.entries)
                    (id: source.key, label: source.value.summary),
                ],
                (value) => setState(() {
                  _source = value;
                  _renameCollection = false;
                  _confirmCollectionRemoval = false;
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
            child: results.isEmpty && subscriptionResults.isEmpty
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
                    itemCount: results.length + subscriptionResults.length,
                    itemBuilder: (_, index) {
                      if (index >= results.length) {
                        final entry =
                            subscriptionResults[index - results.length];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: ui.button(
                            [
                              entry.journal.title ?? l10n.untitledJournal,
                              entry.source.summary,
                              entry.journal.start?.rawValue ?? l10n.noDate,
                            ].join(' · '),
                            () => setState(() => _subscriptionEntry = entry),
                          ),
                        );
                      }
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
          if (_offset > 0 ||
              results.length == 100 ||
              subscriptionResults.length == 100)
            Wrap(
              spacing: 8,
              children: [
                ui.button(
                  '‹',
                  _offset > 0 ? () => setState(() => _offset -= 100) : null,
                ),
                ui.button(
                  '›',
                  results.length == 100 || subscriptionResults.length == 100
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

class _JournalConflict extends StatelessWidget {
  const _JournalConflict({
    required this.snapshot,
    required this.capabilities,
    required this.ui,
    required this.busy,
    required this.resolve,
  });

  final DavConflictSnapshot snapshot;
  final DavConflictEntity capabilities;
  final JournalControls ui;
  final bool busy;
  final ValueChanged<DavConflictResolution> resolve;

  List<IcalComponent> _components(String raw) {
    if (raw.isEmpty) return const [];
    try {
      return IcalDocument.parse(raw).calendarComponents
          .where((component) => component.name == 'VJOURNAL')
          .toList(growable: false);
    } on FormatException {
      return const [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.conflictBlocked),
        for (final (label, raw) in [
          (l10n.pendingLocally, snapshot.localCandidateRawIcs),
          (l10n.keepServerVersion, snapshot.remoteRawIcs),
        ]) ...[
          Text(label),
          for (final component in _components(raw))
            for (final property in component.properties)
              if (const {
                'SUMMARY',
                'DESCRIPTION',
                'DTSTART',
                'RECURRENCE-ID',
                'STATUS',
              }.contains(property.name))
                Text(property.decodedTextValue),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final (choice, label, allowed) in [
              (
                DavConflictResolution.keepServer,
                l10n.keepServerVersion,
                capabilities.canKeepServer,
              ),
              (
                DavConflictResolution.reapplyLocal,
                l10n.reapplyLocalChange,
                capabilities.canReapplyLocal,
              ),
              (
                DavConflictResolution.duplicateLocal,
                l10n.duplicateLocalItem,
                capabilities.canDuplicate,
              ),
            ])
              ui.button(label, !busy && allowed ? () => resolve(choice) : null),
          ],
        ),
      ],
    );
  }
}

typedef _JournalSave = Future<void> Function(
  String? title,
  IcalProperty? start,
  String? status,
  List<DavRawPropertyValue> descriptions,
  List<DavRawPropertyValue> attachments,
  JournalFrequency? frequency,
  List<IcalProperty> details,
  List<IcalComponent> children,
);

class _JournalEditor extends StatefulWidget {
  const _JournalEditor({
    super.key,
    required this.repository,
    required this.draftId,
    required this.ui,
    required this.snapshot,
    required this.source,
    required this.writable,
    required this.busy,
    required this.error,
    required this.close,
    required this.save,
    required this.files,
    required this.run,
    this.conflict,
    this.occurrences,
    this.openOccurrence,
    this.occurrenceScope,
    this.changeOccurrenceStatus,
    this.cancelRange,
    this.delete,
    this.duplicate,
    this.export,
    this.move,
  });

  final JournalControls ui;
  final JournalRepository repository;
  final String draftId;
  final JournalSnapshot? snapshot;
  final DavCollection? source;
  final bool writable;
  final bool busy;
  final String? error;
  final VoidCallback close;
  final _JournalSave save;
  final JournalFileActions? files;
  final Future<void> Function(Future<void> Function()) run;
  final Widget? conflict;
  final List<IcalOccurrence> Function(DateTime month)? occurrences;
  final void Function(IcalOccurrence, bool)? openOccurrence;
  final bool? occurrenceScope;
  final VoidCallback? changeOccurrenceStatus;
  final VoidCallback? cancelRange;
  final VoidCallback? delete;
  final VoidCallback? duplicate;
  final VoidCallback? export;
  final Widget? move;

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

  bool get derived => isDerivedJournalProperty(original);

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
      group: original?.group,
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
  String _frequency = '';
  DateTime? _occurrenceMonth;
  late final _descriptions = [
    for (final property
        in widget.snapshot?.component.descriptions ?? const <IcalProperty>[])
      _DescriptionDraft(property),
  ];
  late final _attachments = [
    ...?widget.snapshot?.component.component.propertiesNamed('ATTACH'),
  ];
  final _attachmentUrl = TextEditingController();
  late final _details = [
    for (final property
        in widget.snapshot?.component.component.properties ??
            const <IcalProperty>[])
      if (journalDetailsFields.contains(property.name))
        JournalPropertyDraft(property.name, _persistDraft, property),
  ];
  late final _children = [
    for (final child
        in widget.snapshot?.component.component.components ??
            const <IcalComponent>[])
      JournalChildDraft(child, _persistDraft),
  ];
  bool _showDetails = false;
  bool _confirmDelete = false;
  bool _confirmCancelRange = false;
  bool _loadingDraft = true;
  bool _hasDraft = false;
  bool _draftDurable = false;
  bool _staleDraft = false;
  bool _draftFailed = false;
  bool _saving = false;
  Future<void> _draftWrite = Future.value();
  String? _lastDraftContent;

  late final _baselineDigest = widget.snapshot == null
      ? null
      : sha256
            .convert(utf8.encode(widget.snapshot!.effectiveRawIcs))
            .toString();

  @override
  void initState() {
    super.initState();
    unawaited(_loadDraft());
  }

  Future<void> _loadDraft() async {
    try {
      final draft = await widget.repository.readDraft(widget.draftId);
      if (!mounted) return;
      if (draft != null) {
        final data = (jsonDecode(draft.contentJson) as Map)
            .cast<String, Object?>();
        _title.text = data['title'] as String;
        _date.text = data['date'] as String;
        _zone.text = data['zone'] as String;
        _mode = data['mode'] as String;
        _status = data['status'] as String;
        _frequency = data['frequency'] as String;
        for (final description in _descriptions) {
          description.dispose();
        }
        _descriptions
          ..clear()
          ..addAll(
            _draftProperties(data, 'DESCRIPTION').map(_DescriptionDraft.new),
          );
        _attachments
          ..clear()
          ..addAll(_draftProperties(data, 'ATTACH'));
        if (data['details'] case final List details) {
          for (final detail in _details) {
            detail.dispose();
          }
          _details.clear();
          for (final item in details.cast<Map>()) {
            final name = item['name'] as String;
            if (!journalDetailsFields.contains(name)) continue;
            final property = _draftProperties({
              'details': [item],
            }, 'details').single;
            _details.add(
              JournalPropertyDraft(
                name,
                _persistDraft,
                IcalProperty(
                  group: property.group,
                  name: name,
                  parameters: property.parameters,
                  rawValue: property.rawValue,
                  originalPhysicalLines: const [],
                ),
              ),
            );
          }
        }
        if (data['children'] case final List children) {
          for (final child in _children) {
            child.dispose();
          }
          _children
            ..clear()
            ..addAll(
              children.cast<Map>().map(
                (child) => JournalChildDraft(
                  journalChildDraftFromJson(child.cast<String, Object?>()),
                  _persistDraft,
                ),
              ),
            );
        }
        _hasDraft = true;
        _draftDurable = true;
        _staleDraft = draft.baselineDigest != _baselineDigest;
      }
    } on Object {
      _draftFailed = true;
    }
    if (!mounted) return;
    for (final controller in [_title, _date, _zone]) {
      controller.addListener(_persistDraft);
    }
    for (final description in _descriptions) {
      _listenDescription(description);
    }
    _lastDraftContent = _draftContent();
    setState(() => _loadingDraft = false);
  }

  Iterable<IcalProperty> _draftProperties(
    Map<String, Object?> data,
    String name,
  ) => (data[name] as List).map((item) {
    final value = DavRawPropertyValue.fromJson(
      (item as Map).cast<String, Object?>(),
    );
    return IcalProperty(
      group: value.group,
      name: name,
      parameters: value.parameters,
      rawValue: value.value,
      originalPhysicalLines: const [],
    );
  });

  void _listenDescription(_DescriptionDraft draft) {
    for (final controller in [draft.text, draft.language, draft.alternate]) {
      controller.addListener(_persistDraft);
    }
  }

  String _draftContent() => jsonEncode({
    'title': _title.text,
    'date': _date.text,
    'zone': _zone.text,
    'mode': _mode,
    'status': _status,
    'frequency': _frequency,
    'details': [
      for (final field in _details)
        {'name': field.name, ..._rawProperty(field.toProperty()).toJson()},
    ],
    'children': [
      for (final child in _children)
        journalChildDraftToJson(child.toComponent()),
    ],
    'DESCRIPTION': [for (final draft in _descriptions) draft.toRaw().toJson()],
    'ATTACH': [
      for (final property in _attachments)
        DavRawPropertyValue(
          value: property.rawValue,
          parameters: property.parameters,
          group: property.group,
        ).toJson(),
    ],
  });

  void _persistDraft() {
    if (_loadingDraft || _saving || _staleDraft) return;
    final collectionId = widget.source?.id ?? widget.snapshot?.collection.id;
    if (collectionId == null) return;
    final content = _draftContent();
    if (content == _lastDraftContent) return;
    _lastDraftContent = content;
    if (!_hasDraft || _draftDurable) {
      setState(() {
        _hasDraft = true;
        _draftDurable = false;
      });
    }
    final repository = widget.repository;
    final id = widget.draftId;
    final digest = _baselineDigest;
    _draftWrite = _draftWrite.then((_) async {
      try {
        await repository.saveDraft(
          id: id,
          collectionId: collectionId,
          baselineDigest: digest,
          contentJson: content,
        );
        if (mounted && _lastDraftContent == content) {
          setState(() {
            _draftFailed = false;
            _draftDurable = true;
          });
        }
      } on Object {
        if (mounted) setState(() => _draftFailed = true);
      }
    });
  }

  Future<bool> _flushDraft() async {
    if (_saving || widget.busy) return false;
    await _draftWrite;
    return !_draftFailed;
  }

  void _changeDraft(VoidCallback change) {
    if (_saving || widget.busy) return;
    setState(change);
    _persistDraft();
  }

  Future<void> _save() async {
    if (_saving || widget.busy || _staleDraft || !widget.writable) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _saving = true);
    try {
      await _draftWrite;
      if (!mounted || !widget.writable) return;
      final oldTitle = widget.snapshot?.component.title;
      await widget.save(
        _title.text.isEmpty && oldTitle != '' ? null : _title.text,
        _start(),
        _status.isEmpty ? null : _status,
        _descriptions.map((draft) => draft.toRaw()).toList(),
        [
          for (final property in _attachments)
            DavRawPropertyValue(
              value: property.rawValue,
              parameters: property.parameters,
              group: property.group,
            ),
        ],
        _mode.isEmpty || _frequency.isEmpty
            ? null
            : JournalFrequency.values.byName(_frequency),
        _details.map((field) => field.toProperty(validate: true)).toList(),
        _children.map((child) => child.toComponent(validate: true)).toList(),
      );
    } on FormatException catch (error) {
      if (mounted) {
        await widget.run(() async {
          throw DavException(
            kind: DavErrorKind.invalidCalendarData,
            code: 'IcalInvalidJournalField',
            safeMessage: error.message,
          );
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _discardDraft() async {
    if (!await _flushDraft() || !mounted) return;
    await widget.run(() async {
      await widget.repository.discardDraft(widget.draftId);
      if (mounted) widget.close();
    });
  }

  @override
  void dispose() {
    _title.dispose();
    _date.dispose();
    _zone.dispose();
    _attachmentUrl.dispose();
    for (final description in _descriptions) {
      description.dispose();
    }
    for (final detail in _details) {
      detail.dispose();
    }
    for (final child in _children) {
      child.dispose();
    }
    super.dispose();
  }

  void _addAttachment(String value, List<IcalParameter> parameters) {
    setState(() {
      _attachments.add(
        IcalProperty(
          group: null,
          name: 'ATTACH',
          parameters: parameters,
          rawValue: value,
          originalPhysicalLines: const [],
          isDirty: true,
        ),
      );
    });
    _persistDraft();
  }

  List<Widget> _attachmentControls(AppLocalizations l10n, bool canEdit) {
    final ui = widget.ui;
    final editable =
        canEdit && !widget.busy && _attachments.length < maximumIcalAttachments;
    if (_attachments.length > maximumIcalAttachments) {
      return [Text(l10n.attachmentsNotLoaded)];
    }
    final attachments = readIcalAttachmentProperties(_attachments);
    return [
      const SizedBox(height: 12),
      Text(l10n.attachments),
      for (final attachment in attachments)
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            Text(
              attachment.kind == IcalAttachmentKind.binary
                  ? davAttachmentFileName(attachment)
                  : attachment.rawValue,
            ),
            if (attachment.canSave && widget.files != null)
              ui.button(
                l10n.save,
                widget.busy
                    ? null
                    : () => widget.run(() async {
                        await widget.files!.saveAttachment(attachment);
                      }),
              ),
            if (safeScheduleWebUri(attachment.uri) != null)
              ui.button(
                l10n.openLink,
                widget.busy
                    ? null
                    : () => widget.run(() async {
                        if (!await openScheduleWebLink(attachment.uri)) {
                          throw const FormatException('Could not open link.');
                        }
                      }),
              ),
            if (canEdit &&
                attachment.parameterValue('DERIVED')?.toUpperCase() != 'TRUE')
              ui.button(
                l10n.removeAction,
                widget.busy
                    ? null
                    : () => _changeDraft(
                        () => _attachments.removeAt(attachment.index),
                      ),
              ),
          ],
        ),
      if (editable) ...[
        ui.input('URL', controller: _attachmentUrl),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            ui.button(
              l10n.webLink,
              () => widget.run(() async {
                final uri = safeScheduleWebUri(_attachmentUrl.text);
                if (uri == null) {
                  throw const FormatException('Invalid attachment link.');
                }
                _addAttachment(uri.toString(), const []);
                _attachmentUrl.clear();
              }),
            ),
            if (widget.files != null)
              ui.button(
                l10n.registrationChooseFile,
                () => widget.run(() async {
                  final file = await widget.files!.pickAttachment();
                  if (file == null || !mounted) return;
                  _addAttachment(base64.encode(file.bytes), [
                    const IcalParameter(
                      name: 'VALUE',
                      values: ['BINARY'],
                      wasQuoted: false,
                    ),
                    const IcalParameter(
                      name: 'ENCODING',
                      values: ['BASE64'],
                      wasQuoted: false,
                    ),
                    IcalParameter(
                      name: 'X-FILENAME',
                      values: [file.name],
                      wasQuoted: true,
                    ),
                  ]);
                }),
              ),
          ],
        ),
      ],
    ];
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

  DateTime? get _civilDateTime {
    try {
      return parseIcalTemporal(_start())?.localValue;
    } on DavException {
      return null;
    }
  }

  void _chooseCivilDateTime(DateTime value, {required bool changeDay}) {
    final prior = _civilDateTime;
    final date = changeDay ? value : prior ?? value;
    final time = changeDay ? prior : value;
    String two(int value) => value.toString().padLeft(2, '0');
    final day =
        '${date.year.toString().padLeft(4, '0')}${two(date.month)}${two(date.day)}';
    final clock = time == null
        ? '000000'
        : '${two(time.hour)}${two(time.minute)}${two(time.second)}';
    _changeDraft(() => _date.text = _mode == 'date' ? day : '${day}T$clock');
  }

  List<Widget> _occurrenceControls(AppLocalizations l10n) {
    final ui = widget.ui;
    final month = _occurrenceMonth;
    if (widget.occurrences == null) return const [];
    if (month == null) {
      return [
        ui.button(l10n.repeat, () {
          final now = DateTime.now();
          setState(() => _occurrenceMonth = DateTime.utc(now.year, now.month));
        }),
      ];
    }
    List<IcalOccurrence> rows = const [];
    String? failure;
    try {
      rows = widget.occurrences!(month);
    } on DavException catch (error) {
      failure = error.safeMessage;
    } on FormatException {
      failure = l10n.journalOperationFailed;
    }
    return [
      Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          ui.button(
            l10n.previousMonth,
            () => setState(
              () =>
                  _occurrenceMonth = DateTime.utc(month.year, month.month - 1),
            ),
          ),
          Text(month.toIso8601String().substring(0, 7)),
          ui.button(
            l10n.nextMonth,
            () => setState(
              () =>
                  _occurrenceMonth = DateTime.utc(month.year, month.month + 1),
            ),
          ),
          ui.button(l10n.close, () => setState(() => _occurrenceMonth = null)),
        ],
      ),
      if (failure != null)
        Text(failure)
      else if (rows.isEmpty)
        Text(l10n.journalNoEntries)
      else
        SizedBox(
          height: 120,
          child: ListView.builder(
            primary: false,
            itemCount: rows.length,
            itemBuilder: (_, index) {
              final occurrence = rows[index];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Text(
                      [
                        occurrence.start.rawValue,
                        occurrence.summary,
                        if (occurrence.isCancelled) 'CANCELLED',
                      ].nonNulls.join(' · '),
                    ),
                    if (widget.openOccurrence case final open?) ...[
                      ui.button(
                        l10n.journalEditOccurrence,
                        () => open(occurrence, false),
                      ),
                      ui.button(
                        l10n.journalEditFuture,
                        () => open(occurrence, true),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ui = widget.ui;
    final canEdit = widget.writable && !_staleDraft;
    final snapshot = widget.snapshot;
    final component = snapshot?.component.component;
    final title = component?.firstProperty('SUMMARY');
    final status = component?.firstProperty('STATUS');
    final derivedDate = isDerivedJournalProperty(_original);
    final knownStatuses = ['', 'DRAFT', 'FINAL', 'CANCELLED'];
    if (_loadingDraft) return const SizedBox.shrink();
    final locked = _saving || widget.busy;
    return BusyMaxWindowCloseGuard(
      onCloseRequested: _flushDraft,
      child: PopScope(
        canPop: !locked,
        child: AbsorbPointer(
          absorbing: locked,
          child: ExcludeFocus(
            excluding: locked,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  widget.source?.displayName ??
                      snapshot?.collection.displayName ??
                      '',
                ),
                if (widget.occurrenceScope case final future?)
                  Text(
                    future
                        ? l10n.journalEditFuture
                        : l10n.journalEditOccurrence,
                  ),
                if (widget.error != null)
                  Semantics(liveRegion: true, child: Text(widget.error!)),
                if (_draftFailed) Text(l10n.journalDraftWriteFailed),
                if (_hasDraft && (_draftDurable || _staleDraft))
                  Text(
                    _staleDraft
                        ? l10n.journalDraftStale
                        : l10n.journalDraftSaved,
                  ),
                if (widget.conflict case final conflict?) conflict,
                if (canEdit) ...[
                  if (isDerivedJournalProperty(title))
                    Text(title!.decodedTextValue)
                  else
                    ui.input(l10n.title, controller: _title),
                  if (derivedDate)
                    Text(_original!.rawValue)
                  else
                    ui.choose(l10n.journalDate, _mode, [
                      (id: '', label: l10n.noDate),
                      (id: 'date', label: l10n.journalDate),
                      (id: 'floatingDateTime', label: l10n.journalFloatingTime),
                      (id: 'utcDateTime', label: '${l10n.journalDate} (UTC)'),
                      (id: 'tzidDateTime', label: l10n.journalZonedTime),
                    ], (value) => _changeDraft(() => _mode = value)),
                  if (!derivedDate && _mode.isNotEmpty) ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ui.pickDate(
                          l10n.journalPickDate,
                          _civilDateTime,
                          (date) => _chooseCivilDateTime(date, changeDay: true),
                        ),
                        if (_mode != 'date')
                          ui.pickTime(
                            l10n.journalPickTime,
                            _civilDateTime,
                            (time) =>
                                _chooseCivilDateTime(time, changeDay: false),
                          ),
                      ],
                    ),
                    ui.input(
                      _mode == 'date' ? 'YYYY-MM-DD' : 'YYYY-MM-DDTHH:MM:SS',
                      controller: _date,
                    ),
                  ],
                  if (!derivedDate && _mode == 'tzidDateTime')
                    ui.input('TZID', controller: _zone),
                  if (snapshot == null && _mode.isNotEmpty)
                    ui.choose(l10n.repeat, _frequency, [
                      (id: '', label: l10n.repeatNone),
                      (id: 'daily', label: l10n.repeatDaily),
                      (id: 'weekly', label: l10n.repeatWeekly),
                      (id: 'monthly', label: l10n.repeatMonthly),
                      (id: 'yearly', label: l10n.repeatYearly),
                    ], (value) => _changeDraft(() => _frequency = value)),
                  if (isDerivedJournalProperty(status))
                    Text(status!.rawValue)
                  else
                    ui.choose(l10n.journalStatus, _status, [
                      for (final status in {...knownStatuses, _status})
                        (id: status, label: status.isEmpty ? '—' : status),
                    ], (value) => _changeDraft(() => _status = value)),
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
                              () => _changeDraft(() {
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
                    () => _changeDraft(() {
                      final draft = _DescriptionDraft();
                      _listenDescription(draft);
                      _descriptions.add(draft);
                    }),
                  ),
                ] else if (_hasDraft) ...[
                  Text(
                    _title.text.isEmpty ? l10n.untitledJournal : _title.text,
                  ),
                  Text(_date.text.isEmpty ? l10n.noDate : _date.text),
                  if (_status.isNotEmpty) Text(_status),
                  for (final description in _descriptions)
                    Text(description.text.text),
                ] else if (snapshot != null) ...[
                  Text(snapshot.component.title ?? l10n.untitledJournal),
                  Text(snapshot.component.start?.rawValue ?? l10n.noDate),
                  if (snapshot.component.status case final status?)
                    Text(status),
                  for (final property in snapshot.component.descriptions)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(property.decodedTextValue),
                    ),
                ],
                ..._attachmentControls(l10n, canEdit),
                ..._occurrenceControls(l10n),
                if (canEdit) ...[
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: ui.button(
                      l10n.journalDetails,
                      () => setState(() => _showDetails = !_showDetails),
                    ),
                  ),
                  if (_showDetails) ...[
                    JournalPropertyEditor(
                      ui: ui,
                      fields: _details,
                      changed: _persistDraft,
                    ),
                    JournalComponentEditor(
                      parentType: 'VJOURNAL',
                      children: _children,
                      ui: ui,
                      changed: _persistDraft,
                    ),
                  ],
                ],
                if (!_hasDraft && widget.move != null) widget.move!,
                if (snapshot != null) ...[
                  if (!canEdit || !_showDetails)
                    ...journalReadOnlyChildren(snapshot.component.component),
                  for (final property
                      in snapshot.component.component.properties)
                    if (!const {
                          'SUMMARY',
                          'DESCRIPTION',
                          'DTSTART',
                          'STATUS',
                        }.contains(property.name) &&
                        (!canEdit ||
                            !journalDetailsFields.contains(property.name)) &&
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
                        locked || _staleDraft ? null : _save,
                        primary: true,
                      ),
                    if (widget.export != null)
                      ui.button(
                        l10n.export,
                        widget.busy ? null : widget.export,
                      ),
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
                    if (widget.changeOccurrenceStatus != null && !_hasDraft)
                      ui.button(
                        widget.occurrenceScope == true
                            ? l10n.journalDeleteFuture
                            : l10n.journalDeleteOccurrence,
                        locked
                            ? null
                            : _confirmDelete
                            ? widget.changeOccurrenceStatus
                            : () => setState(() => _confirmDelete = true),
                      ),
                    if (widget.cancelRange != null && !_hasDraft)
                      ui.button(
                        l10n.journalCancelFuture,
                        locked
                            ? null
                            : _confirmCancelRange
                            ? widget.cancelRange
                            : () => setState(() => _confirmCancelRange = true),
                      ),
                    ui.button(l10n.close, widget.busy ? null : widget.close),
                    if (_hasDraft)
                      ui.button(
                        l10n.discardChangesAction,
                        locked ? null : _discardDraft,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

DavRawPropertyValue _rawProperty(IcalProperty property) => DavRawPropertyValue(
  value: property.rawValue,
  parameters: property.parameters,
  group: property.group,
);

bool _sameProperties(
  List<IcalProperty> current,
  List<DavRawPropertyValue> values,
) {
  if (current.length != values.length) return false;
  for (var index = 0; index < current.length; index++) {
    final value = values[index];
    final before = current[index];
    final after = IcalProperty(
      group: value.group,
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
