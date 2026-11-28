import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../app/app_bootstrap.dart';
import '../../app/busymax_window_close.dart';
import '../../core/time/stored_temporal_projection.dart';
import '../../dav/dav_errors.dart';
import '../../dav/ical/ical_attachments.dart';
import '../../dav/ical/ical_document.dart';
import '../../dav/ical/ical_recurrence.dart';
import '../../dav/ical/ical_semantics.dart';
import '../../dav/ical/dav_native_import.dart';
import '../../dav/ical/dav_native_export.dart';
import '../../dav/mutation/dav_conflict_repository.dart';
import '../../dav/mutation/dav_mutation_patch.dart';
import '../../dav/mutation/dav_pending_operations.dart';
import '../../dav/storage/dav_collection_capabilities.dart';
import '../../dav/xml/dav_xml.dart';
import '../../db/app_database.dart';
import '../../features/attachments/presentation/dav_attachment_file_name.dart';
import '../../features/schedule/presentation/schedule_event_details_format.dart';
import '../../features/sync/sync_request.dart';
import '../../l10n/time_format_scope.dart';
import '../../providers/busy_provider.dart';
import '../../schedule/schedule_commands.dart';
import '../../schedule/schedule_item.dart';
import '../journal_component.dart';
import '../journal_import_review.dart';
import '../journal_repository.dart';
import '../journal_subscription_repository.dart';

import 'journal_controls.dart';
import 'journal_component_editor.dart';
import 'journal_property_editor.dart';

export 'journal_controls.dart';

final _importOperation = StreamProvider.autoDispose.family<PendingOp?, String>((
  ref,
  id,
) {
  final database = ref.watch(databaseProvider);
  return (database.select(
    database.pendingOps,
  )..where((row) => row.id.equals(id))).watchSingleOrNull();
});

final _journalRepository = Provider(
  (ref) => JournalRepository(ref.watch(databaseProvider)),
);
final _importReviews = Provider(
  (ref) => JournalImportReviewRepository(ref.watch(_journalRepository)),
);
final _importReview = StreamProvider.autoDispose(
  (ref) => ref.watch(_importReviews).watch(),
);
final _journalSources = StreamProvider.autoDispose(
  (ref) => ref.watch(_journalRepository).watchSources(),
);
final _relatedEntries = FutureProvider.autoDispose
    .family<List<JournalLinkTarget>, JournalSnapshot>((ref, origin) {
      ref.watch(scheduleDataRevisionProvider);
      return ref.watch(_journalRepository).relatedEntries(origin);
    });
final _pending = StreamProvider.autoDispose.family<PendingOp?, String>(
  (ref, id) => ref.watch(_journalRepository).watchPending(id),
);
final _journalConflict = StreamProvider.autoDispose
    .family<DavConflictSnapshot?, String>(
      (ref, id) => ref.watch(_journalRepository).watchConflict(id),
    );

Object _linkIdentity(JournalLinkTarget target) => switch (target) {
  LinkedJournal(:final entry) => (
    'journal',
    entry.accountId,
    entry.collectionId,
    entry.componentId,
  ),
  LinkedEvent(:final event) => (
    'event',
    event.accountId,
    event.calendarSourceId,
    event.id,
  ),
  LinkedTask(:final task) => ('task', task.accountId, task.taskListId, task.id),
  LinkedXml(:final uri) => ('xml', uri),
  UnresolvedJournalLink(:final valueType, :final value) => (valueType, value),
};

String _linkLabel(JournalLinkTarget target, AppLocalizations l10n) =>
    switch (target) {
      LinkedJournal(:final entry) => entry.title ?? l10n.untitledJournal,
      LinkedEvent(:final event) => event.title,
      LinkedTask(:final task) => task.title,
      LinkedXml(:final uri) => uri.toString(),
      UnresolvedJournalLink(:final value) => value,
    };

enum JournalPaneAction {
  open,
  create,
  import,
  createCollection,
  renameCollection,
  removeCollection,
  exportCollection,
}

enum JournalDetailAction { share, edit, delete, close }

String journalPaneTitle(AppLocalizations l10n, JournalPaneAction action) =>
    switch (action) {
      JournalPaneAction.open => l10n.journalDetails,
      JournalPaneAction.create => l10n.newJournalEntry,
      JournalPaneAction.import => l10n.importIcsFile,
      JournalPaneAction.createCollection => l10n.newJournalSource,
      JournalPaneAction.renameCollection => l10n.rename,
      JournalPaneAction.removeCollection => l10n.journalDeleteCollection,
      JournalPaneAction.exportCollection => l10n.journalExportCollection,
    };

class JournalPane extends ConsumerStatefulWidget {
  const JournalPane({
    required this.controls,
    this.files,
    this.navigationCoordinator,
    this.openScheduleItem,
    this.onRefresh,
    required this.action,
    this.item,
    this.sourceId,
    this.accountId,
    this.initialDate,
    this.editOnOpen = false,
    this.initialOccurrenceScope,
    this.onEditRequested,
    required this.onClose,
    this.detailActions,
    super.key,
  });

  final JournalControls controls;
  final JournalFileActions? files;
  final Future<void> Function(SyncScope)? onRefresh;
  final JournalPaneAction action;
  final JournalScheduleItem? item;
  final String? sourceId;
  final String? accountId;
  final DateTime? initialDate;
  final bool editOnOpen;
  final bool? initialOccurrenceScope;
  final ValueChanged<bool?>? onEditRequested;
  final VoidCallback onClose;
  final Widget Function(
    List<({String label, JournalDetailAction icon, VoidCallback? run})> actions,
  )?
  detailActions;
  final BusyMaxWindowCloseCoordinator? navigationCoordinator;
  final Future<void> Function(BuildContext, ScheduleWorkspaceCommand)?
  openScheduleItem;

  @override
  ConsumerState<JournalPane> createState() => _JournalPaneState();
}

