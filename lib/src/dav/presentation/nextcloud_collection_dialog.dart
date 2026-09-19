import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yaru/yaru.dart';

import '../../app/app_bootstrap.dart';
import '../../app/busymax_design.dart';
import '../../app/busymax_dialogs.dart';
import '../../dav/dav_errors.dart';
import '../../dav/nextcloud/nextcloud_collection_controller.dart';
import '../../dav/nextcloud/nextcloud_collection_service.dart';
import '../../dav/nextcloud/nextcloud_dav_context.dart';
import '../../dav/nextcloud/nextcloud_trash_service.dart';
import '../../dav/xml/dav_xml.dart';
import '../../l10n/l10n.dart';
import '../../ui/common/schedule/native_collection_export.dart';
import 'nextcloud_scheduling_dialog.dart';

Future<void> showLinuxNextcloudCollectionDialog(
  BuildContext context, {
  required String accountId,
  required String collectionId,
}) => showBusyMaxModalDialog<void>(
  context,
  barrierDismissible: false,
  builder: (dialogContext) => LinuxNextcloudCollectionDialog(
    accountId: accountId,
    collectionId: collectionId,
  ),
);

class LinuxNextcloudCollectionDialog extends ConsumerStatefulWidget {
  const LinuxNextcloudCollectionDialog({
    super.key,
    required this.accountId,
    required this.collectionId,
  });
  final String accountId;
  final String collectionId;
  @override
  ConsumerState<LinuxNextcloudCollectionDialog> createState() =>
      _LinuxNextcloudCollectionDialogState();
}

