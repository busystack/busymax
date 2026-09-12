import 'dart:async';
import '../common/schedule/native_collection_export.dart';
import 'windows_nextcloud_scheduling_dialog.dart';
import 'dart:math' as math;
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:busymax/l10n/generated/app_localizations.dart';
import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/dav/nextcloud/nextcloud_collection_controller.dart';
import 'package:busymax/src/dav/nextcloud/nextcloud_collection_service.dart';
import 'package:busymax/src/dav/nextcloud/nextcloud_dav_context.dart';
import 'package:busymax/src/dav/nextcloud/nextcloud_trash_service.dart';
import 'package:busymax/src/dav/dav_errors.dart';
import 'package:busymax/src/dav/xml/dav_xml.dart';

Future<void> showWindowsNextcloudCollectionDialog(
  BuildContext context, {
  required String accountId,
  required String collectionId,
}) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (_) => WindowsNextcloudCollectionDialog(
    accountId: accountId,
    collectionId: collectionId,
  ),
);

class WindowsNextcloudCollectionDialog extends ConsumerStatefulWidget {
  const WindowsNextcloudCollectionDialog({
    super.key,
    required this.accountId,
    required this.collectionId,
  });
  final String accountId;
  final String collectionId;
  @override
  ConsumerState<WindowsNextcloudCollectionDialog> createState() =>
      _WindowsNextcloudCollectionDialogState();
}

