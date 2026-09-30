import 'package:flutter/foundation.dart';

import '../../../calendar_providers/attachment_upload_session.dart';
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
  _UnresolvedUpload({
    required this.name,
    required this.size,
    required this.beforeIds,
    required this.contentType,
    required this.bytes,
  });

  final String name;
  final int size;
  final Set<String> beforeIds;
  final String contentType;
  final List<int> bytes;
  MicrosoftAttachmentUploadSession? session;
  bool reviewed = false;
}

/// Item-scoped operation state survives closing and reopening a detail view.
/// A missing list item immediately after a lost response is not proof that the
/// upload failed: Graph attachment collections may lag the write endpoint.
final class AttachmentUploadCoordinator extends ChangeNotifier {
  final _statuses = <AttachmentUploadKey, AttachmentUploadStatus>{};
  final _unresolved = <AttachmentUploadKey, _UnresolvedUpload>{};
  final _confirmedAwaitingList = <AttachmentUploadKey, String>{};

  AttachmentUploadStatus status(AttachmentUploadKey key) =>
      _statuses[key] ?? AttachmentUploadStatus.ready;

  bool canSubmit(AttachmentUploadKey key) =>
      status(key) != AttachmentUploadStatus.submitting &&
      _unresolved[key] == null &&
      !_confirmedAwaitingList.containsKey(key);

  bool needsReconciliation(AttachmentUploadKey key) =>
      (_unresolved[key] != null || _confirmedAwaitingList.containsKey(key)) &&
      status(key) != AttachmentUploadStatus.submitting;

  bool hasResumableSession(AttachmentUploadKey key) =>
      _unresolved[key]?.session != null;

  String? confirmedId(AttachmentUploadKey key) => _confirmedAwaitingList[key];

