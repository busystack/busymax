import 'package:flutter/foundation.dart';

import '../../../core/http/request_dispatch_exception.dart';
import '../../../microsoft_calendar/microsoft_calendar_errors.dart';
import '../../../microsoft_calendar/microsoft_calendar_api_client.dart';
import '../../../microsoft_todo/api/microsoft_todo_api_client.dart';
import '../../../microsoft_todo/api/microsoft_todo_api_error.dart';

typedef AttachmentUploadKey = ({
  String accountId,
  String kind,
  String containerId,
  String itemId,
});

typedef AttachmentUploadRemoteItem = ({String id, String name, int? size});

enum AttachmentUploadStatus { ready, submitting, unresolved, committed }

class AttachmentUploadUnresolvedException implements Exception {
  const AttachmentUploadUnresolvedException();

  @override
  String toString() =>
      'Attachment upload outcome is unresolved. Refresh attachments before retrying.';
}

final class _UnresolvedUpload {
  const _UnresolvedUpload({
    required this.name,
    required this.size,
    required this.beforeIds,
  });

  final String name;
  final int size;
  final Set<String> beforeIds;
}

/// Item-scoped operation state survives closing and reopening a detail view.
/// A missing list item immediately after a lost response is not proof that the
/// upload failed: Graph attachment collections may lag the write endpoint.
final class AttachmentUploadCoordinator extends ChangeNotifier {
  final _statuses = <AttachmentUploadKey, AttachmentUploadStatus>{};
  final _unresolved = <AttachmentUploadKey, _UnresolvedUpload>{};

  AttachmentUploadStatus status(AttachmentUploadKey key) =>
      _statuses[key] ?? AttachmentUploadStatus.ready;

  bool canSubmit(AttachmentUploadKey key) =>
      status(key) != AttachmentUploadStatus.submitting &&
      _unresolved[key] == null;

  bool needsReconciliation(AttachmentUploadKey key) =>
      _unresolved[key] != null &&
      status(key) != AttachmentUploadStatus.submitting;

  static AttachmentUploadKey eventKey(
    String accountId,
    String calendarId,
    String eventId,
  ) => (
    accountId: accountId,
    kind: 'event',
    containerId: calendarId,
    itemId: eventId,
  );

  static AttachmentUploadKey taskKey(
    String accountId,
    String taskListId,
    String taskId,
  ) => (
    accountId: accountId,
    kind: 'task',
    containerId: taskListId,
    itemId: taskId,
  );

  Future<void> uploadEvent({
    required MicrosoftCalendarApiClient client,
    required String accountId,
    required String calendarId,
    required String eventId,
    required String name,
    required String contentType,
    required List<int> bytes,
  }) => upload(
    key: eventKey(accountId, calendarId, eventId),
    name: name,
    size: bytes.length,
    list: () async => [
      for (final item in await client.listEventAttachments(
        calendarId: calendarId,
        eventId: eventId,
      ))
        (id: item.id, name: item.name, size: item.size),
    ],
    submit: () => client.uploadEventFileAttachment(
      calendarId: calendarId,
      eventId: eventId,
      name: name,
      contentType: contentType,
      bytes: bytes,
    ),
  );

  Future<AttachmentUploadStatus> reconcileEvent({
    required MicrosoftCalendarApiClient client,
    required String accountId,
    required String calendarId,
    required String eventId,
  }) => reconcile(
    key: eventKey(accountId, calendarId, eventId),
    list: () async => [
      for (final item in await client.listEventAttachments(
        calendarId: calendarId,
        eventId: eventId,
      ))
        (id: item.id, name: item.name, size: item.size),
    ],
  );

  Future<List<AttachmentUploadRemoteItem>> _taskItems(
    MicrosoftTodoAttachmentsApiClient client,
    String taskListId,
    String taskId,
  ) async {
    final items = <AttachmentUploadRemoteItem>[];
    final seen = <String>{};
    String? next;
    do {
      final page = await client.listTaskAttachmentsPage(
        taskListId: taskListId,
        taskId: taskId,
        nextLink: next,
      );
      items.addAll([
        for (final item in page.attachments)
          (id: item.id, name: item.name, size: item.size),
      ]);
      next = page.nextLink;
      if (next != null && !seen.add(next)) {
        throw const FormatException('Attachment pagination loop.');
      }
    } while (next != null);
    return items;
  }

