import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/calendar_repository.dart';
import '../data/cloud_calendar_sharing_service.dart';

final class CloudCalendarSharingSession extends ChangeNotifier {
  CloudCalendarSharingSession(this._createService);

  final CloudCalendarSharingService Function(CalendarSourceEntity)
  _createService;
  CloudCalendarSharingService? service;
  CalendarSourceEntity? source;
  CloudCalendarShareSnapshot? snapshot;
  Object? error;
  bool busy = false;
  bool _disposed = false;
  int _generation = 0;
  Timer? _cooldownTimer;

  bool get canMutate =>
      !busy &&
      snapshot != null &&
      snapshot!.refreshError == null &&
      !snapshot!.outcomeUnknown &&
      service?.hasUnresolvedOutcome == false &&
      service?.isRateLimited == false;

  Future<void> select(CalendarSourceEntity? source) async {
    final generation = ++_generation;
    _cooldownTimer?.cancel();
    this.source = source;
    service = null;
    snapshot = null;
    error = null;
    busy = source != null;
    notifyListeners();
    if (source == null) return;
    await _run(generation, () {
      final selected = service = _createService(source);
      return selected.load();
    });
  }

  Future<CloudCalendarShareSnapshot?> mutate(
    Future<CloudCalendarShareSnapshot> Function(CloudCalendarSharingService)
    action,
  ) {
    final selected = service;
    if (_disposed || selected == null || !canMutate) return Future.value();
    busy = true;
    error = null;
    notifyListeners();
    return _run(_generation, () => action(selected));
  }

  Future<CloudCalendarShareSnapshot?> _run(
    int generation,
    Future<CloudCalendarShareSnapshot> Function() operation,
  ) async {
    try {
      final result = await operation();
      if (_disposed || generation != _generation) return null;
      return snapshot = result;
    } on Object catch (failure) {
      if (!_disposed && generation == _generation) error = failure;
      return null;
    } finally {
      if (!_disposed && generation == _generation) {
        busy = false;
        notifyListeners();
        _scheduleCooldown();
      }
    }
  }

  void _scheduleCooldown() {
    _cooldownTimer?.cancel();
    final delay = service?.retryAfter;
    if (delay == null) return;
    _cooldownTimer = Timer(delay + const Duration(milliseconds: 1), () {
      notifyListeners();
      _scheduleCooldown();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _cooldownTimer?.cancel();
    super.dispose();
  }
}