  bool canResolveManually(AttachmentUploadKey key) =>
      _unresolved[key]?.reviewed == true &&
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
    contentType: contentType,
    bytes: bytes,
    list: () async => [
      for (final item in await client.listEventAttachments(
        calendarId: calendarId,
        eventId: eventId,
      ))
        (id: item.id, name: item.name, size: item.size),
    ],
    submit: (onSession) => client.uploadEventFileAttachment(
      calendarId: calendarId,
      eventId: eventId,
      name: name,
      contentType: contentType,
      bytes: bytes,
      onSession: onSession,
    ),
  );

  Future<AttachmentUploadStatus> reconcileEvent({
    required MicrosoftCalendarApiClient client,
    required String accountId,
    required String calendarId,
    required String eventId,
  }) => _reconcile(
    key: eventKey(accountId, calendarId, eventId),
    list: () async => [
      for (final item in await client.listEventAttachments(
        calendarId: calendarId,
        eventId: eventId,
      ))
        (id: item.id, name: item.name, size: item.size),
    ],
    resume: (attempt) => client.uploadEventFileAttachment(
      calendarId: calendarId,
      eventId: eventId,
      name: attempt.name,
      contentType: attempt.contentType,
      bytes: attempt.bytes,
      resumeSession: attempt.session,
    ),
  );

  Future<void> cancelEvent({
    required MicrosoftCalendarApiClient client,
    required String accountId,
    required String calendarId,
    required String eventId,
  }) => cancelSession(
    key: eventKey(accountId, calendarId, eventId),
    cancel: client.cancelEventAttachmentUpload,
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
    contentType: contentType,
    bytes: bytes,
    list: () => _taskItems(client, taskListId, taskId),
    submit: (onSession) => client.uploadTaskFileAttachment(
      taskListId: taskListId,
      taskId: taskId,
      name: name,
      contentType: contentType,
      bytes: bytes,
      onSession: onSession,
    ),
  );

  Future<AttachmentUploadStatus> reconcileTask({
    required MicrosoftTodoAttachmentsApiClient client,
    required String accountId,
    required String taskListId,
    required String taskId,
  }) => _reconcile(
    key: taskKey(accountId, taskListId, taskId),
    list: () => _taskItems(client, taskListId, taskId),
    resume: (attempt) => client.uploadTaskFileAttachment(
      taskListId: taskListId,
      taskId: taskId,
      name: attempt.name,
      contentType: attempt.contentType,
      bytes: attempt.bytes,
      resumeSession: attempt.session,
    ),
  );

  Future<void> cancelTask({
    required MicrosoftTodoAttachmentsApiClient client,
    required String accountId,
    required String taskListId,
    required String taskId,
  }) => cancelSession(
    key: taskKey(accountId, taskListId, taskId),
    cancel: client.cancelTaskAttachmentUpload,
  );

  void _set(AttachmentUploadKey key, AttachmentUploadStatus value) {
    _statuses[key] = value;
    notifyListeners();
  }

  Future<void> upload({
    required AttachmentUploadKey key,
    required String name,
    required int size,
    required String contentType,
    required List<int> bytes,
    required Future<List<AttachmentUploadRemoteItem>> Function() list,
    required Future<String> Function(
      void Function(MicrosoftAttachmentUploadSession),
    )
    submit,
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
    final attempt = _UnresolvedUpload(
      name: name,
      size: size,
      beforeIds: beforeIds,
      contentType: contentType,
      bytes: bytes,
    );
    try {
      final id = await submit((session) {
        attempt.session = session;
        _unresolved[key] = attempt;
      });
      _confirm(key, id);
      await _refreshConfirmed(key, list);
      return;
    } on Object catch (error) {
      if (attempt.session == null && _confirmedNotCommitted(error)) {
        _unresolved.remove(key);
        _set(key, AttachmentUploadStatus.ready);
        rethrow;
      }
      _unresolved[key] = attempt;
      _set(key, AttachmentUploadStatus.unresolved);
      throw const AttachmentUploadUnresolvedException();
    }
  }

  void _confirm(AttachmentUploadKey key, String id) {
    if (id.isEmpty) throw const MicrosoftAttachmentUploadUncertain();
    _unresolved.remove(key);
    _confirmedAwaitingList[key] = id;
    _set(key, AttachmentUploadStatus.committed);
  }

  Future<void> _refreshConfirmed(
    AttachmentUploadKey key,
    Future<List<AttachmentUploadRemoteItem>> Function() list,
  ) async {
    final id = _confirmedAwaitingList[key];
    if (id == null) return;
    try {
      if ((await list()).any((item) => item.id == id)) {
        _confirmedAwaitingList.remove(key);
        notifyListeners();
      }
    } on Object {
      // The attachment ID proves the write; a failed list is only a pending
      // presentation refresh, never a reason to resubmit the payload.
    }
  }

  Future<AttachmentUploadStatus> _reconcile({
    required AttachmentUploadKey key,
    required Future<List<AttachmentUploadRemoteItem>> Function() list,
    required Future<String> Function(_UnresolvedUpload) resume,
  }) async {
    final attempt = _unresolved[key];
    if (attempt == null) {
      await _refreshConfirmed(key, list);
      return status(key);
    }
    if (attempt.session != null) {
      _set(key, AttachmentUploadStatus.submitting);
      try {
        final id = await resume(attempt);
        _confirm(key, id);
        await _refreshConfirmed(key, list);
        return status(key);
      } on Object {
        attempt.reviewed = true;
        _set(key, AttachmentUploadStatus.unresolved);
        throw const AttachmentUploadUnresolvedException();
      }
    }
    // A same-name, same-size attachment from another client is not evidence
    // that this attempt committed. Listing is still useful for the user to
    // inspect, but only the response ID can automatically confirm it.
    await list();
    attempt.reviewed = true;
    return status(key);
  }

  Future<void> cancelSession({
    required AttachmentUploadKey key,
    required Future<void> Function(MicrosoftAttachmentUploadSession) cancel,
  }) async {
    final attempt = _unresolved[key];
    final session = attempt?.session;
    if (session == null || status(key) == AttachmentUploadStatus.submitting) {
      throw const AttachmentUploadUnresolvedException();
    }
    _set(key, AttachmentUploadStatus.submitting);
    try {
      await cancel(session);
      _unresolved.remove(key);
      _set(key, AttachmentUploadStatus.ready);
    } on Object {
      _set(key, AttachmentUploadStatus.unresolved);
      throw const AttachmentUploadUnresolvedException();
    }
  }

  /// The user has independently verified the outcome in the provider. This
  /// must only be invoked behind an explicit confirmation in native UI.
  void resolveUncertainManually(
    AttachmentUploadKey key, {
    required bool exists,
  }) {
    if (_unresolved[key]?.reviewed != true ||
        status(key) == AttachmentUploadStatus.submitting) {
      throw const AttachmentUploadUnresolvedException();
    }
    _unresolved.remove(key);
    _set(
      key,
      exists ? AttachmentUploadStatus.committed : AttachmentUploadStatus.ready,
    );
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
