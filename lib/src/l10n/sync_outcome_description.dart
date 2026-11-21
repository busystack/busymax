import '../../l10n/generated/app_localizations.dart';
import '../features/sync/sync_request.dart';

String syncOutcomeDescription(AppLocalizations l10n, SyncDisposition? status) =>
    switch (status) {
      SyncDisposition.partial => l10n.syncPartiallyCompleted,
      SyncDisposition.deferred => l10n.syncDeferred,
      SyncDisposition.missing => l10n.collectionsUnavailable,
      SyncDisposition.disabled => l10n.off,
      _ => l10n.cachedSyncError,
    };