class _JournalPaneState extends ConsumerState<JournalPane> {
  String? _error;
  JournalSnapshot? _open;
  JournalSubscriptionEntry? _subscriptionEntry;
  JournalOccurrenceDraft? _occurrenceEdit;
  DavCollection? _create;
  bool _busy = false;
  bool _editing = false;
  bool _confirmReadDelete = false;
  bool _loadingPane = false;
  JournalImportReview? _unassignedImport;
  String? _moveSource;
  String? _notice;
  final _recoveryChoices = <String?, int>{};
  final _collectionName = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.action
        case JournalPaneAction.open ||
            JournalPaneAction.create ||
            JournalPaneAction.import ||
            JournalPaneAction.renameCollection) {
      _loadingPane = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_loadPane(widget.action));
      });
    }
  }

  Future<void> _loadPane(JournalPaneAction action) async {
    await _run(() async {
      final repository = ref.read(_journalRepository);
      switch (action) {
        case JournalPaneAction.open:
          final item = widget.item!;
          if (item.subscription case final entry?) {
            if (mounted) setState(() => _subscriptionEntry = entry);
          } else if (item.entry case final entry?) {
            final current = await repository.read(entry);
            if (!mounted) return;
            // Conflicts already have their own review flow. Open it directly
            // so a blocked journal can be resolved from the item's normal tap.
            if (widget.onEditRequested case final review?) {
              final pending = await ref.read(
                _pending(entry.davObjectId).future,
              );
              if (!mounted) return;
              if (pending?.state == 'conflict') {
                review(null);
                return;
              }
            }
            setState(() {
              _open = current;
              _editing = widget.editOnOpen;
            });
            if (widget.initialOccurrenceScope case final future?) {
              final occurrence = item.occurrence;
              if (occurrence != null) {
                final draft = repository.inspectOccurrence(
                  current,
                  occurrence,
                  thisAndFuture: future,
                );
                setState(() => _occurrenceEdit = draft);
              }
            }
          }
        case JournalPaneAction.create:
          final sources = await repository.watchSources().first;
          final writable = sources.where(
            (source) =>
                collectionCapabilitiesFromStored(source)
                    .canAttemptCreateJournal,
          );
          final source =
              writable
                  .where((source) => source.id == widget.sourceId)
                  .firstOrNull ??
              writable.firstOrNull;
          if (mounted) setState(() => _create = source);
        case JournalPaneAction.import:
          if (await ref.read(_importReviews).watch().first != null) return;
          if (widget.sourceId case final id?) await _loadImport(id);
        case JournalPaneAction.renameCollection:
          final source = (await repository.watchSources().first)
              .where((source) => source.id == widget.sourceId)
              .firstOrNull;
          if (mounted && source != null) {
            _collectionName.text = source.displayName;
          }
        case JournalPaneAction.createCollection ||
            JournalPaneAction.removeCollection ||
            JournalPaneAction.exportCollection:
          break;
      }
    });
    if (mounted) setState(() => _loadingPane = false);
  }

  bool _canImport(DavCollection source, {bool? journalMessage}) {
    final caps = collectionCapabilitiesFromStored(source);
    return caps.canAttemptCreateJournal ||
        (journalMessage != false && caps.canAttemptUpdateJournal);
  }

  Future<void> _loadImport(String sourceId) async {
    final repository = ref.read(_journalRepository);
    Future<DavCollection?> destination(bool? journalMessage) async =>
        (await repository.listSources())
            .where(
              (source) =>
                  source.id == sourceId &&
                  _canImport(source, journalMessage: journalMessage),
            )
            .firstOrNull;
    if (await destination(_unassignedImport?.preview.isJournalMessage) ==
            null ||
        !mounted) {
      return;
    }
    final files = widget.files;
    if (files == null) return;
    if (_unassignedImport == null) {
      final bytes = await files.read();
      if (!mounted) return;
      if (bytes == null) {
        widget.onClose();
        return;
      }
      final preview = ref
          .read(icalImportServiceProvider)
          .parsePreview(bytes)
          .nativePreview;
      _unassignedImport = JournalImportReview(
        NextcloudNativeImportPreview(
          preview.resources
              .where((entry) => entry.componentType == 'VJOURNAL')
              .toList(),
          preview.rejected,
          preview.schedulingMethod,
        ),
        bytes,
      );
    }
    final review = _unassignedImport!;
    final source = await destination(review.preview.isJournalMessage);
    if (source == null || !mounted) return;
    await ref.read(_importReviews).begin(source, review);
    _unassignedImport = null;
  }

  @override
  void dispose() {
    _collectionName.dispose();
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

  String _importOutcomeLabel(
    AppLocalizations l10n,
    NativeImportItemResult result,
  ) {
    if (result.status == NativeImportItemStatus.queued) {
      final operationId = result.operationId;
      final operation = operationId == null
          ? null
          : ref.watch(_importOperation(operationId)).valueOrNull;
      if (operation?.lastErrorCode case final code?) {
        return l10n.syncFailed(operation?.lastErrorMessage ?? code);
      }
      return operation == null ? l10n.importQueued(1) : l10n.pendingSync;
    }
    final explanation = result.safeMessage ?? result.code;
    return switch (result.status) {
      NativeImportItemStatus.queued => l10n.pendingSync,
      NativeImportItemStatus.duplicate => l10n.importDuplicatesSkipped(1),
      NativeImportItemStatus.unsupported =>
        explanation == null
            ? l10n.importUnsupportedSets(1)
            : explanation == 'DavImportDestinationDenied'
            ? l10n.davPermissionChanged
            : l10n.importIcsFailed(explanation),
      NativeImportItemStatus.failed => l10n.importIcsFailed(
        explanation ?? l10n.journalOperationFailed,
      ),
    };
  }

  void _closeEntry() => widget.onClose();

  Future<void> _openReference(
    JournalSnapshot origin,
    JournalLinkTarget reference,
  ) => _run(() async {
    final repository = ref.read(_journalRepository);
    final identity = _linkIdentity(reference);
    final target = (await repository.relatedEntries(origin))
        .where((item) => _linkIdentity(item) == identity)
        .singleOrNull;
    if (!mounted) return;
    if (target == null) {
      setState(() => _error = AppLocalizations.of(context).scheduleUnavailable);
      return;
    }
    switch (target) {
      case UnresolvedJournalLink():
        setState(
          () => _error = AppLocalizations.of(context).scheduleUnavailable,
        );
      case LinkedJournal(:final entry):
        final next = await repository.read(entry);
        if (!mounted) return;
        setState(() {
          _open = next;
          _occurrenceEdit = null;
          _editing = false;
        });
      case LinkedXml(:final uri):
        if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
            mounted) {
          setState(
            () => _error = AppLocalizations.of(context).scheduleUnavailable,
          );
        }
      case LinkedEvent() || LinkedTask():
        final sequence = DateTime.now().microsecondsSinceEpoch;
        final command = switch (target) {
          LinkedEvent(:final event) => ScheduleWorkspaceCommand(
            ScheduleWorkspaceCommandKind.openCalendarEvent,
            sequence,
            date: calendarEventStartAsLocal(event),
            accountId: event.accountId,
            sourceId: event.calendarSourceId,
            itemId: event.id,
          ),
          LinkedTask(:final task) => ScheduleWorkspaceCommand(
            ScheduleWorkspaceCommandKind.openTask,
            sequence,
            accountId: task.accountId,
            sourceId: task.taskListId,
            itemId: task.id,
          ),
          _ => throw StateError('Expected a schedule reference.'),
        };
        if (widget.openScheduleItem case final open?) {
          await open(context, command);
        } else {
          widget.onClose();
          ref.read(scheduleWorkspaceCommandProvider.notifier).state = command;
        }
    }
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ui = widget.controls;
    final repository = ref.watch(_journalRepository);
    final sources =
        ref.watch(_journalSources).valueOrNull ?? const <DavCollection>[];
    final filteredSource = sources
        .where((source) => source.id == widget.sourceId)
        .firstOrNull;
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
    if (_loadingPane &&
        current == null &&
        _create == null &&
        _subscriptionEntry == null) {
      return widget.onEditRequested == null
          ? Center(child: Text(l10n.scheduleLoading))
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Text(l10n.scheduleLoading),
            );
    }

    if (_subscriptionEntry case final entry?) {
      return ListView(
        shrinkWrap: widget.onEditRequested != null,
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
          ui.button(l10n.close, _busy ? null : _closeEntry),
        ],
      );
    }

    if (current?.pendingRecovery case final recovery?) {
      final recoveryWritable = recovery.operation.operationType == 'dav.create'
          ? caps?.canAttemptCreateJournal == true
          : caps?.canAttemptUpdateJournal == true;
      if (editorSource?.journalInventoryComplete != true || !recoveryWritable) {
        return Column(
          children: [
            Text(l10n.davPermissionChanged),
            ui.button(l10n.close, _closeEntry),
          ],
        );
      }
      final competing = DavJournalPendingRecovery.competingComponents(
        IcalSemanticDocument.parse(recovery.invalidCandidate),
      ).entries;
      final report = const JsonEncoder.withIndent('  ')
          .convert(recovery.toJson());
      return ListView(
        shrinkWrap: widget.onEditRequested != null,
        padding: const EdgeInsets.all(16),
        children: [
          Text(l10n.journalPendingRecovery),
          if (!recovery.canReplace) Text(l10n.journalRecoveryUncertain),
          if (_error != null) Text(_error!),
          for (final group in competing) ...[
            Text(group.value.first.recurrenceId?.rawValue ?? l10n.noDate),
            for (final component in group.value.indexed) ...[
              ui.button(
                '${_recoveryChoices[group.key] == component.$1 ? '✓ ' : ''}'
                '${component.$1 + 1}. ${component.$2.summary ?? l10n.untitledJournal}',
                !_busy && recovery.canReplace && recoveryWritable
                    ? () => setState(
                        () => _recoveryChoices[group.key] = component.$1,
                      )
                    : null,
              ),
              for (final property in component.$2.documentComponent.properties)
                Text(property.serializeLogicalLine()),
              ...journalReadOnlyChildren(component.$2.documentComponent),
            ],
          ],
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ui.button(
                l10n.registrationCopyAll,
                _busy
                    ? null
                    : () => _run(
                        () => Clipboard.setData(ClipboardData(text: report)),
                      ),
              ),
              if (widget.files?.exportDraft != null)
                ui.button(
                  l10n.journalExportRecovery,
                  _busy
                      ? null
                      : () => _run(() => widget.files!.exportDraft!(report)),
                ),
              if (recovery.canCheckServer)
                ui.button(
                  l10n.journalCheckRecovery,
                  _busy
                      ? null
                      : () => _run(() async {
                          final op = recovery.operation;
                          await DavPendingOperationQueue(
                            database: repository.database,
                          ).retryBlockedOperation(
                            accountId: op.accountId,
                            operationId: op.id,
                          );
                          final scope = davCollectionSyncScope(
                            op.accountId,
                            editorSource!.id,
                          );
                          if (widget.onRefresh case final refresh?) {
                            await refresh(scope);
                          } else {
                            final outcome = await ref.read(
                              manualSyncRunnerProvider,
                            )(scope);
                            if (outcome.needsAttention && mounted) {
                              setState(
                                () => _error = l10n.journalOperationFailed,
                              );
                            }
                          }
                          final fresh = await repository.read(current!.entry);
                          if (mounted) setState(() => _open = fresh);
                        }),
                ),
              ui.button(
                l10n.journalReapplyReviewedUpdate,
                !_busy &&
                        recovery.canReplace &&
                        recoveryWritable &&
                        competing.every(
                          (group) => _recoveryChoices.containsKey(group.key),
                        )
                    ? () => _run(() async {
                        final fresh = await repository.read(current!.entry);
                        final reviewed = fresh.pendingRecovery;
                        if (reviewed == null ||
                            reviewed.invalidCandidate !=
                                recovery.invalidCandidate ||
                            reviewed.operation.mutationPatchJson !=
                                recovery.operation.mutationPatchJson ||
                            reviewed.operation.requestJson !=
                                recovery.operation.requestJson ||
                            !reviewed.canReplace) {
                          throw const DavException(
                            kind: DavErrorKind.conflict,
                            code: 'DavJournalRecoveryChanged',
                            safeMessage: 'Reopen this journal to review the current pending update.',
                          );
                        }
                        await repository.repairPendingUpdate(
                          reviewed,
                          _recoveryChoices,
                        );
                        if (mounted) _closeEntry();
                      })
                    : null,
                primary: true,
              ),
              ui.button(l10n.close, _busy ? null : _closeEntry),
            ],
          ),
        ],
      );
    }

    if (current != null &&
        widget.action == JournalPaneAction.open &&
        !_editing &&
        (conflict == null || widget.onEditRequested != null)) {
      final occurrence =
          widget.item?.entry?.componentId == current.entry.componentId
          ? widget.item?.occurrence
          : null;
      final journal = occurrence == null
          ? current.component
          : JournalComponent(occurrence.effectiveComponent.documentComponent);
      final item = widget.item;
      final start = item?.entry?.componentId == current.entry.componentId
          ? item?.start
          : null;
      final date = start == null
          ? journal.start?.rawValue ?? l10n.noDate
          : DateFormat.yMMMd(Localizations.localeOf(context).toLanguageTag())
                .format(start);
      final actions =
          <({String label, JournalDetailAction icon, VoidCallback? run})>[
            if (widget.files != null)
              (
                label: l10n.export,
                icon: JournalDetailAction.share,
                run: _busy
                    ? null
                    : () => _run(
                        () => widget.files!.export(current.effectiveRawIcs),
                      ),
              ),
            (
              label: l10n.editJournalEntry,
              icon: JournalDetailAction.edit,
              run: _busy
                  ? null
                  : () {
                      if (widget.onEditRequested case final open?) {
                        open(null);
                      } else {
                        setState(() => _editing = true);
                      }
                    },
            ),
            if (caps?.canAttemptDeleteJournal == true)
              (
                label: l10n.delete,
                icon: JournalDetailAction.delete,
                run: _busy
                    ? null
                    : () => setState(() => _confirmReadDelete = true),
              ),
            (
              label: l10n.close,
              icon: JournalDetailAction.close,
              run: _busy ? null : _closeEntry,
            ),
          ];
      return ListView(
        shrinkWrap: widget.onEditRequested != null,
        padding: const EdgeInsets.all(16),
        children: [
          Text(journal.title ?? l10n.untitledJournal),
          Text(current.collection.displayName),
          Text(
            [
              date,
              if (start != null && item?.allDay == false)
                BusyMaxTimeFormatScope.of(context).format(start),
            ].join(' · '),
          ),
          if (journal.status case final status?) Text(status),
          if (pending != null)
            Text(pending.lastErrorMessage ?? l10n.pendingSync),
          for (final body in journal.descriptions) Text(body.decodedTextValue),
          if (!writable) Text(l10n.readOnlySharedCollection),
          if (_error != null) Semantics(liveRegion: true, child: Text(_error!)),
          if (widget.detailActions case final buildActions?)
            buildActions(actions)
          else
            Wrap(
              spacing: 8,
              children: [
                for (final action in actions)
                  ui.button(action.label, action.run),
              ],
            ),
          if (_confirmReadDelete) ...[
            Text(l10n.journalDeleteSeries),
            Wrap(
              spacing: 8,
              children: [
                ui.button(
                  l10n.cancel,
                  () => setState(() => _confirmReadDelete = false),
                ),
                ui.button(
                  l10n.delete,
                  _busy
                      ? null
                      : () => _run(() async {
                          if (await repository.readDraft(
                                'entry:${current.entry.componentId}',
                              ) !=
                              null) {
                            if (widget.onEditRequested case final open?) {
                              open(null);
                            } else {
                              setState(() => _editing = true);
                            }
                            return;
                          }
                          await repository.deleteResource(current);
                          if (mounted) _closeEntry();
                        }),
                ),
              ],
            ),
          ],
          if (occurrence != null && writable && !_confirmReadDelete)
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final future in [false, true])
                  ui.button(
                    future
                        ? l10n.journalEditFuture
                        : l10n.journalEditOccurrence,
                    _busy
                        ? null
                        : () => _run(() async {
                            if (widget.onEditRequested case final open?) {
                              open(future);
                              return;
                            }
                            final draft = repository.inspectOccurrence(
                              current,
                              occurrence,
                              thisAndFuture: future,
                            );
                            if (mounted) {
                              setState(() {
                                _occurrenceEdit = draft;
                                _editing = true;
                              });
                            }
                          }),
                  ),
              ],
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
        navigationCoordinator: widget.navigationCoordinator,
        snapshot: editing,
        initialDate: widget.initialDate,
        destinationChoices: current == null
            ? [
                for (final source in sources)
                  if (collectionCapabilitiesFromStored(source)
                      .canAttemptCreateJournal)
                    (id: source.id, label: _journalSourceName(source)),
              ]
            : const [],
        changeDestination: (sourceId) => setState(
          () =>
              _create = sources.singleWhere((source) => source.id == sourceId),
        ),
        relatedEntries: editing == null
            ? const []
            : ref.watch(_relatedEntries(editing)).valueOrNull ?? const [],
        openReference: (target) => _openReference(editing!, target),
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
        recoverAsNew: current == null || caps?.canAttemptCreateJournal != true
            ? null
            : (content) => _run(() async {
                final source = editorSource!;
                final refresh = await ref.read(manualSyncRunnerProvider)(
                  davCollectionSyncScope(source.accountId, source.id),
                );
                if (refresh.needsAttention) {
                  throw const DavException(
                    kind: DavErrorKind.authorization,
                    code: 'DavJournalRecoveryRefreshRequired',
                    safeMessage: 'Refresh the journal collection to check its permissions before recovering this draft.',
                  );
                }
                final live = await repository.prepareDraftRecovery(
                  source,
                  content,
                );
                if (!mounted) return;
                setState(() {
                  _open = null;
                  _occurrenceEdit = null;
                  _create = live;
                });
              }),
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

    final reviewState = ref.watch(_importReview);
    final review = reviewState.valueOrNull;
    if (widget.action == JournalPaneAction.import && review == null) {
      final destinations = sources.where(
        (source) => _canImport(
          source,
          journalMessage: _unassignedImport?.preview.isJournalMessage,
        ),
      );
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_error != null) Text(_error!),
          if (widget.sourceId != null || _unassignedImport != null)
            Text(l10n.davPermissionChanged),
          ui.choose(
            l10n.journalCollection,
            '',
            [
              (id: '', label: '—'),
              for (final source in destinations)
                (id: source.id, label: _journalSourceName(source)),
            ],
            (id) {
              if (!_busy && id.isNotEmpty) _run(() => _loadImport(id));
            },
          ),
          ui.button(l10n.close, _busy ? null : _closeEntry),
        ],
      );
    }
    if (widget.action == JournalPaneAction.import && review != null) {
      final pendingImport = review.preview;
      final destinations = sources
          .where(
            (source) => _canImport(
              source,
              journalMessage: pendingImport.isJournalMessage,
            ),
          )
          .toList();
      final reviewedId = review.destinationId;
      final destination = destinations
          .where((source) => source.id == reviewedId)
          .firstOrNull;
      final remaining = destination == null
          ? null
          : review.remaining(destination.id);
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(l10n.importIcsFile),
          ui.choose(
            l10n.journalCollection,
            destination?.id ?? '',
            [
              (id: '', label: l10n.journalCollection),
              for (final source in destinations)
                (id: source.id, label: source.displayName),
            ],
            (value) {
              if (_busy || value.isEmpty || value == reviewedId) return;
              final selected = destinations.singleWhere(
                (source) => source.id == value,
              );
              _run(
                () => ref
                    .read(_importReviews)
                    .selectDestination(review, selected),
              );
            },
          ),
          if (pendingImport.isJournalMessage)
            Text(pendingImport.schedulingMethod!),
          if (reviewedId != null && destination == null)
            Text(l10n.davPermissionChanged),
          if (_error != null) Text(_error!),
          for (final entry
              in remaining?.resources.take(100) ??
                  const <NativeImportResource>[])
            Text(
              IcalDocument.parse(entry.rawIcs).calendarComponents.first
                      .firstProperty('SUMMARY')
                      ?.decodedTextValue ??
                  entry.uid,
            ),
          for (final result in review.results) ...[
            Text(result.uid),
            Text(_importOutcomeLabel(l10n, result)),
          ],
          if (pendingImport.schedulingMethod != null &&
              !pendingImport.isJournalMessage)
            Text(l10n.journalOperationFailed),
          Wrap(
            spacing: 8,
            children: [
              ui.button(
                l10n.save,
                _busy ||
                        destination == null ||
                        remaining == null ||
                        remaining.resources.isEmpty ||
                        (pendingImport.schedulingMethod != null &&
                            !pendingImport.isJournalMessage)
                    ? null
                    : () => _run(
                        () =>
                            ref.read(_importReviews).queue(review, destination),
                      ),
                primary: true,
              ),
              ui.button(l10n.close, _busy ? null : _closeEntry),
              if (widget.files?.exportDraft != null)
                ui.button(
                  l10n.journalExportRecovery,
                  _busy
                      ? null
                      : () => _run(
                          () => widget.files!.exportDraft!(review.encode()),
                        ),
                ),
              ui.button(
                l10n.discardChangesAction,
                _busy
                    ? null
                    : () => _run(() async {
                        await ref.read(_importReviews).discard(review);
                        if (mounted) _closeEntry();
                      }),
              ),
            ],
          ),
        ],
      );
    }
    return _collectionPane(context, widget.action, filteredSource);
  }

  String _journalSourceName(DavCollection source) {
    final account = ref
        .watch(accountsStreamProvider)
        .valueOrNull
        ?.where((account) => account.id == source.accountId)
        .firstOrNull;
    return account == null
        ? source.displayName
        : '${source.displayName} · ${account.displayLabel}';
  }

  Widget _collectionPane(
    BuildContext context,
    JournalPaneAction action,
    DavCollection? source,
  ) {
    final l10n = AppLocalizations.of(context);
    final ui = widget.controls;
    final accountId = source?.accountId ?? widget.accountId;
    final account = ref
        .watch(accountsStreamProvider)
        .valueOrNull
        ?.where((account) => account.id == accountId)
        .firstOrNull;
    final repository = ref.watch(_journalRepository);
    final collectionAction = switch (action) {
      JournalPaneAction.createCollection => (
        l10n.create,
        () async {
          final result = await ref
              .read(
                davCalendarCollectionMutationServiceForAccountProvider(
                  accountId!,
                ),
              )
              .createJournalCollection(_collectionName.text.trim());
          if (mounted && result.refreshPending) {
            setState(() => _notice = l10n.pendingSync);
          }
        },
      ),
      JournalPaneAction.renameCollection => (
        l10n.save,
        () async {
          final name = _collectionName.text.trim();
          if (name.isEmpty) {
            throw const FormatException('A collection name is required.');
          }
          final changes = {
            const DavPropertyName(davNamespace, 'displayname'): name,
          };
          if (account?.provider == BusyProvider.nextcloud) {
            await ref
                .read(nextcloudCollectionServiceProvider(accountId!))
                .update(source!.id, changes);
          } else {
            await ref
                .read(davCollectionAdministrationProvider(accountId!))
                .update(source!.id, changes);
          }
        },
      ),
      JournalPaneAction.removeCollection => (
        l10n.delete,
        () async {
          if (await repository.hasDrafts(source!.id)) {
            throw DavException(
              kind: DavErrorKind.conflict,
              code: 'DavJournalDraftsRemain',
              safeMessage: l10n.journalCollectionHasDrafts,
            );
          }
          if (account?.provider == BusyProvider.nextcloud) {
            await ref
                .read(nextcloudCollectionServiceProvider(accountId!))
                .remove(source.id);
          } else {
            await ref
                .read(davCollectionAdministrationProvider(accountId!))
                .remove(source.id);
          }
        },
      ),
      JournalPaneAction.exportCollection
          when widget.files?.exportCollection != null =>
        (
          l10n.export,
          () async {
            final exported = await DavNativeExportService(repository.database)
                .collectionForReview(accountId!, source!.id);
            final path = await widget.files!.exportCollection!(
              exported.resources
                  .where((item) => item.componentType == 'VJOURNAL')
                  .toList(),
            );
            if (mounted) {
              setState(
                () => _notice = [
                  if (path != null) l10n.exportedFile(path),
                  if (exported.excludedJournalCount > 0)
                    l10n.journalCollectionExportRecovery,
                ].join('\n'),
              );
            }
          },
        ),
      _ => null,
    };
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (source != null) Text(source.displayName),
        if (action == JournalPaneAction.removeCollection)
          Text(
            account?.provider == BusyProvider.nextcloud && source != null
                ? l10n.deleteCalendarConfirmation(source.displayName)
                : l10n.journalDeleteCollectionConfirmation,
          ),
        if (action == JournalPaneAction.createCollection ||
            action == JournalPaneAction.renameCollection)
          ui.input(l10n.title, controller: _collectionName),
        if (collectionAction == null && _error == null)
          Text(l10n.scheduleUnavailable),
        if (_notice?.isNotEmpty == true)
          Semantics(liveRegion: true, child: Text(_notice!)),
        if (_error != null) Semantics(liveRegion: true, child: Text(_error!)),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: Wrap(
            spacing: 8,
            children: [
              ui.button(
                collectionAction == null ? l10n.close : l10n.cancel,
                _busy ? null : _closeEntry,
              ),
              if (collectionAction case (final label, final run))
                ui.button(
                  label,
                  _busy ||
                          accountId == null ||
                          (source == null &&
                              action != JournalPaneAction.createCollection)
                      ? null
                      : () => _run(() async {
                          await run();
                          if (mounted &&
                              _notice == null &&
                              action != JournalPaneAction.exportCollection) {
                            _closeEntry();
                          }
                        }),
                  primary: true,
                ),
            ],
          ),
        ),
      ],
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
    this.navigationCoordinator,
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
    this.recoverAsNew,
    this.destinationChoices = const [],
    this.changeDestination,
    this.initialDate,
    required this.relatedEntries,
    required this.openReference,
  });

  final JournalControls ui;
  final BusyMaxWindowCloseCoordinator? navigationCoordinator;
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
  final Future<void> Function(String content)? recoverAsNew;
  final List<JournalLinkTarget> relatedEntries;
  final List<JournalChoice> destinationChoices;
  final ValueChanged<String>? changeDestination;
  final DateTime? initialDate;
  final Future<void> Function(JournalLinkTarget) openReference;

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
  late final _date = TextEditingController(
    text:
        _original?.rawValue ??
        (widget.snapshot == null && widget.initialDate != null
            ? DateFormat('yyyyMMdd').format(widget.initialDate!)
            : null),
  );
  late final _zone = TextEditingController(
    text: _original?.parameterValue('TZID'),
  );
  late String _status = widget.snapshot?.component.status ?? '';
  late String _mode =
      widget.snapshot?.component.start?.kind.name ??
      (widget.snapshot == null && widget.initialDate != null ? 'date' : '');
  String _lastTimedMode = 'floatingDateTime';
  bool _timeValid = true;
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
  bool _draftLoadFailed = false;
  bool _draftListenersAttached = false;
  bool _draftLeaving = false;
  String? _unreadableDraft;
  late String? _draftBaselineRawIcs = widget.snapshot?.effectiveRawIcs;
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
    if (mounted && !_loadingDraft) setState(() => _loadingDraft = true);
    try {
      final draft = await widget.repository.readDraft(widget.draftId);
      if (!mounted) return;
      if (draft != null) {
        _hasDraft = true;
        _draftDurable = true;
        _staleDraft = draft.baselineDigest != _baselineDigest;
        try {
          _restoreDraft(draft.contentJson);
        } on Object {
          _unreadableDraft = draft.contentJson;
        }
      }
      _draftLoadFailed = false;
    } on Object {
      _draftLoadFailed = true;
    }
    if (!mounted) return;
    if (!_draftListenersAttached) {
      for (final controller in [_title, _date, _zone]) {
        controller.addListener(_persistDraft);
      }
      for (final description in _descriptions) {
        _listenDescription(description);
      }
      _draftListenersAttached = true;
    }
    _lastDraftContent = _draftContent();
    setState(() => _loadingDraft = false);
  }

  void _restoreDraft(String saved) {
    final data = (jsonDecode(saved) as Map).cast<String, Object?>();
    final version = data['version'];
    if (version != null && version != 2) {
      throw const FormatException('Unrecognized journal draft version.');
    }
    final title = data['title'] as String;
    final date = data['date'] as String;
    final zone = data['zone'] as String;
    final mode = data['mode'] as String;
    final status = data['status'] as String;
    final frequency = data['frequency'] as String;
    final baseline = data['baselineRawIcs'] as String?;
    final descriptions = <_DescriptionDraft>[];
    final attachments = <IcalProperty>[];
    final details = <JournalPropertyDraft>[];
    final children = <JournalChildDraft>[];
    try {
      for (final property in _draftProperties(data, 'DESCRIPTION')) {
        descriptions.add(_DescriptionDraft(property));
      }
      attachments.addAll(_draftProperties(data, 'ATTACH'));
      if (data['details'] case final List entries) {
        for (final item in entries.cast<Map>()) {
          final name = item['name'] as String;
          if (!journalDetailsFields.contains(name)) {
            throw const FormatException('Unrecognized journal draft field.');
          }
          final field = item.cast<String, Object?>();
          details.add(
            version == 2
                ? JournalPropertyDraft.fromDraftJson(field, _persistDraft)
                : JournalPropertyDraft(
                    name,
                    _persistDraft,
                    journalDraftPropertyFromJson(name, field),
                  ),
          );
        }
      }
      if (data['children'] case final List entries) {
        for (final item in entries.cast<Map>()) {
          final child = item.cast<String, Object?>();
          children.add(
            version == 2
                ? JournalChildDraft.fromDraftJson(child, _persistDraft)
                : JournalChildDraft(
                    journalChildDraftFromJson(child),
                    _persistDraft,
                  ),
          );
        }
      }
    } on Object {
      for (final description in descriptions) {
        description.dispose();
      }
      for (final detail in details) {
        detail.dispose();
      }
      for (final child in children) {
        child.dispose();
      }
      rethrow;
    }
    _title.text = title;
    _date.text = date;
    _zone.text = zone;
    _mode = mode;
    _status = status;
    _frequency = frequency;
    _draftBaselineRawIcs =
        baseline ?? (_staleDraft ? null : widget.snapshot?.effectiveRawIcs);
    for (final description in _descriptions) {
      description.dispose();
    }
    for (final detail in _details) {
      detail.dispose();
    }
    for (final child in _children) {
      child.dispose();
    }
    _descriptions
      ..clear()
      ..addAll(descriptions);
    if (_draftListenersAttached) {
      for (final description in _descriptions) {
        _listenDescription(description);
      }
    }
    _attachments
      ..clear()
      ..addAll(attachments);
    _details
      ..clear()
      ..addAll(details);
    _children
      ..clear()
      ..addAll(children);
  }

  Iterable<IcalProperty> _draftProperties(
    Map<String, Object?> data,
    String name,
  ) => (data[name] as List).map(
    (item) => journalDraftPropertyFromJson(
      name,
      (item as Map).cast<String, Object?>(),
    ),
  );

  void _listenDescription(_DescriptionDraft draft) {
    for (final controller in [draft.text, draft.language, draft.alternate]) {
      controller.addListener(_persistDraft);
    }
  }

  String _draftContent() => jsonEncode({
    'version': 2,
    'baselineRawIcs': _draftBaselineRawIcs,
    'title': _title.text,
    'date': _date.text,
    'zone': _zone.text,
    'mode': _mode,
    'status': _status,
    'frequency': _frequency,
    'details': [for (final field in _details) field.toDraftJson()],
    'children': [for (final child in _children) child.toDraftJson()],
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

  void _persistDraft({bool retry = false}) {
    if (_loadingDraft ||
        _saving ||
        _staleDraft ||
        _draftLoadFailed ||
        _unreadableDraft != null) {
      return;
    }
    final collectionId = widget.source?.id ?? widget.snapshot?.collection.id;
    if (collectionId == null) return;
    final content = _draftContent();
    if (!retry && content == _lastDraftContent) return;
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
    if (_saving ||
        widget.busy ||
        _draftLeaving ||
        _loadingDraft ||
        _draftLoadFailed) {
      return false;
    }
    setState(() => _draftLeaving = true);
    try {
      Future<void> pending;
      do {
        pending = _draftWrite;
        await pending;
      } while (!identical(pending, _draftWrite));
      return !_draftFailed;
    } finally {
      if (mounted) setState(() => _draftLeaving = false);
    }
  }

  Future<void> _requestClose() async {
    if (await _flushDraft() && mounted) widget.close();
  }

  void _changeDraft(VoidCallback change) {
    if (_saving || widget.busy || _draftLeaving) return;
    setState(change);
    _persistDraft();
  }

  Future<void> _save() async {
    if (_saving ||
        widget.busy ||
        _staleDraft ||
        !widget.writable ||
        _draftLoadFailed ||
        _unreadableDraft != null) {
      return;
    }
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
    if (_saving || widget.busy || _draftLeaving || _draftLoadFailed) return;
    await widget.run(() async {
      await _draftWrite;
      await widget.repository.discardDraft(widget.draftId);
      if (mounted) widget.close();
    });
  }

  String _recoveryJson() => const JsonEncoder.withIndent('  ').convert({
    'format': 'busymax-journal-draft',
    'version': 1,
    'draftId': widget.draftId,
    'savedIcalendar': widget.snapshot?.effectiveRawIcs,
    'editorStateJson': _unreadableDraft ?? _draftContent(),
  });

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

  List<JournalChoice> _timeModes(AppLocalizations l10n) => [
    (id: 'floatingDateTime', label: l10n.journalFloatingTime),
    (id: 'utcDateTime', label: 'UTC'),
    (id: 'tzidDateTime', label: l10n.journalZonedTime),
  ];

  void _toggleDetails() => setState(() => _showDetails = !_showDetails);

  void _setDateMode(String mode) {
    if (_mode == mode) return;
    if (_mode.endsWith('DateTime')) _lastTimedMode = _mode;
    final civil =
        _civilDateTime ??
        DateTime.tryParse(_date.text.trim().replaceFirst(RegExp(r'[Zz]$'), ''));
    _changeDraft(() {
      _mode = mode;
      _timeValid = true;
      if (mode.isNotEmpty && (civil != null || _date.text.isEmpty)) {
        _date.text = DateFormat(
          mode == 'date' ? 'yyyyMMdd' : "yyyyMMdd'T'HHmmss",
        ).format(civil ?? widget.initialDate ?? DateTime.now());
      }
    });
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
                      ui.button(l10n.journalEditOccurrence, () async {
                        if (await _flushDraft() && mounted) {
                          open(occurrence, false);
                        }
                      }),
                      ui.button(l10n.journalEditFuture, () async {
                        if (await _flushDraft() && mounted) {
                          open(occurrence, true);
                        }
                      }),
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
    final recovering =
        _hasDraft &&
        (_staleDraft || _unreadableDraft != null || !widget.writable);
    final canEdit =
        widget.writable &&
        !_staleDraft &&
        !_draftLoadFailed &&
        _unreadableDraft == null;
    final snapshot = widget.snapshot;
    final component = snapshot?.component.component;
    final title = component?.firstProperty('SUMMARY');
    final status = component?.firstProperty('STATUS');
    final derivedDate = isDerivedJournalProperty(_original);
    final timed = !derivedDate && _mode.isNotEmpty && _mode != 'date';
    final knownStatuses = ['', 'DRAFT', 'FINAL', 'CANCELLED'];
    if (_loadingDraft) return const SizedBox.shrink();
    final locked = _saving || widget.busy || _draftLeaving;
    final draftNeedsRecovery =
        _draftFailed || _draftLoadFailed || (_hasDraft && !_draftDurable);
    final layout = ui is JournalEditorLayout ? ui as JournalEditorLayout : null;
    Widget group(List<Widget> children) =>
        layout?.group(children) ??
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        );
    return BusyMaxWindowCloseGuard(
      onCloseRequested: _flushDraft,
      navigationCoordinator: widget.navigationCoordinator,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) unawaited(_requestClose());
        },
        child: AbsorbPointer(
          absorbing: locked,
          child: ExcludeFocus(
            excluding: locked,
            child: _editorBody(
              layout: layout,
              locked: locked,
              canEdit: canEdit,
              canSave: canEdit && !locked && (!timed || _timeValid),
              fields: [
                if (widget.destinationChoices.isNotEmpty &&
                    widget.source != null)
                  ui.choose(
                    l10n.journalCollection,
                    widget.source!.id,
                    widget.destinationChoices,
                    (destination) async {
                      if (destination != widget.source!.id &&
                          await _flushDraft() &&
                          mounted) {
                        widget.changeDestination?.call(destination);
                      }
                    },
                  )
                else
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
                if (_draftFailed ||
                    _draftLoadFailed ||
                    _unreadableDraft != null)
                  Text(l10n.journalDraftWriteFailed),
                if (_draftFailed || _draftLoadFailed)
                  ui.button(
                    l10n.retry,
                    locked
                        ? null
                        : () {
                            if (_draftLoadFailed) {
                              unawaited(_loadDraft());
                            } else {
                              _persistDraft(retry: true);
                            }
                          },
                  ),
                if (_hasDraft && (_draftDurable || _staleDraft))
                  Text(
                    _staleDraft
                        ? l10n.journalDraftStale
                        : l10n.journalDraftSaved,
                  ),
                if (widget.conflict case final conflict?)
                  ExcludeFocus(
                    excluding: draftNeedsRecovery,
                    child: AbsorbPointer(
                      absorbing: draftNeedsRecovery,
                      child: conflict,
                    ),
                  ),
                if (canEdit) ...[
                  group([
                    if (isDerivedJournalProperty(title))
                      Text(title!.decodedTextValue)
                    else
                      ui.input(l10n.title, controller: _title),
                  ]),
                  group([
                    if (derivedDate)
                      Text(_original!.rawValue)
                    else if (layout == null)
                      ui.choose(l10n.journalDate, _mode, [
                        (id: '', label: l10n.noDate),
                        (id: 'date', label: l10n.allDay),
                        ..._timeModes(l10n),
                      ], _setDateMode)
                    else ...[
                      ui.choose(
                        l10n.journalDate,
                        _mode.isEmpty ? '' : 'dated',
                        [
                          (id: '', label: l10n.noDate),
                          (id: 'dated', label: l10n.journalDated),
                        ],
                        (value) => _setDateMode(value.isEmpty ? '' : 'date'),
                      ),
                      if (_mode.isNotEmpty)
                        layout.timeMode(
                          _mode == 'date',
                          (allDay) =>
                              _setDateMode(allDay ? 'date' : _lastTimedMode),
                        ),
                      if (_mode.isNotEmpty && _mode != 'date')
                        ui.choose(
                          l10n.selectTimeZone,
                          _mode,
                          _timeModes(l10n),
                          _setDateMode,
                        ),
                    ],
                    if (!derivedDate && _mode.isNotEmpty) ...[
                      ui.pickDate(
                        l10n.journalPickDate,
                        _civilDateTime,
                        (date) => _chooseCivilDateTime(date, changeDay: true),
                      ),
                      if (timed)
                        layout?.timeField(
                              l10n.startTime,
                              _civilDateTime,
                              (time) =>
                                  _chooseCivilDateTime(time, changeDay: false),
                              timeZone: _mode == 'tzidDateTime'
                                  ? _zone.text
                                  : null,
                              onTimeZoneChanged: _mode != 'tzidDateTime'
                                  ? null
                                  : (value) =>
                                        _changeDraft(() => _zone.text = value),
                              onValidityChanged: (valid) {
                                if (_timeValid != valid) {
                                  setState(() => _timeValid = valid);
                                }
                              },
                            ) ??
                            ui.pickTime(
                              l10n.journalPickTime,
                              _civilDateTime,
                              (time) =>
                                  _chooseCivilDateTime(time, changeDay: false),
                            ),
                      if (_mode == 'tzidDateTime' && layout == null)
                        ui.input(l10n.selectTimeZone, controller: _zone),
                    ],
                    if (!derivedDate &&
                        widget.occurrences != null &&
                        _mode.isNotEmpty &&
                        _mode != 'date' &&
                        _mode != snapshot?.component.start?.kind.name)
                      Text(l10n.journalSeriesDateModeNotice),
                  ]),
                  group([
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
                  ]),
                  group([
                    for (final draft in _descriptions)
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
                    ui.button(
                      l10n.journalAddDescription,
                      () => _changeDraft(() {
                        final draft = _DescriptionDraft();
                        _listenDescription(draft);
                        _descriptions.add(draft);
                      }),
                    ),
                  ]),
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
                for (final related in widget.relatedEntries)
                  if (related is UnresolvedJournalLink)
                    Text(
                      '${related.valueType}: ${related.value}\n${l10n.scheduleUnavailable}',
                    )
                  else
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: ui.button(
                        '${l10n.openLink} · ${_linkLabel(related, l10n)}',
                        locked
                            ? null
                            : () async {
                                if (await _flushDraft() && mounted) {
                                  await widget.openReference(related);
                                }
                              },
                      ),
                    ),
                if (recovering && _unreadableDraft == null) ...[
                  for (final field in _details)
                    Text(field.toProperty().serializeLogicalLine()),
                  ...journalReadOnlyChildren(
                    IcalComponent(
                      name: 'VJOURNAL',
                      originalBeginLine: 'BEGIN:VJOURNAL',
                      originalEndLine: 'END:VJOURNAL',
                      children: [
                        for (final child in _children) child.toComponent(),
                      ],
                    ),
                  ),
                ],
                ..._occurrenceControls(l10n),
                if (canEdit) ...[
                  group([
                    layout?.details(l10n.journalDetails, _toggleDetails) ??
                        ui.button(l10n.journalDetails, _toggleDetails),
                  ]),
                  if (_showDetails) ...[
                    group([
                      if (!derivedDate &&
                          _mode == 'tzidDateTime' &&
                          layout != null)
                        ui.input('TZID', controller: _zone),
                      if (!derivedDate && _mode.isNotEmpty)
                        ui.input(
                          _mode == 'date'
                              ? 'YYYY-MM-DD'
                              : 'YYYY-MM-DDTHH:MM:SS',
                          controller: _date,
                        ),
                      for (final draft in _descriptions.where(
                        (draft) => !draft.derived,
                      ))
                        KeyedSubtree(
                          key: ObjectKey(draft),
                          child: Column(
                            children: [
                              ui.input('LANGUAGE', controller: draft.language),
                              ui.input('ALTREP', controller: draft.alternate),
                            ],
                          ),
                        ),
                    ]),
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
                    if (canEdit && layout == null)
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
                    if (recovering || _draftFailed)
                      ui.button(
                        l10n.registrationCopyAll,
                        locked
                            ? null
                            : () => widget.run(
                                () => Clipboard.setData(
                                  ClipboardData(text: _recoveryJson()),
                                ),
                              ),
                      ),
                    if ((recovering || _draftFailed) &&
                        widget.files?.exportDraft != null)
                      ui.button(
                        '${l10n.export} JSON',
                        locked
                            ? null
                            : () => widget.run(
                                () =>
                                    widget.files!.exportDraft!(_recoveryJson()),
                              ),
                      ),
                    if (recovering &&
                        _unreadableDraft == null &&
                        widget.recoverAsNew != null)
                      ui.button(
                        l10n.duplicateLocalItem,
                        locked
                            ? null
                            : () async {
                                if (await _flushDraft() && mounted) {
                                  await widget.recoverAsNew!(_draftContent());
                                }
                              },
                      ),
                    if (widget.duplicate != null)
                      ui.button(
                        l10n.journalDuplicate,
                        locked || draftNeedsRecovery ? null : widget.duplicate,
                      ),
                    if (widget.delete != null)
                      ui.button(
                        _confirmDelete ? l10n.journalDeleteSeries : l10n.delete,
                        locked || draftNeedsRecovery
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
                    if (layout == null)
                      ui.button(l10n.close, locked ? null : _requestClose),
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

  Widget _editorBody({
    required JournalEditorLayout? layout,
    required bool locked,
    required bool canEdit,
    required bool canSave,
    required List<Widget> fields,
  }) {
    final l10n = AppLocalizations.of(context);
    return layout?.editor(
          title: widget.snapshot == null
              ? l10n.newJournalEntry
              : l10n.editJournalEntry,
          closeLabel: canEdit ? l10n.cancel : l10n.close,
          saveLabel: l10n.save,
          close: () => unawaited(_requestClose()),
          save: canSave ? _save : null,
          locked: locked,
          children: fields,
        ) ??
        ListView(padding: const EdgeInsets.all(16), children: fields);
  }
}

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
