import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('all platform location editors use ordinary native text fields', () {
    final linuxEvent = _source(
      'lib/src/features/calendar/presentation/event_editor.dart',
    );
    final linuxTask = _source(
      'lib/src/features/tasks/presentation/ical_task_fields_editor.dart',
    );
    final windowsEvent = _source(
      'lib/src/ui/windows/windows_event_editor_dialog.dart',
    );
    final windowsTaskCreate = _source(
      'lib/src/ui/windows/windows_task_editor_dialog.dart',
    );
    final windowsTaskDetails = _source(
      'lib/src/ui/windows/windows_task_details_dialog.dart',
    );

    expect(linuxEvent, contains("ValueKey('event-location-field')"));
    expect(linuxEvent, contains('title: TextFormField('));
    expect(linuxTask, contains("ValueKey('ical-task-location-field')"));
    expect(linuxTask, contains('title: TextField('));
    expect(windowsEvent, contains("ValueKey('windows-event-location-field')"));
    expect(windowsEvent, contains('child: TextBox('));
    expect(
      windowsTaskCreate,
      contains("ValueKey('windows-new-task-location-field')"),
    );
    expect(windowsTaskCreate, contains('child: TextBox('));
    expect(
      windowsTaskDetails,
      contains("'windows-task-details-location-field'"),
    );
    expect(windowsTaskDetails, contains('child: TextBox('));

    for (final source in [
      linuxEvent,
      linuxTask,
      windowsEvent,
      windowsTaskCreate,
      windowsTaskDetails,
    ]) {
      expect(source, isNot(contains('LocationAutocomplete')));
      expect(source, isNot(contains('LocationMapDialog')));
      expect(source, isNot(contains('LocationSearchController')));
    }
  });

  test('embedded map and address-search implementations are absent', () {
    for (final path in [
      'lib/src/features/maps/application/location_search_controller.dart',
      'lib/src/features/maps/application/location_map_controller.dart',
      'lib/src/features/maps/data/geoapify_client.dart',
      'lib/src/features/maps/data/map_tile_service.dart',
      'lib/src/features/maps/presentation/linux_location_autocomplete.dart',
      'lib/src/features/maps/presentation/linux_location_map_dialog.dart',
      'lib/src/features/maps/presentation/map_canvas.dart',
      'lib/src/ui/windows/windows_location_autocomplete.dart',
      'lib/src/ui/windows/windows_location_map_dialog.dart',
      'lib/src/features/maps/application/directions_launcher.dart',
    ]) {
      expect(File(path).existsSync(), isFalse, reason: path);
    }
  });

  test('new task editors cannot expose saved-location actions', () {
    final linuxDetails = _source(
      'lib/src/features/tasks/presentation/task_details_editor.dart',
    );
    final windowsCreate = _source(
      'lib/src/ui/windows/windows_task_editor_dialog.dart',
    );

    expect(linuxDetails, contains('savedIdentity: widget.isCreate'));
    expect(linuxDetails, contains('? null'));
    expect(windowsCreate, isNot(contains('windows-task-location-open')));
    expect(windowsCreate, isNot(contains('ExternalLocationLauncher')));
  });
}

String _source(String path) => File(path).readAsStringSync();
