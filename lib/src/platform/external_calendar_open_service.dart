import 'dart:async';

import 'package:flutter/services.dart';

const externalCalendarOpenChannelName =
    'io.busystack.busymax/external_calendar_open';

enum ExternalCalendarOpenKind { webCal, icsFile }

final class ExternalCalendarOpenRequest {
  const ExternalCalendarOpenRequest({required this.kind, required this.value});

  final ExternalCalendarOpenKind kind;
  final String value;
}

final class ExternalCalendarOpenService {
  ExternalCalendarOpenService({
    MethodChannel channel = const MethodChannel(
      externalCalendarOpenChannelName,
    ),
  }) : _channel = channel;

  final MethodChannel _channel;
  final _requests = StreamController<ExternalCalendarOpenRequest>();
  bool _initialized = false;

  Stream<ExternalCalendarOpenRequest> get requests => _requests.stream;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'openItem' || call.arguments is! Map) return;
      final arguments = Map<Object?, Object?>.from(call.arguments as Map);
      final kind = arguments['kind'];
      final value = arguments['value'];
      if (value is! String || value.isEmpty) return;
      switch (kind) {
        case 'webcal':
          _requests.add(
            ExternalCalendarOpenRequest(
              kind: ExternalCalendarOpenKind.webCal,
              value: value,
            ),
          );
        case 'ics':
          _requests.add(
            ExternalCalendarOpenRequest(
              kind: ExternalCalendarOpenKind.icsFile,
              value: value,
            ),
          );
      }
    });
    await _channel.invokeMethod<void>('ready');
  }

  Future<void> dispose() async {
    _channel.setMethodCallHandler(null);
    await _requests.close();
  }
}