class _WindowsNextcloudCollectionDialogState
    extends ConsumerState<WindowsNextcloudCollectionDialog> {
  late final NextcloudCollectionController model;
  final fields = <DavPropertyName, TextEditingController>{};
  final query = TextEditingController();
  @override
  void initState() {
    super.initState();
    model = NextcloudCollectionController(
      ref.read(nextcloudSharingServiceProvider(widget.accountId)),
      widget.collectionId,
    )..addListener(_changed);
    unawaited(model.load());
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    model.removeListener(_changed);
    model.dispose();
    query.dispose();
    for (final controller in fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<bool> _confirm(String message, String action) async =>
      await showDialog<bool>(
        context: context,
        builder: (dialogContext) => ContentDialog(
          title: Text(message),
          actions: [
            Button(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(AppLocalizations.of(context).cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(action),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _close() async {
    if (model.busy) return;
    final l10n = AppLocalizations.of(context);
    if (model.dirty && !await _confirm(l10n.discardChanges, l10n.discard)) {
      return;
    }
    if (mounted) Navigator.pop(context);
  }

  Widget _field(DavPropertyName property, String label) {
    final controller = fields.putIfAbsent(
      property,
      () => TextEditingController(text: model.values[property]),
    );
    final input = TextBox(
      key: ValueKey('nextcloud-${property.localName}'),
      controller: controller,
      enabled: model.state!.collection.canWriteMetadata && !model.busy,
      maxLines:
          property.localName == 'calendar-description' ||
              property.localName == 'calendar-timezone'
          ? 3
          : 1,
      onChanged: (value) => model.change(property, value),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InfoLabel(label: label, child: input),
    );
  }

  Widget _check(
    DavPropertyName property,
    String label,
    String yes,
    String no,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: LayoutBuilder(
      builder: (context, constraints) => Checkbox(
        content: SizedBox(
          width: math.max(0, constraints.maxWidth - 36),
          child: Text(label),
        ),
        checked: model.values[property] == yes,
        onChanged: model.state!.collection.canWriteMetadata && !model.busy
            ? (value) => model.change(property, value == true ? yes : no)
            : null,
      ),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = model.state;
    final role = state == null
        ? ''
        : switch (state.collection.role) {
            NextcloudCollectionRole.owned => l10n.nextcloudOwned,
            NextcloudCollectionRole.shared => l10n.nextcloudShared,
            NextcloudCollectionRole.delegated => l10n.nextcloudDelegated,
            NextcloudCollectionRole.subscription => l10n.nextcloudSubscription,
            NextcloudCollectionRole.deleted => l10n.nextcloudDeleted,
          };
    return PopScope(
      canPop: !model.dirty && !model.busy,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) unawaited(_close());
      },
      child: ContentDialog(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 760),
        title: Text(l10n.nextcloudCollectionSettings),
        content: SizedBox(
          width: 620,
          height: math.min(500.0, MediaQuery.sizeOf(context).height * .6),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (model.busy) Center(child: const ProgressRing()),
                if (model.failed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      model.error is DavException &&
                              (model.error! as DavException).kind ==
                                  DavErrorKind.authorization
                          ? l10n.nextcloudOperationDenied
                          : l10n.nextcloudServerUnavailable,
                    ),
                  ),
                if (model.refreshPending) Text(l10n.nextcloudRefreshPending),
                if (state == null && !model.busy)
                  Button(onPressed: model.load, child: Text(l10n.retry)),
                if (state != null) ...[
                  if (state.collection.collection.eventProjectionEnabled)
                    Button(
                      onPressed: model.busy
                          ? null
                          : () => showWindowsNextcloudSchedulingDialog(
                              context,
                              accountId: widget.accountId,
                              collectionId: widget.collectionId,
                            ),
                      child: Text(l10n.nextcloudSchedulingInbox),
                    ),
                  Text('${state.collection.collection.displayName} · $role'),
                  if (state.collection.collection.ownerHref case final owner?)
                    SelectableText(owner),
                  if (state.collection.collection.readOnly &&
                      state.collection.canWriteMetadata)
                    Text(l10n.nextcloudMetadataEditable),
                  const SizedBox(height: 12),
                  _field(
                    const DavPropertyName(davNamespace, 'displayname'),
                    l10n.title,
                  ),
                  _field(
                    const DavPropertyName(appleIcalNamespace, 'calendar-color'),
                    l10n.calendarColor,
                  ),
                  _field(
                    const DavPropertyName(appleIcalNamespace, 'calendar-order'),
                    l10n.nextcloudServerOrder,
                  ),
                  _field(
                    const DavPropertyName(
                      caldavNamespace,
                      'calendar-description',
                    ),
                    l10n.description,
                  ),
                  _field(
                    const DavPropertyName(caldavNamespace, 'calendar-timezone'),
                    l10n.nextcloudCalendarTimezone,
                  ),
                  _check(
                    const DavPropertyName(
                      owncloudNamespace,
                      'calendar-enabled',
                    ),
                    l10n.nextcloudCalendarEnabled,
                    '1',
                    '0',
                  ),
                  _check(
                    const DavPropertyName(
                      caldavNamespace,
                      'schedule-calendar-transp',
                    ),
                    l10n.nextcloudAvailability,
                    'opaque',
                    'transparent',
                  ),
                  const SizedBox(height: 12),
                  Text(l10n.nextcloudSharing),
                  for (final share in state.shares)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Wrap(
                        spacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(share.recipient.label),
                          Button(
                            onPressed: !model.busy && state.canShare
                                ? () => model.share(
                                    share.recipient,
                                    !share.writable,
                                  )
                                : null,
                            child: Text(
                              share.writable
                                  ? l10n.nextcloudWriteAccess
                                  : l10n.nextcloudReadAccess,
                            ),
                          ),
                          if (state.canShare)
                            Button(
                              onPressed: model.busy
                                  ? null
                                  : () async {
                                      if (await _confirm(
                                        l10n.nextcloudRevokeShare,
                                        l10n.nextcloudRevokeShare,
                                      )) {
                                        await model.share(
                                          share.recipient,
                                          null,
                                        );
                                      }
                                    },
                              child: Text(l10n.nextcloudRevokeShare),
                            ),
                        ],
                      ),
                    ),
                  if (state.canShare) ...[
                    const SizedBox(height: 8),
                    InfoLabel(
                      label: l10n.nextcloudRecipientSearch,
                      child: TextBox(
                        controller: query,
                        enabled: !model.busy,
                        onChanged: (_) => model.clearSearch(),
                        onSubmitted: (value) => model.search(value),
                      ),
                    ),
                    Button(
                      onPressed: model.busy
                          ? null
                          : () => model.search(query.text),
                      child: Text(l10n.windowsSearch),
                    ),
                    for (final recipient in model.recipients)
                      Wrap(
                        spacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(recipient.label),
                          Button(
                            onPressed: model.busy
                                ? null
                                : () => model.share(recipient, false),
                            child: Text(l10n.nextcloudReadAccess),
                          ),
                          Button(
                            onPressed: model.busy
                                ? null
                                : () => model.share(recipient, true),
                            child: Text(l10n.nextcloudWriteAccess),
                          ),
                        ],
                      ),
                  ],
                  if (state.publishUrl != null)
                    SelectableText(state.publishUrl.toString()),
                  if (state.canPublish)
                    Button(
                      onPressed: model.busy
                          ? null
                          : () async {
                              final publish = state.publishUrl == null;
                              if (!publish ||
                                  await _confirm(
                                    l10n.nextcloudPublishWarning,
                                    l10n.nextcloudPublish,
                                  )) {
                                await model.publish(publish);
                              }
                            },
                      child: Text(
                        state.publishUrl == null
                            ? l10n.nextcloudPublish
                            : l10n.nextcloudUnpublish,
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          Button(
            onPressed: model.busy
                ? null
                : () => model.exportTo((resources) async {
                    final path =
                        await exportNativeCollectionWithDirectoryDialog(
                          resources,
                        );
                    if (mounted && path != null) {
                      await _confirm(l10n.exportedFile(path), l10n.close);
                    }
                  }),
            child: Text(l10n.nextcloudExportCollection),
          ),
          Button(
            onPressed: model.busy ? null : _close,
            child: Text(l10n.close),
          ),
          FilledButton(
            onPressed:
                model.busy ||
                    !model.dirty ||
                    state?.collection.canWriteMetadata != true
                ? null
                : model.save,
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  }
}

Future<void> showWindowsNextcloudTrashDialog(
  BuildContext context, {
  required String accountId,
}) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (_) => _WindowsNextcloudTrashDialog(accountId: accountId),
);

class _WindowsNextcloudTrashDialog extends ConsumerStatefulWidget {
  const _WindowsNextcloudTrashDialog({required this.accountId});
  final String accountId;
  @override
  ConsumerState<_WindowsNextcloudTrashDialog> createState() =>
      _WindowsNextcloudTrashState();
}

class _WindowsNextcloudTrashState
    extends ConsumerState<_WindowsNextcloudTrashDialog> {
  NextcloudTrashListing? listing;
  bool busy = false, failed = false, refreshPending = false;
  Object? error;
  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      busy = true;
      failed = false;
    });
    try {
      final result = await ref
          .read(nextcloudTrashServiceProvider(widget.accountId))
          .list();
      if (mounted) {
        setState(() {
          listing = result;
          refreshPending = false;
        });
      }
    } on Object catch (caught) {
      if (mounted) {
        setState(() {
          failed = true;
          error = caught;
        });
      }
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> _mutate(NextcloudTrashItem item, bool permanent) async {
    final l10n = AppLocalizations.of(context);
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => ContentDialog(
            title: Text(
              permanent
                  ? l10n.nextcloudPermanentDeleteWarning
                  : l10n.nextcloudRestore,
            ),
            content: Text(item.title),
            actions: [
              Button(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(
                  permanent
                      ? l10n.nextcloudPermanentDelete
                      : l10n.nextcloudRestore,
                ),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;
    setState(() {
      busy = true;
      failed = false;
    });
    try {
      final service = ref.read(nextcloudTrashServiceProvider(widget.accountId));
      final result = permanent
          ? await service.permanentlyDelete(item)
          : await service.restore(item);
      if (!mounted) return;
      setState(
        () =>
            refreshPending = result == NextcloudMutationOutcome.refreshPending,
      );
      if (!refreshPending) await _load();
    } on Object catch (caught) {
      if (mounted) {
        setState(() {
          failed = true;
          error = caught;
        });
      }
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ContentDialog(
      title: Text(l10n.nextcloudTrash),
      content: SizedBox(
        width: 620,
        height: math.min(460.0, MediaQuery.sizeOf(context).height * .6),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (busy) Center(child: const ProgressRing()),
              if (failed)
                Text(
                  error is DavException &&
                          (error! as DavException).code == 'DavTrashUnsupported'
                      ? l10n.nextcloudUnsupported
                      : l10n.nextcloudServerUnavailable,
                ),
              if (refreshPending) Text(l10n.nextcloudRefreshPending),
              if (listing?.retentionSeconds != null)
                Text(
                  l10n.nextcloudTrashRetention(
                    (listing!.retentionSeconds! / 86400).ceil(),
                  ),
                ),
              if (listing?.items.isEmpty == true)
                Text(l10n.nextcloudTrashEmpty),
              for (final item in listing?.items ?? const <NextcloudTrashItem>[])
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(item.title),
                      if (item.deletedAt != null) Text(item.deletedAt!),
                      Text(switch (item.kind) {
                        NextcloudTrashKind.event => l10n.calendarEvents,
                        NextcloudTrashKind.task => l10n.calendarTasks,
                        NextcloudTrashKind.calendar => l10n.calendar,
                        NextcloudTrashKind.taskList => l10n.taskLists,
                        NextcloudTrashKind.mixedCollection =>
                          l10n.collectionSupportsEventsAndTasks,
                      }),
                      Wrap(
                        spacing: 8,
                        children: [
                          Button(
                            onPressed:
                                busy || refreshPending || !item.canRestore
                                ? null
                                : () => _mutate(item, false),
                            child: Text(l10n.nextcloudRestore),
                          ),
                          Button(
                            onPressed:
                                busy ||
                                    refreshPending ||
                                    !item.canPermanentlyDelete
                                ? null
                                : () => _mutate(item, true),
                            child: Text(l10n.nextcloudPermanentDelete),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        Button(onPressed: busy ? null : _load, child: Text(l10n.refresh)),
        FilledButton(
          onPressed: busy ? null : () => Navigator.pop(context),
          child: Text(l10n.close),
        ),
      ],
    );
  }
}
