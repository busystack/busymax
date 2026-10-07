import 'dart:async';
import 'package:uuid/uuid.dart';
import 'oauth_models.dart';

/// A UI-owned invocation signal. It never cancels persistence recovery itself.
final class AuthorizationCancellation {
  final Completer<void> _signal = Completer<void>();
  bool _committed = false;
  bool get wasCommitted => _committed;
  void committed() => _committed = true;
  bool get isCancelled => _signal.isCompleted;
  Future<void> get signal => _signal.future;
  void cancel() {
    if (!isCancelled && !_committed) _signal.complete();
  }
}

/// Captured before preparation. New invocations cannot replace this future.
final class AuthorizationAttempt {
  AuthorizationAttempt({
    required this.nowUtc,
    AuthorizationCancellation? cancellation,
    Duration lifetime = const Duration(minutes: 10),
  }) : _externalCancellation = cancellation,
       deadline = nowUtc().add(lifetime) {
    _timer = Timer(lifetime, () {
      _expired = true;
      cancel();
    });
    if (cancellation?.isCancelled == true) cancel();
    if (cancellation != null) {
      unawaited(cancellation.signal.then((_) => cancel()));
    }
  }
  final AuthorizationCancellation? _externalCancellation;
  final String id = const Uuid().v4();
  final DateTime Function() nowUtc;
  final DateTime deadline;
  final AuthorizationCancellation _cancellation = AuthorizationCancellation();
  late final Timer _timer;
  bool _expired = false;
  bool _committed = false;
  Future<void> get cancellation => _cancellation.signal;
  bool get cancelled => !_committed && _cancellation.isCancelled;
  void cancel() {
    if (!_committed) _cancellation.cancel();
  }

  void check() {
    if (_committed) return;
    if (_expired || !nowUtc().isBefore(deadline)) {
      throw const OAuthException(
        'OAuthRequestTimeout',
        'Authorization timed out. Try again.',
      );
    }
    if (cancelled) {
      throw const OAuthException(
        'OAuthSignInCancelled',
        'Authorization was cancelled.',
      );
    }
  }

  Future<T> wait<T>(Future<T> work) async {
    check();
    final result = await Future.any([
      work,
      cancellation.then<T>((_) {
        check();
        throw StateError('Cancelled authorization');
      }),
    ]);
    check();
    return result;
  }

  void committed() {
    _committed = true;
    _externalCancellation?.committed();
    dispose();
  }

  void dispose() => _timer.cancel();
}

final class AuthorizationAttemptOwner {
  AuthorizationAttempt? current;
  AuthorizationAttempt begin(
    DateTime Function() nowUtc,
    AuthorizationCancellation? cancellation,
  ) {
    current?.cancel();
    current?.dispose();
    return current = AuthorizationAttempt(
      nowUtc: nowUtc,
      cancellation: cancellation,
    );
  }

  void finish(AuthorizationAttempt attempt) {
    attempt.cancel();
    attempt.dispose();
    if (identical(current, attempt)) current = null;
  }
}
