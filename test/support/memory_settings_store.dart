import 'dart:convert';

import 'package:busymax/src/app/app_settings.dart';

class MemorySettingsStore implements LocalSettingsStore {
  MemorySettingsStore([Map<String, Object?> initial = const {}])
    : value = Map.of(initial);

  Map<String, Object?> value;
  int saves = 0;

  @override
  Future<Map<String, Object?>> load() async => value;

  @override
  Future<void> save(Map<String, Object?> json) async {
    saves++;
    value = (jsonDecode(jsonEncode(json)) as Map).cast<String, Object?>();
  }
}
