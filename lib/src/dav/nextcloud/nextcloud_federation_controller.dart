import 'package:flutter/foundation.dart';

import 'nextcloud_dav_context.dart';
import 'nextcloud_federation_service.dart';

final class NextcloudFederationController extends ChangeNotifier {
  NextcloudFederationController(this.service);
  final NextcloudFederationService service;
  List<NextcloudFederationInvitation>? invitations;
  Object? error;
  bool busy = false, refreshPending = false, _disposed = false;

  Future<void> load() => _run(() async {
    final current = await service.pending();
    if (_disposed) return;
    invitations = current;
    if (refreshPending) {
      refreshPending =
          await service.collections.refreshResult() ==
          NextcloudMutationOutcome.refreshPending;
    }
  });

  Future<void> respond(
    NextcloudFederationInvitation invitation, {
    required bool accept,
  }) => _run(() async {
    final outcome = accept
        ? await service.accept(invitation)
        : await service.decline(invitation);
    if (_disposed) return;
    invitations = invitations?.where((i) => i.id != invitation.id).toList();
    refreshPending = outcome == NextcloudMutationOutcome.refreshPending;
    try {
      final current = await service.pending();
      if (!_disposed) invitations = current;
    } on Object {
      refreshPending = true;
    }
  });

  Future<void> _run(Future<void> Function() action) async {
    if (busy || _disposed) return;
    busy = true;
    error = null;
    notifyListeners();
    try {
      await action();
    } on Object catch (caught) {
      error = caught;
    }
    if (!_disposed) {
      busy = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
