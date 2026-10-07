import 'dart:async';

import 'package:busymax/src/platform/common/desktop_services.dart';

/// Delivers controlled native activation requests through the production service.
final class TestDesktopActivationService implements DesktopActivationService {
  final _controller = StreamController<DesktopActivation>.broadcast();

  void add(DesktopActivation activation) => _controller.add(activation);

  @override
  Stream<DesktopActivation> get activations => _controller.stream;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> dispose() => _controller.close();
}
