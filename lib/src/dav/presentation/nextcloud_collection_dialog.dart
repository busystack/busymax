import 'dart:async';

import 'package:busymax/src/ui/common/flutter_material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yaru/yaru.dart';

import '../../app/app_bootstrap.dart';
import '../../app/busymax_design.dart';
import '../../app/busymax_dialogs.dart';
import '../../dav/nextcloud/nextcloud_collection_controller.dart';
import '../../dav/nextcloud/nextcloud_collection_service.dart';
import '../../dav/nextcloud/nextcloud_trash_service.dart';
import '../nextcloud/nextcloud_trash_session.dart';
import '../nextcloud/nextcloud_federation_controller.dart';
import '../../dav/xml/dav_xml.dart';
import '../../l10n/l10n.dart';
import '../../l10n/nextcloud_collection_error_description.dart';
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
          errorText: localizedNextcloudFieldError(
            context.l10n,
            model.fieldErrors[property],
          ),
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

  Future<void> _showExportResult(String? path, int excluded) =>
      showBusyMaxModalDialog<void>(
        context,
        builder: (dialogContext) => BusyMaxDialogShell(
          title: context.l10n.nextcloudExportCollection,
          actions: [
            BusyMaxPushButton.suggested(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(context.l10n.close),
            ),
          ],
          children: [
            if (path != null) Text(context.l10n.exportedFile(path)),
            if (excluded > 0)
              Text(context.l10n.journalCollectionExportRecovery),
          ],
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
          if (model.failed &&
              model.error is! NextcloudCollectionValidationException)
            Text(localizedNextcloudCollectionError(l10n, model.error)),
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
                YaruExpandable(
                  header: Text(l10n.advancedSection),
                  expandIconSemanticLabel: l10n.advancedSection,
                  isExpanded: model.fieldErrors.keys.any(
                    (p) => p.localName == 'calendar-timezone',
                  ),
                  child: Column(
                    children: [
                      if (state.collection.collection.ownerHref
                          case final owner?)
                        YaruListTile.square(
                          leading: const Icon(Icons.person_outline),
                          title: SelectableText(owner),
                        ),
                      _field(
                        const DavPropertyName(
                          caldavNamespace,
                          'calendar-timezone',
                        ),
                        l10n.nextcloudCalendarTimezone,
                      ),
                    ],
                  ),
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
                    subtitle: share.recipient.federated
                        ? Text(l10n.nextcloudFederationGrant)
                        : (share.status.isEmpty ? null : Text(share.status)),
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
                  onTap: () => model.exportTo((snapshot) async {
                    final path = await exportDavCollectionWithDirectoryDialog(
                      snapshot,
                    );
                    if (mounted &&
                        (path != null || snapshot.excludedJournalCount > 0)) {
                      await _showExportResult(
                        path,
                        snapshot.excludedJournalCount,
                      );
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
  late final _session = NextcloudTrashSession(
    ref.read(nextcloudTrashServiceProvider(widget.accountId)),
  );

  @override
  void initState() {
    super.initState();
    _session.addListener(_onSessionChanged);
    unawaited(_session.load());
  }

  void _onSessionChanged() => setState(() {});

  @override
  void dispose() {
    _session.dispose();
    super.dispose();
  }

  Future<void> _mutate(NextcloudTrashItem item, bool permanent) async {
    final l10n = context.l10n;
    final confirmed = await showBusyMaxConfirm(
      context,
      title: permanent ? l10n.nextcloudPermanentDelete : l10n.nextcloudRestore,
      message: permanent
          ? '${item.title}\n\n${l10n.nextcloudPermanentDeleteWarning}'
          : item.title,
      confirmLabel: permanent
          ? l10n.nextcloudPermanentDelete
          : l10n.nextcloudRestore,
      destructive: permanent,
    );
    if (!confirmed || !mounted) return;
    if (!mounted) return;
    await _session.mutate(item, permanent: permanent);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PopScope(
      canPop: !_session.busy,
      child: BusyMaxDialogShell(
        key: const ValueKey('nextcloud-trash-dialog'),
        title: l10n.nextcloudTrash,
        maxWidth: 680,
        header: BusyMaxEditorHeader(
          title: l10n.nextcloudTrash,
          cancelLabel: l10n.close,
          saveLabel: l10n.refresh,
          onCancel: () => Navigator.of(context).pop(),
          cancelEnabled: !_session.busy,
          onSave: _session.busy ? null : _session.load,
        ),
        children: [
          if (_session.busy)
            const Center(child: YaruCircularProgressIndicator()),
          if (_session.error != null)
            Text(localizedNextcloudCollectionError(l10n, _session.error)),
          if (_session.refreshPending) Text(l10n.nextcloudRefreshPending),
          if (_session.listing?.retentionSeconds != null)
            Text(
              _session.listing!.retentionSeconds == 0
                  ? l10n.nextcloudTrashDisabled
                  : l10n.nextcloudTrashRetention(
                      (_session.listing!.retentionSeconds! / 86400).ceil(),
                    ),
            ),
          if (_session.listing?.items.isEmpty == true)
            Text(l10n.nextcloudTrashEmpty),
          if (_session.listing?.items.isNotEmpty == true)
            SizedBox(
              height: MediaQuery.sizeOf(context).height * .5,
              child: ListView.builder(
                itemCount: _session.listing!.items.length,
                itemBuilder: (context, index) {
                  final item = _session.listing!.items[index];
                  return BusyMaxGroupedList(
                    filled: true,
                    children: [
                      YaruListTile.square(
                        leading: Icon(switch (item.kind) {
                          NextcloudTrashKind.unknownObject =>
                            Icons.description_outlined,
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
                              NextcloudTrashKind.unknownObject => 'iCalendar',
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
                      if (item.isObject && !item.contentLoaded)
                        BusyMaxActionRow(
                          key: ValueKey((
                            'nextcloud-trash-details',
                            item.href.toString(),
                          )),
                          title: l10n.show,
                          leading: _session.loadingDetails(item.href)
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: YaruCircularProgressIndicator(),
                                )
                              : const Icon(Icons.description_outlined),
                          enabled:
                              !_session.busy &&
                              !_session.loadingDetails(item.href),
                          onTap: () => _session.details(item),
                        ),
                      BusyMaxActionRow(
                        key: ValueKey((
                          'nextcloud-trash-restore',
                          item.href.toString(),
                        )),
                        title: l10n.nextcloudRestore,
                        leading: const Icon(Icons.restore),
                        enabled: _session.canMutate && item.canRestore,
                        onTap: () => _mutate(item, false),
                      ),
                      BusyMaxActionRow(
                        key: ValueKey((
                          'nextcloud-trash-delete',
                          item.href.toString(),
                        )),
                        title: l10n.nextcloudPermanentDelete,
                        leading: const Icon(YaruIcons.trash),
                        enabled:
                            _session.canMutate && item.canPermanentlyDelete,
                        onTap: () => _mutate(item, true),
                      ),
                    ],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

Future<void> showLinuxNextcloudFederationDialog(
  BuildContext context, {
  required String accountId,
}) => showBusyMaxModalDialog<void>(
  context,
  barrierDismissible: false,
  builder: (_) => LinuxNextcloudFederationDialog(accountId: accountId),
);

class LinuxNextcloudFederationDialog extends ConsumerStatefulWidget {
  const LinuxNextcloudFederationDialog({super.key, required this.accountId});
  final String accountId;
  @override
  ConsumerState<LinuxNextcloudFederationDialog> createState() =>
      _LinuxNextcloudFederationDialogState();
}

class _LinuxNextcloudFederationDialogState
    extends ConsumerState<LinuxNextcloudFederationDialog> {
  late final NextcloudFederationController model;
  @override
  void initState() {
    super.initState();
    model = NextcloudFederationController(
      ref.read(nextcloudFederationServiceProvider(widget.accountId)),
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final enabled = !model.busy && model.error == null && !model.refreshPending;
    return PopScope(
      canPop: !model.busy,
      child: BusyMaxDialogShell(
        key: const ValueKey('nextcloud-federation-dialog'),
        title: l10n.nextcloudFederationInvitations,
        maxWidth: 680,
        header: BusyMaxEditorHeader(
          title: l10n.nextcloudFederationInvitations,
          cancelLabel: l10n.close,
          saveLabel: l10n.refresh,
          onCancel: () => Navigator.pop(context),
          cancelEnabled: !model.busy,
          onSave: model.busy ? null : model.load,
        ),
        children: [
          if (model.busy) const Center(child: YaruCircularProgressIndicator()),
          if (model.error != null)
            Text(localizedNextcloudCollectionError(l10n, model.error)),
          if (model.refreshPending) Text(l10n.nextcloudRefreshPending),
          if (model.invitations?.isEmpty == true)
            Text(l10n.nextcloudFederationEmpty),
          for (final invitation in model.invitations ?? [])
            BusyMaxGroupedList(
              filled: true,
              children: [
                YaruListTile.square(
                  title: Text(invitation.displayName),
                  subtitle: Text(invitation.sharedBy),
                ),
                BusyMaxActionRow(
                  key: ValueKey('nextcloud-federation-accept-${invitation.id}'),
                  title: l10n.acceptInvitation,
                  leading: const Icon(Icons.check),
                  onTap: enabled
                      ? () => model.respond(invitation, accept: true)
                      : null,
                ),
                BusyMaxActionRow(
                  key: ValueKey(
                    'nextcloud-federation-decline-${invitation.id}',
                  ),
                  title: l10n.declineInvitation,
                  leading: const Icon(Icons.close),
                  onTap: enabled
                      ? () => model.respond(invitation, accept: false)
                      : null,
                ),
              ],
            ),
        ],
      ),
    );
  }
}
