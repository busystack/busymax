import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:busymax/src/google_tasks/api/google_tasks_api_surface.dart';

void main() {
  test('implemented method set matches cached discovery document', () {
    final discovery =
        jsonDecode(
              File('tool/cache/tasks_v1_discovery.json').readAsStringSync(),
            )
            as Map<String, Object?>;
    final resources = (discovery['resources'] as Map).cast<String, Object?>();
    final methods = <String>{
      for (final resourceName in ['tasklists', 'tasks'])
        for (final methodName in _methodNames(resources, resourceName))
          '$resourceName.$methodName',
    };

    expect(implementedGoogleTasksMethods, equals(methods));
  });
}

Iterable<String> _methodNames(
  Map<String, Object?> resources,
  String resourceName,
) {
  final resource = (resources[resourceName] as Map).cast<String, Object?>();
  final methods = (resource['methods'] as Map).cast<String, Object?>();
  return methods.keys;
}
