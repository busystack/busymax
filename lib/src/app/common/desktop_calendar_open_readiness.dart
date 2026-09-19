import 'dart:async';

import 'package:flutter/widgets.dart';

/// Cancellable, frame-driven readiness checks for desktop calendar-open flows.
final class DesktopCalendarOpenReadiness {
  final _disposed = Completer<void>();

  bool get isActive => !_disposed.isCompleted;

  Future<bool> waitFor(Future<void> future) async {
    if (!isActive) return false;
    final completed = await Future.any<bool>([
      future.then((_) => true),
      _disposed.future.then((_) => false),
    ]);
    return completed && isActive;
  }

  Future<BuildContext?> waitForRootNavigator(
    GlobalKey<NavigatorState> navigatorKey,
  ) async {
    while (isActive) {
      if (!await waitFor(WidgetsBinding.instance.endOfFrame)) return null;
      final navigator = navigatorKey.currentState;
      final overlay = navigator?.overlay;
      final context = navigatorKey.currentContext;
      if (navigator != null &&
          navigator.mounted &&
          overlay != null &&
          overlay.mounted &&
          context != null &&
          context.mounted) {
        return context;
      }
    }
    return null;
  }

  bool isUsableRootNavigator(
    GlobalKey<NavigatorState> navigatorKey,
    BuildContext context,
  ) {
    final navigator = navigatorKey.currentState;
    final overlay = navigator?.overlay;
    return isActive &&
        context.mounted &&
        identical(context, navigatorKey.currentContext) &&
        navigator != null &&
        navigator.mounted &&
        overlay != null &&
        overlay.mounted;
  }

  void dispose() {
    if (!_disposed.isCompleted) _disposed.complete();
  }
}
