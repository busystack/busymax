import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_bootstrap.dart';
import '../../dav/dav_errors.dart';
import '../../dav/nextcloud/nextcloud_scheduling_controller.dart';
import '../../dav/nextcloud/nextcloud_scheduling_service.dart';
import '../../l10n/l10n.dart';

class AndroidNextcloudSchedulingScreen extends ConsumerStatefulWidget {
  const AndroidNextcloudSchedulingScreen({
    super.key,
    required this.accountId,
    required this.collectionId,
  });

  final String accountId;
  final String collectionId;

  @override
  ConsumerState<AndroidNextcloudSchedulingScreen> createState() =>
      _AndroidNextcloudSchedulingScreenState();
}

class _AndroidNextcloudSchedulingScreenState
    extends ConsumerState<AndroidNextcloudSchedulingScreen> {
  late final NextcloudSchedulingController _model;

  @override
  void initState() {
    super.initState();
    _model = NextcloudSchedulingController(
      ref.read(nextcloudSchedulingServiceProvider(widget.accountId)),
      widget.collectionId,
      fallbackTimeZone: ref.read(localTimeZoneProvider),
    )..addListener(_changed);
    unawaited(_model.load());
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _model.removeListener(_changed);
    _model.dispose();
    super.dispose();
  }

  Future<void> _acknowledge(NextcloudInboxMessage message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.nextcloudAcknowledge),
        content: Text(context.l10n.nextcloudAcknowledgeConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.l10n.nextcloudAcknowledge),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) await _model.acknowledge(message);
  }

  @override
  Widget build(BuildContext context) {
    final error = _model.error;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.nextcloudSchedulingInbox),
        actions: [
          IconButton(
            tooltip: context.l10n.refresh,
            onPressed: _model.busy ? null : _model.load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _model.load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
          children: [
            Text(context.l10n.nextcloudInboxExplanation),
            if (_model.busy) ...[
              const SizedBox(height: 16),
              const LinearProgressIndicator(),
            ],
            if (error != null) ...[
              const SizedBox(height: 16),
              Text(
                error is DavException &&
                        error.kind == DavErrorKind.authorization
                    ? context.l10n.nextcloudOperationDenied
                    : context.l10n.nextcloudServerUnavailable,
              ),
            ],
            if (_model.loaded &&
                !_model.busy &&
                error == null &&
                _model.messages.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 24),
                child: Text(context.l10n.nextcloudInboxEmpty),
              ),
            for (final message in _model.messages)
              Card(
                child: ListTile(
                  title: Text(message.title),
                  subtitle: message.method == null
                      ? null
                      : Text(message.method!),
                  trailing: TextButton(
                    onPressed: _model.busy ? null : () => _acknowledge(message),
                    child: Text(context.l10n.nextcloudAcknowledge),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
