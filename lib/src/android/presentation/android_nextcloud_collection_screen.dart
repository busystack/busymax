import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_bootstrap.dart';
import '../../dav/nextcloud/nextcloud_collection_controller.dart';
import '../../dav/xml/dav_xml.dart';
import '../../l10n/l10n.dart';
import '../../l10n/nextcloud_collection_error_description.dart';

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
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    model.removeListener(_changed);
    model.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    if (model.busy) return;
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
      if (discard != true || !mounted) return;
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
      if (!didPop) unawaited(_close());
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
                onPressed: model.load,
                child: Text(context.l10n.retry),
              ),
            ),
          if (model.refreshPending)
            ListTile(
              title: Text(context.l10n.davRefreshPending),
              trailing: TextButton(
                onPressed: model.load,
                child: Text(context.l10n.refresh),
              ),
            ),
          if (model.state != null) ...[
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
              const DavPropertyName(caldavNamespace, 'calendar-description'),
              context.l10n.description,
              multiline: true,
            ),
            ExpansionTile(
              title: Text(context.l10n.advancedSection),
              children: [
                _field(
                  const DavPropertyName(caldavNamespace, 'calendar-timezone'),
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
              onChanged: model.busy || !model.state!.collection.canWriteMetadata
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
              onChanged: model.busy || !model.state!.collection.canWriteMetadata
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
        ],
      ),
    ),
  );
}
