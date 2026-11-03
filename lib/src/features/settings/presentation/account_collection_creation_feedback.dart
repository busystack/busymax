import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../app/app_bootstrap.dart';
import '../../../dav/dav_errors.dart';
import '../../../l10n/nextcloud_collection_error_description.dart';

/// Shared account feedback content hosted by each platform's settings view.
/// It never labels a successful calendar/task pull as failed or retries writes.
class AccountCollectionCreationFeedback extends ConsumerWidget {
  const AccountCollectionCreationFeedback({super.key, required this.accountId});
  final String accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final failures = ref
        .watch(accountSyncActivityProvider)
        .collectionCreationFailures(accountId);
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
                ],
              ),
            ),
          ),
      ],
    );
  }
}
