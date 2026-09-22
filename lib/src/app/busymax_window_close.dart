import 'dart:async';

import 'package:flutter/widgets.dart';

typedef BusyMaxWindowCloseHandler = FutureOr<bool> Function();

/// Coordinates destructive top-level window close requests with the active
/// modal surface that owns any transient editor state.
///
/// Handlers are ordered by presentation: the most recently mounted active
/// surface owns the decision. Concurrent close requests share one resolution
/// so they cannot open duplicate confirmation dialogs.
final class BusyMaxWindowCloseCoordinator {
  final List<_BusyMaxWindowCloseRegistration> _registrations = [];
  Future<bool>? _pendingRequest;

  bool get hasActiveHandler => _registrations.isNotEmpty;

  Future<bool> requestClose() {
    final pending = _pendingRequest;
    if (pending != null) return pending;

    final request = _resolveCloseRequest();
    _pendingRequest = request;
    return request.whenComplete(() {
      if (identical(_pendingRequest, request)) {
        _pendingRequest = null;
      }
    });
  }

  _BusyMaxWindowCloseRegistration _register(BusyMaxWindowCloseHandler handler) {
    final registration = _BusyMaxWindowCloseRegistration(this, handler);
    _registrations.add(registration);
    return registration;
  }

  Future<bool> _resolveCloseRequest() async {
    if (_registrations case [..., final active]) {
      try {
        return await active.handler();
      } on Object catch (error, stackTrace) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stackTrace,
            library: 'BusyMax window close coordinator',
            context: ErrorDescription(
              'while asking the active surface to resolve a window close',
            ),
          ),
        );
        return false;
      }
    }
    return true;
  }

  void _unregister(_BusyMaxWindowCloseRegistration registration) {
    _registrations.remove(registration);
  }
}

final class _BusyMaxWindowCloseRegistration {
  _BusyMaxWindowCloseRegistration(this._owner, this.handler);

  BusyMaxWindowCloseCoordinator? _owner;
  final BusyMaxWindowCloseHandler handler;

  void dispose() {
    _owner?._unregister(this);
    _owner = null;
  }
}

class BusyMaxWindowCloseScope extends InheritedWidget {
  const BusyMaxWindowCloseScope({
    super.key,
    required this.coordinator,
    required super.child,
  });

  final BusyMaxWindowCloseCoordinator coordinator;

  static BusyMaxWindowCloseCoordinator? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<BusyMaxWindowCloseScope>()
        ?.coordinator;
  }

  @override
  bool updateShouldNotify(BusyMaxWindowCloseScope oldWidget) =>
      !identical(coordinator, oldWidget.coordinator);
}

/// Registers a close decision owned by an editor or modal surface while that
/// surface is mounted beneath [BusyMaxWindowCloseScope].
class BusyMaxWindowCloseGuard extends StatefulWidget {
  const BusyMaxWindowCloseGuard({
    super.key,
    required this.onCloseRequested,
    required this.child,
  });

  final BusyMaxWindowCloseHandler onCloseRequested;
  final Widget child;

  @override
  State<BusyMaxWindowCloseGuard> createState() =>
      _BusyMaxWindowCloseGuardState();
}

class _BusyMaxWindowCloseGuardState extends State<BusyMaxWindowCloseGuard> {
  BusyMaxWindowCloseCoordinator? _coordinator;
  _BusyMaxWindowCloseRegistration? _registration;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final coordinator = BusyMaxWindowCloseScope.maybeOf(context);
    if (identical(coordinator, _coordinator)) return;
    _registration?.dispose();
    _coordinator = coordinator;
    _registration = coordinator?._register(() => widget.onCloseRequested());
  }

  @override
  void dispose() {
    _registration?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
