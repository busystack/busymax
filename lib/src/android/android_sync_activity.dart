import 'dart:async';

import 'package:busymax_android_platform/busymax_android_platform.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../features/sync/account_sync_activity.dart';
import '../features/sync/sync_request.dart';

/// The plugin keeps each engine's current scopes in memory while it is
/// attached. A dead engine cannot leave a persisted running flag.
final class AndroidSyncActivity extends AccountSyncActivity {
  AndroidSyncActivity(this._platform) {
    addListener(_publish);
  }

  final BusyMaxAndroidPlatform _platform;
  Set<SyncScope> _published = const {};

  void _publish() {
    final current = localExecutingScopes;
    if (setEquals(current, _published)) return;
    _published = current;
    unawaited(_send(current));
  }

  Future<void> _send(Set<SyncScope> scopes) async {
    try {
      await _platform.publishSyncActivity([
        for (final scope in scopes)
          [scope.kind.name, scope.accountId, scope.resourceId],
      ]);
    } on PlatformException {
      // The engine can detach between the state change and the platform call.
    } on MissingPluginException {
      // The native bridge is unavailable in engine-free widget tests.
    }
  }

  void updateFromPlatform(List<Object?> scopes) {
    setExternalExecuting([
      for (final value in scopes)
        if (value case [
          final String kind,
          final String? accountId,
          final String? resourceId,
        ])
          for (final type in SyncScopeKind.values.where(
            (item) => item.name == kind,
          ))
            (kind: type, accountId: accountId, resourceId: resourceId),
    ]);
  }

  Future<void> reconcilePlatformActivity() async {
    try {
      updateFromPlatform(await _platform.externalSyncActivity());
    } on PlatformException {
      setExternalExecuting(const []);
    } on MissingPluginException {
      setExternalExecuting(const []);
    }
  }

  @override
  void dispose() {
    if (_published.isNotEmpty) unawaited(_send(const {}));
    super.dispose();
  }
}
