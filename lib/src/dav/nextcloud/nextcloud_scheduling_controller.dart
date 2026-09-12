import 'package:flutter/foundation.dart';

import '../../features/calendar/presentation/event_editor_draft.dart';
import 'nextcloud_scheduling_service.dart';

/// Shared request and pending state for the native scheduling dialogs.
/// Opening either view never mutates a calendar event or queues an invitation.
final class NextcloudSchedulingController extends ChangeNotifier {
  NextcloudSchedulingController(
    this.service,
    this.collectionId, {
    this.draft,
    required this.fallbackTimeZone,
  });
  final NextcloudSchedulingService service;
  final String collectionId;
  final EventEditorDraft? draft;
  final String fallbackTimeZone;
  List<NextcloudInboxMessage> messages = const [];
  List<NextcloudFreeBusyResult> availability = const [];
  Object? error;
  bool busy = false, loaded = false, _disposed = false;

  Future<void> load() async {
    if (busy || _disposed) return;
    busy = true;
    error = null;
    notifyListeners();
    try {
      if (draft == null) {
        final cached = await service.cachedInbox(collectionId);
        if (_disposed) return;
        messages = cached;
        notifyListeners();
        final fresh = await service.inbox(collectionId);
        if (!_disposed) messages = fresh;
      } else {
        final result = await service.freeBusyForDraft(
          collectionId: collectionId,
          draft: draft!,
          fallbackTimeZone: fallbackTimeZone,
        );
        if (!_disposed) availability = result;
      }
    } on Object catch (failure) {
      if (!_disposed) error = failure;
    } finally {
      if (!_disposed) {
        busy = false;
        loaded = true;
        notifyListeners();
      }
    }
  }

  Future<void> acknowledge(NextcloudInboxMessage message) async {
    if (busy || _disposed || !messages.contains(message)) return;
    busy = true;
    error = null;
    notifyListeners();
    try {
      await service.acknowledge(collectionId, message);
      if (!_disposed) {
        messages = List.unmodifiable(
          messages.where((m) => m.href != message.href),
        );
      }
    } on Object catch (failure) {
      if (!_disposed) error = failure;
    } finally {
      if (!_disposed) {
        busy = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
