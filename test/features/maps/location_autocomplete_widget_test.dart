import 'dart:async';
import 'dart:convert';

import 'package:busymax/l10n/generated/app_localizations.dart';
import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/features/maps/data/geoapify_client.dart';
import 'package:busymax/src/features/maps/domain/location_result.dart';
import 'package:busymax/src/features/maps/presentation/linux_location_autocomplete.dart';
import 'package:busymax/src/ui/windows/windows_location_autocomplete.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  testWidgets('Linux initial value is quiet and typing invalidates its point', (
    tester,
  ) async {
    var requests = 0;
    final changes = <LocationChange>[];
    final client = _client((_) async {
      requests++;
      return _results();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [geoapifyClientProvider.overrideWithValue(client)],
        child: _material(
          LinuxLocationAutocomplete(
            text: 'Existing room',
            enabled: true,
            onChanged: (_, change) => changes.add(change),
            onPreview: () async {},
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(requests, 0);
    expect(changes, isEmpty);

    await tester.enterText(
      find.byKey(const ValueKey('location-autocomplete-field')),
      'Central library',
    );
    expect(changes.single, const LocationChange.clear());
    await tester.pump(const Duration(milliseconds: 301));
    await tester.pump();
    expect(requests, 1);
    expect(find.text('Central Library, Example City'), findsOneWidget);
    expect(find.text('Approximate area'), findsOneWidget);
  });

  testWidgets('Linux arrow and Enter select without an editor submission', (
    tester,
  ) async {
    String? selectedText;
    LocationChange? selectedChange;
    var editorSubmissions = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          geoapifyClientProvider.overrideWithValue(
            _client((_) async => _results()),
          ),
        ],
        child: _material(
          CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.enter): () {
                editorSubmissions++;
              },
            },
            child: LinuxLocationAutocomplete(
              text: '',
              enabled: true,
              onChanged: (text, change) {
                selectedText = text;
                selectedChange = change;
              },
              onPreview: () async {},
            ),
          ),
        ),
      ),
    );
    await tester.enterText(
      find.byKey(const ValueKey('location-autocomplete-field')),
      'Central library',
    );
    await tester.pump(const Duration(milliseconds: 301));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(selectedText, 'Central Library, Example City');
    expect(selectedChange?.selection?.point.latitude, 49.2);
    expect(editorSubmissions, 0);

    await tester.enterText(
      find.byKey(const ValueKey('location-autocomplete-field')),
      'Meeting room 3',
    );
    expect(selectedChange, const LocationChange.clear());
  });

  testWidgets('Linux programmatic text update does not mimic user typing', (
    tester,
  ) async {
    var changes = 0;
    Widget build(String text) => ProviderScope(
      overrides: [
        geoapifyClientProvider.overrideWithValue(
          _client((_) async => _results()),
        ),
      ],
      child: _material(
        LinuxLocationAutocomplete(
          text: text,
          enabled: true,
          onChanged: (_, _) => changes++,
          onPreview: () async {},
        ),
      ),
    );

    await tester.pumpWidget(build('Old'));
    await tester.pumpWidget(build('Selected result'));
    expect(changes, 0);
    expect(
      tester
          .widget<TextField>(
            find.byKey(const ValueKey('location-autocomplete-field')),
          )
          .controller
          ?.text,
      'Selected result',
    );
  });

  testWidgets('Linux coordinate-only preview remains reachable', (
    tester,
  ) async {
    var previews = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          geoapifyClientProvider.overrideWithValue(
            _client((_) async => _results()),
          ),
        ],
        child: _material(
          LinuxLocationAutocomplete(
            text: '',
            enabled: false,
            previewAvailable: true,
            onChanged: (_, _) {},
            onPreview: () async => previews++,
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.map_outlined));
    expect(previews, 1);
  });

  testWidgets('Windows uses Fluent autocomplete and preserves free text', (
    tester,
  ) async {
    final textController = TextEditingController(text: 'Existing');
    addTearDown(textController.dispose);
    String? draftText;
    LocationChange? draftChange;
    await tester.pumpWidget(
      fluent.FluentApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: fluent.ScaffoldPage(
          content: WindowsLocationAutocomplete(
            controller: textController,
            client: _client((_) async => _results()),
            enabled: true,
            onChanged: (text, change) {
              draftText = text;
              draftChange = change;
            },
            onPreview: () async {},
          ),
        ),
      ),
    );

    expect(find.byType(fluent.AutoSuggestBox<LocationResult>), findsOneWidget);
    await tester.enterText(find.byType(fluent.TextBox), 'Meeting room 3');
    expect(draftText, 'Meeting room 3');
    expect(draftChange, const LocationChange.clear());
  });
}

Widget _material(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

GeoapifyClient _client(
  Future<http.StreamedResponse> Function(http.BaseRequest request) handler,
) => GeoapifyClient(
  client: _Transport(handler),
  apiKey: 'key',
  canUseNetwork: () async => true,
);

http.StreamedResponse _results() => http.StreamedResponse(
  Stream.value(
    utf8.encode(
      jsonEncode({
        'results': [
          {
            'formatted': 'Central Library, Example City',
            'name': 'Central Library',
            'lat': 49.2,
            'lon': -123.1,
            'result_type': 'city',
          },
        ],
      }),
    ),
  ),
  200,
);

final class _Transport extends http.BaseClient {
  _Transport(this.handler);
  final Future<http.StreamedResponse> Function(http.BaseRequest request)
  handler;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      handler(request);
}
