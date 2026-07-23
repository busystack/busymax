import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import 'linux_header_bar_service.dart';

@immutable
final class BusyMaxHeaderBarConfiguration {
  const BusyMaxHeaderBarConfiguration({
    required this.labels,
    required this.sidebarWidth,
    required this.theme,
  });

  final BusyMaxHeaderBarLabels labels;
  final double sidebarWidth;
  final BusyMaxHeaderBarTheme theme;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is BusyMaxHeaderBarConfiguration &&
            labels == other.labels &&
            sidebarWidth == other.sidebarWidth &&
            theme == other.theme;
  }

  @override
  int get hashCode => Object.hash(labels, sidebarWidth, theme);
}

typedef BusyMaxHeaderBarConfigurationApplier =
    Future<void> Function(BusyMaxHeaderBarConfiguration configuration);
typedef BusyMaxAfterFrameScheduler = void Function(VoidCallback callback);
typedef BusyMaxHeaderBarConfigurationErrorReporter =
    void Function(Object error, StackTrace stackTrace);

/// Coalesces build-time native chrome updates and applies them serially.
///
/// A route or theme change can rebuild the application several times in one
/// frame. Only the latest configuration from that frame reaches GTK, while an
/// update requested during an in-flight platform call is queued behind it.
final class BusyMaxHeaderBarConfigurationSynchronizer {
  BusyMaxHeaderBarConfigurationSynchronizer(LinuxHeaderBarService service)
    : this._(
        apply: (configuration) async {
          await service.initialize();
          await service.setLocalizedLabels(configuration.labels);
          await service.setSidebarWidth(configuration.sidebarWidth);
          await service.setTheme(configuration.theme);
        },
        scheduleAfterFrame: _afterCurrentFrame,
        reportError: _reportApplyFailure,
      );

  @visibleForTesting
  BusyMaxHeaderBarConfigurationSynchronizer.forTesting({
    required BusyMaxHeaderBarConfigurationApplier apply,
    required BusyMaxAfterFrameScheduler scheduleAfterFrame,
    BusyMaxHeaderBarConfigurationErrorReporter? reportError,
  }) : this._(
         apply: apply,
         scheduleAfterFrame: scheduleAfterFrame,
         reportError: reportError ?? _reportApplyFailure,
       );

  BusyMaxHeaderBarConfigurationSynchronizer._({
    required BusyMaxHeaderBarConfigurationApplier apply,
    required BusyMaxAfterFrameScheduler scheduleAfterFrame,
    required BusyMaxHeaderBarConfigurationErrorReporter reportError,
  }) : _apply = apply,
       _scheduleAfterFrame = scheduleAfterFrame,
       _reportError = reportError;

  final BusyMaxHeaderBarConfigurationApplier _apply;
  final BusyMaxAfterFrameScheduler _scheduleAfterFrame;
  final BusyMaxHeaderBarConfigurationErrorReporter _reportError;

  BusyMaxHeaderBarConfiguration? _requested;
  Future<void> _tail = Future<void>.value();
  var _revision = 0;
  var _disposed = false;

  void schedule(BusyMaxHeaderBarConfiguration configuration) {
    if (_disposed || _requested == configuration) {
      return;
    }
    _requested = configuration;
    final revision = ++_revision;
    _scheduleAfterFrame(() {
      if (_disposed || revision != _revision) {
        return;
      }
      _tail = _tail.then((_) => _applySafely(configuration, revision));
    });
  }

  @visibleForTesting
  Future<void> get settled => _tail;

  void dispose() {
    _disposed = true;
    _revision += 1;
  }

  Future<void> _applyIfCurrent(
    BusyMaxHeaderBarConfiguration configuration,
    int revision,
  ) async {
    if (_disposed || revision != _revision) {
      return;
    }
    await _apply(configuration);
  }

  Future<void> _applySafely(
    BusyMaxHeaderBarConfiguration configuration,
    int revision,
  ) async {
    try {
      await _applyIfCurrent(configuration, revision);
    } catch (error, stackTrace) {
      // A platform-channel failure must not poison the serial queue. Clear the
      // deduplication token only when this remains the newest request so an
      // equivalent configuration can be retried on a later rebuild.
      if (!_disposed && revision == _revision && _requested == configuration) {
        _requested = null;
      }
      try {
        _reportError(error, stackTrace);
      } catch (reportingError, reportingStackTrace) {
        _reportApplyFailure(reportingError, reportingStackTrace);
      }
    }
  }

  static void _reportApplyFailure(Object error, StackTrace stackTrace) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'BusyMax Linux header bar',
        context: ErrorDescription(
          'while applying native header-bar configuration',
        ),
      ),
    );
  }

  static void _afterCurrentFrame(VoidCallback callback) {
    SchedulerBinding.instance.addPostFrameCallback((_) => callback());
  }
}
