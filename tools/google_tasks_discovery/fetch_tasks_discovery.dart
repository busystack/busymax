import 'dart:convert';
import 'dart:io';

const discoveryUrl =
    'https://www.googleapis.com/discovery/v1/apis/tasks/v1/rest';
const lockedRevision = '20260602';
const cachePath = 'tools/google_tasks_discovery/cache/tasks_v1_discovery.json';
const revisionDartPath =
    'lib/src/google_tasks/api/tasks_discovery_revision.dart';

Future<void> main() async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(Uri.parse(discoveryUrl));
    final response = await request.close();
    if (response.statusCode != HttpStatus.ok) {
      stderr.writeln('Discovery fetch failed: HTTP ${response.statusCode}');
      exitCode = 1;
      return;
    }

    final body = await utf8.decodeStream(response);
    await File(cachePath).parent.create(recursive: true);
    await File(cachePath).writeAsString(body);

    final json = jsonDecode(body) as Map<String, Object?>;
    final revision = json['revision']?.toString() ?? '';
    final resources = (json['resources'] as Map).cast<String, Object?>();
    final schemas = (json['schemas'] as Map).cast<String, Object?>();

    stdout.writeln('name: ${json['name']}');
    stdout.writeln('version: ${json['version']}');
    stdout.writeln('revision: $revision');
    stdout.writeln('baseUrl: ${json['baseUrl']}');
    _printMethods(resources, 'tasklists');
    _printMethods(resources, 'tasks');
    _printSchema(schemas, 'Task');
    _printSchema(schemas, 'TaskList');

    if (revision != lockedRevision) {
      stderr.writeln(
        'WARNING: discovery revision changed from $lockedRevision to '
        '$revision. Regenerate method, schema, parameter, and contract-test '
        'artifacts before coding against the new surface.',
      );
    }

    await File(revisionDartPath).writeAsString(
      "const googleTasksDiscoveryRevision = '$lockedRevision';\n",
    );
  } finally {
    client.close(force: true);
  }
}

void _printMethods(Map<String, Object?> resources, String resourceName) {
  final resource = (resources[resourceName] as Map).cast<String, Object?>();
  final methods = (resource['methods'] as Map).cast<String, Object?>();
  stdout.writeln('resources.$resourceName.methods:');
  for (final name in methods.keys.toList()..sort()) {
    stdout.writeln('  - $name');
  }
}

void _printSchema(Map<String, Object?> schemas, String schemaName) {
  final schema = (schemas[schemaName] as Map).cast<String, Object?>();
  final properties = (schema['properties'] as Map).cast<String, Object?>();
  stdout.writeln('schemas.$schemaName:');
  for (final name in properties.keys.toList()..sort()) {
    stdout.writeln('  - $name');
  }
}