  Future<void> uploadTask({
    required MicrosoftTodoAttachmentsApiClient client,
    required String accountId,
    required String taskListId,
    required String taskId,
    required String name,
    required String contentType,
    required List<int> bytes,
  }) => upload(
    key: taskKey(accountId, taskListId, taskId),
    name: name,
    size: bytes.length,
    list: () => _taskItems(client, taskListId, taskId),
    submit: () => client.uploadTaskFileAttachment(
      taskListId: taskListId,
      taskId: taskId,
      name: name,
      contentType: contentType,
      bytes: bytes,
    ),
  );

  Future<AttachmentUploadStatus> reconcileTask({
    required MicrosoftTodoAttachmentsApiClient client,
    required String accountId,
    required String taskListId,
    required String taskId,
  }) => reconcile(
    key: taskKey(accountId, taskListId, taskId),
    list: () => _taskItems(client, taskListId, taskId),
  );

  void _set(AttachmentUploadKey key, AttachmentUploadStatus value) {
    _statuses[key] = value;
    notifyListeners();
  }

  Future<void> upload({
    required AttachmentUploadKey key,
    required String name,
    required int size,
    required Future<List<AttachmentUploadRemoteItem>> Function() list,
    required Future<void> Function() submit,
  }) async {
    if (!canSubmit(key)) throw const AttachmentUploadUnresolvedException();
    _set(key, AttachmentUploadStatus.submitting);
    late final Set<String> beforeIds;
    try {
      beforeIds = (await list())
          .map((item) => item.id)
          .where((id) => id.isNotEmpty)
          .toSet();
    } on Object {
      _set(key, AttachmentUploadStatus.ready);
      rethrow;
    }
    try {
      await submit();
      _unresolved[key] = _UnresolvedUpload(
        name: name,
        size: size,
        beforeIds: beforeIds,
      );
      _set(key, AttachmentUploadStatus.committed);
      try {
        await reconcile(key: key, list: list);
      } on Object {
        // The write is confirmed. Keep it committed and block a repeat until
        // an authoritative list identifies the new attachment.
      }
      return;
    } on Object catch (error) {
      if (_confirmedNotCommitted(error)) {
        _unresolved.remove(key);
        _set(key, AttachmentUploadStatus.ready);
        rethrow;
      }
      _unresolved[key] = _UnresolvedUpload(
        name: name,
        size: size,
        beforeIds: beforeIds,
      );
      _set(key, AttachmentUploadStatus.unresolved);
      try {
        await reconcile(key: key, list: list);
      } on Object {
        // Keep the unresolved state when authoritative retrieval fails.
      }
      if (status(key) == AttachmentUploadStatus.committed) return;
      throw const AttachmentUploadUnresolvedException();
    }
  }

  Future<AttachmentUploadStatus> reconcile({
    required AttachmentUploadKey key,
    required Future<List<AttachmentUploadRemoteItem>> Function() list,
  }) async {
    final attempt = _unresolved[key];
    if (attempt == null) return status(key);
    final items = await list();
    final matching = items
        .where(
          (item) =>
              item.id.isNotEmpty &&
              !attempt.beforeIds.contains(item.id) &&
              item.name == attempt.name &&
              item.size == attempt.size,
        )
        .toList();
    if (matching.length == 1) {
      _unresolved.remove(key);
      _set(key, AttachmentUploadStatus.committed);
    }
    return status(key);
  }

  bool _confirmedNotCommitted(Object error) {
    if (error is RequestNotDispatchedException || error is ArgumentError) {
      return true;
    }
    final code = switch (error) {
      MicrosoftCalendarApiError e => e.statusCode,
      MicrosoftTodoApiError e => e.statusCode,
      _ => null,
    };
    return code != null &&
        code >= 400 &&
        code < 500 &&
        code != 408 &&
        code != 409 &&
        code != 429;
  }
}
