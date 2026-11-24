import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:busymax_android_platform/busymax_android_platform.dart';

import 'package:busymax/src/ui/common/flutter_material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_bootstrap.dart';
import '../../dav/nextcloud/nextcloud_collection_controller.dart';
import '../../dav/nextcloud/nextcloud_collection_service.dart';
import '../../dav/xml/dav_xml.dart';
import '../../l10n/l10n.dart';
import '../../l10n/nextcloud_collection_error_description.dart';
import 'android_settings_screen.dart' show AndroidNextcloudSharingScreen;
import 'android_nextcloud_scheduling_screen.dart';
import 'android_editor_group.dart';

class AndroidNextcloudCollectionScreen extends ConsumerStatefulWidget {
  const AndroidNextcloudCollectionScreen({
    super.key,
    required this.accountId,
    required this.collectionId,
  });
  final String accountId, collectionId;
  @override
  ConsumerState<AndroidNextcloudCollectionScreen> createState() =>
      _AndroidNextcloudCollectionScreenState();
}

class _AndroidNextcloudCollectionScreenState
    extends ConsumerState<AndroidNextcloudCollectionScreen> {
  late final model = NextcloudCollectionController(
    ref.read(nextcloudSharingServiceProvider(widget.accountId)),
    widget.collectionId,
  );
  bool _allowPop = false;
  @override
  void initState() {
    super.initState();
    model.addListener(_changed);
    unawaited(model.load());
  }

  void _changed() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    model.removeListener(_changed);
    model.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    if (model.busy) {
      return;
    }
    if (model.dirty) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(context.l10n.discardChanges),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(context.l10n.discard),
            ),
          ],
        ),
      );
      if (discard != true || !mounted) {
        return;
      }
    }
    setState(() => _allowPop = true);
    Navigator.pop(context);
  }

  Widget _field(
    DavPropertyName property,
    String label, {
    bool multiline = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      key: ValueKey((property, model.state)),
      initialValue: model.values[property] ?? '',
      enabled:
          !model.busy && (model.state?.collection.canWriteMetadata ?? false),
      minLines: multiline ? 3 : 1,
      maxLines: multiline ? 8 : 1,
      decoration: InputDecoration(
        labelText: label,
        errorText: model.fieldErrors.containsKey(property)
            ? context.l10n.invalidCollectionValue
            : null,
      ),
      onChanged: (value) => model.change(property, value),
    ),
  );
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _allowPop || (!model.dirty && !model.busy),
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) {
        unawaited(_close());
      }
    },
    child: Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.nextcloudCollectionSettings),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: model.busy ? null : _close,
        ),
        actions: [
          TextButton(
            onPressed:
                model.busy ||
                    !model.dirty ||
                    !(model.state?.collection.canWriteMetadata ?? false)
                ? null
                : model.save,
            child: Text(context.l10n.save),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (model.busy) const LinearProgressIndicator(),
          if (model.error != null)
            ListTile(
              title: Text(
                localizedNextcloudCollectionError(context.l10n, model.error!),
              ),
              trailing: TextButton(
                onPressed: model.busy
                    ? null
                    : model.state == null
                    ? model.load
                    : model.dirty
                    ? model.save
                    : null,
                child: Text(context.l10n.retry),
              ),
            ),
          if (model.refreshPending)
            ListTile(
              title: Text(context.l10n.davRefreshPending),
              trailing: TextButton(
                onPressed: model.dirty || model.busy ? null : model.load,
                child: Text(context.l10n.refresh),
              ),
            ),
          if (model.state != null) ...[
            ListTile(
              title: Text(model.state!.collection.collection.displayName),
              subtitle: Text(switch (model.state!.collection.role) {
                NextcloudCollectionRole.owned => context.l10n.nextcloudOwned,
                NextcloudCollectionRole.shared => context.l10n.nextcloudShared,
                NextcloudCollectionRole.delegated =>
                  context.l10n.nextcloudDelegated,
                NextcloudCollectionRole.subscription =>
                  context.l10n.nextcloudSubscription,
                NextcloudCollectionRole.deleted =>
                  context.l10n.nextcloudDeleted,
              }),
            ),
            if (model.state!.collection.collection.readOnly &&
                model.state!.collection.canWriteMetadata)
              Text(context.l10n.nextcloudMetadataEditable),
            AndroidEditorGroup(
              title: context.l10n.metadata,
              children: [
                _field(
                  const DavPropertyName(davNamespace, 'displayname'),
                  context.l10n.title,
                ),
                _field(
                  const DavPropertyName(appleIcalNamespace, 'calendar-color'),
                  context.l10n.calendarColor,
                ),
                _field(
                  const DavPropertyName(appleIcalNamespace, 'calendar-order'),
                  context.l10n.nextcloudServerOrder,
                ),
                _field(
                  const DavPropertyName(
                    caldavNamespace,
                    'calendar-description',
                  ),
                  context.l10n.description,
                  multiline: true,
                ),
                ExpansionTile(
                  title: Text(context.l10n.advancedSection),
                  initiallyExpanded: model.fieldErrors.keys.any(
                    (property) => property.localName == 'calendar-timezone',
                  ),
                  children: [
                    if (model.state!.collection.collection.ownerHref
                        case final owner?)
                      ListTile(
                        leading: const Icon(Icons.person_outline),
                        title: SelectableText(owner),
                      ),
                    _field(
                      const DavPropertyName(
                        caldavNamespace,
                        'calendar-timezone',
                      ),
                      context.l10n.nextcloudCalendarTimezone,
                      multiline: true,
                    ),
                  ],
                ),
                SwitchListTile(
                  title: Text(context.l10n.nextcloudCalendarEnabled),
                  value:
                      model.values[const DavPropertyName(
                        owncloudNamespace,
                        'calendar-enabled',
                      )] ==
                      '1',
                  onChanged:
                      model.busy || !model.state!.collection.canWriteMetadata
                      ? null
                      : (value) => model.change(
                          const DavPropertyName(
                            owncloudNamespace,
                            'calendar-enabled',
                          ),
                          value ? '1' : '0',
                        ),
                ),
                SwitchListTile(
                  title: Text(context.l10n.nextcloudAvailability),
                  value:
                      model.values[const DavPropertyName(
                        caldavNamespace,
                        'schedule-calendar-transp',
                      )] !=
                      'transparent',
                  onChanged:
                      model.busy || !model.state!.collection.canWriteMetadata
                      ? null
                      : (value) => model.change(
                          const DavPropertyName(
                            caldavNamespace,
                            'schedule-calendar-transp',
                          ),
                          value ? 'opaque' : 'transparent',
                        ),
                ),
              ],
            ),
            AndroidEditorGroup(
              title: context.l10n.nextcloudSharing,
              children: [
                for (final share in model.state!.shares)
                  ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: Text(share.recipient.label),
                    subtitle: Text(
                      share.writable
                          ? context.l10n.nextcloudWriteAccess
                          : context.l10n.nextcloudReadAccess,
                    ),
                  ),
                TextButton(
                  onPressed: model.busy
                      ? null
                      : () => Navigator.of(context).push<void>(
                          MaterialPageRoute(
                            builder: (_) => AndroidNextcloudSharingScreen(
                              accountId: widget.accountId,
                              collectionId: widget.collectionId,
                              title: model
                                  .state!
                                  .collection
                                  .collection
                                  .displayName,
                            ),
                          ),
                        ),
                  child: Text(context.l10n.nextcloudSharing),
                ),
              ],
            ),
            AndroidEditorGroup(
              title: context.l10n.actionsSection,
              children: [
                if (model.state!.collection.collection.eventProjectionEnabled)
                  ListTile(
                    leading: const Icon(Icons.inbox_outlined),
                    title: Text(context.l10n.nextcloudSchedulingInbox),
                    enabled: !model.busy,
                    onTap: () => Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (_) => AndroidNextcloudSchedulingScreen(
                          accountId: widget.accountId,
                          collectionId: widget.collectionId,
                        ),
                      ),
                    ),
                  ),
                ListTile(
                  leading: const Icon(Icons.file_download_outlined),
                  title: Text(context.l10n.nextcloudExportCollection),
                  enabled: !model.busy,
                  onTap: () => model.exportTo((resources) async {
                    await BusyMaxAndroidPlatform.instance.exportDocumentTree(
                      folderName:
                          'BusyMax-export-${DateTime.now().toUtc().millisecondsSinceEpoch}',
                      resources: [
                        for (var index = 0; index < resources.length; index++)
                          AndroidExportResource(
                            name: 'resource-${index + 1}.ics',
                            bytes: Uint8List.fromList(
                              utf8.encode(resources[index].rawIcs),
                            ),
                          ),
                      ],
                    );
                  }),
                ),
              ],
            ),
          ],
        ],
      ),
    ),
  );
}