class _LinuxNextcloudCollectionDialogState
    extends ConsumerState<LinuxNextcloudCollectionDialog> {
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

  Future<bool> _confirm({
    required String title,
    required String message,
    required String action,
    bool destructive = false,
  }) => showBusyMaxConfirm(
    context,
    title: title,
    message: message,
    confirmLabel: action,
    destructive: destructive,
  );

  Future<void> _close() async {
    if (model.busy) return;
    final l10n = context.l10n;
    if (model.dirty &&
        !await _confirm(
          title: l10n.discard,
          message: l10n.discardChanges,
          action: l10n.discard,
          destructive: true,
        )) {
      return;
    }
    if (mounted) Navigator.pop(context);
  }

  Widget _field(DavPropertyName property, String label) {
    final controller = fields.putIfAbsent(
      property,
      () => TextEditingController(text: model.values[property]),
    );
    final multiline =
        property.localName == 'calendar-description' ||
        property.localName == 'calendar-timezone';
    return YaruListTile.square(
      title: TextField(
        key: ValueKey('nextcloud-${property.localName}'),
        controller: controller,
        enabled: model.state!.collection.canWriteMetadata && !model.busy,
        maxLines: multiline ? 3 : 1,
        decoration: busyMaxGroupedTextFieldDecoration(
          context,
          labelText: label,
          alignLabelWithHint: multiline,
        ),
        onChanged: (value) => model.change(property, value),
      ),
    );
  }

  Widget _check(
    DavPropertyName property,
    String label,
    String yes,
    String no,
  ) => BusyMaxSwitchRow(
    title: label,
    value: model.values[property] == yes,
    enabled: model.state!.collection.canWriteMetadata && !model.busy,
    onChanged: (value) => model.change(property, value ? yes : no),
  );

  Future<void> _showExportComplete(String path) => showBusyMaxModalDialog<void>(
    context,
    builder: (dialogContext) => BusyMaxDialogShell(
      title: context.l10n.nextcloudExportCollection,
      actions: [
        BusyMaxPushButton.suggested(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(context.l10n.close),
        ),
      ],
      children: [Text(context.l10n.exportedFile(path))],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
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
      child: BusyMaxDialogShell(
        key: const ValueKey('nextcloud-collection-dialog'),
        title: l10n.nextcloudCollectionSettings,
        maxWidth: 680,
        header: BusyMaxEditorHeader(
          title: l10n.nextcloudCollectionSettings,
          cancelLabel: l10n.close,
          saveLabel: l10n.save,
          onCancel: _close,
          cancelEnabled: !model.busy,
          saving: model.busy && model.dirty,
          onSave:
              model.busy ||
                  !model.dirty ||
                  state?.collection.canWriteMetadata != true
              ? null
              : model.save,
        ),
        children: [
          if (model.busy) const Center(child: YaruCircularProgressIndicator()),
          if (model.failed)
            Text(
              model.error is DavException &&
                      (model.error! as DavException).kind ==
                          DavErrorKind.authorization
                  ? l10n.nextcloudOperationDenied
                  : l10n.nextcloudServerUnavailable,
            ),
          if (model.refreshPending) Text(l10n.nextcloudRefreshPending),
          if (state == null && !model.busy)
            BusyMaxGroupedList(
              filled: true,
              children: [
                BusyMaxActionRow(
                  title: l10n.retry,
                  leading: const Icon(YaruIcons.sync),
                  onTap: model.load,
                ),
              ],
            ),
          if (state != null) ...[
            BusyMaxGroupedList(
              title: l10n.metadata,
              filled: true,
              children: [
                YaruListTile.square(
                  leading: const Icon(YaruIcons.calendar),
                  title: Text(state.collection.collection.displayName),
                  subtitle: Text(role),
                ),
                if (state.collection.collection.ownerHref case final owner?)
                  YaruListTile.square(
                    leading: const Icon(Icons.person_outline),
                    title: SelectableText(owner),
                  ),
                if (state.collection.collection.readOnly &&
                    state.collection.canWriteMetadata)
                  YaruListTile.square(
                    leading: const Icon(Icons.info_outline),
                    title: Text(l10n.nextcloudMetadataEditable),
                  ),
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
                  const DavPropertyName(owncloudNamespace, 'calendar-enabled'),
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
              ],
            ),
            BusyMaxGroupedList(
              title: l10n.nextcloudSharing,
              filled: true,
              children: [
                for (final share in state.shares) ...[
                  YaruListTile.square(
                    leading: const Icon(Icons.person_outline),
                    title: Text(share.recipient.label),
                    subtitle: share.status.isEmpty ? null : Text(share.status),
                  ),
                  BusyMaxActionRow(
                    title: share.writable
                        ? l10n.nextcloudWriteAccess
                        : l10n.nextcloudReadAccess,
                    leading: Icon(
                      share.writable ? Icons.edit_outlined : Icons.visibility,
                    ),
                    enabled: !model.busy && state.canShare,
                    onTap: () => model.share(share.recipient, !share.writable),
                  ),
                  if (state.canShare)
                    BusyMaxActionRow(
                      title: l10n.nextcloudRevokeShare,
                      leading: const Icon(Icons.link_off),
                      enabled: !model.busy,
                      onTap: () async {
                        if (await _confirm(
                          title: l10n.nextcloudRevokeShare,
                          message: l10n.nextcloudRevokeShare,
                          action: l10n.nextcloudRevokeShare,
                          destructive: true,
                        )) {
                          await model.share(share.recipient, null);
                        }
                      },
                    ),
                ],
                if (state.canShare) ...[
                  YaruListTile.square(
                    title: TextField(
                      controller: query,
                      enabled: !model.busy,
                      textInputAction: TextInputAction.search,
                      decoration: busyMaxGroupedTextFieldDecoration(
                        context,
                        labelText: l10n.nextcloudRecipientSearch,
                      ),
                      onChanged: (_) => model.clearSearch(),
                      onSubmitted: model.search,
                    ),
                  ),
                  BusyMaxActionRow(
                    title: l10n.windowsSearch,
                    leading: const Icon(YaruIcons.search),
                    enabled: !model.busy,
                    onTap: () => model.search(query.text),
                  ),
                  for (final recipient in model.recipients) ...[
                    YaruListTile.square(
                      leading: const Icon(Icons.person_add_outlined),
                      title: Text(recipient.label),
                    ),
                    BusyMaxActionRow(
                      title: l10n.nextcloudReadAccess,
                      leading: const Icon(Icons.visibility),
                      enabled: !model.busy,
                      onTap: () => model.share(recipient, false),
                    ),
                    BusyMaxActionRow(
                      title: l10n.nextcloudWriteAccess,
                      leading: const Icon(Icons.edit_outlined),
                      enabled: !model.busy,
                      onTap: () => model.share(recipient, true),
                    ),
                  ],
                ],
                if (state.publishUrl != null)
                  YaruListTile.square(
                    leading: const Icon(Icons.link),
                    title: SelectableText(state.publishUrl.toString()),
                  ),
                if (state.canPublish)
                  BusyMaxActionRow(
                    title: state.publishUrl == null
                        ? l10n.nextcloudPublish
                        : l10n.nextcloudUnpublish,
                    leading: Icon(
                      state.publishUrl == null ? Icons.public : Icons.link_off,
                    ),
                    enabled: !model.busy,
                    onTap: () async {
                      final publish = state.publishUrl == null;
                      if (!publish ||
                          await _confirm(
                            title: l10n.nextcloudPublish,
                            message: l10n.nextcloudPublishWarning,
                            action: l10n.nextcloudPublish,
                          )) {
                        await model.publish(publish);
                      }
                    },
                  ),
              ],
            ),
            BusyMaxGroupedList(
              title: l10n.actionsSection,
              filled: true,
              children: [
                if (state.collection.collection.eventProjectionEnabled)
                  BusyMaxActionRow(
                    title: l10n.nextcloudSchedulingInbox,
                    leading: const Icon(Icons.inbox_outlined),
                    enabled: !model.busy,
                    onTap: () => showLinuxNextcloudSchedulingDialog(
                      context,
                      accountId: widget.accountId,
                      collectionId: widget.collectionId,
                    ),
                  ),
                BusyMaxActionRow(
                  title: l10n.nextcloudExportCollection,
                  leading: const Icon(Icons.file_download_outlined),
                  enabled: !model.busy,
                  onTap: () => model.exportTo((resources) async {
                    final path =
                        await exportNativeCollectionWithDirectoryDialog(
                          resources,
                        );
                    if (mounted && path != null) {
                      await _showExportComplete(path);
                    }
                  }),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

Future<void> showLinuxNextcloudTrashDialog(
  BuildContext context, {
  required String accountId,
}) => showBusyMaxModalDialog<void>(
  context,
  barrierDismissible: false,
  builder: (dialogContext) => _LinuxNextcloudTrashDialog(accountId: accountId),
);

class _LinuxNextcloudTrashDialog extends ConsumerStatefulWidget {
  const _LinuxNextcloudTrashDialog({required this.accountId});
  final String accountId;
  @override
  ConsumerState<_LinuxNextcloudTrashDialog> createState() =>
      _LinuxNextcloudTrashState();
}

class _LinuxNextcloudTrashState
    extends ConsumerState<_LinuxNextcloudTrashDialog> {
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
    final l10n = context.l10n;
    final confirmed = await showBusyMaxConfirm(
      context,
      title: permanent ? l10n.nextcloudPermanentDelete : l10n.nextcloudRestore,
      message: permanent ? l10n.nextcloudPermanentDeleteWarning : item.title,
      confirmLabel: permanent
          ? l10n.nextcloudPermanentDelete
          : l10n.nextcloudRestore,
      destructive: permanent,
    );
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
    final l10n = context.l10n;
    return PopScope(
      canPop: !busy,
      child: BusyMaxDialogShell(
        key: const ValueKey('nextcloud-trash-dialog'),
        title: l10n.nextcloudTrash,
        maxWidth: 680,
        header: BusyMaxEditorHeader(
          title: l10n.nextcloudTrash,
          cancelLabel: l10n.close,
          saveLabel: l10n.refresh,
          onCancel: () => Navigator.of(context).pop(),
          cancelEnabled: !busy,
          onSave: busy ? null : _load,
        ),
        children: [
          if (busy) const Center(child: YaruCircularProgressIndicator()),
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
          if (listing?.items.isEmpty == true) Text(l10n.nextcloudTrashEmpty),
          if (listing?.items.isNotEmpty == true)
            BusyMaxGroupedList(
              filled: true,
              children: [
                for (final item in listing!.items) ...[
                  YaruListTile.square(
                    leading: Icon(switch (item.kind) {
                      NextcloudTrashKind.event => YaruIcons.calendar,
                      NextcloudTrashKind.task => Icons.task_alt,
                      NextcloudTrashKind.calendar => YaruIcons.calendar,
                      NextcloudTrashKind.taskList => Icons.checklist,
                      NextcloudTrashKind.mixedCollection =>
                        Icons.view_agenda_outlined,
                    }),
                    title: Text(item.title),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (item.deletedAt != null) Text(item.deletedAt!),
                        Text(switch (item.kind) {
                          NextcloudTrashKind.event => l10n.calendarEvents,
                          NextcloudTrashKind.task => l10n.calendarTasks,
                          NextcloudTrashKind.calendar => l10n.calendar,
                          NextcloudTrashKind.taskList => l10n.taskLists,
                          NextcloudTrashKind.mixedCollection =>
                            l10n.collectionSupportsEventsAndTasks,
                        }),
                      ],
                    ),
                  ),
                  BusyMaxActionRow(
                    title: l10n.nextcloudRestore,
                    leading: const Icon(Icons.restore),
                    enabled: !busy && !refreshPending && item.canRestore,
                    onTap: () => _mutate(item, false),
                  ),
                  BusyMaxActionRow(
                    title: l10n.nextcloudPermanentDelete,
                    leading: const Icon(YaruIcons.trash),
                    enabled:
                        !busy && !refreshPending && item.canPermanentlyDelete,
                    onTap: () => _mutate(item, true),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }
}
