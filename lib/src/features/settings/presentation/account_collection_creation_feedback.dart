import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../app/app_bootstrap.dart';
import '../../../dav/dav_errors.dart';
import '../../../l10n/nextcloud_collection_error_description.dart';

/// Shared account feedback content hosted by each platform's settings view.
/// It never labels a successful calendar/task pull as failed or retries writes.
class AccountCollectionCreationFeedback extends ConsumerStatefulWidget {
  const AccountCollectionCreationFeedback({
    super.key,
    required this.accountId,
    required this.dismissButtonBuilder,
  });
  final String accountId;
  final Widget Function(
    BuildContext context,
    VoidCallback? onPressed,
    String label,
  )
  dismissButtonBuilder;

  @override
  ConsumerState<AccountCollectionCreationFeedback> createState() =>
      _AccountCollectionCreationFeedbackState();
}

class _AccountCollectionCreationFeedbackState
    extends ConsumerState<AccountCollectionCreationFeedback> {
  final _dismissing = <String>{};
  final _failed = <String>{};

  @override
  void didUpdateWidget(covariant AccountCollectionCreationFeedback oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.accountId != widget.accountId) {
      _dismissing.clear();
      _failed.clear();
    }
  }

  Future<void> _dismiss(String accountId, String operationId) async {
    setState(() {
      _dismissing.add(operationId);
      _failed.remove(operationId);
    });
    var failed = false;
    try {
      failed = !await ref.read(acknowledgeDavCollectionCreationNoticeProvider)(
        accountId,
        operationId,
      );
    } on Object {
      failed = true;
    }
    if (mounted && widget.accountId == accountId) {
      setState(() {
        _dismissing.remove(operationId);
        if (failed) _failed.add(operationId);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final accountId = widget.accountId;
    final l10n = AppLocalizations.of(context);
    final failures = ref.watch(
      accountCollectionCreationFailuresProvider(accountId),
    );
    if (failures.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final failure in failures.values)
          Padding(
            key: ValueKey((
              'collection-creation-feedback',
              accountId,
              failure.operation.id,
            )),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Semantics(
              liveRegion: true,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(failure.operation.displayName),
                        Text(
                          failure.pending
                              ? l10n.davCollectionCreationPending
                              : failure.taskList
                              ? l10n.taskListCreateFailed(
                                  failure.error.kind ==
                                          DavErrorKind.authorization
                                      ? l10n.davCollectionCreationDenied
                                      : localizedNextcloudCollectionError(
                                          l10n,
                                          failure.error,
                                        ),
                                )
                              : l10n.calendarCreateFailed(
                                  failure.error.kind ==
                                          DavErrorKind.authorization
                                      ? l10n.davCollectionCreationDenied
                                      : localizedNextcloudCollectionError(
                                          l10n,
                                          failure.error,
                                        ),
                                ),
                        ),
                      ],
                    ),
                  ),
                  if (failure.operation.state == 'rejected')
                    Column(
                      children: [
                        KeyedSubtree(
                          key: ValueKey((
                            'dismiss-collection-creation',
                            accountId,
                            failure.operation.id,
                          )),
                          child: widget.dismissButtonBuilder(
                            context,
                            _dismissing.contains(failure.operation.id)
                                ? null
                                : () =>
                                      _dismiss(accountId, failure.operation.id),
                            l10n.notificationDismissAction,
                          ),
                        ),
                        if (_failed.contains(failure.operation.id))
                          Text(l10n.operationFailed),
                      ],
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
