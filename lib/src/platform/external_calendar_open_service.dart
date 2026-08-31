import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';

import 'common/desktop_services.dart';

const externalCalendarOpenChannelName =
    'io.busystack.busymax/external_calendar_open';

enum ExternalCalendarOpenKind { webCal, icsFile }

final class ExternalCalendarOpenRequest {
  const ExternalCalendarOpenRequest({required this.kind, required this.value});

  final ExternalCalendarOpenKind kind;
  final String value;
}

/// Validates and queues native desktop activations before exposing them to the
/// application. Missing native support is treated as an ordinary launch, so an
/// unpackaged or test build never fails merely because the channel is absent.
final class ExternalCalendarOpenService implements DesktopActivationService {
  ExternalCalendarOpenService({
    MethodChannel channel = const MethodChannel(
      externalCalendarOpenChannelName,
    ),
  }) : _channel = channel;

  final MethodChannel _channel;
  late final StreamController<DesktopActivation> _activations =
      StreamController<DesktopActivation>.broadcast(onListen: _flushPending);
  final _calendarRequests =
      StreamController<ExternalCalendarOpenRequest>.broadcast();
  bool _initialized = false;
  final List<DesktopActivation> _pending = [];

  @override
  Stream<DesktopActivation> get activations => _activations.stream;

  /// Compatibility stream retained for the Linux presentation while the
  /// common activation model is used by both application roots.
  Stream<ExternalCalendarOpenRequest> get requests => _calendarRequests.stream;

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'openItem':
          _acceptLegacyOpenItem(call.arguments);
        case 'activation':
          _acceptEncoded(call.arguments);
      }
    });
    try {
      final pending = await _channel.invokeListMethod<Object?>('ready');
      for (final value in pending ?? const []) {
        _acceptEncoded(value);
      }
    } on MissingPluginException {
      // Tests and unsupported/unpackaged runners have no activation bridge.
    } on PlatformException {
      // Invalid native activation state must not prevent ordinary startup.
    }
  }

  void _acceptLegacyOpenItem(Object? raw) {
    if (raw is! Map) return;
    final arguments = Map<Object?, Object?>.from(raw);
    final kind = arguments['kind'];
    final value = arguments['value'];
    if (value is! String) return;
    final activation = switch (kind) {
      'webcal' => DesktopActivation(
        kind: DesktopActivationKind.webCal,
        value: value,
      ),
      'ics' => DesktopActivation(
        kind: DesktopActivationKind.icsFile,
        value: value,
      ),
      _ => null,
    };
    if (activation?.isValid == true) _emit(activation!);
  }

  void _acceptEncoded(Object? raw) {
    final DesktopActivation? activation;
    if (raw is String) {
      activation = DesktopActivation.tryDecode(raw);
    } else if (raw is Map) {
      try {
        activation = DesktopActivation.tryDecode(
          jsonEncode(Map<Object?, Object?>.from(raw)),
        );
      } on JsonUnsupportedObjectError {
        return;
      }
    } else {
      activation = null;
    }
    if (activation != null) _emit(activation);
  }

  void _emit(DesktopActivation activation) {
    if (_activations.hasListener) {
      _activations.add(activation);
    } else {
      _pending.add(activation);
    }
    switch (activation.kind) {
      case DesktopActivationKind.webCal:
        _calendarRequests.add(
          ExternalCalendarOpenRequest(
            kind: ExternalCalendarOpenKind.webCal,
            value: activation.value!,
          ),
        );
      case DesktopActivationKind.icsFile:
        _calendarRequests.add(
          ExternalCalendarOpenRequest(
            kind: ExternalCalendarOpenKind.icsFile,
            value: activation.value!,
          ),
        );
      case DesktopActivationKind.normalLaunch:
      case DesktopActivationKind.startMinimized:
      case DesktopActivationKind.notification:
        break;
    }
  }

  void _flushPending() {
    if (_pending.isEmpty) return;
    final queued = List<DesktopActivation>.of(_pending);
    _pending.clear();
    scheduleMicrotask(() {
      for (final activation in queued) {
        if (!_activations.isClosed) _activations.add(activation);
      }
    });
  }

  @override
  Future<void> dispose() async {
    _channel.setMethodCallHandler(null);
    await _activations.close();
    await _calendarRequests.close();
  }
}
